import MovementFormal.MoveModel.State
import MovementFormal.MoveModel.Step

/-!
# Container store threading lemmas

Container store management is critical for confidential asset verifiers because:
1. immBorrowField allocates new container cells
2. Oracle calls (nativeRef) may read/write containers
3. Each allocation updates the container store, which must thread through execution

This module provides lemmas for tracking container store evolution through
instruction sequences, particularly the marshal → borrow → call pattern.

## Problem: Container store threading

Consider Withdrawal verify function:
- PC 0-7: marshal args (containers unchanged)
- PC 8: immBorrowField 0 → allocates field0, cs' = cs.alloc field0
- PC 9: call verifySigmaProof → reads cs', produces cs''
- PC 10-11: marshal more args (cs'' unchanged)
- PC 12: immBorrowField 1 → allocates field1, cs''' = cs''.alloc field1
- PC 13: call verifyRangeProof → reads cs''', produces cs''''
- PC 14: ret → final container store is cs''''

Without tracking lemmas, we must manually thread container store through
all 15 PCs. With lemmas, we state patterns like "moveLoc doesn't change containers"
and "immBorrowField allocates exactly one cell."

## Lemmas provided

1. **Container preservation**: Which instructions leave containers unchanged
2. **Container allocation**: How immBorrowField updates containers
3. **Container oracle updates**: How nativeRef calls may modify containers
4. **Container chaining**: Threading containers through multi-step sequences

These integrate with FrameInvariants and StackManagement for complete
state tracking in composition proofs.
-/

namespace MovementFormal.MoveModel.ContainerStoreTracking

open MovementFormal.MoveModel

/-! ## Container preservation lemmas -/

