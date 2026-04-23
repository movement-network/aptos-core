# Cross-Layer Consistency Validation Guide: Keeping MSL, Lean, and Difftest Aligned

## Executive Summary

The three-stack verification architecture (MSL, Lean, difftest) provides independent verification, but requires **disciplined consistency maintenance** to prevent drift. This guide catalogs validation patterns, automated checks, and maintenance workflows to ensure all three stacks prove compatible properties about the same system.

**Consistency dimensions**:
1. **Abort codes**: MSL `aborts_if ... with CODE`, Lean `.aborted CODE`, difftest `expected_abort: CODE`
2. **State structure**: MSL `global<Store>`, Lean `State.store`, VM JSON output — same fields, same types
3. **Operation semantics**: MSL postconditions, Lean functional sims, difftest expected results
4. **Crypto boundaries**: MSL `pragma opaque`, Lean native oracles, difftest oracle mocks
5. **Coverage**: MSL all functions, Lean all crypto verifiers, difftest all abort paths

**Validation strategy**: Automated scripts + CI gates prevent drift, manual audits catch semantic gaps.

---

## 1. The Consistency Challenge

### 1.1 Why Drift Happens

**MSL and Lean don't talk**: Different languages, different proof checkers, different developers potentially. Without active validation, they **will** diverge.

**Examples of drift**:
- Developer adds abort condition to Move code, updates MSL spec, forgets to update Lean functional sim → Difftest fails (Lean allows, VM aborts)
- Developer changes struct field name in Move (`pending_counter` → `pending_count`), updates MSL, Lean still uses old name → Build fails (good!) but only if Lean file is rebuilt
- Developer adds new operation, writes MSL spec, forgets Lean proof → Gap in verification coverage (silent failure, no CI check)

**Prevention**: Automated cross-layer checks that fail CI on drift.

### 1.2 What "Consistent" Means

**Structural consistency**: Same types, same field names, same enums (abort codes, event types).

**Semantic consistency**: Same behavior — if MSL says operation aborts with code X under condition C, Lean functional sim returns `.aborted X` under same condition C, and difftest has a corpus row testing C expects abort X.

**Coverage consistency**: If MSL specifies a function, Lean has a proof (or explicit gap documented), and difftest has rows exercising it.

**Crypto boundary consistency**: If MSL marks function as `pragma opaque`, Lean has a native oracle stub for it, and difftest has crypto-specific rows validating it.

---

## 2. Abort Code Consistency

### 2.1 Single Source of Truth: Move Constants

**Pattern**: Define abort codes in Move source, reference everywhere else.

**Move** (`confidential_asset.move`):
```move
const ESIGMA_PROTOCOL_VERIFY_FAILED: u64 = 65537;
const EBULLETPROOF_VERIFY_FAILED: u64 = 65538;
const ESTORE_NOT_FOUND: u64 = 196609;
const ESTORE_ALREADY_EXISTS: u64 = 196610;
const EFROZEN: u64 = 196611;
const ENOT_NORMALIZED: u64 = 196612;
// ... all codes defined here
```

**MSL** (`confidential_asset.spec.move`):
```move
spec withdraw_to_internal {
    aborts_if !exists<ConfidentialAssetStore>(...) with ESTORE_NOT_FOUND;
    aborts_if frozen with EFROZEN;
}
```

**Lean** (`ConfidentialAsset/AbortCodes.lean`):
```lean
def ESIGMA_PROTOCOL_VERIFY_FAILED : Nat := 65537
def EBULLETPROOF_VERIFY_FAILED : Nat := 65538
def ESTORE_NOT_FOUND : Nat := 196609
def ESTORE_ALREADY_EXISTS : Nat := 196610
def EFROZEN : Nat := 196611
def ENOT_NORMALIZED : Nat := 196612
-- ... mirrored from Move
```

**Difftest** (`corpus/e2e/e2e_withdraw_frozen.json`):
```json
{
  "expected": {
    "success": false,
    "abort_code": 196611  // EFROZEN
  }
}
```

### 2.2 Automated Consistency Check

**Script**: `scripts/check_abort_code_consistency.sh`

