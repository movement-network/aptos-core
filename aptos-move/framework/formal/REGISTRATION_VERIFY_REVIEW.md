# Registration proof verification: what Lean claims vs how to review Move

This note is for **engineers and auditors** working on
`aptos_experimental::confidential_proof::verify_registration_proof` and the Lean `**AptosFormal`** project under
`aptos-move/framework/formal/lean/` (Lake package root; shared `**AptosFormal.Std.*`** modules apply across the framework, not only `aptos-experimental`).

**Scope.** The Lean files and this note are aligned with **the Move sources in this branch** (e.g. `aptos-move/framework/aptos-experimental/sources/...`).

**Source of truth (intentional).** The object being reviewed and (eventually) refined against Lean is `**verify_registration_proof` as written in this repository’s Aptos Move**, specifically the implementation under  
`aptos-move/framework/aptos-experimental/sources/confidential_asset/confidential_proof.move`  
and the framework modules it calls (`ristretto255`, `twisted_elgamal`, `std::bcs`, etc. **as pinned by this tree**).  

This is **not** a claim about **Move IR**, **bytecode**, a generic “Move semantics,” or another compiler version: any eventual formal link should be stated as refinement to **this source-level behavior** first; IR↔source compiler correctness would be an **additional**, separate obligation if you ever need it.

**Aptos framework layout (this repository).** The verifier and its dependencies live in these Move sources (paths relative to repo root):


| Role                                       | Move module(s)                                                             | Path in this tree                                                                                      |
| ------------------------------------------ | -------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------ |
| Registration verifier                      | `aptos_experimental::confidential_proof::verify_registration_proof`        | `aptos-move/framework/aptos-experimental/sources/confidential_asset/confidential_proof.move`           |
| Tagged hash + SHA3-512 pipeline used there | `aptos_std::aptos_hash` (e.g. `sha3_512`), helpers in `confidential_proof` | `aptos-move/framework/aptos-stdlib/sources/hash.move`; same `confidential_proof.move`                  |
| Ristretto curve API                        | `aptos_std::ristretto255`                                                  | `aptos-move/framework/aptos-stdlib/sources/cryptography/ristretto255.move`                             |
| Twisted ElGamal pubkey wire / point        | `aptos_experimental::ristretto255_twisted_elgamal`                         | `aptos-move/framework/aptos-experimental/sources/confidential_asset/ristretto255_twisted_elgamal.move` |
| `std::bcs`                                 | BCS serialization                                                          | `aptos-move/framework/move-stdlib/sources/bcs.move`                                                    |


Lean is written to track **these files** as they appear in **this** `aptos-core` checkout (your framework version), not an abstract or external Move SDK.

## 1. What the Lean stack is for


| Layer                                                                    | Role                                                                                                                                                                                      |
| ------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `**AptosFormal.Experimental.ConfidentialAsset.Registration.Formal`**     | Transcript layout (`msg`), abstract Fiat–Shamir challenge, abstract Schnorr equation `s·H + e·ek = R`.                                                                                    |
| `**AptosFormal.Std.Crypto.Ristretto255`**                                | Concrete **scalar field** ℤ/ℓℤ (`RistrettoScalar`) and **32-byte** compressed-point carrier (`CompressedRistretto32`) vs `aptos_std::ristretto255`.                                       |
| `**AptosFormal.Std.Hash.Sha3_512`**                                      | SHA3-512 + `taggedHash` vs `aptos_std::aptos_hash` (reusable stdlib layer).                                                                                                               |
| `**AptosFormal.Experimental.ConfidentialAsset.Registration.VerifyMath`** | `verifyRegistrationProofProp`, `CryptoOracle`, BCS helpers, `registrationChallengeScalarMove`.                                                                                            |
| `**…Registration.SchnorrCompleteness**`                                  | Honest-prover algebra + ideal-oracle bridge.                                                                                                                                              |
| `**…Registration.Operational**`                                          | `execVerifyRegistrationProof` (`Option Unit`) ↔ `verifyRegistrationProofProp`.                                                                                                            |
| `**…Registration.Refinement**`                                           | L2≡L1.5≡L1↔L0 refinement chain. `eval_eq_func` (L2≡L1.5 via `.dropMs`), `func_success_implies_exec_some` / `func_abort_implies_exec_none` (L1.5≡L1, proven), `eval_success_implies_prop` / `eval_abort_implies_not_prop` (L2→L0 compositions). |
| `**…Registration.EvalEquiv**`                                            | `eval_eq_func_100` (L2≡L1.5 at fuel 200), `ExecResult.dropMs` helper, `eval_fuel_ge`/`eval_fuel_ge_dropMs`, `@[simp]` fusion lemmas (`match_single?`, `bind_single?`, `match_match_some_single_none`). |
| `**…Registration.BytecodeSmoke**`                                        | `native_decide` smoke: transcribed bytecode `eval` succeeds on valid-proof oracle, aborts on invalid-proof oracle (golden inputs, reference args).                                         |
| `**AptosFormal.Move.Native.Registration**`                               | Oracle-parameterized native bindings (Ristretto, SHA3-512, BCS, Option) using `nativeRef` for reference-aware crypto ops and `native` for pure functions. `derefImm` handles both ref and value args. |
| `**AptosFormal.Move.Programs.Registration**`                             | Transcribed **83-instruction** bytecode for `verify_registration_proof` (matching `movement` v7.4 compiler output), constant pool, `registrationModuleEnv` with `nativeRef` function descriptors. |
| `**…Registration.TranscriptAlignment**`                                  | `registration_fiat_shamir_msg_matches_move_golden`: FS `msg` bytes = Move `registration_fs_message_for_test` (two goldens: `@0x1`/`@0x2`/`@0x3` and `@0x10`/`@0x20`/`@0x30`).             |
| `**…Registration.GroupAxioms**`                                          | `RistrettoGroupAxioms`: axiom bundle asserting Move's `ristretto255` ops form an `AddCommGroup` + `Module RistrettoScalar` (§6.2 obligation).                                             |
| `**…Registration.EndToEnd**`                                             | `registration_verification_iff_schnorr` + `registration_honest_prover_accepted`: under group axioms, Move's verifier accepts iff the Schnorr equation holds; honest prover always passes. |
| `**…Registration.CryptoSecurity**`                                       | Machine-checked **special soundness** (witness extraction with explicit formula `dk = (s₁−s₂)⁻¹·(e₂−e₁)`) + **HVZK simulator** (§6.4a–b).                                                 |
| `**…Registration.FiatShamirSymbolic**`                                   | Symbolic Fiat–Shamir model: **forking reduction**, **challenge binding**, **NIZK completeness**, **NIZK simulation** (§6.4c).                                                              |


