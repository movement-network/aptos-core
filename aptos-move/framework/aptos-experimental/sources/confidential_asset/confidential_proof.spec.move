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
    // Verification entry points — opaque crypto boundary
    //

    spec verify_withdrawal_proof {
        pragma opaque;
        // Aborts on proof rejection; proof acceptance semantics are pinned by the Lean
        // theorem for the bytecode of `verify_withdrawal_proof` (Phase 4).
    }

    spec verify_transfer_proof {
        pragma opaque;
        // See `verify_withdrawal_proof` note.
    }

    spec verify_normalization_proof {
        pragma opaque;
        // See `verify_withdrawal_proof` note.
    }

    spec verify_rotation_proof {
        pragma opaque;
        // See `verify_withdrawal_proof` note.
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