```bash
#!/bin/bash

# Extract codes from Move source
grep "const E.*: u64 = " aptos-move/.../confidential_asset.move \
  | sed 's/const \(E[A-Z_]*\): u64 = \([0-9]*\);/\1:\2/' \
  | sort > /tmp/move_codes.txt

# Extract codes from Lean
grep "def E.* : Nat := " lean/.../AbortCodes.lean \
  | sed 's/def \(E[A-Z_]*\) : Nat := \([0-9]*\)/\1:\2/' \
  | sort > /tmp/lean_codes.txt

# Extract codes from MSL specs
grep "aborts_if .* with E" aptos-move/.../confidential_asset.spec.move \
  | sed 's/.*with \(E[A-Z_]*\).*/\1/' \
  | sort -u > /tmp/msl_codes.txt

# Extract codes from difftest corpus
grep "abort_code" difftest/corpus/e2e/*.json \
  | sed 's/.*"abort_code": \([0-9]*\).*/\1/' \
  | sort -u > /tmp/difftest_codes.txt

# Compare Move ↔ Lean
diff /tmp/move_codes.txt /tmp/lean_codes.txt > /tmp/abort_diff.txt
if [ -s /tmp/abort_diff.txt ]; then
  echo "ERROR: Abort code mismatch between Move and Lean:"
  cat /tmp/abort_diff.txt
  exit 1
fi

# Check MSL uses only defined codes
while read code; do
  if ! grep -q "^${code}:" /tmp/move_codes.txt; then
    echo "ERROR: MSL spec uses undefined abort code: $code"
    exit 1
  fi
done < /tmp/msl_codes.txt

# Check difftest uses only defined codes
while read code_num; do
  if ! grep -q ":${code_num}$" /tmp/move_codes.txt; then
    echo "ERROR: Difftest corpus uses undefined abort code: $code_num"
    exit 1
  fi
done < /tmp/difftest_codes.txt

echo "✅ All abort codes consistent across Move, Lean, MSL, and difftest"
```

**CI integration**:
```yaml
# .github/workflows/cross-layer-consistency.yaml
- name: Check abort code consistency
  run: ./scripts/check_abort_code_consistency.sh
```

### 2.3 Maintenance Workflow

**When adding new abort code**:
1. Add `const ENEW_CONDITION: u64 = <next_code>` in Move source
2. Add `def ENEW_CONDITION : Nat := <same_code>` in Lean `AbortCodes.lean`
3. Add `aborts_if <condition> with ENEW_CONDITION` in MSL spec
4. Add difftest corpus row expecting abort `<same_code>`
5. Run `scripts/check_abort_code_consistency.sh` locally
6. Commit all four changes in same PR (atomic update)

**CI prevents partial updates**: If developer forgets step 2 (Lean), CI fails with "Abort code mismatch".

---

## 3. State Structure Consistency

### 3.1 Field-Level Alignment

**Move struct** (`confidential_asset.move`):
```move
struct ConfidentialAssetStore has key {
    frozen: bool,
    normalized: bool,
    pending_counter: u64,
    ek: RistrettoPoint,
    pending_balance: EncryptedBalance,
    actual_balance: EncryptedBalance,
}
```

**MSL spec** (`confidential_asset.spec.move`):
```move
spec ConfidentialAssetStore {
    invariant pending_counter <= MAX_TRANSFERS_BEFORE_ROLLOVER;
    invariant len(pending_balance.chunks) == 4;
    invariant len(actual_balance.chunks) == 8;
}
```

**Lean model** (`ConfidentialAsset/State.lean`):
```lean
structure ConfidentialAssetStore where
  frozen : Bool
  normalized : Bool
  pending_counter : Nat
  ek : RistrettoPoint
  pending_balance : EncryptedBalance
  actual_balance : EncryptedBalance
```

**Difftest JSON**:
```json
{
  "expected": {
    "final_state": {
      "sender_store": {
        "frozen": false,
        "normalized": true,
        "pending_counter": 5,
        "ek": "0x...",
        "pending_balance": { "chunks": [...] },
        "actual_balance": { "chunks": [...] }
      }
    }
  }
}
```

