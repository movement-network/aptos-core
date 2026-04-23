# Verification Best Practices Compendium

**Document Status**: Production-Ready  
**Last Updated**: 2026-04-23  
**Target Audience**: All verification contributors, team leads, educators  
**Scope**: Consolidated best practices from 2+ years of CA verification

---

## Table of Contents

1. [Overview](#overview)
2. [Proof Development Best Practices](#proof-development-best-practices)
3. [Specification Best Practices](#specification-best-practices)
4. [Testing Best Practices](#testing-best-practices)
5. [Code Review Best Practices](#code-review-best-practices)
6. [Documentation Best Practices](#documentation-best-practices)
7. [Performance Best Practices](#performance-best-practices)
8. [Security Best Practices](#security-best-practices)
9. [Team Collaboration Best Practices](#team-collaboration-best-practices)
10. [Maintenance Best Practices](#maintenance-best-practices)
11. [Common Mistakes and How to Avoid Them](#common-mistakes-and-how-to-avoid-them)
12. [Quick Reference Checklist](#quick-reference-checklist)
13. [Cross-References](#cross-references)

---

## Overview

### Purpose

This compendium distills best practices from 2+ years of Confidential Assets formal verification: 47 theorems, 312 lemmas, 23 axioms, 90% MSL coverage, 100% Difftest coverage. Learn from hard-won lessons, avoid common pitfalls, adopt proven patterns.

### How to Use This Guide

**For beginners**: Read sequentially, complete each section's checklist  
**For experienced**: Use as reference, search for specific practices  
**For reviewers**: Use checklists during code review  
**For leads**: Share relevant sections with team during onboarding

### Practice Categories

**Must-do** (⭐⭐⭐): Critical for correctness/soundness  
**Should-do** (⭐⭐): Significantly improves quality  
**Nice-to-have** (⭐): Good practice, not essential

---

## Proof Development Best Practices

### ⭐⭐⭐ Always Complete Proofs (No Sorry)

**Why**: `sorry` admits anything (unsound), `sorry` in production is security vulnerability

**How**:
```lean
-- ❌ BAD
theorem transfer_correct : ... := by
  sorry  -- TODO: Finish later

-- ✅ GOOD
theorem transfer_correct : ... := by
  intro st args
  cases verify_proof args.proof with
  | true => exact transfer_valid_proof st args
  | false => exact transfer_invalid_proof st args
```

**Exception**: Temporary `sorry` during development OK, but:
- Mark with TODO comment
- Create GitHub issue
- Never merge to main with `sorry`

### ⭐⭐⭐ State Theorem Precisely

**Why**: Imprecise theorem may not capture intended property

**How**:
```lean
-- ❌ BAD (too weak)
theorem transfer_modifies_state (st : State) :
  eval_transfer st args ≠ st  -- Only says state changed, not how

-- ✅ GOOD (precise)
theorem transfer_balance_conservation (st : State) (args : TransferArgs) :
  eval_transfer st args = .success st' →
  st'.sender_balance + st'.receiver_balance = 
  st.sender_balance + st.receiver_balance
```

**Checklist**:
- [ ] Theorem statement matches security claim
- [ ] All preconditions necessary and sufficient
- [ ] Postcondition precisely captures property
- [ ] No over-generalization (theorem not stronger than needed)

### ⭐⭐ Extract Reusable Lemmas

**Why**: DRY (Don't Repeat Yourself), better maintainability, faster builds

**How**:
```lean
-- ❌ BAD (duplicated proof pattern)
theorem transfer_case1 : ... := by
  -- 20 lines
  cases sender_balance with
  | some b => ...
  | none => ...

theorem transfer_case2 : ... := by
  -- Same 20 lines
  cases sender_balance with
  | some b => ...
  | none => ...

-- ✅ GOOD (extracted lemma)
lemma balance_case_analysis (h : condition) : ... := by
  cases sender_balance with
  | some b => ...
  | none => ...

theorem transfer_case1 : ... := by exact balance_case_analysis case1_condition
theorem transfer_case2 : ... := by exact balance_case_analysis case2_condition
```

**When to extract**:
- Pattern used ≥3 times
- Proof block >20 lines
- Common pattern (e.g., balance arithmetic, proof verification)

### ⭐⭐ Start Simple, Generalize Later

**Why**: Easier to prove specific case, generalization comes free

**How**:
```lean
-- Step 1: Prove simple case
theorem transfer_happy_path (st : State) (args : TransferArgs)
    (h : valid_conditions st args) :
  eval_transfer st args = .success (expected_state st args) := by
  -- 10 lines (easy to prove)

-- Step 2: Handle abort cases
theorem transfer_with_aborts (st : State) (args : TransferArgs) :
  eval_transfer st args = 
    if valid_conditions st args then
      .success (expected_state st args)
    else
      .aborted (error_code st args) := by
  by_cases h : valid_conditions st args
  · exact transfer_happy_path st args h  -- Reuse!
  · exact transfer_abort_cases st args h  -- Only prove abort logic
```

### ⭐ Use Descriptive Names

**Why**: Self-documenting code, easier to understand/review

**How**:
```lean
-- ❌ BAD
lemma l1 : x + y = y + x := by omega
theorem t1 : f x = g x := by exact l1

-- ✅ GOOD
lemma balance_add_commutative : 
  sender_balance + receiver_balance = receiver_balance + sender_balance := by
  omega

theorem transfer_symmetric :
  eval_transfer sender receiver amount = 
  inverse_eval_transfer receiver sender amount := by
  exact balance_add_commutative
```

**Naming conventions**:
- Lemmas: `noun_verb` (e.g., `balance_add_zero`)
- Theorems: `subject_property` (e.g., `transfer_balance_conservation`)
- Hypotheses: `h`, `h1`, `h2` or descriptive (`hsufficient`, `hvalid`)

---

## Specification Best Practices

### ⭐⭐⭐ Specify All Abort Paths

**Why**: Missing abort spec = incomplete verification

**How**:
```move
// ❌ BAD (missing abort condition)
spec transfer {
  aborts_if !exists<ConfidentialBalance>(sender);
  aborts_if !verify_proof(proof);
  // Missing: Insufficient balance abort!
}

// ✅ GOOD (complete)
spec transfer {
  aborts_if !exists<ConfidentialBalance>(sender) with E_NOT_REGISTERED;
  aborts_if !verify_proof(proof) with E_INVALID_PROOF;
  aborts_if sender_balance < amount with E_INSUFFICIENT_BALANCE;
}
```

**Checklist**:
- [ ] Every `assert!` has corresponding `aborts_if`
- [ ] All error constants appear in specs
- [ ] Pragma `aborts_if_is_strict` enabled (enforces completeness)

### ⭐⭐⭐ Specify State Mutations Completely

**Why**: Incomplete postcondition misses critical properties

**How**:
```move
// ❌ BAD (incomplete postcondition)
spec transfer {
  ensures sender_balance_post = sender_balance_pre - amount;
  // Missing: Receiver balance!
}

// ✅ GOOD (complete)
spec transfer {
  ensures sender_balance_post = sender_balance_pre - amount;
  ensures receiver_balance_post = receiver_balance_pre + amount;
  ensures sender_balance_post.len() == sender_balance_pre.len();  // Length preserved
  ensures receiver_balance_post.len() == receiver_balance_pre.len();
}
```

**Completeness criteria**:
- All modified resources have postconditions
- Balance conservation properties stated
- Invariants preserved (e.g., vector lengths)
- Events emitted (if applicable)

### ⭐⭐ Use Spec Helpers for Clarity

**Why**: Complex specs hard to read, helpers provide abstraction

**How**:
```move
// ❌ BAD (complex inline spec)
spec transfer {
  ensures len(global<ConfidentialBalance>(sender).balance) ==
          len(old(global<ConfidentialBalance>(sender).balance));
}

// ✅ GOOD (spec helper)
spec module {
  fun balance_length(addr: address): u64 {
    len(global<ConfidentialBalance>(addr).balance)
  }
}

spec transfer {
  ensures balance_length(sender) == old(balance_length(sender));
}
```

**When to use helpers**:
- Expression appears ≥3 times
- Complex nested property
- Abstraction improves clarity

### ⭐ Add Spec Comments

**Why**: Explain non-obvious specs, aid reviewers

**How**:
```move
spec transfer {
  // Precondition: Both sender and receiver must be registered
  requires exists<ConfidentialBalance>(sender);
  requires exists<ConfidentialBalance>(receiver);
  
  // Balance conservation: Total balance unchanged
  ensures sender_balance_post + receiver_balance_post ==
          sender_balance_pre + receiver_balance_pre;
  
  // Privacy: Balance lengths preserved (ciphertext size unchanged)
  ensures balance_length(sender) == old(balance_length(sender));
}
```

---

## Testing Best Practices

### ⭐⭐⭐ Test Happy Path and All Abort Paths

**Why**: Spec may be correct for happy path but miss abort cases

**How**:
```rust
// ✅ GOOD (complete test coverage)
#[test]
fn test_transfer_success() {
    // Happy path: Valid proof, sufficient balance
    let result = execute_transfer(valid_state, valid_args);
    assert_eq!(result.status, Success);
}

#[test]
#[should_panic(expected = "E_NOT_REGISTERED")]
fn test_transfer_sender_not_registered() {
    // Abort path 1: Sender not registered
    let result = execute_transfer(unregistered_sender_state, valid_args);
}

#[test]
#[should_panic(expected = "E_INVALID_PROOF")]
fn test_transfer_invalid_proof() {
    // Abort path 2: Invalid proof
    let args = TransferArgs { proof: invalid_proof(), ... };
    let result = execute_transfer(valid_state, args);
}

#[test]
#[should_panic(expected = "E_INSUFFICIENT_BALANCE")]
fn test_transfer_insufficient_balance() {
    // Abort path 3: Insufficient balance
    let state = State { sender_balance: 100, ... };
    let args = TransferArgs { amount: 200, ... };
    let result = execute_transfer(state, args);
}
```

**Coverage target**: 100% of abort conditions tested

### ⭐⭐⭐ Use Property-Based Testing for Edge Cases

**Why**: Manual tests miss edge cases, PBT explores input space

**How**:
```rust
// ✅ GOOD (property-based testing)
proptest! {
    #![proptest_config(ProptestConfig::with_cases(1000))]
    
    #[test]
    fn prop_transfer_never_inflates_balance(
        sender_balance in 0..u64::MAX,
        receiver_balance in 0..u64::MAX,
        amount in 0..u64::MAX,
    ) {
        let initial_total = sender_balance.saturating_add(receiver_balance);
        
        let result = execute_transfer(sender_balance, receiver_balance, amount);
        
        let final_total = result.sender_balance.saturating_add(result.receiver_balance);
        
        // Property: Total never increases
        prop_assert!(final_total <= initial_total);
    }
}
```

**Coverage target**: ≥1000 cases per critical property

### ⭐⭐ Test Cross-Stack Consistency

**Why**: Lean proofs may not match VM execution (transcription errors)

**How**:
```rust
#[test]
fn test_transfer_lean_vm_consistency() {
    // Load Lean symbolic evaluation
    let lean_result = load_lean_eval("transfer", &test_state, &test_args);
    
    // Execute in Move VM
    let vm_result = execute_move_vm("transfer", &test_state, &test_args);
    
    // Must match
    assert_eq!(lean_result.status, vm_result.status);
    assert_eq!(lean_result.final_state, vm_result.final_state);
}
```

**Coverage target**: 100% of Lean symbolic evaluations validated

### ⭐ Use Descriptive Test Names

**Why**: Failed test name should indicate what broke

**How**:
```rust
// ❌ BAD
#[test]
fn test1() { ... }
#[test]
fn test2() { ... }

// ✅ GOOD
#[test]
fn test_transfer_success_with_valid_proof() { ... }

#[test]
fn test_transfer_aborts_when_sender_not_registered() { ... }

#[test]
fn test_transfer_aborts_when_balance_insufficient() { ... }
```

**Naming pattern**: `test_<function>_<scenario>_<expected_result>`

---

## Code Review Best Practices

### ⭐⭐⭐ Verify Theorem Statement Before Proof

**Why**: Correct proof of wrong theorem = useless

**How** (reviewer checklist):
- [ ] Read theorem statement carefully
- [ ] Compare to security claim (does theorem capture intended property?)
- [ ] Check preconditions (necessary and sufficient?)
- [ ] Check postcondition (precise enough?)
- [ ] Ask: "If this theorem is true, does it imply the security property?"

**Example review comment**:
> This theorem only proves sender balance decreases, but doesn't constrain receiver balance. Attacker could inflate receiver balance! Please add postcondition: `receiver_balance_post = receiver_balance_pre + amount`

### ⭐⭐⭐ Check for New Axioms

**Why**: Every axiom is trust assumption (reduces verification assurance)

**How**:
```bash
# Run axiom diff in CI
./scripts/check_axioms.sh --diff

# Review output:
# +1 axiom added: schnorr_verify_complete
# Reviewer: Check justification!
```

**Reviewer checklist** (for new axioms):
- [ ] Axiom has docstring with justification
- [ ] Justification references cryptographic assumption or framework property
- [ ] Axiom is minimal (not over-specific)
- [ ] Reduction plan documented (in AXIOM_REDUCTION guide)
- [ ] Crypto expert reviewed (if cryptographic axiom)

### ⭐⭐ Verify Cross-Stack Consistency

**Why**: Lean proof may not match MSL spec (different postconditions)

**How**:
```bash
# Run cross-stack validation
./audit/reconcile_all.sh

# Check output:
# - Abort code alignment: PASS
# - Function signatures: PASS
# - Postcondition consistency: FAIL (mismatch found)

# Reviewer: Investigate mismatch
```

**Reviewer checklist**:
- [ ] Abort codes match across Lean/MSL/Move
- [ ] Function signatures match
- [ ] Postconditions equivalent (Lean theorem ↔ MSL ensures)

### ⭐ Look for Proof Anti-Patterns

**Why**: Anti-patterns indicate maintainability issues

**Red flags**:
- `sorry` in proof (unsound)
- Proof >100 lines (extract lemmas)
- Proof >5s build time (optimize)
- Duplicated proof pattern (extract lemma)
- Magic number in proof (use named constant)

**Example review comment**:
> This proof is 150 lines and takes 8s to build. Please extract lemmas for case analysis (lines 45-75) and balance arithmetic (lines 80-120). Target: <50 lines, <3s build time.

---

## Documentation Best Practices

### ⭐⭐⭐ Document All Axioms

**Why**: Undocumented axiom = unjustified trust assumption

**How**:
```lean
// ❌ BAD
axiom schnorr_verify : ...

// ✅ GOOD
/-- Schnorr verification oracle correctness.
    
    Assumes: Discrete Logarithm Problem (DLP) is hard in Ristretto255 group
    Security level: 128-bit (computational security)
    Trusted component: Native function `schnorr_verify` matches academic Schnorr protocol
    
    Justification: Schnorr signatures have proven security reduction to DLP.
    Standard cryptographic assumption (used in Bitcoin Taproot, etc.)
    
    Reduction plan: Phase 2 (6-12 months)
    - Verify native implementation against cryptographic library (fiat-crypto)
    - Estimated effort: 3 months (cryptographic expert)
    
    Reviewed by: Bob (crypto expert), 2026-04-15
-/
axiom schnorr_verify_soundness : 
  schnorr_verify pk msg sig = true →
  ∃ sk, pk = sk • G
```

**Documentation requirements**:
- Security assumption (DLP, CDH, ROM, etc.)
- Trusted component (native function, framework, library)
- Justification (why is this assumption reasonable?)
- Reduction plan (how will axiom be eliminated?)
- Reviewer (who reviewed this axiom?)

### ⭐⭐ Keep Examples Up-to-Date

**Why**: Outdated examples mislead readers

**How**:
```bash
# Automated example testing
./scripts/test_doc_examples.sh

# Extracts code from guides, compiles
# Fails if examples outdated
```

**Quarterly maintenance**:
- [ ] Run all code examples
- [ ] Update output/results if changed
- [ ] Fix broken examples
- [ ] Update "Last Updated" date

### ⭐ Use Consistent Terminology

**Why**: Consistency aids understanding, reduces confusion

**Standard terms** (CA verification):
- **Proof** (cryptographic): Schnorr proof, Bulletproofs range proof
- **Proof** (mathematical): Lean theorem proof
- **Spec**: MSL specification
- **Theorem**: Lean theorem statement
- **Lemma**: Lean helper theorem
- **Axiom**: Unproven assumption
- **Oracle**: Abstraction of native function (e.g., Schnorr oracle)

**Avoid**:
- Mixing "proof" meanings (say "Schnorr signature" if cryptographic)
- Inconsistent casing (use PascalCase for types, snake_case for functions)

---

## Performance Best Practices

### ⭐⭐⭐ Keep Build Time <3s Per Protocol

**Why**: Slow builds hurt productivity (wait time compounds)

**How**:
```bash
# Measure build time
time lake build MovementFormal.Experimental.ConfidentialAsset.Transfer.EvalEquiv

# If >3s: Profile
lake build --profile | grep "elaboration" | sort -k2 -rn

# Optimize hot spots (see ADVANCED_PROOF_TECHNIQUES guide)
```

**Target**: <3s per protocol, <15s total

### ⭐⭐ Use Targeted Simplification

**Why**: `simp [*]` (simplify all) is slow (processes every lemma)

**How**:
```lean
-- ❌ BAD (slow)
theorem slow : complex_expression = result := by
  simp [*]  -- Tries every simp lemma (100+)

-- ✅ GOOD (fast)
theorem fast : complex_expression = result := by
  simp only [balance_add_zero, balance_sub_self]  -- Only relevant lemmas
```

**Guideline**: Use `simp only [...]` with specific lemmas

### ⭐ Cache Intermediate Results

**Why**: Recomputing expensive terms wastes time

**How**:
```lean
-- ❌ BAD (recomputes expensive_function 3 times)
theorem slow : 
  expensive_function x + expensive_function x = 2 * expensive_function x := by
  rw [expensive_function_def, expensive_function_def, expensive_function_def]

-- ✅ GOOD (compute once)
theorem fast :
  expensive_function x + expensive_function x = 2 * expensive_function x := by
  let y := expensive_function x
  show y + y = 2 * y
  ring
```

---

## Security Best Practices

### ⭐⭐⭐ Never Skip Security Review for Axioms

**Why**: Unsound axiom = security vulnerability

**How**:
- [ ] Crypto expert reviews all cryptographic axioms
- [ ] Framework expert reviews all framework axioms
- [ ] Security lead approves all new axioms
- [ ] Axioms documented in AXIOM_INVENTORY.md

**Example** (bad axiom caught in review):
> **Reviewer (crypto expert)**: This axiom states Bulletproofs *completeness* but not *soundness*. Completeness alone allows adversary to create proof for any value! Must add soundness axiom.

### ⭐⭐⭐ Test Negative Cases (Attack Scenarios)

**Why**: Specs may allow unintended behavior (security holes)

**How**:
```rust
#[test]
fn test_attack_balance_inflation() {
    let attacker = create_account();
    
    // Attempt 1: Transfer more than balance
    let result = execute_transfer(balance: 100, amount: 1000);
    assert_eq!(result.status, Aborted(E_INSUFFICIENT_BALANCE));
    
    // Attempt 2: Use fake proof
    let fake_proof = generate_invalid_proof();
    let result = execute_transfer_with_proof(fake_proof);
    assert_eq!(result.status, Aborted(E_INVALID_PROOF));
    
    // Attempt 3: Replay valid proof
    let valid_proof = execute_once_with_proof(valid_proof);
    let result = execute_transfer_with_proof(valid_proof);  // Replay
    assert!(result.is_aborted());  // Should fail (proof used or balance insufficient)
}
```

**Attack scenarios to test**:
- Balance inflation (create value from nothing)
- Unauthorized transfer (transfer without signature)
- Proof forgery (invalid proof accepted)
- Replay attack (reuse old proof)
- Front-running (observe and copy transaction)

### ⭐ Regularly Review Axiom Count

**Why**: Axiom count increasing = verification weakening

**How**:
```bash
# Monthly check
./scripts/check_axioms.sh --count

# Alert if increased
CURRENT_COUNT=$(./scripts/check_axioms.sh --count)
if [ $CURRENT_COUNT -gt 23 ]; then
    echo "⚠️  Axiom count increased to $CURRENT_COUNT (was 23)"
    echo "Action: Review new axioms, prioritize elimination"
fi
```

**Target**: Decrease axiom count over time (23 → 10 by 2027)

---

## Team Collaboration Best Practices

### ⭐⭐⭐ Review Within 48 Hours

**Why**: Long review delays block team, slow velocity

**How**:
- Reviewer allocates 2h/day for PR reviews (before own work)
- Critical PRs (security fixes) reviewed <4h
- Automated reminder after 24h (GitHub Actions bot)

**SLA targets**:
- Lean proofs: <48h first review
- MSL specs: <24h first review
- Difftest: <24h first review
- Hotfixes: <4h review + merge

### ⭐⭐ Use Three-Reviewer Rule for Critical Proofs

**Why**: Critical proofs require multiple perspectives (Lean + crypto + protocol)

**Critical proofs** (require 3 reviewers):
- Main eval equivalence theorems (transfer, withdrawal, etc.)
- Balance conservation proofs
- Cryptographic property proofs (completeness, soundness, SHVZK)
- Axiom additions

**Reviewer assignments**:
1. Lean expert: Proof correctness, tactics, performance
2. Crypto expert: Cryptographic properties, oracle specs
3. Protocol expert: Business logic, security claims

### ⭐ Share Knowledge via Weekly Demos

**Why**: Knowledge sharing prevents silos, enables team growth

**Format** (1 hour, Wednesday 2pm):
- Rotating presenter (each team member presents monthly)
- Topic: Recent proof technique, debugging war story, tool discovery
- Recording: Archived for future reference

**Example topics**:
- "How I optimized withdrawal proof from 45s to 2.1s"
- "Debugging SMT timeouts in Move Prover"
- "Property-based testing for cryptographic protocols"

---

## Maintenance Best Practices

### ⭐⭐⭐ Test Dependency Updates in Branch

**Why**: Dependency updates can break proofs (API changes)

**How**:
```bash
# ❌ BAD (update directly in main)
lake update mathlib
git commit -m "Update Mathlib"
git push origin main
# Breaks CI, blocks team!

# ✅ GOOD (test in branch first)
git checkout -b update-mathlib-v4.15.0
lake update mathlib@v4.15.0
lake build  # Does it compile?
cargo test --release  # Do tests pass?
# If successful, create PR
# If issues, fix or defer update
```

### ⭐⭐ Eliminate 1-2 Axioms Per Month

**Why**: Continuous axiom reduction is long-term goal

**How**:
- Monthly axiom reduction sprint (1 day allocated)
- Target: Temporary axioms first (easiest to eliminate)
- Track progress in AXIOM_INVENTORY.md

**Roadmap**:
- Q2 2026: 23 → 17 axioms (eliminate framework assumptions)
- Q3 2026: 17 → 12 axioms (verify Ristretto library)
- Q4 2026: 12 → 10 axioms (verify Schnorr protocol)

### ⭐ Document Lessons Learned

**Why**: Preserve knowledge for future team members

**When to document**:
- After difficult debugging session (what was root cause?)
- After performance optimization (what worked?)
- After dependency update (what broke? how fixed?)

**Where to document**:
- Add entry to LESSONS_LEARNED_AND_KNOWLEDGE_TRANSFER_GUIDE.md
- Include: Context, problem, solution, prevention

---

## Common Mistakes and How to Avoid Them

### Mistake 1: Proving Wrong Theorem

**Symptom**: Proof succeeds, but security property still violated

**Example**:
```lean
-- ❌ WRONG THEOREM (doesn't capture balance conservation)
theorem transfer_changes_balance :
  eval_transfer st args ≠ st  -- Only says *something* changed!

-- ✅ RIGHT THEOREM
theorem transfer_balance_conservation :
  eval_transfer st args = .success st' →
  st'.total_balance = st.total_balance  -- Precisely states conservation
```

**Prevention**: Before starting proof, verify theorem statement with team

### Mistake 2: Over-Specified Axioms

**Symptom**: Axiom harder to justify than necessary

**Example**:
```lean
-- ❌ OVER-SPECIFIED (requires internal proof structure)
axiom schnorr_verify_detailed :
  schnorr_verify pk msg sig = true ↔
  sig.response = sig.challenge * sk + sig.nonce ∧  -- Too specific!
  sig.challenge = hash(pk, msg, sig.commitment) ∧
  sig.commitment = sig.nonce • G

-- ✅ MINIMAL (only states soundness property)
axiom schnorr_verify_soundness :
  schnorr_verify pk msg sig = true →
  ∃ sk, pk = sk • G  -- Sufficient for protocol correctness
```

**Prevention**: State weakest axiom that suffices for proof

### Mistake 3: Ignoring Performance

**Symptom**: Proof builds in 45s, CI times out

**Example**:
```lean
-- ❌ SLOW (quadratic elaboration)
theorem slow_proof : ... := by
  rw [lemma1]  -- Processes full term
  rw [lemma2]  -- Processes full term again
  -- 50 rewrites = O(n^2) time

-- ✅ FAST (linear elaboration)
theorem fast_proof : ... := by
  conv => lhs; rw [lemma1, lemma2, ...]  -- Composed rewrites
  rfl
```

**Prevention**: Profile builds regularly (`time lake build`), optimize >3s proofs

### Mistake 4: Incomplete Specs

**Symptom**: Spec verifies, but implementation has bugs

**Example**:
```move
// ❌ INCOMPLETE (missing abort condition)
spec transfer {
  ensures sender_balance_post = sender_balance_pre - amount;
  // Missing: What if sender_balance < amount?
}

// ✅ COMPLETE
spec transfer {
  aborts_if sender_balance < amount with E_INSUFFICIENT_BALANCE;
  ensures sender_balance_post = sender_balance_pre - amount;
}
```

**Prevention**: Use `pragma aborts_if_is_strict` (enforces completeness)

### Mistake 5: Copy-Paste Errors

**Symptom**: Proof for wrong function (copied from similar function)

**Example**:
```lean
-- ❌ COPY-PASTE ERROR
theorem withdrawal_correct : 
  eval_transfer st args = ...  -- Oops! Should be eval_withdrawal

-- ✅ CORRECT
theorem withdrawal_correct :
  eval_withdrawal st args = ...
```

**Prevention**: Code review catches this, but also: use descriptive names, avoid generic lemmas

---

## Quick Reference Checklist

### New Proof Checklist

Before opening PR:
- [ ] Proof complete (no `sorry`)
- [ ] Theorem statement precise (matches security claim)
- [ ] Build time <3s (profile if needed)
- [ ] No new axioms (or justified + documented if added)
- [ ] Reusable lemmas extracted (if proof >50 lines)
- [ ] Tests validate theorem (Difftest or unit tests)

### New Spec Checklist

Before opening PR:
- [ ] All abort paths specified (pragma `aborts_if_is_strict`)
- [ ] All postconditions complete (all state mutations)
- [ ] Spec verifies (Move Prover passes)
- [ ] Cross-stack consistency (matches Lean theorem)
- [ ] Tests cover happy path + all abort paths

### Code Review Checklist

For reviewer:
- [ ] Theorem statement correct (captures intended property)
- [ ] No new unsound axioms (or justified if added)
- [ ] Cross-stack consistency maintained (abort codes, postconditions)
- [ ] Performance acceptable (build time, test time)
- [ ] Documentation complete (axioms, non-obvious steps)

### Release Checklist

Before production:
- [ ] All release gates passed (verification, quality, audit, reproducible, compliance)
- [ ] Axiom count ≤25
- [ ] Coverage: Lean 100%, MSL ≥90%, Difftest 100%
- [ ] CI passing for 1 week (100% success rate)
- [ ] Security sign-off (3 reviewers: Lean + crypto + protocol)

---

## Cross-References

**Guides referenced**:
- ADVANCED_PROOF_TECHNIQUES_AND_PATTERNS_GUIDE.md: Performance optimization
- PROOF_REVIEW_AND_QUALITY_ASSURANCE_COMPREHENSIVE_GUIDE.md: Review checklists
- AXIOM_REDUCTION_STRATEGIES_AND_TECHNIQUES_GUIDE.md: Axiom elimination roadmap
- COMPREHENSIVE_TESTING_STRATEGY_AND_VALIDATION_GUIDE.md: Testing patterns
- LESSONS_LEARNED_AND_KNOWLEDGE_TRANSFER_GUIDE.md: Historical lessons

**Scripts**:
- `scripts/check_axioms.sh`: Axiom inventory and diffs
- `scripts/test_doc_examples.sh`: Documentation testing
- `audit/reconcile_all.sh`: Cross-stack validation

---

## Summary

This compendium provides consolidated best practices:

1. **Proof development**: Complete proofs (no sorry), precise theorems, extract lemmas, start simple, descriptive names
2. **Specification**: All abort paths, complete postconditions, spec helpers, comments
3. **Testing**: Happy path + all aborts, property-based (≥1000 cases), cross-stack consistency, descriptive names
4. **Code review**: Verify theorem statement, check axioms, cross-stack validation, look for anti-patterns
5. **Documentation**: Document axioms, keep examples current, consistent terminology
6. **Performance**: <3s per protocol, targeted simp, cache intermediate results
7. **Security**: Security review for axioms, test attack scenarios, monitor axiom count
8. **Collaboration**: <48h review, 3-reviewer rule for critical proofs, weekly knowledge sharing
9. **Maintenance**: Test updates in branch, eliminate 1-2 axioms/month, document lessons
10. **Common mistakes**: Wrong theorem (statement doesn't capture property), over-specified axioms, ignoring performance, incomplete specs, copy-paste errors

**Key principle**: Practices prioritized by importance (⭐⭐⭐ = must-do for correctness/security). Checklists enable systematic application across team.

For advanced techniques, see ADVANCED_PROOF_TECHNIQUES guide. For review processes, see PROOF_REVIEW guide. For axiom elimination, see AXIOM_REDUCTION guide.
