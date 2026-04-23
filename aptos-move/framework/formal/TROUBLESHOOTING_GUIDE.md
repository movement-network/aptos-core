# CA Formal Verification — Troubleshooting Guide

**Last updated:** 2026-04-22  
**Scope:** Common issues and solutions across Lean, Move Prover, and difftest stacks

This guide covers problems you might encounter when running CA formal verification, organized by symptom and tool.

## Quick Diagnostics

### Is the problem with my setup or the code?

Run the smoke tests:

```bash
# Lean: Should complete in ~1s
cd aptos-move/framework/formal/audit
./verify-ca.sh --op register --stack lean

# Move Prover: Should complete in ~1s (0 VCs expected)
./verify-ca.sh --op register --stack move-prover

# If both fail: Setup issue
# If one fails: Tool-specific issue
# If both pass but your changes fail: Code issue
```

### Where to look first

| Symptom | First check | Tool |
|---------|-------------|------|
| "lake: command not found" | elan installation | Lean |
| "Build timed out after 15+ min" | mathlib cache | Lean |
| "unknown identifier" | Imports, typos | Lean |
| "type mismatch" | Theorem statement types | Lean |
| "Z3_EXE not set" | Prover dependencies | Move Prover |
| "unresolved addresses" | --named-addresses flag | Move Prover |
| "VC failed" | Spec too weak or incorrect | Move Prover |
| "VM ≠ Lean" | Oracle mismatch | Difftest |

## Lean Stack Issues

### Issue: "lake: command not found"

**Symptom:**
```
bash: lake: command not found
```

**Cause:** Lean toolchain not installed or not in PATH

**Fix:**
```bash
# Install Lean via elan
curl https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh -sSf | sh

# Add to PATH (elan installer does this, but verify)
echo "$HOME/.elan/bin" >> ~/.bashrc  # or ~/.zshrc
source ~/.bashrc  # or open new terminal

# Verify
lake --version
```

**Prevention:** Follow setup in `lean/README.md` or `audit/REVIEWER_QUICK_START.md`

---

### Issue: Build takes 10-30 minutes (should be seconds)

**Symptom:**
```
cd aptos-move/framework/formal/lean
lake build
# ... hangs for 10+ minutes, compiling mathlib from source
```

**Cause:** Mathlib cache not fetched. Mathlib takes ~4 hours to compile from source.

**Fix:**
```bash
cd aptos-move/framework/formal/lean

# Fetch mathlib cache (CRITICAL)
lake exe cache get

# Now rebuild (should be ~4-6s)
lake build
```

**Why this happens:**
- Fresh clone: No cache
- mathlib version changed: Cache is stale
- Cache directory deleted: Need to re-fetch

**Prevention:** **ALWAYS run `lake exe cache get` before `lake build`**. This is the #1 Lean performance issue.

**Cache location:** `~/.cache/mathlib4/`

---

### Issue: "unknown identifier 'foo'"

**Symptom:**
```
error: unknown identifier 'step_registration_pc42'
```

**Cause:** Missing import or typo

**Fix:**

1. Check spelling (case-sensitive):
   ```lean
   -- Wrong: step_Registration_pc42
   -- Right: step_registration_pc42
   ```

2. Check imports:
   ```lean
   import MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquivRebuild
   ```

3. Check namespace:
   ```lean
   open ConfidentialAsset.Registration  -- If needed
   ```

4. Search for definition:
   ```bash
   cd lean
   grep -r "def step_registration_pc42" .
   ```

---

### Issue: "type mismatch" in theorem statement

**Symptom:**
```
error: type mismatch
  step registrationModuleEnv st
has type
  MoveResult MachineState
but is expected to have type
  MoveResult Frame
```

**Cause:** Wrong types in theorem statement

**Fix:**

1. Check types with `#check`:
   ```lean
   #check step registrationModuleEnv st
   #check (step registrationModuleEnv st : MoveResult MachineState)
   ```

2. Fix theorem statement types:
   ```lean
   -- Wrong
   theorem foo : step env st = .ok frame := ...
   
   -- Right (if step returns MachineState)
   theorem foo : step env st = .ok machineState := ...
   ```

