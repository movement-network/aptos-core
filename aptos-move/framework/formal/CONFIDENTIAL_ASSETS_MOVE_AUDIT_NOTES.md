# Confidential assets — Move source audit notes (formal / difftest track)

**Audience:** Engineers and proof engineers working on `AptosFormal`, `move-lean-difftest`, and CA alignment.

**Scope:** Targeted review of `aptos_experimental::confidential_*` and related `aptos_std` crypto helpers while extending formal artifacts. This is **not** a substitute for Aptos product security review, external audit, or bug bounty triage.

**Method:** Static reading of Move sources on disk in this repo revision; no claimed completeness.

---

## Summary

| ID | Severity | Topic |
|----|----------|--------|
| **M1** | Informational (API / semantics) | `deserialize_*` returns `Some` without validating Bulletproofs wire bytes |
| **M2** | Documentation (resolved) | `new_scalar_from_tagged_hash` / `new_scalar_from_sha3_512` now **`assert!` + `extract`** (`confidential_proof.move`) |
| **M3** | Informational (precondition) | `#[test_only]` / harness provers use `scalar_invert(..).extract()` — aborts if scalar is non-invertible |
| **M4** | Informational (harness) | `confidential_gas_e2e_helpers` parses auditor pubkeys with `.extract()` — malformed test inputs abort |
| **M5** | Informational (abort semantics / UX) | Production **`entry`** paths (e.g. `confidential_transfer`) chain `option::extract()` on balance / auditor / proof deserializers — **malformed client payloads abort** the transaction (safe rejection), not silent state corruption |
| **M6** | Documentation (resolved) | Doc typo **`suffucient`** on `ensure_sufficient_fa` — fixed to **sufficient** (`confidential_asset.move`) |
| **M7** | Documentation (resolved) | Awkward phrasing **“decrypt the it”** on `confidential_transfer` — fixed (`confidential_asset.move`) |
| **M8** | Informational (API naming) | Public function **`new_pending_balance_u64_no_randonmess`** — spelling typo (**randonmess** vs **randomness**); renaming would be a **breaking** API change, so it is documented here rather than “fixed” in-place |
| **M9** | Informational (API / wire semantics) | **`serialize_auditor_amounts`** concatenates `balance_to_bytes` in **vector order**; permuting the `vector<ConfidentialBalance>` changes the wire when encodings differ (difftest **120** vs **121** + Lean `serializeAuditorAmounts_mixed512_orders_distinct`; **122** vs **123** + `serializeAuditorAmounts_mixed768_orders_distinct`). Integrations that map auditors to indices must keep the same ordering as Move. |
| **M10** | Informational (wire ambiguity) | If every serialized ciphertext byte is **zero**, different **`ConfidentialBalance`** sequences can still yield the **same** overall `vector<u8>` (e.g. `[pending_zero, actual_zero]` vs `[actual_zero, pending_zero]` are both **768** bytes of zeros on the current VM). Off-chain tools cannot recover per-slot **pending vs actual width** from raw bytes alone without out-of-band typing. |
| **M11** | Informational (formal / difftest alignment) | VM **`deserialize_*` → `Some`** layout rows vs Lean **length-only** bytecode (**110–113**, same **`Step`** as **128–130**); see **§ M11** below and **`STUB_POLICY.md`**. |

**No production-breaking cryptographic flaw was identified in this pass** from the slices above; the items are documentation of **semantics**, **hardening opportunities**, and **test-only / harness** sharp edges.

---

## M1 — `deserialize_*` vs `range_proof_from_bytes` (API semantics)

**Locations**

- `aptos-move/framework/aptos-experimental/sources/confidential_asset/confidential_proof.move` — `deserialize_withdrawal_proof`, `deserialize_transfer_proof`, `deserialize_normalization_proof`, `deserialize_rotation_proof`.
- `aptos-move/framework/aptos-stdlib/sources/cryptography/ristretto255_bulletproofs.move` — `range_proof_from_bytes` wraps arbitrary `vector<u8>` in `RangeProof` without parsing or rejecting malformed proofs.

**Observation**

`deserialize_*_proof` returns `option::some` whenever the **sigma** sub-deserializer succeeds. The ZK range proof slots are filled via `range_proof_from_bytes`, which **does not** establish cryptographic validity.

**Why this is not automatically a protocol vulnerability**

Soundness for transactions still depends on **`verify_*`** entry paths (and Bulletproofs / Ristretto natives inside them), which perform real verification. `deserialize_*` is better read as **layout / typing** of bytes into structs.

**Risk if misunderstood**

Off-chain tooling or future call sites might treat `Some` as “safe to use in a verify-free path.” That would be incorrect.

