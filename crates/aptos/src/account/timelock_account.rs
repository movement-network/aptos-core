// Copyright © Aptos Foundation
// SPDX-License-Identifier: Apache-2.0

use crate::{
    common::types::{
        CliCommand, CliError, CliTypedResult, TimelockAccount,
        TimelockAccountWithProposalHash, TransactionOptions, TransactionSummary,
    },
    governance::CompileScriptFunction,
};
use aptos_api_types::ViewFunction;
use aptos_cached_packages::aptos_stdlib;
use aptos_rest_client::{
    aptos_api_types::{WriteResource, WriteSetChange},
    Transaction,
};
use aptos_types::{
    account_address::AccountAddress,
    transaction::{Script, TransactionPayload},
};
use async_trait::async_trait;
use bcs::to_bytes;
use clap::Parser;
use move_core_types::{ident_str, language_storage::ModuleId};
use rand::{rngs::OsRng, RngCore};
use serde::Serialize;
use serde_json::json;

/// Length in bytes of execution hashes, proposal hashes, and salts.
const TIMELOCK_BYTES_LENGTH: usize = 32;
/// Maximum byte length of the optional off-chain script path pointer.
const MAX_SCRIPT_PATH_LENGTH: usize = 256;
/// Fully qualified type of the event emitted when a timelock transaction is proposed.
const CREATE_TRANSACTION_EVENT_TYPE: &str = "0x1::timelock::CreateTransaction";

/// Decode a hex string (with or without 0x prefix) that must be exactly 32 bytes.
fn parse_hex_32(input: &str, arg_name: &str) -> CliTypedResult<Vec<u8>> {
    let bytes = hex::decode(input.trim_start_matches("0x")).map_err(|err| {
        CliError::CommandArgumentError(format!("Invalid hex value for --{}: {}", arg_name, err))
    })?;
    if bytes.len() != TIMELOCK_BYTES_LENGTH {
        return Err(CliError::CommandArgumentError(format!(
            "--{} must be exactly {} bytes, got {}",
            arg_name,
            TIMELOCK_BYTES_LENGTH,
            bytes.len()
        )));
    }
    Ok(bytes)
}

fn timelock_view_function(function: &'static str, args: Vec<Vec<u8>>) -> ViewFunction {
    ViewFunction {
        module: ModuleId::new(AccountAddress::ONE, ident_str!("timelock").to_owned()),
        function: ident_str!(function).to_owned(),
        ty_args: vec![],
        args,
    }
}

/// Fetch a timelock transaction from on-chain via the `timelock::get_transaction` view function.
async fn get_timelock_transaction(
    txn_options: &TransactionOptions,
    timelock_address: AccountAddress,
    proposal_hash: &[u8],
) -> CliTypedResult<serde_json::Value> {
    Ok(txn_options
        .view(timelock_view_function("get_transaction", vec![
            to_bytes(&timelock_address)?,
            to_bytes(proposal_hash)?,
        ]))
        .await?[0]
        .clone())
}

/// Parse the proposal hash and submit a timelock entry function that takes
/// `(timelock_address, proposal_hash)`. Shared by the cancel-transaction and approve-resolution
/// commands, which differ only in the entry function invoked.
async fn submit_proposal_hash_action(
    txn_options: &TransactionOptions,
    account_with_hash: &TimelockAccountWithProposalHash,
    payload: impl FnOnce(AccountAddress, Vec<u8>) -> TransactionPayload,
) -> CliTypedResult<TransactionSummary> {
    let proposal_hash = parse_hex_32(&account_with_hash.proposal_hash, "proposal-hash")?;
    txn_options
        .submit_transaction(payload(
            account_with_hash.timelock_account.timelock_address,
            proposal_hash,
        ))
        .await
        .map(|inner| inner.into())
}

