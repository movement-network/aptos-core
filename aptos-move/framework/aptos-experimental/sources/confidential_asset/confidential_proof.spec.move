/// MSL specs for `aptos_experimental::confidential_proof`.
///
/// **Scope:** this module's `verify_*_proof` functions are *the* boundary between Move-side
/// state verification (Move Prover) and crypto-verifier correctness (Lean). Per the unified
/// verification plan §3, the `verify_withdrawal_proof` / `verify_transfer_proof` /
/// `verify_normalization_proof` / `verify_rotation_proof` bytecode theorems live on the
/// Lean side (`SigmaVerifiers.lean` + the rebuilt L2 EvalEquiv chains in Phase 4).
///
/// At the Move Prover boundary, we declare these verifiers as `pragma opaque`: their inputs
/// are consumed, they abort on invalid proofs, and they return on acceptance. The acceptance
/// semantics (verifier accepts iff the sigma predicate holds on the honest oracle) is carried
/// by the Lean theorems and bound to the VM via the difftest corpus.
///
/// This initial pass declares the opacity explicitly. Fully-expressive `aborts_if` / `ensures`
/// clauses await Phase 4 (Lean verifier proofs) + Phase 5 (composition into entry-point specs).
spec aptos_experimental::confidential_proof {
    spec module {
        pragma verify = true;
        pragma aborts_if_is_strict = false;
    }

    //
    // Abort codes documented in the Move source:
    //   const ESIGMA_PROTOCOL_VERIFY_FAILED: u64 = 1;     → error::invalid_argument(1) = 0x10001 = 65537
    //   const ERANGE_PROOF_VERIFICATION_FAILED: u64 = 2;  → error::invalid_argument(2) = 0x10002 = 65538
    //

    //
    // Verification entry points — opaque crypto boundary + abort-code discipline
    //
    // Each verify_*_proof either succeeds (the caller continues) or aborts with one of the
    // two error codes above. The acceptance semantics (proof verifies iff sigma predicate
    // holds on honest oracle) is pinned by the Lean theorem for the respective bytecode
    // (Phase 4). MSL treats the predicate as opaque; but the aborts_with discipline pins
    // the failure-mode contract.
    //

    spec verify_withdrawal_proof {
        pragma opaque;
        aborts_with 65537, 65538;
    }

    spec verify_transfer_proof {
        pragma opaque;
        aborts_with 65537, 65538;
    }

    spec verify_normalization_proof {
        pragma opaque;
        aborts_with 65537, 65538;
    }

    spec verify_rotation_proof {
        pragma opaque;
        aborts_with 65537, 65538;
    }

    //
    // Deserialization — Option-valued, never abort
    //

    spec deserialize_withdrawal_proof {
        pragma opaque;
        aborts_if false;
    }

    spec deserialize_transfer_proof {
        pragma opaque;
        aborts_if false;
    }

    spec deserialize_normalization_proof {
        pragma opaque;
        aborts_if false;
    }
}
