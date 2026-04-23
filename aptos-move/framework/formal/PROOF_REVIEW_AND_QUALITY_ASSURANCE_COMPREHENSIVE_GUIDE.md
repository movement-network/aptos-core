# Proof Review and Quality Assurance: Comprehensive Guide

**Document Status**: Production-Ready  
**Last Updated**: 2026-04-22  
**Target Audience**: Proof reviewers, verification engineers, QA specialists  
**Scope**: Proof correctness, soundness verification, review processes, quality metrics

---

## Table of Contents

1. [Overview](#overview)
2. [Proof Soundness Fundamentals](#proof-soundness-fundamentals)
3. [Review Checklist for Lean Proofs](#review-checklist-for-lean-proofs)
4. [Review Checklist for MSL Specifications](#review-checklist-for-msl-specifications)
5. [Review Checklist for Difftest Suites](#review-checklist-for-difftest-suites)
6. [Axiom Review Process](#axiom-review-process)
7. [Oracle Specification Review](#oracle-specification-review)
8. [Cross-Stack Consistency Review](#cross-stack-consistency-review)
9. [Performance Quality Gates](#performance-quality-gates)
10. [Automated Quality Checks](#automated-quality-checks)
11. [Manual Review Best Practices](#manual-review-best-practices)
12. [Security-Critical Proof Review](#security-critical-proof-review)
13. [Common Proof Anti-Patterns](#common-proof-anti-patterns)
14. [Quality Metrics and Tracking](#quality-metrics-and-tracking)
15. [Case Studies](#case-studies)
16. [Troubleshooting](#troubleshooting)
17. [Cross-References](#cross-references)

---

## Overview

### Purpose

Quality assurance for formal verification requires different techniques than traditional software QA. This guide provides systematic processes for reviewing proofs, specifications, and tests to ensure soundness, completeness, and maintainability.

### Quality Dimensions

**Soundness**: Proof actually establishes claimed property (no logical errors, axioms justified)  
**Completeness**: All required properties proven (no gaps in verification coverage)  
**Performance**: Proofs build quickly (<3s per protocol), don't slow CI  
**Maintainability**: Proofs understandable, modular, well-documented  
**Consistency**: Cross-stack alignment (Lean ↔ MSL ↔ Difftest)

### Review Philosophy

1. **Trust but verify**: Lean checker verifies proof correctness, but reviewers verify *what* is proven
2. **Defense in depth**: Multiple review layers (automated CI + peer review + security review)
3. **Axioms are debt**: Every axiom is technical debt requiring justification and reduction plan
4. **Cross-stack validation**: Lean proof alone insufficient, must match MSL specs and Difftest behavior

---

## Proof Soundness Fundamentals

### What Makes a Proof Sound?

**Formally**: A proof is sound if its conclusion follows from premises via valid logical inference rules.

**Practically** (for CA verification):
1. **Axioms are justified**: All axioms represent trusted assumptions (DLP hardness, correct framework implementation)
2. **Theorem statement is correct**: Statement actually captures intended property
3. **Proof has no sorry/admit**: Proof is complete (Lean checker verifies)
4. **Symbolic semantics match reality**: `eval_protocol` accurately models bytecode execution

### Soundness Threats

**Threat 1: Incorrect axiom** (most serious)
```lean
-- UNSOUND: Axiom claims false property
axiom all_numbers_equal : ∀ (x y : Nat), x = y

-- This axiom breaks soundness of entire proof system
-- Can prove anything: 0 = 1, false = true, etc.
```

**Mitigation**:
- Every axiom requires written justification (why is this true?)
- Axioms reviewed by ≥2 domain experts before merge
- Axioms tracked in inventory, reduction plan documented

**Threat 2: Incorrect theorem statement**
```lean
-- UNSOUND: Statement doesn't capture intended property
-- INTENT: Prove balance conservation (sender + receiver balance unchanged)
-- ACTUAL: Only proves sender balance unchanged (receiver balance unconstrained!)
theorem transfer_preserves_sender_balance (st : State) (args : TransferArgs) :
  eval_transfer st args = .success st' →
  sender_balance st' = sender_balance st - args.amount := by
  -- Proof correct, but statement incomplete!
```

**Mitigation**:
- Reviewers read theorem statement carefully, compare to spec doc
- Check postconditions match MSL spec
- Difftest validates property end-to-end

**Threat 3: Symbolic semantics mismatch**
```lean
-- UNSOUND: Symbolic evaluation doesn't match bytecode
def eval_transfer (st : State) (args : TransferArgs) : Result :=
  -- Forgets to check sender balance ≥ amount (bytecode checks this!)
  let st' := st.update_balance sender (balance - amount)
  .success st'

-- Proof valid in Lean, but doesn't reflect actual bytecode behavior
```

**Mitigation**:
- Difftest validates symbolic evaluation matches VM execution
- Cross-stack reconciliation checks state transitions
- Bytecode transcription reviewed line-by-line

### Soundness vs. Completeness

**Sound but incomplete** (acceptable, can improve later):
```lean
-- Proves transfer works for valid inputs, doesn't cover abort cases
theorem transfer_eval_equiv_happy_path (st : State) (args : TransferArgs)
    (h : valid_conditions st args) :
  eval_transfer st args = eval_bytecode st args := by ...
  
-- TODO: Extend to abort cases
```

**Complete but unsound** (NEVER acceptable):
```lean
-- Claims to prove all cases, but uses unjustified axiom
theorem transfer_eval_equiv_all_cases (st : State) (args : TransferArgs) :
  eval_transfer st args = eval_bytecode st args := by
  sorry  -- Proof incomplete!
  
-- OR relies on axiom:
axiom transfer_always_works : ∀ st args, eval_transfer st args = eval_bytecode st args
```

**Mitigation**: Always prefer sound-but-incomplete over complete-but-unsound. Explicitly document coverage gaps.

---

## Review Checklist for Lean Proofs

### High-Level Review (10 minutes)

**Goal**: Quick sanity check before detailed review

- [ ] **Proof compiles**: `lake build` succeeds without errors
- [ ] **No sorry/admit**: Search for `sorry` and `admit` in file (both indicate incomplete proof)
- [ ] **Theorem statement makes sense**: Read statement, compare to protocol spec doc
- [ ] **File organization**: Proofs in correct directory (`ConfidentialAsset/<Protocol>/EvalEquiv.lean`)
- [ ] **Imports reasonable**: No circular dependencies, imports only necessary modules

**Red flags** (stop review, send back to author):
- Proof contains `sorry` or `admit`
- Theorem statement unclear or incorrect
- File imports unnecessary modules (suggests copy-paste errors)

### Axiom Review (15 minutes)

**Goal**: Verify no unsound axioms introduced

**Process**:
1. Run `scripts/check_axioms.sh <file>` to list all axioms used
2. Compare to baseline (`AXIOM_INVENTORY.md`)
3. For each new axiom, check:
   - [ ] **Justification documented**: Axiom has comment explaining why true
   - [ ] **Minimality**: Axiom states weakest necessary property (not over-specific)
   - [ ] **Reduction plan**: AXIOM_REDUCTION_STRATEGIES guide documents elimination path
   - [ ] **Security review**: Crypto expert reviewed (if cryptographic axiom)

**Example axiom review**:
```lean
/-- Schnorr verification oracle correctness.
    Assumes: DLP hardness in Ristretto255 group (128-bit security)
    Trusted: Native function `schnorr_verify` matches academic Schnorr protocol
    Reduction plan: Phase 2 (verify native implementation against cryptographic library)
    Reviewed by: Bob (crypto expert), 2026-04-15
-/
axiom schnorr_verify_correct :
  ∀ (pk : PublicKey) (msg : Message) (sig : Signature),
    schnorr_verify pk msg sig = true ↔
    ∃ (sk : SecretKey), pk = sk • G ∧ valid_schnorr_proof sk msg sig

-- ✓ PASS: Well-documented, justified, reduction plan exists
```

**Common axiom issues**:
- **Missing justification**: Axiom added without comment (WHY is this true?)
- **Over-specification**: Axiom states stronger property than needed
- **No reduction plan**: Axiom intended to be temporary, but no elimination strategy

### Theorem Statement Review (10 minutes)

**Goal**: Verify theorem statement captures intended property

**Checklist**:
- [ ] **Completeness**: Statement covers all cases (happy path + aborts)?
  - If not, explicitly document gap: `-- TODO: Add abort case proofs`
- [ ] **Preconditions sufficient**: Are all preconditions necessary? Are any missing?
- [ ] **Postconditions precise**: Does conclusion match MSL spec postconditions?
- [ ] **Quantifiers correct**: `∀` vs `∃` correct? Quantifier ordering correct?

**Example review** (transfer eval equivalence):
```lean
-- Theorem statement under review:
theorem transfer_eval_equiv (st : State) (args : TransferArgs) :
  eval_transfer st args = eval_bytecode st (transcribe_transfer args) := by ...

-- Review questions:
-- Q1: Does this cover abort cases?
-- A1: YES - both eval_transfer and eval_bytecode return Result (Success | Aborted code)

-- Q2: Are preconditions needed (e.g., valid state)?
-- A2: NO - theorem should hold for ALL states (including invalid), since bytecode handles it

-- Q3: Does conclusion match MSL spec?
-- A3: CHECK MSL spec... Yes, MSL postconditions match eval_transfer semantics

-- ✓ PASS: Statement complete and correct
```

### Proof Structure Review (20 minutes)

**Goal**: Verify proof uses sound reasoning, follows project patterns

**Checklist**:
- [ ] **Follows project architecture**: Uses symbolic state (not frame-chaining)?
- [ ] **PC-chaining pattern**: Bytecode proofs use per-instruction step lemmas?
- [ ] **Lemma extraction**: Complex sub-proofs extracted as separate lemmas?
- [ ] **Proof modularity**: Reusable lemmas in `StepLemmas/`, protocol-specific in `<Protocol>/`?
- [ ] **Tactic usage appropriate**: No brute-force `simp [*]` (too slow), uses targeted `rw`/`simp`?

**Example structure review**:
```lean
-- GOOD: Modular proof with extracted lemmas
theorem transfer_eval_equiv (st : State) (args : TransferArgs) :
  eval_transfer st args = eval_bytecode st (transcribe_transfer args) := by
  unfold eval_transfer eval_bytecode transcribe_transfer
  apply pc_chain_equiv  -- Reusable lemma
  intro pc
  cases pc with
  | load_sender => exact load_sender_step st args  -- Extracted lemma
  | verify_balance => exact verify_balance_step st args
  | update_state => exact update_state_step st args

-- BAD: Monolithic proof (hard to review, hard to maintain)
theorem transfer_eval_equiv (st : State) (args : TransferArgs) :
  eval_transfer st args = eval_bytecode st (transcribe_transfer args) := by
  unfold eval_transfer eval_bytecode transcribe_transfer
  simp [step, State.update, Balance.add, Balance.sub, ...]  -- 50+ simp lemmas
  cases st.check_balance with
  | true => rw [...]; simp [...]; cases ...; ...  -- 100 lines inlined
  | false => rw [...]; simp [...]; ...
```

### Performance Review (5 minutes)

**Goal**: Verify proof doesn't degrade build performance

**Checklist**:
- [ ] **Build time acceptable**: Run `time lake build <file>`, check <3s
- [ ] **No quadratic patterns**: No nested large `rw` chains, no `simp [*]` in loops
- [ ] **CI impact assessed**: Check CI timing before/after PR (in GitHub Actions logs)

**Performance regression example**:
```bash
# Before PR: transfer proof builds in 2.8s
$ time lake build MovementFormal.Experimental.ConfidentialAsset.Transfer.EvalEquiv
real    0m2.847s

# After PR: transfer proof builds in 45s (REGRESSION!)
$ time lake build MovementFormal.Experimental.ConfidentialAsset.Transfer.EvalEquiv
real    0m45.123s

# Action: Send back to author for optimization
```

### Documentation Review (5 minutes)

**Goal**: Verify proof is understandable to future readers

**Checklist**:
- [ ] **Module docstring**: File has top-level comment explaining purpose
- [ ] **Theorem docstrings**: Complex theorems have docstrings explaining property
- [ ] **Non-obvious steps commented**: Tricky tactics have inline comments
- [ ] **Cross-references**: Related proofs/guides referenced in comments

**Example documentation**:
```lean
/- 
# Transfer Protocol Eval Equivalence

Proves that symbolic evaluation of transfer protocol matches bytecode execution.

Main theorem: `transfer_eval_equiv`
Dependencies: `StepLemmas/Calls.lean`, `Native/Transfer.lean`
Related: CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md (Phase 4)
-/

/-- Transfer eval equivalence (happy path + aborts).
    Property: For all states and arguments, symbolic evaluation of transfer
    produces same result as bytecode execution.
    Coverage: 100% (happy path when balance sufficient, abort when insufficient)
-/
theorem transfer_eval_equiv (st : State) (args : TransferArgs) :
  eval_transfer st args = eval_bytecode st (transcribe_transfer args) := by
  unfold eval_transfer eval_bytecode
  apply pc_chain_equiv
  intro pc
  cases pc with
  | load_sender => 
    -- Step 1: Load sender balance from storage
    exact load_sender_step st args
  | verify_balance =>
    -- Step 2: Check sender balance ≥ transfer amount
    -- (Abort with E_INSUFFICIENT_BALANCE if check fails)
    exact verify_balance_step st args
  ...
```

---

## Review Checklist for MSL Specifications

### Specification Completeness Review (15 minutes)

**Goal**: Verify all function behaviors specified

**Checklist**:
- [ ] **All public functions have specs**: No public function without `spec` block
- [ ] **Preconditions complete**: All function requirements stated in `requires` or `aborts_if`
- [ ] **Postconditions complete**: All state mutations stated in `ensures`
- [ ] **Abort conditions complete**: All error paths have `aborts_if` clauses
- [ ] **Frame conditions**: `modifies` clause lists all touched resources

**Example completeness review**:
```move
// Function under review:
public fun transfer(
    sender: &signer,
    receiver: address,
    amount: u64,
    proof: TransferProof
) {
    // 1. Load sender and receiver balances
    let sender_bal = borrow_global_mut<ConfidentialBalance>(signer::address_of(sender));
    let receiver_bal = borrow_global_mut<ConfidentialBalance>(receiver);
    
    // 2. Verify proof
    assert!(confidential_proof::verify_transfer_proof(&proof, ...), E_INVALID_PROOF);
    
    // 3. Update balances
    sender_bal.balance = subtract_balance(sender_bal.balance, amount);
    receiver_bal.balance = add_balance(receiver_bal.balance, amount);
    
    // 4. Emit event
    event::emit(TransferEvent { sender, receiver, amount });
}

spec transfer {
    // Preconditions
    requires exists<ConfidentialBalance>(signer::address_of(sender));  // ✓
    requires exists<ConfidentialBalance>(receiver);  // ✓
    
    // Abort conditions
    aborts_if !exists<ConfidentialBalance>(signer::address_of(sender)) with E_NOT_REGISTERED;  // ✓
    aborts_if !exists<ConfidentialBalance>(receiver) with E_NOT_REGISTERED;  // ✓
    aborts_if !valid_transfer_proof(proof) with E_INVALID_PROOF;  // ✓
    aborts_if sender_balance < amount with E_INSUFFICIENT_BALANCE;  // ✗ MISSING!
    
    // Postconditions
    ensures sender_balance_post = sender_balance_pre - amount;  // ✓
    ensures receiver_balance_post = receiver_balance_pre + amount;  // ✓
    ensures event::was_event_emitted<TransferEvent>(...);  // ✓
    ensures sender_balance_post.len() == sender_balance_pre.len();  // ✓ (length preservation)
    
    // Frame conditions
    modifies global<ConfidentialBalance>(signer::address_of(sender));  // ✓
    modifies global<ConfidentialBalance>(receiver);  // ✓
}

// ✗ INCOMPLETE: Missing aborts_if for insufficient balance
// Action: Add missing abort condition
```

### Specification Correctness Review (15 minutes)

**Goal**: Verify specifications match actual function behavior

**Process**:
1. **Read function implementation** (Move code)
2. **Read specification** (spec block)
3. **Compare**: Does spec accurately describe implementation?

**Common correctness issues**:

**Issue 1: Abort condition doesn't match error path**
```move
// Code aborts with E_INVALID_PROOF (error code 100)
assert!(verify_proof(proof), E_INVALID_PROOF);

// Spec claims different error code (WRONG!)
spec {
  aborts_if !verify_proof(proof) with E_VERIFICATION_FAILED;  // ✗ Wrong error constant
}

// Fix: Match error code exactly
spec {
  aborts_if !verify_proof(proof) with E_INVALID_PROOF;  // ✓ Correct
}
```

**Issue 2: Postcondition too weak**
```move
// Code updates BOTH sender and receiver balances
sender_bal.balance = subtract_balance(sender_bal.balance, amount);
receiver_bal.balance = add_balance(receiver_bal.balance, amount);

// Spec only mentions sender (INCOMPLETE!)
spec {
  ensures sender_balance_post = sender_balance_pre - amount;  // ✓ True but incomplete
}

// Fix: Add receiver postcondition
spec {
  ensures sender_balance_post = sender_balance_pre - amount;  // ✓
  ensures receiver_balance_post = receiver_balance_pre + amount;  // ✓ Complete
}
```

**Issue 3: Precondition too strong**
```move
// Code works for any sender (even if not registered, will abort gracefully)
public fun transfer(sender: &signer, ...) {
    assert!(exists<ConfidentialBalance>(sender_addr), E_NOT_REGISTERED);
    ...
}

// Spec claims sender must be registered (TOO STRONG!)
spec {
  requires exists<ConfidentialBalance>(signer::address_of(sender));  // ✗ Too strong
  // This means function CANNOT be called with unregistered sender
  // But code handles this case (aborts with E_NOT_REGISTERED)
}

// Fix: Remove precondition, add abort condition
spec {
  aborts_if !exists<ConfidentialBalance>(signer::address_of(sender)) 
    with E_NOT_REGISTERED;  // ✓ Correct
}
```

### Specification Solvability Review (10 minutes)

**Goal**: Verify Move Prover can verify spec (no SMT timeouts)

**Process**:
1. Run `aptos move prove` locally
2. Check for timeouts, false positives
3. If timeout: Identify problematic clauses

**Checklist**:
- [ ] **Specs verified by Move Prover**: `aptos move prove` passes (or justified `verify = false`)
- [ ] **No SMT timeouts**: No clause takes >60s to verify
- [ ] **No false positives**: Prover doesn't report spurious errors
- [ ] **Quantifiers have triggers**: All `forall`/`exists` have explicit triggers (if complex)

**Example solvability issue**:
```move
// TIMEOUT: Unbounded quantifier
spec {
  ensures forall i in 0..len(balance):  // ✗ SMT solver explores all indices (slow!)
    balance[i] < MAX_VALUE;
}

// Fix: Add trigger or bound
spec {
  ensures forall i in 0..len(balance) where balance[i] > 0:  // ✓ Bounded by condition
    balance[i] < MAX_VALUE;
}

// OR increase timeout with justification:
spec {
  pragma verify_duration_estimate = 120;  // 2min timeout
  // Justification: Complex postcondition with quantifier, requires extra SMT time
  ensures forall i in 0..len(balance): balance[i] < MAX_VALUE;
}
```

### Cross-Stack Consistency Review (10 minutes)

**Goal**: Verify MSL spec matches Lean proof and Difftest behavior

**Process**:
1. Compare MSL abort codes with Lean symbolic semantics
2. Compare MSL postconditions with Lean theorem conclusions
3. Validate with Difftest (VM execution matches spec)

**Checklist**:
- [ ] **Abort codes match Lean**: `aborts_if ... with CODE` same as Lean `.aborted CODE`
- [ ] **Postconditions match Lean**: `ensures` clauses match Lean theorem postconditions
- [ ] **State transitions match Difftest**: MSL state mutations validated by VM execution tests

**Example cross-stack review**:
```move
// MSL spec
spec transfer {
  aborts_if !valid_proof(proof) with E_INVALID_PROOF;  // Error code 100
  ensures sender_balance_post = sender_balance_pre - amount;
}
```

```lean
-- Lean symbolic semantics
def eval_transfer (st : State) (args : TransferArgs) : Result :=
  if valid_proof args.proof then
    .success (st.update_sender_balance (st.sender_balance - args.amount))
  else
    .aborted 100  -- ✓ Matches MSL error code E_INVALID_PROOF
```

```rust
// Difftest validation
#[test]
fn test_transfer_invalid_proof() {
    let result = vm_execute_transfer(invalid_proof_args);
    assert_eq!(result.status, AbortStatus(100));  // ✓ Matches MSL and Lean
}
```

---

## Review Checklist for Difftest Suites

### Test Coverage Review (15 minutes)

**Goal**: Verify Difftest covers all spec clauses and edge cases

**Checklist**:
- [ ] **Happy path tested**: Valid inputs → success case covered
- [ ] **All abort paths tested**: Each `aborts_if` clause has ≥1 test case
- [ ] **Edge cases tested**: Zero amounts, max values, boundary conditions
- [ ] **Property-based tests**: Corpus size ≥1000 generated cases per protocol
- [ ] **Cross-stack differential**: Tests compare VM execution with Lean symbolic evaluation

**Example coverage review**:
```rust
// MSL spec has 4 abort conditions:
// 1. Sender not registered (E_NOT_REGISTERED = 101)
// 2. Receiver not registered (E_NOT_REGISTERED = 101)
// 3. Invalid proof (E_INVALID_PROOF = 100)
// 4. Insufficient balance (E_INSUFFICIENT_BALANCE = 102)

// Difftest suite review:
#[test] fn test_transfer_success() { ... }  // ✓ Happy path

#[test] fn test_transfer_sender_not_registered() {
    assert_eq!(result.status, AbortStatus(101));  // ✓ Abort path 1
}

#[test] fn test_transfer_receiver_not_registered() {
    assert_eq!(result.status, AbortStatus(101));  // ✓ Abort path 2
}

#[test] fn test_transfer_invalid_proof() {
    assert_eq!(result.status, AbortStatus(100));  // ✓ Abort path 3
}

// ✗ MISSING: No test for insufficient balance (abort path 4)
// Action: Add test case
```

### Oracle Mock Review (15 minutes)

**Goal**: Verify oracle mocks match Lean specifications

**Checklist**:
- [ ] **Oracle behavior matches Lean axioms**: Mock implements same property as Lean oracle
- [ ] **Minimality preserved**: Mock doesn't over-specify (only what Lean axiom states)
- [ ] **Testability**: Mock supports both valid and invalid cases (for abort path testing)
- [ ] **Debugging support**: Mock logs oracle calls for debugging

**Example oracle mock review**:
```lean
-- Lean oracle specification
axiom schnorr_verify_correct :
  ∀ (pk : PublicKey) (msg : Message) (sig : Signature),
    schnorr_verify pk msg sig = true ↔
    ∃ (sk : SecretKey), pk = sk • G ∧ valid_schnorr_proof sk msg sig
```

```rust
// Oracle mock under review
struct SchnorrOracleMock {
    valid_keys: HashMap<PublicKey, SecretKey>,
}

impl SchnorrOracleMock {
    fn verify(&self, pk: &PublicKey, msg: &Message, sig: &Signature) -> bool {
        // ✓ Matches Lean spec: Returns true iff pk corresponds to known secret key
        if let Some(sk) = self.valid_keys.get(pk) {
            // ✓ Checks proof validity (matches Lean spec)
            verify_schnorr_proof(sk, pk, msg, sig)
        } else {
            // ✓ Returns false for unknown keys (matches Lean spec: no sk exists)
            false
        }
    }
}

// ✓ PASS: Mock matches Lean oracle specification
```

### Test Quality Review (10 minutes)

**Goal**: Verify tests are deterministic, fast, maintainable

**Checklist**:
- [ ] **Tests deterministic**: Run 10× locally, always pass (no flakiness)
- [ ] **Tests fast**: Full suite <2s
- [ ] **Tests isolated**: No shared state between tests (each test independent)
- [ ] **Test names descriptive**: `test_transfer_insufficient_balance` better than `test_transfer_2`

**Example test quality issues**:
```rust
// BAD: Flaky test (random seed not fixed)
#[test]
fn test_transfer_random() {
    let mut rng = rand::thread_rng();  // ✗ Non-deterministic seed
    let amount = rng.gen_range(1..1000);
    assert_eq!(vm_execute_transfer(amount).status, Success);
}

// GOOD: Deterministic test
#[test]
fn test_transfer_random() {
    let mut rng = StdRng::seed_from_u64(42);  // ✓ Fixed seed
    let amount = rng.gen_range(1..1000);
    assert_eq!(vm_execute_transfer(amount).status, Success);
}

// BAD: Slow test (large corpus)
#[test]
fn test_transfer_proptest() {
    proptest!(|(amount in 1..u64::MAX, ...)| {  // ✗ Runs 10,000+ cases (slow)
        ...
    });
}

// GOOD: Reasonable corpus size
#[test]
fn test_transfer_proptest() {
    proptest!(ProptestConfig::with_cases(1000), |(amount in 1..u64::MAX, ...)| {  // ✓ 1000 cases
        ...
    });
}
```

---

## Axiom Review Process

### Initial Axiom Review (New Axiom Introduced)

**Trigger**: PR introduces new axiom (detected by `axiom-diff-ca.yaml` workflow)

**Reviewers**: Lean expert + domain expert (crypto expert for crypto axioms, Move expert for VM axioms)

**Review steps**:

1. **Categorize axiom** (see AXIOM_INVENTORY.md):
   - **Cryptographic**: DLP hardness, CDH assumption, ROM, Schnorr/Bulletproofs correctness
   - **Temporary**: Placeholders for future proofs (e.g., framework correctness)
   - **Library**: From external libraries (Mathlib, cryptographic libraries)
   - **VM semantics**: Properties of Move VM behavior

2. **Check justification**:
   - [ ] Axiom has docstring explaining WHY it's true
   - [ ] Security assumptions documented (if cryptographic)
   - [ ] Trusted components identified (if library/VM axiom)

3. **Check minimality**:
   - [ ] Axiom states weakest necessary property (not over-specific)
   - [ ] No stronger alternative formulation possible
   - [ ] Axiom doesn't imply false (sanity check with simple corollaries)

4. **Check reduction plan**:
   - [ ] AXIOM_REDUCTION_STRATEGIES guide includes elimination path
   - [ ] Priority assigned (urgent/high/medium/low)
   - [ ] Estimated effort and timeline documented

**Example axiom review**:
```lean
-- New axiom introduced in PR #1234
axiom bulletproofs_verify_correct :
  ∀ (comm : Commitment) (proof : BulletproofRangeProof),
    bulletproofs_verify comm proof = true →
    ∃ (value : Scalar) (blinding : Scalar),
      comm = commit value blinding ∧ value ∈ [0, 2^64)

-- Review:
-- 1. Category: Cryptographic (Bulletproofs oracle)
-- 2. Justification: ✓ Assumes Bulletproofs cryptographic protocol correct
-- 3. Minimality: ✓ States minimal property (soundness only, not SHVZK)
-- 4. Reduction plan: ✓ Documented in AXIOM_REDUCTION (Phase 3, 17 months, PhD-level)
-- DECISION: APPROVE (well-justified, reduction plan exists)
```

### Quarterly Axiom Audit

**Frequency**: Every 3 months  
**Goal**: Review all axioms, update reduction progress

**Process**:
1. Run `scripts/check_axioms.sh` to generate current axiom inventory
2. Compare to previous quarter (axioms added/eliminated?)
3. For each axiom, update:
   - Reduction progress (any progress toward elimination?)
   - Priority (has priority changed based on new information?)
   - Justification (still accurate? Any new security research?)
4. Publish updated AXIOM_INVENTORY.md

**Metrics tracked**:
- **Total axiom count**: Target <25 (current: 23)
- **Axioms eliminated this quarter**: Target ≥1
- **Axioms added this quarter**: Target 0
- **High-priority axioms**: Target 0 (all high-priority eliminated)

---

## Oracle Specification Review

### Oracle Minimality Review

**Goal**: Verify oracle axioms state minimal necessary properties (avoid over-specification)

**Principle**: Oracle should be as weak as possible while still enabling proof of desired properties.

**Example**:
```lean
-- TOO STRONG: Over-specifies Schnorr verification
axiom schnorr_verify_overspecified :
  ∀ (pk : PublicKey) (msg : Message) (sig : Signature),
    schnorr_verify pk msg sig = true ↔
    ∃ (sk : SecretKey),
      pk = sk • G ∧
      sig.response = sig.challenge * sk + sig.nonce ∧  -- ✗ Over-specifies internal structure
      sig.challenge = hash(pk, msg, sig.commitment) ∧   -- ✗ Over-specifies Fiat-Shamir
      sig.commitment = sig.nonce • G                     -- ✗ Over-specifies commitment

-- MINIMAL: States only soundness property
axiom schnorr_verify_minimal :
  ∀ (pk : PublicKey) (msg : Message) (sig : Signature),
    schnorr_verify pk msg sig = true →
    ∃ (sk : SecretKey), pk = sk • G  -- ✓ Minimal: only proves knowledge of sk

-- Minimality rationale:
-- - We only need soundness (verifier accepts → prover knows sk)
-- - Internal proof structure irrelevant for protocol correctness
-- - Weaker axiom = easier to justify, easier to validate with Difftest
```

**Review checklist**:
- [ ] Oracle states property of inputs/outputs only (not internal computation)
- [ ] Oracle doesn't constrain implementation details (algorithm choice, etc.)
- [ ] Oracle sufficient for protocol proof (removing any clause would break proof)

### Oracle Testability Review

**Goal**: Verify oracle specification is testable via Difftest

**Principle**: Every oracle axiom should have corresponding Difftest mock that validates property.

**Example**:
```lean
-- Oracle axiom (Lean)
axiom schnorr_verify_soundness :
  ∀ (pk : PublicKey) (msg : Message) (sig : Signature),
    schnorr_verify pk msg sig = true →
    ∃ (sk : SecretKey), pk = sk • G
```

```rust
// Corresponding Difftest mock (Rust)
impl SchnorrOracleMock {
    fn verify(&self, pk: &PublicKey, msg: &Message, sig: &Signature) -> bool {
        // Test that mock matches axiom:
        // If mock returns true, then there exists sk such that pk = sk * G
        self.valid_keys.contains_key(pk)  // ✓ Testable: valid_keys maps pk to sk
    }
}

#[test]
fn test_schnorr_oracle_soundness() {
    let mut oracle = SchnorrelMock::new();
    let (pk, sk) = generate_keypair();
    oracle.register_key(pk, sk);
    
    // If verify returns true, pk must have corresponding sk
    let sig = generate_valid_signature(sk, msg);
    assert!(oracle.verify(&pk, &msg, &sig));  // ✓ Soundness holds
    
    // If pk has no sk, verify must return false
    let (unknown_pk, _) = generate_keypair();
    assert!(!oracle.verify(&unknown_pk, &msg, &sig));  // ✓ Soundness validated
}
```

**Review checklist**:
- [ ] Oracle has corresponding Difftest mock
- [ ] Mock implementation makes oracle property testable
- [ ] Difftest includes tests validating oracle property

---

## Cross-Stack Consistency Review

**Goal**: Ensure Lean proofs, MSL specs, and Difftest tests describe same system

### Abort Code Alignment

**Automated**: `scripts/check_abort_alignment.sh`

**Process**:
1. Extract error constants from Move code (`const E_* = ...`)
2. Extract abort codes from MSL specs (`aborts_if ... with CODE`)
3. Extract abort codes from Lean proofs (`.aborted CODE`)
4. Compare all three, report mismatches

**Example**:
```bash
$ ./scripts/check_abort_alignment.sh

Move error constants:
  E_NOT_REGISTERED = 101
  E_INVALID_PROOF = 100
  E_INSUFFICIENT_BALANCE = 102

MSL abort codes:
  101 (E_NOT_REGISTERED)
  100 (E_INVALID_PROOF)
  102 (E_INSUFFICIENT_BALANCE)

Lean abort codes:
  101, 100, 102

✓ PASS: All stacks aligned
```

### Function Signature Alignment

**Automated**: `scripts/check_function_signatures.py`

**Process**:
1. Parse Move function signatures (parameters, return types)
2. Parse Lean symbolic semantics function signatures
3. Compare parameter counts, types, ordering

**Example**:
```bash
$ ./scripts/check_function_signatures.py

Function: transfer
  Move: (sender: &signer, receiver: address, amount: u64, proof: TransferProof) -> ()
  Lean: (sender: Address, receiver: Address, amount: U64, proof: TransferProof) -> Result
  
  ✓ Parameter count matches (4)
  ✓ Parameter types match (signer ≈ Address, address ≈ Address, u64 ≈ U64, TransferProof ≈ TransferProof)
  ✓ Return type matches (() ≈ Result, since Move function aborts on error)
```

### State Transition Consistency (Manual)

**Process**: Compare MSL postconditions with Lean symbolic semantics

**Example**:
```move
// MSL spec
spec transfer {
  ensures sender_balance_post = sender_balance_pre - amount;
  ensures receiver_balance_post = receiver_balance_pre + amount;
}
```

```lean
-- Lean symbolic semantics
def eval_transfer (st : State) (args : TransferArgs) : Result :=
  if valid_conditions st args then
    let st' := st
      |>.update_balance args.sender (st.balance args.sender - args.amount)  -- ✓ Matches MSL
      |>.update_balance args.receiver (st.balance args.receiver + args.amount)  -- ✓ Matches MSL
    .success st'
  else
    .aborted (error_code st args)
```

**Review checklist**:
- [ ] Each MSL `ensures` clause has corresponding Lean state update
- [ ] Lean state updates match MSL exactly (same operations, same order)
- [ ] No Lean state updates missing from MSL (MSL complete)

---

## Performance Quality Gates

### Build Time Gates

**Rule**: No PR merged if it degrades build time by >10%

**Process**:
1. CI measures build time before/after PR
2. If degradation >10%, PR blocked
3. Author must optimize or justify exception

**Example**:
```yaml
# .github/workflows/performance-gate.yaml
- name: Check build time regression
  run: |
    BEFORE=$(cat baseline_build_time.txt)  # e.g., 8.2s
    AFTER=$(lake build 2>&1 | grep "real" | awk '{print $2}')  # e.g., 9.5s
    REGRESSION=$(echo "scale=2; ($AFTER - $BEFORE) / $BEFORE * 100" | bc)  # 15.8%
    
    if (( $(echo "$REGRESSION > 10" | bc -l) )); then
      echo "❌ Build time regression: $REGRESSION% (threshold: 10%)"
      exit 1
    fi
```

### CI Duration Gates

**Rule**: Total CI duration <15 min

**Breakdown**:
- Lean verification: <8 min
- MSL verification: <12 min
- Difftest suite: <5 min
- Cross-layer validation: <3 min

**Process**:
1. CI tracks duration of each workflow
2. If any workflow exceeds threshold, alert team
3. Performance optimization task created

---

## Automated Quality Checks

### CI Quality Checks (Every PR)

**Workflow**: `.github/workflows/quality-ci.yaml`

**Checks**:
1. **No sorry/admit**: Scan for `sorry` and `admit` in Lean files
2. **Axiom diff**: Compare axiom count before/after PR
3. **Build time**: Check per-protocol build time <3s
4. **MSL verification**: Run Move Prover, check no timeouts
5. **Difftest coverage**: Check corpus size ≥1000 per protocol
6. **Abort code alignment**: Run `check_abort_alignment.sh`
7. **Function signature matching**: Run `check_function_signatures.py`

**Example output**:
```
✓ No sorry/admit found
✓ Axiom count unchanged (23 axioms)
✓ Build times acceptable (all <3s)
✓ MSL verification passed (0 timeouts)
✓ Difftest coverage met (1247 test cases)
✓ Abort codes aligned across stacks
✓ Function signatures consistent

All quality checks PASSED
```

### Nightly Quality Audit

**Workflow**: `.github/workflows/nightly-audit.yaml` (runs at 2am UTC)

**Checks**:
1. **Full axiom inventory**: Generate `AXIOM_INVENTORY.md`, check for unexpected changes
2. **Proof density metrics**: Lines of proof per theorem (maintainability metric)
3. **Coverage gaps**: Identify functions without MSL specs or Difftest tests
4. **Dead code**: Find unused lemmas (potential cleanup opportunities)
5. **Documentation sync**: Check guides reference existing files (no broken links)

**Example report** (posted to Slack `#ca-verification-metrics`):
```
📊 Nightly Quality Audit (2026-04-22)

Axioms: 23 (unchanged)
Proofs: 47 theorems, 312 lemmas
Proof density: 16.8 lines/theorem (target: <20)
MSL spec coverage: 90% (57/63 functions)
Difftest coverage: 100% (1247 test cases)

⚠️ Warnings:
- 6 functions without MSL specs (see report)
- 12 unused lemmas (candidates for removal)

Report: https://ci.movement.com/audit/2026-04-22.html
```

---

## Manual Review Best Practices

### Review Time Allocation

**Target**: 1 hour per 300 lines of proof code

**Breakdown**:
- 10 min: High-level review (compiles, no sorry, theorem statement makes sense)
- 15 min: Axiom review (justify all axioms, check reduction plan)
- 20 min: Proof structure review (follows patterns, modular, maintainable)
- 10 min: Cross-stack consistency (compare to MSL/Difftest)
- 5 min: Documentation review (comments, docstrings, cross-references)

### Review Feedback Guidelines

**DO**:
- Be specific: "Line 45: This step needs explanation" > "Proof unclear"
- Suggest fixes: "Consider extracting this as a lemma" > "This is messy"
- Ask questions: "Why is this axiom necessary?" (invites discussion)
- Acknowledge good work: "Nice use of PC-chaining here!"

**DON'T**:
- Nitpick style excessively (autoformat handles this)
- Block on minor issues (suggest, don't require)
- Review while tired (quality suffers)
- Ghost PRs (respond to all comments, even if just "Acknowledged")

### Review Escalation

**When to escalate**:
- Unsure about axiom soundness (escalate to crypto expert)
- Theorem statement seems wrong (escalate to protocol expert)
- Performance concerns (escalate to Lean expert for optimization)
- Cross-stack inconsistency (escalate to all three stack owners)

**Escalation process**:
1. Comment on PR: "@alice-crypto-expert Can you review this axiom for soundness?"
2. Tag in Slack: "Need crypto review on PR #1234, axiom concerns"
3. If urgent (CI broken): Direct message + mention in daily standup

---

## Security-Critical Proof Review

### Definition of Security-Critical

**A proof is security-critical if its incorrectness would enable**:
- Theft of funds (e.g., balance conservation violated)
- Privacy breach (e.g., balance leakage)
- Denial of service (e.g., protocol always aborts)

**Examples of security-critical proofs**:
- Transfer eval equivalence (balance conservation)
- Withdrawal eval equivalence (prevents double-spending)
- Schnorr soundness (prevents unauthorized registration)
- Bulletproofs range proof soundness (prevents negative balances)

### Security-Critical Review Process

**Three-reviewer rule**: Security-critical proofs require approval from:
1. Lean expert (proof correctness)
2. Crypto expert (cryptographic properties)
3. Protocol expert (business logic correctness)

**Extended checklist**:
- [ ] All three reviewers approve
- [ ] Security properties explicitly stated in theorem
- [ ] Threat model reviewed (what attacks does this prevent?)
- [ ] Axioms reviewed by crypto expert (security assumptions valid?)
- [ ] Cross-stack validation complete (MSL + Difftest confirm property)
- [ ] Negative testing complete (Difftest includes attack scenarios)

**Example security review**:
```lean
-- Security-critical theorem: Transfer preserves total balance (prevents theft)
theorem transfer_balance_conservation (st : State) (args : TransferArgs) :
  eval_transfer st args = .success st' →
  total_balance st' = total_balance st := by
  -- Proof: sender balance decreases by amount, receiver increases by amount
  -- Therefore total unchanged
  
-- Security review checklist:
-- ✓ Lean expert (Alice): Proof sound, no axioms, build time 2.1s
-- ✓ Crypto expert (Bob): Property correctly captures balance conservation
-- ✓ Protocol expert (Charlie): Business logic correct (sender + receiver only accounts modified)
-- ✓ MSL spec confirms: `ensures sender + receiver = sender_pre + receiver_pre`
-- ✓ Difftest confirms: 1000+ test cases, all preserve total balance
-- ✓ Negative tests: Attempted theft (send more than balance) correctly aborts

-- APPROVED FOR MERGE
```

---

## Common Proof Anti-Patterns

### Anti-Pattern 1: "Proof by Sorry"

**Pattern**:
```lean
theorem important_property : ... := by
  sorry  -- TODO: Prove this later
```

**Why bad**: Proof incomplete, property not actually established

**Fix**: Don't merge until sorry removed, or explicitly document gap

### Anti-Pattern 2: "Kitchen Sink Axiom"

**Pattern**:
```lean
axiom everything_works :
  ∀ (st : State) (args : Args),
    eval_protocol st args = .success (correct_state st args)
```

**Why bad**: Axiom states entire property, proof trivial (just apply axiom)

**Fix**: Prove property from minimal axioms (oracles only)

### Anti-Pattern 3: "Brute Force Simplification"

**Pattern**:
```lean
theorem slow_proof : ... := by
  simp [*, step, eval, update, balance, ...]  -- 100+ simp lemmas
  -- Build time: 45s
```

**Why bad**: Quadratic elaboration time, hard to debug

**Fix**: Use targeted `rw` or extract lemmas

### Anti-Pattern 4: "Undocumented Axiom"

**Pattern**:
```lean
axiom mysterious_property : ∀ x y, f x = g y
-- No comment explaining why this is true
```

**Why bad**: Reviewer can't assess soundness, future readers confused

**Fix**: Always document axioms with justification

### Anti-Pattern 5: "Incomplete Specification"

**Pattern**:
```move
spec transfer {
  ensures sender_balance_post < sender_balance_pre;  // Only says balance decreased
  // Missing: receiver balance increased, total conserved
}
```

**Why bad**: Spec doesn't capture key properties (balance conservation)

**Fix**: Complete specification (all state mutations)

### Anti-Pattern 6: "Over-Specified Oracle"

**Pattern**:
```lean
axiom schnorr_verify :
  schnorr_verify pk msg sig = true ↔
    sig.response = challenge * sk + nonce ∧  -- Internal structure
    challenge = hash(pk, msg, commitment) ∧   -- Fiat-Shamir details
    ...
```

**Why bad**: Over-constrains implementation, hard to justify

**Fix**: Minimal oracle (soundness property only)

---

## Quality Metrics and Tracking

### Proof Quality Metrics

| Metric | Target | Current | Trend |
|--------|--------|---------|-------|
| Axiom count | <25 | 23 | ↓ (was 28 in Q4 2025) |
| Sorry count | 0 | 0 | → |
| Build time (per protocol) | <3s | 2.4s avg | → |
| CI duration | <15min | 13min | ↓ (was 18min in Q4) |
| MSL spec coverage | >90% | 90% | ↑ (was 85% in Q4) |
| Difftest coverage | 100% | 100% | → |
| Proof density | <20 lines/thm | 16.8 | → |
| Review turnaround | <48h | 36h avg | ↑ (was 28h in Q4) |

### Weekly Quality Review

**When**: Friday week review meeting  
**Duration**: 10 minutes  
**Participants**: Full team

**Agenda**:
1. Review quality metrics (5 min): Any concerning trends?
2. Axiom status (2 min): Progress on elimination? New axioms added?
3. Performance status (2 min): Build time within budget? CI duration acceptable?
4. Action items (1 min): Any quality issues requiring attention next week?

---

## Case Studies

### Case Study 1: Axiom Soundness Issue (Caught in Review)

**Context**: PR #1456 introduces Bulletproofs axiom

**Initial axiom** (UNSOUND):
```lean
axiom bulletproofs_completeness :
  ∀ (value : Scalar) (blinding : Scalar),
    value ∈ [0, 2^64) →
    ∃ (proof : BulletproofRangeProof),
      bulletproofs_verify (commit value blinding) proof = true
```

**Reviewer (Bob, crypto expert) catches issue**:
> "This axiom is incomplete. It states completeness (honest prover can prove), but doesn't state soundness (adversary cannot prove false statement). Without soundness, protocol insecure!"

**Fixed axiom** (SOUND):
```lean
axiom bulletproofs_soundness :
  ∀ (comm : Commitment) (proof : BulletproofRangeProof),
    bulletproofs_verify comm proof = true →
    ∃ (value : Scalar) (blinding : Scalar),
      comm = commit value blinding ∧ value ∈ [0, 2^64)

-- Also add completeness (for proving honest case works):
axiom bulletproofs_completeness :
  ∀ (value : Scalar) (blinding : Scalar),
    value ∈ [0, 2^64) →
    ∃ (proof : BulletproofRangeProof),
      bulletproofs_verify (commit value blinding) proof = true
```

**Outcome**: Security vulnerability caught before merge

### Case Study 2: Performance Regression (Caught by CI)

**Context**: PR #1567 refactors withdrawal proof

**CI output**:
```
❌ Build time regression: 18.2% (was 2.8s, now 3.3s)
Threshold: 10%
```

**Author investigates**: Finds nested `rw` chains causing quadratic elaboration

**Fix**: Extract lemmas, reduce elaboration time to 2.6s (actually improved!)

**Outcome**: Performance gate prevented regression, led to improvement

---

## Troubleshooting

### Problem 1: Axiom Review Bottleneck

**Symptom**: PRs blocked waiting for crypto expert review of axioms

**Solutions**:
- Train secondary crypto reviewer (junior crypto expert)
- Schedule dedicated axiom review time (crypto expert: 2h/week)
- Batch axiom reviews (review multiple PRs in one session)

### Problem 2: MSL Specs Don't Match Implementation

**Symptom**: Move Prover reports errors, but code seems correct

**Diagnosis**:
1. Read error message carefully (which clause fails?)
2. Compare spec to code (does spec accurately describe code?)
3. Check for missing abort conditions (code aborts, spec doesn't mention)

**Fix**: Update spec to match implementation (or vice versa if code wrong)

### Problem 3: Cross-Stack Validation Fails

**Symptom**: `reconcile_all.sh` reports abort code mismatch

**Diagnosis**:
1. Run `check_abort_alignment.sh` to see exact mismatch
2. Check which stack is wrong (Move, MSL, or Lean?)
3. Fix incorrect stack, rerun validation

**Example**:
```bash
$ ./scripts/check_abort_alignment.sh

❌ MISMATCH: MSL uses abort code 103, Lean uses 102 for E_INSUFFICIENT_BALANCE

Action: Fix Lean to use 102 (Move and MSL agree on 102)
```

---

## Cross-References

**Related guides**:
- **COLLABORATIVE_VERIFICATION_WORKFLOWS_AND_TEAM_PROCESSES_GUIDE.md**: Team roles, PR workflow
- **AXIOM_REDUCTION_STRATEGIES_AND_TECHNIQUES_GUIDE.md**: Axiom elimination roadmap
- **CROSS_LAYER_VALIDATION_AND_RECONCILIATION_AUTOMATION_GUIDE.md**: Automation for consistency checks
- **PERFORMANCE_BENCHMARKING_AND_OPTIMIZATION_COMPLETE_GUIDE.md**: Build time optimization
- **LESSONS_LEARNED_AND_KNOWLEDGE_TRANSFER_GUIDE.md**: Hard-won insights

**Automation scripts**:
- `scripts/check_axioms.sh`: Axiom inventory
- `scripts/check_abort_alignment.sh`: Abort code validation
- `scripts/check_function_signatures.py`: Function signature matching
- `audit/reconcile_all.sh`: Full cross-stack validation

**CI workflows**:
- `.github/workflows/quality-ci.yaml`: Quality checks on every PR
- `.github/workflows/axiom-diff-ca.yaml`: Axiom count tracking
- `.github/workflows/performance-gate.yaml`: Build time regression detection

---

## Summary

This guide provides systematic QA processes for formal verification:

1. **Proof soundness review**: Axioms justified, theorem statements correct, symbolic semantics match reality
2. **Comprehensive checklists**: Lean proofs (axioms, statement, structure, performance), MSL specs (completeness, correctness, solvability), Difftest (coverage, oracle mocks, quality)
3. **Axiom review**: Initial review (justification, minimality, reduction plan), quarterly audit (track progress)
4. **Oracle review**: Minimality (weak as possible), testability (Difftest validates)
5. **Cross-stack consistency**: Abort codes, function signatures, state transitions aligned
6. **Performance gates**: Build time <3s per protocol, CI <15min total
7. **Automated checks**: CI runs quality suite every PR, nightly audit finds coverage gaps
8. **Security-critical review**: Three-reviewer rule (Lean + crypto + protocol experts)
9. **Anti-patterns**: Avoid proof by sorry, kitchen sink axioms, brute force tactics, undocumented axioms
10. **Quality tracking**: Weekly review of metrics (axiom count, build time, coverage, review turnaround)

**Success criteria**: All proofs sound (0 sorry), axioms <25 (with reduction plan), MSL coverage >90%, Difftest 100%, build time <3s, CI <15min, cross-stack 100% aligned.

For team workflows, see COLLABORATIVE_VERIFICATION_WORKFLOWS. For axiom elimination, see AXIOM_REDUCTION_STRATEGIES. For cross-stack automation, see CROSS_LAYER_VALIDATION.
