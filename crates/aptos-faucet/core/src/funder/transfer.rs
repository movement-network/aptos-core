// Copyright © Aptos Foundation
// SPDX-License-Identifier: Apache-2.0

use super::{
    common::{
        submit_transaction, ApiConnectionConfig, GasUnitPriceManager, TransactionSubmissionConfig,
    },
    FunderHealthMessage, FunderTrait,
};
use crate::{
    endpoints::{AptosTapError, AptosTapErrorCode, RejectionReason, RejectionReasonCode},
    funder::common::update_sequence_numbers,
    middleware::TRANSFER_FUNDER_ACCOUNT_BALANCE,
};
use anyhow::{Context, Result};
use aptos_logger::info;
use aptos_sdk::{
    crypto::{ed25519::Ed25519PrivateKey, PrivateKey},
    rest_client::{AptosBaseUrl, Client},
    transaction_builder::{aptos_stdlib, TransactionFactory},
    types::{
        account_address::AccountAddress,
        chain_id::ChainId,
        transaction::{authenticator::AuthenticationKey, SignedTransaction, TransactionPayload},
        LocalAccount,
    },
};
use async_trait::async_trait;
use reqwest::Url;
use serde::{Deserialize, Serialize};
use std::{collections::HashMap, str::FromStr, time::Duration};
use tokio::sync::RwLock;

#[derive(Clone, Debug, Deserialize, Serialize)]
pub struct TransferFunderConfig {
    #[serde(flatten)]
    pub api_connection_config: ApiConnectionConfig,

    #[serde(flatten)]
    pub transaction_submission_config: TransactionSubmissionConfig,

    /// The minimum amount of coins the funder account should have. If it
    /// doesn't have this many, or if it gets to this point, the funder will
    /// intentionally fail to build, resulting in a failure on startup.
    pub minimum_funds: MinimumFunds,

    /// The amount of coins to fund the receiver account.
    pub amount_to_fund: AmountToFund,

    /// If true, the funder also funds receiver accounts that already exist,
    /// transferring up to `amount_to_fund` to them with
    /// `0x1::aptos_account::transfer`. If false (the default), a request for an
    /// existing account is rejected with `AccountAlreadyExists`.
    #[serde(default)]
    pub allow_existing_accounts: bool,
}

impl TransferFunderConfig {
    pub async fn build_funder(&self) -> Result<TransferFunder> {
        // Read in private key.
        let key = self.api_connection_config.get_key()?;

        // Build account address from private key.
        let account_address = account_address_from_private_key(&key);

        // Build local representation of account.
        let faucet_account = LocalAccount::new(account_address, key, 0);

        let funder = TransferFunder::new(
            faucet_account,
            self.api_connection_config.chain_id,
            self.api_connection_config.node_url.clone(),
            self.api_connection_config.api_key.clone(),
            self.api_connection_config.additional_headers.clone(),
            self.minimum_funds,
            self.amount_to_fund,
            self.transaction_submission_config
                .get_gas_unit_price_ttl_secs(),
            self.transaction_submission_config.gas_unit_price_override,
            self.transaction_submission_config.max_gas_amount,
            self.transaction_submission_config
                .transaction_expiration_secs,
            self.transaction_submission_config
                .wait_for_outstanding_txns_secs,
            self.transaction_submission_config.wait_for_transactions,
            self.allow_existing_accounts,
        );

        Ok(funder)
    }
}

pub struct TransferFunder {
    faucet_account: RwLock<LocalAccount>,

    transaction_factory: TransactionFactory,

    /// URL of an Aptos node API.
    node_url: Url,
    node_api_key: Option<String>,
    node_additional_headers: Option<HashMap<String, String>>,

    /// The minimum amount of funds the Funder should have to operate.
    minimum_funds: MinimumFunds,

    /// Maximum amount we'll fund an account.
    amount_to_fund: AmountToFund,

    /// See comment of gas_unit_price.
    gas_unit_price_manager: GasUnitPriceManager,

    /// If this is Some, we'll use this. If not, we'll get the gas_unit_price
    /// from the gas_unit_price_manager.
    gas_unit_price_override: Option<u64>,