/// Compile the resolution script, fetch the on-chain proposal, and confirm the compiled script's
/// hash equals the proposal's `execution_hash`. Returns the compiled bytecode and the on-chain
/// transaction on match; otherwise a "Transaction mismatch" error. Shared by the
/// verify-transaction and execute commands.
async fn compile_and_match_execution_hash(
    txn_options: &TransactionOptions,
    compile_proposal_args: CompileScriptFunction,
    command_name: &'static str,
    timelock_address: AccountAddress,
    proposal_hash: &[u8],
) -> CliTypedResult<(Vec<u8>, serde_json::Value)> {
    let (bytecode, script_hash) =
        compile_proposal_args.compile(command_name, txn_options.prompt_options)?;
    let timelock_transaction =
        get_timelock_transaction(txn_options, timelock_address, proposal_hash).await?;
    let expected_execution_hash = format!("0x{}", hex::encode(script_hash.to_vec()));
    let actual_execution_hash = timelock_transaction["execution_hash"]
        .as_str()
        .unwrap_or_default()
        .to_string();
    if expected_execution_hash != actual_execution_hash {
        return Err(CliError::UnexpectedError(format!(
            "Transaction mismatch: The script you provided has an execution hash of \
            {expected_execution_hash}, but the on-chain transaction proposal you specified \
            has an execution hash of {actual_execution_hash}."
        )));
    }
    Ok((bytecode, timelock_transaction))
}

/// Create a new timelock account on-chain.
///
/// Creates a resource account derived from the sender; the sender gains no authority over it —
/// roles are determined entirely by the provided lists.
#[derive(Debug, Parser)]
pub struct Create {
    /// Addresses authorized to propose AND cancel transactions. Must contain at least one address.
    #[clap(long, num_args = 1.., required = true, value_parser = crate::common::types::load_account_arg)]
    pub(crate) creators: Vec<AccountAddress>,
    /// Addresses authorized to execute transactions after the timelock period.
    /// If empty, creators can also execute.
    #[clap(long, num_args = 0.., value_parser = crate::common::types::load_account_arg)]
    pub(crate) executors: Vec<AccountAddress>,
    /// Addresses authorized ONLY to cancel pending transactions, at any time (emergency response).
    /// Cancelers cannot propose or execute. Optional.
    #[clap(long, num_args = 0.., value_parser = crate::common::types::load_account_arg)]
    pub(crate) cancelers: Vec<AccountAddress>,
    /// Minimum delay in seconds between proposing a transaction and being able to execute it.
    #[clap(long)]
    pub(crate) num_seconds_execute: u64,
    #[clap(flatten)]
    pub(crate) txn_options: TransactionOptions,
}

/// A shortened create timelock account output
#[derive(Clone, Debug, Serialize)]
pub struct CreateSummary {
    #[serde(flatten)]
    pub timelock_account: Option<TimelockAccount>,
    #[serde(flatten)]
    pub transaction_summary: TransactionSummary,
}

impl From<Transaction> for CreateSummary {
    fn from(transaction: Transaction) -> Self {
        let transaction_summary = TransactionSummary::from(&transaction);

        let mut summary = CreateSummary {
            transaction_summary,
            timelock_account: None,
        };

        if let Transaction::UserTransaction(txn) = transaction {
            summary.timelock_account = txn.info.changes.iter().find_map(|change| match change {
                WriteSetChange::WriteResource(WriteResource { address, data, .. }) => {
                    if data.typ.name.as_str() == "TimelockAccount"
                        && data.typ.module.as_str() == "timelock"
                    {
                        Some(TimelockAccount {
                            timelock_address: *address.inner(),
                        })
                    } else {
                        None
                    }
                },
                _ => None,
            });
        }

        summary
    }
}

#[async_trait]
impl CliCommand<CreateSummary> for Create {
    fn command_name(&self) -> &'static str {
        "CreateTimelock"
    }

    async fn execute(self) -> CliTypedResult<CreateSummary> {
        self.txn_options
            .submit_transaction(aptos_stdlib::timelock_create(
                self.creators,
                self.executors,
                self.cancelers,
                self.num_seconds_execute,
            ))
            .await
            .map(CreateSummary::from)
    }
}

