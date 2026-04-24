import MovementFormal.MoveModel.StepLemmas.Basic
import MovementFormal.MoveModel.StepLemmas.Locals
import MovementFormal.MoveModel.StepLemmas.Calls
import MovementFormal.MoveModel.StepLemmas.Run
import MovementFormal.MoveModel.ExecResultDropMs
import MovementFormal.Experimental.ConfidentialAsset.Registration.FunctionalSim
import MovementFormal.Experimental.ConfidentialAsset.Registration.BytecodeLemmas
import MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquivRebuild

/-!
# Singleton Branch Proofs for Registration

This file demonstrates the singleton branch proof approach and documents the elaboration blocker.

## Elaboration Blocker Encountered

Attempting to prove PC 0-2 composition hits the "Expected type must not contain free variables"
error when constructing frames with `.set` operations on array bounds. This is the same
architectural issue documented in SINGLETON_BRANCH_ROADMAP.md.

## Current Approach

Since direct proof hits elaboration limits, the recommended path is:
1. Use bundled-snapshot approach for container-store threading
2. Define `@[irreducible]` intermediate state constructors
3. Expose only necessary projections as `@[simp]` lemmas
4. Avoid inline `.set` with dependent bounds in theorem statements

## Proof Sketch for PC 0-2

The intended composition is:
- PC 0: `moveLoc 5` pushes commitment bytes onto stack
- PC 1: `call 0` invokes `newCompressedPointFromBytes` native
- PC 2: `stLoc 7` stores result in local 7

Each step is provable individually using StepLemmas, but chaining them requires
careful frame management to avoid the elaboration blocker.

## Next Steps

1. Implement `@[irreducible]` frame constructors for PC 0, 1, 2 intermediate states
2. Prove projection lemmas showing field equalities
3. Compose using `run_succ_ok_of_step` without inline frame construction
4. Extend pattern through remaining PCs

See EvalEquivRebuild.lean for axiomatized helpers that this file aims to prove.
-/

namespace MovementFormal.Experimental.ConfidentialAsset.Registration.SingletonBranchProofs

open MovementFormal.MoveModel
open MovementFormal.MoveModel.StepLemmas
open MovementFormal.MoveModel.Native.Registration
open MovementFormal.MoveModel.Programs.Registration
open MovementFormal.Experimental.ConfidentialAsset.Registration.FunctionalSim
open MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquivRebuild
open BytecodeLemmas

/-! ## Example: Proving PC 0 step individually

This demonstrates that individual PC steps are provable. The challenge is composing them. -/

-- Frame after PC 0 - demonstrating the elaboration blocker even in irreducible defs
-- The `.set` operation with dependent bound proof causes "Expected type must not contain free variables"
-- This is WHY the singleton branch is blocked - even defining intermediate states hits the issue

axiom frameAfterPC0 (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray) : Frame

-- Projection axioms (would be theorems if frameAfterPC0 were definable)
axiom frameAfterPC0_pc (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray) :
    (frameAfterPC0 chainId sender contract token ekBa commitBa respBa).pc = 1

axiom frameAfterPC0_code (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray) :
    (frameAfterPC0 chainId sender contract token ekBa commitBa respBa).code = verifyRegistrationProofCode

/-! ## Proof attempt showing elaboration blocker

The following axiom shows what we're trying to prove. Converting to `theorem` hits
the elaboration blocker at the `.set` bound proof. -/

axiom step_pc0_demo
    (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray) :
    let args := registrationArgs chainId sender contract token ekBa commitBa respBa
    let initFrame := registrationInitFrame args
    step (registrationModuleEnv o) initFrame [] [] MachineState.empty =
      .ok (frameAfterPC0 chainId sender contract token ekBa commitBa respBa)
          []
          [.vector .u8 (commitBa.toList.map .u8)]
          MachineState.empty

/-! ## Path forward: Incremental frame builders

To avoid elaboration issues, define frame builders incrementally:
1. `frameAfterPC0` - after moveLoc
2. `frameAfterPC1` - after native call (needs container threading)
3. `frameAfterPC2` - after stLoc
4. Continue pattern through PC 70

Each builder is `@[irreducible]` with projection lemmas.
Proofs use projections instead of inline frame construction.
-/

end MovementFormal.Experimental.ConfidentialAsset.Registration.SingletonBranchProofs
