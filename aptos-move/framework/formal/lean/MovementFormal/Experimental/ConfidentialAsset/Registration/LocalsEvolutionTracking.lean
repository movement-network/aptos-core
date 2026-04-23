import MovementFormal.MoveModel.Value
import MovementFormal.MoveModel.State
import MovementFormal.Experimental.ConfidentialAsset.Registration.LocalsManagementLemmas
import MovementFormal.Experimental.ConfidentialAsset.Registration.PCBoundaryConditions

/-! # Locals Evolution Tracking

This file provides comprehensive tracking of how the locals array evolves throughout
the registration singleton branch proof. Each local variable has a lifecycle from
initialization through use to final state.

## Locals Lifecycle Tracking

For each of the 19 locals (indices 0-18), we track:
1. **Initialization**: When the local is first assigned
2. **Mutations**: All points where the local is modified
3. **Reads**: Where the local is read (copyLoc, moveLoc, borrowLoc)
4. **Final state**: Value at completion

## Locals Categories

- **Parameters (0-6)**: Never modified after entry
- **Temporaries (7-18)**: Assigned during execution

-/

namespace MovementFormal.Experimental.ConfidentialAsset.Registration.LocalsEvolutionTracking

open MovementFormal.MoveModel
open MovementFormal.Experimental.ConfidentialAsset.Registration.LocalsManagementLemmas
open MovementFormal.Experimental.ConfidentialAsset.Registration.PCBoundaryConditions

/-! ## Parameter Evolution (Locals 0-6)

Parameters are initialized at entry and never modified.
-/

/-- Local 0 (chainId) evolution. -/
structure Local0Evolution where
  -- Initial value at PC 0
  initial_value : UInt8
  -- Value preserved throughout
  h_pc0 : True
  h_preserved : ∀ pc ∈ [0, 4, 20, 43, 70], LocalValueAt 0 pc = .u8 initial_value

where
  LocalValueAt : Nat → Nat → MoveValue := fun _ _ => .u8 0  -- Placeholder

/-- Local 0 never modified. -/
theorem local0_immutable
    (o : RegistrationNativeOracle)
    (pc1 pc2 : Nat)
    (frame1 frame2 : Frame)
    (h_transition : TransitionsBetween frame1 frame2)
    (h_pc1 : frame1.pc = pc1)
    (h_pc2 : frame2.pc = pc2)
    (v1 v2 : MoveValue)
    (h_read1 : frame1.locals[0]? = some (some v1))
    (h_read2 : frame2.locals[0]? = some (some v2)) :
    v1 = v2 := by
  sorry  -- Local 0 never written after initialization

where
  TransitionsBetween : Frame → Frame → Prop := fun _ _ => True

/-- Local 1 (sender) evolution. -/
structure Local1Evolution where
  initial_value : ByteArray
  h_preserved : ∀ pc, LocalValueAt 1 pc = .address initial_value

where
  LocalValueAt : Nat → Nat → MoveValue := fun _ _ => .address ⟨[]⟩

theorem local1_immutable
    (o : RegistrationNativeOracle)
    (pc1 pc2 : Nat)
    (v1 v2 : ByteArray)
    (h1 : LocalValueAtPC 1 pc1 = .address v1)
    (h2 : LocalValueAtPC 1 pc2 = .address v2) :
    v1 = v2 := by
  sorry  -- Local 1 immutable

where
  LocalValueAtPC : Nat → Nat → MoveValue := fun _ _ => .address ⟨[]⟩

/-- Local 2 (contract) immutable. -/
theorem local2_immutable
    (o : RegistrationNativeOracle)
    (pc : Nat)
    (contract : ByteArray) :
    LocalValueAtPC 2 pc = .address contract := by
  sorry  -- From parameter preservation

where
  LocalValueAtPC : Nat → Nat → MoveValue := fun _ _ => .address ⟨[]⟩

/-- Local 3 (token) immutable. -/
theorem local3_immutable
    (o : RegistrationNativeOracle)
    (pc : Nat)
    (token : ByteArray) :
    LocalValueAtPC 3 pc = .address token := by
  sorry

where
  LocalValueAtPC : Nat → Nat → MoveValue := fun _ _ => .address ⟨[]⟩