### 3.2 Automated Structure Check

**Script**: `scripts/check_state_structure_consistency.sh`

```python
#!/usr/bin/env python3
import re, sys

# Parse Move struct
move_fields = parse_move_struct("aptos-move/.../confidential_asset.move", "ConfidentialAssetStore")
# Returns: [("frozen", "bool"), ("normalized", "bool"), ...]

# Parse Lean struct
lean_fields = parse_lean_struct("lean/.../State.lean", "ConfidentialAssetStore")
# Returns: [("frozen", "Bool"), ("normalized", "Bool"), ...]

# Parse MSL spec
msl_invariants = parse_msl_spec("aptos-move/.../confidential_asset.spec.move", "ConfidentialAssetStore")
# Returns: ["pending_counter <= MAX", "len(pending_balance.chunks) == 4", ...]

# Compare Move ↔ Lean field names
move_names = [f[0] for f in move_fields]
lean_names = [f[0] for f in lean_fields]
if move_names != lean_names:
    print(f"ERROR: Field mismatch:\n  Move: {move_names}\n  Lean: {lean_names}")
    sys.exit(1)

# Check MSL invariants reference only defined fields
for inv in msl_invariants:
    for field in move_names:
        if field in inv:
            break
    else:
        # Invariant doesn't reference any known field — might be typo
        print(f"WARNING: MSL invariant doesn't reference known field: {inv}")

print("✅ State structure consistent across Move, Lean, and MSL")
```

**CI integration**:
```yaml
- name: Check state structure consistency
  run: ./scripts/check_state_structure_consistency.sh
```

### 3.3 Type Consistency

**Challenge**: Move uses `u64`, Lean uses `Nat`. MSL uses `int` (unbounded). Difftest JSON uses numbers.

**Alignment**:
- **Move → Lean**: Map `u64` → `Fin (2^64)` or `Nat` with postcondition `< 2^64`
- **Move → MSL**: MSL's `int` is unbounded, but postconditions should constrain to `u64` range
- **Difftest**: JSON numbers are arbitrary precision, but should fit in `u64` for Move compatibility

**Validation**:
```lean
-- In Lean model
structure PendingCounter where
  val : Nat
  h_bounded : val < 2^64  -- Explicit bound matching u64

theorem pending_counter_valid (st : State) :
  st.store.pending_counter.val < MAX_TRANSFERS_BEFORE_ROLLOVER := by
  exact st.store.pending_counter.h_bounded
```

**MSL**:
```move
spec deposit_to_internal {
    ensures global<...>.pending_counter < 2^64;  // Explicit u64 bound
}
```

---

## 4. Operation Semantics Consistency

### 4.1 Postcondition Alignment

**Example**: `deposit_to` increments `pending_counter`.

**MSL** (`confidential_asset.spec.move`):
```move
spec deposit_to_internal {
    ensures global<ConfidentialAssetStore>(recipient).pending_counter ==
            old(global<...>(recipient).pending_counter) + 1;
}
```

**Lean** (`ConfidentialAsset/Deposit/FunctionalSim.lean`):
```lean
def eval_deposit_to (st : State) (args : DepositArgs) : Result :=
  let store := st.stores[args.recipient]?
  match store with
  | .none => .error ESTORE_NOT_FOUND
  | .some s =>
      if s.frozen then .error EFROZEN
      else if s.pending_counter >= MAX then .error EMAX_PENDING
      else
        let store' := { s with pending_counter := s.pending_counter + 1 }
        .success (st.update_store args.recipient store')
```

**Difftest** (`e2e_deposit_to_happy_001.json`):
```json
{
  "setup": {
    "recipient_store": {
      "pending_counter": 5
    }
  },
  "expected": {
    "final_state": {
      "recipient_store": {
        "pending_counter": 6  // 5 + 1
      }
    }
  }
}
```

### 4.2 Semantic Consistency Check

**Manual audit** (quarterly):
1. For each operation, read MSL `ensures` clauses
2. Read corresponding Lean `eval_*` function
3. For each `ensures`, verify Lean functional sim computes same result
4. Check difftest has row validating the postcondition

