# Mathematical Foundations and Cryptography Reference for Confidential Assets

**Version**: 1.0  
**Last Updated**: 2026-04-22  
**Status**: Production  
**Audience**: Cryptographers, mathematicians, verification engineers, security reviewers  
**Estimated Read Time**: 120 minutes  
**Prerequisites**: Abstract algebra (groups, fields), probability theory, computational complexity  

---

## Table of Contents

1. [Overview](#overview)
2. [Group Theory Foundations](#group-theory-foundations)
3. [Elliptic Curve Cryptography](#elliptic-curve-cryptography)
4. [Ristretto255 Group](#ristretto255-group)
5. [Computational Hardness Assumptions](#computational-hardness-assumptions)
6. [ElGamal Encryption](#elgamal-encryption)
7. [Sigma Protocols and Zero-Knowledge](#sigma-protocols-and-zero-knowledge)
8. [Fiat-Shamir Transform](#fiat-shamir-transform)
9. [Homomorphic Properties](#homomorphic-properties)
10. [Security Reductions](#security-reductions)
11. [Formalization in Lean](#formalization-in-lean)
12. [Proofs of Security Properties](#proofs-of-security-properties)

---

## Overview

### Purpose

This document provides rigorous mathematical foundations for the cryptographic protocols used in Confidential Assets (CA). It bridges the gap between informal protocol descriptions and formal verification by presenting:

1. **Precise mathematical definitions** of cryptographic primitives
2. **Proofs** of security properties (with reduction to standard assumptions)
3. **Formalization** techniques for representing crypto in Lean 4

### Scope

**Covered:**
- Elliptic curve groups (Curve25519, Ristretto255)
- Discrete logarithm and Diffie-Hellman assumptions
- ElGamal encryption (correctness, security)
- Sigma protocols (Schnorr, commitment-based)
- Fiat-Shamir transform (soundness, knowledge extraction)
- Homomorphic encryption properties

**Not Covered:**
- Post-quantum cryptography (future work)
- Side-channel analysis (implementation-specific)
- Concrete performance analysis (see LEAN_PERFORMANCE_OPTIMIZATION_GUIDE.md)

### Notation Conventions

**Groups:**
- `G` = elliptic curve group (Ristretto255)
- `|G|` = group order (prime, ~2^255)
- `g` = generator of `G`
- `∘` = group operation (addition for elliptic curves)
- `e` = identity element (point at infinity)
- `[n]P` = scalar multiplication (P added to itself n times)

**Fields:**
- `F_q` = field of integers mod q
- `q` = group order (large prime)
- `+, ×, -` = field operations

**Probabilities:**
- `Pr[event]` = probability of event
- `A` = adversary (probabilistic polynomial-time algorithm)
- `negl(λ)` = negligible function in security parameter λ

**Complexity:**
- `PPT` = probabilistic polynomial-time
- `λ` = security parameter (255 for Ristretto255)
- `O(f(n))` = big-O notation for complexity

---

## Group Theory Foundations

### Cyclic Groups

**Definition 1.1 (Cyclic Group):**
A group `(G, ∘)` is **cyclic** if there exists an element `g ∈ G` such that every element of `G` can be written as `g^n` for some integer `n`.

Such an element `g` is called a **generator**.

**Example:**
The additive group `ℤ_q = {0, 1, ..., q-1}` under addition mod `q` is cyclic with generator `g = 1`:
- `0 = 1^0 mod q`
- `1 = 1^1 mod q`
- `2 = 1^2 mod q`
- ...

**Theorem 1.1 (Existence of Generators):**
A cyclic group of order `n` has `φ(n)` generators, where `φ` is Euler's totient function.

For prime `q`, `|ℤ_q| = q` and `φ(q) = q-1`, so there are `q-1` generators.

### Discrete Logarithm Problem

**Definition 1.2 (Discrete Logarithm):**
Let `G` be a cyclic group of order `q` with generator `g`. For any `h ∈ G`, the **discrete logarithm** of `h` to base `g` is the unique integer `x ∈ [0, q-1]` such that `h = g^x`.

Notation: `x = log_g(h)` or `x = dlog(h)`.

**Problem 1.1 (Discrete Logarithm Problem, DLP):**
Given `(G, g, h)` where `h = g^x` for unknown `x`, compute `x`.

**Hardness Assumption:**
For cryptographically-chosen groups `G` (e.g., elliptic curves), there is no PPT algorithm that solves DLP with non-negligible probability.

**Formal Statement:**
```
∀ PPT adversary A, ∃ negligible function ε:
  Pr[x' = x : x ← ℤ_q, h := g^x, x' ← A(G, g, h)] ≤ ε(λ)
```

### Computational Diffie-Hellman (CDH)

**Problem 1.2 (CDH):**
Given `(G, g, g^a, g^b)` for unknown random `a, b ← ℤ_q`, compute `g^{ab}`.

**Hardness Assumption:**
No PPT adversary can solve CDH with non-negligible advantage over random guessing.

**Formal Statement:**
```
∀ PPT adversary A, ∃ negligible ε:
  Pr[C = g^{ab} : a,b ← ℤ_q, C ← A(G, g, g^a, g^b)] ≤ 1/|G| + ε(λ)
```

**Relation to DLP:**
If DLP is easy, then CDH is easy:
- Given `(g, g^a, g^b)`, compute `a = log_g(g^a)`
- Compute `g^{ab} = (g^b)^a`

Therefore: `DLP hard ⇒ CDH hard` (contrapositive: `CDH easy ⇒ DLP easy`).

But converse is unknown: CDH might be hard even if DLP is easy (in some groups).

### Decisional Diffie-Hellman (DDH)

**Problem 1.3 (DDH):**
Distinguish tuples `(G, g, g^a, g^b, g^{ab})` from `(G, g, g^a, g^b, g^c)` where `a, b, c ← ℤ_q` are random.

**Hardness Assumption:**
No PPT adversary can distinguish DDH tuples from random with non-negligible advantage.

**Formal Statement:**
```
∀ PPT adversary A, ∃ negligible ε:
  |Pr[A(g, g^a, g^b, g^{ab}) = 1] - Pr[A(g, g^a, g^b, g^c) = 1]| ≤ ε(λ)
```

where probabilities are over random `a, b, c ← ℤ_q` and randomness of `A`.

**Relation to CDH:**
If CDH is easy, then DDH is easy:
- Given `(g, g^a, g^b, g^z)`, compute `g^{ab}` via CDH
- If `z = g^{ab}`, output 1; else output 0

Therefore: `CDH hard ⇒ DDH hard`.

But converse is unknown: DDH might be hard even if CDH is easy.

**Hierarchy:**
```
DLP hard ⇒ CDH hard ⇒ DDH hard
```

All three are believed equivalent for elliptic curves (but not proven).

---

## Elliptic Curve Cryptography

### Elliptic Curves over Finite Fields

**Definition 2.1 (Elliptic Curve):**
An elliptic curve `E` over a finite field `F_p` is the set of solutions `(x, y) ∈ F_p × F_p` to the equation:
```
y² = x³ + ax + b  (mod p)
```
where `a, b ∈ F_p` satisfy `4a³ + 27b² ≠ 0` (non-singular), together with a special "point at infinity" `O`.

**Group Law:**
Points on `E` form an abelian group `(E(F_p), +)` with:
- Identity: `O` (point at infinity)
- Inverse: `-(x, y) = (x, -y)`
- Addition: Geometric chord-tangent rule

**Explicit Formulas (for P ≠ Q, P ≠ -Q):**
```
P = (x₁, y₁), Q = (x₂, y₂)
R = P + Q = (x₃, y₃)

λ = (y₂ - y₁) / (x₂ - x₁)  mod p  (slope of line PQ)
x₃ = λ² - x₁ - x₂  mod p
y₃ = λ(x₁ - x₃) - y₁  mod p
```

**Point Doubling (for P = Q):**
```
λ = (3x₁² + a) / (2y₁)  mod p  (slope of tangent)
x₃ = λ² - 2x₁  mod p
y₃ = λ(x₁ - x₃) - y₁  mod p
```

**Scalar Multiplication:**
For integer `n` and point `P`, define `[n]P = P + P + ... + P` (n times).

Computed efficiently via double-and-add:
```
[n]P:
  Q := O
  for i from log₂(n) down to 0:
    Q := 2Q
    if bit i of n is 1:
      Q := Q + P
  return Q
```

Complexity: `O(log n)` group operations.

### Curve25519

**Definition 2.2 (Curve25519):**
Montgomery curve over `F_p` where `p = 2^255 - 19`:
```
y² = x³ + 486662x² + x  (mod p)
```

**Properties:**
- Prime order subgroup of size `q = 2^252 + 27742317777372353535851937790883648493`
- Cofactor `h = 8` (total group size = `8q`)
- Generator `G = (9, ...)` (standard base point)

**Security Level:**
~126 bits (due to Pollard's rho algorithm with complexity `O(√q)`).

**Why Curve25519?**
- Fast arithmetic (optimized for modern CPUs)
- Safe curve (resistant to many attacks)
- Widely deployed (TLS, SSH, Tor, Signal, ...)

### Edwards25519

**Definition 2.3 (Edwards25519):**
Twisted Edwards form of Curve25519:
```
-x² + y² = 1 - (121665/121666)x²y²  (mod p)
```

**Properties:**
- Birationally equivalent to Curve25519 (same group)
- Complete addition formulas (no special cases)
- Faster signature verification

**Usage:**
Edwards25519 is used for Ed25519 signatures. Curve25519 (Montgomery) is used for ECDH key exchange.

They are the **same curve** in different coordinate systems.

---

## Ristretto255 Group

### The Cofactor Problem

**Problem:**
Edwards25519 has cofactor `h = 8`. Not all points are in the prime-order subgroup:
```
E(F_p) = G₁ ⊕ G₈
```
where `|G₁| = q` (prime order), `|G₈| = 8` (small subgroup).

**Issue:**
If cryptographic protocols don't check subgroup membership, adversaries can send points in `G₈`, leading to:
- Small subgroup attacks
- Non-uniform distributions
- Protocol failures

**Naive Fix:**
Multiply all points by `h = 8` to clear cofactor:
```
P' = [8]P
```

But this loses `log₂(8) = 3` bits of security.

### Ristretto Construction

**Solution:**
Ristretto is a **quotient group** that eliminates cofactor without losing security.

**Construction:**
Define equivalence relation on Edwards25519 points:
```
P ~ Q  iff  P - Q ∈ coset structure
```

Ristretto group = `Edwards25519 / ~`

**Properties:**
- Prime order `q` (no cofactor)
- Encoding/decoding functions ensure all elements valid
- Compatible with Ed25519 arithmetic
- Fast (almost as fast as raw Edwards25519)

**Formal Definition:**
Ristretto255 is the group of Jacobi quartic points modulo equivalence. Details in [Ristretto spec](https://ristretto.group/).

### Ristretto255 Operations

**Group Operation:**
```
add : Ristretto255 → Ristretto255 → Ristretto255
```
Implemented via Edwards25519 addition.

**Scalar Multiplication:**
```
scalarMult : ℤ_q → Ristretto255 → Ristretto255
scalarMult n P = [n]P
```

**Scalar Base Multiplication:**
```
scalarMultBase : ℤ_q → Ristretto255
scalarMultBase n = [n]G
```
where `G` is the standard generator. Faster than general multiplication (precomputed tables).

**Encoding:**
```
encode : Ristretto255 → Bytes[32]
decode : Bytes[32] → Option Ristretto255
```

**Properties:**
- `decode(encode(P)) = some P` (for all `P`)
- `decode(b) = none` for invalid encodings (not in subgroup, malformed)
- Encoding is **canonical** (each element has unique encoding)

### Security Properties

**Theorem 2.1 (Ristretto255 DLP Hardness):**
Discrete logarithm in Ristretto255 is as hard as in the prime-order subgroup of Edwards25519.

**Proof Sketch:**
- Ristretto255 is a quotient of the prime-order subgroup
- DLP in quotient reduces to DLP in subgroup
- No known attacks exploit quotient structure

**Theorem 2.2 (Ristretto255 DDH Hardness):**
DDH assumption holds for Ristretto255 (under standard assumptions for Edwards25519).

**Security Level:**
~126 bits (same as Curve25519).

---

## Computational Hardness Assumptions

### Generic Group Model

**Definition 3.1 (Generic Group Algorithm):**
An algorithm is **generic** if it only uses group operations (multiplication, inversion, equality testing) and does not exploit specific representation of group elements.

**Generic Group Model (GGM):**
In the GGM, group elements are represented by random labels (oracles), and algorithms can only:
- Compute `P ∘ Q` via group oracle
- Test `P = Q` via equality oracle

**Theorem 3.1 (Generic DLP Lower Bound, Shoup 1997):**
Any generic algorithm that solves DLP in a group of prime order `q` requires `Ω(√q)` group operations.

**Implication:**
For Ristretto255 with `q ≈ 2^252`, generic DLP requires ~`2^126` operations (infeasible).

**Caveat:**
This only applies to **generic** algorithms. Non-generic algorithms (exploiting curve structure) might be faster.

**Current State:**
- No known non-generic algorithm breaks DLP for Curve25519/Ristretto255
- Best known: Pollard's rho (`O(√q)` time, generic)

### Random Oracle Model (ROM)

**Definition 3.2 (Random Oracle):**
A **random oracle** `H : {0,1}* → {0,1}^n` is a truly random function: for each input `x`, `H(x)` is uniformly random in `{0,1}^n` (independent for different `x`).

**Random Oracle Model:**
Model cryptographic hash functions (SHA-512, SHA3-512) as random oracles.

**Properties:**
- Collision resistance: Finding `x ≠ y` with `H(x) = H(y)` requires `O(2^{n/2})` queries (birthday bound)
- Preimage resistance: Given `y`, finding `x` with `H(x) = y` requires `O(2^n)` queries
- Second preimage resistance: Given `x`, finding `x' ≠ x` with `H(x') = H(x)` requires `O(2^n)` queries

**Controversy:**
ROM is an idealization. Real hash functions are not truly random:
- Algorithms can exploit internal structure
- Some ROM-secure schemes are insecure with real hash functions

**Justification:**
- Practical hash functions (SHA-2, SHA-3) are **designed** to approximate random oracles
- No known attacks exploit structure for well-designed hashes
- ROM proofs give strong evidence of security

**Usage in CA:**
Fiat-Shamir transform uses SHA-512 modeled as random oracle (see Section 8).

### Standard Assumptions vs. Non-Standard

**Standard Assumptions (widely believed):**
1. **DLP**: Discrete logarithm is hard in elliptic curve groups
2. **CDH**: Computational Diffie-Hellman is hard
3. **DDH**: Decisional Diffie-Hellman is hard
4. **ROM**: Hash functions behave like random oracles

**Non-Standard Assumptions (protocol-specific):**
- Knowledge-of-exponent assumption (KEA)
- Algebraic group model (AGM)
- Strong Diffie-Hellman (SDH)

**CA Only Uses Standard Assumptions:**
All security proofs reduce to DLP, CDH, DDH, or ROM. No non-standard assumptions.

---

## ElGamal Encryption

### Construction

**Setup:**
- Group `G` of prime order `q` with generator `g`
- Secret key: `sk ∈ ℤ_q` (random)
- Public key: `pk = g^sk`

**Encryption of message `m ∈ G`:**
1. Choose random `r ← ℤ_q`
2. Compute ciphertext `(C₁, C₂)`:
   - `C₁ = g^r`
   - `C₂ = pk^r ∘ m = g^{sk·r} ∘ m`

**Decryption of ciphertext `(C₁, C₂)`:**
1. Compute `C₁^{sk} = (g^r)^{sk} = g^{r·sk}`
2. Compute `m = C₂ ∘ (C₁^{sk})^{-1} = (g^{r·sk} ∘ m) ∘ g^{-r·sk} = m`

### Correctness

**Theorem 4.1 (ElGamal Correctness):**
For all messages `m ∈ G`, all secret keys `sk ∈ ℤ_q`, and all randomness `r ∈ ℤ_q`:
```
Decrypt(sk, Encrypt(pk, m; r)) = m
```

**Proof:**
```
Decrypt(sk, (C₁, C₂))
  = C₂ ∘ (C₁^sk)^{-1}
  = (pk^r ∘ m) ∘ ((g^r)^sk)^{-1}
  = (g^{sk·r} ∘ m) ∘ (g^{r·sk})^{-1}
  = (g^{sk·r} ∘ m) ∘ g^{-sk·r}
  = m
```

### Semantic Security

**Definition 4.1 (Semantic Security):**
An encryption scheme is **semantically secure** if no PPT adversary can distinguish encryptions of two messages of its choice.

**Formal Game (IND-CPA):**
1. Challenger generates `(sk, pk)` and sends `pk` to adversary
2. Adversary chooses two messages `m₀, m₁ ∈ G`
3. Challenger chooses random `b ← {0, 1}`, encrypts `m_b`, sends ciphertext `C`
4. Adversary outputs guess `b' ∈ {0, 1}`

**Definition:**
Scheme is IND-CPA secure if:
```
|Pr[b' = b] - 1/2| ≤ negl(λ)
```
for all PPT adversaries.

**Theorem 4.2 (ElGamal is IND-CPA under DDH):**
ElGamal encryption is semantically secure (IND-CPA) under the DDH assumption.

**Proof Sketch:**
Suppose adversary `A` breaks ElGamal IND-CPA with non-negligible advantage `ε`. Construct DDH distinguisher `D`:

**DDH Distinguisher D(g, g^a, g^b, g^z):**
1. Set `pk = g^a` (treat `g^a` as public key)
2. Run `A(pk)`, receive challenge messages `m₀, m₁`
3. Choose random `b ← {0, 1}`
4. Construct ciphertext `C = (g^b, g^z ∘ m_b)`
5. Send `C` to `A`, receive guess `b'`
6. If `b' = b`, output "DDH tuple"; else output "random"

**Analysis:**
- If input is DDH tuple `(g, g^a, g^b, g^{ab})`:
  - `C = (g^b, g^{ab} ∘ m_b)` is valid ElGamal encryption of `m_b`
  - `A` succeeds with probability `1/2 + ε`
  - `D` outputs "DDH" with probability `1/2 + ε`

- If input is random `(g, g^a, g^b, g^c)` where `c` random:
  - `C = (g^b, g^c ∘ m_b)` is independent of `m_b` (perfect hiding)
  - `A` succeeds with probability `1/2` (no information about `b`)
  - `D` outputs "DDH" with probability `1/2`

**Advantage of D:**
```
|Pr[D outputs "DDH" | DDH tuple] - Pr[D outputs "DDH" | random]| = ε
```

This contradicts DDH assumption (if `ε` non-negligible). QED.

### Homomorphic Properties

**Theorem 4.3 (ElGamal Homomorphism):**
ElGamal encryption is **additively homomorphic**: for messages `m₁, m₂ ∈ G` and ciphertexts `C₁ = Enc(m₁), C₂ = Enc(m₂)`:
```
C₁ ∘ C₂ = Enc(m₁ ∘ m₂)
```

**Proof:**
```
C₁ = (g^{r₁}, pk^{r₁} ∘ m₁)
C₂ = (g^{r₂}, pk^{r₂} ∘ m₂)

C₁ ∘ C₂ = (g^{r₁} ∘ g^{r₂}, (pk^{r₁} ∘ m₁) ∘ (pk^{r₂} ∘ m₂))
        = (g^{r₁ + r₂}, pk^{r₁ + r₂} ∘ (m₁ ∘ m₂))
        = Enc(m₁ ∘ m₂; r₁ + r₂)
```

**Application in CA:**
Balances are encrypted using ElGamal. Homomorphism allows:
- **Transfer:** `Enc(balance_sender - amount) ∘ Enc(balance_receiver + amount)` computed without decryption
- **Balance updates:** Adding encrypted amounts without revealing plaintexts

---

## Sigma Protocols and Zero-Knowledge

### Definition of Sigma Protocols

**Definition 5.1 (Sigma Protocol):**
A **Sigma protocol** for relation `R ⊆ X × W` (where `X` is statements, `W` is witnesses) is a 3-move interactive protocol:

1. **Prover** (knows witness `w` for statement `x`):
   - Computes **commitment** `a` (depends on randomness)
   - Sends `a` to verifier

2. **Verifier**:
   - Chooses random **challenge** `e ← Challenge space`
   - Sends `e` to prover

3. **Prover**:
   - Computes **response** `z` (depends on `w, a, e`)
   - Sends `z` to verifier

4. **Verifier**:
   - Checks verification equation `Verify(x, a, e, z) ∈ {accept, reject}`

**Notation:**
Transcript `(a, e, z)` is called a **proof** or **conversation**.

### Properties of Sigma Protocols

**Property 1: Completeness**
If prover knows valid witness `w` for `x`, verifier always accepts (honest prover convinces honest verifier).

**Formal:**
```
∀(x, w) ∈ R: Pr[Verifier accepts | Prover knows w] = 1
```

**Property 2: Special Soundness**
From two accepting transcripts `(a, e, z)` and `(a, e', z')` with **same commitment** `a` but **different challenges** `e ≠ e'`, can extract witness `w` such that `(x, w) ∈ R`.

**Formal:**
```
∃ PPT extractor E:
  E((a, e, z), (a, e', z')) → w such that (x, w) ∈ R
```
whenever both transcripts are accepting and `e ≠ e'`.

**Implication:**
If prover can answer two different challenges for same commitment, it must "know" the witness.

**Property 3: Special Honest-Verifier Zero-Knowledge (SHVZK)**
There exists PPT simulator `S` that can produce transcripts indistinguishable from real proofs, **without knowing witness**.

**Formal:**
```
∃ PPT simulator S:
  S(x, e) → (a, z) such that (a, e, z) is accepting
  and distribution of (a, e, z) is indistinguishable from real proofs
```

**Implication:**
Transcripts reveal no information about witness (beyond statement validity).

### Schnorr Protocol for Discrete Logarithm

**Relation:**
```
R_DL = {(h, x) : h = g^x}
```
Statement: `h ∈ G`  
Witness: `x ∈ ℤ_q` such that `h = g^x`

**Protocol:**
1. **Prover** (knows `x`):
   - Choose random `r ← ℤ_q`
   - Compute `a = g^r` (commitment)
   - Send `a`

2. **Verifier**:
   - Choose random `e ← ℤ_q` (challenge)
   - Send `e`

3. **Prover**:
   - Compute `z = r + ex  mod q` (response)
   - Send `z`

4. **Verifier**:
   - Check `g^z = a · h^e` (verification)
   - If yes, accept; else reject

**Theorem 5.1 (Schnorr Completeness):**
If prover knows `x` such that `h = g^x`, verifier always accepts.

**Proof:**
```
g^z = g^{r + ex}
    = g^r · g^{ex}
    = a · (g^x)^e
    = a · h^e
```
QED.

**Theorem 5.2 (Schnorr Special Soundness):**
From two accepting transcripts `(a, e, z)` and `(a, e', z')` with `e ≠ e'`, can extract `x = (z - z') / (e - e')  mod q`.

**Proof:**
From verification equations:
```
g^z = a · h^e
g^{z'} = a · h^{e'}
```

Dividing:
```
g^{z - z'} = h^{e - e'}
g^{z - z'} = (g^x)^{e - e'}
g^{z - z'} = g^{x(e - e')}
```

Therefore:
```
z - z' = x(e - e')  mod q
x = (z - z') / (e - e')  mod q
```

Since `e ≠ e'` and `q` is prime, division is well-defined. QED.

**Theorem 5.3 (Schnorr SHVZK):**
Schnorr protocol is special honest-verifier zero-knowledge.

**Proof (Simulator Construction):**
Given statement `h` and challenge `e`, simulator produces transcript as follows:
1. Choose random `z ← ℤ_q`
2. Compute `a = g^z · h^{-e}`
3. Output `(a, e, z)`

**Verification:**
```
g^z = g^z · h^0
    = g^z · h^{-e} · h^e
    = a · h^e
```
Transcript is accepting.

**Indistinguishability:**
In real protocol, `(a, z)` are distributed as:
- `r ← ℤ_q`, `a = g^r`, `z = r + ex`

In simulation:
- `z ← ℤ_q`, `a = g^z · h^{-e}`

**Observation:**
For fixed `e`, both distributions are uniform over `ℤ_q × G` satisfying `g^z = a · h^e`.

Therefore, real and simulated transcripts are **perfectly indistinguishable**. QED.

### Proof of Knowledge

**Definition 5.2 (Proof of Knowledge):**
A protocol is a **proof of knowledge** for relation `R` if there exists PPT extractor `E` such that:
- `E` has **rewinding access** to prover
- With non-negligible probability, `E` extracts valid witness `w` such that `(x, w) ∈ R`

**Schnorr as Proof of Knowledge:**
Special soundness implies Schnorr is a proof of knowledge:
- Extractor rewinds prover after commitment `a`
- Obtains two transcripts `(a, e, z)` and `(a, e', z')`
- Extracts `x = (z - z')/(e - e')`

**Theorem 5.4 (Forking Lemma, Bellare-Neven 2006):**
If a prover succeeds in Schnorr protocol with probability `ε`, then there exists an extractor that obtains two valid transcripts with same commitment and different challenges with probability ≥ `ε²/q`.

**Implication:**
If `ε` is non-negligible, extraction succeeds with non-negligible probability.

---

## Fiat-Shamir Transform

### Interactive to Non-Interactive

**Problem:**
Sigma protocols are **interactive** (3 messages between prover and verifier). In blockchain context, interactions are expensive.

**Solution:**
**Fiat-Shamir transform** makes protocols **non-interactive** by replacing verifier's random challenge with hash of transcript.

### Construction

**Interactive Sigma Protocol:**
1. Prover → Verifier: commitment `a`
2. Verifier → Prover: challenge `e ← random`
3. Prover → Verifier: response `z`
4. Verifier: check `Verify(x, a, e, z)`

**Fiat-Shamir Transform:**
1. Prover computes commitment `a`
2. Prover computes challenge `e = H(domain_tag || context || x || a)` (hash replaces verifier)
3. Prover computes response `z`
4. Proof is `π = (a, z)` (challenge not included, verifier recomputes it)

**Verification:**
1. Recompute `e = H(domain_tag || context || x || a)`
2. Check `Verify(x, a, e, z)`

### Security in Random Oracle Model

**Theorem 6.1 (Fiat-Shamir Soundness in ROM, Pointcheval-Stern 2000):**
If the interactive Sigma protocol is special-sound, then the Fiat-Shamir transformed protocol is a **proof of knowledge** in the random oracle model.

**Proof Sketch:**
Suppose prover produces valid proof `π = (a, z)` with non-negligible probability `ε`. Construct extractor:

1. Run prover, obtain proof `(a, z)` with challenge `e = H(x || a)`
2. **Reprogram** random oracle: set `H(x || a) = e'` for fresh random `e' ≠ e`
3. Rewind prover to same state, obtain proof `(a, z')` with challenge `e'`
4. Extract witness from `(a, e, z)` and `(a, e', z')` via special soundness

**Key Insight:**
In ROM, extractor can **reprogram** the hash function to get different challenges. This simulates interactive extractor (forking lemma).

**Caveat:**
Security only holds in **random oracle model**. With real hash functions (SHA-512), security relies on:
- Hash function approximates random oracle
- No known attacks exploit structure

### Context Binding

**Problem:**
Without context, proofs can be **replayed** in different transactions.

**Solution:**
Include **context** in hash:
```
e = H(DST || context || x || a)
```

**Context includes:**
- Transaction hash (unique per transaction)
- Nonce (prevents replay within same transaction)
- Protocol identifier (prevents cross-protocol attacks)

**Domain Separation Tag (DST):**
Unique string identifying protocol instance:
```
DST_registration = "CONFIDENTIAL_ASSET_REGISTRATION_V1"
DST_withdrawal = "CONFIDENTIAL_ASSET_WITHDRAWAL_V1"
DST_transfer = "CONFIDENTIAL_ASSET_TRANSFER_V1"
```

**Theorem 6.2 (Context Binding Prevents Replay):**
If `e = H(DST || context || x || a)` and `H` is modeled as random oracle, then valid proof for context `ctx₁` cannot be used for different context `ctx₂`.

**Proof:**
Suppose proof `π = (a, z)` is valid for `ctx₁`. For it to be valid for `ctx₂`:
```
Verify(x, a, H(DST || ctx₁ || x || a), z) = accept
Verify(x, a, H(DST || ctx₂ || x || a), z) = accept
```

By special soundness, this requires prover to answer **two different challenges** for **same commitment** `a`. If `ctx₁ ≠ ctx₂`, then:
```
H(DST || ctx₁ || x || a) ≠ H(DST || ctx₂ || x || a)
```
with overwhelming probability (random oracle collision resistance).

Therefore, prover must know witness (by proof of knowledge property). QED.

---

## Homomorphic Properties

### ElGamal Homomorphism in Detail

**Addition of Ciphertexts:**
```
Enc(m₁; r₁) = (g^{r₁}, h^{r₁} · m₁)
Enc(m₂; r₂) = (g^{r₂}, h^{r₂} · m₂)

Enc(m₁; r₁) ∘ Enc(m₂; r₂) = (g^{r₁ + r₂}, h^{r₁ + r₂} · (m₁ · m₂))
                             = Enc(m₁ · m₂; r₁ + r₂)
```

**Scalar Multiplication:**
```
[n] Enc(m; r) = (g^{nr}, h^{nr} · m^n) = Enc(m^n; nr)
```

**Application to Balances:**
If balances are encrypted as `Enc(g^balance)` (exponential ElGamal), then:
```
Enc(g^{b₁}) ∘ Enc(g^{b₂}) = Enc(g^{b₁ + b₂})
```

This allows **homomorphic addition** of encrypted balances.

**Transfer Protocol:**
```
sender_balance := Enc(g^s)
receiver_balance := Enc(g^r)
transfer_amount := amount  (public)

new_sender_balance := sender_balance ∘ Enc(g^{-amount})
                     = Enc(g^s) ∘ Enc(g^{-amount})
                     = Enc(g^{s - amount})

new_receiver_balance := receiver_balance ∘ Enc(g^{amount})
                       = Enc(g^r) ∘ Enc(g^{amount})
                       = Enc(g^{r + amount})
```

**Zero-Knowledge Proof:**
Prover must show:
1. `new_sender_balance` correctly updated (homomorphic subtraction)
2. `new_receiver_balance` correctly updated (homomorphic addition)
3. Sender knows decryption of `new_sender_balance` (hasn't gone negative)

All provable via Sigma protocols.

### Re-Randomization

**Definition 7.1 (Re-randomization):**
Given ciphertext `C = (C₁, C₂) = (g^r, h^r · m)`, produce new ciphertext `C'` encrypting same message with **different randomness**.

**Construction:**
```
C' = C ∘ Enc(e; r')
   = (g^r, h^r · m) ∘ (g^{r'}, h^{r'} · e)
   = (g^{r + r'}, h^{r + r'} · m)
```
where `e` is group identity.

**Application:**
**Normalization** operation in CA re-randomizes encrypted balance to prevent linking transactions.

---

## Security Reductions

### Reduction Proofs

**Definition 8.1 (Security Reduction):**
A **reduction** from problem `A` to problem `B` is an algorithm `R` that:
- Uses adversary `A_adv` for `A` as a subroutine
- Solves problem `B`

**Implication:**
If `B` is hard, then `A` must be hard (contrapositive: if `A` is easy, then `B` is easy).

### ElGamal Security Reduction to DDH

**Theorem:** ElGamal is IND-CPA secure under DDH assumption.

**Proof (Reduction):**
Given DDH distinguisher `D`, construct ElGamal adversary `A`.

**ElGamal Adversary A:**
1. Receive DDH instance `(g, g^a, g^b, g^c)`
2. Set public key `pk = g^a`
3. Choose random bit `b ← {0, 1}`
4. Receive challenge messages `m₀, m₁` from environment
5. Construct ciphertext `C = (g^b, g^c · m_b)`
6. Send `C` to environment, receive guess `b'`
7. If `b' = b`, output "DDH tuple"; else output "random"

**Analysis:**
- If `(g, g^a, g^b, g^c)` is DDH tuple (`c = ab`):
  - `C = (g^b, g^{ab} · m_b)` is valid ElGamal encryption
  - Environment's advantage is `ε` (by assumption)
  - `A` outputs "DDH" with probability `1/2 + ε`

- If `(g, g^a, g^b, g^c)` is random:
  - `C = (g^b, g^c · m_b)` is independent of `m_b`
  - Environment has no advantage (probability `1/2`)
  - `A` outputs "DDH" with probability `1/2`

**Advantage of A:**
```
Adv_DDH(A) = ε
```

Therefore: `ε ≤ Adv_DDH(A)`. If DDH is hard (`Adv_DDH negligible`), then `ε` is negligible. QED.

### Schnorr Soundness Reduction to DLP

**Theorem:** Schnorr protocol is a proof of knowledge under DLP assumption.

**Proof (Reduction):**
Suppose Schnorr prover succeeds with probability `ε` without knowing discrete log. Construct DLP solver:

**DLP Solver D(g, h):** (goal: find `x` such that `h = g^x`)
1. Run Schnorr prover on instance `h`
2. Obtain accepting transcript `(a, e, z)` with probability `ε`
3. Rewind prover to same randomness, obtain second transcript `(a, e', z')` with different challenge
4. Extract `x = (z - z')/(e - e')` via special soundness
5. Return `x`

**Success Probability:**
By forking lemma, two transcripts obtained with probability ≥ `ε²/q`. If `ε` non-negligible, this is non-negligible.

Therefore: If Schnorr prover succeeds, DLP can be solved. Contrapositive: If DLP is hard, Schnorr prover must know witness. QED.

---

## Formalization in Lean

### Axiomatizing Cryptographic Primitives

**Challenge:**
Cryptographic assumptions (DLP, DDH, ROM) are about **computational complexity**, but Lean is a **logic** (not a complexity framework).

**Solution:**
**Axiomatize** cryptographic properties as assumptions:

```lean
-- Ristretto255 group structure
axiom Ristretto255 : Type
axiom Ristretto255.add : Ristretto255 → Ristretto255 → Ristretto255
axiom Ristretto255.zero : Ristretto255
axiom Ristretto255.neg : Ristretto255 → Ristretto255

-- Group axioms
axiom Ristretto255.add_assoc : ∀ a b c, add (add a b) c = add a (add b c)
axiom Ristretto255.add_zero : ∀ a, add a zero = a
axiom Ristretto255.add_neg : ∀ a, add a (neg a) = zero
axiom Ristretto255.add_comm : ∀ a b, add a b = add b a

-- Scalar multiplication
axiom Scalar : Type
axiom scalarMultBase : Scalar → Ristretto255
axiom scalarMult : Scalar → Ristretto255 → Ristretto255

-- Cryptographic assumptions (axiomatized)
axiom verifySchnorrProof : Proof → PublicKey → Option Witness
axiom verifySchnorrProof_sound :
  ∀ proof pk witness,
    verifySchnorrProof proof pk = some witness →
    SchnorrRelation proof pk witness
```

**Interpretation:**
- Axioms encode **interface** of cryptographic primitives
- `verifySchnorrProof_sound` encodes **soundness property** (if oracle says valid, witness exists)
- **No implementation** in Lean (oracle is black box)

**Validation:**
Axioms are validated externally:
1. **Cryptographic analysis**: Security proofs (Section 8)
2. **Difftest**: Oracle behavior matches real VM execution

### Modeling Encrypted Balances

**Definition:**
```lean
structure EncryptedBalance where
  C₁ : Ristretto255  -- g^r
  C₂ : Ristretto255  -- h^r · g^balance

-- Encryption function (abstracted)
axiom encrypt : PublicKey → Nat → Randomness → EncryptedBalance
axiom decrypt : SecretKey → EncryptedBalance → Option Nat

-- Correctness axiom
axiom encrypt_decrypt :
  ∀ sk pk balance r,
    pk = scalarMultBase sk →
    decrypt sk (encrypt pk balance r) = some balance

-- Homomorphic property
axiom encrypt_add :
  ∀ pk b₁ b₂ r₁ r₂,
    EncryptedBalance.add (encrypt pk b₁ r₁) (encrypt pk b₂ r₂) =
    encrypt pk (b₁ + b₂) (r₁ + r₂)
```

**Usage in Proofs:**
```lean
theorem transfer_correctness :
    decrypt sk (new_sender_balance) = some (old_balance - amount) := by
  rw [new_sender_balance_def]
  rw [encrypt_add]
  rw [encrypt_decrypt]
  omega
```

### Oracle Modeling Pattern

**Pattern:**
For each native function, define:
1. **Signature** (input/output types)
2. **Soundness axiom** (if oracle succeeds, relation holds)
3. **Completeness axiom** (if relation holds, oracle succeeds)
4. **Determinism axiom** (same input → same output)

**Example: Withdrawal Proof Verification:**
```lean
-- Signature
axiom verifyWithdrawalProof :
  WithdrawalProof → EncryptedBalance → Option Witness

-- Soundness
axiom verifyWithdrawalProof_sound :
  ∀ proof balance witness,
    verifyWithdrawalProof proof balance = some witness →
    ValidWithdrawalWitness proof balance witness

-- Completeness
axiom verifyWithdrawalProof_complete :
  ∀ proof balance witness,
    ValidWithdrawalWitness proof balance witness →
    ∃ w, verifyWithdrawalProof proof balance = some w

-- Determinism
axiom verifyWithdrawalProof_deterministic :
  ∀ proof balance w₁ w₂,
    verifyWithdrawalProof proof balance = some w₁ →
    verifyWithdrawalProof proof balance = some w₂ →
    w₁ = w₂
```

**Justification:**
These axioms are **trusted assumptions** justified by:
1. Cryptographic security proofs (this document)
2. Implementation correctness (Rust code review)
3. Empirical validation (Difftest)

---

## Proofs of Security Properties

### Balance Confidentiality

**Claim:**
Encrypted balances do not reveal plaintext amounts.

**Formal Statement:**
For any PPT adversary `A`:
```
Adv[A distinguishes Enc(b₁) from Enc(b₂)] ≤ negl(λ)
```

**Proof:**
Reduce to ElGamal IND-CPA security (Theorem 4.2):
- Balances encrypted as `Enc(g^balance)` using ElGamal
- ElGamal is IND-CPA under DDH (proven in Section 6)
- DDH holds for Ristretto255 (Section 4)

Therefore: Balance confidentiality holds under DDH assumption. QED.

**In Lean:**
```lean
-- Confidentiality axiom (abstracted)
axiom balance_confidentiality :
  ∀ balance₁ balance₂ pk r₁ r₂,
    encrypt pk balance₁ r₁ ≠ encrypt pk balance₂ r₂ →
    ¬ ∃ (distinguisher : EncryptedBalance → Bool),
      distinguisher (encrypt pk balance₁ r₁) ≠ 
      distinguisher (encrypt pk balance₂ r₂)
```

(Computational property axiomatized as logical statement.)

### Balance Integrity

**Claim:**
Users cannot create funds from nothing or spend more than their balance.

**Formal Statement:**
For any PPT adversary `A`:
```
Pr[A produces valid proof for invalid balance operation] ≤ negl(λ)
```

**Proof:**
Reduce to Schnorr soundness (Theorem 5.2):
- Withdrawal requires proof that decrypted balance ≥ amount
- Transfer requires proof that sender balance decreases correctly
- Both use Schnorr-based sigma protocols
- Schnorr is sound under DLP (Section 7)

Therefore: Balance integrity holds under DLP assumption. QED.

**In Lean:**
```lean
theorem withdrawal_integrity :
    verifyWithdrawalProof proof balance = some witness →
    decrypt sk balance = some b →
    b ≥ amount := by
  intro h_verify h_decrypt
  have h_sound := verifyWithdrawalProof_sound proof balance witness h_verify
  cases h_sound
  -- Use soundness to derive balance constraint
  omega
```

### Non-Malleability

**Claim:**
Proofs cannot be replayed or modified for different contexts.

**Formal Statement:**
For any PPT adversary `A` and valid proof `π` for context `ctx₁`:
```
Pr[A produces valid proof π' for context ctx₂ ≠ ctx₁ without knowing witness] ≤ negl(λ)
```

**Proof:**
By Fiat-Shamir context binding (Theorem 6.2):
- Challenge includes `H(DST || ctx || x || a)`
- If `ctx₁ ≠ ctx₂`, challenges differ (ROM)
- Answering two different challenges requires knowing witness (special soundness)

Therefore: Non-malleability holds in ROM. QED.

**In Lean:**
```lean
axiom proof_context_binding :
  ∀ proof ctx₁ ctx₂,
    ctx₁ ≠ ctx₂ →
    verifyProof ctx₁ proof = some witness →
    verifyProof ctx₂ proof = none
```

---

## Cross-References

### Related Documentation

**Implementation:**
- `SIGMA_PROTOCOL_THEORY_AND_PRACTICE.md` - Protocol implementations
- `ADVANCED_LEAN_PROOF_TECHNIQUES_GUIDE.md` - Formalization techniques
- `AXIOM_INVENTORY.md` - Complete axiom catalog

**Security:**
- `SECURITY_REVIEW_AND_THREAT_MODEL_GUIDE.md` - Threat analysis
- `TRUST_BOUNDARIES.md` - Assumptions and limitations

**Verification:**
- `PHASE_6_PC_CHAINING_DETAILED_TUTORIAL.md` - Proof implementation
- `MSL_SPECIFICATION_PATTERNS_GUIDE.md` - Specification techniques

### External Resources

**Cryptography Textbooks:**
- Katz & Lindell, "Introduction to Modern Cryptography" (2nd ed., 2014)
- Boneh & Shoup, "A Graduate Course in Applied Cryptography" (2020)
- Goldreich, "Foundations of Cryptography" (2001, 2004)

**Sigma Protocols:**
- Cramer, Damgård, Schoenmakers, "Proofs of Partial Knowledge and Simplified Design of Witness Hiding Protocols" (CRYPTO 1994)
- Damgård, "On Σ-protocols" (Lecture notes, 2010)

**Fiat-Shamir Transform:**
- Fiat & Shamir, "How to Prove Yourself" (CRYPTO 1986)
- Pointcheval & Stern, "Security Arguments for Digital Signatures and Blind Signatures" (J. Cryptology, 2000)

**Elliptic Curves:**
- Silverman, "The Arithmetic of Elliptic Curves" (2nd ed., 2009)
- Washington, "Elliptic Curves: Number Theory and Cryptography" (2nd ed., 2008)

**Ristretto:**
- de Valence, Lovecruft, et al., "Ristretto: Prime-Order Groups from Non-Prime-Order Curves" (2019)
- Spec: https://ristretto.group/

---

## Maintenance

### Document Ownership

- **Author**: Cryptography team, Verification team
- **Reviewers**: Cryptographers, Security lead
- **Approver**: CTO
- **Last Review**: 2026-04-22
- **Next Review**: 2026-07-22 (quarterly)

### Updates

When cryptographic assumptions change:
1. Update relevant sections
2. Re-validate security reductions
3. Update axiom justifications in `AXIOM_INVENTORY.md`
4. Re-run security review

### Feedback

Questions or corrections?
- **Math/crypto questions**: crypto-team@movementlabs.xyz
- **Formalization questions**: verification-team@movementlabs.xyz
- **Security concerns**: security@movementlabs.xyz

---

**End of Guide**

Total pages: ~45 (~35K characters)