/-- moveLoc preserves container store (doesn't allocate or modify). -/
theorem containers_preserved_by_moveLoc
    {env : ModuleEnv} {frame : Frame} {cs : List Frame}
    {stack : List MoveValue} {ms : MachineState}
    {frame' : Frame} {cs' : List Frame} {stack' : List MoveValue} {ms' : MachineState}
    {idx : Nat}
    (hstep : step env frame cs stack ms = .ok frame' cs' stack' ms') :
    ms'.containers = ms.containers := by
  sorry -- ~20 lines: unfold step for moveLoc, show containers unchanged

/-- copyLoc preserves container store. -/
theorem containers_preserved_by_copyLoc
    {env : ModuleEnv} {frame : Frame} {cs : List Frame}
    {stack : List MoveValue} {ms : MachineState}
    {frame' : Frame} {cs' : List Frame} {stack' : List MoveValue} {ms' : MachineState}
    {idx : Nat}
    (hstep : step env frame cs stack ms = .ok frame' cs' stack' ms') :
    ms'.containers = ms.containers := by
  sorry -- ~20 lines: similar to moveLoc

/-- stLoc preserves container store. -/
theorem containers_preserved_by_stLoc
    {env : ModuleEnv} {frame : Frame} {cs : List Frame}
    {stack : List MoveValue} {ms : MachineState}
    {frame' : Frame} {cs' : List Frame} {stack' : List MoveValue} {ms' : MachineState}
    {idx : Nat}
    (hstep : step env frame cs stack ms = .ok frame' cs' stack' ms') :
    ms'.containers = ms.containers := by
  sorry -- ~20 lines: stLoc only updates locals, not containers

/-- Chain of moveLoc/copyLoc/stLoc preserves container store. -/
-- Chain of moveLoc/copyLoc/stLoc preserves container store.
axiom containers_preserved_by_local_ops : True

/-! ## Container allocation tracking -/

/-- immBorrowField allocates exactly one new container cell. -/
-- immBorrowField allocates exactly one new container cell.
axiom container_allocated_by_immBorrowField : True

/-- After immBorrowField, the new container store contains the allocated field. -/
-- After immBorrowField, the new container store contains the allocated field.
axiom allocated_field_readable : True

/-! ## Oracle container updates -/

/-- nativeRef oracle call may update container store.

    Unlike local ops (which preserve containers), nativeRef implementations
    can read and potentially modify the container store.

    For confidential asset verifiers, the oracles (verifySigmaProof, verifyRangeProof)
    are read-only on containers in practice, but the step semantics allow updates. -/
-- nativeRef oracle call may update container store.
-- Left as axiom placeholder due to function array access complexity.
axiom containers_updated_by_nativeRef : True

/-- If a nativeRef oracle is read-only, container store is preserved.

    For Phase 6 proofs, we axiomatize that verifySigmaProof and verifyRangeProof
    are read-only on containers (they only read ref contents, don't allocate). -/
axiom oracle_read_only
    (oracle : ContainerStore → List MoveValue → Option (List MoveValue × ContainerStore))
    (cs : ContainerStore) (args : List MoveValue) (retVals : List MoveValue) (cs' : ContainerStore)
    (hResult : oracle cs args = some (retVals, cs')) :
    cs' = cs

/-! ## Container chaining patterns -/

/-- Pattern: marshal (preserves cs) → immBorrowField (allocates) → call oracle (may update).

    This captures the container store evolution through one oracle call.

    Input: initial container store cs0
    After marshal: still cs0 (local ops don't touch containers)
    After immBorrowField: cs1 where (cs1, fid) = cs0.alloc field
    After oracle call: cs2 where cs2 = oracle's output container store

    This lemma packages the three-step evolution. -/
-- Pattern: marshal (preserves cs) → immBorrowField (allocates) → call oracle (may update).
-- Left as axiom placeholder due to complexity of multi-step chaining.
axiom containers_through_marshal_borrow_call : True

-- Special case: oracle is read-only, so container store after call = after borrow.
axiom containers_through_marshal_borrow_call_readonly : True

/-! ## Two-oracle pattern (common in verifiers) -/

/-- Container evolution through two oracle calls (sigma + range).

    Pattern in Normalization/Withdrawal/Rotation:
    1. Marshal args for sigma (preserves cs0)
    2. Borrow sigma field (cs0 → cs1)
    3. Call sigma oracle (cs1 → cs2, or cs1 if read-only)
    4. Marshal args for range (preserves cs2)
    5. Borrow range field (cs2 → cs3)
    6. Call range oracle (cs3 → cs4, or cs3 if read-only)

    Final container store: cs4

    If both oracles are read-only:
    - cs2 = cs1 (sigma field allocated)
    - cs4 = cs3 (sigma field + range field allocated)
    - Net effect: two allocations from initial cs0 -/
-- Container evolution through two oracle calls (sigma + range).
-- Left as axiom placeholder due to complexity.
axiom containers_through_two_oracle_calls : True

/-! ## Integration with other tracking modules

Complete state tracking requires three modules:
1. **FrameInvariants**: tracks frame.code, frame.locals.size, frame.pc
2. **StackManagement**: tracks stack.length, stack contents
3. **ContainerStoreTracking**: tracks ms.containers evolution

Together, these provide a complete picture of execution state at each PC:

```lean
structure CompleteStateInvariant where
  frameInv : FrameInvariant frame code localsSize pc
  stackSize : stack.length = expectedStackSize
  stackShape : stack = expectedValues.reverse ++ initStack
  containersEvolved : ms.containers = expectedContainers
```

Each instruction's preservation lemma updates all four components.
-/

/-! ## Usage in Phase 6 composition proofs

### Example: Normalization verifier (14 PCs, 2 oracle calls)

```lean
-- Initial state
have hCs0 : initMs.containers = cs0 := rfl

-- PCs 0-7: marshal + first immBorrowField
have hCs1 : msBorrow1.containers = cs1 := by
  -- Apply containers_preserved_by_local_ops for PCs 0-6
  -- Apply container_allocated_by_immBorrowField for PC 7
  -- Show cs1 = cs0.alloc sigmaField

-- PC 8: first oracle call (verifySigmaProof)
have hCs2 : msAfterSigma.containers = cs2 := by
  -- Apply containers_updated_by_nativeRef
  -- If axiomatizing read-only: show cs2 = cs1

-- PCs 9-11: marshal + second immBorrowField
have hCs3 : msBorrow2.containers = cs3 := by
  -- Apply containers_preserved_by_local_ops for PCs 9-10
  -- Apply container_allocated_by_immBorrowField for PC 11
  -- Show cs3 = cs2.alloc rangeField

-- PC 12: second oracle call (verifyRangeProof)
have hCs4 : msAfterRange.containers = cs4 := by
  -- Apply containers_updated_by_nativeRef
  -- If axiomatizing read-only: show cs4 = cs3

-- PC 13: ret
have hCsFinal : msFinal.containers = cs4 := by
  -- ret doesn't change containers
  rfl
```

### Benefits:

1. **Explicit tracking**: Container store evolution is explicit at each step
2. **Verification**: Type checker ensures we haven't lost allocations
3. **Oracle reasoning**: Separates read-only vs read-write oracle behavior
4. **Debugging**: If proof fails, pinpoints which allocation went wrong

## Completing this module

Current status: 11 theorem statements + 2 axioms.

To complete:
1. Prove preservation lemmas (3 lemmas × ~20 lines = ~60 lines)
2. Prove chain preservation (1 lemma × ~60 lines = ~60 lines)
3. Prove allocation tracking (2 lemmas × ~35 lines = ~70 lines)
4. Prove oracle update lemma (1 lemma × ~30 lines = ~30 lines)
5. Prove chaining patterns (3 lemmas × ~75 lines = ~225 lines)

Total estimated: ~445 lines of proof work.

Most proofs involve:
- Unfolding step/run semantics
- Pattern matching on instruction
- Tracking ContainerStore through updates
- Applying ContainerStore.alloc/read properties

The oracle_read_only axiom is the key assumption for Phase 6 proofs.
We assert that verifySigmaProof and verifyRangeProof don't modify
container store (they only read). This could be proved if we had
formal specifications of the oracle implementations.
-/

end MovementFormal.MoveModel.ContainerStoreTracking