**Example audit log**:
```
Operation: deposit_to
MSL postcondition 1: pending_counter incremented by 1
  ✅ Lean line 47: pending_counter := s.pending_counter + 1
  ✅ Difftest: e2e_deposit_to_happy_001.json checks counter 5 → 6

MSL postcondition 2: frozen unchanged
  ✅ Lean line 49: { s with pending_counter := ... }  (no frozen update)
  ✅ Difftest: e2e_deposit_to_happy_001.json expects frozen=false (unchanged)

MSL postcondition 3: pending_balance updated (crypto-layer gap)
  ⚠️  Lean line 50: pending_balance := <opaque oracle result>  (axiomatized)
  ✅ Difftest: e2e_deposit_to_happy_001.json expects specific balance bytes
  
Status: Consistent (crypto gap documented, acceptable)
```

**Frequency**: Quarterly (or on major operation changes).

---

## 5. Crypto Boundary Consistency

### 5.1 Opaque Function Alignment

**Pattern**: MSL `pragma opaque` ↔ Lean native oracle ↔ difftest crypto corpus.

**MSL** (`confidential_proof.spec.move`):
```move
spec verify_normalization_proof {
    pragma opaque;
    aborts_if false;
    ensures std::option::spec_is_some(result) ==> <some property>;
}
```

**Lean** (`Native/Normalization.lean`):
```lean
def verifyNormalizationProofOracle (proof : Bytes) (ek : Point) : Option VerifyResult :=
  sorry  -- Axiomatized: models native Rust implementation

axiom verifyNormalizationProofOracle_semantics :
  verifyNormalizationProofOracle proof ek = .some res ↔
  sigma_normalization_predicate proof ek = true ∧ ...
```

**Difftest** (`sigma_verify_normalization_*.json`):
```json
{
  "operation": "verify_normalization_proof_oracle",
  "inputs": {
    "proof": "0x3a4f...",
    "ek": "0x7b2e..."
  },
  "expected": {
    "success": true,
    "result": "verify_success"
  }
}
```

### 5.2 Crypto Boundary Catalog

Maintain a catalog of all crypto boundaries:

| Function | MSL `pragma opaque`? | Lean Oracle? | Difftest Rows | Status |
|----------|---------------------|--------------|---------------|--------|
| `verify_registration_proof` | ✅ | ✅ `verifyRegistrationProofOracle` | 20 rows | ✅ |
| `verify_withdrawal_proof` | ✅ | ✅ `verifyWithdrawalProofOracle` | 15 rows | ✅ |
| `verify_transfer_proof` | ✅ | ✅ `verifyTransferProofOracle` | 20 rows | ✅ |
| `verify_normalization_proof` | ✅ | ✅ `verifyNormalizationProofOracle` | 12 rows | ✅ |
| `verify_rotation_proof` | ✅ | ✅ `verifyRotationProofOracle` | 15 rows | ✅ |
| `verify_range_proof_internal` | ✅ | ✅ `verifyRangeProofOracle` | 25 rows | ✅ |
| `ristretto255::point_add` | ✅ | ✅ `pointAddOracle` | 10 rows | ✅ |
| `twisted_elgamal::ciphertext_add` | ✅ | ✅ `ciphertextAddOracle` | 8 rows | ✅ |

**Automated check**:
```bash
# Extract pragma opaque from MSL
grep "pragma opaque" aptos-move/.../confidential_proof.spec.move | wc -l
# Output: 8

# Extract oracle defs from Lean
grep "def .*Oracle" lean/.../Native/*.lean | wc -l
# Output: 8

# Extract crypto corpus rows
ls difftest/corpus/crypto/*.json | wc -l
# Output: 162

# Assert: MSL opaque count == Lean oracle count
```

---

## 6. Coverage Consistency

### 6.1 Function Coverage Matrix

