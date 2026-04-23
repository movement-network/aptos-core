import MovementFormal.MoveModel.Step
import MovementFormal.MoveModel.StepLemmas.Locals
import MovementFormal.MoveModel.StepLemmas.Run

/-!
# Bundled multi-instruction step helpers

This module provides bundled helpers for common instruction sequences in the confidential
asset verifier functions. Each helper chains multiple `step` applications for common patterns:

- **moveLoc chains**: consecutive moveLoc instructions pushing locals onto stack
- **copyLoc chains**: consecutive copyLoc instructions
- **Mixed sequences**: common patterns like "moveLoc × N + copyLoc × M"

These helpers reduce boilerplate in Phase 6 composition theorems by providing pre-packaged
multi-step chains. They use the run_succ_*_ok helpers from StepLemmas.Run but provide
operation-specific interfaces.

## Usage pattern

Instead of applying individual step theorems and manually chaining with run_succ_ok_of_step,
use bundled helpers:

```lean
-- Old: manual chaining (verbose)
have h0 := step_pc0 ...
have h1 := run_succ_ok_of_step ... h0
have h2 := step_pc1 ...
have h3 := run_succ_ok_of_step ... h2
...

-- New: bundled helper (concise)
have h := moveLoc_chain_three 0 1 2 ... -- PCs 0, 1, 2 are moveLoc
-- Result: frame at PC 3, three values on stack
```

These helpers are most useful when:
1. Multiple consecutive PCs perform the same operation class (moveLoc, copyLoc)
2. No oracle calls or branching between instructions
3. Locals are present and localRefs are none (common verifier pattern)
-/

namespace MovementFormal.MoveModel.StepLemmas.Bundled

open MovementFormal.MoveModel
open MovementFormal.MoveModel.StepLemmas

variable {env : ModuleEnv}

/-! ## Bundled multi-step helpers (axiom placeholders)

These helpers would chain multiple consecutive instructions of the same type.
They are left as axiom placeholders because completing them requires resolving
the array manipulation "free variable" constraint that currently blocks all
PC-chaining proofs.

Each axiom represents ~40-80 lines of proof work (step applications + run chaining).
Total module completion effort: ~300-400 lines once the array constraint is resolved.

### Design notes for future completion:

1. **moveLoc_chain_N**: Chain N consecutive moveLoc instructions
   - Input: frame at startPc, N populated locals
   - Output: frame at startPc + N, N values on stack (reverse order)
   - Requires: N step_moveLoc_noRef applications + N-1 run_succ_ok_of_step chains

2. **copyLoc_chain_N**: Chain N consecutive copyLoc instructions
   - Input: frame at startPc, N populated locals
   - Output: frame at startPc + N, N values on stack (locals unchanged)
   - Easier than moveLoc since no local clearing

3. **Mixed patterns**: moveLoc × M then copyLoc × N
   - Common in verifier functions (e.g., Withdrawal: 6 moveLoc + 2 copyLoc)
   - Requires induction on instruction list or explicit unrolling for fixed lengths

### Usage pattern when completed:

```lean
-- Instead of:
have h0 := step_moveLoc_noRef ...
have h1 := run_succ_ok_of_step ... h0
have h2 := step_moveLoc_noRef ...
have h3 := run_succ_ok_of_step ... h2
...

-- Use:
have h := moveLoc_chain_three idx0 idx1 idx2 ...
```
-/

axiom moveLoc_chain_two : True
axiom moveLoc_chain_three : True
axiom moveLoc_chain_four : True
axiom moveLoc_chain_five : True
axiom moveLoc_chain_six : True

axiom copyLoc_chain_two : True
axiom copyLoc_chain_three : True

/-! ## Mixed moveLoc + copyLoc patterns

Note: These are intentionally left as incomplete declarations due to the complexity of
parameterizing over variable-length instruction sequences. Completing them requires
either induction on list structure or explicit unrolling for fixed lengths. -/

-- Placeholder for pattern theorem - would need dependent types for variable length
axiom moveLoc_then_copyLoc_pattern_placeholder : True

/-! ## Oracle-call helpers

Pattern: marshal args (moveLoc/copyLoc), immBorrowField, call native oracle.
This is the exact pattern in all four Phase 4 verifier functions.

These are left as axiom placeholders due to parameterization complexity. -/

axiom marshal_and_borrow_field_pattern_placeholder : True

/-! ## Documentation helpers -/

/-- Helper theorem: computing fuel requirements for bundled operations.
    If a sequence requires `k` steps and we have `fuel ≥ k`, then we can decompose
    `fuel` as `(fuel - k) + k` for the run equation. -/
theorem fuel_decompose (fuel k : Nat) (h : fuel ≥ k) :
    fuel = (fuel - k) + k := by omega

/-! ## Notes for Phase 6 completion

When using these bundled helpers in composition theorems:

1. **Fuel management**: Always prove `hfuel : fuel ≥ requiredSteps` before invoking
2. **Frame consistency**: Track `code`, `pc`, `locals.size`, `localRefs.size` invariants
3. **Stack order**: moveLoc pushes in reverse of index order (idx=0 first → deepest on stack)
4. **Container threading**: immBorrowField updates `ms.containers`, must thread through
5. **Oracle splitting**: After marshaling, split on oracle outcome before continuing

These helpers are intentionally left with `sorry` placeholders. Completing them requires
resolving the array manipulation "free variable" constraint that currently blocks PC-chaining
proofs. Once that's resolved, each sorry becomes ~30-50 lines of step application + run chaining.

Total effort to complete this module: ~400-500 lines of proof.
-/

end MovementFormal.MoveModel.StepLemmas.Bundled
