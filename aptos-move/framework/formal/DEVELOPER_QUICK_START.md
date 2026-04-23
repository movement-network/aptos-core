# CA Formal Verification — Developer Quick Start

**Last updated:** 2026-04-22

This guide gets developers from zero to contributing to CA formal verification in under 30 minutes. Unlike the **Reviewer Quick Start** (read-only verification), this guide covers the full development workflow: writing proofs, adding specs, running tests, and committing changes.

## Target Audience

- Team members adding new CA operations or modifying existing ones
- Lean proof engineers working on Phase 1/4/6 bytecode theorems
- Move Prover engineers writing MSL specs (Phase 2/3/5)
- Infrastructure engineers maintaining the verification stack

## Prerequisites (15 min setup)

### 1. Lean 4 Development Stack

```bash
# Install Lean toolchain
curl https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh -sSf | sh

# Clone repo and navigate to formal directory
cd aptos-move/framework/formal/lean

# Fetch mathlib cache (CRITICAL — saves hours of compilation)
lake exe cache get

# Build the full CA Lean tree (~4s)
lake build

# Verify no sorry exists in production code
../scripts/check_confidential_lean_hygiene.sh
```

**Why mathlib cache matters:** Mathlib takes ~4 hours to compile from source. The cache makes clean builds finish in ~10 seconds. **Always run `lake exe cache get` before `lake build`** — this is the #1 cause of "my Lean build is hanging" issues.

### 2. Move Prover Development Stack

**Current status (2026-04-22):** Toolchain ready, verification blocked on ristretto255 patches (expected 0 VCs until blocker clears). See `MOVE_PROVER_INTEGRATION_STATUS.md` for details.

```bash
# Install prover dependencies (Boogie 3.5.1, Z3 4.11.2, CVC5 0.0.3)
movement update prover-dependencies --assume-yes

# Set environment variables (add to ~/.zshrc or ~/.bashrc for persistence)
export BOOGIE_EXE=$HOME/.local/bin/boogie
export Z3_EXE=$HOME/.local/bin/z3
export CVC5_EXE=$HOME/.local/bin/cvc5
export DOTNET_ROOT=$HOME/.dotnet

# Verify toolchain
$Z3_EXE --version    # expect: Z3 version 4.11.2 (NOT 4.14.x from Homebrew!)
$BOOGIE_EXE -version # expect: Boogie program verifier version 3.5.1.0

# Smoke test (should pass in <5s)
movement move prove \
  --package-dir aptos-move/framework/move-stdlib \
  --filter vector \
  --vc-timeout 20 \
  --skip-fetch-latest-git-deps
```

**Critical gotcha:** Do NOT install Z3 from Homebrew — it ships 4.14.x, which Move Prover rejects. Use `movement update prover-dependencies` which installs the correct 4.11.2 version.

### 3. Git Hooks (recommended)

Install the pre-commit hook to catch verification issues before commit:

```bash
cd aptos-move/framework/formal
ln -s ../../aptos-move/framework/formal/scripts/pre-commit-hook.sh .git/hooks/pre-commit
```

