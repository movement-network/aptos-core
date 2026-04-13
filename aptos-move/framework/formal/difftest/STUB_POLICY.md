# Lean column policy: bytecode, natives, and globals (difftest §3)

This document is the **single place** that explains how the **Lean** side of
`move-lean-difftest` stays aligned with the **VM oracle** for confidential assets
and other suites. It implements the engineering constraints from
[`CONFIDENTIAL_ASSETS_DIFFERENTIAL_TESTING_PLAN.md`](../CONFIDENTIAL_ASSETS_DIFFERENTIAL_TESTING_PLAN.md) §3
(*“Lean must be able to run what you test”*).

## 1. Three obligations for every oracle case

For a JSON case to run under `lake exe difftest`, **all** of the following must hold:

1. **Bytecode (or an explicit substitute)**  
   Either the case maps to **`FuncBody.bytecode`** in `AptosFormal.Move.Programs.*`
   (hand-written or transcribed from `movement move disassemble`), **or** the team
   documents a deliberate **native-only** entry (see §2).

2. **`MoveInstr` + `step`**  
   Every instruction used by that bytecode must be implemented in
   `AptosFormal/Move/Instr.lean` and `Step.lean`. Missing opcodes → **`.error`** or
   wrong semantics → oracle mismatch.

3. **Natives**  
   Every `Call` to a **`FuncBody.native`** must have a Lean implementation that
   matches the VM on the oracle inputs (usually by delegating to `AptosFormal.Std.*`
   / `AptosFormal.AptosStd.*` specs, or by a **stub** table documented here).

**Globals:** resource-like behavior is modeled separately (§4); it is **not**
automatically the same as Aptos `borrow_global` / `move_to` opcodes from the
binary format.

## 2. Confidential suites: native stubs vs bytecode

| Suite | Lean `ModuleEnv` | Policy |
|-------|------------------|--------|
| `confidential_balance`, `confidential_proof` (smoke), `confidential_asset` (layer), `global_resource_smoke` | `confidentialModuleEnv` (`Programs/Confidential.lean`) | **Prefer `FuncBody.bytecode` in `eval`** for oracle rows where the observable result is fixed by simple Move-shaped logic: constant `u64`/`bool`, empty `vector<u8>` (`vec_pack`+`ret`), `ld_const`+`ret` for fixed byte vectors (BP DST + SHA3-512 digest + FS golden `msg` + 255×`0u8` short-length `Option`), `vec_pack`+`vec_len`+`neq` for empty-bytes wrong-length `Option`, **`globalMoveTo`/`mutBorrowGlobal`/`readRef`** for `test_read_std_counter` (synthetic key; same `u64` as VM). **Merged CA e2e** (`confidential_asset_e2e::…`): Lean uses indices **40–42** (`bool` witness, void `ret`, fixed abort `65542`) — JSON outcome alignment, not entrypoint replay. **`test_registration_helpers_roundtrip` (35)** and **`test_registration_proof_framework_deterministic_verify_roundtrip` (171):** Lean runs **`Operational.execVerifyRegistrationProof`** on VM-matched wire bytes (`Programs/RegistrationDifftestOracle.lean`) with a **finite table `CryptoOracleWithBoolEq`** (not a general Ristretto interpreter). **171** exercises **`confidential_proof::{prove_registration_deterministic_for_difftest, verify_registration_proof_for_difftest}`** on the same fixture as **35**; Lean column is the **same native** as **35**. Regenerate bytes with `cargo run -p move-lean-difftest --bin print-difftest-registration-wire` if the Move-only path changes. VM still runs full framework code where the harness calls into `aptos_experimental::confidential_balance` / `confidential_proof`. Formal hex corpora under **`corpora/confidential_assets/`** (registration FS `msg`, tagged SHA3-512 digest, Bulletproofs `DST` + digest, **`deserialize_sigma_*.hex`** layout wires, **`serialize_auditor_*.hex`** serializer VM wires) are checked by **`cargo run -p move-lean-difftest -- verify-corpora`** (Rust; same checks as the legacy Python script). |
| `vector` (`difftest_vector`) | `realModuleEnv` indices **30–33** (`Programs.lean` + `Native.lean`) | `vector::remove`, `swap_remove`, `append`, `singleton` on **`vector<u64>`** via **natives** that match the harness oracle (VM↔Lean **no longer skipped** for those rows). |
| `confidential_elgamal` | Same | Mix of **stub constants** and paths that mirror public APIs; see [`inventory/confidential_assets.md`](inventory/confidential_assets.md) for skips. |
| Future: CA with real bytecode | TBD | Transcribe bytecode + extend `MoveInstr` / `step` + replace stubs per function as coverage expands. |

Skipped functions and rationale stay in **`difftest/inventory/confidential_assets.md`**
(and per-package tables under `difftest/inventory/`).

## 3. `confidential_asset` and global storage (Option B vs future work)

The differential plan’s **Option B** remains the default for the **`confidential_asset`**
suite: only entrypoints that **do not require** a modeled global store appear in
the VM↔Lean oracle.

