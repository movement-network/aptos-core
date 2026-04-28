# Move ↔ Lean differential tests (`move-lean-difftest`)

These tests compare the **real Move VM** (Rust) against the **Lean bytecode evaluator** on the same inputs and expected outputs. The Rust binary writes a **JSON oracle**; the Lean executable reads it and reports pass/fail.

This is **runtime empirical checking**, not a formal proof. The oracle is **VM output** — if Move and Lean disagree, **something is wrong** (Move bug, Lean model bug, or stale oracle); do not assume confidential assets (or any module) is correct **a priori**.

**Phase 0 inventory (planning, any future suite):** [`INVENTORY.md`](INVENTORY.md) and [`inventory/`](inventory/).

## Git and CI

**Registration + CA corpora (§4.5 / independent vectors):** [`corpora/confidential_assets/`](corpora/confidential_assets/) holds hex goldens for registration FS `msg`, SHA2-512 digest, Bulletproofs `DST` + SHA3-512 digest, **`deserialize_sigma_*.hex`** sigma wire layouts, and **`serialize_auditor_*.hex`** serializer pins. **Authoritative semantics** for CA behavior remain: (1) the **Move VM** when generating `difftest_oracle*.json`, and (2) **`lake exe difftest`** comparing that JSON to Lean `eval`. The corpus step is an extra **static** gate: length checks, recomputing SHA2-512/SHA3-512 chains, and byte-for-byte comparisons against small fixed constants. That gate is implemented only in **Rust** (`cargo run -p move-lean-difftest -- verify-corpora`, also `#[test]` in `corpus_verify.rs`). **`../difftest.sh`** runs `verify-corpora` as step **\[0\]**, then **\[0a\]** [`../scripts/check_confidential_lean_hygiene.sh`](../scripts/check_confidential_lean_hygiene.sh) (no line-start `sorry` in `Experimental/ConfidentialAsset/` **and** CA companion modules: `AptosStd/Crypto/EdwardsOracle.lean`, `Refinement/…/Confidential.lean`, `MoveModel/Programs/{Confidential,Registration,RegistrationDifftestOracle}.lean`, `MoveModel/Native/Registration.lean`, `SmokeTests/Confidential.lean`, `DiffTest/Runner.lean`, `RunnerFuncMappingAux.lean`; single allowlisted `axiom` under Experimental only). **`.github/workflows/formal-difftest.yaml`** runs **`verify-corpora`** in **`rust-oracle`** and the hygiene script plus **`lake build`** in **`lean-proofs`**. Move semantics notes: [`../CONFIDENTIAL_ASSETS_MOVE_AUDIT_NOTES.md`](../CONFIDENTIAL_ASSETS_MOVE_AUDIT_NOTES.md).

**`difftest_oracle*.json` is gitignored** — it is generated output from the real VM, not source. Regenerate with `cargo run -p move-lean-difftest` (or `../difftest.sh`) before running `lake exe difftest`, or rely on a CI job that runs the harness then Lean in one pipeline.

If you prefer **committed goldens** (offline Lean-only runs, PR diffs when VM output changes), remove the `difftest_oracle*.json` line from `difftest/.gitignore` and check the files in — trade-off is noisier PRs and risk of stale oracles.

## Naming (not vector-specific)

- **`difftest_oracle.json`** — default file holding VM ground truth for **all** registered suites (`vector`, `bcs`, `hash`, `global_resource_smoke`, `confidential_balance`, `confidential_elgamal`, `confidential_proof`, `confidential_asset`, `fa_stub`, or **`--suite confidential`** for the four confidential-related suites only). The old name `test_vectors.json` suggested everything was about `vector.move`; the new name matches “oracle for differential testing.”
- **`schema_version`** — integer at the JSON root (`CURRENT_SCHEMA_VERSION` in Rust). Document incompatible bumps in [`ORACLE_CHANGELOG.md`](ORACLE_CHANGELOG.md).
- **`skip_lean`** — optional per test case (`false` or absent = run Lean). Use `true` for VM-only rows when merging transactional e2e output into the same oracle file as VM↔Lean suites (Lean reports **SKIP** for those cases).

**One JSON file (VM↔Lean + VM-only):** after you have a VM oracle from this crate and a separate fragment (full `TestSuite` or `{ "test_cases": [...] }`, e.g. exported from `e2e-move-tests`), merge them so Lean runs once:

```bash
# from repo root (input paths resolve via the difftest crate manifest, then cwd;
# relative `-o` resolves against cwd when the parent directory exists, else the crate dir)
cargo run -p move-lean-difftest -- merge -o difftest_merged.json \
  aptos-move/framework/formal/difftest/difftest_oracle.json \
  path/to/e2e_fragment.json
cd aptos-move/framework/formal/lean && lake exe difftest ../difftest/difftest_merged.json
```

