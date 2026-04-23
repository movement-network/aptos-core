# Testing Strategy: Comprehensive Guide for Verified Protocols

**Version**: 1.0  
**Last Updated**: 2026-04-22  
**Status**: Production  
**Audience**: QA engineers, verification engineers, test developers  
**Estimated Read Time**: 80 minutes  
**Prerequisites**: Understanding of Lean, MSL, Difftest  

---

## Table of Contents

1. [Overview](#overview)
2. [Three-Layer Testing Pyramid](#three-layer-testing-pyramid)
3. [Unit Testing Strategy](#unit-testing-strategy)
4. [Integration Testing](#integration-testing)
5. [End-to-End Testing](#end-to-end-testing)
6. [Property-Based Testing](#property-based-testing)
7. [Fuzz Testing](#fuzz-testing)
8. [Performance Testing](#performance-testing)
9. [Security Testing](#security-testing)
10. [Regression Testing](#regression-testing)
11. [Test Coverage Metrics](#test-coverage-metrics)
12. [Continuous Testing Infrastructure](#continuous-testing-infrastructure)

---

## Overview

### Testing Philosophy

**Verification ≠ Testing**

- **Verification** (Lean/MSL): Proves properties hold for *all* inputs
- **Testing** (Difftest): Validates behavior for *specific* inputs

**Both Are Necessary:**
- Verification ensures correctness
- Testing validates implementation matches verification
- Testing catches integration issues
- Testing provides empirical evidence

### Testing Objectives

**O1: Correctness Validation**
- Verified properties hold in practice
- Implementation matches specification
- No gaps between layers

**O2: Integration Validation**
- Components work together correctly
- Cross-protocol composition works
- End-to-end flows successful

**O3: Performance Validation**
- Gas costs within budgets
- Latency acceptable
- Throughput meets requirements

**O4: Security Validation**
- Attack vectors mitigated
- Error handling secure
- No information leakage

---

## Three-Layer Testing Pyramid

### Layer 1: Lean Proofs (Mathematical Foundation)

**What:** Formal verification of symbolic execution

**Coverage:** 100% of logic (all possible inputs)

**Tests:**
```lean
-- Not "tests" but proofs
theorem transfer_correct :
    ∀ sender receiver amount,
      amount ≤ sender_balance →
      run_transfer sender receiver amount = 
        (sender_balance - amount, receiver_balance + amount) := by
  -- Proof covers ALL valid amounts
```

**Verification, Not Testing:**
- Proves properties mathematically
- No execution required
- Covers infinite input space

### Layer 2: MSL Specifications (Functional Correctness)

**What:** Specification-based verification

**Coverage:** All public functions

**Tests:**
```move
spec transfer {
    requires balance(sender) >= amount;
    ensures balance(sender) == old(balance(sender)) - amount;
    ensures balance(receiver) == old(balance(receiver)) + amount;
    aborts_if balance(sender) < amount;
}
```

**Automated Verification:**
- Move Prover generates verification conditions
- SMT solver checks properties
- No manual test writing

### Layer 3: Difftest (Empirical Validation)

**What:** Concrete execution testing

**Coverage:** Representative scenarios (95%+ coverage)

**Tests:**
```rust
#[test]
fn test_transfer_basic() {
    let sender = create_account(1000);
    let receiver = create_account(0);
    
    transfer(&sender, &receiver, 300).unwrap();
    
    assert_eq!(get_balance(&sender), 700);
    assert_eq!(get_balance(&receiver), 300);
}
```

**Empirical Evidence:**
- Actual execution
- Real VM behavior
- Integration testing

### Pyramid Structure

```
         /\
        /  \  Lean Proofs
       /────\  (100% logic coverage, 0 execution)
      /      \
     /────────\ MSL Specs
    /          \ (100% function coverage, verified)
   /────────────\
  / Difftest     \ (95%+ scenario coverage, executed)
 /________________\

    More Abstract
         ↑
         |
         |
    More Concrete
```

---

## Unit Testing Strategy

### Test Scope

**Unit Test Definition:**
Test single function in isolation

**Example: Transfer Function**
```rust
#[test]
fn unit_test_transfer_success() {
    // Setup: Single function scope
    let sender = setup_account_with_balance(1000);
    let receiver = setup_account_with_balance(0);
    let proof = generate_transfer_proof(&sender, &receiver, 300);
    
    // Execute: Single function
    let result = confidential_asset::transfer(&sender, &receiver, 300, proof);
    
    // Assert: Function postconditions
    assert!(result.is_ok());
    assert_eq!(get_balance(&sender), 700);
    assert_eq!(get_balance(&receiver), 300);
}

#[test]
fn unit_test_transfer_insufficient_balance() {
    let sender = setup_account_with_balance(100);
    let receiver = setup_account_with_balance(0);
    let proof = generate_transfer_proof(&sender, &receiver, 300);
    
    // Should fail
    let result = confidential_asset::transfer(&sender, &receiver, 300, proof);
    
    assert!(result.is_err());
    assert_eq!(result.unwrap_err(), INSUFFICIENT_BALANCE);
}
```

### Boundary Testing

**Test Boundary Values:**
```rust
#[test]
fn test_transfer_boundary_zero_amount() {
    let result = transfer(&sender, &receiver, 0, proof);
    // Should succeed (valid edge case)
    assert!(result.is_ok());
}

#[test]
fn test_transfer_boundary_exact_balance() {
    let sender = setup_account_with_balance(1000);
    let result = transfer(&sender, &receiver, 1000, proof);
    // Should succeed (exact balance)
    assert!(result.is_ok());
    assert_eq!(get_balance(&sender), 0);
}

#[test]
fn test_transfer_boundary_max_u64() {
    let sender = setup_account_with_balance(u64::MAX);
    let result = transfer(&sender, &receiver, u64::MAX, proof);
    assert!(result.is_ok());
}

#[test]
fn test_transfer_overflow() {
    let sender = setup_account_with_balance(u64::MAX);
    let receiver = setup_account_with_balance(1);
    // Should handle overflow gracefully
    let result = transfer(&sender, &receiver, u64::MAX, proof);
    assert!(result.is_err());
}
```

### Error Path Testing

**Test All Error Conditions:**
```rust
// From MSL spec:
// aborts_if balance(sender) < amount;
// aborts_if !valid_proof(proof);
// aborts_if !exists<Balance>(receiver);

#[test]
fn test_all_error_paths() {
    // Error 1: Insufficient balance
    test_transfer_insufficient_balance();
    
    // Error 2: Invalid proof
    test_transfer_invalid_proof();
    
    // Error 3: Receiver not registered
    test_transfer_unregistered_receiver();
}
```

---

## Integration Testing

### Cross-Protocol Integration

**Test Protocol Interactions:**
```rust
#[test]
fn integration_register_then_transfer() {
    // Register sender
    let sender = create_account();
    let sender_reg_proof = generate_registration_proof(&sender);
    confidential_asset::register(&sender, sender_reg_proof).unwrap();
    
    // Register receiver
    let receiver = create_account();
    let receiver_reg_proof = generate_registration_proof(&receiver);
    confidential_asset::register(&receiver, receiver_reg_proof).unwrap();
    
    // Deposit to sender
    deposit(&sender, 1000).unwrap();
    
    // Transfer
    let transfer_proof = generate_transfer_proof(&sender, &receiver, 300);
    confidential_asset::transfer(&sender, &receiver, 300, transfer_proof).unwrap();
    
    // Verify end-to-end
    assert_eq!(decrypt_balance(&sender), 700);
    assert_eq!(decrypt_balance(&receiver), 300);
}

#[test]
fn integration_transfer_then_normalize() {
    let sender = setup_registered_account(1000);
    let receiver = setup_registered_account(0);
    
    // Transfer
    transfer(&sender, &receiver, 300, transfer_proof).unwrap();
    
    // Normalize sender's balance for privacy
    let normalize_proof = generate_normalization_proof(&sender);
    confidential_asset::normalize(&sender, normalize_proof).unwrap();
    
    // Verify balance preserved
    assert_eq!(decrypt_balance(&sender), 700);
    
    // Verify encryption changed
    let encrypted_after = get_encrypted_balance(&sender);
    assert_ne!(encrypted_before, encrypted_after);
}
```

### Cross-Module Integration

**Test Module Dependencies:**
```rust
#[test]
fn integration_confidential_with_public_balance() {
    let account = create_account();
    
    // Start with public balance
    coin::register<AptosCoin>(&account);
    coin::deposit(account_addr, 1000);
    
    // Convert to confidential
    let reg_proof = generate_registration_proof(&account);
    confidential_asset::register(&account, reg_proof).unwrap();
    confidential_asset::deposit(&account, 500).unwrap();
    
    // Verify both balances
    assert_eq!(coin::balance<AptosCoin>(account_addr), 500);  // Public
    assert_eq!(decrypt_balance(&account), 500);  // Confidential
    
    // Withdraw back to public
    let withdraw_proof = generate_withdrawal_proof(&account, 200);
    confidential_asset::withdraw(&account, 200, withdraw_proof).unwrap();
    
    assert_eq!(coin::balance<AptosCoin>(account_addr), 700);
    assert_eq!(decrypt_balance(&account), 300);
}
```

---

## End-to-End Testing

### Complete User Flows

**Test Realistic Scenarios:**
```rust
#[test]
fn e2e_full_user_lifecycle() {
    // 1. User onboarding
    let alice = create_account();
    let alice_keypair = generate_keypair();
    
    // 2. Registration
    let reg_proof = generate_registration_proof_with_keypair(&alice, &alice_keypair);
    confidential_asset::register(&alice, reg_proof).unwrap();
    
    // 3. Initial deposit
    coin::register<AptosCoin>(&alice);
    mint_coins(&alice, 10000);  // Get some public coins
    confidential_asset::deposit(&alice, 10000).unwrap();
    assert_eq!(decrypt_balance(&alice), 10000);
    
    // 4. Multiple transfers
    let bob = setup_registered_account(0);
    let carol = setup_registered_account(0);
    
    transfer(&alice, &bob, 3000, generate_proof()).unwrap();
    transfer(&alice, &carol, 2000, generate_proof()).unwrap();
    
    assert_eq!(decrypt_balance(&alice), 5000);
    assert_eq!(decrypt_balance(&bob), 3000);
    assert_eq!(decrypt_balance(&carol), 2000);
    
    // 5. Bob transfers to Carol
    transfer(&bob, &carol, 1000, generate_proof()).unwrap();
    assert_eq!(decrypt_balance(&bob), 2000);
    assert_eq!(decrypt_balance(&carol), 3000);
    
    // 6. Alice normalizes for privacy
    normalize(&alice, generate_normalization_proof(&alice)).unwrap();
    assert_eq!(decrypt_balance(&alice), 5000);  // Same balance
    
    // 7. Partial withdrawal
    withdraw(&alice, 2000, generate_withdrawal_proof(&alice, 2000)).unwrap();
    assert_eq!(decrypt_balance(&alice), 3000);
    assert_eq!(coin::balance<AptosCoin>(alice_addr), 2000);
    
    // 8. Key rotation
    let new_keypair = generate_keypair();
    let rotation_proof = generate_rotation_proof(&alice, &alice_keypair, &new_keypair);
    confidential_asset::rotate_key(&alice, new_keypair.public, rotation_proof).unwrap();
    
    // Verify can still access balance with new key
    assert_eq!(decrypt_balance_with_key(&alice, &new_keypair), 3000);
}
```

### Multi-User Scenarios

**Test Concurrent Operations:**
```rust
#[test]
fn e2e_multi_user_concurrent_transfers() {
    // Setup 10 users
    let users: Vec<_> = (0..10).map(|_| setup_registered_account(1000)).collect();
    
    // Concurrent transfers (simulated)
    let mut threads = vec![];
    for i in 0..10 {
        let sender = users[i].clone();
        let receiver = users[(i + 1) % 10].clone();
        
        threads.push(thread::spawn(move || {
            transfer(&sender, &receiver, 100, generate_proof()).unwrap();
        }));
    }
    
    // Wait for all transfers
    for thread in threads {
        thread.join().unwrap();
    }
    
    // Verify: Each user sent 100, received 100, balance unchanged
    for user in users {
        assert_eq!(decrypt_balance(&user), 1000);
    }
}
```

---

## Property-Based Testing

### Property Definition

**Example Properties:**
```rust
use proptest::prelude::*;

// Property: Transfer preserves total supply
proptest! {
    #[test]
    fn prop_transfer_preserves_supply(
        sender_balance in 0u64..=1_000_000,
        receiver_balance in 0u64..=1_000_000,
        amount in 0u64..=1_000_000
    ) {
        // Setup
        let sender = setup_account_with_balance(sender_balance);
        let receiver = setup_account_with_balance(receiver_balance);
        
        // Only test valid transfers
        if amount > sender_balance {
            return Ok(());
        }
        
        let total_before = sender_balance + receiver_balance;
        
        // Execute
        transfer(&sender, &receiver, amount, generate_proof())?;
        
        // Verify property
        let total_after = decrypt_balance(&sender) + decrypt_balance(&receiver);
        assert_eq!(total_before, total_after);
    }
}

// Property: Normalization preserves balance
proptest! {
    #[test]
    fn prop_normalization_preserves_balance(
        balance in 0u64..=1_000_000
    ) {
        let account = setup_account_with_balance(balance);
        
        normalize(&account, generate_normalization_proof(&account))?;
        
        assert_eq!(decrypt_balance(&account), balance);
    }
}
```

### Invariant Testing

**Test Global Invariants:**
```rust
proptest! {
    #[test]
    fn prop_total_supply_invariant(
        operations in prop::collection::vec(any::<Operation>(), 1..100)
    ) {
        let mut state = initialize_state();
        let initial_supply = get_total_supply(&state);
        
        // Execute arbitrary sequence of operations
        for op in operations {
            state = execute_operation(state, op)?;
        }
        
        // Invariant: Total supply unchanged
        assert_eq!(get_total_supply(&state), initial_supply);
    }
}
```

---

## Fuzz Testing

### Input Fuzzing

**Fuzz All Entry Points:**
```rust
#[test]
fn fuzz_transfer() {
    let mut fuzzer = Fuzzer::new();
    
    for _ in 0..10000 {
        // Generate random inputs
        let sender_balance = fuzzer.gen_u64();
        let receiver_balance = fuzzer.gen_u64();
        let amount = fuzzer.gen_u64();
        let proof = fuzzer.gen_bytes(32);
        
        let sender = setup_account_with_balance(sender_balance);
        let receiver = setup_account_with_balance(receiver_balance);
        
        // Execute (should not crash)
        let result = transfer(&sender, &receiver, amount, proof);
        
        // Either succeeds or fails gracefully
        match result {
            Ok(_) => {
                // Verify postconditions
                assert!(amount <= sender_balance);
                assert_eq!(decrypt_balance(&sender), sender_balance - amount);
            }
            Err(e) => {
                // Verify error is expected
                assert!(is_expected_error(e));
            }
        }
    }
}
```

### Differential Fuzzing

**Compare Against Reference:**
```rust
#[test]
fn differential_fuzz_against_reference() {
    let mut fuzzer = Fuzzer::new();
    
    for _ in 0..10000 {
        let sender_balance = fuzzer.gen_u64();
        let amount = fuzzer.gen_u64();
        
        // Reference implementation (simple, verified)
        let reference_result = if amount <= sender_balance {
            Ok(sender_balance - amount)
        } else {
            Err(INSUFFICIENT_BALANCE)
        };
        
        // Actual implementation
        let sender = setup_account_with_balance(sender_balance);
        let receiver = setup_account_with_balance(0);
        let actual_result = transfer(&sender, &receiver, amount, generate_proof())
            .map(|_| decrypt_balance(&sender));
        
        // Results must match
        assert_eq!(reference_result, actual_result);
    }
}
```

---

## Performance Testing

### Load Testing

**Sustained Load:**
```rust
#[test]
fn load_test_sustained_transfers() {
    let users = setup_users(100);
    let duration = Duration::from_secs(60);
    let start = Instant::now();
    
    let mut tx_count = 0;
    let mut total_latency = Duration::ZERO;
    
    while start.elapsed() < duration {
        let sender = choose_random(&users);
        let receiver = choose_random(&users);
        
        let tx_start = Instant::now();
        transfer(&sender, &receiver, 100, generate_proof()).unwrap();
        let tx_latency = tx_start.elapsed();
        
        total_latency += tx_latency;
        tx_count += 1;
    }
    
    let throughput = tx_count as f64 / duration.as_secs_f64();
    let avg_latency = total_latency / tx_count;
    
    println!("Throughput: {:.2} tx/s", throughput);
    println!("Average latency: {:?}", avg_latency);
    
    // Assertions
    assert!(throughput > 10.0, "Throughput too low: {}", throughput);
    assert!(avg_latency < Duration::from_millis(100), "Latency too high");
}
```

### Stress Testing

**Peak Load:**
```rust
#[test]
fn stress_test_burst_traffic() {
    let users = setup_users(1000);
    
    // Burst: 1000 concurrent transfers
    let start = Instant::now();
    
    let threads: Vec<_> = users.chunks(2)
        .map(|pair| {
            let sender = pair[0].clone();
            let receiver = pair[1].clone();
            thread::spawn(move || {
                transfer(&sender, &receiver, 100, generate_proof())
            })
        })
        .collect();
    
    let results: Vec<_> = threads.into_iter()
        .map(|t| t.join().unwrap())
        .collect();
    
    let duration = start.elapsed();
    
    // Verify all succeeded
    assert!(results.iter().all(|r| r.is_ok()));
    
    // Verify completed in reasonable time
    assert!(duration < Duration::from_secs(10), "Burst took too long: {:?}", duration);
}
```

### Gas Benchmarking

**Gas Cost Regression:**
```rust
#[test]
fn benchmark_gas_costs() {
    let gas_results = GasBenchmark::new()
        .benchmark("registration", || {
            confidential_asset::register(&account, proof)
        })
        .benchmark("transfer", || {
            confidential_asset::transfer(&sender, &receiver, 1000, proof)
        })
        .benchmark("withdrawal", || {
            confidential_asset::withdraw(&account, 500, proof)
        })
        .benchmark("normalization", || {
            confidential_asset::normalize(&account, proof)
        })
        .benchmark("key_rotation", || {
            confidential_asset::rotate_key(&account, new_key, proof)
        })
        .run();
    
    // Assert against budgets
    assert!(gas_results["registration"] < 5000);
    assert!(gas_results["transfer"] < 8000);
    assert!(gas_results["withdrawal"] < 7000);
    assert!(gas_results["normalization"] < 6000);
    assert!(gas_results["key_rotation"] < 5500);
    
    // Save baseline for regression detection
    gas_results.save_baseline("gas_baseline.json");
}
```

---

## Security Testing

### Attack Simulation

**Test Against Known Attacks:**
```rust
#[test]
fn security_test_replay_attack() {
    let sender = setup_account_with_balance(1000);
    let receiver = setup_account_with_balance(0);
    
    // Legitimate transfer
    let proof = generate_transfer_proof(&sender, &receiver, 300);
    transfer(&sender, &receiver, 300, proof.clone()).unwrap();
    
    // Attempt replay attack (reuse same proof)
    let replay_result = transfer(&sender, &receiver, 300, proof);
    
    // Should fail
    assert!(replay_result.is_err());
    assert_eq!(replay_result.unwrap_err(), PROOF_REPLAY_DETECTED);
}

#[test]
fn security_test_proof_malleability() {
    let sender = setup_account_with_balance(1000);
    let receiver = setup_account_with_balance(0);
    
    let proof = generate_transfer_proof(&sender, &receiver, 300);
    
    // Modify proof slightly
    let mut malicious_proof = proof.clone();
    malicious_proof.challenge[0] ^= 0x01;  // Flip one bit
    
    // Should fail verification
    let result = transfer(&sender, &receiver, 300, malicious_proof);
    assert!(result.is_err());
    assert_eq!(result.unwrap_err(), INVALID_PROOF);
}
```

### Privilege Escalation Testing

**Test Access Control:**
```rust
#[test]
fn security_test_unauthorized_withdrawal() {
    let alice = setup_account_with_balance(1000);
    let bob = create_account();
    
    // Bob tries to withdraw Alice's balance
    let malicious_proof = generate_withdrawal_proof(&bob, 500);  // Bob's signature
    let result = withdraw_from_account(&alice, 500, malicious_proof);
    
    // Should fail: wrong signature
    assert!(result.is_err());
    assert_eq!(result.unwrap_err(), UNAUTHORIZED);
}
```

---

## Regression Testing

### Test Suite Versioning

**Maintain Test History:**
```rust
// tests/regression/v1_0_0/
mod registration_tests { ... }
mod transfer_tests { ... }

// tests/regression/v1_1_0/
mod batch_transfer_tests { ... }  // New in v1.1.0

// tests/regression/v2_0_0/
mod updated_proof_format_tests { ... }  // Breaking change
```

### Golden Tests

**Compare Against Known Good Outputs:**
```rust
#[test]
fn golden_test_transfer_output() {
    let sender = setup_account_with_balance(1000);
    let receiver = setup_account_with_balance(0);
    
    let result = transfer(&sender, &receiver, 300, proof).unwrap();
    
    // Compare against golden output
    let golden = load_golden_output("transfer_300.json");
    assert_eq!(result, golden);
}
```

---

## Test Coverage Metrics

### Code Coverage

**Measure Coverage:**
```bash
# Run tests with coverage
cargo tarpaulin --out Html --output-dir coverage/

# Check coverage percentage
coverage_pct=$(cargo tarpaulin --out Stdout | grep "%" | awk '{print $1}')

if (( $(echo "$coverage_pct < 95" | bc -l) )); then
    echo "❌ Coverage below 95%: $coverage_pct"
    exit 1
fi
```

### Scenario Coverage

**Track Tested Scenarios:**
```python
# coverage_tracker.py

SCENARIOS = {
    'registration': {
        'happy_path': True,
        'duplicate_registration': True,
        'invalid_proof': True,
    },
    'transfer': {
        'basic_transfer': True,
        'insufficient_balance': True,
        'unregistered_receiver': True,
        'zero_amount': True,
        'max_amount': True,
        'self_transfer': False,  # Not yet tested
    },
    # ...
}

def coverage_report():
    total = sum(len(scenarios) for scenarios in SCENARIOS.values())
    covered = sum(sum(scenarios.values()) for scenarios in SCENARIOS.values())
    
    pct = covered / total * 100
    print(f"Scenario coverage: {covered}/{total} ({pct:.1f}%)")
    
    # List uncovered
    for protocol, scenarios in SCENARIOS.items():
        uncovered = [s for s, covered in scenarios.items() if not covered]
        if uncovered:
            print(f"{protocol}: Missing tests for {uncovered}")
```

---

## Continuous Testing Infrastructure

### CI/CD Integration

**Test Pipeline:**
```yaml
# .github/workflows/test-suite.yaml

name: Test Suite

on: [push, pull_request]

jobs:
  unit-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Run unit tests
        run: cargo test --package confidential-asset --lib
  
  integration-tests:
    runs-on: ubuntu-latest
    needs: unit-tests
    steps:
      - name: Run integration tests
        run: cargo test --package integration-tests
  
  e2e-tests:
    runs-on: ubuntu-latest
    needs: integration-tests
    steps:
      - name: Run E2E tests
        run: cargo test --package e2e-tests
  
  performance-tests:
    runs-on: ubuntu-latest
    needs: unit-tests
    steps:
      - name: Run performance benchmarks
        run: cargo bench --package benchmarks
  
  security-tests:
    runs-on: ubuntu-latest
    steps:
      - name: Run security test suite
        run: cargo test --package security-tests
  
  coverage:
    runs-on: ubuntu-latest
    steps:
      - name: Generate coverage report
        run: cargo tarpaulin --out Xml
      - name: Upload to codecov
        uses: codecov/codecov-action@v2
```

---

## Cross-References

### Related Documentation

**Verification:**
- `INTEGRATION_TESTING_AND_CROSS_LAYER_VALIDATION_GUIDE.md` - Layer integration
- `DIFFTEST_CORPUS_EXPANSION_STRATEGY_GUIDE.md` - Difftest testing
- `REGRESSION_PREVENTION_AND_CONTINUOUS_VERIFICATION_GUIDE.md` - Regression testing

**Quality:**
- `CI_CD_PIPELINE_COMPREHENSIVE_GUIDE.md` - Automation
- `GAS_OPTIMIZATION_AND_COST_ANALYSIS.md` - Performance testing
- `SECURITY_REVIEW_AND_THREAT_MODEL_GUIDE.md` - Security testing

---

## Maintenance

### Document Ownership

- **Author**: QA team, Testing engineers
- **Reviewers**: Verification team, Security team
- **Approver**: Tech lead
- **Last Review**: 2026-04-22
- **Next Review**: 2026-07-22 (quarterly)

---

**End of Guide**

Total pages: ~36 (~30K characters)