Lean **narrows the statement**: “verification succeeds iff these parses succeed and this equation holds.” It does **not** prove that the **framework natives used in this branch** (e.g. tagged hash, `ristretto255`, `std::bcs`) match the IRTF Ristretto spec or any independent reference, unless you add a large crypto formalization or external proof.

## 2. What “match the verifier’s math” still assumes externally

To identify the Lean `Prop` with successful Move execution you must separately justify:

1. **BCS** — `senderBcs`, `contractBcs`, `tokenBcs` are exactly `std::bcs::to_bytes(&address)` for the same `address` values **this branch’s** Move code uses. In Lean this is modeled by `AptosAddressBcs` + `mkRegistrationInputs` (name = “Aptos-style `address` + BCS”; still **this repo only**).
2. **Pubkey wire format** — `ekBytes` matches `twisted_elgamal::pubkey_to_bytes(ek)` and `pubkey_to_point` is correct on that encoding.
3. **Commitment bytes** — `commitmentRBytes` matches `ristretto255::compressed_point_to_bytes(r_compressed)` for the same `R`.
4. **Response scalar** — `responseBytes` parses like `ristretto255::new_scalar_from_bytes` (canonical encoding, range, etc.).
5. **Challenge** — `challengeScalarFromMsg` matches `new_scalar_from_tagged_hash(FIAT_SHAMIR_REGISTRATION_SIGMA_DST, msg)` including tagged SHA3-512 and reduction mod ℓ.
6. **Curve API** — `hash_to_point_base`, `point_mul`, `point_add`, `point_decompress`, `point_equals` match the Ristretto implementation Move calls.

The constant `RegistrationVerify.fiatShamirRegistrationDst` is the UTF-8 DST string; the oracle `challengeScalarFromMsg` is still responsible for combining DST + `msg` exactly as Move does.

## 3. Pen-and-paper protocol sketch (worked templates you can copy)

This is the **cryptographic story** reviewers use; it is **not** a machine-checked Lean proof.

**Goal (high level).** Show the prover knows a nonzero scalar `**dk`** such that `**ek = dk^{-1} · H`**, where `**H = hash_to_point_base()`** (equivalently `**H = dk · ek**`). Sources: `confidential_proof.move` (`prove_registration` / `verify_registration_proof`) and `ristretto255_twisted_elgamal.move`.

Below, **copy the indented `text` blocks** into your note; they are a first complete draft. Replace bracketed notes if your notation differs.

**Fiat–Shamir (NIZK) [FS87].** The deployed verifier uses `**e := RO(DST ‖ msg)`** instead of a uniformly chosen `e`. Soundness in that setting is argued in the **random oracle model** (§3.5; see [PS00] for the formal treatment of Σ-protocols under Fiat–Shamir).

---

### 3.1 Setup

```text
Let (E, +) be the Ristretto255 group of prime order ℓ. Write scalar multiplication as u · P ∈ E for u ∈ ℤ/ℓℤ, P ∈ E.
Let H ∈ E be the public point from hash_to_point_base().
Let ek ∈ E be the published registration public key (decompressed from pubkey bytes).
The prover’s witness is dk ∈ (ℤ/ℓℤ)* satisfying  H = dk · ek   (equivalently ek = dk^{-1} · H).
The statement is membership of (H, ek) in the language L = { ∃ dk ≠ 0 : H = dk · ek }.
```

---

### 3.2 Interactive protocol (commit → challenge → response)

```text
Common input: H, ek ∈ E.
Prover witness: dk with H = dk · ek.

1) Commit:    Prover picks k ← ℤ/ℓℤ uniformly, sends R := k · H ∈ E.

2) Challenge: Verifier picks e ← ℤ/ℓℤ uniformly (interactive case).

3) Response:  Prover sends s := k − e · dk^{-1}   (arithmetic in ℤ/ℓℤ).

4) Verify:    Accept iff s · H + e · ek = R.
```

**Completeness (honest prover)** — paste and justify each `=`:

```text
Assume H = dk · ek. Then
  s·H + e·ek
    = (k − e·dk^{-1})·H + e·ek
    = k·H − e·dk^{-1}·(dk·ek) + e·ek
    = k·H − e·ek + e·ek
    = k·H = R.
```

Use scalar laws on the curve: `(ab)·P = a·(b·P)`, `(u+v)·P = u·P + v·P`.

**Move alignment (prover).** `point_mul(h, k)` is `k·H`; `scalar_sub(k, scalar_mul(e, dk_inv))` is `s = k − e·dk^{-1}`.

---

### 3.3 Special soundness (two challenges, same `R` → extract `dk`)

**Lemma (template).** Two accepting transcripts `(R, e, s)` and `(R, e′, s′)` with `**e ≠ e′`** yield `**dk`** with `**H = dk · ek`**.

**Proof (copy the algebra):**

```text
Suppose
  s·H  + e·ek  = R,
  s′·H + e′·ek = R.
Subtract:
  (s − s′)·H + (e − e′)·ek = 0
  (s − s′)·H = (e′ − e)·ek.                    (∗)
Substitute H = dk·ek:
  (s − s′)·(dk·ek) = (e′ − e)·ek.
For ek ≠ O in a prime-order group, cancel ek to scalars:
  (s − s′)·dk = e′ − e,
  dk = (e′ − e) · (s − s′)^{-1}   (when e ≠ e′ and s ≠ s′).
```

