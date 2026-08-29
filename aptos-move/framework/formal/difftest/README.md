# `move-lean-difftest` (Move VM → JSON oracle)

Compares the **real Aptos Move VM** (Rust) with the **Lean** evaluator (`lake exe difftest`) using a shared **JSON oracle**. This is **empirical regression testing**, not a proof.

## Quickstart (stdlib-only, this branch)

From **repo root**:

```bash
./aptos-move/framework/formal/difftest-stdlib.sh
```

Equivalent manual steps: same suite flags and paths as in [`../difftest-stdlib.sh`](../difftest-stdlib.sh) (regenerates the oracle, then `lake build difftest` + `lake exe difftest` from `lean/`).

Oracle JSON is **gitignored** (`difftest_oracle*.json`); regenerate with the script or `cargo run`.

```bash
cargo run -p move-lean-difftest -- --list-suites
cargo run -p move-lean-difftest -- --help
cargo run -p move-lean-difftest -- merge --help
```

## Further reading (in this directory)

| Doc | Use when |
|-----|----------|
| [`INVENTORY.md`](INVENTORY.md) | You want the **methodology** for suites, oracle discipline, and checklists for **adding** coverage. §1–2 and §5 stay generally valid; later sections still mention **CA / inventory paths** that were removed from *this* branch — treat those as archival pointers, not live paths. |
| [`ORACLE_CHANGELOG.md`](ORACLE_CHANGELOG.md) | You change **`schema_version`** or `TestCase` JSON shape — bump Rust + Lean and log the change here. Rows about CA-only cases remain **historical** context for schema **1**. |
| [`STUB_POLICY.md`](STUB_POLICY.md) | **Historical / CA-era** policy for how Lean `ModuleEnv` + globals aligned with CA difftests. This branch keeps a **stub** `Programs/Confidential.lean` for linker/catalog layout only; most of that doc **does not apply** until a CA formal branch is merged again. |

Formal tree overview: [`../README.md`](../README.md).
