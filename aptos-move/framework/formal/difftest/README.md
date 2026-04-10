# Move ↔ Lean differential tests (`move-lean-difftest`)

These tests compare the **real Move VM** (Rust) against the **Lean bytecode evaluator** on the same inputs and expected outputs. The Rust binary writes a **JSON oracle**; the Lean executable reads it and reports pass/fail.

This is **runtime empirical checking**, not a formal proof.

## Git and CI

**`difftest_oracle*.json` is gitignored** — it is generated output from the real VM, not source. Regenerate with `cargo run -p move-lean-difftest` (or `../difftest.sh`) before running `lake exe difftest`, or rely on a CI job that runs the harness then Lean in one pipeline.

If you prefer **committed goldens** (offline Lean-only runs, PR diffs when VM output changes), remove the `difftest_oracle*.json` line from `difftest/.gitignore` and check the files in — trade-off is noisier PRs and risk of stale oracles.

## Naming (not vector-specific)

- **`difftest_oracle.json`** — default file holding VM ground truth for **all** registered suites (`vector`, `bcs`, `hash`, …). The old name `test_vectors.json` suggested everything was about `vector.move`; the new name matches “oracle for differential testing.”
- **`difftest.sh`** — one-shot script at `formal/difftest.sh` (next to `lean/` and `difftest/`). It is **not** only for vector tests.

The Move module **`0x1::difftest_vector`** is only the **vector** suite’s wrapper; BCS and hash use **`difftest_bcs`** and **`difftest_hash`**.

## Recommended: one command (all suites)

From the repo root:

```bash
./aptos-move/framework/formal/difftest.sh
```

This runs `cargo run -p move-lean-difftest -- --quiet` then `lake exe difftest` on **`difftest/difftest_oracle.json`**.

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
| `src/suites/` | One Rust module per area: `vector.rs`, `bcs.rs`, `hash.rs`. |
| `difftest_oracle*.json` | Generated oracle(s); **ignored by git** by default (see above). |
| `../lean/AptosFormal/DiffTest/` | Lean JSON parser and runner. |

## Adding coverage

Add a `DiffTestSuite` in `src/suites/`, register it in `mod.rs` (`all_suites` + `suites_filtered`), extend **`funcNameToMapping`** in `AptosFormal.DiffTest.Runner`, and wire Lean **`ModuleEnv`** / natives as needed.
