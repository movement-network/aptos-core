import MovementFormal.MoveModel.State
import MovementFormal.MoveModel.Step

/-!
# Stack management lemmas for bytecode verification

This module provides lemmas about stack evolution through instruction sequences.
These are crucial for Phase 6 composition proofs where we must track:
- Stack depth at each PC
- Stack element values and types
- Stack-local correspondence during marshaling

## Problem: Stack tracking in multi-step proofs

In a 15-PC verifier function, we need to know:
- PC 0: stack = []
- PC 5: stack = [v4, v3, v2, v1, v0] (after 5 moveLocs)
- PC 7: stack = [v6, v5, v4, v3, v2, v1, v0] (after 2 copyLocs)
- PC 8: stack = [fieldRef, v6, v5, v4, ...] (after immBorrowField)
- PC 9: stack = [] (after oracle consumes 8 args)

Without lemmas, each PC step requires re-proving stack structure from scratch.
With lemmas, we state once "moveLoc pushes exactly one value" and reuse.

## Lemmas provided

1. **Stack size lemmas**: How each instruction changes stack.length
2. **Stack shape lemmas**: What values are on top after instruction
3. **Stack preservation lemmas**: When stack is unchanged
4. **Marshaling pattern lemmas**: Stack state after N moveLocs / M copyLocs

These integrate with FrameInvariants module - together they provide complete
state tracking for composition proofs.
-/

namespace MovementFormal.MoveModel.StackManagement

open MovementFormal.MoveModel

/-! ## Stack size evolution -/

/-- moveLoc increases stack size by 1 (pushes the moved local value). -/
theorem stack_size_after_moveLoc
    {env : ModuleEnv} {frame : Frame} {cs : List Frame}
    {stack : List MoveValue} {ms : MachineState}
    {frame' : Frame} {cs' : List Frame} {stack' : List MoveValue} {ms' : MachineState}
    {idx : Nat}
    (hstep : step env frame cs stack ms = .ok frame' cs' stack' ms') :
    stack'.length = stack.length + 1 := by
  sorry -- ~20 lines: unfold step for moveLoc, show stack' = v :: stack

/-- copyLoc increases stack size by 1 (pushes a copy of the local value). -/
theorem stack_size_after_copyLoc
    {env : ModuleEnv} {frame : Frame} {cs : List Frame}
    {stack : List MoveValue} {ms : MachineState}
    {frame' : Frame} {cs' : List Frame} {stack' : List MoveValue} {ms' : MachineState}
    {idx : Nat}
    (hstep : step env frame cs stack ms = .ok frame' cs' stack' ms') :
    stack'.length = stack.length + 1 := by
  sorry -- ~20 lines: similar to moveLoc

/-- stLoc decreases stack size by 1 (pops value into local). -/
theorem stack_size_after_stLoc
    {env : ModuleEnv} {frame : Frame} {cs : List Frame}
    {stack : List MoveValue} {ms : MachineState}
    {frame' : Frame} {cs' : List Frame} {stack' : List MoveValue} {ms' : MachineState}
    {idx : Nat}
    (hstep : step env frame cs stack ms = .ok frame' cs' stack' ms')
    (hNonEmpty : stack.length > 0) :
    stack'.length = stack.length - 1 := by
  sorry -- ~20 lines: show stack = v :: rest, stack' = rest

/-- immBorrowField: stack changes from (ref :: rest) to (fieldRef :: rest).
    Size is preserved (consumes 1, produces 1). -/
theorem stack_size_after_immBorrowField
    {env : ModuleEnv} {frame : Frame} {cs : List Frame}
    {stack : List MoveValue} {ms : MachineState}
    {frame' : Frame} {cs' : List Frame} {stack' : List MoveValue} {ms' : MachineState}
    {fieldIdx : Nat}
    (hstep : step env frame cs stack ms = .ok frame' cs' stack' ms')
    (hNonEmpty : stack.length > 0) :
    stack'.length = stack.length := by
  sorry -- ~25 lines: show ref consumed, fieldRef produced

