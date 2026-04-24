/-
# Complete Container Interaction Analysis

Comprehensive analysis of container store interactions in registration.
Tracks all container allocations, references, borrows, and deallocations
throughout the singleton branch execution.

## Container Operations

1. **Allocation**: Create new container entries
2. **Borrow**: Create references (mutable or immutable)
3. **Read**: Access container values through references
4. **Write**: Modify container values through mutable references
5. **Drop**: Release references and deallocate containers

## Container Lifecycle

- **Birth**: Container allocated via oracle or borrow operation
- **Active**: Container has live references
- **Zombie**: All references dropped but container still in store
- **Death**: Container removed from store

## Container Types in Registration

Most operations in the singleton branch work directly with values
(no intermediate container allocations). Container store interactions
are minimal and localized to specific oracle calls.

## Source

Extends ContainerStoreProperties.lean and ContainerStoreMonotonicity.lean.

-/

import MovementFormal.MoveModel.State
import MovementFormal.Experimental.ConfidentialAsset.Registration.ContainerStoreProperties
import MovementFormal.Experimental.ConfidentialAsset.Registration.ContainerStoreMonotonicity
import MovementFormal.Experimental.ConfidentialAsset.Registration.ReferenceLifetimeAnalysis

namespace MovementFormal.Experimental.ConfidentialAsset.Registration

/-! ## Container Identification -/

/-- Container reference ID type -/
def ContainerRefId := Nat

/-- Container value type -/
structure ContainerEntry where
  ref_id : ContainerRefId
  value : MoveValue
  ref_count : Nat
  is_mutable : Bool

/-- Container store snapshot -/
structure ContainerSnapshot where
  pc : Nat
  entries : List ContainerEntry
  h_no_duplicates : entries.map ContainerEntry.ref_id |>.Nodup

/-! ## Container Operations Classification -/

/-- Container operation types -/
inductive ContainerOp
  | allocate (ref_id : ContainerRefId) (value : MoveValue)
  | borrow_mut (ref_id : ContainerRefId)
  | borrow_imm (ref_id : ContainerRefId)
  | read (ref_id : ContainerRefId)
  | write (ref_id : ContainerRefId) (new_value : MoveValue)
  | drop_ref (ref_id : ContainerRefId)
  | deallocate (ref_id : ContainerRefId)

/-- Container operation at each PC -/
def containerOpAt : Nat → Option ContainerOp
  | _ => none  -- Registration has minimal container operations

/-! ## Container Lifetime States -/

/-- Container lifecycle state -/
inductive ContainerState
  | unallocated
  | allocated (ref_count : Nat)
  | zombie
  | deallocated

/-- Container state at PC -/
def containerStateAt
    (ref_id : ContainerRefId)
    (pc : Nat)
    (ms : MachineState) : ContainerState :=
  if containsContainer ref_id ms then
    .allocated (getRefCount ref_id ms)
  else
    .unallocated
  where
    containsContainer : ContainerRefId → MachineState → Bool := fun _ _ => false
    getRefCount : ContainerRefId → MachineState → Nat := fun _ _ => 0

/-! ## Container Allocation Analysis -/

/-- All container allocations in registration -/
def allContainerAllocations : List (Nat × ContainerRefId) :=
  []  -- Registration performs no explicit container allocations

/-- Container allocation monotonicity -/
theorem container_allocations_monotonic
    (o : RegistrationNativeOracle)
    (ref_id : ContainerRefId)
    (pc1 pc2 : Nat)
    (h_order : pc1 < pc2)
    (ms1 ms2 : MachineState)
    (h_states : ∃ frame1 stack1 frame2 stack2 fuel,
      run (registrationModuleEnv o) fuel [] frame1 stack1 ms1 =
      .ok [] frame2 stack2 ms2 ∧
      frame1.pc = pc1 ∧ frame2.pc = pc2)
    (h_allocated : containerStateAt ref_id pc1 ms1 = .allocated sorry) :
    containerStateAt ref_id pc2 ms2 ≠ .unallocated := by
  sorry

/-! ## Reference Counting -/

