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

    /// Salt that uniquely identifies this transaction within the timelock account.
    pub salt: Vec<u8>,

    // Transaction payload is optional if already stored on chain.
    pub transaction_payload: Option<TimelockTransactionPayload>,
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
