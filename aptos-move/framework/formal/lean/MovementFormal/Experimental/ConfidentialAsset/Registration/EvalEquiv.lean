import MovementFormal.Experimental.ConfidentialAsset.Registration.FunctionalSim
import MovementFormal.MoveModel.ExecResultDropMs
import MovementFormal.MoveModel.Programs.Registration

/-!
# Bytecode eval ≡ functional simulation (L2 ≡ L1.5) — axiom-only stub

**Phase 1 day-one commit of the Lean architectural revision.**

The previous proof of this file (the ~8,600-line `EvalEquiv/Part1.lean` … `Part4.lean` chain)
has been deleted. It is being rebuilt on the new architecture described in
[`CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md`](../../../../../CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md) §4:
symbolic state, `@[irreducible]` frame definitions, `Array.get?` in statements, and the
per-instruction-class step lemmas now in `MovementFormal.MoveModel.StepLemmas.*`.

## What this stub declares

- `registration_eval_equiv_functional_sim` — the only name `Refinement.lean` applies as a term.
  Exported here as a **TEMPORARY AXIOM**, reproved in the Phase 1 completion commit.

## What this stub does *not* declare

The old `Part4.lean` exported two additional public theorems that were internal machinery for
the old chain-based proof: `registration_eval_equiv_singleton_tail` and
`registration_eval_equiv_singleton_tail_of_schnorr_hmac_bundle`. Nothing outside the deleted
`EvalEquiv/Part*.lean` applies them as terms (grep of Refinement/EndToEnd/BytecodeDifftestBridge
shows only doc-comment mentions). The rebuilt proof is free to introduce fresh internal lemmas
with different names and shapes, so these two names do not need stubs here.

Historical copies of the old `Part*.lean` files are available via git history; see the PR
landing this day-one commit for the exact SHA.
-/

namespace MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquiv

open MovementFormal.MoveModel
open MovementFormal.MoveModel.Native.Registration
open MovementFormal.MoveModel.Programs.Registration
open MovementFormal.Experimental.ConfidentialAsset.Registration.FunctionalSim

/-- TEMPORARY AXIOM: reproved in the Phase 1 completion commit (rebuild on new architecture). -/
axiom registration_eval_equiv_functional_sim
    (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (fuel : Nat) (hfuel : fuel ≥ 200) :
    (eval (registrationModuleEnv o) verifyRegistrationProofIdx
        [.u8 chainId, .address sender, .address contract,
         .struct_ [.vector .u8 (ekBa.toList.map .u8)],
         .address token,
         .vector .u8 (commitBa.toList.map .u8),
         .vector .u8 (respBa.toList.map .u8)]
        fuel MachineState.empty).dropMs =
    verifyRegistrationBytecodeResult o
        [.u8 chainId, .address sender, .address contract,
         .struct_ [.vector .u8 (ekBa.toList.map .u8)],
         .address token,
         .vector .u8 (commitBa.toList.map .u8),
         .vector .u8 (respBa.toList.map .u8)]

end MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquiv
