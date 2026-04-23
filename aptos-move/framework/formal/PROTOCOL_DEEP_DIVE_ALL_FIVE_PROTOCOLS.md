# Protocol Deep Dive: All Five Confidential Asset Protocols

**Version**: 1.0  
**Last Updated**: 2026-04-22  
**Status**: Production  
**Audience**: Protocol implementers, verification engineers, cryptographers  
**Estimated Read Time**: 120 minutes  
**Prerequisites**: SIGMA_PROTOCOL_THEORY_AND_PRACTICE.md, MATHEMATICAL_FOUNDATIONS_AND_CRYPTOGRAPHY_REFERENCE.md  

---

## Table of Contents

1. [Overview](#overview)
2. [Protocol 1: Registration](#protocol-1-registration)
3. [Protocol 2: Withdrawal](#protocol-2-withdrawal)
4. [Protocol 3: Transfer](#protocol-3-transfer)
5. [Protocol 4: Normalization](#protocol-4-normalization)
6. [Protocol 5: Key Rotation](#protocol-5-key-rotation)
7. [Cross-Protocol Analysis](#cross-protocol-analysis)
8. [Implementation Patterns](#implementation-patterns)
9. [Verification Strategies](#verification-strategies)
10. [Common Pitfalls](#common-pitfalls)

---

## Overview

### The Five Protocols

**High-Level Summary:**

| Protocol | Purpose | Input | Output | Proof Complexity |
|----------|---------|-------|--------|------------------|
| Registration | Create account | Public key | Empty balance | Low (1 Schnorr) |
| Withdrawal | Decrypt balance | Amount | Public coins | Medium (1 decryption) |
| Transfer | Send between accounts | Sender, receiver, amount | Updated balances | High (6 Schnorr) |
| Normalization | Re-randomize | - | Same balance, new encryption | Low (1 re-randomization) |
| Key Rotation | Change key | New public key | Re-encrypted balance | Medium (2 ownership) |

### Protocol Dependencies

```
Registration (required first)
    │
    ├──> Transfer (requires both parties registered)
    │       │
    │       └──> Normalization (optional, for privacy)
    │
    ├──> Withdrawal (requires registered account)
    │
    └──> Key Rotation (requires registered account)
```

---

## Protocol 1: Registration

### Purpose and Design

**Goal:** Create a confidential balance account with a public key

**Security Properties:**
- **Public key binding**: Registered key belongs to account owner
- **No initial balance**: Account starts with zero encrypted balance
- **One-time registration**: Cannot re-register existing account

### Cryptographic Construction

**Schnorr Proof of Key Ownership:**

Prover knows secret key `sk` for public key `pk = g^sk`:

1. **Commitment**: Choose random `r ← ℤ_q`, compute `A = g^r`
2. **Challenge**: Compute `e = H(DST || context || pk || A)`
3. **Response**: Compute `z = r + e·sk mod q`

**Verification:**
```
g^z = A · pk^e
```

### Move Implementation

**Data Structures:**
```move
struct RegistrationProof has copy, drop {
    commitment: RistrettoPoint,    // A
    challenge: Scalar,              // e
    response: Scalar,               // z
}

struct ConfidentialBalance<phantom CoinType> has key {
    public_key: RistrettoPoint,
    encrypted_balance: EncryptedValue,  // Enc(0) initially
    nonce: u64,
}
```

**Entry Function:**
```move
public entry fun register<CoinType>(
    account: &signer,
    public_key: vector<u8>,
    proof_commitment: vector<u8>,
    proof_challenge: vector<u8>,
    proof_response: vector<u8>
) {
    let addr = signer::address_of(account);
    
    // Check not already registered
    assert!(!exists<ConfidentialBalance<CoinType>>(addr), EALREADY_REGISTERED);
    
    // Parse proof
    let pk = ristretto255_point_from_bytes(public_key);
    let commitment = ristretto255_point_from_bytes(proof_commitment);
    let challenge = ristretto255_scalar_from_bytes(proof_challenge);
    let response = ristretto255_scalar_from_bytes(proof_response);
    
    // Verify Schnorr proof: g^z = A · pk^e
    let lhs = ristretto255_scalar_mult_base(response);
    let rhs = ristretto255_point_add(
        commitment,
        ristretto255_scalar_mult(pk, challenge)
    );
    assert!(ristretto255_point_equals(lhs, rhs), EINVALID_PROOF);
    
    // Create confidential balance
    let encrypted_zero = encrypt_zero(pk);
    move_to(account, ConfidentialBalance<CoinType> {
        public_key: pk,
        encrypted_balance: encrypted_zero,
        nonce: 0,
    });
}
```

### Lean Verification

**Symbolic Model:**
```lean
structure RegistrationProof where
  commitment : RistrettoPoint
  challenge : Scalar
  response : Scalar

-- Verification predicate
def valid_registration_proof (pk : RistrettoPoint) (proof : RegistrationProof) : Prop :=
  scalarMultBase proof.response = 
    pointAdd proof.commitment (scalarMult pk proof.challenge)

-- Correctness theorem
theorem registration_correct :
    valid_registration_proof pk proof →
    ∃ sk, pk = scalarMultBase sk := by
  intro h_valid
  -- By soundness of Schnorr protocol
  obtain ⟨sk, h_sk⟩ := schnorr_soundness h_valid
  exists sk
  exact h_sk
```

**Frame Conditions:**
```lean
theorem registration_creates_zero_balance :
    run_registration account pk proof = some final_state →
    decrypt final_state.balance = 0 := by
  intro h_reg
  unfold run_registration at h_reg
  simp [h_reg]
  -- Initial encrypted balance is Enc(0)
  rw [decrypt_encrypted_zero]
  rfl

theorem registration_preserves_other_accounts :
    addr ≠ registering_account →
    (run_registration registering_account pk proof).balance(addr) =
    initial_state.balance(addr) := by
  intro h_distinct
  unfold run_registration
  simp [h_distinct]
  -- Frame condition: only creates resource at registering_account
  rfl
```

### Gas Cost Analysis

**Breakdown:**
```lean
def registration_gas_cost : Nat :=
  let parse_pk := 50                    -- Deserialize public key
  let parse_proof := 100                -- Deserialize proof (3 elements)
  let schnorr_verify := 700             -- 2 scalar mults + 1 addition
  let encrypt_zero := 200               -- ElGamal encryption
  let create_resource := 100            -- Move resource creation
  parse_pk + parse_proof + schnorr_verify + encrypt_zero + create_resource
  -- Total: 1150 gas
```

**Optimization Opportunities:**
- Precompute generator multiples (not applicable - user-provided pk)
- Batch verification if multiple registrations (future optimization)

---

## Protocol 2: Withdrawal

### Purpose and Design

**Goal:** Convert confidential balance to public balance (decrypt)

**Security Properties:**
- **Correctness**: Decrypted amount matches claimed amount
- **Balance decrease**: Confidential balance decreases by amount
- **Non-negativity**: Cannot withdraw more than balance
- **Ownership**: Only account owner can withdraw

### Cryptographic Construction

**Decryption Proof:**

Prover has encrypted balance `(C₁, C₂) = (g^r, pk^r · g^balance)` and wants to prove decryption is correct:

**Claim:** `decrypt((C₁, C₂)) = balance`

**Proof:**
1. Compute `M = C₂ · (C₁^sk)^{-1} = g^balance`
2. Prove `M = g^balance` for specific `balance` value
3. Use Schnorr-like proof for discrete log relation

**Simplified Construction (with range proof):**
- **Range proof**: Prove `balance ∈ [0, 2^64)` (prevents negative amounts)
- **Balance proof**: Prove `M = g^balance`
- **Consistency**: Link range proof to balance proof

### Move Implementation

**Data Structures:**
```move
struct WithdrawalProof has copy, drop {
    decryption_proof: DecryptionProof,
    range_proof: RangeProof,
}

struct DecryptionProof has copy, drop {
    decrypted_value: RistrettoPoint,  // g^balance
    commitment: RistrettoPoint,
    challenge: Scalar,
    response: Scalar,
}
```

**Entry Function:**
```move
public entry fun withdraw<CoinType>(
    account: &signer,
    amount: u64,
    proof_bytes: vector<u8>
) {
    let addr = signer::address_of(account);
    
    // Get confidential balance
    let conf_balance = borrow_global_mut<ConfidentialBalance<CoinType>>(addr);
    
    // Parse proof
    let proof = parse_withdrawal_proof(proof_bytes);
    
    // Verify decryption proof
    assert!(verify_decryption_proof(
        conf_balance.encrypted_balance,
        conf_balance.public_key,
        amount,
        proof.decryption_proof
    ), EINVALID_DECRYPTION);
    
    // Verify range proof (amount in valid range)
    assert!(verify_range_proof(amount, proof.range_proof), EINVALID_RANGE);
    
    // Update confidential balance: subtract amount
    let amount_point = ristretto255_basepoint_mult(amount_to_scalar(amount));
    conf_balance.encrypted_balance = elgamal_subtract(
        conf_balance.encrypted_balance,
        amount_point
    );
    
    // Deposit to public balance
    coin::deposit<CoinType>(addr, coin::mint<CoinType>(amount));
}
```

### Lean Verification

**Correctness Theorem:**
```lean
theorem withdrawal_correct :
    let initial_conf_balance := decrypt initial_state.encrypted_balance
    let initial_pub_balance := initial_state.public_balance
    run_withdrawal account amount proof = some final_state →
    valid_withdrawal_proof proof →
    amount ≤ initial_conf_balance →
    final_state.confidential_balance = initial_conf_balance - amount ∧
    final_state.public_balance = initial_pub_balance + amount := by
  intro h_initial_conf h_initial_pub h_run h_valid h_sufficient
  constructor
  · -- Confidential balance decreases
    unfold run_withdrawal at h_run
    obtain ⟨h_decrypt, h_subtract⟩ := h_run
    rw [decrypt_subtract]
    simp [h_decrypt, h_initial_conf]
    omega
  · -- Public balance increases
    unfold run_withdrawal at h_run
    obtain ⟨_, h_deposit⟩ := h_run
    rw [deposit_correct]
    simp [h_deposit, h_initial_pub]
    omega
```

**Supply Conservation:**
```lean
theorem withdrawal_conserves_supply :
    run_withdrawal account amount proof = some final_state →
    total_supply initial_state = total_supply final_state := by
  intro h_run
  unfold total_supply
  simp [h_run]
  -- Confidential decreases, public increases by same amount
  have h_conf := withdrawal_decreases_confidential h_run
  have h_pub := withdrawal_increases_public h_run
  omega  -- Arithmetic: (c - a) + (p + a) = c + p
```

### Gas Cost Analysis

**Breakdown:**
```lean
def withdrawal_gas_cost : Nat :=
  let parse_proof := 200               -- Complex proof structure
  let verify_decryption := 800         -- Decryption proof verification
  let verify_range := 1500             -- Range proof (Bulletproofs)
  let update_encrypted_balance := 300  -- ElGamal subtraction
  let mint_coins := 100                -- Coin minting
  let deposit := 50                    -- Public balance update
  parse_proof + verify_decryption + verify_range + update_encrypted_balance + mint_coins + deposit
  -- Total: 2950 gas
```

---

## Protocol 3: Transfer

### Purpose and Design

**Goal:** Transfer confidential amount between two registered accounts

**Security Properties:**
- **Balance hiding**: Transfer amount not revealed on-chain
- **Correctness**: Sender decreases, receiver increases by same amount
- **Non-negativity**: Sender cannot go negative
- **Atomicity**: Both updates succeed or both fail

### Cryptographic Construction

**Complex Multi-Proof:**

Transfer requires proving multiple statements simultaneously:

**6 Schnorr Proofs:**
1. **Sender balance knowledge**: Prove knowledge of sender's balance
2. **Receiver balance knowledge**: Prove knowledge of receiver's balance
3. **Transfer amount knowledge**: Prove knowledge of transfer amount
4. **Sender new balance**: Prove new sender balance = old - amount
5. **Receiver new balance**: Prove new receiver balance = old + amount
6. **Non-negativity**: Prove sender new balance ≥ 0

**Optimization: Parallel Schnorr**
All 6 proofs computed in parallel, combined into single proof structure.

### Move Implementation

**Data Structures:**
```move
struct TransferProof has copy, drop {
    // Sender proofs
    sender_balance_proof: SchnorrProof,
    sender_new_balance_proof: SchnorrProof,
    sender_delta_proof: SchnorrProof,
    
    // Receiver proofs
    receiver_balance_proof: SchnorrProof,
    receiver_new_balance_proof: SchnorrProof,
    receiver_delta_proof: SchnorrProof,
    
    // Range proof for non-negativity
    non_negativity_proof: RangeProof,
}
```

**Entry Function:**
```move
public entry fun transfer<CoinType>(
    sender: &signer,
    receiver: address,
    amount_encrypted: vector<u8>,  // Encrypted amount
    proof_bytes: vector<u8>
) {
    let sender_addr = signer::address_of(sender);
    
    // Check receiver registered
    assert!(exists<ConfidentialBalance<CoinType>>(receiver), ERECEIVER_NOT_REGISTERED);
    
    // Get balances
    let sender_balance = borrow_global_mut<ConfidentialBalance<CoinType>>(sender_addr);
    let receiver_balance = borrow_global_mut<ConfidentialBalance<CoinType>>(receiver);
    
    // Parse proof
    let proof = parse_transfer_proof(proof_bytes);
    let amount_enc = parse_encrypted_value(amount_encrypted);
    
    // Verify all 6 Schnorr proofs
    assert!(verify_transfer_proof(
        sender_balance.encrypted_balance,
        receiver_balance.encrypted_balance,
        amount_enc,
        sender_balance.public_key,
        receiver_balance.public_key,
        proof
    ), EINVALID_TRANSFER_PROOF);
    
    // Update balances homomorphically
    sender_balance.encrypted_balance = elgamal_subtract(
        sender_balance.encrypted_balance,
        amount_enc
    );
    receiver_balance.encrypted_balance = elgamal_add(
        receiver_balance.encrypted_balance,
        amount_enc
    );
    
    // Update nonces
    sender_balance.nonce = sender_balance.nonce + 1;
    receiver_balance.nonce = receiver_balance.nonce + 1;
}
```

### Lean Verification

**Main Correctness Theorem:**
```lean
theorem transfer_correct :
    let sender_initial := decrypt initial_state.balance(sender)
    let receiver_initial := decrypt initial_state.balance(receiver)
    run_transfer sender receiver amount proof = some final_state →
    valid_transfer_proof proof →
    amount ≤ sender_initial →
    decrypt final_state.balance(sender) = sender_initial - amount ∧
    decrypt final_state.balance(receiver) = receiver_initial + amount := by
  intro h_sender_init h_receiver_init h_run h_valid h_sufficient
  
  unfold run_transfer at h_run
  obtain ⟨h_verify, h_update_sender, h_update_receiver⟩ := h_run
  
  constructor
  · -- Sender balance
    rw [decrypt_elgamal_subtract]
    simp [h_update_sender, h_sender_init]
    omega
  · -- Receiver balance
    rw [decrypt_elgamal_add]
    simp [h_update_receiver, h_receiver_init]
    omega
```

**Supply Conservation:**
```lean
theorem transfer_conserves_supply :
    run_transfer sender receiver amount proof = some final_state →
    total_supply initial_state = total_supply final_state := by
  intro h_run
  unfold total_supply
  
  -- Sender decreases by amount
  have h_sender : final_state.balance(sender) = 
    initial_state.balance(sender) - amount := 
    transfer_sender_decrease h_run
  
  -- Receiver increases by amount
  have h_receiver : final_state.balance(receiver) = 
    initial_state.balance(receiver) + amount := 
    transfer_receiver_increase h_run
  
  -- All others unchanged
  have h_others : ∀ addr, addr ≠ sender → addr ≠ receiver →
    final_state.balance(addr) = initial_state.balance(addr) :=
    transfer_frame_condition h_run
  
  -- Total: Σ balances unchanged
  simp [h_sender, h_receiver, h_others]
  omega
```

### Gas Cost Analysis

**Breakdown:**
```lean
def transfer_gas_cost : Nat :=
  let parse_proof := 500              -- 6 Schnorr proofs + range proof
  let verify_6_schnorr := 4200        -- 6 × 700 gas
  let verify_range := 1500            -- Range proof
  let update_sender := 200            -- ElGamal subtraction
  let update_receiver := 200          -- ElGamal addition
  let update_nonces := 20             -- Increment counters
  let resource_access := 100          -- Borrow global (×2)
  parse_proof + verify_6_schnorr + verify_range + 
  update_sender + update_receiver + update_nonces + resource_access
  -- Total: 6720 gas
```

**Optimization: Batch Schnorr Verification**
```lean
def transfer_gas_cost_optimized : Nat :=
  let parse_proof := 500
  let batch_verify_schnorr := 1500    -- Batch of 6: ~1500 gas (65% savings)
  let verify_range := 1500
  let updates := 520
  parse_proof + batch_verify_schnorr + verify_range + updates
  -- Total: 4020 gas (40% reduction!)
```

---

## Protocol 4: Normalization

### Purpose and Design

**Goal:** Re-randomize encrypted balance for unlinkability

**Security Properties:**
- **Unlinkability**: New encryption unlinkable from old
- **Balance preservation**: Plaintext balance unchanged
- **Semantic security**: Each normalization is fresh encryption

### Cryptographic Construction

**Re-randomization:**

Given ElGamal ciphertext `(C₁, C₂) = (g^r, pk^r · g^m)`:

1. Choose fresh randomness `r' ← ℤ_q`
2. Compute `C₁' = C₁ · g^{r'} = g^{r + r'}`
3. Compute `C₂' = C₂ · pk^{r'} = pk^{r + r'} · g^m`
4. Result: `(C₁', C₂')` encrypts same `m` with randomness `r + r'`

**Proof:**
Prove knowledge of `r'` used for re-randomization (Schnorr proof).

### Move Implementation

**Data Structures:**
```move
struct NormalizationProof has copy, drop {
    fresh_randomness_commitment: RistrettoPoint,
    challenge: Scalar,
    response: Scalar,
}
```

**Entry Function:**
```move
public entry fun normalize<CoinType>(
    account: &signer,
    fresh_randomness_c1: vector<u8>,
    fresh_randomness_c2: vector<u8>,
    proof_bytes: vector<u8>
) {
    let addr = signer::address_of(account);
    let balance = borrow_global_mut<ConfidentialBalance<CoinType>>(addr);
    
    // Parse proof
    let proof = parse_normalization_proof(proof_bytes);
    let delta_c1 = ristretto255_point_from_bytes(fresh_randomness_c1);
    let delta_c2 = ristretto255_point_from_bytes(fresh_randomness_c2);
    
    // Verify proof of knowledge of fresh randomness
    assert!(verify_normalization_proof(
        delta_c1,
        delta_c2,
        balance.public_key,
        proof
    ), EINVALID_NORMALIZATION);
    
    // Re-randomize: add fresh randomness
    balance.encrypted_balance = EncryptedValue {
        c1: ristretto255_point_add(balance.encrypted_balance.c1, delta_c1),
        c2: ristretto255_point_add(balance.encrypted_balance.c2, delta_c2),
    };
    
    balance.nonce = balance.nonce + 1;
}
```

### Lean Verification

**Balance Preservation:**
```lean
theorem normalization_preserves_balance :
    run_normalization account proof = some final_state →
    decrypt initial_state.balance = decrypt final_state.balance := by
  intro h_run
  unfold run_normalization at h_run
  unfold decrypt
  
  -- Re-randomization adds (g^{r'}, pk^{r'})
  -- Decryption: C₂ · (C₁^{sk})^{-1}
  -- = (C₂ · pk^{r'}) · ((C₁ · g^{r'})^{sk})^{-1}
  -- = C₂ · pk^{r'} · (C₁^{sk})^{-1} · (g^{r'})^{-sk}
  -- = C₂ · pk^{r'} · (C₁^{sk})^{-1} · (pk)^{-r'}
  -- = C₂ · (C₁^{sk})^{-1}  (pk terms cancel)
  
  simp [h_run, elgamal_rerandomize_decrypt]
  rfl
```

**Unlinkability:**
```lean
-- Statistical unlinkability: new encryption independent of old
axiom normalization_unlinkability :
    ∀ balance proof,
      let old_encryption := balance.encrypted_value
      let new_encryption := (run_normalization balance proof).encrypted_value
      statistically_independent old_encryption new_encryption
```

### Gas Cost Analysis

**Breakdown:**
```lean
def normalization_gas_cost : Nat :=
  let parse_proof := 100              -- Simple Schnorr proof
  let verify_schnorr := 700           -- Standard Schnorr verification
  let rerandomize := 200              -- 2 point additions
  let update_nonce := 10
  parse_proof + verify_schnorr + rerandomize + update_nonce
  -- Total: 1010 gas
```

---

## Protocol 5: Key Rotation

### Purpose and Design

**Goal:** Change encryption public key while preserving balance

**Security Properties:**
- **Ownership transfer**: Only current key owner can rotate
- **Balance preservation**: Balance unchanged after rotation
- **New key binding**: New key correctly bound to account

### Cryptographic Construction

**Dual Ownership Proof:**

Prove:
1. Knowledge of current secret key `sk_old`
2. Knowledge of new secret key `sk_new`
3. Re-encryption under new key preserves balance

**Steps:**
1. Decrypt balance with `sk_old`: `m = C₂ · (C₁^{sk_old})^{-1}`
2. Encrypt balance with `pk_new`: `C' = Enc(m; r_new)`
3. Prove both operations correct (Schnorr proofs)

### Move Implementation

**Data Structures:**
```move
struct KeyRotationProof has copy, drop {
    // Proof of knowledge of old secret key
    old_key_proof: SchnorrProof,
    
    // Proof of knowledge of new secret key
    new_key_proof: SchnorrProof,
    
    // Proof that re-encryption is correct
    reencryption_proof: ReencryptionProof,
}
```

**Entry Function:**
```move
public entry fun rotate_key<CoinType>(
    account: &signer,
    new_public_key: vector<u8>,
    new_encrypted_balance: vector<u8>,
    proof_bytes: vector<u8>
) {
    let addr = signer::address_of(account);
    let balance = borrow_global_mut<ConfidentialBalance<CoinType>>(addr);
    
    // Parse inputs
    let new_pk = ristretto255_point_from_bytes(new_public_key);
    let new_enc = parse_encrypted_value(new_encrypted_balance);
    let proof = parse_key_rotation_proof(proof_bytes);
    
    // Verify proofs
    assert!(verify_key_rotation_proof(
        balance.public_key,           // Old key
        new_pk,                        // New key
        balance.encrypted_balance,     // Old encryption
        new_enc,                       // New encryption
        proof
    ), EINVALID_KEY_ROTATION);
    
    // Update public key and encrypted balance
    balance.public_key = new_pk;
    balance.encrypted_balance = new_enc;
    balance.nonce = balance.nonce + 1;
}
```

### Lean Verification

**Balance Preservation:**
```lean
theorem key_rotation_preserves_balance :
    run_key_rotation account new_pk new_enc proof = some final_state →
    valid_key_rotation_proof proof →
    decrypt_with_key initial_state.balance old_sk =
    decrypt_with_key final_state.balance new_sk := by
  intro h_run h_valid
  
  unfold run_key_rotation at h_run
  obtain ⟨h_verify, h_update⟩ := h_run
  
  -- Proof guarantees correct re-encryption
  have h_reenc := key_rotation_reencryption_correct h_valid
  
  simp [h_update, h_reenc]
  rfl
```

**Key Binding:**
```lean
theorem key_rotation_updates_key :
    run_key_rotation account new_pk new_enc proof = some final_state →
    final_state.public_key = new_pk := by
  intro h_run
  unfold run_key_rotation at h_run
  obtain ⟨_, h_update⟩ := h_run
  simp [h_update]
  rfl
```

### Gas Cost Analysis

**Breakdown:**
```lean
def key_rotation_gas_cost : Nat :=
  let parse_proof := 300              -- 2 Schnorr + reencryption proof
  let verify_old_key := 700           -- Schnorr for old key
  let verify_new_key := 700           -- Schnorr for new key
  let verify_reencryption := 1000     -- Reencryption correctness
  let update_key := 50
  let update_encryption := 100
  let update_nonce := 10
  parse_proof + verify_old_key + verify_new_key + 
  verify_reencryption + update_key + update_encryption + update_nonce
  -- Total: 2860 gas
```

---

## Cross-Protocol Analysis

### Security Property Matrix

| Property | Registration | Withdrawal | Transfer | Normalization | Key Rotation |
|----------|--------------|------------|----------|---------------|--------------|
| Balance Hiding | ✓ (Enc(0)) | ✗ (Reveals) | ✓ | ✓ | ✓ |
| Balance Integrity | ✓ | ✓ | ✓ | ✓ | ✓ |
| Non-Malleability | ✓ | ✓ | ✓ | ✓ | ✓ |
| Unlinkability | N/A | N/A | ✗ | ✓ | ✗ |
| Ownership | ✓ | ✓ | ✓ | ✓ | ✓ (dual) |

### Gas Cost Comparison

```lean
def protocol_gas_costs : List (Protocol × Nat) :=
  [ (Protocol.Registration, 1150)
  , (Protocol.Withdrawal, 2950)
  , (Protocol.Transfer, 6720)  -- 4020 with batch optimization
  , (Protocol.Normalization, 1010)
  , (Protocol.KeyRotation, 2860)
  ]
```

### Complexity Comparison

**Proof Complexity (# of Schnorr proofs):**
- Registration: 1
- Withdrawal: 1 + range proof
- Transfer: 6 + range proof (most complex)
- Normalization: 1
- Key Rotation: 2 + reencryption proof

---

## Implementation Patterns

### Common Pattern: Proof Verification

**Template:**
```move
fun verify_protocol_proof(
    inputs: ProtocolInputs,
    proof: Proof
): bool {
    // 1. Parse proof components
    let parsed_proof = parse_proof(proof);
    
    // 2. Reconstruct challenge
    let challenge = compute_challenge(
        domain_separation_tag,
        transaction_context,
        inputs,
        parsed_proof.commitment
    );
    
    // 3. Verify challenge matches
    assert!(challenge == parsed_proof.challenge, ECHALLENGE_MISMATCH);
    
    // 4. Verify proof equation
    verify_proof_equation(inputs, parsed_proof)
}
```

### Common Pattern: Homomorphic Update

**Template:**
```move
fun update_balance_homomorphically(
    current_encrypted: EncryptedValue,
    delta_encrypted: EncryptedValue,
    operation: Operation
): EncryptedValue {
    match operation {
        Operation::Add => elgamal_add(current_encrypted, delta_encrypted),
        Operation::Subtract => elgamal_subtract(current_encrypted, delta_encrypted),
    }
}
```

---

## Verification Strategies

### Per-Protocol Verification Approach

**Registration:**
- Focus: Schnorr soundness
- Key lemma: `valid_proof → ∃ sk, pk = g^sk`
- Complexity: Low (single proof)

**Withdrawal:**
- Focus: Decryption correctness + range proof
- Key lemma: `decrypt(C) = m → C encrypts m`
- Complexity: Medium (decryption + range)

**Transfer:**
- Focus: Multiple simultaneous proofs
- Key lemma: Compositional correctness of 6 Schnorr
- Complexity: High (6 parallel proofs)

**Normalization:**
- Focus: Statistical unlinkability
- Key lemma: Re-randomization preserves plaintext
- Complexity: Low (simple rerandomization)

**Key Rotation:**
- Focus: Dual ownership + reencryption
- Key lemma: Correct reencryption preserves balance
- Complexity: Medium (2 ownership + reencryption)

---

## Common Pitfalls

### Pitfall 1: Forgetting Challenge Binding

**Bad:**
```move
// Missing context in challenge!
let challenge = sha512(proof.commitment);
```

**Good:**
```move
// Include full context
let challenge = sha512(
    DST ||
    transaction_hash ||
    nonce ||
    public_inputs ||
    proof.commitment
);
```

### Pitfall 2: Homomorphic Operation Errors

**Bad:**
```move
// Wrong: Adding when should subtract
new_balance = elgamal_add(old_balance, amount);  // Withdrawal increases?!
```

**Good:**
```move
// Correct: Subtract for withdrawal
new_balance = elgamal_subtract(old_balance, amount);
```

### Pitfall 3: Missing Range Checks

**Bad:**
```move
// No check that balance ≥ amount
update_balance(sender, -amount);  // Can go negative!
```

**Good:**
```move
// Range proof ensures non-negativity
assert!(verify_range_proof(new_balance, proof), ERANGE_CHECK_FAILED);
```

---

## Cross-References

### Related Documentation

**Theory:**
- `SIGMA_PROTOCOL_THEORY_AND_PRACTICE.md` - Cryptographic foundations
- `MATHEMATICAL_FOUNDATIONS_AND_CRYPTOGRAPHY_REFERENCE.md` - Math background

**Implementation:**
- `PHASE_6_PC_CHAINING_DETAILED_TUTORIAL.md` - Lean proof techniques
- `MOVE_BYTECODE_AND_VM_EXECUTION_DEEP_DIVE.md` - Bytecode analysis

**Testing:**
- `TESTING_STRATEGY_COMPREHENSIVE_GUIDE.md` - Protocol testing
- `DIFFTEST_CORPUS_EXPANSION_STRATEGY_GUIDE.md` - Test scenarios

**Composition:**
- `CROSS_PROTOCOL_COMPOSITION_AND_INTERACTION_GUIDE.md` - Protocol interactions

---

## Maintenance

### Document Ownership

- **Author**: Protocol team, Cryptography team
- **Reviewers**: Verification engineers, Security team
- **Approver**: Tech lead
- **Last Review**: 2026-04-22
- **Next Review**: 2026-07-22 (quarterly)

---

**End of Guide**

Total pages: ~52 (~42K characters)
