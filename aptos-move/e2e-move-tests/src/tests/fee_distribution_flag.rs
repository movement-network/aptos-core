// Copyright © Aptos Foundation
// SPDX-License-Identifier: Apache-2.0

use crate::MoveHarness;
use aptos_types::{
	account_address::AccountAddress,
	move_utils::MemberId,
	on_chain_config::FeatureFlag,
};
use move_core_types::{ident_str, language_storage::ModuleId};

fn view_bool(h: &mut MoveHarness, module: &str, func: &str) -> bool {
	let out = h.execute_view_function(
		MemberId {
			module_id: ModuleId::new(AccountAddress::ONE, ident_str!(module).to_owned()),
			member_id: ident_str!(func).to_owned(),
		},
		vec![],
		vec![],
	);
	match out {
		aptos_types::transaction::ViewFunctionOutput::MoveValue(move_core_types::value::MoveValue::Bool(b)) => b,
		_ => panic!("unexpected output"),
	}
}

#[test]
fn test_enable_fee_distribution_flags() {
	let mut h = MoveHarness::new();
	// Enable fee distribution feature flags; leave them off by default otherwise.
	h.enable_features(
		vec![
			FeatureFlag::CALCULATE_TRANSACTION_FEE_FOR_DISTRIBUTION,
			FeatureFlag::DISTRIBUTE_TRANSACTION_FEE,
		],
		vec![],
	);
	// Verify via Move features view functions
	assert!(view_bool(&mut h, "features", "is_calculate_transaction_fee_for_distribution_enabled"));
	assert!(view_bool(&mut h, "features", "is_distribute_transaction_fee_enabled"));
}