    /// When recovering from being overloaded, this struct ensures we handle
    /// requests in the order they came in.
    outstanding_requests: RwLock<Vec<(AccountAddress, u64)>>,

    /// Amount of time we'll wait for the seqnum to catch up before resetting it.
    wait_for_outstanding_txns_secs: u64,

    /// If set, we won't return responses until the transaction is processed.
    wait_for_transactions: bool,

    /// If set, we also fund receiver accounts that already exist, rather than
    /// rejecting them with `AccountAlreadyExists`.
    allow_existing_accounts: bool,
}

impl TransferFunder {
    pub fn new(
        faucet_account: LocalAccount,
        chain_id: ChainId,
        node_url: Url,
        node_api_key: Option<String>,
        node_additional_headers: Option<HashMap<String, String>>,
        minimum_funds: MinimumFunds,
        amount_to_fund: AmountToFund,
        gas_unit_price_ttl_secs: Duration,
        gas_unit_price_override: Option<u64>,
        max_gas_amount: u64,
        transaction_expiration_secs: u64,
        wait_for_outstanding_txns_secs: u64,
        wait_for_transactions: bool,
        allow_existing_accounts: bool,
    ) -> Self {
        let gas_unit_price_manager =
            GasUnitPriceManager::new(node_url.clone(), gas_unit_price_ttl_secs);

        Self {
            faucet_account: RwLock::new(faucet_account),
            transaction_factory: TransactionFactory::new(chain_id)
                .with_max_gas_amount(max_gas_amount)
                .with_transaction_expiration_time(transaction_expiration_secs),
            node_url,
            node_api_key,
            node_additional_headers,
            minimum_funds,
            amount_to_fund,
            gas_unit_price_manager,
            gas_unit_price_override,
            outstanding_requests: RwLock::new(vec![]),
            wait_for_outstanding_txns_secs,
            wait_for_transactions,
            allow_existing_accounts,
        }
    }

    /// Within a single request we should just call this once and use this client
    /// the entire time because it uses cookies, ensuring we're talking to the same
    /// node behind the LB every time.
    pub fn get_api_client(&self) -> Client {
        let mut builder = Client::builder(AptosBaseUrl::Custom(self.node_url.clone()));

        if let Some(api_key) = self.node_api_key.clone() {
            builder = builder.api_key(&api_key).expect("Failed to set API key");
        }

        if let Some(additional_headers) = &self.node_additional_headers {
            for (key, value) in additional_headers {
                builder = builder.header(key, value).expect("Failed to set header");
            }
        }

        builder.build()
    }

    async fn get_gas_unit_price(&self) -> Result<u64, AptosTapError> {
        match self.gas_unit_price_override {
            Some(gas_unit_price) => Ok(gas_unit_price),
            None => self
                .gas_unit_price_manager
                .get_gas_unit_price()
                .await
                .map_err(|e| {
                    AptosTapError::new_with_error_code(e, AptosTapErrorCode::AptosApiError)
                }),
        }
    }

    /// This function builds, signs, submits, waits for, and checks the result
    /// of a transaction.
    async fn execute_transaction(
        &self,
        client: &Client,
        payload: TransactionPayload,
        // Only used for logging.
        receiver_address: &AccountAddress,
    ) -> Result<SignedTransaction, AptosTapError> {
        // Build a transaction factory using the gas unit price from the
        // GasUnitPriceManager. This mostly ensures that we will build a
        // transaction with a gas unit price that will be accepted.
        let transaction_factory = self
            .transaction_factory
            .clone()
            .with_gas_unit_price(self.get_gas_unit_price().await?);

        let transaction_builder = transaction_factory.payload(payload);

        let signed_transaction = self
            .faucet_account
            .write()
            .await
            .sign_with_transaction_builder(transaction_builder);

        submit_transaction(
            client,
            &self.faucet_account,
            signed_transaction,
            receiver_address,
            self.wait_for_transactions,
        )
        .await
    }