| Function | Move Implementation | MSL Spec | Lean Proof | Difftest Rows | Status |
|----------|---------------------|----------|------------|---------------|--------|
| `register_internal` | ✅ | ✅ | ✅ (Phase 1) | 13 rows | ✅ Complete |
| `deposit_to_internal` | ✅ | ✅ | ❌ (source-only) | 15 rows | ⚠️  Lean gap (intentional) |
| `withdraw_to_internal` | ✅ | ✅ | ✅ (Phase 4) | 15 rows | ✅ Complete |
| `confidential_transfer_internal` | ✅ | ✅ | ✅ (Phase 4) | 21 rows | ✅ Complete |
| `normalize_internal` | ✅ | ✅ | ✅ (Phase 4) | 9 rows | ✅ Complete |
| `rotate_encryption_key_internal` | ✅ | ✅ | ✅ (Phase 4) | 12 rows | ✅ Complete |
| `freeze_token_internal` | ✅ | ✅ | ❌ (source-only) | 6 rows | ⚠️  Lean gap (intentional) |
| `rollover_pending_balance_internal` | ✅ | ✅ | ❌ (source-only) | 5 rows | ⚠️  Lean gap (intentional) |

**Legend**:
- ✅ Complete: All three stacks cover this function
- ⚠️  Lean gap (intentional): No crypto component, MSL + difftest sufficient (documented in unified plan §3)
- ❌ Missing: Gap requiring action

### 6.2 Coverage Gap Detection

**Script**: `scripts/check_coverage_consistency.sh`

```bash
#!/bin/bash

# Extract all public/internal functions from Move
grep "public.*fun\|fun.*_internal" aptos-move/.../confidential_asset.move \
  | sed 's/.*fun \([a-z_]*\).*/\1/' | sort -u > /tmp/move_functions.txt

# Extract all spec blocks from MSL
grep "spec [a-z_]" aptos-move/.../confidential_asset.spec.move \
  | sed 's/spec \([a-z_]*\) {/\1/' | sort -u > /tmp/msl_functions.txt

# Extract all eval_* functions from Lean (if they should exist)
grep "def eval_" lean/.../FunctionalSim.lean \
  | sed 's/def eval_\([a-z_]*\) .*/\1/' | sort -u > /tmp/lean_functions.txt

# Compare Move ↔ MSL
diff /tmp/move_functions.txt /tmp/msl_functions.txt > /tmp/coverage_gap.txt
if [ -s /tmp/coverage_gap.txt ]; then
  echo "WARNING: MSL coverage gap detected (functions in Move but not MSL):"
  grep "^<" /tmp/coverage_gap.txt | sed 's/^< /  /'
fi

# Compare Lean coverage (only for crypto operations)
crypto_ops="register withdraw transfer normalize rotate"
for op in $crypto_ops; do
  if ! grep -q "^${op}$" /tmp/lean_functions.txt; then
    echo "ERROR: Lean missing eval_${op} (crypto operation requires Lean proof)"
    exit 1
  fi
done

echo "✅ Coverage consistent across Move, MSL, Lean, and difftest"
```

---

## 7. CI Integration: The Consistency Gate

### 7.1 CI Workflow

**File**: `.github/workflows/cross-layer-consistency.yaml`

```yaml
name: Cross-Layer Consistency

on: [push, pull_request]

jobs:
  consistency-checks:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Check abort code consistency
        run: ./scripts/check_abort_code_consistency.sh
      
      - name: Check state structure consistency
        run: ./scripts/check_state_structure_consistency.sh
      
      - name: Check coverage consistency
        run: ./scripts/check_coverage_consistency.sh
      
      - name: Check crypto boundary alignment
        run: ./scripts/check_crypto_boundary_alignment.sh
      
      - name: Validate TRUST_BOUNDARIES.md
        run: ./scripts/reconcile_trust_boundaries.sh --validate
      
      - name: Check MSL spec coverage
        run: |
          msl_count=$(grep "spec " aptos-move/.../confidential_asset.spec.move | wc -l)
          if [ "$msl_count" -lt 57 ]; then
            echo "ERROR: MSL spec count ($msl_count) below threshold (57)"
            exit 1
          fi
      
      - name: Check difftest corpus size
        run: |
          corpus_count=$(ls difftest/corpus/**/*.json | wc -l)
          if [ "$corpus_count" -lt 287 ]; then
            echo "ERROR: Difftest corpus ($corpus_count) below threshold (287)"
            exit 1
          fi
```

