# Developer Workflow Guide - Daily development workflows for CA formal verification

**Last updated:** 2026-04-23

Practical guide to daily development workflows for contributors working on CA formal verification.

## Quick Start

### First-Time Setup
```bash
curl https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh -sSf | sh -s -- -y
elan default v4.24.0
cd aptos-move/framework/formal/lean && lake exe cache get && cd ..
./scripts/run_verification_suite.sh --quick
```

## Daily Workflow

### Morning: Pull & Sync
```bash
git pull origin movement
cd lean && lake exe cache get && cd ..
./scripts/quick_fix.sh --dry-run
./scripts/run_verification_suite.sh --quick
```

### During Development
```bash
# Watch mode (auto-rebuild on save)
./scripts/watch_verification.sh --operation register --stack lean

# Manual iteration
cd lean && lake build MovementFormal.Experimental.ConfidentialAsset.<Module>
```

### End of Day: Verify & Commit
```bash
./scripts/run_verification_suite.sh
./scripts/diff_verification_baseline.sh
git commit -m "feat: description"
```

## Common Tasks

### Add New Theorem
```bash
$EDITOR lean/MovementFormal/Experimental/ConfidentialAsset/<Op>/EvalEquiv.lean
cd lean && lake build MovementFormal.Experimental.ConfidentialAsset.<Op>.EvalEquiv
./audit/verify-ca.sh --op <op> --stack lean
```

### Update Axiom Baseline
```bash
./scripts/check_axioms.sh > audit/axiom-baseline.txt
$EDITOR audit/AXIOM_INVENTORY.md  # Document rationale
git add audit/axiom-baseline.txt audit/AXIOM_INVENTORY.md
git commit -m "axioms: add XYZ for <reason>"
```

### Eliminate Sorry
```bash
grep -r "sorry" lean/MovementFormal/Experimental/ConfidentialAsset/
$EDITOR path/to/file.lean  # Replace sorry with proof
cd lean && lake build
./scripts/diff_verification_baseline.sh  # Verify decrease
```

## Testing Workflow

```bash
# Quick (2 min)
./scripts/run_verification_suite.sh --quick

# Standard (5 min)
./scripts/run_verification_suite.sh

# Comprehensive (15 min)
./scripts/run_verification_suite.sh --comprehensive

# Per-operation
./audit/verify-ca.sh --op register
```

## Productivity Tips

1. **Watch mode:** `./scripts/watch_verification.sh --operation <op>`
2. **Work incrementally:** Start with `sorry`, prove pieces
3. **Batch similar work:** Group axiom reduction, sorry elimination
4. **Generate baselines:** Track progress across sessions
5. **Use smoke tests:** Fast feedback before committing

## Pre-Commit Checklist

- [ ] `cd lean && lake build` passes
- [ ] `./scripts/run_verification_suite.sh --quick` passes
- [ ] No new sorries (or documented)
- [ ] No axiom drift (or documented in AXIOM_INVENTORY.md)
- [ ] Documentation updated (CLAIMS.md, etc.)
- [ ] Descriptive commit message

## Getting Help

**Quick help:** `./scripts/<script>.sh --help`

**Documentation:**
- `FAQ.md`
- `DEBUGGING_VERIFICATION_FAILURES_GUIDE.md`
- `TROUBLESHOOTING_GUIDE.md`
- `AUTOMATION_INFRASTRUCTURE_GUIDE.md`

**Key commands:**
```bash
./scripts/run_verification_suite.sh --quick
./scripts/watch_verification.sh
./scripts/quick_fix.sh
./scripts/diff_verification_baseline.sh
```

Happy verifying! 🎯
