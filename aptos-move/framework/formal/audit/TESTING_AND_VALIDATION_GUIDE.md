# CA Formal Verification — Testing & Validation Guide

**Last updated:** 2026-04-23

This guide covers all testing and validation procedures for the CA formal verification suite across all three stacks (Lean, Move Prover, difftest).

## Overview

CA formal verification uses three independent verification stacks that collectively establish correctness:

1. **Lean Stack:** Bytecode-level theorems (310 theorems across 5 operations)
2. **Move Prover Stack:** Source-level MSL specs (131 spec blocks)
3. **Difftest Stack:** VM↔Lean consistency (87+ corpus rows)

Each stack has independent test procedures and acceptance criteria.

## Lean Stack Testing

### Quick Health Check

Verify Lean environment is working:

```bash
cd aptos-move/framework/formal/lean

# Check Lean version
cat lean-toolchain
# Expected: leanprover/lean4:v4.24.0

# Check Lake version
lake --version
# Expected: Lake version 5.0.0-src+797c613

# Verify mathlib cache
lake exe cache get
# Should download/verify cache files
```

### Per-Module Testing

Test individual modules:

```bash
# Test registration (206 theorems)
lake build MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquivRebuild

# Test withdrawal (27 theorems)
lake build MovementFormal.Experimental.ConfidentialAsset.Withdrawal.EvalEquiv

# Test transfer (33 theorems)
lake build MovementFormal.Experimental.ConfidentialAsset.Transfer.EvalEquiv

# Test normalization (22 theorems)
lake build MovementFormal.Experimental.ConfidentialAsset.Normalization.EvalEquiv

# Test rotation (22 theorems)
lake build MovementFormal.Experimental.ConfidentialAsset.Rotation.EvalEquiv
```

**Expected output:** `Build completed successfully (N jobs).`

**Warnings:** 3 expected sorries (axiom bodies, proof irrelevance) - all documented in AXIOM_INVENTORY.md

### Full Tree Testing

Test entire Lean codebase:

```bash
# Full build (1896 jobs)
lake build

# Expected output:
# Build completed successfully (1896 jobs).

# Expected time: 1-6s with warm cache, 10-30 min without
```

### Test-Driven Development Workflow

When making changes:

```bash
# 1. Make changes to Lean file
vim MovementFormal/Experimental/ConfidentialAsset/Transfer/EvalEquiv.lean

# 2. Test just that file
lake build MovementFormal.Experimental.ConfidentialAsset.Transfer.EvalEquiv

# 3. If successful, test full tree
lake build

# 4. Run verification test
cd ../audit
./verify-ca.sh --op transfer --stack lean

# 5. Check for new axioms
cd ..
./scripts/check_axioms.sh --diff
```

### Axiom Verification

Check that no new axioms were introduced:

```bash
cd aptos-move/framework/formal

# Generate current axiom list
./scripts/check_axioms.sh > /tmp/current-axioms.txt

# Compare against baseline
diff audit/axiom-baseline.txt /tmp/current-axioms.txt

# Expected: No differences (or only expected changes)
```

**Acceptance criteria:**
- No new axioms beyond documented ones (26 total: 21 permanent + 5 temporary)
- All new axioms documented in AXIOM_INVENTORY.md
- Baseline updated if new axioms are intentional

### Coverage Testing

Verify theorem coverage:

```bash
cd audit
./verify-ca.sh --coverage

# Expected output shows:
# - Lean theorem counts (310 total)
# - MSL spec counts (131 total)
# - Axiom inventory (26 axioms)
```

## Move Prover Stack Testing

**Status (2026-04-22):** ✅ Toolchain installed and integrated. ⚠️ Verification blocked on ristretto255 patches (Phase 0).

### Prerequisites

```bash
# Install prover dependencies
movement update prover-dependencies --assume-yes

# Set environment variables (add to shell profile for persistence)
export BOOGIE_EXE=$HOME/.local/bin/boogie
export Z3_EXE=$HOME/.local/bin/z3
export CVC5_EXE=$HOME/.local/bin/cvc5

# Verify installation
$Z3_EXE --version    # expect: Z3 version 4.11.2
$BOOGIE_EXE -version # expect: Boogie program verifier version 3.5.1.0
```

### Compilation Testing

Test that specs compile:

```bash
cd aptos-move/framework/aptos-experimental

# Compile all specs
movement move compile \
    --package-dir . \
    --named-addresses aptos_experimental=0x7 \
    --skip-fetch-latest-git-deps

# Expected: { "Result": "Success" }
```