    /// Reject a receiver that already exists on chain (it has a sequence number)
    /// unless the funder is configured to fund existing accounts.
    fn check_receiver_eligibility(
        &self,
        receiver_address: AccountAddress,
        receiver_seq_num: Option<u64>,
    ) -> Result<(), AptosTapError> {
        if receiver_seq_num.is_some() && !self.allow_existing_accounts {
            return Err(AptosTapError::new(
                "Account ineligible".to_string(),
                AptosTapErrorCode::Rejected,
            )
            .rejection_reasons(vec![RejectionReason::new(
                format!("Account {} already exists", receiver_address),
                RejectionReasonCode::AccountAlreadyExists,
            )]));
        }
        Ok(())
    }

    async fn is_healthy_as_result(&self) -> Result<(), AptosTapError> {
        let funder_health = self.is_healthy().await;
        if !funder_health.can_process_requests {
            return Err(AptosTapError::new(
                format!(
                    "Tap TransferFunder is not able to handle requests right now: {}",
                    funder_health
                        .message
                        .unwrap_or_else(|| "no message".to_string()),
                ),
                AptosTapErrorCode::FunderAccountProblem,
            ));
        }
        Ok(())
    }
}

#[async_trait]
impl FunderTrait for TransferFunder {
    /// Before actually initiating the fund transaction, we do a set of checks,
    /// such as ensuring that the funder has sufficient funds and, unless
    /// `allow_existing_accounts` is set, that the receiver account does not yet
    /// exist. These are not meant to completely verify these preconditions, as
    /// there could be races between the checks and the transaction submission
    /// between requests, but it reduces the prevalence of transaction failure.
    /// The existence check is a policy check only: the transfer we submit
    /// works for both new and existing accounts, so a receiver created between
    /// the check and the submission is still funded.
    /// If check_only is set, we only do the initial checks without actually
    /// submitting any transactions.
    async fn fund(
        &self,
        amount: Option<u64>,
        receiver_address: AccountAddress,
        check_only: bool,
        did_bypass_checkers: bool,
    ) -> Result<Vec<SignedTransaction>, AptosTapError> {
        // Confirm the funder has sufficient balance, return a 500 if not. This
        // will only happen briefly, soon after we get into this state the LB
        // will deregister this instance based on the health check responses
        // being returned from `/`.
        self.is_healthy_as_result().await?;

        let client = self.get_api_client();

        // Determine amount to fund.
        let amount = self.get_amount(amount, did_bypass_checkers);

        // Update the sequence numbers of the accounts.
        let (_funder_seq_num, receiver_seq_num) = update_sequence_numbers(
            &client,
            &self.faucet_account,
            &self.outstanding_requests,
            receiver_address,
            amount,
            self.wait_for_outstanding_txns_secs,
        )
        .await?;

        // The receiver sequence number is Some if the account already exists.
        // By default we only fund accounts that do not exist yet.
        self.check_receiver_eligibility(receiver_address, receiver_seq_num)?;

        // This Move function creates the receiver account if it does not exist
        // yet, then transfers the requested amount of coins to it.
        let transactions = if check_only {
            vec![]
        } else {
            let txn = self
                .execute_transaction(
                    &client,
                    aptos_stdlib::aptos_account_transfer(receiver_address, amount),
                    &receiver_address,
                )
                .await?;
            info!(
                hash = txn.committed_hash().to_hex_literal(),
                address = receiver_address,
                amount = amount,
                event = "transaction_submitted"
            );
            vec![txn]
        };

        Ok(transactions)
    }

    fn get_amount(
        &self,
        amount: Option<u64>,
        // Ignored for now with TransferFunder, since generally we don't use Bypassers
        // when using the TransferFunder.
        _did_bypass_checkers: bool,
    ) -> u64 {
        match amount {
            Some(amount) => std::cmp::min(amount, self.amount_to_fund.0),
            None => self.amount_to_fund.0,
        }
    }

