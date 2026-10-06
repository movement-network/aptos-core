// Copyright © Aptos Foundation
// SPDX-License-Identifier: Apache-2.0

use crate::on_chain_config::OnChainConfig;
use move_core_types::{account_address::AccountAddress, language_storage::ModuleId};
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

/// Mirror of `0x1::transaction_permissions::ModulePattern`.
#[derive(Clone, Debug, Deserialize, PartialEq, Eq, Serialize)]
pub struct ModulePattern {
    pub addr: AccountAddress,
    /// `None` matches every module at `addr`.
    pub name: Option<String>,
}

impl ModulePattern {
    pub fn matches(&self, module_id: &ModuleId) -> bool {
        self.addr == *module_id.address()
            && self
                .name
                .as_ref()
                .map_or(true, |name| name.as_str() == module_id.name().as_str())
    }
}

/// Mirror of `0x1::transaction_permissions::Rule`.
#[derive(Clone, Debug, Deserialize, PartialEq, Eq, Serialize)]
pub struct TransactionPermissionRule {
    /// `None` matches all senders.
    pub sender: Option<AccountAddress>,
    pub kind: u8,
    /// `None`: a transaction-level rule. `Some`: the rule applies per module
    /// (published modules for deploy/upgrade kinds, loaded modules for
    /// script/other kinds).
    pub module: Option<ModulePattern>,
    pub allow: bool,
}

impl TransactionPermissionRule {
    fn matches_sender_and_kind(
        &self,
        sender: AccountAddress,
        kind: TransactionPermissionKind,
    ) -> bool {
        self.kind == kind as u8 && self.sender.map_or(true, |addr| addr == sender)
    }
}

/// Mirror of `0x1::transaction_permissions::TransactionPermissions`: an
/// ordered rule table evaluated first-match-wins; no match means allow.
#[derive(Clone, Debug, Deserialize, PartialEq, Eq, Serialize)]
pub struct TransactionPermissions {
    pub rules: Vec<TransactionPermissionRule>,
}

impl TransactionPermissions {
    /// The transaction-level verdict: the first rule without a module pattern
    /// matching `sender` and `kind`, if any.
    pub fn tx_verdict(
        &self,
        sender: AccountAddress,
        kind: TransactionPermissionKind,
    ) -> Option<bool> {
        self.rules
            .iter()
            .find(|rule| rule.module.is_none() && rule.matches_sender_and_kind(sender, kind))
            .map(|rule| rule.allow)
    }

    pub fn is_tx_allowed(&self, sender: AccountAddress, kind: TransactionPermissionKind) -> bool {
        self.tx_verdict(sender, kind).unwrap_or(true)
    }

    /// The module-access verdict applied while a transaction of `kind` runs:
    /// the first rule whose module pattern matches `module_id` and whose
    /// sender and kind match.
    pub fn module_access_verdict(
        &self,
        sender: AccountAddress,
        kind: TransactionPermissionKind,
        module_id: &ModuleId,
    ) -> Option<bool> {
        self.rules
            .iter()
            .find(|rule| {
                rule.matches_sender_and_kind(sender, kind)
                    && rule
                        .module
                        .as_ref()
                        .is_some_and(|pattern| pattern.matches(module_id))
            })
            .map(|rule| rule.allow)
    }

    pub fn is_module_access_allowed(
        &self,
        sender: AccountAddress,
        kind: TransactionPermissionKind,
        module_id: &ModuleId,
    ) -> bool {
        self.module_access_verdict(sender, kind, module_id)
            .unwrap_or(true)
    }

    /// The publish verdict for one module of a bundle: the first rule
    /// matching `sender` and `kind` whose module pattern matches `module_id`
    /// or is absent (a transaction-level deploy/upgrade rule matches any
    /// published module).
    pub fn publish_verdict(
        &self,
        sender: AccountAddress,
        kind: TransactionPermissionKind,
        module_id: &ModuleId,
    ) -> Option<bool> {
        self.rules
            .iter()
            .find(|rule| {
                rule.matches_sender_and_kind(sender, kind)
                    && rule
                        .module
                        .as_ref()
                        .map_or(true, |pattern| pattern.matches(module_id))
            })
            .map(|rule| rule.allow)
    }

    pub fn is_publish_allowed(
        &self,
        sender: AccountAddress,
        kind: TransactionPermissionKind,
        module_id: &ModuleId,
    ) -> bool {
        self.publish_verdict(sender, kind, module_id)
            .unwrap_or(true)
    }

    /// Whether any rule carries a module pattern for the given kind; when
    /// false, per-module access checks can be skipped entirely.
    pub fn has_module_rules(&self, kind: TransactionPermissionKind) -> bool {
        self.rules
            .iter()
            .any(|rule| rule.kind == kind as u8 && rule.module.is_some())
    }
}

impl OnChainConfig for TransactionPermissions {
    const MODULE_IDENTIFIER: &'static str = "transaction_permissions";
    const TYPE_IDENTIFIER: &'static str = "TransactionPermissions";
}

#[cfg(test)]
mod tests {
    use super::*;
    use move_core_types::identifier::Identifier;

    fn addr(n: u8) -> AccountAddress {
        let mut bytes = [0u8; AccountAddress::LENGTH];
        bytes[AccountAddress::LENGTH - 1] = n;
        // Avoid the special address range 0x0..0xf.
        bytes[0] = 0xAB;
        AccountAddress::new(bytes)
    }

    fn module(a: AccountAddress, name: &str) -> ModuleId {
        ModuleId::new(a, Identifier::new(name).unwrap())
    }

    fn rule(
        sender: Option<AccountAddress>,
        kind: TransactionPermissionKind,
        module: Option<ModulePattern>,
        allow: bool,
    ) -> TransactionPermissionRule {
        TransactionPermissionRule {
            sender,
            kind: kind as u8,
            module,
            allow,
        }
    }