**Formal / difftest alignment**

Difftest documents Lean witness limits for VM↔Lean on `deserialize_*`; hex corpora under `difftest/corpora/confidential_assets/deserialize_sigma_*.hex` pin **sigma wire** layouts only. For **`test_deserialize_*_layout_ok_is_some`**, see **M11** (Lean **`ldTrue`** stubs vs VM real parsers). Separate rows **`test_layout_sigma_*_byte_length_is_*`** (**Lean 128–130**) exercise **`vecLen` + `eq`** on the same pinned sigma bytes — length agreement only, not parser replay.

---

## M2 — `new_scalar_from_tagged_hash` / `new_scalar_from_sha3_512` (`option::extract`) — **addressed**

**Location:** `confidential_proof.move` — `new_scalar_from_tagged_hash`, `new_scalar_from_sha3_512`.

**Observation (historical)**

Previously both used `option::extract` on `ristretto255::new_scalar_uniform_from_64_bytes` without an immediately adjacent `assert!(option::is_some(&...))`.

**Resolution**

Both paths now **`assert!(option::is_some(&sc_opt), error::invalid_argument(ESIGMA_PROTOCOL_VERIFY_FAILED))`** before **`option::extract`**, so the **64-byte** precondition is explicit if implementations change.

**Analysis (unchanged)**

`ristretto255::new_scalar_uniform_from_64_bytes` returns `some` **iff** the input vector has length **64** (`ristretto255.move`). `tagged_hash` and `aptos_hash::sha3_512` outputs are **64 bytes** on these paths, so `none` remains **unreachable** under current implementations.

---

## M3 — `scalar_invert(..).extract()` in `#[test_only]` provers

**Locations (examples)**

- `confidential_proof.move` — `prove_withdrawal`, `prove_transfer`, `prove_normalization`, `prove_rotation`, etc. (all `#[test_only]`).

**Observation**

Prover-side code uses `ristretto255::scalar_invert(dk).extract()` (and similar). `scalar_invert` returns `none` for a **zero** scalar (`ristretto255` tests document this).

**Impact**

Test / harness code **aborts** if a caller passes a zero decryption key (or other non-invertible scalar where applicable). This is **not** a production `public`/`entry` path in the snippets reviewed; it affects **test-only proof generation**.

**Recommendation**

Test harnesses should pass invertible scalars; optional explicit `assert!(option::is_some(&ristretto255::scalar_invert(dk)), …)` improves error messages over a bare `extract` abort.

---

## M4 — `confidential_gas_e2e_helpers` auditor pubkey parsing

**Location:** `confidential_gas_e2e_helpers.move` — `pack_confidential_transfer_proof_with_auditors` (and similar loops).

**Observation**

`twisted_elgamal::new_pubkey_from_bytes(auditor_eks[i]).extract()` is used without a per-element `is_some` check.

**Impact**

**Test-only / e2e helper** module: malformed auditor key bytes cause **abort** during packing, not a silent wrong proof. Production entrypoints still run full `verify_transfer_proof` with real crypto.

**Recommendation**

For clearer harness failures, prefer `assert!(option::is_some(&pk), …)` with a descriptive error code before `extract`.

---

## M5 — Production `entry` functions and `option::extract`

**Location:** `confidential_asset.move` — e.g. `confidential_transfer` (`new_*_from_bytes`, `deserialize_auditor_*`, `deserialize_transfer_proof`, all `.extract()`).

**Observation**

Several **public entry** functions deserialize caller-supplied bytes and use **`option::extract`** (via `extract()` on `Option`) without an intermediate local and `assert!` with a module-specific error code on every `none` case in the same syntactic pattern (some paths use `assert!` earlier inside helpers).

**Security read**

For malformed proofs / balances / auditor blobs, the typical outcome is **`abort`** (transaction failure), which is **safe** for on-chain state: invalid data does not silently pass verification.

**Operational read**

This is mostly **UX / observability** (clients see a failed transaction; error mapping depends on abort vs structured `error::` paths elsewhere). It is **not** framed here as a soundness vulnerability.

---

## M8 — `new_pending_balance_u64_no_randonmess` (spelling)

**Location:** `confidential_balance.move` — `public fun new_pending_balance_u64_no_randonmess`.

**Observation**

The identifier uses **randonmess** instead of **randomness**. This is a **public** API surface; fixing the spelling would require a new function name (and deprecation of the old one) to avoid breaking callers.

**Impact**

None for correctness or security; **documentation / ergonomics** only.

---

## M9 — `serialize_auditor_amounts` follows vector order