    /// Assert funder account actually exists and has the minimum funds.
    async fn is_healthy(&self) -> FunderHealthMessage {
        let account_address = self.faucet_account.read().await.address();
        let funder_balance = match self
            .get_api_client()
            .view_apt_account_balance(account_address)
            .await
        {
            Ok(response) => response.into_inner(),
            Err(e) => return FunderHealthMessage {
                can_process_requests: false,
                message: Some(format!(
                    "Failed to get account balance to determine whether tap account has sufficient funds: {:#}",
                    e
                )),
            },
        };

        TRANSFER_FUNDER_ACCOUNT_BALANCE.set(funder_balance as i64);

        if funder_balance < self.minimum_funds.0 {
            FunderHealthMessage {
                can_process_requests: false,
                message: Some(format!(
                    "Funder account {} has insufficient funds. It has {}, but the minimum is {}",
                    account_address, funder_balance, self.minimum_funds.0
                )),
            }
        } else {
            FunderHealthMessage {
                can_process_requests: true,
                message: None,
            }
        }
    }
}

fn account_address_from_private_key(private_key: &Ed25519PrivateKey) -> AccountAddress {
    let public_key = private_key.public_key();
    let auth_key = AuthenticationKey::ed25519(&public_key);
    AccountAddress::new(*auth_key.account_address())
}

// Use newtypes so we don't accidentally mix these up.

#[derive(Clone, Copy, Debug, Default, Deserialize, Eq, PartialEq, Serialize)]
pub struct MinimumFunds(pub u64);

impl std::fmt::Display for MinimumFunds {
    fn fmt(&self, f: &mut std::fmt::Formatter) -> std::fmt::Result {
        write!(f, "{}", &self.0)
    }
}

impl FromStr for MinimumFunds {
    type Err = anyhow::Error;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        let data = s
            .parse::<u64>()
            .with_context(|| format!("Parsing u64 string {} failed", s))?;
        Ok(Self(data))
    }
}

#[derive(Clone, Copy, Debug, Default, Deserialize, Eq, PartialEq, Serialize)]
pub struct AmountToFund(pub u64);

impl std::fmt::Display for AmountToFund {
    fn fmt(&self, f: &mut std::fmt::Formatter) -> std::fmt::Result {
        write!(f, "{}", &self.0)
    }
}

impl FromStr for AmountToFund {
    type Err = anyhow::Error;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        let data = s
            .parse::<u64>()
            .with_context(|| format!("Parsing u64 string {} failed", s))?;
        Ok(Self(data))
    }
}

#[cfg(test)]
mod test {
    use super::*;
    use crate::endpoints::USE_HELPFUL_ERRORS;
    use aptos_sdk::{
        bcs, crypto::Uniform, move_types::account_address::AccountAddress as MoveAddress,
    };
    use poem::{
        get, handler,
        http::StatusCode,
        listener::TcpListener,
        post,
        web::{Data, Path},
        Body, EndpointExt, Response, Route, Server,
    };
    use std::{
        collections::HashSet,
        sync::{Arc, Mutex},
    };

    const AMOUNT_TO_FUND: u64 = 100;

    /// A minimal stand-in for the node API endpoints the TransferFunder uses:
    /// account lookup, the balance view function and BCS transaction submission.
    /// Submitted transactions are treated as committed immediately, so the
    /// funder's on-chain sequence number is the number of submissions.
    struct MockNode {
        funder_address: AccountAddress,
        existing_accounts: HashMap<AccountAddress, u64>,
        submitted: Mutex<Vec<SignedTransaction>>,
    }

    fn with_state_headers(status: StatusCode, body: Body) -> Response {
        Response::builder()
            .status(status)
            .header("X-Aptos-Chain-Id", "4")
            .header("X-Aptos-Epoch", "1")
            .header("X-Aptos-Ledger-Version", "1")
            .header("X-Aptos-Ledger-Oldest-Version", "0")
            .header("X-Aptos-Block-Height", "1")
            .header("X-Aptos-Oldest-Block-Height", "0")
            .header("X-Aptos-Ledger-TimestampUsec", "1")
            .body(body)
    }