3. Use `.dropFunction` if needed:
   ```lean
   theorem foo : (step env st).dropFunction = .ok frame := ...
   ```

---

### Issue: "tactic 'simp' failed, failed to rewrite"

**Symptom:**
```
error: tactic 'simp' failed, failed to rewrite using equation theorems for 'foo'
```

**Cause:** Simp lemma doesn't apply or term too complex

**Fix:**

1. **Add intermediate steps:**
   ```lean
   -- Instead of:
   simp [foo, bar, baz]
   
   -- Do:
   simp only [foo]
   simp only [bar]
   simp only [baz]
   ```

2. **Use `rw` instead of `simp`:**
   ```lean
   rw [foo, bar]
   ```

3. **Check simp lemmas are marked `@[simp]`:**
   ```lean
   @[simp]
   theorem foo_simp : foo x = bar x := ...
   ```

4. **Add `@[irreducible]` to control unfolding:**
   ```lean
   @[irreducible]
   def myState := { ... }
   ```

---

### Issue: Build succeeds but "sorry" in proof

**Symptom:**
```
warning: declaration uses 'sorry'
```

**Cause:** Incomplete proof (uses `sorry` placeholder)

**This is NOT an error** — it's a warning. Build still succeeds.

**To find sorries:**
```bash
cd lean
grep -rn "sorry" MovementFormal/Experimental/ConfidentialAsset/
```

**Expected sorries (Phase 6):**
- `normalization_eval_equiv_functional_sim` — sorry (PC-chaining proof pending)
- `withdrawal_eval_equiv_functional_sim` — sorry
- `transfer_eval_equiv_functional_sim` — sorry
- `rotation_eval_equiv_functional_sim` — sorry

All others should be complete.

---

### Issue: "maximum heartbeats" error

**Symptom:**
```
error: maximum recursion depth has been reached
```
or
```
error: (deterministic) timeout at ...
```

**Cause:** Proof term too large or inefficient tactics

**Fix:**

1. **Break proof into smaller lemmas:**
   ```lean
   -- Instead of one giant proof:
   theorem big : foo = bar := by
     simp [100 lemmas...]  -- Too big!
   
   -- Split into parts:
   theorem step1 : foo = intermediate := by simp [lemmas1...]
   theorem step2 : intermediate = bar := by simp [lemmas2...]
   theorem big : foo = bar := by rw [step1, step2]
   ```

2. **Use `@[irreducible]` to control term size:**
   ```lean
   @[irreducible]
   def symbolicState := { ... }
   ```

3. **Avoid chained record updates:**
   ```lean
   -- Bad (O(N²) whnf cost):
   def st2 := { st1 with pc := 2 }
   def st3 := { st2 with locals := st2.locals.set 0 v }
   def st4 := { st3 with stack := st3.stack.push x }
   
   -- Good (flat record):
   def st4 := { pc := 4, locals := ..., stack := ... }
   ```

**See also:** Memory document `feedback_fv_heartbeats.md` on why lifting heq-rfl bridges didn't help (bound-proof elaboration is the real cost).

---

### Issue: Axiom guard fails ("new axioms detected")

**Symptom:**
```
❌ Axiom diff check failed
New axioms:
  foo_axiom
```

**Cause:** New axiom added without updating baseline

**Fix:**

1. **Check if axiom is intentional:**
   ```bash
   cd aptos-move/framework/formal
   ./scripts/check_axioms.sh
   ```

2. **If intentional, update documentation:**
   - Add row to `audit/AXIOM_INVENTORY.md` with rationale
   - Update `audit/axiom-baseline.txt`:
     ```bash
     ./scripts/check_axioms.sh > audit/axiom-baseline.txt
     ```
   - Commit both files in same PR

3. **If unintentional, remove axiom:**
   - Change `axiom foo` to `theorem foo := by ...`
   - Complete the proof

**Expected axioms (2026-04-22):** 26 total (21 permanent + 5 temporary). Run `./verify-ca.sh --coverage` to see current count.

## Move Prover Stack Issues

### Issue: "Z3_EXE not set"

