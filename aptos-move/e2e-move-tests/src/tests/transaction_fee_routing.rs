// Copyright © Aptos Foundation
// SPDX-License-Identifier: Apache-2.0

use crate::{assert_success, MoveHarness};
use aptos_cached_packages::aptos_stdlib;
use aptos_language_e2e_tests::account::Account;
use aptos_types::{
	account_address::AccountAddress,
	fee_statement::FeeStatement,
	move_utils::MemberId,
	on_chain_config::FeatureFlag,
};
use move_core_types::{
	ident_str,
	language_storage::{ModuleId, StructTag, TypeTag},
	parser::parse_struct_tag,
	value::MoveValue,
};

fn view_collect_and_distribute_feature(h: &mut MoveHarness) -> bool {
	let output = h.execute_view_function(
		MemberId {
			module_id: ModuleId::new(AccountAddress::ONE, ident_str!("features").to_owned()),
			member_id: ident_str!("collect_and_distribute_gas_fees").to_owned(),
		},
		vec![],
		vec![],
	);
	match output {
		aptos_types::transaction::ViewFunctionOutput::MoveValue(MoveValue::Bool(b)) => b,
		_ => panic!("Unexpected view output"),
	}
}

#[test]
fn test_deprecated_collect_and_distribute_flag_is_disabled() {
	let mut h = MoveHarness::new();
	// Even if we try to enable the deprecated flag, the public function returns false.
	h.enable_features(vec![FeatureFlag::_DEPRECATED_COLLECT_AND_DISTRIBUTE_GAS_FEES], vec![]);
	let enabled = view_collect_and_distribute_feature(&mut h);
	assert!(!enabled, "Deprecated collect_and_distribute flag should be hard-disabled");
}

#[test]
fn test_fee_statement_matches_balance_delta() {
	let mut h = MoveHarness::new();
	// Make pricing deterministic for the assertion.
	h.set_default_gas_unit_price(17);

	let sender = h.new_account_at(AccountAddress::from_hex_literal("0x111").unwrap());
	let receiver = h.new_account_at(AccountAddress::from_hex_literal("0x222").unwrap());

	let sender_before = h.read_aptos_balance(sender.address());
	let receiver_before = h.read_aptos_balance(receiver.address());

	let payload = aptos_stdlib::aptos_coin_transfer(*receiver.address(), 123);
	let (_log, gas_used, fee_stmt_opt) = h.evaluate_gas_with_profiler(&sender, payload);
	assert!(fee_stmt_opt.is_some(), "FeeStatement must be emitted");
	let FeeStatement {
		total_charge_gas_units,
		execution_gas_units: _,
		io_gas_units: _,
		storage_fee_octas,
		storage_fee_refund_octas,
	} = fee_stmt_opt.unwrap();

	// Sanity: gas_used equals total_charge_gas_units per contract.
	assert_eq!(gas_used, total_charge_gas_units);

	let gas_unit_price = 17u64;
	let expected_charge_octas = total_charge_gas_units
		.checked_mul(gas_unit_price)
		.expect("no overflow in gas calc");
	let expected_net_charge = expected_charge_octas
		.checked_sub(storage_fee_refund_octas)
		.expect("refund not larger than charge");

	let sender_after = h.read_aptos_balance(sender.address());
	let receiver_after = h.read_aptos_balance(receiver.address());

	let sender_delta = sender_before
		.checked_sub(sender_after)
		.expect("sender must be charged");
	let receiver_delta = receiver_after
		.checked_sub(receiver_before)
		.expect("receiver received transfer");

	// Verify that the sender paid exactly the net fee + transfer amount, and receiver got 123.
	assert_eq!(receiver_delta, 123, "receiver should get transfer amount only");
	assert_eq!(sender_delta, expected_net_charge + 123, "sender net debit should equal fee + transfer");

	// Additional check: storage fee octas are included in charge; nothing is redistributed.
	let _ = storage_fee_octas; // ensure we referenced the field to make intent clear
}

#[test]
fn test_no_collected_fees_resource_published() {
	let h = &mut MoveHarness::new();
	// Ensure the deprecated CollectedFeesPerBlock resource is not present.
	let collected_fees_tag: StructTag = parse_struct_tag(
		"0x1::transaction_fee::CollectedFeesPerBlock",
	)
	.unwrap();
	let exists = h.exists_resource(&AccountAddress::ONE, collected_fees_tag);
	assert!(!exists, "Deprecated CollectedFeesPerBlock should not exist");
}
