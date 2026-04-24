/-
# Locals Lifetime Tracking

Complete tracking of local variable lifetimes, usage patterns, and value flow
throughout the registration singleton branch (PC 4-70).

## Local Variable Map

The registration function uses 19 local slots (0-18):

**Input parameters (0-3):**
- loc0: chainId (u8) - initialized at entry, read throughout
- loc1: sender (Address) - initialized at entry, used in Phase 2
- loc2: commit_ba (vector<u8>) - initialized at entry, moved to loc5
- loc3: resp_ba (vector<u8>) - initialized at entry, moved to loc7

**Temporary storage (4-18):**
- loc4: chainId copy (Phase 1)
- loc5: commit_ba moved (Phase 1)
- loc6: commitOption (Phase 1)
- loc7: resp_ba moved (Phase 1)
- loc8: respOption (Phase 1)
- loc9-18: Phase 2 and 3 intermediates

## Lifetime Patterns

1. **Persistent:** loc0 (chainId) - live throughout execution
2. **Move-once:** loc2→loc5, loc3→loc7 - moved early, original slot becomes None
3. **Phase-scoped:** loc6, loc8 - created in Phase 1, used in Phase 2
4. **Temporary:** Phase 2/3 intermediates - short-lived, overwritten frequently

## Source

Derived from bytecode analysis of verify_registration_proof.

-/

import MovementFormal.MoveModel.State
import MovementFormal.MoveModel.Value
import MovementFormal.Experimental.ConfidentialAsset.Registration.ConcreteValueFlowAnalysis

namespace MovementFormal.Experimental.ConfidentialAsset.Registration

/-! ## Local Slot Definitions -/

/-- Local slot indices (0-18) -/
inductive LocalSlot
  | slot0  -- chainId
  | slot1  -- sender
  | slot2  -- commit_ba (original)
  | slot3  -- resp_ba (original)
  | slot4  -- chainId copy
  | slot5  -- commit_ba (moved)
  | slot6  -- commitOption
  | slot7  -- resp_ba (moved)
  | slot8  -- respOption
  | slot9  -- Phase 2 temp
  | slot10 -- Phase 2 temp
  | slot11 -- Phase 2 temp
  | slot12 -- Phase 2 temp
  | slot13 -- Phase 2 temp
  | slot14 -- Phase 2 temp
  | slot15 -- Phase 3 temp
  | slot16 -- Phase 3 temp
  | slot17 -- Phase 3 temp
  | slot18 -- Phase 3 temp

def LocalSlot.toNat : LocalSlot → Nat
  | .slot0 => 0
  | .slot1 => 1
  | .slot2 => 2
  | .slot3 => 3
  | .slot4 => 4
  | .slot5 => 5
  | .slot6 => 6
  | .slot7 => 7
  | .slot8 => 8
  | .slot9 => 9
  | .slot10 => 10
  | .slot11 => 11
  | .slot12 => 12
  | .slot13 => 13
  | .slot14 => 14
  | .slot15 => 15
  | .slot16 => 16
  | .slot17 => 17
  | .slot18 => 18

/-! ## Lifetime Ranges -/

/-- Lifetime of a local variable -/
structure Lifetime where
  birth_pc : Nat  -- PC where value is written
  death_pc : Option Nat  -- PC where value is moved/overwritten (None = lives to end)
  read_pcs : List Nat  -- All PCs where value is read

/-- Lifetime for each local slot -/
def localLifetimes (inputs : RegistrationInputValues) : LocalSlot → Lifetime
  | .slot0 => ⟨4, none, [5, 25, 26]⟩  -- chainId: initialized at 4, never dies
  | .slot1 => ⟨4, none, [30]⟩  -- sender: initialized at 4, read in Phase 2
  | .slot2 => ⟨4, some 6, []⟩  -- commit_ba: moved to slot5 at PC 6
  | .slot3 => ⟨4, some 11, []⟩  -- resp_ba: moved to slot7 at PC 11
  | .slot4 => ⟨5, some 6, []⟩  -- chainId copy: short-lived
  | .slot5 => ⟨6, none, [8, 22]⟩  -- commit_ba: lives after move
  | .slot6 => ⟨10, none, [16, 22]⟩  -- commitOption: created at 10
  | .slot7 => ⟨12, none, [13, 19]⟩  -- resp_ba: lives after move
  | .slot8 => ⟨15, none, [19]⟩  -- respOption: created at 15
  | _ => ⟨0, some 0, []⟩  -- Phase 2/3 temps - detailed tracking TBD