**Symptom:**
```
Error: Z3_EXE not set. Run: movement update prover-dependencies --assume-yes
```

**Cause:** Prover dependencies not installed or env vars not exported

**Fix:**

```bash
# Install dependencies
movement update prover-dependencies --assume-yes

# Export env vars (add to shell profile for persistence)
export BOOGIE_EXE=$HOME/.local/bin/boogie
export Z3_EXE=$HOME/.local/bin/z3
export CVC5_EXE=$HOME/.local/bin/cvc5

# Verify
$Z3_EXE --version  # Should show: Z3 version 4.11.2
$BOOGIE_EXE -version  # Should show: Boogie 3.5.1.0
```

**Persistent setup (add to ~/.bashrc or ~/.zshrc):**
```bash
echo 'export BOOGIE_EXE=$HOME/.local/bin/boogie' >> ~/.bashrc
echo 'export Z3_EXE=$HOME/.local/bin/z3' >> ~/.bashrc
echo 'export CVC5_EXE=$HOME/.local/bin/cvc5' >> ~/.bashrc
source ~/.bashrc
```

---

### Issue: "unresolved addresses: aptos_experimental"

**Symptom:**
```
error: unresolved addresses: aptos_experimental
```

**Cause:** Missing `--named-addresses` flag

**Fix:**
```bash
# Add --named-addresses flag
movement move prove \
    --package-dir aptos-move/framework/aptos-experimental \
    --named-addresses aptos_experimental=0x7 \  # <-- This line
    --filter register_internal
```

**Or use verify-ca.sh (handles this automatically):**
```bash
./audit/verify-ca.sh --op register --stack move-prover
```

---

### Issue: "VC failed" with timeout

**Symptom:**
```
error: verification failed after timeout
```

**Cause:** Z3 timeout (default 60s) or spec too complex

**Fix:**

1. **Increase timeout:**
   ```bash
   movement move prove \
       --vc-timeout 120 \  # Increase from 60s to 120s
       --filter register_internal
   ```

2. **Simplify spec:**
   - Break complex `ensures` into multiple clauses
   - Add intermediate `assert` statements
   - Strengthen preconditions (`aborts_if` clauses)

3. **Check for contradictory specs:**
   ```move
   spec foo {
       ensures result == 1;
       ensures result == 2;  // Contradiction! Z3 will timeout
   }
   ```

---

### Issue: "0 verification conditions"

**Symptom:**
```
[INFO] 0 verification conditions
{"Result": "Success"}
```

**This is NOT an error** (as of 2026-04-22).

**Explanation:**
- Specs compile successfully
- But don't generate VCs (verification conditions)
- Reason: Specs are scaffolded with `pragma opaque` on crypto functions
- **Blocked on:** ristretto255 upstream patches (Phase 0)

**Status:**
- ✅ Toolchain works (this confirms it)
- ⚠️ Meaningful verification blocked (expected)
- See `MOVE_PROVER_INTEGRATION_STATUS.md` for details

**What to do:** Nothing. This is expected current state. Wait for ristretto255 patches.

---

### Issue: Ristretto255 verification failures

**Symptom:**
```
error: abort condition never happens
    at aptos-stdlib/sources/cryptography/ristretto255.move:234:19
    abort happened here with code 0xB
```

**Cause:** Upstream ristretto255 spec bugs (Phase 0 blocker)

**Status (2026-04-22):**
- Bug 1 (bv/int mismatch): ✅ Resolved
- Bug 2 (vector monomorphization): ⚠️ Partially resolved, still causing issues

**Impact:**
- Blocks meaningful verification of CA specs
- Specs compile but can't verify (0 VCs is expected)

**Fix:** Wait for Phase 0 completion. This is a known blocker, not your problem.

**Workaround:** Use `pragma opaque` on crypto functions (already done).

**See:** `MOVE_PROVER_INTEGRATION_STATUS.md` for detailed blocker analysis.

---

### Issue: Compilation succeeds but verification fails

**Symptom:**
```
Compiling... ✓ Success
Verifying... ✗ Error: VC failed
```

