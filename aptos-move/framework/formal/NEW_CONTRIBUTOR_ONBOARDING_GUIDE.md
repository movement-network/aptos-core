# New Contributor Onboarding Guide

**Audience:** Engineers joining the CA formal verification project  
**Prerequisites:** Basic Move/Rust knowledge, willingness to learn formal methods  
**Related:** `FORMAL_VERIFICATION_THEORY_PRIMER.md`, `COMPREHENSIVE_GUIDES_INDEX.md`

## Purpose

This guide provides structured onboarding path for engineers joining the Confidential Assets formal verification project. From zero to productive contributor in 2-4 weeks.

## Table of Contents

1. [Week 1: Environment Setup & Theory](#week-1-environment-setup--theory)
2. [Week 2: Hands-On Practice](#week-2-hands-on-practice)
3. [Week 3: First Contribution](#week-3-first-contribution)
4. [Week 4: Independent Work](#week-4-independent-work)
5. [Ongoing Learning](#ongoing-learning)

---

## Week 1: Environment Setup & Theory

### Day 1: Environment Setup (4 hours)

**Morning: Install Tools**

1. **Lean 4** (30 min):
   ```bash
   curl https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh -sSf | sh -s -- -y --default-toolchain v4.24.0
   source ~/.profile
   lean --version  # Should show: Lean (version 4.24.0, ...)
   ```

2. **Movement CLI** (30 min):
   ```bash
   curl -sSfL https://raw.githubusercontent.com/movementlabsxyz/aptos-core/main/scripts/dev_setup.sh | bash
   source ~/.profile
   movement --version
   ```

3. **Move Prover Dependencies** (30 min):
   ```bash
   movement update prover-dependencies --assume-yes
   $Z3_EXE --version  # Should show: Z3 version 4.11.2
   ```

4. **VS Code + Extensions** (30 min):
   - Install VS Code
   - Install: `leanprover.lean4` extension
   - Install: `move.move` extension (syntax highlighting)

5. **Clone Repository** (30 min):
   ```bash
   git clone https://github.com/movementlabsxyz/aptos-core.git
   cd aptos-core/aptos-move/framework/formal
   ```

6. **Verify Setup** (1 hour):
   ```bash
   # Lean:
   cd lean
   lake exe cache get  # Fetch mathlib cache (important!)
   lake build  # Should complete in ~5-10 min
   
   # Move Prover (smoke test):
   cd ../../move-stdlib
   movement move prove --filter vector  # Should pass
   ```

**Afternoon: Read Documentation (4 hours)**

1. **Skim unified verification plan** (1 hour):
   - File: `CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md`
   - Focus: §1-3 (why, trust model, tool assignment)
   - Goal: Understand big picture

2. **Read theory primer** (2 hours):
   - File: `FORMAL_VERIFICATION_THEORY_PRIMER.md`
   - Focus: What is FV, three stacks, soundness vs completeness
   - Goal: Understand verification fundamentals

3. **Skim comprehensive guides index** (1 hour):
   - File: `COMPREHENSIVE_GUIDES_INDEX.md`
   - Goal: Know what guides exist (reference later)

**End of Day 1:** Environment set up, high-level understanding of project

### Day 2: Lean Basics (8 hours)

**Morning: Lean 4 Tutorial (4 hours)**

1. **Lean 4 basics** (online tutorial, 2 hours):
   - https://lean-lang.org/theorem_proving_in_lean4/
   - Chapters 1-3: Basics, dependent types, propositions
   - Goal: Understand `theorem`, `def`, `#check`, `#eval`

2. **Lean tactics** (1 hour):
   - File: `LEAN_TACTICS_COOKBOOK.md` §1-3
   - Focus: `simp`, `rw`, `rfl`, `omega`
   - Goal: Know 5-10 common tactics

3. **Practice** (1 hour):
   - Create `lean/scratch.lean`
   - Copy-paste examples from cookbook
   - Run in VS Code, see tactics in action

**Afternoon: CA Lean Architecture (4 hours)**

1. **Read bytecode transcription guide** (2 hours):
   - File: `BYTECODE_TRANSCRIPTION_WORKFLOW_GUIDE.md`
   - Focus: §2-3 (architecture, workflow)
   - Goal: Understand symbolic state, step lemmas

2. **Explore Registration proof** (2 hours):
   - File: `lean/MovementFormal/Experimental/ConfidentialAsset/Registration/EvalEquivRebuild.lean`
   - Read top 100 lines (symbolic state definition)
   - Find one step lemma (e.g., `step_registration_pc0`)
   - Understand: state → step → new state

**End of Day 2:** Basic Lean literacy, understand CA Lean architecture

### Day 3: MSL Basics (8 hours)

**Morning: MSL Tutorial (4 hours)**

1. **MSL syntax** (1 hour):
   - Upstream: https://github.com/move-language/move/blob/main/language/move-prover/doc/user/spec-lang.md
   - Sections: Spec blocks, requires/ensures/aborts_if

2. **CA MSL specs** (2 hours):
   - File: `aptos-experimental/sources/confidential_asset/confidential_asset.spec.move`
   - Read specs for `register_internal`, `withdraw_to_internal`
   - Understand: preconditions, postconditions, abort conditions

3. **MSL patterns guide** (1 hour):
   - File: `MSL_SPECIFICATION_PATTERNS_GUIDE.md` §2-3
   - Focus: Basic patterns (resource existence, preservation)

**Afternoon: Run Move Prover (4 hours)**

1. **Smoke test** (1 hour):
   ```bash
   cd aptos-move/framework/aptos-experimental
   movement move prove --filter register_internal --verbose
   ```
   - Currently blocked on Phase 0, will fail with ristretto255 error
   - That's expected! Goal is to see Move Prover run

2. **Read MSL debugging guide** (2 hours):
   - File: `MSL_DEBUGGING_AND_VERIFICATION_GUIDE.md`
   - Focus: §1-2 (failure modes, error messages)

3. **Experiment** (1 hour):
   - Break a spec (comment out `aborts_if` clause)
   - Run Move Prover, see error
   - Fix spec, see it pass
   - Goal: Understand error messages

**End of Day 3:** MSL literacy, can read/write basic specs

### Day 4: Difftest & Three-Stack Model (8 hours)

**Morning: Difftest Architecture (4 hours)**

1. **Read difftest harness guide** (2 hours):
   - File: `DIFFTEST_HARNESS_DEVELOPMENT_GUIDE.md`
   - Focus: §1-2 (architecture, test development)

2. **Explore difftest corpus** (1 hour):
   - File: `difftest/corpora/confidential_asset/`
   - Read 3-5 scenarios (happy path, error path)
   - Understand: input → Lean executor → VM executor → compare

3. **Run difftest** (1 hour):
   ```bash
   cd aptos-move/framework/formal/difftest
   # Pending integration, placeholder:
   # ./difftest.sh --scenario register_happy_path
   ```

**Afternoon: Three-Stack Composition (4 hours)**

1. **Read composition guide** (2 hours):
   - File: `END_TO_END_COMPOSITION_VERIFICATION_GUIDE.md`
   - Focus: §1-2 (three-layer model, composition patterns)

2. **Read CLAIMS.md** (2 hours):
   - File: `audit/CLAIMS.md`
   - Pick one operation (e.g., Withdrawal)
   - Read all claims for that operation
   - Understand: Lean claim + MSL claim + Difftest binding

**End of Day 4:** Understand how three stacks compose

### Day 5: Verification Plan Deep Dive (8 hours)

**Morning: Phase Status (4 hours)**

1. **Re-read verification plan** (2 hours):
   - File: `CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md`
   - Now read §4-8 (phases)
   - Understand: what's done, what's outstanding

2. **Review Phase 6 status** (1 hour):
   - File: `audit/PHASE_6_FUNCTIONAL_SIMS.md`
   - Understand: which operations have PC-chaining proofs

3. **Review audit package** (1 hour):
   - File: `AUDIT_PACKAGE_FINAL_COMPLETION_GUIDE.md`
   - Understand: what deliverables exist, what's missing

**Afternoon: Ask Questions (4 hours)**

1. **Prepare questions** (1 hour):
   - Write down 10+ questions from week 1
   - Categorize: Lean, MSL, Difftest, Process

2. **Office hours with mentor** (2 hours):
   - Go through questions
   - Clarify confusing concepts
   - Get pointers to deeper resources

3. **Consolidate learnings** (1 hour):
   - Update personal notes
   - Write summary: "What I learned this week"

**End of Week 1:** Environment ready, theory understood, ready for hands-on practice

---

## Week 2: Hands-On Practice

### Day 6: Baby Lean Proof (8 hours)

**Goal:** Write first Lean proof from scratch

**Task:** Prove a simple step lemma for a new (hypothetical) operation

**Steps:**

1. **Read Phase 4 workflow** (1 hour):
   - File: `BYTECODE_TRANSCRIPTION_WORKFLOW_GUIDE.md` §3

2. **Copy template** (1 hour):
   - Copy `Withdrawal/EvalEquiv.lean` to `scratch/MyOperation.lean`
   - Simplify: 5 instructions instead of 15

3. **Write symbolic state** (2 hours):
   - Define `myOperationState` with `@[irreducible]`
   - Write projection lemmas (pc, locals, code)

4. **Write step lemmas** (3 hours):
   - Prove `step_0`, `step_1`, `step_2`, `step_3`, `step_4`
   - Use step-lemma library

5. **Run lake build** (1 hour):
   - Debug errors
   - Fix until `lake build scratch/MyOperation.lean` passes

**End of Day 6:** First Lean proof complete (even if simple)

### Day 7: Baby MSL Spec (8 hours)

**Goal:** Write first MSL spec from scratch

**Task:** Spec a simple helper function

**Steps:**

1. **Pick function** (30 min):
   - Choose simple function (e.g., `is_frozen`, `get_balance`)

2. **Write spec** (2 hours):
   ```move
   spec is_frozen {
       requires exists<ConfidentialAssetStore>(addr);
       ensures result == global<ConfidentialAssetStore>(addr).frozen;
       aborts_if !exists<ConfidentialAssetStore>(addr);
   }
   ```

3. **Run Move Prover** (1 hour):
   ```bash
   movement move prove --filter is_frozen
   ```
   - Debug errors
   - Fix until passes (or blocked on Phase 0)

4. **Read MSL coordination guide** (2 hours):
   - File: `MSL_TO_LEAN_COORDINATION_GUIDE.md`
   - Understand: MSL spec ↔ Lean proof consistency

5. **Write second spec** (2.5 hours):
   - Pick another function
   - Repeat process
   - Goal: Muscle memory for spec writing

**End of Day 7:** First MSL specs written, understand prover feedback

### Day 8: Difftest Scenario (8 hours)

**Goal:** Write first difftest scenario

**Task:** Happy-path scenario for simple operation

**Steps:**

1. **Read difftest development workflow** (1 hour):
   - File: `DIFFTEST_HARNESS_DEVELOPMENT_GUIDE.md` §2

2. **Copy template** (1 hour):
   - Find existing scenario (e.g., `register_happy_path`)
   - Copy as template for new scenario

3. **Write scenario** (3 hours):
   ```rust
   #[test]
   fn test_my_operation_happy_path() {
       let scenario = TestScenario::builder("my_op_happy")
           .account("alice", initial_balance(1000))
           .function("confidential_asset", "my_operation_internal")
           .arg(signer("alice"))
           .arg(u64(100))
           .oracle("verify_proof", OracleResult::Success)
           .expects_success()
           .build();
       
       assert!(run_difftest(&scenario).is_pass());
   }
   ```

4. **Run scenario** (2 hours):
   - Build: `cargo build --release`
   - Run: `cargo test test_my_operation_happy_path`
   - Debug until passes

5. **Document** (1 hour):
   - Add to `DIFFTEST_CA_INVENTORY.md`

**End of Day 8:** First difftest scenario written, understand test harness

### Day 9-10: Mini-Project (16 hours)

**Goal:** End-to-end mini-project (spec + proof + test)

**Task:** Add verification for a simple helper function

**Suggested function:** `has_pending_balance(addr: address): bool`

**Steps:**

**Day 9:**
1. **Write Move code** (2 hours):
   ```move
   public fun has_pending_balance(addr: address): bool acquires ConfidentialAssetStore {
       if (!exists<ConfidentialAssetStore>(addr)) {
           false
       } else {
           let store = borrow_global<ConfidentialAssetStore>(addr);
           vector::length(&store.pending_balance.chunks) > 0
       }
   }
   ```

2. **Write MSL spec** (3 hours):
   ```move
   spec has_pending_balance {
       ensures result == (
           exists<ConfidentialAssetStore>(addr) &&
           len(global<ConfidentialAssetStore>(addr).pending_balance.chunks) > 0
       );
       aborts_if false;  // Never aborts
   }
   ```

3. **Run Move Prover** (3 hours):
   - Debug spec until passes
   - Add to `CLAIMS.md`

**Day 10:**
4. **Transcribe to Lean** (4 hours):
   - Write bytecode def
   - Write step lemmas
   - Prove `eval_has_pending_balance_eq_run`

5. **Write difftest scenarios** (3 hours):
   - Happy path (has pending balance)
   - Edge case (no pending balance)
   - Error path (store doesn't exist)

6. **Document** (1 hour):
   - Update guides with learnings

**End of Day 9-10:** Complete mini-project, understand full stack

**Week 2 Summary:** Hands-on practice with all three stacks, first end-to-end contribution

---

## Week 3: First Contribution

### Day 11-15: Real Task (40 hours)

**Goal:** Complete a real task from backlog

**Suggested tasks (pick one, increasing difficulty):**

**Easy (2-3 days):**
1. Add missing difftest scenarios (5 scenarios from `DIFFTEST_CORPUS_EXPANSION_STRATEGY_GUIDE.md`)
2. Document one operation in `CLAIMS.md` (if not yet done)
3. Write MSL spec for governance function (`enable_allow_list`, etc.)

**Medium (3-4 days):**
4. Complete PC-chaining proof for one operation (Withdrawal, Normalization, or Rotation)
5. Add comprehensive guide on new topic (e.g., "Error Handling Patterns in CA")

**Hard (5 days):**
6. Singleton-branch PC-chaining for Registration (Phase 1 completion)
7. Design + implement new oracle + proofs

**Process:**

1. **Day 11: Task selection & planning** (4 hours):
   - Review backlog with mentor
   - Pick task matching skill level
   - Write task plan (breakdown, timeline)

2. **Day 11-14: Implementation** (28 hours):
   - Work on task
   - Daily stand-up with mentor (15 min)
   - Debug, iterate, refine

3. **Day 15: Code review & merge** (8 hours):
   - Open PR
   - Address review comments
   - Merge when approved

**End of Week 3:** First real contribution merged!

---

## Week 4: Independent Work

### Day 16-20: Self-Directed Task (40 hours)

**Goal:** Work independently (minimal mentorship)

**Suggested tasks:**
- Pick second task from Week 3 list
- OR: Propose own improvement (guide, optimization, bug fix)
- OR: Help with Phase 7 completion (audit package)

**Process:**
- Daily async updates (Slack)
- Weekly 1:1 with mentor (not daily)
- More autonomy, less hand-holding

**End of Week 4:** Comfortable working independently, second contribution merged

---

## Ongoing Learning

### Monthly Goals (Months 2-6)

**Month 2:** Become expert in one stack (Lean OR MSL OR Difftest)
**Month 3:** Become proficient in second stack
**Month 4:** Lead one phase completion (e.g., complete all Phase 6 PC-chaining proofs)
**Month 5:** Mentor new contributor
**Month 6:** Design new feature verification from scratch

### Resources for Deep Dive

**Lean 4:**
- Book: "Theorem Proving in Lean 4" (https://lean-lang.org/theorem_proving_in_lean4/)
- Book: "Functional Programming in Lean" (https://lean-lang.org/functional_programming_in_lean/)
- Community: Lean Zulip chat

**Move Specification Language:**
- Official docs: https://github.com/move-language/move/tree/main/language/move-prover/doc
- Paper: "The Move Prover" (https://arxiv.org/abs/...)
- Examples: Aptos framework specs (`aptos-framework/sources/*.spec.move`)

**Cryptography (for CA understanding):**
- Book: "Introduction to Modern Cryptography" by Katz & Lindell
- Paper: "Ristretto: Group Abstraction for Elliptic Curve Cryptography" (https://ristretto.group)
- Guide: `SIGMA_PROTOCOL_THEORY_AND_PRACTICE.md` (in this repo)

### Weekly Habits

**Monday:** Review verification health (`./scripts/release_health_check.sh`)
**Wednesday:** Read one comprehensive guide
**Friday:** Write/update one guide or document

### Continuous Improvement

**After each task:**
- What went well?
- What was hard?
- What would I do differently?
- What should be documented?

**Quarterly:**
- Review progress with mentor
- Set goals for next quarter
- Update onboarding guide with learnings

---

## Cheat Sheet

### Quick Commands

```bash
# Lean:
cd aptos-move/framework/formal/lean
lake exe cache get  # Fetch mathlib cache
lake build  # Build all
lake build MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquivRebuild  # Build one file

# Move Prover:
cd aptos-move/framework/aptos-experimental
movement move prove --filter register_internal  # Verify one function
movement move prove --verbose  # Verbose output

# Difftest:
cd aptos-move/framework/formal/difftest
cargo build --release
cargo test test_register_happy_path  # Run one test

# Verification suite:
cd aptos-move/framework/formal
./scripts/run_verification_suite.sh --quick  # 2 min
./scripts/run_verification_suite.sh --standard  # 5 min
./audit/verify-ca.sh --op register --stack lean  # Verify one operation
```

### Key Files

- **Verification plan:** `CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md`
- **Guides index:** `COMPREHENSIVE_GUIDES_INDEX.md`
- **Claims:** `audit/CLAIMS.md`
- **Trust boundaries:** `audit/TRUST_BOUNDARIES.md`
- **Lean proofs:** `lean/MovementFormal/Experimental/ConfidentialAsset/*/EvalEquiv.lean`
- **MSL specs:** `aptos-experimental/sources/confidential_asset/*.spec.move`
- **Difftest:** `difftest/corpora/confidential_asset/`

### Who to Ask

- **Lean questions:** @verification-team (Slack)
- **MSL questions:** @verification-team
- **Cryptography questions:** @crypto-team
- **Process questions:** @mentor
- **Stuck >2 hours:** Ask for help (don't spin wheels)

---

## Related Guides

- [FORMAL_VERIFICATION_THEORY_PRIMER.md](FORMAL_VERIFICATION_THEORY_PRIMER.md) — FV fundamentals
- [COMPREHENSIVE_GUIDES_INDEX.md](COMPREHENSIVE_GUIDES_INDEX.md) — All guides
- [CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md](CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md) — Master plan

---

**Document Status:** v1.0 (2026-04-22)  
**Maintainer:** Verification team  
**Last Updated:** 2026-04-22  
**Next Review:** After each new hire (update with feedback)

**Key Takeaway:** 4-week onboarding: Week 1 (theory + setup), Week 2 (hands-on practice), Week 3 (first real contribution), Week 4 (independent work). By end of month 1, should be productive contributor. Ongoing learning for months 2-6 to reach expertise.
