# Verification Engineer Onboarding Guide

**Purpose:** Fast-track onboarding for new formal verification engineers  
**Target:** Engineers joining the CA formal verification team  
**Timeline:** 1-2 weeks from zero to productive  
**Prerequisites:** Basic programming experience, willingness to learn Lean 4

---

## Welcome!

Welcome to the Confidential Assets formal verification team! This guide will take you from zero formal verification experience to being productive on the team in 1-2 weeks.

**What you'll learn:**
- Week 1 (40 hours): Lean 4 basics, CA architecture, existing proofs
- Week 2 (40 hours): Hands-on proof writing, debugging, contribution workflow

**Learning philosophy:**
- ✅ Learn by doing (80% hands-on, 20% theory)
- ✅ Incremental complexity (start simple, build up)
- ✅ Pair programming encouraged (learn from team members)

---

## Table of Contents

1. [Day 1: Environment Setup](#day-1-environment-setup)
2. [Day 2: Lean 4 Crash Course](#day-2-lean-4-crash-course)
3. [Day 3: CA Architecture Deep Dive](#day-3-ca-architecture-deep-dive)
4. [Day 4: Reading Existing Proofs](#day-4-reading-existing-proofs)
5. [Day 5: First Proof (Guided)](#day-5-first-proof-guided)
6. [Week 2: Advanced Topics](#week-2-advanced-topics)
7. [Resources and References](#resources-and-references)

---

## Day 1: Environment Setup

**Goal:** Get a working development environment (4-6 hours)

### Step 1.1: Install Prerequisites (30 minutes)

**On macOS:**
```bash
# Install Homebrew (if not already installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install git
brew install git

# Install VS Code
brew install --cask visual-studio-code

# Install jq (for JSON processing)
brew install jq
```

**On Linux:**
```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install -y git curl build-essential jq

# Install VS Code
sudo snap install --classic code
```

---

### Step 1.2: Install Lean 4 (15 minutes)

```bash
# Install elan (Lean version manager)
curl https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh -sSf | sh -s -- -y

# Add elan to PATH
echo 'export PATH="$HOME/.elan/bin:$PATH"' >> ~/.zshrc  # or ~/.bashrc
source ~/.zshrc  # or ~/.bashrc

# Verify installation
lean --version
# Expected: leanprover/lean4:v4.X.Y

lake --version
# Expected: Lake version 4.X.Y
```

---

### Step 1.3: Install VS Code Extensions (10 minutes)

```bash
# Install Lean 4 extension
code --install-extension leanprover.lean4

# Install helpful extensions
code --install-extension GitHub.copilot  # Optional but recommended
code --install-extension eamodio.gitlens
code --install-extension streetsidesoftware.code-spell-checker
```

**Configure VS Code settings:**

File → Preferences → Settings (or Cmd+, on macOS)

```json
{
  "lean4.elaborationDelay": 500,
  "lean4.serverLogging.enabled": false,
  "editor.formatOnSave": true,
  "editor.rulers": [100],
  "files.trimTrailingWhitespace": true
}
```

---

### Step 1.4: Clone Repository (10 minutes)

```bash
# Clone the repository
git clone https://github.com/movement-labs/aptos-core.git
cd aptos-core/aptos-move/framework/formal

# Checkout the formal verification branch
git checkout lean-fv

# Verify directory structure
ls -la
# Should see: lean/ (Lean 4 proofs), audit/ (verification scripts), scripts/ (automation)
```

---

### Step 1.5: Build Lean Proofs (2-3 hours first time)

```bash
cd lean

# Update dependencies (first time takes longer)
lake update

# Build all proofs
lake build MovementFormal.Experimental.ConfidentialAsset

# Expected output (after 3-5 minutes):
# [280/280] Building MovementFormal.Experimental.ConfidentialAsset
# Build succeeded.
```

**Note:** First build downloads dependencies (~2GB). Subsequent builds are much faster (~4s).

---

### Step 1.6: Verify Setup (15 minutes)

```bash
# Run verification suite
cd ..
./audit/verify-ca.sh --lean

# Expected output:
# ✅ Lean verification: PASS
# Build time: ~4s
# Axioms: 23 permanent, 0 temporary
```

**If tests pass:** ✅ Setup complete!

**If tests fail:** See [Troubleshooting](#troubleshooting) section below.

---

### Step 1.7: Open Project in VS Code (15 minutes)

```bash
# Open project
code /path/to/aptos-core/aptos-move/framework/formal/lean
```

**Navigate to a proof file:**
```
MovementFormal/Experimental/ConfidentialAsset/Normalization/EvalEquiv.lean
```

**Verify LSP is working:**
- Hover over `theorem` → should see type information
- Click on function name → should jump to definition
- Save file → should see live error checking

**If LSP not working:** Restart Lean server (Cmd+Shift+P → "Lean 4: Restart Server")

---

## Day 2: Lean 4 Crash Course

**Goal:** Learn enough Lean to read and write basic proofs (6-8 hours)

### Step 2.1: Interactive Tutorial (2 hours)

**Complete the Natural Number Game:**
https://adam.math.hhu.de/#/g/leanprover-community/nng4

**Focus on these worlds:**
- ✅ Tutorial World (basic tactics)
- ✅ Addition World (`rw`, `rfl`)
- ✅ Multiplication World (`induction`)

**Skip for now:**
- ⏭️ Advanced Worlds (not needed for CA verification)

**What you'll learn:**
- `rfl` (reflexivity)
- `rw` (rewrite)
- `exact` (exact proof)
- `have` (introduce intermediate steps)

---

### Step 2.2: Lean 4 Syntax Primer (1 hour)

**Open:** `lean/Examples/LearnBasics.lean` (create if doesn't exist)

```lean
import Mathlib.Tactic

/-!
# Lean 4 Basics for CA Verification

Essential syntax and tactics.
-/

-- Example 1: Reflexivity
example : 5 = 5 := by
  rfl  -- Prove equality by computation

-- Example 2: Rewrite
example (x y : Nat) (h : x = y) : x + 1 = y + 1 := by
  rw [h]  -- Replace x with y
  rfl

-- Example 3: Have (intermediate step)
example (x y z : Nat) (h1 : x = y) (h2 : y = z) : x = z := by
  have h3 : x = y := h1
  rw [h3, h2]
  rfl

-- Example 4: Cases (split on type)
example (n : Nat) : n = 0 ∨ n > 0 := by
  cases n
  case zero =>
    left
    rfl
  case succ n' =>
    right
    omega  -- Arithmetic tactic

-- Example 5: Simp (simplification)
example (x : Nat) : x + 0 = x := by
  simp only [Nat.add_zero]  -- Targeted simp

-- Example 6: Apply (backward reasoning)
example (h : ∀ x, P x → Q x) (hp : P 5) : Q 5 := by
  apply h
  exact hp
```

**Exercise:** Type these examples yourself, observe LSP feedback.

---

### Step 2.3: Read Lean 4 Documentation (1 hour)

**Essential docs:**
- [Lean 4 Manual](https://lean-lang.org/lean4/doc/): Skim chapters 1-3
- [Theorem Proving in Lean 4](https://leanprover.github.io/theorem_proving_in_lean4/): Read chapters 1-5

**Focus on:**
- Inductive types (Chapter 3)
- Tactics (Chapter 5)
- Structures (Chapter 6)

**Skip:**
- Type classes (advanced, not needed yet)
- Metaprogramming (advanced)

---

### Step 2.4: CA-Specific Tactics (2 hours)

**Read:** `LEAN_PROOF_TACTICS_REFERENCE.md`

**Practice exercises:** `lean/Examples/CATacticPractice.lean`

```lean
import MovementFormal.MoveModel.Basic

/-!
# CA Tactic Practice

Common patterns in CA proofs.
-/

-- Exercise 1: Unfold irreducible state
@[irreducible]
def myState (pc : Nat) : Frame :=
  { code := #[Instruction.ret],
    pc := pc,
    locals := #[],
    localRefs := #[] }

theorem state_eq : myState 0 = myState 0 := by
  rfl  -- Works: both sides reduce to same @[irreducible] constructor

-- Exercise 2: Step lemma pattern
theorem step_example :
    step env (myState 0) cs ms = .returned [] ms := by
  rw [myState]  -- Unfold state
  rw [step_ret]  -- Apply step lemma
  rfl  -- Close

-- Exercise 3: Array access
example (arr : Array Nat) (h : arr.size > 0) : arr.get? 0 = some (arr.get ⟨0, h⟩) := by
  simp only [Array.get?]
  rfl

-- More exercises in file...
```

**Work through all exercises:** Type them, build, debug if needed.

---

### Step 2.5: Mini Quiz (30 minutes)

**Complete these without looking at answers:**

1. What tactic proves `x = x`?
2. What tactic replaces `x` with `y` given `h : x = y`?
3. What does `@[irreducible]` do?
4. What's the difference between `simp` and `simp only [...]`?
5. When should you use `exact` vs `apply`?

**Answers:** See end of this guide.

---

## Day 3: CA Architecture Deep Dive

**Goal:** Understand the CA formal verification architecture (6-8 hours)

### Step 3.1: Read Core Documentation (2 hours)

**Read in this order:**

1. **CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md** (skim, 30 min)
   - Understand 8 phases
   - Note current status (Phase 1 95%, Phase 4 100%, etc.)

2. **VERIFICATION_PROGRESS_SUMMARY.md** (read, 30 min)
   - See what's done, what's remaining
   - Understand metrics (build times, axiom counts)

3. **PROOF_FLOW.md** (read, 1 hour)
   - Three-stack architecture (Lean + MSL + Difftest)
   - How stacks relate to each other
   - Verification levels

---

### Step 3.2: Understand Operations (1 hour)

**Read operation overview in:**
- `NORMALIZATION_COMPLETE_IMPLEMENTATION.md` (simplest, start here)
- `WITHDRAWAL_COMPLETE_IMPLEMENTATION.md` (medium complexity)
- `TRANSFER_COMPLETE_IMPLEMENTATION.md` (high complexity)

**For each operation, understand:**
- What does it do? (high-level description)
- What are the inputs/outputs?
- What proofs do we verify? (balance conservation, crypto soundness, etc.)

---

### Step 3.3: Trace Code Flow (2 hours)

**Pick Normalization (simplest operation):**

**Step 1: Read Move code**
```bash
# Open Move implementation
code aptos-move/framework/aptos-experimental/sources/confidential_asset/confidential_asset.move

# Find normalize_internal function (Cmd+F → "normalize_internal")
# Read the code, understand the logic
```

**Step 2: Read MSL spec**
```bash
# Open MSL spec
code aptos-move/framework/aptos-experimental/sources/confidential_asset/confidential_asset.spec.move

# Find spec normalize_internal block
# Compare with Move implementation
```

**Step 3: Read Lean proof**
```bash
# Open Lean proof
code lean/MovementFormal/Experimental/ConfidentialAsset/Normalization/EvalEquiv.lean

# Read from top to bottom:
# 1. Bytecode definition
# 2. Symbolic state definitions
# 3. Step lemmas
# 4. Chaining theorem
```

**Step 4: Read Difftest**
```bash
# Open difftest case
code difftest/confidential_asset/normalization_happy_path.json

# See inputs, expected outputs, Lean alignment
```

**Make a diagram:** Draw boxes for Move → MSL → Lean → Difftest, show how they connect.

---

### Step 3.4: Explore Codebase Structure (1 hour)

```bash
cd lean/MovementFormal

# Explore directory tree
tree -L 3

# Key directories:
# - MoveModel/: Move VM model (instructions, step semantics)
# - MoveModel/StepLemmas/: Reusable step lemma library
# - MoveModel/Native/: Native function oracles
# - Experimental/ConfidentialAsset/: CA operation proofs
#   - Normalization/: Simplest operation
#   - Transfer/: Most complex operation
#   - Registration/: Largest operation (55 PCs)
```

**Create a mental map:** "If I need to find X, I look in Y directory."

---

## Day 4: Reading Existing Proofs

**Goal:** Understand how to read and navigate proofs (6-8 hours)

### Step 4.1: Read Normalization Proof (3 hours)

**File:** `lean/MovementFormal/Experimental/ConfidentialAsset/Normalization/EvalEquiv.lean`

**Reading strategy:**

**Pass 1 (30 min): Skim structure**
- How many PCs? (14)
- How many theorems? (17)
- How many axioms? (check with `#print axioms`)
- How is the file organized? (sections, comments)

**Pass 2 (1 hour): Read bytecode**
- What does each PC do?
- Identify branch points
- Identify native oracle calls

**Pass 3 (1.5 hours): Read one section in detail**
Pick PCs 0-3 (frozen check):
1. Read state definitions for PC 0, 1, 2, 3
2. Read step lemmas for PC 0→1, 1→2, 2→3
3. Trace the proof: what hypotheses are needed?
4. Why does each `rfl` work?

**Make notes:** Annotate the code with comments explaining what's happening.

---

### Step 4.2: Compare with Worked Example (2 hours)

**Open two files side-by-side:**
- Left: `NORMALIZATION_COMPLETE_IMPLEMENTATION.md`
- Right: `lean/MovementFormal/Experimental/ConfidentialAsset/Normalization/EvalEquiv.lean`

**For each section:**
1. Read explanation in markdown
2. Find corresponding code in Lean
3. Verify they match

**Focus on:**
- State definitions (`@[irreducible]` pattern)
- Step lemmas (one per PC)
- Chaining (combining step lemmas)

---

### Step 4.3: Debugging Exercise (2 hours)

**Break a proof intentionally, then fix it:**

```bash
# Make a copy
cp lean/MovementFormal/Experimental/ConfidentialAsset/Normalization/EvalEquiv.lean \
   lean/Examples/NormalizationBroken.lean

# Edit NormalizationBroken.lean
```

**Break 1: Remove `@[irreducible]`**
```lean
-- Before:
@[irreducible]
def normalizationState ...

-- After (remove @[irreducible]):
def normalizationState ...
```

**Rebuild:** Observe build time increases dramatically (0.5s → 10s+)

**Fix:** Add `@[irreducible]` back

---

**Break 2: Wrong PC in state**
```lean
-- Before:
def normalizationState_PC1 ... :=
  { code := ...,
    pc := 1,  -- Correct
    ... }

-- After:
def normalizationState_PC1 ... :=
  { code := ...,
    pc := 2,  -- Wrong!
    ... }
```

**Rebuild:** Observe error messages

**Fix:** Correct PC back to 1

**Lesson:** Intentional errors teach you what error messages look like.

---

## Day 5: First Proof (Guided)

**Goal:** Write your first proof from scratch (6-8 hours)

### Step 5.1: Choose a Task (30 min)

**Good first tasks:**
1. **Add a new step lemma** to an existing operation
2. **Fix a `sorry` placeholder** in Phase 1 singleton-some branch
3. **Write a helper lemma** for step lemma library

**Recommended:** Fix a `sorry` in normalization (easiest).

**Find a sorry:**
```bash
cd lean
grep -r "sorry" MovementFormal/Experimental/ConfidentialAsset/Normalization/
```

---

### Step 5.2: Understand the Goal (1 hour)

**Read the theorem with `sorry`:**

```lean
theorem step_pc5_example : ... := by
  sorry  -- TODO: Complete this proof
```

**Questions to answer:**
1. What does this theorem state? (in plain English)
2. What are the inputs? (hypotheses)
3. What is the goal? (conclusion)
4. What step lemmas exist that might help?

**Write down answers** before starting proof.

---

### Step 5.3: Attempt the Proof (2-3 hours)

**Strategy:**

**Step 1: Skeleton**
```lean
theorem step_pc5_example : ... := by
  -- Unfold states
  rw [stateAtPC5]
  rw [stateAtPC6]
  
  -- Apply step lemma
  rw [step_<instruction>]
  
  -- Simplify
  simp only [Array.get?]
  
  -- Close
  sorry  -- Still doesn't work, but closer
```

**Step 2: Debug**
- Hover over goal after each line
- See what's left to prove
- Add more tactics as needed

**Step 3: Ask for help** (after 30 min of being stuck)
- Pair program with team member
- Ask in team chat: "I'm trying to prove X, stuck on Y"

**Step 4: Complete**
- Remove `sorry`
- Build successfully
- Celebrate! 🎉

---

### Step 5.4: Code Review (1 hour)

**Self-review checklist:**
- [ ] Proof builds without errors
- [ ] No `sorry` remaining
- [ ] Comments explain non-obvious steps
- [ ] Follows style guide (see BEST_PRACTICES_AND_PATTERNS.md)

**Submit for team review:**
```bash
git checkout -b first-proof-<your-name>
git add <files>
git commit -m "feat: complete proof for PC 5 in normalization"
git push origin first-proof-<your-name>

# Create PR
gh pr create --title "First proof: Normalization PC 5" --body "Completes TODO at line X"
```

---

## Week 2: Advanced Topics

**Goal:** Become independently productive (40 hours)

### Day 6: Phase 1 Singleton-Some Branch (8 hours)

**Read:** `PHASE_1_ACCELERATED_COMPLETION_GUIDE.md`

**Task:** Complete 1-2 step lemmas for singleton-some branch

**Estimated:** 2-4 hours per lemma

**Deliverable:** 2-3 step lemmas with 0 temporary axioms

---

### Day 7: Performance Optimization (8 hours)

**Read:** `PERFORMANCE_TUNING_DEEP_DIVE.md`

**Task:** Profile a slow proof, apply optimizations

**Steps:**
1. Find slow theorem (> 1s build time)
2. Profile with `./scripts/profile_lean_build.sh`
3. Apply optimizations (`@[irreducible]`, `simp only`, etc.)
4. Re-profile, validate improvement

**Deliverable:** 2× speedup on a slow theorem

---

### Day 8: Debugging Practice (8 hours)

**Read:** `ADVANCED_DEBUGGING_GUIDE.md`

**Task:** Debug 5 intentionally broken proofs

**Scenarios:**
1. Type mismatch error
2. `rfl` fails (terms don't reduce)
3. `omega` can't solve arithmetic
4. `cases` produces no goals
5. Performance regression (> 10× slower)

**Deliverable:** Fix all 5 proofs, document lessons learned

---

### Day 9: Phase 6 Composition Proofs (8 hours)

**Read:** `PHASE_6_PC_CHAINING_IMPLEMENTATION_GUIDE.md`

**Task:** Write 1 shape lemma for Normalization Phase 6

**Estimated:** 3-5 hours

**Deliverable:** 1 shape lemma (e.g., `normalization_shape_verifyFailed`)

---

### Day 10: Independent Contribution (8 hours)

**Goal:** Pick a task from backlog, complete end-to-end

**Example tasks:**
1. Complete Phase 1 singleton-some branch (200-300 lines)
2. Add difftest test case for edge case scenario
3. Write automation script for new workflow
4. Improve documentation (add worked example, fix stale content)

**Deliverable:** Merged PR with substantial contribution

---

## Resources and References

### Essential Reading

**Week 1:**
- ✅ VERIFICATION_PROGRESS_SUMMARY.md
- ✅ NORMALIZATION_COMPLETE_IMPLEMENTATION.md
- ✅ LEAN_PROOF_TACTICS_REFERENCE.md

**Week 2:**
- ✅ PHASE_1_ACCELERATED_COMPLETION_GUIDE.md
- ✅ ADVANCED_DEBUGGING_GUIDE.md
- ✅ PERFORMANCE_TUNING_DEEP_DIVE.md

**Reference:**
- ✅ ERROR_DIAGNOSIS_GUIDE.md (when stuck)
- ✅ BEST_PRACTICES_AND_PATTERNS.md (before submitting PR)
- ✅ TROUBLESHOOTING_GUIDE.md (when something breaks)

---

### External Resources

**Lean 4:**
- [Lean 4 Manual](https://lean-lang.org/lean4/doc/)
- [Theorem Proving in Lean 4](https://leanprover.github.io/theorem_proving_in_lean4/)
- [Mathlib4 Docs](https://leanprover-community.github.io/mathlib4_docs/)
- [Lean Zulip Chat](https://leanprover.zulipchat.com/)

**Formal Verification:**
- [Software Foundations](https://softwarefoundations.cis.upenn.edu/) (Coq, but concepts transfer)
- [Concrete Semantics](http://concrete-semantics.org/) (Isabelle, theory background)

---

### Team Resources

**Team chat:** #formal-verification on Slack

**Office hours:** Tuesdays 2-3pm PT (Zoom link in Slack)

**Weekly sync:** Fridays 10-11am PT

**Pair programming:** Schedule with any team member via Slack

---

## Troubleshooting

### Issue: Lean 4 extension not working in VS Code

**Symptom:** No syntax highlighting, no LSP feedback

**Solution:**
1. Restart VS Code
2. Run: Cmd+Shift+P → "Lean 4: Restart Server"
3. Check elan is in PATH: `which lean` should output a path
4. Reinstall extension if needed

---

### Issue: `lake build` fails with dependency errors

**Symptom:**
```
error: package 'Mathlib' not found
```

**Solution:**
```bash
cd lean
lake clean
lake update
lake build
```

---

### Issue: Build extremely slow (> 10 minutes)

**Symptom:** Stuck on building for hours

**Solution:**
```bash
# Kill build
Ctrl+C

# Check for stale build cache
rm -rf lean/build
rm -rf lean/.lake

# Rebuild from scratch
lake build
```

---

## Mini Quiz Answers

1. **What tactic proves `x = x`?**  
   `rfl` (reflexivity)

2. **What tactic replaces `x` with `y` given `h : x = y`?**  
   `rw [h]` (rewrite)

3. **What does `@[irreducible]` do?**  
   Prevents Lean from automatically unfolding the definition, improving performance

4. **What's the difference between `simp` and `simp only [...]`?**  
   `simp` uses all registered simp lemmas (slow), `simp only [...]` uses only specified lemmas (fast)

5. **When should you use `exact` vs `apply`?**  
   Use `exact` when you have the exact proof term. Use `apply` when you have a function that produces the proof (and Lean will create subgoals for function arguments)

---

## Next Steps After Onboarding

**After Week 2, you should be able to:**
- ✅ Read and understand existing proofs
- ✅ Write new step lemmas
- ✅ Debug proof failures
- ✅ Optimize slow proofs
- ✅ Contribute independently to the verification effort

**Career growth paths:**
1. **Phase lead:** Own completion of Phase 1, 6, or 8
2. **Automation:** Build tools to accelerate verification
3. **Research:** Explore axiom reduction strategies
4. **Mentoring:** Onboard future team members

**Welcome to the team! 🚀**