### Spec Verification

**Current status:** Specs compile but generate 0 VCs (verification conditions). This is expected — specs are structural scaffolds with `pragma opaque` on crypto functions. Meaningful verification blocked on ristretto255 patches.

Test via verify-ca.sh (recommended):

```bash
cd aptos-move/framework/formal/audit

# Single operation
./verify-ca.sh --op register --stack move-prover
# Expected: "Move Prover: OK (1s)" with "0 verification conditions"

# All operations
./verify-ca.sh --stack move-prover
# Expected: All 5 operations pass (~5s total)
```

Direct testing (without verify-ca.sh):

```bash
cd aptos-move/framework/aptos-experimental

# Verify register_internal
movement move prove \
    --package-dir . \
    --named-addresses aptos_experimental=0x7 \
    --filter 'register_internal' \
    --vc-timeout 120 \
    --skip-fetch-latest-git-deps

# Expected output:
# [INFO] 0 verification conditions
# {"Result": "Success"}
```

**Interpreting "0 verification conditions":**
- ✅ **Good:** Toolchain works, specs compile, no errors
- ⚠️ **Limited:** No meaningful properties verified yet (specs scaffolded)
- **Next:** Strengthen specs once ristretto255 blocker clears

**Common issues:**
- `Z3_EXE not set`: Run `movement update prover-dependencies` and export env vars
- `unresolved addresses`: Add `--named-addresses aptos_experimental=0x7`
- Verification failures with ristretto255 errors: **Expected**, blocked on Phase 0 patches

### Spec Coverage Check

Verify all functions have specs:

```bash
# List all public functions
grep -r "public fun\|public entry fun" \
    aptos-move/framework/aptos-experimental/sources/confidential_asset/*.move \
    | wc -l

# List all spec blocks
grep -r "spec.*fun" \
    aptos-move/framework/aptos-experimental/sources/confidential_asset/*.spec.move \
    | wc -l

# Compare counts - should be equal or spec count slightly higher
```

### Pragma Escape Audit

Check for verification escapes:

```bash
# Find all pragma opaque (acceptable for crypto)
grep -rn "pragma opaque" \
    aptos-move/framework/aptos-experimental/sources/confidential_asset/

# Find verification escapes (should be documented if present)
grep -rn "pragma verify = false\|pragma deactivated_proof\|pragma aborts_if_is_partial" \
    aptos-move/framework/aptos-experimental/sources/confidential_asset/

# Expected: Only pragma opaque for crypto functions, no verify=false escapes
```

## Difftest Stack Testing

### Prerequisites

```bash
# Install difftest harness
# (See difftest/README.md for setup instructions)

# Verify VM is available
movement move test --help

# Verify Lean is available
cd aptos-move/framework/formal/lean
lake build MovementFormal.Experimental.ConfidentialAsset.BytecodeDifftestBridge
```

### Corpus Validation

Check difftest corpus files:

```bash
cd aptos-move/framework/formal/difftest

# List corpus files
find corpora/confidential_asset -name "*.json" | wc -l
# Expected: 87+ files

# Validate JSON format
for file in corpora/confidential_asset/*.json; do
    jq empty "$file" || echo "Invalid JSON: $file"
done

# Expected: No output (all files valid)
```

### Per-Row Testing

Test individual difftest rows:

```bash
# Test single corpus row
./difftest.sh --suite confidential_asset --row registration_happy_path

# Test all registration rows
./difftest.sh --suite confidential_asset --filter registration

# Test all withdrawal rows
./difftest.sh --suite confidential_asset --filter withdrawal
```

**Expected output:** All rows pass with `VM output == Lean output`

### Full Difftest Run

Test all corpus rows:

```bash
# Run full difftest suite
./difftest.sh --suite confidential_asset

# Expected: All 87+ rows pass
```

**Acceptance criteria:**
- VM output matches Lean output for all rows
- No `Blocked` or `Option B` entries
- All oracle calls consistent

### Adding New Difftest Rows

When adding new corpus rows:

```bash
# 1. Create JSON file in corpus directory
cat > corpora/confidential_asset/new_test_case.json <<EOF
{
  "name": "new_test_case",
  "operation": "withdrawal",
  "inputs": { ... },
  "expected_output": "success"
}
EOF

# 2. Validate JSON
jq empty corpora/confidential_asset/new_test_case.json

# 3. Run difftest on new row
./difftest.sh --suite confidential_asset --row new_test_case

# 4. Document in DIFFTEST_CA_INVENTORY.md
echo "| new_test_case | withdrawal | success | ... |" >> audit/DIFFTEST_CA_INVENTORY.md
```

