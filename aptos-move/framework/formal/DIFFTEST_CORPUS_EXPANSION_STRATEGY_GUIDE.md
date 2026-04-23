# Difftest Corpus Expansion Strategy Guide

**Audience:** Verification engineers, QA engineers, test developers  
**Prerequisites:** Understanding of difftest architecture, CA operations  
**Related:** `DIFFTEST_HARNESS_DEVELOPMENT_GUIDE.md`, `CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md` §9

## Purpose

This guide provides systematic strategy for expanding the CA difftest corpus from current 95% (97/102 scenarios) to 100% coverage, and maintaining high coverage as new operations are added.

## Table of Contents

1. [Current Coverage Status](#current-coverage-status)
2. [Gap Analysis](#gap-analysis)
3. [Scenario Design Principles](#scenario-design-principles)
4. [Expansion Roadmap](#expansion-roadmap)
5. [Maintenance Strategy](#maintenance-strategy)
6. [Quality Assurance](#quality-assurance)

---

## Current Coverage Status

### By Operation (97/102 scenarios)

| Operation | Happy Path | Error Paths | Edge Cases | Total | Coverage |
|-----------|------------|-------------|------------|-------|----------|
| Registration | 3 | 5 | 2 | 10 | 100% ✅ |
| Deposit | 2 | 3 | 1 | 6 | 100% ✅ |
| Withdrawal | 3 | 4 | 2 | 9 | 89% ⚠️ (1 missing) |
| Transfer | 4 | 6 | 3 | 13 | 92% ⚠️ (1 missing) |
| Normalization | 2 | 3 | 2 | 7 | 100% ✅ |
| Rotation | 3 | 4 | 2 | 9 | 100% ✅ |
| Freeze/Unfreeze | 4 | 2 | 0 | 6 | 100% ✅ |
| Rollover | 2 | 2 | 1 | 5 | 100% ✅ |
| Allow-list | 3 | 3 | 1 | 7 | 86% ⚠️ (1 missing) |
| Governance | 4 | 2 | 2 | 8 | 100% ✅ |
| E2E Sequences | 5 | 3 | 2 | 10 | 90% ⚠️ (1 missing) |
| Cross-operation | 3 | 4 | 0 | 7 | 100% ✅ |

**Total:** 38 happy-path + 41 error-path + 18 edge-case = **97/102 scenarios** (95% coverage)

**Missing:** 5 scenarios across 4 categories

### By Path Type

| Path Type | Implemented | Total | Coverage |
|-----------|-------------|-------|----------|
| Happy Path (success) | 38 | 40 | 95% |
| Error Path (aborts) | 41 | 42 | 98% |
| Edge Cases (boundary) | 18 | 20 | 90% |

**Gap:** Mostly in edge cases (90% vs 95%/98%)

### By Stack

| Stack | Scenarios | Status |
|-------|-----------|--------|
| Lean ↔ VM | 97 | ✅ All passing |
| MSL ↔ VM | 0 | ⚠️ Blocked on Phase 0 |

**Note:** MSL difftest pending ristretto255 patches

---

## Gap Analysis

### Missing Scenarios (5 total)

**1. Withdrawal: Concurrent withdrawals (edge case)**
- **What:** Two withdrawals from same account in sequence, second should see updated balance
- **Why missing:** Edge case, not critical for soundness
- **Priority:** Medium
- **Effort:** 2 hours (scenario design + oracle mock)

**2. Transfer: Self-transfer rejected (error path)**
- **What:** Transfer from account to itself, should abort with ESELF_TRANSFER
- **Why missing:** Assumed impossible (UI prevents), but should test
- **Priority:** High (security property)
- **Effort:** 1 hour (simple scenario)

**3. Allow-list: Concurrent enable/disable (edge case)**
- **What:** Enable allow-list, add address, disable, re-enable — address should persist
- **Why missing:** Complex state machine, edge case
- **Priority:** Low
- **Effort:** 3 hours (multi-step scenario)

**4. E2E Sequence: Register → Deposit → Withdraw → Transfer (happy path)**
- **What:** Full lifecycle in one scenario
- **Why missing:** Covered by individual ops, but not E2E composition
- **Priority:** Medium (good smoke test)
- **Effort:** 2 hours (orchestration)

**5. E2E Sequence: Freeze → Unfreeze → Transfer (edge case)**
- **What:** Freeze account, unfreeze, verify transfer works
- **Why missing:** Edge case, covered partially
- **Priority:** Low
- **Effort:** 2 hours

**Total effort to 100%:** ~10 hours (1-2 days)

### Coverage Blind Spots (Not Counted in 102)

**Cryptographic edge cases (not testable in difftest):**
- Invalid curve points (non-canonical encodings) — caught by Ristretto decoder, before difftest
- Hash collisions (SHA-512) — computationally infeasible
- DLog breaks — assumption, not testable

**VM-specific edge cases:**
- Stack overflow (deeply nested calls) — out of scope for CA
- Gas exhaustion — separate testing (integration tests)
- Transaction-level aborts — tested at integration level

**Concurrency:**
- True concurrent transactions — not possible in single-threaded difftest
- Covered by: integration tests with parallel transactions

**These are OK to leave out** — difftest focuses on single-operation semantics, not concurrency/resource exhaustion

---

## Scenario Design Principles

### Principle 1: Representativeness

**Goal:** Each scenario represents a class of inputs, not just one input

**Example (bad):**
```rust
#[test]
fn test_transfer_amount_100() {
    // Only tests amount=100, not general case
    let scenario = TestScenario::builder("transfer_100")
        .amount(100)
        .expects_success();
}
```

**Example (good):**
```rust
#[test]
fn test_transfer_various_amounts() {
    for amount in [1, 100, 1000, u64::MAX - 1] {
        let scenario = TestScenario::builder(&format!("transfer_{}", amount))
            .amount(amount)
            .expects_success();
        assert!(run_difftest(&scenario).is_pass());
    }
}
```

**Why:** Four scenarios cover: minimum (1), typical (100), large (1000), boundary (MAX-1)

### Principle 2: Error Path Coverage

**Goal:** Every `aborts_if` clause in MSL spec has a corresponding difftest scenario

**Process:**
1. Read MSL spec for operation
2. List all `aborts_if` clauses
3. For each clause, create scenario triggering that abort
4. Verify scenario aborts with expected code

**Example (Withdrawal):**
```move
spec withdraw_to_internal {
    aborts_if !exists<ConfidentialAssetStore>(addr) with ESTORE_NOT_FOUND;
    aborts_if global<ConfidentialAssetStore>(addr).frozen with ESTORE_FROZEN;
    aborts_if balance < amount with EINSUFFICIENT_BALANCE;
    aborts_if !verify_withdrawal_proof(proof) with EVERIFY_FAILED;
}
```

**Required scenarios:**
- `test_withdraw_store_not_found` → ESTORE_NOT_FOUND
- `test_withdraw_frozen` → ESTORE_FROZEN
- `test_withdraw_insufficient_balance` → EINSUFFICIENT_BALANCE
- `test_withdraw_invalid_proof` → EVERIFY_FAILED

**Verification:** All 4 scenarios exist and pass

### Principle 3: Boundary Testing

**Goal:** Test inputs at boundaries (0, 1, MAX, MAX-1)

**Boundary categories:**
- **Numeric boundaries:** 0, 1, MAX, MAX-1
- **Collection boundaries:** empty, singleton, full
- **State boundaries:** first-time (register), last-time (withdraw all)

**Example (Transfer):**
```rust
// Numeric boundaries
test_transfer_amount_zero()         // Should abort (invalid)
test_transfer_amount_one()          // Minimum valid
test_transfer_amount_max()          // Maximum (balance = MAX)
test_transfer_balance_exactly()     // Transfer entire balance

// State boundaries
test_transfer_first_transaction()   // After registration, before any ops
test_transfer_after_normalize()     // After normalization (fresh state)
```

### Principle 4: Independence

**Goal:** Each scenario is self-contained (no dependencies on other scenarios)

**Bad (dependent):**
```rust
#[test]
fn test_deposit() {
    // Assumes registration already happened (implicit dependency)
    deposit(account, 100);
}

#[test]
fn test_withdraw() {
    // Assumes deposit happened (implicit dependency)
    withdraw(account, 50);
}
```

**Good (independent):**
```rust
#[test]
fn test_deposit() {
    register(account);  // Explicit setup
    deposit(account, 100);
}

#[test]
fn test_withdraw() {
    register(account);   // Explicit setup
    deposit(account, 100);  // Explicit setup
    withdraw(account, 50);
}
```

**Why:** Independent scenarios can run in parallel, easier to debug when fail

### Principle 5: Oracle Realism

**Goal:** Mock oracles return realistic values (not just success/failure)

**Bad (unrealistic mock):**
```rust
oracle.verify_proof = always_returns_success();
```

**Good (realistic mock):**
```rust
oracle.verify_proof = |proof| {
    if proof.commitment.is_valid_ristretto_point() && proof.response.len() == 32 {
        OracleResult::Success
    } else if proof.is_well_formed() {
        OracleResult::Failed  // Proof valid but doesn't verify
    } else {
        OracleResult::Error  // Malformed proof
    }
};
```

**Why:** Realistic oracles catch more bugs (e.g., proof parsing edge cases)

---

## Expansion Roadmap

### Phase 1: Fill 5 Gaps (1-2 days, reach 100%)

**Day 1 Morning: High-priority scenario (2 hours)**
```rust
// Scenario 1: Transfer self-transfer rejection
#[test]
fn test_transfer_self_transfer_rejected() {
    let scenario = TestScenario::builder("transfer_self_rejected")
        .account("alice", initial_balance(1000))
        .function("confidential_asset", "confidential_transfer_internal")
        .arg(signer("alice"))   // Sender
        .arg(signer("alice"))   // Recipient (same!)
        .arg(u64(100))
        .arg(valid_transfer_proof(100))
        .expects_abort(ESELF_TRANSFER)  // Should reject
        .build();
    
    assert!(run_difftest(&scenario).is_pass());
}
```

**Day 1 Afternoon: Medium-priority scenarios (4 hours)**
```rust
// Scenario 2: Withdrawal concurrent (edge case)
#[test]
fn test_withdraw_concurrent() {
    let scenario = TestScenario::builder("withdraw_concurrent")
        .account("alice", initial_balance(1000))
        .sequence([
            step("withdraw_first", withdraw("alice", 400)),
            step("withdraw_second", withdraw("alice", 300)),  // Second sees updated balance
        ])
        .expects_success()
        .build();
    
    assert!(run_difftest(&scenario).is_pass());
}

// Scenario 3: E2E lifecycle
#[test]
fn test_e2e_lifecycle() {
    let scenario = TestScenario::builder("e2e_lifecycle")
        .sequence([
            step("register", register("alice")),
            step("deposit", deposit("alice", 1000)),
            step("withdraw", withdraw("alice", 300)),
            step("transfer", transfer("alice", "bob", 200)),
        ])
        .expects_success()
        .assert_final_balance("alice", 500)  // 1000 - 300 - 200
        .assert_final_balance("bob", 200)
        .build();
    
    assert!(run_difftest(&scenario).is_pass());
}
```

**Day 2 Morning: Low-priority scenarios (4 hours)**
```rust
// Scenario 4: Allow-list concurrent enable/disable
#[test]
fn test_allowlist_enable_disable_cycle() {
    let scenario = TestScenario::builder("allowlist_cycle")
        .account("alice")
        .sequence([
            step("enable", enable_allow_list("alice")),
            step("add_bob", add_to_allow_list("alice", "bob")),
            step("disable", disable_allow_list("alice")),
            step("re_enable", enable_allow_list("alice")),
            step("verify_bob_still_allowed", transfer("alice", "bob", 100)),  // Should work
        ])
        .expects_success()
        .build();
    
    assert!(run_difftest(&scenario).is_pass());
}

// Scenario 5: Freeze → Unfreeze → Transfer
#[test]
fn test_freeze_unfreeze_transfer() {
    let scenario = TestScenario::builder("freeze_unfreeze_transfer")
        .account("alice", initial_balance(1000))
        .account("bob")
        .sequence([
            step("freeze", freeze_token("alice")),
            step("transfer_fails", transfer("alice", "bob", 100).expects_abort(ESTORE_FROZEN)),
            step("unfreeze", unfreeze_token("alice")),
            step("transfer_succeeds", transfer("alice", "bob", 100).expects_success()),
        ])
        .build();
    
    assert!(run_difftest(&scenario).is_pass());
}
```

**Phase 1 Output:** 5 new scenarios, 100% coverage (102/102)

### Phase 2: Expand Beyond 102 (1 week, reach 120 scenarios)

**Goal:** Add defensive scenarios (not counted in original 102)

**Categories:**

**1. Adversarial scenarios (10 scenarios, 2 days)**
- Malformed proof bytes (corrupt serialization)
- Replayed proofs (same proof used twice)
- Cross-operation proof (registration proof used for withdrawal)
- Timing attacks (if applicable)
- Large inputs (u64::MAX amounts)

**2. Integration scenarios (5 scenarios, 1 day)**
- Multi-hop transfers (A → B → C)
- Batch operations (multiple deposits in sequence)
- Rollback after error (deposit aborts, balance unchanged)

**3. Regression tests (3 scenarios, 1 day)**
- Any bugs found in production → add scenario
- Historical issues from git log

**Phase 2 Output:** 18 new scenarios, 120 total (118% of original target)

### Phase 3: Continuous Expansion (ongoing)

**Process:** For every new operation or feature:
1. Happy path scenario (1 scenario minimum)
2. Error path scenarios (1 per `aborts_if` clause)
3. Edge case scenarios (1-2 per operation)

**Estimated:** +5 scenarios per new operation

---

## Maintenance Strategy

### Weekly Maintenance (30 min)

**Every Monday:**
1. Run full corpus:
   ```bash
   cd aptos-move/framework/formal/difftest
   ./difftest.sh --all
   ```

2. Check for flaky tests (pass/fail intermittently):
   ```bash
   # Run 10 times, flag if any failures
   for i in {1..10}; do ./difftest.sh --all --quiet || echo "Flaky run $i"; done
   ```

3. Update `DIFFTEST_CA_INVENTORY.md` with any changes

### Monthly Review (2 hours)

**First Monday of month:**
1. **Coverage analysis:**
   ```bash
   ./difftest.sh --all --coverage-report > /tmp/coverage.txt
   cat /tmp/coverage.txt | grep "Coverage:"
   # Should be ≥95%, ideally 100%
   ```

2. **Performance analysis:**
   ```bash
   ./difftest.sh --all --benchmark > /tmp/benchmark.txt
   # Check for regressions (any scenario >5s)
   ```

3. **Identify gaps:**
   - New operations without scenarios?
   - New error codes without scenarios?
   - Edge cases not covered?

4. **Plan expansion:**
   - Schedule 1-2 days to add missing scenarios
   - Prioritize high-value gaps (security properties, complex logic)

### Quarterly Audit (1 day)

**First Monday of quarter:**
1. **Full corpus review:**
   - Read every scenario
   - Verify scenario still relevant (or can be removed)
   - Check for duplicates (can be merged)

2. **Oracle mock review:**
   - Are mocks still realistic?
   - Do mocks cover all oracle paths (success/failed/error)?
   - Update mocks if Rust implementation changed

3. **Documentation sync:**
   - Update `DIFFTEST_HARNESS_DEVELOPMENT_GUIDE.md`
   - Update `DIFFTEST_CA_INVENTORY.md`
   - Update `TEST_MATRIX.md` in audit package

---

## Quality Assurance

### Scenario Review Checklist

**Before merging new scenario:**
- [ ] Scenario name is descriptive (`test_transfer_self_rejected`, not `test_foo`)
- [ ] Scenario is independent (sets up own state, no dependencies)
- [ ] Scenario has clear expected outcome (`.expects_success()` or `.expects_abort(CODE)`)
- [ ] Scenario covers a specific edge case or error path (not redundant)
- [ ] Oracle mocks are realistic (not just `always_success`)
- [ ] Scenario passes in CI (run locally first)
- [ ] Scenario documented in `DIFFTEST_CA_INVENTORY.md`

### Corpus Health Metrics

**Track over time:**
1. **Coverage %** (target: ≥95%, stretch: 100%)
2. **Scenario count** (current: 97, target: 102+)
3. **Flaky test rate** (target: <5% of scenarios flaky)
4. **Execution time** (target: full corpus <20 min)
5. **Oracle mock coverage** (target: all 3 paths — success/failed/error — covered)

**Alert thresholds:**
- Coverage <90%: Red (investigate, add scenarios)
- Flaky rate >10%: Yellow (diagnose, fix)
- Execution time >30 min: Yellow (optimize slow scenarios)

### Automated Checks (CI)

**Per-PR difftest check:**
```yaml
# .github/workflows/difftest-pr.yaml (already exists)
- name: Run difftest (happy path only, fast)
  run: ./difftest.sh --filter happy_path

# Exit code 0: pass, non-zero: fail
```

**Nightly difftest check:**
```yaml
# .github/workflows/difftest-nightly.yaml
- name: Run full corpus
  run: ./difftest.sh --all --coverage-report

# Upload coverage report as artifact
# Alert if coverage <95%
```

---

## Related Guides

- [DIFFTEST_HARNESS_DEVELOPMENT_GUIDE.md](DIFFTEST_HARNESS_DEVELOPMENT_GUIDE.md) — Harness architecture and development
- [CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md](CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md) §9 — Definition of done
- [TEST_MATRIX.md](audit/TEST_MATRIX.md) — Three-layer test pyramid
- [DIFFTEST_CA_INVENTORY.md](audit/DIFFTEST_CA_INVENTORY.md) — Complete scenario catalog

---

**Document Status:** v1.0 (2026-04-22)  
**Maintainer:** QA team + Verification team  
**Last Updated:** 2026-04-22  
**Next Review:** 2026-07-22 (quarterly)

**Key Takeaway:** 5 scenarios away from 100% (97/102 current). High-priority: self-transfer rejection (security). Medium-priority: concurrent withdrawal, E2E lifecycle. Low-priority: allow-list cycles, freeze/unfreeze. Estimated 10 hours (1-2 days) to reach 100%. Maintain via weekly runs + monthly reviews + quarterly audits.
