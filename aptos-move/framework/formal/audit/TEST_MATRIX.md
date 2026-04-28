# CA verification test matrix — `audit/TEST_MATRIX.md`

Operation × (MSL / Lean / difftest) grid of test commands a reviewer can run to spot-check
individual claims. Supersedes ad-hoc "run `lake build X`" recipes scattered across the Lean
namespace docs.

**One-command entry point:** `./audit/verify-ca.sh --op <name> --stack <move-prover|lean|difftest>`.

This matrix lists the underlying commands `verify-ca.sh` dispatches to, plus manual-invocation
fallbacks for when a reviewer wants finer granularity than the script provides.

## Grid

Legend: ✅ = has working test command; 🟡 = scaffold only (no test yet); ☐ = not applicable.

| Operation | MSL spec | Lean theorem | Difftest corpus | Combined |
|---|---|---|---|---|
| `register` | ✅ `movement move prove --filter register_internal` (blocked on Phase 0) | ✅ `lake build MovementFormal.…Registration.EvalEquivRebuild` (128+ theorems) | ✅ 5 rows (FS DST / msg / SHA goldens) | ✅ `verify-ca.sh --op register` |
| `register` entry | ✅ `spec register` (wraps `register_internal`) | ☐ | ✅ registration golden rows | 🟡 |
| `deposit_to` / `deposit` | ✅ `spec deposit_to_internal`, `spec deposit_to`, `spec deposit` | ☐ (no crypto) | e2e via `difftest.sh --suite confidential_asset` | 🟡 |
| `deposit_coins_to` / `deposit_coins` (generic) | ✅ `spec deposit_coins_to<CoinType>` | ☐ | ✅ (same suite) | 🟡 |
| `withdraw_to` / `withdraw` | ✅ `spec withdraw_to_internal`, entry specs | 🟡 `Withdrawal/EvalEquiv.lean` + `FunctionalSim.lean` scaffold | ✅ `verify_withdrawal_proof_zero_sigma_aborts` row | 🟡 |
| `confidential_transfer` | ✅ `spec confidential_transfer_internal` with auditor-count + hint-length invariants | 🟡 `Transfer/EvalEquiv.lean` scaffold | ✅ 20 transfer-with-auditors corpus rows (0–19 auditors) | 🟡 |
| `rotate_encryption_key` + `_and_unfreeze` | ✅ `spec rotate_encryption_key_internal`, `spec rotate_encryption_key_and_unfreeze` | 🟡 `Rotation/EvalEquiv.lean` scaffold | ✅ `verify_rotation_proof_zero_sigma_aborts` row | 🟡 |
| `normalize` | ✅ `spec normalize_internal`, `spec normalize` | 🟡 `Normalization/EvalEquiv.lean` scaffold | ✅ `verify_normalization_proof_zero_sigma_aborts` row | 🟡 |
| `freeze_token` / `unfreeze_token` | ✅ `spec *_token_internal` + entry specs | ☐ (no crypto) | ✅ `e2e_freeze_twice`, `e2e_unfreeze_not_frozen` | ✅ |
| `rollover_pending_balance` + `_and_freeze` | ✅ `spec rollover_pending_balance_internal` + entry | ☐ | ✅ e2e rollover rows | ✅ |
| `enable_allow_list` / `disable_allow_list` / `enable_token` / `disable_token` / `set_auditor` | ✅ governance specs | ☐ | ✅ e2e governance rows | ✅ |
| View funcs (`pending_balance`, `actual_balance`, `encryption_key`, `is_normalized`, `is_frozen`, `is_allow_list_enabled`, `has_confidential_asset_store`) | ✅ | ☐ | ✅ e2e read rows | ✅ |

## Manual commands (granular)

### Lean: build one operation's proof target

```bash
cd aptos-move/framework/formal/lean
lake exe cache get       # ALWAYS FIRST — see plan §Local-dev-setup
lake build MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquivRebuild
lake build MovementFormal.Experimental.ConfidentialAsset.Withdrawal.FunctionalSim
lake build MovementFormal.Experimental.ConfidentialAsset.Transfer.FunctionalSim
lake build MovementFormal.Experimental.ConfidentialAsset.Normalization.FunctionalSim
lake build MovementFormal.Experimental.ConfidentialAsset.Rotation.FunctionalSim
lake build MovementFormal.MoveModel.Programs.{Withdrawal,Transfer,Normalization,Rotation}
lake build MovementFormal.MoveModel.StepLemmas.{Basic,Locals,Refs,Arithmetic,Casts,Structs,Calls,Vectors,Globals,Run,Example}
```

### Lean: full tree build (sanity)

```bash
cd aptos-move/framework/formal/lean
lake exe cache get
lake build   # takes ~5 min on a warm cache, all mathlib deps already cached
```

### Move Prover: per-module (blocked on Phase 0 ristretto255 patches)

```bash
# After applying formal/ristretto255.spec.patch upstream:
cd aptos-move/framework/aptos-experimental
movement move prove \
  --named-addresses aptos_experimental=0x7 \
  --filter 'confidential_(proof|balance|asset|twisted_elgamal)' \
  --vc-timeout 120 \
  --skip-fetch-latest-git-deps
```

### Difftest: per-suite

```bash
cd aptos-move/framework/formal
./difftest.sh --suite confidential_asset
./difftest.sh --suite confidential_proof
./difftest.sh --suite confidential_balance
./difftest.sh --suite confidential_elgamal
DIFTEST_MERGE_CA_E2E=1 ./difftest.sh --suite confidential   # includes e2e rows
```

### Audit utilities

```bash
./audit/verify-ca.sh --list            # enumerate all claims
./audit/verify-ca.sh --coverage        # theorem / spec / axiom counts
./scripts/check_axioms.sh              # axiom + pragma-opaque inventory
```

## Blocking dependencies

| Dependency | What's blocked | Resolution |
|---|---|---|
| Phase 0 ristretto255 spec patches | All Move Prover `movement move prove` runs on CA | Apply [`formal/ristretto255.spec.patch`](../ristretto255.spec.patch) + verify; see [`PHASE_0_RISTRETTO255_PATCH_NOTES.md`](../PHASE_0_RISTRETTO255_PATCH_NOTES.md) |
| Phase 4 bytecode transcription | Lean theorems for withdrawal / transfer / normalize / rotate | Follow [`BYTECODE_TRANSCRIPTION_GUIDE.md`](../BYTECODE_TRANSCRIPTION_GUIDE.md) |
| Phase 1 singleton branch | The `registration_eval_equiv_functional_sim` TEMPORARY AXIOM | See [`SINGLETON_BRANCH_ROADMAP.md`](../SINGLETON_BRANCH_ROADMAP.md) |

## Acceptance milestones (from plan §10.6)

- [ ] `verify-ca.sh` (full run) on pinned Docker image from fresh clone ≤ 45 min
- [ ] `verify-ca.sh --op <name>` any single op ≤ 3 min
- [x] `verify-ca.sh --list` enumerates every claim ✅ (implemented)
- [x] `CLAIMS.md` has a row for every public function in §3 ✅
- [x] `TRUST_BOUNDARIES.md` enumeration reconciles with `#print axioms` + `grep pragma opaque` ✅ (via `axiom-baseline.txt`)
- [ ] `axiom-baseline.txt` committed; axiom-diff CI lane green — scaffolded, CI wiring pending
- [ ] A person unfamiliar with the project can, in ≤ 30 min, identify tool-per-property, unproved assumptions, and rerun command — use this doc as the entry point
