# Debugging Verification Failures Guide

**Last updated:** 2026-04-23

Comprehensive guide to diagnosing and fixing verification failures across all three stacks (Lean, Move Prover, difftest). Covers common failure modes, debugging techniques, and resolution strategies.

---

## Table of Contents

1. [Quick Diagnosis](#quick-diagnosis)
2. [Lean Build Failures](#lean-build-failures)
3. [Lean Proof Failures](#lean-proof-failures)
4. [Move Prover Failures](#move-prover-failures)
5. [Difftest Failures](#difftest-failures)
6. [CI/CD Failures](#cicd-failures)
7. [Performance Issues](#performance-issues)
8. [Common Patterns](#common-patterns)

---

## Quick Diagnosis

Run the quick diagnostic script to identify the failure category:

```bash
./scripts/run_verification_suite.sh --quick
```

**Exit codes:**
- `0` = All checks passed
- `1` = One or more checks failed (see output for details)

**Immediate checks:**
1. Lean toolchain version: `lean --version` (should be v4.24.0)
2. Move Prover tools: `$Z3_EXE --version` (should be 4.11.2)
3. Mathlib cache: `cd lean && lake exe cache get`
4. Git status: `git status` (uncommitted changes can cause issues)

---

## Lean Build Failures

### Symptom: `lake build` fails

#### Cause 1: Missing mathlib cache

**Error message:**
```
Building mathlib from source (this will take hours...)
```

**Solution:**
```bash
cd lean
lake exe cache get
lake build
```

**Why:** Mathlib is large (~1.5GB compiled). Building from source takes 2-4 hours. Always use the cache.

#### Cause 2: Lean version mismatch

**Error message:**
```
error: toolchain 'leanprover/lean4:v4.XX.0' is not installed
```

**Solution:**
```bash
elan default v4.24.0
cd lean && lake build
```

**Why:** The project pins Lean 4.24.0. Other versions may have incompatible APIs.

#### Cause 3: Corrupted build artifacts

**Error message:**
```
error: module '...' not found in search path
```

**Solution:**
```bash
cd lean
lake clean
lake exe cache get
lake build
```

**Why:** Incremental builds can sometimes get into inconsistent states. Clean rebuild fixes it.

#### Cause 4: Import cycle

**Error message:**
```
error: import cycle detected: A imports B imports A
```

**Solution:**
1. Identify the cycle in the error message
2. Refactor to break the cycle:
   - Extract shared definitions to a new file
   - Reorder imports
   - Use forward declarations

**Why:** Lean's module system doesn't support cycles. Code must be acyclic.

#### Cause 5: Missing file reference

**Error message:**
```
error: no such file or directory: .../SomeFile.lean
```

**Solution:**
1. Check if file was deleted: `git log --all -- path/to/SomeFile.lean`
2. Update `lakefile.lean` to remove the reference
3. Update imports in other files

**Why:** Deleted files leave dangling references. All references must be cleaned up.

---

## Lean Proof Failures

### Symptom: Theorem fails to compile or typecheck

#### Cause 1: Type mismatch

**Error message:**
```
type mismatch
  ?m
has type
  Nat
but is expected to have type
  Int
```

**Solution:**
1. Check the types of all terms in the theorem
2. Add explicit type annotations: `(x : Nat)`
3. Use type coercions if appropriate: `↑x`
4. Simplify complex type expressions

**Debugging:**
```lean
#check term  -- Check type of term
#print term  -- Print definition
set_option pp.all true  -- Show implicit arguments
```

#### Cause 2: Sorry in dependency

**Error message:**
```
warning: declaration uses 'sorry'
```

**Solution:**
1. Find the sorry: `grep -r "sorry" lean/MovementFormal/Experimental/ConfidentialAsset/`
2. Either:
   - Complete the proof
   - Axiomatize if intentional (document in AXIOM_INVENTORY.md)
   - Remove dependency on the sorry'd theorem

**Why:** Sorries make the proof incomplete. They're okay during development but must be documented.

#### Cause 3: Heartbeat limit exceeded

**Error message:**
```
maximum heartbeat threshold reached
```

**Solution:**
1. **First, try to optimize the proof:**
   - Simplify complex terms before using them
   - Break large proofs into smaller lemmas
   - Use `@[irreducible]` on expensive definitions
   - Avoid deeply nested pattern matches

2. **If optimization isn't feasible:**
   ```lean
   set_option maxHeartbeats 400000 in
   theorem expensive_proof : ... := ...
   ```

**Why:** Heartbeat limits prevent infinite loops. High heartbeat usage often indicates inefficient proofs that should be optimized.

#### Cause 4: Tactic failure

**Error message:**
```
tactic 'simp' failed, no simplification rules applied
```

**Solution:**
1. Check simp lemmas are in scope: `#check @[simp] lemma_name`
2. Try alternative tactics:
   - `simp only [specific_lemmas]`
   - `rw [lemma1, lemma2]`
   - `exact proof_term`
3. Add intermediate steps to see where it fails

**Debugging:**
```lean
theorem foo : ... := by
  simp  -- fails here
  trace "After simp: {goal}"  -- won't execute, but shows intent
  -- Try instead:
  simp?  -- suggests which lemmas to use
```

#### Cause 5: Definitional equality fails

**Error message:**
```
failed to synthesize
  Decidable (a = b)
```

**Solution:**
1. Provide the instance explicitly: `decide`
2. Prove the equality: `show a = b from ...`
3. Use `by decide` for computationally decidable goals

**Why:** Lean needs to know how to check equality. Not all types have automatic decidability.

---

## Move Prover Failures

### Symptom: `movement move prove` fails

#### Cause 1: Z3 version mismatch

**Error message:**
```
expected at most version 4.11.2 but found 4.14.x for z3
```

**Solution:**
```bash
# DO NOT use Homebrew Z3 (installs 4.14.x)
# Instead, use Movement CLI installer:
movement update prover-dependencies --assume-yes

# Verify:
$Z3_EXE --version  # Should show: Z3 version 4.11.2
```

**Why:** Move Prover requires exactly Z3 4.11.2. Newer versions have incompatible changes.

#### Cause 2: Boogie not found

**Error message:**
```
error: BOOGIE_EXE not set or boogie not found
```

**Solution:**
```bash
movement update prover-dependencies --assume-yes
echo $BOOGIE_EXE  # Should point to boogie binary
```

**Why:** Move Prover requires Boogie 3.5.1. Must be installed and env var set.

#### Cause 3: Spec compilation error

**Error message:**
```
error: undefined spec function
```

**Solution:**
1. Check spec function is declared: `spec fun name(...): Type;`
2. Check module imports: `use 0x1::module_name;`
3. Verify function signature matches usage

**Debugging:**
```bash
# Compile specs only (no verification)
movement move compile --package-dir aptos-experimental --skip-fetch-latest-git-deps
```

#### Cause 4: Ristretto255 blocker

**Error message:**
```
error: monomorphization failed for vector<CompressedRistretto>
```

**Status:** Known upstream blocker. Patches exist but not yet applied.

**Workaround:**
- Specs compile but generate 0 VCs
- This is expected and doesn't block CA development
- See `PHASE_0_RISTRETTO255_PATCH_NOTES.md` for details

#### Cause 5: Missing modifies clause

**Error message:**
```
error: function modifies global resource but lacks modifies clause
```

**Solution:**
Add modifies clause to spec:
```move
spec withdraw_to {
    modifies global<ConfidentialAssetStore>(addr);
    modifies global<ConcurrentFungibleBalance>(fa_addr);
}
```

**Why:** Move Prover needs to know which globals might be modified for soundness.

---

## Difftest Failures

### Symptom: Difftest corpus verification fails

#### Cause 1: VM output changed

**Error message:**
```
Mismatch: VM output differs from expected
```

**Solution:**
1. Regenerate golden outputs:
   ```bash
   cd difftest
   ./difftest.sh --regenerate
   ```
2. Review changes carefully
3. Update corpus if VM behavior intentionally changed
4. If unintentional, this is a regression

**Why:** Difftest pins exact VM behavior. Any change must be intentional.

#### Cause 2: Model diverged from VM

**Error message:**
```
Model output differs from VM output
```

**Solution:**
1. Check recent changes to Lean model
2. Verify bytecode transcription is correct
3. Run single-operation test:
   ```bash
   ./audit/verify-ca.sh --op register --stack difftest
   ```
4. Fix model to match VM behavior

**Why:** Model must match VM exactly. Divergence indicates transcription error or stale model.

#### Cause 3: Hygiene check failure

**Error message:**
```
Hygiene check failed: sorry detected in proof
```

**Status:** Expected during Phase 6 work (21 sorries in composition theorems).

**Solution:**
- If sorries are expected (documented in plan): This is not a failure
- If sorries are unexpected: Complete the proofs

**Why:** Hygiene check ensures proofs are complete. Temporarily disabled for Phase 6.

---

## CI/CD Failures

### Symptom: GitHub Actions workflow fails

#### Cause 1: Mathlib cache timeout

**Error message:**
```
Error: lake exe cache get timed out after 10 minutes
```

**Solution:**
```yaml
# In workflow file, increase timeout:
- name: Fetch mathlib cache
  timeout-minutes: 15
  run: |
    lake exe cache get || echo "::warning::Cache fetch failed, will build from source"
```

**Why:** Network issues can slow cache fetch. Timeout should allow retry.

#### Cause 2: Axiom drift detected

**Error message:**
```
error: Axiom drift detected - new axioms without baseline update
```

**Solution:**
```bash
# Locally:
./scripts/check_axioms.sh > audit/axiom-baseline.txt

# Update AXIOM_INVENTORY.md with rationale for new axioms

# Commit both files
git add audit/axiom-baseline.txt audit/AXIOM_INVENTORY.md
git commit -m "Update axiom baseline: <reason>"
```

**Why:** CI guards against unintentional axiom additions. All new axioms must be documented.

#### Cause 3: Sorry count regression

**Error message:**
```
error: Sorry count increased from 21 to 25
```

**Solution:**
1. Find new sorries: `git diff HEAD~1 | grep sorry`
2. Either:
   - Complete the proofs
   - Document as expected work-in-progress
   - Update baseline if legitimate increase

**Why:** Sorry count should decrease over time, not increase. Regression indicates incomplete work.

#### Cause 4: Performance regression

**Error message:**
```
warning: Build time increased from 4s to 8s (100% regression)
```

**Solution:**
1. Profile the slow build:
   ```bash
   ./scripts/performance_dashboard.sh --benchmark
   ```
2. Identify the slow file:
   ```bash
   lake build --verbose 2>&1 | grep "Building"
   ```
3. Optimize the slow proof (see "Heartbeat limit exceeded" above)

**Why:** Performance regressions accumulate. Address them promptly.

---

## Performance Issues

### Symptom: Builds are slow

#### Diagnosis

```bash
# Benchmark current performance
./scripts/benchmark_verification.sh

# Compare against baseline
./scripts/diff_verification_baseline.sh --baseline reports/verification-baseline.json
```

#### Cause 1: Missing mathlib cache

**Solution:** Always run `lake exe cache get` before building.

#### Cause 2: Inefficient proof

**Indicators:**
- High heartbeat usage
- Long build times for specific files
- Deep tactic nesting

**Solution:**
1. Profile the file:
   ```bash
   lake build --verbose MovementFormal.Path.To.Slow.File 2>&1 | grep heartbeats
   ```
2. Optimize:
   - Break large proofs into smaller lemmas
   - Use `@[irreducible]` on expensive definitions
   - Simplify before tactics: `have h : simplified := by simp; exact h`
   - Avoid deeply nested pattern matches

#### Cause 3: Redundant builds

**Solution:**
```bash
# Clean and rebuild
cd lean
lake clean
lake exe cache get
lake build
```

---

## Common Patterns

### Pattern 1: "It works locally but fails in CI"

**Common causes:**
1. Different tool versions (check Lean/Z3/Boogie versions)
2. Missing cache (CI might not fetch mathlib cache)
3. Different environment variables
4. Uncommitted files locally

**Debug:**
```bash
# Replicate CI environment locally
docker build -t ca-fv -f audit/Dockerfile .
docker run --rm ca-fv ./audit/verify-ca.sh
```

### Pattern 2: "It worked yesterday but fails today"

**Common causes:**
1. Dependency update (check `lake-manifest.json`)
2. Upstream changes (check git history)
3. Environment change (check tool versions)

**Debug:**
```bash
# Bisect to find the breaking commit
git bisect start
git bisect bad HEAD
git bisect good <last-known-good-commit>
# Test at each step until git identifies the culprit
```

### Pattern 3: "Proof fails only on specific operations"

**Common causes:**
1. Operation-specific complexity
2. Missing lemmas for that operation
3. Different bytecode patterns

**Debug:**
```bash
# Compare working vs failing operation
diff -u lean/MovementFormal/.../Working/EvalEquiv.lean \
        lean/MovementFormal/.../Failing/EvalEquiv.lean
```

---

## Getting Help

### Before asking for help:

1. **Run diagnostics:**
   ```bash
   ./scripts/run_verification_suite.sh --quick
   ./scripts/integration_test_suite.sh --smoke-test
   ```

2. **Collect logs:**
   ```bash
   # Lean build
   cd lean && lake build > /tmp/lean-build.log 2>&1

   # Move Prover
   movement move prove --package-dir ../aptos-experimental \
     --filter 'confidential_*' > /tmp/move-prover.log 2>&1

   # Verification suite
   ./scripts/run_verification_suite.sh > /tmp/verification-suite.log 2>&1
   ```

3. **Check recent changes:**
   ```bash
   git log --oneline -10
   git diff HEAD~5
   ```

### When asking for help:

Include:
- Error message (full text, not screenshot)
- Steps to reproduce
- Your environment (Lean version, OS, etc.)
- What you've already tried
- Relevant logs

**Resources:**
- `TROUBLESHOOTING_GUIDE.md`: Additional troubleshooting
- `FAQ.md`: Frequently asked questions
- GitHub Issues: Report bugs
- Team chat: Real-time support

---

## Summary

**Quick diagnosis flow:**

```
Failure
  ├─ Build failure?
  │    ├─ Missing cache? → lake exe cache get
  │    ├─ Version mismatch? → elan default v4.24.0
  │    └─ Corrupted artifacts? → lake clean && lake build
  │
  ├─ Proof failure?
  │    ├─ Type error? → Add type annotations, check types
  │    ├─ Tactic failure? → Try simp?, rw, exact
  │    └─ Heartbeat exceeded? → Optimize proof, split lemmas
  │
  ├─ Move Prover failure?
  │    ├─ Z3 version? → movement update prover-dependencies
  │    ├─ Spec error? → Check spec syntax, imports
  │    └─ Ristretto blocker? → Expected, see PHASE_0 notes
  │
  ├─ Difftest failure?
  │    ├─ VM changed? → Review, regenerate if intentional
  │    ├─ Model diverged? → Fix model to match VM
  │    └─ Hygiene check? → Expected during Phase 6
  │
  └─ Performance issue?
       ├─ Missing cache? → lake exe cache get
       ├─ Inefficient proof? → Optimize, split lemmas
       └─ Compare baseline? → ./scripts/diff_verification_baseline.sh
```

**Most common fixes:**
1. `lake exe cache get` (95% of Lean build issues)
2. `movement update prover-dependencies` (90% of Move Prover issues)
3. `lake clean && lake build` (80% of mysterious build failures)

**When in doubt:** Run the full verification suite and check logs.