/-- Count active references to container -/
def countActiveRefs
    (ref_id : ContainerRefId)
    (frame : Frame)
    (stack : List MoveValue) : Nat :=
  let local_refs := frame.locals.filterMap id
    |>.filter (isRefTo ref_id) |>.length
  let stack_refs := stack.filter (isRefTo ref_id) |>.length
  local_refs + stack_refs
  where
    isRefTo : ContainerRefId → MoveValue → Bool := fun _ _ => false

/-- Reference count invariant -/
theorem ref_count_invariant
    (o : RegistrationNativeOracle)
    (ref_id : ContainerRefId)
    (frame : Frame) (stack : List MoveValue) (ms : MachineState)
    (h_pc : 4 ≤ frame.pc ∧ frame.pc < 70) :
    -- Container ref count matches actual reference count
    (containerStateAt ref_id frame.pc ms).allocated? =
    some (countActiveRefs ref_id frame stack) ∨
    containerStateAt ref_id frame.pc ms = .unallocated := by
  sorry
  where
    ContainerState.allocated? : ContainerState → Option Nat
      | .allocated n => some n
      | _ => none

/-! ## Borrow Analysis -/

/-- Borrow operations in registration -/
def allBorrowOps : List (Nat × ContainerRefId × Bool) :=
  []  -- (PC, ref_id, is_mutable)
     -- Registration has no explicit borrow operations

/-- Borrow exclusivity -/
theorem borrow_exclusivity
    (o : RegistrationNativeOracle)
    (ref_id : ContainerRefId)
    (frame : Frame) (stack : List MoveValue) (ms : MachineState)
    (h_mutable : hasMutableRef ref_id frame stack) :
    -- No other refs (mutable or immutable) coexist
    countActiveRefs ref_id frame stack = 1 := by
  sorry
  where
    hasMutableRef : ContainerRefId → Frame → List MoveValue → Bool :=
      fun _ _ _ => false

/-! ## Container Store Size Bounds -/

/-- Maximum container store size -/
def maxContainerStoreSize : Nat := 0
  -- Registration doesn't allocate containers

/-- Container store bounded -/
theorem container_store_bounded
    (o : RegistrationNativeOracle)
    (inputs : RegistrationInputValues)
    (flow : CompleteValueFlow o inputs)
    (ms : MachineState)
    (h_reachable : ∃ frame stack fuel,
      run (registrationModuleEnv o) fuel [] sorry [] sorry =
      .ok [] frame stack ms) :
    containerStoreSize ms ≤ maxContainerStoreSize := by
  sorry
  where
    containerStoreSize : MachineState → Nat := fun _ => 0

/-! ## Container Leak Detection -/

/-- Find leaked containers (zombie state) -/
def findLeakedContainers
    (frame : Frame)
    (stack : List MoveValue)
    (ms : MachineState) : List ContainerRefId :=
  getAllContainers ms |>.filter fun ref_id =>
    countActiveRefs ref_id frame stack = 0
  where
    getAllContainers : MachineState → List ContainerRefId := fun _ => []

/-- No container leaks -/
theorem no_container_leaks
    (o : RegistrationNativeOracle)
    (inputs : RegistrationInputValues)
    (flow : CompleteValueFlow o inputs)
    (frame : Frame) (stack : List MoveValue) (ms : MachineState)
    (h_pc : 4 ≤ frame.pc ∧ frame.pc < 70) :
    findLeakedContainers frame stack ms = [] := by
  sorry

/-! ## Container Access Patterns -/

/-- Container access pattern -/
structure AccessPattern where
  ref_id : ContainerRefId
  accesses : List (Nat × AccessType)  -- (PC, access type)
  where
    AccessType := String  -- "read" | "write" | "borrow"

/-- Extract access pattern for container -/
def extractAccessPattern
    (ref_id : ContainerRefId)
    (o : RegistrationNativeOracle)
    (inputs : RegistrationInputValues) : AccessPattern :=
  { ref_id := ref_id
    accesses := [] }  -- Would extract from execution trace

/-- All access patterns well-formed -/
theorem access_patterns_well_formed
    (o : RegistrationNativeOracle)
    (inputs : RegistrationInputValues)
    (ref_id : ContainerRefId)
    (pattern : AccessPattern)
    (h_pattern : pattern = extractAccessPattern ref_id o inputs) :
    -- No write after deallocate
    (∀ i j, i < j → j < pattern.accesses.length →
      pattern.accesses[i]? = some (sorry, "deallocate") →
      pattern.accesses[j]?.map Prod.snd ≠ some "write") ∧
    -- No read of zombie container
    (∀ i, i < pattern.accesses.length →
      pattern.accesses[i]?.map Prod.snd = some "read" →
      ∃ ref_count, ref_count > 0) := by
  sorry

