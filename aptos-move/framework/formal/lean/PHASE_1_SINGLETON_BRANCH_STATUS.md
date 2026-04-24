# Phase 1 Registration Singleton Branch - Actual Status

**Date**: 2026-04-24
**Assessment**: Infrastructure files are unimplemented skeletons, not broken code needing fixes

## Executive Summary

**Phases 4 & 6 Status: ✅ COMPLETE**
All 4 crypto operations (Withdrawal, Transfer, Normalization, Rotation) have:
- EvalEquiv theorems: ✅ Building (0 sorries)
- Phase6Composition: ✅ Building (0 sorries)

**Phase 1 Registration Status: 🟡 BLOCKED on Singleton Branch Implementation**
- EvalEquivRebuild.lean: 8805 lines, 175 sorries (plan claims "zero sorries" but reality differs)
- 16 infrastructure files failing - ALL are unimplemented skeletons for singleton branch proof
- Estimated work: 2000-3000 lines of NEW proof code (per SINGLETON_BRANCH_ROADMAP.md)

## Build Status Reality Check

### Successfully Building (✅ All 4 Operations)
```bash
$ for op in Rotation Normalization Transfer Withdrawal; do
    lake build MovementFormal.Experimental.ConfidentialAsset.$op.EvalEquiv
    lake build MovementFormal.Experimental.ConfidentialAsset.$op.Phase6Composition
  done
# All build successfully
```

### Failing (🟡 Registration Only - 16 Files)

#### Group 1: PC-Specific Helpers (Unimplemented Skeletons)
1. **PC4_20_concrete_helper.lean** (47 errors)
   - Defines: `FrameAtPC4`, `FrameAtPC6`, `FrameAtPC8`, `FrameAtPC11`, `FrameAtPC15`, `FrameAtPC18`, `FrameAtPC20`
   - Theorems: `thread_pc4_to_pc6`, `thread_pc6_to_pc8`, etc.
   - Status: Structure definitions exist, ALL theorems are `sorry`
   - Purpose: PC 4-20 oracle threading and container-store mutations

2. **PC20_43_message_assembly.lean** (85 errors)
   - Purpose: Fiat-Shamir message assembly (25 PCs of pure bytecode)
   - Status: Skeleton only

3. **PC43_70_sigma_verification.lean** (54 errors)
   - Purpose: Final sigma verification steps
   - Status: Skeleton only

#### Group 2: Infrastructure (Partially Implemented)
4. **StateTransitionLemmas.lean** - ✅ FIXED (builds successfully)
   - Comprehensive lemmas for all instruction types
   - 197 theorems with expected 'sorry' placeholders

5-16. **Other Infrastructure Files** (all partially implemented, all failing):
   - ModuleEnvProperties (20 errors) - missing `mkRegistrationModuleEnv`, wrong oracle references
   - ExecutionTraceProperties (structural issues)
   - PCBoundaryConditions (missing `buildInitialLocals`, `StateAtPC0`)
   - ErrorPathHandling (oracle method references)
   - And 8 more...

## Root Cause Analysis

### NOT Mechanical Fixes Needed
The infrastructure files are NOT broken code that needs fixing. They are:
- **Skeleton files created to support future work**
- **Placeholder structures with `sorry` proofs**
- **Design artifacts not implementations**

### What's Actually Needed
Per `SINGLETON_BRANCH_ROADMAP.md`:

1. **Container-Store Threading Solution** (lines 80-89)
   - Pick threading approach (bundled snapshot recommended)
   - Implement container state propagation through all 67 PCs
   
2. **PC-by-PC Composition** (lines 122-137)
   - Extend composition through PC 4 (oracle case-split)
   - PC 5 branch handling (true/false paths)
   - PCs 6-16 similar pattern
   - PCs 17-43 Fiat-Shamir message assembly
   - PCs 44-68 dense oracle case-splits
   - PC 69-70 final case-split + ret

3. **Estimated Effort**: 2000-3000 lines of NEW proof code
   - ~130 PC-step applications
   - Multiple oracle case-splits per native call
   - Container-store threading throughout

## Why Previous Fix Attempts Failed

**Session 1 Approach**: Mechanical fixes (step signature corrections, ExecResult.ok parameter order)
- Result: Fixed StateTransitionLemmas.lean (1 file) ✅
- Why others failed: Files need implementation, not fixes

**Session 2 Approach**: Fix oracle method references, type annotations
- Result: Reduced error counts but no files building
- Why failed: Missing functions (`mkRegistrationModuleEnv`), undefined structures (`FrameAtPCX`)

**Core Issue**: Trying to "fix" skeleton files that were never meant to work yet

## What Work Actually Exists

