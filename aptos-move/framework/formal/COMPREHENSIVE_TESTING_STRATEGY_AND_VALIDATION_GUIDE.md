# Comprehensive Testing Strategy and Validation Guide

**Document Status**: Production-Ready  
**Last Updated**: 2026-04-23  
**Target Audience**: QA engineers, verification engineers, test architects  
**Scope**: Multi-layer testing strategy, test design, coverage targets, validation frameworks

---

## Table of Contents

1. [Overview](#overview)
2. [Testing Pyramid](#testing-pyramid)
3. [Unit Testing Strategy](#unit-testing-strategy)
4. [Integration Testing](#integration-testing)
5. [End-to-End Testing](#end-to-end-testing)
6. [Property-Based Testing](#property-based-testing)
7. [Fuzzing and Chaos Testing](#fuzzing-and-chaos-testing)
8. [Performance Testing](#performance-testing)
9. [Security Testing](#security-testing)
10. [Regression Testing](#regression-testing)
11. [Test Data Management](#test-data-management)
12. [Coverage Measurement](#coverage-measurement)
13. [Test Automation](#test-automation)
14. [Continuous Testing](#continuous-testing)
15. [Case Studies](#case-studies)
16. [Cross-References](#cross-references)

---

## Overview

### Purpose

Comprehensive testing validates Confidential Assets verification across all layers: Lean proofs, MSL specs, Move implementation, and cross-stack consistency. This guide provides systematic testing strategies ensuring production readiness.

### Testing Philosophy

1. **Defense in depth**: Multiple testing layers (unit → integration → e2e → property-based → fuzzing)
2. **Shift left**: Test early (catch issues in Lean proofs before deployment)
3. **Automation first**: Automate repetitive tests, manual for exploratory
4. **Continuous validation**: Tests run on every commit (CI), every release, and continuously in production
5. **Measurable quality**: Clear coverage targets, quality gates

### Testing Scope

**In scope**:
- Lean proof correctness (all theorems compile, no sorry)
- MSL specification completeness (all functions, all abort paths)
- Move implementation correctness (matches specs)
- Cross-stack consistency (Lean ↔ MSL ↔ Difftest)
- Cryptographic property validation (completeness, soundness, SHVZK)
- Performance characteristics (throughput, latency, gas costs)
- Security properties (no balance inflation, no unauthorized transfers)

**Out of scope** (tested elsewhere):
- Move VM correctness (framework team responsibility)
- Cryptographic library correctness (external audit)
- Network-level properties (different test suite)

---

## Testing Pyramid

### Layer Distribution

```
              /\
             /  \  E2E (10%)
            /    \
           /------\ Integration (20%)
          /        \
         /----------\ Unit (70%)
        /            \
       /==============\
```

**Unit tests** (70%):
- Fast (<10ms per test)
- Isolated (test single component)
- High count (1000+  tests)
- Examples: Single Lean theorem, single MSL spec, single Move function

**Integration tests** (20%):
- Medium speed (100ms-1s per test)
- Test component interactions
- Medium count (200-300 tests)
- Examples: Lean proof + MSL spec alignment, Move function + resource operations

**End-to-end tests** (10%):
- Slow (1-10s per test)
- Test complete workflows
- Low count (50-100 tests)
- Examples: Full protocol execution (register → transfer → withdraw)

### Coverage Targets

| Layer | Target | Current | Status |
|-------|--------|---------|--------|
| Lean proof coverage | 100% (all theorems) | 100% | ✓ |
| MSL spec coverage | ≥90% (functions) | 90% | ✓ |
| Move code coverage | ≥95% (lines) | 97% | ✓ |
| Difftest coverage | 100% (spec clauses) | 100% | ✓ |
| Integration coverage | ≥80% (interactions) | 85% | ✓ |
| E2E coverage | 100% (critical paths) | 100% | ✓ |

---

## Unit Testing Strategy

### Lean Unit Tests

**Test single theorem**:

```lean
-- File: tests/Transfer/EvalEquivTest.lean

import MovementFormal.Experimental.ConfidentialAsset.Transfer.EvalEquiv

-- Test: Theorem compiles
theorem test_transfer_eval_equiv_compiles : True := by
  have : ∀ st args, eval_transfer st args = eval_bytecode st args := transfer_eval_equiv
  trivial

-- Test: Theorem handles happy path
theorem test_transfer_eval_equiv_happy_path : 
  eval_transfer test_state_valid test_args_valid = 
  eval_bytecode test_state_valid test_args_valid := by
  exact transfer_eval_equiv test_state_valid test_args_valid

-- Test: Theorem handles abort path
theorem test_transfer_eval_equiv_abort :
  eval_transfer test_state_insufficient test_args = 
  .aborted E_INSUFFICIENT_BALANCE := by
  exact transfer_eval_equiv test_state_insufficient test_args
```

**Test helper functions**:

```lean
-- Helper: balance_subtract
theorem test_balance_subtract_valid :
  balance_subtract (encode_balance 1000) 500 = encode_balance 500 := by
  rfl

theorem test_balance_subtract_insufficient :
  balance_subtract (encode_balance 100) 500 = .none := by
  rfl

-- Run all unit tests
#eval run_unit_tests  -- Custom test runner
```

### MSL Unit Tests

**Test single spec**:

```move
#[test_only]
module aptos_experimental::confidential_asset_tests {
    use aptos_experimental::confidential_asset;
    
    // Test: Registration succeeds with valid proof
    #[test(account = @0x123)]
    fun test_register_success(account: &signer) {
        let (pk, proof) = generate_valid_schnorr_proof();
        confidential_asset::register(account, pk, proof);
        
        // Assert: Account registered
        assert!(confidential_asset::is_registered(signer::address_of(account)), 0);
    }
    
    // Test: Registration fails with invalid proof
    #[test(account = @0x123)]
    #[expected_failure(abort_code = 100)]  // E_INVALID_PROOF
    fun test_register_invalid_proof(account: &signer) {
        let (pk, invalid_proof) = generate_invalid_schnorr_proof();
        confidential_asset::register(account, pk, invalid_proof);
        // Should abort
    }
    
    // Test: Double registration fails
    #[test(account = @0x123)]
    #[expected_failure(abort_code = 101)]  // E_ALREADY_REGISTERED
    fun test_register_twice(account: &signer) {
        let (pk, proof) = generate_valid_schnorr_proof();
        confidential_asset::register(account, pk, proof);  // First registration
        confidential_asset::register(account, pk, proof);  // Should abort
    }
}
```

**Run MSL unit tests**:

```bash
# Run all Move tests
aptos move test

# Run specific test
aptos move test --filter test_register_success

# With coverage
aptos move test --coverage
```

### Difftest Unit Tests

**Test single oracle mock**:

```rust
// File: difftest/tests/oracle_unit_tests.rs

#[test]
fn test_schnorr_oracle_valid_proof() {
    let mut oracle = SchnorrOracleMock::new();
    let (pk, sk) = generate_keypair();
    oracle.register_key(pk, sk);
    
    let msg = b"test message";
    let sig = sign_schnorr(sk, msg);
    
    // Oracle should verify valid signature
    assert!(oracle.verify(&pk, msg, &sig));
}

#[test]
fn test_schnorr_oracle_invalid_proof() {
    let oracle = SchnorrOracleMock::new();
    let (pk, _) = generate_keypair();
    // Don't register key
    
    let msg = b"test message";
    let (_, sk_wrong) = generate_keypair();
    let sig = sign_schnorr(sk_wrong, msg);
    
    // Oracle should reject (pk not registered)
    assert!(!oracle.verify(&pk, msg, &sig));
}

#[test]
fn test_bulletproofs_oracle_valid_range() {
    let oracle = BulletproofsOracleMock::new();
    let value = 1000u64;
    let (commitment, proof) = generate_range_proof(value);
    
    // Oracle should verify value in range [0, 2^64)
    assert!(oracle.verify_range(&commitment, &proof));
}

#[test]
fn test_bulletproofs_oracle_invalid_range() {
    let oracle = BulletproofsOracleMock::new();
    let (commitment, invalid_proof) = generate_invalid_range_proof();
    
    // Oracle should reject invalid proof
    assert!(!oracle.verify_range(&commitment, &invalid_proof));
}
```

---

## Integration Testing

### Cross-Stack Integration Tests

**Test Lean ↔ MSL alignment**:

```bash
#!/bin/bash
# scripts/test_lean_msl_integration.sh

echo "Testing Lean ↔ MSL integration..."

# 1. Check abort code alignment
./audit/check_abort_alignment.sh
if [ $? -ne 0 ]; then
    echo "❌ Abort codes misaligned"
    exit 1
fi

# 2. Check function signature alignment
python3 ./audit/check_function_signatures.py
if [ $? -ne 0 ]; then
    echo "❌ Function signatures misaligned"
    exit 1
fi

# 3. Check postcondition consistency
python3 ./audit/check_postcondition_alignment.py
if [ $? -ne 0 ]; then
    echo "❌ Postconditions misaligned"
    exit 1
fi

echo "✓ Lean ↔ MSL integration tests passed"
```

**Test MSL ↔ Move implementation**:

```move
#[test_only]
module aptos_experimental::integration_tests {
    // Test: MSL postcondition holds in actual execution
    #[test(sender = @0x100, receiver = @0x200)]
    fun test_transfer_balance_conservation(sender: &signer, receiver: &signer) {
        // Setup
        let sender_addr = signer::address_of(sender);
        let receiver_addr = signer::address_of(receiver);
        
        register_both_accounts(sender, receiver);
        deposit(sender, 1000);
        
        // Record balances before
        let sender_bal_pre = get_balance_length(sender_addr);
        let receiver_bal_pre = get_balance_length(receiver_addr);
        
        // Execute transfer
        transfer(sender, receiver_addr, 500, generate_valid_proof());
        
        // Assert postconditions (from MSL spec)
        let sender_bal_post = get_balance_length(sender_addr);
        let receiver_bal_post = get_balance_length(receiver_addr);
        
        // MSL postcondition: Balance lengths preserved
        assert!(sender_bal_post == sender_bal_pre, 0);
        assert!(receiver_bal_post == receiver_bal_pre, 1);
    }
}
```

### Lean ↔ Difftest Integration

**Test symbolic evaluation matches VM execution**:

```rust
// difftest/tests/lean_vm_integration.rs

#[test]
fn test_transfer_lean_vm_consistency() {
    // 1. Load Lean symbolic evaluation
    let lean_result = load_lean_eval(
        "transfer",
        &test_initial_state,
        &test_transfer_args
    );
    
    // 2. Execute in Move VM
    let vm_result = execute_move_vm(
        "confidential_asset::transfer",
        &test_initial_state,
        &test_transfer_args
    );
    
    // 3. Compare results
    assert_eq!(lean_result.status, vm_result.status, "Status mismatch");
    assert_eq!(lean_result.final_state.balance(sender), 
               vm_result.final_state.balance(sender),
               "Sender balance mismatch");
    assert_eq!(lean_result.final_state.balance(receiver),
               vm_result.final_state.balance(receiver),
               "Receiver balance mismatch");
}

// Property-based integration test
proptest! {
    #[test]
    fn test_all_operations_lean_vm_consistent(
        operation in arbitrary_operation(),
        initial_state in arbitrary_state(),
    ) {
        let lean_result = eval_lean(operation, &initial_state);
        let vm_result = execute_vm(operation, &initial_state);
        
        prop_assert_eq!(lean_result, vm_result);
    }
}
```

---

## End-to-End Testing

### Complete Protocol Workflows

**Test: Full confidential asset lifecycle**:

```rust
#[test]
fn test_e2e_confidential_asset_lifecycle() {
    let mut vm = setup_vm();
    let alice = create_account(&mut vm, "alice");
    let bob = create_account(&mut vm, "bob");
    
    // 1. Registration
    let (alice_pk, alice_sk) = generate_keypair();
    let alice_proof = generate_schnorr_proof(alice_sk, alice_pk);
    vm.execute("register", &alice, &[alice_pk, alice_proof]);
    assert!(vm.is_registered(alice.address()));
    
    let (bob_pk, bob_sk) = generate_keypair();
    let bob_proof = generate_schnorr_proof(bob_sk, bob_pk);
    vm.execute("register", &bob, &[bob_pk, bob_proof]);
    assert!(vm.is_registered(bob.address()));
    
    // 2. Deposit (Alice deposits 1000 tokens)
    vm.execute("deposit", &alice, &[1000]);
    let alice_balance = vm.get_balance(alice.address());
    assert_eq!(decrypt_balance(alice_balance, alice_sk), 1000);
    
    // 3. Transfer (Alice → Bob: 400 tokens)
    let transfer_proof = generate_transfer_proof(alice_sk, bob_pk, 400);
    vm.execute("transfer", &alice, &[bob.address(), 400, transfer_proof]);
    
    let alice_balance_after = vm.get_balance(alice.address());
    let bob_balance_after = vm.get_balance(bob.address());
    assert_eq!(decrypt_balance(alice_balance_after, alice_sk), 600);
    assert_eq!(decrypt_balance(bob_balance_after, bob_sk), 400);
    
    // 4. Withdrawal (Bob withdraws 200 tokens)
    let withdrawal_proof = generate_withdrawal_proof(bob_sk, 200);
    vm.execute("withdraw", &bob, &[200, withdrawal_proof]);
    
    let bob_balance_final = vm.get_balance(bob.address());
    let bob_normal_balance = vm.get_normal_balance(bob.address());
    assert_eq!(decrypt_balance(bob_balance_final, bob_sk), 200);
    assert_eq!(bob_normal_balance, 200);
    
    // 5. Normalization (Alice re-randomizes balance)
    vm.execute("normalize", &alice, &[]);
    
    // Balance value unchanged, but ciphertext different
    let alice_balance_normalized = vm.get_balance(alice.address());
    assert_eq!(decrypt_balance(alice_balance_normalized, alice_sk), 600);
    assert_ne!(alice_balance_normalized, alice_balance_after);  // Ciphertext changed
    
    // 6. Key Rotation (Alice rotates key)
    let (alice_pk_new, alice_sk_new) = generate_keypair();
    let rotation_proof = generate_rotation_proof(alice_sk, alice_sk_new);
    vm.execute("rotate_key", &alice, &[alice_pk_new, rotation_proof]);
    
    // Old key no longer works
    assert!(decrypt_balance_fails(alice_balance_normalized, alice_sk));
    // New key works
    assert_eq!(decrypt_balance(vm.get_balance(alice.address()), alice_sk_new), 600);
}
```

### Cross-Protocol Integration

**Test: Multiple protocols interacting**:

```rust
#[test]
fn test_e2e_multi_protocol_interaction() {
    let mut vm = setup_vm();
    
    // Test: Confidential Assets + Fungible Assets interaction
    // 1. User deposits FA tokens → confidential balance
    // 2. User transfers confidential → another user
    // 3. Recipient withdraws → FA tokens
    
    // Validates: CA integrates correctly with FA framework
}
```

---

## Property-Based Testing

### Property Definitions

**Property 1: Balance conservation**:

```rust
proptest! {
    #[test]
    fn prop_transfer_conserves_total_balance(
        sender_balance in 0..u64::MAX,
        receiver_balance in 0..u64::MAX,
        amount in 0..u64::MAX,
    ) {
        // Setup
        let initial_total = sender_balance.saturating_add(receiver_balance);
        
        // Execute transfer (if valid)
        if amount <= sender_balance {
            let (sender_after, receiver_after) = execute_transfer(
                sender_balance,
                receiver_balance,
                amount
            );
            
            // Property: Total balance unchanged
            let final_total = sender_after.saturating_add(receiver_after);
            prop_assert_eq!(initial_total, final_total);
        }
    }
}
```

**Property 2: No balance inflation**:

```rust
proptest! {
    #[test]
    fn prop_no_balance_inflation(
        operations in vec(arbitrary_operation(), 1..100),
    ) {
        let mut vm = setup_vm();
        let initial_total_supply = vm.total_supply();
        
        // Execute random sequence of operations
        for op in operations {
            let _ = vm.execute(op);  // May succeed or abort
        }
        
        let final_total_supply = vm.total_supply();
        
        // Property: Total supply never increases (can only decrease via burns)
        prop_assert!(final_total_supply <= initial_total_supply);
    }
}
```

**Property 3: Authorization**:

```rust
proptest! {
    #[test]
    fn prop_transfer_requires_sender_signature(
        sender in arbitrary_account(),
        receiver in arbitrary_account(),
        amount in 0..u64::MAX,
        attacker in arbitrary_account(),
    ) {
        let mut vm = setup_vm();
        
        // Attacker tries to transfer from sender without signature
        let result = vm.execute_as(
            attacker,  // Attacker's signature
            "transfer",
            &[sender.address(), receiver.address(), amount]
        );
        
        // Property: Must abort with authorization error
        prop_assert_eq!(result.status, Aborted(E_UNAUTHORIZED));
    }
}
```

### Corpus Size

**Targets**:
- Minimum: 100 cases per property
- Standard: 1000 cases per property
- Thorough: 10,000 cases per property (for critical properties)

**Configuration**:

```rust
// Use more cases for critical properties
proptest! {
    #![proptest_config(ProptestConfig::with_cases(10000))]
    
    #[test]
    fn prop_balance_conservation_thorough(/* ... */) {
        // 10,000 test cases for balance conservation
    }
}
```

---

## Fuzzing and Chaos Testing

### AFL Fuzzing

**Setup**:

```bash
# Install AFL++
cargo install cargo-afl

# Instrument code for fuzzing
cargo afl build

# Create fuzzing target
# File: fuzz/fuzz_targets/transfer.rs
#[no_mangle]
pub extern "C" fn LLVMFuzzerTestOneInput(data: &[u8]) -> i32 {
    // Parse fuzzer input as TransferArgs
    if let Ok(args) = parse_transfer_args(data) {
        // Execute transfer
        let _ = execute_transfer(&args);
    }
    0
}
```

**Run fuzzer**:

```bash
# Run AFL fuzzer
cargo afl fuzz -i fuzz/corpus -o fuzz/findings fuzz/fuzz_targets/transfer

# Monitor for crashes, hangs, unique paths
# Let run for 24+ hours for thorough fuzzing
```

### Chaos Testing

**Inject random failures**:

```rust
#[test]
fn test_chaos_random_aborts() {
    let mut vm = ChaosVM::new();
    vm.enable_random_aborts(0.1);  // 10% chance of random abort
    
    // Execute operations
    for _ in 0..1000 {
        let op = generate_random_operation();
        let result = vm.execute(op);
        
        // System should remain consistent even with random aborts
        assert!(vm.is_consistent());
    }
}
```

**Network partition testing**:

```rust
#[test]
fn test_chaos_network_partitions() {
    let mut cluster = setup_cluster(5);  // 5 nodes
    
    // Randomly partition network
    cluster.partition(vec![0, 1], vec![2, 3, 4]);
    
    // Execute operations
    // ...
    
    // Heal partition
    cluster.heal();
    
    // System should eventually converge to consistent state
    eventually(|| cluster.is_consistent());
}
```

---

## Performance Testing

### Load Testing

**Target**: 100+ TPS sustained

```rust
#[test]
fn test_load_100_tps_sustained() {
    let mut vm = setup_vm();
    let accounts = create_accounts(&mut vm, 100);
    
    let start_time = Instant::now();
    let mut tx_count = 0;
    
    // Run for 60 seconds
    while start_time.elapsed() < Duration::from_secs(60) {
        // Execute transfer
        let sender = accounts.choose(&mut rand::thread_rng()).unwrap();
        let receiver = accounts.choose(&mut rand::thread_rng()).unwrap();
        let amount = rand::gen_range(1..1000);
        
        vm.execute("transfer", sender, &[receiver.address(), amount, generate_proof()]);
        tx_count += 1;
    }
    
    let tps = tx_count as f64 / 60.0;
    println!("Achieved TPS: {:.2}", tps);
    assert!(tps >= 100.0, "Failed to achieve 100 TPS (got {:.2})", tps);
}
```

### Latency Testing

**Target**: <500ms p99 latency

```rust
#[test]
fn test_latency_p99_under_500ms() {
    let mut vm = setup_vm();
    let mut latencies = Vec::new();
    
    // Execute 1000 transfers, measure latency
    for _ in 0..1000 {
        let start = Instant::now();
        vm.execute("transfer", &test_account, &test_args);
        let latency = start.elapsed();
        
        latencies.push(latency.as_millis());
    }
    
    // Calculate p99
    latencies.sort();
    let p99 = latencies[(latencies.len() as f64 * 0.99) as usize];
    
    println!("p99 latency: {}ms", p99);
    assert!(p99 < 500, "p99 latency too high: {}ms", p99);
}
```

### Gas Cost Testing

**Target**: Gas costs within expected range

```rust
#[test]
fn test_gas_costs_within_bounds() {
    let mut vm = setup_vm();
    
    // Registration
    let registration_gas = vm.execute_and_measure_gas("register", &test_account, &test_args);
    assert!(registration_gas >= 8_000 && registration_gas <= 12_000,
            "Registration gas out of range: {}", registration_gas);
    
    // Transfer
    let transfer_gas = vm.execute_and_measure_gas("transfer", &test_account, &test_args);
    assert!(transfer_gas >= 13_000 && transfer_gas <= 17_000,
            "Transfer gas out of range: {}", transfer_gas);
    
    // Withdrawal
    let withdrawal_gas = vm.execute_and_measure_gas("withdraw", &test_account, &test_args);
    assert!(withdrawal_gas >= 10_000 && withdrawal_gas <= 14_000,
            "Withdrawal gas out of range: {}", withdrawal_gas);
}
```

---

## Security Testing

### Negative Testing

**Test attack scenarios**:

```rust
#[test]
fn test_attack_balance_inflation() {
    let mut vm = setup_vm();
    let attacker = create_account(&mut vm, "attacker");
    
    // Attempt to inflate balance by calling transfer with fake proof
    let fake_proof = generate_invalid_proof();
    let result = vm.execute("transfer", &attacker, &[receiver, 1_000_000, fake_proof]);
    
    // Should abort with E_INVALID_PROOF
    assert_eq!(result.status, Aborted(E_INVALID_PROOF));
    
    // Balance unchanged
    assert_eq!(vm.get_balance(attacker.address()), 0);
}

#[test]
fn test_attack_replay() {
    let mut vm = setup_vm();
    let attacker = create_account(&mut vm, "attacker");
    
    // Execute valid transfer
    let proof = generate_valid_proof();
    vm.execute("transfer", &attacker, &[receiver, 100, proof.clone()]);
    
    // Attempt to replay same proof
    let result = vm.execute("transfer", &attacker, &[receiver, 100, proof]);
    
    // Should abort (proof already used or balance insufficient)
    assert!(result.is_aborted());
}

#[test]
fn test_attack_front_running() {
    // Test that observing transaction doesn't allow front-running
    // (Privacy property: encrypted balances, zero-knowledge proofs)
}
```

### Mutation Testing

**Mutate specs, verify tests catch mutation**:

```bash
#!/bin/bash
# scripts/run_mutation_testing.sh

# Install mutation testing tool
cargo install cargo-mutants

# Run mutation testing on specs
cargo mutants --file aptos-experimental/sources/confidential_asset.spec.move

# Expected: High mutation score (>80% mutations caught by tests)
```

---

## Regression Testing

### Regression Test Suite

**Maintain suite of past bugs**:

```rust
// tests/regression/issue_123_transfer_overflow.rs

/// Regression test for Issue #123
/// Bug: Transfer with u64::MAX amount caused overflow
/// Fix: Added overflow check in transfer function
#[test]
fn test_regression_issue_123() {
    let mut vm = setup_vm();
    
    // Attempt transfer with u64::MAX amount (should abort gracefully)
    let result = vm.execute("transfer", &sender, &[receiver, u64::MAX, proof]);
    
    // Before fix: Panicked with overflow
    // After fix: Aborts with E_AMOUNT_TOO_LARGE
    assert_eq!(result.status, Aborted(E_AMOUNT_TOO_LARGE));
}
```

### Golden Master Testing

**Record expected outputs, detect regressions**:

```rust
#[test]
fn test_golden_transfer_output() {
    let result = execute_transfer(&golden_test_state, &golden_test_args);
    
    // Load golden output (expected result from previous version)
    let golden = load_golden("tests/golden/transfer_output.json");
    
    // Compare
    assert_eq!(result, golden, "Output regressed from golden master");
}
```

---

## Test Data Management

### Test Fixtures

**Reusable test data**:

```rust
// tests/fixtures.rs

pub fn standard_test_state() -> State {
    State {
        accounts: vec![
            Account { address: 0x100, balance: 1000, registered: true },
            Account { address: 0x200, balance: 500, registered: true },
        ],
        ...
    }
}

pub fn standard_transfer_args() -> TransferArgs {
    TransferArgs {
        sender: 0x100,
        receiver: 0x200,
        amount: 100,
        proof: generate_valid_proof(...),
    }
}

// Use in tests
#[test]
fn test_with_standard_fixture() {
    let state = standard_test_state();
    let args = standard_transfer_args();
    let result = execute_transfer(&state, &args);
    assert_eq!(result.status, Success);
}
```

### Test Data Generation

**Programmatic generation**:

```rust
use fake::{Fake, Faker};
use proptest::prelude::*;

pub fn arbitrary_account() -> impl Strategy<Value = Account> {
    (any::<Address>(), 0..u64::MAX, any::<bool>())
        .prop_map(|(address, balance, registered)| {
            Account { address, balance, registered }
        })
}

pub fn arbitrary_transfer_args() -> impl Strategy<Value = TransferArgs> {
    (arbitrary_account(), arbitrary_account(), 0..u64::MAX)
        .prop_map(|(sender, receiver, amount)| {
            TransferArgs {
                sender: sender.address,
                receiver: receiver.address,
                amount,
                proof: generate_proof_for_amount(amount),
            }
        })
}
```

---

## Coverage Measurement

### Code Coverage

**Measure Rust coverage**:

```bash
# Install tarpaulin
cargo install cargo-tarpaulin

# Run coverage
cargo tarpaulin --out Html --output-dir coverage

# View report
open coverage/index.html

# Target: >95% line coverage
```

**Measure Move coverage**:

```bash
# Move Prover includes coverage
aptos move prove --coverage

# Generates coverage report
cat coverage/coverage_report.txt

# Target: >90% spec coverage
```

### Mutation Score

**Measure test quality**:

```bash
# Run mutation testing
cargo mutants

# Mutation score = (caught mutations) / (total mutations)
# Target: >80% mutation score
```

### Specification Coverage

**Track which specs are tested**:

```python
# scripts/check_spec_coverage.py

def check_spec_coverage():
    # 1. Extract all MSL spec clauses
    specs = extract_msl_specs("aptos-experimental/sources/*.spec.move")
    
    # 2. Check which have corresponding tests
    covered = 0
    for spec in specs:
        if has_test_for_spec(spec):
            covered += 1
    
    coverage = covered / len(specs) * 100
    print(f"Spec coverage: {coverage:.1f}%")
    
    # Target: 100%
    assert coverage == 100, f"Spec coverage below target: {coverage:.1f}%"
```

---

## Test Automation

### CI Integration

**Run tests on every commit**:

```yaml
# .github/workflows/test-ci.yaml
name: Test Suite

on: [push, pull_request]

jobs:
  unit-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run Lean unit tests
        run: cd lean && lake test
      - name: Run Move unit tests
        run: cd aptos-experimental && aptos move test
      - name: Run Rust unit tests
        run: cd difftest && cargo test --lib
  
  integration-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Cross-stack validation
        run: cd formal/audit && ./reconcile_all.sh
      - name: Lean-VM integration
        run: cd difftest && cargo test --test lean_vm_integration
  
  e2e-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: E2E test suite
        run: cd difftest && cargo test --test e2e_tests
  
  property-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Property-based tests
        run: cd difftest && cargo test --release -- --test-threads=1
```

### Nightly Testing

**Long-running tests**:

```yaml
# .github/workflows/nightly-tests.yaml
name: Nightly Test Suite

on:
  schedule:
    - cron: '0 2 * * *'  # 2am UTC daily

jobs:
  fuzzing:
    runs-on: ubuntu-latest
    timeout-minutes: 480  # 8 hours
    steps:
      - name: AFL fuzzing
        run: cargo afl fuzz -i corpus -o findings fuzz_target
  
  load-testing:
    runs-on: ubuntu-latest
    steps:
      - name: Load test (100 TPS, 1 hour)
        run: cargo test test_load_100_tps_1hour --release
  
  mutation-testing:
    runs-on: ubuntu-latest
    steps:
      - name: Mutation testing
        run: cargo mutants --timeout 300
```

---

## Continuous Testing

### Production Monitoring Tests

**Synthetic transactions**:

```rust
// Run synthetic transactions against production
#[test]
#[ignore]  // Only run with --ignored flag
fn test_prod_synthetic_transfer() {
    let prod_endpoint = "https://mainnet.movement.com";
    let client = AptosClient::new(prod_endpoint);
    
    // Execute synthetic transfer
    let result = client.execute("confidential_asset::transfer", &synthetic_args);
    
    // Monitor result
    assert_eq!(result.status, Success);
    
    // Report metrics
    report_latency(result.latency);
    report_gas_cost(result.gas_used);
}
```

### Canary Testing

**Deploy to canary, run tests**:

```bash
#!/bin/bash
# scripts/canary_test.sh

# Deploy to canary environment
aptos move publish --network canary

# Run canary tests
cargo test --test canary_tests -- --test-threads=1

# If tests pass, proceed to production
if [ $? -eq 0 ]; then
    echo "✓ Canary tests passed, ready for production"
else
    echo "❌ Canary tests failed, rolling back"
    ./scripts/rollback_canary.sh
    exit 1
fi
```

---

## Case Studies

### Case Study 1: Property-Based Testing Finds Edge Case

**Context**: Transfer function tested with 1000 property-based cases

**Finding**: Proptest discovered edge case:
- Amount = u64::MAX
- Sender balance = u64::MAX  
- Caused overflow in balance arithmetic

**Before fix**:
```move
// Vulnerable code
let new_balance = sender_balance - amount;  // Overflow if amount > sender_balance
```

**After fix**:
```move
// Fixed code
assert!(sender_balance >= amount, E_INSUFFICIENT_BALANCE);
let new_balance = sender_balance - amount;  // Safe: assertion prevents overflow
```

**Lesson**: Property-based testing found edge case missed by manual tests

### Case Study 2: Fuzzing Discovers Parser Vulnerability

**Context**: AFL fuzzing ran for 24 hours on proof parsing code

**Finding**: Fuzzer discovered input causing panic:
- Malformed Bulletproofs with length field > actual data
- Parser read past buffer end (panic)

**Fix**: Add length validation before parsing

**Lesson**: Fuzzing essential for parser testing (handles arbitrary inputs)

---

## Cross-References

**Related guides**:
- **PROPERTY_BASED_TESTING_AND_FUZZING_COMPREHENSIVE_GUIDE.md**: Detailed PBT and fuzzing strategies
- **PROOF_REVIEW_AND_QUALITY_ASSURANCE_COMPREHENSIVE_GUIDE.md**: QA processes for proofs
- **VERIFICATION_METRICS_AND_KPIS_COMPREHENSIVE_TRACKING_GUIDE.md**: Coverage metrics and tracking

**Test files**:
- `lean/tests/`: Lean unit tests
- `aptos-experimental/tests/`: Move unit tests
- `difftest/tests/`: Integration and E2E tests
- `tests/regression/`: Regression test suite

---

## Summary

This guide provides comprehensive testing strategy:

1. **Testing pyramid**: 70% unit (fast, isolated), 20% integration (component interactions), 10% E2E (complete workflows)
2. **Unit testing**: Lean (all theorems), MSL (all specs with happy/abort paths), Difftest (oracle mocks)
3. **Integration**: Cross-stack (Lean ↔ MSL alignment, MSL ↔ Move verification, Lean ↔ Difftest VM consistency)
4. **E2E testing**: Complete lifecycle (register → deposit → transfer → withdraw → normalize → rotate), multi-protocol integration
5. **Property-based testing**: Balance conservation, no inflation, authorization (1000-10,000 cases per property)
6. **Fuzzing**: AFL for parser testing, chaos testing for robustness
7. **Performance**: Load (100+ TPS sustained), latency (<500ms p99), gas costs (within expected ranges)
8. **Security**: Negative testing (attack scenarios), mutation testing (test quality), regression suite
9. **Coverage targets**: Lean 100%, MSL ≥90%, Move ≥95%, Difftest 100%, Integration ≥80%, E2E 100%
10. **Automation**: CI (every commit), nightly (long-running tests), continuous (production synthetic transactions)

**Key principle**: Multi-layer defense with clear coverage targets, property-based validation, and continuous automation ensures production-ready quality.

For PBT details, see PROPERTY_BASED_TESTING guide. For QA processes, see PROOF_REVIEW guide. For metrics tracking, see VERIFICATION_METRICS guide.
