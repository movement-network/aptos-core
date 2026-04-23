# Sigma Protocol Theory and Practice Guide

**Audience:** Cryptographers, verification engineers, security auditors  
**Prerequisites:** Basic cryptography (discrete log, hash functions), Lean basics  
**Related:** `NATIVE_FUNCTION_ORACLE_MODELING_GUIDE.md`, `CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md` §4

## Purpose

This guide provides comprehensive coverage of sigma protocols as used in Confidential Assets, bridging theory and implementation:
- Mathematical foundations (Sigma protocol definition, soundness, zero-knowledge)
- CA-specific sigma protocols (Registration, Withdrawal, Transfer, Normalization, Rotation)
- Lean formalization patterns
- Fiat-Shamir transform for non-interactivity
- Verification methodology
- Security analysis

## Table of Contents

1. [Sigma Protocol Foundations](#sigma-protocol-foundations)
2. [CA Sigma Protocols Catalog](#ca-sigma-protocols-catalog)
3. [Lean Formalization Patterns](#lean-formalization-patterns)
4. [Fiat-Shamir Transform](#fiat-shamir-transform)
5. [Verification Methodology](#verification-methodology)
6. [Security Analysis](#security-analysis)
7. [Implementation Notes](#implementation-notes)
8. [Troubleshooting](#troubleshooting)

---

## Sigma Protocol Foundations

### 1.1 What is a Sigma Protocol?

A **sigma protocol** (Σ-protocol) is a three-move interactive proof of knowledge:

```
Prover                                     Verifier
-------                                    --------
  Secret: w
  Statement: x ∈ L

  commitment ← commit(x, w)      ──────>
                                 <──────    challenge ← random()
  response ← prove(x, w, ch)     ──────>
                                           accept/reject ← verify(x, com, ch, resp)
```

**Properties (required for sigma protocol):**
1. **Completeness:** Honest prover convinces honest verifier
2. **Special soundness:** Two accepting transcripts with same commitment but different challenges → extract witness
3. **Honest-verifier zero-knowledge (HVZK):** Simulator can generate accepting transcripts indistinguishable from real, without witness

### 1.2 Schnorr Protocol (Canonical Example)

**Statement:** "I know discrete log x such that X = g^x"

```
Prover (knows x)                           Verifier
----------------                           --------
  r ← random scalar
  R := g^r                       ──────>
                                 <──────    c ← random challenge
  s := r + c·x (mod q)           ──────>
                                           Accept iff g^s = R · X^c
```

**Completeness:** g^s = g^(r+cx) = g^r · g^(cx) = R · X^c ✓

**Special soundness:** Given (R, c, s) and (R, c', s') both accepting:
- g^s = R · X^c
- g^s' = R · X^c'
- Divide: g^(s-s') = X^(c-c')
- Extract: x = (s - s') / (c - c') mod q

**HVZK:** Simulator(X, c):
- s ← random
- R := g^s / X^c
- Output (R, c, s) — indistinguishable from real transcript

### 1.3 Sigma Protocol Composition

**Parallel composition (AND):** Prove knowledge of (w1 AND w2)
- Run both protocols in parallel with SAME challenge
- Soundness preserved (can extract both w1 and w2)
- Zero-knowledge preserved (simulate both)

**OR composition:** Prove knowledge of (w1 OR w2) — more complex, not used in CA

### 1.4 Fiat-Shamir Transform

**Problem:** Interactive protocols impractical for blockchain (no verifier interaction)

**Solution:** Replace random challenge with hash of commitment + context:

```
Non-interactive:
  r ← random
  R := g^r
  c := H(context || R)    ← Challenge = hash, not random
  s := r + c·x
  
  Proof = (R, s)
  
  Verify: c := H(context || R), check g^s = R · X^c
```

**Security:** Assumes random oracle model (hash function is "perfect" random function)

**CA uses:** SHA-512 as hash function, context includes domain separation tag (DST)

---

## CA Sigma Protocols Catalog

### 2.1 Registration Protocol (Schnorr on ElGamal)

**Statement:** "I know secret key sk such that ek = g^sk (ElGamal public key)"

**Purpose:** Prove ownership of encryption key during account registration

**Prover input:**
- Secret: `sk` (scalar, private key)
- Public: `ek = g^sk` (Ristretto point, encryption key)
- Context: `(chain_id, sender, contract, token)`

**Protocol:**
```
Commitment: R = g^r  (r ← random scalar)
Challenge: c = SHA512(DST || chain_id || sender || contract || ek || token || R)
Response: s = r + c·sk  (mod q)

Proof: (R, s)
Verification: g^s = R · ek^c
```

**Domain separation tag (DST):**
```
DST = "APTOS_CONFIDENTIAL_ASSET_REGISTRATION_V1"
```

**Lean formalization:**
```lean
structure RegistrationProof where
  commitment : RistrettoPoint
  response : Scalar

def verifyRegistrationProof (proof : RegistrationProof) (ek : RistrettoPoint) (context : Context) : Bool :=
  let challenge := sha512(DST || encodeContext(context) || encode(ek) || encode(proof.commitment))
  scalarMultBase(proof.response) == proof.commitment + scalarMult(challenge, ek)
```

**Security:** Soundness follows from DLog hardness. HVZK from Schnorr simulation.

### 2.2 Withdrawal Protocol (Decryption Proof)

**Statement:** "I know secret key sk and randomness r such that ElGamal_decrypt(ciphertext, sk) = amount"

**Purpose:** Prove correct decryption of encrypted balance during withdrawal

**Prover input:**
- Secret: `sk` (encryption key), `r_bal` (balance randomness)
- Public: `ek = g^sk`, `ct = (C, D) = (g^r_bal, g^amount · ek^r_bal)` (ciphertext)
- Claim: `amount` (withdrawal amount)

**Protocol:** Proves knowledge of sk such that:
1. `ek = g^sk` (key correctness)
2. `D / C^sk = g^amount` (decryption correctness)

This is TWO Schnorr proofs run in parallel (same challenge):

```
Commitment: R1 = g^r1, R2 = C^r1  (r1 ← random)
Challenge: c = SHA512(DST || context || ek || ct || amount || R1 || R2)
Response: s = r1 + c·sk

Proof: (R1, R2, s)
Verification:
  1. g^s = R1 · ek^c  (key correctness)
  2. C^s = R2 · (D / g^amount)^c  (decryption correctness)
```

**Domain separation tag:**
```
DST = "APTOS_CONFIDENTIAL_ASSET_WITHDRAWAL_V1"
```

**Lean formalization:**
```lean
structure WithdrawalProof where
  commitment1 : RistrettoPoint
  commitment2 : RistrettoPoint
  response : Scalar

def verifyWithdrawalProof (proof : WithdrawalProof) 
    (ek : RistrettoPoint) (ct : ElGamalCiphertext) (amount : Scalar) (context : Context) : Bool :=
  let challenge := sha512(DST || encodeContext(context) || encode(ek) || encode(ct) || encode(amount) || encode(proof.commitment1) || encode(proof.commitment2))
  let check1 := scalarMultBase(proof.response) == proof.commitment1 + scalarMult(challenge, ek)
  let check2 := scalarMult(proof.response, ct.C) == proof.commitment2 + scalarMult(challenge, ct.D - scalarMultBase(amount))
  check1 && check2
```

**Security:** Parallel composition of Schnorr → soundness and HVZK preserved

### 2.3 Transfer Protocol (Balance Consistency)

**Statement:** "I know old balance, new balance, transfer amount, and randomness such that encrypted balances are consistent"

**Purpose:** Prove that transfer decrements sender balance and increments recipient balance correctly (encrypted)

**Prover input:**
- Secret: `sk_sender`, `r_old`, `r_new`, `r_amt` (scalars)
- Public: `ek_sender`, `ek_recipient`, `ct_old`, `ct_new_sender`, `ct_new_recipient`, `ct_amt`
- Claim: Encrypted values consistent with `ct_old - ct_amt = ct_new_sender` and `ct_new_recipient = ct_amt`

**Protocol:** Multiple Schnorr proofs in parallel (6 checks):
1. Sender key ownership: `ek_sender = g^sk_sender`
2. Old balance decryption consistency
3. New sender balance consistency (old - amt)
4. Amount ciphertext well-formed
5. Recipient balance increment consistency
6. Auditor copy consistency (if auditor enabled)

```
Commitments: R1, R2, ..., R6 (all using same randomness r)
Challenge: c = SHA512(DST || context || all public values || all commitments)
Responses: s1, s2, ..., s6 (each s_i = r + c·witness_i)

Proof: (R1, ..., R6, s1, ..., s6)
Verification: All 6 Schnorr checks pass
```

**Domain separation tag:**
```
DST = "APTOS_CONFIDENTIAL_ASSET_TRANSFER_V1"
```

**Complexity:** Transfer is the most complex sigma protocol in CA (6 parallel Schnorr proofs)

**Lean formalization:** See `Transfer/EvalEquiv.lean` lines 200-600 for full bytecode transcription

### 2.4 Normalization Protocol (ElGamal Re-Randomization)

**Statement:** "I know secret key sk and old/new randomness such that normalization re-randomizes ciphertext without changing plaintext"

**Purpose:** Prove that normalization operation produces fresh ciphertext of same balance (privacy refresh)

**Prover input:**
- Secret: `sk`, `r_old`, `r_new`
- Public: `ek`, `ct_old`, `ct_new`
- Claim: `ct_new` is re-randomization of `ct_old` (same plaintext, fresh randomness)

**Protocol:** Proves:
1. Key ownership: `ek = g^sk`
2. Re-randomization correctness: `ct_new = ct_old · ElGamal(0, r_delta)` where `r_delta = r_new - r_old`

```
Commitment: R1 = g^r, R2 = ct_old.C^r  (r ← random)
Challenge: c = SHA512(DST || context || ek || ct_old || ct_new || R1 || R2)
Response: s = r + c·sk

Verification:
  1. g^s = R1 · ek^c
  2. ct_new.C^s / ct_old.C^s = R2 · (ct_new.D / ct_old.D)^c
```

**Domain separation tag:**
```
DST = "APTOS_CONFIDENTIAL_ASSET_NORMALIZATION_V1"
```

**Security:** Re-randomization preserves plaintext (soundness) and hides which output corresponds to which input (zero-knowledge)

### 2.5 Rotation Protocol (Key Rotation)

**Statement:** "I know both old and new secret keys, and can decrypt with both"

**Purpose:** Prove ownership of both old and new encryption keys during key rotation

**Prover input:**
- Secret: `sk_old`, `sk_new`
- Public: `ek_old = g^sk_old`, `ek_new = g^sk_new`, `ct_old` (encrypted balance)
- Claim: Can decrypt `ct_old` with `sk_old` AND owns `sk_new`

**Protocol:** Two parallel Schnorr proofs:
1. Old key ownership + decryption
2. New key ownership

```
Commitments: R1 = g^r, R2 = ct_old.C^r  (r ← random)
Challenge: c = SHA512(DST || context || ek_old || ek_new || ct_old || R1 || R2)
Responses: s_old = r + c·sk_old, s_new = r + c·sk_new

Verification:
  1. g^s_old = R1 · ek_old^c
  2. ct_old.C^s_old = R2 · ct_old.D^c
  3. g^s_new = R1 · ek_new^c
```

**Domain separation tag:**
```
DST = "APTOS_CONFIDENTIAL_ASSET_ROTATION_V1"
```

**Security:** Ensures user can decrypt existing balance AND controls new key (prevents key loss)

---

## Lean Formalization Patterns

### 3.1 Oracle-Based Verification Model

CA verifies sigma protocols via native Rust functions (Ristretto arithmetic, SHA-512). Lean models these as oracles:

```lean
structure RegistrationOracle where
  verifyProof : RegistrationProof → EncryptionKey → Context → OracleResult

axiom verifyProof_sound :
  ∀ oracle proof ek ctx,
    oracle.verifyProof proof ek ctx = .success →
    ∃ sk, ek = scalarMultBase sk ∧ proofIsValid proof ek sk ctx
```

**Pattern:**
1. Define oracle interface (function signature)
2. State soundness axiom (if oracle says "accept", witness exists)
3. Optionally: completeness axiom (if witness exists, oracle accepts)
4. Optionally: zero-knowledge axiom (simulator exists)

**Why oracles:** Ristretto point arithmetic and SHA-512 are too complex to fully formalize in Lean. Oracle approach:
- Keeps Lean proofs tractable (no EC arithmetic in Lean)
- Soundness relies on crypto assumptions (DLog, ROM) + oracle correctness
- Oracle correctness validated by difftest (VM ↔ Lean on concrete inputs)

### 3.2 Functional Simulation Pattern

**Goal:** Prove bytecode ≡ mathematical predicate

**Approach:**
1. Define functional simulation (mathematical spec):
   ```lean
   def verifyRegistrationBytecodeResult (oracle : Oracle) (args : List MoveValue) : ExecResult :=
     match extractProofAndContext args with
     | .error => .error
     | .ok (proof, ek, ctx) =>
         match oracle.verifyProof proof ek ctx with
         | .success => .returned []
         | .failed => .aborted ESIGMA_PROTOCOL_VERIFY_FAILED
         | .error => .error
   ```

2. Prove bytecode eval equals functional sim:
   ```lean
   theorem registration_eval_equiv_functional_sim :
       eval env verifyRegistrationProofIdx args fuel = 
       verifyRegistrationBytecodeResult oracle args :=
     by
       unfold eval verifyRegistrationBytecodeResult
       -- PC-by-PC step proof...
       sorry  -- (Phase 6 work)
   ```

**Why functional sim:** Separates concerns:
- Bytecode verification (Lean): instruction semantics, control flow
- Crypto verification (assumptions): sigma protocol soundness

### 3.3 Error Path Handling

Sigma verification has 3 outcomes:
1. **Success:** Proof valid, prover knows witness
2. **Failed:** Proof invalid (prover doesn't know witness, or malformed proof)
3. **Error:** Malformed input (can't parse proof struct)

**Lean pattern:**
```lean
inductive OracleResult
  | success
  | failed
  | error

def handleOracleResult (result : OracleResult) : ExecResult :=
  match result with
  | .success => .returned []  -- Accept
  | .failed => .aborted ESIGMA_PROTOCOL_VERIFY_FAILED  -- Reject proof
  | .error => .error  -- Malformed input
```

**Bytecode must distinguish:** Failed proof (user error, abort code 65537) vs malformed input (VM error, no abort code)

### 3.4 Composition Lemmas

**Goal:** Compose per-operation proofs into end-to-end claims

**Pattern:**
```lean
-- Per-operation: bytecode ≡ functional sim
theorem registration_eval_equiv : eval env idx args = functionalSim oracle args

-- Refinement: functional sim ≡ cryptographic predicate
theorem functionalSim_refines_crypto :
  functionalSim oracle args = .returned [] →
  ∃ sk, ekFromArgs args = scalarMultBase sk

-- Composition: bytecode ↔ crypto
theorem registration_sound :
  eval env idx args = .returned [] →
  ∃ sk, ekFromArgs args = scalarMultBase sk :=
  by
    intro h
    rw [registration_eval_equiv] at h
    exact functionalSim_refines_crypto h
```

**Current status (Phase 6):** `eval_equiv` theorems complete for all 4 operations. Refinement and composition lemmas scaffolded with `sorry`.

---

## Fiat-Shamir Transform

### 4.1 Challenge Derivation

**CA convention:** Challenge = SHA-512(DST || context || public inputs || commitments)

**Components:**
- **DST (Domain Separation Tag):** Prevents cross-protocol attacks (registration proof ≠ withdrawal proof)
- **Context:** Chain ID, sender, contract, token (binds proof to transaction context)
- **Public inputs:** Encryption keys, ciphertexts, amounts (statement being proved)
- **Commitments:** R1, R2, ... (prover's first move)

**Encoding:** All values serialized to bytes before hashing:
- Scalars: 32 bytes little-endian
- Points: 32 bytes compressed Ristretto
- Addresses: 32 bytes
- u8: 1 byte

**Example (Registration):**
```
DST = b"APTOS_CONFIDENTIAL_ASSET_REGISTRATION_V1"
context_bytes = chain_id (1 byte) || sender (32 bytes) || contract (32 bytes) || token (32 bytes)
ek_bytes = compress(ek)  // 32 bytes
R_bytes = compress(R)    // 32 bytes

challenge_preimage = DST || context_bytes || ek_bytes || R_bytes
challenge_hash = SHA512(challenge_preimage)  // 64 bytes
challenge_scalar = scalar_from_bytes_mod_order(challenge_hash[0..32])  // First 32 bytes, reduced mod q
```

### 4.2 Security Implications

**Random Oracle Model (ROM):** Security proof assumes SHA-512 is indistinguishable from truly random function

**Practical:** SHA-512 not actually random oracle, but no known attacks on Fiat-Shamir + SHA-512 in this context

**DST importance:** Without DST, proof for one protocol could be replayed as proof for another:
- Registration proof might verify as withdrawal proof (if public inputs overlap)
- DST makes challenge computation protocol-specific → prevents replay

**Context importance:** Without context, proof could be replayed across different chains/accounts:
- Attacker proves on testnet, replays on mainnet
- Context binding prevents this

### 4.3 Implementation Notes

**SHA-512 vs SHA-256:** CA uses SHA-512 (64-byte output) for 256-bit security margin. First 32 bytes taken as scalar.

**Canonical encoding:** All serialization must be deterministic and canonical:
- Ristretto points: compressed form (32 bytes)
- Scalars: little-endian (32 bytes)
- No length prefixes (lengths implicit from types)

**Difftest validation:** Challenge computation tested end-to-end via difftest:
```rust
#[test]
fn test_registration_challenge_computation() {
    let proof = RegistrationProof { commitment: R, response: s };
    let challenge_lean = lean_compute_challenge(ctx, ek, R);
    let challenge_rust = rust_compute_challenge(ctx, ek, R);
    assert_eq!(challenge_lean, challenge_rust);
}
```

---

## Verification Methodology

### 5.1 Three-Layer Verification Stack

**Layer 1 (Lean): Bytecode ↔ Functional Simulation**
- Proves: `eval verifyProofCode args = functionalSim oracle args`
- Guarantees: Bytecode correctly implements oracle-based verification
- Does NOT prove: Oracle is sound

**Layer 2 (Assumptions/Axioms): Oracle Soundness**
- Assumes: Oracle soundness axiom
  ```lean
  axiom oracle_sound :
    oracle.verify proof = .success →
    ∃ witness, relation(witness, publicInputs)
  ```
- Guarantees: If oracle accepts, witness exists (soundness)
- Does NOT prove: Oracle implementation correct

**Layer 3 (Difftest): Oracle Implementation Correctness**
- Tests: Lean oracle vs Rust native function on 1000+ concrete inputs
- Guarantees: Oracle implementation matches specification on tested inputs
- Does NOT prove: Universal correctness (only tested inputs)

**Composition:**
```
Bytecode correct (Lean proof)
  ∧ Oracle sound (crypto assumption + axiom)
  ∧ Oracle implementation correct (difftest)
  ⇒ Bytecode implements sound sigma verification
```

### 5.2 Per-Operation Verification Workflow

**Step 1:** Write mathematical spec (functional simulation)
```lean
def verifyTransferBytecodeResult (oracle : Oracle) (args : List MoveValue) : ExecResult := ...
```

**Step 2:** Transcribe bytecode to Lean
```lean
def verifyTransferProofCode : List Instruction := [
  .moveLoc 0,  -- PC 0
  .moveLoc 1,  -- PC 1
  ...
]
```

**Step 3:** Prove per-PC step lemmas
```lean
theorem step_0 : step env (state 0) = .ok (state 1) := by simp only [step, state_pc, ...]
theorem step_1 : step env (state 1) = .ok (state 2) := by simp only [step, state_pc, ...]
...
```

**Step 4:** Chain PCs via `run`
```lean
theorem chain_0_to_N : run env (state 0) N = ... := by
  rw [run_succ_ok_of_step _ _ _ _ _ step_0]
  rw [run_succ_ok_of_step _ _ _ _ _ step_1]
  ...
```

**Step 5:** Prove eval ≡ functional sim
```lean
theorem transfer_eval_equiv_functional_sim :
    eval env idx args fuel = verifyTransferBytecodeResult oracle args :=
  by
    unfold eval verifyTransferBytecodeResult
    rw [chain_0_to_N]
    -- Match on oracle result...
    sorry  -- (Phase 6 work)
```

**Step 6:** Add difftest corpus rows
```rust
#[test]
fn test_transfer_happy_path() {
    let scenario = DiffTestScenario::new()
        .args(sender, recipient, amount, valid_proof)
        .expects_success();
    assert!(run_difftest(scenario).is_pass());
}
```

**Current status:**
- Steps 1-4: ✅ Complete for all 4 operations (Phase 4)
- Step 5: 🟡 Scaffolded with `sorry` for all 4 (Phase 6 in progress)
- Step 6: 🟡 87/102 scenarios (need 10 more for 95% target)

### 5.3 Axiom Review Process

**Goal:** Ensure every crypto axiom is justified and documented

**Quarterly review checklist:**
1. List all axioms: `#print axioms <theorem>`
2. Categorize:
   - Crypto assumptions (DLog, SHA-512, Bulletproofs) → permanent
   - Temporary (proof incomplete) → target for elimination
   - Framework (upstream Lean/mathlib) → permanent
3. For each crypto axiom:
   - Document in `TRUST_BOUNDARIES.md`
   - Cite source (paper, standard, audit)
   - Justify why not proved in Lean
4. Track temporary axioms → prioritize elimination

**Current axiom count:** 23 total (21 permanent crypto + 2 temporary)

---

## Security Analysis

### 6.1 Soundness Analysis

**Per-operation soundness:**
- **Registration:** Reduces to discrete log (DLog) hardness on Ristretto255 group
- **Withdrawal:** Reduces to DLog + ElGamal semantic security
- **Transfer:** Reduces to DLog + parallel Schnorr soundness
- **Normalization:** Reduces to DLog + ElGamal security
- **Rotation:** Reduces to DLog

**Assumption chain:**
```
Ristretto255 group has large prime order (2^252 + ...)
  → DLog hard in this group
  → Schnorr protocol sound
  → Parallel Schnorr sound (6 parallel in Transfer)
  → Fiat-Shamir + SHA-512 sound (ROM assumption)
  → Non-interactive proofs sound
```

**Weakest link:** Random Oracle Model (ROM) assumption for Fiat-Shamir

**Mitigation:** SHA-512 is industry-standard hash, no known ROM-breaking attacks in this context

### 6.2 Zero-Knowledge Analysis

**Per-operation zero-knowledge:**
- All CA sigma protocols are **honest-verifier zero-knowledge (HVZK)**
- Fiat-Shamir transform → **non-interactive zero-knowledge (NIZK)** in ROM

**What zero-knowledge guarantees:**
- Proof reveals nothing beyond statement truth
- Specifically: Proof does NOT reveal secret key, randomness, or plaintext balance

**What zero-knowledge does NOT guarantee:**
- Statement itself may leak info (e.g., withdrawal amount is public)
- Side channels (timing, power analysis) not covered

**Simulation:**
```lean
def simulateRegistrationProof (ek : RistrettoPoint) (challenge : Scalar) : RegistrationProof :=
  let s ← randomScalar()
  let R := scalarMultBase(s) - scalarMult(challenge, ek)
  { commitment := R, response := s }
```

**Indistinguishability:** Simulated proofs ≡ real proofs (computationally indistinguishable)

### 6.3 Completeness Analysis

**Per-operation completeness:**
- If prover knows witness (secret key, randomness), proof ALWAYS verifies
- No false negatives (honest prover never rejected)

**Potential failure modes:**
- Malformed proof struct (error, not verification failure)
- Arithmetic overflow (prevented by modular arithmetic)
- Point encoding invalid (rejected by Ristretto decoding, not sigma verification)

**Testing:** Difftest validates completeness on 1000+ honest proofs (all should verify)

### 6.4 Attack Vectors

**Replay attacks:**
- **Mitigation:** Context binding (chain ID, sender, contract, token)
- **Test:** Difftest scenario `test_registration_replay_different_chain` (should reject)

**Cross-protocol attacks:**
- **Mitigation:** Domain separation tags (DST)
- **Test:** Difftest scenario `test_registration_proof_as_withdrawal` (should reject)

**Malleability:**
- **Non-issue:** Schnorr proofs are not malleable (challenge binds commitment)
- **Test:** Difftest scenario `test_transfer_proof_malleability` (modify response, should reject)

**Quantum attacks:**
- **Impact:** Shor's algorithm breaks DLog → all sigma protocols broken
- **Mitigation:** None currently (post-quantum crypto out of scope)
- **Timeline:** Quantum computers capable of breaking 256-bit DLog estimated 10-20 years away

---

## Implementation Notes

### 7.1 Ristretto255 Group

**Why Ristretto255:**
- Prime-order group (no cofactor issues)
- Fast arithmetic (faster than secp256k1)
- Canonical encoding (no point malleability)

**Group parameters:**
- Order: q = 2^252 + 27742317777372353535851937790883648493
- Base point: g = Ristretto255 base point (derived from Curve25519)

**Security:** 126-bit security (sqrt(2^252) ≈ 2^126 operations for DLog)

### 7.2 Scalar Arithmetic

**All scalar arithmetic mod q:**
- Addition: `(a + b) mod q`
- Multiplication: `(a · b) mod q`
- Inversion: `a^(-1) mod q` (via extended Euclidean algorithm)

**Response computation:** `s = r + c·sk mod q`

**Lean modeling:**
```lean
structure Scalar where
  val : Nat
  h_bounded : val < q

def addScalar (a b : Scalar) : Scalar :=
  ⟨(a.val + b.val) % q, by omega⟩

def mulScalar (a b : Scalar) : Scalar :=
  ⟨(a.val * b.val) % q, by omega⟩
```

### 7.3 Point Compression

**Ristretto255 points:** 32 bytes compressed encoding

**Compression:** Point → 32 bytes (canonical)  
**Decompression:** 32 bytes → Option Point (rejects invalid encodings)

**Invalid encodings:**
- Non-canonical (multiple representations of same point)
- Not on curve
- Cofactor component (not in Ristretto group)

**Error handling:**
```rust
fn decompress(bytes: [u8; 32]) -> Result<RistrettoPoint, Error> {
    RistrettoPoint::from_bytes(&bytes)
        .ok_or(Error::InvalidPointEncoding)
}
```

**Lean modeling:**
```lean
axiom decompressRistrettoPoint : ByteArray → Option RistrettoPoint
axiom decompressRistrettoPoint_canonical :
  ∀ bytes, decompressRistrettoPoint bytes = some p →
    compressRistrettoPoint p = bytes
```

---

## Troubleshooting

### Issue: Proof Verification Fails (Rust)

**Symptom:**
```rust
assert_eq!(verify_transfer_proof(proof, ctx), VerifyResult::Success);
// Fails with VerifyResult::Failed
```

**Diagnosis:**
1. **Check challenge computation:**
   ```rust
   let challenge_expected = compute_challenge_manually(ctx, proof.commitment);
   let challenge_actual = proof.challenge_from_proof(ctx);
   assert_eq!(challenge_expected, challenge_actual);
   ```

2. **Check response computation:**
   ```rust
   let s_expected = r + c * sk;  // mod q
   assert_eq!(proof.response, s_expected);
   ```

3. **Check verification equation:**
   ```rust
   let lhs = RISTRETTO_BASEPOINT * proof.response;
   let rhs = proof.commitment + (ek * challenge);
   assert_eq!(lhs, rhs);
   ```

**Common causes:**
- Wrong challenge encoding (byte order, field order)
- Arithmetic overflow (forgot `mod q`)
- Point compression bug (non-canonical encoding)

### Issue: Difftest Mismatch (Lean ≠ VM)

**Symptom:**
```
Difftest failed: test_transfer_happy_path
  Lean result: .returned []
  VM result: .aborted 65537
```

**Diagnosis:**
1. **Check oracle inputs:**
   ```lean
   #eval oracle.verify proof ek ctx
   -- Compare with Rust oracle on same inputs
   ```

2. **Check proof encoding:**
   ```rust
   let proof_lean = lean_encode_proof(proof);
   let proof_rust = rust_encode_proof(proof);
   assert_eq!(proof_lean, proof_rust);
   ```

3. **Check context encoding:**
   ```rust
   let ctx_lean = lean_encode_context(ctx);
   let ctx_rust = rust_encode_context(ctx);
   assert_eq!(ctx_lean, ctx_rust);
   ```

**Common causes:**
- Encoding mismatch (byte order)
- Oracle implementation divergence (Lean model ≠ Rust impl)
- Proof generation bug (invalid proof in test)

### Issue: Proof Generation Slow

**Symptom:** Generating 1000 proofs takes >10 seconds

**Diagnosis:** Profile scalar multiplication (hotspot)

**Optimization:**
1. **Use precomputed tables** for fixed-base scalar mult (`g^s`):
   ```rust
   lazy_static! {
       static ref BASEPOINT_TABLE: RistrettoBasepointTable = 
           RistrettoBasepointTable::create(&RISTRETTO_BASEPOINT_POINT);
   }
   
   fn scalar_mult_base(s: &Scalar) -> RistrettoPoint {
       BASEPOINT_TABLE.multiply(s)  // 5× faster than naive
   }
   ```

2. **Batch verify** if checking multiple proofs:
   ```rust
   fn batch_verify(proofs: &[Proof], keys: &[PublicKey]) -> bool {
       // Use batch verification equation (Bellare-Garay-Rabin)
       // ~2× faster than verifying individually
   }
   ```

3. **Use parallel proof generation** (proofs are independent):
   ```rust
   proofs.par_iter().map(|ctx| generate_proof(sk, ctx)).collect()
   ```

### Issue: Zero-Knowledge Leakage

**Symptom:** Simulated proofs distinguishable from real proofs

**Diagnosis:**
1. **Check simulator implementation:**
   ```lean
   def simulateProof (ek : RistrettoPoint) (c : Scalar) : Proof :=
     let s ← randomScalar()
     let R := scalarMultBase(s) - scalarMult(c, ek)
     { commitment := R, response := s }
   ```

2. **Statistical test:**
   ```rust
   let real_proofs: Vec<Proof> = (0..1000).map(|_| generate_real_proof(sk)).collect();
   let sim_proofs: Vec<Proof> = (0..1000).map(|_| simulate_proof(ek)).collect();
   
   // Chi-squared test on response distribution
   assert!(chi_squared_test(real_proofs, sim_proofs) < 0.05);  // Not distinguishable
   ```

**Common causes:**
- Simulator uses wrong challenge (not uniformly random)
- Simulator uses biased randomness
- Implementation leaks secret via side channel (not ZK property, but bad)

---

## Related Guides

- [NATIVE_FUNCTION_ORACLE_MODELING_GUIDE.md](NATIVE_FUNCTION_ORACLE_MODELING_GUIDE.md) — Oracle design patterns
- [CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md](CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md) §4 — Phase 4 Lean proofs
- [DIFFTEST_HARNESS_DEVELOPMENT_GUIDE.md](DIFFTEST_HARNESS_DEVELOPMENT_GUIDE.md) — Testing sigma verification
- [MSL_SPECIFICATION_PATTERNS_GUIDE.md](MSL_SPECIFICATION_PATTERNS_GUIDE.md) — MSL crypto-opaque boundary

---

## References

**Sigma protocols (theory):**
- Damgård, I. (2010). "On Σ-protocols." Lecture notes, University of Aarhus.
- Schnorr, C. P. (1991). "Efficient signature generation by smart cards." Journal of Cryptology.

**Fiat-Shamir transform:**
- Fiat, A., & Shamir, A. (1986). "How to prove yourself: Practical solutions to identification and signature problems."
- Bernhard, D., et al. (2012). "On the necessity of rewinding in secure multiparty computation."

**Ristretto255:**
- de Valence, H., et al. (2020). "The ristretto255 Group." IETF Internet-Draft.
- https://ristretto.group

**ElGamal encryption:**
- ElGamal, T. (1985). "A public key cryptosystem and a signature scheme based on discrete logarithms."

**CA-specific:**
- `SigmaVerifiers.lean` — Mathematical definitions of all 5 sigma predicates
- `TranscriptAlignment.lean` — Fiat-Shamir challenge computation proof
- `audit/AXIOM_INVENTORY.md` — Complete axiom catalog

---

**Document Status:** v1.0 (2026-04-22)  
**Maintainer:** Cryptography team + Verification team  
**Last Updated:** 2026-04-22  
**Next Review:** 2026-07-22 (quarterly)

**Security Notice:** This guide documents the *design* and *verification methodology* of CA sigma protocols. Actual security depends on correct implementation (validated by difftest), sound crypto assumptions (DLog, ROM), and absence of side channels (outside verification scope). For security audit, see `audit/CLAIMS.md` and `audit/TRUST_BOUNDARIES.md`.
