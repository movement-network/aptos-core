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

## Current status

This is a **scaffold**. The Phase 1 day-one commit landed `verify-ca.sh --op register --stack lean`
as the first working path (it builds the Registration axiom-stub in seconds). Other routes dispatch
to "not implemented yet" pending their respective phases.

Per plan §10.6, Phase 7 is complete when:
- `--op <name>` works for every operation listed in §3 of the main plan, hitting the ≤ 3 min budget.
- CLAIMS.md has a row for every public function; every claim's rerun command is live.
- TRUST_BOUNDARIES.md reconciles with `#print axioms` + `grep pragma opaque` on a fresh build.
- `toolchain.lock` pins an actual Docker image digest, not `unpinned`.

## Updating

When a new phase lands: add / update the relevant rows in CLAIMS.md + TRUST_BOUNDARIES.md in the
same PR (not a doc-only follow-up) and flip the row's `*blocked* / TBD` markers to concrete links.
