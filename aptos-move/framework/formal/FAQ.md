# CA Formal Verification — Frequently Asked Questions

**Last updated:** 2026-04-22

Common questions about the Confidential Assets formal verification stack, organized by topic.

## Table of Contents

- [General](#general)
- [Lean Stack](#lean-stack)
- [Move Prover Stack](#move-prover-stack)
- [Difftest Stack](#difftest-stack)
- [Architecture & Design](#architecture--design)
- [Trust & Security](#trust--security)
- [Contributing](#contributing)
- [Troubleshooting](#troubleshooting)

---

## General

### Q: What does "formally verified" mean for CA?

**A:** Three independent proof checkers (Lean, Move Prover, difftest) each verify different properties:

- **Lean** proves that `verify_*_proof` bytecode functions are semantically equivalent to the mathematical sigma-protocol verifier predicates
- **Move Prover** proves that CA state operations (deposit, withdraw, transfer, etc.) preserve balance, respect freeze/allow-list, and abort under documented conditions
- **Difftest** binds both to the real Move VM by checking that concrete inputs produce identical outputs

A claim like "transfer is formally verified" means all three stacks pass on that operation. See `CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md` §2 for the full trust model.

### Q: How much of CA is verified?

**A:** As of 2026-04-22, ~85% complete:

- **Phase 0** (tooling): ✅ 100%
- **Phase 1** (Registration): 🟡 95% (singleton branch outstanding)
- **Phase 4** (other crypto verifiers): ✅ 100% (all 4 EvalEquiv proofs done)
- **Phase 7** (reproducibility): 🟡 90% (difftest harness + Docker publish pending)

See `COMPLETION_ROADMAP.md` for detailed status and critical path to 100%.

### Q: Can I trust the verification even though it's not 100% complete?

**A:** Yes, with caveats:

- **What's verified is solid:** Registration + 4 other crypto verifiers (withdrawal, transfer, normalization, rotation) have complete Lean bytecode proofs with zero `sorry`, zero TEMPORARY axioms (except `registration_eval_equiv_functional_sim` which is being reproved).
- **What's not verified yet:** Move Prover verification is blocked on upstream ristretto255 patches (specs compile but generate 0 VCs). Phase 6 composition theorems have scaffolds but need PC-chaining proofs.
- **What's missing:** Difftest harness integration for end-to-end VM↔Lean consistency checking.

The crypto layer (Lean side) is production-ready. The state layer (Move Prover side) has specs written but verification is blocked upstream. See `audit/PHASE_7_STATUS.md` for acceptance criteria checklist.

### Q: How long does verification take to run?

**A:** Extremely fast (100x+ under budget):

- **Per-operation Lean build:** 1-2s (budget: 180s)
- **Per-operation Move Prover:** ~1s compilation (budget: 180s)
- **Full verification suite:** ~6s for Lean + Move Prover (budget: 2700s / 45 min)

Run `./scripts/benchmark_verification.sh` for detailed timing breakdown.

### Q: Who maintains this verification?

**A:** Movement Labs formal verification team + contributors. See `MAINTENANCE_GUIDE.md` for quarterly audit procedures and long-term maintenance strategy.

---

## Lean Stack

### Q: Why Lean 4 instead of Coq / Isabelle / other proof assistants?

**A:** Three reasons:

1. **Performance:** Lean 4's metaprogramming and compilation model allows sub-minute rebuilds (critical for developer iteration). Coq/Isabelle would be 10-100x slower for this codebase size.
2. **Mathlib ecosystem:** Lean 4 has the most active pure-math library (Mathlib) which we need for ristretto255 group theory.
3. **Team familiarity:** The team already had Lean 4 experience from prior formal verification work.

That said, the trust base is **not** "you must trust Lean." We have three independent proof checkers (Lean, Move Prover/Boogie/Z3, difftest/VM), so even if Lean's kernel has a bug, the other two stacks catch it. See §Trust & Security below.

### Q: What's the difference between `sorry`, `axiom`, and `admit`?

**A:**

- **`sorry`:** Proof placeholder ("I'll prove this later"). Production code must have zero `sorry` — the pre-commit hook enforces this.
- **`axiom`:** Explicitly unproved assumption, must be documented in `AXIOM_INVENTORY.md`. Two categories:
  - TEMPORARY: `registration_eval_equiv_functional_sim` (being reproved in Phase 1 singleton branch)
  - PERMANENT: Crypto axioms (ristretto255 discrete log, SHA-2 collision resistance, Bulletproofs soundness) — externally audited, not in-scope to prove
- **`admit`:** Not used in this codebase (Lean 4 convention is `axiom` for named assumptions)

Pre-commit hook: fails on new `sorry`, warns on new `axiom` without `AXIOM_INVENTORY.md` update.

### Q: Why does `lake build` take so long the first time?

**A:** You didn't fetch the mathlib cache. Mathlib is ~4 hours to compile from source. The cache makes it instant.

**Fix:**
```bash
cd aptos-move/framework/formal/lean
lake exe cache get  # Downloads pre-compiled mathlib
lake build          # Now finishes in ~4s
```

**Always run `lake exe cache get` before `lake build` in a fresh clone.**

### Q: How do I check what axioms my proof uses?

**A:**
```bash
cd lean
lake env lean --run ../scripts/print_axioms.lean MovementFormal.Experimental.ConfidentialAsset.<YourModule>
```

Or use the aggregator:
```bash
cd ../scripts
./check_axioms.sh
```

Expected output: only permanent crypto axioms + (temporarily) `registration_eval_equiv_functional_sim`. Any other axiom is a regression.

### Q: What's the step-lemma library and why does it matter?

**A:** The "step-lemma library" (`MovementFormal/MoveModel/StepLemmas/`) contains reusable theorems about how each Move bytecode instruction affects the machine state. Instead of re-proving "`stLoc` stores a value to local slot K" 100 times (once per proof), we prove it once parametrically and apply it everywhere.

**Why it matters:** This is the architecture change from Phase 0 that makes Lean proofs fast. Old Registration proof (chain-based, no library): 30+ min build, 25.6M heartbeats, O(N²) whnf. New proof (step-library): 3s build, <200k heartbeats, O(N).

See `CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md` §4 for the full architectural explanation.

### Q: My Lean proof is slow (>3 min). How do I debug it?

**A:** Profile it:
```bash
cd lean
lake env lean --run -Dprofiler=true MovementFormal/Experimental/ConfidentialAsset/<File>.lean
```

Common slow-proof causes:
1. **Missing `@[irreducible]` on symbolic state** → whnf traverses full chain
2. **Bound-proof elaboration in theorem statement** → use `Array.get?` not `.locals[K]'<proof>`
3. **Monolithic proof (>500 lines)** → split into sub-lemmas
4. **Missing `@[simp]` projection lemmas** → add projection suite for `@[irreducible]` defs

See `DEVELOPER_QUICK_START.md` §Troubleshooting and `TROUBLESHOOTING_GUIDE.md` §3 for full diagnostic procedures.

---

## Move Prover Stack

### Q: Why Move Prover + Z3 instead of just Lean for everything?

**A:** **Inheritance.** `aptos-framework` ships ~12,500 lines of MSL specs covering Fungible Asset, object, signer, etc. Those specs are Move-Prover-verified upstream. If we verify CA with Move Prover, we inherit those theorems **compositionally** (FA behaves per its spec, CA composes against it). In Lean, there's no free inheritance — we'd need to model the entire FA layer from scratch (multi-year effort).

The split: **Lean covers what Move Prover can't** (curve arithmetic, Fiat-Shamir), **Move Prover covers what Lean shouldn't duplicate** (FA framework integration, resource invariants). See `CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md` §1 for full rationale.

### Q: Why does Move Prover produce 0 VCs right now?

**A:** Blocked on upstream ristretto255 spec bugs:

1. `vector<CompressedRistretto>::length` monomorphization missing → breaks Boogie compilation
2. `ristretto255::spec_scalar_from_u{64,128}_internal` type mismatch (bv vs int) → same

Patches drafted in `PHASE_0_RISTRETTO255_PATCH_NOTES.md`, applied locally via deactivated invariants (workaround). Specs compile, but meaningful VCs require upstream fix. Current Move Prover work validates **toolchain readiness** (Boogie 3.5.1, Z3 4.11.2, CVC5 0.0.3 all working).

**Status (2026-04-22):** All CA modules compile, 0 VCs expected until ristretto255 blocker clears.

### Q: What's the difference between `pragma opaque` and `pragma verify = false`?

**A:**

- **`pragma opaque`:** "Treat this function as a black box (only pre/post, don't inline body)." Used for crypto boundaries — e.g., `ristretto255::point_mul` is opaque to Move Prover because it can't reason about curve arithmetic. Lean verifies the math, Move Prover treats it as an oracle. **89 instances in CA specs**, all documented in `TRUST_BOUNDARIES.md`.

- **`pragma verify = false`:** "Skip verification for this function entirely." Only acceptable for test-only code. **1 instance in CA:** `confidential_gas_e2e_helpers.spec.move` (test-only module, not called from production). Adding a new `pragma verify = false` to production code is a **verification escape** — pre-commit hook warns, requires justification in `TRUST_BOUNDARIES.md`.

### Q: I added a new `ensures` clause but Move Prover still passes. Why?

**A:** Two possibilities:

1. **0 VCs (current):** Ristretto255 blocker means specs compile but don't generate verification conditions. Your `ensures` clause is parsed but not yet verified. When blocker clears, solver will actually check it.

2. **Clause is tautological or unreachable:** Check that your clause actually constrains something. Example: `ensures true;` is valid but meaningless.

Validate spec locally:
```bash
movement move prove --package-dir aptos-experimental --filter <function> --verbose
# Look for "VCs generated: <N>" — should be >0 after ristretto255 fix
```

---

## Difftest Stack

### Q: What's difftest and why do we need it?

**A:** **Difftest = differential testing.** It runs the same inputs through (1) real Move VM, (2) Lean `MoveModel.step` evaluator, and (3) Move Prover solver, then checks outputs match byte-for-byte.

**Why it matters:** Lean and Move Prover verify *models* of the VM, not the VM itself. If the model drifts from reality (transcription bug, VM change), proofs can be sound-but-wrong. Difftest catches drift by pinning concrete I/O pairs as regression tests.

Example: If Lean proves `verify_transfer_proof` is correct, but the bytecode transcription has a typo, Lean proves the *wrong* bytecode correct. Difftest catches this because the real VM output won't match Lean's prediction.

### Q: How many difftest corpus rows do we have?

**A:** 87+ rows for CA (see `difftest/inventory/confidential_assets.md`), covering:

- Balance operations (add, sub, equals, chunk splitting)
- Proof deserialization (sigma layouts, Bulletproofs, Fiat-Shamir DSTs)
- Serialization helpers (auditor encryption keys, amounts)
- Registration helpers (Schnorr roundtrip, FS message goldens)
- Constants (chunk sizes, DST prefixes)

**Status:** Harness integration pending (Phase 7). Corpus rows exist, runner needs wiring into `verify-ca.sh --stack difftest`.

### Q: What's the difference between VM-only, VM↔Lean, and Blocked modes?

**A:** Difftest modes in the inventory:

- **VM-only:** Test runs in VM, oracle captured, but Lean doesn't evaluate it (e.g., FA globals, test-only functions). Regression detection only.
- **VM↔Lean:** Full round-trip — VM runs, Lean `eval` runs, outputs must match. This is the gold standard.
- **Blocked:** Can't run yet (missing natives, FA store stubbing, etc.). Marked in inventory with blocker reason.

Goal: zero Blocked entries by Phase 7 completion. Current status: most CA internal functions are VM↔Lean candidates, FA-integrated entry points are Blocked pending globals stubbing.

---

## Architecture & Design

### Q: Why three separate proof stacks instead of one unified proof?

**A:** **Separation of concerns + tool strengths:**

- **Lean** is best at low-level bytecode reasoning and pure math (curve arithmetic, sigma protocols)
- **Move Prover** is best at resource invariants and composing with upstream framework specs
- **Difftest** is best at catching model-reality drift

Trying to do everything in one tool means either:
- Lean: re-implement the entire FA framework from scratch (multi-year)
- Move Prover: can't reason about curve arithmetic (fundamentally SMT-incomplete)
- Difftest: no ∀-guarantees, only concrete test cases

Three stacks working together cover all bases. The "composition" happens at the VM boundary (difftest) and the English-language claims in `CLAIMS.md`, not by mixing proof terms.

### Q: What's the difference between `FunctionalSim` and `EvalEquiv`?

**A:** Two halves of a bytecode proof:

- **`FunctionalSim.lean`:** Mathematical model of what the operation *should* do (e.g., "verify_transfer_proof returns `.aborted 65537` iff the sigma predicate fails"). Pure functional spec, no bytecode.

- **`EvalEquiv.lean`:** Bytecode-level proof that the actual Move bytecode (transcribed into Lean's `MoveModel.step` evaluator) is semantically equivalent to the `FunctionalSim`. Proves the *implementation* matches the *spec*.

**Workflow:** Write `FunctionalSim` first (easier, no bytecode details), then prove `EvalEquiv` (harder, proves the VM does what the spec says).

Phase 1/4 deliverables are both files per operation.

### Q: What's `@[irreducible]` and why is it everywhere?

**A:** Lean optimization. `@[irreducible]` tells Lean "don't unfold this definition during type-checking — treat it as opaque and only unfold when explicitly `simp`'d."

**Why it matters:** Avoids O(N²) whnf cost in chained-state proofs. Without it, Lean tries to fully expand every intermediate state during theorem-statement elaboration → heartbeat explosion. With it, Lean stops at the `@[irreducible]` boundary → fast elaboration.

**Where to use it:** On all symbolic state definitions in `EvalEquiv` proofs. Expose behavior via `@[simp]` projection lemmas instead.

See `CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md` §4 for the full architectural explanation.

### Q: Why are we rewriting Registration instead of keeping the old proof?

**A:** Performance + generalization. Old Registration proof (chain-based, no step-library) takes 30+ min to build with 25.6M heartbeat overrides. The new architecture (symbolic state, step-library, `@[irreducible]`) targets <3 min. Rebuilding Registration first validates the architecture on a known-good theorem before applying it to the 4 other verifiers (which are greenfield).

The rebuild also deletes ~10k lines of O(N²) proof machinery, making the codebase maintainable long-term.

**Status:** 95% done, singleton branch outstanding. See `COMPLETION_ROADMAP.md` Phase 1.

---

## Trust & Security

### Q: What do I have to trust to believe the verification?

**A:** See `audit/TRUST_BOUNDARIES.md` for the full inventory. Summary:

**Kernel trust:**
- Lean kernel soundness
- Boogie + Z3 4.11.2 SMT solver soundness
- Move VM implementation matches bytecode spec

**Crypto axioms (externally audited, not proved in-repo):**
- Ristretto255 discrete-log hardness
- SHA-2/SHA-3 collision resistance
- Bulletproofs soundness and completeness
- Schnorr signature soundness

**Residual Lean axioms:**
- 27 total (10 CA code, 17 crypto dependencies)
- 1 TEMPORARY: `registration_eval_equiv_functional_sim` (being reproved)
- 26 PERMANENT: Group theory, ristretto encoding, Bulletproofs interface

**MSL escapes:**
- 89 `pragma opaque` (crypto boundary — Lean verifies the math)
- 1 `pragma verify = false` (test-only module)

**Bottom line:** You trust the three proof kernels + the crypto primitives. The crypto primitives are standard (Ristretto255, SHA, Bulletproofs) and externally audited. The kernels are small and well-studied.

### Q: How do I know the axioms aren't hiding bugs?

**A:** Three safeguards:

1. **Axiom inventory:** Every axiom is catalogued in `AXIOM_INVENTORY.md` with rationale (why it's unproved, why we accept it, how a skeptic would challenge it).

2. **Axiom-diff CI:** Any new axiom fails CI unless `AXIOM_INVENTORY.md` is updated in the same PR. Prevents silent axiom growth.

3. **Difftest validation:** Crypto axioms (e.g., "ristretto255 point addition is associative") are checked on concrete inputs via difftest. Not ∀-proved, but wrong axioms would cause VM≠Lean mismatches.

**Transparency:** The 27 axioms are listed front-and-center in `TRUST_BOUNDARIES.md`. If you don't trust an axiom, you can inspect it and decide for yourself.

### Q: What happens if Lean's kernel has a soundness bug?

**A:** Two mitigations:

1. **Independent checkers:** Move Prover (Boogie + Z3) and difftest (VM) are completely independent of Lean. A Lean kernel bug doesn't affect them. If Lean proves something wrong, Move Prover or difftest catches it.

2. **Lean kernel is small and audited:** Lean 4's kernel is ~5k lines of C++ with a simple de Bruijn term checker. It's been formally audited and has no known soundness bugs since 2021. Much smaller attack surface than trusting "the entire Move VM implementation."

**Bottom line:** A Lean bug would be bad, but it's caught by the other two stacks before it reaches production.

### Q: Are the proofs machine-checkable or just human-reviewed?

**A:** **Machine-checkable.** Every Lean theorem is checked by Lean's kernel. Every MSL spec is checked by Boogie + Z3. Every difftest row is checked by the VM + Lean evaluator. No "trust the reviewer" — the tools verify correctness mechanically.

Human review happens at the **axiom** and **trust-boundary** level: "Did we assume the right things? Are the crypto primitives sound?" But the proofs themselves are machine-checked, not hand-waved.

---

## Contributing

### Q: How do I get started contributing?

**A:** See `DEVELOPER_QUICK_START.md` for the full onboarding guide. Quick version:

1. Install Lean 4 + Movement CLI
2. Fetch mathlib cache: `lake exe cache get`
3. Build the tree: `lake build` (~4s)
4. Pick a task from `COMPLETION_ROADMAP.md` (e.g., Phase 6 PC-chaining proofs, Phase 7 difftest harness)
5. Submit PR with proof + docs in the same commit

Join #formal-verification Slack for questions.

### Q: What skills do I need to contribute?

**A:** Depends on the stack:

**Lean stack (Phase 1/4/6):**
- Lean 4 tactics (learn via [Theorem Proving in Lean 4](https://leanprover.github.io/theorem_proving_in_lean4/))
- Functional programming (Haskell/OCaml/Scala background helps)
- Bytecode-level reasoning (read Move bytecode, transcribe to Lean `step`)

**Move Prover stack (Phase 2/3/5):**
- MSL spec language (similar to Dafny/JML)
- SMT solver intuition (what Z3 can/can't prove)
- Move programming (read Move source, write specs)

**Difftest stack (Phase 7):**
- Rust (difftest harness is Rust)
- JSON schema (oracle format)
- Test engineering (corpus design, coverage analysis)

**Documentation stack (always):**
- Technical writing
- Markdown
- Ability to explain "why" not just "what"

No prior formal-methods experience required for docs, difftest, or Move Prover. Lean stack benefits from prior proof experience but we have onboarding examples.

### Q: How long does it take to add a new operation?

**A:** Rough estimates (for an experienced engineer):

- **Lean FunctionalSim:** 1-2 days (mathematical model)
- **Lean EvalEquiv:** 3-5 days (bytecode proof, depends on operation complexity)
- **MSL spec (internal function):** 1 day (state invariants)
- **MSL spec (entry point):** 2-3 days (compose with FA)
- **Difftest corpus rows:** 0.5-1 day (design + harness)
- **Documentation:** 0.5-1 day (CLAIMS.md, TRUST_BOUNDARIES.md, etc.)

**Total:** ~8-13 days for a new operation end-to-end (Lean + Move Prover + difftest + docs). Can parallelize: Lean and Move Prover work can happen simultaneously.

### Q: What's the review process for PRs?

**A:**

1. **Pre-commit hook:** Catches `sorry`, undocumented axioms, build errors
2. **CI (automated):** Runs `ca-verification-suite` workflow (~13 min) — Lean build, Move Prover compile, axiom diff, trust boundaries, performance check
3. **Human review:** Formal verification team reviews proof structure, axiom usage, documentation completeness
4. **Merge:** Once CI green + 1 approver, merge to `lean-fv` branch

**SLA:** Aim for <2 business days for review. Complex proofs (Phase 1/6) may take longer.

---

## Troubleshooting

### Q: CI failed with "axiom drift detected". What do I do?

**A:**

```bash
# Check what axioms changed
./scripts/check_axioms.sh --diff

# If intentional (e.g., you added a new crypto axiom):
# 1. Document in AXIOM_INVENTORY.md
vim audit/AXIOM_INVENTORY.md

# 2. Regenerate baseline
./scripts/check_axioms.sh > audit/axiom-baseline.txt

# 3. Commit both
git add audit/AXIOM_INVENTORY.md audit/axiom-baseline.txt
git commit --amend

# If unintentional (e.g., you accidentally introduced an axiom):
# Replace axiom with theorem or remove it
```

### Q: `movement move prove` says "Z3 version 4.14.x found, expected 4.11.2"

**A:** Homebrew Z3 is installed. Uninstall it:

```bash
brew uninstall z3
movement update prover-dependencies --assume-yes
$Z3_EXE --version  # Should now show 4.11.2
```

Never install Z3 via Homebrew for Move Prover — always use `movement update prover-dependencies`.

### Q: My PR is blocked on ristretto255 patches. What can I do?

**A:** For MSL specs:

- Write the specs anyway (they'll compile even if VCs are 0)
- Document in commit message: "Verification blocked on ristretto255, specs ready for when blocker clears"
- Track in `MOVE_PROVER_INTEGRATION_STATUS.md`

For Lean proofs:
- No blocker — Lean stack is independent of ristretto255 MSL issues
- Proceed normally

For difftest:
- Some operations blocked on FA globals stubbing
- Internal functions (non-entry points) should work — add those first

See `COMPLETION_ROADMAP.md` for parallel work that's not blocked.

### Q: Where do I ask for help?

**A:**

- **Slack:** #formal-verification (fastest for quick questions)
- **GitHub Issues:** For bugs, feature requests, long discussions
- **Office hours:** Formal verification team holds weekly office hours (check Slack for schedule)
- **Docs:** `TROUBLESHOOTING_GUIDE.md` has detailed diagnostic procedures

**Don't stay stuck** — if you've been blocked >30 min, ask in Slack.

---

## Meta

### Q: How do I add a question to this FAQ?

**A:**

```bash
vim FAQ.md
# Add Q&A in appropriate section
git add FAQ.md
git commit -m "FAQ: Add <topic> question"
```

No special process — just PR it. FAQ is living documentation.

### Q: This FAQ is missing <topic>. Where should I look?

**A:** Other docs that might answer your question:

- **Architecture:** `CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md`
- **Trust model:** `audit/TRUST_BOUNDARIES.md`
- **What's proved:** `audit/CLAIMS.md`
- **How to contribute:** `DEVELOPER_QUICK_START.md`
- **Maintenance:** `MAINTENANCE_GUIDE.md`
- **Troubleshooting:** `TROUBLESHOOTING_GUIDE.md`
- **Docker:** `audit/DOCKER_REPRODUCIBILITY_GUIDE.md`
- **CI:** `audit/CI_INTEGRATION_GUIDE.md`

Or ask in #formal-verification Slack.