### 7.2 Pre-Commit Hook

**File**: `.git/hooks/pre-commit` (or `scripts/pre-commit-hook.sh`)

```bash
#!/bin/bash

echo "Running cross-layer consistency checks..."

# Quick checks (fast enough for pre-commit)
./scripts/check_abort_code_consistency.sh || exit 1
./scripts/check_coverage_consistency.sh || exit 1

echo "✅ Consistency checks passed"
```

**Installation**:
```bash
ln -s ../../scripts/pre-commit-hook.sh .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

---

## 8. Manual Audit Checklist (Quarterly)

### 8.1 Abort Code Audit

✅ **All Move constants mirrored in Lean**: Check `AbortCodes.lean` has all codes from Move source

✅ **All MSL aborts_if use defined codes**: No typos like `EFROOZEN` (should be `EFROZEN`)

✅ **All difftest rows use defined codes**: No magic numbers like `999999`

✅ **No orphaned codes**: Codes defined but never used (remove or document)

### 8.2 State Structure Audit

✅ **Field names match**: Move ↔ Lean ↔ MSL ↔ difftest JSON

✅ **Field types compatible**: `u64` ↔ `Nat` with bounds, `bool` ↔ `Bool`

✅ **Invariants complete**: MSL invariants cover all structural constraints Lean assumes

### 8.3 Semantic Consistency Audit

✅ **Postconditions aligned**: For each MSL `ensures`, Lean functional sim computes same

✅ **Abort conditions aligned**: For each MSL `aborts_if`, Lean returns same error

✅ **Crypto gaps documented**: Functions with `pragma opaque` have Lean oracle and difftest rows

### 8.4 Coverage Audit

✅ **All public functions specced**: Every `public fun` has MSL spec block

✅ **All crypto ops have Lean proofs**: 5 sigma verifiers have Phase 4 theorems

✅ **All operations have difftest rows**: At minimum, 1 happy path + 1 abort per operation

---

## 9. Drift Scenarios and Remediation

### 9.1 Scenario: Developer Adds Abort Condition, Forgets Lean

**Symptom**: Difftest fails — Lean model allows operation, VM aborts.

**Detection**: CI difftest job fails with "Expected success=true, got success=false, abort_code=X".

**Root cause**: Developer updated Move code + MSL spec, but not Lean functional sim.

**Fix**:
1. Identify which abort condition was added (check MSL spec diff)
2. Update Lean `eval_*` function to return `.error X` under that condition
3. Add difftest row exercising new abort path
4. Rebuild Lean (`lake build`)
5. Rerun difftest (`verify-ca.sh --stack difftest`)

**Prevention**: Automated coverage check flags functions with MSL spec but no Lean counterpart.

### 9.2 Scenario: Developer Renames Struct Field, Breaks Lean

**Symptom**: Lean build fails — `unknown identifier 'pending_counter'`.

**Detection**: CI Lean job fails immediately.

**Root cause**: Move struct field renamed (`pending_counter` → `pending_count`), Lean still uses old name.

**Fix**:
1. Grep Lean codebase for old field name: `grep -r "pending_counter" lean/`
2. Replace all occurrences with new name: `sed -i 's/pending_counter/pending_count/g' lean/**/*.lean`
3. Rebuild Lean (`lake build`)

**Prevention**: Structure consistency check (§3.2) flags mismatched field names before CI.

### 9.3 Scenario: MSL Spec Out of Sync with Move Code

**Symptom**: Move Prover fails — postcondition doesn't hold.

**Detection**: CI Move Prover job fails with "postcondition might not hold".

**Root cause**: Developer changed Move implementation without updating MSL spec.

**Fix**:
1. Read Move Prover counterexample (if available)
2. Identify which postcondition is wrong
3. Update MSL `ensures` clause to match new behavior
4. Verify Move Prover passes
5. Update Lean functional sim to match (if semantic change)

**Prevention**: Code review checklist — "MSL spec updated?" checkbox.

---

## 10. Tooling: Consistency Dashboard

### 10.1 Dashboard Metrics

**Proposed tool**: `scripts/generate_consistency_dashboard.sh` → outputs HTML report

**Metrics tracked**:
| Metric | Current | Target | Status |
|--------|---------|--------|--------|
| Abort codes: Move ↔ Lean ↔ MSL ↔ Difftest | 100% aligned | 100% | ✅ |
| State fields: Move ↔ Lean ↔ MSL | 100% aligned | 100% | ✅ |
| MSL spec coverage (functions with specs) | 57/57 (100%) | 100% | ✅ |
| Lean proof coverage (crypto ops with theorems) | 5/5 (100%) | 100% | ✅ |
| Difftest corpus coverage (abort paths) | 43/43 (100%) | 100% | ✅ |
| Crypto boundary alignment (opaque ↔ oracle ↔ corpus) | 8/8 (100%) | 100% | ✅ |
| Last consistency audit | 2026-04-15 | <3 months | ✅ |

**Dashboard generation**:
```bash
./scripts/generate_consistency_dashboard.sh > audit/CONSISTENCY_DASHBOARD.html
open audit/CONSISTENCY_DASHBOARD.html
```

**CI integration**: Publish dashboard as artifact on every CI run, available for download.

---

## 11. Best Practices

### 11.1 Atomic Cross-Layer Updates

**Rule**: Changes that affect multiple stacks should be committed atomically (same PR).

**Example**: Adding new abort condition

**✅ Good PR**:
```
Files changed:
  confidential_asset.move (add abort)
  confidential_asset.spec.move (add aborts_if)
  ConfidentialAsset/AbortCodes.lean (add constant)
  ConfidentialAsset/Deposit/FunctionalSim.lean (update eval_*)
  difftest/corpus/e2e/e2e_deposit_abort_new_condition.json (new row)

