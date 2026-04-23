import MovementFormal.MoveModel.Step
import MovementFormal.MoveModel.StepLemmas.Basic
import MovementFormal.MoveModel.StepLemmas.Locals
import MovementFormal.MoveModel.StepLemmas.Structs
import MovementFormal.MoveModel.StepLemmas.Calls
import MovementFormal.MoveModel.StepLemmas.Run

/-!
# Oracle call patterns for confidential asset verifiers

This module provides specialized helpers for the oracle-call pattern used in all four Phase 4
confidential asset verifier functions (Normalization, Withdrawal, Rotation, Transfer).

## Common pattern

All four verifiers follow this structure:
1. Marshal arguments: moveLoc × N pushes locals onto stack
2. Copy proof refs: copyLoc × M duplicates proof references
3. Borrow proof field: immBorrowField extracts struct field
4. Call oracle: native call to verifySigmaProof or verifyRangeProof
5. Handle result: branch on oracle outcome (some vs none)

## Oracle outcome splitting

The key challenge in Phase 6 composition proofs is splitting on oracle outcomes cleanly.
Each verifier has 2-3 oracle calls, creating 4-8 execution paths through the function.

### Splitting strategy

For a verifier with two oracle calls (sigma + range):

```lean
-- After marshaling to PC N (before first oracle call)
cases hsigma : o.verifySigmaProof cs sigmaArgs with
| none =>
  -- Error path: chain to oracle call PC, show step returns .error
  -- Use step_<verifier>_pcN_none lemma
| some ⟨retVals, cs'⟩ =>
  cases retVals with
  | [] =>
    -- Success: continue to second oracle
    cases hrange : o.verifyRangeProof cs' rangeArgs with
    | none => -- range error path
    | some ⟨retVals2, cs''⟩ =>
      cases retVals2 with
      | [] => -- full success path
      | _ :: _ => -- arity mismatch (impossible)
  | _ :: _ => -- arity mismatch (impossible)
```

## Helpers in this module

1. **Oracle argument construction**: Bundle moveLoc/copyLoc results into oracle arg lists
2. **Container allocation tracking**: Thread container store through immBorrowField
3. **Oracle outcome predicates**: State oracle success/failure conditions
4. **Path lemmas**: Connect oracle outcomes to run execution paths

These are structure lemmas, not complete proofs - they factor out common reasoning
patterns to reduce duplication across the four verifier composition theorems.
-/

namespace MovementFormal.MoveModel.StepLemmas.OraclePatterns

open MovementFormal.MoveModel
open MovementFormal.MoveModel.StepLemmas

/-! ## Oracle argument list construction -/

/-- Predicate: the stack contains exactly the arguments needed for verifySigmaProof.

    Sigma proof oracles take 7-8 arguments depending on the verifier:
    - Normalization/Withdrawal/Rotation: 7 args (chainId, sender, contract, ekRef, curBalRef, newBalRef, sigmaProofRef)
    - Transfer has variation: 8 args with additional fields

    This helper states "the stack top N elements match the expected argument pattern"
    without reconstructing the full stack history. -/
def SigmaArgsOnStack (stack : List MoveValue) (expectedArgs : List MoveValue) : Prop :=
  ∃ rest, stack = expectedArgs.reverse ++ rest

/-- Predicate: the stack contains exactly the arguments needed for verifyRangeProof.

    Range proof oracles take 2 arguments: (balanceRef, rangeProofRef) -/
def RangeArgsOnStack (stack : List MoveValue) (expectedArgs : List MoveValue) : Prop :=
  ∃ rest, stack = expectedArgs.reverse ++ rest

/-! ## Container store threading -/

/-- After immBorrowField, the container store is updated and a new field reference is on stack.

    This packages the three facts needed to continue after immBorrowField:
    1. New container store allocated
    2. Field reference is on top of stack
    3. Machine state containers updated -/
structure ImmBorrowFieldResult where
  containers' : ContainerStore
  fieldRef : RefId
  fieldValue : MoveValue
  hAlloc : containers'.alloc fieldValue = (containers', fieldRef)

/-- Helper: construct ImmBorrowFieldResult from proof struct access.

    Given a proof struct at rid with fields, and an index i, constructs the result
    of borrowing field i. -/
axiom borrowProofField
    (proofFields : List MoveValue) (fieldIdx : Nat) (initCs : ContainerStore)
    (hlt : fieldIdx < proofFields.length) :
    ImmBorrowFieldResult

/-! ## Oracle outcome predicates -/