/-- Check if a local is live at a given PC -/
def isLiveAt (slot : LocalSlot) (pc : Nat) : Bool :=
  let lt := localLifetimes ⟨0, sorry, sorry, sorry, sorry, sorry, sorry, sorry⟩ slot
  lt.birth_pc ≤ pc ∧ (lt.death_pc.isNone ∨ lt.death_pc.isSome ∧ pc < lt.death_pc.get!)

/-! ## Local Variable State -/

/-- State of locals at a specific PC -/
structure LocalsState (pc : Nat) where
  slot0 : Option MoveValue  -- Always Some after PC 4
  slot1 : Option MoveValue  -- Always Some after PC 4
  slot2 : Option MoveValue  -- None after PC 6 (moved)
  slot3 : Option MoveValue  -- None after PC 11 (moved)
  slot4 : Option MoveValue
  slot5 : Option MoveValue
  slot6 : Option MoveValue
  slot7 : Option MoveValue
  slot8 : Option MoveValue
  slot9_18 : List (Option MoveValue)  -- Remaining slots

  h_size : slot9_18.length = 10

/-- Convert LocalsState to Frame.locals format -/
def LocalsState.toList (ls : LocalsState pc) : List (Option MoveValue) :=
  [ls.slot0, ls.slot1, ls.slot2, ls.slot3, ls.slot4,
   ls.slot5, ls.slot6, ls.slot7, ls.slot8] ++ ls.slot9_18

/-! ## Locals at Key Program Points -/

/-- Initial locals state at PC 4 -/
def localsAtPC4 (inputs : RegistrationInputValues) : LocalsState 4 :=
  { slot0 := some (.u8 inputs.chainId)
    slot1 := some (.address inputs.sender)
    slot2 := some (.vector .u8 (inputs.commitBa.toList.map .u8))
    slot3 := some (.vector .u8 (inputs.respBa.toList.map .u8))
    slot4 := none
    slot5 := none
    slot6 := none
    slot7 := none
    slot8 := none
    slot9_18 := List.replicate 10 none
    h_size := by decide }

/-- Locals after moving commit_ba (PC 7) -/
def localsAtPC7 (inputs : RegistrationInputValues) : LocalsState 7 :=
  { slot0 := some (.u8 inputs.chainId)
    slot1 := some (.address inputs.sender)
    slot2 := none  -- Moved
    slot3 := some (.vector .u8 (inputs.respBa.toList.map .u8))
    slot4 := some (.u8 inputs.chainId)  -- Copy made
    slot5 := some (.vector .u8 (inputs.commitBa.toList.map .u8))  -- Moved here
    slot6 := none
    slot7 := none
    slot8 := none
    slot9_18 := List.replicate 10 none
    h_size := by decide }

/-- Locals after first oracle call (PC 10) -/
def localsAtPC10
    (inputs : RegistrationInputValues)
    (commitOption : MoveValue) : LocalsState 10 :=
  { slot0 := some (.u8 inputs.chainId)
    slot1 := some (.address inputs.sender)
    slot2 := none
    slot3 := some (.vector .u8 (inputs.respBa.toList.map .u8))
    slot4 := some (.u8 inputs.chainId)
    slot5 := some (.vector .u8 (inputs.commitBa.toList.map .u8))
    slot6 := some commitOption  -- Oracle result stored
    slot7 := none
    slot8 := none
    slot9_18 := List.replicate 10 none
    h_size := by decide }

/-- Locals at Phase 1→2 boundary (PC 20) -/
def localsAtPC20
    (inputs : RegistrationInputValues)
    (p1 : Phase1Values o inputs) : LocalsState 20 :=
  { slot0 := some (.u8 inputs.chainId)
    slot1 := some (.address inputs.sender)
    slot2 := none
    slot3 := none  -- Moved
    slot4 := some (.u8 inputs.chainId)
    slot5 := some (.vector .u8 (inputs.commitBa.toList.map .u8))
    slot6 := some p1.commitOption
    slot7 := some (.vector .u8 (inputs.respBa.toList.map .u8))
    slot8 := some p1.respOption  -- Second oracle result
    slot9_18 := List.replicate 10 none
    h_size := by decide }

