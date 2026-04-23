# Difftest Corpus Design and Generation Guide

## Executive Summary

Difftest is the **binding layer** that connects MSL proofs, Lean theorems, and the Move VM into a coherent verification story. This guide provides comprehensive patterns for designing, generating, maintaining, and scaling the difftest corpus to maximize bug-finding power while keeping CI time manageable.

**Current corpus (2026-04-23)**: 87 CA-specific rows + ~200 crypto/sigma rows = **287 total rows**

**Target (Phase 7 complete)**: **400-500 total rows** covering all operations, all abort paths, boundary cases, and crypto edge cases.

---

## 1. Difftest Architecture and Purpose

### 1.1 What Difftest Is (and Isn't)

**Difftest IS**:
- Runtime witness that MSL model ≡ Lean model ≡ Move VM
- Concrete input/output validation (finite, not ∀)
- Bug-finding tool (exposes model drift, compiler bugs, VM bugs)
- Regression test suite (prevents silent behavior changes)

**Difftest IS NOT**:
- A proof (it's evidence)
- Complete coverage (287 inputs ≠ 2^256 possible inputs)
- A replacement for MSL/Lean proofs (those give ∀ guarantees)

### 1.2 Three-Model Execution

For each corpus row:

```
Input: JSON { operation, args, sender, ... }
   ↓
┌────────────┬──────────────┬────────────┐
│ MSL Model  │  Lean Model  │  Move VM   │
│  (Boogie)  │  (MoveModel) │  (aptos)   │
└─────┬──────┴───────┬──────┴──────┬─────┘
      │              │             │
      ↓              ↓             ↓
  Result_MSL   Result_Lean   Result_VM
      │              │             │
      └──────────────┴─────────────┘
                ↓
         assert_eq!(all three)
```

If any assertion fails, **CI fails** → model or VM has a bug.

### 1.3 Coverage Dimensions

Design corpus to maximize coverage across:

| Dimension | Why It Matters | Example |
|-----------|----------------|---------|
| **Operations** | Each operation has unique code paths | register, deposit, withdraw, transfer, normalize, rotate, freeze |
| **Happy paths** | Validate main workflow | valid proof, sufficient balance, not frozen |
| **Abort paths** | Validate error handling | invalid proof, insufficient balance, frozen, missing store |
| **Boundary values** | Expose off-by-one bugs | amount=0, counter=MAX, balance=exactly_enough |
| **Crypto edge cases** | Validate oracle robustness | malformed proof bytes, invalid curve points, zero points |
| **State combinations** | Multi-field interactions | frozen+normalized, counter=MAX-1, multiple pending transfers |

---

## 2. Corpus Design Principles

### 2.1 Principle 1: One Row, One Invariant

Each corpus row should target **one specific property**.

**Bad** (tests too many things):
```json
{
  "name": "transfer_complex_scenario",
  "sender_frozen": false,
  "sender_normalized": true,
  "recipient_frozen": false,
  "recipient_counter": 5,
  "amount": 1000,
  "proof_valid": true
}
```

**Good** (focused):
```json
{
  "name": "transfer_happy_path_small_amount",
  "sender_normalized": true,
  "recipient_frozen": false,
  "amount": 100,
  "proof_valid": true,
  "expected": "success"
}
```

```json
{
  "name": "transfer_abort_sender_not_normalized",
  "sender_normalized": false,  // ← Single failing invariant
  "recipient_frozen": false,
  "proof_valid": true,
  "expected_abort": "ESENDER_NOT_NORMALIZED"
}
```

**Why**: When a test fails, you immediately know **which invariant** broke. Complex scenarios make debugging harder.

### 2.2 Principle 2: Cover All Abort Paths

For each operation, enumerate **every `aborts_if` clause** in the MSL spec and ensure at least one corpus row triggers it.

**Example: `withdraw_to` abort coverage**

MSL spec:
```move
spec withdraw_to {
    aborts_if !exists<ConfidentialAssetStore>(sender_addr);  // Abort 1
    aborts_if !exists<ConfidentialAssetStore>(recipient_addr);  // Abort 2
    aborts_if !verify_withdrawal_proof(...);  // Abort 3
}
```

Required corpus rows:
1. `withdraw_sender_store_missing.json` → expect abort ESTORE_NOT_FOUND (sender)
2. `withdraw_recipient_store_missing.json` → expect abort ESTORE_NOT_FOUND (recipient)
3. `withdraw_invalid_proof.json` → expect abort ESIGMA_PROTOCOL_VERIFY_FAILED

**CI check**: Script greps MSL `aborts_if` clauses and difftest corpus, asserts 1:1 mapping.

### 2.3 Principle 3: Boundary Value Analysis

For each numeric parameter, test:
- **Minimum**: 0, empty, null
- **Just above minimum**: 1, single-element
- **Typical**: Mid-range values
- **Just below maximum**: MAX - 1
- **Maximum**: u64::MAX, MAX_TRANSFERS_BEFORE_ROLLOVER

**Example: Transfer amount**

```json
{ "amount": 0, "name": "transfer_zero_amount" }           // MIN
{ "amount": 1, "name": "transfer_one_unit" }              // MIN+1
{ "amount": 1000, "name": "transfer_typical" }            // Typical
{ "amount": 18446744073709551614, "name": "transfer_max_minus_one" }  // MAX-1
{ "amount": 18446744073709551615, "name": "transfer_u64_max" }        // MAX
```

**Why**: Boundary bugs are common (e.g., `counter < MAX` vs `counter <= MAX`).

### 2.4 Principle 4: State Machine Coverage

Model each operation's preconditions as a state machine, ensure all states covered.

**Example: Normalize state machine**

```
States:
- S1: not_normalized + pending_counter > 0
- S2: normalized + pending_counter = 0
- S3: normalized + pending_counter > 0 (shouldn't happen, but test anyway)

Transitions:
- normalize(S1) → S2 (happy path)
- normalize(S2) → abort EALREADY_NORMALIZED
- normalize(S3) → abort or S2 (depending on implementation)
```

Corpus rows:
1. `normalize_happy_from_not_normalized.json` (S1 → S2)
2. `normalize_abort_already_normalized_counter_zero.json` (S2 → abort)
3. `normalize_edge_normalized_but_counter_nonzero.json` (S3 → ?)

**Why**: State machines expose logic bugs (missing state checks, invalid transitions).

### 2.5 Principle 5: Crypto Corpus Orthogonality

Crypto tests (proof verification, point arithmetic) should be **separate** from E2E operation tests.

**Separate files**:
- `corpus/crypto/sigma_verify_registration_*.json` (20 rows, pure crypto)
- `corpus/crypto/bulletproofs_verify_*.json` (15 rows, pure crypto)
- `corpus/e2e/e2e_register_*.json` (10 rows, full operation with valid crypto)

**Why**:
1. Crypto rows run faster (no full state setup)
2. Easier to diagnose failures (crypto bug vs state bug)
3. Crypto corpus reusable across operations (same sigma verifier used by multiple ops)

---

## 3. Corpus Row Anatomy

### 3.1 Standard JSON Schema

Every corpus row follows this schema:

```json
{
  "name": "unique_identifier_snake_case",
  "operation": "register | deposit | withdraw | transfer | normalize | rotate | freeze",
  "description": "Human-readable description of what this tests",
  "setup": {
    "sender": "0xA11CE",
    "recipient": "0xB0B",  // Optional, if operation involves two parties
    "token": "0xFA",
    "initial_state": {
      "sender_store": {
        "frozen": false,
        "normalized": true,
        "pending_counter": 0,
        "ek": "0x4f3a...",  // Compressed Ristretto point
        "pending_balance": { "chunks": ["0x00...", "0x00...", "0x00...", "0x00..."] },
        "actual_balance": { "chunks": ["0x7f...", "0x2e...", ...] }  // 8 chunks
      }
    }
  },
  "inputs": {
    "amount": 1000,  // Or other operation-specific inputs
    "proof": "0x3a4f...",  // Serialized proof bytes
    "new_ek": "0x8b2c..."  // For rotation
  },
  "expected": {
    "success": true,  // Or false if expecting abort
    "abort_code": null,  // Or numeric code if success=false
    "final_state": {
      "sender_store": {
        "frozen": false,
        "normalized": true,
        "pending_counter": 1,  // Updated
        "ek": "0x4f3a...",  // Unchanged
        "pending_balance": { "chunks": ["0x9e...", ...] },  // Updated
        "actual_balance": { "chunks": ["0x7f...", ...] }  // Unchanged
      }
    },
    "events": [
      {
        "type": "Deposited",
        "data": { "user": "0xA11CE", "amount_ciphertext": "0x9e..." }
      }
    ]
  },
  "tags": ["happy_path", "deposit", "small_amount"]
}
```

### 3.2 Field-by-Field Explanation

**`name`**: Unique identifier for this row. Used in CI output (`PASSED: withdraw_happy_001`). Convention: `<operation>_<scenario>_<variant>`.

**`operation`**: Enum of operation type. Maps to `verify-ca.sh --op <operation>` filter.

**`description`**: Human-readable. Appears in failure messages to help debugging.

**`setup.initial_state`**: State of all involved stores **before** operation executes. Difftest runner creates this state in VM before executing operation.

**`inputs`**: Arguments passed to the operation (amount, proof bytes, encryption key, etc.). Serialized to Move function arguments.

**`expected.success`**: Boolean. If `false`, `abort_code` must be set.

**`expected.abort_code`**: Numeric abort code (e.g., 65537 = ESIGMA_PROTOCOL_VERIFY_FAILED). `null` if success=true.

**`expected.final_state`**: State of all stores **after** operation executes (if success). Assertions check each field.

**`expected.events`**: List of events emitted (Registered, Deposited, etc.). Checked if success.

**`tags`**: List of strings for filtering. Examples: `happy_path`, `abort_frozen`, `boundary_max`, `crypto_edge`.

### 3.3 Minimal vs Full Rows

**Minimal row** (fast, focused):
```json
{
  "name": "sigma_verify_registration_valid_proof",
  "operation": "verify_registration_proof_oracle",
  "inputs": {
    "proof": "0x3a4f...",
    "ek": "0x7b2e...",
    "commitment": "0x9f1a..."
  },
  "expected": {
    "success": true,
    "result": "verify_success"
  }
}
```

**Full E2E row** (comprehensive, slower):
```json
{
  "name": "e2e_register_happy_path",
  "operation": "register",
  "setup": { ... full state ... },
  "inputs": { ... full args ... },
  "expected": { ... full final state + events ... }
}
```

**When to use each**:
- **Minimal**: Crypto oracles, pure functions, unit-level tests
- **Full E2E**: Entry points, multi-store operations, integration tests

**Ratio**: Aim for 70% minimal, 30% E2E (faster CI, easier debugging).

---

## 4. Corpus Generation Strategies

### 4.1 Manual Generation (Current Approach)

**Process**:
1. Identify invariant to test (from MSL spec or code review)
2. Write JSON row by hand
3. Run operation on VM manually to get expected output
4. Copy VM output into `expected` field
5. Add row to corpus directory
6. Run `verify-ca.sh --stack difftest` to validate

**Pros**: Full control, easy to understand
**Cons**: Time-consuming, error-prone, doesn't scale

**Estimated effort**: 15-30 min per row (including VM execution and validation)

### 4.2 Semi-Automated Generation (Recommended for Phase 7)

**Tooling**: `scripts/generate_difftest_row.sh`

**Usage**:
```bash
./scripts/generate_difftest_row.sh \
  --operation deposit \
  --scenario happy_path \
  --sender 0xA11CE \
  --recipient 0xB0B \
  --amount 1000 \
  --output corpus/e2e/e2e_deposit_happy_002.json
```

**What it does**:
1. Creates minimal setup state (sender + recipient stores with defaults)
2. Executes operation on VM with provided inputs
3. Captures VM output (final state, events, abort code)
4. Generates JSON row with actual VM results in `expected` field
5. Writes to `--output` file

**Pros**: 10× faster than manual (1-3 min per row), fewer copy-paste errors
**Cons**: Requires maintaining generator script

**Implementation** (~200 lines of Rust/Python):
```rust
fn generate_row(args: Args) -> DifftestRow {
    let setup = create_default_setup(args.sender, args.recipient);
    let vm_result = execute_on_vm(args.operation, args.inputs, setup);
    DifftestRow {
        name: format!("{}_{}_generated", args.operation, args.scenario),
        operation: args.operation,
        setup,
        inputs: args.inputs,
        expected: vm_result,  // Directly use VM output
        tags: vec![args.scenario],
    }
}
```

### 4.3 Property-Based Generation (Advanced, Phase 8+)

**Concept**: Use QuickCheck-style randomized testing to generate inputs, run through all three stacks, auto-add rows that expose disagreements.

**Pseudocode**:
```rust
#[quickcheck]
fn prop_all_stacks_agree(input: ArbitraryOperationInput) -> TestResult {
    let msl_result = msl_model_eval(input);
    let lean_result = lean_model_eval(input);
    let vm_result = aptos_vm_execute(input);
    
    if msl_result == lean_result && lean_result == vm_result {
        TestResult::passed()  // Agreement, no new corpus row needed
    } else {
        save_corpus_row(input, msl_result, lean_result, vm_result);
        TestResult::failed()  // Disagreement found, saved as new row
    }
}
```

**Pros**: Finds edge cases humans wouldn't think of, grows corpus automatically
**Cons**: Requires integrating QuickCheck with MSL + Lean + VM (estimated 2-3 months)

**ROI**: High value for Phase 8+ (comprehensive fuzz testing). Defer until Phases 1-7 complete.

### 4.4 Mutation-Based Generation

**Concept**: Take existing passing rows, mutate one field at a time, expect abort.

**Example**:
```python
def generate_mutation_rows(base_row):
    mutations = []
    
    # Mutate: sender frozen
    m1 = base_row.copy()
    m1['setup']['sender_store']['frozen'] = True
    m1['expected']['success'] = False
    m1['expected']['abort_code'] = EFROZEN
    mutations.append(m1)
    
    # Mutate: invalid proof (flip one byte)
    m2 = base_row.copy()
    m2['inputs']['proof'] = flip_byte(base_row['inputs']['proof'], index=10)
    m2['expected']['success'] = False
    m2['expected']['abort_code'] = ESIGMA_PROTOCOL_VERIFY_FAILED
    mutations.append(m2)
    
    # ... more mutations ...
    return mutations
```

**Pros**: Systematically covers abort paths, fast generation (1 base row → 10+ mutations)
**Cons**: Only finds bugs in error handling, not in happy path logic

**ROI**: Medium. Good for abort-path coverage (Phase 2/3 work). Implement as 50-line Python script.

---

## 5. Corpus Organization

### 5.1 Directory Structure

```
difftest/corpus/
├── crypto/                     # Pure crypto tests (no state)
│   ├── sigma_verify_registration_*.json  (20 rows)
│   ├── sigma_verify_withdrawal_*.json    (15 rows)
│   ├── sigma_verify_transfer_*.json      (20 rows)
│   ├── sigma_verify_normalization_*.json (12 rows)
│   ├── sigma_verify_rotation_*.json      (15 rows)
│   ├── bulletproofs_verify_*.json        (25 rows)
│   ├── ristretto_point_ops_*.json        (30 rows)
│   └── twisted_elgamal_ops_*.json        (25 rows)
├── e2e/                        # Full operation tests (with state)
│   ├── registration/
│   │   ├── e2e_register_happy_*.json     (5 rows)
│   │   ├── e2e_register_abort_*.json     (5 rows)
│   │   └── e2e_register_boundary_*.json  (3 rows)
│   ├── deposit/
│   │   ├── e2e_deposit_to_happy_*.json   (5 rows)
│   │   ├── e2e_deposit_abort_*.json      (6 rows)
│   │   └── e2e_deposit_boundary_*.json   (4 rows)
│   ├── withdrawal/
│   │   ├── e2e_withdraw_to_happy_*.json  (5 rows)
│   │   ├── e2e_withdraw_abort_*.json     (7 rows)
│   │   └── e2e_withdraw_boundary_*.json  (3 rows)
│   ├── transfer/
│   │   ├── e2e_transfer_happy_*.json     (6 rows)
│   │   ├── e2e_transfer_abort_*.json     (10 rows)
│   │   └── e2e_transfer_boundary_*.json  (5 rows)
│   ├── normalization/
│   │   ├── e2e_normalize_happy_*.json    (4 rows)
│   │   ├── e2e_normalize_abort_*.json    (3 rows)
│   │   └── e2e_normalize_boundary_*.json (2 rows)
│   ├── rotation/
│   │   ├── e2e_rotate_key_happy_*.json   (5 rows)
│   │   ├── e2e_rotate_abort_*.json       (4 rows)
│   │   └── e2e_rotate_boundary_*.json    (3 rows)
│   └── freeze/
│       ├── e2e_freeze_happy_*.json       (3 rows)
│       ├── e2e_freeze_abort_*.json       (4 rows)
│       └── e2e_unfreeze_*.json           (3 rows)
├── integration/                # Multi-operation sequences
│   ├── register_then_deposit_*.json      (3 rows)
│   ├── transfer_then_normalize_*.json    (3 rows)
│   └── freeze_thaw_cycle_*.json          (2 rows)
└── regression/                 # Bug-specific tests
    ├── bug_2026_04_15_pending_counter_overflow.json
    ├── bug_2026_03_22_frozen_check_missing.json
    └── ...
```

**Total estimate**: 162 crypto + 120 E2E + 8 integration + 10 regression = **300 rows** (up from current 287)

### 5.2 Naming Conventions

**Crypto rows**: `<verifier>_<scenario>_<variant>.json`
- Example: `sigma_verify_registration_invalid_proof_001.json`

**E2E rows**: `e2e_<operation>_<path>_<detail>.json`
- Example: `e2e_transfer_abort_recipient_frozen.json`

**Integration rows**: `<op1>_then_<op2>_<scenario>.json`
- Example: `register_then_deposit_happy_path.json`

**Regression rows**: `bug_<date>_<short_description>.json`
- Example: `bug_2026_04_23_rotation_key_corruption.json`

**Why specific naming**: Enables filtering by pattern (`verify-ca.sh --filter "e2e_transfer_*"`), makes failures easy to identify in CI logs.

---

## 6. Corpus Execution and Validation

### 6.1 Difftest Runner Architecture

**Script**: `difftest/run_corpus.sh` (or Rust binary `move-lean-difftest`)

**Per-row execution**:
```rust
fn run_row(row: DifftestRow) -> TestResult {
    // 1. Setup VM state
    let vm_state = setup_vm_state(row.setup);
    
    // 2. Execute on VM
    let vm_result = execute_operation_on_vm(vm_state, row.operation, row.inputs);
    
    // 3. Execute on Lean model
    let lean_result = lean_model_eval(row.setup, row.operation, row.inputs);
    
    // 4. Execute on MSL model (via Boogie trace interpreter)
    let msl_result = msl_model_eval(row.setup, row.operation, row.inputs);
    
    // 5. Assertions
    assert_eq!(vm_result.success, row.expected.success, "VM success mismatch");
    assert_eq!(lean_result.success, vm_result.success, "Lean ≠ VM success");
    assert_eq!(msl_result.success, vm_result.success, "MSL ≠ VM success");
    
    if vm_result.success {
        assert_eq!(vm_result.final_state, row.expected.final_state, "Final state mismatch");
        assert_eq!(lean_result.final_state, vm_result.final_state, "Lean ≠ VM state");
        assert_eq!(msl_result.final_state, vm_result.final_state, "MSL ≠ VM state");
        assert_eq!(vm_result.events, row.expected.events, "Events mismatch");
    } else {
        assert_eq!(vm_result.abort_code, row.expected.abort_code, "Abort code mismatch");
        assert_eq!(lean_result.abort_code, vm_result.abort_code, "Lean ≠ VM abort");
        assert_eq!(msl_result.abort_code, vm_result.abort_code, "MSL ≠ VM abort");
    }
    
    TestResult::Passed
}
```

### 6.2 Execution Modes

**Full run** (CI mode):
```bash
./difftest/run_corpus.sh
# Runs all 300 rows, exits non-zero on first failure
# Time: ~5-10 minutes (300 rows × 1-2 sec/row)
```

**Filtered run** (development mode):
```bash
./difftest/run_corpus.sh --filter "e2e_transfer_*"
# Runs only transfer E2E rows (21 rows)
# Time: ~30 seconds
```

**Single row** (debugging):
```bash
./difftest/run_corpus.sh --row "e2e_transfer_abort_recipient_frozen"
# Runs one row, prints verbose output
# Time: ~1 second
```

**Parallel run** (fast CI):
```bash
./difftest/run_corpus.sh --parallel 8
# Runs 8 rows in parallel (8× speedup on multi-core)
# Time: ~1-2 minutes for full corpus
```

### 6.3 Failure Reporting

**Example failure output**:
```
FAILED: e2e_transfer_happy_001
  Assertion failed: lean_result.final_state.sender_store.pending_counter ≠ vm_result
  Expected (VM): 5
  Actual (Lean): 4
  
  Lean model likely missing pending_counter increment on sender side.
  Check MovementFormal/Experimental/ConfidentialAsset/Transfer/FunctionalSim.lean:47
  
  Full trace: difftest/failures/e2e_transfer_happy_001_trace.json
```

**Trace file** (`e2e_transfer_happy_001_trace.json`):
```json
{
  "row": "e2e_transfer_happy_001",
  "vm_result": { "success": true, "sender_counter": 5, ... },
  "lean_result": { "success": true, "sender_counter": 4, ... },
  "msl_result": { "success": true, "sender_counter": 5, ... },
  "divergence": "lean_model_counter_mismatch",
  "suggested_fix": "Update eval_transfer in FunctionalSim.lean line 47"
}
```

**Why detailed traces**: Saves debugging time (know immediately which model is wrong and where to look).

---

## 7. Coverage Metrics and Tracking

### 7.1 Operation Coverage Matrix

| Operation | Happy Paths | Abort Paths | Boundary Cases | Crypto Edge | Total Rows | Target |
|-----------|-------------|-------------|----------------|-------------|------------|--------|
| Registration | 5 | 5 | 3 | (20 sigma) | 13 + 20 | 15 + 20 |
| Deposit | 5 | 6 | 4 | — | 15 | 18 |
| Withdrawal | 5 | 7 | 3 | (15 sigma) | 15 + 15 | 18 + 15 |
| Transfer | 6 | 10 | 5 | (20 sigma) | 21 + 20 | 25 + 20 |
| Normalization | 4 | 3 | 2 | (12 sigma) | 9 + 12 | 12 + 12 |
| Rotation | 5 | 4 | 3 | (15 sigma) | 12 + 15 | 15 + 15 |
| Freeze/unfreeze | 6 | 8 | — | — | 14 | 18 |
| **TOTAL** | **36** | **43** | **20** | **97** | **196** | **229** |

**Add**: 25 Bulletproofs rows, 30 Ristretto point ops, 25 ElGamal ops, 8 integration, 10 regression = **294 total rows**

### 7.2 Abort Path Coverage

**Goal**: Every `aborts_if` clause in MSL specs has ≥1 corpus row.

**Tracking script**: `scripts/check_abort_coverage.sh`
```bash
#!/bin/bash
# Extracts all aborts_if from *.spec.move, checks corpus has matching row

grep -r "aborts_if" aptos-move/framework/aptos-experimental/sources/confidential_asset/*.spec.move \
  | sed 's/.*aborts_if \(.*\) with \(.*\);/\2/' \
  | sort -u > /tmp/abort_codes.txt

grep -r "expected_abort" difftest/corpus/e2e/*.json \
  | sed 's/.*"expected_abort": \(.*\)/\1/' \
  | sort -u > /tmp/corpus_aborts.txt

diff /tmp/abort_codes.txt /tmp/corpus_aborts.txt
# Empty diff = complete coverage
```

**CI integration**: Run as part of `verify-ca.sh --coverage` mode, fail if any abort code missing.

### 7.3 Crypto Coverage

**Crypto operations** (from `ristretto255.move`, `confidential_proof.move`, `ristretto255_bulletproofs.move`):
- Sigma verify (registration, withdrawal, transfer, normalization, rotation): 5 × 15 = **75 rows** (happy + invalid + malformed × 5)
- Bulletproofs verify: **25 rows** (range proof valid + out-of-range + malformed)
- Point arithmetic (add, sub, mul): **30 rows** (basic ops + edge cases like identity, inverse)
- ElGamal ops (encrypt, add, sub): **25 rows** (homomorphic property tests)

**Total crypto**: **155 rows** (vs current ~200 → some cleanup possible)

---

## 8. Maintenance and Evolution

### 8.1 When to Add Rows

**Trigger 1: New code**
- Every new CA function → 3 rows minimum (happy, abort, boundary)
- New abort condition → 1 row
- New crypto oracle → 5 rows (valid, invalid, malformed, edge, boundary)

**Trigger 2: Bug found**
- Production bug → Add regression row in `regression/bug_<date>_<desc>.json`
- Code review comment "what if...?" → Add edge case row

**Trigger 3: Coverage gap**
- Abort coverage script finds missing code → Add row
- Code review: "This case isn't tested" → Add row

### 8.2 When to Remove Rows

**Criteria for removal**:
1. **Duplicate coverage**: Two rows test identical invariant with different inputs
2. **Obsolete**: Code changed, row no longer relevant (e.g., removed abort condition)
3. **Flaky**: Row fails non-deterministically (fix or delete, don't keep flaky)

**Process**:
1. Mark row with `"deprecated": true` in JSON
2. Run corpus without deprecated rows for 1 week
3. If no regressions, delete file
4. Document removal in `CHANGELOG.md`

**Anti-pattern**: Don't delete rows just to speed up CI. Optimize runner instead (parallelization, caching).

### 8.3 Corpus Versioning

**Approach**: Tag corpus at each release.

```bash
git tag -a corpus-v1.0 -m "Corpus snapshot for CA release 1.0"
git push origin corpus-v1.0
```

**Why**: Enables:
1. Bisecting when a row starts failing ("Was this passing in v0.9?")
2. Reproducing historical test runs
3. Auditor can verify against tagged corpus

---

## 9. Advanced Patterns

### 9.1 Multi-Operation Sequences (Integration Tests)

**Pattern**: Test operation A → operation B to validate state transitions.

**Example**: Register → Deposit
```json
{
  "name": "register_then_deposit_happy_path",
  "operations": [
    {
      "type": "register",
      "sender": "0xA11CE",
      "ek": "0x4f3a...",
      "expected": { "success": true }
    },
    {
      "type": "deposit_to",
      "sender": "0xB0B",
      "recipient": "0xA11CE",
      "amount": 1000,
      "expected": {
        "success": true,
        "recipient_pending_counter": 1
      }
    }
  ]
}
```

**Why**: Catches bugs in state initialization (e.g., register creates store with wrong default values that deposit assumes).

**Coverage targets**: 8-10 integration rows covering common workflows.

### 9.2 Chaos Testing

**Pattern**: Randomize operation order, inputs, state to find unexpected interactions.

**Pseudocode**:
```rust
fn chaos_test() {
    let mut state = initial_state();
    for _ in 0..100 {
        let op = random_operation();
        let inputs = random_inputs();
        let result = execute_all_stacks(state, op, inputs);
        assert_eq!(result.msl, result.lean);
        assert_eq!(result.lean, result.vm);
        state = result.vm.final_state;
    }
}
```

**Expected failures**: None (all stacks should agree on all random sequences).

**ROI**: High bug-finding power for Phase 8+. Requires property-based testing infrastructure.

### 9.3 Negative Testing (Invalid Inputs)

**Pattern**: Deliberately violate preconditions, expect abort.

**Examples**:
- `transfer_malformed_proof_bytes.json` → proof is not valid Ristretto encoding
- `deposit_recipient_null.json` → recipient address is 0x0
- `rotate_new_ek_identity_point.json` → new encryption key is identity (invalid)

**Coverage**: 15-20% of corpus should be negative tests (vs current ~35%).

**Balance**: Too many negative tests → CI time inflated. Focus on **unique** error paths.

---

## 10. Performance Optimization

### 10.1 Current Bottleneck Analysis

**Measured**:
- Full corpus (287 rows): ~8-10 minutes sequential
- Per-row time: ~1.5-2 seconds (VM startup dominates)
- Parallelization: Scales linearly to 8 cores (~1.5 min with `--parallel 8`)

**Bottlenecks**:
1. **VM startup overhead**: ~1 sec per row (aptos CLI launches fresh VM each time)
2. **State setup**: ~0.3 sec per E2E row (create stores, init balances)
3. **Crypto operations**: ~0.2 sec per sigma verify (Ristretto point ops)

### 10.2 Optimization Strategies

**Strategy 1: VM process reuse**

Instead of:
```rust
for row in corpus {
    let vm = launch_aptos_vm();  // 1 sec overhead
    let result = vm.execute(row);
    vm.shutdown();
}
```

Do:
```rust
let vm = launch_aptos_vm();  // 1 sec overhead once
for row in corpus {
    vm.reset_state(row.setup);  // 0.05 sec
    let result = vm.execute(row);
}
vm.shutdown();
```

**Savings**: 287 rows × 1 sec = 287 sec → 1 sec + 287 × 0.05 sec = 15 sec (**19× speedup**)

**Implementation**: Requires `aptos` CLI to support `--reuse-vm` flag (or use Rust bindings to VM directly).

**Strategy 2: State caching**

Cache common initial states (e.g., "sender normalized, recipient not frozen"):
```rust
let cache = HashMap::new();
cache.insert("standard_sender_recipient", precompute_state());

for row in corpus {
    let initial_state = cache.get(row.state_template).unwrap_or_else(|| setup_state(row));
    ...
}
```

**Savings**: 100 E2E rows × 0.3 sec state setup = 30 sec → ~5 sec (**6× speedup**)

**Strategy 3: Parallel execution**

Already implemented (`--parallel 8`), scales to 8× speedup on multi-core.

**Combined**: 10 min → 1.5 min (VM reuse) → 1 min (state caching) → **7.5 sec** (8-core parallel) = **80× total speedup**

**Target**: CI runs full corpus in **<1 minute** (achievable with these optimizations).

---

## 11. Future: Property-Based Corpus Generation

### 11.1 QuickCheck Integration

**Goal**: Generate 10,000+ randomized inputs, run through all stacks, auto-discover disagreements.

**Implementation sketch**:
```rust
use quickcheck::{Arbitrary, QuickCheck};

#[derive(Clone, Debug)]
struct ArbitraryTransferInput {
    sender: Address,
    recipient: Address,
    amount: u64,
    proof: Vec<u8>,
    // ... state fields ...
}

impl Arbitrary for ArbitraryTransferInput {
    fn arbitrary(g: &mut Gen) -> Self {
        ArbitraryTransferInput {
            sender: Arbitrary::arbitrary(g),
            recipient: Arbitrary::arbitrary(g),
            amount: Arbitrary::arbitrary(g),
            proof: gen_valid_proof_or_random(g),  // 90% valid, 10% random bytes
        }
    }
}

#[quickcheck]
fn prop_transfer_all_stacks_agree(input: ArbitraryTransferInput) -> TestResult {
    let msl = msl_eval(input);
    let lean = lean_eval(input);
    let vm = vm_eval(input);
    
    if msl == lean && lean == vm {
        TestResult::passed()
    } else {
        save_failing_input(input, msl, lean, vm);
        TestResult::failed()
    }
}
```

**Run**:
```bash
cargo test --test quickcheck_corpus -- --quickcheck-tests 10000
# Generates 10k random inputs, runs in ~30 min (with VM reuse optimization)
```

**Expected outcome**: Finds 5-10 edge cases humans didn't think of → save as regression rows.

### 11.2 Fuzzing with AFL

**Goal**: Use American Fuzzy Lop to find crashing inputs.

**Target**: Native oracles (Ristretto point decompression, proof deserialization).

**Setup**:
```rust
#[no_mangle]
pub extern "C" fn LLVMFuzzerTestOneInput(data: *const u8, size: usize) -> i32 {
    let bytes = unsafe { std::slice::from_raw_parts(data, size) };
    let _ = ristretto255::decompress_point(bytes);  // Shouldn't crash
    0
}
```

**Run**:
```bash
cargo afl build --release
cargo afl fuzz -i seeds/ -o findings/ target/release/fuzz_ristretto
```

**Expected**: After 24h, AFL finds 50-100 malformed inputs that crash or hang → add to corpus as negative tests.

---

## 12. Corpus Quality Checklist

Before marking corpus as "Phase 7 complete":

✅ **Coverage**: All `aborts_if` clauses have ≥1 row (check via `scripts/check_abort_coverage.sh`)

✅ **Boundary values**: Every numeric parameter tested at 0, 1, typical, MAX-1, MAX

✅ **Crypto edge cases**: All sigma verifiers tested with valid, invalid, malformed proofs

✅ **Integration tests**: ≥8 multi-operation sequences (register→deposit, transfer→normalize, etc.)

✅ **Regression tests**: All production bugs have regression rows in `regression/`

✅ **Performance**: Full corpus runs in ≤60 seconds on CI (with `--parallel 8` + optimizations)

✅ **Documentation**: Each row has human-readable `description` field

✅ **Naming consistency**: All rows follow `<category>_<operation>_<scenario>_<variant>.json` convention

✅ **No flaky tests**: 100 consecutive CI runs, zero flaky failures

✅ **Versioned**: Corpus tagged at release (e.g., `corpus-v1.0`)

---

## 13. Summary: The Difftest Corpus Philosophy

**Difftest is the glue** that binds MSL proofs, Lean theorems, and VM execution into a coherent verification story. Without it, MSL and Lean are **ungrounded** — proving properties of models that might not match reality.

**Quality over quantity**: 300 well-designed rows covering all invariants > 1000 random rows.

**Continuous evolution**: Corpus grows with code, shrinks when redundant, stays aligned with verification goals.

**Automation enables scale**: Manual corpus maintenance doesn't scale past 100 rows. Semi-automated + property-based generation unlocks 1000+.

**Trust model**: Difftest doesn't prove ∀-correctness (MSL and Lean do that). It proves **model fidelity** — the models match VM on concrete inputs, so the ∀-theorems apply to reality.

---

*This guide is the authoritative reference for difftest corpus design. Update as new patterns emerge or corpus grows.*
