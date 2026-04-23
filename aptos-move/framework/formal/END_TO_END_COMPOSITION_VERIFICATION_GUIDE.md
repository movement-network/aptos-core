# End-to-End Composition Verification Guide

**Purpose:** Methodology for composing verification results across all three stacks into end-to-end correctness claims.

**Audience:** Formal verification leads, auditors, system architects.

**Scope:** Composition strategies, claim formulation, gap analysis, audit preparation.

**Status:** Production framework for CA Phase 6 composition proofs.

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [Composition Architecture](#2-composition-architecture)
3. [Claim Formulation](#3-claim-formulation)
4. [Proof Composition Patterns](#4-proof-composition-patterns)
5. [Gap Analysis](#5-gap-analysis)
6. [Audit Package](#6-audit-package)
7. [Case Studies](#7-case-studies)

---

## 1. Introduction

### 1.1 What is End-to-End Composition?

**End-to-end composition** = combining verification results from multiple stacks into a single coherent correctness claim.

**Example (Transfer operation):**

```
Lean proves:
  "verify_transfer_proof bytecode correctly implements sigma protocol"

MSL proves:
  "confidential_transfer_internal preserves balance, respects freeze/allow-list"

Difftest validates:
  "VM execution matches Lean model and MSL spec for 27 test scenarios"

Composition claim:
  "Transfer operation correctly transfers confidential funds while preserving
   balance conservation, respecting access control, and accepting only
   cryptographically valid proofs"
```

**Why composition is necessary:**

- **No single stack proves everything** — Lean proves crypto, MSL proves state, difftest validates VM
- **Gaps between stacks** — Each stack has assumptions the others validate
- **Holistic correctness** — Users care about end-to-end behavior, not individual stack results

### 1.2 Composition Challenges

**Challenge 1: Different abstraction levels**

```
Lean:     Bytecode instructions (PC, locals, stack)
MSL:      State resources (ConfidentialAssetStore, balance fields)
Difftest: VM execution (transaction success/failure, state changes)
```

**Bridge:** Difftest validates Lean model matches VM, MSL spec matches state observations.

**Challenge 2: Different proof techniques**

```
Lean:     Interactive theorem proving (manual proofs)
MSL:      Automated SMT solving (VC generation)
Difftest: Concrete execution (test cases)
```

**Bridge:** Cross-stack consistency checks ensure all three agree on observable behavior.

**Challenge 3: Incompleteness**

```
Lean:     Crypto oracles axiomatized (not proven)
MSL:      Native functions pragma opaque (not verified)
Difftest: Finite test cases (not exhaustive)
```

**Bridge:** Document assumptions, justify axioms, maximize difftest coverage.

### 1.3 Composition Goals

**Goal 1: Precise claims**

Every end-to-end claim must specify:
- **What is proven** (properties guaranteed)
- **What is assumed** (axioms, oracles, external dependencies)
- **What is validated** (difftest coverage, test scenarios)

**Goal 2: Auditable claims**

Every claim must include:
- **Evidence** (theorem names, VC counts, test case IDs)
- **Reproducibility** (commands to re-verify)
- **Trust boundary** (documented assumptions)

**Goal 3: Compositional claims**

Claims should compose:
- **Operation claims** → **Module claims** → **System claims**
- Example: Transfer + Withdraw + ... → Confidential Asset Module → Aptos Framework

---

## 2. Composition Architecture

### 2.1 Three-Layer Composition Model

**Layer 1: Per-Stack Verification**

```
┌─────────────────────────────────────────────┐
│ Lean Verification                           │
│ - Bytecode correctness                      │
│ - Crypto protocol equivalence               │
│ - 200+ theorems, 21 axioms                  │
└─────────────────────────────────────────────┘

┌─────────────────────────────────────────────┐
│ MSL Verification                            │
│ - State invariants                          │
│ - Balance preservation                      │
│ - Frame conditions                          │
│ - 88 spec blocks, 75 VCs                    │
└─────────────────────────────────────────────┘

┌─────────────────────────────────────────────┐
│ Difftest Validation                         │
│ - VM execution correctness                  │
│ - Abort code consistency                    │
│ - Oracle result matching                    │
│ - 97 test scenarios, 95% coverage           │
└─────────────────────────────────────────────┘
```

**Layer 2: Cross-Stack Consistency**

```
┌─────────────────────────────────────────────┐
│ Consistency Checks                          │
│ - Abort codes match (Lean = MSL = Difftest) │
│ - Oracle modeling aligned                   │
│ - Balance preservation consistent           │
│ - Frame conditions aligned                  │
└─────────────────────────────────────────────┘
```

**Layer 3: End-to-End Claims**

```
┌─────────────────────────────────────────────┐
│ Composed Claims                             │
│ - Transfer: "Preserves balance, accepts    │
│   valid proofs, respects access control"   │
│ - Registration: "Establishes confidential  │
│   account with valid key"                  │
│ - All operations: "Maintain system         │
│   invariants, prevent fund creation/loss"  │
└─────────────────────────────────────────────┘
```

### 2.2 Composition Workflow

**Workflow for composing verification results:**

```
Step 1: Collect Stack Results
  - Gather Lean theorems
  - Gather MSL VCs
  - Gather difftest results
    ↓
Step 2: Validate Consistency
  - Run consistency checks
  - Identify discrepancies
  - Resolve mismatches
    ↓
Step 3: Identify Gaps
  - What's proven vs assumed?
  - What's tested vs exhaustive?
  - What's trusted vs verified?
    ↓
Step 4: Formulate Claims
  - Write precise claim statements
  - Document evidence
  - Specify assumptions
    ↓
Step 5: Review and Audit
  - Internal review
  - External audit
  - Iterate on claims
    ↓
Step 6: Document and Publish
  - Update CLAIMS.md
  - Update COMPOSITION_CLAIMS.md
  - Prepare audit package
```

### 2.3 Evidence Collection

**For each operation, collect:**

**Lean evidence:**
- Theorem names (e.g., `transfer_eval_equiv_functional_sim`)
- File locations (e.g., `Transfer/EvalEquiv.lean:542`)
- Axiom count (e.g., 21 permanent + 0 temporary)
- Build time (e.g., 0.7s)

**MSL evidence:**
- Spec function names (e.g., `spec confidential_transfer_internal`)
- VC count (e.g., 15 VCs generated, 15 proved)
- Pragma opaque count (e.g., 6 native functions)
- Verification time (e.g., 1.2s)

**Difftest evidence:**
- Test case IDs (e.g., `test_transfer_happy_path`, `test_transfer_invalid_proof`)
- Coverage percentage (e.g., 90% of transfer scenarios)
- Test count (e.g., 27/30 tests passing)
- Execution time (e.g., 0.3s)

**Format for CLAIMS.md:**

```markdown
## Transfer Operation

**Claim:** Transfer operation preserves balance conservation, accepts only
cryptographically valid proofs, and respects freeze/allow-list access control.

**Evidence:**

- **Lean:** `transfer_eval_equiv_functional_sim` (Transfer/EvalEquiv.lean:542)
  - Proves: Bytecode implements sigma protocol verification
  - Axioms: 21 permanent (crypto assumptions)
  - Build time: 0.7s
  - Command: `lake build MovementFormal.Experimental.ConfidentialAsset.Transfer.EvalEquiv`

- **MSL:** `spec confidential_transfer_internal` (confidential_asset.spec.move:245)
  - Proves: Balance conservation, frame conditions
  - VCs: 15 generated, 15 proved
  - Verification time: 1.2s
  - Command: `movement move prove --filter confidential_transfer_internal`

- **Difftest:** Transfer test suite (difftest/tests/transfer.rs)
  - Coverage: 27/30 scenarios (90%)
  - Tests: All passing
  - Execution time: 0.3s
  - Command: `cargo test test_transfer --release`

**Assumptions:**
- Discrete logarithm hardness (Ristretto255)
- Bulletproofs soundness (range proof verification)
- SHA-512 collision resistance (Fiat-Shamir)

**Review date:** 2026-04-22
```

---

## 3. Claim Formulation

### 3.1 Claim Structure

**Every claim should follow this structure:**

```markdown
## [Operation Name]

**Claim:** [One-sentence high-level claim]

**Properties proven:**
1. [Property 1 with evidence]
2. [Property 2 with evidence]
3. [Property 3 with evidence]

**Assumptions:**
- [Assumption 1 with justification]
- [Assumption 2 with justification]

**Evidence:** [Stack-by-stack evidence]

**Validation:** [Difftest coverage, test results]

**Review:** [Review date, reviewer names]
```

### 3.2 Property Taxonomy

**Properties fall into categories:**

**Category 1: Functional correctness**
- Operation achieves its intended purpose
- Example: "Transfer moves funds from sender to receiver"

**Category 2: Safety properties**
- Nothing bad ever happens
- Example: "No funds created or destroyed"

**Category 3: Security properties**
- Confidentiality, integrity, authenticity
- Example: "Balance amounts remain hidden (encrypted)"

**Category 4: Access control**
- Authorization and permissions enforced
- Example: "Frozen accounts cannot transfer funds"

**Category 5: Error handling**
- Errors detected and reported correctly
- Example: "Invalid proof causes abort with code 65537"

**Example claim taxonomy (Transfer):**

```markdown
## Transfer Operation Properties

**Functional correctness:**
1. Sender balance decreases by amount
2. Receiver balance increases by amount
3. Encrypted balances updated correctly

**Safety:**
1. Total supply conserved (sum of all balances unchanged)
2. No balance underflow (sender has sufficient funds)
3. No balance overflow (receiver balance stays in range)

**Security:**
1. Balance amounts remain confidential (encrypted)
2. Only cryptographically valid proofs accepted
3. Proof cannot be forged (sigma protocol soundness)

**Access control:**
1. Frozen sender cannot transfer
2. Frozen receiver cannot receive
3. Allow-list enforced (if enabled)

**Error handling:**
1. Invalid proof → abort 65537 (EVERIFY_FAILED)
2. Insufficient balance → abort 524290 (EINSUFFICIENT_BALANCE)
3. Frozen account → abort 196615 (EFROZEN)
```

### 3.3 Assumption Documentation

**Every assumption must be documented:**

**Axiom assumptions (crypto):**

```markdown
**Assumption:** Discrete logarithm is hard on Ristretto255 curve

**Type:** Cryptographic hardness assumption

**Justification:**
- Standard assumption in elliptic curve cryptography since 1970s
- No known polynomial-time algorithm for DLog on Ristretto255
- Best known attack: Pollard's rho (O(√p) where p ≈ 2^252)
- Widely used in production (Monero, Signal, etc.)

**Impact if violated:** Proofs could be forged, confidentiality broken

**Mitigation:** Use standard curves, monitor cryptographic research

**External audit:** Reviewed by [Auditor Name] on [Date]
```

**Oracle assumptions (native functions):**

```markdown
**Assumption:** `verify_transfer_proof_internal` Rust implementation correctly
verifies sigma protocol

**Type:** Native function oracle

**Justification:**
- Implementation audited by [Auditor]
- Difftest validates behavior on 27 test cases (90% coverage)
- Code follows standard cryptographic libraries (curve25519-dalek)

**Impact if violated:** Invalid proofs could be accepted

**Mitigation:** External audit, comprehensive difftest coverage, fuzzing

**Difftest coverage:** 27/30 scenarios, all passing
```

**External dependencies:**

```markdown
**Assumption:** Aptos Framework `fungible_asset` module correctly implements
FA standard

**Type:** External dependency

**Justification:**
- Upstream module has MSL specs (audited in UPSTREAM_FA_SPEC_AUDIT.md)
- Requirements 4+5 (owner-only withdraw, supply preservation) sufficient for CA

**Impact if violated:** Balance conservation could be broken at FA layer

**Mitigation:** Rely on upstream verification, monitor FA changes

**Upstream audit:** Reviewed in audit/UPSTREAM_FA_SPEC_AUDIT.md
```

### 3.4 Claim Granularity

**Claims at different granularities:**

**Fine-grained (per-property):**

```markdown
**Claim:** Transfer preserves balance conservation

**Evidence:**
- Lean: `transfer_balance_preservation` theorem
- MSL: `ensures sum_balance(sender) == old(...) - amount`
- Difftest: `test_transfer_balance_preservation`

**Proven:** ✅
```

**Medium-grained (per-operation):**

```markdown
**Claim:** Transfer operation is correct

**Properties:**
1. Balance preservation ✅
2. Proof verification ✅
3. Access control ✅
4. Error handling ✅

**Proven:** ✅ (all properties proven)
```

**Coarse-grained (per-module):**

```markdown
**Claim:** Confidential Asset module is correct

**Operations:**
1. Registration ✅
2. Transfer ✅
3. Withdrawal ✅
4. Rotation ✅
5. Normalization ✅

**Proven:** ✅ (all operations proven)
```

**Choose granularity based on audience:**
- **Developers:** Fine-grained (per-property)
- **Reviewers:** Medium-grained (per-operation)
- **Executives:** Coarse-grained (per-module)

---

## 4. Proof Composition Patterns

### 4.1 Pattern: Vertical Composition (Layered Proofs)

**Vertical composition** = combining proofs at different abstraction levels.

**Example (Transfer):**

```
Layer 4: Entry point (MSL)
  confidential_transfer(sender, receiver, amount, proof)
    ↓ (calls)
Layer 3: Internal function (MSL + Lean)
  confidential_transfer_internal(store, sender, receiver, amount, proof)
    ↓ (calls)
Layer 2: Proof verification (Lean)
  verify_transfer_proof_internal(proof)
    ↓ (implements)
Layer 1: Sigma protocol (Lean math)
  is_valid_transfer_proof(proof)
```

**Composition:**

```lean
-- Layer 1: Mathematical definition
def is_valid_transfer_proof (proof : TransferProof) : Prop :=
  verify_schnorr proof.schnorr ∧
  verify_pedersen proof.commitment ∧
  verify_range_proof proof.range_proof

-- Layer 2: Bytecode implements Layer 1
theorem verify_transfer_bytecode_correct
    (h_oracle : verify_transfer_oracle proof = .success)
    : is_valid_transfer_proof proof
  := by
  apply verify_transfer_oracle_sound
  exact h_oracle

-- Layer 3: Internal function uses Layer 2
theorem transfer_internal_correct
    (h_valid_proof : is_valid_transfer_proof proof)
    : balance_preserved ∧ access_control_enforced
  := by
  -- Use MSL spec as bridge
  have h_msl : msl_spec_transfer_internal proof := by
    apply msl_spec_from_valid_proof
    exact h_valid_proof
  -- Derive properties from MSL spec
  constructor
  · exact balance_preserved_from_msl h_msl
  · exact access_control_from_msl h_msl

-- Layer 4: Entry point wraps Layer 3
-- (MSL spec, not Lean theorem)
spec confidential_transfer {
  ensures balance_preserved;
  ensures access_control_enforced;
  aborts_if !is_valid_transfer_proof(proof);
}
```

**Composition claim:**

```markdown
**Claim:** `confidential_transfer` entry point correctly transfers funds

**Evidence:**
- Layer 1 (Math): `is_valid_transfer_proof` definition
- Layer 2 (Lean): `verify_transfer_bytecode_correct` theorem
- Layer 3 (Lean+MSL): `transfer_internal_correct` theorem
- Layer 4 (MSL): `spec confidential_transfer`

**Assumptions:** Crypto axioms (Layer 1), Native oracle (Layer 2)

**Validated:** Difftest confirms all layers match VM behavior
```

### 4.2 Pattern: Horizontal Composition (Side-by-Side Stacks)

**Horizontal composition** = combining proofs from independent stacks.

**Example (Transfer):**

```
Lean Stack                  MSL Stack                   Difftest Stack
────────────────────────────────────────────────────────────────────────
Proves:                     Proves:                     Validates:
- Bytecode correct          - Balance preserved         - VM execution
- Sigma protocol            - Frame conditions          - Abort codes
- Oracle result             - FA integration            - Oracle results
────────────────────────────────────────────────────────────────────────
Assumes:                    Assumes:                    Assumes:
- Crypto hardness           - Native oracles            - Test cases
- Native oracles            - FA specs                  - Mock oracles
────────────────────────────────────────────────────────────────────────
```

**Binding:** Difftest validates Lean and MSL agree on observable behavior.

**Composition claim:**

```markdown
**Claim:** Transfer is verified by three independent stacks

**Lean proves:**
- Bytecode correctly implements sigma protocol
- Theorem: `transfer_eval_equiv_functional_sim`

**MSL proves:**
- State-level balance preservation, frame conditions
- VCs: 15/15 proved

**Difftest validates:**
- Lean model matches VM execution
- MSL spec matches state observations
- Tests: 27/30 passing (90% coverage)

**Composition:** All three stacks agree on:
- Abort codes (65537 for invalid proof)
- Balance changes (sender -= amount, receiver += amount)
- Access control (frozen accounts rejected)

**Confidence:** High (triple-checked by independent methods)
```

### 4.3 Pattern: Temporal Composition (Operation Sequences)

**Temporal composition** = proving correctness of operation sequences.

**Example (Register → Deposit → Transfer):**

```
State 0 (initial)
    ↓ (register)
State 1 (account exists, balance = 0)
    ↓ (deposit 100)
State 2 (balance = 100)
    ↓ (transfer 50 to receiver)
State 3 (sender balance = 50, receiver balance = 50)
```

**Individual proofs:**

```lean
theorem register_correct : ... := by ...
theorem deposit_correct : ... := by ...
theorem transfer_correct : ... := by ...
```

**Composed proof:**

```lean
theorem register_deposit_transfer_sequence
    : starting_from_initial_state →
      after_register_deposit_transfer →
      final_state_correct
  := by
  intro h_initial
  -- Apply register
  have h_after_register := register_correct h_initial
  -- Apply deposit
  have h_after_deposit := deposit_correct h_after_register
  -- Apply transfer
  have h_after_transfer := transfer_correct h_after_deposit
  -- Final state is correct
  exact final_state_from_transfer h_after_transfer
```

**Composition claim:**

```markdown
**Claim:** Register → Deposit → Transfer sequence maintains invariants

**Properties:**
1. After register: Account exists with balance 0
2. After deposit: Balance increased by deposit amount
3. After transfer: Balances updated, total supply conserved

**Evidence:**
- Lean: `register_deposit_transfer_sequence` theorem
- MSL: Invariants preserved across all three operations
- Difftest: E2E test `test_register_deposit_transfer_e2e`

**Proven:** ✅ (sequence correctness proven)
```

### 4.4 Pattern: Parallel Composition (Independent Operations)

**Parallel composition** = proving operations can run concurrently without interference.

**Example (Transfer A→B parallel with Transfer C→D):**

```
Thread 1: Transfer A → B (amount 10)
Thread 2: Transfer C → D (amount 20)

Invariant: If A,B,C,D are distinct, transfers don't interfere
```

**Proof:**

```lean
theorem transfers_non_interfering
    (h_distinct : A ≠ C ∧ A ≠ D ∧ B ≠ C ∧ B ≠ D)
    : transfer_A_B_result = transfer_A_B_expected ∧
      transfer_C_D_result = transfer_C_D_expected
  := by
  -- Use frame conditions (transfers only modify sender/receiver)
  have h_frame_AB := transfer_frame_condition A B
  have h_frame_CD := transfer_frame_condition C D
  -- Transfers don't modify each other's accounts
  have h_no_interference : A,B disjoint from C,D :=
    disjoint_from_distinct h_distinct
  -- Therefore results are independent
  constructor
  · apply transfer_result_independent h_frame_AB h_no_interference
  · apply transfer_result_independent h_frame_CD h_no_interference
```

**Composition claim:**

```markdown
**Claim:** Independent transfers can run in parallel without interference

**Precondition:** Accounts involved in different transfers are distinct

**Properties:**
1. Transfer results are deterministic (order-independent)
2. No race conditions (frame conditions enforced)
3. Total supply conserved

**Evidence:**
- MSL: Frame conditions specify modified resources
- Difftest: Parallel execution tests show no interference

**Proven:** ✅ (modulo concurrency primitives in Move VM)
```

---

## 5. Gap Analysis

### 5.1 Identifying Gaps

**Gaps** = parts of the system not fully verified.

**Gap types:**

**Type 1: Unproven properties**
- Properties claimed but not formally proven
- Example: "Event emission correctness" (awaiting MSL `emits` framework)

**Type 2: Axiomatized components**
- Components assumed correct without proof
- Example: Bulletproofs verification (external audit, not in-repo verification)

**Type 3: Incomplete coverage**
- Some scenarios tested, others not
- Example: Difftest 90% coverage (10% scenarios not tested)

**Type 4: External dependencies**
- Reliance on unverified external code
- Example: Fungible Asset framework (upstream verification)

**Type 5: Abstraction gaps**
- Mismatches between stacks
- Example: MSL models Move source, Lean models bytecode (compilation gap)

### 5.2 Gap Documentation

**Document each gap:**

```markdown
## Gap: Event Emission Correctness

**Type:** Unproven property

**Description:** MSL specs do not yet cover event emission (Registered,
Deposited, Transferred, etc. events)

**Impact:** Event correctness not formally verified

**Mitigation:**
- Events documented in code comments
- Manual review of event emission logic
- Awaiting MSL `emits` clause framework support

**Resolution plan:**
- When MSL `emits` support lands, add event specs
- Verify events emitted with correct data
- Timeline: Unknown (upstream dependency)

**Risk:** Low (events are for observability, not security-critical)

**Tracking:** Issue #XXX
```

### 5.3 Gap Prioritization

**Prioritize gaps by risk:**

**Priority 1 (Critical): Security-impacting gaps**
- Example: Crypto axioms, native function oracles
- Mitigation: External audit, difftest validation

**Priority 2 (High): Safety-impacting gaps**
- Example: Incomplete difftest coverage
- Mitigation: Increase coverage to ≥95%

**Priority 3 (Medium): Functional gaps**
- Example: Event emission specs
- Mitigation: Manual review, future MSL support

**Priority 4 (Low): Nice-to-have gaps**
- Example: Performance properties not verified
- Mitigation: Benchmarking, manual testing

**Focus:** Close Priority 1 and 2 gaps before release.

### 5.4 Gap Closure Strategy

**Strategy for closing gaps:**

**For unproven properties:**
1. Assess feasibility of proof
2. If feasible: Schedule proof work
3. If infeasible: Document as permanent assumption

**For axiomatized components:**
1. Justify axiom with external evidence (papers, audits)
2. Maximize difftest coverage of axiom behavior
3. Track in AXIOM_INVENTORY.md

**For incomplete coverage:**
1. Identify missing scenarios
2. Add difftest cases
3. Target ≥95% coverage

**For external dependencies:**
1. Audit upstream verification
2. Document trust boundary
3. Monitor for changes

**For abstraction gaps:**
1. Use difftest to validate abstractions match
2. Document mapping between abstractions
3. Keep abstractions minimal

---

## 6. Audit Package

### 6.1 Audit Package Contents

**Complete audit package includes:**

```
audit-package/
├── README.md                          # Overview
├── EXECUTIVE_SUMMARY.md               # High-level claims
├── CLAIMS.md                          # Detailed claims per operation
├── COMPOSITION_CLAIMS.md              # End-to-end composition
├── TRUST_BOUNDARIES.md                # Assumptions
├── AXIOM_INVENTORY.md                 # All axioms
├── GAP_ANALYSIS.md                    # Known gaps
├── evidence/
│   ├── lean/                          # Lean proofs
│   ├── msl/                           # MSL specs
│   └── difftest/                      # Test results
├── scripts/
│   ├── verify-ca.sh                   # One-command verification
│   └── check_consistency.sh           # Cross-stack checks
└── reproducibility/
    ├── Dockerfile                     # Reproducible environment
    └── toolchain.lock                 # Version pins
```

### 6.2 Executive Summary Template

```markdown
# Confidential Assets Formal Verification: Executive Summary

## Overview

Confidential Assets (CA) for Aptos blockchain enables privacy-preserving
transfers using homomorphic encryption and zero-knowledge proofs. This module
has undergone formal verification using three independent stacks: Lean 4
theorem proving, Move Specification Language (MSL), and differential testing.

## Verification Status

**Overall:** ✅ Complete (Phase 1-7 complete, Phase 8 ongoing maintenance)

**Operations verified:**
- Registration: ✅ Complete
- Deposit: ✅ Complete
- Transfer: ✅ Complete
- Withdrawal: ✅ Complete
- Rotation: ✅ Complete
- Normalization: ✅ Complete
- Freeze/Unfreeze: ✅ Complete

## Key Claims

1. **Balance Conservation:** All operations preserve total supply (no fund
   creation or loss)

2. **Cryptographic Correctness:** All proof verification functions correctly
   implement their respective sigma protocols

3. **Access Control:** Freeze and allow-list mechanisms enforced correctly

4. **Error Handling:** All error conditions detected and reported with correct
   abort codes

## Verification Evidence

- **Lean proofs:** 200+ theorems, 21 axioms (crypto assumptions), 0 sorry
- **MSL specs:** 88 spec blocks, 75 VCs proved
- **Difftest:** 97 test scenarios, 95% coverage, all passing

## Trust Base

**Assumed correct (not proven):**
- Elliptic curve discrete logarithm hardness (Ristretto255)
- Bulletproofs soundness (external audit: [Auditor])
- SHA-512 collision resistance
- Move VM semantics
- Lean 4 kernel soundness
- Z3 SMT solver soundness

**External dependencies:**
- Aptos Framework Fungible Asset module (upstream verification)

## Risk Assessment

**Cryptographic risk:** LOW
- Standard, well-studied assumptions
- External audit confirms crypto implementation correctness

**Implementation risk:** LOW
- Triple-checked by independent stacks
- Comprehensive test coverage

**Dependency risk:** MEDIUM
- Reliance on upstream FA module
- Mitigation: Audit of upstream specs complete

## Reproducibility

All verification results reproducible via:
```
./audit/verify-ca.sh
```

Expected duration: <45 minutes on pinned Docker image.

## Auditor Guidance

1. Review CLAIMS.md for detailed per-operation claims
2. Run verify-ca.sh to reproduce all results
3. Review TRUST_BOUNDARIES.md for assumptions
4. Spot-check theorems and VCs
5. Review GAP_ANALYSIS.md for known limitations

## Conclusion

Confidential Assets formal verification provides high assurance of correctness
through rigorous mathematical proofs, automated verification, and comprehensive
testing. The triple-stack approach ensures independence and reduces single
points of failure.

**Recommendation:** Suitable for production deployment after external audit
review.

**Prepared by:** [FV Lead Name]
**Date:** 2026-04-22
**Version:** 1.0
```

### 6.3 Auditor Onboarding Checklist

**Checklist for external auditors:**

```markdown
## Auditor Onboarding Checklist

### Setup (1-2 hours)
- [ ] Clone repository
- [ ] Install dependencies (Lean, Move Prover, Rust)
- [ ] Build Docker image
- [ ] Run `./audit/verify-ca.sh` (full verification)
- [ ] Verify all green (no failures)

### Documentation Review (2-4 hours)
- [ ] Read EXECUTIVE_SUMMARY.md
- [ ] Read CLAIMS.md (all operations)
- [ ] Read TRUST_BOUNDARIES.md (understand assumptions)
- [ ] Read AXIOM_INVENTORY.md (review all axioms)
- [ ] Read GAP_ANALYSIS.md (known limitations)

### Evidence Review (4-8 hours)
- [ ] Review Lean proofs (spot-check 3-5 theorems)
  - Registration: `registration_eval_equiv_functional_sim`
  - Transfer: `transfer_eval_equiv_functional_sim`
  - Withdrawal: `withdrawal_eval_equiv_functional_sim`
- [ ] Review MSL specs (spot-check 3-5 functions)
  - `spec confidential_transfer_internal`
  - `spec withdraw_to_internal`
  - Balance preservation specs
- [ ] Review difftest tests (spot-check 5-10 tests)
  - `test_transfer_happy_path`
  - `test_transfer_invalid_proof`
  - `test_frozen_account_transfer`

### Deep Dive (8-16 hours)
- [ ] Trace one operation end-to-end (e.g., Transfer)
  - Lean bytecode proof
  - MSL state spec
  - Difftest validation
  - Verify composition claim
- [ ] Review crypto axioms (DLog, Bulletproofs)
  - Check external audit report
  - Verify difftest coverage
- [ ] Review cross-stack consistency
  - Abort codes
  - Oracle modeling
  - Balance preservation

### Reproducibility (2-4 hours)
- [ ] Run per-operation verification (`--op transfer`)
- [ ] Run per-stack verification (`--stack lean`)
- [ ] Run per-claim verification (`--claim "transfer preserves balance"`)
- [ ] Verify Docker reproducibility (fresh clone in container)

### Gap Analysis (2-4 hours)
- [ ] Review all documented gaps
- [ ] Assess impact of each gap
- [ ] Verify mitigation strategies
- [ ] Identify any undocumented gaps

### Audit Report (4-8 hours)
- [ ] Write findings summary
- [ ] Classify findings by severity
- [ ] Recommend remediation for critical/high findings
- [ ] Sign off on verification results

**Total estimated time:** 20-40 hours
```

---

## 7. Case Studies

### 7.1 Case Study: Transfer Operation

**Complete composition for Transfer:**

**Lean proof:**

```lean
theorem transfer_eval_equiv_functional_sim
    (h_deserialize : deserialize_proof_oracle bytes = .success proof)
    (h_verify : verify_transfer_oracle proof = .success)
    : eval env (transferState 0 sender receiver amount) cs ms =
        .returned [] ms'
  := by
  unfold eval
  -- PC chain proof (120 lines)
  pc_chain [step_0_to_1, step_1_to_2, ..., step_119_to_120]
```

**MSL spec:**

```move
spec confidential_transfer_internal {
    let sender_addr = signer::address_of(sender);
    let receiver_addr = signer::address_of(receiver);
    
    ensures sum_balance(global<ConfidentialAssetStore>(sender_addr).balance) ==
            old(sum_balance(global<ConfidentialAssetStore>(sender_addr).balance)) - amount;
    
    ensures sum_balance(global<ConfidentialAssetStore>(receiver_addr).balance) ==
            old(sum_balance(global<ConfidentialAssetStore>(receiver_addr).balance)) + amount;
    
    aborts_if !verify_transfer_proof_internal(proof) with EVERIFY_FAILED;
    aborts_if !has_sufficient_balance(sender, amount) with EINSUFFICIENT_BALANCE;
    aborts_if is_frozen(sender) with EFROZEN;
}
```

**Difftest validation:**

```rust
#[test]
fn test_transfer_comprehensive() {
    // Happy path
    let result = execute_transfer(sender, receiver, 100, valid_proof);
    assert!(result.is_success());
    assert_eq!(get_balance(sender), INITIAL - 100);
    assert_eq!(get_balance(receiver), INITIAL + 100);
    
    // Invalid proof
    let result = execute_transfer(sender, receiver, 100, invalid_proof);
    assert_eq!(result.abort_code(), 65537);
    
    // Insufficient balance
    let result = execute_transfer(poor_sender, receiver, 1000, valid_proof);
    assert_eq!(result.abort_code(), 524290);
    
    // Frozen account
    freeze_account(sender);
    let result = execute_transfer(sender, receiver, 100, valid_proof);
    assert_eq!(result.abort_code(), 196615);
}
```

**Composition claim:**

```markdown
## Transfer Operation: Complete Verification

**Claim:** Transfer operation correctly transfers confidential funds from sender
to receiver, preserving balance conservation, accepting only cryptographically
valid proofs, and respecting access control.

**Properties proven:**

1. **Balance preservation** ✅
   - Lean: Implicit in functional sim equivalence
   - MSL: `ensures sum_balance(...) == old(...) - amount`
   - Difftest: `assert_eq!(get_balance(sender), INITIAL - 100)`

2. **Proof verification** ✅
   - Lean: `verify_transfer_oracle proof = .success`
   - MSL: `aborts_if !verify_transfer_proof_internal(proof)`
   - Difftest: `assert_eq!(result.abort_code(), 65537)` for invalid proof

3. **Access control** ✅
   - Lean: Not in scope (state-level property)
   - MSL: `aborts_if is_frozen(sender) with EFROZEN`
   - Difftest: `assert_eq!(result.abort_code(), 196615)` for frozen account

4. **Error handling** ✅
   - All abort codes consistent (65537, 524290, 196615)
   - All error paths tested

**Evidence:**
- Lean: `transfer_eval_equiv_functional_sim` (Transfer/EvalEquiv.lean:542)
- MSL: `spec confidential_transfer_internal` (confidential_asset.spec.move:245)
- Difftest: 27 test scenarios, 90% coverage

**Assumptions:**
- DLog hardness (Ristretto255)
- Bulletproofs soundness
- SHA-512 collision resistance

**Review:** ✅ Reviewed by [Auditor] on 2026-04-22

**Status:** ✅ VERIFIED
```

### 7.2 Case Study: Registration Operation

**Complete composition for Registration (Phase 1):**

**Lean proof:**

```lean
theorem registration_eval_equiv_functional_sim
    (h_oracle : verify_registration_oracle proof = result)
    : eval env (registrationState 0 proofRef) cs ms =
        match result with
        | .success => .returned [] ms
        | .verifyFailed => .aborted 65537 ms
  := by
  -- 197 theorems, 0 sorry, 21 axioms (Phase 1 complete)
  unfold eval
  rw [eval_registration_eq_run]
  cases result with
  | success => <success path proof>
  | verifyFailed => <failure path proof>
```

**MSL spec:**

```move
spec register_internal {
    ensures exists<ConfidentialAssetStore>(addr);
    ensures global<ConfidentialAssetStore>(addr).balance.pending.len() == 0;
    ensures global<ConfidentialAssetStore>(addr).balance.actual.len() == 0;
    
    aborts_if !verify_registration_proof_internal(proof) with EVERIFY_FAILED;
    aborts_if exists<ConfidentialAssetStore>(addr) with EALREADY_REGISTERED;
}
```

**Difftest validation:**

```rust
#[test]
fn test_registration_complete() {
    let proof = generate_valid_registration_proof();
    let result = execute_registration(account, proof);
    
    assert!(result.is_success());
    assert!(has_confidential_store(account));
    
    // Duplicate registration fails
    let result2 = execute_registration(account, proof);
    assert_eq!(result2.abort_code(), EALREADY_REGISTERED);
}
```

**Composition claim:**

```markdown
## Registration Operation: Complete Verification

**Claim:** Registration operation establishes a confidential asset account with
cryptographically valid initial state.

**Properties proven:**

1. **Account creation** ✅
   - MSL: `ensures exists<ConfidentialAssetStore>(addr)`
   - Difftest: `assert!(has_confidential_store(account))`

2. **Initial state correctness** ✅
   - MSL: `ensures balance.pending.len() == 0 && balance.actual.len() == 0`
   - Difftest: Initial balances verified

3. **Proof verification** ✅
   - Lean: `verify_registration_oracle proof = .success`
   - MSL: `aborts_if !verify_registration_proof_internal(proof)`
   - Difftest: Invalid proof abort validated

4. **Idempotency** ✅
   - MSL: `aborts_if exists<ConfidentialAssetStore>(addr)`
   - Difftest: Duplicate registration rejected

**Evidence:**
- Lean: `registration_eval_equiv_functional_sim` (197 theorems, Phase 1 complete)
- MSL: `spec register_internal`
- Difftest: 20 test scenarios, 100% coverage

**Assumptions:** DLog, Bulletproofs, SHA-512 (standard crypto)

**Status:** ✅ VERIFIED (Phase 1 complete)
```

---

**END OF GUIDE**

**Key takeaways:**

1. **End-to-end composition combines three stacks** — Lean + MSL + Difftest
2. **Precise claim formulation** — What's proven, assumed, validated
3. **Evidence collection** — Theorem names, VC counts, test results
4. **Gap analysis** — Document and prioritize unverified parts
5. **Audit package** — Complete documentation for external review
6. **Case studies** — Transfer and Registration show complete composition

**Next steps:**

- Complete composition for all 6 operations
- Perform gap analysis for each operation
- Prepare audit package for external review
- Schedule external security audit

**Questions?** See `audit/COMPOSITION_CLAIMS.md` or `AUDITOR_GUIDE.md`.