/// Propose a new timelock transaction.
///
/// As one of the creators of the timelock account, propose the SHA3-256 hash of a resolution
/// script's bytecode. After the timelock period elapses, an executor submits that exact script
/// (see Execute). The script must call `timelock::resolve` to obtain the timelock account's
/// signer and then perform the transaction's effects.
///
/// The script can be provided as Move source (--script-path), compiled bytecode
/// (--compiled-script-path), or directly as a precomputed hash (--execution-hash).
///
/// CAUTION: the proposal commits only to the script's bytecode (its hash), NOT to any arguments.
/// The script must take only the executor signer (`fun main(executor: &signer)`); bake every other
/// value into the body. A script with extra parameters lets the executor supply values the
/// proposal never agreed to.
#[derive(Debug, Parser)]
pub struct CreateTransaction {
    #[clap(flatten)]
    pub(crate) timelock_account: TimelockAccount,
    /// SHA3-256 hash (hex) of the resolution script's bytecode, if already known.
    /// Alternative to providing the script itself for compilation.
    #[clap(long, group = "script")]
    pub(crate) execution_hash: Option<String>,
    #[clap(flatten)]
    pub(crate) compile_proposal_args: CompileScriptFunction,
    /// Seconds that must elapse after proposal before this transaction can be executed.
    /// Must be at least the timelock account's configured minimum delay.
    #[clap(long)]
    pub(crate) num_seconds_execute: u64,
    /// 32-byte hex salt disambiguating duplicate proposals of the same script.
    /// A random salt is generated if not provided.
    #[clap(long)]
    pub(crate) salt: Option<String>,
    /// Optional off-chain pointer (e.g. an IPFS URI or URL) to the human-readable script
    /// source and metadata, stored on-chain alongside the proposal.
    #[clap(long)]
    pub(crate) script_path_uri: Option<String>,
    #[clap(flatten)]
    pub(crate) txn_options: TransactionOptions,
}

/// A shortened create timelock transaction output
#[derive(Clone, Debug, Serialize)]
pub struct CreateTransactionSummary {
    /// The hash identifying this proposal on-chain (keccak256(execution_hash || salt)).
    /// Pass it as --proposal-hash to the cancel-transaction, verify-transaction, and
    /// execute commands.
    pub proposal_hash: Option<String>,
    pub execution_hash: String,
    pub salt: String,
    #[serde(flatten)]
    pub transaction_summary: TransactionSummary,
}

/// Extract the on-chain proposal hash from the CreateTransaction event, if present.
fn extract_timelock_proposal_hash(transaction: &Transaction) -> Option<String> {
    if let Transaction::UserTransaction(txn) = transaction {
        txn.events.iter().find_map(|event| {
            if event.typ.to_string() == CREATE_TRANSACTION_EVENT_TYPE {
                event
                    .data
                    .get("proposal_hash")
                    .and_then(|hash| hash.as_str())
                    .map(str::to_string)
            } else {
                None
            }
        })
    } else {
        None
    }
}

#[async_trait]
impl CliCommand<CreateTransactionSummary> for CreateTransaction {
    fn command_name(&self) -> &'static str {
        "CreateTransactionTimelock"
    }

    async fn execute(self) -> CliTypedResult<CreateTransactionSummary> {
        let execution_hash = if let Some(execution_hash) = self.execution_hash {
            parse_hex_32(&execution_hash, "execution-hash")?
        } else {
            let (_bytecode, script_hash) = self
                .compile_proposal_args
                .compile("CreateTransactionTimelock", self.txn_options.prompt_options)?;
            script_hash.to_vec()
        };
        let salt = match self.salt {
            Some(salt) => parse_hex_32(&salt, "salt")?,
            None => {
                let mut salt = [0u8; TIMELOCK_BYTES_LENGTH];
                OsRng.fill_bytes(&mut salt);
                salt.to_vec()
            },
        };
        let script_path_uri = self.script_path_uri.unwrap_or_default().into_bytes();
        if script_path_uri.len() > MAX_SCRIPT_PATH_LENGTH {
            return Err(CliError::CommandArgumentError(format!(
                "--script-path-uri must be at most {} bytes, got {}",
                MAX_SCRIPT_PATH_LENGTH,
                script_path_uri.len()
            )));
        }

        let transaction = self
            .txn_options
            .submit_transaction(aptos_stdlib::timelock_create_transaction(
                self.timelock_account.timelock_address,
                execution_hash.clone(),
                self.num_seconds_execute,
                salt.clone(),
                script_path_uri,
            ))
            .await?;

        Ok(CreateTransactionSummary {
            proposal_hash: extract_timelock_proposal_hash(&transaction),
            execution_hash: format!("0x{}", hex::encode(&execution_hash)),
            salt: format!("0x{}", hex::encode(&salt)),
            transaction_summary: TransactionSummary::from(&transaction),
        })
    }
}

/// Verify a resolution script matches an on-chain timelock transaction proposal.
///
/// Compiles the script locally (or reads its compiled bytecode) and compares its hash with the
/// execution hash stored in the on-chain proposal identified by the proposal hash.
#[derive(Debug, Parser)]
pub struct VerifyTransaction {
    #[clap(flatten)]
    pub(crate) timelock_account_with_proposal_hash: TimelockAccountWithProposalHash,
    #[clap(flatten)]
    pub(crate) txn_options: TransactionOptions,
    #[clap(flatten)]
    pub(crate) compile_proposal_args: CompileScriptFunction,
}