## Integrated Testing

### Full 3-Stack Verification

Test all three stacks together:

```bash
cd aptos-move/framework/formal/audit

# Run full verification (all stacks, all operations)
./verify-ca.sh

# Expected:
# - Lean: ✓ (6s for all 5 operations)
# - Move Prover: ✓ (5-10 min estimate)
# - Difftest: ✓ (2-5 min estimate)
# Total: <45 min (budget: 45 min)
```

### Per-Operation Integration

Test single operation across all stacks:

```bash
# Test registration across all stacks
./verify-ca.sh --op register

# Test withdrawal across all stacks
./verify-ca.sh --op withdraw

# Expected: All 3 stacks pass for that operation
```

### Smoke Test

Quick test that everything is working:

```bash
# Lean only (fastest)
./verify-ca.sh --op register --stack lean
# Expected: ~1s, passes

# Move Prover only
./verify-ca.sh --op register --stack move-prover
# Expected: ~10-30s, passes

# Difftest only
./verify-ca.sh --op register --stack difftest
# Expected: ~5-10s, passes
```

## Regression Testing

### Automated Regression Suite

Run after any code changes:

```bash
#!/bin/bash
# regression-test.sh

echo "=== Regression Test Suite ==="

# 1. Lean full build
echo "1. Testing Lean full build..."
cd aptos-move/framework/formal/lean
lake build || { echo "❌ Lean build failed"; exit 1; }

# 2. Axiom check
echo "2. Checking axioms..."
cd ..
./scripts/check_axioms.sh --diff || { echo "❌ New axioms detected"; exit 1; }

# 3. Per-operation verification
echo "3. Testing per-operation verification..."
cd audit
for op in register withdraw transfer normalize rotate; do
    echo "  Testing $op..."
    ./verify-ca.sh --op $op --stack lean || { echo "❌ $op failed"; exit 1; }
done

# 4. Coverage check
echo "4. Checking coverage..."
./verify-ca.sh --coverage | grep "310 theorems" || { echo "❌ Coverage changed"; exit 1; }

echo "✅ All regression tests passed"
```

### Before/After Comparison

Compare performance and results before/after changes:

```bash
# Before changes
git stash
./verify-ca.sh --stack lean > /tmp/before.txt 2>&1
BEFORE_TIME=$(grep "Total time:" /tmp/before.txt | awk '{print $3}')

# After changes
git stash pop
lake clean && lake exe cache get && lake build
./verify-ca.sh --stack lean > /tmp/after.txt 2>&1
AFTER_TIME=$(grep "Total time:" /tmp/after.txt | awk '{print $3}')

# Compare
echo "Before: ${BEFORE_TIME}"
echo "After: ${AFTER_TIME}"
diff /tmp/before.txt /tmp/after.txt
```

## Acceptance Criteria

### Phase 7 Completion (Plan §10.6)

**Lean Stack:**
- [ ] All 310 theorems verify successfully
- [ ] Per-operation time ≤180s (currently: 1-2s ✅)
- [ ] Full run time ≤2700s (currently: 6s ✅)
- [ ] No unexpected axioms (26 documented total)
- [ ] verify-ca.sh --stack lean passes

**Move Prover Stack:**
- [x] Toolchain installed (Z3 4.11.2, Boogie 3.5.1, CVC5 0.0.3) ✅
- [x] Compilation succeeds for all modules ✅
- [x] verify-ca.sh --stack move-prover integration complete ✅
- [ ] VCs generated (currently 0 — blocked on ristretto255 patches) ⚠️
- [ ] All spec blocks verify successfully (pending ristretto255 + spec strengthening)
- [ ] No pragma verify=false escapes ✅ (currently no escapes)

**Difftest Stack:**
- [ ] All 87+ corpus rows pass
- [ ] VM output matches Lean output
- [ ] verify-ca.sh --stack difftest passes

**Integration:**
- [ ] verify-ca.sh (full 3-stack) completes in ≤45 min
- [ ] All operations pass across all stacks
- [ ] No regressions in any stack

## CI Integration

### Required CI Jobs

**Job 1: Lean Verification**
```yaml
- name: Lean Verification
  run: |
    cd aptos-move/framework/formal/audit
    ./verify-ca.sh --stack lean
  timeout-minutes: 15
```

