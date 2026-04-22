// Copyright © Aptos Foundation
// SPDX-License-Identifier: Apache-2.0

use super::{TransactionExecutable, TransactionExecutableRef};
use crate::transaction::EntryFunction;
use move_core_types::account_address::AccountAddress;
use serde::{Deserialize, Serialize};

/// A timelock transaction that allows an executor of a timelock account to execute a
/// pre-approved transaction as the timelock account after the timelock delay has elapsed.
#[derive(Clone, Debug, Hash, Eq, PartialEq, Serialize, Deserialize)]
pub struct Timelock {
    pub timelock_address: AccountAddress,

    /// Salt used together with the payload to derive the transaction hash.
    /// The table key (hash) is `keccak256(bcs(payload) || salt)`.
    pub salt: Vec<u8>,

    /// Transaction payload. When `None` the VM fetches the payload from on-chain storage
    /// using `hash` as the table key. The executor must have computed
    /// `hash = keccak256(bcs(payload) || salt)` off-chain in that case.
    pub transaction_payload: Option<TimelockTransactionPayload>,

    /// Transaction table key: `keccak256(bcs(payload) || salt)`.
    /// Required when `transaction_payload` is `None` so the VM can look up the stored
    /// payload via `timelock::get_transaction(timelock_address, hash)`.
    /// When `transaction_payload` is `Some`, the VM derives the hash itself and this
    /// field is ignored.
    pub hash: Vec<u8>,
}

#[derive(Clone, Debug, Hash, Eq, PartialEq, Serialize, Deserialize)]
pub enum TimelockTransactionPayload {
    EntryFunction(EntryFunction),
}

impl Timelock {
    pub fn as_transaction_executable(&self) -> TransactionExecutable {
        match &self.transaction_payload {
            Some(TimelockTransactionPayload::EntryFunction(entry)) => {
                TransactionExecutable::EntryFunction(entry.clone())
            },
            None => TransactionExecutable::Empty,
        }
    }

    pub fn as_transaction_executable_ref(&self) -> TransactionExecutableRef {
        match &self.transaction_payload {
            Some(TimelockTransactionPayload::EntryFunction(entry)) => {
                TransactionExecutableRef::EntryFunction(entry)
            },
            None => TransactionExecutableRef::Empty,
        }
    }
}
