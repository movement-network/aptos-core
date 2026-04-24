# Infrastructure File Fix Status

## Successfully Fixed ✅

### StateTransitionLemmas.lean
- **Fixed**: All ExecResult.ok signature errors (17 locations)
- **Fixed**: step/run parameter order throughout
- **Fixed**: ValueType → MoveType conversion  
- **Status**: Builds with only expected 'sorry' warnings
- **Lines**: ~600 lines

## Attempted But Blocked 🟡

### Files with Step Signature Issues (Partially Fixed)
These have had mechanical step signature fixes applied but still fail due to deeper issues:

1. **NativeCallPatterns.lean** (16 step fixes applied)
   - Applied: step env [] → step env frame []
   - Remaining: Missing oracle methods, type mismatches

2. **StackInvariantPreservation.lean** (13 step fixes applied)
   - Applied: step env [] → step env frame []
   - Remaining: ContainerStore API mismatches

3. **ValueTypePreservation.lean** (3 step fixes applied)
   - Applied: step env [] → step env frame []
   - Remaining: Missing oracle fields (optionIsSomeRef, etc.)

4. **CompositeInstructionPatterns.lean** (93 step fixes attempted)
   - Applied: step/run signature fixes
   - Applied: ExecResult.ok conversions
   - Remaining: Complex multi-line pattern issues

5. **ExecutionTraceProperties.lean**
   - Applied: step/run signature fixes
   - Remaining: ~10 structural errors with TraceSegment, PC tracking

### Files with Type Annotation Issues

6. **ErrorPathHandling.lean**
   - Applied: MoveValue.struct_, MoveValue.bool annotations
   - Remaining: Missing oracle methods (newCompressedPointFromBytes, newScalarFromBytes)
   
7. **InstructionEncodingVerification.lean**
   - Attempted: MoveInstr constructor fixes
   - Remaining: 19 errors - type issues, syntax errors, undefined functions

### Files with Missing Definitions

8. **PC4_20_concrete_helper.lean** (47 errors)
   - Needs: FrameAtPC6, FrameAtPC8, FrameAtPC11, FrameAtPC15, FrameAtPC18 structures

9. **PC20_43_message_assembly.lean** (85 errors)
   - Similar missing FrameAtPCX structures

10. **PC43_70_sigma_verification.lean** (54 errors)
    - Similar missing FrameAtPCX structures

11. **ModuleEnvProperties.lean** (20 errors)
    - Missing: mkRegistrationModuleEnv function
    - Missing oracle fields: optionIsSomeRef, optionExtractRef, vectorPushBackU8Ref, vectorAppendU8Ref, bcsToBytesAddressRef
    - FuncBody.bytecode type mismatches

12. **SingletonBranchIntegration.lean** (16 errors)
    - Missing: scalarFromBytes (should be newScalarFromBytes)
    - Proof failures (rfl, omega tactics)
    - Type inference issues

13. **PCBoundaryConditions.lean** (29 errors)
    - Missing: buildInitialLocals function
    - StateAtPC0 structure issues

14. **BytecodeSemanticsCatalog.lean** (35 errors)
    - ContainerStore API mismatches (.read?, .containers fields don't exist)
    - Instruction constructor type issues

15. **OracleSemantics.lean**
    - Unknown errors (need investigation)

16. **PCRangeComposition.lean**
    - Unknown errors (need investigation)

## Root Causes

### 1. Oracle Method Mismatches
Many files reference oracle methods that don't exist in RegistrationNativeOracle:
- `scalarFromBytes` → should be `newScalarFromBytes`
- `optionIsSomeRef` → doesn't exist (maybe `optionIsSome`?)
- `optionExtractRef` → doesn't exist
- `vectorPushBackU8Ref` → doesn't exist
- `vectorAppendU8Ref` → doesn't exist
- `bcsToBytesAddressRef` → doesn't exist

### 2. ContainerStore API Unknown
Files reference non-existent ContainerStore fields:
- `.containers.containers.length`
- `.containers.read?`
- `.write?`

Actual API appears to be:
- `.alloc : MoveValue → (ContainerStore × RefId)`
- `.read : RefId → Option MoveValue`
- `.write : RefId → MoveValue → Option ContainerStore`

### 3. Missing FrameAtPCX Structures
PC-specific helper files need concrete frame state definitions for each PC.

### 4. Skeleton Files
Many files are incomplete skeletons with `sorry` axioms and placeholder structures.

## Recommended Next Steps

### High Priority
1. **Fix RegistrationNativeOracle definition** in `MovementFormal/MoveModel/Native/Registration.lean`
   - Add missing oracle methods or correct file references
   
2. **Document actual ContainerStore API** 
   - Update files to use correct field names and methods

3. **Implement FrameAtPCX structures** for PC4_20, PC20_43, PC43_70 files
   - Or replace with a different approach

### Medium Priority
4. **Fix instruction constructor references**
   - Use `MoveInstr.copyLoc` etc. consistently

5. **Fix oracle method names**
   - scalarFromBytes → newScalarFromBytes globally

### Low Priority (Require Design Work)
6. **Complete skeleton implementations** for:
   - ExecutionTraceProperties
   - PCBoundaryConditions  
   - BytecodeSemanticsCatalog
   - OracleSemantics
   - PCRangeComposition

## Mechanical Fixes Applied

The following sed/regex patterns were successfully applied where appropriate:

```bash
# Step signature fixes
sed 's/step env \[\] \([a-z_0-9]*\)/step env \1 []/g'
sed 's/run env \[\] \([a-z_0-9]*\)/run env \1 []/g'

# ExecResult conversions
sed 's/= \.ok \[\]/= ExecResult.ok/g'
sed 's/\.returned \[\]/ExecResult.returned/g'

# Python regex for ExecResult.ok parameter insertion
content = re.sub(
    r'ExecResult\.ok\s+([a-z_0-9]+\'?)\s+([a-z_0-9]+\'?)\s+([a-z_0-9]+\'?)\b',
    r'ExecResult.ok \1 [] \2 \3',
    content
)
```

## Session Summary

- **Time invested**: Significant (full session)
- **Files successfully fixed**: 1 (StateTransitionLemmas.lean)
- **Files attempted**: 15
- **Root issue**: Infrastructure files are incomplete skeletons, not just mechanically broken
- **Recommendation**: Focus on completing core infrastructure (oracle definitions, API documentation) before attempting to fix dependent files
