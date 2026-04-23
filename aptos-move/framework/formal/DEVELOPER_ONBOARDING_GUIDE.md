# Developer Onboarding Guide: CA Formal Verification

**Purpose:** Get a new team member from zero to productive on CA formal verification in ~2 hours.

**Target audience:** Engineers joining the CA verification effort who need to:
- Run the full verification stack locally
- Understand the architecture and workflow
- Make their first contribution within 24 hours

**Prerequisites:** macOS or Linux, 16GB+ RAM, 50GB+ free disk space, basic command-line comfort.

---

## Table of Contents

1. [Quick Start (30 minutes)](#1-quick-start-30-minutes)
2. [Deep Dive: Verification Stack (45 minutes)](#2-deep-dive-verification-stack-45-minutes)
3. [Your First Contribution (30 minutes)](#3-your-first-contribution-30-minutes)
4. [Troubleshooting](#4-troubleshooting)
5. [Where to Get Help](#5-where-to-get-help)

---

## 1. Quick Start (30 minutes)

### 1.1 Clone and Navigate

```bash
# Clone the repository (if not already done)
git clone https://github.com/movementlabsxyz/aptos-core.git
cd aptos-core

# Switch to the verification branch
git checkout lean-fv

# Navigate to formal verification directory
cd aptos-move/framework/formal
```

**What you're looking at:** The `formal/` directory contains all CA verification infrastructure:
- `lean/` — Lean 4 proofs (bytecode-level crypto verification)
- `difftest/` — VM↔Lean differential testing
- `scripts/` — Automation and validation tools
- `audit/` — Deliverables for external review
- Various `.md` docs — Guides like this one

### 1.2 Install Lean Stack (~10 minutes)

**Step 1: Install elan (Lean version manager)**

```bash
curl https://elan.dev/install.sh -sSf | sh
source ~/.bashrc  # or ~/.zshrc on macOS
```

**Step 2: Verify installation**

```bash
elan --version  # Should show elan 3.x.x
lean --version  # Should show Lean 4.24.0
```

**Step 3: Fetch Mathlib cache (CRITICAL)**

```bash
cd aptos-move/framework/formal/lean
lake exe cache get!
```

**Why this matters:** Mathlib is a huge library (~500k lines). Without the precompiled cache, building from source takes **hours**. The cache downloads in ~2 minutes and makes builds take ~4 minutes instead.

**Step 4: Build Lean proofs**

```bash
lake build
```

**Expected:** First build takes ~4 minutes (with cache). Output shows compilation progress. If it takes >15 minutes, you likely skipped `cache get!` — abort and run it.

**Verify success:**

```bash
lake build MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquivRebuild
```

Should complete in ~3 seconds on incremental build. If you see errors, skip to [§4 Troubleshooting](#4-troubleshooting).

### 1.3 Install Move Prover Stack (~5 minutes)

**Step 1: Install Movement CLI**

Follow: https://docs.movementnetwork.xyz/devs/movementcli

Or via Homebrew (macOS):

```bash
brew tap movementlabsxyz/tap
brew install movement
```

**Step 2: Install prover dependencies**

```bash
movement update prover-dependencies --assume-yes
```

This installs:
- Boogie 3.5.1 (verification condition generator)
- Z3 4.11.2 (SMT solver)
- CVC5 0.0.3 (backup solver)

**Important:** Do NOT install Z3 via Homebrew. The Movement CLI installs the exact version (4.11.2) that Move Prover requires.

**Step 3: Source environment**

```bash
# The installer adds these to your shell profile:
export BOOGIE_EXE=$HOME/.local/bin/boogie
export Z3_EXE=$HOME/.local/bin/z3
export CVC5_EXE=$HOME/.local/bin/cvc5
export DOTNET_ROOT=$HOME/.dotnet

# Verify:
$Z3_EXE --version  # Should show: Z3 version 4.11.2
```

**Step 4: Smoke test**

```bash
cd aptos-move/framework/formal
movement move prove \
  --package-dir ../move-stdlib \
  --filter vector \
  --vc-timeout 20 \
  --skip-fetch-latest-git-deps
```

Expected: `{ "Result": "Success" }` in <5 seconds.

### 1.4 Install Difftest Stack (~5 minutes)

**Prerequisites:** Rust toolchain (for Move VM oracle generation)

```bash
# Install Rust if needed
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source ~/.cargo/env

# Verify
cargo --version  # Should show: cargo 1.7x or newer
```

**Build difftest binary:**

```bash
cd aptos-move/framework/formal/difftest
cargo build -p move-lean-difftest --release
```

Expected: ~3 minutes to compile. Binary at `target/release/move-lean-difftest`.

### 1.5 Run Full Verification (~5 minutes)

**All three stacks in one command:**

```bash
cd aptos-move/framework/formal
./audit/verify-ca.sh --op register --stack lean
./audit/verify-ca.sh --op register --stack move-prover
```

**Expected output:**

```
✅ Lean verification passed (register)
   Build time: 2.8s

✅ Move Prover verification passed (register)
   Compile time: 1.1s
   VCs generated: 0 (blocked on ristretto255 patches)
```

**If all green:** You're set up! Jump to [§2 Deep Dive](#2-deep-dive-verification-stack-45-minutes) to understand what you just ran.

**If red:** See [§4 Troubleshooting](#4-troubleshooting).

---

## 2. Deep Dive: Verification Stack (45 minutes)

### 2.1 Architecture Overview (10 minutes)

CA verification uses **three independent proof stacks** bound by differential testing:

```
┌────────────────────────────────────────────────────────────┐
│                    CA Formal Verification                  │
├────────────────────────────────────────────────────────────┤
│                                                            │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐    │
│  │  Lean Proofs │  │ Move Prover  │  │   Difftest   │    │
│  │              │  │              │  │              │    │
│  │  Bytecode-   │  │  MSL specs   │  │  VM ↔ Model  │    │
│  │  level crypto│  │  for state   │  │  binding     │    │
│  │  verification│  │  invariants  │  │              │    │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘    │
│         │                 │                 │             │
│         └─────────────────┴─────────────────┘             │
│                           │                               │
│                    Move VM (ground truth)                 │
└────────────────────────────────────────────────────────────┘
```

**Why three stacks?**

1. **Lean:** Proves crypto correctness at bytecode level (`verify_*_proof` functions). Move Prover can't reason about elliptic curves or Fiat-Shamir transforms.

2. **Move Prover:** Proves state-layer properties (balance conservation, abort conditions, invariants). Inherits upstream Aptos Framework specs (~12k lines) compositionally.

3. **Difftest:** Empirically checks that both Lean and Move Prover model the same VM as production. Catches model drift.

**Key insight:** We don't mix proof terms. Each stack is independent; difftest is the binding.

### 2.2 Lean Stack Deep Dive (15 minutes)

**What Lean proves:**

For each of 5 operations (register, withdraw, transfer, normalize, rotate):

- **EvalEquiv theorem:** Bytecode execution is semantically equivalent to a mathematical specification
- **Functional correctness:** The crypto verifier accepts iff the sigma-protocol predicate holds
- **Error paths:** All rejection cases are precisely characterized

**Example: Registration**

```lean
-- Theorem statement (simplified)
theorem registration_eval_equiv_functional_sim
    (env : ModuleEnvironment)
    (publicKey : RistrettoPoint)
    (proof : SchnorRegistrationProof)
    : MoveModel.eval env registrationBytecode [publicKey, proof] =
      if verifySchnorrProof publicKey proof
      then .returned [] emptyState
      else .aborted SIGMA_PROTOCOL_VERIFY_FAILED
```

**File structure:**

```
lean/MovementFormal/Experimental/ConfidentialAsset/
├── Registration/
│   ├── EvalEquivRebuild.lean      # Main theorem (197 theorems, 3330 lines)
│   ├── FunctionalSim.lean         # Mathematical spec
│   └── Phase6Composition.lean     # Entry-to-exit composition
├── Withdrawal/
│   ├── EvalEquiv.lean             # 15-instr proof
│   └── Phase6Composition.lean
├── Transfer/
│   ├── EvalEquiv.lean             # 24-instr proof (most complex)
│   └── Phase6Composition.lean
├── Normalization/
│   ├── EvalEquiv.lean             # 14-instr proof (simplest)
│   └── Phase6Composition.lean
└── Rotation/
    ├── EvalEquiv.lean             # 15-instr proof
    └── Phase6Composition.lean
```

**Architecture patterns:**

1. **Symbolic state:** Define state as named fields, not chained frames
2. **Per-PC step theorems:** Prove each instruction once, parametrically
3. **@[irreducible]:** Prevent unfolding during elaboration (performance)
4. **Array.get?:** Avoid bound proofs in theorem statements

See `PROOF_PATTERNS_WORKED_EXAMPLE.md` for complete worked example.

**Build times:**

- Per-file incremental: ~0.5–3s
- Full CA tree cold build: ~4s
- Budget: <3 min per file, <10 min full tree

**Checking axioms:**

```bash
cd lean
lake env lean <<EOF
import MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquivRebuild
#print axioms registration_eval_equiv_functional_sim
EOF
```

Expected: Only documented crypto axioms (Ristretto255, SHA, Bulletproofs).

### 2.3 Move Prover Stack Deep Dive (10 minutes)

**What Move Prover proves:**

- **State invariants:** `ConfidentialAssetStore` consistency
- **Balance conservation:** Encrypted balance sum unchanged
- **Abort conditions:** All error paths documented in `aborts_if` clauses
- **Frame conditions:** Only authorized state mutations

**MSL spec example:**

```move
spec deposit_to_internal {
    // Preconditions
    requires len(store.pending_balance) > 0;
    requires len(pending_chunk) == CHUNK_SIZE;

    // Postconditions
    ensures len(store.pending_balance) == old(len(store.pending_balance));
    ensures store.actual_balance == old(store.actual_balance);

    // Abort conditions
    aborts_if len(store.pending_balance) == 0 with ERROR_EMPTY_BALANCE;
    aborts_if len(pending_chunk) != CHUNK_SIZE with ERROR_INVALID_CHUNK;

    // Frame
    modifies global<ConfidentialAssetStore>(addr);
}
```

**File structure:**

```
aptos-experimental/sources/confidential_asset/
├── confidential_asset.move             # Entry points
├── confidential_balance.move           # Arithmetic
├── confidential_proof.move             # Proof verification
├── ristretto255_twisted_elgamal.move   # Crypto layer

# Specs (sidecar files)
├── confidential_asset.spec.move        # 15 entry-point specs
├── confidential_balance.spec.move      # Balance invariants
├── confidential_proof.spec.move        # Opaque crypto boundary
└── confidential_gas_e2e_helpers.spec.move  # Test helpers
```

**Current status:**

- **Phase 2:** ✅ Internal function specs landed, blocked on ristretto255 patches
- **Phase 3:** ✅ Store-only operation specs landed, blocked on patches
- **Phase 5:** ✅ Entry-point specs landed, blocked on patches

**Running Move Prover:**

```bash
cd aptos-move/framework/formal
movement move prove \
  --package-dir ../aptos-experimental \
  --filter register_internal \
  --vc-timeout 120 \
  --skip-fetch-latest-git-deps
```

Expected: Compilation succeeds, 0 VCs (blocked until ristretto255 patches land upstream).

### 2.4 Difftest Stack Deep Dive (10 minutes)

**What difftest checks:**

For each corpus row:
1. Run real Move VM on input
2. Capture output (return value or abort code)
3. Run Lean bytecode evaluator on same input
4. Compare: outputs must match exactly

**Corpus inventory:**

```
difftest/inventory/confidential_assets.md
```

Current: 87 rows across registration, balance, proof, asset layers.

**Running difftest:**

```bash
# From repo root
./aptos-move/framework/formal/difftest.sh
```

Or per-suite:

```bash
./aptos-move/framework/formal/difftest.sh --suite confidential_asset
```

**Adding a corpus row:**

```bash
cd aptos-move/framework/formal
./scripts/manage_difftest_corpus.sh add \
  --operation transfer \
  --case sender_frozen \
  --description "Transfer from frozen sender account"
```

Generates TODOs for Rust oracle and Lean mapping.

---

## 3. Your First Contribution (30 minutes)

### 3.1 Pick a Starter Task

**Recommended first contributions:**

1. **Add a difftest corpus row** (easiest, ~1 hour)
   - Pick an error case not yet covered
   - Add Rust oracle generation
   - Add Lean mapping
   - Verify: `./difftest.sh --suite confidential_asset`

2. **Strengthen an MSL spec** (intermediate, ~2 hours)
   - Pick a function in `confidential_asset.spec.move`
   - Add missing `ensures` clauses or `aborts_if` conditions
   - Run: `movement move prove --filter <function>`
   - Document in PR

3. **Prove a sub-lemma in Lean** (advanced, ~4 hours)
   - Pick a `sorry` in Phase 6 composition theorems
   - Prove one PC-chaining step
   - Verify: `lake build MovementFormal.Experimental.ConfidentialAsset.<Op>.Phase6Composition`

### 3.2 Starter Task Walkthrough: Add Difftest Row

**Goal:** Add test coverage for "withdraw from frozen account" error path.

**Step 1: Check current coverage**

```bash
cd aptos-move/framework/formal
./scripts/manage_difftest_corpus.sh stats
```

Look for gaps in withdrawal error coverage.

**Step 2: Add corpus row**

```bash
./scripts/manage_difftest_corpus.sh add --interactive
```

Answer prompts:
- Operation: `withdraw`
- Case name: `frozen_account`
- Description: `Withdraw from frozen sender account`
- Skip Lean: `N`

**Step 3: Implement Rust oracle**

Edit: `move-lean-difftest/src/suites/confidential_asset.rs`

```rust
TestCase {
    id: "withdraw_frozen_account".into(),
    oracle_fn: Box::new(|h| {
        // Setup: create account, freeze it
        let account = h.new_account();
        h.freeze_account(&account);
        
        // Attempt withdraw
        let result = h.run_function(
            &account,
            "confidential_asset",
            "withdraw_to_internal",
            vec![/* args */],
            vec![],
        );
        
        // Expect: abort with FROZEN_ACCOUNT error code
        OracleResult::Aborted(ERROR_ACCOUNT_FROZEN)
    }),
    skip_lean: false,
},
```

**Step 4: Add Lean mapping**

Edit: `lean/MovementFormal/DiffTest/RunnerFuncMappingAux.lean`

```lean
| "withdraw_frozen_account" =>
  some { funcIdx := withdrawalFuncIdx
         env := withdrawalModuleEnv
         cs := { frames := [], current_frame_idx := 0 }
         stack := [/* initial stack for test */]
         ms := { globals := [/* frozen account state */]
                 account_address := testAddress }
       }
```

**Step 5: Run difftest**

```bash
./difftest.sh --suite confidential_asset
```

Expected: New row passes (or shows what needs fixing).

**Step 6: Update inventory status**

```bash
# Edit difftest/inventory/confidential_assets.md
# Change status from "Pending" to "Passing"
```

**Step 7: Create PR**

```bash
git checkout -b add-withdraw-frozen-difftest
git add move-lean-difftest/src/suites/confidential_asset.rs
git add lean/MovementFormal/DiffTest/RunnerFuncMappingAux.lean
git add difftest/inventory/confidential_assets.md
git commit -m "difftest: add withdraw frozen account error path

Add corpus row for withdraw operation when sender account is frozen.
Expects abort with ERROR_ACCOUNT_FROZEN (196617).

Coverage: Withdrawal error paths 4/7 → 5/7
"
```

Use PR template: `.github/PULL_REQUEST_TEMPLATE_CA_VERIFICATION.md`

### 3.3 Getting Your PR Reviewed

**Pre-submit checklist:**

```bash
# Run pre-commit checks
./scripts/setup_git_hooks.sh install
git commit  # Hooks run automatically

# Or manually:
./scripts/run_comprehensive_validation.sh --quick
```

**What reviewers look for:**

1. **Difftest:** Does the new row pass?
2. **Coverage:** Does this close a documented gap?
3. **Documentation:** Is inventory updated?
4. **Clean build:** Does CI stay green?

**Typical review time:** 1-2 days.

---

## 4. Troubleshooting

### 4.1 Lean Build Fails

**Symptom:** `lake build` errors with "unknown package 'Mathlib'"

**Fix:**

```bash
cd aptos-move/framework/formal/lean
lake exe cache get!
lake clean
lake build
```

---

**Symptom:** Build takes >15 minutes

**Cause:** Mathlib cache not fetched, compiling from source.

**Fix:** Abort (`Ctrl+C`), run `lake exe cache get!`, retry.

---

**Symptom:** `heartbeat exceeded` errors

**Cause:** Old Lean version or missing workarounds.

**Fix:** Check `lean-toolchain` shows `leanprover/lean4:v4.24.0`. Verify with:

```bash
lean --version  # Must show 4.24.0
```

If wrong version, reinstall elan:

```bash
elan self update
elan default leanprover/lean4:v4.24.0
```

### 4.2 Move Prover Fails

**Symptom:** `expected at most version 4.11.2 but found 4.14.x for z3`

**Cause:** Homebrew Z3 installed instead of prover-specific version.

**Fix:**

```bash
# Uninstall Homebrew Z3
brew uninstall z3

# Reinstall via Movement CLI
movement update prover-dependencies --assume-yes

# Verify
$Z3_EXE --version  # Must show 4.11.2
```

---

**Symptom:** `Boogie not found`

**Cause:** `BOOGIE_EXE` not in environment.

**Fix:**

```bash
export BOOGIE_EXE=$HOME/.local/bin/boogie
export DOTNET_ROOT=$HOME/.dotnet

# Add to ~/.bashrc or ~/.zshrc for persistence
```

### 4.3 Difftest Fails

**Symptom:** `Rust oracle generation failed: cannot find -lmove_vm`

**Cause:** Rust workspace not built.

**Fix:**

```bash
cd aptos-core  # Repo root
cargo build -p move-lean-difftest --release
```

---

**Symptom:** Lean difftest executable not found

**Cause:** Difftest target not built.

**Fix:**

```bash
cd aptos-move/framework/formal/lean
lake build difftest
```

---

## 5. Where to Get Help

### 5.1 Documentation

**Start here:**
- `README.md` — High-level overview
- `CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md` — Master plan
- `PROOF_PATTERNS_WORKED_EXAMPLE.md` — Lean proof walkthrough
- `MOVE_PROVER_READINESS_CHECKLIST.md` — MSL spec guide

**Guides:**
- `PHASE_1_SINGLETON_BRANCH_STARTER_KIT.md` — Registration implementation
- `PHASE_6_IMPLEMENTATION_GUIDE.md` — Composition theorems
- `MAINTENANCE_GUIDE.md` — Ongoing care and feeding

### 5.2 Scripts

**Essential automation:**

```bash
# Full validation suite
./scripts/run_comprehensive_validation.sh --quick

# Axiom drift check
./scripts/check_axioms.sh --diff

# Git hooks (pre-commit checks)
./scripts/setup_git_hooks.sh install

# Difftest corpus management
./scripts/manage_difftest_corpus.sh stats
```

### 5.3 Verification Commands

**One-command checks:**

```bash
# Verify one operation (Lean + Move Prover + difftest)
./audit/verify-ca.sh --op register

# Verify specific stack
./audit/verify-ca.sh --op transfer --stack lean

# Full verification matrix
./audit/verify-ca.sh
```

### 5.4 Quick Reference

**Lean:**
```bash
lake build                                    # Full tree
lake build MovementFormal.<Module>            # Single module
lake env lean _check_axioms.lean              # Check axioms
```

**Move Prover:**
```bash
movement move prove \
  --package-dir ../aptos-experimental \
  --filter <function> \
  --vc-timeout 120
```

**Difftest:**
```bash
./difftest.sh                                 # All suites
./difftest.sh --suite confidential_asset      # One suite
```

**Git hooks:**
```bash
./scripts/setup_git_hooks.sh install          # Install
git commit --no-verify                        # Skip hooks (not recommended)
```

### 5.5 Common Patterns

**Finding files:**
```bash
# Lean proof for an operation
lean/MovementFormal/Experimental/ConfidentialAsset/<Op>/EvalEquiv.lean

# MSL spec for a module
aptos-experimental/sources/confidential_asset/<module>.spec.move

# Difftest inventory
difftest/inventory/confidential_assets.md
```

**Reading verification status:**
```bash
# Overall progress
./audit/verify-ca.sh --coverage

# Phase status
cat CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md | grep -A 5 "Progress tracker"

# Axiom count
./scripts/check_axioms.sh
```

---

## Next Steps

After completing this guide, you should be able to:

✅ Build all three verification stacks locally  
✅ Run the full verification suite  
✅ Understand the architecture and file layout  
✅ Make your first contribution (difftest row, MSL spec, or Lean proof)  

**Recommended next steps:**

1. **Read the worked example:** `PROOF_PATTERNS_WORKED_EXAMPLE.md` (30 min)
2. **Review a PR:** Find recent verification PRs, see what good contributions look like
3. **Pick a task:** Check PHASE_*_STATUS.md files for open work items
4. **Ask questions:** Team is friendly, no question too basic

**Welcome to CA formal verification!** 🎉

---

**Appendix: Full Setup Checklist**

Use this checklist to verify your setup is complete:

- [ ] Lean 4.24.0 installed (`lean --version`)
- [ ] Mathlib cache fetched (`lake exe cache get!`)
- [ ] Lean builds succeed (`lake build`, <5 min)
- [ ] Movement CLI installed (`movement --version`)
- [ ] Prover dependencies installed (`$Z3_EXE --version` → 4.11.2)
- [ ] Move Prover smoke test passes (`movement move prove --package-dir ../move-stdlib --filter vector`)
- [ ] Rust toolchain installed (`cargo --version`)
- [ ] Difftest builds (`cargo build -p move-lean-difftest`)
- [ ] Difftest runs (`./difftest.sh`)
- [ ] verify-ca.sh works (`./audit/verify-ca.sh --op register --stack lean`)
- [ ] Git hooks installed (`./scripts/setup_git_hooks.sh install`)
- [ ] Documentation readable (open `README.md`, `CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md`)

**Time to complete:** ~2 hours for full setup + reading this guide.

**Questions?** See §5 Where to Get Help.
