import MovementFormal.Experimental.ConfidentialAsset.Normalization.EvalEquiv
import MovementFormal.MoveModel.StepLemmas

namespace Attempt

open MovementFormal.MoveModel
open MovementFormal.MoveModel.Programs.Normalization
open MovementFormal.MoveModel.StepLemmas

/-! Attempt to prove norm_run_pc5_to_pc8 or a variant

The challenge: The original theorem uses let-destructuring in its statement:
  let (sigmaCs, sigmaFid) := initMs.containers.alloc (proofFields[0]'...)
This creates free variables that block proof construction.

Strategy: Try to prove it step-by-step anyway, documenting what works and what doesn't.
-/

-- First, let's try assuming we know what's in locals5
axiom locals5_has_newBalRef : ∀ locals5 newBalRef,
  5 < locals5.size → locals5[5] = some newBalRef

axiom locals5_has_proofRef : ∀ locals5 proofRef,
  6 < locals5.size → locals5[6] = some proofRef

theorem norm_run_pc5_to_pc8_attempt
    (o : NormalizationModuleOracle)
    (chainId : UInt8) (sender contract : ByteArray)
    (ekRef curBalRef newBalRef proofRef : MoveValue)
    (proofRid : RefId) (proofFields : List MoveValue)
    (initMs : MachineState)
    (locals5 : Array (Option MoveValue))
    (hFieldCount : 1 < proofFields.length)
    (hread : initMs.containers.read proofRid = some (.struct_ proofFields))
    (hproofRef : getRefId proofRef = some proofRid)
    (hlocals5_size : 7 ≤ locals5.size)
    (hlocals5_5 : locals5[5]'(by omega : 5 < locals5.size) = some newBalRef)
    (hlocals5_6 : locals5[6]'(by omega : 6 < locals5.size) = some proofRef)
    (fuel : Nat)
    (hfuel : fuel ≥ 3) :
    let (sigmaCs, sigmaFid) := initMs.containers.alloc (proofFields[0]'(by omega))
    run (normalizationModuleEnv o)
        { code := verifyNormalizationProofCode, pc := 5,
          locals := locals5,
          localRefs := (List.replicate 7 none).toArray }
        []
        [curBalRef, ekRef, .address contract, .address sender, .u8 chainId]
        initMs fuel =
    run (normalizationModuleEnv o)
        { code := verifyNormalizationProofCode, pc := 8,
          locals := locals5,
          localRefs := (List.replicate 7 none).toArray }
        []
        [.immRef sigmaFid, proofRef, newBalRef, curBalRef, ekRef,
         .address contract, .address sender, .u8 chainId]
        { initMs with containers := sigmaCs }
        (fuel - 3) := by
  -- Step 1: Unfold let-binding
  -- This is where the free variable issue occurs
  -- Let's see if we can work with it anyway

  -- Apply run_succ to peel off PC 5
  rw [StepLemmas.Run.run_succ_ok_of_step]

  -- PC 5: copyLoc 5 (newBalRef)
  · apply step_copyLoc_noRef
    · decide  -- pc < code.size
    · rfl     -- code[pc] = .copyLoc 5
    · omega   -- 5 < locals.size
    · exact hlocals5_5  -- locals[5] = some newBalRef
    · left; decide  -- localRefs doesn't have ref at index 5

  -- After PC 5, stack is [newBalRef, curBalRef, ekRef, .address contract, .address sender, .u8 chainId]
  -- PC at 6, locals unchanged

  -- Apply run_succ to peel off PC 6
  rw [StepLemmas.Run.run_succ_ok_of_step]

  -- PC 6: copyLoc 6 (proofRef)
  · apply step_copyLoc_noRef
    · decide  -- pc < code.size
    · rfl     -- code[pc] = .copyLoc 6
    · omega   -- 6 < locals.size
    · exact hlocals5_6  -- locals[6] = some proofRef
    · left; decide  -- localRefs doesn't have ref at index 6

  -- After PC 6, stack is [proofRef, newBalRef, curBalRef, ...]
  -- PC at 7, locals unchanged

  -- Apply run_succ to peel off PC 7
  rw [StepLemmas.Run.run_succ_ok_of_step]

  -- PC 7: immBorrowField 0
  · apply step_immBorrowField
    · decide  -- pc < code.size
    · rfl     -- code[pc] = .immBorrowField 0
    · exact hproofRef  -- getRefId proofRef = some proofRid
    · exact hread  -- containers.read proofRid = some (.struct_ proofFields)
    · omega   -- 0 < proofFields.length
    · -- Here's the problem: we need to show
      -- initMs.containers.alloc (proofFields[0]'...) = (sigmaCs, sigmaFid)
      -- But (sigmaCs, sigmaFid) are let-bound variables
      sorry

  -- After PC 7: stack is [.immRef sigmaFid, proofRef, newBalRef, ...]
  -- containers updated to sigmaCs
  -- PC at 8

  sorry  -- The halloc sorry above prevents completion

end Attempt