`merge` **preserves** each appended file’s `skip_lean` flags by default (use **`--force-skip-lean`** only if you want every appended row forced to VM-only). See **`cargo run -p move-lean-difftest -- merge --help`**.

**CA transactional e2e → `OracleFragment`:** `e2e-move-tests` depends on this crate’s library types. The test **`export_confidential_asset_e2e_oracle_fragment`** runs all confidential-asset VM scenarios once and writes JSON when **`CONFIDENTIAL_ASSET_E2E_ORACLE_OUT`** is set to a file path. **Relative paths** are interpreted from the **workspace repo root** (two levels above `e2e-move-tests`’s `Cargo.toml`), so the recipe below works without an absolute path.

```bash
export CONFIDENTIAL_ASSET_E2E_ORACLE_OUT=aptos-move/framework/formal/difftest/difftest_ca_e2e_fragment.json
RUST_MIN_STACK=8388608 cargo test -p e2e-move-tests export_confidential_asset_e2e_oracle_fragment -- --test-threads=1
```

Then **`merge`** that file into the harness oracle and run **`lake exe difftest`** on the merged file (see **`.github/workflows/formal-difftest.yaml`** for the CI recipe).

### CI parity: harness + CA e2e → merged Lean run

**On PRs**, [`.github/workflows/formal-difftest.yaml`](../../../.github/workflows/formal-difftest.yaml) runs, in order: **`verify-corpora`** → VM harness (`cargo run -p move-lean-difftest -- --quiet`) → **`export_confidential_asset_e2e_oracle_fragment`** (writes `difftest_ca_e2e_fragment.json`) → **`merge`** into **`difftest_ci_merged.json`** → **`lake exe difftest`** on that merged file. You do **not** need to commit those JSON files: they are listed in [`difftest/.gitignore`](.gitignore); CI regenerates them whenever the workflow runs.

**Locally** (same shape as CI, including export + merge — **slow** because the export test runs every CA e2e oracle scenario in `all_fragment_cases()`):

```bash
# From repo root
DIFTEST_MERGE_CA_E2E=1 ./aptos-move/framework/formal/difftest.sh
```

Without `DIFTEST_MERGE_CA_E2E=1`, the script still runs **`verify-corpora`**, the VM harness, and Lean on **`difftest_oracle.json`** only (no e2e fragment, no merged file).

### Checklist: adding a new CA transactional e2e oracle row

Keep CI green when extending the VM↔Lean fragment:

1. Add the scenario in [`../../e2e-move-tests/src/tests/confidential_asset_e2e_oracle_impl.rs`](../../e2e-move-tests/src/tests/confidential_asset_e2e_oracle_impl.rs) and append it from **`all_fragment_cases()`**.
2. Add a **`#[test]`** wrapper in [`../../e2e-move-tests/src/tests/confidential_asset_e2e.rs`](../../e2e-move-tests/src/tests/confidential_asset_e2e.rs) so `cargo test` exercises the harness path.
3. Map the full oracle id in [`../lean/MovementFormal/DiffTest/RunnerFuncMappingAux.lean`](../lean/MovementFormal/DiffTest/RunnerFuncMappingAux.lean) (`funcIdx` + env flags).
4. Record the extension in [`ORACLE_CHANGELOG.md`](ORACLE_CHANGELOG.md) and a row in [`inventory/confidential_assets.md`](inventory/confidential_assets.md).

Then run **`DIFTEST_MERGE_CA_E2E=1 ./aptos-move/framework/formal/difftest.sh`** before landing if you changed Lean or need to reproduce CI locally.

- **`difftest.sh`** — one-shot script at `formal/difftest.sh` (next to `lean/` and `difftest/`). It is **not** only for vector tests.

The Move module **`0x1::difftest_vector`** is only the **vector** suite’s wrapper; BCS and hash use **`difftest_bcs`** and **`difftest_hash`**. Confidential-asset smoke modules: **`0x1::difftest_confidential_balance`**, **`difftest_confidential_proof`**, **`difftest_confidential_asset_layer`**.

**`confidential_asset` and globals:** the Lean `MoveModel.*` model has a **minimal global map**
(`MachineState` + `GlobalResourceKey`; see [`STUB_POLICY.md`](STUB_POLICY.md) and
[`../lean/MovementFormal/MoveModel/README.md`](../lean/MovementFormal/MoveModel/README.md)). It is **not**
full Move VM `borrow_global` / FA / signer wiring. The **`confidential_asset`** suite still
follows **Option B** from [`../CONFIDENTIAL_ASSETS_DIFFERENTIAL_TESTING_PLAN.md`](../CONFIDENTIAL_ASSETS_DIFFERENTIAL_TESTING_PLAN.md): only **functions that need no globals**
stay in the VM↔Lean oracle until bytecode + keys + policy are extended; FA-heavy
entrypoints stay inventory-**Blocked** or move to Option C (VM-only column).