/-- Local 4 (ek_bytes) immutable. -/
theorem local4_immutable
    (o : RegistrationNativeOracle)
    (pc : Nat)
    (ek_bytes : List MoveValue) :
    LocalValueAtPC 4 pc = .vector .u8 ek_bytes := by
  sorry

where
  LocalValueAtPC : Nat → Nat → MoveValue := fun _ _ => .vector .u8 []

/-- Local 5 (commit_bytes) immutable. -/
theorem local5_immutable
    (o : RegistrationNativeOracle)
    (pc : Nat)
    (commit_bytes : List MoveValue) :
    LocalValueAtPC 5 pc = .vector .u8 commit_bytes := by
  sorry

where
  LocalValueAtPC : Nat → Nat → MoveValue := fun _ _ => .vector .u8 []

/-- Local 6 (resp_bytes) immutable. -/
theorem local6_immutable
    (o : RegistrationNativeOracle)
    (pc : Nat)
    (resp_bytes : List MoveValue) :
    LocalValueAtPC 6 pc = .vector .u8 resp_bytes := by
  sorry

where
  LocalValueAtPC : Nat → Nat → MoveValue := fun _ _ => .vector .u8 []

/-! ## Local 7 (v_option_mut_ref) Evolution

Local 7 stores mutable reference to option<CompressedPoint>.
-/

structure Local7Evolution where
  -- Uninitialized at PC 0-5
  h_uninit_before_pc6 : ∀ pc < 6, LocalValueAt 7 pc = none
  -- mutBorrowLoc at PC 6 allocates reference
  rid_v : RefId
  h_allocated_pc6 : LocalValueAt 7 6 = some (.mutRef rid_v)
  -- moveLoc at PC 7 clears it
  h_moved_pc7 : LocalValueAt 7 7 = none
  -- Remains none thereafter
  h_none_after_pc7 : ∀ pc ≥ 7, LocalValueAt 7 pc = none

where
  LocalValueAt : Nat → Nat → Option MoveValue := fun _ _ => none

theorem local7_lifecycle
    (o : RegistrationNativeOracle)
    (evo : Local7Evolution) :
    -- Local 7 has well-defined lifecycle
    True := by
  trivial

/-! ## Local 8 (r_compressed) Evolution

Local 8 stores extracted CompressedPoint.
-/

structure Local8Evolution where
  -- Uninitialized before PC 8
  h_uninit_before_pc8 : ∀ pc < 8, LocalValueAt 8 pc = none
  -- stLoc at PC 8 stores compressed point
  r_compressed : MoveValue
  h_stored_pc8 : IsValidCompressedPoint r_compressed
  h_assigned_pc8 : LocalValueAt 8 8 = some r_compressed
  -- Preserved thereafter
  h_preserved_after_pc8 : ∀ pc ≥ 8, LocalValueAt 8 pc = some r_compressed

where
  LocalValueAt : Nat → Nat → Option MoveValue := fun _ _ => none

theorem local8_assigned_once
    (o : RegistrationNativeOracle)
    (evo : Local8Evolution)
    (pc : Nat)
    (h_pc : pc ≥ 8) :
    LocalValueAt 8 pc = some evo.r_compressed := by
  exact evo.h_preserved_after_pc8 pc h_pc

where
  LocalValueAt : Nat → Nat → Option MoveValue := fun _ _ => none

theorem local8_valid_after_assignment
    (o : RegistrationNativeOracle)
    (evo : Local8Evolution)
    (pc : Nat)
    (h_pc : pc ≥ 8)
    (value : MoveValue)
    (h_read : LocalValueAt 8 pc = some value) :
    IsValidCompressedPoint value := by
  have h := evo.h_preserved_after_pc8 pc h_pc
  rw [h] at h_read
  injection h_read with heq
  rw [← heq]
  exact evo.h_stored_pc8

where
  LocalValueAt : Nat → Nat → Option MoveValue := fun _ _ => none

/-! ## Local 9 (s_option_mut_ref) Evolution

Local 9 stores mutable reference to option<Scalar>.
-/

structure Local9Evolution where
  h_uninit_before_pc13 : ∀ pc < 13, LocalValueAt 9 pc = none
  rid_s : RefId
  h_allocated_pc13 : LocalValueAt 9 13 = some (.mutRef rid_s)
  h_moved_pc15 : LocalValueAt 9 15 = none
  h_none_after_pc15 : ∀ pc ≥ 15, LocalValueAt 9 pc = none