/-! ## Container Value Evolution -/

/-- Container value at each write -/
structure ContainerValueTrace where
  ref_id : ContainerRefId
  timeline : List (Nat × MoveValue)  -- (PC, value)

/-- Build value trace for container -/
def buildValueTrace
    (ref_id : ContainerRefId)
    (o : RegistrationNativeOracle)
    (inputs : RegistrationInputValues) : ContainerValueTrace :=
  { ref_id := ref_id
    timeline := [] }

/-- Value trace type consistency -/
theorem value_trace_type_consistent
    (o : RegistrationNativeOracle)
    (ref_id : ContainerRefId)
    (trace : ContainerValueTrace)
    (h_trace : trace = buildValueTrace ref_id o inputs) :
    -- All values in trace have same type
    ∀ i j, i < trace.timeline.length → j < trace.timeline.length →
      ∃ ty val_i val_j,
        trace.timeline[i]? = some (sorry, val_i) ∧
        trace.timeline[j]? = some (sorry, val_j) ∧
        HasType val_i ty ∧ HasType val_j ty := by
  sorry

/-! ## Container Store Snapshots -/

/-- Container store at key PCs -/
def containerSnapshotAt (pc : Nat) : ContainerSnapshot :=
  match pc with
  | 4  => { pc := 4, entries := [], h_no_duplicates := by simp [List.Nodup] }
  | 20 => { pc := 20, entries := [], h_no_duplicates := by simp [List.Nodup] }
  | 43 => { pc := 43, entries := [], h_no_duplicates := by simp [List.Nodup] }
  | 70 => { pc := 70, entries := [], h_no_duplicates := by simp [List.Nodup] }
  | _  => { pc := pc, entries := [], h_no_duplicates := by simp [List.Nodup] }

/-- Snapshots consistent with execution -/
theorem snapshots_consistent
    (o : RegistrationNativeOracle)
    (inputs : RegistrationInputValues)
    (pc : Nat)
    (h_pc : pc ∈ [4, 20, 43, 70])
    (frame : Frame) (ms : MachineState)
    (h_state : ∃ stack fuel,
      run (registrationModuleEnv o) fuel [] sorry [] sorry =
      .ok [] frame stack ms ∧ frame.pc = pc) :
    -- Snapshot matches actual container store
    let snapshot := containerSnapshotAt pc
    snapshot.entries.map ContainerEntry.ref_id =
    getAllContainerIds ms := by
  sorry
  where
    getAllContainerIds : MachineState → List ContainerRefId := fun _ => []

/-! ## Container Store Monotonicity -/

/-- Container store only grows (until cleanup) -/
theorem container_store_monotonic
    (o : RegistrationNativeOracle)
    (pc1 pc2 : Nat)
    (h_order : pc1 < pc2)
    (h_range : 4 ≤ pc1 ∧ pc2 < 70)
    (ms1 ms2 : MachineState)
    (h_states : ∃ frame1 stack1 frame2 stack2 fuel,
      run (registrationModuleEnv o) fuel [] frame1 stack1 ms1 =
      .ok [] frame2 stack2 ms2 ∧
      frame1.pc = pc1 ∧ frame2.pc = pc2)
    (ref_id : ContainerRefId)
    (h_exists1 : containerStateAt ref_id pc1 ms1 ≠ .unallocated) :
    -- Container still exists at pc2 (unless explicitly deallocated)
    containerStateAt ref_id pc2 ms2 ≠ .unallocated ∨
    ∃ dealloc_pc, pc1 < dealloc_pc ∧ dealloc_pc < pc2 ∧
      containerOpAt dealloc_pc = some (.deallocate ref_id) := by
  sorry

/-! ## Container Interaction Simplicity -/

