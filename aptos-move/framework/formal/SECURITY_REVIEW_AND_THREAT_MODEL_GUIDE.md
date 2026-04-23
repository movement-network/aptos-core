# Security Review and Threat Model Guide for Confidential Assets

**Version**: 1.0  
**Last Updated**: 2026-04-22  
**Status**: Production  
**Audience**: Security reviewers, auditors, verification engineers, protocol designers  
**Estimated Read Time**: 75 minutes  

---

## Table of Contents

1. [Overview](#overview)
2. [Threat Model](#threat-model)
3. [Security Properties and Guarantees](#security-properties-and-guarantees)
4. [Attack Surface Analysis](#attack-surface-analysis)
5. [Cryptographic Security Assumptions](#cryptographic-security-assumptions)
6. [Layer-Specific Review Checklists](#layer-specific-review-checklists)
7. [Known Limitations and Trust Boundaries](#known-limitations-and-trust-boundaries)
8. [Side-Channel Considerations](#side-channel-considerations)
9. [Review Workflow and Sign-Off](#review-workflow-and-sign-off)
10. [Security Regression Testing](#security-regression-testing)
11. [Incident Response Procedures](#incident-response-procedures)
12. [Cross-References](#cross-references)

---

## Overview

### Purpose

This guide provides a systematic framework for security review of the Confidential Assets (CA) protocol and its formal verification infrastructure. It defines the threat model, enumerates security properties, analyzes attack surfaces, and provides concrete checklists for reviewing each verification layer.

### Scope

**In scope:**
- Confidential asset protocol security properties (balance hiding, integrity, non-malleability)
- Cryptographic protocol correctness (sigma protocols, zero-knowledge proofs)
- Verification infrastructure security (Lean proofs, MSL specifications, Difftest coverage)
- Trust boundaries and assumptions
- Side-channel attack vectors
- Security regression prevention

**Out of scope:**
- Move VM security (covered by Aptos core security reviews)
- Network-layer security (P2P, consensus)
- Wallet/client-side security (handled by wallet implementers)
- Operational security (key management, deployment procedures)

### Document Structure

This guide follows a top-down approach:
1. **Threat model** defines adversaries and their capabilities
2. **Security properties** enumerate what we're protecting against
3. **Attack surface** maps where adversaries can interact
4. **Review checklists** provide concrete verification steps
5. **Incident response** handles discovered vulnerabilities

---

## Threat Model

### Adversary Model

#### Adversary Categories

**A1: Malicious User**
- **Capabilities**: Can submit arbitrary transactions, craft malicious proofs, control multiple accounts
- **Goal**: Steal funds, create funds from nothing, break balance hiding
- **Constraints**: Cannot break cryptographic assumptions, cannot compromise validator nodes
- **Examples**: Attacker trying to withdraw more than their balance, double-spend, or deanonymize other users

**A2: Malicious Validator**
- **Capabilities**: Can observe all transaction data, delay/reorder transactions (subject to consensus), fork blockchain (if controlling >1/3 stake)
- **Goal**: Deanonymize users, censor transactions, extract MEV
- **Constraints**: Cannot break cryptographic assumptions, cannot forge signatures
- **Examples**: Validator trying to link encrypted balances to users, front-run confidential transfers

**A3: Blockchain Observer**
- **Capabilities**: Can read all on-chain data, correlate transactions, analyze patterns
- **Goal**: Deanonymize users, infer transaction amounts
- **Constraints**: Cannot modify blockchain, cannot access off-chain data
- **Examples**: Chain analysis firm attempting to break balance hiding through traffic analysis

**A4: Compromised Client**
- **Capabilities**: Can access user's private keys and decryption keys
- **Goal**: Steal funds, impersonate user
- **Constraints**: Limited to single user's assets
- **Examples**: Malware on user's device extracting private keys

**Out-of-Scope Adversaries:**
- **Quantum adversaries**: Currently out of scope; would require lattice-based crypto migration
- **Covert channel adversaries**: Timing/power analysis on client devices (wallet responsibility)
- **Supply chain adversaries**: Compromised compiler/hardware (operational security)

#### Adversarial Capabilities Matrix

| Capability | A1: User | A2: Validator | A3: Observer | A4: Client |
|------------|----------|---------------|--------------|------------|
| Submit transactions | ✓ | ✓ | ✗ | ✓ |
| Craft malicious proofs | ✓ | ✓ | ✗ | ✓ |
| Observe all on-chain data | ✓ | ✓ | ✓ | ✓ |
| Delay/reorder transactions | ✗ | ✓ | ✗ | ✗ |
| Access user private keys | ✗ | ✗ | ✗ | ✓ |
| Correlate transactions | ✓ | ✓ | ✓ | ✓ |
| Break crypto assumptions | ✗ | ✗ | ✗ | ✗ |

### Security Goals

**G1: Balance Confidentiality**
- Encrypted balances must not reveal plaintext amounts to adversaries A1, A2, A3
- Even with full on-chain data access, adversaries cannot determine user balances
- Defense: ElGamal encryption under Decisional Diffie-Hellman assumption

**G2: Balance Integrity**
- Users cannot create funds from nothing
- Users cannot spend more than their balance
- Total supply is conserved across all operations
- Defense: Zero-knowledge proofs enforce balance constraints without revealing amounts

**G3: Non-Malleability**
- Adversaries cannot modify encrypted balances without detection
- Proofs cannot be replayed or tampered with
- Defense: Fiat-Shamir transform binds proofs to specific contexts

**G4: Correctness**
- All valid operations are accepted
- All invalid operations are rejected
- No false positives/negatives in proof verification
- Defense: Formal verification proves implementation matches specification

**G5: Availability**
- Valid transactions cannot be permanently censored (subject to consensus)
- Protocol remains functional under adversarial conditions
- Defense: Decentralized validator set, consensus guarantees

### Out-of-Scope Security Goals

**NOT guaranteed:**
- **Sender/receiver anonymity**: Transactions reveal sender/receiver addresses (by design)
- **Transaction graph unlinkability**: Transaction flow is public (balance amounts are hidden)
- **Resistance to traffic analysis**: Timing/pattern analysis may reveal information
- **Protection against compromised validators controlling >2/3 stake**: Consensus-level attack
- **Post-quantum security**: Current crypto primitives are quantum-vulnerable

---

## Security Properties and Guarantees

### Property P1: Balance Hiding (Computational)

**Formal Statement:**
For any PPT adversary A with access to all on-chain data, the advantage in distinguishing between encryptions of balance `b₁` and `b₂` is negligible:

```
Adv[A distinguishes Enc(b₁) from Enc(b₂)] ≤ negl(λ)
```

where `λ` is the security parameter (255 bits for Ristretto255).

**Verification Evidence:**
- **Cryptographic reduction**: ElGamal encryption security reduces to DDH assumption over Ristretto255 group
- **Lean proof**: `ConfidentialBalance.lean` proves encryption correctness
- **MSL specification**: `confidential_balance.spec.move` specifies balance encryption properties
- **Difftest**: `scenarios/encryption_randomness.move` validates encryption uniqueness

**Known Limitations:**
- Does **not** protect against timing/traffic analysis (observable transaction patterns)
- Does **not** hide transaction graph (sender/receiver addresses public)
- Reveals balance is within supported range [0, 2^64)

**Review Checklist:**
- [ ] Verify ElGamal encryption uses fresh randomness per encryption
- [ ] Confirm no plaintext leakage in error messages
- [ ] Check encryption uses Ristretto255 group correctly (cofactor clearing)
- [ ] Validate randomness source has sufficient entropy

### Property P2: Balance Integrity (Soundness)

**Formal Statement:**
For any PPT adversary A, the probability of producing a valid proof for an invalid statement is negligible:

```
Pr[A produces valid proof for invalid balance operation] ≤ negl(λ)
```

**Verification Evidence:**
- **Lean proof**: PC-chaining proofs in `Withdrawal/EvalEquiv.lean`, `Transfer/EvalEquiv.lean`, etc. prove that accepted proofs imply correct balance updates
- **MSL specification**: Abort conditions in `confidential_asset.spec.move` enforce proof verification
- **Difftest**: `scenarios/invalid_proofs.move` validates rejection of malformed proofs

**Known Limitations:**
- Soundness holds **if and only if** cryptographic assumptions hold (discrete log hardness)
- Proof verification cost is O(n) in proof size (potential DoS vector if not rate-limited)

**Review Checklist:**
- [ ] Verify all abort paths are fully specified in MSL
- [ ] Confirm Lean proofs cover both success and failure paths
- [ ] Check that proof verification rejects malformed inputs (fuzzing coverage)
- [ ] Validate no proof verification bypass paths exist

### Property P3: Non-Malleability

**Formal Statement:**
For any PPT adversary A given a valid proof π for statement x, the probability of producing a different valid proof π' for a related statement x' (without knowing the witness) is negligible:

```
Pr[A(x, π) → (x', π') where π' valid for x' and x' ≠ x] ≤ negl(λ)
```

**Verification Evidence:**
- **Cryptographic reduction**: Fiat-Shamir transform with context binding prevents replay attacks
- **Lean proof**: Challenge computation in `ConfidentialProof.lean` includes transaction context
- **MSL specification**: `generate_challenge` function includes domain separation tags
- **Difftest**: `scenarios/proof_replay.move` validates replay attack rejection

**Implementation Details:**
```move
// Context binding in challenge generation
fun generate_challenge(
    dst: vector<u8>,  // Domain separation tag
    context: vector<u8>,  // Transaction-specific context
    public_inputs: vector<u8>
): Scalar {
    sha512(dst || context || public_inputs)
}
```

**Review Checklist:**
- [ ] Verify domain separation tag (DST) is unique per protocol
- [ ] Confirm context includes all public inputs
- [ ] Check challenge derivation cannot be controlled by adversary
- [ ] Validate proofs cannot be copied between different operations

### Property P4: Completeness

**Formal Statement:**
For any valid operation with a valid witness, there exists a proof that will be accepted:

```
∀ valid operations: ∃ proof π such that verify(π) = true
```

**Verification Evidence:**
- **Lean proof**: Forward direction of equivalence proofs shows valid operations produce valid proofs
- **MSL specification**: Preconditions specify exactly when operations should succeed
- **Difftest**: Happy path scenarios validate all valid operations are accepted

**Known Limitations:**
- Completeness holds only for inputs within specified ranges
- Operations may fail due to gas limits (not a protocol limitation)

**Review Checklist:**
- [ ] Verify all happy path scenarios pass in Difftest
- [ ] Confirm no spurious abort conditions in MSL specs
- [ ] Check Lean proofs cover forward direction (valid → accepted)
- [ ] Validate gas limits are sufficient for valid operations

### Property P5: Supply Conservation

**Formal Statement:**
The total supply across all encrypted balances is conserved across all operations:

```
∀ operations op: Σ balances_before = Σ balances_after
```

**Verification Evidence:**
- **Lean proof**: `Transfer/EvalEquiv.lean` proves sender decrease equals receiver increase
- **MSL specification**: Balance change invariants in all operation specs
- **Difftest**: `scenarios/supply_conservation.move` validates total supply tracking

**Implementation Details:**
```move
// Transfer operation preserves supply
ensures old(confidential_balance(sender).encrypted_balance) + amount ==
        confidential_balance(sender).encrypted_balance;
ensures old(confidential_balance(receiver).encrypted_balance) - amount ==
        confidential_balance(receiver).encrypted_balance;
```

**Review Checklist:**
- [ ] Verify all operations specify balance change explicitly
- [ ] Confirm withdrawal decreases total supply correctly
- [ ] Check registration doesn't create funds from nothing
- [ ] Validate normalization/rotation preserve balance

---

## Attack Surface Analysis

### Surface S1: Transaction Entry Points

**Public Functions:**
1. `register(public_key, proof)` - Create confidential balance
2. `transfer(sender, receiver, amount, proof)` - Confidential transfer
3. `withdraw(owner, amount, proof)` - Decrypt and withdraw to regular balance
4. `normalize(owner, proof)` - Re-randomize encrypted balance
5. `rotate_key(owner, new_key, proof)` - Change encryption key

**Attack Vectors:**

**V1.1: Malformed Proof Submission**
- **Attack**: Submit proof with invalid scalars/points
- **Impact**: DoS if verification crashes, balance theft if verification bypassed
- **Mitigation**: Input validation rejects out-of-range scalars, off-curve points
- **Verification**: `scenarios/malformed_proofs.move` in Difftest
- **Review**: Check all `from_bytes` operations handle invalid inputs gracefully

**V1.2: Proof Replay**
- **Attack**: Copy valid proof from one transaction to another
- **Impact**: Unauthorized operations if context binding is weak
- **Mitigation**: Fiat-Shamir challenge includes transaction hash, nonce
- **Verification**: `scenarios/proof_replay.move` validates rejection
- **Review**: Verify challenge computation includes all relevant context

**V1.3: Integer Overflow in Amount**
- **Attack**: Provide amount near `u64::MAX` causing overflow in balance computation
- **Impact**: Balance wrapping, creating funds from nothing
- **Mitigation**: All arithmetic checked in MSL specs, Lean proofs assume bounded inputs
- **Verification**: MSL abort conditions on overflow, Difftest boundary cases
- **Review**: Check all arithmetic operations have overflow checks

**V1.4: Front-Running**
- **Attack**: Validator observes pending transfer, submits own transaction first
- **Impact**: MEV extraction, transaction censoring
- **Mitigation**: Consensus-level protection (out of scope), application-level defenses (nonce ordering)
- **Verification**: Not directly verified (consensus responsibility)
- **Review**: Document front-running risks, recommend nonce-based ordering

### Surface S2: Native Function Oracles

**Native Functions:**
1. `ristretto255_point_from_bytes` - Deserialize curve point
2. `ristretto255_scalar_from_bytes` - Deserialize scalar
3. `sha512` - Hash function
4. `verify_schnorr_proof` - Sigma protocol verification

**Attack Vectors:**

**V2.1: Oracle Implementation Bug**
- **Attack**: Native function has bug in Rust implementation
- **Impact**: Incorrect verification results, consensus failure
- **Mitigation**: Heavy testing, formal verification of oracle axioms
- **Verification**: Oracle axioms in `AXIOM_INVENTORY.md`, Difftest validates against real implementation
- **Review**: Check oracle axioms match Rust implementation, review Difftest coverage

**V2.2: Serialization Mismatch**
- **Attack**: Serialization format differs between Rust and Move
- **Impact**: Valid data rejected, invalid data accepted
- **Mitigation**: Shared serialization format (BCS), integration tests
- **Verification**: Difftest uses real VM execution
- **Review**: Verify serialization format consistency across language boundary

**V2.3: Side-Channel Leakage**
- **Attack**: Timing/power analysis on native function execution
- **Impact**: Private key extraction (if client-side), balance deanonymization
- **Mitigation**: Constant-time implementations in Rust (out of scope for Move verification)
- **Verification**: Rust implementation review (not covered by Lean/MSL)
- **Review**: Document constant-time requirements, recommend security review of Rust code

### Surface S3: State Access Patterns

**Global State Resources:**
1. `ConfidentialBalance<CoinType>` - Per-user encrypted balance
2. `ConfidentialAssetConfig<CoinType>` - Protocol parameters

**Attack Vectors:**

**V3.1: Unauthorized State Access**
- **Attack**: Read/modify another user's balance without permission
- **Impact**: Privacy violation, balance theft
- **Mitigation**: Move's resource ownership model enforces access control
- **Verification**: MSL specs use `acquires` clauses, Lean proofs model resource ownership
- **Review**: Verify all state access uses proper capabilities

**V3.2: State Corruption**
- **Attack**: Leave resources in inconsistent state after abort
- **Impact**: Broken invariants, protocol malfunction
- **Mitigation**: Move's transaction atomicity, MSL global invariants
- **Verification**: MSL `invariant` specs, Lean proofs show state consistency
- **Review**: Check all operations maintain invariants even on abort paths

**V3.3: Resource Exhaustion**
- **Attack**: Create unbounded number of resources, exhaust storage
- **Impact**: DoS, high storage costs
- **Mitigation**: Gas limits, per-account resource limits
- **Verification**: Gas profiling in CI/CD pipeline
- **Review**: Verify storage costs are reasonable, no unbounded loops

### Surface S4: Verification Infrastructure

**Components:**
1. Lean 4 proofs (`lean/MovementFormal/`)
2. MSL specifications (`sources/*.spec.move`)
3. Difftest corpus (`difftest/scenarios/`)

**Attack Vectors:**

**V4.1: Proof Gaps**
- **Attack**: Exploit gap between verified code and deployed code
- **Impact**: Verified properties don't hold in production
- **Mitigation**: Bytecode transcription validation, automated comparison
- **Verification**: `BYTECODE_TRANSCRIPTION_GUIDE.md` procedures
- **Review**: Compare deployed bytecode against verified Move source

**V4.2: Axiom Misuse**
- **Attack**: Introduce unsound axiom that allows proving false statements
- **Impact**: Proofs prove nothing, security properties void
- **Mitigation**: Axiom review checklist, automated axiom tracking
- **Verification**: `AXIOM_INVENTORY.md` documents all 23 axioms, CI/CD detects additions
- **Review**: Verify each axiom has cryptographic justification, no `sorry` in production

**V4.3: Incomplete Specification**
- **Attack**: MSL spec doesn't cover all code paths, allowing unverified behavior
- **Impact**: Unverified code may violate security properties
- **Mitigation**: Specification coverage metrics, completeness review
- **Verification**: MSL coverage analysis, Difftest corpus expansion
- **Review**: Check all public functions have complete specs, all abort paths covered

**V4.4: Difftest Oracle Mocking**
- **Attack**: Difftest uses incorrect oracle behavior, masking bugs
- **Impact**: False confidence in correctness
- **Mitigation**: Oracle axioms match real implementation, regular sync
- **Verification**: Oracle implementations in `difftest/oracles/` match native code
- **Review**: Compare oracle implementations against Rust native functions

---

## Cryptographic Security Assumptions

### Assumption C1: Discrete Logarithm Hardness

**Statement:**
For random generator `G` and point `P = xG` in Ristretto255 group, no PPT adversary can compute `x` with non-negligible probability.

**Security Level:** ~126 bits (Ristretto255 over Curve25519)

**Where Used:**
- ElGamal encryption security
- Schnorr proof soundness
- Public key ownership

**Failure Impact:**
If discrete log is broken:
- Encrypted balances can be decrypted (balance hiding lost)
- Proofs can be forged (integrity lost)
- Private keys can be extracted (complete protocol failure)

**Risk Assessment:**
- **Current**: Very low (no practical attacks known)
- **5 years**: Low (quantum computers unlikely to be large enough)
- **10 years**: Medium (quantum computers may threaten 256-bit ECC)
- **Mitigation**: Plan migration to post-quantum cryptography

### Assumption C2: Decisional Diffie-Hellman (DDH)

**Statement:**
For random generator `G` and random scalars `a, b, c`, no PPT adversary can distinguish `(G, aG, bG, abG)` from `(G, aG, bG, cG)` with non-negligible advantage.

**Security Level:** ~126 bits (same as DL assumption)

**Where Used:**
- ElGamal encryption semantic security
- Balance confidentiality

**Failure Impact:**
If DDH is broken:
- Encrypted balances can be distinguished (balance hiding partially lost)
- Multiple encryptions of same balance can be linked
- Transaction amounts may be inferred

**Risk Assessment:**
- **Current**: Very low (DDH is believed equivalent to DL for elliptic curves)
- **Long-term**: Same as DL assumption

### Assumption C3: Random Oracle Model (ROM)

**Statement:**
SHA-512 hash function behaves like a random oracle: outputs are indistinguishable from random for adversary.

**Security Level:** 512-bit output (overkill for 126-bit security target)

**Where Used:**
- Fiat-Shamir transform (proof non-malleability)
- Challenge generation in sigma protocols

**Failure Impact:**
If SHA-512 is broken (preimage, collision):
- Proofs may be malleable (replay attacks)
- Challenges may be predictable (proof forgeability)

**Risk Assessment:**
- **Current**: Very low (SHA-512 is battle-tested)
- **Long-term**: Low (512-bit output provides huge security margin)
- **Mitigation**: SHA-512 can be swapped for SHA3-512 if needed (protocol parameter)

### Assumption C4: Standard Cryptographic Implementation

**Statement:**
Rust implementations of cryptographic primitives (curve25519-dalek, sha2) are correct and free of critical bugs.

**Security Level:** N/A (implementation assumption)

**Where Used:**
- All native function oracles
- Serialization/deserialization

**Failure Impact:**
Implementation bugs could:
- Break cryptographic security
- Create consensus failures
- Enable balance manipulation

**Risk Assessment:**
- **Current**: Low (widely-used, audited libraries)
- **Mitigation**: 
  - Use well-audited crates (curve25519-dalek, sha2)
  - Regular dependency updates
  - Fuzzing of native functions
  - Independent security audit of Rust code

### Assumption Summary Table

| Assumption | Type | Security Level | Failure Impact | Current Risk |
|------------|------|----------------|----------------|--------------|
| C1: Discrete Log | Hardness | ~126 bits | Total protocol failure | Very Low |
| C2: DDH | Hardness | ~126 bits | Balance hiding lost | Very Low |
| C3: Random Oracle | Model | 512-bit hash | Proof malleability | Very Low |
| C4: Implementation | Correctness | N/A | Variable | Low |

**Crypto Agility:**
Protocol is designed for crypto agility:
- Hash function is a parameter (can upgrade SHA-512 → SHA3-512)
- Curve choice is abstracted (can migrate Ristretto255 → post-quantum)
- Proof format is versioned (can introduce new proof systems)

---

## Layer-Specific Review Checklists

### Checklist L1: Lean 4 Proof Review

**Proof Completeness:**
- [ ] No `sorry` in production code (except documented temporary gaps)
- [ ] All public functions have corresponding `EvalEquiv` proof
- [ ] Both success and abort paths are proven
- [ ] PC-chaining covers all bytecode instructions

**Axiom Review:**
- [ ] All axioms documented in `AXIOM_INVENTORY.md`
- [ ] Each axiom has cryptographic justification
- [ ] No new axioms added without security review
- [ ] Axiom count matches expected (21 permanent + 2 temporary)

**Structural Invariants:**
- [ ] `@[irreducible]` used for large state definitions
- [ ] Simp lemmas for all `@[irreducible]` projections
- [ ] Step lemmas cover all bytecode operations
- [ ] Frame conditions prove state isolation

**Performance:**
- [ ] No file takes >3 minutes to compile
- [ ] Full tree builds in <10 minutes
- [ ] No performance regressions in CI/CD

**Review Commands:**
```bash
# Check for sorry
grep -r "sorry" lean/MovementFormal/Experimental/ConfidentialAsset/ --include="*.lean"

# Count axioms
./scripts/check_axioms.sh

# Performance profile
lake build --profile MovementFormal.Experimental.ConfidentialAsset.Transfer.EvalEquiv
```

### Checklist L2: MSL Specification Review

**Specification Completeness:**
- [ ] All public functions have specs
- [ ] All abort conditions enumerated
- [ ] All state modifications specified
- [ ] Frame conditions for unmodified state

**Balance Invariants:**
- [ ] Supply conservation in all operations
- [ ] Balance non-negativity preserved
- [ ] Overflow checks on all arithmetic

**Crypto Opaque Boundaries:**
- [ ] `pragma opaque;` on all crypto functions
- [ ] Only properties specified, not implementation
- [ ] Verification succeeds without unfolding crypto

**Abort Specifications:**
- [ ] All error paths have `aborts_if` clauses
- [ ] Error conditions are mutually exclusive and complete
- [ ] Abort reasons match code

**Review Commands:**
```bash
# Run Move Prover
cd aptos-move/framework/aptos-experimental
aptos move prove --filter confidential_asset

# Check for unspecified aborts
grep "aborts_if" sources/confidential_asset/*.spec.move
```

**Common Issues:**
- Forgetting to specify abort condition → verification fails with "unexpected abort"
- Overly strong postcondition → verification fails (counterexample)
- Forgetting frame condition → verification fails (modified unexpected state)

### Checklist L3: Difftest Scenario Review

**Coverage Metrics:**
- [ ] All public functions have happy path scenario
- [ ] All abort paths have negative test scenario
- [ ] Boundary cases tested (0, max, overflow)
- [ ] Current coverage ≥95% (97/102 scenarios)

**Oracle Validation:**
- [ ] Oracle implementations match native function behavior
- [ ] Serialization format matches BCS
- [ ] Error handling matches VM behavior

**Scenario Quality:**
- [ ] Each scenario tests one specific property
- [ ] Scenarios are independent (no ordering dependencies)
- [ ] Assertions check expected outcomes
- [ ] Gas costs are reasonable

**Review Commands:**
```bash
# Run difftest suite
cd aptos-move/framework/formal/difftest
cargo test --release

# Coverage report
./scripts/coverage_report.sh
```

**Scenario Template:**
```move
#[test(alice = @0xa11ce)]
public fun test_transfer_success(alice: signer) {
    // Setup
    confidential_asset::register(&alice, alice_public_key, registration_proof);
    
    // Action
    confidential_asset::transfer(&alice, @bob, amount, transfer_proof);
    
    // Assertions
    assert!(confidential_asset::verify_balance(&alice, expected_balance));
}
```

### Checklist L4: Integration Review

**Cross-Layer Consistency:**
- [ ] Lean symbolic state matches Move code structure
- [ ] MSL specifications match Lean theorems
- [ ] Difftest oracles match Lean axioms
- [ ] All three layers agree on abort conditions

**Bytecode Transcription:**
- [ ] Deployed bytecode matches verified Move source
- [ ] No handwritten bytecode modifications
- [ ] Bytecode hash recorded in audit trail

**CI/CD Validation:**
- [ ] All verification jobs pass
- [ ] No axiom drift detected
- [ ] Performance budgets met
- [ ] No regression in coverage

**Review Commands:**
```bash
# Full verification suite
./audit/verify-ca.sh

# Compare bytecode
aptos move compile --save-metadata
diff expected_bytecode.json current_bytecode.json
```

### Checklist L5: Security-Specific Review

**Threat Coverage:**
- [ ] All adversaries in threat model addressed
- [ ] All attack vectors have mitigations
- [ ] Known limitations documented

**Cryptographic Review:**
- [ ] All assumptions documented
- [ ] Security parameters meet target (≥126 bits)
- [ ] Constant-time implementations (Rust side)
- [ ] No custom crypto (use audited libraries)

**Privacy Review:**
- [ ] No plaintext balance leakage in events/errors
- [ ] Encrypted balances use fresh randomness
- [ ] Proofs don't leak witness information

**DoS Review:**
- [ ] Gas limits prevent unbounded loops
- [ ] Proof verification cost bounded
- [ ] Storage costs reasonable
- [ ] No resource exhaustion vectors

---

## Known Limitations and Trust Boundaries

### Limitation L1: Sender/Receiver Anonymity

**What's NOT Hidden:**
- Transaction sender address (visible on-chain)
- Transaction receiver address (visible on-chain)
- Transaction graph (who transacts with whom)

**What IS Hidden:**
- Transaction amounts
- User balances

**Implication:**
Confidential Assets provide **amount privacy**, not **sender/receiver privacy**. This is by design (simpler protocol, better performance).

**Mitigation Options (Out of Scope):**
- Mix networks (e.g., Tornado Cash style)
- Ring signatures (e.g., Monero style)
- zk-SNARKs (e.g., Zcash style)

These would require significant protocol changes and performance trade-offs.

### Limitation L2: Traffic Analysis

**What's Observable:**
- Transaction timing
- Transaction frequency
- Gas usage patterns
- Account creation times

**Attack Scenario:**
An adversary observing:
- Alice registers confidential balance at time T1
- Alice makes 5 transfers in quick succession at T2
- Alice withdraws to public balance at T3

Can infer:
- Alice's confidential activity pattern
- Approximate balance range (from gas costs)
- Correlation with public balance changes

**Mitigation:**
- Client-side batching (multiple operations in one transaction)
- Dummy transactions (pad activity)
- Network-layer privacy (Tor, VPN)

These are **client responsibilities**, not protocol guarantees.

### Limitation L3: Quantum Resistance

**Current State:**
All cryptographic primitives (ElGamal, Schnorr, SHA-512) are **quantum-vulnerable**.

**Timeline:**
- **Near-term (0-5 years)**: No practical threat
- **Medium-term (5-10 years)**: Large quantum computers may threaten 256-bit ECC
- **Long-term (10+ years)**: Migration to post-quantum crypto likely needed

**Migration Path:**
1. Protocol supports crypto agility (hash function is parameter)
2. Proof format is versioned
3. Can introduce post-quantum ZK systems (e.g., STARKs, Bulletproofs++)
4. Requires coordinated upgrade, re-registration of balances

**Trust Assumption:**
Security holds **assuming quantum computers remain impractical** during asset lifetime.

### Limitation L4: Validator Assumptions

**What Validators Can Do:**
- Observe all transaction data (encrypted balances, proofs)
- Reorder transactions within a block
- Censor transactions (subject to consensus liveness)

**What Validators CANNOT Do (Trust Assumptions):**
- Break cryptographic assumptions (DL, DDH)
- Forge user signatures
- Modify user proofs without detection
- Collude to fork chain (requires >1/3 stake)

**Implication:**
Confidential Assets rely on **consensus security**. If validators control >2/3 stake, they can:
- Halt the chain
- Censor all transactions
- Rewrite history

This is a **blockchain-level limitation**, not specific to Confidential Assets.

### Limitation L5: Native Function Trust

**Trust Boundary:**
Move verification proves that **if native functions behave as specified**, then security properties hold.

**What's NOT Verified:**
- Rust implementation of native functions
- Constant-time properties (side-channel resistance)
- Serialization format correctness

**Difftest Validation:**
Difftest validates oracle behavior against real VM execution, providing **empirical evidence** (not proof) that oracles match implementation.

**Risk Mitigation:**
- Use audited Rust libraries (curve25519-dalek, sha2)
- Independent security audit of native code
- Fuzzing of native functions
- Regular dependency updates

**Trust Assumption:**
Security holds **assuming native function implementations are correct**.

### Trust Boundary Diagram

```
┌─────────────────────────────────────────────────────────┐
│                  Verified Boundaries                     │
│  ┌────────────────────────────────────────────────────┐ │
│  │          Lean 4 Proofs (Math)                      │ │
│  │  - Symbolic execution correctness                  │ │
│  │  - Balance preservation                            │ │
│  │  - Proof soundness (modulo axioms)                 │ │
│  └────────────────────────────────────────────────────┘ │
│                         │                                │
│                         ▼                                │
│  ┌────────────────────────────────────────────────────┐ │
│  │          MSL Specifications (Logic)                │ │
│  │  - Functional correctness                          │ │
│  │  - Abort conditions                                │ │
│  │  - State invariants                                │ │
│  └────────────────────────────────────────────────────┘ │
│                         │                                │
│                         ▼                                │
│  ┌────────────────────────────────────────────────────┐ │
│  │          Move Source Code (Implementation)         │ │
│  │  - Public entry functions                          │ │
│  │  - Balance operations                              │ │
│  │  - Proof verification                              │ │
│  └────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────┐
│              Trust Boundaries (Unverified)               │
│  ┌────────────────────────────────────────────────────┐ │
│  │  Native Functions (Rust)                           │ │
│  │  - ristretto255 operations                         │ │
│  │  - SHA-512 hashing                                 │ │
│  │  - Schnorr verification                            │ │
│  │  Trust: Audited libraries + Difftest validation    │ │
│  └────────────────────────────────────────────────────┘ │
│                                                          │
│  ┌────────────────────────────────────────────────────┐ │
│  │  Cryptographic Assumptions                         │ │
│  │  - Discrete log hardness                           │ │
│  │  - DDH assumption                                  │ │
│  │  - Random oracle model                             │ │
│  │  Trust: >40 years of cryptanalysis                 │ │
│  └────────────────────────────────────────────────────┘ │
│                                                          │
│  ┌────────────────────────────────────────────────────┐ │
│  │  Blockchain Consensus                              │ │
│  │  - Validator honesty (<1/3 Byzantine)              │ │
│  │  - Transaction ordering                            │ │
│  │  - Liveness guarantees                             │ │
│  │  Trust: Aptos consensus protocol                   │ │
│  └────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

---

## Side-Channel Considerations

### Side-Channel S1: Timing Attacks

**Attack Scenario:**
Adversary measures execution time of proof verification to infer information about witness (e.g., private key, balance amount).

**Where Applicable:**
- Client-side proof generation (wallet software)
- Validator-side proof verification (less critical, no private data)

**Mitigation (Client Side):**
- Constant-time scalar multiplication (curve25519-dalek provides this)
- Constant-time field arithmetic
- Avoid branching on secret data

**Verification Status:**
- **Not verified in Lean/MSL**: Timing properties are implementation-specific
- **Responsibility**: Wallet developers, Rust library maintainers
- **Recommendation**: Use audited constant-time libraries (curve25519-dalek, subtle crate)

**Review Checklist:**
- [ ] Rust implementation uses constant-time libraries
- [ ] No branching on secret scalars
- [ ] Blinding used in exponentiation if needed

### Side-Channel S2: Power/EM Analysis

**Attack Scenario:**
Adversary with physical access to device measures power consumption or electromagnetic emissions during proof generation.

**Where Applicable:**
- Hardware wallets
- Mobile devices
- IoT devices

**Mitigation:**
- Hardware-level protections (shielding, noise injection)
- Algorithm-level protections (masking, blinding)

**Verification Status:**
- **Out of scope** for protocol verification
- **Responsibility**: Hardware wallet vendors, device manufacturers

### Side-Channel S3: Cache Timing

**Attack Scenario:**
Adversary sharing CPU cache with victim observes cache access patterns to infer secret data.

**Where Applicable:**
- Shared hosting environments
- Browsers (if proof generation in WASM)

**Mitigation:**
- Cache-timing-resistant implementations
- Avoid secret-dependent memory access patterns
- Use constant-time table lookups

**Verification Status:**
- **Not verified**: Cache behavior is microarchitecture-specific
- **Recommendation**: Use audited libraries, test in production environment

### Side-Channel S4: Fault Injection

**Attack Scenario:**
Adversary induces faults (voltage glitching, clock manipulation) to skip security checks or extract secrets.

**Where Applicable:**
- Hardware wallets (physical access required)
- Embedded devices

**Mitigation:**
- Redundant security checks
- Fault detection (checksums, redundant computation)
- Hardware countermeasures

**Verification Status:**
- **Out of scope** for protocol verification
- **Responsibility**: Hardware vendors

### Side-Channel Responsibility Matrix

| Attack Vector | Client/Wallet | Validator | Protocol | Status |
|---------------|---------------|-----------|----------|--------|
| Timing attacks | Critical | Low risk | N/A | Use constant-time libs |
| Power analysis | Critical | N/A | N/A | Hardware protection |
| Cache timing | Medium | Low | N/A | Use resistant libs |
| Fault injection | Critical | Low | N/A | Hardware protection |

**Key Takeaway:**
Side-channel protection is primarily a **client/wallet responsibility**, not a protocol-level guarantee. Protocol verification ensures **logical correctness**, not **physical security**.

---

## Review Workflow and Sign-Off

### Review Phase 1: Automated Verification (Daily)

**Trigger:** Every commit to `lean-fv` branch

**CI/CD Jobs:**
1. **Lean verification** (6 min budget)
   - Build all proofs
   - Check for `sorry`
   - Detect axiom additions
   
2. **MSL verification** (2 min budget)
   - Run Move Prover on all specs
   - Check for timeout regressions
   
3. **Difftest validation** (3 min budget)
   - Run full scenario corpus
   - Validate oracle behavior
   
4. **Performance check** (2 min budget)
   - Profile slow files
   - Check against budgets

**Pass Criteria:**
- [ ] All verification jobs pass
- [ ] No new `sorry` added
- [ ] No axiom count increase
- [ ] No performance regression >10%
- [ ] No test failures

**Automated Actions:**
- Slack notification on failure
- Block merge if checks fail
- Generate performance report

### Review Phase 2: Human Review (Per PR)

**Reviewer:** Verification engineer (peer review)

**Scope:**
- Code changes since last review
- New proofs or specifications
- Modified axioms

**Checklist:**
- [ ] All modified files pass verification
- [ ] Code follows style guide
- [ ] Proofs have clear structure
- [ ] Specifications are complete
- [ ] Tests cover new functionality

**Review Time:** 30-60 min per PR

**Sign-Off:** PR approval required before merge

### Review Phase 3: Security Review (Per Release)

**Reviewer:** Security lead + external auditor

**Scope:**
- All code since last release
- New attack vectors
- Cryptographic assumptions
- Trust boundary changes

**Checklist:**
- [ ] Threat model up to date
- [ ] All attack vectors addressed
- [ ] No new trust assumptions without justification
- [ ] Cryptographic parameters meet security target
- [ ] Side-channel considerations documented
- [ ] Known limitations disclosed

**Deliverables:**
- Security review report
- Updated threat model
- Audit findings log

**Review Time:** 1-2 weeks per major release

**Sign-Off:** Security lead + CTO approval

### Review Phase 4: Audit Package Validation (Pre-Release)

**Reviewer:** Release manager

**Scope:**
- Complete audit package
- Reproducible builds
- Documentation completeness

**Validation Script:**
```bash
#!/bin/bash
# validate_audit_package.sh

set -e

echo "=== Audit Package Validation ==="

# 1. Check package structure
echo "Checking package structure..."
required_files=(
    "CLAIMS.md"
    "CLAIMS_SUMMARY.md"
    "AXIOM_INVENTORY.md"
    "TRUST_BOUNDARIES.md"
    "BYTECODE_TRANSCRIPTION_GUIDE.md"
    "verify-ca.sh"
)

for file in "${required_files[@]}"; do
    if [ ! -f "audit/$file" ]; then
        echo "❌ Missing required file: $file"
        exit 1
    fi
done

# 2. Run full verification
echo "Running full verification suite..."
./audit/verify-ca.sh

# 3. Check axiom count
echo "Validating axiom count..."
axiom_count=$(./scripts/check_axioms.sh | grep -c "axiom")
if [ "$axiom_count" -ne 23 ]; then
    echo "❌ Expected 23 axioms, found $axiom_count"
    exit 1
fi

# 4. Verify no sorry
echo "Checking for incomplete proofs..."
if grep -r "sorry" lean/MovementFormal/Experimental/ConfidentialAsset/ --include="*.lean" | grep -v "TEMPORARY"; then
    echo "❌ Found sorry in production proofs"
    exit 1
fi

# 5. Performance check
echo "Validating performance..."
time lake build MovementFormal.Experimental.ConfidentialAsset
# Should complete in <10 min

# 6. Difftest coverage
echo "Checking Difftest coverage..."
coverage=$(cargo test --release 2>&1 | grep "test result" | grep -oP '\d+(?= passed)')
if [ "$coverage" -lt 97 ]; then
    echo "❌ Coverage below 97%: $coverage"
    exit 1
fi

echo "✅ Audit package validation passed"
```

**Pass Criteria:**
- [ ] All required files present
- [ ] Full verification suite passes
- [ ] Axiom count is 23 (or justified increase)
- [ ] No `sorry` in production code
- [ ] Performance meets budgets
- [ ] Difftest coverage ≥95%

### Sign-Off Authority Matrix

| Review Phase | Reviewer | Authority | Blocks |
|--------------|----------|-----------|--------|
| Automated | CI/CD | Verification engineers | PR merge |
| Human review | Peer | Verification engineers | PR merge |
| Security review | Security lead | CTO | Release |
| Audit validation | Release manager | Security + CTO | Release |

### Emergency Bypass Procedure

**When Allowed:**
- Critical security patch (0-day exploit)
- Production outage
- Consensus failure

**Requirements:**
- [ ] CTO approval
- [ ] Incident ticket created
- [ ] Rollback plan documented
- [ ] Post-mortem scheduled

**Process:**
1. Create emergency branch
2. Apply minimal fix
3. Deploy to production
4. File technical debt ticket
5. Complete full review within 1 week

**Post-Mortem:**
- Root cause analysis
- Process improvements
- Update review procedures

---

## Security Regression Testing

### Regression Test R1: Proof Breakage Detection

**Goal:** Detect when code changes break existing proofs

**Mechanism:**
- Pre-commit hook checks for new `sorry`
- CI/CD runs full Lean build on every commit
- Diff report shows which proofs broke

**Detection Script:**
```bash
#!/bin/bash
# check_proof_regression.sh

set -e

echo "=== Proof Regression Check ==="

# Get list of sorry from main branch
git fetch origin movement
git diff origin/movement...HEAD --name-only | grep "\.lean$" > changed_files.txt

# For each changed file, check sorry count
while read file; do
    old_sorry=$(git show origin/movement:$file | grep -c "sorry" || echo 0)
    new_sorry=$(grep -c "sorry" "$file" || echo 0)
    
    if [ "$new_sorry" -gt "$old_sorry" ]; then
        echo "❌ Proof regression in $file: $old_sorry → $new_sorry sorry"
        exit 1
    fi
done < changed_files.txt

echo "✅ No proof regressions detected"
```

**Response SLA:**
- **Detection**: Immediate (pre-commit)
- **Fix**: <1 hour (block merge until resolved)

### Regression Test R2: Axiom Creep Detection

**Goal:** Detect unauthorized axiom additions

**Mechanism:**
- `check_axioms.sh` counts axioms in every file
- CI/CD compares against baseline (23 axioms)
- Diff report shows new axioms

**Detection Script:**
```bash
#!/bin/bash
# check_axiom_drift.sh

set -e

BASELINE=23

current=$(./scripts/check_axioms.sh | grep -c "axiom")

if [ "$current" -gt "$BASELINE" ]; then
    echo "❌ Axiom count increased: $BASELINE → $current"
    echo "New axioms require security review"
    exit 1
fi

echo "✅ Axiom count stable: $current"
```

**Response SLA:**
- **Detection**: Immediate (pre-commit)
- **Review**: <1 day (security lead approval required)

### Regression Test R3: Performance Degradation

**Goal:** Detect when changes slow down verification

**Mechanism:**
- CI/CD profiles build times
- Compare against performance budget
- Report files that exceed budget

**Detection Script:**
```bash
#!/bin/bash
# check_performance_regression.sh

set -e

BUDGET_SECONDS=180  # 3 min per file

echo "=== Performance Regression Check ==="

# Build with profiling
lake build --profile MovementFormal.Experimental.ConfidentialAsset 2>&1 | tee build.log

# Parse slow files
slow_files=$(grep "elaboration time" build.log | awk '$3 > '$BUDGET_SECONDS' {print $1, $3}')

if [ -n "$slow_files" ]; then
    echo "❌ Files exceeding budget:"
    echo "$slow_files"
    exit 1
fi

echo "✅ All files within performance budget"
```

**Response SLA:**
- **Detection**: Immediate (CI/CD)
- **Fix**: <1 day (optimize or increase budget with justification)

### Regression Test R4: Coverage Decrease

**Goal:** Detect when Difftest coverage decreases

**Mechanism:**
- Run full Difftest corpus on every commit
- Compare pass count against baseline
- Report new failures

**Detection Script:**
```bash
#!/bin/bash
# check_coverage_regression.sh

set -e

BASELINE=97  # scenarios

echo "=== Coverage Regression Check ==="

cd difftest
current=$(cargo test --release 2>&1 | grep "test result" | grep -oP '\d+(?= passed)')

if [ "$current" -lt "$BASELINE" ]; then
    echo "❌ Coverage decreased: $BASELINE → $current"
    exit 1
fi

echo "✅ Coverage stable: $current passed"
```

**Response SLA:**
- **Detection**: Immediate (CI/CD)
- **Fix**: <1 hour (fix test or update baseline with justification)

### Regression Test R5: MSL Spec Completeness

**Goal:** Detect when functions lose specifications

**Mechanism:**
- Parse Move code for public functions
- Check each has corresponding spec
- Report unspecified functions

**Detection Script:**
```bash
#!/bin/bash
# check_spec_completeness.sh

set -e

echo "=== Specification Completeness Check ==="

cd aptos-move/framework/aptos-experimental/sources/confidential_asset

# Extract public functions
public_fns=$(grep "public fun" *.move | cut -d: -f2 | awk '{print $3}' | cut -d'(' -f1)

# Check each has spec
for fn in $public_fns; do
    if ! grep -q "fun $fn" *.spec.move; then
        echo "❌ Function $fn has no specification"
        exit 1
    fi
done

echo "✅ All public functions specified"
```

**Response SLA:**
- **Detection**: Immediate (CI/CD)
- **Fix**: <1 day (add missing spec)

---

## Incident Response Procedures

### Incident I1: Security Vulnerability Discovered

**Severity Levels:**

**Critical (P0):**
- Balance theft possible
- Fund creation from nothing
- Consensus failure
- **Response time**: <1 hour
- **Escalation**: CTO, Security lead, All hands

**High (P1):**
- Privacy violation (balance deanonymization)
- DoS attack vector
- Proof forgery under specific conditions
- **Response time**: <4 hours
- **Escalation**: Security lead, Verification team

**Medium (P2):**
- Performance degradation
- Incomplete specifications
- Missing test coverage
- **Response time**: <1 day
- **Escalation**: Verification team

**Low (P3):**
- Documentation gaps
- Code style issues
- Minor optimization opportunities
- **Response time**: <1 week
- **Escalation**: Normal PR process

### Response Workflow

**Step 1: Triage (15 min)**
1. Assign severity level (P0-P3)
2. Identify affected components
3. Estimate blast radius
4. Create incident ticket

**Step 2: Contain (P0: 30 min, P1: 2 hours)**
1. If production vulnerability:
   - Alert operations team
   - Consider emergency chain halt (P0 only)
   - Disable affected functionality if possible
2. If pre-production:
   - Block merges to affected code
   - Revert if recently introduced

**Step 3: Investigate (P0: 2 hours, P1: 1 day)**
1. Reproduce vulnerability
2. Identify root cause
3. Assess impact on deployed contracts
4. Determine fix approach

**Step 4: Fix (P0: 4 hours, P1: 2 days)**
1. Implement minimal fix
2. Add regression test
3. Update verification:
   - Lean proof if logic bug
   - MSL spec if specification gap
   - Difftest scenario if edge case
4. Emergency review (security lead)

**Step 5: Deploy (P0: 2 hours, P1: 1 week)**
1. If production:
   - Coordinate with operations
   - Deploy via emergency procedure
   - Monitor for issues
2. If pre-production:
   - Normal merge + deploy process

**Step 6: Post-Mortem (Within 1 week)**
1. Document timeline
2. Root cause analysis
3. Process improvements
4. Update threat model
5. Share learnings

### Incident Examples

**Example 1: Proof Replay Attack (P0)**

**Discovery:**
External researcher reports that withdrawal proofs can be replayed to withdraw multiple times.

**Triage:**
- Severity: P0 (balance theft)
- Impact: All deployed confidential balances
- Root cause: Challenge doesn't include transaction nonce

**Contain:**
- Emergency chain halt
- Disable all withdrawal transactions

**Fix:**
- Add nonce to challenge computation:
  ```move
  challenge = sha512(DST || context || nonce || public_inputs)
  ```
- Update Lean proof to model nonce
- Add Difftest scenario for replay attack

**Deploy:**
- Emergency upgrade contract
- Restart chain after validator consensus

**Post-Mortem:**
- Add nonce to all proof challenges
- Update MSL specs with nonce requirements
- Expand Difftest to include all replay vectors

**Example 2: Timing Side-Channel (P1)**

**Discovery:**
Academic paper demonstrates timing attack on proof verification reveals balance amount.

**Triage:**
- Severity: P1 (privacy violation)
- Impact: Client implementations (wallets)
- Root cause: Variable-time scalar multiplication

**Contain:**
- Alert wallet developers
- Recommend users upgrade immediately

**Fix:**
- Update Rust implementation to use constant-time functions
- Add documentation on side-channel requirements
- Consider adding test vectors for timing

**Deploy:**
- Release updated native function library
- Coordinate with wallet vendors

**Post-Mortem:**
- Add side-channel section to security docs
- Establish constant-time testing in CI
- Review all cryptographic operations

---

## Cross-References

### Related Documentation

**Verification Infrastructure:**
- `CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md` - Overall verification strategy
- `PHASE_6_PC_CHAINING_DETAILED_TUTORIAL.md` - Lean proof implementation
- `MSL_DEBUGGING_AND_VERIFICATION_GUIDE.md` - Move Prover workflows
- `DIFFTEST_CORPUS_EXPANSION_STRATEGY_GUIDE.md` - Test coverage strategy

**Audit Materials:**
- `audit/CLAIMS.md` - Security claims and verification status
- `audit/TRUST_BOUNDARIES.md` - Trust assumptions and limitations
- `audit/AXIOM_INVENTORY.md` - Complete axiom catalog with justifications
- `audit/COMPOSITION_CLAIMS.md` - How layers compose for end-to-end security

**Performance and Operations:**
- `LEAN_PERFORMANCE_OPTIMIZATION_GUIDE.md` - Performance tuning
- `CI_CD_PIPELINE_COMPREHENSIVE_GUIDE.md` - Automation and gates
- `REGRESSION_PREVENTION_AND_CONTINUOUS_VERIFICATION_GUIDE.md` - Quality assurance

**Theory and Background:**
- `SIGMA_PROTOCOL_THEORY_AND_PRACTICE.md` - Cryptographic foundations
- `MSL_SPECIFICATION_PATTERNS_GUIDE.md` - Specification techniques

### External Resources

**Cryptographic Foundations:**
- [Ristretto255 Specification](https://ristretto.group/) - Curve implementation
- [Fiat-Shamir Transform](https://en.wikipedia.org/wiki/Fiat%E2%80%93Shamir_heuristic) - Non-interactive proofs
- [ElGamal Encryption](https://en.wikipedia.org/wiki/ElGamal_encryption) - Homomorphic encryption

**Verification Tools:**
- [Lean 4 Documentation](https://lean-lang.org/documentation/) - Proof assistant
- [Move Prover Guide](https://github.com/move-language/move/tree/main/language/move-prover) - Specification language
- [Aptos Framework](https://github.com/aptos-labs/aptos-core) - Blockchain platform

**Security Standards:**
- [NIST Post-Quantum Cryptography](https://csrc.nist.gov/projects/post-quantum-cryptography) - Future crypto
- [OWASP Smart Contract Security](https://owasp.org/www-project-smart-contract-top-10/) - Common vulnerabilities

---

## Maintenance and Updates

### Review Schedule

**Monthly:**
- [ ] Update threat model with new attack vectors
- [ ] Review and close incident tickets
- [ ] Update coverage metrics
- [ ] Performance profiling

**Quarterly:**
- [ ] Full security review
- [ ] Cryptographic assumption review
- [ ] Update external audit package
- [ ] Side-channel threat assessment

**Annually:**
- [ ] Comprehensive security audit (external)
- [ ] Threat model revision
- [ ] Update post-quantum migration plan
- [ ] Review trust boundaries

### Document Ownership

- **Author**: Verification team
- **Reviewers**: Security lead, External auditor
- **Approver**: CTO
- **Last Review**: 2026-04-22
- **Next Review**: 2026-07-22 (quarterly)

### Feedback and Improvements

Questions or suggestions? Contact:
- **Security issues**: security@movementlabs.xyz
- **Verification questions**: verification-team@movementlabs.xyz
- **General feedback**: GitHub issues in aptos-core repo

---

**End of Guide**

Total pages: ~35 (~30K characters)