    #[handler]
    fn get_account(Path(address): Path<String>, node: Data<&Arc<MockNode>>) -> Response {
        let address = AccountAddress::from_hex(address.trim_start_matches("0x"))
            .expect("mock node got an invalid address");
        let sequence_number = if address == node.funder_address {
            Some(node.submitted.lock().unwrap().len() as u64)
        } else {
            node.existing_accounts.get(&address).copied()
        };
        match sequence_number {
            Some(sequence_number) => with_state_headers(
                StatusCode::OK,
                Body::from_json(serde_json::json!({
                    "sequence_number": sequence_number.to_string(),
                    "authentication_key": format!("0x{}", "00".repeat(32)),
                }))
                .unwrap(),
            ),
            None => with_state_headers(
                StatusCode::NOT_FOUND,
                Body::from_json(serde_json::json!({
                    "message": format!("Account not found by Address({})", address),
                    "error_code": "account_not_found",
                    "vm_error_code": null,
                }))
                .unwrap(),
            ),
        }
    }

    #[handler]
    fn view() -> Response {
        with_state_headers(
            StatusCode::OK,
            Body::from(bcs::to_bytes(&vec![u64::MAX]).unwrap()),
        )
    }

    #[handler]
    fn submit(body: Vec<u8>, node: Data<&Arc<MockNode>>) -> Response {
        let txn: SignedTransaction =
            bcs::from_bytes(&body).expect("mock node got an invalid transaction");
        node.submitted.lock().unwrap().push(txn);
        with_state_headers(StatusCode::ACCEPTED, Body::empty())
    }

    async fn start_mock_node(
        existing_accounts: &[(AccountAddress, u64)],
    ) -> (Url, Arc<MockNode>, LocalAccount) {
        let key = Ed25519PrivateKey::generate_for_testing();
        let funder_address = account_address_from_private_key(&key);
        let faucet_account = LocalAccount::new(funder_address, key, 0);
        let node = Arc::new(MockNode {
            funder_address,
            existing_accounts: existing_accounts.iter().copied().collect(),
            submitted: Mutex::new(vec![]),
        });
        let app = Route::new()
            .at("/v1/accounts/:address", get(get_account))
            .at("/v1/view", post(view))
            .at("/v1/transactions", post(submit))
            .data(node.clone());
        let port = aptos_config::utils::get_available_port();
        tokio::spawn(Server::new(TcpListener::bind(format!("127.0.0.1:{}", port))).run(app));
        let url = Url::parse(&format!("http://127.0.0.1:{}/", port)).unwrap();
        for _ in 0..100 {
            if tokio::net::TcpStream::connect(("127.0.0.1", port))
                .await
                .is_ok()
            {
                return (url, node, faucet_account);
            }
            tokio::time::sleep(Duration::from_millis(50)).await;
        }
        panic!("mock node did not start");
    }

    fn build_funder(
        faucet_account: LocalAccount,
        node_url: Url,
        allow_existing_accounts: bool,
    ) -> TransferFunder {
        let _ = USE_HELPFUL_ERRORS.set(true);
        TransferFunder::new(
            faucet_account,
            ChainId::test(),
            node_url,
            None,
            None,
            MinimumFunds(0),
            AmountToFund(AMOUNT_TO_FUND),
            Duration::from_secs(30),
            Some(100),
            10_000,
            30,
            // wait_for_outstanding_txns_secs
            5,
            // wait_for_transactions
            false,
            allow_existing_accounts,
        )
    }

    /// Assert that the transaction transfers `amount` to `receiver` through
    /// 0x1::aptos_account::transfer.
    fn assert_is_transfer(txn: &SignedTransaction, receiver: AccountAddress, amount: u64) {
        let entry_function = match txn.payload() {
            TransactionPayload::EntryFunction(entry_function) => entry_function,
            other => panic!("unexpected payload {:?}", other),
        };
        assert_eq!(entry_function.module().address(), &MoveAddress::ONE);
        assert_eq!(entry_function.module().name().as_str(), "aptos_account");
        assert_eq!(entry_function.function().as_str(), "transfer");
        assert_eq!(entry_function.args(), &[
            bcs::to_bytes(&receiver).unwrap(),
            bcs::to_bytes(&amount).unwrap()
        ]);
    }

    #[test]
    fn test_config_allow_existing_accounts_defaults_to_false() {
        let base = "node_url: \"http://127.0.0.1:8080\"\nchain_id: 4\nminimum_funds: 10\namount_to_fund: 5\n";
        let config: TransferFunderConfig = serde_yaml::from_str(base).unwrap();
        assert!(!config.allow_existing_accounts);

        let config: TransferFunderConfig =
            serde_yaml::from_str(&format!("{}allow_existing_accounts: true\n", base)).unwrap();
        assert!(config.allow_existing_accounts);
    }

