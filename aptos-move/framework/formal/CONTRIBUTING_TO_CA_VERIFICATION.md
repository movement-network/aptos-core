# Contributing to CA Formal Verification

**Welcome!** This guide helps you make effective contributions to the Confidential Assets formal verification effort.

**Target audience:** Engineers, researchers, and students who want to contribute proofs, specs, documentation, or infrastructure.

---

## Table of Contents

1. [Getting Started](#1-getting-started)
2. [Contribution Types](#2-contribution-types)
3. [Development Workflow](#3-development-workflow)
4. [Code Standards](#4-code-standards)
5. [Review Process](#5-review-process)
6. [Recognition & Credit](#6-recognition--credit)

---

## 1. Getting Started

### 1.1 First Steps

**Before your first contribution:**

1. **Set up your environment** (2 hours):
   - Follow `DEVELOPER_ONBOARDING_GUIDE.md` end-to-end
   - Verify all three stacks work: Lean, Move Prover, difftest

2. **Read core documentation** (1 hour):
   - `README.md` — High-level overview
   - `CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md` — Master plan
   - `PROOF_PATTERNS_WORKED_EXAMPLE.md` — Learn by example

3. **Join communication channels**:
   - GitHub Discussions: Ask questions, share progress
   - Slack: #ca-formal-verification (real-time discussion)

4. **Pick your first issue** (see §2):
   - Filter by `good-first-issue` label
   - Look for "Starter Task" in PHASE_*_STATUS.md files

### 1.2 Finding Work

**Where to look for open work:**

```bash
# Check phase status files
cat PHASE_1_STATUS.md | grep "☐"  # Pending tasks
cat PHASE_6_PROGRESS_SUMMARY.md | grep "TODO"

# Generate test coverage gaps
./scripts/generate_test_matrix.sh --gaps-only

# Check GitHub Issues
# https://github.com/movementlabsxyz/aptos-core/issues?q=is:issue+is:open+label:ca-verification
```

**Priority order:**
1. **Critical path** (Phase 1 singleton branch, Phase 6 composition)
2. **Coverage gaps** (missing difftest cases, error paths)
3. **Documentation** (examples, guides, API docs)
4. **Infrastructure** (automation, CI improvements)

---

## 2. Contribution Types

### 2.1 Lean Proofs (High Impact, High Skill)

**What:** Theorem proving in Lean 4 for bytecode-level verification.

**Where:**
- **Phase 1:** Registration singleton branch (~50 PCs, 500-700 lines)
- **Phase 6:** Composition theorems (4 operations × 200-450 lines each)

**Prerequisites:**
- Lean 4 experience (or willingness to learn, ~1 week ramp-up)
- Understanding of MoveVM bytecode
- Familiarity with proof patterns (read `PROOF_PATTERNS_WORKED_EXAMPLE.md`)

**Starter tasks:**
- Prove 5-10 PCs in Phase 1 singleton branch (using `PHASE_1_SINGLETON_BRANCH_STARTER_KIT.md`)
- Prove one error-path sub-lemma in Phase 6

**Typical PR size:** 100-300 lines, 1-3 days of work.

**Review time:** 2-4 days (requires Lean expert review).

---

### 2.2 MSL Specs (Medium Impact, Medium Skill)

**What:** Move Specification Language specs for Move Prover verification.

**Where:**
- **Phase 2/3/5:** MSL specs for CA modules (currently blocked on ristretto255, but specs can be written)

**Prerequisites:**
- Move language experience
- Understanding of MSL syntax (read `MSL_SPEC_PATTERN_LIBRARY.md`)
- Familiarity with Hoare logic (optional but helpful)

**Starter tasks:**
- Strengthen one `ensures` clause (add missing postcondition)
- Add one `aborts_if` clause (document error path)
- Write spec for a new helper function

**Typical PR size:** 50-150 lines, 0.5-1 day of work.

**Review time:** 1-2 days.

---

### 2.3 Difftest Cases (Low Barrier, High Value)

**What:** Add VM↔Lean differential test corpus rows.

**Where:**
- Coverage gaps identified by `./scripts/generate_test_matrix.sh --gaps-only`

**Prerequisites:**
- Basic Rust (for oracle generation)
- Basic Lean (for RunnerFuncMappingAux.lean)
- Understanding of Move VM execution

**Starter tasks:**
- Add one error-path test case (frozen account, invalid proof, etc.)
- Add one edge-case test (zero amount, max balance, self-transfer)

**Typical PR size:** 30-80 lines (Rust + Lean + inventory update), 1-2 hours of work.

**Review time:** 1 day.

**Instructions:** Follow `DEVELOPER_ONBOARDING_GUIDE.md` §3.2 (walkthrough).

---

### 2.4 Documentation (Low Barrier, Medium Value)

**What:** Improve guides, examples, API docs.

**Where:**
- Missing worked examples (Withdrawal/Rotation operations)
- API documentation (Lean modules, MSL spec funs)
- Troubleshooting guides

**Prerequisites:**
- Good technical writing
- Understanding of target audience

**Starter tasks:**
- Proofread and improve one guide
- Add missing examples to pattern library
- Document one common error and fix

**Typical PR size:** 100-500 lines markdown, 2-4 hours of work.

**Review time:** 1-2 days.

---

### 2.5 Infrastructure & Automation (Medium Barrier, High Value)

**What:** Scripts, CI improvements, tooling.

**Where:**
- CI enhancements (see `CI_ENHANCEMENT_GUIDE.md`)
- Automation scripts (corpus management, performance tracking)
- Developer tools (formatters, linters, test runners)

**Prerequisites:**
- Bash/Python scripting
- CI/CD experience (GitHub Actions)
- Understanding of developer workflow

**Starter tasks:**
- Implement one "Quick Win" from CI_ENHANCEMENT_GUIDE.md
- Add one command to existing script
- Fix one flaky CI check

**Typical PR size:** 100-400 lines, 0.5-2 days of work.

**Review time:** 1-2 days.

---

## 3. Development Workflow

### 3.1 Git Workflow

**Branch naming:**

```bash
# Format: <type>/<short-description>
git checkout -b lean-proof/phase1-singleton-pc10-15
git checkout -b msl-spec/withdraw-balance-invariant
git checkout -b difftest/transfer-frozen-recipient
git checkout -b docs/update-onboarding-guide
git checkout -b infra/ci-fast-fail-check
```

**Types:** `lean-proof`, `msl-spec`, `difftest`, `docs`, `infra`, `fix`.

### 3.2 Commit Messages

**Format:**

```
<type>: <short summary> (<scope>)

<detailed description>

<metrics or impact>

Co-Authored-By: Your Name <email@example.com>
```

**Examples:**

```
lean-proof: prove Phase 1 singleton PCs 10-15 (Registration)

Implement per-PC step theorems for PCs 10-15 in singleton branch.
Uses symbolic state pattern + step-lemma library.

- 6 theorems added (step_pc10 through step_pc15)
- Build time: +0.3s (within budget)
- Coverage: 15/50 PCs → 21/50 PCs (42%)

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
```

```
difftest: add transfer frozen recipient error path

Add corpus row for confidential_transfer with frozen recipient.
Expects abort with ERROR_ACCOUNT_FROZEN (196617).

- Rust oracle: confidential_asset.rs:234
- Lean mapping: RunnerFuncMappingAux.lean:567
- Inventory: confidential_assets.md (status: Passing)
- Coverage: Transfer error paths 7/13 → 8/13 (62%)

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
```

### 3.3 Pre-Commit Checklist

**Before committing:**

```bash
# 1. Run pre-commit hooks
./scripts/setup_git_hooks.sh install  # One-time setup
git commit  # Hooks run automatically

# 2. Verify no sorry
grep -r "sorry" lean/MovementFormal/Experimental/ConfidentialAsset/ || echo "✅ No sorry"

# 3. Check axiom drift (if touched Lean)
./scripts/check_axioms.sh --diff

# 4. Run relevant tests
# For Lean:
cd lean && lake build MovementFormal.Experimental.ConfidentialAsset.<YourModule>

# For MSL:
movement move compile --package-dir ../aptos-experimental

# For difftest:
./difftest.sh --suite confidential_asset

# 5. Update documentation
# If you changed functionality, update:
# - PHASE_*_STATUS.md (progress)
# - README.md (if public API changed)
# - Pattern libraries (if new pattern emerged)
```

### 3.4 Creating a Pull Request

**Use the PR template:**

```bash
# Template: .github/PULL_REQUEST_TEMPLATE_CA_VERIFICATION.md
# Fills in automatically when you create PR via GitHub UI
```

**Required sections:**

1. **Summary:** 1-3 sentences on what this PR does
2. **Changes Made:** Check applicable boxes (Lean/MSL/Difftest/Docs/Infra)
3. **Verification Checklist:** ALL items must be checked or N/A
4. **Metrics:** Fill in before/after numbers (theorems, axioms, build time)
5. **Testing Evidence:** Paste command outputs showing green

**Example PR title:**

```
Phase 1: Prove singleton branch PCs 10-20 (11 theorems, +220 LoC)
```

**Draft PRs:**

Use draft PRs for work-in-progress:

```bash
# Create draft PR via GitHub CLI
gh pr create --draft --title "WIP: Phase 6 Transfer composition"

# Or via UI: Check "Create draft pull request" box
```

---

## 4. Code Standards

### 4.1 Lean Code Style

**Formatting:**

```lean
-- File header
/-!
# Module Title

Brief description of what this module proves.

## Main theorems

- `theorem_name`: One-line description
-/

-- Imports (sorted alphabetically)
import MovementFormal.MoveModel.Programs.Registration
import MovementFormal.MoveModel.StepLemmas.Basic
import MovementFormal.MoveModel.StepLemmas.Locals

-- Namespace
namespace MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquiv

-- Theorem names: snake_case
theorem step_pc10
    (env : ModuleEnvironment) (frame : CallFrame)
    (h_pc : frame.pc = 10)
    (h_fn : frame.function = registrationFuncIdx)
    : MoveModel.step env frame cs stack ms = 
      .success { frame with pc := 11 } cs newStack ms := by
  simp only [step, h_pc, h_fn, step_copyLoc]
  rfl

-- Use simp lemmas (@[simp]) for module environment facts
@[simp] theorem registrationModuleEnv_fn0_numParams :
    (registrationModuleEnv o).functions[0].numParams = 5 := by
  unfold registrationModuleEnv; rfl

end MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquiv
```

**Line length:** Prefer ≤100 characters (soft limit).

**Proof style:**
- Prefer `by rfl` for definitional equalities
- Use `simp only [...]` with explicit lemma list (not bare `simp`)
- Avoid `sorry` (PRs with sorry will be rejected unless WIP/draft)

---

### 4.2 MSL Code Style

**Formatting:**

```move
spec withdraw_to_internal {
    // Preconditions (alphabetical)
    requires exists<ConfidentialAssetStore>(sender_addr);
    requires len(store.pending_balance) > 0;

    // Postconditions (grouped by topic)
    // 1. Balance structure
    ensures len(store.pending_balance) == len(old(store.pending_balance));
    ensures balance_chunks_valid(store.pending_balance);

    // 2. Balance conservation
    ensures sum_balance_chunks(store.pending_balance) == 
        sum_balance_chunks(old(store.pending_balance)) - withdrawal_amount;

    // Abort conditions (order by likelihood: common errors first)
    aborts_if !exists<ConfidentialAssetStore>(sender_addr);
    aborts_if store.frozen with ERROR_ACCOUNT_FROZEN;
    aborts_if !verify_withdrawal_proof(...) with ESIGMA_PROTOCOL_VERIFY_FAILED;
    aborts_if withdrawal_amount > current_balance with ERROR_INSUFFICIENT_BALANCE;

    // Modifies
    modifies global<ConfidentialAssetStore>(sender_addr);

    // Pragmas (last)
    pragma aborts_if_is_strict;
}
```

**Spec fun style:**

```move
spec fun helper_name(param: Type): ReturnType {
    // Brief comment explaining purpose
    if (condition) {
        value_if_true
    } else {
        value_if_false
    }
}
```

---

### 4.3 Rust/Difftest Code Style

**Follow Rust standard style:**

```bash
cargo fmt  # Auto-format
cargo clippy  # Lint
```

**Test case structure:**

```rust
TestCase {
    id: "operation_error_condition".into(),  // snake_case
    oracle_fn: Box::new(|h| {
        // Setup
        let account = h.new_account();
        h.freeze_account(&account);
        
        // Execute
        let result = h.run_function(
            &account,
            "confidential_asset",
            "withdraw_to_internal",
            vec![/* args */],
            vec![],
        );
        
        // Assert
        OracleResult::Aborted(ERROR_ACCOUNT_FROZEN)
    }),
    skip_lean: false,  // true only if VM-only test
},
```

---

## 5. Review Process

### 5.1 What Reviewers Look For

**All PRs:**
- [ ] Clear summary (what/why)
- [ ] All checklist items addressed
- [ ] Tests pass (CI green)
- [ ] No `sorry` in Lean code
- [ ] Metrics filled in (before/after)

**Lean PRs:**
- [ ] Follows proof patterns from library
- [ ] No axiom drift (unless justified + documented)
- [ ] Build time within budget (≤3 min per file)
- [ ] Theorem names match convention (snake_case, descriptive)

**MSL PRs:**
- [ ] Spec compiles (`movement move compile`)
- [ ] Follows MSL patterns from library
- [ ] All `aborts_if` have test cases in corpus
- [ ] Crypto boundaries use `pragma opaque`

**Difftest PRs:**
- [ ] Corpus row in inventory (updated status)
- [ ] Rust oracle implemented
- [ ] Lean mapping added
- [ ] Test passes (`./difftest.sh --suite confidential_asset`)

**Documentation PRs:**
- [ ] No broken links
- [ ] Examples are runnable (tested)
- [ ] Grammar and spelling checked
- [ ] Updated table of contents (if applicable)

### 5.2 Review Timeline

**Target response times:**

| PR Type | First Review | Follow-up | Merge Decision |
|---------|--------------|-----------|----------------|
| Difftest | 1 day | 1 day | 2-3 days |
| MSL Spec | 1-2 days | 1-2 days | 3-5 days |
| Lean Proof | 2-3 days | 2-3 days | 5-7 days |
| Documentation | 1-2 days | 1 day | 2-4 days |
| Infrastructure | 1-2 days | 1-2 days | 3-5 days |

**Delays:** If no review after 3 business days, ping in Slack #ca-formal-verification.

### 5.3 Addressing Review Comments

**Workflow:**

1. **Read all comments** before making changes
2. **Ask clarifying questions** if feedback unclear
3. **Make changes** in new commits (don't force-push yet)
4. **Reply to each comment** when addressed
5. **Request re-review** when all comments resolved
6. **Squash commits** before merge (if requested)

**Example replies:**

```markdown
✅ Fixed - changed theorem name to `step_pc10_copyLoc`

❓ Question - Should I split this into two PRs? One for PCs 10-15, another for 16-20?

🚧 In progress - working on proving `step_pc12`, ETA tomorrow

✅ Done - added test case `withdraw_insufficient_balance` to corpus
```

---

## 6. Recognition & Credit

### 6.1 Attribution

**All contributions are credited:**

- **Git commits:** Your name in commit author
- **Co-authoring:** Claude assists → `Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>`
- **PR description:** Detailed metrics showing your impact
- **Quarterly reports:** Top contributors highlighted

**Examples:**

```bash
# Your commit
git commit --author="Your Name <your.email@example.com>"

# Claude co-authoring (if assisted)
Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
```

### 6.2 Contribution Metrics

**We track:**

- Theorems proved (Lean)
- Spec blocks written (MSL)
- Test cases added (difftest)
- Documentation pages (markdown)
- Scripts/automation (bash/python)

**Quarterly leaderboard** (published in Slack):

```
Q2 2026 Top Contributors:

1. Alice (12 Lean theorems, 450 LoC, Phase 1 singleton branch)
2. Bob (8 MSL specs, 23 test cases, comprehensive coverage)
3. Carol (5 guides, 2 automation scripts, onboarding improvements)
```

### 6.3 Acknowledgment

**In academic papers / technical reports:**

Contributors with ≥3 merged PRs will be acknowledged in:
- Formal verification technical reports
- Academic papers citing this work
- Conference presentations

**Optional:** Add yourself to `CONTRIBUTORS.md` after first merged PR.

---

## Appendix A: Quick Reference

### Commands

```bash
# Setup
./scripts/setup_git_hooks.sh install

# Build
cd lean && lake build
movement move compile --package-dir ../aptos-experimental
./difftest.sh

# Verify
./audit/verify-ca.sh --op <operation> --stack <stack>

# Check
./scripts/check_axioms.sh --diff
./scripts/generate_test_matrix.sh --gaps-only
./scripts/quarterly_maintenance.sh --section coverage

# PR
gh pr create --title "..." --body "..."
gh pr status
```

### Resources

- **Onboarding:** `DEVELOPER_ONBOARDING_GUIDE.md`
- **Patterns (Lean):** `PROOF_PATTERNS_WORKED_EXAMPLE.md`, `PROOF_PATTERNS_LIBRARY.md`
- **Patterns (MSL):** `MSL_SPEC_PATTERN_LIBRARY.md`
- **Guides:** `PHASE_1_SINGLETON_BRANCH_STARTER_KIT.md`, `PHASE_6_IMPLEMENTATION_GUIDE.md`
- **CI:** `CI_ENHANCEMENT_GUIDE.md`
- **Plan:** `CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md`

### Getting Help

- **GitHub Discussions:** Questions, design discussions
- **Slack #ca-formal-verification:** Real-time help
- **GitHub Issues:** Bug reports, feature requests
- **Weekly office hours:** Tuesdays 2PM PT (Zoom link in Slack)

---

## Appendix B: Contribution Ideas

**Good first issues:**

1. **Add difftest case:** `withdraw_zero_amount` (1-2 hours)
2. **Strengthen MSL spec:** Add `ensures` clause to `deposit_to_internal` (1 hour)
3. **Prove 5 PCs:** Phase 1 singleton PCs 10-14 (1 day)
4. **Write guide:** "Debugging Move Prover Timeouts" (2-3 hours)
5. **Fix CI:** Implement fast-fail pre-check from CI_ENHANCEMENT_GUIDE.md (2-4 hours)

**High-impact contributions:**

1. **Phase 1 singleton branch:** 50 PCs, core critical path (5-7 days)
2. **Phase 6 composition:** 1 operation end-to-end (3-5 days)
3. **Difftest automation:** Auto-generate test cases from MSL specs (1 week)
4. **Dashboard:** Verification metrics dashboard (3-4 weeks)

**Documentation needs:**

1. Worked example for Withdrawal operation (complement to Normalization)
2. MSL debugging guide (common errors + fixes)
3. Lean performance tuning guide
4. Video tutorial: "Your First Lean Proof" (10 min)

---

**Thank you for contributing to CA formal verification!** 🎉

Your work helps ensure the security and correctness of confidential asset operations. Every proof, spec, test case, and doc improvement makes the system more trustworthy.

**Questions?** Open an issue or ask in Slack. We're here to help!
