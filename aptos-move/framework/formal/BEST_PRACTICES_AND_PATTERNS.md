# Best Practices and Patterns for CA Formal Verification

**Purpose:** Collected wisdom and battle-tested patterns from the CA formal verification project. Covers architectural decisions, coding conventions, performance optimizations, and team workflows.

**Audience:** All developers working on CA formal verification.

---

## Table of Contents

1. [Architectural Principles](#1-architectural-principles)
2. [Lean Coding Conventions](#2-lean-coding-conventions)
3. [MSL Specification Conventions](#3-msl-specification-conventions)
4. [Performance Patterns](#4-performance-patterns)
5. [Testing Strategies](#5-testing-strategies)
6. [Code Review Guidelines](#6-code-review-guidelines)
7. [Git Workflow](#7-git-workflow)
8. [Common Anti-Patterns to Avoid](#8-common-anti-patterns-to-avoid)
9. [Onboarding New Team Members](#9-onboarding-new-team-members)
10. [Lessons Learned](#10-lessons-learned)

---

## 1. Architectural Principles

### 1.1 Separation of Concerns (Three Stacks)

**Principle:** Each verification stack has a specific purpose. Don't mix their responsibilities.

**Guidelines:**
- **Lean** proves bytecode-level properties (crypto verifiers, PC semantics)
- **Move Prover** proves source-level properties (state invariants, resource safety)
- **Difftest** validates VM fidelity (concrete execution consistency)

**Anti-pattern:**
```lean
-- DON'T: Try to prove state-level properties in Lean
theorem balance_conservation_in_lean : 
    sum_balance(new_state) = sum_balance(old_state) := by ...
-- This belongs in MSL, not Lean
```

**Correct pattern:**
```move
-- DO: Prove state properties in MSL
spec normalize_internal {
    ensures sum_balance(store.pending_balance) == sum_balance(old(store.pending_balance));
}
```

---

### 1.2 Trust Boundaries Are Explicit

**Principle:** Every unproved assumption must be documented in `TRUST_BOUNDARIES.md`.

**Guidelines:**
- All `axiom` declarations → documented
- All `pragma opaque` → documented
- All crypto assumptions → documented with citations

**Enforcement:**
```bash
# CI job fails if undocumented axioms are introduced
./scripts/reconcile_trust_boundaries.sh
```

---

### 1.3 Proof Reuse Over Proof Duplication

**Principle:** Factor out common proof patterns into reusable lemmas.

**Example:**
```lean
-- DON'T: Prove the same step 100 times
theorem step_pc0_registration : step env frame0 cs ms = ... := by
  unfold step; simp [Instruction.immBorrowLoc]; rfl

theorem step_pc0_withdrawal : step env frame0 cs ms = ... := by
  unfold step; simp [Instruction.immBorrowLoc]; rfl
-- Duplicated proof!

-- DO: Prove once, reuse everywhere
theorem step_immBorrowLoc_frame {env frame cs ms} : 
    frame.code[frame.pc] = Instruction.immBorrowLoc idx →
    step env frame cs ms = .ok (frame with pc := frame.pc + 1) cs ms := by
  unfold step; simp; rfl

-- Now reuse:
theorem step_pc0_registration : step env frame0 cs ms = ... := by
  apply step_immBorrowLoc_frame; rfl

theorem step_pc0_withdrawal : step env frame0 cs ms = ... := by
  apply step_immBorrowLoc_frame; rfl
```

**Impact:** 10-20× reduction in proof size, 10-20× speedup.

---

## 2. Lean Coding Conventions

### 2.1 Naming Conventions

| Entity | Pattern | Example |
|---|---|---|
| Module file | `PascalCase.lean` | `EvalEquiv.lean`, `FunctionalSim.lean` |
| Theorem | `snake_case` | `eval_registration_eq_run`, `step_pc0_immBorrowLoc` |
| Definition | `camelCase` | `registrationState`, `normalizationOracle` |
| Type | `PascalCase` | `RegistrationNativeOracle`, `ExecResult` |
| Constant | `SCREAMING_SNAKE_CASE` | `MAX_CHUNKS`, `ETOKEN_IS_FROZEN` |

**Rationale:** Matches Lean 4 community conventions + mathlib.

---

### 2.2 File Organization

**Structure:**
```
Operation/
├── EvalEquiv.lean          -- PC-level bytecode proof
├── FunctionalSim.lean      -- High-level functional simulation
├── Phase6Composition.lean  -- Composition (eval ↔ functional sim)
├── Refinement.lean         -- (Optional) Additional refinement layers
└── EndToEnd.lean           -- (Optional) Full end-to-end theorem
```

**Each file should:**
- Start with imports
- Follow with a module docstring (`/-! ... -/`)
- Group related definitions/theorems
- End with the main theorem

**Example module docstring:**
```lean
/-!
# Normalization EvalEquiv Proof

Proves that the `verify_normalization_proof` bytecode is semantically equivalent
to the high-level functional simulation.

Main theorem: `eval_normalization_eq_run`

Build time: ~0.5s (as of 2026-04-22)
-/
```

---

### 2.3 Proof Structure

**Pattern:**
```lean
theorem descriptive_name
    (hypotheses : ...)
    : goal := by
  -- 1. Unfold definitions
  unfold def1 def2
  
  -- 2. Rewrite using lemmas
  rw [lemma1, lemma2, lemma3]
  
  -- 3. Case-split if needed
  cases h : expr
  case constructor1 => ...
  case constructor2 => ...
  
  -- 4. Simplify
  simp only [explicit, lemma, list]
  
  -- 5. Close
  rfl
```

**Guidelines:**
- **One tactic per line** (easier to debug)
- **Comment non-obvious steps**
- **Keep proofs short** (< 20 lines ideally; factor out if longer)

---

### 2.4 Irreducibility

**Rule:** Mark all state constructors `@[irreducible]`.

**Pattern:**
```lean
@[irreducible]
def operationState (pc : Nat) (...) : Frame :=
  { code := operationCode,
    pc := pc,
    locals := ...,
    localRefs := ... }

-- Expose projections as simp lemmas
@[simp]
theorem operationState_pc : (operationState pc ...).pc = pc := by
  unfold operationState; rfl

@[simp]
theorem operationState_code : (operationState pc ...).code = operationCode := by
  unfold operationState; rfl
```

**Impact:** 100× build time improvement in Phase 4 proofs.

---

## 3. MSL Specification Conventions

### 3.1 Always Use `pragma aborts_if_is_strict`

**Rule:** Every function spec must have `pragma aborts_if_is_strict` unless there's a documented reason not to.

**Pattern:**
```move
spec my_function(...) {
    pragma aborts_if_is_strict;
    
    aborts_if condition1 with ERROR_CODE_1;
    aborts_if condition2 with ERROR_CODE_2;
    
    ensures postcondition;
}
```

**Why:** Without it, the Move Prover allows unspecified aborts (unsound).

---

### 3.2 Abort Conditions in Code Order

**Rule:** List `aborts_if` clauses in the same order as they appear in the implementation.

**Example:**
```move
// Implementation:
fun my_function() {
    assert!(!frozen, ETOKEN_IS_FROZEN);       // Check 1
    assert!(proof_valid, EPROOF_FAILED);       // Check 2
    assert!(amount > 0, EAMOUNT_ZERO);         // Check 3
    ...
}

// Spec (same order):
spec my_function {
    pragma aborts_if_is_strict;
    
    aborts_if frozen with ETOKEN_IS_FROZEN;    // Check 1
    aborts_if !proof_valid with EPROOF_FAILED; // Check 2
    aborts_if amount == 0 with EAMOUNT_ZERO;   // Check 3
}
```

**Why:** Makes it easy to audit spec against code.

---

### 3.3 Use `old()` Explicitly

**Rule:** Always use `old()` for pre-state references, never rely on implicit capture.

**Pattern:**
```move
// DON'T (implicit):
spec withdraw {
    let sum_before = sum_balance(store.pending_balance);
    ensures sum_balance(store.pending_balance) == sum_before - amount;
    // sum_before captures post-state in some contexts (confusing)
}

// DO (explicit):
spec withdraw {
    ensures sum_balance(store.pending_balance) == 
            sum_balance(old(store.pending_balance)) - amount;
}
```

---

## 4. Performance Patterns

### 4.1 Never Use Bare `simp`

**Rule:** Always use `simp only [...]` with an explicit lemma list.

**Pattern:**
```lean
-- DON'T
theorem slow_proof : ... := by
  simp
  rfl

-- DO
theorem fast_proof : ... := by
  simp only [Frame.pc, Frame.locals, Option.get?]
  rfl
```

**Impact:** 5-10× build time improvement.

---

### 4.2 Avoid Bound Proofs in Statements

**Rule:** Use `Array.get?` in theorem statements, not `Array.get` with bound proofs.

**Pattern:**
```lean
-- DON'T
theorem with_bounds (h : 5 < frame.locals.size) :
    step env { frame with locals := frame.locals[5] } cs ms = ... := by
  -- Bound proof h is elaborated during statement parsing (slow)
  ...

-- DO
theorem with_option :
    frame.locals.get? 5 = some val →
    step env { frame with locals := val } cs ms = ... := by
  intro h_get
  -- Bound proof is computed inside the proof, not during elaboration
  ...
```

**Impact:** 50× statement elaboration speedup.

---

### 4.3 Batch Independent Rewrites

**Rule:** Group `rw` calls when rewriting independent subexpressions.

**Pattern:**
```lean
-- DON'T (sequential, slow)
theorem slow : ... := by
  rw [lemma1]
  rw [lemma2]
  rw [lemma3]
  rfl

-- DO (batched, fast)
theorem fast : ... := by
  rw [lemma1, lemma2, lemma3]
  rfl
```

**Impact:** 2-3× speedup for long rewrite chains.

---

## 5. Testing Strategies

### 5.1 Test Pyramid

**Structure:**
```
         /\
        /E2E\        Few, slow, high-value (difftest full corpus)
       /------\
      /Integration\  Medium count, medium speed (verify-ca.sh per op)
     /------------\
    /  Unit Tests  \ Many, fast, focused (individual theorems, VCs)
   /----------------\
```

**Guidelines:**
- **Unit tests:** Every theorem, every VC, every difftest case
- **Integration tests:** Every operation (all three stacks together)
- **E2E tests:** Full corpus (weekly, not on every commit)

---

### 5.2 Red-Green-Refactor for Proofs

**Pattern:**
1. **Red:** Write the theorem statement with `sorry`
2. **Green:** Prove it (any way that works)
3. **Refactor:** Optimize for build time and readability

**Example:**
```lean
-- Step 1 (Red): State the theorem
theorem step_pc0 : step env frame cs ms = ... := by sorry

-- Step 2 (Green): Prove it
theorem step_pc0 : step env frame cs ms = ... := by
  unfold step
  simp [Instruction.immBorrowLoc, Frame.pc, ...]
  rfl

-- Step 3 (Refactor): Optimize
theorem step_pc0 : step env frame cs ms = ... := by
  rw [step_immBorrowLoc_frame]  -- Use step lemma library
  rfl
```

---

### 5.3 Golden Tests for Difftest

**Rule:** Every difftest JSON is a golden test (expected output is authoritative).

**Workflow:**
1. Generate golden output from VM execution
2. Commit JSON to corpus
3. CI fails if VM behavior changes

**Updating goldens:**
```bash
# Regenerate golden output (after intentional VM change)
./scripts/manage_difftest_corpus.sh regenerate <operation>

# Review diff carefully
git diff examples/difftest/<operation>*.json

# Commit if correct
git add examples/difftest/
git commit -m "Update difftest goldens for <change>"
```

---

## 6. Code Review Guidelines

### 6.1 Review Checklist

**For all PRs:**
- [ ] CI is green (all three stacks pass)
- [ ] No `sorry` in Lean proofs
- [ ] No unexpected axioms (check `TRUST_BOUNDARIES.md`)
- [ ] Performance within budget (per-file < 3 min)
- [ ] Tests added/updated (unit + integration)
- [ ] Documentation updated (`CLAIMS.md`, `TRUST_BOUNDARIES.md`)

**For Lean proofs:**
- [ ] Uses `@[irreducible]` for state constructors
- [ ] Uses `simp only [...]` not bare `simp`
- [ ] Step lemmas reused (not duplicated)
- [ ] Proof is readable (comments on non-obvious steps)

**For MSL specs:**
- [ ] `pragma aborts_if_is_strict` present
- [ ] All abort conditions enumerated
- [ ] Abort codes match implementation
- [ ] Uses `old()` explicitly for pre-state

**For difftest:**
- [ ] Test cases cover happy path + all error paths
- [ ] JSON validates against schema
- [ ] Expected output matches VM execution

---

### 6.2 Review Priorities

**High priority (block merge if missing):**
1. Correctness (are the theorems/specs actually true?)
2. Completeness (are all abort conditions covered?)
3. Security (are there injection vulnerabilities, overflow bugs?)

**Medium priority (flag but don't block):**
4. Performance (is build time acceptable?)
5. Readability (are proofs easy to understand?)

**Low priority (mention in comments):**
6. Style (naming, formatting)
7. Documentation (inline comments, examples)

---

## 7. Git Workflow

### 7.1 Branch Naming

**Pattern:** `<type>/<scope>-<short-description>`

**Examples:**
- `feat/ca-rotation-operation`
- `fix/msl-balance-conservation-spec`
- `perf/lean-build-time-optimization`
- `docs/phase6-completion-guide`

---

### 7.2 Commit Messages

**Pattern:**
```
<type>(<scope>): <subject>

<body>

<footer>
```

**Example:**
```
feat(ca): add rotation operation Lean EvalEquiv proof

Implements Phase 4 proof for verify_rotation_proof bytecode:
- 15 PC step lemmas
- Top-level eval_rotation_eq_run theorem
- Zero new axioms
- Builds in 0.5s (under 3 min budget)

Related: #456
```

**Types:**
- `feat` — new feature (new operation, new automation)
- `fix` — bug fix (wrong spec, incorrect proof)
- `perf` — performance improvement (build time, VC time)
- `docs` — documentation only
- `test` — add/update tests
- `refactor` — code restructuring (no behavior change)
- `chore` — maintenance (dependency updates, CI config)

---

### 7.3 When to Squash vs Preserve Commits

**Preserve commits when:**
- Each commit is a logical unit (e.g., "add PC 0-5", "add PC 6-10", "add PC 11-15")
- History tells a story (useful for future debugging)

**Squash when:**
- Commits are "fix typo", "WIP", "oops forgot file"
- Too many commits make history noisy

**Default:** Squash on merge via GitHub PR.

---

## 8. Common Anti-Patterns to Avoid

### 8.1 Premature Optimization

**Anti-pattern:**
```lean
-- Adding complex optimizations before measuring
def optimized_state (pc : Nat) : Frame :=
  if pc < 10 then
    fastPath pc
  else if pc < 20 then
    mediumPath pc
  else
    slowPath pc
-- All this complexity before profiling shows it's needed
```

**Correct:**
```lean
-- Start simple
@[irreducible]
def state (pc : Nat) : Frame := ...

-- Profile
-- $ ./scripts/profile_lean_build.sh

-- Optimize ONLY if it exceeds budget
```

---

### 8.2 Overspecification in MSL

**Anti-pattern:**
```move
spec my_function {
    // Specifying implementation details
    ensures store.pending_balance[0] == old(store.pending_balance[0]) + amount;
    ensures store.pending_balance[1] == old(store.pending_balance[1]);
    // Brittle! Breaks if implementation changes chunk ordering
}
```

**Correct:**
```move
spec my_function {
    // Specify observable behavior only
    ensures sum_balance(store.pending_balance) == 
            sum_balance(old(store.pending_balance)) + amount;
}
```

---

### 8.3 Duplicating Difftest Cases

**Anti-pattern:**
```
examples/difftest/
  transfer_happy_path_001.json
  transfer_happy_path_002.json
  transfer_happy_path_003.json
// All three test the exact same thing
```

**Correct:**
```
examples/difftest/
  transfer_happy_path.json
  transfer_sender_frozen.json
  transfer_proof_failed.json
// Each tests a different scenario
```

---

## 9. Onboarding New Team Members

### 9.1 Day 1: Environment Setup

**Tasks:**
1. Clone repo
2. Install Lean 4, Move Prover, difftest runner
3. Run `./audit/verify-ca.sh --op normalization` (should pass)

**Time estimate:** 2-4 hours.

---

### 9.2 Week 1: Study Existing Proofs

**Tasks:**
1. Read `CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md`
2. Study Normalization proof (simplest operation)
3. Read `LEAN_PROOF_TACTICS_REFERENCE.md`
4. Review MSL specs in `confidential_asset.spec.move`

**Goal:** Understand the three-stack architecture.

---

### 9.3 Week 2: Small Contribution

**Tasks:**
1. Pick a small bug fix or documentation improvement
2. Submit a PR
3. Go through code review

**Goal:** Get familiar with the workflow.

---

### 9.4 Month 1: Implement a New Operation (Guided)

**Tasks:**
1. Pair with senior engineer on a new operation
2. Follow `COMPLETE_VERIFICATION_WORKFLOW.md`
3. Complete all phases (A-H)

**Goal:** End-to-end experience.

---

## 10. Lessons Learned

### 10.1 From Registration Rebuild (Phase 1)

**Lesson:** Symbolic state + `@[irreducible]` is 100× faster than chained state updates.

**Before:**
```lean
def statePC0 : Frame := initialFrame
def statePC1 : Frame := { statePC0 with pc := 1, locals := ... }
def statePC2 : Frame := { statePC1 with pc := 2, locals := ... }
-- 25.6M heartbeats, 30+ minutes to build
```

**After:**
```lean
@[irreducible]
def state (pc : Nat) : Frame := { code := ..., pc := pc, locals := ... }
-- 50K heartbeats, 3 seconds to build
```

**Takeaway:** Architecture matters more than tactics.

---

### 10.2 From Move Prover Integration (Phase 0)

**Lesson:** Z3 version matters. Homebrew's Z3 4.14.x is incompatible.

**Problem:** `movement move prove` fails with "expected version ≤ 4.11.2".

**Solution:** Always use `movement update prover-dependencies`.

**Takeaway:** Pin all tool versions in `toolchain.lock` and Docker image.

---

### 10.3 From Difftest Corpus Design

**Lesson:** Test both happy path AND error paths. One test per abort condition minimum.

**Before:** Only happy-path tests → missed abort condition bugs.

**After:** Every abort condition has ≥1 test case → caught 5 bugs before production.

**Takeaway:** Error paths are first-class citizens.

---

### 10.4 From Performance Optimization

**Lesson:** Measure before optimizing. "Obvious" optimizations often don't help.

**Example:** Tried to cache step results → no speedup (the compiler already does this).

**Takeaway:** Profile with `./scripts/profile_lean_build.sh` before changing anything.

---

## Summary

**Core principles:**
1. **Separation of concerns** — Lean, MSL, difftest each have specific roles
2. **Explicit trust boundaries** — document all axioms
3. **Proof reuse** — factor out common patterns
4. **Performance by design** — `@[irreducible]`, `simp only`, `Array.get?`
5. **Test all paths** — happy + error paths
6. **Measure, then optimize** — profile before changing

**Daily habits:**
- Run `lake build` frequently (catch errors early)
- Use `simp only [...]` always (never bare `simp`)
- Mark state constructors `@[irreducible]`
- Test locally before pushing (all three stacks)

**Resources:**
- This guide (best practices)
- `COMPLETE_VERIFICATION_WORKFLOW.md` (end-to-end workflow)
- `ERROR_DIAGNOSIS_GUIDE.md` (troubleshooting)
- Team Slack `#formal-verification`

**Next steps:** Apply these patterns to your next PR. When in doubt, follow existing examples (Normalization, Withdrawal, Transfer).
