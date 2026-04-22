# Plan: Unified formal verification for Confidential Assets (Move Prover + Lean + difftest)

**Status:** proposal. Supersedes Lean-only scoping for operations beyond Registration.
**Related:** [`CONFIDENTIAL_ASSETS_FORMAL_VERIFICATION_PLAN.md`](CONFIDENTIAL_ASSETS_FORMAL_VERIFICATION_PLAN.md) (Lean-centric, Registration), [`CONFIDENTIAL_ASSETS_DIFFERENTIAL_TESTING_PLAN.md`](CONFIDENTIAL_ASSETS_DIFFERENTIAL_TESTING_PLAN.md) (VM↔Lean bridge).

## 0. Progress tracker

This section is the source of truth for where the plan is at. **Update it in the same PR that lands the work** — not as a separate doc-only commit, so status never drifts from reality. Every phase checkbox links to the merge commit that completed it.

| Phase | Scope | Status | Landed | Measured cost |
|---|---|---|---|---|
| 0 | Unblock tools (ristretto255 spec patches, Move Prover CI lane, Lean step-lemma library, `boogie.bpl` gitignore) | 🟡 in progress | step-lemma library + `boogie.bpl` gitignore landed; `move-prover-ca` workflow scaffolded (gated on `workflow_dispatch` until ristretto255 patches land); architecture demo (`StepLemmas/Example.lean`) validates per-PC composition end-to-end; ristretto255 spec patches outstanding | step-lemma files build in ~0.5s each; full 4-step run composition in `Example.lean` builds in 0.2s |
| 1 | Registration rebuilt on new Lean architecture, old `EvalEquiv/Part*.lean` deleted | 🟡 in progress | day-one axiom-stub + rebuild body landed: `EvalEquivRebuild.lean` (~3330 lines / **197 theorems**, zero `sorry`, zero axioms). Lands (a) `@[irreducible]` symbolic state + projection suite; (b) `eval_registration_eq_run`; (c) PC-lookup lemmas; (d) all 55 non-native PCs proved; (e) all 28 native-call happy-path PCs proved + 10 error-path `_none` variants; (f) complete per-function descriptor suite (51 `@[simp]` lemmas for `registrationModuleEnv.functions[0..16]`); (g) composition theorems — early-error, 2-PC / 3-PC happy-path; (h) complete non-singleton branch of the top-level theorem; (i) **16 functional-sim shape reductions** covering every case of the outer + `blockB` + `blockCDE` match trees — happy-path success (`_blockCDE_success` → `.returned [] empty`), verify-failed (`_blockCDE_verifyFailed` → `.aborted 65537`), and 14 `.error` variants for every intermediate oracle-failure point; (j) `ESIGMA_PROTOCOL_VERIFY_FAILED_ABORT_CODE_value = 65537` constant; (k) `optionIsSomeRef_immRef_read/_malformed` reduction lemmas in `Native.Registration`. **Outstanding:** the PC-level side of the singleton-some branch — threading through container-store mutation. All functional-sim reduction pieces are in place. | rebuild file `lake build` in 3.0s; downstream still builds in 1–2s; target ≤3 min |
| 2 | MSL specs for `*_internal` CA functions (4 functions) | 🟡 in progress | structural-scaffold specs landed for `register_internal` / `deposit_to_internal` / `withdraw_to_internal` / `confidential_transfer_internal` / `rotate_encryption_key_internal` / `normalize_internal` (6 functions — superset of plan scope) — store pre/post, abort conditions, frame conditions. Crypto-layer obligations (balance homomorphism, proof acceptance) deferred to Phase 4 + 5. **Spec compilation fix**: `get_user_address` impurity resolved via `spec fun spec_get_user_address` + `spec get_user_address { pragma opaque; ensures result == spec_get_user_address(...) }` bridge; `<CoinType>` generic syntax in `spec deposit_coins_to/deposit_coins` blocks fixed. All spec files now compile cleanly (`movement move compile` succeeds). Verification blocked on Phase 0 ristretto255 patches. | — |
| 3 | MSL specs for store-only ops (freeze/allow-list/governance/rollover, 9 functions) | 🟡 in progress | initial spec pass landed for `freeze_token_internal`, `unfreeze_token_internal`, `enable_allow_list`, `disable_allow_list`, `enable_token`, `disable_token`, `set_auditor`, `rollover_pending_balance_internal`, and view functions. `confidential_balance.spec.move` covers length invariants + abort conditions for add/sub/equals/split. `confidential_proof.spec.move` and `ristretto255_twisted_elgamal.spec.move` declare the crypto-opaque boundary via `pragma opaque`. Verification blocked on Phase 0 ristretto255 patches. | — |
| 4 | Lean proofs for `verify_withdrawal_proof` / `verify_transfer_proof` / `verify_normalization_proof` / `verify_rotation_proof` | ✅ done | **All 4 EvalEquiv proofs complete and building.** `Normalization/EvalEquiv.lean` (14-instr dispatcher, 14 per-PC step theorems + 2 error paths, `eval_normalization_eq_run`, `verifyNormalizationBytecodeResult` functional sim, builds in ~0.5s). `Rotation/EvalEquiv.lean` (15-instr, 15 per-PC + 2 error paths, builds in ~0.5s). `Withdrawal/EvalEquiv.lean` (15-instr, 15 per-PC + 2 error paths, builds in ~0.5s). `Transfer/EvalEquiv.lean` (24-instr, 3 sub-calls, 24 per-PC + 3 error paths — the most complex dispatcher — builds in ~0.7s). All use: per-instruction-class step-lemma library (`StepLemmas.Basic/Locals/Structs/Calls/Run`), `(by decide)` array-bounds proofs, named implicits for `env`/`frame`/`cs`/`stack`/`ms`, and direct `simp only [step, ...]` for `immBorrowField` and post-call `moveLoc` PCs. Total Phase 4 Lean: ~900 lines, zero sorry, zero axioms, full CA Lean tree builds in ~4s. | Normalization/Rotation/Withdrawal ~0.5s each; Transfer ~0.7s; full tree ~4s |
| 5 | MSL specs for FA-integrated entry points (9 functions) | 🟡 in progress | 15 entry-point specs landed in `confidential_asset.spec.move`: `register` / `deposit_to` / `deposit` / `deposit_coins_to<CoinType>` / `deposit_coins<CoinType>` / `withdraw_to` / `withdraw` / `confidential_transfer` / `rotate_encryption_key` / `rotate_encryption_key_and_unfreeze` / `normalize` / `freeze_token` / `unfreeze_token` / `rollover_pending_balance` / `rollover_pending_balance_and_freeze`. Each pins the store-observable part; FA side-effects remain `pragma opaque` until upstream `aptos_framework::fungible_asset` specs are audited for sufficiency (plan §8 Open Q 3). Verification blocked on Phase 0. | — |
| 6 | End-to-end composition claims per operation | 🟡 in progress | `audit/COMPOSITION_CLAIMS.md` drafted. **Phase 6 Lean scaffolds** landed for all 5 operations: `Registration/Phase6Composition.lean` (axiom `register_is_formally_verified`, discharged via `registration_eval_equiv_functional_sim`). `Withdrawal/Phase6Composition.lean`, `Transfer/Phase6Composition.lean`, `Normalization/Phase6Composition.lean`, `Rotation/Phase6Composition.lean` — all updated to import real `EvalEquiv` modules (not FunctionalSim stubs), state meaningful `*_is_formally_verified` axioms in terms of the real oracle types and eval expressions, and provide `example` derivations citing `eval_*_eq_run`. **Outstanding:** top-level equivalence theorems (`withdraw_eval_equiv_functional_sim`, etc.) connecting per-PC chains into single composition statements. | all 5 Phase6Composition.lean build cleanly in ~0.3s each |
| 7 | Reproducibility and audit package (§10 deliverables) | 🟡 in progress | scaffolded `audit/` directory: `CLAIMS.md`, `TRUST_BOUNDARIES.md`, `AXIOM_INVENTORY.md`, `COMPOSITION_CLAIMS.md`, `DIFFTEST_CA_INVENTORY.md`, `UPSTREAM_FA_SPEC_AUDIT.md`, `PROOF_FLOW.md`, `TEST_MATRIX.md`, `toolchain.lock`, `verify-ca.sh`, `README.md`, `axiom-baseline.txt`. `verify-ca.sh --op {register,withdraw,transfer,normalize,rotate} --stack lean` all build cleanly; `--coverage` mode reports theorem/spec/axiom counts; difftest dispatcher routes ops to the right `--suite`. **`check_axioms.sh --diff` + `.github/workflows/axiom-diff-ca.yaml`** implement the §10.5 axiom-diff CI guard — any new Lean axiom fails the guard unless `audit/axiom-baseline.txt` + `AXIOM_INVENTORY.md` are updated in the same PR. | `--op register --stack lean` ~4s; `--op withdraw/transfer/normalize/rotate --stack lean` ~0.5s each; axiom-diff runs in <1s |
| 8 | Axiom closure (Bulletproofs decision, `registration_eval_equiv_singleton_tail` elimination, ongoing axiom review) | 🟡 in progress | `audit/AXIOM_INVENTORY.md` drafted — 23 axioms across 5 files categorized into TEMPORARY (1: `registration_eval_equiv_functional_sim`), group-theory (12: Edwards group laws + 2 primality facts), Ristretto encoding (4: compression/roundtrip), Bulletproofs (5: external-audit acceptance). Only TEMPORARY category expected to shrink. | 21 permanent + 1 temporary (22 unique); regenerable via `./audit/verify-ca.sh --coverage` |