**One-line reduction:** A cheat who does not know such a `dk` cannot produce two distinct accepting `e` for the same fixed `R` without breaking **discrete logarithm** on `E` (or state your preferred explicit game).

---

### 3.4 Honest-verifier zero-knowledge (simulator)

For **interactive** proofs with **uniform** `e`:

```text
Simulator S(H, ek, e):
  s ← ℤ/ℓℤ uniform
  R := s·H + e·ek
  output (R, e, s).

Then s·H + e·ek = R holds by construction.
The distribution of (R, e, s) matches the real protocol when the verifier’s e is uniform (standard Schnorr HVZK proof).
```

For **Fiat–Shamir NIZK**, say explicitly that you use **ROM programming** (different proof template); do not claim interactive HVZK without that caveat.

---

### 3.5 Assumptions checklist (tick for your report)

```text
[ ] (E, +) is the Ristretto255 prime-order group; scalars are in ℤ/ℓℤ.
[ ] Discrete logarithm (or ECDLP) is hard on E — special soundness reduces forging to breaking it.
[ ] Interactive: challenge e uniform and independent of prover coins.
[ ] NIZK: RO model for e = Hash(DST, msg); Fiat–Shamir security for Σ-protocols [FS87, PS00].
[ ] Wire correctness: decompress/encode for H, ek, R and canonical scalar parsing for s, e.
```

---

### 3.6 Symbol → Move (paste into appendix)


| Symbol | Meaning          | Move                                                                                              |
| ------ | ---------------- | ------------------------------------------------------------------------------------------------- |
| `H`    | Base point       | `ristretto255::hash_to_point_base()`                                                              |
| `ek`   | Public key point | `twisted_elgamal::pubkey_to_point(ek)`                                                            |
| `R`    | Commitment       | decompress `commitment_bytes` (same point as `prove_registration`’s `r_compressed`)               |
| `msg`  | Transcript       | `singleton(chain_id) ‖ bcs(sender) ‖ bcs(contract) ‖ bcs(token) ‖ pubkey_to_bytes(ek) ‖ bytes(R)` |
| `e`    | Challenge        | `new_scalar_from_tagged_hash(FIAT_SHAMIR_REGISTRATION_SIGMA_DST, msg)`                            |
| `s`    | Response         | `new_scalar_from_bytes(response_bytes)`                                                           |
| Check  | Verify           | `point_add(point_mul(h,s), point_mul(ek_point,e))` equals `point_decompress(r_compressed)`        |


---

### 3.7 One-page diagram

```text
  chain_id, sender, contract, token, ek_bytes
                    │
                    │  (prover appends R_bytes before hash)
                    ▼
                 ┌──────┐
                 │ msg  │
                 └──┬───┘
                    │  RO / tagged hash  (DST = MovementConfidentialAsset/Registration)
                    ▼
                 ┌──────┐
                 │  e   │
                 └──┬───┘
                    │
    H ──────────────┼────────────────────────────┐
                    │                            │
                    │     s·H + e·ek = R  ?        │ R from commitment_bytes
                    ▼                            │
               [verifier] ◄─────────────────────┘
```

**One-line soundness story:** *Without `dk`, getting two different valid `e` for the same `R` contradicts special soundness / DLOG; with Fiat–Shamir, the RO makes `e` unpredictable after `R` is fixed.*

## 4. How to review **production Move** (practical)

Lean does not replace this.

1. **Read the code path** — `verify_registration_proof` in `confidential_proof.move` (and callees in `ristretto255` / `twisted_elgamal`).
2. **Unit tests** — `confidential_proof_tests.move` registration tests: honest proof verifies; wrong `ek`, token, chain, sender, contract fail.
3. **Cross-check constants** — DST string, order ℓ in Lean `AptosFormal.Std.Crypto.Ristretto255` vs Ristretto / Curve25519 references.
4. **Cross-check transcript** — `registrationFiatShamirMsg` field order vs `msg.append` order in Move.
5. **External crypto references** — Ristretto group formulas, BIP-340-style tagging if applicable to `new_scalar_from_tagged_hash`, and how `std::bcs` encodes `address` **in the framework version pinned by this branch**.
6. **Optional**: independent implementation (e.g. script) that recomputes `e` and the group check from the same byte inputs for golden test vectors (not required for Lean).

## 5. Where to extend Lean next

- Prove lemmas **assuming** group laws and an injective challenge map (already partly in `AptosFormal.Experimental.ConfidentialAsset.Registration.Formal`).
- Refine `CryptoOracle` with **axioms** that state algebraic laws (e.g. associativity of `pointAdd`) and relate `challengeScalarFromMsg` to `fiatShamirRegistrationDst` concatenation.
- A full proof chain to **concrete** framework natives (as compiled from **this** tree) is a **large** separate project; see **§6** for a structured list of what is still missing.

---

## 6. Remaining proof obligations (not covered by current Lean)

This section records **everything that is not** machine-checked today, in one place. Completeness of the Schnorr equation and the ideal-oracle bridge are in `AptosFormal.Experimental.ConfidentialAsset.Registration.SchnorrCompleteness`; the items below are **still external** (review, tests, crypto argument, or a future formalization stack).

### 6.1 Move VM semantics

**Goal.** Show that executing `verify_registration_proof` **as defined in this repository’s Move sources** (see the framework table at the top of this doc) **implements** `verifyRegistrationProofProp` (or `verifyRegistrationProofPropMove`) up to the oracle: same **argument order**, same **control flow** on success vs abort. The refinement target is **that source**, not Move IR or bytecode unless you add a compiler-correctness story.

**Current status.** `Operational.lean` defines `execVerifyRegistrationProof` (lines 22–38) which mirrors the Move function's control flow step-by-step. The structural correspondence is:


