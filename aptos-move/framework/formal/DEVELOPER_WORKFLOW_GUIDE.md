# Developer Workflow Guide

**Purpose:** Day-to-day development workflows for Confidential Assets with formal verification integrated.

**Audience:** Engineers working on CA features, adding new operations, or maintaining existing verification.

**Scope:** End-to-end workflows from feature request to verified deployment.

---

## Table of Contents

1. [Daily Development Workflow](#1-daily-development-workflow)
2. [Adding a New CA Operation](#2-adding-a-new-ca-operation)
3. [Modifying Existing Operations](#3-modifying-existing-operations)
4. [Code Review Workflow](#4-code-review-workflow)
5. [Local Testing Workflow](#5-local-testing-workflow)
6. [PR Submission Checklist](#6-pr-submission-checklist)
7. [Common Development Scenarios](#7-common-development-scenarios)
8. [Debugging Workflows](#8-debugging-workflows)

---

## 1. Daily Development Workflow

### 1.1 Morning Setup

**Step 1: Pull latest changes**
```bash
cd aptos-core
git checkout movement
git pull origin movement

# Update submodules if any
git submodule update --init --recursive
```

**Step 2: Verify local environment**
```bash
# Lean
cd lean
lake exe cache get  # Download mathlib cache (5 min first time, <30s after)
lake build MovementFormal  # Should complete in ~4s
cd ..

# Move Prover
movement move prove --package-dir aptos-move/framework/move-stdlib --filter vector
# Should succeed (smoke test)

# Difftest
cd difftest
cargo test --release test_register_happy_path
# Should pass
cd ..
```

**If any of the above fails:** Check `CI_TROUBLESHOOTING_GUIDE.md` before proceeding.

### 1.2 Create Feature Branch

```bash
git checkout -b feature/<operation-name>-<feature-description>

# Example:
git checkout -b feature/transfer-batch-support
```

### 1.3 Iterative Development Loop

```
┌─────────────────────────────────────┐
│ 1. Edit Move source                 │
│    ↓                                 │
│ 2. Update MSL specs                  │
│    ↓                                 │
│ 3. Run Move Prover (fast: ~1s)      │
│    ↓                                 │
│ 4. Update Lean proofs (if needed)   │
│    ↓                                 │
│ 5. Run lake build (fast: ~1-2s)     │
│    ↓                                 │
│ 6. Update difftest (if needed)      │
│    ↓                                 │
│ 7. Run cargo test (fast: <1s)       │
│    ↓                                 │
│ 8. Iterate if failures               │
└─────────────────────────────────────┘
```

**Key insight:** Full iteration loop should be <10s with hot caches. If slower, check `PERFORMANCE_OPTIMIZATION_GUIDE.md`.

### 1.4 End of Day

**Before committing:**
```bash
# Run full verification suite (takes ~5 min)
./scripts/run_verification_suite.sh --mode standard

# If green, commit
git add <files>
git commit -m "feat(ca): <description>"

# Push to remote
git push origin feature/<feature-name>
```

**If not green:** Debug before pushing (see §8).

---

## 2. Adding a New CA Operation

**Example scenario:** Add `batch_transfer` operation that transfers to multiple recipients in one call.

### 2.1 Design Phase

**Before writing code, decide:**
- [ ] Which verification stacks cover this? (Lean, MSL, Difftest)
- [ ] What properties need to be verified? (balance conservation, freeze enforcement, etc.)
- [ ] What are the abort conditions?
- [ ] What test cases are needed?

**Document in design doc:**
```markdown
# Batch Transfer Design

## Specification
- **Input:** List of (recipient, amount) pairs
- **Preconditions:** Sender has sufficient balance for sum of amounts
- **Postconditions:** Each recipient balance increased by amount
- **Abort conditions:**
  - E_INSUFFICIENT_BALANCE (0x30001)
  - E_FROZEN_SENDER (0x30003)
  - E_INVALID_PROOF (0x10001)

## Verification Plan
- **Lean:** `verify_batch_transfer_proof` bytecode equivalence
- **MSL:** Balance sum preservation, freeze enforcement
- **Difftest:** 5 test cases (happy path, insufficient balance, frozen, invalid proof, partial failure)
```

### 2.2 Implementation Phase

**Step 1: Implement Move source**

```bash
vim aptos-move/framework/aptos-experimental/sources/confidential_asset/confidential_asset.move
```

Add the new function:
```move
public entry fun batch_transfer(
    account: &signer,
    recipients: vector<address>,
    amounts: vector<vector<u8>>,  // Encrypted amounts
    proof: BatchTransferProof
) acquires ConfidentialAssetStore {
    let sender_addr = signer::address_of(account);
    
    // Verify proof
    assert!(
        verify_batch_transfer_proof(&proof, sender_addr, &recipients, &amounts),
        error::invalid_argument(ESIGMA_PROTOCOL_VERIFY_FAILED)
    );
    
    // Execute transfers
    batch_transfer_internal(sender_addr, recipients, amounts);
}

fun batch_transfer_internal(
    sender: address,
    recipients: vector<address>,
    amounts: vector<vector<u8>>
) acquires ConfidentialAssetStore {
    // Implementation
    ...
}
```

**Step 2: Add MSL spec**

```bash
vim aptos-move/framework/aptos-experimental/sources/confidential_asset/confidential_asset.spec.move
```

```move
spec batch_transfer_internal {
    pragma opaque;
    
    requires len(recipients) == len(amounts);
    requires forall i in 0..len(recipients): exists<ConfidentialAssetStore>(recipients[i]);
    requires exists<ConfidentialAssetStore>(sender);
    
    ensures sum_balance(global<ConfidentialAssetStore>(sender).balance) == 
            old(sum_balance(global<ConfidentialAssetStore>(sender).balance)) - sum(amounts);
    
    ensures forall i in 0..len(recipients):
        sum_balance(global<ConfidentialAssetStore>(recipients[i]).balance) ==
        old(sum_balance(global<ConfidentialAssetStore>(recipients[i]).balance)) + amounts[i];
    
    aborts_if !exists<ConfidentialAssetStore>(sender) with ESTORE_NOT_FOUND;
    aborts_if global<ConfidentialAssetStore>(sender).frozen with ESTORE_FROZEN;
    aborts_if sum_balance(global<ConfidentialAssetStore>(sender).balance) < sum(amounts) 
        with EINSUFFICIENT_BALANCE;
}
```

**Step 3: Verify MSL spec**

```bash
movement move prove \
  --package-dir aptos-move/framework/aptos-experimental \
  --filter confidential_asset::batch_transfer_internal \
  --vc-timeout 120
```

**If it fails:** See `MSL_DEBUGGING_AND_TROUBLESHOOTING_GUIDE.md`.

**Step 4: Add Lean proof**

```bash
# Create directory
mkdir -p lean/MovementFormal/Experimental/ConfidentialAsset/BatchTransfer

# Create files
touch lean/MovementFormal/Experimental/ConfidentialAsset/BatchTransfer/{Bytecode,FunctionalSim,EvalEquiv,Phase6Composition}.lean
```

**Bytecode.lean:**
```lean
-- Transcribe bytecode from compiled module
-- See BYTECODE_TRANSCRIPTION_GUIDE.md for workflow

def verifyBatchTransferProofCode : Array Instruction :=
  #[
    .ldU64 0,          -- PC 0
    .stLoc 0,          -- PC 1
    -- ... (rest of bytecode)
  ]
```

**FunctionalSim.lean:**
```lean
-- Define high-level functional model
def verifyBatchTransferProofFunctionalSim 
    (proof : BatchTransferProof) 
    (sender : Address) 
    (recipients : List Address)
    (amounts : List Amount) : VerifyResult :=
  -- Mathematical sigma protocol verification
  if sigmaVerifyBatchTransfer proof sender recipients amounts then
    .success
  else
    .verifyFailed
```

**EvalEquiv.lean:**
```lean
-- Prove bytecode equivalent to functional sim
-- Follow pattern from Transfer/EvalEquiv.lean
-- See PHASE_6_PC_CHAINING_COMPLETE_GUIDE.md for detailed steps

theorem eval_batch_transfer_eq_run : ... := by
  unfold eval run
  -- PC chaining
  rw [step_pc0, step_pc1, ..., step_pcN]
  rfl

theorem batch_transfer_eval_equiv_functional_sim : ... := by
  cases oracleResult with
  | success => ...
  | verifyFailed => ...
  | error => ...
```

**Phase6Composition.lean:**
```lean
-- End-to-end composition theorem
theorem batch_transfer_is_formally_verified : ... := by
  apply batch_transfer_eval_equiv_functional_sim
  ...
```

**Step 5: Build Lean proofs**

```bash
cd lean
lake build MovementFormal.Experimental.ConfidentialAsset.BatchTransfer.EvalEquiv
# Should complete in <180s (per budget)

lake build MovementFormal  # Full tree
# Should complete in <600s
```

**Step 6: Add difftest tests**

```bash
vim difftest/corpus/confidential_asset_e2e.rs
```

```rust
#[test]
fn test_batch_transfer_happy_path() {
    let sender = setup_account_with_balance(1000);
    let recipients = vec![account1(), account2(), account3()];
    let amounts = vec![100, 200, 300];
    let proof = generate_batch_transfer_proof(sender, recipients, amounts);
    
    let result = execute_batch_transfer(sender, recipients, amounts, proof);
    
    assert!(result.is_success());
    assert_eq!(sender.balance(), 400);  // 1000 - 100 - 200 - 300
    assert_eq!(recipients[0].balance(), 100);
    assert_eq!(recipients[1].balance(), 200);
    assert_eq!(recipients[2].balance(), 300);
}

#[test]
fn test_batch_transfer_insufficient_balance() {
    let sender = setup_account_with_balance(100);
    let recipients = vec![account1(), account2()];
    let amounts = vec![60, 60];  // Total 120 > balance 100
    
    let result = execute_batch_transfer(sender, recipients, amounts, proof);
    
    assert_eq!(result, Aborted(0x30001));  // E_INSUFFICIENT_BALANCE
}

#[test]
fn test_batch_transfer_sender_frozen() {
    let sender = setup_frozen_account(1000);
    let recipients = vec![account1()];
    let amounts = vec![100];
    
    let result = execute_batch_transfer(sender, recipients, amounts, proof);
    
    assert_eq!(result, Aborted(0x30003));  // E_FROZEN_SENDER
}

#[test]
fn test_batch_transfer_invalid_proof() {
    let sender = setup_account_with_balance(1000);
    let recipients = vec![account1()];
    let amounts = vec![100];
    let invalid_proof = generate_invalid_proof();
    
    let result = execute_batch_transfer(sender, recipients, amounts, invalid_proof);
    
    assert_eq!(result, Aborted(0x10001));  // E_INVALID_PROOF
}

#[test]
fn test_batch_transfer_partial_failure() {
    // Test that if one recipient transfer would fail, whole batch aborts
    let sender = setup_account_with_balance(1000);
    let recipients = vec![account1(), frozen_account()];  // One frozen
    let amounts = vec![100, 100];
    
    let result = execute_batch_transfer(sender, recipients, amounts, proof);
    
    assert_eq!(result, Aborted(0x30003));  // E_FROZEN_RECIPIENT
    // Verify no partial transfer (atomicity)
    assert_eq!(sender.balance(), 1000);  // Unchanged
    assert_eq!(account1().balance(), 0);  // Unchanged
}
```

**Step 7: Run difftest**

```bash
cargo test --release test_batch_transfer
# All 5 tests should pass
```

### 2.3 Documentation Phase

**Step 1: Update CLAIMS.md**

```bash
vim audit/CLAIMS.md
```

```markdown
## Batch Transfer

**Property:** Atomically transfers encrypted balances to multiple recipients, preserving total balance sum and enforcing freeze constraints.

**Stacks:** Lean, MSL, Difftest

**Lean:** `lean/MovementFormal/Experimental/ConfidentialAsset/BatchTransfer/Phase6Composition.lean:45`
  - Theorem: `batch_transfer_is_formally_verified`
  - Proves: `verify_batch_transfer_proof` bytecode equivalent to sigma verifier
  - Verify: `lake build MovementFormal.Experimental.ConfidentialAsset.BatchTransfer.Phase6Composition`

**MSL:** `aptos-experimental/sources/confidential_asset/confidential_asset.spec.move:234`
  - Spec: `spec batch_transfer_internal { ensures sum_balance preserved; aborts_if frozen | insufficient; }`
  - Verify: `movement move prove --filter batch_transfer_internal`

**Difftest:** `difftest/corpus/confidential_asset_e2e.rs:test_batch_transfer_*`
  - 5 test cases: happy path, insufficient balance, frozen sender, invalid proof, partial failure
  - Run: `cargo test test_batch_transfer`
```

**Step 2: Update COMPOSITION_CLAIMS.md**

```bash
vim audit/COMPOSITION_CLAIMS.md
```

Add composition claim for batch_transfer.

**Step 3: Update MSL_SPEC_COVERAGE.md and BYTECODE_VERIFICATION_COVERAGE.md**

```bash
vim audit/MSL_SPEC_COVERAGE.md
# Add batch_transfer_internal to coverage table

vim audit/BYTECODE_VERIFICATION_COVERAGE.md
# Add verify_batch_transfer_proof to coverage table
```

**Step 4: Update verify-ca.sh**

```bash
vim audit/verify-ca.sh
```

Add `batch_transfer` to the operation list so `./verify-ca.sh --op batch_transfer` works.

### 2.4 CI Integration

**Step 1: Update CI workflow**

```bash
vim .github/workflows/ca-verification-suite.yaml
```

```yaml
strategy:
  matrix:
    operation: [register, withdraw, transfer, normalize, rotate, batch_transfer]  # Added
```

**Step 2: Run full verification suite locally**

```bash
./scripts/run_verification_suite.sh --mode comprehensive
# Should complete in <15 min, all checks green
```

### 2.5 Submit PR

**Step 1: Create PR**

```bash
git add .
git commit -m "feat(ca): add batch_transfer operation with full verification"
git push origin feature/transfer-batch-support

# Create PR via GitHub UI
```

**Step 2: PR Description Template**

```markdown
## Summary
Adds `batch_transfer` operation to Confidential Assets, allowing atomic transfer to multiple recipients in a single transaction.

## Verification
- [x] Lean: `verify_batch_transfer_proof` bytecode equivalence proved
- [x] MSL: Balance sum preservation and freeze enforcement specified and verified
- [x] Difftest: 5 test cases covering happy path and all error conditions

## Testing
```bash
# Local verification
./audit/verify-ca.sh --op batch_transfer
# Result: PASSED (3.2s Lean, 1.1s MSL, 0.8s difftest)

# Full suite
./scripts/run_verification_suite.sh --mode comprehensive
# Result: ALL PASSED (12.5 min)
```

## Checklist
- [x] Move source implemented
- [x] MSL spec added and verified
- [x] Lean proof added and verified
- [x] Difftest tests added and passing
- [x] Documentation updated (CLAIMS.md, COMPOSITION_CLAIMS.md, coverage docs)
- [x] CI workflow updated
- [x] verify-ca.sh updated
- [x] All verification stacks green locally
- [x] Axiom count unchanged (23 total, 0 new)
```

---

## 3. Modifying Existing Operations

**Example scenario:** Add new abort condition to `withdraw_to` for minimum withdrawal amount.

### 3.1 Impact Analysis

**Before changing code, determine impact:**

```bash
# Which files need updates?
# - Move source: confidential_asset.move
# - MSL spec: confidential_asset.spec.move (add aborts_if clause)
# - Lean proof: unlikely (if bytecode doesn't change)
# - Difftest: yes (add test case for new abort condition)
```

### 3.2 Update Workflow

**Step 1: Modify Move source**

```move
fun withdraw_to_internal(...) {
    let amount_sum = sum_amounts(&encrypted_amount);
    assert!(amount_sum >= MIN_WITHDRAWAL_AMOUNT, error::invalid_argument(EAMOUNT_TOO_SMALL));
    
    // ... rest of function
}
```

**Step 2: Update MSL spec**

```move
spec withdraw_to_internal {
    aborts_if sum_amounts(encrypted_amount) < MIN_WITHDRAWAL_AMOUNT with EAMOUNT_TOO_SMALL;
    // ... other clauses unchanged
}
```

**Step 3: Verify MSL**

```bash
movement move prove --filter withdraw_to_internal
# Should pass with new abort condition
```

**Step 4: Check if bytecode changed**

```bash
# Compile and compare bytecode
movement move build --package-dir aptos-move/framework/aptos-experimental

# Check instruction count
# If PC count changed → must update Lean proof
# If PC count unchanged → Lean proof likely still works
```

**If bytecode changed:** Update Lean proofs following §2.2 Step 4.

**Step 5: Add difftest test case**

```rust
#[test]
fn test_withdraw_amount_too_small() {
    let account = setup_account_with_balance(1000);
    let amount = 5;  // Below MIN_WITHDRAWAL_AMOUNT = 10
    
    let result = execute_withdraw(account, amount);
    
    assert_eq!(result, Aborted(0x30010));  // E_AMOUNT_TOO_SMALL
}
```

**Step 6: Run verification**

```bash
./audit/verify-ca.sh --op withdraw
# Should pass with new test case
```

**Step 7: Update documentation**

```bash
# Update CLAIMS.md to mention new abort condition
vim audit/CLAIMS.md

# Under "Withdraw" section:
# aborts_if amount < MIN_WITHDRAWAL_AMOUNT with EAMOUNT_TOO_SMALL;
```

---

## 4. Code Review Workflow

### 4.1 Reviewer Checklist

**For reviewer reviewing a CA PR:**

**Step 1: Verify claims match code**

```bash
# Check that CLAIMS.md accurately reflects what's verified
# Read the claim, then verify it matches the actual spec/proof

# Example:
# Claim says: "Transfer preserves balance sum"
# Check MSL spec:
grep "ensures.*balance.*sum" aptos-experimental/sources/confidential_asset/confidential_asset.spec.move
# Should find the matching ensures clause
```

**Step 2: Check for verification bypasses**

```bash
# No sorry
grep -r "sorry" lean/MovementFormal/Experimental/ConfidentialAsset/

# No pragma verify = false (unless explicitly documented)
grep -r "pragma verify = false" aptos-experimental/sources/confidential_asset/

# No axioms added (unless explicitly documented and approved)
./scripts/check_axioms.sh
diff audit/axiom-baseline.txt <(./scripts/check_axioms.sh --output)
# Should show no diff (or only approved new axioms)
```

**Step 3: Run verification locally**

```bash
# Don't trust CI alone — verify locally
./audit/verify-ca.sh --op <affected-operation>
# Should complete in <3 min and pass
```

**Step 4: Check performance**

```bash
# Verify build times within budget
time lake build MovementFormal.Experimental.ConfidentialAsset.<OPERATION>.EvalEquiv
# Should be <180s

# Check heartbeat count
lake build <File> --verbose 2>&1 | grep heartbeats
# Should be <10M per theorem
```

**Step 5: Review proof quality**

**Red flags:**
- `set_option maxHeartbeats` used without justification
- Large monolithic proofs (>200 lines without factoring)
- Bare `simp` instead of `simp only [...]`
- Chained state definitions (see PERFORMANCE_OPTIMIZATION_GUIDE.md §3.2)

**Good signs:**
- `@[irreducible]` on state constructors
- PC-range helper lemmas
- Clear comments explaining non-obvious steps
- Proof structure mirrors bytecode structure

### 4.2 Common Review Comments

**MSL specs:**
- "Add `requires` clause to narrow verification scope"
- "This `ensures` is too weak — doesn't capture X property"
- "Add `pragma opaque` to avoid VC timeout"
- "Factor this complex expression into a spec function"

**Lean proofs:**
- "Add `@[irreducible]` to this state definition (performance)"
- "Replace `simp` with `simp only [...]`"
- "Factor PCs 10-20 into a helper lemma"
- "Use `Array.get?` instead of `Array.get!` in statement"

**Difftest:**
- "Add test case for this abort condition"
- "This test is non-deterministic (use fixed seed)"
- "Add edge case: empty list, single element, maximum size"

---

## 5. Local Testing Workflow

### 5.1 Quick Iteration Loop

**During active development:**

```bash
# Edit file
vim aptos-move/framework/aptos-experimental/sources/confidential_asset/confidential_asset.move

# Quick check: does it compile?
movement move build --package-dir aptos-move/framework/aptos-experimental
# Should complete in ~1s

# Quick check: MSL spec
movement move prove --filter <changed_function> --vc-timeout 60
# Should complete in <60s

# Quick check: Lean (if changed)
lake build MovementFormal.Experimental.ConfidentialAsset.<OPERATION>.EvalEquiv
# Should complete in <3s (incremental)

# Quick check: difftest (if changed)
cargo test test_<operation> --release
# Should complete in <1s
```

**Total iteration time: <10s** (with hot caches).

### 5.2 Pre-Commit Checks

**Before every commit:**

```bash
# Run pre-commit hook
./scripts/pre-commit-hook.sh
# Checks:
# - No sorry in Lean files
# - No pragma verify = false in MSL (unless documented)
# - Lean builds in <180s per file
# - Axiom count unchanged
# - Code formatting

# If hook passes, commit
git add <files>
git commit -m "<message>"
```

### 5.3 Pre-Push Checks

**Before every push:**

```bash
# Run standard verification suite (~5 min)
./scripts/run_verification_suite.sh --mode standard

# If green, push
git push origin <branch>

# If red, fix before pushing
```

---

## 6. PR Submission Checklist

**Before submitting PR:**

- [ ] Code compiles cleanly (no warnings)
- [ ] MSL specs verify (all VCs pass)
- [ ] Lean proofs build (no `sorry`, axiom count unchanged)
- [ ] Difftest tests pass (all test cases green)
- [ ] Performance within budget (build times <budget)
- [ ] Documentation updated (CLAIMS.md, coverage docs, COMPOSITION_CLAIMS.md)
- [ ] CI workflow updated (if new operation)
- [ ] verify-ca.sh updated (if new operation)
- [ ] Local full verification suite green
- [ ] Cross-stack consistency checks pass (abort codes, state transitions)

**PR title format:**
```
<type>(<scope>): <description>

Types: feat | fix | refactor | docs | perf | test
Scopes: ca | lean | msl | difftest | ci

Examples:
feat(ca): add batch_transfer operation with full verification
fix(msl): strengthen balance preservation spec for withdraw
perf(lean): factor transfer proof into PC-range helpers
docs(audit): update CLAIMS.md for rotation operation
```

---

## 7. Common Development Scenarios

### 7.1 "I changed Move source, now Lean proofs fail"

**Root cause:** Bytecode changed.

**Fix workflow:**

```bash
# 1. Recompile and inspect bytecode
movement move build --package-dir aptos-move/framework/aptos-experimental
movement move disassemble --bytecode-path <path-to-module>

# 2. Compare with Lean transcription
diff <disassembly> lean/MovementFormal/.../Bytecode.lean

# 3. Update Bytecode.lean with new instructions
vim lean/MovementFormal/.../Bytecode.lean

# 4. Update EvalEquiv.lean with new PC count and steps
vim lean/MovementFormal/.../EvalEquiv.lean

# 5. Rebuild
lake build MovementFormal.Experimental.ConfidentialAsset.<OPERATION>.EvalEquiv
```

**See:** `BYTECODE_TRANSCRIPTION_GUIDE.md` for detailed transcription workflow.

### 7.2 "MSL verification times out"

**Root cause:** VC too complex for SMT solver.

**Fix workflow:**

```bash
# 1. Identify which VC times out
movement move prove --filter <function> --vc-timeout 120 --verbose
# Look for: "VC #4 timeout after 120s"

# 2. Try CVC5 instead of Z3
movement move prove --cvc5 --filter <function>

# 3. If still timeout, add pragma opaque
vim <spec_file>
# Add: pragma opaque = <expensive_function>;

# 4. Or factor out complex expression
# Replace inline ensures with spec fun

# 5. Verify fix
movement move prove --filter <function>
```

**See:** `MSL_DEBUGGING_AND_TROUBLESHOOTING_GUIDE.md` §4.

### 7.3 "Axiom count increased"

**Root cause:** New axiom introduced.

**Fix workflow:**

```bash
# 1. Identify which axiom
./scripts/check_axioms.sh > current-axioms.txt
diff audit/axiom-baseline.txt current-axioms.txt

# 2. Find where it's declared
grep -r "axiom <axiom_name>" lean/

# 3. Decide: should this be an axiom?
# - Crypto primitive → yes, document in AXIOM_INVENTORY.md
# - Helper lemma → no, prove it instead
# - Temporary (work-in-progress) → mark as TEMPORARY, file issue

# 4a. If should be axiom: document and update baseline
vim audit/AXIOM_INVENTORY.md
./scripts/check_axioms.sh > audit/axiom-baseline.txt

# 4b. If should be theorem: prove it
vim lean/.../<file>.lean
# Replace: axiom my_lemma : ...
# With: theorem my_lemma : ... := by <proof>
```

### 7.4 "CI green locally, red in CI"

**Root cause:** Environment difference or flaky test.

**Debug workflow:**

```bash
# 1. Check what failed in CI
# Look at CI logs for exact error

# 2. Match CI environment locally
# Use Docker to match CI OS/toolchain
docker run -it ubuntu:22.04  # Match CI runner
# Install same tool versions as CI

# 3. Run same command as CI
# Copy exact command from CI logs and run locally

# 4. If still can't reproduce, check for:
# - Flaky test (non-deterministic inputs)
# - Timing dependency
# - Cache corruption
```

**See:** `CI_TROUBLESHOOTING_GUIDE.md` §10 (Flaky Test Diagnosis).

---

## 8. Debugging Workflows

### 8.1 Debugging Lean Proofs

**Scenario:** Proof fails with "type mismatch".

**Workflow:**

```bash
# 1. Understand the goal
# Add trace to see current goal state
theorem my_theorem : ... := by
  trace "{repr (← getMainGoal)}"
  <tactic>

# 2. Step through proof interactively
# Use Lean LSP in VS Code
# Place cursor after each tactic to see proof state

# 3. Check assumptions
# Are all hypotheses available?
# Are types what you expect?

# 4. Simplify
# Comment out failing tactic
# Try simpler tactic first (rfl, simp, assumption)

# 5. Check for common issues
# - PC counter mismatch
# - Stack/locals state mismatch
# - Missing bound proof
```

**See:** `LEAN_PROOF_TACTICS_REFERENCE.md` §8 (Debugging Tactics).

### 8.2 Debugging MSL Specs

**Scenario:** Move Prover says "VC failed".

**Workflow:**

```bash
# 1. Run with verbose output
movement move prove --filter <function> --verbose

# 2. Identify which VC failed
# Look for: "VC #3 failed: ..."

# 3. Check VC description
# Usually mentions which ensures/aborts_if clause failed

# 4. Check if it's a false alarm or real bug
# Read the failing VC
# Is the property too strong?
# Or is there a real bug in the code?

# 5. Fix
# - Add precondition (requires) to narrow scope
# - Weaken postcondition (ensures) if too strong
# - Fix Move code if real bug
```

**See:** `MSL_DEBUGGING_AND_TROUBLESHOOTING_GUIDE.md`.

### 8.3 Debugging Difftest Failures

**Scenario:** Test assertion fails.

**Workflow:**

```bash
# 1. Run test with output
cargo test test_<name> -- --show-output

# 2. Check what value was wrong
# assertion `left == right` failed
#   left: <actual>
#  right: <expected>

# 3. Determine if expected or actual is wrong
# - Run operation in Move REPL to check actual behavior
# - Review test case to check if expected value is correct

# 4. Fix
# - Update Move source if actual is wrong
# - Update test expected value if expected is wrong
```

---

## Appendix A: Tool Versions and Setup

**Required tools:**
- Lean: 4.24.0 (pinned in `lean-toolchain`)
- Movement CLI: latest (install via `curl ...` from movement docs)
- Boogie: 3.5.1 (via `movement update prover-dependencies`)
- Z3: 4.11.2 (via `movement update prover-dependencies`)
- Rust: 1.75+ (for difftest)

**Setup scripts:**
- Lean: `lean/README.md`
- Move Prover: `CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md` §5.1
- Difftest: `difftest/README.md`

---

## Appendix B: Common Commands

**Verification:**
```bash
# Full suite
./scripts/run_verification_suite.sh --mode comprehensive

# Single operation
./audit/verify-ca.sh --op transfer

# Single stack
./audit/verify-ca.sh --op transfer --stack lean
```

**Performance:**
```bash
# Benchmark all operations
./scripts/benchmark_verification.sh

# Profile specific file
time lake build <Module> --verbose
```

**Consistency:**
```bash
# Check abort codes
./scripts/reconcile_abort_codes.sh

# Check axioms
./scripts/check_axioms.sh
```

---

**END OF GUIDE**

**Questions?** Check `VERIFICATION_MAINTENANCE_HANDBOOK.md` for ongoing maintenance or ask in #formal-verification Slack.
