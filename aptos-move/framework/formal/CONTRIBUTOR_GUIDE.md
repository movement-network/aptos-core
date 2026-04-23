# CA Formal Verification — Contributor Guide

**Last updated:** 2026-04-22

Comprehensive guide for contributors to CA formal verification. Covers code standards, review processes, documentation requirements, and team workflows.

## Table of Contents

1. [Before You Start](#before-you-start)
2. [Code Standards](#code-standards)
3. [Documentation Requirements](#documentation-requirements)
4. [Review Process](#review-process)
5. [Commit Guidelines](#commit-guidelines)
6. [Branch Strategy](#branch-strategy)
7. [CI/CD Integration](#cicd-integration)
8. [Communication](#communication)

---

## Before You Start

### Required Reading

Before making your first contribution, read these docs in order:

1. **`DEVELOPER_QUICK_START.md`** — Setup instructions, basic workflows
2. **`CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md`** — Architecture and phasing
3. **`audit/TRUST_BOUNDARIES.md`** — What we trust, what we prove
4. **`audit/CLAIMS.md`** — What properties are verified
5. **`MAINTENANCE_GUIDE.md`** — Long-term maintenance practices

**Estimated reading time:** 90 minutes. Don't skip this — many PR comments are "this is explained in §X of the plan."

### Choose Your Work

Check `COMPLETION_ROADMAP.md` for:
- Current phase status
- Outstanding tasks per phase
- Estimated effort and blockers
- Parallelizable work

**Good first contributions:**
- Documentation improvements (fix typos, clarify confusing sections)
- Difftest corpus rows (add test cases for existing operations)
- MSL specs for store-only operations (Phase 3 — no crypto complexity)
- Lean step-lemma library enhancements (Phase 0 shared infrastructure)

**Advanced contributions:**
- Lean EvalEquiv proofs (Phase 1/4 — requires Lean 4 proof experience)
- Phase 6 composition theorems (PC-chaining proofs, currently blocked on elaborator)
- Phase 7 difftest harness integration (Rust + Move + Lean integration)

### Discuss Before Starting

For large contributions (>2 days of work), open a GitHub issue or Slack thread **before** writing code:
- Describe what you plan to do
- Link to relevant plan sections
- Ask for feedback on approach

This avoids "I spent 2 weeks on this and it doesn't fit the architecture" surprises.

---

## Code Standards

### Lean Code

#### File Organization

```
lean/MovementFormal/
├── MoveModel/                  # Shared bytecode model
│   ├── StepLemmas/            # Per-instruction-class step lemmas (Phase 0)
│   ├── Native/                # Native function oracles
│   └── Programs/              # Bytecode transcriptions
├── Experimental/
│   └── ConfidentialAsset/
│       ├── <Operation>/
│       │   ├── FunctionalSim.lean    # Mathematical spec
│       │   ├── EvalEquiv.lean        # Bytecode equivalence proof
│       │   └── Phase6Composition.lean # Composition theorem (Phase 6)
│       └── Common/            # Shared definitions (balance types, etc.)
└── Std/                       # Move stdlib specs (aptos_std, move_stdlib)
```

#### Naming Conventions

**Theorems:**
- `step_pc<N>` — Per-PC step theorem (e.g., `step_pc0`, `step_pc17`)
- `<operation>_eval_equiv_functional_sim` — Top-level bytecode equivalence
- `<property>_preserved` — Invariant theorems
- `eval_<operation>_eq_run` — Unfolding `eval` to `run`

**Definitions:**
- `<Operation>State` — Symbolic state (e.g., `TransferVerifyState`)
- `<Operation>Oracle` — Oracle type for native calls
- `exec<Operation>` — Operational semantics

**Variables:**
- `env` — Module environment
- `frame` — Call frame
- `cs` — Control stack
- `stack` — Operand stack
- `ms` — Machine state
- `oracle` — Native oracle

#### Style Guide

**Proof structure:**

```lean
theorem example_theorem : P → Q := by
  intro h
  -- Use named tactics, not tactic macros
  simp only [definition1, definition2]
  apply lemma_name
  · case_1  -- Name cases explicitly
    exact proof1
  · case_2
    exact proof2
```

**Avoid:**
- Unnamed `sorry` (use `axiom` with doc-comment if truly unproved)
- `set_option maxHeartbeats` >200000 without justification
- Chained state (use `@[irreducible]` symbolic state instead)
- Bound proofs in theorem statements (use `Array.get?`)
- Tactic macros like `omega` or `decide` without explanation

**Required annotations:**
- `@[irreducible]` on all symbolic state definitions
- `@[simp]` on projection lemmas for `@[irreducible]` defs
- Doc-comments on all public theorems: `-- Proves that <operation> bytecode is equivalent to <spec>`

#### Build Time Budget

Every file must build in **≤3 minutes** (per-file) and contribute **≤1 minute** to full-tree build time. If you exceed this:

1. Profile: `lake env lean --run -Dprofiler=true <File>.lean`
2. Identify bottleneck (usually whnf or elaboration)
3. Refactor: split into sub-lemmas, add `@[irreducible]`, use step-library
4. Re-measure

**Never merge a proof that exceeds the budget.** This is a hard architectural requirement, not a guideline.

### Move Code & MSL Specs

#### Spec File Organization

```
aptos-experimental/sources/confidential_asset/
├── confidential_asset.move          # Entry points
├── confidential_asset.spec.move     # Entry point specs (Phase 5)
├── confidential_balance.move        # Balance operations
├── confidential_balance.spec.move   # Balance specs (Phase 2)
├── confidential_proof.move          # Proof verifiers
├── confidential_proof.spec.move     # Verifier specs (Phase 4 MSL side)
└── ...
```

**One spec block per function** (not scattered across file):

```move
spec register_internal {
    // Preconditions (what must be true on entry)
    requires <preconditions>;
    
    // Postconditions (what's guaranteed on successful return)
    ensures <postconditions>;
    
    // Abort conditions (when function aborts, with error codes)
    aborts_if <condition_1> with <error_code_1>;
    aborts_if <condition_2> with <error_code_2>;
    
    // Frame (what doesn't change)
    modifies global<ResourceType>(addr);
}
```

#### Pragma Usage Rules

**`pragma opaque` (crypto boundary):**
- Use: Native functions that involve curve arithmetic, hashing, or Bulletproofs
- Requires: Entry in `TRUST_BOUNDARIES.md` §5 "Native-function assumptions"
- Example: `ristretto255::point_mul`, `aptos_hash::sha3_512`

**`pragma verify = false` (verification escape):**
- Use: **NEVER in production code**
- Acceptable: Test-only modules (`#[test_only]`)
- Requires: Justification in `TRUST_BOUNDARIES.md` §5 "Verification escapes"

**`pragma aborts_if_is_strict`:**
- Use: Module-level, when all abort conditions are exhaustively specified
- Default: Not strict (allows unspecified aborts)

**`pragma deactivated_proof`:**
- Use: Temporary workaround for upstream bugs (document blocker)
- Requires: GitHub issue tracking removal, entry in `TRUST_BOUNDARIES.md`

### Difftest Corpus

#### Row Format

Every corpus row must have:
1. **Descriptive label** (Rust suite identifier)
2. **Clear input summary** (what's being tested)
3. **Expected output** (VM oracle)
4. **Lean function index** (for VM↔Lean mode)
5. **Hex corpus file** (if input is complex binary data)

Example entry in `difftest/inventory/confidential_assets.md`:

```markdown
| `sigma18_len` | VM `layout_sigma_*().length()` vs **1152** | none | `bool(true)` | VM↔Lean (**funcIdx 128**): `ldConst` + `vecLen` + `eq` |
```

#### Coverage Requirements

When adding a new function, add corpus rows for:
- Happy path (valid inputs, successful execution)
- Error paths (abort conditions, one row per error code)
- Edge cases (zero balances, empty vectors, boundary values)

**Minimum:** 3 rows (happy path + 2 error paths). Complex functions may need 10-20 rows.

---

## Documentation Requirements

### Per-Contribution Documentation

Every PR that adds or changes verification must update docs in **the same commit**:

| Code change | Required doc updates |
|-------------|---------------------|
| New Lean theorem | `CLAIMS.md` (if public), `CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md` §0 progress tracker |
| New MSL spec | `CLAIMS.md`, `TRUST_BOUNDARIES.md` (if pragma opaque), reconcile script |
| New axiom | `AXIOM_INVENTORY.md`, `TRUST_BOUNDARIES.md`, regenerate axiom baseline |
| New operation | `CLAIMS.md`, plan §3 tool matrix, difftest inventory, `verify-ca.sh` |
| Change Move function sig | MSL spec, Lean `FunctionalSim`, `CLAIMS.md` |
| Add `pragma opaque` | `TRUST_BOUNDARIES.md` §5, reconcile script |

**No "I'll update docs in a follow-up PR"** — docs and code land together.

### Commit Message Documentation

Every commit message must have:

1. **Subject line** (<70 chars): What you did
2. **Body**: Why you did it, what changes, what's tested
3. **Metrics**: Build time, axiom count, LoC, test coverage

Example:

```
Add verify_normalization_proof EvalEquiv theorem

Covers all 14 PCs using step-lemma library. Mathematical spec in
FunctionalSim matches sigma-protocol verifier predicate.

Metrics:
- Build time: 0.5s (budget: 180s)
- Axioms: 0 new (only existing crypto axioms)
- LoC: ~150 (theorem + step lemmas)
- Tests: difftest row 195 (negative pin)

Related: Phase 4 (verify_*_proof family)
```

### Documentation Style

**Clarity over cleverness:**
- Write for someone unfamiliar with the codebase
- Define acronyms on first use (MSL = Move Specification Language)
- Link to relevant plan sections (§3, not "section 3" — use actual § symbol)
- Provide examples, not just rules

**Update vs create:**
- Prefer updating existing docs over creating new files
- If creating a new file, add it to the appropriate README index
- Cross-link from related docs

**Completeness:**
- Every `FIXME` / `TODO` gets a GitHub issue
- Every "see §X" link actually resolves
- Every example compiles

---

## Review Process

### Pre-Review Checklist

Before requesting review, ensure:

- [ ] **Pre-commit hook passes** (or explicitly bypassed with justification)
- [ ] **Local verification suite passes**: `./scripts/run_verification_suite.sh`
- [ ] **Documentation updated** (see table above)
- [ ] **Axiom diff checked**: `./scripts/check_axioms.sh --diff`
- [ ] **Trust boundaries reconciled** (if MSL changes): `./scripts/reconcile_trust_boundaries.sh`
- [ ] **Build time within budget** (<3 min per file, <10 min full tree)
- [ ] **Commit message follows template** (subject, body, metrics)

### Review Criteria

Reviewers check:

1. **Correctness:**
   - Theorem statement matches claimed property
   - Proof has no `sorry` in production code
   - MSL spec covers all abort conditions
   - Difftest corpus covers happy + error paths

2. **Architecture:**
   - Uses step-lemma library (not re-deriving step behavior)
   - Symbolic state is `@[irreducible]` with `@[simp]` projections
   - No O(N²) whnf patterns (chain-based state)
   - Follows Phase 0/1/4 architectural patterns

3. **Documentation:**
   - `CLAIMS.md` updated with plain-English property
   - `TRUST_BOUNDARIES.md` updated if new axiom/pragma
   - Plan §0 progress tracker updated
   - Commit message has metrics

4. **Trust boundary:**
   - New axioms justified (crypto, not laziness)
   - `pragma opaque` usage documented
   - No `pragma verify = false` in production code
   - Axiom baseline regenerated if axioms changed

5. **Performance:**
   - Build time ≤3 min per file
   - No heartbeat overrides >200k without justification
   - Profiler output included for slow proofs (>60s)

### Review SLA

- **Simple PRs** (docs, corpus rows, <100 LoC): 1 business day
- **Medium PRs** (MSL spec, step lemma, <500 LoC): 2 business days
- **Complex PRs** (EvalEquiv proof, Phase 6 composition, >500 LoC): 3-5 business days

**Exceeding SLA:** Ping reviewer in Slack after SLA expires.

### Addressing Review Comments

**Respond to every comment**, even if just "Ack, fixed." Reviewers check the conversation, not just the diff.

**When pushing changes:**
- Squash fixup commits before final merge
- Update commit message with review feedback
- Re-run verification suite (review iteration might break other files)

**Disagreements:**
- Discuss in PR comments first
- Escalate to Slack #formal-verification if stuck
- Final call: formal verification team lead

---

## Commit Guidelines

### Commit Granularity

**One logical change per commit:**
- ✅ "Add verify_normalization_proof EvalEquiv theorem"
- ✅ "Update TRUST_BOUNDARIES.md for new pragma opaque"
- ❌ "Add proof + update docs + fix typo + refactor unrelated code"

**Exception:** Documentation updates for the same code change can be in the same commit (proof + CLAIMS.md update).

### Commit Message Format

```
<subject line>

<body paragraphs>

<metrics>

<footer: Related/Fixes>
```

**Subject line:**
- <70 characters
- Imperative mood ("Add", not "Added" or "Adds")
- No period at end
- Capitalize first word

**Body:**
- Wrap at 80 columns
- Explain **why**, not **what** (diff shows what)
- Reference plan sections (§0, §3, etc.)
- Include profiler output if build time >60s

**Metrics:**
- Build time
- Axiom count (new vs total)
- LoC (if significant)
- Test coverage (corpus rows, verification checks)

**Footer:**
- `Related: Phase X` (which phase this contributes to)
- `Fixes: #123` (GitHub issue, if applicable)

### Co-authorship

If pair-programming or incorporating code from others:

```
Co-Authored-By: Alice Engineer <alice@example.com>
Co-Authored-By: Bob Prover <bob@example.com>
```

### Atomic Commits

Every commit must:
- **Build cleanly** (`lake build` succeeds)
- **Pass pre-commit hook** (or explicitly bypass with `--no-verify` + justification)
- **Leave codebase in consistent state** (no half-finished proofs, no broken links)

**Never commit:**
- `sorry` in production code without `axiom` + doc-comment
- Compilation errors
- Commented-out code (use `git show` to recover old code)
- Debug print statements

---

## Branch Strategy

### Primary Branches

- **`movement`** — Main branch (production-ready)
- **`lean-fv`** — Formal verification development branch (staging for movement)
- **Feature branches** — Your work (named `<username>/<feature>`)

### Workflow

1. **Branch from `lean-fv`:**
   ```bash
   git checkout lean-fv
   git pull
   git checkout -b yourname/add-normalization-proof
   ```

2. **Develop + commit:**
   ```bash
   # Make changes
   git add <files>
   git commit -m "Add verify_normalization_proof EvalEquiv"
   ```

3. **Rebase before PR:**
   ```bash
   git fetch origin
   git rebase origin/lean-fv
   # Resolve conflicts if any
   ```

4. **Open PR:**
   - Target branch: `lean-fv`
   - Title: Same as commit subject (if single commit) or descriptive summary
   - Description: Link to plan section, summarize changes, call out review focus areas

5. **Address review, squash, merge:**
   ```bash
   # Squash fixup commits
   git rebase -i origin/lean-fv
   # Force push (your branch only!)
   git push --force-with-lease
   # Merge via GitHub UI (squash or rebase, per team preference)
   ```

### Feature Branch Lifetime

- **Short-lived:** <1 week preferred
- **Long-lived:** >2 weeks requires weekly rebase to stay current
- **Abandoned:** Delete if no activity for >1 month

### Merge Strategy

**Prefer:** Squash and merge (for clean history)

**Exceptions:** Multi-commit PRs where individual commits are meaningful (e.g., "Add FunctionalSim" + "Add EvalEquiv" as separate commits).

---

## CI/CD Integration

### CI Workflows

**On every push to `lean-fv` or PRs:**

1. **`ca-verification-suite`** (~13 min, 6 parallel jobs):
   - Quick check (Lean + Move Prover toolchains)
   - Lean build (all ops)
   - Move Prover compile (all ops)
   - Trust boundaries reconciliation
   - Documentation checks
   - Performance benchmarks

2. **`axiom-diff-ca`** (~2 min):
   - Diff axioms against baseline
   - Fail if new axioms without `AXIOM_INVENTORY.md` update

3. **`lean-ca`** (~5 min):
   - Full Lean build
   - Sorry count check
   - Axiom inventory validation

4. **`move-prover-ca`** (~3 min):
   - Move Prover compilation (all CA modules)
   - Currently expects 0 VCs (ristretto255 blocker)

### CI Failure Response

**If CI fails on your PR:**

1. **Check logs** (GitHub Actions tab)
2. **Reproduce locally:**
   ```bash
   ./scripts/run_verification_suite.sh --comprehensive
   ```
3. **Fix** (see `TROUBLESHOOTING_GUIDE.md` for common failures)
4. **Push fix** (will re-trigger CI)

**Never:**
- Merge with failing CI
- Disable CI checks to "fix" failures
- Comment "CI failure is unrelated" without investigation

### Local Pre-CI Validation

Before pushing, run:

```bash
# Quick validation (~2 min)
./scripts/run_verification_suite.sh --quick

# Full validation (~15 min, matches CI)
./scripts/run_verification_suite.sh --comprehensive
```

**Catches 90% of CI failures locally** before wasting CI time.

---

## Communication

### Channels

- **Slack #formal-verification:** Quick questions, blockers, coordination
- **GitHub Issues:** Bug reports, feature requests, long discussions
- **GitHub PRs:** Code review, technical feedback
- **Email:** Formal announcements only (phase completions, releases)

### Asking for Help

**Good question format:**

```
Problem: <what's not working>
Context: <what you're trying to do>
Attempted: <what you've tried>
Logs: <error messages, profiler output>
Question: <specific question>
```

Example:

```
Problem: Lean proof exceeds heartbeat limit
Context: Adding verify_rotation_proof EvalEquiv (Phase 4)
Attempted: Used @[irreducible] on state, imported step-lemma library
Logs: <profiler output showing whnf bottleneck in theorem statement>
Question: How do I avoid bound-proof elaboration in the statement?
```

**Avoid:**
- "It doesn't work" (no context)
- "Can someone help?" (no specific question)
- Slack DMs to random team members (use #formal-verification)

### Office Hours

Formal verification team holds weekly office hours:
- **When:** Tuesdays 2-3pm Pacific
- **Where:** Zoom (link in Slack channel topic)
- **Agenda:** Open Q&A, proof walkthroughs, architecture discussions

**Bring your blockers** — screen-share proof code, walk through errors together.

### Code of Conduct

- **Be kind:** Assume good intent, give constructive feedback
- **Be patient:** Formal methods is hard; learning curve is steep
- **Be responsive:** Reply to PRs/issues within 1 business day
- **Be collaborative:** Share knowledge, help onboard new contributors

---

## Contribution Checklist

Before submitting your PR, verify:

- [ ] **Code builds:** `lake build` (Lean) or `movement move compile` (Move) succeeds
- [ ] **Verification suite passes:** `./scripts/run_verification_suite.sh --comprehensive`
- [ ] **Pre-commit hook passes** (or bypassed with `--no-verify` + justification)
- [ ] **Documentation updated:** All relevant docs from table above
- [ ] **Axiom diff clean:** `./scripts/check_axioms.sh --diff` (or baseline regenerated)
- [ ] **Trust boundaries reconcile:** `./scripts/reconcile_trust_boundaries.sh`
- [ ] **Build time within budget:** <3 min per file, <10 min full tree
- [ ] **Commit message complete:** Subject, body, metrics, footer
- [ ] **Tests added:** Corpus rows, verification checks (as applicable)
- [ ] **GitHub issue linked:** `Fixes: #123` or `Related: Phase X`

**Skip this checklist at your own risk** — reviewers will send you back to complete it.

---

## Getting Unblocked

**Stuck >30 min?** Ask for help.

**Stuck >1 day?** Escalate to office hours.

**Stuck >1 week?** The task might be mis-scoped — discuss in Slack.

**Never stay blocked in silence.** The team is here to help.

---

## Thank You

Every contribution makes CA formal verification stronger. Whether you're adding a single corpus row or a full EvalEquiv proof, you're helping build trustworthy cryptographic infrastructure.

**Happy contributing!** 🚀