**Cause:** Spec is incorrect (states something that's not true)

**Fix:**

1. **Check spec logic:**
   ```move
   spec withdraw_internal {
       // Is this actually true?
       ensures global<Store>(...).balance == old(global<Store>(...).balance) - amount;
   }
   ```

2. **Strengthen preconditions:**
   ```move
   spec withdraw_internal {
       // Add abort condition
       aborts_if global<Store>(...).balance < amount;  // Underflow check
       
       ensures ...;  // Now ensures clause can assume balance >= amount
   }
   ```

3. **Add invariants:**
   ```move
   spec module {
       invariant forall addr: address where exists<Store>(addr):
           global<Store>(addr).balance >= 0;  // Balance is non-negative
   }
   ```

4. **Check frame conditions:**
   ```move
   spec freeze {
       // Does this operation modify *only* frozen flag?
       ensures global<Store>(...).frozen == true;
       ensures global<Store>(...).balance == old(global<Store>(...).balance);  // Frame
   }
   ```

## Difftest Stack Issues

### Issue: Difftest harness not found

**Symptom:**
```
ERROR: difftest harness not found/executable at .../difftest.sh
```

**Cause:** Difftest harness not set up yet

**Status (2026-04-22):** Difftest harness setup is pending. This is expected.

**Workaround:** Skip difftest for now. Focus on Lean + Move Prover stacks.

**Future:** Difftest will be integrated in Phase 7 completion.

---

### Issue: "VM output ≠ Lean output"

**Symptom:**
```
FAILED: withdrawal_happy_path
  VM output: success
  Lean output: error
```

**Cause:** Oracle mismatch or model bug

**Fix:**

1. **Check oracle implementation:**
   - Are Ristretto255 natives consistent between VM and Lean?
   - Run standalone oracle test

2. **Check input format:**
   - Corpus row JSON might be malformed
   - Verify with `jq empty corpus_row.json`

3. **Check Lean model:**
   - Does Lean oracle match VM behavior?
   - Add debug prints to compare intermediate values

4. **Check VM state:**
   - Is VM initialized correctly?
   - Are contract addresses correct?

**Debugging:**
```bash
# Run with verbose output (future)
./difftest.sh --suite confidential_asset --row withdrawal_happy_path --verbose

# Check VM output
cat /tmp/vm_output.json

# Check Lean output
cat /tmp/lean_output.json

# Compare
diff /tmp/vm_output.json /tmp/lean_output.json
```

## Integration Issues (verify-ca.sh)

### Issue: verify-ca.sh fails with "operation not recognized"

**Symptom:**
```
Error: Operation 'withdrawl' not recognized
```

**Cause:** Typo in operation name

**Fix:**

Valid operations:
- `register`
- `withdraw` (not "withdrawl")
- `transfer`
- `normalize`
- `rotate`

**Check available operations:**
```bash
./verify-ca.sh --help
```

---

### Issue: "Budget exceeded" warning

**Symptom:**
```
⚠ Time: 185s (exceeds per-op budget of 180s)
```

**This is a WARNING, not an error.** Verification still passed.

**Cause:** Operation took longer than 3-minute budget

**Fix (if it matters):**

1. **Check mathlib cache:**
   ```bash
   cd aptos-move/framework/formal/lean
   lake exe cache get
   ```

2. **Check for slow proofs:**
   - Profile with `lake build --profile`
   - Look for large heartbeat counts

3. **Optimize proofs:**
   - Break into smaller lemmas
   - Use `@[irreducible]`
   - Avoid chained record updates

**Current status:** All operations well within budget (1-2s each).

## Performance Issues

### Issue: Verification is slow (>5 min for full run)

**Expected times (2026-04-22):**
- Lean full run: ~6s
- Move Prover full run: ~5s (0 VCs)
- Full 3-stack: ~11s (difftest pending)

**If slower than expected:**

1. **Lean:** Check mathlib cache
   ```bash
   cd lean && lake exe cache get && lake clean && lake build
   ```

2. **Move Prover:** Check Z3 version
   ```bash
   $Z3_EXE --version  # Must be 4.11.2, not 4.14.x
   ```

3. **System:** Check CPU load
   ```bash
   top  # Check if other processes consuming CPU
   ```

4. **Network:** Check git remote (shouldn't fetch during build)
   ```bash
   # Use --skip-fetch-latest-git-deps flag
   movement move prove --skip-fetch-latest-git-deps ...
   ```

---

### Issue: Out of memory during build

**Symptom:**
```
error: killed (signal 9)
```
or
```
lake: out of memory
```

**Cause:** Too many parallel jobs

**Fix:**

```bash
# Reduce parallelism
cd lean
lake build -j4  # Limit to 4 parallel jobs

# Or even less
lake build -j1  # Single-threaded (slowest but least memory)
```

**System requirements:**
- Minimum: 8GB RAM (use -j4)
- Recommended: 16GB RAM (use -j8)
- Optimal: 32GB+ RAM (use -j16)

## CI Issues

### Issue: CI builds timeout (15+ minutes)

**Cause:** Mathlib cache not restored

**Fix:**

Add cache step to CI workflow:
```yaml
- name: Cache mathlib
  uses: actions/cache@v3
  with:
    path: ~/.cache/mathlib4
    key: mathlib4-${{ hashFiles('**/lake-manifest.json') }}
    restore-keys: mathlib4-
```

See `audit/CI_INTEGRATION_GUIDE.md` for complete workflow examples.

---

### Issue: CI fails on "new axioms detected"

**Cause:** Axiom-diff guard caught new axiom

**This is INTENTIONAL.** The guard prevents silent trust-base growth.

**Fix:**

1. **Review the new axiom:** Is it necessary?
2. **Document in AXIOM_INVENTORY.md:**
   ```markdown
   | new_axiom | file.lean:123 | TEMPORARY | Will be proved in Phase N | Blocked on: ... |
   ```
3. **Update axiom baseline:**
   ```bash
   ./scripts/check_axioms.sh > audit/axiom-baseline.txt
   ```
4. **Commit both files in same PR**

**Do NOT:** Disable the axiom-diff guard. It's there for a reason.

## Getting Help

### Diagnostic Information to Collect

When asking for help, provide:

```bash
# Lean version
cat lean/lean-toolchain

# Lake version
cd lean && lake --version

# Move Prover versions
$Z3_EXE --version
$BOOGIE_EXE -version

# Git status
git status
git log --oneline -5

# Full error output
./verify-ca.sh --op <operation> --stack <stack> 2>&1 | tee error.log
```

### Where to Ask

- **Lean issues:** Check `lean/README.md`, search Lean Zulip
- **Move Prover issues:** Check Movement Labs docs
- **CA-specific issues:** Check plan, CLAIMS.md, TRUST_BOUNDARIES.md

### Documentation Index

- **Setup:** `audit/REVIEWER_QUICK_START.md`
- **Testing:** `audit/TESTING_AND_VALIDATION_GUIDE.md`
- **Performance:** `audit/PERFORMANCE_BENCHMARKING_GUIDE.md`
- **CI:** `audit/CI_INTEGRATION_GUIDE.md`
- **Move Prover:** `MOVE_PROVER_INTEGRATION_STATUS.md`
- **Three stacks:** `THREE_STACK_VERIFICATION_STORY.md`
- **Plan:** `CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md`

## Summary of Common Fixes

| Issue | Quick Fix |
|-------|-----------|
| "lake not found" | `curl https://...elan-init.sh \| sh` |
| Slow build (10+ min) | `cd lean && lake exe cache get` |
| "Z3_EXE not set" | `movement update prover-dependencies && export Z3_EXE=...` |
| "unknown identifier" | Check imports, check spelling |
| "type mismatch" | Use `#check` to verify types |
| "0 VCs" | Expected (blocked on ristretto255) |
| "new axioms" | Document in AXIOM_INVENTORY.md + update axiom-baseline.txt |
| Out of memory | `lake build -j4` (reduce parallelism) |
| CI timeout | Add mathlib cache step |

**Most common issues:**
1. Mathlib cache not fetched (Lean slow)
2. Z3_EXE not set (Move Prover fails)
3. New axioms (CI guard fails)

**Prevention:** Follow setup guides carefully, run smoke tests after setup.