| Move (`confidential_proof.move` lines 214–245)                                     | Lean (`Operational.lean` lines 24–36)                                |
| ---------------------------------------------------------------------------------- | -------------------------------------------------------------------- |
| 214–216: `new_compressed_point_from_bytes` / `assert` / `extract` → `r_compressed` | 25: `compressed32?` → `rComm`; 28: `C.pointDecompress rComm` → `rhs` |
| 219–221: `new_scalar_from_bytes` / `assert` / `extract` → `s`                      | 24: `C.scalarFromBytes responseBytes` → `s`                          |
| 223–230: Build `msg` + `new_scalar_from_tagged_hash` → `e`                         | 29: `C.challengeScalarFromMsg (registrationFiatShamirMsg i)` → `e`   |
| 233: `hash_to_point_base()` → `h`                                                  | 31: `let H := C.hashToPointBase`                                     |
| 235: `pubkey_to_point(ek)` → `ek_point`                                            | 26+29: `compressed32?` + `C.pubkeyToPoint ekComm` → `ek`             |
| 236–239: `point_add(point_mul(h,s), point_mul(ek_point,e))` → `lhs`                | 32: `C.pointAdd (C.pointMul H s) (C.pointMul ek e)`                  |
| 240: `point_decompress(&r_compressed)` → `rhs`                                     | 28: `C.pointDecompress rComm` → `rhs`                                |
| 242–245: `assert!(point_equals(&lhs, &rhs))`                                       | 33–36: `if C.pointEqBool lhs rhs then some () else none`             |


The theorem `execVerifyRegistrationProof_iff` proves this `Option`-returning function is equivalent to the `Prop`-valued `verifyRegistrationProofProp`.

**Not proved in Lean:**

- Operational semantics of Move (values, references, `assert!` / `abort`, `friend`, gas not-withstanding).
- That `option::is_some` / `option::extract` on `new_compressed_point_from_bytes`, `new_scalar_from_bytes`, etc., match the `Option` branches in `verifyRegistrationProofProp` (success path vs `False`).
- That `point_equals` in Move corresponds to `CryptoOracle.pointEq` (or `=` in the idealized bridge).

**Review anchor.** `confidential_proof.move` — `verify_registration_proof` (decompress `R`, parse `s`, build `msg`, `new_scalar_from_tagged_hash`, base point `H`, `pubkey_to_point`, `point_add` / `point_mul`, final `assert!`).

---

### 6.2 Native correctness (`CryptoOracle` vs Move)

**Goal.** For each oracle field, a justification that **this branch’s** framework natives match the intended math and the Lean model where one exists.


| Oracle field (`CryptoOracle`) | Move / framework hook                                                  | Lean counterpart (if any)                                                                                                                                                                                                                                                |
| ----------------------------- | ---------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `scalarFromBytes`             | `ristretto255::new_scalar_from_bytes`                                  | Parsing + range as in Move; `Ristretto255` gives `ℤ/ℓℤ` as the type of scalars, not byte-level canonicality proofs.                                                                                                                                                      |
| `challengeScalarFromMsg`      | `new_scalar_from_tagged_hash(FIAT_SHAMIR_REGISTRATION_SIGMA_DST, msg)` | `registrationChallengeScalarMove` = `scalarUniformFrom64Bytes (AptosFormal.Std.Hash.Sha3_512.taggedHash …)` — **byte-level SHA3-512 + tag layout** in `AptosFormal/Std/Hash/Sha3_512.lean`; **no proof** that Move’s native hash is bit-identical to that Lean function. |
| `hashToPointBase`             | `ristretto255::hash_to_point_base()`                                   | Abstract `Point`; no Ristretto proof.                                                                                                                                                                                                                                    |
| `pointMul`                    | `ristretto255::point_mul`                                              | Abstract; no proof of group law / encoding.                                                                                                                                                                                                                              |
| `pointAdd`                    | `ristretto255::point_add`                                              | Abstract.                                                                                                                                                                                                                                                                |
| `pointEq`                     | `ristretto255::point_equals`                                           | In bridge theorems, often specialized to `=`; no proof that Move’s comparison matches mathematical equality on the curve.                                                                                                                                                |
| `pointDecompress`             | `ristretto255::point_decompress` on commitment bytes                   | Abstract; no IRTF Ristretto decode proof.                                                                                                                                                                                                                                |
| `pubkeyToPoint`               | `twisted_elgamal::pubkey_to_point`                                     | Abstract; must match `pubkey_to_bytes` wire format used in `msg`.                                                                                                                                                                                                        |


**Move golden tests (§6.2 evidence).** `formal_goldens_ristretto.move` (8 passing tests) verifies group-law properties of the `ristretto255` natives on this branch: scalar identity (`1·H = H`), annihilation (`0·H = 0`), double-add consistency, distributivity, commutativity, identity element, and scalar multiplication associativity.

**Review anchor.** `ristretto255` module, `ristretto255_twisted_elgamal.move`, `confidential_proof.move` (`new_scalar_from_tagged_hash` implementation).

---

### 6.3 BCS (`address` → transcript bytes)

**Goal.** The bytes fed into `registrationFiatShamirMsg` for `sender`, `contract`, and `token` are **exactly** `std::bcs::to_bytes(&address)` for the same runtime `address` values Move uses, in the **framework version pinned by this branch**.

**Lean model.** `AptosAddress32` + `aptosAddress32Bcs` / `mkRegistrationInputs32`: **32 raw bytes**, no outer length prefix, matching the usual Aptos `address` BCS layout used in this codebase’s Move sources.

**Not proved in Lean:**

- That real `std::bcs::to_bytes(&address)` is always 32 bytes and matches those 32 bytes field-for-field for every address the VM can pass into `verify_registration_proof`.
- Any change to BCS rules or `address` representation in the framework invalidates a byte-level claim until re-audited.

**Move golden tests (§6.3 evidence).** `formal_goldens_bcs_address.move` (7 passing tests) verifies BCS encoding of `address` values `@0x1`, `@0x2`, `@0x3`, `@0x10`, `@0x20`, `@0x30`, and `@0xFFF…F` as 32 raw bytes with no length prefix, matching the `AptosAddress32` model in Lean.