**Update conventions:**
- Status marks: `☐ pending`, `🟡 in progress`, `✅ done`, `⚠️ blocked`.
- "Landed" column: short commit SHA + date, linked.
- "Measured cost" column: fill in once measurable (build time, VC count, LoC) so future planning isn't guessing. Replaces the target numbers the moment reality is known.
- On `⚠️ blocked`, add a one-line reason and link to the blocker (issue, PR, upstream ticket).
- When a phase's scope changes mid-flight, edit the Scope column and mention the change in **§8 Open questions** (or resolve and remove the relevant question).

**Sub-progress within a phase** — for phases with many discrete deliverables (notably 2/3/4/5), mirror the per-function matrix in §3 with a status column, and update it as each function's spec or theorem lands. The §3 table becomes authoritative for "what's proved right now."

## Local developer setup (all three stacks)

Onboarding pointers. Each stack has a canonical setup location; this plan intentionally does **not** duplicate those instructions — fixes should land in the canonical doc so there's one source of truth.

| Stack | Canonical setup | What it covers |
|---|---|---|
| **Lean** | [`lean/README.md`](lean/README.md) | `lake build`, mathlib cache (`lake exe cache get`), toolchain pin (`lean-toolchain`), common failure modes (elan, old mathlib cache), per-file builds (`lake build MovementFormal.…`) |

> **ALWAYS run `lake exe cache get` before `lake build` in this repo.** Mathlib takes hours to compile from source; the cache makes clean builds finish in minutes. Any mathlib-pulling `lake build` without a warm cache is a mistake — abort and fetch the cache first. If a build has clearly been running too long without progress, this is the first thing to check.
| **Difftest** | [`difftest/README.md`](difftest/README.md) | `difftest.sh` runner, corpus layout, Rust suite IDs, `move-lean-difftest verify-corpora`, `Runner` config |
| **Move Prover** | **§5.1** of this document | `movement update prover-dependencies`, Boogie/Z3/CVC5 env vars, the Z3 4.14.x vs 4.11.2 pitfall, smoke-test command. If this section grows beyond three steps' worth of guidance, graduate it to its own `prover/README.md` and point §5.1 at that. |