**Location:** `confidential_asset.move` — `public fun serialize_auditor_amounts`.

**Observation**

The output is a concatenation of per-balance encodings in **`amounts` vector order**. Swapping two non-identical balances (for example zero pending vs **`u64(1)`** no-rand pending) yields a **different** **512**-byte wire. For **768**-byte mixed **actual** + **`u64(1)`** pending rows, reversing vector order changes the byte layout (difftest **122** / **123**); see **M10** for the degenerate all-zero case.

**Impact**

**Not a protocol flaw** — it is the natural encoding. Off-chain code that re-sorts auditor balances or merges lists without preserving on-chain order can produce **unintended** auditor wires relative to what signers / auditors expect. Difftest and Lean (`serializeAuditorAmounts_mixed512_orders_distinct`) document the distinction.

---

## M10 — All-zero encodings can collide across different balance shapes

**Location:** `confidential_asset.move` — `serialize_auditor_amounts`; `confidential_balance.move` — `balance_to_bytes`.

**Observation**

`balance_to_bytes` for **pending** zero and **actual** zero (no randomness) produces only **zero** ciphertext bytes on the current VM. Concatenating **256** + **512** in either order therefore yields the same **768**-byte all-zero `vector<u8>` for `[pending_zero, actual_zero]` and `[actual_zero, pending_zero]`.

**Impact**

**Not an on-chain ambiguity** for honest modules that deserialize with typed `new_*_from_bytes` length checks. It **is** a footgun for **off-chain** tooling that tries to infer “which slice was pending vs actual” from raw bytes without metadata. Difftest **122**/**123** intentionally use a **non-zero** pending encoding (`u64(1)` no-rand) so VM↔Lean corpora remain byte-order-sensitive.

---

## M11 — Lean column for `deserialize_*` layout-`Some` rows (length check, not parser replay)

**Locations:** `AptosFormal.Move.Programs.Confidential` (function indices **110–113**); `AptosFormal.DiffTest.Runner` name mappings; `difftest/src/suites/confidential_proof.rs` harness.

**Observation**

The VM runs real **`confidential_proof::deserialize_*`** on fixed sigma bytes and returns **`option::is_some(&…)`**. The Lean column uses the same bytecode as indices **128–130**: **`ldConst`** (corpus-matching sigma bytes) + **`vecLen`** + **`eq`** against **1152** / **1216** / **1792**, so **`lake exe difftest`** checks a **necessary** layout-length condition (still **not** Bulletproofs slots, Ristretto batch parsing, or friend-module internals in `Move.eval`).

**Related**

Indices **128–130** are the explicitly named harness tests for the same length property; **110–113** align the **`layout_ok_is_some`** oracle rows with that **`Step`** instead of a context-free **`ldTrue`**. Transfer **auditor extension** tiers (**131**/**132** through **151**/**152**) pair **`test_layout_sigma_transfer_*_byte_length_is_*`** with **`test_deserialize_transfer_layout_extended_*_ok_is_some`**: Lean uses **`ldConst` 27**–**37** + **`vecLen`** + **`eq`** on **1920** … **3200** B corpus bytes (one tier per **`ldConst`**); the second index in each pair duplicates the first bytecode (VM-only stronger **`deserialize_transfer`** `Some`).

**Why this is documented**

Lean’s length check can **diverge** from the VM if **`deserialize_*`** later rejects wires that still have the nominal sigma length. **L0** lemmas relate checked-in **`deserialize_sigma_*.hex`** bytes to **`serialize_auditor_eks_*_a_points.hex`** prefixes (**`deserializeSigma*…_five/six_points_eq_serializeAuditorEks*`** in `Confidential.lean`) without claiming full parser parity.

---

## Positive checks (no issue filed)

- **`register`** (`confidential_asset.move`) invokes `confidential_proof::verify_registration_proof` **before** `register_internal`, with chain id, addresses, and Fiat–Shamir transcript inputs wired consistently in the reviewed block.
- **Bulletproofs DST length:** `verify_range_proof` enforces `dst.length() <= 256` (`ristretto255_bulletproofs.move`); CA DST string is shorter — domain separation is enforced where documented.

---

## Maintenance

When CA Move sources change behavior relevant to formal work:

1. Update this file if new **verified** observations appear.
2. Keep **[`CONFIDENTIAL_ASSETS_DIFFERENTIAL_TESTING_PLAN.md`](CONFIDENTIAL_ASSETS_DIFFERENTIAL_TESTING_PLAN.md)** §4.5 / inventory rows aligned with what the formal tree actually claims.
3. Distinguish **“API hazard / hardening”** from **“soundness break”** — only the latter belongs in urgent security channels without additional review.