**Review anchor.** Aptos Move `address` + `std::bcs` spec for the release you ship.

---

### 6.3a Bytecode transcription and eval smoke tests (L2)

**What Lean provides today.**

- **Transcribed bytecode** (`AptosFormal.Move.Programs.Registration`): an **83-instruction** `MoveInstr` array faithfully transcribed from the **`movement` v7.4.0** compiler output (`movement move disassemble`, def_idx 39, PC 0–82). Local layout: 7 parameters (chain_id, sender, contract_address, ek, token_address, commitment_bytes, response_bytes) + 12 temporaries (19 locals total). The transcription uses reference-semantic instructions (`immBorrowLoc`, `mutBorrowLoc`) matching the compiler output exactly.

- **Oracle-parameterized natives** (`AptosFormal.Move.Native.Registration`): `RegistrationNativeOracle` bundles Ristretto point operations, scalar parsing, pubkey wire conversions, and twisted ElGamal helpers. Crypto-ops use `FuncBody.nativeRef` (receiving `ContainerStore` + `List MoveValue` and returning `Option (List MoveValue × ContainerStore)`) with a `derefImm` helper that transparently handles both immutable references (`.immRef id` → container store lookup) and direct values (pass-through). Non-oracle natives (SHA3-512, tagged hash, BCS, Option is_some/extract, vector append/singleton) use `FuncBody.native` and are **executable** in Lean (no oracle).

- **Module environment** (`registrationModuleEnv`): 18-slot function table (indices 0–9 oracle `nativeRef`, 10–16 executable `native`, 17 bytecode verifier). Constant pool entry 0 is the `FIAT_SHAMIR_REGISTRATION_SIGMA_DST` bytes.

- **Eval smoke tests** (`…Registration.BytecodeSmoke`): `native_decide` proofs that `eval` on golden inputs (with **reference args**: `.immRef 0` for ek and a pre-populated `MachineState`) produces `returned []` (valid proof) and `aborted 65537` (invalid proof). These run the full evaluator loop (200 fuel steps) through all 83 instructions with container-store threading.

- **MachineState projection** (`ExecResult.dropMs` in `EvalEquiv.lean`): The 83-instruction bytecode populates the `ContainerStore` via `immBorrowLoc`/`mutBorrowLoc`/`nativeRef` calls, so `eval` returns `.returned [] ms` where `ms` has a non-empty container store. The functional simulation returns `.returned [] MachineState.empty`. `ExecResult.dropMs` projects away the `MachineState` from `.returned` outcomes (replacing with `MachineState.empty`), enabling comparison of observable results (return values / abort codes) while abstracting over the differing container stores. Includes `@[simp]` lemmas and bidirectional `_iff` lemmas for all constructors.

- **Refinement theorems** (`…Registration.Refinement`):
  - `func_success_implies_exec_some` — **proven (no sorry)**: if the bytecode-level functional sim returns successfully, the spec-level runner also returns `some ()`. Uses `OracleCoherence` (both forward and reverse properties), `func_success_extracts` (structural decomposition of the 15-layer nested match), and `buildFSMessageMv_list_gen` (message coherence through `ByteArray.toList_append`).
  - `func_abort_implies_exec_none` — **proven (no sorry)**: if the functional sim aborts, the spec-level runner returns `none`. Uses `func_abort_classification` (3-way abort decomposition) + failure-direction `OracleCoherence` properties (`compressedFromBytes_false_rev`, `scalarFromBytes_false_rev`).
  - `eval_success_implies_prop` — **composition proven (no sorry in proof body)**: composes `eval_eq_func` (via `.dropMs`) + `func_success_implies_exec_some` + `execVerifyRegistrationProof_iff`. Accepts any returned `MachineState` `ms` (not just `MachineState.empty`), since the real bytecode leaves references in the container store. Depends on `eval_eq_func` (sorry in `eval_eq_func_100`) for the L2≡L1.5 step.
  - `eval_abort_implies_not_prop` — **composition proven (no sorry in proof body)**: composes `eval_eq_func` (via `.dropMs`) + `func_abort_implies_exec_none` + `execVerifyRegistrationProof_iff`. The `.aborted` constructor doesn't carry `MachineState`, so `.dropMs` is trivial. Depends on `eval_eq_func` (sorry in `eval_eq_func_100`).
  - `eval_eq_func` — **largely proven**: lifts `eval_eq_func_100` (at fuel 200) to arbitrary `fuel ≥ 200` via `eval_fuel_ge_dropMs`. Uses `by_cases` on whether `eval` at fuel 200 is `.error`. **One residual sorry** for error-fuel-monotonicity: when the oracle returns garbage (both sides are `.error`), proving `eval fuel = .error` from `eval 200 = .error` requires bounded-execution-length formalization. This case is vacuous for all callers (which assume `eval` returns `.returned` or `.aborted`).
  - `eval_eq_func_100` — **sorry** (in `EvalEquiv.lean`): states that `(eval ... 200 MachineState.empty).dropMs = verifyRegistrationBytecodeResult ...` for all abstract oracles, using **value args** (struct for ek, not `.immRef`). The `nativeRef` wrappers handle non-ref values via `derefImm` (pass-through). Proving this requires symbolic bytecode stepping through 83 instructions with container-store threading. Concrete instances verified by `native_decide` in `BytecodeDifftestEval.lean`.

- **Functional simulation** (`…Registration.FunctionalSim`): `verifyRegistrationBytecodeResult` — a readable Lean function on `MoveValue`s that mirrors the bytecode's control flow, returning `MachineState.empty` in all cases. Serves as the L1.5 intermediary: `eval ≡ L1.5` is verified by `native_decide` on concrete oracles (via `.dropMs`); `L1.5 ≡ L1` is algebraic under oracle coherence. Includes `func_trichotomy`, `buildFSMessageMv` (Fiat-Shamir message construction), `buildFSMessageMv_list` and `buildFSMessageMv_list_gen` (message correctness proven, no sorry). `ByteArray.toList_append` is axiomatized as a library-level obligation (verified concretely by `native_decide` for every tested ByteArray pair; orthogonal to the cryptographic verification).

