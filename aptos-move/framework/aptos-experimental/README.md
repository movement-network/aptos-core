# aptos-experimental

Move packages that are **experimental**: APIs may change. The largest surface area here is **Confidential Assets** — private fungible balances with homomorphic encryption and on-chain zero-knowledge verification.

## Confidential Assets — where to read

| Document | Purpose |
| -------- | ------- |
| [`whitepaper.md`](./whitepaper.md) | End-to-end protocol, Fiat–Shamir, security discussion, and **full `Transferred` event field reference** (§5). |
| [`doc/`](./doc/) | Generated Move API reference (`confidential_asset`, `confidential_proof`, `confidential_balance`, …). |
| [`sources/confidential_asset/`](./sources/confidential_asset/) | Modules: `confidential_asset`, `confidential_proof`, `confidential_balance`, `ristretto255_twisted_elgamal`, gas e2e helpers (`#[test_only]`). |
| [`tests/confidential_asset/`](./tests/confidential_asset/) | Move unit tests (`confidential_asset_tests`, `confidential_proof_tests`). |

Rust **`e2e-move-tests`** (repo root `aptos-move/e2e-move-tests`) calls into `confidential_gas_e2e_helpers` to pack proofs for real transactions; they complement but do not replace Move tests for event shape.

## `Transferred` event (indexers & integrators)

Emitted on each successful **`confidential_transfer`**. There is **no cleartext amount** in the payload; observers still see cryptographic material suitable for correlation and auditor workflows.

| Field | Summary |
| ----- | ------- |
| **`from`**, **`to`**, **`asset_type`** | Sender and recipient addresses; **`asset_type`** is the FA metadata object address for the token. |
| **`amount`** | Compressed ciphertext for the transferred amount (recipient key, pending-balance layout). |
| **`ek_volun_auds`** | Flattened **`sigma_proof.xs.x7s`**: per auditor row in the proof, **four** compressed Ristretto points (32 bytes each), row-major order. Length **`128 × n`** bytes (`n` = auditor rows; **`n = 0`** ⇒ empty `vector`). Produced by `confidential_proof::transfer_proof_ek_volun_auds_flat_bytes`. |
| **`sender_auditor_hint`** | Opaque bytes (≤ **256**); must be identical when proving and when submitting the entry; bound into the transfer sigma Fiat–Shamir hash (BCS). |
| **`new_sender_available_balance`**, **`new_recip_pending_balance`** | Sender’s new **actual** balance and recipient’s new **pending** balance (compressed ciphertexts). |
| **`memo`** | Reserved; **empty** `vector` in the current implementation. |

**Integrator rule:** whatever bytes you pass as **`sender_auditor_hint`** to the on-chain entry must be the same bytes you included when generating the transfer proof (Fiat–Shamir binds them).

**Test coverage:** `confidential_asset_tests` uses `assert_last_transferred_event_matches_state` to check addresses, `asset_type`, hint, `ek_volun_auds` **length** vs auditor count, and both post-transfer ciphertexts against on-chain store. `confidential_proof_tests` cover proof verification (including wrong-hint failure) without going through the event path.