Separately, the Lean model now includes **`MachineState`** with **`GlobalResourceKey`**
(see `Move/README.md`) so **new** bytecode can use abstract **`globalExists`** /
**`globalMoveTo`** / **`mutBorrowGlobal`** without inventing a one-off native per
resource. **That is not yet** full Aptos wiring:

- No automatic **`StructTag`** / **`address`** encoding from the Move constant pool.
- No **`signer`**-checked publish path (values carry `MoveValue.signer`, but the
  step rules do not enforce `move_to` signer rules).
- No **fungible asset** / **`object::Object`** store layout.

When a CA path needs those, either extend the key type + stepping rules, add
targeted natives, or adopt **Option C** (VM-only column) for that slice — and
update this file + the inventory row.

**Phase L5 (FA / primary store — stub implemented):** `MachineState` now has
`faBalances : List ((UInt64 × UInt64) × UInt64)` (opaque `(metadataId, ownerKey) ↦ amount`).
`Step.lean` threads full `MachineState` through `withCG` on every transition.
New opcodes: **`faReadBalance`** (stack: `owner :: metaId :: rest` → push `u64` balance)
and **`faWriteBalance`** (`amt :: owner :: metaId :: rest` → update map). `eval` takes an
optional initial `MachineState` (default `empty`); `Runner.lean` seeds balances for
`test_fa_stub_balance_answer` to match the Rust `fa_stub` suite constant. A second harness row
**`test_fa_stub_write_then_read_balance`** checks **`faWriteBalance`** then **`faReadBalance`** on
**`MachineState.empty`** (Lean index **169**); the VM returns the same pinned **`u64`** constant.
**`test_registration_fs_message_framework_matches_helpers_golden`** (Lean index **170**) VM-compares
**`confidential_proof::registration_fs_message_for_test`** against **`difftest_registration_helpers::registration_fs_message_golden_move`**
(Lean **`ldTrue`** stub).
**`test_registration_proof_framework_deterministic_verify_roundtrip`** (Lean index **171**) VM-runs production
**`prove_registration_deterministic_for_difftest`** + **`verify_registration_proof_for_difftest`** on the **35** fixture;
Lean **`caRegistrationHelpersRoundtripNative`** (same as **35**).
**`test_registration_fs_message_framework_second_scenario_matches_helpers_golden`** (Lean index **173**) is the
**`goldenRegistrationInputs2`** counterpart to **170** (`ldTrue` stub).
**`test_registration_tagged_hash_golden_move_{first,second}`** (Lean **174** / **175**) return the **64**-byte
**`tagged_hash`** vectors for FS golden **1** / **2** (`ldConst` **47** / **48** + `ret`, matching **`verify-corpora`** hex).
This is **not**
Aptos `primary_fungible_store` / `Object` semantics — transactional CA e2e rows remain
**witness Lean** until a richer model lands.

## 4. `GlobalResourceKey` (Lean L4 scaffolding)

Defined in `lean/AptosFormal/Move/Value.lean`:

- `address : ByteArray` — publish site.
- `structTagHash : Nat` — stand-in fingerprint; may coexist with optional `structTag`.
- `instanceNonce : Nat` — reserved for FA / object disambiguation (often `0`).
- `structTag : Option StructTag` — optional `(account, module, struct)` **byte** path
  (no generic args); not tied to the VM constant pool.

`MachineState.globals : List (GlobalResourceKey × RefId)` maps keys to heap cells
in the shared `ContainerStore`. `globalMoveToSigned` + `ldSigner` model a minimal
signer-address check vs `move_to` (see `Step.lean`). Smoke bytecode:
`Programs/GlobalSmoke.lean`, tests: `Tests/GlobalSmoke.lean`.

## 5. When to bump `schema_version`

If the JSON oracle shape or comparison rules change, bump **`CURRENT_SCHEMA_VERSION`**
in Rust and document in [`ORACLE_CHANGELOG.md`](ORACLE_CHANGELOG.md). Changes to
**Lean-only** stubs without oracle field changes do not require a schema bump.

## 6. Related files

| File | Role |
|------|------|
| [`lean/AptosFormal/Move/README.md`](../lean/AptosFormal/Move/README.md) | Execution model + phases |
| [`lean/AptosFormal/DiffTest/Runner.lean`](../lean/AptosFormal/DiffTest/Runner.lean) | Difftest driver + case name → `eval` glue |
| [`lean/AptosFormal/DiffTest/RunnerFuncMappingAux.lean`](../lean/AptosFormal/DiffTest/RunnerFuncMappingAux.lean) | Large oracle name table (split `match` + `<|>` so elaboration stays under default `maxHeartbeats`) |
| [`lean/AptosFormal/Move/Programs/Confidential.lean`](../lean/AptosFormal/Move/Programs/Confidential.lean) | CA stub `ModuleEnv` |
| [`INVENTORY.md`](INVENTORY.md) | Suite registry + methodology |
