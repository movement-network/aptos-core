# Error Diagnosis Guide for CA Formal Verification

**Purpose:** Comprehensive troubleshooting guide for common errors encountered during Confidential Assets formal verification work across all three stacks (Lean, Move Prover, Difftest).

**Audience:** Developers debugging verification failures, build errors, or test failures.

---

## Table of Contents

1. [Lean Compilation Errors](#1-lean-compilation-errors)
2. [Lean Proof Errors](#2-lean-proof-errors)
3. [Lean Performance Issues](#3-lean-performance-issues)
4. [Move Prover Errors](#4-move-prover-errors)
5. [Difftest Failures](#5-difftest-failures)
6. [Cross-Stack Inconsistencies](#6-cross-stack-inconsistencies)
7. [Build System Issues](#7-build-system-issues)
8. [CI Failures](#8-ci-failures)

---

## 1. Lean Compilation Errors

### 1.1 `unknown identifier`

**Error message:**
```
unknown identifier 'registrationState'
```

**Cause:** The identifier is not in scope (not imported or not defined).

**Fix:**
```lean
import MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquiv

open MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquiv
```

**Common occurrences:**
- Forgot to import the module
- Typo in the identifier name
- Identifier is in a different namespace

---

### 1.2 `type mismatch`

**Error message:**
```
type mismatch
  step env frame cs ms
has type
  ExecResult CallStack MachineState : Type
but is expected to have type
  ExecResult CallStack MachineState' : Type
```

**Cause:** The types don't unify (e.g., using `ms` when `ms'` is expected).

**Fix:**
Check the types carefully:
```lean
-- Before mutation
theorem step_before : step env frame cs ms = .ok frame' cs ms := by ...

-- After mutation
theorem step_after : step env frame' cs ms' = ... := by ...
                                          -- ^ Note: ms' not ms
```

**Common occurrences:**
- Using the wrong machine state variable after a mutation (PC that performs `MoveTo`, `MutBorrow`, etc.)
- Type variables not generalizing correctly

---

### 1.3 `maximum recursion depth exceeded`

**Error message:**
```
maximum recursion depth has been exceeded
(use `set_option maxRecDepth <num>` to increase limit)
```

**Cause:** The elaborator is stuck in an infinite recursion (often due to expensive unfolding).

**Fix:**
1. **Don't increase `maxRecDepth`** — that's treating the symptom, not the cause
2. Mark expensive definitions `@[irreducible]`:
   ```lean
   @[irreducible]
   def registrationState (pc : Nat) (...) : Frame := ...
   ```
3. Avoid bare `simp` — use `simp only [...]`

**Common occurrences:**
- Unfurling a large state definition repeatedly
- Circular dependencies in definitions

---

### 1.4 `failed to synthesize instance`

**Error message:**
```
failed to synthesize instance
  Decidable (frame.locals[5]'h = some val)
```

**Cause:** Lean can't automatically infer the type class instance (e.g., `Decidable` for a proposition).

**Fix:**
Provide the instance explicitly or use a different formulation:
```lean
-- Instead of:
have h : frame.locals[5]'h_bounds = some val := by ...

-- Use:
have h : frame.locals.get? 5 = some val := by ...
```

**Common occurrences:**
- Using `Array.getElem` (the `[i]'h` syntax) in complex contexts
- Type class resolution failing for custom types

---

## 2. Lean Proof Errors

### 2.1 `rfl` fails (not definitionally equal)

**Error message:**
```
tactic 'rfl' failed, the left-hand side
  step env frame cs ms
is not definitionally equal to the right-hand side
  .ok frame' cs ms'
```

**Cause:** The two sides differ by more than just computational reduction.

**Fix:**
1. Check if you need more rewrites:
   ```lean
   rw [step_immBorrowLoc_frame]
   rw [registrationState]
   rfl  -- Now they should be equal
   ```
2. Check if the goal is actually provable (might be wrong)

**Common occurrences:**
- Missing a rewrite step
- Using the wrong lemma

---

### 2.2 `cases` produces no goals

**Error message:**
```
tactic 'cases' produced no goals
```

**Cause:** The value being destructed has only one constructor, so there's nothing to split.

**Fix:**
Don't use `cases` on singleton types. Use `rw` or `let` instead:
```lean
-- Instead of:
cases h : some_value

-- Use:
rw [h]  -- if h is an equality
```

**Common occurrences:**
- Trying to case-split on a value that's already known

---

### 2.3 `omega` fails on non-linear arithmetic

**Error message:**
```
omega failed to solve goal
```

**Cause:** `omega` only handles linear arithmetic. Your goal involves multiplication of variables, division, or other non-linear operations.

**Fix:**
1. Simplify the goal to linear form
2. Use `decide` if the goal is decidable
3. Prove the non-linear part separately

**Example:**
```lean
-- omega can't solve: x * y < 100
-- Rewrite to: x < 10 ∧ y < 10 → x * y < 100
-- Prove the implication manually
```

---

### 2.4 `simp` loops indefinitely

**Error message:**
```
(deterministic) timeout at 'whnf', maximum number of heartbeats (200000) has been reached
```

**Cause:** Simp lemmas form a rewrite loop.

**Fix:**
1. **Never use bare `simp`** — always use `simp only [...]` with an explicit lemma list
2. If you must use `simp`, add `maxSteps`:
   ```lean
   simp (config := { maxSteps := 1000 })
   ```

**Common occurrences:**
- Bare `simp` in CA proofs (banned by project conventions)
- Conflicting simp lemmas

---

## 3. Lean Performance Issues

### 3.1 Build takes > 3 minutes per file

**Symptom:** `lake build <File>` exceeds the per-file budget (3 minutes).

**Diagnosis:**
```bash
./scripts/profile_lean_build.sh --file MovementFormal.Experimental.ConfidentialAsset.<Operation>.<File>
```

**Common causes:**

1. **Bare `simp`:**
   ```lean
   -- BAD
   simp

   -- GOOD
   simp only [Frame.pc, Frame.locals, Option.get?]
   ```

2. **Missing `@[irreducible]`:**
   ```lean
   -- BAD
   def statePC0 : Frame := { ... }

   -- GOOD
   @[irreducible]
   def statePC0 : Frame := { ... }
   ```

3. **Bound proofs in theorem statements:**
   ```lean
   -- BAD
   theorem step : ... frame.locals[5]'h ... := by ...

   -- GOOD
   theorem step : frame.locals.get? 5 = some val → ... := by
     intro h
     ...
   ```

**Fix:** Apply the Phase 4 architecture patterns (see `PERFORMANCE_OPTIMIZATION_GUIDE.md`).

---

### 3.2 Memory usage spikes

**Symptom:** `lake build` uses > 8GB RAM, sometimes OOM-kills.

**Diagnosis:**
```bash
/usr/bin/time -l lake build <File>
# Look for "maximum resident set size"
```

**Common causes:**

1. **Large proof terms:** Inline proofs that should be factored out
2. **Mathlib cache miss:** Recompiling mathlib from scratch

**Fix:**
1. Factor out large proofs into separate lemmas
2. Refresh mathlib cache:
   ```bash
   lake exe cache clean
   lake exe cache get
   ```

---

## 4. Move Prover Errors

### 4.1 `Boogie verification failed`

**Error message:**
```
error: post-condition does not hold
  --> confidential_asset.spec.move:42:5
```

**Cause:** Move Prover found a counterexample where the postcondition doesn't hold.

**Diagnosis:**

1. **Check if the spec is correct:**
   - Review the Move implementation
   - Trace through the logic manually

2. **Check for missing aborts:**
   - Does the function abort under certain conditions the spec doesn't account for?

3. **Check for overflow:**
   - Does the spec assume no overflow (e.g., `u64` arithmetic wraps)?

**Fix:**
- If the spec is wrong, relax it to match the implementation
- If the implementation is wrong, fix the implementation

**Example:**
```move
// SPEC SAYS:
ensures sum_balance(store) == sum_balance(old(store)) + amount;

// BUT IMPLEMENTATION:
if (amount > MAX_AMOUNT) abort 196610;  // Missing abort in spec!

// FIX: Add abort condition
aborts_if amount > MAX_AMOUNT with EAMOUNT_TOO_LARGE;
```

---

### 4.2 `cannot infer type`

**Error message:**
```
error: cannot infer type for expression: global<T>(_)
```

**Cause:** Move Prover can't infer the type parameter or address.

**Fix:**
Be explicit:
```move
// Instead of:
let store = global<ConfidentialAssetStore>(_);

// Use:
let owner_addr = signer::address_of(owner);
let store = global<ConfidentialAssetStore>(owner_addr);
```

---

### 4.3 `pragma verify = false` isn't working

**Symptom:** Move Prover still tries to verify a function marked `pragma verify = false`.

**Cause:** The pragma is scoped incorrectly (module-level vs function-level).

**Fix:**
```move
// Function-level (only disables this function):
spec my_function {
    pragma verify = false;
}

// Module-level (disables all functions in module):
spec module {
    pragma verify = false;
}
```

---

### 4.4 Timeout

**Error message:**
```
error: timeout (vc-timeout = 120)
```

**Cause:** The SMT solver (Z3) couldn't prove the property within the time limit.

**Fix:**

1. **Simplify the spec:**
   - Break complex ensures clauses into multiple simpler ones
   - Use `pragma opaque` for expensive functions

2. **Increase timeout (temporary workaround):**
   ```bash
   movement move prove --vc-timeout 300 ...
   ```

3. **Check for quantifiers:**
   - Quantifiers (`forall`, `exists`) are expensive
   - Bound them or remove if possible

---

## 5. Difftest Failures

### 5.1 VM output != Lean model output

**Error message:**
```
FAIL: transfer_happy_path_001
  VM result: { "status": "success", "balance": 4000 }
  Lean result: { "status": "aborted", "abort_code": 196612 }
```

**Cause:** The Lean model and VM disagree on the outcome.

**Diagnosis:**

1. **Check the test case inputs:**
   - Are they valid (e.g., no frozen accounts when the test expects success)?

2. **Check the Lean functional sim:**
   - Does it handle all abort conditions?
   ```lean
   def verifyTransferBytecodeResult (oracle : Oracle) (...) : ExecResult :=
     if sender_store.frozen then
       .aborted 196612  -- ETOKEN_IS_FROZEN
     else ...
   ```

3. **Run the VM execution manually:**
   ```bash
   movement move run --function transfer --args ...
   ```

**Fix:**
- If the Lean model is wrong, update the functional sim
- If the test case is wrong, fix the inputs

---

### 5.2 JSON parse error

**Error message:**
```
Error parsing test case: transfer_happy_path_001.json
  Unexpected token at line 42
```

**Cause:** Malformed JSON.

**Fix:**
Validate the JSON:
```bash
jq . examples/difftest/transfer_happy_path_001.json
```

**Common issues:**
- Missing comma
- Trailing comma (not allowed in JSON)
- Unescaped quotes in strings

---

### 5.3 Test case not found

**Error message:**
```
Error: No test cases found for operation: new_operation
```

**Cause:** The difftest corpus doesn't include test cases for this operation.

**Fix:**
Add test cases:
```bash
# Generate template
./scripts/generate_test_template.sh --operation new_operation --template difftest

# Fill in the template and save to examples/difftest/new_operation_*.json
```

---

## 6. Cross-Stack Inconsistencies

### 6.1 Lean proves P, MSL disproves P

**Symptom:**
- Lean proof builds successfully
- Move Prover reports VC failure for the same property

**Diagnosis:**

1. **Check if they're proving the same property:**
   - Lean: `sum(new_balance) = sum(old_balance)`
   - MSL: `sum_balance(store) == sum_balance(old(store))`

   Are the definitions of `sum` compatible?

2. **Check for different assumptions:**
   - Lean might assume no overflow (`Nat` or `Int` arithmetic)
   - MSL uses `u64` (wraps on overflow)

**Fix:**
Align the assumptions or document the divergence in `TRUST_BOUNDARIES.md`.

---

### 6.2 All stacks pass, but property is wrong

**Symptom:**
- Lean ✅
- MSL ✅
- Difftest ✅
- But manual audit reveals the property is wrong

**Cause:** All three stacks prove the *wrong* property (spec bug, not implementation bug).

**Diagnosis:**
- Review the property in plain English
- Check against the security requirements

**Fix:**
1. Update the property in all three stacks
2. Add a difftest case that would have caught the bug

**Example:**
```
WRONG PROPERTY: "Withdrawal succeeds if proof verifies"
RIGHT PROPERTY: "Withdrawal succeeds if proof verifies AND balance >= amount"

All three stacks proved the wrong property (missing balance check).
```

---

## 7. Build System Issues

### 7.1 `lake build` fails with "unknown package"

**Error message:**
```
error: unknown package 'mathlib4'
```

**Cause:** `lake.exe` cache is stale or `lakefile.lean` is incorrect.

**Fix:**
```bash
lake update
lake exe cache clean
lake exe cache get
```

---

### 7.2 `movement move prove` can't find Boogie

**Error message:**
```
error: Boogie executable not found
```

**Cause:** `BOOGIE_EXE` environment variable not set.

**Fix:**
```bash
movement update prover-dependencies --assume-yes
source ~/.bashrc  # or ~/.zshrc

# Verify
$BOOGIE_EXE -version
```

---

## 8. CI Failures

### 8.1 CI passes locally, fails in CI

**Symptom:**
- `lake build` succeeds locally
- CI job `lean-verification` fails

**Common causes:**

1. **Mathlib cache miss:** CI doesn't have the cache
   - **Fix:** Ensure the CI job runs `lake exe cache get`

2. **Environment differences:** Different Lean version, different OS
   - **Fix:** Check `lean-toolchain` matches locally and in CI

3. **Timeout:** CI has stricter timeouts
   - **Fix:** Optimize the proof (see §3)

---

### 8.2 Axiom-diff CI fails

**Error message:**
```
error: new axioms detected:
  + registration_eval_equiv_singleton_tail
```

**Cause:** A new axiom was introduced.

**Fix:**

1. **If the axiom is intentional:** Update the baseline
   ```bash
   lake env lean --run scripts/check_axioms.sh <Module> > audit/<module>-axioms-baseline.txt
   git add audit/<module>-axioms-baseline.txt
   git commit -m "Update axiom baseline: add <axiom>"
   ```

2. **If the axiom is unintentional:** Remove it (prove the theorem instead)

---

### 8.3 Performance CI fails

**Error message:**
```
error: build time regression detected
  File: Normalization/EvalEquiv.lean
  Expected: < 60s
  Actual: 247s
```

**Cause:** A change introduced a performance regression.

**Fix:**
1. Identify the commit that introduced the regression:
   ```bash
   git bisect start
   git bisect bad HEAD
   git bisect good <last-good-commit>
   # For each bisect step:
   ./scripts/benchmark_verification.sh --file <File>
   git bisect good  # or git bisect bad
   ```

2. Revert the problematic change or optimize it

---

## Summary

**Common error patterns:**

| Error Type | Most Likely Cause | First Thing to Check |
|---|---|---|
| `unknown identifier` | Missing import | Import statement |
| `type mismatch` | Wrong variable after mutation | `ms` vs `ms'` usage |
| `rfl` fails | Missing rewrite | Rewrite chain completeness |
| Timeout (Lean) | Bare `simp` or missing `@[irreducible]` | Tactic usage, definitions |
| VC failure (MSL) | Spec too strong | Spec vs implementation |
| Difftest mismatch | Lean model doesn't match VM | Functional sim abort conditions |
| Cross-stack inconsistency | Different assumptions | Overflow handling, edge cases |
| CI-only failure | Cache miss, environment diff | Mathlib cache, Lean version |

**Debugging workflow:**

1. **Read the error message carefully** (it's usually accurate)
2. **Isolate the failure** (reproduce locally, minimize the test case)
3. **Check the obvious** (typos, missing imports, wrong variables)
4. **Consult this guide** (find the error pattern)
5. **If stuck, ask for help** (provide the full error message + minimal reproduction)

**Resources:**
- `TROUBLESHOOTING_GUIDE.md` — Additional troubleshooting tips
- `INTEGRATION_TESTING_STRATEGY.md` — Cross-stack testing
- `PERFORMANCE_OPTIMIZATION_GUIDE.md` — Build time optimization
- `#formal-verification` Slack channel — Team support

---

## Quick Diagnostic Commands

```bash
# Lean build with verbose output
lake build --verbose MovementFormal.Experimental.ConfidentialAsset.<Module>

# Profile Lean build time
./scripts/profile_lean_build.sh --file <File>

# Check axioms
lake env lean --run scripts/check_axioms.sh <Module>

# Move Prover with verbose output
movement move prove --filter <module> --verbose

# Difftest single operation
./scripts/manage_difftest_corpus.sh run <operation> --verbose

# Compare verification stacks
./scripts/compare_verification_stacks.sh --operation <operation>

# Full verification check
./audit/verify-ca.sh --op <operation> --verbose
```