Fastest end-to-end check that your setup is sane, once all three are installed:
```
./aptos-move/framework/formal/audit/verify-ca.sh --op register --stack move-prover   # ≤ 1 min
./aptos-move/framework/formal/audit/verify-ca.sh --op register --stack lean          # ≤ 3 min
./aptos-move/framework/formal/audit/verify-ca.sh --op register --stack difftest      # ≤ 1 min
```
(This script ships in Phase 7 — until then, the underlying `movement move prove`, `lake build`, and `difftest.sh` commands are the manual equivalent; see each stack's README for the current form.)

## 1. Why two stacks

The core insight: **the foundation we need is already formally verified upstream — we shouldn't re-prove it in Lean.**

`aptos-framework/sources/` ships ~12,500 lines of MSL specs across 48 `.spec.move` files covering Fungible Asset, object, signer, account, coin, and related primitives. Those specs are Move-Prover-verified upstream; they state things like "FA transfer preserves total supply," "object-creation invariants hold," "signer authentication is well-defined." Confidential Assets sits on top of those primitives — every `deposit`/`withdraw`/`transfer` entry point calls directly into FA.

If we verify CA with the Move Prover, we inherit those upstream theorems **compositionally**: the Move Prover treats an FA function call as a black-box pre/post rather than inlining it, so CA specs can assume FA behaves per its spec and the verification composes automatically. In Lean, there's no analogous free inheritance — every FA primitive would need modeling from scratch in `MoveModel` before CA could call into it. That's the multi-year cost we avoid by not reinventing the wheel.

So the split is:

- **Foundation (free, already done upstream):** MSL-verified `aptos-framework` — FA, object, signer, account, event, coin, friends. CA inherits these as theorems.
- **CA state layer (cheap, small CA-specific MSL on top):** balance conservation, freeze semantics, allow-list consistency, store invariants, abort conditions. Move Prover discharges them by composing with the upstream specs.
- **CA crypto layer (irreducibly Lean's job):** the five `verify_*_proof` bytecode theorems. Move Prover can't reason about curve arithmetic or Fiat–Shamir transcript structure; Lean can.
- **VM fidelity (always):** difftest corpus rows pin VM↔model agreement on concrete inputs; the ∀-guarantees from Move Prover and Lean are only as good as the model matching the VM, which difftest checks.

The second motivation — separate from the inheritance argument — is to improve Lean build performance so iteration is fast for everyone on the team. The new architecture in §4 targets sub-minute incremental rebuilds and a ≤3 min per-file budget, which makes everyday proof work tractable. This is independent of the Move Prover question; it's addressed by the Lean architecture described in **§4**.

The plan: **let each tool cover what it covers best, bind them through the VM via difftest, and never mix their proof terms.**

## 2. Trust model (what "formally verified" will mean for CA under this plan)

Three independent checkers, three trust bases, one common anchor:

- **Lean kernel** (small, de Bruijn-style type theory) — trust base for bytecode-level theorems about `MoveModel.step` and native oracles.
- **Boogie + Z3 (SMT)** — trust base for source-level MSL theorems about resources, store invariants, abort behavior.
- **Move VM** — ground truth. Difftest rows pin concrete (input, output) pairs for both stacks.

External cryptographic axioms remain (listed, not hidden): Ristretto255 discrete-log, SHA-2/3 collision resistance, Bulletproofs soundness/completeness (external audit, not verified in-repo).

**A claim like "`confidential_transfer` is formally verified" means, under this plan:**

1. **Move Prover proves** (source level): balance conservation, abort conditions, `ConfidentialAssetStore` invariants preserved, FA transfer side effects match spec, no unauthorized state mutations.
2. **Lean proves** (bytecode level): `verify_transfer_proof`'s bytecode is semantically equivalent to the mathematical sigma-verifier predicate in `SigmaVerifiers.lean` (the `verify_*` proof family, **not** the entry point).
3. **Difftest binds them** to the VM: the same bytes flow through both stacks and through the real VM; any disagreement fails CI.

Skipping any of the three is a scope reduction, not a verification claim.

## 3. Tool assignment per operation

Authoritative mapping for which tool covers what. **M** = Move Prover, **L** = Lean EvalEquiv-style, **D** = difftest binding (always), **—** = not applicable / external. As work lands, add a **Status** column per function and update it in the same PR that ships the proof (see **§0**).

| Operation | State/resource | Crypto / proof verifier | Entry wrapper |
|---|---|---|---|
| `register` / `register_internal` | **M** | **L** (Phase 1 rebuild — replaces existing EvalEquiv) | **M** |
| `deposit_to` / `deposit_to_internal` | **M** | — (no proof) | **M** |
| `deposit` / `deposit_coins*` | **M** | — | **M** |
| `withdraw_to` / `withdraw_to_internal` | **M** | **L** (verify_withdrawal_proof) | **M** |
| `withdraw` | **M** | **L** (as above) | **M** |
| `confidential_transfer` / `_internal` | **M** | **L** (verify_transfer_proof) | **M** |
| `rotate_encryption_key` | **M** | **L** (verify_rotation_proof) | **M** |
| `normalize` | **M** | **L** (verify_normalization_proof) | **M** |
| `rollover_pending_balance` / `_and_freeze` | **M** | — | **M** |
| `rotate_encryption_key_and_unfreeze` | **M** | **L** (verify_rotation_proof) | **M** |
| `freeze_token` / `unfreeze_token` | **M** | — | **M** |
| `enable_allow_list` / `disable_allow_list` | **M** | — | **M** |
| `enable_token` / `disable_token` / `set_auditor` | **M** | — | **M** |
| Governance / admin reads (`has_confidential_asset_store`, `pending_balance`, …) | **M** | — | **M** |
| Bulletproofs range-proof verify | — | **axiomatize** (external audit) | **D** only |
| Ristretto255 native operations | **M** (framework specs) | `@[opaque]` Lean native oracle | **D** only |

**D (difftest)** is implicit on every row: the existing 87-row CA corpus plus the sigma/Bulletproofs/serialization/FS-DST rows pin VM output byte-for-byte and will fail CI on any silent VM drift regardless of whether M or L verified the property. New operations added to M or L get a matching corpus row before the proof is merged.

## 4. Lean architectural revision

**Registration is rebuilt from scratch on the new architecture. The previous proof files are deleted at Phase 1 day one; the three public theorems they exported are temporarily replaced with `axiom` stubs so downstream (`Refinement.lean` → `EndToEnd.lean` → `BytecodeDifftestBridge.lean`) keeps building, and get reproved as the rebuild progresses.** The payoff is that the new architecture lands cleanly on main from day one and supports fast iteration (≤3 min per-file, sub-minute incremental) across the whole CA tree. Historical copies of the old files are available via `git show <commit>:<path>` if needed; no reason to keep them in the live tree. The existing mathematical content (L0 models, `SigmaVerifiers`, `FunctionalSim`, `TranscriptAlignment`, `Refinement`) is separate from the L2 EvalEquiv layer and stays untouched — only the bytecode-chain proofs are replaced. The axiom-stub transition cleanly splits "land the new architecture on main immediately" from "finish the rewrite properly"; each temporary axiom is visible in `#print axioms` output until it's reproved, which makes progress easy to see.

**Target build-time budget:** each `verify_*_proof` file (Registration included, post-rebuild) should complete `lake build` on the file alone in under **3 minutes** on a developer laptop, and the full CA Lean tree in under **10 minutes** cold. If a rebuild exceeds that budget, the architecture is wrong and we iterate before replicating it.

The five `verify_*` proofs (registration, withdrawal, transfer, normalization, rotation) share the same architecture:

- **Symbolic state, not chained frames.** Define `TransferVerifyState` (and analogues) as a flat record of named fields representing the abstract locals/stack/refs that matter. *Not* a chain of `{ prev with pc := N, locals := prev.locals.set K v _ }` definitions — that's what drives the O(N²) whnf cost and the 25.6M-heartbeat overrides in Part3.
- **Per-instruction-class step lemmas.** `step_stLoc_frame`, `step_immBorrowLoc_frame`, `step_call_frame`, … each proved *once*, parametric over an arbitrary input frame. Specific-PC proofs become one-line applications, not re-derivations.
- **`Array.get?` in theorem statements.** Avoid the `.locals[K]'<bound_proof>` idiom. The bound proof is what forces chain-unfold during statement type-elaboration, and is the reason my Apr 2026 attempt to lift heq-rfl bridges couldn't drop the heartbeat overrides — see [memory `feedback_fv_heartbeats.md`](../../../../../../.claude/projects/-Users-andygmove-Downloads-repos-aptos-core/memory/feedback_fv_heartbeats.md).
- **`@[irreducible]` from day one** on the symbolic state definitions; expose projection lemmas with `@[simp]`. whnf stops at the state boundary instead of traversing the full chain.
- **Native oracle as opaque interface.** Ristretto scalar math, point decompression, SHA-2, Bulletproofs — all remain `@[opaque]` definitions bound to named Rust/Move natives, with the difftest corpus as the fidelity check. No attempt to re-prove the crypto primitives in Lean.

**Rough cost estimate per operation after redesign:** 1.5–3k lines of Lean, **≤3 min build** (see budget above). Rebuilding Registration first validates the budget against a known-good theorem, which is strictly safer than greenfielding on the other four verifiers — divergences during the rebuild are architecture-level signals, easy to iterate on, rather than novel math problems.

## 5. Move Prover side

### 5.1 Local developer setup (one-time)

Exact steps for a teammate onboarding from scratch. These are the same steps that got the prover running on `lean-fv` during plan authoring; the pain points they avoid are real and already hit.

1. **Install prover dependencies via the Movement CLI's installer**:
   ```
   movement update prover-dependencies --assume-yes
   ```
   This downloads and installs Boogie 3.5.1, Z3 4.11.2, and CVC5 0.0.3 to `~/.local/bin/`, and writes `BOOGIE_EXE` / `Z3_EXE` / `CVC5_EXE` to your shell profile. **Do not install Z3 from Homebrew** — Homebrew ships Z3 4.14.x, which the Move Prover rejects with `expected at most version 4.11.2 but found 4.14.x for z3`. Using the installer above ensures the right version.

2. **Source the profile or open a new terminal** so the env vars land in your session. Then verify:
   ```
   $Z3_EXE --version       # expect: Z3 version 4.11.2
   $BOOGIE_EXE -version    # expect: Boogie 3.0.9 or 3.5.1
   ```

3. **Smoke-test end-to-end** against a module known to verify cleanly:
   ```
   movement move prove \
     --package-dir aptos-move/framework/move-stdlib \
     --filter vector \
     --vc-timeout 20 \
     --skip-fetch-latest-git-deps
   ```
   Expect `{ "Result": "Success" }` in under 5 seconds. If this fails, something is off with your local setup — do not proceed to CA verification until this is green.

4. **Also ensure**: `DOTNET_ROOT=$HOME/.dotnet` (or wherever `dotnet` lives) is exported — Boogie is a .NET tool and needs it at runtime.

5. **Gotcha: `boogie.bpl` in the repo root** is an intermediate artifact that `movement move prove` regenerates on every run (~300 KB). It's already in `.gitignore` on `lean-fv`; don't commit it.

### 5.2 Prerequisites (blocking right now)

Running `movement move prove` on any CA module on the `lean-fv` branch currently fails at Boogie compilation — not because CA specs are wrong, but because **upstream `aptos-stdlib` ristretto255 specs are incomplete for codegen paths CA hits:**

- `vector<CompressedRistretto>::length` monomorphization missing → breaks anything touching `SigmaProofXs`/similar vector-of-compressed types (confidential_proof).
- `ristretto255::spec_scalar_from_u{64,128}_internal` declared with `int` but called with `bv64`/`bv128` in the Boogie translation of `confidential_balance`.

Both must be patched in `aptos-move/framework/aptos-stdlib/sources/cryptography/ristretto255.spec.move` before any CA MSL work can reach the solver. These are pre-existing upstream framework bugs this plan inherits — filing them with upstream (or patching locally) is **Phase 0 task #1**.

**Candidate patches written up in [`PHASE_0_RISTRETTO255_PATCH_NOTES.md`](PHASE_0_RISTRETTO255_PATCH_NOTES.md)** with three options for Bug 1 (in order of least-to-most invasive: module-level `pragma bv_implementation = false`, companion bv-typed spec funs, or swap `u64`/`u128` for MSL `num`) and a deactivated-invariant trigger workaround for Bug 2. Recommendation: try the module-pragma fix first; concrete reproduce-and-apply steps are enumerated in the patch-notes doc.

### 5.3 MSL spec development

The four CA `*.spec.move` files (`confidential_asset`, `confidential_balance`, `confidential_proof`, `ristretto255_twisted_elgamal`) are currently empty stubs (`spec <mod> { }`, 2 lines each). They need:

- **Resource invariants** on `ConfidentialAssetStore` and `FAConfig` (non-negativity, allow-list consistency, freeze-state well-foundedness).
- **Function specs** with `aborts_if` / `ensures` / `requires` / `modifies` for each public/entry function. Priority order = Phases 2, 3, 5 below (Move Prover phases, in dependency order).
- **Inline `spec` blocks** (as opposed to sidecar `.spec.move`) for arithmetic invariants tightly coupled to a single function body (`confidential_balance` is the main candidate).
- **Pragmas** where Move Prover needs hints: `pragma aborts_if_is_strict`, `pragma verify = true` at module level, opaque abstractions (`pragma opaque`) for crypto natives that Move Prover should treat as uninterpreted.

### 5.4 CI lane

Move Prover runs go into a new CI job parallel to the existing `lake build` lane:

```
move-prover-ca:
  env:
    BOOGIE_EXE, Z3_EXE, CVC5_EXE, DOTNET_ROOT   # via movement update prover-dependencies
  steps:
    - movement move prove --package-dir aptos-move/framework/aptos-experimental \
        --named-addresses aptos_experimental=0x7 \
        --filter 'confidential_(proof|balance|asset|twisted_elgamal)' \
        --vc-timeout 120
    - scripts/check_axioms.sh   # enumerate pragma opaque, pragma deactivated, mvp axioms
```

Timeouts must be bounded (`--vc-timeout 120` or lower) so any stall surfaces quickly in CI. Pin Z3 4.11.2 and Boogie 3.5.1 in the Docker image (movement CLI already enforces the Z3 version; Boogie version is looser).

## 6. Phasing

Sequenced by dependency and by what unlocks what. Each phase ends with: (a) a green CI run, (b) a scope-doc update listing new proved properties and new axiom citations, and (c) an update to the **§0 progress tracker** in the same PR — status mark, commit SHA, and measured cost. Phases don't count as done until §0 reflects reality.

### Phase 0 — Unblock the tools (1–2 weeks)
- Patch ristretto255 spec bugs in `aptos-stdlib` (vector length monomorphization, scalar-from-u64/u128 bv/int mismatch).
- Stand up `move-prover-ca` CI lane, proving a trivial placeholder invariant on `confidential_balance` end-to-end so "green" is meaningful.
- Build the per-instruction-class Lean step-lemma library (`MovementFormal/MoveModel/StepLemmas/`) — the shared infrastructure the rebuilt `verify_*` proofs will consume.
- Commit `.gitignore` rule for `boogie.bpl` (already done on lean-fv branch).

### Phase 1 — Registration rebuild as architecture validation (3–5 weeks)

**Day-one commit** — replace old proof with an axiom-only stub so downstream keeps building:
- Delete `EvalEquiv/Part*.lean` + `EvalEquiv/README.md`.
- Rewrite `EvalEquiv.lean` as a minimal axiom-only stub declaring **only the public name `Refinement.lean` applies as a term** (`registration_eval_equiv_functional_sim`) as a temporary axiom, carrying a doc-comment `-- TEMPORARY AXIOM: reproved in Phase 1 completion commit (rebuild on new architecture)`. Grep confirms the other two old public names (`registration_eval_equiv_singleton_tail`, `registration_eval_equiv_singleton_tail_of_schnorr_hmac_bundle`) are referenced outside `EvalEquiv/*` only in doc comments, so they don't need axiom stubs — they were internal machinery for the old chain-based proof and the rebuild is free to introduce fresh internal lemmas with different names and shapes.
- Skip the `#print axioms` baseline snapshot: the old tree doesn't compile fast enough to produce one reliably, and the baseline we care about is textual — "only `registration_eval_equiv_functional_sim` + documented crypto axioms," checked directly on the rebuild.
- Result: CI builds in minutes instead of 30, `lean-fv` main is unblocked for everyone, and the one remaining public axiom is clearly flagged as work-in-progress.

**Body of Phase 1** — rebuild on the new architecture:
- Build out `MovementFormal/Experimental/ConfidentialAsset/Registration/EvalEquiv.lean` using symbolic state, `@[irreducible]`, the step-lemma library from Phase 0, and `Array.get?` in statements.
- Reprove `registration_eval_equiv_functional_sim`. Remove its temporary `axiom` declaration once closed.
- Whether an internal axiom analogous to the old `registration_eval_equiv_singleton_tail` resurfaces depends on the rebuild architecture; track any such residual axiom as Phase 8 work when and if it reappears.

**Phase 1 acceptance criteria:**
- No temporary axioms remain; only `registration_eval_equiv_singleton_tail` + documented crypto axioms appear in `#print axioms`.
- Diff of `#print axioms` output vs `audit/registration-axioms-baseline.txt`: exactly zero additions (same or fewer axioms).
- Full file `lake build` on the rebuilt `EvalEquiv.lean` under **3 min**; full CA Lean tree under **10 min cold**.
- `BytecodeDifftestBridge.lean` + `EndToEnd.lean` build unchanged without modification.
- `./verify-ca.sh --op register --stack lean` completes in ≤ 3 min (§10.1 budget).

**Why Phase 1 goes first:** we already have a known-good theorem to target (snapshotted in `registration-axioms-baseline.txt`), so divergences during the rebuild are architecture bugs (fixable on a clean rebuild) not math bugs (expensive). Validates the ≤3 min budget before committing to four more verifiers.

### Phase 2 — `*_internal` functions, store stubbed (3–6 weeks)
- Move Prover specs for `register_internal`, `deposit_to_internal`, `withdraw_to_internal`, `confidential_transfer_internal`.
- Covers: balance arithmetic, abort conditions, `ConfidentialAssetStore` field-level pre/post.
- These don't load from global state inside — they take the store as an argument — so they sidestep the FA/resource blockers until Phase 5.
- First real Move Prover proofs land; establishes the "MSL is ground truth for state" half of the claim.

### Phase 3 — Store-only operations (2–4 weeks, parallelizable with Phase 2)
- Move Prover specs for `freeze_token`, `unfreeze_token`, `enable_token`, `disable_token`, `enable_allow_list`, `disable_allow_list`, `set_auditor`, `rollover_pending_balance`, `rollover_and_freeze`.
- Pure store mutations, no crypto. Clean territory for Move Prover.
- Invariant: every abort listed in existing e2e difftest rows (`e2e_freeze_twice` → 196615, `e2e_unfreeze_not_frozen` → 196616, …) gets a corresponding `aborts_with` clause.

### Phase 4 — Remaining crypto-verifier family in Lean (3–6 weeks, faster than Registration rebuild thanks to reuse)
- Lean EvalEquiv-style proofs for `verify_withdrawal_proof`, `verify_transfer_proof`, `verify_normalization_proof`, `verify_rotation_proof` using the Phase 0 step-lemma library and the Phase 1-validated architecture.
- Each lands as its own file under `MovementFormal/Experimental/ConfidentialAsset/<Operation>/EvalEquiv.lean`.
- Each ≤3 min build (per the budget); full CA Lean tree stays under 10 min cold with all four added.
- Parallels existing `SigmaVerifiers.lean` math predicates.

### Phase 5 — FA-integrated entry points (4–6 weeks, blocks on aptos-framework FA specs)
- Move Prover specs for `register`, `deposit_to`, `deposit`, `withdraw_to`, `withdraw`, `confidential_transfer`, `rotate_encryption_key`, `normalize`, `rotate_encryption_key_and_unfreeze`.
- Requires: `aptos_framework::fungible_asset` has reasonable MSL specs. If not, upstream contribution needed; this is the biggest external dependency.
- Observable: each entry point's invariants compose from Phase 2 (internal) + Phase 3 (store) + upstream FA framework specs.

### Phase 6 — End-to-end composition (2–4 weeks)
- Bind Move Prover results and Lean results for a single operation (e.g., `confidential_transfer`) into an English-language claim: "the entry point, as shipped bytecode, preserves balance conservation, respects freeze/allow-list, aborts precisely under the listed conditions, and its embedded proof-verification accepts iff the sigma predicate holds."
- No literal proof composition — the binding is textual + difftest-enforced.

### Phase 7 — Reproducibility and audit package (2–3 weeks)
Ship the artifacts that let a third party — teammate, reviewer, external auditor — confirm the verification holds without reading the source tree. Deliverables enumerated in **§10**.

### Phase 8 — Remaining axioms and closure (ongoing)
- Decide Bulletproofs treatment: axiomatized (current plan) vs Lean-implemented (multi-year, likely out of scope).
- Audit `#print axioms` on every top-level theorem. Keep the list short, named, and reviewed per release.
- Integrate `registration_eval_equiv_singleton_tail` elimination (currently parked pending `dropMs` / `@[irreducible]` refactor — see `EvalEquiv/Part4.lean:1493`).

## 7. What gets thrown away vs kept

**Kept unchanged:**
- `SigmaVerifiers.lean` and `SigmaVerifiersGoldens.lean` — the mathematical models and hermetic goldens remain the specification half of every `verify_*_proof` rebuild.
- `FunctionalSim.lean`, `TranscriptAlignment.lean`, `Operational.lean`, `Refinement.lean`, `Formal.lean`, `EndToEnd.lean` — the L0/L1 layers and refinement scaffolding stay; only the L2 (bytecode) layer is rebuilt.
- All 87 CA difftest corpus rows.
- `BytecodeDifftestEval.lean` + `BytecodeDifftestBridge.lean` — the single-trace L2→L1→L0 witness; retargetable to the new L2 proof when Registration is rebuilt.

**Deleted immediately (first commit of Phase 1), then replaced:**
- `EvalEquiv/Part1.lean` + `EvalEquiv/Part2.lean` + `EvalEquiv/Part2A.lean` + `EvalEquiv/Part2B.lean` + `EvalEquiv/Part2C.lean` + `EvalEquiv/Part3.lean` + `EvalEquiv/Part4.lean` + `EvalEquiv/README.md` — the entire expensive chain-based proof, gone on day one of Phase 1.
- `EvalEquiv.lean` is **replaced** (not deleted) with a minimal axiom-only stub declaring the three public theorems `Refinement.lean` depends on (two temporary axioms + one pre-existing axiom), so downstream keeps building while the body of Phase 1 rebuilds the proofs. See Phase 1 day-one commit in §6.
- Historical copy available via git; no reason to keep the old files in-tree slowing every build.

**Rebuilt with new architecture (greenfield):**
- `verify_withdrawal_proof` / `verify_transfer_proof` / `verify_normalization_proof` / `verify_rotation_proof` Lean EvalEquiv chains — do not exist yet. Phase 4.

**New, does not exist yet:**
- All MSL specs for CA modules (currently 4 empty 2-line stubs).
- `MovementFormal/MoveModel/StepLemmas/` — the per-instruction-class Lean library.
- `move-prover-ca` CI lane and Docker-pinned prover dependencies.
- Patched `aptos-stdlib/sources/cryptography/ristretto255.spec.move`.

**Not in scope for this plan:**
- Lean implementation of Bulletproofs verifier (multi-year cryptographic engineering, out of scope).
- Lean FA framework model (use Move Prover + framework MSL specs instead).

## 8. Open questions

1. **Who owns the upstream ristretto255 spec patches?** — 🟡 **partially resolved.** Concrete patch drafted at [`ristretto255.spec.patch`](ristretto255.spec.patch) (Candidate Patch B + monomorphization trigger), with candidate-patch rationale in [`PHASE_0_RISTRETTO255_PATCH_NOTES.md`](PHASE_0_RISTRETTO255_PATCH_NOTES.md). Recommendation: apply locally + open upstream PR in parallel. Still needs: someone with Move Prover access to apply and verify the three `movement move prove` reproducer commands in the patch header.
2. **Bulletproofs: MSL `pragma opaque` with external audit citation, or Lean axiom with external audit citation?** — ✅ **resolved via "both."** Upstream `ristretto255_bulletproofs.spec.move` already declares `verify_range_proof_internal` / `verify_batch_range_proof_internal` as `pragma opaque`; CA composes against those. Lean axioms in `AptosStd/Crypto/Bulletproofs.lean` (5 axioms catalogued in [`audit/AXIOM_INVENTORY.md`](audit/AXIOM_INVENTORY.md) §4) cover the Lean-side bytecode claims.
3. **Does `aptos_framework::fungible_asset` have MSL specs upstream?** — ✅ **resolved.** Full audit in [`audit/UPSTREAM_FA_SPEC_AUDIT.md`](audit/UPSTREAM_FA_SPEC_AUDIT.md). Verdict: sufficient for CA's critical Phase 5 composition (requirements 4+5 pin owner-only withdraw + supply preservation, which are the two invariants `deposit_to` / `withdraw_to` compose against). Follow-up: audit `dispatchable_fungible_asset.spec.move` as a Phase 5 prerequisite.
4. **Registration axiom elimination (`registration_eval_equiv_singleton_tail`):** — ✅ **resolved: no longer needed.** The old axiom was deleted with the old `EvalEquiv/Part*.lean` chain. The rebuild in `EvalEquivRebuild.lean` has no equivalent axiom — its composition threads directly through `run` via the PC-step library. Only TEMPORARY AXIOM left is `registration_eval_equiv_functional_sim` itself, tracked in Phase 1.
5. **MSL expressiveness for sigma relations:** — 🟡 **ongoing.** Current approach: CA's MSL specs declare `verify_*_proof` as `pragma opaque` with `aborts_with 65537, 65538` (the two failure modes). The Lean side pins the sigma-predicate semantics via the `registration_eval_equiv_functional_sim` theorem. This is the "pragma opaque + Lean covers math" split recommended in the plan text. Viable long-term.
6. **Proof maintenance cost per Move-source diff:** — 🟡 **monitored.** Lean-side: 185+ theorems rebuild in ~3s; MSL-side: 88 spec blocks per run. CI budget (plan §10.6) ≤ 45 min full, ≤ 3 min per-op hits the target. Actual churn cost per Move-source diff is ≤ 5 min per op (rebuild + difftest) based on current per-op `verify-ca.sh` timings. **Verdict: within budget; re-measure if per-op exceeds 3 min.**

## 9. Definition of "done" for CA formal verification under this plan

Green on all three proof checkers:

- **Move Prover CI** proves the MSL spec for every public function listed in §3 column 1, with no `pragma verify = false`, `pragma aborts_if_is_partial`, or `pragma deactivated_proof` escapes.
- **Lean `lake build`** succeeds for every `verify_*_proof` theorem in §3 column 2, each producing a `#print axioms` list limited to the documented crypto axioms and (temporarily) `registration_eval_equiv_singleton_tail`.
- **`move-lean-difftest` VM↔Lean corpus CI** passes on the 87-row CA corpus plus new rows added per operation per phase, with zero `Blocked` or `Option B` entries remaining in §3 of [`difftest/inventory/confidential_assets.md`](difftest/inventory/confidential_assets.md).

Plus the reproducibility-package deliverables in §10 all shipped. A verification that passes CI but that a third party can't re-run and audit is not "done" for this plan's purpose.

Operations not listed in §3 (future CA features) get added to the matrix at feature-design time, with tool assignment committed before code merge.

## 10. Reproducibility and audit package

The verification above is only meaningful if someone other than the authors can confirm it. Phase 7 ships these artifacts, all under `aptos-move/framework/formal/audit/` (new directory).

### 10.1 Single-command reproducer with per-claim granularity

**`aptos-move/framework/formal/audit/verify-ca.sh`** is the reviewer entry point. It supports both full-stack verification and targeted single-claim verification, so a reviewer can either confirm the whole thing or poke at one specific property in under ~3 minutes.

**Full-stack run** (used for release certification and CI):
```
./verify-ca.sh
```
Runs all three proof checkers against the full CA surface, exits non-zero on any failure, writes status JSON to `audit/last-run.json`. Target wall-clock ≤ 45 min on the pinned Docker image (a soft acceptance criterion — see §10.6; replace with the measured number once Phase 1 lands).

**Per-operation run** (the default reviewer mode):
```
./verify-ca.sh --op transfer
./verify-ca.sh --op withdraw
./verify-ca.sh --op register
./verify-ca.sh --op freeze
```
Verifies everything attached to one operation — its MSL spec via Move Prover (scoped with `--only confidential_asset::transfer_internal`), its Lean bytecode theorem if any (single-file `lake build`), and the difftest rows tagged to that operation. **Budget: ≤ 3 minutes per operation**, matching the per-file Lean build budget in §4. If any operation exceeds 3 min, the architecture missed its target — either in Lean (Phase 1 exit criterion) or in MSL (re-scope the spec).

**Per-stack run** (narrow to one checker):
```
./verify-ca.sh --op transfer --stack move-prover
./verify-ca.sh --op transfer --stack lean
./verify-ca.sh --op transfer --stack difftest
```
Useful when a reviewer wants to understand what each tool contributes to a given operation. Sub-minute for each individual check in the typical case.

**Per-claim run** (by plain-English name from CLAIMS.md):
```
./verify-ca.sh --claim "transfer preserves balance sum"
./verify-ca.sh --claim "freeze rejects frozen accounts"
./verify-ca.sh --list                    # enumerate available claims
```
The `--claim` flag fuzzy-matches against CLAIMS.md entries and runs the single minimal command recorded there. `--list` prints the full claim list with expected wall-clock per claim, so reviewers can plan which to check without surprises.

All modes share the same exit-code semantics (non-zero on any failure), the same JSON status output, and the same cache behavior — a full run followed by a per-op run should take the per-op time, not re-do work. Implementation: granular `lake build <Module>` targets + `movement move prove --only <mod::func>` + difftest row tags indexed by operation name.

### 10.2 Claims guide
**`audit/CLAIMS.md`** — the human-readable map from "what do you want to know" to "where is it proved." For each operation in §3, it lists:
- The plain-English property ("transfer preserves encrypted-balance sum," "freeze prevents future transfers," "verify_transfer_proof accepts iff the sigma predicate holds on the honest oracle").
- The tool that proves it (Move Prover / Lean / difftest).
- The file and theorem name (`file.lean:LINE` or `module.spec.move: spec transfer_internal`).
- The exact command to re-check just that theorem in isolation.
- Any axioms or `pragma opaque` declarations it relies on, with a back-pointer to §10.3.

No CA property covered by this plan is complete until it has a line in CLAIMS.md.

### 10.3 Trust-boundary inventory
**`audit/TRUST_BOUNDARIES.md`** — enumerates every unproved assumption the verification relies on, organized by trust category:
- **Kernel / solver trust:** Lean kernel soundness, Boogie soundness, Z3 4.11.2 soundness, the difftest runner's assumption that oracle JSON matches VM output.
- **Crypto axioms:** Ristretto255 discrete-log hardness, SHA-2/3 collision resistance, Bulletproofs soundness and completeness, Schnorr-registration soundness — each with a citation to the source (paper or code) and a note on why it's not in-scope.
- **Native-function assumptions:** every `@[opaque]` Lean def bound to a Move native, every `pragma opaque` MSL declaration, and the claim that the Lean oracle matches the VM native (verified per-input by difftest, not ∀-verified).
- **Residual axioms in Lean:** `registration_eval_equiv_singleton_tail` and anything else `#print axioms` reveals on top-level theorems.
- **MSL escapes:** any `pragma aborts_if_is_partial`, `pragma verify = false`, `pragma deactivated_proof`, or explicitly-declared abstraction.

Each row has: name, declaration location, what it asserts, why we accept it, how a skeptic would challenge it.

### 10.4 Reproducibility pin
**`audit/toolchain.lock`** plus a Docker image (or Nix flake) pinning:
- Lean toolchain version (currently v4.24.0).
- Movement CLI version.
- Boogie version (3.5.1).
- Z3 version (4.11.2 — must match the Movement CLI pin, not Homebrew's latest).
- CVC5 version (0.0.3 if we keep it in the install).
- OS base image and architecture.

A reviewer on a different machine gets identical tool versions; otherwise reruns drift and the "red" vs "green" status becomes machine-dependent — the exact symptom we fought with Z3 4.14.1 vs 4.11.2 earlier on this branch.

### 10.5 Axiom-diff CI guard
**`audit/axiom-baseline.txt`** checked into the repo, regenerated per release. A CI job runs `#print axioms` on every top-level Lean theorem and every MSL `pragma opaque` declaration, diffs the output against the baseline, and fails if anything new appears. Prevents silent trust-base growth — the kind of regression where "formally verified" shifts meaning without anyone noticing.

### 10.6 Acceptance criteria for Phase 7

- `./verify-ca.sh` (full run) completes on the pinned Docker image from a fresh clone in ≤ 45 minutes — a soft ceiling; replace with the measured number the moment Phase 1 and Phase 4 both land.
- `./verify-ca.sh --op <operation>` completes any single operation in ≤ 3 minutes. This is the hard acceptance bar: if a per-op verification takes longer, reviewers won't use it and §10 has failed its purpose.
- `./verify-ca.sh --list` enumerates every claim in CLAIMS.md with expected wall-clock and the stack(s) that prove it.
- `CLAIMS.md` has an entry for every public function in §3 with a file:line that opens in an editor and a minimal rerun command that matches what `--claim` dispatches to.
- `TRUST_BOUNDARIES.md` enumeration reconciles with `#print axioms` + `grep pragma opaque` output on a fresh build (CI check).
- `axiom-baseline.txt` committed; axiom-diff CI lane green.
- A person unfamiliar with the project can, in ≤30 minutes of reading, point at which tool proves which property, what the unproved assumptions are, and what command to run to check any single claim.

§10 is what makes the rigor in §1–§9 externally auditable: reviewers get a single command for any claim, a documented trust boundary, and a pinned reproducible toolchain. This is how the verification becomes something teammates and auditors can actually use, not just something that exists.