    #[tokio::test]
    async fn test_existing_account_rejected_by_default() {
        let receiver = AccountAddress::random();
        let (url, node, faucet_account) = start_mock_node(&[(receiver, 3)]).await;
        let funder = build_funder(faucet_account, url, false);

        for check_only in [true, false] {
            let error = funder
                .fund(None, receiver, check_only, false)
                .await
                .expect_err("existing account should be rejected by default");
            assert_eq!(error.error_code, AptosTapErrorCode::Rejected);
            assert_eq!(
                error
                    .rejection_reasons
                    .iter()
                    .map(|reason| reason.get_code())
                    .collect::<Vec<_>>(),
                vec![RejectionReasonCode::AccountAlreadyExists]
            );
        }
        assert!(node.submitted.lock().unwrap().is_empty());
    }

    #[tokio::test]
    async fn test_existing_account_funded_when_allowed() {
        let receiver = AccountAddress::random();
        let (url, node, faucet_account) = start_mock_node(&[(receiver, 3)]).await;
        let funder = build_funder(faucet_account, url, true);

        // check_only passes the checks without submitting anything.
        let txns = funder.fund(None, receiver, true, false).await.unwrap();
        assert!(txns.is_empty());
        assert!(node.submitted.lock().unwrap().is_empty());

        // A real request transfers to the existing account, capped at
        // amount_to_fund, and does not wait on the receiver's sequence number.
        let txns = tokio::time::timeout(
            Duration::from_secs(5),
            funder.fund(Some(AMOUNT_TO_FUND * 10), receiver, false, false),
        )
        .await
        .expect("funding an existing account should not stall")
        .unwrap();
        assert_eq!(txns.len(), 1);
        assert_is_transfer(&txns[0], receiver, AMOUNT_TO_FUND);
        let submitted = node.submitted.lock().unwrap();
        assert_eq!(submitted.len(), 1);
        assert_is_transfer(&submitted[0], receiver, AMOUNT_TO_FUND);
    }

    #[tokio::test]
    async fn test_new_account_funded_in_both_modes() {
        for allow_existing_accounts in [false, true] {
            let (url, node, faucet_account) = start_mock_node(&[]).await;
            let funder = build_funder(faucet_account, url, allow_existing_accounts);
            let receiver = AccountAddress::random();
            let txns = funder.fund(Some(7), receiver, false, false).await.unwrap();
            assert_eq!(txns.len(), 1);
            assert_is_transfer(&txns[0], receiver, 7);
            assert_eq!(node.submitted.lock().unwrap().len(), 1);
        }
    }

    /// Many concurrent requests for the same existing receiver share the same
    /// (receiver, amount) key in the outstanding request queue. They must all
    /// complete, each with its own funder sequence number.
    #[tokio::test(flavor = "multi_thread", worker_threads = 4)]
    async fn test_concurrent_requests_for_same_existing_account() {
        let receiver = AccountAddress::random();
        let (url, node, faucet_account) = start_mock_node(&[(receiver, 0)]).await;
        let funder = Arc::new(build_funder(faucet_account, url, true));

        let num_requests = 40;
        let handles: Vec<_> = (0..num_requests)
            .map(|_| {
                let funder = funder.clone();
                tokio::spawn(async move { funder.fund(None, receiver, false, false).await })
            })
            .collect();
        let mut sequence_numbers = HashSet::new();
        for handle in handles {
            let txns = tokio::time::timeout(Duration::from_secs(20), handle)
                .await
                .expect("concurrent requests should not stall")
                .unwrap()
                .unwrap();
            assert_is_transfer(&txns[0], receiver, AMOUNT_TO_FUND);
            assert!(sequence_numbers.insert(txns[0].sequence_number()));
        }
        assert_eq!(
            sequence_numbers,
            (0..num_requests as u64).collect::<HashSet<_>>()
        );
        assert_eq!(node.submitted.lock().unwrap().len(), num_requests);
    }
}