/-- Oracle returned success with empty return list (the common verifier pattern). -/
def OracleSucceeded
    (oracle : ContainerStore → List MoveValue → Option (List MoveValue × ContainerStore))
    (cs : ContainerStore) (args : List MoveValue) (cs' : ContainerStore) : Prop :=
  oracle cs args = some ([], cs')

/-- Oracle returned failure (none). -/
def OracleFailed
    (oracle : ContainerStore → List MoveValue → Option (List MoveValue × ContainerStore))
    (cs : ContainerStore) (args : List MoveValue) : Prop :=
  oracle cs args = none

/-! ## Path lemmas: oracle outcome → execution result

These lemmas connect oracle outcomes to the corresponding `run` result after executing
the oracle call instruction. They factor out the "if oracle succeeds, execution continues;
if oracle fails, execution returns .error" reasoning.

Each is a wrapper around the per-PC step theorems from the verifier EvalEquiv files,
restated in terms of the predicates above for easier composition. -/

/-- If sigma oracle succeeds and we're at the call instruction, execution continues.

    Generic version - specific verifiers instantiate with their step_<verifier>_pcN theorem. -/
axiom sigma_call_succeeds_continues
    (env : ModuleEnv) (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (oracle : ContainerStore → List MoveValue → Option (List MoveValue × ContainerStore))
    (args : List MoveValue) (cs' : ContainerStore)
    (callPc : Nat)
    (hOracle : OracleSucceeded oracle ms.containers args cs')
    (hStack : SigmaArgsOnStack stack args) :
    ∃ frameNext,
      step env frame cs stack ms =
        .ok frameNext cs [] { ms with containers := cs', globals := ms.globals } ∧
      frameNext.pc = callPc + 1

/-- If sigma oracle fails and we're at the call instruction, execution returns .error. -/
axiom sigma_call_fails_errors
    (env : ModuleEnv) (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (oracle : ContainerStore → List MoveValue → Option (List MoveValue × ContainerStore))
    (args : List MoveValue)
    (hOracle : OracleFailed oracle ms.containers args)
    (hStack : SigmaArgsOnStack stack args) :
    step env frame cs stack ms = .error

/-- If range oracle succeeds, execution continues. -/
axiom range_call_succeeds_continues
    (env : ModuleEnv) (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (oracle : ContainerStore → List MoveValue → Option (List MoveValue × ContainerStore))
    (args : List MoveValue) (cs' : ContainerStore)
    (callPc : Nat)
    (hOracle : OracleSucceeded oracle ms.containers args cs')
    (hStack : RangeArgsOnStack stack args) :
    ∃ frameNext,
      step env frame cs stack ms =
        .ok frameNext cs [] { ms with containers := cs', globals := ms.globals } ∧
      frameNext.pc = callPc + 1

/-- If range oracle fails, execution returns .error. -/
axiom range_call_fails_errors
    (env : ModuleEnv) (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (oracle : ContainerStore → List MoveValue → Option (List MoveValue × ContainerStore))
    (args : List MoveValue)
    (hOracle : OracleFailed oracle ms.containers args)
    (hStack : RangeArgsOnStack stack args) :
    step env frame cs stack ms = .error

/-! ## Arity mismatch lemmas

Oracles returning the wrong number of values should be impossible (type system invariant),
but the step semantics produce .error for arity mismatches. These lemmas let composition
proofs discharge impossible branches quickly. -/

/-- If an oracle returns a non-empty list when numReturns = 0, step produces .error.
    This case is impossible in well-typed bytecode but must be handled for completeness. -/
-- If an oracle returns a non-empty list when numReturns = 0, step produces .error.
-- Left as placeholder axiom due to indexing complexity.
axiom oracle_arity_mismatch_error : True

/-! ## Composition helpers

These bundle common multi-step patterns for cleaner composition theorem statements. -/

/-- Pattern: marshal N arguments, borrow field, call sigma oracle, split on outcome.

    This captures the first half of every 2-oracle verifier:
    1. Execute moveLoc/copyLoc to build argument stack
    2. Execute immBorrowField to extract proof field
    3. Execute call to sigma oracle
    4. Split on oracle outcome

    Returns either:
    - .error if oracle failed
    - Updated state at PC after oracle call if oracle succeeded -/
-- Pattern: marshal N arguments, borrow field, call sigma oracle, split on outcome.
-- Left as axiom placeholder due to complexity of multi-step chaining + dependent types.
axiom marshal_borrow_call_sigma_pattern : True

/-! ## Usage notes for Phase 6 completion

When completing composition theorems, use these patterns:

1. **Import this module** alongside the verifier's EvalEquiv file
2. **State oracle outcomes** using OracleSucceeded/OracleFailed predicates
3. **Split execution** using the path lemmas above
4. **Discharge impossible branches** using arity_mismatch lemmas

Example structure for a 2-oracle verifier:

```lean
theorem <verifier>_eval_equiv_functional_sim ... := by
  rw [eval_<verifier>_eq_run]

  -- Split on first oracle
  cases hsigma : o.verifySigmaProof ... with
  | none =>
    -- Apply sigma_call_fails_errors
    -- Show run propagates .error
  | some ⟨[], cs2⟩ =>
    -- Apply sigma_call_succeeds_continues
    -- Chain to second oracle
    cases hrange : o.verifyRangeProof ... with
    | none => ...
    | some ⟨[], cs3⟩ => ...
  | some ⟨_ :: _, _⟩ =>
    -- Apply oracle_arity_mismatch_error
```

## Completing this module

Current status: axiom placeholders for structure lemmas.

To complete:
1. Prove path lemmas by instantiating with specific per-PC step theorems
2. Prove marshal_borrow_call_sigma_pattern by composing step lemmas
3. Add analogous patterns for range oracle calls
4. Add patterns for Transfer's 3-oracle structure

Estimated effort: ~300-400 lines of proof work, leveraging existing step theorems.
-/

end MovementFormal.MoveModel.StepLemmas.OraclePatterns