    #[test]
    fn empty_table_allows() {
        let perms = TransactionPermissions { rules: vec![] };
        assert_eq!(
            perms.tx_verdict(addr(1), TransactionPermissionKind::Script),
            None
        );
        assert!(perms.is_tx_allowed(addr(1), TransactionPermissionKind::Script));
        assert!(perms.is_module_access_allowed(
            addr(1),
            TransactionPermissionKind::Other,
            &module(addr(2), "m"),
        ));
    }

    #[test]
    fn first_match_wins() {
        let perms = TransactionPermissions {
            rules: vec![
                rule(Some(addr(1)), TransactionPermissionKind::Deploy, None, true),
                rule(None, TransactionPermissionKind::Deploy, None, false),
            ],
        };
        assert!(perms.is_tx_allowed(addr(1), TransactionPermissionKind::Deploy));
        assert!(!perms.is_tx_allowed(addr(2), TransactionPermissionKind::Deploy));
        // Other kinds fall through to the default.
        assert!(perms.is_tx_allowed(addr(2), TransactionPermissionKind::Upgrade));
    }

    #[test]
    fn wildcard_matches_all() {
        let perms = TransactionPermissions {
            rules: vec![rule(None, TransactionPermissionKind::Script, None, false)],
        };
        assert!(!perms.is_tx_allowed(addr(1), TransactionPermissionKind::Script));
        assert!(!perms.is_tx_allowed(addr(2), TransactionPermissionKind::Script));
        assert!(perms.is_tx_allowed(addr(2), TransactionPermissionKind::Other));
    }

    #[test]
    fn module_rules_do_not_affect_tx_verdict() {
        let pattern = ModulePattern {
            addr: addr(9),
            name: Some("dex".to_string()),
        };
        let perms = TransactionPermissions {
            rules: vec![rule(
                None,
                TransactionPermissionKind::Other,
                Some(pattern),
                false,
            )],
        };
        assert_eq!(
            perms.tx_verdict(addr(1), TransactionPermissionKind::Other),
            None
        );
        assert!(!perms.is_module_access_allowed(
            addr(1),
            TransactionPermissionKind::Other,
            &module(addr(9), "dex"),
        ));
        // Different module name and different kind are unaffected.
        assert!(perms.is_module_access_allowed(
            addr(1),
            TransactionPermissionKind::Other,
            &module(addr(9), "amm"),
        ));
        assert!(perms.is_module_access_allowed(
            addr(1),
            TransactionPermissionKind::Script,
            &module(addr(9), "dex"),
        ));
        assert!(perms.has_module_rules(TransactionPermissionKind::Other));
        assert!(!perms.has_module_rules(TransactionPermissionKind::Script));
    }

    #[test]
    fn address_wide_pattern() {
        let pattern = ModulePattern {
            addr: addr(9),
            name: None,
        };
        let perms = TransactionPermissions {
            rules: vec![rule(
                Some(addr(1)),
                TransactionPermissionKind::Script,
                Some(pattern),
                false,
            )],
        };
        assert!(!perms.is_module_access_allowed(
            addr(1),
            TransactionPermissionKind::Script,
            &module(addr(9), "anything"),
        ));
        assert!(perms.is_module_access_allowed(
            addr(2),
            TransactionPermissionKind::Script,
            &module(addr(9), "anything"),
        ));
    }

    #[test]
    fn publish_verdict_mixes_module_and_tx_rules() {
        // Only module `m` at addr(9) may be deployed; everything else denied.
        let perms = TransactionPermissions {
            rules: vec![
                rule(
                    None,
                    TransactionPermissionKind::Deploy,
                    Some(ModulePattern {
                        addr: addr(9),
                        name: Some("m".to_string()),
                    }),
                    true,
                ),
                rule(None, TransactionPermissionKind::Deploy, None, false),
            ],
        };
        assert!(perms.is_publish_allowed(
            addr(1),
            TransactionPermissionKind::Deploy,
            &module(addr(9), "m"),
        ));
        assert!(!perms.is_publish_allowed(
            addr(1),
            TransactionPermissionKind::Deploy,
            &module(addr(9), "n"),
        ));
        assert!(!perms.is_publish_allowed(
            addr(1),
            TransactionPermissionKind::Deploy,
            &module(addr(2), "m"),
        ));
    }

    #[test]
    fn bcs_layout_matches_move() {
        // Move serializes Rule { sender: Option<address>, kind: u8,
        // module: Option<ModulePattern>, allow: bool }; a wildcard tx-level
        // rule is [0x00 (none), kind, 0x00 (none), allow].
        let wildcard = rule(None, TransactionPermissionKind::Script, None, false);
        assert_eq!(bcs::to_bytes(&wildcard).unwrap(), vec![
            0x00, 0x02, 0x00, 0x00
        ]);

        // A module rule: Move's String is a struct wrapping vector<u8>, so it
        // serializes as a ULEB length plus UTF-8 bytes, same as Rust String.
        let with_module = rule(
            Some(addr(1)),
            TransactionPermissionKind::Deploy,
            Some(ModulePattern {
                addr: addr(2),
                name: Some("dex".to_string()),
            }),
            true,
        );
        let mut expected = vec![0x01];
        expected.extend_from_slice(addr(1).as_ref());
        expected.push(0x00); // kind
        expected.push(0x01); // module: some
        expected.extend_from_slice(addr(2).as_ref());
        expected.extend_from_slice(&[0x01, 0x03]); // name: some, len 3
        expected.extend_from_slice(b"dex");
        expected.push(0x01); // allow
        assert_eq!(bcs::to_bytes(&with_module).unwrap(), expected);
    }
}