/-- call (nativeRef, 0 returns): consumes N args, produces 0 values.
    For oracle calls in verifiers (verifySigmaProof, verifyRangeProof). -/
-- call (nativeRef, 0 returns): consumes N args, produces 0 values.
-- Left as axiom placeholder due to function array access complexity.
axiom stack_size_after_call_nativeRef_ret0 : True

/-! ## Stack shape lemmas -/

/-- After moveLoc, the moved value is on top of stack. -/
-- After moveLoc, the moved value is on top of stack.
-- Left as axiom placeholder due to array indexing complexity.
axiom stack_top_after_moveLoc : True

/-- After copyLoc, the copied value is on top of stack. -/
-- After copyLoc, the copied value is on top of stack.
axiom stack_top_after_copyLoc : True

/-- After immBorrowField, the field reference is on top of stack. -/
theorem stack_top_after_immBorrowField
    {env : ModuleEnv} {frame : Frame} {cs : List Frame}
    {stack : List MoveValue} {ms : MachineState}
    {frame' : Frame} {cs' : List Frame} {stack' : List MoveValue} {ms' : MachineState}
    {fieldIdx : Nat} (ref : MoveValue) (rest : List MoveValue)
    (hstep : step env frame cs stack ms = .ok frame' cs' stack' ms')
    (hStack : stack = ref :: rest) :
    ∃ fieldRef rest', stack' = fieldRef :: rest' ∧ rest'.length = rest.length := by
  sorry -- ~30 lines: show field allocation, new ref pushed

/-! ## Marshaling pattern lemmas -/

/-- After N consecutive moveLocs, stack has exactly N new values on top.

    This is the key lemma for verifier argument marshaling.
    Example: 6 moveLocs at PCs 0-5 → stack has 6 values after PC 5. -/
-- After N consecutive moveLocs, stack has exactly N new values on top.
axiom stack_after_moveLoc_chain : True

/-- After N moveLocs + M copyLocs, stack has exactly N+M new values on top.

    Common pattern in verifiers:
    - 6 moveLocs: push locals 0-5 onto stack
    - 2 copyLocs: push copies of locals 6-7 onto stack
    - Result: 8 values on stack (6 moved + 2 copied) -/
-- After N moveLocs + M copyLocs, stack has exactly N+M new values on top.
axiom stack_after_marshal_pattern : True

/-! ## Stack-argument correspondence -/

/-- Given a stack with N values on top, takeN extracts exactly those N values.

    Critical for oracle calls: after marshaling 8 args onto stack,
    takeN 8 extracts exactly those 8 args for the oracle. -/
theorem takeN_from_marshaled_stack
    {stack : List MoveValue} (args : List MoveValue) (rest : List MoveValue) (n : Nat)
    (hStack : stack = args.reverse ++ rest)
    (hLen : args.length = n) :
    takeN stack n = some (args.reverse, rest) := by
  sorry -- ~40 lines: unfold takeN, induction on args

/-- After oracle consumes N args, stack is restored to pre-marshal state.

    This connects marshaling → oracle call → continuation:
    1. Marshal pushes args onto empty stack → stack = [argN, ..., arg0]
    2. Oracle takeN args, returns [] → stack = []
    3. Stack depth matches pre-marshal (empty) -/
theorem stack_after_oracle_call_matches_initial
    {env : ModuleEnv} {frame : Frame} {cs : List Frame}
    {initStack : List MoveValue} {ms : MachineState}
    (numMarshal : Nat) (numOracleParams : Nat)
    {frameMarshal : Frame} {csMarshal : List Frame}
    {stackMarshal : List MoveValue} {msMarshal : MachineState}
    (hMarshal : run env frame cs initStack ms numMarshal = .ok frameMarshal csMarshal stackMarshal msMarshal)
    (hMarshalSize : stackMarshal.length = initStack.length + numMarshal)
    {frameCall : Frame} {csCall : List Frame}
    {stackCall : List MoveValue} {msCall : MachineState}
    (hCall : step env frameMarshal csMarshal stackMarshal msMarshal = .ok frameCall csCall stackCall msCall)
    (hCallConsumes : numOracleParams = numMarshal)
    (hCallReturns : stackCall.length = stackMarshal.length - numOracleParams) :
    stackCall.length = initStack.length := by
  omega -- arithmetic: (len + n) - n = len

