# Difftest Harness Integration — Complete Implementation

**Phase 7 Outstanding Item:** Difftest harness integration (~1 day)  
**Status:** ✅ Rust harness exists, 🟡 verify-ca.sh integration pending  
**This guide:** Complete implementation to integrate difftest into verify-ca.sh

---

## Current State Analysis

### Existing Components

**1. Rust Difftest Harness** (`difftest/src/`)
- ✅ `main.rs` - CLI entry point
- ✅ `corpus_verify.rs` - Corpus verification logic
- ✅ `vm.rs` - Move VM integration
- ✅ `compiler.rs` - Move compiler integration
- ✅ `schema.rs` - JSON schema definitions
- ✅ `oracle_row.rs` - Oracle row parsing

**2. Corpus Data** (`difftest/corpora/`)
- ✅ `confidential_assets/*.json` - Test cases for CA operations
- ✅ Registration, Withdrawal, Transfer, Normalization, Rotation corpora

**3. verify-ca.sh Script** (`audit/verify-ca.sh`)
- ✅ Lean verification integration (working)
- ✅ Move Prover integration (working)
- ❌ Difftest integration (stub placeholder)

### Gap Analysis

**Missing pieces:**
1. Difftest mode in verify-ca.sh (--stack difftest)
2. Corpus path mapping for each operation
3. Error handling and output formatting
4. CI integration

**Estimated implementation:** 4-6 hours

---

## Part 1: Rust Harness Interface

### 1.1 Current CLI

```bash
# Check current difftest CLI
cd difftest
cargo run -- --help

# Expected output:
# Usage: difftest [OPTIONS] --corpus <PATH>
#
# Options:
#   --corpus <PATH>    Path to corpus JSON file
#   --vm-path <PATH>   Path to Move VM binary (optional)
#   --verbose          Enable verbose output
```

### 1.2 Wrapper Script

Create `scripts/run-difftest.sh`:

```bash
#!/usr/bin/env bash
# run-difftest.sh — Wrapper for difftest harness
#
# Usage:
#   ./scripts/run-difftest.sh <operation> [--verbose]
#
# Operations: normalization, withdrawal, transfer, rotation, registration

set -euo pipefail

OPERATION="${1:-}"
VERBOSE="${2:-}"

if [[ -z "$OPERATION" ]]; then
    echo "Usage: $0 <operation> [--verbose]" >&2
    echo "Operations: normalization, withdrawal, transfer, rotation, registration" >&2
    exit 1
fi

# Map operation to corpus file
CORPUS_DIR="difftest/corpora/confidential_assets"

case "$OPERATION" in
    normalization)
        CORPUS_FILE="$CORPUS_DIR/normalization_corpus.json"
        ;;
    withdrawal)
        CORPUS_FILE="$CORPUS_DIR/withdrawal_corpus.json"
        ;;
    transfer)
        CORPUS_FILE="$CORPUS_DIR/transfer_corpus.json"
        ;;
    rotation)
        CORPUS_FILE="$CORPUS_DIR/rotation_corpus.json"
        ;;
    registration)
        CORPUS_FILE="$CORPUS_DIR/registration_corpus.json"
        ;;
    *)
        echo "Error: Unknown operation '$OPERATION'" >&2
        exit 1
        ;;
esac

if [[ ! -f "$CORPUS_FILE" ]]; then
    echo "Error: Corpus file not found: $CORPUS_FILE" >&2
    exit 1
fi

# Build difftest if needed
if [[ ! -f "difftest/target/release/difftest" ]]; then
    echo "Building difftest harness..."
    (cd difftest && cargo build --release)
fi

# Run difftest
echo "Running difftest for $OPERATION..."
echo "Corpus: $CORPUS_FILE"

if [[ -n "$VERBOSE" ]]; then
    difftest/target/release/difftest --corpus "$CORPUS_FILE" --verbose
else
    difftest/target/release/difftest --corpus "$CORPUS_FILE"
fi

# Check exit code
if [[ $? -eq 0 ]]; then
    echo "✅ Difftest passed for $OPERATION"
else
    echo "❌ Difftest failed for $OPERATION"
    exit 1
fi
```

---

## Part 2: verify-ca.sh Integration

### 2.1 Add Difftest Stack Support

Edit `audit/verify-ca.sh`, find the `--stack` handler and add:

```bash
# Around line 150-200 (after lean and move-prover cases)

elif [[ "$STACK" == "difftest" ]]; then
    echo "Running difftest verification..."

    if [[ -z "$OP" ]]; then
        # Run all operations
        for operation in normalization withdrawal transfer rotation registration; do
            echo ""
            echo "=== Difftest: $operation ==="
            ./scripts/run-difftest.sh "$operation" || FAILED=true
        done
    else
        # Run specific operation
        ./scripts/run-difftest.sh "$OP" || FAILED=true
    fi

    if [[ "$FAILED" == "true" ]]; then
        echo ""
        echo "❌ Difftest verification failed"
        exit 1
    fi

    echo ""
    echo "✅ Difftest verification passed"
```

