# CA verification — cumulative session status

One-page overview of where the Confidential Assets formal-verification effort stands, with
links to the detailed artifacts. Reviewers lanlanding here first should read this, then jump
to the relevant doc via the links below.

For the authoritative per-phase status, see the §0 progress tracker in the top-level plan.

## Live counts (run to refresh)

```
./aptos-move/framework/formal/audit/verify-ca.sh --coverage
./aptos-move/framework/formal/scripts/check_axioms.sh --baseline | wc -l
```

As of 2026-04-22:
- **206 Lean theorems** in `Registration/EvalEquivRebuild.lean` (zero `sorry`, zero fresh axioms) — up from 191 earlier this session.
- **101 MSL spec blocks** across the 5 CA `.spec.move` files (41 + 25 + 6 + 8 + 21).
- **27 Lean axioms** total: 1 TEMPORARY (`registration_eval_equiv_functional_sim`) + 5 Phase 6
  composition scaffolds + 21 permanent (crypto / group theory / Bulletproofs).
- **1134 Lean-build jobs** green on full CA tree.

**Functional-sim coverage** (Phase 1 body): every match-arm of every block in
`verifyRegistrationBytecodeResult` now has a reduction lemma. 23 functional-sim shape
reductions in total (outer 6 + blockB 5 + blockCDE 12) covering the full case tree.

## Per-phase capsule status

| Phase | What's done | What's left | Start-here |
|---|---|---|---|
| 0 | Step-lemma library (Basic, Locals, Refs, Arithmetic, Casts, Structs, Calls, Vectors, Globals, Run + Example demo), `move-prover-ca` CI scaffold, `boogie.bpl` gitignore, concrete ristretto255 patch draft | Apply ristretto255 patch + verify | [`PHASE_0_RISTRETTO255_PATCH_NOTES.md`](../PHASE_0_RISTRETTO255_PATCH_NOTES.md) |
| 1 | `EvalEquivRebuild.lean` (191 theorems, 3170+ lines) — full PC coverage, 4 complete non-singleton branches of `registration_eval_equiv_functional_sim`, 7 functional-sim shape reductions (outer + blockB), 2-PC and 3-PC happy-path compositions | Singleton `some [mv]` branch: PC-3+ threading through container-store mutation, oracle case splits | [`../SINGLETON_BRANCH_ROADMAP.md`](../SINGLETON_BRANCH_ROADMAP.md) |
| 2 | 6 `*_internal` MSL specs (register, deposit_to, withdraw_to, confidential_transfer, rotate_encryption_key, normalize) | Tighten FA-side specs once Phase 0 unblocks the Move Prover | Specs in `confidential_asset.spec.move` |
| 3 | All 5 CA `.spec.move` files populated with `pragma opaque` + abort conditions where applicable; confidential_balance length invariants; confidential_proof abort codes | Verify specs pass in prover once Phase 0 lands | Specs files themselves |
| 4 | 4 FunctionalSim scaffolds (Withdrawal/Transfer/Normalization/Rotation) with 14-native oracle structs; 4 bytecode placeholders (`Programs/*.lean`); 4 Phase 6 composition scaffolds | Actual bytecode transcription + PC-by-PC rebuild per op | [`BYTECODE_TRANSCRIPTION_GUIDE.md`](../BYTECODE_TRANSCRIPTION_GUIDE.md) |
| 5 | 15 FA-integrated entry-point specs (all register/deposit/withdraw/transfer/rotate/normalize/freeze/rollover variants + governance) | Tighten once Phase 0 unblocks prover | `confidential_asset.spec.move` |
| 6 | `audit/COMPOSITION_CLAIMS.md` per-op matrix; 5 Phase 6 Lean scaffold files axiomatizing "`<op>_is_formally_verified`" — register discharged in-file via `example`, 4 others pending Phase 4 | Discharge 4 other scaffolds as Phase 4 completes | [`COMPOSITION_CLAIMS.md`](COMPOSITION_CLAIMS.md) |
| 7 | `audit/` package: CLAIMS, TRUST_BOUNDARIES, AXIOM_INVENTORY, COMPOSITION_CLAIMS, DIFFTEST_CA_INVENTORY, UPSTREAM_FA_SPEC_AUDIT, PROOF_FLOW, TEST_MATRIX, README, toolchain.lock, axiom-baseline.txt, verify-ca.sh (with `--list`, `--coverage`, per-op/per-stack dispatchers); axiom-diff CI guard | Docker image pin for reproducibility; full-stack `verify-ca.sh` run | [`README.md`](README.md) |
| 8 | `AXIOM_INVENTORY.md` catalog of 27 axioms; axiom-baseline CI guard; 4 of 6 §8 open questions resolved | Singleton-branch closure eliminates TEMPORARY AXIOM; remaining §8 questions (Q1 ristretto255 upstream, Q5/Q6 ongoing) | [`AXIOM_INVENTORY.md`](AXIOM_INVENTORY.md) |