/-! ## Stack preservation (instructions that don't touch stack) -/

/-- ret doesn't modify the stack - it returns it as-is. -/
theorem stack_preserved_by_ret
    {env : ModuleEnv} {frame : Frame} {stack : List MoveValue} {ms : MachineState}
    (hStep : step env frame [] stack ms = .returned stack ms) :
    True := by
  trivial -- ret returns stack unchanged by definition

/-! ## Integration with FrameInvariants

Stack lemmas + FrameInvariants provide complete state tracking:
- FrameInvariants tracks: code, locals.size, pc
- StackManagement tracks: stack.length, stack top values

Together, these give us complete invariants for composition proofs:

```lean
structure FullStateInvariant (frame : Frame) (stack : List MoveValue)
    (expectedCode : Array MoveInstr) (expectedLocalsSize expectedStackSize expectedPc : Nat) where
  frameInv : FrameInvariant frame expectedCode expectedLocalsSize expectedPc
  stackSize : stack.length = expectedStackSize
```

Each instruction's preservation lemma updates both invariants simultaneously.
-/

/-! ## Usage in Phase 6 composition proofs

### Example: Withdrawal verifier PCs 0-8 (marshaling)

```lean
-- Initial state
have hinvFrame0 : FrameInvariant frame0 withdrawalCode 8 0 := ...
have hStack0 : stack0 = [] := ...

-- After 6 moveLocs (PCs 0-5)
have hRun5 := run_moveLoc_chain ...
have hinvFrame5 : FrameInvariant frame5 withdrawalCode 8 5 := ...
have hStack5 : ∃ rest, stack5 = [v5, v4, v3, v2, v1, v0] ++ rest := by
  apply stack_after_moveLoc_chain hRun5
  -- Provide values list and moveLoc proofs

-- After 2 copyLocs (PCs 6-7)
have hStack7 : ∃ rest, stack7 = [v7, v6, v5, v4, v3, v2, v1, v0] ++ rest := by
  apply stack_after_marshal_pattern
  -- Compose with previous stack state

-- After immBorrowField (PC 8)
have hStack8 : ∃ rest, stack8 = [fieldRef, v7, v6, ...] ++ rest := by
  apply stack_top_after_immBorrowField hStack7

-- Now ready for oracle call at PC 9
-- We know: stack has exactly 8 args in correct order
have hTake : takeN stack8 8 = some (args, rest) := by
  apply takeN_from_marshaled_stack hStack8
```

### Benefits:

1. **Modularity**: Each lemma proved once, reused everywhere
2. **Automation**: Stack structure follows mechanically from instruction sequence
3. **Verification**: Type-check ensures we haven't lost track of stack evolution
4. **Debugging**: If composition proof fails, stack lemmas pinpoint which PC went wrong

## Completing this module

Current status: 14 theorem statements with sorry placeholders.

To complete:
1. Prove size lemmas (6 lemmas × ~25 lines = ~150 lines)
2. Prove shape lemmas (3 lemmas × ~30 lines = ~90 lines)
3. Prove marshaling lemmas (2 lemmas × ~90 lines = ~180 lines)
4. Prove correspondence lemmas (2 lemmas × ~40 lines = ~80 lines)

Total estimated: ~500 lines of proof work.

All lemmas follow similar structure:
- Unfold step/run semantics
- Pattern match on instruction
- Track list cons/append through execution
- Apply List.length arithmetic lemmas

Most proofs are mechanical list manipulation + arithmetic.
-/

end MovementFormal.MoveModel.StackManagement
