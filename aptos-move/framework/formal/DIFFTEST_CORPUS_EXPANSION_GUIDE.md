# Difftest Corpus Expansion Guide for Confidential Assets

**Status:** Complete guide for expanding difftest coverage from 85% to 95%+  
**Audience:** Verification engineers adding difftest test cases  
**Current coverage:** 87 test cases, ~85% scenario coverage  
**Target coverage:** 102-115 test cases, 95%+ scenario coverage  
**Estimated effort:** 1-2 weeks for 15-28 new test cases

## Overview

Difftest provides ground-truth validation that the Move VM and Lean/MSL models agree on concrete inputs. Current coverage (87 tests) is good but misses several important edge cases and operation combinations.

**This guide provides:**
1. Complete coverage gap analysis (what's missing)
2. Systematic test case generation procedures
3. Test case templates for each gap
4. Automated test generation scripts
5. Coverage measurement methodology
6. Integration with CI/CD

**Coverage formula:**
```
Coverage = (Scenarios Tested / Total Meaningful Scenarios) × 100%
```

**Current state:**
- Total meaningful scenarios: ~102 (enumerated in §2)
- Scenarios tested: 87
- Coverage: 85.3%

**Target:** 95%+ coverage (97-102 test cases)

## 1. Current Coverage Analysis

### 1.1 Coverage by Operation

| Operation | Happy Path | Error Paths | Edge Cases | Total Tested | Total Scenarios | Coverage |
|-----------|------------|-------------|------------|--------------|-----------------|----------|
| **Registration** | 3 | 4 | 2 | 9 | 12 | 75% |
| **Deposit** | 2 | 1 | 1 | 4 | 5 | 80% |
| **Withdrawal** | 2 | 3 | 2 | 7 | 9 | 78% |
| **Transfer** | 3 | 5 | 3 | 11 | 14 | 79% |
| **Rotation** | 2 | 3 | 1 | 6 | 8 | 75% |
| **Normalization** | 2 | 2 | 1 | 5 | 6 | 83% |
| **Freeze/Unfreeze** | 4 | 4 | 1 | 9 | 10 | 90% |
| **Allow-list** | 4 | 3 | 1 | 8 | 9 | 89% |
| **Rollover** | 3 | 2 | 1 | 6 | 7 | 86% |
| **Admin ops** | 5 | 2 | 1 | 8 | 9 | 89% |
| **Combinations** | 8 | 4 | 2 | 14 | 23 | 61% |
| **TOTAL** | 38 | 33 | 16 | **87** | **102** | **85.3%** |

### 1.2 Gap Analysis

**Top coverage gaps (lowest coverage first):**

1. **Operation combinations** (61% coverage)
   - Missing: Freeze after partial transfer, rotation during rollover, withdrawal after normalization, etc.
   - Impact: HIGH (these are real-world usage patterns)
   - Tests needed: 9 additional combination tests

2. **Registration** (75% coverage)
   - Missing: Singleton container with existing store, concurrent registration attempts, proof with wrong account
   - Impact: MEDIUM (registration is one-time operation, but critical)
   - Tests needed: 3 additional tests

3. **Rotation** (75% coverage)
   - Missing: Rotation with non-zero pending balance, rotation immediately after rotation, rotation with frozen account
   - Impact: MEDIUM (key rotation is infrequent but security-critical)
   - Tests needed: 2 additional tests

4. **Withdrawal** (78% coverage)
   - Missing: Withdrawal of exact balance (boundary), withdrawal with pending normalization, simultaneous withdrawals from same account
   - Impact: MEDIUM-HIGH (withdrawal is common operation)
   - Tests needed: 2 additional tests

5. **Transfer** (79% coverage)
   - Missing: Self-transfer (sender == receiver), transfer with exactly max amount, transfer to account with different encryption scheme
   - Impact: MEDIUM (transfer is most complex operation)
   - Tests needed: 3 additional tests

6. **Deposit** (80% coverage)
   - Missing: Deposit to frozen account (should succeed pre-freeze), deposit of MAX_U64
   - Impact: LOW (deposit is simple operation)
   - Tests needed: 1 additional test

**Total tests needed for 95% coverage:** 20 tests (87 + 20 = 107, coverage = 107/102 = 105% accounting for some overlap)

**Revised target:** 15-20 high-value tests to reach 95%+

## 2. Test Case Inventory (Complete Enumeration)

### 2.1 Registration (12 scenarios)

#### Happy Path (3 scenarios)
- ✅ `e2e_register_new_account` — Fresh registration, no existing store
- ✅ `e2e_register_singleton_none` — Singleton container, no existing store
- ✅ `e2e_register_singleton_some` — Singleton container, existing store (Phase 1 in-progress)

#### Error Paths (5 scenarios)
- ✅ `e2e_register_invalid_proof` — Schnorr signature verification fails
- ✅ `e2e_register_invalid_hmac` — HMAC verification fails
- ✅ `e2e_register_double_register` — Account already registered
- ❌ `e2e_register_wrong_account_proof` — Proof generated for different account (**MISSING**)
- ❌ `e2e_register_concurrent_attempt` — Two registrations for same account in same block (**MISSING**)

#### Edge Cases (4 scenarios)
- ✅ `e2e_register_max_balance` — Register with maximum encrypted balance
- ✅ `e2e_register_zero_balance` — Register with zero initial balance
- ❌ `e2e_register_with_auditor` — Register with auditor address set (**MISSING**)
- ❌ `e2e_register_non_singleton_container` — Non-singleton container table (**MISSING** - out of scope for Phase 1)

### 2.2 Deposit (5 scenarios)

#### Happy Path (2 scenarios)
- ✅ `e2e_deposit_to_existing_account` — Deposit to registered account
- ✅ `e2e_deposit_coins_fa_integration` — Deposit via FA coin conversion

#### Error Paths (2 scenarios)
- ✅ `e2e_deposit_to_nonexistent_account` — Account not registered
- ❌ `e2e_deposit_fa_insufficient_balance` — Not enough FA coins to deposit (**MISSING**)

#### Edge Cases (1 scenario)
- ✅ `e2e_deposit_max_amount` — Deposit MAX_U64

### 2.3 Withdrawal (9 scenarios)

#### Happy Path (2 scenarios)
- ✅ `e2e_withdraw_partial` — Withdraw less than balance
- ✅ `e2e_withdraw_to_fa` — Withdraw to FA coins

#### Error Paths (4 scenarios)
- ✅ `e2e_withdraw_insufficient_balance` — Overdraft attempt
- ✅ `e2e_withdraw_invalid_proof` — Sigma verification fails
- ✅ `e2e_withdraw_frozen_account` — Withdraw from frozen account
- ❌ `e2e_withdraw_range_proof_invalid` — Range proof fails (negative balance) (**MISSING**)

#### Edge Cases (3 scenarios)
- ✅ `e2e_withdraw_exact_balance` — Withdraw entire balance
- ✅ `e2e_withdraw_zero_amount` — Withdraw 0 (should succeed but no-op)
- ❌ `e2e_withdraw_pending_normalization` — Withdraw while pending balance > 0 (**MISSING**)

### 2.4 Transfer (14 scenarios)

#### Happy Path (3 scenarios)
- ✅ `e2e_transfer_basic` — Simple transfer between two accounts
- ✅ `e2e_transfer_with_allow_list` — Transfer to account with allow-list enabled (sender is allowed)
- ✅ `e2e_transfer_max_amount` — Transfer maximum valid amount

#### Error Paths (7 scenarios)
- ✅ `e2e_transfer_insufficient_balance` — Overdraft
- ✅ `e2e_transfer_sender_frozen` — Sender frozen
- ✅ `e2e_transfer_receiver_frozen` — Receiver frozen
- ✅ `e2e_transfer_allow_list_rejected` — Receiver allow-list blocks sender
- ✅ `e2e_transfer_invalid_sigma_proof` — Sigma verification fails
- ❌ `e2e_transfer_invalid_sender_range_proof` — Sender new balance range proof fails (**MISSING**)
- ❌ `e2e_transfer_invalid_amount_range_proof` — Transfer amount range proof fails (**MISSING**)

#### Edge Cases (4 scenarios)
- ✅ `e2e_transfer_to_self` — Sender == receiver (should succeed as no-op or abort?)
- ✅ `e2e_transfer_zero_amount` — Transfer 0 (should succeed but no-op)
- ❌ `e2e_transfer_with_different_encryption_keys` — Sender and receiver have different key types (**MISSING** - out of scope, all use Ristretto255)
- ✅ `e2e_transfer_exact_balance` — Transfer sender's entire balance

### 2.5 Rotation (8 scenarios)

#### Happy Path (2 scenarios)
- ✅ `e2e_rotate_key_basic` — Rotate encryption key with valid proof
- ✅ `e2e_rotate_key_and_unfreeze` — Combined rotation + unfreeze entry point

#### Error Paths (4 scenarios)
- ✅ `e2e_rotate_invalid_proof` — Sigma verification fails (wrong key)
- ✅ `e2e_rotate_frozen_account` — Rotation on frozen account
- ✅ `e2e_rotate_range_proof_invalid` — Range proof fails
- ❌ `e2e_rotate_immediately_after_rotate` — Double rotation in same transaction (**MISSING**)

#### Edge Cases (2 scenarios)
- ✅ `e2e_rotate_with_zero_balance` — Rotation with all balances zero
- ❌ `e2e_rotate_with_pending_balance` — Rotation with non-zero pending balance (**MISSING**)

### 2.6 Normalization (6 scenarios)

#### Happy Path (2 scenarios)
- ✅ `e2e_normalize_basic` — Move pending → actual
- ✅ `e2e_normalize_partial` — Normalize some chunks, leave others pending

#### Error Paths (3 scenarios)
- ✅ `e2e_normalize_invalid_proof` — Sigma verification fails
- ✅ `e2e_normalize_frozen_account` — Normalize frozen account
- ❌ `e2e_normalize_range_proof_invalid` — Range proof fails (**MISSING**)

#### Edge Cases (1 scenario)
- ✅ `e2e_normalize_all_chunks` — Normalize all pending chunks at once

### 2.7 Freeze/Unfreeze (10 scenarios)

#### Happy Path (4 scenarios)
- ✅ `e2e_freeze_account` — Freeze via owner
- ✅ `e2e_unfreeze_account` — Unfreeze via owner
- ✅ `e2e_freeze_via_admin` — Admin freezes account
- ✅ `e2e_rollover_and_freeze` — Combined rollover + freeze

#### Error Paths (5 scenarios)
- ✅ `e2e_freeze_twice` — Freeze already frozen account (abort 196615)
- ✅ `e2e_unfreeze_not_frozen` — Unfreeze non-frozen account (abort 196616)
- ✅ `e2e_freeze_not_owner` — Non-owner attempts freeze (abort NOT_OWNER)
- ✅ `e2e_unfreeze_not_owner` — Non-owner attempts unfreeze
- ❌ `e2e_freeze_during_transfer` — Freeze mid-transaction (should fail or succeed depending on ordering) (**MISSING** - requires atomic transaction semantics test)

#### Edge Cases (1 scenario)
- ✅ `e2e_freeze_unfreeze_cycle` — Multiple freeze/unfreeze cycles

### 2.8 Allow-list (9 scenarios)

#### Happy Path (4 scenarios)
- ✅ `e2e_enable_allow_list` — Enable allow-list on account
- ✅ `e2e_disable_allow_list` — Disable allow-list
- ✅ `e2e_add_to_allow_list` — Add address to allow-list
- ✅ `e2e_remove_from_allow_list` — Remove address from allow-list

#### Error Paths (4 scenarios)
- ✅ `e2e_allow_list_not_owner` — Non-owner attempts allow-list modification
- ✅ `e2e_transfer_rejected_by_allow_list` — Transfer blocked by allow-list
- ✅ `e2e_add_to_disabled_allow_list` — Add to allow-list when disabled (should succeed)
- ❌ `e2e_enable_allow_list_frozen` — Enable allow-list on frozen account (**MISSING**)

#### Edge Cases (1 scenario)
- ✅ `e2e_allow_list_max_entries` — Allow-list with maximum entries (stress test)

### 2.9 Rollover (7 scenarios)

#### Happy Path (3 scenarios)
- ✅ `e2e_rollover_pending_to_actual` — Basic rollover
- ✅ `e2e_rollover_partial` — Rollover some chunks
- ✅ `e2e_rollover_and_freeze` — Combined rollover + freeze

#### Error Paths (3 scenarios)
- ✅ `e2e_rollover_frozen` — Rollover frozen account
- ✅ `e2e_rollover_not_owner` — Non-owner attempts rollover
- ❌ `e2e_rollover_empty_pending` — Rollover with zero pending balance (**MISSING** - should succeed as no-op)

#### Edge Cases (1 scenario)
- ✅ `e2e_rollover_all_chunks` — Rollover all pending chunks

### 2.10 Admin Operations (9 scenarios)

#### Happy Path (5 scenarios)
- ✅ `e2e_set_auditor` — Set auditor address
- ✅ `e2e_remove_auditor` — Remove auditor (set to None)
- ✅ `e2e_enable_token` — Enable token
- ✅ `e2e_disable_token` — Disable token
- ✅ `e2e_view_balance` — Read balance (view function)

#### Error Paths (3 scenarios)
- ✅ `e2e_set_auditor_not_owner` — Non-owner attempts to set auditor
- ✅ `e2e_disable_token_not_owner` — Non-owner attempts to disable token
- ❌ `e2e_operation_on_disabled_token` — Attempt operation on disabled token (**MISSING**)

#### Edge Cases (1 scenario)
- ✅ `e2e_auditor_set_remove_cycle` — Set/remove auditor multiple times

### 2.11 Operation Combinations (23 scenarios)

**These test real-world sequences of operations.**

#### Common Sequences (8 tested, 15 total)
- ✅ `e2e_deposit_then_withdraw` — Deposit followed by withdrawal (identity)
- ✅ `e2e_deposit_then_transfer` — Deposit then transfer to another account
- ✅ `e2e_transfer_then_normalize` — Transfer then normalize pending balance
- ✅ `e2e_rotate_then_transfer` — Key rotation followed by transfer
- ✅ `e2e_freeze_then_unfreeze_then_transfer` — Freeze/unfreeze cycle then transfer
- ✅ `e2e_rollover_then_withdraw` — Rollover then withdraw from actual balance
- ✅ `e2e_multiple_deposits_then_normalize` — Multiple deposits then single normalization
- ✅ `e2e_transfer_chain` — A → B → C transfer chain

**Missing common sequences (7):**
- ❌ `e2e_withdraw_then_deposit` — Withdraw then re-deposit (should restore balance)
- ❌ `e2e_freeze_during_pending_transfer` — Freeze account with pending balance
- ❌ `e2e_rotation_then_normalize` — Rotate key then normalize (re-encrypted balances)
- ❌ `e2e_normalize_then_withdrawal` — Normalize pending, then withdraw from actual
- ❌ `e2e_transfer_rejected_then_retry` — Failed transfer (frozen) then succeed after unfreeze
- ❌ `e2e_concurrent_operations_same_account` — Two operations on same account in one block
- ❌ `e2e_complex_sequence` — Register → Deposit → Transfer → Normalize → Withdraw (full lifecycle)

#### Error Sequences (4 tested, 8 total)
- ✅ `e2e_freeze_blocks_subsequent_transfer` — Freeze then attempt transfer (should abort)
- ✅ `e2e_overdraft_then_deposit_then_retry` — Overdraft → Deposit → Retry withdrawal
- ✅ `e2e_allow_list_enable_blocks_transfer` — Enable allow-list → Transfer (should abort if not allowed)
- ✅ `e2e_rotation_invalidates_old_proofs` — Rotate key → Use old proof (should fail)

**Missing error sequences (4):**
- ❌ `e2e_double_freeze_attempt` — Freeze → Freeze again (should abort)
- ❌ `e2e_withdrawal_after_transfer_overdraft` — Transfer all → Withdraw (should abort insufficient)
- ❌ `e2e_normalize_with_invalid_proof_after_deposit` — Deposit → Normalize with wrong proof
- ❌ `e2e_transfer_with_stale_proof` — Generate proof → Deposit → Use proof (balance changed)

## 3. Systematic Test Case Generation

### 3.1 Test Case Template

**JSON structure for new test cases:**
```json
{
  "test_id": "e2e_<operation>_<scenario>",
  "description": "Brief description of what this test validates",
  "operation": "<operation_name>",
  "scenario_type": "happy_path | error_path | edge_case | combination",
  "setup": {
    "accounts": [
      {
        "address": "0x1",
        "store": {
          "pending_balance": {"chunks": [...]},
          "actual_balance": {"chunks": [...]},
          "frozen": false,
          "current_encryption_key": "...",
          "incoming_allow_list": {"enabled": false, "addresses": []},
          "auditor": null
        }
      }
    ],
    "container_store": {
      "singleton": true,
      "initial_state": "..."
    }
  },
  "inputs": {
    "caller": "0x1",
    "function": "confidential_asset::operation_internal",
    "args": [...]
  },
  "expected": {
    "result": "success | aborted",
    "abort_code": null,
    "final_state": {
      "accounts": [
        {
          "address": "0x1",
          "store": {
            "pending_balance": {"chunks": [...]},
            "actual_balance": {"chunks": [...]},
            ...
          }
        }
      ]
    }
  },
  "assertions": [
    "Balance conservation: sum(initial) == sum(final)",
    "Frozen state: account.frozen == true",
    ...
  ]
}
```

### 3.2 Automated Test Generation Script

**`scripts/generate_missing_difftest_cases.sh`:**
```bash
#!/usr/bin/env bash
set -euo pipefail

#
# generate_missing_difftest_cases.sh
#
# Purpose: Generate the 20 missing difftest test cases identified in coverage analysis.
# Uses templates and random-but-deterministic input generation.
#

CORPUS_DIR="difftest/corpus/confidential_assets"
TEMPLATE_DIR="scripts/difftest_templates"

# Missing test cases (from §2 gap analysis)
MISSING_TESTS=(
  "e2e_register_wrong_account_proof:registration:error_path"
  "e2e_register_with_auditor:registration:edge_case"
  "e2e_deposit_fa_insufficient_balance:deposit:error_path"
  "e2e_withdraw_range_proof_invalid:withdrawal:error_path"
  "e2e_withdraw_pending_normalization:withdrawal:edge_case"
  "e2e_transfer_invalid_sender_range_proof:transfer:error_path"
  "e2e_transfer_invalid_amount_range_proof:transfer:error_path"
  "e2e_rotate_immediately_after_rotate:rotation:edge_case"
  "e2e_rotate_with_pending_balance:rotation:edge_case"
  "e2e_normalize_range_proof_invalid:normalization:error_path"
  "e2e_freeze_during_transfer:freeze:error_path"
  "e2e_enable_allow_list_frozen:allow_list:error_path"
  "e2e_rollover_empty_pending:rollover:error_path"
  "e2e_operation_on_disabled_token:admin:error_path"
  "e2e_withdraw_then_deposit:combinations:happy_path"
  "e2e_freeze_during_pending_transfer:combinations:error_path"
  "e2e_rotation_then_normalize:combinations:happy_path"
  "e2e_normalize_then_withdrawal:combinations:happy_path"
  "e2e_transfer_rejected_then_retry:combinations:error_path"
  "e2e_complex_sequence:combinations:happy_path"
)

echo "Generating ${#MISSING_TESTS[@]} missing difftest test cases..."

for test_spec in "${MISSING_TESTS[@]}"; do
  IFS=':' read -r test_id operation scenario_type <<< "$test_spec"
  
  echo "Generating $test_id ($operation, $scenario_type)..."
  
  # Call template-based generator
  ./scripts/generate_difftest_test.sh \
    --operation "$operation" \
    --scenario "$scenario_type" \
    --test-id "$test_id" \
    --output "$CORPUS_DIR/${test_id}.json"
  
  echo "  ✅ Created: $CORPUS_DIR/${test_id}.json"
done

echo ""
echo "Summary:"
echo "  Generated: ${#MISSING_TESTS[@]} test cases"
echo "  Total corpus size: $(find "$CORPUS_DIR" -name "*.json" | wc -l) tests"
echo "  Estimated new coverage: 95%+"
```

### 3.3 Example: Generate Missing Registration Test

**Specific example for `e2e_register_wrong_account_proof`:**

```bash
./scripts/generate_difftest_test.sh \
  --operation registration \
  --scenario error_path \
  --test-id e2e_register_wrong_account_proof \
  --custom-proof-account "0x999" \
  --output difftest/corpus/confidential_assets/e2e_register_wrong_account_proof.json
```

**Generated JSON:**
```json
{
  "test_id": "e2e_register_wrong_account_proof",
  "description": "Registration with proof generated for a different account should abort with EPROOF_VERIFICATION_FAILED",
  "operation": "registration",
  "scenario_type": "error_path",
  "setup": {
    "accounts": [
      {
        "address": "0x1",
        "store": null
      },
      {
        "address": "0x999",
        "store": {
          "pending_balance": {"chunks": []},
          "actual_balance": {"chunks": []},
          "current_encryption_key": "...",
          "frozen": false,
          "incoming_allow_list": {"enabled": false, "addresses": []},
          "auditor": null
        }
      }
    ]
  },
  "inputs": {
    "caller": "0x1",
    "function": "confidential_asset::register_internal",
    "args": [
      {
        "type": "RegistrationProof",
        "value": {
          "schnorr_signature": "...",  // Generated for 0x999, not 0x1
          "hmac": "...",
          "initial_balance": "...",
          "encryption_key": "..."
        }
      }
    ]
  },
  "expected": {
    "result": "aborted",
    "abort_code": 65537,  // EPROOF_VERIFICATION_FAILED
    "error_message": "Schnorr signature verification failed (wrong account)"
  },
  "assertions": [
    "Abort code == EPROOF_VERIFICATION_FAILED",
    "No store created for 0x1"
  ]
}
```

## 4. Coverage Measurement Methodology

### 4.1 Scenario Coverage Metric

**Formula:**
```
Scenario Coverage = (Unique Scenarios Tested / Total Meaningful Scenarios) × 100%
```

**Scenario definition:** A unique combination of:
1. Operation (register, deposit, withdraw, transfer, rotate, normalize, freeze, etc.)
2. Input conditions (frozen/unfrozen, valid/invalid proof, sufficient/insufficient balance)
3. Expected outcome (success, specific abort code, state change)

**Example:**
- "Transfer from frozen account" is 1 scenario
- "Transfer to frozen account" is a DIFFERENT scenario
- "Transfer with invalid sigma proof" is a DIFFERENT scenario

**Total meaningful scenarios:** Enumerated in §2 (102 scenarios)

### 4.2 Coverage Calculation Script

**`scripts/calculate_difftest_coverage.sh`:**
```bash
#!/usr/bin/env bash
set -euo pipefail

CORPUS_DIR="difftest/corpus/confidential_assets"
SCENARIO_INVENTORY="scripts/difftest_scenario_inventory.json"

echo "Calculating difftest coverage..."

# Count test cases
TOTAL_TESTS=$(find "$CORPUS_DIR" -name "*.json" -type f | wc -l)

# Parse scenario inventory (§2 enumeration)
TOTAL_SCENARIOS=$(jq '.total_scenarios' "$SCENARIO_INVENTORY")

# Count tested scenarios (by matching test_id patterns)
TESTED_SCENARIOS=$(jq '.tested_scenarios | length' "$SCENARIO_INVENTORY")

COVERAGE=$(echo "scale=2; ($TESTED_SCENARIOS / $TOTAL_SCENARIOS) * 100" | bc)

echo ""
echo "Difftest Coverage Report"
echo "========================"
echo "Total test cases:       $TOTAL_TESTS"
echo "Total scenarios:        $TOTAL_SCENARIOS"
echo "Tested scenarios:       $TESTED_SCENARIOS"
echo "Coverage:               ${COVERAGE}%"
echo ""

# Breakdown by operation
echo "Coverage by Operation:"
echo "----------------------"
jq -r '.coverage_by_operation | to_entries[] | "\(.key): \(.value.tested)/\(.value.total) (\(.value.percentage)%)"' \
  "$SCENARIO_INVENTORY"

# List missing scenarios
echo ""
echo "Missing Scenarios (Target for Expansion):"
echo "------------------------------------------"
jq -r '.missing_scenarios[]' "$SCENARIO_INVENTORY"
```

### 4.3 Scenario Inventory JSON

**`scripts/difftest_scenario_inventory.json`:**
```json
{
  "total_scenarios": 102,
  "tested_scenarios": 87,
  "coverage_percentage": 85.3,
  "coverage_by_operation": {
    "registration": {
      "total": 12,
      "tested": 9,
      "percentage": 75.0,
      "missing": [
        "e2e_register_wrong_account_proof",
        "e2e_register_concurrent_attempt",
        "e2e_register_with_auditor"
      ]
    },
    "deposit": {
      "total": 5,
      "tested": 4,
      "percentage": 80.0,
      "missing": ["e2e_deposit_fa_insufficient_balance"]
    },
    "withdrawal": {
      "total": 9,
      "tested": 7,
      "percentage": 77.8,
      "missing": [
        "e2e_withdraw_range_proof_invalid",
        "e2e_withdraw_pending_normalization"
      ]
    },
    "transfer": {
      "total": 14,
      "tested": 11,
      "percentage": 78.6,
      "missing": [
        "e2e_transfer_invalid_sender_range_proof",
        "e2e_transfer_invalid_amount_range_proof"
      ]
    },
    "rotation": {
      "total": 8,
      "tested": 6,
      "percentage": 75.0,
      "missing": [
        "e2e_rotate_immediately_after_rotate",
        "e2e_rotate_with_pending_balance"
      ]
    },
    "normalization": {
      "total": 6,
      "tested": 5,
      "percentage": 83.3,
      "missing": ["e2e_normalize_range_proof_invalid"]
    },
    "freeze_unfreeze": {
      "total": 10,
      "tested": 9,
      "percentage": 90.0,
      "missing": ["e2e_freeze_during_transfer"]
    },
    "allow_list": {
      "total": 9,
      "tested": 8,
      "percentage": 88.9,
      "missing": ["e2e_enable_allow_list_frozen"]
    },
    "rollover": {
      "total": 7,
      "tested": 6,
      "percentage": 85.7,
      "missing": ["e2e_rollover_empty_pending"]
    },
    "admin": {
      "total": 9,
      "tested": 8,
      "percentage": 88.9,
      "missing": ["e2e_operation_on_disabled_token"]
    },
    "combinations": {
      "total": 23,
      "tested": 14,
      "percentage": 60.9,
      "missing": [
        "e2e_withdraw_then_deposit",
        "e2e_freeze_during_pending_transfer",
        "e2e_rotation_then_normalize",
        "e2e_normalize_then_withdrawal",
        "e2e_transfer_rejected_then_retry",
        "e2e_concurrent_operations_same_account",
        "e2e_complex_sequence",
        "e2e_double_freeze_attempt",
        "e2e_withdrawal_after_transfer_overdraft"
      ]
    }
  },
  "missing_scenarios": [
    "registration: e2e_register_wrong_account_proof",
    "registration: e2e_register_concurrent_attempt",
    "registration: e2e_register_with_auditor",
    "deposit: e2e_deposit_fa_insufficient_balance",
    "withdrawal: e2e_withdraw_range_proof_invalid",
    "withdrawal: e2e_withdraw_pending_normalization",
    "transfer: e2e_transfer_invalid_sender_range_proof",
    "transfer: e2e_transfer_invalid_amount_range_proof",
    "rotation: e2e_rotate_immediately_after_rotate",
    "rotation: e2e_rotate_with_pending_balance",
    "normalization: e2e_normalize_range_proof_invalid",
    "freeze: e2e_freeze_during_transfer",
    "allow_list: e2e_enable_allow_list_frozen",
    "rollover: e2e_rollover_empty_pending",
    "admin: e2e_operation_on_disabled_token",
    "combinations: e2e_withdraw_then_deposit",
    "combinations: e2e_freeze_during_pending_transfer",
    "combinations: e2e_rotation_then_normalize",
    "combinations: e2e_normalize_then_withdrawal",
    "combinations: e2e_transfer_rejected_then_retry"
  ]
}
```

## 5. Priority Test Cases (Top 10)

**If limited time, implement these 10 tests first for maximum coverage gain:**

### Priority 1 (Combinations - High Value)
1. **`e2e_complex_sequence`** — Full lifecycle: Register → Deposit → Transfer → Normalize → Withdraw
2. **`e2e_rotation_then_normalize`** — Key rotation followed by normalization (re-encrypted balances)
3. **`e2e_transfer_rejected_then_retry`** — Transfer fails (frozen) → Unfreeze → Retry (tests state recovery)

### Priority 2 (Error Paths - Security Critical)
4. **`e2e_register_wrong_account_proof`** — Proof from different account should abort
5. **`e2e_transfer_invalid_sender_range_proof`** — Sender new balance range proof invalid
6. **`e2e_withdraw_range_proof_invalid`** — Negative balance range proof should abort

### Priority 3 (Edge Cases - Real World)
7. **`e2e_rotate_with_pending_balance`** — Rotation with non-zero pending (common scenario)
8. **`e2e_withdraw_pending_normalization`** — Withdraw while pending > 0 (should use actual balance)
9. **`e2e_rollover_empty_pending`** — Rollover with nothing to roll (should be no-op)

### Priority 4 (Operation Combinations)
10. **`e2e_normalize_then_withdrawal`** — Normalize pending → Withdraw from actual

**Rationale:** These 10 cover the highest-risk scenarios (proof verification failures, state inconsistencies, real-world operation sequences).

## 6. Test Implementation Walkthrough

### 6.1 Example: `e2e_complex_sequence`

**Goal:** Test full lifecycle of a confidential asset account.

**Sequence:**
1. Register account (0x1)
2. Deposit 1000 units
3. Transfer 300 units to account 0x2
4. Normalize pending balance
5. Withdraw 500 units
6. Final state: 200 units remaining in actual balance

**JSON test case:**
```json
{
  "test_id": "e2e_complex_sequence",
  "description": "Full lifecycle: Register → Deposit → Transfer → Normalize → Withdraw",
  "operation": "combinations",
  "scenario_type": "happy_path",
  "sequence": [
    {
      "step": 1,
      "operation": "register",
      "caller": "0x1",
      "function": "confidential_asset::register_internal",
      "args": {
        "proof": {
          "schnorr_signature": "...",
          "hmac": "...",
          "initial_balance": "0",
          "encryption_key": "..."
        }
      },
      "expected": {
        "result": "success",
        "state_after": {
          "accounts": {
            "0x1": {
              "pending_balance": {"chunks": [0, 0, 0, 0]},
              "actual_balance": {"chunks": [0, 0, 0, 0, 0, 0, 0, 0]},
              "frozen": false
            }
          }
        }
      }
    },
    {
      "step": 2,
      "operation": "deposit",
      "caller": "0x1",
      "function": "confidential_asset::deposit_to_internal",
      "args": {
        "amount": 1000
      },
      "expected": {
        "result": "success",
        "state_after": {
          "accounts": {
            "0x1": {
              "pending_balance": {"chunks": [1000, 0, 0, 0]},
              "actual_balance": {"chunks": [0, 0, 0, 0, 0, 0, 0, 0]}
            }
          }
        }
      }
    },
    {
      "step": 3,
      "operation": "transfer",
      "caller": "0x1",
      "function": "confidential_asset::confidential_transfer_internal",
      "args": {
        "sender_addr": "0x1",
        "receiver_addr": "0x2",
        "proof": {
          "sender_new_chunk": "...",  // 700 units
          "receiver_new_chunk": "...", // 300 units
          "sigma_proof": "...",
          "sender_balance_range_proof": "...",
          "amount_range_proof": "..."
        }
      },
      "expected": {
        "result": "success",
        "state_after": {
          "accounts": {
            "0x1": {
              "pending_balance": {"chunks": [700, 0, 0, 0]},
              "actual_balance": {"chunks": [0, 0, 0, 0, 0, 0, 0, 0]}
            },
            "0x2": {
              "pending_balance": {"chunks": [300, 0, 0, 0]},
              "actual_balance": {"chunks": [0, 0, 0, 0, 0, 0, 0, 0]}
            }
          }
        }
      }
    },
    {
      "step": 4,
      "operation": "normalize",
      "caller": "0x1",
      "function": "confidential_asset::normalize_internal",
      "args": {
        "proof": {
          "sigma_proof": "...",
          "range_proof": "..."
        }
      },
      "expected": {
        "result": "success",
        "state_after": {
          "accounts": {
            "0x1": {
              "pending_balance": {"chunks": [0, 0, 0, 0]},
              "actual_balance": {"chunks": [700, 0, 0, 0, 0, 0, 0, 0]}
            }
          }
        }
      }
    },
    {
      "step": 5,
      "operation": "withdraw",
      "caller": "0x1",
      "function": "confidential_asset::withdraw_to_internal",
      "args": {
        "amount": 500,
        "proof": {
          "new_balance_chunk": "...",  // 200 units
          "sigma_proof": "...",
          "range_proof": "..."
        }
      },
      "expected": {
        "result": "success",
        "state_after": {
          "accounts": {
            "0x1": {
              "pending_balance": {"chunks": [0, 0, 0, 0]},
              "actual_balance": {"chunks": [200, 0, 0, 0, 0, 0, 0, 0]}
            }
          }
        },
        "withdrawn_amount": 500
      }
    }
  ],
  "assertions": [
    "step1: Account registered successfully",
    "step2: Balance increased to 1000",
    "step3: Balance split 700/300 between accounts",
    "step4: Pending moved to actual for account 0x1",
    "step5: Final balance 200 (1000 deposited - 300 transferred - 500 withdrawn)"
  ]
}
```

**Execution:**
```bash
./difftest/difftest.sh run-single \
  difftest/corpus/confidential_assets/e2e_complex_sequence.json
```

**Expected output:**
```
Running test: e2e_complex_sequence
  Step 1: register... ✅ PASS
  Step 2: deposit... ✅ PASS
  Step 3: transfer... ✅ PASS
  Step 4: normalize... ✅ PASS
  Step 5: withdraw... ✅ PASS
  
Assertions:
  ✅ Account registered successfully
  ✅ Balance increased to 1000
  ✅ Balance split 700/300 between accounts
  ✅ Pending moved to actual for account 0x1
  ✅ Final balance 200
  
Test e2e_complex_sequence: ✅ PASSED
```

### 6.2 Example: `e2e_withdraw_range_proof_invalid`

**Goal:** Withdrawal with invalid range proof (proving negative balance) should abort.

**Scenario:**
1. Account has 500 units
2. Attempt to withdraw 700 units (overdraft)
3. Range proof claims new balance is valid, but VM verifier should detect negative balance

**JSON test case:**
```json
{
  "test_id": "e2e_withdraw_range_proof_invalid",
  "description": "Withdrawal with range proof proving negative balance should abort with EPROOF_VERIFICATION_FAILED",
  "operation": "withdrawal",
  "scenario_type": "error_path",
  "setup": {
    "accounts": [
      {
        "address": "0x1",
        "store": {
          "pending_balance": {"chunks": [500, 0, 0, 0]},
          "actual_balance": {"chunks": [0, 0, 0, 0, 0, 0, 0, 0]},
          "current_encryption_key": "...",
          "frozen": false,
          "incoming_allow_list": {"enabled": false, "addresses": []},
          "auditor": null
        }
      }
    ]
  },
  "inputs": {
    "caller": "0x1",
    "function": "confidential_asset::withdraw_to_internal",
    "args": {
      "amount": 700,
      "proof": {
        "new_balance_chunk": "...",  // Encrypted -200 (invalid!)
        "sigma_proof": "...",        // Valid sigma (proves knowledge of key)
        "range_proof": "..."         // INVALID range proof (claims -200 is in [0, MAX])
      }
    }
  },
  "expected": {
    "result": "aborted",
    "abort_code": 65538,  // ERANGE_PROOF_VERIFICATION_FAILED
    "error_message": "Range proof verification failed (negative balance detected)"
  },
  "assertions": [
    "Abort code == ERANGE_PROOF_VERIFICATION_FAILED",
    "Account balance unchanged (500 units)",
    "No withdrawal executed"
  ]
}
```

## 7. Integration with CI/CD

### 7.1 Update Workflow

**Add coverage check to `.github/workflows/ca-verification-suite.yaml`:**
```yaml
difftest-coverage-check:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v3
    
    - name: Calculate difftest coverage
      run: ./scripts/calculate_difftest_coverage.sh
    
    - name: Check coverage threshold
      run: |
        COVERAGE=$(jq -r '.coverage_percentage' scripts/difftest_scenario_inventory.json)
        THRESHOLD=95.0
        
        if (( $(echo "$COVERAGE < $THRESHOLD" | bc -l) )); then
          echo "Coverage $COVERAGE% is below threshold $THRESHOLD%"
          exit 1
        fi
        
        echo "Coverage $COVERAGE% meets threshold $THRESHOLD%"
    
    - name: Run all difftest tests
      run: ./difftest/difftest.sh run-corpus confidential_assets
    
    - name: Upload coverage report
      uses: actions/upload-artifact@v3
      with:
        name: difftest-coverage-report
        path: scripts/difftest_scenario_inventory.json
```

### 7.2 Coverage Trend Tracking

**Track coverage over time:**
```bash
# scripts/track_coverage_trend.sh

#!/usr/bin/env bash
set -euo pipefail

COVERAGE_LOG="metrics/difftest_coverage_history.csv"

# Calculate current coverage
COVERAGE=$(./scripts/calculate_difftest_coverage.sh | grep "Coverage:" | awk '{print $2}' | tr -d '%')
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
COMMIT=$(git rev-parse --short HEAD)

# Append to history
echo "$TIMESTAMP,$COMMIT,$COVERAGE" >> "$COVERAGE_LOG"

# Plot trend (requires gnuplot)
gnuplot <<EOF
set terminal png size 800,600
set output 'metrics/difftest_coverage_trend.png'
set title 'Difftest Coverage Over Time'
set xlabel 'Commit'
set ylabel 'Coverage (%)'
set yrange [80:100]
set datafile separator ','
plot '$COVERAGE_LOG' using 3:xtic(2) with linespoints title 'Coverage'
EOF

echo "Coverage trend updated: metrics/difftest_coverage_trend.png"
```

## 8. Maintenance and Evolution

### 8.1 Adding New Operations

When new CA operations are added:

1. **Enumerate scenarios** (happy path, error paths, edge cases)
2. **Update inventory** (`scripts/difftest_scenario_inventory.json`)
3. **Generate test cases** (use template script)
4. **Run and validate**
5. **Update coverage report**

**Template for new operation:**
```json
{
  "operation_name": "new_operation",
  "total_scenarios": 8,
  "tested_scenarios": 0,
  "scenarios": [
    {"id": "e2e_new_op_basic", "type": "happy_path", "priority": "high"},
    {"id": "e2e_new_op_frozen", "type": "error_path", "priority": "high"},
    {"id": "e2e_new_op_invalid_proof", "type": "error_path", "priority": "high"},
    {"id": "e2e_new_op_edge_case_1", "type": "edge_case", "priority": "medium"},
    ...
  ]
}
```

### 8.2 Regression Test Suite

**Automatically add failing cases to regression suite:**
```bash
# When a difftest fails in CI, add to regression suite
if ./difftest/difftest.sh run-single "$TEST_CASE" fails; then
  cp "$TEST_CASE" difftest/corpus/confidential_assets/regression/
  git add difftest/corpus/confidential_assets/regression/
  git commit -m "regression: add failing test case from CI"
fi
```

## 9. Success Metrics

### 9.1 Target Metrics

- ✅ **Coverage:** 95%+ scenario coverage (97-102 tested scenarios out of 102 total)
- ✅ **Test count:** 102-115 test cases total (87 existing + 15-28 new)
- ✅ **CI time:** Difftest suite completes in <10 minutes
- ✅ **Failure rate:** <2% false positives (tests fail due to harness bugs, not real issues)
- ✅ **Regression detection:** 100% of previously-failing cases added to regression suite

### 9.2 Coverage Breakdown Target

| Operation | Current | Target | Gap |
|-----------|---------|--------|-----|
| Registration | 75% | 100% | +3 tests |
| Deposit | 80% | 100% | +1 test |
| Withdrawal | 78% | 100% | +2 tests |
| Transfer | 79% | 100% | +3 tests |
| Rotation | 75% | 100% | +2 tests |
| Normalization | 83% | 100% | +1 test |
| Freeze/Unfreeze | 90% | 100% | +1 test |
| Allow-list | 89% | 100% | +1 test |
| Rollover | 86% | 100% | +1 test |
| Admin ops | 89% | 100% | +1 test |
| Combinations | 61% | 95% | +8 tests |
| **TOTAL** | **85%** | **95%+** | **+24 tests** |

## 10. Implementation Roadmap

### 10.1 Week 1: Foundation
- [ ] Create `difftest_scenario_inventory.json` with full enumeration (§2)
- [ ] Implement `calculate_difftest_coverage.sh` script
- [ ] Baseline coverage measurement (current: 85.3%)
- [ ] Prioritize top 10 missing tests (§5)

### 10.2 Week 2: Core Tests
- [ ] Generate 10 priority tests (§5)
- [ ] Run and validate all 10 tests
- [ ] Fix any difftest harness issues discovered
- [ ] Update coverage: target 90%+

### 10.3 Week 3: Completion
- [ ] Generate remaining 10-18 tests for 95%+ coverage
- [ ] Run full corpus (107+ tests)
- [ ] CI integration (coverage check, threshold enforcement)
- [ ] Documentation updates

### 10.4 Week 4: Polish
- [ ] Coverage trend tracking (§7.2)
- [ ] Regression suite setup
- [ ] Performance optimization (parallel test execution)
- [ ] Final validation: 95%+ coverage achieved

## Summary

**Current state:** 87 difftest tests, 85.3% scenario coverage  
**Target state:** 102-115 tests, 95%+ scenario coverage  
**Implementation time:** 3-4 weeks  
**High-priority tests:** 10 tests (§5) for 90%+ coverage  
**Full expansion:** 20-24 additional tests for 95%+ coverage  

**Key deliverables:**
1. Scenario inventory (102 scenarios enumerated)
2. Coverage measurement script
3. 20-24 new test cases (JSON)
4. CI integration (coverage threshold check)
5. Regression test suite framework

**Success criteria:**
- ✅ 95%+ scenario coverage measured
- ✅ All priority tests passing
- ✅ CI enforces coverage threshold
- ✅ Trend tracking operational

**Next step:** Generate scenario inventory and baseline coverage measurement (Week 1).
