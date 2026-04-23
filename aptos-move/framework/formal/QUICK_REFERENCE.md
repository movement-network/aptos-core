# CA Formal Verification Quick Reference

**Purpose:** Single-page reference for common commands and patterns  
**Print this:** Keep at your desk for quick lookup

---

## Common Commands

### Lean Verification
```bash
# Build single file
cd lean && lake build MovementFormal.Experimental.ConfidentialAsset.Transfer.EvalEquiv

# Build full tree
cd lean && lake build

# Get mathlib cache (REQUIRED before first build)
cd lean && lake exe cache get

# Check axioms
./scripts/check_axioms.sh
```

### Move Prover
```bash
# Verify single function
movement move prove --filter confidential_transfer_internal

# Verify all CA modules
movement move prove --package-dir aptos-move/framework/aptos-experimental
```

### Difftest
```bash
# Run single operation
cd move-lean-difftest && ./difftest.sh --filter transfer

# Run full suite
cd move-lean-difftest && ./difftest.sh --suite confidential_asset
```

### Unified Verification
```bash
# Verify any operation (all 3 stacks)
./audit/verify-ca.sh --op transfer

# Verify specific stack
./audit/verify-ca.sh --op withdraw --stack lean
```

---

## File Locations

### Lean Proofs
```
lean/MovementFormal/Experimental/ConfidentialAsset/
├── Registration/EvalEquivRebuild.lean
├── Normalization/EvalEquiv.lean
├── Withdrawal/EvalEquiv.lean
├── Transfer/EvalEquiv.lean
└── Rotation/EvalEquiv.lean
```

### MSL Specs
```
aptos-experimental/sources/confidential_asset/
├── confidential_asset.spec.move
├── confidential_balance.spec.move
└── confidential_proof.spec.move
```

### Difftest Corpus
```
move-lean-difftest/corpus/confidential_asset/
├── register.json
├── transfer.json
├── withdraw.json
├── normalize.json
└── rotation.json
```

---

## Lean Proof Pattern (3 Steps)

```lean
-- 1. Symbolic state
@[irreducible]
def OpState (pc : Nat) (args...) (locals : Locals) (stack : Stack) : CallFrame

-- 2. Per-PC steps
theorem step_pc0 : step env (OpState 0 ...) cs ms = ... := by
  rw [step_immBorrowLoc_frame]; rfl

-- 3. Top-level theorem
theorem eval_op_eq_run : ... := by
  rw [step_pc0, step_pc1, ..., step_pcN]
  cases oracle; simp; rfl
```

---

## MSL Spec Pattern (4 Parts)

```move
spec operation_internal(...) {
    // 1. Preconditions
    requires !store.frozen;
    
    // 2. Abort conditions
    pragma aborts_if_is_strict;
    aborts_if store.frozen with ETOKEN_IS_FROZEN;
    
    // 3. Postconditions
    ensures sum_balance(...) == old(sum_balance(...)) - amount;
    
    // 4. Frame conditions
    ensures store.encryption_pubkey == old(store.encryption_pubkey);
}
```

---

## Error Codes

| Code | Name | Meaning |
|------|------|---------|
| 65537 | ESIGMA_PROTOCOL_VERIFY_FAILED | Proof verification failed |
| 65538 | EINVALID_PROOF | Malformed proof structure |
| 196613 | ETOKEN_IS_FROZEN | Account frozen |
| 196614 | ENOT_IN_ALLOW_LIST | Not in allow list |

---

## Performance Budgets

| Component | Budget | Typical | Status |
|-----------|--------|---------|--------|
| Per-file Lean | ≤180s | 0.5-3.0s | ✅ |
| Full Lean tree | ≤600s | ~4s | ✅ |
| Per-op MSL | ≤60s | ~1-2s | ✅ |
| Difftest run | ≤180s | ~30s | ✅ |

---

## Common Errors & Fixes

**"Type mismatch in stack"**
→ Stack is LIFO; reverse order

**"Failed to unify Locals"**
→ Forgot locals update after StLoc

**"Build time >3s"**
→ Check: chained state? bound proofs? bare simp?

**"Mathlib taking forever"**
→ Run `lake exe cache get` first

**"Z3 version mismatch"**
→ Use `movement update prover-dependencies`

---

## Keyboard Shortcuts

**VSCode with Lean extension:**
- `Ctrl+Shift+Enter` - Check Lean file
- `Ctrl+Shift+I` - Show info
- `F12` - Go to definition

**Terminal:**
- `Ctrl+R` - Search command history
- `!!` - Repeat last command
- `!$` - Last argument of previous command

---

## Useful Greps

```bash
# Count theorems
grep -r "^theorem " lean/ | wc -l

# Find sorry's
grep -r "sorry" lean/MovementFormal/Experimental/ConfidentialAsset/

# Count spec blocks
grep -r "^spec " aptos-experimental/sources/confidential_asset/ | wc -l

# Find pragma opaque
grep -r "pragma opaque" aptos-experimental/sources/
```

---

## Tool Versions

| Tool | Version | Install |
|------|---------|---------|
| Lean | 4.24.0 | `curl ... \| sh` |
| Lake | (with Lean) | - |
| Z3 | 4.11.2 | `movement update prover-dependencies` |
| Boogie | 3.5.1 | (same) |
| Movement CLI | latest | `curl ... \| bash` |

---

## Automation Scripts

| Script | Purpose | Example |
|--------|---------|---------|
| verify-ca.sh | Unified verification | `./audit/verify-ca.sh --op transfer` |
| generate_test_template.sh | Generate templates | `./scripts/generate_test_template.sh --type lean --op rotation` |
| detect_performance_regression.sh | Performance check | `./scripts/detect_performance_regression.sh --ci` |
| manage_difftest_corpus.sh | Corpus management | `./scripts/manage_difftest_corpus.sh gaps --operation all` |
| quarterly_maintenance.sh | Health checks | `./scripts/quarterly_maintenance.sh` |

---

## Documentation Quick Links

- **Architecture:** CA_ARCHITECTURE_OVERVIEW.md
- **Contributing:** CONTRIBUTING_TO_CA_VERIFICATION.md
- **Lean patterns:** PROOF_PATTERNS_LIBRARY.md
- **MSL patterns:** MSL_SPEC_PATTERN_LIBRARY.md
- **Performance:** PERFORMANCE_OPTIMIZATION_GUIDE.md
- **Phase 1 guide:** PHASE_1_IMPLEMENTATION_GUIDE.md
- **Worked examples:** WITHDRAWAL_PROOF_WORKED_EXAMPLE.md, ROTATION_PROOF_WORKED_EXAMPLE.md

---

## Phase Status Quick View

- Phase 0: ✅ Done
- Phase 1: 🟡 95%
- Phase 4: ✅ Done
- Phase 7: ✅ 98%
- Others: 🟡 In progress

**Next:** Complete Phase 1 singleton branch (~1-2 days)

---

**Print date:** 2026-04-22  
**Keeper:** Development team  
**Update:** Quarterly or when major changes
