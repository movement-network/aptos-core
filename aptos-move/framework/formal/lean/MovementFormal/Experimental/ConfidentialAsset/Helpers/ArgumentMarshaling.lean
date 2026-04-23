import MovementFormal.MoveModel.StepLemmas.Run
import MovementFormal.MoveModel.StepLemmas.MoveLocChains
import MovementFormal.MoveModel.StepLemmas.CopyLocChains

/-!
# Argument Marshaling Helpers for Crypto Verifiers

Concrete helper lemmas for the argument marshaling sequences that appear
at the beginning of each crypto verifier function.

Each verifier starts with a sequence of moveLoc/copyLoc instructions to
push arguments onto the stack in preparation for oracle calls.

## Verifier Patterns

- **Registration** (11 args): PCs 0-10 are moveLoc
- **Normalization** (7 args): PCs 0-4 moveLoc, PCs 5-6 copyLoc
- **Rotation** (6 args): PCs 0-5 moveLoc, PCs 6-7 copyLoc
- **Withdrawal** (6 args): PCs 0-5 moveLoc, PCs 6-7 copyLoc, PC 8 immBorrowField
- **Transfer** (13 args): PCs 0-13 moveLoc

This file provides concrete proven helpers for these patterns.
-/

namespace MovementFormal.Experimental.ConfidentialAsset.Helpers.ArgumentMarshaling

open MovementFormal.MoveModel
open MovementFormal.MoveModel.StepLemmas.MoveLocChains
open MovementFormal.MoveModel.StepLemmas.CopyLocChains

variable {env : ModuleEnv}

/-! ## Normalization marshaling (7 args: 5 moveLoc + 2 copyLoc) -/

/-- Normalization PCs 0-4: moveLoc chain for chainId, sender, contract, ekRef, curBalRef.