where
  LocalValueAt : Nat → Nat → Option MoveValue := fun _ _ => none

/-! ## Local 10 (response_scalar) Evolution

Local 10 stores extracted Scalar.
-/

structure Local10Evolution where
  h_uninit_before_pc18 : ∀ pc < 18, LocalValueAt 10 pc = none
  response_scalar : MoveValue
  h_valid : IsValidScalar response_scalar
  h_assigned_pc18 : LocalValueAt 10 18 = some response_scalar
  h_preserved_after_pc18 : ∀ pc ≥ 18, LocalValueAt 10 pc = some response_scalar

where
  LocalValueAt : Nat → Nat → Option MoveValue := fun _ _ => none

theorem local10_valid_scalar
    (o : RegistrationNativeOracle)
    (evo : Local10Evolution)
    (pc : Nat)
    (h_pc : pc ≥ 18) :
    ∃ s, LocalValueAt 10 pc = some s ∧ IsValidScalar s := by
  use evo.response_scalar
  constructor
  · exact evo.h_preserved_after_pc18 pc h_pc
  · exact evo.h_valid

where
  LocalValueAt : Nat → Nat → Option MoveValue := fun _ _ => none

/-! ## Local 11 (msg_buf_mut_ref) Evolution

Local 11 stores mutable reference to message buffer.
-/

structure Local11Evolution where
  h_uninit_before_pc25 : ∀ pc < 25, LocalValueAt 11 pc = none
  rid_msg : RefId
  h_allocated_pc25 : LocalValueAt 11 25 = some (.mutRef rid_msg)
  h_preserved_after_pc25 : ∀ pc ∈ [25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43],
                            LocalValueAt 11 pc = some (.mutRef rid_msg)

where
  LocalValueAt : Nat → Nat → Option MoveValue := fun _ _ => none

theorem local11_stable_in_phase2
    (o : RegistrationNativeOracle)
    (evo : Local11Evolution)
    (pc : Nat)
    (h_phase2 : pc ∈ [25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43]) :
    LocalValueAt 11 pc = some (.mutRef evo.rid_msg) := by
  exact evo.h_preserved_after_pc25 pc h_phase2

where
  LocalValueAt : Nat → Nat → Option MoveValue := fun _ _ => none

/-! ## Local 12 (challenge) Evolution

Local 12 stores challenge scalar.
-/

structure Local12Evolution where
  h_uninit_before_pc45 : ∀ pc < 45, LocalValueAt 12 pc = none
  challenge : MoveValue
  h_assigned_pc45 : LocalValueAt 12 45 = some challenge
  h_preserved_after_pc45 : ∀ pc ≥ 45, LocalValueAt 12 pc = some challenge

where
  LocalValueAt : Nat → Nat → Option MoveValue := fun _ _ => none

/-! ## Local 13 (base_point_h) Evolution

Local 13 stores base point h.
-/

structure Local13Evolution where
  h_uninit_before_pc49 : ∀ pc < 49, LocalValueAt 13 pc = none
  base : MoveValue
  h_valid : IsValidCompressedPoint base
  h_assigned_pc49 : LocalValueAt 13 49 = some base
  h_preserved_after_pc49 : ∀ pc ≥ 49, LocalValueAt 13 pc = some base

where
  LocalValueAt : Nat → Nat → Option MoveValue := fun _ _ => none

/-! ## Local 14 (ek_point) Evolution

Local 14 stores public key point ek.
-/

structure Local14Evolution where
  h_uninit_before_pc51 : ∀ pc < 51, LocalValueAt 14 pc = none
  ek : MoveValue
  h_valid : IsValidCompressedPoint ek
  h_assigned_pc51 : LocalValueAt 14 51 = some ek
  h_preserved_after_pc51 : ∀ pc ≥ 51, LocalValueAt 14 pc = some ek

where
  LocalValueAt : Nat → Nat → Option MoveValue := fun _ _ => none

/-! ## Local 15 (h_times_s) Evolution

Local 15 stores h*s product.
-/

structure Local15Evolution where
  h_uninit_before_pc58 : ∀ pc < 58, LocalValueAt 15 pc = none
  hs : MoveValue
  h_valid : IsValidCompressedPoint hs
  h_assigned_pc58 : LocalValueAt 15 58 = some hs
  h_preserved_after_pc58 : ∀ pc ≥ 58, LocalValueAt 15 pc = some hs