#[async_trait]
impl CliCommand<serde_json::Value> for VerifyTransaction {
    fn command_name(&self) -> &'static str {
        "VerifyTransactionTimelock"
    }

    async fn execute(self) -> CliTypedResult<serde_json::Value> {
        let proposal_hash = parse_hex_32(
            &self
                .timelock_account_with_proposal_hash
                .proposal_hash,
            "proposal-hash",
        )?;
        let timelock_address = self
            .timelock_account_with_proposal_hash
            .timelock_account
            .timelock_address;
        // Compiles the script, fetches the proposal, and errors on hash mismatch.
        let (_bytecode, timelock_transaction) = compile_and_match_execution_hash(
            &self.txn_options,
            self.compile_proposal_args,
            "VerifyTransactionTimelock",
            timelock_address,
            &proposal_hash,
        )
        .await?;
        Ok(json!({
            "Status": "Transaction match",
            "Timelock transaction": timelock_transaction
        }))
    }
}

/// Cancel a pending timelock transaction.
///
/// As one of the creators or cancelers of the timelock account, cancel a proposed transaction.
/// (Executors cannot cancel.) Canceled transactions are marked executed and can never be resolved.
#[derive(Debug, Parser)]
pub struct CancelTransaction {
    #[clap(flatten)]
    pub(crate) timelock_account_with_proposal_hash: TimelockAccountWithProposalHash,
    #[clap(flatten)]
    pub(crate) txn_options: TransactionOptions,
}

#[async_trait]
impl CliCommand<TransactionSummary> for CancelTransaction {
    fn command_name(&self) -> &'static str {
        "CancelTransactionTimelock"
    }

    async fn execute(self) -> CliTypedResult<TransactionSummary> {
        submit_proposal_hash_action(
            &self.txn_options,
            &self.timelock_account_with_proposal_hash,
            aptos_stdlib::timelock_cancel_transaction,
        )
        .await
    }
}

/// Pre-authorize resolution of a pending timelock transaction.
///
/// As one of the executors (or a creator, if the executor list is empty), approve a proposed
/// transaction for resolution without submitting the script yourself. This is the path for an
/// executor that cannot send a `Script` transaction — notably an Aptos multisig account, which
/// executes entry functions only: the multisig calls this through its normal create/approve flow.
/// Once approved, any party may submit the committed resolution script (see Execute) and it will
/// resolve. A direct executor does not need this — they can run Execute directly once the timelock
/// period has elapsed.
///
/// Approval is only permitted after the timelock delay has elapsed; resolution enforces it too.
#[derive(Debug, Parser)]
pub struct ApproveResolution {
    #[clap(flatten)]
    pub(crate) timelock_account_with_proposal_hash: TimelockAccountWithProposalHash,
    #[clap(flatten)]
    pub(crate) txn_options: TransactionOptions,
}

#[async_trait]
impl CliCommand<TransactionSummary> for ApproveResolution {
    fn command_name(&self) -> &'static str {
        "ApproveResolutionTimelock"
    }

    async fn execute(self) -> CliTypedResult<TransactionSummary> {
        submit_proposal_hash_action(
            &self.txn_options,
            &self.timelock_account_with_proposal_hash,
            aptos_stdlib::timelock_approve_resolution,
        )
        .await
    }
}

/// Execute a proposed timelock transaction whose timelock period has elapsed.
///
/// As an executor (or a creator when the executor list is empty), submit the proposed resolution
/// script. It must be self-contained, taking only the executor signer (`fun main(executor: &signer)`):
/// all values — including the timelock address and the salt from which it derives its proposal hash
/// at runtime — are baked in, so the execution hash commits to them. The CLI passes no arguments;
/// `--timelock-address`/`--proposal-hash` drive only the pre-flight checks (the script hash matches
/// the proposal, and the proposal is executable).
///
/// CAUTION — script arguments: only the bytecode is committed to, not arguments; the CLI passes
/// none. Never use a resolution script that takes parameters beyond the executor signer (the
/// executor could otherwise supply values the proposal never agreed to).
///
/// CAUTION — multisig executors: a multisig account (0x1::multisig_account) dispatches entry
/// functions, not `Script`s, so it cannot run `Execute` itself. Instead it calls `approve-resolution`
/// through its normal flow, then any account runs `Execute` with the committed script. This
/// authorizes execution only — it does not raise the transaction-size limit.
///
/// CAUTION — hardware wallets: the script's full bytecode travels inline, so large scripts (e.g.
/// ones embedding a package upgrade) may exceed what a Ledger can sign.
#[derive(Debug, Parser)]
pub struct Execute {
    #[clap(flatten)]
    pub(crate) timelock_account_with_proposal_hash: TimelockAccountWithProposalHash,
    #[clap(flatten)]
    pub(crate) compile_proposal_args: CompileScriptFunction,
    #[clap(flatten)]
    pub(crate) txn_options: TransactionOptions,
}