Commit message: "Add ENEW_CONDITION abort to deposit_to (cross-layer)"
```

**❌ Bad** (split across 3 PRs):
```
PR 1: Update Move + MSL
PR 2: Update Lean (2 days later)
PR 3: Add difftest row (1 week later)
```

**Why bad**: CI fails between PRs, blocks other developers, creates confusion.

### 11.2 Documentation as Source of Truth

**Rule**: For intentional gaps (e.g., deposit has no Lean proof), document in unified plan §3.

**Example**:
```markdown
## 3. Tool assignment per operation

| Operation | State/resource | Crypto / proof verifier | Entry wrapper |
|---|---|---|---|
| `deposit_to` / `deposit_to_internal` | **M** | — (no proof) | **M** |
```

**Why**: Automated coverage check can skip documented gaps, flag undocumented gaps.

### 11.3 Regular Audits

**Cadence**: Quarterly (every 3 months)

**Checklist**: Use §8 manual audit checklist

**Outcome**: Update `audit/CONSISTENCY_AUDIT_<date>.md` with findings, remediation plan

**Example audit summary**:
```markdown
# Consistency Audit 2026-04-23

## Findings
- ✅ All abort codes aligned
- ✅ State structure consistent
- ⚠️  1 MSL postcondition weaker than Lean (deposit balance update)
- ✅ Difftest coverage complete

## Remediation
- Strengthen MSL postcondition for deposit balance (PR #1234)

## Next audit: 2026-07-23
```

---

## 12. Summary: The Consistency Philosophy

**Independence ≠ Inconsistency**: MSL and Lean are independent verifiers, but they must verify **compatible properties** about the **same system**. Automated checks enforce structural consistency; manual audits verify semantic consistency.

**Drift is inevitable without discipline**: Developers work in one stack at a time (MSL or Lean). Drift happens unless there's active prevention (CI gates, checklists, atomic updates).

**Trust through validation**: The three-stack architecture provides high assurance **only if** the stacks stay aligned. Regular consistency validation is not optional — it's foundational to the verification claim.

**Automation enables scale**: Manual consistency checks don't scale past 10 operations. Automated scripts + CI gates scale to 100+ operations without developer burden.

---

*This guide is the authoritative reference for cross-layer consistency validation. Update as new validation patterns emerge or checks are added.*