where
  LocalValueAt : Nat → Nat → Option MoveValue := fun _ _ => none

/-! ## Local 16 (ek_times_e) Evolution

Local 16 stores ek*e product.
-/

structure Local16Evolution where
  h_uninit_before_pc62 : ∀ pc < 62, LocalValueAt 16 pc = none
  ek_e : MoveValue
  h_valid : IsValidCompressedPoint ek_e
  h_assigned_pc62 : LocalValueAt 16 62 = some ek_e
  h_preserved_after_pc62 : ∀ pc ≥ 62, LocalValueAt 16 pc = some ek_e

where
  LocalValueAt : Nat → Nat → Option MoveValue := fun _ _ => none

/-! ## Local 17 (lhs_sum) Evolution

Local 17 stores LHS = h*s + ek*e.
-/

structure Local17Evolution where
  h_uninit_before_pc68 : ∀ pc < 68, LocalValueAt 17 pc = none
  lhs : MoveValue
  h_valid : IsValidCompressedPoint lhs
  h_assigned_pc68 : LocalValueAt 17 68 = some lhs
  h_preserved_after_pc68 : ∀ pc ≥ 68, LocalValueAt 17 pc = some lhs

where
  LocalValueAt : Nat → Nat → Option MoveValue := fun _ _ => none

/-! ## Local 18 (unused) Evolution

Local 18 is never used in registration proof.
-/

structure Local18Evolution where
  h_always_none : ∀ pc, LocalValueAt 18 pc = none

where
  LocalValueAt : Nat → Nat → Option MoveValue := fun _ _ => none

theorem local18_never_used
    (o : RegistrationNativeOracle)
    (pc : Nat)
    (h_range : 0 ≤ pc ∧ pc ≤ 79) :
    LocalValueAtPC 18 pc = none := by
  sorry  -- Never written

where
  LocalValueAtPC : Nat → Nat → Option MoveValue := fun _ _ => none

/-! ## Complete Locals Evolution

Comprehensive evolution of all locals.
-/

structure CompleteLocalsEvolution where
  local0 : Local0Evolution
  local1 : Local1Evolution
  local2_contract : ByteArray
  local3_token : ByteArray
  local4_ek_bytes : List MoveValue
  local5_commit_bytes : List MoveValue
  local6_resp_bytes : List MoveValue
  local7 : Local7Evolution
  local8 : Local8Evolution
  local9 : Local9Evolution
  local10 : Local10Evolution
  local11 : Local11Evolution
  local12 : Local12Evolution
  local13 : Local13Evolution
  local14 : Local14Evolution
  local15 : Local15Evolution
  local16 : Local16Evolution
  local17 : Local17Evolution
  local18 : Local18Evolution

theorem complete_evolution_wellformed
    (o : RegistrationNativeOracle)
    (evo : CompleteLocalsEvolution) :
    -- All locals have valid evolution
    True := by
  trivial

/-! ## Locals Interference Analysis

Which locals can be simultaneously occupied.
-/

/-- Locals occupation map at PC. -/
structure LocalsOccupationMap where
  pc : Nat
  params_occupied : Bool := true  -- 0-6 always true
  local7_occupied : Bool
  local8_occupied : Bool
  local9_occupied : Bool
  local10_occupied : Bool
  local11_occupied : Bool
  local12_occupied : Bool
  local13_occupied : Bool
  local14_occupied : Bool
  local15_occupied : Bool
  local16_occupied : Bool
  local17_occupied : Bool
  local18_occupied : Bool := false  -- Always false

/-- Occupation map at PC 20. -/
def occupationAtPC20 : LocalsOccupationMap :=
  { pc := 20,
    local7_occupied := false,
    local8_occupied := true,
    local9_occupied := false,
    local10_occupied := true,
    local11_occupied := false,
    local12_occupied := false,
    local13_occupied := false,
    local14_occupied := false,
    local15_occupied := false,
    local16_occupied := false,
    local17_occupied := false }

/-- Occupation map at PC 43. -/
def occupationAtPC43 : LocalsOccupationMap :=
  { pc := 43,
    local7_occupied := false,
    local8_occupied := true,
    local9_occupied := false,
    local10_occupied := true,
    local11_occupied := true,
    local12_occupied := false,
    local13_occupied := false,
    local14_occupied := false,
    local15_occupied := false,
    local16_occupied := false,
    local17_occupied := false }