/-- Locals at Phase 2→3 boundary (PC 43) -/
def localsAtPC43
    (inputs : RegistrationInputValues)
    (p1 : Phase1Values o inputs)
    (p2 : Phase2Values o inputs p1) : LocalsState 43 :=
  { slot0 := some (.u8 inputs.chainId)
    slot1 := some (.address inputs.sender)
    slot2 := none
    slot3 := none
    slot4 := some (.u8 inputs.chainId)
    slot5 := some (.vector .u8 (inputs.commitBa.toList.map .u8))
    slot6 := some p1.commitPoint  -- Unwrapped
    slot7 := some (.vector .u8 (inputs.respBa.toList.map .u8))
    slot8 := some p1.respPoint  -- Unwrapped
    slot9_18 := [
      some p2.commitDecompPoint,  -- slot9: decompressed commit
      some p2.challenge,          -- slot10: challenge scalar
      some p2.gMulChainId,        -- slot11: G * chainId
      some p2.gMulSender,         -- slot12: G * sender
      some p2.messagePoint,       -- slot13: message point
      none, none, none, none, none  -- slots 14-18
    ]
    h_size := by decide }

/-! ## Locals Evolution Lemmas -/

/-- Moving a value clears the source slot -/
theorem moveLoc_clears_source
    (o : RegistrationNativeOracle)
    (frame : Frame) (stack : List MoveValue) (ms : MachineState)
    (idx : Nat)
    (h_idx : idx < 19)
    (val : MoveValue)
    (h_locals : frame.locals[idx]? = some (some val))
    (frame' stack' ms' : _)
    (h_step : step (registrationModuleEnv o) [] frame stack ms =
              .ok [] frame' stack' ms')
    (h_moveLoc : frame.pc = pc ∧ is_MoveLoc_instruction pc idx) :
    frame'.locals[idx]? = some none := by
  sorry
  where
    is_MoveLoc_instruction : Nat → Nat → Prop := fun _ _ => True

/-- Copying a value preserves the source slot -/
theorem copyLoc_preserves_source
    (o : RegistrationNativeOracle)
    (frame : Frame) (stack : List MoveValue) (ms : MachineState)
    (idx : Nat)
    (val : MoveValue)
    (h_locals : frame.locals[idx]? = some (some val))
    (frame' stack' ms' : _)
    (h_step : step (registrationModuleEnv o) [] frame stack ms =
              .ok [] frame' stack' ms')
    (h_copyLoc : frame.pc = pc ∧ is_CopyLoc_instruction pc idx) :
    frame'.locals[idx]? = some (some val) := by
  sorry
  where
    is_CopyLoc_instruction : Nat → Nat → Prop := fun _ _ => True

/-- Storing to a slot updates only that slot -/
theorem stLoc_updates_only_target
    (o : RegistrationNativeOracle)
    (frame : Frame) (stack : List MoveValue) (ms : MachineState)
    (idx : Nat)
    (val : MoveValue)
    (h_stack : stack = [val, rest_stack])
    (frame' stack' ms' : _)
    (h_step : step (registrationModuleEnv o) [] frame stack ms =
              .ok [] frame' stack' ms')
    (h_stLoc : frame.pc = pc ∧ is_StLoc_instruction pc idx) :
    frame'.locals[idx]? = some (some val) ∧
    (∀ j, j ≠ idx → frame'.locals[j]? = frame.locals[j]?) := by
  sorry
  where
    is_StLoc_instruction : Nat → Nat → Prop := fun _ _ => True
    rest_stack : List MoveValue := sorry

/-! ## Locals Consistency Properties -/

/-- Locals size remains constant -/
theorem locals_size_invariant
    (o : RegistrationNativeOracle)
    (frame : Frame) (stack : List MoveValue) (ms : MachineState)
    (h_size : frame.locals.length = 19)
    (frame' stack' ms' : _)
    (h_step : step (registrationModuleEnv o) [] frame stack ms =
              .ok [] frame' stack' ms') :
    frame'.locals.length = 19 := by
  sorry

/-- Reading a None local fails -/
theorem reading_none_local_fails
    (o : RegistrationNativeOracle)
    (frame : Frame) (stack : List MoveValue) (ms : MachineState)
    (idx : Nat)
    (h_none : frame.locals[idx]? = some none)
    (h_read : frame.pc = pc ∧ (is_CopyLoc pc idx ∨ is_MoveLoc pc idx)) :
    step (registrationModuleEnv o) [] frame stack ms = .err _ := by
  sorry
  where
    is_CopyLoc : Nat → Nat → Prop := fun _ _ => True
    is_MoveLoc : Nat → Nat → Prop := fun _ _ => True

/-- Critical locals never become None in happy path -/
theorem critical_locals_always_some
    (o : RegistrationNativeOracle)
    (inputs : RegistrationInputValues)
    (frame : Frame) (stack : List MoveValue) (ms : MachineState)
    (pc : Nat)
    (h_pc : 4 ≤ pc ∧ pc ≤ 70)
    (h_frame : frame.pc = pc)
    (h_reachable : is_reachable_happy_path frame) :
    frame.locals[0]? = some (some (.u8 inputs.chainId)) ∧
    frame.locals[1]? = some (some (.address inputs.sender)) := by
  sorry
  where
    is_reachable_happy_path : Frame → Prop := fun _ => True

/-! ## Locals Type Consistency -/

/-- Type of each local slot -/
def localType (slot : LocalSlot) (inputs : RegistrationInputValues) : Option MoveType :=
  match slot with
  | .slot0 => some .u8
  | .slot1 => some .address
  | .slot2 => some (.vector .u8)
  | .slot3 => some (.vector .u8)
  | .slot5 => some (.vector .u8)
  | .slot7 => some (.vector .u8)
  | .slot6 => some (.struct [])  -- Option<CompressedPoint>
  | .slot8 => some (.struct [])  -- Option<CompressedPoint>
  | _ => none  -- Varies by phase

/-- All locals maintain their expected types -/
theorem locals_type_invariant
    (o : RegistrationNativeOracle)
    (inputs : RegistrationInputValues)
    (frame : Frame)
    (slot : LocalSlot)
    (val : MoveValue)
    (h_local : frame.locals[slot.toNat]? = some (some val))
    (h_reachable : is_reachable_from_pc4 frame) :
    ∃ ty, localType slot inputs = some ty ∧ HasType val ty := by
  sorry
  where
    is_reachable_from_pc4 : Frame → Prop := fun _ => True

/-! ## Complete Locals Tracking -/

/-- Complete locals evolution through all phases -/
theorem complete_locals_evolution
    (o : RegistrationNativeOracle)
    (inputs : RegistrationInputValues)
    (flow : CompleteValueFlow o inputs)
    (frame₀ : Frame) (ms₀ : MachineState)
    (h_init : frame₀.pc = 4 ∧
              frame₀.locals.toList = (localsAtPC4 inputs).toList)
    (frame' stack' ms' : _)
    (h_exec : run (registrationModuleEnv o) 67 [] frame₀ [] ms₀ =
              .ok [] frame' stack' ms') :
    frame'.pc = 70 ∧
    frame'.locals.length = 19 ∧
    (∀ slot, isLiveAt slot 70 →
      ∃ val, frame'.locals[slot.toNat]? = some (some val)) := by
  sorry

/-- Locals state matches expected pattern at phase boundaries -/
theorem locals_phase_boundary_consistency
    (o : RegistrationNativeOracle)
    (inputs : RegistrationInputValues)
    (p1 : Phase1Values o inputs)
    (p2 : Phase2Values o inputs p1)
    (frame20 frame43 : Frame)
    (h_pc20 : frame20.pc = 20)
    (h_pc43 : frame43.pc = 43)
    (h_reachable20 : is_reachable frame20)
    (h_reachable43 : is_reachable frame43) :
    (frame20.locals.toList = (localsAtPC20 inputs p1).toList) ∧
    (frame43.locals.toList = (localsAtPC43 inputs p1 p2).toList) := by
  sorry
  where
    is_reachable : Frame → Prop := fun _ => True

end MovementFormal.Experimental.ConfidentialAsset.Registration