### 2.2 Add "all" Stack Mode

```bash
# Around line 100 (stack selection logic)

if [[ "$STACK" == "all" ]] || [[ -z "$STACK" ]]; then
    echo "Running all verification stacks..."

    # Lean
    echo "=== Stack: Lean ==="
    ./audit/verify-ca.sh --op "$OP" --stack lean || FAILED=true

    # Move Prover
    echo "=== Stack: Move Prover ==="
    ./audit/verify-ca.sh --op "$OP" --stack move-prover || FAILED=true

    # Difftest
    echo "=== Stack: Difftest ==="
    ./audit/verify-ca.sh --op "$OP" --stack difftest || FAILED=true

    if [[ "$FAILED" == "true" ]]; then
        echo "❌ Some stacks failed"
        exit 1
    fi

    echo "✅ All stacks passed"
    exit 0
fi
```

---

## Part 3: Corpus File Structure

### 3.1 Example Corpus Format

```json
{
  "operation": "withdrawal",
  "test_cases": [
    {
      "name": "happy_path",
      "inputs": {
        "chain_id": 1,
        "sender": "0x1234...",
        "contract": "0x5678...",
        "ek_ref": "...",
        "amount": 100,
        "cur_bal_ref": "...",
        "new_bal_ref": "...",
        "proof_ref": "..."
      },
      "expected_output": {
        "status": "success",
        "returned_values": []
      }
    },
    {
      "name": "sigma_proof_fails",
      "inputs": {
        ...
      },
      "expected_output": {
        "status": "error"
      }
    }
  ]
}
```

### 3.2 Generating Corpus Files

Create `scripts/generate-corpus.sh`:

```bash
#!/usr/bin/env bash
# generate-corpus.sh — Generate difftest corpus from Move tests

set -euo pipefail

OPERATION="$1"
OUTPUT_FILE="difftest/corpora/confidential_assets/${OPERATION}_corpus.json"

echo "Generating corpus for $OPERATION..."

# Run Move tests with trace output
movement test \
    --package aptos-experimental \
    --filter "test_${OPERATION}" \
    --trace-json > /tmp/${OPERATION}_trace.json

# Convert trace to corpus format
python3 scripts/trace-to-corpus.py \
    /tmp/${OPERATION}_trace.json \
    "$OUTPUT_FILE"

echo "✅ Generated $OUTPUT_FILE"
```

---

## Part 4: Error Handling and Reporting

### 4.1 Detailed Output Mode

Modify `run-difftest.sh` to support JSON output:

```bash
# Add --output-format option

OUTPUT_FORMAT="${OUTPUT_FORMAT:-text}"  # text or json

if [[ "$OUTPUT_FORMAT" == "json" ]]; then
    # Run difftest with JSON output
    difftest/target/release/difftest \
        --corpus "$CORPUS_FILE" \
        --output-format json \
        > difftest_results.json

    # Parse JSON for pass/fail
    if jq -e '.all_passed' difftest_results.json > /dev/null; then
        echo "✅ Difftest passed"
        exit 0
    else
        echo "❌ Difftest failed"
        jq '.failures' difftest_results.json
        exit 1
    fi
else
    # Text output (current behavior)
    difftest/target/release/difftest --corpus "$CORPUS_FILE"
fi
```

### 4.2 Coverage Report

```bash
# Add --coverage flag to difftest

difftest/target/release/difftest \
    --corpus "$CORPUS_FILE" \
    --coverage \
    > coverage_report.txt

# Expected output:
# Operation: withdrawal
# Test cases: 12
# Passed: 11
# Failed: 1
# Coverage: 91.67%
```

---

## Part 5: CI Integration

### 5.1 GitHub Actions Workflow

Create `.github/workflows/difftest-ca.yaml`:

```yaml
name: CA Difftest Verification

on:
  push:
    paths:
      - 'aptos-move/framework/aptos-experimental/sources/**'
      - 'aptos-move/framework/formal/difftest/**'
  pull_request:
    paths:
      - 'aptos-move/framework/aptos-experimental/sources/**'
      - 'aptos-move/framework/formal/difftest/**'

jobs:
  difftest:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Setup Rust
        uses: actions-rs/toolchain@v1
        with:
          toolchain: stable
          override: true

      - name: Build difftest harness
        run: |
          cd aptos-move/framework/formal/difftest
          cargo build --release

      - name: Run difftest (all operations)
        run: |
          cd aptos-move/framework/formal
          for op in normalization withdrawal transfer rotation registration; do
            echo "Testing $op..."
            ./scripts/run-difftest.sh "$op"
          done

      - name: Generate coverage report
        run: |
          cd aptos-move/framework/formal
          ./scripts/difftest-coverage.sh > difftest_coverage.txt
          cat difftest_coverage.txt

      - name: Upload coverage artifact
        uses: actions/upload-artifact@v3
        with:
          name: difftest-coverage
          path: aptos-move/framework/formal/difftest_coverage.txt
```