**Transactional CA + real `verify_*` / `register` (VM only, not this JSON pipeline):** the repo already runs **`MoveHarness`** scenarios in **`e2e-move-tests`** (test-mode bytecode inject, FA + store, full proof paths). See plan [**§7.0**](../CONFIDENTIAL_ASSETS_DIFFERENTIAL_TESTING_PLAN.md). From repo root:

```bash
RUST_MIN_STACK=8388608 cargo test -p e2e-move-tests confidential_asset_e2e -- --test-threads=1
```

**Native stubs vs bytecode (plan §3):** see **[`STUB_POLICY.md`](STUB_POLICY.md)** —
obligations for bytecode, `MoveInstr`/`step`, and natives; confidential-suite tables;
and how abstract globals relate to CA coverage.

## Recommended: one command (all suites)

From the repo root:

```bash
./aptos-move/framework/formal/difftest.sh
```

This runs `cargo run -p move-lean-difftest -- --quiet` then `lake exe difftest` on **`difftest/difftest_oracle.json`**.

**Optional fuzz / property tests:** not part of this crate’s CI. Add a separate tool if you need random inputs beyond the fixed VM oracle vectors.

## Run only one suite (e.g. BCS)

Rust (from repo root):

```bash
cargo run -p move-lean-difftest -- --quiet --suite bcs
```

Writes **`difftest/difftest_oracle_bcs.json`** by default. Then:

```bash
cd aptos-move/framework/formal/lean
lake exe difftest ../difftest/difftest_oracle_bcs.json
```

Or use the script (it picks the same default path as Rust when you pass `--suite`):

```bash
./aptos-move/framework/formal/difftest.sh --suite bcs
```

Multiple suites, sorted ids in the filename:

```bash
cargo run -p move-lean-difftest -- --quiet --suite hash --suite bcs
# → difftest/difftest_oracle_bcs_hash.json
```

Override the path:

```bash
cargo run -p move-lean-difftest -- --quiet --suite bcs -o my_bcs.json
```

Use **`cargo run -p move-lean-difftest -- --help`** for the full CLI.

## Prerequisites

| Tool | Notes |
| ---- | ----- |
| **Cargo** | Build from the `aptos-core` repository root. |
| **Lean + Lake** | Same setup as [`../lean/README.md`](../lean/README.md). |

## Manual steps

### Generate oracle JSON only

```bash
cargo run -p move-lean-difftest
```

Writes **`difftest/difftest_oracle.json`** (all suites) unless you pass **`--suite`** / **`-o`**. With **`--quiet`**, no JSON on stdout (file only).

### Run Lean checker only

```bash
cd aptos-move/framework/formal/lean
lake build difftest
lake exe difftest ../difftest/difftest_oracle.json
```

Pass whichever oracle file you generated.

### Exit code (Lean)

**0** if every executed case passes (skipped cases do not fail the run), **1** on failure or bad JSON.

## Layout

| Path | Role |
| ---- | ---- |
| [`../difftest.sh`](../difftest.sh) | VM → JSON → Lean (forwards args to Cargo). |
| `src/suites/` | One Rust module per area: `vector`, `bcs`, `hash`, `global_resource_smoke`, `confidential_balance`, `confidential_proof`, `confidential_asset`, `fa_stub`, … |
| [`ORACLE_CHANGELOG.md`](ORACLE_CHANGELOG.md) | **Schema version** history for the JSON oracle format. |
| [`STUB_POLICY.md`](STUB_POLICY.md) | **Bytecode / natives / globals** policy for the Lean column (CA §3). |
| `difftest_oracle*.json` | Generated oracle(s); **ignored by git** by default (see above). |
| `../lean/MovementFormal/DiffTest/` | Lean JSON parser and runner. |

## Adding coverage

1. Read [`INVENTORY.md`](INVENTORY.md) and copy [`inventory/move_framework_template.md`](inventory/move_framework_template.md) if you need a new per-package inventory table.
2. Add a `DiffTestSuite` in `src/suites/`, register it in `mod.rs` (`all_suites` + **`suites_filtered` match** — must stay in sync; see comment in `mod.rs`).
3. Run `cargo run -p move-lean-difftest -- --list-suites` to verify the new id appears.
4. Extend **`funcNameToMapping`** in `MovementFormal.DiffTest.Runner`, and wire Lean **`ModuleEnv`** / natives as needed.