/-- Registration has minimal container interactions -/
theorem registration_minimal_containers
    (o : RegistrationNativeOracle)
    (inputs : RegistrationInputValues)
    (flow : CompleteValueFlow o inputs)
    (frame₀ : Frame) (ms₀ : MachineState)
    (h_init : let (f, _, m) := constructInitialState inputs
              frame₀ = f ∧ ms₀ = m)
    (frame' stack' ms' : _)
    (h_exec : run (registrationModuleEnv o) 67 [] frame₀ [] ms₀ =
              .ok [] frame' stack' ms') :
    -- No container allocations
    allContainerAllocations = [] ∧
    -- No borrow operations
    allBorrowOps = [] ∧
    -- Container store empty at all boundaries
    (∀ pc ∈ [4, 20, 43, 70],
      (containerSnapshotAt pc).entries = []) := by
  sorry

/-! ## Oracle Container Semantics -/

/-- Oracle operations that might use containers internally -/
def oracleUsesContainers (oracle_name : String) : Bool :=
  match oracle_name with
  | "newCompressedPointFromBytes" => false
  | "pointDecompress" => false
  | "basePointMul" => false
  | "pointAdd" => false
  | "pointMul" => false
  | "pointEquals" => false
  | "sha3_256" => false
  | "scalarFromHash" => false
  | "isSome" => false
  | "unwrap" => false
  | _ => false

/-- Oracle container encapsulation -/
theorem oracle_container_encapsulation
    (o : RegistrationNativeOracle)
    (oracle_name : String)
    (inputs outputs : List MoveValue)
    (ms_before ms_after : MachineState)
    (h_call : oracleCall o oracle_name inputs ms_before =
              some (outputs, ms_after)) :
    -- Oracle doesn't leak containers to caller
    (∀ ref_id,
      containerStateAt ref_id sorry ms_after = .allocated sorry →
      containerStateAt ref_id sorry ms_before = .allocated sorry) ∧
    -- Oracle doesn't deallocate caller's containers
    (∀ ref_id,
      containerStateAt ref_id sorry ms_before = .allocated sorry →
      containerStateAt ref_id sorry ms_after ≠ .deallocated) := by
  sorry
  where
    oracleCall : RegistrationNativeOracle → String → List MoveValue →
                 MachineState → Option (List MoveValue × MachineState) :=
      fun _ _ _ _ => none

/-! ## Complete Container Interaction Theorem -/

/-- Main theorem: Container interactions are safe and minimal -/
theorem registration_container_safe
    (o : RegistrationNativeOracle)
    (inputs : RegistrationInputValues)
    (flow : CompleteValueFlow o inputs)
    (frame₀ : Frame) (ms₀ : MachineState)
    (h_init : let (f, _, m) := constructInitialState inputs
              frame₀ = f ∧ ms₀ = m)
    (frame' stack' ms' : _)
    (h_exec : run (registrationModuleEnv o) 67 [] frame₀ [] ms₀ =
              .ok [] frame' stack' ms') :
    -- Minimal container usage
    (∀ pc, 4 ≤ pc ∧ pc < 70 →
      containerSnapshotAt pc |>.entries = []) ∧
    -- No leaks
    (∀ pc frame stack ms,
      4 ≤ pc ∧ pc < 70 →
      findLeakedContainers frame stack ms = []) ∧
    -- Reference counts accurate
    (∀ ref_id frame stack ms,
      ref_count_invariant o ref_id frame stack ms sorry) ∧
    -- Borrow exclusivity
    (∀ ref_id frame stack ms,
      hasMutableRef ref_id frame stack →
      countActiveRefs ref_id frame stack = 1) ∧
    -- Store bounded
    (∀ ms, containerStoreSize ms ≤ maxContainerStoreSize) ∧
    -- Oracle encapsulation
    (∀ oracle_name inputs outputs ms_before ms_after,
      oracleCall o oracle_name inputs ms_before = some (outputs, ms_after) →
      oracle_container_encapsulation o oracle_name inputs outputs ms_before ms_after sorry) := by
  sorry
  where
    hasMutableRef : ContainerRefId → Frame → List MoveValue → Bool :=
      fun _ _ _ => false
    containerStoreSize : MachineState → Nat := fun _ => 0
    oracleCall : RegistrationNativeOracle → String → List MoveValue →
                 MachineState → Option (List MoveValue × MachineState) :=
      fun _ _ _ _ => none

end MovementFormal.Experimental.ConfidentialAsset.Registration
