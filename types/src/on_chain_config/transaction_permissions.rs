// Copyright © Aptos Foundation
// SPDX-License-Identifier: Apache-2.0

use crate::on_chain_config::OnChainConfig;
use move_core_types::account_address::AccountAddress;
use serde::{Deserialize, Serialize};

/// The kind of a transaction as classified by the transaction permission
/// table. Values must match the `KIND_*` constants in
/// `0x1::transaction_permissions`.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
#[repr(u8)]
pub enum TransactionPermissionKind {
    Deploy = 0,
    Upgrade = 1,
    Script = 2,
    Other = 3,
}

/// Mirror of `0x1::transaction_permissions::Rule`.
#[derive(Clone, Debug, Deserialize, PartialEq, Eq, Serialize)]
pub struct TransactionPermissionRule {
    /// `None` matches all senders.
    pub sender: Option<AccountAddress>,
    pub kind: u8,
    pub allow: bool,
}

/// Mirror of `0x1::transaction_permissions::TransactionPermissions`: an
/// ordered rule table evaluated first-match-wins; no match means allow.
#[derive(Clone, Debug, Deserialize, PartialEq, Eq, Serialize)]
pub struct TransactionPermissions {
    pub rules: Vec<TransactionPermissionRule>,
}

impl TransactionPermissions {
    /// The verdict of the first rule matching `sender` and `kind`, if any.
    pub fn verdict(&self, sender: AccountAddress, kind: TransactionPermissionKind) -> Option<bool> {
        self.rules
            .iter()
            .find(|rule| rule.kind == kind as u8 && rule.sender.map_or(true, |addr| addr == sender))
            .map(|rule| rule.allow)
    }

    pub fn is_allowed(&self, sender: AccountAddress, kind: TransactionPermissionKind) -> bool {
        self.verdict(sender, kind).unwrap_or(true)
    }
}

impl OnChainConfig for TransactionPermissions {
    const MODULE_IDENTIFIER: &'static str = "transaction_permissions";
    const TYPE_IDENTIFIER: &'static str = "TransactionPermissions";
}

#[cfg(test)]
mod tests {
    use super::*;

    fn addr(n: u8) -> AccountAddress {
        let mut bytes = [0u8; AccountAddress::LENGTH];
        bytes[AccountAddress::LENGTH - 1] = n;
        // Avoid the special address range 0x0..0xf.
        bytes[0] = 0xAB;
        AccountAddress::new(bytes)
    }

    fn rule(
        sender: Option<AccountAddress>,
        kind: TransactionPermissionKind,
        allow: bool,
    ) -> TransactionPermissionRule {
        TransactionPermissionRule {
            sender,
            kind: kind as u8,
            allow,
        }
    }

    #[test]
    fn empty_table_allows() {
        let perms = TransactionPermissions { rules: vec![] };
        assert_eq!(
            perms.verdict(addr(1), TransactionPermissionKind::Script),
            None
        );
        assert!(perms.is_allowed(addr(1), TransactionPermissionKind::Script));
    }

    #[test]
    fn first_match_wins() {
        let perms = TransactionPermissions {
            rules: vec![
                rule(Some(addr(1)), TransactionPermissionKind::Deploy, true),
                rule(None, TransactionPermissionKind::Deploy, false),
            ],
        };
        assert!(perms.is_allowed(addr(1), TransactionPermissionKind::Deploy));
        assert!(!perms.is_allowed(addr(2), TransactionPermissionKind::Deploy));
        // Other kinds fall through to the default.
        assert!(perms.is_allowed(addr(2), TransactionPermissionKind::Upgrade));
    }

    #[test]
    fn wildcard_matches_all() {
        let perms = TransactionPermissions {
            rules: vec![rule(None, TransactionPermissionKind::Script, false)],
        };
        assert!(!perms.is_allowed(addr(1), TransactionPermissionKind::Script));
        assert!(!perms.is_allowed(addr(2), TransactionPermissionKind::Script));
        assert!(perms.is_allowed(addr(2), TransactionPermissionKind::Other));
    }

    #[test]
    fn bcs_layout_matches_move() {
        // Move serializes Rule { sender: Option<address>, kind: u8, allow: bool };
        // a wildcard rule is [0x00 (none), kind, allow].
        let wildcard = TransactionPermissionRule {
            sender: None,
            kind: 2,
            allow: false,
        };
        assert_eq!(bcs::to_bytes(&wildcard).unwrap(), vec![0x00, 0x02, 0x00]);

        let specific = TransactionPermissionRule {
            sender: Some(addr(1)),
            kind: 0,
            allow: true,
        };
        let mut expected = vec![0x01];
        expected.extend_from_slice(addr(1).as_ref());
        expected.extend_from_slice(&[0x00, 0x01]);
        assert_eq!(bcs::to_bytes(&specific).unwrap(), expected);
    }
}
