# Error Handling and Recovery Patterns: Complete Guide

**Document Status**: Production-Ready  
**Last Updated**: 2026-04-22  
**Target Audience**: Verification engineers, DevOps, proof developers  
**Scope**: Build failures, proof errors, CI recovery, debugging strategies

---

## Table of Contents

1. [Overview](#overview)
2. [Lean Build Errors](#lean-build-errors)
3. [Lean Proof Errors](#lean-proof-errors)
4. [MSL Specification Errors](#msl-specification-errors)
5. [Move Prover Errors](#move-prover-errors)
6. [Difftest Failures](#difftest-failures)
7. [CI/CD Failures](#cicd-failures)
8. [Cross-Stack Consistency Errors](#cross-stack-consistency-errors)
9. [Performance Degradation](#performance-degradation)
10. [Dependency and Toolchain Issues](#dependency-and-toolchain-issues)
11. [Recovery Procedures](#recovery-procedures)
12. [Debugging Strategies](#debugging-strategies)
13. [Prevention Best Practices](#prevention-best-practices)
14. [Error Categories and Severity](#error-categories-and-severity)
15. [Case Studies](#case-studies)
16. [Troubleshooting Decision Trees](#troubleshooting-decision-trees)
17. [Cross-References](#cross-references)

---

## Overview

### Purpose

Formal verification workflows involve multiple complex toolchains (Lean, Move Prover, Difftest, CI/CD). Errors are inevitable. This guide provides systematic approaches to diagnosing, fixing, and preventing common errors.

### Error Categories

**Build errors**: Code doesn't compile (syntax, type errors)  
**Proof errors**: Proof tactics fail (unsolved goals, type mismatches)  
**Specification errors**: Specs invalid or unsolvable (SMT timeouts, false positives)  
**Test failures**: Difftest cases fail (oracle mismatches, VM errors)  
**CI failures**: Workflows fail (timeouts, environment issues, flaky tests)  
**Performance errors**: Builds too slow, exceed resource limits

### Recovery Time Objectives (RTO)

**Critical (CI broken, blocks all PRs)**: <2 hours  
**High (individual blocked)**: <4 hours  
**Medium (degraded performance)**: <24 hours  
**Low (minor issues)**: <1 week

---

## Lean Build Errors

### Error 1: Unknown Identifier

**Symptom**:
```lean
unknown identifier 'transfer_step_lemma'
```

**Causes**:
1. Typo in identifier name
2. Missing import
3. Lemma defined in later section (forward reference)
4. Lemma renamed/deleted in refactoring

**Diagnosis**:
```bash
# Search for definition
grep -r "transfer_step_lemma" lean/
# If found: Check if file imported
# If not found: Likely renamed or deleted
```

**Fixes**:
1. **Typo**: Fix spelling
2. **Missing import**: Add `import MovementFormal.MoveModel.StepLemmas.Transfer`
3. **Forward reference**: Move definition before use, or add `mutual` block
4. **Renamed**: Update to new name (check git log: `git log --all --grep="transfer_step"`)

**Prevention**:
- Use IDE with autocomplete (VS Code + Lean extension)
- Import entire module, not specific theorems (avoids refactoring breakage)

### Error 2: Type Mismatch

**Symptom**:
```lean
type mismatch
  eval_transfer st args
has type
  Result State : Type
but is expected to have type
  Result : Type
```

**Causes**:
1. Function applied to wrong number of arguments
2. Type parameters not inferred correctly
3. Implicit arguments need explicit annotation

**Diagnosis**:
```lean
-- Add type annotations to diagnose
#check eval_transfer  -- Shows expected type
#check eval_transfer st args  -- Shows actual type
```

**Fixes**:
1. **Wrong arguments**: Check function signature, add/remove arguments
2. **Type parameters**: Add explicit `@` annotation: `@eval_transfer State st args`
3. **Implicit arguments**: Use `{ }` for implicit arguments: `eval_transfer {st := st} args`

**Prevention**:
- Use `#check` liberally while developing proofs
- Add type annotations to complex expressions: `(expr : Type)`

### Error 3: Equation Compiler Stuck

**Symptom**:
```lean
equation compiler stuck when trying to match
  match eval_transfer st args with
  | .success st' => ...
  | .aborted code => ...
```

**Causes**:
1. Missing case in pattern match
2. Overlapping patterns
3. Dependent type constraints not satisfied

**Diagnosis**:
```lean
-- Check if Result has more constructors
#print Result
-- Output: inductive Result (α : Type) where
--   | success : α → Result α
--   | aborted : Nat → Result α
-- ✓ All cases covered

-- Check if type parameter causes issue
#check eval_transfer st args  -- What is α?
```

**Fixes**:
1. **Missing case**: Add all constructors
2. **Overlapping**: Reorder patterns (most specific first)
3. **Dependent types**: Add constraints: `match h : eval_transfer st args with`

**Prevention**:
- Use `| _ => sorry` as catch-all while developing (remove before merge)
- Use `cases` tactic instead of `match` in proofs (better error messages)

### Error 4: Maximum Recursion Depth Exceeded

**Symptom**:
```lean
maximum recursion depth has been exceeded
(use 'set_option maxRecDepth <num>' to increase limit)
```

**Causes**:
1. Infinite recursion in definition
2. `simp` loop (lemma simplifies to itself)
3. Type class resolution loop

**Diagnosis**:
```lean
-- Check if definition terminates
#reduce my_function 5  -- Does this finish?

-- Check simp lemmas
set_option trace.simplify true
simp [my_lemma]  -- Does trace show loop?
```

**Fixes**:
1. **Infinite recursion**: Add termination proof with `termination_by` and `decreasing_by`
2. **Simp loop**: Remove problematic simp lemma, or add `simp [-looping_lemma]`
3. **Type class loop**: Increase limit temporarily: `set_option maxRecDepth 10000`, then refactor

**Prevention**:
- Always prove termination for recursive functions
- Test simp lemmas in isolation before adding `@[simp]` attribute

### Error 5: Deterministic Timeout

**Symptom**:
```lean
(deterministic) timeout at elaboration
```

**Causes**:
1. Proof too complex (elaboration time >heartbeat limit)
2. Large term construction (nested `rw` chains)
3. Type inference too hard (deeply nested types)

**Diagnosis**:
```bash
# Build with profiling
lake build --profile MovementFormal.Experimental.ConfidentialAsset.Transfer.EvalEquiv

# Output shows which theorem is slow:
# transfer_eval_equiv: 45.2s elaboration
```

**Fixes**:
1. **Complex proof**: Break into smaller lemmas
2. **Large terms**: Use `conv` tactic to focus rewrites: `conv => rhs; rw [lemma]`
3. **Type inference**: Add explicit type annotations
4. **Temporary**: Increase heartbeat limit: `set_option maxHeartbeats 500000`

**Prevention**:
- Monitor build times (`time lake build`)
- Extract lemmas early (don't wait for timeout)
- See PERFORMANCE_BENCHMARKING_AND_OPTIMIZATION_COMPLETE_GUIDE.md

---

## Lean Proof Errors

### Error 1: Unsolved Goals

**Symptom**:
```lean
unsolved goals
st : State
args : TransferArgs
⊢ eval_transfer st args = eval_bytecode st (transcribe_transfer args)
```

**Causes**:
1. Proof incomplete (forgot to prove goal)
2. Wrong tactic (doesn't make progress)
3. Missing lemma (need to prove subgoal first)

**Diagnosis**:
```lean
-- Check current proof state
theorem my_theorem : ... := by
  intro st args
  -- Add #check here to inspect types
  #check st  -- State
  #check args  -- TransferArgs
  sorry  -- What needs to be proven?
```

**Fixes**:
1. **Incomplete**: Continue proof (use appropriate tactics)
2. **Wrong tactic**: Try different approach (`cases`, `induction`, `rw`, `simp`)
3. **Missing lemma**: Extract as separate lemma, prove first

**Common tactics**:
- `rw [lemma]`: Rewrite using equality
- `simp [lemma1, lemma2]`: Simplify with lemmas
- `intro x`: Introduce hypothesis/variable
- `cases h`: Case analysis on h
- `induction h`: Induction on h
- `exact proof`: Provide explicit proof term

**Prevention**:
- Work incrementally (prove one step at a time)
- Use `sorry` as placeholder, come back later

### Error 2: Tactic Failed

**Symptom**:
```lean
tactic 'rewrite' failed, did not find instance of the pattern
  eval_transfer ?st ?args
```

**Causes**:
1. Pattern doesn't match goal exactly
2. Lemma not applicable (type mismatch)
3. Implicit arguments different

**Diagnosis**:
```lean
-- Check if pattern matches
#check eval_transfer st args  -- Actual term
#check my_lemma  -- Lemma pattern
-- Compare types and arguments
```

**Fixes**:
1. **Pattern mismatch**: Use `conv` to focus: `conv => lhs; rw [lemma]`
2. **Type mismatch**: Add type annotations or use `@lemma` with explicit args
3. **Implicit args**: Use `rw [@lemma State st args]`

**Prevention**:
- State lemmas generally (avoid over-specific patterns)
- Test lemmas before using in large proofs

### Error 3: Type Mismatch in Proof

**Symptom**:
```lean
application type mismatch
  transfer_step st args
argument
  args
has type
  TransferArgs : Type
but is expected to have type
  RegisterArgs : Type
```

**Causes**:
1. Wrong function/lemma applied
2. Copy-paste error (copied from different protocol)
3. Refactoring changed types

**Diagnosis**:
```lean
#check transfer_step  -- Expected type
#check args  -- Actual type
-- Confirm args is TransferArgs, not RegisterArgs
```

**Fixes**:
1. **Wrong function**: Use correct function for this protocol
2. **Copy-paste**: Check surrounding context, ensure consistency
3. **Refactoring**: Update to new types

**Prevention**:
- Use IDE type hints (hover over variables)
- Add explicit type annotations in complex proofs

### Error 4: Failed to Synthesize Instance

**Symptom**:
```lean
failed to synthesize instance
  DecidableEq State
```

**Causes**:
1. Type class not defined for custom type
2. Import missing
3. Instance not in scope

**Diagnosis**:
```bash
# Search for instance definition
grep -r "instance.*DecidableEq State" lean/
```

**Fixes**:
1. **Not defined**: Add instance:
   ```lean
   instance : DecidableEq State := by
     unfold State; infer_instance
   ```
2. **Missing import**: Import module with instance definition
3. **Not in scope**: Open namespace: `open DecidableEq`

**Prevention**:
- Define standard instances for all custom types (Eq, Ord, ToString, etc.)

---

## MSL Specification Errors

### Error 1: Aborts-If Not Exhaustive

**Symptom**:
```move
error: abort not covered by any of the `aborts_if` clauses
at line 42: assert!(sender_balance >= amount, E_INSUFFICIENT_BALANCE);
```

**Causes**:
1. Missing `aborts_if` clause
2. Clause condition too specific (doesn't cover all cases)
3. Wrong error code in clause

**Diagnosis**:
```move
// Check all assert! statements in function
// Ensure each has corresponding aborts_if

public fun transfer(...) {
    assert!(exists<ConfidentialBalance>(sender), E_NOT_REGISTERED);  // Need aborts_if
    assert!(verify_proof(proof), E_INVALID_PROOF);  // Need aborts_if
    assert!(sender_balance >= amount, E_INSUFFICIENT_BALANCE);  // Need aborts_if (MISSING!)
}
```

**Fixes**:
Add missing `aborts_if` clause:
```move
spec transfer {
    aborts_if !exists<ConfidentialBalance>(sender) with E_NOT_REGISTERED;
    aborts_if !verify_proof(proof) with E_INVALID_PROOF;
    aborts_if sender_balance < amount with E_INSUFFICIENT_BALANCE;  // ✓ Add this
}
```

**Prevention**:
- Use `pragma aborts_if_is_strict;` to enforce exhaustiveness
- Review all `assert!` statements when writing specs

### Error 2: Postcondition Does Not Hold

**Symptom**:
```move
error: post-condition does not hold
ensures sender_balance_post = sender_balance_pre - amount;
```

**Causes**:
1. Spec incorrect (doesn't match implementation)
2. Implementation has bug
3. Helper function spec missing (Move Prover can't verify)

**Diagnosis**:
1. **Read implementation**: Does it actually update `sender_balance` by `-amount`?
2. **Check helper functions**: Does `subtract_balance` have spec?
3. **Add intermediate assertion**: `assert sender_balance == sender_balance_old - amount;` in code

**Fixes**:
1. **Spec incorrect**: Fix spec to match implementation
2. **Implementation bug**: Fix implementation
3. **Missing helper spec**: Add spec for helper function

**Example** (missing helper spec):
```move
// Helper function without spec (causes verification failure)
fun subtract_balance(balance: vector<u8>, amount: u64): vector<u8> {
    // ... complex implementation
}

// Add spec for helper:
spec subtract_balance {
    ensures result == balance_as_int(balance) - amount;  // ✓ Now verifiable
}
```

**Prevention**:
- Spec all helper functions, not just public entry points
- Use `aptos move prove --trace` to see verification details

### Error 3: SMT Timeout

**Symptom**:
```move
error: timeout in SMT solver (after 60s)
spec transfer {
    ensures forall i in 0..len(balance): balance[i] < MAX_VALUE;
}
```

**Causes**:
1. Unbounded quantifier (SMT solver explores too many cases)
2. Complex postcondition (nested implications, large conjunctions)
3. Missing trigger for quantifier

**Diagnosis**:
```move
// Simplify spec to isolate issue
spec transfer {
    // Comment out clauses one by one to find culprit
    // ensures clause_1;  // Fast
    // ensures clause_2;  // Fast
    ensures clause_3;  // TIMEOUT - this is the problem
}
```

**Fixes**:
1. **Unbounded quantifier**: Add bounds/triggers:
   ```move
   // BAD: No trigger
   ensures forall x: address: has_balance(x) ==> balance_valid(x);
   
   // GOOD: Add trigger
   ensures forall x: address where has_balance(x): balance_valid(x);
   ```

2. **Complex postcondition**: Split into multiple clauses:
   ```move
   // BAD: Large conjunction
   ensures A && B && C && D && E;
   
   // GOOD: Separate clauses
   ensures A;
   ensures B;
   ensures C;
   ensures D;
   ensures E;
   ```

3. **Increase timeout** (last resort):
   ```move
   spec transfer {
       pragma verify_duration_estimate = 120;  // 2 minutes
       // Justification: Complex range proof verification requires extra time
       ensures ...;
   }
   ```

**Prevention**:
- Avoid quantifiers if possible (use concrete properties)
- Keep specs simple (prefer many simple clauses over few complex ones)

### Error 4: Spec Helper Function Not Defined

**Symptom**:
```move
error: unbound name 'balance_as_int'
```

**Causes**:
1. Spec helper function not defined
2. Typo in function name
3. Function defined in wrong module

**Diagnosis**:
```bash
# Search for definition
grep -r "spec fun balance_as_int" aptos-experimental/sources/
```

**Fixes**:
1. **Not defined**: Define spec helper:
   ```move
   spec module {
       fun balance_as_int(balance: vector<u8>): num {
           // ... interpretation of encrypted balance as integer
       }
   }
   ```

2. **Typo**: Fix spelling

3. **Wrong module**: Import or move to correct module

**Prevention**:
- Define spec helpers in same file as related specs
- Use descriptive names (avoid typos)

---

## Move Prover Errors

### Error 1: Boogie Backend Failure

**Symptom**:
```
Error: Boogie verification failed with exit code 1
```

**Causes**:
1. Move Prover internal error (bug in tool)
2. Spec too complex for backend
3. Z3 crash

**Diagnosis**:
```bash
# Run with verbose output
aptos move prove --verbose

# Check Z3 version
z3 --version
```

**Fixes**:
1. **Tool bug**: Report to Move team, disable verification for this spec: `pragma verify = false;`
2. **Too complex**: Simplify spec (remove quantifiers, split conjunctions)
3. **Z3 crash**: Update Z3, or use CVC5 backend: `aptos move prove --backend cvc5`

**Prevention**:
- Keep specs simple
- Update Move Prover regularly

### Error 2: No Supported Z3 Version Found

**Symptom**:
```
Error: Z3 version 4.8.12 not supported (need 4.8.14 or later)
```

**Causes**:
1. Outdated Z3 installation
2. Wrong Z3 in PATH

**Diagnosis**:
```bash
which z3  # Where is Z3?
z3 --version  # What version?
```

**Fixes**:
```bash
# Install correct Z3 version
wget https://github.com/Z3Prover/z3/releases/download/z3-4.8.14/z3-4.8.14-x64-ubuntu-20.04.zip
unzip z3-4.8.14-x64-ubuntu-20.04.zip
sudo mv z3-4.8.14-x64-ubuntu-20.04/bin/z3 /usr/local/bin/
z3 --version  # Verify: 4.8.14
```

**Prevention**:
- Pin Z3 version in reproducible build (Docker, Nix)
- Document required version in README

---

## Difftest Failures

### Error 1: Oracle Mock Mismatch

**Symptom**:
```rust
assertion failed: `(left == right)`
  left: `Success`,
 right: `Aborted(100)`
```

**Causes**:
1. Oracle mock doesn't match Lean specification
2. Test setup incorrect (missing mock setup)
3. Oracle behavior changed (Lean spec updated, mock not)

**Diagnosis**:
```rust
// Add debug logging
println!("Oracle returned: {:?}", oracle_mock.verify(&pk, &msg, &sig));
println!("Expected: true (valid proof)");

// Check mock setup
println!("Valid keys registered: {:?}", oracle_mock.valid_keys);
```

**Fixes**:
1. **Mock mismatch**: Update mock to match Lean spec
2. **Setup incorrect**: Add mock registration:
   ```rust
   let mut oracle_mock = SchnorrOracleMock::new();
   oracle_mock.register_key(pk, sk);  // ✓ Add this
   ```
3. **Spec changed**: Update mock to reflect new Lean spec

**Prevention**:
- Link mock to Lean spec in comments
- Automated test: Compare mock behavior to Lean symbolic evaluation

### Error 2: VM Execution Error

**Symptom**:
```rust
VMStatus: MoveAbort { location: Module(transfer), code: 100, info: None }
```

**Causes**:
1. Test input invalid (triggers abort)
2. Test expects success, but input causes abort
3. VM state not set up correctly

**Diagnosis**:
```rust
// Check test input
println!("Transfer amount: {}", amount);
println!("Sender balance: {}", sender_balance);
// Is amount > sender_balance? Would trigger E_INSUFFICIENT_BALANCE

// Check VM state
println!("Sender registered: {}", vm.has_resource::<ConfidentialBalance>(sender));
```

**Fixes**:
1. **Invalid input**: Fix test input (ensure valid for happy path)
2. **Wrong expectation**: Change expected result to `Aborted(100)`
3. **State setup**: Add missing resource:
   ```rust
   vm.create_resource(sender, ConfidentialBalance { balance: vec![...] });
   ```

**Prevention**:
- Use property-based testing to generate valid inputs
- Validate test setup before execution

### Error 3: Property-Based Test Failure

**Symptom**:
```rust
Test failed for input: TransferArgs { amount: 18446744073709551615, ... }
Seed: 0x1234abcd
```

**Causes**:
1. Edge case not handled (e.g., u64::MAX)
2. Oracle mock doesn't handle edge case
3. Actual bug in implementation

**Diagnosis**:
```rust
// Reproduce with minimal case
#[test]
fn test_transfer_max_amount() {
    let result = vm_execute_transfer(TransferArgs {
        amount: u64::MAX,
        ...
    });
    // Does this fail? Why?
}
```

**Fixes**:
1. **Edge case**: Add bounds to property generator:
   ```rust
   prop::strategy::Just(1..u64::MAX - 1000)  // Avoid overflow
   ```
2. **Mock issue**: Fix mock to handle edge case
3. **Implementation bug**: Fix implementation, validate with Lean proof

**Prevention**:
- Define reasonable bounds for property generators
- Add explicit edge case tests (0, 1, MAX, MAX-1)

---

## CI/CD Failures

### Error 1: CI Timeout

**Symptom**:
```yaml
Error: Job exceeded maximum execution time (15 minutes)
```

**Causes**:
1. Build time increased (more proofs, slower proofs)
2. CI runner slow (resource contention)
3. Cache miss (rebuilding dependencies)

**Diagnosis**:
```yaml
# Check job timing in GitHub Actions
# Click on failed job, expand steps:
# - Checkout: 10s
# - Cache restore: 2min
# - Lake build: 25min (TIMEOUT!)

# Check cache hit rate
Cache restored: No (cache miss)
```

**Fixes**:
1. **Build time increase**: Optimize slow proofs (see PERFORMANCE guide)
2. **Slow runner**: Retry job, or request more resources
3. **Cache miss**: Check cache key (did `lean-toolchain` change?)

**Temporary workaround**:
```yaml
# Increase timeout in workflow
timeout-minutes: 30  # Was 15
```

**Prevention**:
- Monitor build time trends (alert if >10% increase)
- Optimize proofs before merge (performance gate)

### Error 2: Cache Corrupted

**Symptom**:
```
Error: Unable to restore cache (corrupted tar archive)
```

**Causes**:
1. Partial upload (network interruption)
2. Disk full during cache creation
3. Race condition (multiple jobs writing same cache)

**Diagnosis**:
```bash
# Check cache size
# In GitHub Actions: Settings -> Actions -> Caches
# Look for unusually small cache (partial upload)
```

**Fixes**:
1. **Corrupted cache**: Delete and regenerate:
   ```yaml
   # In GitHub Actions UI: Delete cache with key lean-cache-*
   # Next run will regenerate
   ```
2. **Prevent race**: Use unique cache keys per job:
   ```yaml
   key: ${{ runner.os }}-lean-${{ github.sha }}-${{ hashFiles('lakefile.lean') }}
   ```

**Prevention**:
- Use `fail-if-no-match: false` (continue even if cache restore fails)
- Monitor cache health (alert on corruption)

### Error 3: Dependency Download Failure

**Symptom**:
```
Error: Failed to download mathlib (connection timeout)
```

**Causes**:
1. Network issue (GitHub/Mathlib server down)
2. Rate limiting (too many requests)
3. Wrong URL (repository moved)

**Diagnosis**:
```bash
# Check if URL accessible
curl -I https://github.com/leanprover-community/mathlib4

# Check rate limit
curl -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/rate_limit
```

**Fixes**:
1. **Transient**: Retry job
2. **Rate limit**: Use GITHUB_TOKEN for authentication:
   ```yaml
   - name: Download dependencies
     env:
       GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
     run: lake update
   ```
3. **URL changed**: Update `lakefile.lean` with new URL

**Prevention**:
- Use retry action for downloads:
   ```yaml
   - uses: nick-invision/retry@v2
     with:
       timeout_minutes: 10
       max_attempts: 3
       command: lake update
   ```

### Error 4: Flaky Test

**Symptom**:
```
Test failed: test_transfer_concurrent
(Passes on retry)
```

**Causes**:
1. Non-deterministic test (random seed, timing-dependent)
2. Shared state between tests
3. Resource leak (file descriptors, memory)

**Diagnosis**:
```rust
// Run test 100 times
for run in 1..100
    cargo test test_transfer_concurrent --seed $run
done
# Does it fail randomly? Flaky test!
```

**Fixes**:
1. **Non-deterministic**: Fix seed:
   ```rust
   let mut rng = StdRng::seed_from_u64(42);  // Fixed seed
   ```
2. **Shared state**: Isolate tests (separate VM instances)
3. **Resource leak**: Add cleanup:
   ```rust
   #[test]
   fn test_transfer() {
       let vm = setup_vm();
       // ... test logic
       vm.cleanup();  // ✓ Explicit cleanup
   }
   ```

**Prevention**:
- Never use `rand::thread_rng()` in tests (non-deterministic)
- Run tests with `--test-threads=1` to detect shared state issues

---

## Cross-Stack Consistency Errors

### Error 1: Abort Code Mismatch

**Symptom**:
```
❌ Abort code alignment check FAILED
MSL uses code 101, Lean uses 102 for E_INSUFFICIENT_BALANCE
```

**Causes**:
1. Copy-paste error (wrong code in one stack)
2. Refactoring (changed code in Move, forgot to update Lean/MSL)
3. Different error constant used

**Diagnosis**:
```bash
# Check each stack:
# Move:
grep "E_INSUFFICIENT_BALANCE" aptos-experimental/sources/*.move
# Output: const E_INSUFFICIENT_BALANCE: u64 = 102;

# MSL:
grep "E_INSUFFICIENT_BALANCE" aptos-experimental/sources/*.spec.move
# Output: aborts_if ... with 101  // ✗ WRONG!

# Lean:
grep "insufficient_balance" lean/MovementFormal/Experimental/ConfidentialAsset/
# Output: .aborted 102
```

**Fixes**:
Fix incorrect stack (MSL):
```move
spec transfer {
    aborts_if sender_balance < amount with 102;  // ✓ Changed from 101
}
```

**Prevention**:
- CI runs `check_abort_alignment.sh` on every PR
- Use named constants in all stacks (not magic numbers)

### Error 2: Function Signature Mismatch

**Symptom**:
```
❌ Function signature mismatch: transfer
Move: (sender: &signer, receiver: address, amount: u64, proof: TransferProof)
Lean: (sender: Address, receiver: Address, amount: U64)  // Missing proof parameter!
```

**Causes**:
1. Lean transcription incomplete (forgot parameter)
2. Function refactored (parameter added/removed in Move, Lean not updated)

**Diagnosis**:
```lean
-- Check Lean definition
def eval_transfer (sender : Address) (receiver : Address) (amount : U64) : Result :=
  -- Only 3 parameters, Move has 4!
```

**Fixes**:
Add missing parameter to Lean:
```lean
def eval_transfer 
    (sender : Address) 
    (receiver : Address) 
    (amount : U64)
    (proof : TransferProof)  -- ✓ Add this
    : Result := ...
```

Update all callers and proofs.

**Prevention**:
- CI runs `check_function_signatures.py` on every PR
- Automated transcription (generate Lean from Move bytecode)

---

## Performance Degradation

### Error 1: Sudden Build Time Increase

**Symptom**:
```
Lean build time: 3.2s → 45.8s (14× slower)
```

**Causes**:
1. New proof with quadratic complexity
2. Simp loop introduced
3. Large term construction

**Diagnosis**:
```bash
# Profile build
lake build --profile MovementFormal.Experimental.ConfidentialAsset.Transfer.EvalEquiv

# Output:
# transfer_eval_equiv: 42.3s elaboration
#   |- step_1: 0.1s
#   |- step_2: 41.8s  # ✗ Culprit!
#   |- step_3: 0.4s
```

**Fixes**:
See PERFORMANCE_BENCHMARKING_AND_OPTIMIZATION_COMPLETE_GUIDE.md:
- Extract lemmas
- Use `conv` instead of nested `rw`
- Replace `simp [*]` with targeted simplification

**Prevention**:
- CI performance gate blocks PRs with >10% regression
- Monitor build time dashboard (Grafana)

### Error 2: CI Duration Creep

**Symptom**:
```
CI duration: 13min → 18min → 25min (over 3 months)
```

**Causes**:
1. More proofs added (expected growth)
2. Proofs getting slower (unexpected)
3. Cache effectiveness decreased

**Diagnosis**:
```bash
# Check historical CI times
gh run list --workflow=lean-ci.yaml --limit 30 | awk '{print $3, $7}'

# Output:
# 2026-04-01: 13min
# 2026-04-08: 14min
# 2026-04-15: 17min
# 2026-04-22: 25min  # Sudden jump on 4/15
```

**Fixes**:
1. **More proofs**: Expected, but optimize if CI >15min
2. **Slower proofs**: Profile and optimize (see performance guide)
3. **Cache issues**: Regenerate cache, check cache key

**Prevention**:
- Weekly review of CI duration trend
- Alert if >15min (action required)

---

## Dependency and Toolchain Issues

### Error 1: Lean Version Mismatch

**Symptom**:
```
Error: Lean version mismatch
  lakefile.lean requires: leanprover/lean4:v4.14.0
  current version: v4.12.0
```

**Causes**:
1. Wrong Lean version installed
2. Multiple Lean versions (wrong one in PATH)
3. Lean toolchain file incorrect

**Diagnosis**:
```bash
lean --version  # Current version
cat lean-toolchain  # Required version
```

**Fixes**:
```bash
# Install correct version via elan
elan install leanprover/lean4:v4.14.0
elan default leanprover/lean4:v4.14.0

lean --version  # Verify: v4.14.0
```

**Prevention**:
- Use elan (manages Lean versions automatically)
- CI uses lean-toolchain file (ensures correct version)

### Error 2: Mathlib Out of Date

**Symptom**:
```
Error: Could not find declaration 'Mathlib.Data.Vector.Lemmas.append_assoc'
(function moved/renamed in latest Mathlib)
```

**Causes**:
1. Mathlib updated, broke compatibility
2. `lake-manifest.json` out of date (dependencies not pinned)

**Diagnosis**:
```bash
# Check current Mathlib version
cat lake-manifest.json | grep mathlib4
# Output: "rev": "abc123..."

# Check if declaration exists in current version
cd .lake/packages/mathlib4
git log --all --grep="append_assoc"
```

**Fixes**:
1. **Update code**: Find new location of declaration
   ```lean
   -- Old: import Mathlib.Data.Vector.Lemmas
   -- New: import Mathlib.Data.Vector.Basic
   ```

2. **Pin Mathlib version**: Lock to working version
   ```bash
   lake update mathlib4@<commit>
   git add lake-manifest.json
   git commit -m "Pin Mathlib version"
   ```

**Prevention**:
- Pin dependencies in `lake-manifest.json`
- Update dependencies in controlled manner (not automatically)

### Error 3: Rust Version Incompatibility

**Symptom**:
```
error: package `difftest v0.1.0` cannot be built because it requires rustc 1.82.0 or newer
```

**Causes**:
1. Outdated Rust version
2. CI using wrong Rust version

**Diagnosis**:
```bash
rustc --version  # Current: 1.80.0
cat rust-toolchain.toml  # Required: 1.82.0
```

**Fixes**:
```bash
# Update Rust via rustup
rustup update
rustc --version  # Verify: 1.82.0

# OR install specific version
rustup install 1.82.0
rustup default 1.82.0
```

**Prevention**:
- Use `rust-toolchain.toml` (rustup reads automatically)
- Pin Rust version in CI

---

## Recovery Procedures

### Procedure 1: Broken Main Branch (CI Failing)

**Severity**: Critical  
**RTO**: <2 hours

**Steps**:
1. **Identify commit** that broke main:
   ```bash
   git log --oneline --graph -10  # Recent commits
   # Check CI status of each commit in GitHub
   ```

2. **Options**:
   - **Option A (prefer)**: Fix forward (if fix is simple)
     ```bash
     # Create fix, open PR with "HOTFIX" label
     # Fast-track review (<2h), merge
     ```
   
   - **Option B**: Revert commit
     ```bash
     git revert <breaking-commit>
     git push origin main
     # CI should pass now
     ```

3. **Communicate**:
   - Post in Slack `#ca-verification`: "Main branch broken by commit X, working on fix"
   - Update when fixed: "Main branch fixed, CI passing"

4. **Post-mortem**:
   - Why did CI not catch this before merge?
   - Add test/check to prevent recurrence

### Procedure 2: Lost Work (Accidental Reset/Delete)

**Severity**: High  
**RTO**: <4 hours

**Steps**:
1. **Check reflog** (git tracks all local changes):
   ```bash
   git reflog
   # Output shows all recent HEAD movements
   # Find commit before accident
   ```

2. **Recover**:
   ```bash
   git reset --hard HEAD@{5}  # Reset to 5 moves ago
   # OR create branch from lost commit:
   git branch recovery-branch abc123
   ```

3. **If reflog doesn't help**:
   - Check local `.git/ORIG_HEAD` (tracks previous HEAD)
   - Check CI artifacts (if pushed before accident)
   - Check teammate's clone (if they pulled your branch)

**Prevention**:
- Push work-in-progress frequently (backup on remote)
- Never use `git reset --hard` or `git clean -f` unless certain

### Procedure 3: Corrupted Lean Build Cache

**Severity**: Medium  
**RTO**: <1 hour

**Steps**:
1. **Clean cache**:
   ```bash
   lake clean
   rm -rf .lake/build .lake/packages
   ```

2. **Rebuild dependencies**:
   ```bash
   lake update  # Download dependencies
   lake build   # Rebuild all
   ```

3. **If still failing**:
   - Check disk space: `df -h`
   - Check file permissions: `ls -la .lake/`
   - Delete and re-clone repo (last resort)

**Prevention**:
- Regularly clean build artifacts (weekly)
- Monitor disk space usage

---

## Debugging Strategies

### Strategy 1: Binary Search (Proof Breaks After Refactoring)

**Scenario**: Large proof worked before refactoring, now fails with cryptic error

**Process**:
1. **Isolate failure**: Comment out half the proof
   - If succeeds: Problem in commented-out half
   - If fails: Problem in active half
2. **Repeat**: Binary search until minimal failing case found
3. **Fix**: Address minimal case

**Example**:
```lean
theorem big_proof : ... := by
  step_1  -- Works
  step_2  -- Works
  step_3  -- Works
  step_4  -- FAILS? Try commenting out 5-8
  step_5
  step_6
  step_7
  step_8
  
-- After binary search: step_6 is culprit
```

### Strategy 2: Simplification (Complex Error Message)

**Scenario**: Type error with 500-line message

**Process**:
1. **Extract subterm**: Isolate failing expression
2. **Add type annotations**: Help type checker
3. **Check subterm types**: Use `#check`

**Example**:
```lean
-- Fails with cryptic error:
theorem complex : ... := by
  exact (big_expression_with_20_subterms)
  
-- Debug:
#check big_expression_with_20_subterms
-- Error: type mismatch in subterm 15

-- Fix subterm 15:
#check (subterm_15 : ExpectedType)  -- Add annotation
exact (big_expression_with_fixed_subterm_15)  -- ✓ Works
```

### Strategy 3: Differential Debugging (Works Locally, Fails in CI)

**Scenario**: Proof builds locally, fails in CI

**Process**:
1. **Compare environments**:
   - Lean version: `lean --version`
   - Dependencies: `cat lake-manifest.json`
   - Seed: Some proofs depend on elaboration order (non-deterministic)

2. **Reproduce CI environment**:
   ```bash
   # Use Docker image from CI
   docker run -v $(pwd):/workspace movement/ci-lean:latest
   cd /workspace
   lake build  # Does it fail now?
   ```

3. **Fix**:
   - If version mismatch: Update local version
   - If non-deterministic: Make proof deterministic (explicit type annotations, no auto-instances)

### Strategy 4: Minimization (Property-Based Test Failure)

**Scenario**: Proptest fails with complex input

**Process**:
1. **Proptest outputs seed**: `Seed: 0x1234abcd`
2. **Reproduce with seed**:
   ```rust
   #[test]
   fn test_minimal_repro() {
       let mut rng = StdRng::seed_from_u64(0x1234abcd);
       // Generate same input that failed
   }
   ```
3. **Minimize input**: Reduce to smallest failing case
4. **Fix**: Address minimal case

---

## Prevention Best Practices

### Practice 1: Incremental Development

**DO**:
- Commit frequently (every 30 min - 1 hour)
- Push work-in-progress (even if incomplete)
- Test locally before pushing

**DON'T**:
- Work for days without committing
- Make large refactorings without backups
- Skip local testing ("CI will catch it")

### Practice 2: Defensive Coding

**DO**:
- Add type annotations proactively
- Test edge cases explicitly
- Document assumptions

**DON'T**:
- Rely on type inference for complex types
- Assume inputs are always valid
- Leave axioms undocumented

### Practice 3: Monitoring and Alerts

**Setup**:
- Grafana dashboard for build times
- Slack alerts for CI failures
- Weekly review of metrics

**Thresholds**:
- Build time >3s per protocol: Alert
- CI duration >15min: Alert
- Any CI failure on main: Immediate alert

### Practice 4: Reproducible Environments

**DO**:
- Use Docker for CI (pinned versions)
- Pin all dependencies (`lake-manifest.json`, `rust-toolchain.toml`)
- Document setup in README

**DON'T**:
- Use `latest` tags (non-deterministic)
- Install tools without version pinning
- Rely on global system installations

---

## Error Categories and Severity

### Severity Levels

**Critical** (CI broken, blocks all work):
- Main branch CI failing
- Reproducible build broken (auditors blocked)
- Security vulnerability discovered
- **RTO**: <2 hours

**High** (individual blocked):
- Proof failing to build (developer stuck)
- Move Prover crash (can't verify specs)
- Difftest suite broken (can't validate)
- **RTO**: <4 hours

**Medium** (degraded performance):
- Build time 2× slower (annoying but works)
- Flaky tests (occasional failures)
- Documentation out of date
- **RTO**: <24 hours

**Low** (minor issues):
- Unused lemmas (code cleanup)
- Suboptimal proof (works but could be better)
- Warning messages (non-blocking)
- **RTO**: <1 week

### Error Category Matrix

| Category | Examples | Severity | Recovery |
|----------|----------|----------|----------|
| **Syntax** | Unknown identifier, type mismatch | High | Fix code, usually easy |
| **Logic** | Unsolved goals, proof incorrect | High | Requires proof expertise |
| **Performance** | Timeout, slow build | Medium | Optimization required |
| **Tooling** | SMT timeout, Boogie crash | High | Simplify spec or report bug |
| **Environment** | Version mismatch, missing dependency | Medium | Update environment |
| **CI/CD** | Pipeline failure, cache corruption | Critical (if main) | Fix workflow or retry |

---

## Case Studies

### Case Study 1: Quadratic Elaboration (42s → 2.1s)

**Context**: Transfer proof timing out after adding abort case

**Symptoms**:
```lean
theorem transfer_eval_equiv : ... := by
  unfold eval_transfer
  rw [step_1, step_2, step_3, ...]  -- 30 nested rewrites
  simp [State.update, Balance.add, Balance.sub, ...]  -- 50 simp lemmas
  -- Build time: 42s (was 2.8s before)
```

**Diagnosis**: Profiling showed `rw` tactic consuming 38s

**Fix**: Extract lemma, use `conv`:
```lean
lemma transfer_unfold : eval_transfer st args = ... := by
  unfold eval_transfer; rfl

theorem transfer_eval_equiv : ... := by
  rw [transfer_unfold]  -- Single rewrite
  -- Build time: 2.1s ✓
```

**Lesson**: Avoid nested rewrites, extract equational lemmas

### Case Study 2: Flaky Difftest (Random Failures)

**Context**: `test_transfer_concurrent` fails ~10% of time

**Symptoms**:
```rust
Test passed: run 1, 2, 3, 4
Test FAILED: run 5
Test passed: run 6, 7
Test FAILED: run 8
```

**Diagnosis**: Using `rand::thread_rng()` (non-deterministic seed)

**Fix**: Fix seed:
```rust
let mut rng = StdRng::seed_from_u64(42);  // Deterministic
```

**Verification**: Ran test 1000× consecutively, 100% pass rate

**Lesson**: Never use non-deterministic randomness in tests

### Case Study 3: Axiom Soundness Issue (Caught in Review)

**Context**: PR adds Bulletproofs axiom

**Symptoms**: Axiom states completeness only, no soundness

**Review catch**:
> "This axiom allows adversary to create proof for any value! Need soundness property."

**Fix**: Add soundness axiom:
```lean
axiom bulletproofs_soundness :
  bulletproofs_verify comm proof = true →
  ∃ value blinding, comm = commit value blinding ∧ value ∈ [0, 2^64)
```

**Lesson**: Crypto expert review essential for axioms

---

## Troubleshooting Decision Trees

### Decision Tree: Lean Build Failure

```
Lean build fails
├─ Syntax error ("unknown identifier")
│  ├─ Typo? → Fix spelling
│  └─ Missing import? → Add import
├─ Type error ("type mismatch")
│  ├─ Add type annotations
│  └─ Check function signature (#check)
├─ Timeout ("deterministic timeout")
│  ├─ Profile (--profile)
│  ├─ Extract lemmas
│  └─ Use conv tactic
└─ Recursion depth ("maximum recursion")
   ├─ Simp loop? → Remove problematic lemma
   └─ Infinite recursion? → Add termination proof
```

### Decision Tree: MSL Verification Failure

```
Move Prover fails
├─ Aborts-if not exhaustive
│  └─ Add missing aborts_if clause
├─ Postcondition does not hold
│  ├─ Spec wrong? → Fix spec
│  ├─ Implementation wrong? → Fix code
│  └─ Helper spec missing? → Add helper spec
├─ SMT timeout
│  ├─ Unbounded quantifier? → Add trigger/bounds
│  ├─ Complex clause? → Split into multiple
│  └─ Increase timeout (last resort)
└─ Boogie crash
   ├─ Simplify spec
   └─ Report bug to Move team
```

### Decision Tree: CI Failure

```
CI fails
├─ Build timeout
│  ├─ Profile build time
│  ├─ Optimize slow proofs
│  └─ Increase timeout (temporary)
├─ Test failure
│  ├─ Flaky test? → Fix seed/state
│  └─ Real failure? → Fix implementation
├─ Cache corrupted
│  └─ Delete cache, regenerate
└─ Dependency download failure
   ├─ Retry job
   └─ Check network/rate limits
```

---

## Cross-References

**Related guides**:
- **PERFORMANCE_BENCHMARKING_AND_OPTIMIZATION_COMPLETE_GUIDE.md**: Build time optimization, profiling
- **COLLABORATIVE_VERIFICATION_WORKFLOWS_AND_TEAM_PROCESSES_GUIDE.md**: Team recovery procedures, escalation
- **PROOF_REVIEW_AND_QUALITY_ASSURANCE_COMPREHENSIVE_GUIDE.md**: Preventing errors via review
- **REPRODUCIBLE_BUILDS_AND_DETERMINISM_COMPLETE_GUIDE.md**: Environment issues, dependency pinning
- **CROSS_LAYER_VALIDATION_AND_RECONCILIATION_AUTOMATION_GUIDE.md**: Cross-stack consistency errors

**Debugging tools**:
- `lake build --profile`: Profile Lean build time
- `#check`: Inspect types in Lean
- `aptos move prove --trace`: Verbose Move Prover output
- `cargo test -- --nocapture`: Show println! in tests
- `git reflog`: Recover lost commits

**Recovery scripts**:
- `scripts/clean_all.sh`: Clean all build artifacts
- `scripts/rebuild_cache.sh`: Regenerate CI cache
- `audit/reconcile_all.sh`: Check cross-stack consistency

---

## Summary

This guide provides systematic error handling and recovery:

1. **Error categories**: Build, proof, spec, test, CI, performance, tooling
2. **Lean errors**: Unknown identifier (import), type mismatch (annotations), timeout (extract lemmas), recursion (simp loops)
3. **MSL errors**: Aborts-if missing (add clause), postcondition false (fix spec/code), SMT timeout (add triggers)
4. **Difftest errors**: Oracle mismatch (update mock), VM error (check state), proptest failure (edge cases)
5. **CI errors**: Timeout (optimize/retry), cache corrupt (regenerate), dependency failure (retry/pin)
6. **Cross-stack errors**: Abort code mismatch (align), signature mismatch (update Lean)
7. **Recovery procedures**: Broken main (<2h: revert or fix forward), lost work (reflog), corrupted cache (clean and rebuild)
8. **Debugging strategies**: Binary search (isolate), simplification (annotate), differential (reproduce CI), minimization (reduce input)
9. **Prevention**: Incremental development, defensive coding, monitoring, reproducible environments
10. **Severity levels**: Critical (<2h RTO), High (<4h), Medium (<24h), Low (<1 week)

**Key principle**: Errors are inevitable in complex verification workflows. Systematic diagnosis, documented recovery procedures, and preventive practices minimize impact and enable rapid resolution.

For performance issues, see PERFORMANCE_BENCHMARKING guide. For team coordination during incidents, see COLLABORATIVE_VERIFICATION_WORKFLOWS. For preventing errors via review, see PROOF_REVIEW_AND_QA.