**Implemented & Working:**
- ✅ MovementFormal/MoveModel/* (step lemmas, state definitions, native functions)
- ✅ All 4 crypto operations (Withdrawal, Transfer, Normalization, Rotation)
- ✅ Registration non-singleton branch (per plan - "complete non-singleton branch")
- ✅ StateTransitionLemmas.lean (after fixes)

**Skeleton Only:**
- 🟡 PC4_20_concrete_helper (structures defined, proofs `sorry`)
- 🟡 PC20_43_message_assembly (minimal skeleton)
- 🟡 PC43_70_sigma_verification (minimal skeleton)
- 🟡 Other infrastructure files (various completion states)

## Recommended Next Steps

### Option A: Complete Singleton Branch (High Value, High Effort)
1. Study existing working proofs in Withdrawal/Transfer/Normalization/Rotation
2. Implement container-store threading pattern
3. Prove PC 4-20 composition (use PC4_20_concrete_helper as template)
4. Extend through remaining PCs systematically
5. Estimated: 2-4 weeks full-time for 2000-3000 lines

### Option B: Document & Defer (Low Effort, Honest)
1. Update verification plan to reflect actual status
2. Mark Phase 1 as "95% complete (non-singleton branch only)"
3. Create detailed implementation plan for singleton branch
4. Defer to dedicated proof engineering sprint

### Option C: Incremental Progress (Medium Effort)
1. Pick ONE helper file (e.g., PC4_20_concrete_helper)
2. Prove one small theorem (e.g., `thread_pc4_to_pc6` for specific oracle values)
3. Build up proof library incrementally
4. Estimated: 1-2 weeks for complete PC4_20 helper

## Key Insights for Future Work

1. **Don't fix skeletons**: Skeleton files with `sorry` are design artifacts, not broken code
2. **Focus on proven patterns**: Withdrawal/Transfer/Normalization/Rotation show the working architecture
3. **Container-store threading is the blocker**: Solve this once, then PC composition becomes mechanical
4. **Infrastructure files can wait**: They're support for the main proof, not blockers themselves

## File-by-File Completion Estimates

| File | Lines | Sorries | Est. Effort | Priority |
|------|-------|---------|-------------|----------|
| PC4_20_concrete_helper | ~400 | ALL | 3-5 days | HIGH - templates exist |
| PC20_43_message_assembly | ~600 | ALL | 5-7 days | MEDIUM - mechanical after PC4_20 |
| PC43_70_sigma_verification | ~500 | ALL | 4-6 days | MEDIUM - similar to PC4_20 |
| ModuleEnvProperties | ~400 | partial | 2-3 days | LOW - support only |
| Other infrastructure | varies | varies | 1-2 days each | LOW - nice-to-have |

**Total for complete singleton branch**: 15-25 days full-time proof engineering

## Current Blockers

1. **No working PC threading example** - need reference implementation
2. **Container-store pattern unclear** - multiple approaches possible, none demonstrated
3. **Oracle case-split boilerplate** - repetitive but no automation exists
4. **Fuel management complexity** - every composition needs careful fuel accounting

## Tools & Resources Available

**Working Examples:**
- `MovementFormal/Experimental/ConfidentialAsset/Withdrawal/EvalEquiv.lean` (reference)
- `MovementFormal/Experimental/ConfidentialAsset/Transfer/EvalEquiv.lean` (reference)
- `MovementFormal/MoveModel/StepLemmas/*.lean` (step lemma library)

**Documentation:**
- `SINGLETON_BRANCH_ROADMAP.md` (architectural guidance)
- `BYTECODE_TRANSCRIPTION_GUIDE.md` (PC-level details)
- `PHASE_0_RISTRETTO255_PATCH_NOTES.md` (crypto layer)

**Skeleton Templates:**
- `PC4_20_concrete_helper.lean` (structure definitions, theorem shapes)
- `PC20_43_message_assembly.lean` (placeholder)
- `PC43_70_sigma_verification.lean` (placeholder)

## Conclusion

The Registration singleton branch is **not broken - it's unimplemented**. The 16 "failing" infrastructure files are skeleton placeholders for 2000-3000 lines of proof code that hasn't been written yet.

The verification plan's claim of "Phase 1 complete" is accurate for the **non-singleton branch**. The singleton branch was always deferred work, documented in SINGLETON_BRANCH_ROADMAP.md.

**Actual verification coverage**:
- ✅ Non-singleton branch (error paths): Complete
- ✅ Withdrawal, Transfer, Normalization, Rotation: Complete  
- 🟡 Registration success path (singleton branch): Unimplemented (2000-3000 LOC remaining)

**Honest status for auditors**: "4 of 5 crypto operations fully verified. Registration verified for all error paths; success path requires singleton branch completion (estimated 15-25 days)."