The hook runs 5 checks (<30s):
1. No new `sorry` in Lean files
2. No new axioms without `AXIOM_INVENTORY.md` update
3. Lean builds successfully (modified files only)
4. Trust boundaries reconcile (if `TRUST_BOUNDARIES.md` modified)
5. No new verification escapes (warns, doesn't fail)

Skip with `git commit --no-verify` when intentionally breaking rules (e.g., work-in-progress axiom stubs).

### 4. Editor Setup

**VS Code (recommended for Lean):**

```bash
# Install Lean 4 extension
code --install-extension leanprover.lean4

# Open workspace
code aptos-move/framework/formal/lean
```

The extension provides:
- Real-time type checking and proof state inspection
- Inline error messages
- Auto-completion for Lean tactics
- "Go to definition" across the full Mathlib + MovementFormal tree

**IntelliJ / VS Code (for Move):**

Install the Move language plugin for syntax highlighting and basic navigation. Full MSL spec support is limited; most engineers use command-line `movement move prove` for verification.

## Development Workflows

### Workflow 1: Adding a New Lean Proof (Phase 1/4)

**Example:** Adding a new `verify_*_proof` EvalEquiv theorem (Phase 4 pattern).

1. **Create the file structure:**

```bash
cd aptos-move/framework/formal/lean/MovementFormal/Experimental/ConfidentialAsset/<Operation>
touch EvalEquiv.lean
```

2. **Write the proof using the architectural pattern:**

```lean
-- EvalEquiv.lean
import MovementFormal.MoveModel.StepLemmas.Run
import MovementFormal.Experimental.ConfidentialAsset.<Operation>.FunctionalSim

namespace MovementFormal.Experimental.ConfidentialAsset.<Operation>

-- Symbolic state (not chained frames)
@[irreducible]
def VerifyState := {
  pc : Nat
  locals : Array (Option Value)
  stack : List Value
  -- ... named fields for everything that matters
}

-- Per-PC step theorems using step-lemma library
theorem step_pc0 : MoveModel.step env frame cs stack ms = ... := by
  simp only [step_ldU64, step_stLoc, ...]
  rfl

-- ... (one theorem per PC)

-- Top-level equivalence: eval ↔ functional sim
theorem verify_<operation>_proof_eval_equiv :
    ∀ oracle, eval verify_<operation>_proof oracle = functionalSim oracle := by
  intro oracle
  simp only [eval, run, step_pc0, step_pc1, ...]
  sorry  -- Filled in during proof development

end MovementFormal.Experimental.ConfidentialAsset.<Operation>
```

3. **Build incrementally:**

```bash
# Build just your file (fast iteration)
lake build MovementFormal.Experimental.ConfidentialAsset.<Operation>.EvalEquiv

# Check proof state in VS Code: click on `sorry`, inspect Lean 4 Infoview

# Once proof compiles, check axioms
lake env lean --run scripts/print_axioms.lean MovementFormal.Experimental.ConfidentialAsset.<Operation>.EvalEquiv
```

4. **Target: sub-3-minute build time**

If your file exceeds 3 minutes, the architecture is wrong. Common fixes:
- Use `@[irreducible]` on symbolic state definitions
- Avoid `.locals[K]'<bound_proof>` idiom (use `Array.get?` instead)
- Break large proofs into sub-lemmas (<100 lines each)
- Check heartbeat usage: `set_option maxHeartbeats 200000 in theorem ...` (temporary; fix root cause before merge)

5. **Verify and commit:**

```bash
# Run verification suite (includes your new proof)
../scripts/run_verification_suite.sh --quick

# Check axiom diff
../scripts/check_axioms.sh --diff

# Commit (pre-commit hook runs automatically)
git add lean/MovementFormal/Experimental/ConfidentialAsset/<Operation>/EvalEquiv.lean
git commit -m "Add verify_<operation>_proof EvalEquiv theorem

Covers all <N> PCs using step-lemma library. Builds in <X>s.
Zero new axioms (only existing crypto axioms).
"
```

### Workflow 2: Writing Move Prover Specs (Phase 2/3/5)

**Example:** Adding MSL specs for a new `*_internal` function.

1. **Navigate to spec file:**

```bash
cd aptos-move/framework/aptos-experimental/sources/confidential_asset
# Edit: confidential_asset.spec.move, confidential_balance.spec.move, etc.
```

2. **Write the spec:**

```move
spec register_internal {
    // Preconditions
    requires len(store.pending_balance) == PENDING_BALANCE_CHUNKS;
    requires len(store.actual_balance) == ACTUAL_BALANCE_CHUNKS;
    
    // Postconditions
    ensures len(store.pending_balance) == PENDING_BALANCE_CHUNKS;
    ensures store.encryption_key == encryption_key;
    ensures store.pending_balance == new_pending_balance_no_randomness(0);
    
    // Abort conditions
    aborts_if has_confidential_asset_store(owner_addr);
    aborts_if !exists<FAConfig>(RESOURCE_ACCOUNT_ADDRESS);
    
    // Frame: what doesn't change
    modifies global<ConfidentialAssetStore>(owner_addr);
}
```

3. **Compile and verify:**

```bash
# Compile specs (should succeed even if 0 VCs generated)
movement move compile --package-dir aptos-move/framework/aptos-experimental

# Run Move Prover (currently produces 0 VCs due to ristretto255 blocker)
movement move prove \
  --package-dir aptos-move/framework/aptos-experimental \
  --filter confidential_asset::register_internal \
  --vc-timeout 120

# Expected output (2026-04-22): compiles cleanly, 0 VCs
# After ristretto255 patches: VCs will appear, solver will run
```

4. **Update trust boundaries if using `pragma opaque`:**

```bash
# If you added pragma opaque (crypto boundary), update TRUST_BOUNDARIES.md
vim ../formal/audit/TRUST_BOUNDARIES.md

# Then reconcile
../formal/scripts/reconcile_trust_boundaries.sh
```

5. **Commit:**

```bash
git add aptos-experimental/sources/confidential_asset/*.spec.move
git commit -m "Add MSL specs for <function>

Covers: balance preservation, abort conditions, frame.
Crypto layer remains pragma opaque (verified in Lean Phase 4).
"
```

### Workflow 3: Updating Documentation After Code Changes

**Trigger:** You changed Move source, Lean proofs, or MSL specs. What docs need updating?

Use the decision tree in `MAINTENANCE_GUIDE.md` §2. Quick version:

| You changed... | Update these docs... |
|----------------|---------------------|
| Move function signature | `CLAIMS.md` (if public), MSL spec, Lean `FunctionalSim` |
| Move function body (not sig) | Lean `EvalEquiv` (re-transcribe bytecode), difftest corpus |
| MSL spec (new `ensures` clause) | `CLAIMS.md`, `TRUST_BOUNDARIES.md` (if new axiom) |
| Lean proof (new axiom) | `AXIOM_INVENTORY.md`, `TRUST_BOUNDARIES.md`, axiom baseline |
| Added `pragma opaque` | `TRUST_BOUNDARIES.md` §5, reconcile script |
| New operation | `CLAIMS.md`, `CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md` §3, difftest inventory |

**Automation:**

```bash
# After changes, run reconciliation
./scripts/reconcile_trust_boundaries.sh

# Check axiom drift
./scripts/check_axioms.sh --diff

# Regenerate baseline if axioms intentionally changed
./scripts/check_axioms.sh > audit/axiom-baseline.txt
git add audit/axiom-baseline.txt
```

### Workflow 4: Running the Full Verification Suite

**Quick check (2 min):**

```bash
cd aptos-move/framework/formal
./scripts/run_verification_suite.sh --quick
```

Runs: Lean toolchain check, Move Prover toolchain check, Lean build (Registration only), Move Prover compile (all ops), sorry count, axiom diff.

**Standard check (5 min):**

```bash
./scripts/run_verification_suite.sh
```

Adds: Full Lean build (all ops), trust boundaries reconciliation, spec coverage check.

**Comprehensive check (15 min, pre-release):**

```bash
./scripts/run_verification_suite.sh --comprehensive
```

Adds: Performance benchmarks, documentation coverage check, axiom inventory reconciliation, all CI checks.

**Per-operation verification (<3s):**

```bash
./audit/verify-ca.sh --op register --stack lean
./audit/verify-ca.sh --op transfer --stack move-prover
```

### Workflow 5: Benchmarking Performance

Track verification timing to catch performance regressions:

```bash
# Run benchmark suite (~2 min)
./scripts/benchmark_verification.sh

# Output formats
./scripts/benchmark_verification.sh --json > benchmarks/run-$(date +%Y%m%d).json
./scripts/benchmark_verification.sh --csv > benchmarks/run-$(date +%Y%m%d).csv
./scripts/benchmark_verification.sh --markdown  # For docs

# Baseline (for regression checking)
./scripts/benchmark_verification.sh --baseline > benchmarks/baseline-$(date +%Y%m%d).txt
```

**Performance budgets (hard limits):**
- Per-operation Lean build: ≤180s (actual: 1-2s — 100x under budget)
- Full Lean tree: ≤600s (actual: ~4s)
- Per-operation Move Prover: ≤180s (actual: ~1s for compilation)

If any operation exceeds its budget, investigate:
1. Check for O(N²) whnf (chain-based state, missing `@[irreducible]`)
2. Profile with `set_option profiler true`
3. Split monolithic proofs into sub-lemmas
4. See `TROUBLESHOOTING_GUIDE.md` §3 "Slow Builds"

## Common Development Tasks

### Task: Add a New Operation to the Verification Matrix

1. **Plan the three-stack split** (see `CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md` §3):
   - State/resource layer → Move Prover (MSL spec)
   - Crypto/proof-verifier → Lean (EvalEquiv bytecode theorem)
   - Entry wrapper → Move Prover (MSL spec)

2. **Update the plan tracker:**
   ```bash
   vim CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md
   # Add row to §3 table, mark as 🟡 in progress
   ```

3. **Create file structure:**
   ```bash
   # Lean
   mkdir lean/MovementFormal/Experimental/ConfidentialAsset/<Operation>
   touch lean/MovementFormal/Experimental/ConfidentialAsset/<Operation>/FunctionalSim.lean
   touch lean/MovementFormal/Experimental/ConfidentialAsset/<Operation>/EvalEquiv.lean
   
   # MSL spec
   # (Edit existing confidential_asset.spec.move)
   ```

4. **Implement in parallel:**
   - Lean: FunctionalSim (mathematical model) → EvalEquiv (bytecode proof)
   - MSL: function spec → entry point spec
   - Difftest: Add corpus rows (see `difftest/inventory/confidential_assets.md`)

5. **Update documentation:**
   - `CLAIMS.md`: Add claims for the new operation
   - `TRUST_BOUNDARIES.md`: Document any new axioms or `pragma opaque`
   - `verify-ca.sh`: Add `--op <new_operation>` support

6. **Land in one PR:**
   - Lean proofs + MSL specs + difftest corpus + documentation updates
   - Pre-commit hook validates consistency
   - CI runs full verification suite

### Task: Eliminate a TEMPORARY Axiom

**Context:** Phase 1 `registration_eval_equiv_functional_sim` is marked TEMPORARY. When singleton branch completes, replace axiom with theorem.

1. **Verify the proof is complete:**
   ```bash
   cd lean
   lake build MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquivRebuild
   # Ensure no `sorry` remains
   ```

2. **Replace axiom with theorem:**
   ```lean
   -- Before:
   axiom registration_eval_equiv_functional_sim : ∀ oracle, eval (...) = functionalSim oracle
   
   -- After:
   theorem registration_eval_equiv_functional_sim : ∀ oracle, eval (...) = functionalSim oracle := by
     intro oracle
     -- ... (proof body)
   ```

3. **Check axiom diff:**
   ```bash
   lake env lean --run ../scripts/print_axioms.lean MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquivRebuild
   # Expect: only permanent crypto axioms, no TEMPORARY axioms
   ```

4. **Update documentation:**
   - `AXIOM_INVENTORY.md`: Remove from TEMPORARY section
   - `audit/axiom-baseline.txt`: Regenerate baseline
   - `CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md` §0: Update Phase 1 status to ✅ COMPLETE

5. **Run axiom-diff CI locally:**
   ```bash
   ./scripts/check_axioms.sh --diff
   # Should show: 1 axiom removed (registration_eval_equiv_functional_sim)
   ```

### Task: Respond to a Verification Failure in CI

**Scenario:** PR merged, CI fails on `ca-verification-suite` workflow.

1. **Identify the failure:**
   - Check GitHub Actions logs
   - Common failures: Lean build error, axiom drift, trust boundary mismatch, performance regression

2. **Reproduce locally:**
   ```bash
   ./scripts/run_verification_suite.sh --comprehensive
   ```

3. **Fix based on failure type:**

   **Lean build error:**
   ```bash
   cd lean
   lake build  # See full error output
   # Fix proof, re-run
   ```

   **Axiom drift:**
   ```bash
   ./scripts/check_axioms.sh --diff
   # If intentional: update AXIOM_INVENTORY.md + regenerate baseline
   # If unintentional: remove new axiom, replace with theorem
   ```

   **Trust boundary mismatch:**
   ```bash
   ./scripts/reconcile_trust_boundaries.sh
   # Follow error messages to fix TRUST_BOUNDARIES.md
   ```

   **Performance regression:**
   ```bash
   ./scripts/benchmark_verification.sh
   # Compare against baseline in benchmarks/
   # If real regression: profile slow proof, refactor
   ```

4. **Push fix:**
   ```bash
   git add <fixed-files>
   git commit -m "Fix CI: <brief description>"
   git push
   ```

## Development Best Practices

### Lean Proof Engineering

1. **Use the step-lemma library** (Phase 0 architecture):
   - Don't re-prove `step` behavior for each instruction
   - Import `MovementFormal.MoveModel.StepLemmas.Run` and apply parametric lemmas

2. **Keep files under 3-minute build budget:**
   - Use `@[irreducible]` on symbolic state
   - Avoid monolithic proofs (>500 lines)
   - Split into sub-lemmas

3. **No `sorry` in production code:**
   - Pre-commit hook catches this
   - Use `axiom` with TEMPORARY marker if work-in-progress, document in `AXIOM_INVENTORY.md`

4. **Check axioms before merge:**
   ```bash
   lake env lean --run ../scripts/print_axioms.lean <YourModule>
   ```

5. **Name theorems descriptively:**
   - `step_pc<N>` for per-PC step theorems
   - `<operation>_eval_equiv_functional_sim` for top-level equivalence
   - `<property>_preserved` for invariants

### Move Prover Spec Engineering

1. **One spec block per function:**
   ```move
   spec register_internal {
       // All spec content here
   }
   ```

2. **Document `pragma opaque` usage:**
   - Every `pragma opaque` must appear in `TRUST_BOUNDARIES.md`
   - Run `./scripts/reconcile_trust_boundaries.sh` after adding

3. **Strengthen specs iteratively:**
   - Start with abort conditions (easiest)
   - Add postconditions (balance preservation, state updates)
   - Add frame conditions (what doesn't change)
   - Current blocker: 0 VCs until ristretto255 patches land

4. **Test locally before CI:**
   ```bash
   movement move prove --package-dir aptos-experimental --filter <function>
   ```

### Documentation Engineering

1. **Update docs in the same PR as code:**
   - Don't land code without updating `CLAIMS.md`, `TRUST_BOUNDARIES.md`, etc.
   - Docs drift is the #1 cause of audit confusion

2. **Use the maintenance decision tree:**
   - See `MAINTENANCE_GUIDE.md` §2: "I changed X, what do I update?"

3. **Keep CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md §0 current:**
   - Update status (☐/🟡/✅/⚠️) in the same PR that lands work
   - Fill "Measured cost" column with actual timings

## Troubleshooting

### Problem: `lake build` hangs forever

**Cause:** Mathlib not cached, compiling from source (~4 hours).

**Fix:**
```bash
lake exe cache get
# If that fails: check internet connection, check Mathlib version in lakefile.lean
```

### Problem: Move Prover rejects Z3 version

**Error:** `expected at most version 4.11.2 but found 4.14.x for z3`

**Cause:** Homebrew Z3 installed (4.14.x).

**Fix:**
```bash
# Uninstall Homebrew Z3
brew uninstall z3

# Install correct version via movement CLI
movement update prover-dependencies --assume-yes

# Verify
$Z3_EXE --version  # Should show 4.11.2
```

### Problem: Pre-commit hook fails with "sorry found"

**Cause:** You have `sorry` in staged Lean files.

**Fix:**
```bash
# See which files have sorry
git diff --cached -- 'lean/**/*.lean' | grep sorry

# Either:
# 1. Complete the proof
# 2. Use axiom instead (document in AXIOM_INVENTORY.md)
# 3. Skip hook: git commit --no-verify (only for WIP commits)
```

### Problem: Axiom-diff CI fails

**Error:** `New axioms detected: <axiom_name>`

**Fix:**

If intentional:
```bash
# Add to AXIOM_INVENTORY.md
vim audit/AXIOM_INVENTORY.md

# Regenerate baseline
./scripts/check_axioms.sh > audit/axiom-baseline.txt

# Commit both
git add audit/AXIOM_INVENTORY.md audit/axiom-baseline.txt
```

If unintentional:
```bash
# Find the axiom
lake env lean --run scripts/print_axioms.lean <YourModule>

# Replace with theorem or remove
```

### Problem: Lean proof exceeds 3-minute budget

**Symptom:** `lake build <Module>` takes >180s

**Diagnosis:**
```bash
# Profile the slow file
cd lean
lake env lean --run -Dprofiler=true <File>.lean
```

**Common causes & fixes:**

1. **O(N²) whnf from chained state:**
   - Fix: Use `@[irreducible]` on symbolic state definitions

2. **Bound proof elaboration in theorem statement:**
   - Fix: Replace `.locals[K]'<proof>` with `Array.get?`

3. **Monolithic proof (>500 lines):**
   - Fix: Split into sub-lemmas (<100 lines each)

4. **Missing `@[simp]` projection lemmas:**
   - Fix: Add projection suite for `@[irreducible]` defs

See `TROUBLESHOOTING_GUIDE.md` §3 for full diagnostic procedures.

## Next Steps

- **Read the architecture:** `CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md`
- **Understand the trust model:** `audit/TRUST_BOUNDARIES.md`
- **See what's proved:** `audit/CLAIMS.md`
- **Track progress:** `COMPLETION_ROADMAP.md`
- **Join the team:** Ask in #formal-verification Slack

**Happy proving!** 🎓