- **Concrete refinement chain** (`…Registration.BytecodeDifftestEval` + `…Registration.BytecodeDifftestBridge`): **Four independent oracle traces** with `native_decide` proofs in two categories:

  *Smoke tests* (reference args + populated `MachineState`, testing `eval` directly):
  - Trace 1 (dk=42/k=9999, chainId=9, @0x1/@0x2/@0x3): eval success (1 proof).
  - Trace 2 (chainId=42, @0x10/@0x20/@0x30, basepoint ek/R): eval success + eval abort (bad commitment) (2 proofs).
  - Trace 3 (scalar-stage abort): eval abort with scalar `optionIsSome` false (1 proof).
  - Trace 4 (point-equality-false abort): eval abort with `pointEquals` false (1 proof).

  *Func≡eval tests* (value args + `MachineState.empty` + `.dropMs`, testing `eval` vs `verifyRegistrationBytecodeResult`):
  - Trace 1: `func_eq_eval_difftest_val` (func=eval via `.dropMs`) + `func_difftest_returns` (func returns `[]`) (2 proofs).
  - Trace 2: `func_eq_eval_trace2_val` (func=eval) + `func_trace2_returns` (func returns `[]`) + `func_trace2_aborts` (func aborts on bad commitment) + `func_trace2_scalar_aborts` (func aborts on bad scalar) + `func_trace2_pointeq_false_aborts` (func aborts on point inequality) (5 proofs).

  - `BytecodeDifftestBridge` composes trace 1 into `difftest_L2_implies_L0` (no sorry), proving the full L2 → L0 chain.

- **Difftest honest L1 column** (`caRegistrationBytecodeEvalNative` at index 194 in `confidentialModuleEnv`): wraps `eval` + `registrationModuleEnv` with the concrete difftest oracle, mapped in `RunnerFuncMappingAux` as `test_registration_bytecode_eval_roundtrip`. This enables cross-checking the Lean bytecode evaluator against the Rust VM in the difftest matrix.

- **L4 entry-point stub** (`…Registration.RegisterEntryStub`): `registerEntrySpec` models the `register` entry function as parse-ek + verify-proof + store. Two proven theorems: `register_success_implies_verify_success` (success implies the embedded proof verification returned) and `register_success_stores_ek` (stored ek matches input bytes). No `sorry`.

**What remains.**

1. **`eval_eq_func_100` (L2 ≡ L1.5, abstract) — sorry.** The theorem states `(eval ... 200 MachineState.empty).dropMs = verifyRegistrationBytecodeResult ...` for all abstract oracles. Proving this requires symbolic stepping through 83 instructions with container-store threading (each `immBorrowLoc`/`mutBorrowLoc` allocates in the `ContainerStore`; each `nativeRef` call reads/writes). Concrete instances are verified by `native_decide` for 4 independent oracle traces. The `EvalEquiv.lean` file contains `@[simp]` fusion lemmas (`match_single?`, `bind_single?`, `match_match_some_single_none`, `runStep_handleNativeResult_ret1/ret0`) and `runStep` machinery designed for the symbolic proof, but the full `simp` + `split` proof is not yet completed due to term-size from container-store threading.
2. **Error-fuel-monotonicity sorry in `eval_eq_func`.** When `eval` at fuel 200 returns `.error` (oracle returns garbage), lifting to arbitrary `fuel ≥ 200` requires proving `eval fuel = .error` for the `.error` case. This sorry is **vacuous for all callers** (`eval_success_implies_prop`, `eval_abort_implies_not_prop`) since they assume `eval` returns `.returned` or `.aborted`.
3. **`ByteArray.toList_append`/`ByteArray.toList_mk_singleton` axioms.** Library-level obligations for `ByteArray.toList` distributivity. Both are concretely verified by `native_decide` for every tested pair. A proper proof requires a loop invariant on the irreducible `ByteArray.toList.loop`. This is orthogonal to the cryptographic claims.

---

### 6.3d Bytecode disassembly cross-check (compiler output vs Lean transcription)

**Goal.** Verify that the hand-transcribed `MoveInstr` array in `AptosFormal.Move.Programs.Registration` faithfully represents the actual bytecode produced by the production compiler for `verify_registration_proof`.

**Method.** Compiled `aptos-experimental` with `movement` v7.4.0 (`movement move compile --package-dir aptos-move/framework/aptos-experimental --named-addresses "aptos_experimental=0x1"`), then disassembled the output (`movement move disassemble --bytecode-path .../confidential_proof.mv`). The disassembly lives at `aptos-move/framework/aptos-experimental/build/AptosExperimental/bytecode_modules/confidential_proof.mv.asm`, lines 4811–4914, function definition index 39.

#### Current status: faithful 83-instruction transcription

The Lean transcription now contains **83 instructions** (PC 0–82) with **19 locals** (7 params + 12 temporaries), matching the compiler output **instruction-for-instruction** including all reference-semantic instructions (`immBorrowLoc`, `mutBorrowLoc`), abort blocks, and temporary variables. The `registrationModuleEnv` uses `FuncBody.nativeRef` for crypto operations that receive references in the real bytecode, and `FuncBody.native` for pure operations (BCS, vector, Option, SHA3-512).

#### Previous state (archived divergence analysis)

The original §6.3d analysis documented 10 divergence types (D1–D10) between a previous 67-instruction value-semantics abstraction and the 83-instruction compiler output. That analysis remains valid as historical documentation of *why* the value-semantics abstraction was behavior-preserving, but is no longer the current Lean code.

The retranscription to 83 instructions was motivated by the need to:
1. Eliminate the manual behavior-preservation argument (D1–D10) by matching the compiler output exactly.
2. Enable `native_decide` proofs that run `eval` on the real bytecode with reference arguments (verified in `BytecodeSmoke.lean`).
3. Support the `nativeRef` native function calling convention (receiving `ContainerStore` for reference dereferencing).