### 5.2 Coverage Badge

Add to README.md:

```markdown
![Difftest Coverage](https://img.shields.io/endpoint?url=https://gist.githubusercontent.com/user/id/raw/difftest-coverage.json)
```

---

## Part 6: Testing and Validation

### 6.1 Smoke Test

```bash
# Test difftest integration end-to-end
cd aptos-move/framework/formal

# Test individual operation
./scripts/run-difftest.sh normalization

# Test via verify-ca.sh
./audit/verify-ca.sh --op normalization --stack difftest

# Test all stacks
./audit/verify-ca.sh --op normalization --stack all
```

### 6.2 Full Regression Test

```bash
# Test all operations, all stacks
./audit/verify-ca.sh

# Expected output:
# === Stack: Lean ===
# ✅ Normalization: Lean (197 theorems, 3.0s)
# ✅ Withdrawal: Lean (150 theorems, 2.5s)
# ...
#
# === Stack: Move Prover ===
# ✅ Normalization: Move Prover (compile only, 1.0s)
# ...
#
# === Stack: Difftest ===
# ✅ Normalization: Difftest (12 test cases, 11 passed, 1 failed)
# ...
#
# ⚠️  Some tests failed. See above for details.
```

---

## Part 7: Maintenance

### 7.1 Adding New Test Cases

```bash
# 1. Add test case to corpus JSON
vim difftest/corpora/confidential_assets/withdrawal_corpus.json

# 2. Regenerate if using automated generation
./scripts/generate-corpus.sh withdrawal

# 3. Run difftest to verify
./scripts/run-difftest.sh withdrawal

# 4. Commit updated corpus
git add difftest/corpora/confidential_assets/withdrawal_corpus.json
git commit -m "difftest: Add withdrawal edge case XYZ"
```

### 7.2 Updating Harness

```bash
# 1. Make changes to Rust code
vim difftest/src/corpus_verify.rs

# 2. Rebuild
cd difftest
cargo build --release

# 3. Test
cd ..
./scripts/run-difftest.sh normalization

# 4. If tests pass, commit
git add difftest/src/
git commit -m "difftest: Improve error handling"
```

---

## Part 8: Complete Implementation Checklist

### Phase 7 Completion

- [x] Rust difftest harness exists
- [ ] `scripts/run-difftest.sh` wrapper created
- [ ] `audit/verify-ca.sh` difftest stack support added
- [ ] All 5 operation corpus files present
- [ ] Smoke test passes (one operation)
- [ ] Full test passes (all operations)
- [ ] CI workflow `.github/workflows/difftest-ca.yaml` added
- [ ] Documentation updated (README.md, plan)
- [ ] Phase 7 status updated to ✅ COMPLETE

### Implementation Timeline

| Task | Estimated Time | Priority |
|------|----------------|----------|
| Create run-difftest.sh | 30 min | HIGH |
| Integrate into verify-ca.sh | 1 hour | HIGH |
| Test all operations | 1 hour | HIGH |
| Add CI workflow | 30 min | MEDIUM |
| Coverage reporting | 1 hour | MEDIUM |
| Documentation | 1 hour | LOW |

**Total:** 5-6 hours (matches "~1 day" estimate from plan)

---

## Part 9: Expected Final State

### After Integration

```bash
# Single operation, single stack
$ ./audit/verify-ca.sh --op normalization --stack difftest
Running difftest verification...
=== Difftest: normalization ===
Corpus: difftest/corpora/confidential_assets/normalization_corpus.json
Running 12 test cases...
✅ happy_path
✅ sigma_proof_fails
✅ range_proof_fails
... (9 more)
✅ Difftest passed for normalization

# All stacks
$ ./audit/verify-ca.sh --op normalization
=== Stack: Lean ===
✅ Normalization (3.0s, 197 theorems)

=== Stack: Move Prover ===
✅ Normalization (1.2s, compile only)

=== Stack: Difftest ===
✅ Normalization (0.8s, 12 test cases)

✅ All stacks passed for normalization
```

### verify-ca.sh --help Output

```
Usage: ./audit/verify-ca.sh [OPTIONS]

Options:
  --op OPERATION        Verify specific operation (normalization, withdrawal, etc.)
  --stack STACK         Run specific stack (lean, move-prover, difftest, all)
  --coverage            Show coverage report
  --verbose             Enable verbose output

Examples:
  ./audit/verify-ca.sh                                    # All operations, all stacks
  ./audit/verify-ca.sh --op normalization                 # One operation, all stacks
  ./audit/verify-ca.sh --op withdrawal --stack lean       # One operation, one stack
  ./audit/verify-ca.sh --stack difftest                   # All operations, difftest only
```

---

**END OF IMPLEMENTATION GUIDE**

**Status:** Ready to implement (all steps documented, scripts provided)  
**Impact:** Completes Phase 7 (moves from 90% → 100%)  
**Follow-up:** Phase 8 (axiom closure)
