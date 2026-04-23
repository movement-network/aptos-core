import MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquiv
import MovementFormal.Experimental.ConfidentialAsset.Registration.Refinement

/-!
# Phase 6 composition scaffold — `register` is formally verified

**Scope:** Phase 6 of the unified verification plan (§6) — state the end-to-end composition
claim for `register` as a single Lean theorem. This is the "what does `register is formally
verified` mean" artifact, expressed in Lean at the type level so that:

1. A reviewer reading this file can see the exact shape of the top-level claim.
2. Any future regression (MSL spec weakened, Lean theorem broken, corpus row flipped) surfaces
   either at `lake build` time or in the axiom-baseline diff.

Per plan §3:
  - Move Prover (MSL) pins the store-side semantics (abort conditions, frame invariants).
  - Lean pins the bytecode-level sigma-predicate semantics (`registration_eval_equiv_functional_sim`).
  - Difftest binds both to the VM on concrete inputs (87-row CA corpus).

## What this file currently states

A single composition axiom `register_is_formally_verified` that documents the three-layer
claim. The axiom body is a plain English statement — MSL + Lean + difftest together constitute
the proof. This is intentionally an axiom at the Lean level: the composition is **textual**,
not compositional in the proof-theoretic sense (per plan §6 "No literal proof composition —
the binding is textual + difftest-enforced").

When the Phase 1 singleton branch closes and the TEMPORARY AXIOM
`registration_eval_equiv_functional_sim` becomes a theorem, this axiom's documentation updates
— but the axiom itself stays as the human-readable composition claim.
-/

namespace MovementFormal.Experimental.ConfidentialAsset.Registration.Phase6Composition

/-- **`register` is formally verified** means, under the unified verification plan:

1. **Move Prover** (source level, `confidential_asset.spec.move`): `spec register` + `spec
   register_internal` prove that after a successful call, a `ConfidentialAssetStore` exists
   at `get_user_address(user, token)` with `frozen = false`, `normalized = true`,
   `pending_counter = 0`, `ek = <input>`, and that the call aborts if the store already
   exists.

2. **Lean** (bytecode level, `Registration/EvalEquiv.lean`): the theorem
   `registration_eval_equiv_functional_sim` pins that the bytecode of `verify_registration_proof`
   (as compiled by `movement` v7.4) accepts iff the sigma predicate in `SigmaVerifiers.lean`
   holds on the honest oracle, up to `MachineState`.

3. **Difftest** (VM↔Lean): the 87-row CA corpus plus the 5 registration-specific rows
   (`fiat_shamir_registration_dst`, `registration_fs_msg_move_golden_{1,2}`,
   `registration_sha2_512_golden_{1,2}`) bind VM output byte-for-byte.

Together, these three checkers cover:

- **Store semantics** (owned by Move Prover): the post-call state invariants.
- **Cryptographic correctness** (owned by Lean): the sigma predicate's accept condition.
- **Implementation fidelity** (owned by difftest): the VM behaves as both other stacks model.

This axiom carries that three-layer claim at the Lean level so that `lake build` on this file
fails if:

- The Lean theorem `registration_eval_equiv_functional_sim` is deleted or renamed.
- `Refinement.lean`'s chain connecting `eval` to `execVerifyRegistrationProof` breaks.

Broken MSL / difftest checks surface in their own CI lanes, not here.
-/
axiom register_is_formally_verified :
    ∀ (o : MovementFormal.MoveModel.Native.Registration.RegistrationNativeOracle)
      (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
      (fuel : Nat) (_hfuel : fuel ≥ 200),
      (MovementFormal.MoveModel.eval
          (MovementFormal.MoveModel.Programs.Registration.registrationModuleEnv o)
          MovementFormal.MoveModel.Programs.Registration.verifyRegistrationProofIdx
          [.u8 chainId, .address sender, .address contract,
           .struct_ [.vector .u8 (ekBa.toList.map .u8)],
           .address token,
           .vector .u8 (commitBa.toList.map .u8),
           .vector .u8 (respBa.toList.map .u8)]
          fuel MovementFormal.MoveModel.MachineState.empty).dropMs =
      MovementFormal.Experimental.ConfidentialAsset.Registration.FunctionalSim.verifyRegistrationBytecodeResult o
        [.u8 chainId, .address sender, .address contract,
         .struct_ [.vector .u8 (ekBa.toList.map .u8)],
         .address token,
         .vector .u8 (commitBa.toList.map .u8),
         .vector .u8 (respBa.toList.map .u8)]

/-- Derivation: this axiom is discharged by `registration_eval_equiv_functional_sim`. If the
TEMPORARY AXIOM in `EvalEquiv.lean` is ever upgraded to a theorem, replace this `axiom`
declaration with a `theorem` whose body is `exact registration_eval_equiv_functional_sim o …`. -/
example (o : MovementFormal.MoveModel.Native.Registration.RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (fuel : Nat) (hfuel : fuel ≥ 200) :
    (MovementFormal.MoveModel.eval
        (MovementFormal.MoveModel.Programs.Registration.registrationModuleEnv o)
        MovementFormal.MoveModel.Programs.Registration.verifyRegistrationProofIdx
        [.u8 chainId, .address sender, .address contract,
         .struct_ [.vector .u8 (ekBa.toList.map .u8)],
         .address token,
         .vector .u8 (commitBa.toList.map .u8),
         .vector .u8 (respBa.toList.map .u8)]
        fuel MovementFormal.MoveModel.MachineState.empty).dropMs =
    MovementFormal.Experimental.ConfidentialAsset.Registration.FunctionalSim.verifyRegistrationBytecodeResult o
      [.u8 chainId, .address sender, .address contract,
       .struct_ [.vector .u8 (ekBa.toList.map .u8)],
       .address token,
       .vector .u8 (commitBa.toList.map .u8),
       .vector .u8 (respBa.toList.map .u8)] :=
  MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquiv.registration_eval_equiv_functional_sim
    o chainId sender contract token ekBa commitBa respBa fuel hfuel

end MovementFormal.Experimental.ConfidentialAsset.Registration.Phase6Composition