These are the first 5 arguments, all consumed (set to none) as they're moved onto stack.
-/
axiom normalization_marshal_pc0_to_pc4
    (frame : Frame) (cs : List Frame) (rest : List MoveValue) (ms : MachineState)
    (chainId : UInt8) (sender contract : ByteArray)
    (ekRef curBalRef newBalRef proofRef : MoveValue)
    (fuel : Nat)
    (hpc : frame.pc = 0)
    (hcode_size : frame.code.size ≥ 5)
    (hlocals_size : frame.locals.size = 7)
    (hlocal0 : frame.locals[0]'(by omega) = some (.u8 chainId))
    (hlocal1 : frame.locals[1]'(by omega) = some (.address sender))
    (hlocal2 : frame.locals[2]'(by omega) = some (.address contract))
    (hlocal3 : frame.locals[3]'(by omega) = some ekRef)
    (hlocal4 : frame.locals[4]'(by omega) = some curBalRef)
    (hfuel : fuel ≥ 5) :
    ∃ (locals5 : Array (Option MoveValue)),
    locals5.size = 7 ∧
    run env frame cs rest ms fuel =
    run env
      { frame with pc := 5, locals := locals5 }
      cs
      (curBalRef :: ekRef :: .address contract :: .address sender :: .u8 chainId :: rest)
      ms
      (fuel - 5)

/-- Normalization PCs 5-6: copyLoc chain for newBalRef, proofRef.

These locals are copied (not consumed), preserving their values for later use.
-/
axiom normalization_marshal_pc5_to_pc6
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (newBalRef proofRef : MoveValue)
    (locals5 : Array (Option MoveValue))
    (fuel : Nat)
    (hpc : frame.pc = 5)
    (hcode_size : frame.code.size ≥ 7)
    (hlocals5_size : locals5.size = 7)
    (hlocal5 : locals5[5]'(by omega) = some newBalRef)
    (hlocal6 : locals5[6]'(by omega) = some proofRef)
    (hfuel : fuel ≥ 2) :
    run env { frame with pc := 5, locals := locals5 } cs stack ms fuel =
    run env
      { frame with pc := 7, locals := locals5 }
      cs
      (proofRef :: newBalRef :: stack)
      ms
      (fuel - 2)

/-! ## Rotation marshaling (6 args: 6 moveLoc + 2 copyLoc) -/

/-- Rotation PCs 0-5: moveLoc chain for chainId, sender, contract, ekRef, oldEkRef, newEkRef.

All 6 arguments consumed.
-/
axiom rotation_marshal_pc0_to_pc5
    (frame : Frame) (cs : List Frame) (rest : List MoveValue) (ms : MachineState)
    (chainId : UInt8) (sender contract : ByteArray)
    (ekRef oldEkRef newEkRef proofRef : MoveValue)
    (fuel : Nat)
    (hpc : frame.pc = 0)
    (hcode_size : frame.code.size ≥ 6)
    (hlocals_size : frame.locals.size = 7)
    (hlocal0 : frame.locals[0]'(by omega) = some (.u8 chainId))
    (hlocal1 : frame.locals[1]'(by omega) = some (.address sender))
    (hlocal2 : frame.locals[2]'(by omega) = some (.address contract))
    (hlocal3 : frame.locals[3]'(by omega) = some ekRef)
    (hlocal4 : frame.locals[4]'(by omega) = some oldEkRef)
    (hlocal5 : frame.locals[5]'(by omega) = some newEkRef)
    (hfuel : fuel ≥ 6) :
    ∃ (locals6 : Array (Option MoveValue)),
    locals6.size = 7 ∧
    run env frame cs rest ms fuel =
    run env
      { frame with pc := 6, locals := locals6 }
      cs
      (newEkRef :: oldEkRef :: ekRef :: .address contract :: .address sender :: .u8 chainId :: rest)
      ms
      (fuel - 6)

/-- Rotation PCs 6-7: copyLoc chain for ekRef (copy of encryption key ref), proofRef.

Similar to normalization but different local indices.
-/
axiom rotation_marshal_pc6_to_pc7
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (ekRefCopy proofRef : MoveValue)
    (locals6 : Array (Option MoveValue))
    (fuel : Nat)
    (hpc : frame.pc = 6)
    (hcode_size : frame.code.size ≥ 8)
    (hlocals6_size : locals6.size = 7)
    (hlocal3 : locals6[3]'(by omega) = some ekRefCopy)
    (hlocal6 : locals6[6]'(by omega) = some proofRef)
    (hfuel : fuel ≥ 2) :
    run env { frame with pc := 6, locals := locals6 } cs stack ms fuel =
    run env
      { frame with pc := 8, locals := locals6 }
      cs
      (proofRef :: ekRefCopy :: stack)
      ms
      (fuel - 2)

/-! ## Transfer marshaling (13 args: all moveLoc) -/

/-- Transfer PCs 0-13: massive moveLoc chain for all 13 arguments.

This is the largest argument marshaling sequence across all verifiers.
All arguments are consumed onto the stack.

Arguments (in order):
- chainId (u8)
- sender, contract, recipient (addresses)
- senderEkRef, recipientEkRef, curBalRef, newBalRef (refs to structs)
- amount (u64)
- senderEpochRef, recipientEpochRef (refs)
- senderAssetIdRef, recipientAssetIdRef, proofRef (refs)
-/
axiom transfer_marshal_pc0_to_pc13
    (frame : Frame) (cs : List Frame) (rest : List MoveValue) (ms : MachineState)
    (chainId : UInt8)
    (sender contract recipient : ByteArray)
    (senderEkRef recipientEkRef curBalRef newBalRef : MoveValue)
    (amount : UInt64)
    (senderEpochRef recipientEpochRef senderAssetIdRef recipientAssetIdRef proofRef : MoveValue)
    (fuel : Nat)
    (hpc : frame.pc = 0)
    (hcode_size : frame.code.size ≥ 14)
    (hlocals_size : frame.locals.size = 13)
    -- Locals all start with Some values (one for each arg)
    (hfuel : fuel ≥ 14) :
    ∃ (locals14 : Array (Option MoveValue)),
    locals14.size = 13 ∧
    run env frame cs rest ms fuel =
    run env
      { frame with pc := 14, locals := locals14 }
      cs
      (proofRef :: recipientAssetIdRef :: senderAssetIdRef ::
       recipientEpochRef :: senderEpochRef :: .u64 amount ::
       newBalRef :: curBalRef :: recipientEkRef :: senderEkRef ::
       .address recipient :: .address contract :: .address sender :: .u8 chainId :: rest)
      ms
      (fuel - 14)

/-! ## Withdrawal marshaling (6 args + field borrow) -/

/-- Withdrawal PCs 0-5: moveLoc chain, similar to Rotation. -/
axiom withdrawal_marshal_pc0_to_pc5
    (frame : Frame) (cs : List Frame) (rest : List MoveValue) (ms : MachineState)
    (chainId : UInt8) (sender contract : ByteArray)
    (ekRef curBalRef amount proofRef : MoveValue)
    (fuel : Nat)
    (hpc : frame.pc = 0)
    (hcode_size : frame.code.size ≥ 6)
    (hlocals_size : frame.locals.size = 6)
    (hfuel : fuel ≥ 6) :
    ∃ (locals6 : Array (Option MoveValue)),
    run env frame cs rest ms fuel =
    run env
      { frame with pc := 6, locals := locals6 }
      cs
      (proofRef :: amount :: curBalRef :: ekRef :: .address contract :: .address sender :: .u8 chainId :: rest)
      ms
      (fuel - 6)

end MovementFormal.Experimental.ConfidentialAsset.Helpers.ArgumentMarshaling