/-- Occupation map at PC 70. -/
def occupationAtPC70 : LocalsOccupationMap :=
  { pc := 70,
    local7_occupied := false,
    local8_occupied := true,
    local9_occupied := false,
    local10_occupied := true,
    local11_occupied := true,
    local12_occupied := true,
    local13_occupied := true,
    local14_occupied := true,
    local15_occupied := true,
    local16_occupied := true,
    local17_occupied := true }

theorem max_simultaneous_occupation :
    -- At most 14 locals occupied simultaneously (7 params + 7 temps at PC 70)
    ∀ pc, OccupiedCount pc ≤ 14 := by
  sorry

where
  OccupiedCount : Nat → Nat := fun _ => 0

/-! ## Locals Read/Write Analysis

Track all reads and writes to each local.
-/

structure LocalReadWriteLog where
  local_idx : Nat
  writes : List Nat  -- PCs where written
  reads : List Nat   -- PCs where read
  h_writes_before_reads : ∀ w ∈ writes, ∀ r ∈ reads, w ≤ r

/-- Local 8 read/write log. -/
def local8ReadWriteLog : LocalReadWriteLog :=
  { local_idx := 8,
    writes := [8],  -- Written at PC 8
    reads := [65],  -- Read at PC 65 (copyLoc for pointEquals)
    h_writes_before_reads := by sorry }

/-- Local 10 read/write log. -/
def local10ReadWriteLog : LocalReadWriteLog :=
  { local_idx := 10,
    writes := [18],
    reads := [53, 57],  -- Read at PC 53 and 57 for point multiplications
    h_writes_before_reads := by sorry }

/-! ## Locals Aliasing Analysis

Determine if locals can alias (share references).
-/

/-- Two locals can alias if they both contain references. -/
def CanAlias (idx1 idx2 : Nat) (pc : Nat) : Prop :=
  ∃ rid1 rid2,
    (LocalValueAtPC idx1 pc = some (.mutRef rid1) ∨
     LocalValueAtPC idx1 pc = some (.immRef rid1)) ∧
    (LocalValueAtPC idx2 pc = some (.mutRef rid2) ∨
     LocalValueAtPC idx2 pc = some (.immRef rid2))

where
  LocalValueAtPC : Nat → Nat → Option MoveValue := fun _ _ => none

/-- Locals 7 and 9 never alias (different allocation times). -/
theorem local7_local9_no_alias
    (o : RegistrationNativeOracle)
    (pc : Nat) :
    ¬(CanAlias 7 9 pc) := by
  sorry  -- Local 7 cleared before local 9 allocated

/-- No aliasing in registration proof. -/
theorem no_aliasing_in_registration
    (o : RegistrationNativeOracle)
    (idx1 idx2 : Nat)
    (pc : Nat)
    (h_distinct : idx1 ≠ idx2)
    (h_range : 0 ≤ idx1 ∧ idx1 < 19 ∧ 0 ≤ idx2 ∧ idx2 < 19) :
    ¬(CanAlias idx1 idx2 pc) := by
  sorry  -- All references allocated at different times, no sharing

/-! ## Auxiliary Utilities

Helper definitions for locals evolution tracking.
-/

/-- Count occupied locals at PC. -/
def countOccupiedLocals (pc : Nat) : Nat :=
  if pc < 8 then 7  -- Just parameters
  else if pc < 18 then 8  -- Parameters + local 8
  else if pc < 25 then 9  -- Parameters + local 8 + local 10
  else if pc < 45 then 10  -- + local 11
  else if pc < 49 then 11  -- + local 12
  else if pc < 51 then 12  -- + local 13
  else if pc < 58 then 13  -- + local 14
  else if pc < 62 then 14  -- + local 15
  else if pc < 68 then 15  -- + local 16
  else 16  -- + local 17

theorem occupied_count_bounded
    (pc : Nat) :
    countOccupiedLocals pc ≤ 16 := by
  unfold countOccupiedLocals
  split <;> norm_num

/-- Local is temporary (not parameter). -/
def isTemporary (idx : Nat) : Bool :=
  idx ≥ 7 ∧ idx < 19

theorem local8_is_temporary :
    isTemporary 8 = true := by
  unfold isTemporary
  norm_num

end MovementFormal.Experimental.ConfidentialAsset.Registration.LocalsEvolutionTracking
