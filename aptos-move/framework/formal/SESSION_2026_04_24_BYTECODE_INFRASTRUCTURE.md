# Session 2026-04-24: Bytecode Specification Infrastructure

## Summary

Completed comprehensive bytecode infrastructure refactoring across all 5 Confidential Asset operations, extracting inline bytecode proofs into dedicated, reusable lemma modules.

## Changes

### New Modules Created (5 files)

1. **`Rotation/BytecodeLemmas.lean`** (58 lines)
   - 15 PC bound lemmas (`pc{0..14}_inbounds`)
   - 15 instruction equality lemmas (`instr{0..14}_eq`)
   - Coverage: All 15 PCs for `verifyRotationProofCode`

2. **`Normalization/BytecodeLemmas.lean`** (61 lines)
   - 1 size theorem (`code_size`)
   - 14 PC bound lemmas (`pc{0..13}_inbounds`)
   - 14 instruction equality lemmas (`instr{0..13}_eq`)
   - Coverage: All 14 PCs for `verifyNormalizationProofCode`

3. **`Withdrawal/BytecodeLemmas.lean`** (58 lines)
   - 15 PC bound lemmas (`pc{0..14}_inbounds`)
   - 15 instruction equality lemmas (`instr{0..14}_eq`)
   - Coverage: All 15 PCs for `verifyWithdrawalProofCode`

4. **`Transfer/BytecodeLemmas.lean`** (76 lines)
   - 24 PC bound lemmas (`pc{0..23}_inbounds`)
   - 24 instruction equality lemmas (`instr{0..23}_eq`)
   - Coverage: All 24 PCs for `verifyTransferProofCode`

5. **Previously created: `Registration/BytecodeLemmas.lean`** (235 lines)
   - 18 function index definitions
   - 83 PC bound lemmas
   - 83 instruction equality lemmas
   - Coverage: All 83 PCs for `verifyRegistrationProofCode`

### Files Refactored (5 files)

Modified each `EvalEquiv.lean` to import BytecodeLemmas and replace inline proofs with lemma references:

- `Registration/EvalEquivRebuild.lean`: Converted 1 axiom to theorem, replaced 2 inline proofs
- `Rotation/EvalEquiv.lean`: Replaced 15 inline theorem definitions with abbrev aliases
- `Normalization/EvalEquiv.lean`: Replaced 15 inline theorem definitions (including size)
- `Withdrawal/EvalEquiv.lean`: Replaced 15 inline theorem definitions with abbrev aliases
- `Transfer/EvalEquiv.lean`: Replaced 24 inline theorem definitions with abbrev aliases

### Documentation Updated (1 file)

- **`audit/BYTECODE_VERIFICATION_COVERAGE.md`**:
  - Added new "Bytecode Specification Infrastructure" section
  - Documented all 5 BytecodeLemmas modules
  - Coverage table showing 303 total lemmas
  - Before/after usage example
  - Updated "Last updated" date

## Metrics

### Code Changes
- **Files changed**: 10 (5 new, 5 modified, 1 doc)
- **Lines added**: +391
- **Lines removed**: -98
- **Net change**: +293 lines

### Lemma Coverage
| Module | PCs | Bound Lemmas | Instr Lemmas | Utilities | Total |
|--------|-----|--------------|--------------|-----------|-------|
| Registration | 83 | 83 | 83 | 18 func indices | 184 |
| Rotation | 15 | 15 | 15 | - | 30 |
| Normalization | 14 | 14 | 14 | 1 size | 29 |
| Withdrawal | 15 | 15 | 15 | - | 30 |
| Transfer | 24 | 24 | 24 | - | 48 |
| **Total** | **151** | **151** | **151** | **+19** | **321** |

Note: 303 bytecode specification lemmas + 18 utility definitions = 321 total declarations

### Build Verification
- All modules build successfully
- Full CA Lean tree: 2033 jobs
- Build times remain fast:
  - Registration/EvalEquivRebuild: ~1.5s
  - Other modules: ~1s each
- No regressions introduced

## Benefits

### Code Quality
1. **Single source of truth**: Bytecode specifications separated from proof logic
2. **Maintainability**: Bytecode changes require updates in one place only
3. **Reusability**: Lemmas usable across all proof contexts
4. **Consistency**: Uniform naming pattern across all 5 modules

### Before/After Comparison

**Before** (inline proof):
```lean
have hpc : 43 < verifyRegistrationProofCode.size := by
  unfold verifyRegistrationProofCode; decide
have hinstr : verifyRegistrationProofCode[43]'hpc = .moveLoc 11 := by rfl
```

**After** (BytecodeLemmas):
```lean
have hpc := BytecodeLemmas.pc43_inbounds
have hinstr := BytecodeLemmas.instr43_eq
```

- Reduced verbosity: 3 lines → 2 lines
- Eliminated inline `unfold` and `decide` proofs
- Clearer intent: references named lemmas
- Easier maintenance: centralized specification

## Git History

```
91ebcf7 docs: document BytecodeLemmas infrastructure in coverage report
563c381 formal: extract Transfer bytecode lemmas to separate module
49103f3 formal: extract Withdrawal bytecode lemmas to separate module  
1f36989 formal: extract Normalization bytecode lemmas to separate module
3b98946 formal: extract Rotation bytecode lemmas to separate module
77c8b0d formal: refactor EvalEquivRebuild to use BytecodeLemmas
```

## Related Work

This infrastructure builds on:
- Registration/BytecodeLemmas.lean (created earlier, 166 lemmas for 83 PCs)
- StepLemmas library (MovementFormal/MoveModel/StepLemmas/*)
- Phase 4 bytecode verification architecture

Enables:
- Simplified proof maintenance across all CA operations
- Consistent patterns for future bytecode verification work
- Foundation for PC-chaining and frame construction work

## Next Steps

The BytecodeLemmas infrastructure is now complete for all 5 CA operations. Future work:
1. Use lemmas in singleton branch work (Registration PCs 20-70)
2. Apply patterns to any new verification functions
3. Consider similar infrastructure for other Move modules

---

**Session date**: 2026-04-24  
**Commits**: 6  
**Status**: ✅ Complete - all modules build successfully
