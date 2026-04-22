/// MSL spec for `aptos_experimental::confidential_gas_e2e_helpers`.
///
/// **Scope:** this module is `#[test_only]`; its functions bundle `confidential_proof::prove_*`
/// output into BCS byte payloads for framework entry-point testing. Production code paths never
/// call these helpers, so their MSL specs are minimal — each function is declared
/// `pragma opaque` at the module boundary. The `pragma verify = false` disables verification
/// entirely for this module.
///
/// If a regression ever calls these helpers from production, the Move Prover will flag the
/// cross-module call at the first site that imports this module's spec. At that point upgrade
/// the opaque declarations to real `aborts_if` / `ensures` clauses.
spec aptos_experimental::confidential_gas_e2e_helpers {
    spec module {
        pragma verify = false;  // test-only module; not verified in CI
    }

    spec pack_withdraw_to_proof {
        pragma opaque;
    }

    spec pack_confidential_transfer_proof_simple {
        pragma opaque;
    }

    spec pack_confidential_transfer_proof_with_auditors {
        pragma opaque;
    }

    spec pack_rotate_encryption_key_proof {
        pragma opaque;
    }

    spec pack_normalization_proof {
        pragma opaque;
    }
}