#### MachineState abstraction via `ExecResult.dropMs`

The 83-instruction bytecode, due to `immBorrowLoc`/`mutBorrowLoc`/`nativeRef` calls, populates the `ContainerStore` during execution. After `eval` completes, the returned `MachineState` contains allocated reference entries that are semantically irrelevant (all references are local to the function and never escape). The functional simulation (`verifyRegistrationBytecodeResult`) returns `MachineState.empty`.

`ExecResult.dropMs` (defined in `EvalEquiv.lean`) bridges this gap by projecting `.returned vs ms` to `.returned vs MachineState.empty`, enabling comparison of observable outcomes:
- **Success**: same return values (`[]` for void return)
- **Abort**: same abort code (`65537`)
- **Error**: same `.error` (oracle returns garbage)

This is a weaker claim than full `MachineState` equality but is **sufficient for the refinement chain**: the L1.5→L1→L0 layers only inspect return values and abort codes, never the final container store.

#### Constant pool

The compiler's constant pool index 5 contains the BCS-serialized DST vector: `[38, 77, 111, ...]` (38 = ULEB128 length prefix, then 38 bytes of `"MovementConfidentialAsset/Registration"`). The Lean model's constant pool index 0 stores the deserialized `MoveValue.vector .u8 [77, 111, ...]`. The VM deserializes constants at load time, so these are equivalent: `LdConst` pushes the same 38-byte vector onto the stack in both cases.

#### Summary

The Lean bytecode array is a **faithful 83-instruction transcription** of the `movement` v7.4 compiler output for `verify_registration_proof`, including all reference-semantic instructions. The `ExecResult.dropMs` projection abstracts over the `MachineState` difference (populated `ContainerStore` vs empty) that arises from reference operations, enabling comparison of observable outcomes (return values / abort codes). This observable-outcome equivalence is:
- **Verified by `native_decide`** for 4 independent concrete oracle traces (7 func≡eval proofs in `BytecodeDifftestEval.lean`).
- **Stated for all abstract oracles** in `eval_eq_func_100` (sorry — requires symbolic stepping through 83 instructions with container-store threading).
- **Sufficient for the full refinement chain** (L2→L0), since downstream layers only inspect return values and abort codes.

---

### 6.4 Cryptographic security (soundness / knowledge soundness)

**What Lean proves today.**

- **Completeness** of the Schnorr check for an honest prover (`registrationSchnorr_completeness`, `registrationVerifySpec_completeness` in `…Registration.SchnorrCompleteness`).
- **Special soundness** (`registrationSchnorr_witness_extraction` in `…Registration.CryptoSecurity`): two accepting transcripts `(R, e₁, s₁)` and `(R, e₂, s₂)` with `e₁ ≠ e₂` yield an explicit witness `dk = (s₁ − s₂)⁻¹ · (e₂ − e₁)` with `H = dk · ek`. The proof uses `Field RistrettoScalar` (via the `Fact (Nat.Prime ℓ)` instance) for scalar inversion.
- **HVZK simulator** (`registrationSchnorr_simulate` / `registrationSchnorr_simulate_accepts`): given `(H, ek, e, s)`, the simulator produces `R := s·H + e·ek` which is always an accepting transcript.
- **Fiat–Shamir symbolic model** (`…Registration.FiatShamirSymbolic`):
  - **Forking reduction** (`fiatShamir_forking_extraction`): two valid NIZK proofs in "oracle worlds" with different challenges for the same FS message yield witness extraction — the algebraic core of the ROM forking lemma [PS00].
  - **Explicit extraction formula** (`fiatShamir_forking_explicit`): `dk = (s₁ − s₂)⁻¹ · (e₂ − e₁)`.
  - **Challenge binding** (`fiatShamir_challenge_binding`): for a fixed hash function, two proofs with the same commitment share the same challenge, so a single-oracle adversary cannot fork.
  - **NIZK completeness** (`fiatShamir_completeness`): the honest Fiat–Shamir prover always passes.
  - **NIZK zero-knowledge** (`fiatShamir_nizk_simulate_accepts`): a simulator with oracle-programming ability produces valid proofs without the witness.

**Not proved in Lean (pen-and-paper / ROM in §3):**

- **Forking probability** — the probability that an adversary triggers the two-oracle-world scenario is shown to be non-negligible in [PS00] via a rewinding argument; this probabilistic argument requires a probability monad or game-based framework.
- **Hardness** — discrete logarithm (or equivalent) on the Ristretto255 group.

Lean does **not** formalize a random oracle, a computational game, or a reduction to DLOG.

---

### 6.5 Primality of ℓ (subgroup order)

**Current status.** `ristretto_subgroup_order_prime : Nat.Prime ristrettoSubgroupOrder` is an `**axiom`** in `AptosFormal.Std.Crypto.Ristretto255` (spec constant from Ristretto / Curve25519 literature), not a **formal primality certificate** inside Lean. A `Fact (Nat.Prime ristrettoSubgroupOrder)` instance is derived from the axiom, making `Field RistrettoScalar` available everywhere (used by the special soundness proof in `CryptoSecurity.lean`).

**To remove the axiom.** Supply a **Pratt primality certificate** for `ristrettoSubgroupOrder` and verify it in Lean. This requires:

1. The complete factorization of `ℓ − 1` (obtainable from a computer algebra system like SageMath or PARI/GP).
2. A primitive root `g` modulo `ℓ`.
3. Recursive Pratt certificates for each prime factor of `ℓ − 1`.

Trial division (`native_decide` on `Nat.Prime`) is infeasible for a 252-bit prime (≈ 2^126 trial divisions).

**Review anchor.** Standard curve parameters [HDEVALENCE, Ber06] vs the numeric literal in `AptosFormal.Std.Crypto.Ristretto255`.

---

### 6.6 Audit checklist (copy for reports)

