# Difftest Harness Implementation Guide

**Last updated:** 2026-04-22

Complete guide for implementing the difftest harness for CA formal verification. Covers architecture, corpus design, integration with verify-ca.sh, and troubleshooting.

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Harness Structure](#harness-structure)
4. [Corpus Row Design](#corpus-row-design)
5. [Integration Points](#integration-points)
6. [Implementation Steps](#implementation-steps)
7. [Testing Strategy](#testing-strategy)
8. [Troubleshooting](#troubleshooting)

---

## Overview

### What is Difftest?

**Differential testing** = running the same inputs through multiple implementations and checking outputs match:
- **Move VM:** Real production runtime
- **Lean `MoveModel.step`:** Formal model (bytecode semantics)
- **Move Prover:** Solver-based verification

**Goal:** Catch model-reality drift (transcription bugs, VM changes, specification errors).

### Current Status (2026-04-22)

- **Corpus:** 87+ rows defined in `difftest/inventory/confidential_assets.md`
- **Harness:** Pending implementation (Phase 7 blocker)
- **Integration:** `verify-ca.sh --stack difftest` scaffolded but non-functional

**Remaining work:** ~1 day (harness implementation + integration)

---

## Architecture

### Three-Layer Stack

```
┌─────────────────────────────────────┐
│  verify-ca.sh --stack difftest      │ ← User-facing script
└─────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────┐
│  difftest.sh                        │ ← Rust runner invocation
└─────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────┐
│  move-lean-difftest (Rust)          │ ← Harness implementation
│  - Reads corpus from JSON/TOML      │
│  - Invokes Move VM                  │
│  - Invokes Lean evaluator           │
│  - Compares outputs                 │
└─────────────────────────────────────┘
                 │
                 ├────────────────────┐
                 ▼                    ▼
         ┌───────────────┐    ┌─────────────────┐
         │  Move VM      │    │  Lean Evaluator │
         │  (MoveOS)     │    │  (lake env)     │
         └───────────────┘    └─────────────────┘
```

### Data Flow

1. **Corpus definition** (TOML/JSON): Input/output pairs
2. **Harness reads corpus:** Parse rows, validate schema
3. **For each row:**
   - Run Move VM with input → VM output
   - Run Lean eval with same input → Lean output
   - Compare: VM output == Lean output?
4. **Report:** Pass/fail per row, summary stats

---

## Harness Structure

### File Organization

```
difftest/
├── Cargo.toml                  # Rust harness package
├── src/
│   ├── main.rs                # CLI entry point
│   ├── corpus.rs              # Corpus parsing (JSON/TOML)
│   ├── vm_runner.rs           # Move VM invocation
│   ├── lean_runner.rs         # Lean evaluator invocation
│   ├── comparator.rs          # Output comparison logic
│   └── report.rs              # Test results formatting
├── corpora/
│   └── confidential_assets/
│       ├── corpus.toml        # Main corpus definition
│       ├── *.hex              # Binary test inputs (87+ files)
│       └── README.md          # Corpus documentation
└── README.md                  # Harness usage guide
```

### Corpus Schema (TOML)

```toml
[[test]]
name = "sigma18_len"
description = "VM layout_sigma_*().length() vs 1152"
mode = "vm-lean"  # or "vm-only"
function_index = 128
inputs = []
expected_output = { type = "bool", value = true }
corpus_file = "deserialize_sigma_18_scalars_18_points.hex"

[[test]]
name = "register_roundtrip"
mode = "vm-lean"
function_index = 35
inputs = [
    { type = "u64", value = 42 },      # dk
    { type = "u64", value = 9999 }     # k
]
expected_output = { type = "bool", value = true }
```

**Schema fields:**
- `name`: Unique test identifier (maps to Rust suite label)
- `description`: Human-readable test purpose
- `mode`: `"vm-lean"` (full round-trip) or `"vm-only"` (regression only)
- `function_index`: Lean `funcIdx` (maps to Move function)
- `inputs`: List of typed values (u64, bool, vector<u8>, etc.)
- `expected_output`: Expected result (for VM-only mode)
- `corpus_file`: (optional) Path to binary input file (.hex)

---

## Corpus Row Design

### Row Categories

**1. Constants (trivial, smoke test):**
```toml
[[test]]
name = "chunk_bits"
mode = "vm-lean"
function_index = 2
inputs = []
expected_output = { type = "u64", value = 64 }
```

**2. Roundtrip (serialize → deserialize):**
```toml
[[test]]
name = "balance_compress_decompress"
mode = "vm-lean"
function_index = 47
inputs = [
    { type = "vector<u8>", hex_file = "zero_pending_balance.hex" }
]
expected_output = { type = "bool", value = true }
```

**3. Crypto operations (native oracles):**
```toml
[[test]]
name = "schnorr_helpers_roundtrip"
mode = "vm-lean"
function_index = 35
inputs = [
    { type = "u64", value = 42 },
    { type = "u64", value = 9999 }
]
expected_output = { type = "bool", value = true }
oracle = "caRegistrationHelpersRoundtripNative"
```

**4. Error paths (abort codes):**
```toml
[[test]]
name = "verify_withdrawal_zero_sigma_aborts"
mode = "vm-lean"
function_index = 195
inputs = [
    { type = "vector<u8>", value = [] }  # Empty sigma
]
expected_output = { type = "aborted", code = 65537 }  # ESIGMA_PROTOCOL_VERIFY_FAILED
```

### Design Principles

**Coverage:**
- ≥3 rows per function (happy path + 2 error paths)
- All abort codes exercised
- Edge cases (zero balances, empty vectors, max values)

**Independence:**
- Each row is self-contained (no shared state)
- Order doesn't matter (parallelizable)
- Deterministic (same input → same output always)

**Debuggability:**
- Descriptive names (`sigma18_len` not `test_042`)
- Clear expected output
- Link to corpus file for complex inputs

---

## Integration Points

### 1. verify-ca.sh Integration

**File:** `audit/verify-ca.sh`

**Add difftest stack:**

```bash
case "$STACK" in
    lean)
        # Existing Lean verification
        ;;
    move-prover)
        # Existing Move Prover verification
        ;;
    difftest)
        # NEW: Difftest harness invocation
        echo "Running difftest for operation: $OP"
        cd "$FORMAL_ROOT/difftest"
        cargo run --release -- \
            --corpus corpora/confidential_assets/corpus.toml \
            --filter "$OP" \
            --output json
        ;;
esac
```

**Filter by operation:**

```bash
# Map operation name to corpus tags
case "$OP" in
    register)
        FILTER="register|schnorr|fs_reg"
        ;;
    withdraw)
        FILTER="withdraw|sigma18"
        ;;
    transfer)
        FILTER="transfer|sigma_tr"
        ;;
    # etc.
esac
```

### 2. Lean Evaluator Integration

**File:** `difftest/src/lean_runner.rs`

**Invoke Lean:**

```rust
use std::process::Command;

pub fn eval_lean(function_idx: u64, inputs: &[Value]) -> Result<Value, Error> {
    // Serialize inputs to JSON
    let input_json = serde_json::to_string(&inputs)?;
    
    // Invoke Lean evaluator
    let output = Command::new("lake")
        .arg("env")
        .arg("lean")
        .arg("--run")
        .arg("scripts/difftest_eval.lean")
        .arg(function_idx.to_string())
        .arg(&input_json)
        .current_dir("lean/")
        .output()?;
    
    // Parse Lean output JSON
    let result: Value = serde_json::from_slice(&output.stdout)?;
    Ok(result)
}
```

**Lean side (scripts/difftest_eval.lean):**

```lean
import MovementFormal.Experimental.ConfidentialAsset.Programs

def main (args : List String) : IO Unit := do
  match args with
  | [funcIdx, inputJson] =>
    let inputs := parseInputs inputJson
    let result := eval (funcIdx.toNat!) inputs
    IO.println (toJson result)
  | _ =>
    IO.eprintln "Usage: difftest_eval <funcIdx> <inputJson>"
```

### 3. VM Integration

**File:** `difftest/src/vm_runner.rs`

**Invoke Move VM:**

```rust
use move_vm_runtime::move_vm::MoveVM;

pub fn eval_vm(
    vm: &MoveVM,
    module_id: &ModuleId,
    function_name: &str,
    inputs: &[Value]
) -> Result<Value, Error> {
    // Load module bytecode
    let module = vm.load_module(module_id)?;
    
    // Find function
    let func = module.function_map.get(function_name)?;
    
    // Execute with inputs
    let session = vm.new_session(&state_view);
    let result = session.execute_function(func, inputs, &mut gas_meter)?;
    
    Ok(result)
}
```

---

## Implementation Steps

### Step 1: Corpus Finalization (2 hours)

**Task:** Convert inventory to TOML corpus.

**Input:** `difftest/inventory/confidential_assets.md`  
**Output:** `difftest/corpora/confidential_assets/corpus.toml`

**Process:**

1. Parse markdown inventory (87+ rows)
2. For each row:
   - Extract: name, mode, function_index, inputs, expected_output
   - Write TOML entry
   - Validate schema
3. Link binary corpus files (.hex)

**Validation:**

```bash
cd difftest/corpora/confidential_assets
cargo run --bin validate-corpus -- corpus.toml
```

### Step 2: Harness Core (4 hours)

**Task:** Implement Rust harness skeleton.

**Files:**
- `difftest/src/main.rs` — CLI arg parsing
- `difftest/src/corpus.rs` — TOML parsing
- `difftest/src/comparator.rs` — Output comparison

**Key functions:**

```rust
// corpus.rs
pub fn load_corpus(path: &Path) -> Result<Vec<TestCase>, Error>;

// comparator.rs
pub fn compare_values(vm_output: &Value, lean_output: &Value) -> bool;
pub fn compare_abort_codes(vm_code: u64, lean_code: u64) -> bool;
```

**Test:**

```bash
cargo test --package move-lean-difftest
```

### Step 3: VM Runner (2 hours)

**Task:** Integrate Move VM invocation.

**File:** `difftest/src/vm_runner.rs`

**Dependencies:**
- `move-vm-runtime`
- `move-binary-format`
- `aptos-vm` (for state_view)

**Test:**

```rust
#[test]
fn test_vm_eval_constant() {
    let vm = setup_vm();
    let result = eval_vm(&vm, &CA_MODULE_ID, "get_chunk_size_bits", &[]);
    assert_eq!(result, Value::u64(64));
}
```

### Step 4: Lean Runner (2 hours)

**Task:** Integrate Lean evaluator invocation.

**Files:**
- `difftest/src/lean_runner.rs` (Rust side)
- `lean/scripts/difftest_eval.lean` (Lean side)

**Lean script:**

```lean
-- Parse JSON inputs, eval function, output JSON result
def evalDifftest (funcIdx : Nat) (inputs : List Value) : IO Value := do
  let env := registrationModuleEnv  -- Or other module env
  let result := MoveModel.eval env funcIdx inputs
  pure result

def main (args : List String) : IO Unit := do
  match args with
  | [funcIdxStr, inputJson] =>
    let funcIdx := funcIdxStr.toNat!
    let inputs := Json.parse inputJson |>.bind parseInputs
    let result ← evalDifftest funcIdx inputs
    IO.println (toJson result)
  | _ => IO.eprintln "Usage: difftest_eval <funcIdx> <inputJson>"
```

**Test:**

```bash
lake env lean --run scripts/difftest_eval.lean 2 '[]'
# Expected: {"type":"u64","value":64}
```

### Step 5: Integration (2 hours)

**Task:** Wire into `verify-ca.sh`.

**Changes:**
- Add `difftest` case to `--stack` switch
- Add operation filtering
- Add JSON output parsing

**Test:**

```bash
./audit/verify-ca.sh --op register --stack difftest
# Expected: Run difftest for registration (schnorr, fs_reg, etc.)
```

### Step 6: CI Integration (1 hour)

**Task:** Add difftest to CI workflow.

**File:** `.github/workflows/ca-verification-suite.yaml`

**Add job:**

```yaml
difftest-check:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v3
    - name: Setup Lean
      run: |
        curl -sSf https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh | sh -s -- -y
        cd aptos-move/framework/formal/lean && lake exe cache get
    - name: Setup Rust
      run: rustup default stable
    - name: Run difftest
      run: |
        cd aptos-move/framework/formal
        ./audit/verify-ca.sh --stack difftest
```

---

## Testing Strategy

### Unit Tests

**Corpus parsing:**

```rust
#[test]
fn test_parse_corpus_toml() {
    let corpus = load_corpus("test_data/sample_corpus.toml").unwrap();
    assert_eq!(corpus.len(), 5);
    assert_eq!(corpus[0].name, "chunk_bits");
}
```

**Value comparison:**

```rust
#[test]
fn test_compare_u64() {
    let vm_val = Value::u64(42);
    let lean_val = Value::u64(42);
    assert!(compare_values(&vm_val, &lean_val));
}

#[test]
fn test_compare_abort_codes() {
    assert!(compare_abort_codes(65537, 65537));
    assert!(!compare_abort_codes(65537, 65538));
}
```

### Integration Tests

**End-to-end (smoke test):**

```bash
#!/usr/bin/env bash
# Test one simple corpus row end-to-end

cd difftest
cargo run --release -- \
    --corpus test_data/smoke_test.toml \
    --output json > /tmp/difftest_smoke.json

# Check: all tests passed
jq '.summary.passed == .summary.total' /tmp/difftest_smoke.json
```

**Per-operation:**

```bash
for op in register withdraw transfer normalize rotate; do
    ./audit/verify-ca.sh --op "$op" --stack difftest || exit 1
done
```

### Regression Tests

**Baseline capture:**

```bash
./audit/verify-ca.sh --stack difftest --output json > difftest/baselines/baseline-$(date +%Y%m%d).json
```

**Regression check:**

```bash
# Compare current against baseline
diff <(jq -S . difftest/baselines/baseline-latest.json) \
     <(./audit/verify-ca.sh --stack difftest --output json | jq -S .)
```

---

## Troubleshooting

### Problem: VM output doesn't match Lean output

**Diagnosis:**

```bash
# Run with verbose output
cargo run -- --corpus corpus.toml --filter failing_test --verbose

# Compare outputs:
# VM:   Value::bool(true)
# Lean: Value::bool(false)
```

**Common causes:**

1. **Transcription bug:** Lean bytecode doesn't match VM bytecode
   - Fix: Re-transcribe from VM disassembly
   - Verify: `movement move disassemble` vs Lean `Programs/*.lean`

2. **Oracle mismatch:** Lean oracle returns different value than VM native
   - Fix: Update Lean oracle definition in `Native/*.lean`
   - Verify: Add debug prints to both sides

3. **State drift:** VM and Lean have different initial state
   - Fix: Ensure both start from `MachineState.empty`
   - Verify: Check state initialization in both runners

### Problem: Difftest hangs / times out

**Diagnosis:**

```bash
# Run with timeout
timeout 10s cargo run -- --corpus corpus.toml --filter hanging_test
```

**Common causes:**

1. **Infinite loop in Lean:** Eval doesn't terminate
   - Fix: Add fuel parameter to `eval`
   - Default: 1000 steps max

2. **VM deadlock:** Waiting on unavailable resource
   - Fix: Mock external dependencies (FA, object storage)

3. **Large corpus file:** Parsing takes too long
   - Fix: Split large corpus into smaller files

### Problem: Lean evaluator not found

**Error:** `lake: command not found`

**Fix:**

```bash
# Install Lean toolchain
curl https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh -sSf | sh

# Verify
lake --version

# Fetch mathlib cache
cd lean && lake exe cache get
```

### Problem: Corpus schema validation fails

**Error:** `Invalid TOML: missing field 'function_index'`

**Fix:**

```bash
# Validate corpus manually
cargo run --bin validate-corpus -- corpora/confidential_assets/corpus.toml

# Fix TOML entries per error messages
```

---

## Performance Targets

**Per-row timing:**
- Simple constants: <10ms
- Roundtrip tests: <100ms
- Crypto operations: <500ms

**Full corpus:**
- 87 rows: <10 seconds total
- Parallelized: <5 seconds (use `rayon` for parallel execution)

**Integration:**
- `verify-ca.sh --stack difftest`: <1 minute (all ops)

---

## Next Steps After Implementation

1. **Expand corpus:** Add more error paths, edge cases
2. **CI integration:** Add to `ca-verification-suite.yaml`
3. **Performance optimization:** Parallelize test execution
4. **Fuzzing:** Generate random inputs, check no panics

**Estimated total implementation time:** ~1 day (8 hours)

---

## For More Information

- **Inventory:** `difftest/inventory/confidential_assets.md` (87+ rows defined)
- **Corpus files:** `difftest/corpora/confidential_assets/*.hex`
- **Existing harness:** `difftest/src/` (skeleton exists, needs completion)
- **Lean evaluator:** `lean/MovementFormal/MoveModel/` (eval functions ready)

**Questions?** Ask in #formal-verification Slack.