**Job 2: Axiom Diff Guard**
```yaml
- name: Axiom Diff
  run: |
    cd aptos-move/framework/formal
    ./scripts/check_axioms.sh --diff
  timeout-minutes: 5
```

**Job 3: Move Prover (when Z3 set up)**
```yaml
- name: Move Prover Verification
  run: |
    cd aptos-move/framework/formal/audit
    ./verify-ca.sh --stack move-prover
  timeout-minutes: 30
```

**Job 4: Difftest (when harness set up)**
```yaml
- name: Difftest Verification
  run: |
    cd aptos-move/framework/formal/audit
    ./verify-ca.sh --stack difftest
  timeout-minutes: 20
```

### PR Requirements

Before merging any PR that touches formal verification:

- [ ] All Lean tests pass
- [ ] Axiom diff check passes (or new axioms documented)
- [ ] verify-ca.sh --op <changed-op> --stack lean passes
- [ ] Performance within budget (timing checks)
- [ ] Documentation updated (if new claims added)

## Troubleshooting

### Common Test Failures

**Lean: "unknown identifier"**
- **Cause:** Typo or missing import
- **Fix:** Check spelling, add import statement

**Lean: "type mismatch"**
- **Cause:** Incorrect type in proof
- **Fix:** Check types with `#check`, fix proof

**Lean: "tactic failed"**
- **Cause:** Proof tactic doesn't apply
- **Fix:** Try different tactic or add intermediate steps

**Move Prover: "VC failed"**
- **Cause:** Spec is incorrect or too weak
- **Fix:** Strengthen preconditions, add invariants

**Difftest: "VM ≠ Lean"**
- **Cause:** Oracle mismatch or bug
- **Fix:** Check oracle implementation, verify corpus input

### Debug Procedures

**Debug Lean failure:**
```bash
# Run with verbose output
lake build --verbose MovementFormal.Experimental.ConfidentialAsset.Transfer.EvalEquiv

# Check specific theorem
# Add `#check` or `#print` in Lean file to inspect types
```

**Debug Move Prover failure:**
```bash
# Generate Boogie file for inspection
movement move prove \
    --package-dir aptos-move/framework/aptos-experimental \
    --named-addresses aptos_experimental=0x7 \
    --filter register_internal \
    --generate-only

# Check generated Boogie
cat boogie.bpl
```

**Debug difftest failure:**
```bash
# Run with verbose output
./difftest.sh --suite confidential_asset --row failing_test --verbose

# Check VM output
# Check Lean output
# Compare manually
```

## Best Practices

### Before Committing

```bash
# Full test checklist
cd aptos-move/framework/formal

# 1. Lean build
cd lean && lake build

# 2. Axiom check
cd .. && ./scripts/check_axioms.sh --diff

# 3. Verification test
cd audit && ./verify-ca.sh --stack lean

# 4. Coverage check
./verify-ca.sh --coverage | grep "310 theorems"

# 5. Git status (check for unintended changes)
git status

# All pass? Commit!
git commit -m "..."
```

### Continuous Testing

Run tests frequently during development:

```bash
# Use file watcher for continuous testing
while inotifywait -e modify MovementFormal/**/*.lean; do
    lake build && echo "✅ Build passed"
done
```

### Test Documentation

Document new tests in CLAIMS.md:

```markdown
| New claim | Lean | file.lean:123 → theorem_name | ./verify-ca.sh --op <op> --stack lean | Relies on: ... |
```

## Summary

**Testing coverage:**
- ✅ Lean: 310 theorems across 5 operations
- ✅ Move Prover: Toolchain set up, 6 spec files compile cleanly (0 VCs, blocked on ristretto255)
- 🟡 Difftest: 87+ corpus rows (pending harness setup)

**Testing tools:**
- verify-ca.sh: Single-command verification across all stacks
- lake build: Lean theorem checking
- movement move prove: MSL spec verification
- difftest.sh: VM↔Lean consistency checking

**Acceptance:** All tests must pass before merge, with timing within budgets and no unexpected axioms.

**Current status (2026-04-22 evening):**
- ✅ Lean stack: Fully tested and passing (~6s for all 5 operations)
- ✅ Move Prover stack: Toolchain installed, verify-ca.sh integrated, compilation tested
  - Blocked on ristretto255 verification patches for meaningful VCs
  - Infrastructure ready for when blocker clears
- 🟡 Difftest stack: Pending harness setup

**See also:** `MOVE_PROVER_INTEGRATION_STATUS.md` for detailed Move Prover status and roadmap.