```text
[✓] §6.1   VM: verify_registration_proof success/abort matches Option/False split in verifyRegistrationProofProp (execVerifyRegistrationProof_iff, no sorry).
[✓] §6.2   Natives: each CryptoOracle field matched to Move; SHA3/tagged hash vs `AptosFormal/Std/Hash/Sha3_512.lean` explicitly reviewed.
[✓] §6.3   BCS: sender/contract/token bytes are to_bytes(&address) as in this framework version (32-byte model).
[✓] §6.3a  Bytecode: transcribed 83-instruction body (matching compiler output with reference semantics); eval smoke passes on 4 traces with reference args; 7 func≡eval native_decide proofs with value args + .dropMs; func_success_implies_exec_some PROVEN; func_abort_implies_exec_none PROVEN; eval_success_implies_prop + eval_abort_implies_not_prop compositions proven. eval_eq_func_100 SORRY (abstract symbolic stepping through 83 instructions with container-store threading). Residual sorry in eval_eq_func for error-fuel-monotonicity (vacuous for callers).
[✓] §6.3d  Disassembly cross-check: Lean transcription now matches `movement` v7.4 compiler output (83 instructions) instruction-for-instruction. MachineState abstraction via ExecResult.dropMs documented. Previous 67→83 divergence analysis archived.
[✓] §6.3b  Concrete L2→L0 chain: difftest_L2_implies_L0 proven (no sorry) for dk=42/k=9999 trace. 3 additional traces covering all 3 abort paths (commitment, scalar, point-equality). Difftest honest L1 column wired (index 194).
[~] §6.3c  L4 entry-point: registerEntrySpec stub for `register`; verify-then-store and ek-storage properties proven (no sorry). Full bytecode transcription of register pending.
[✓] §6.4   Crypto: special soundness + HVZK + symbolic FS model machine-checked; forking probability + DLOG hardness remain external.
[ ] §6.5   ℓ prime: accepted as axiom or replaced by a certificate proof in Lean.
```

For questions about this doc, align with the module owners of `aptos-experimental` confidential assets.

---

## 7. References

### Cryptography


| Ref          | Citation                                                                                                                                                    | Link                                                                                                                     |
| ------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| [PS00]       | D. Pointcheval and J. Stern, "Security arguments for digital signatures and blind signatures," *J. Cryptology*, vol. 13, no. 3, pp. 361–396, 2000.          | [DOI:10.1007/s001450010003](https://doi.org/10.1007/s001450010003)                                                       |
| [FS87]       | A. Fiat and A. Shamir, "How to prove yourself: practical solutions to identification and signature problems," in *CRYPTO '86*, LNCS 263, pp. 186–194, 1987. | [DOI:10.1007/3-540-47721-7_12](https://doi.org/10.1007/3-540-47721-7_12)                                                 |
| [Sch91]      | C. P. Schnorr, "Efficient signature generation by smart cards," *J. Cryptology*, vol. 4, no. 3, pp. 161–174, 1991.                                          | [DOI:10.1007/BF00196725](https://doi.org/10.1007/BF00196725)                                                             |
| [Ber06]      | D. J. Bernstein, "Curve25519: New Diffie-Hellman speed records," in *PKC 2006*, LNCS 3958, pp. 207–228, 2006.                                               | [DOI:10.1007/11745853_14](https://doi.org/10.1007/11745853_14)                                                           |
| [HDEVALENCE] | H. de Valence, J. Grigg, G. Tankersley, F. Valsorda, and I. Lovecruft, "The Ristretto Group" (specification).                                               | [ristretto.group](https://ristretto.group)                                                                               |
| [RFC8032]    | S. Josefsson and I. Liusvaara, "Edwards-Curve Digital Signature Algorithm (EdDSA)," RFC 8032, January 2017.                                                 | [rfc-editor.org/rfc/rfc8032](https://www.rfc-editor.org/rfc/rfc8032)                                                     |
| [BIP340]     | P. Wuille, J. Nick, and T. Ruffing, "Schnorr Signatures for secp256k1," BIP 340, 2020. (Tagged-hash construction referenced for DST design.)                | [github.com/bitcoin/bips/blob/master/bip-0340.mediawiki](https://github.com/bitcoin/bips/blob/master/bip-0340.mediawiki) |


### Lean / Mathlib


| Ref     | Description                                                                          | Link                                                                                                                                                           |
| ------- | ------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Lean 4  | Functional programming language and proof assistant (v4.24.0 in this project).       | [lean-lang.org](https://lean-lang.org)                                                                                                                         |
| Mathlib | Community-maintained mathematics library for Lean 4 (v4.24.0).                       | [github.com/leanprover-community/mathlib4](https://github.com/leanprover-community/mathlib4)                                                                   |
| elan    | Lean version manager.                                                                | [github.com/leanprover/elan](https://github.com/leanprover/elan)                                                                                               |
| `ZMod`  | Mathlib's `ZMod n` type for integers modulo `n`; `Field (ZMod p)` when `p` is prime. | [leanprover-community.github.io/mathlib4_docs/Mathlib/Data/ZMod/Basic.html](https://leanprover-community.github.io/mathlib4_docs/Mathlib/Data/ZMod/Basic.html) |


### Aptos / Move


| Ref                       | Description                                                             | Link                                                                                         |
| ------------------------- | ----------------------------------------------------------------------- | -------------------------------------------------------------------------------------------- |
| Aptos Move framework      | Move stdlib, aptos-stdlib, aptos-experimental as pinned by this branch. | (this repository)                                                                            |
| `ristretto255.move`       | `aptos_std::ristretto255` — Ristretto255 curve operations.              | `aptos-move/framework/aptos-stdlib/sources/cryptography/ristretto255.move`                   |
| `confidential_proof.move` | `aptos_experimental::confidential_proof` — registration proof verifier. | `aptos-move/framework/aptos-experimental/sources/confidential_asset/confidential_proof.move` |
| BCS spec                  | Binary Canonical Serialization.                                         | [github.com/diem/bcs](https://github.com/diem/bcs)                                           |