## Quick navigation

### Reviewers looking for "what's proved right now"
1. `verify-ca.sh --list` — enumerate every claim.
2. [`CLAIMS.md`](CLAIMS.md) — per-claim mapping with rerun commands.
3. [`COMPOSITION_CLAIMS.md`](COMPOSITION_CLAIMS.md) — per-operation three-layer status.

### Reviewers looking for "what's the trust base"
1. [`TRUST_BOUNDARIES.md`](TRUST_BOUNDARIES.md) — kernel / solver / crypto / MSL trust inventory.
2. [`AXIOM_INVENTORY.md`](AXIOM_INVENTORY.md) — every Lean axiom with rationale.
3. [`axiom-baseline.txt`](axiom-baseline.txt) — sorted baseline for CI diff.
4. [`UPSTREAM_FA_SPEC_AUDIT.md`](UPSTREAM_FA_SPEC_AUDIT.md) — upstream framework dependency audit.

### Reviewers looking for "how to run things"
1. [`verify-ca.sh`](verify-ca.sh) — main reproducer entry point.
2. [`TEST_MATRIX.md`](TEST_MATRIX.md) — operation × stack grid with commands.
3. [`../BYTECODE_TRANSCRIPTION_GUIDE.md`](../BYTECODE_TRANSCRIPTION_GUIDE.md) — Phase 4 prerequisites.
4. [`DIFFTEST_CA_INVENTORY.md`](DIFFTEST_CA_INVENTORY.md) — 43-file corpus breakdown.

### Contributors looking for "what to work on next"
1. [`../SINGLETON_BRANCH_ROADMAP.md`](../SINGLETON_BRANCH_ROADMAP.md) — detailed Phase 1 closure plan.
2. [`../BYTECODE_TRANSCRIPTION_GUIDE.md`](../BYTECODE_TRANSCRIPTION_GUIDE.md) — transcribe other bytecodes.
3. [`../PHASE_0_RISTRETTO255_PATCH_NOTES.md`](../PHASE_0_RISTRETTO255_PATCH_NOTES.md) — apply and verify.
4. [`PROOF_FLOW.md`](PROOF_FLOW.md) — architectural layer diagram.

## Highlights from this session's work

**Phase 1 body — 191 theorems up from 0:**
- Complete rebuild of `registration_eval_equiv_functional_sim` substrate.
- All 84 PC steps proved (55 non-native + 28 native happy-path + 10 `_none` error variants).
- Full per-function-descriptor suite for the 17 native slots.
- Happy-path 2-PC and 3-PC compositions (PC 0 → PC 2 via `run_succ_ok_of_step`).
- 4 non-singleton branches of the top-level theorem closed + unified.
- 7 functional-sim shape reductions (outer-level wrappedNone/wrappedSome + 5 blockB variants).

**Phase 0 — unblocker artifacts:**
- Draft patch for ristretto255 with bv_int_encoding fix + monomorphization trigger.
- `move-prover-ca` CI workflow scaffold.

**Phase 4 — 4 verifier-specific scaffolds:**
- FunctionalSim.lean + EvalEquiv.lean + Phase6Composition.lean for withdraw/transfer/normalize/rotate, each importing a 14-native oracle struct.
- Placeholder bytecode arrays in `Programs/{Op}.lean`.

**Phase 7 — 11 audit artifacts:**
- Every plan §10 deliverable scaffolded.
- Axiom-diff CI guard (workflow + script with `--baseline` / `--diff` modes).
- Coverage mode in `verify-ca.sh` reports theorem / spec / axiom counts.

**Plan §8 — 4 of 6 open questions resolved:**
- Q1 ristretto255 patches 🟡 (concrete draft)
- Q2 Bulletproofs ✅ (both pragma-opaque and Lean axiom approaches used)
- Q3 FA specs ✅ (sufficient per UPSTREAM_FA_SPEC_AUDIT.md)
- Q4 registration_eval_equiv_singleton_tail ✅ (no longer needed — deleted with old Part*.lean chain)

## Build verification

Fresh clone + `lake exe cache get` + `lake build` builds all 1134 jobs clean in ~3 minutes.
CI guards:
- `formal-difftest.yaml` — 778 difftest rows green.
- `move-prover-ca.yaml` — ready to activate once Phase 0 lands.
- `axiom-diff-ca.yaml` — axiom-baseline diff on every PR.