#[async_trait]
impl CliCommand<TransactionSummary> for Execute {
    fn command_name(&self) -> &'static str {
        "ExecuteTimelock"
    }

    async fn execute(self) -> CliTypedResult<TransactionSummary> {
        let timelock_address = self
            .timelock_account_with_proposal_hash
            .timelock_account
            .timelock_address;
        let proposal_hash = parse_hex_32(
            &self
                .timelock_account_with_proposal_hash
                .proposal_hash,
            "proposal-hash",
        )?;

        // Compile the script and verify it matches the on-chain proposal before paying gas for a
        // transaction that would abort.
        let (bytecode, timelock_transaction) = compile_and_match_execution_hash(
            &self.txn_options,
            self.compile_proposal_args,
            "ExecuteTimelock",
            timelock_address,
            &proposal_hash,
        )
        .await?;

        // Verify the proposal can be executed (not executed/canceled, timelock elapsed).
        let can_be_executed = self
            .txn_options
            .view(timelock_view_function("can_be_executed", vec![
                to_bytes(&timelock_address)?,
                to_bytes(&proposal_hash)?,
            ]))
            .await?[0]
            .as_bool()
            .unwrap_or(false);
        if !can_be_executed {
            let executed = timelock_transaction["executed"].as_bool().unwrap_or(false);
            return Err(CliError::UnexpectedError(if executed {
                "Transaction has already been executed or canceled".to_string()
            } else {
                let parse_u64 = |field| timelock_transaction[field].as_str()?.parse::<u64>().ok();
                match parse_u64("creation_time_secs").zip(parse_u64("num_seconds_execute")) {
                    Some((creation_time_secs, num_seconds_execute)) => format!(
                        "The timelock period has not elapsed yet: the transaction becomes \
                        executable at unix timestamp {}",
                        creation_time_secs + num_seconds_execute
                    ),
                    None => "The timelock period has not elapsed yet".to_string(),
                }
            }));
        }

        // No type or value arguments: passing any would let the executor supply values the
        // execution hash never committed to. The executor signer comes from the transaction sender.
        self.txn_options
            .submit_transaction(TransactionPayload::Script(Script::new(
                bytecode,
                vec![],
                vec![],
            )))
            .await
            .map(|inner| inner.into())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_hex_32_accepts_with_and_without_prefix() {
        let hex32 = "ab".repeat(TIMELOCK_BYTES_LENGTH);
        let without_prefix = parse_hex_32(&hex32, "execution-hash").unwrap();
        let with_prefix = parse_hex_32(&format!("0x{hex32}"), "execution-hash").unwrap();
        assert_eq!(without_prefix, with_prefix);
        assert_eq!(without_prefix.len(), TIMELOCK_BYTES_LENGTH);
    }

    #[test]
    fn parse_hex_32_rejects_short_input() {
        let too_short = "ab".repeat(TIMELOCK_BYTES_LENGTH - 1);
        let err = parse_hex_32(&too_short, "salt").unwrap_err().to_string();
        assert!(err.contains("must be exactly 32 bytes"), "{err}");
    }

    #[test]
    fn parse_hex_32_rejects_long_input() {
        let too_long = "ab".repeat(TIMELOCK_BYTES_LENGTH + 1);
        let err = parse_hex_32(&too_long, "salt").unwrap_err().to_string();
        assert!(err.contains("must be exactly 32 bytes"), "{err}");
    }

    #[test]
    fn parse_hex_32_rejects_non_hex() {
        let bad = "zz".repeat(TIMELOCK_BYTES_LENGTH);
        let err = parse_hex_32(&bad, "proposal-hash")
            .unwrap_err()
            .to_string();
        assert!(err.contains("Invalid hex value"), "{err}");
    }
}
