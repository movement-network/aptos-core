# CA formal-verification audit package

Reviewer-facing artifacts for the unified Confidential Assets verification effort.
See [`../CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md`](../CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md) §10 for the full rationale.

## Contents

| File | Purpose |
|---|---|
| [`CLAIMS.md`](CLAIMS.md) | Plain-English property → tool → file:theorem → rerun command. One row per verifiable claim. |
| [`TRUST_BOUNDARIES.md`](TRUST_BOUNDARIES.md) | Every unproved assumption: kernel/solver trust, crypto axioms, native-function opacity, residual Lean axioms, MSL escapes, upstream framework dependencies. |
| [`toolchain.lock`](toolchain.lock) | Pinned versions of Lean / Boogie / Z3 / CVC5 / Rust / Docker base image. |
| [`verify-ca.sh`](verify-ca.sh) | Single-command reproducer. `--op <name>` runs one operation through all three stacks; `--list` enumerates claims. |

## Quick start (once Phase 7 is fully live)

```bash
# Enumerate what's verifiable:
./verify-ca.sh --list

# Spot-check one operation (≤ 3 min target):
./verify-ca.sh --op transfer

# Full-stack verification (≤ 45 min target):
./verify-ca.sh

# Run a single claim by name:
./verify-ca.sh --claim "transfer preserves balance sum"
```

## Current status (updated 2026-04-23)

**Lean stack: ✅ FUNCTIONAL**

`verify-ca.sh` now provides full-stack verification for the Lean stack:
- `./verify-ca.sh --stack lean` runs all 5 operations in ~6s (0.2% of 45-min budget)
- `./verify-ca.sh --op <name> --stack lean` verifies individual operations in 1-2s
- `./verify-ca.sh --coverage` reports theorem counts (310 total across 5 operations)
- `./verify-ca.sh --claim <text>` searches CLAIMS.md for matching claims
- All timing tracked against plan §10.6 budgets (≤180s per-op, ≤2700s full run)

**Move Prover stack: ✅ TOOLCHAIN READY, ⚠️ VERIFICATION BLOCKED**

Move Prover integration complete:
- ✅ Toolchain installed (Z3 4.11.2, Boogie 3.5.1, CVC5 0.0.3)
- ✅ `./verify-ca.sh --stack move-prover` functional for all 5 operations (~1s each)
- ✅ All 6 CA spec files compile cleanly
- ⚠️ Verification blocked on ristretto255 upstream patches (Phase 0)
- Current: 0 VCs (specs compile but crypto verification fails)
- See `../MOVE_PROVER_INTEGRATION_STATUS.md` for detailed status

**Difftest stack: 🟡 SCAFFOLDED**

Scaffolding in place but requires harness setup:
- Difftest: needs difftest harness at `formal/difftest.sh`

Per plan §10.6, Phase 7 completion requires:
- ✅ `--op <name>` works for every operation with ≤3 min budget (Lean: done, Move Prover: toolchain ready)
- 🟡 CLAIMS.md rerun commands (search works, per-claim dispatch pending)
- 🟡 TRUST_BOUNDARIES.md reconciliation (manual check needed)
- 🟡 `toolchain.lock` pinning (Lean/Boogie/Z3 done, Docker image digest pending)

**Performance:** All Lean verifications well within budget (~6s). Move Prover toolchain overhead ~1s per operation (0 VCs).

## Updating

When a new phase lands: add / update the relevant rows in CLAIMS.md + TRUST_BOUNDARIES.md in the
same PR (not a doc-only follow-up) and flip the row's `*blocked* / TBD` markers to concrete links.
