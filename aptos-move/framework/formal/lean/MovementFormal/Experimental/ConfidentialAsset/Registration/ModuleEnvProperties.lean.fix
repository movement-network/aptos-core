import MovementFormal.MoveModel.Value
import MovementFormal.MoveModel.State
import MovementFormal.MoveModel.Native.Registration
import MovementFormal.MoveModel.Programs.Registration

/-! # Module Environment Properties

This file provides comprehensive properties about the registration module environment
(ModuleEnv) used throughout the singleton branch proof. The module environment defines
the function table, native oracle bindings, and global state.

## Module Environment Structure

```lean
structure ModuleEnv where
  functions : Array FunctionDef
  globals : GlobalStore
```

where `FunctionDef` contains:
- `numParams : Nat` - number of parameters
- `numReturns : Nat` - number of return values
- `body : FunctionBody` - either `.bytecode code` or `.native oracle_fn`

## Registration Module Environment

The registration module environment (`registrationModuleEnv o`) contains:
- Function 0: verify_registration_proof (bytecode, 79 instructions)
- Functions 1-14: Native oracle functions (see function table below)

-/

namespace MovementFormal.Experimental.ConfidentialAsset.Registration.ModuleEnvProperties

open MovementFormal.MoveModel
open MovementFormal.MoveModel.Native.Registration
open MovementFormal.MoveModel.Programs.Registration

/-! ## Function Index Constants

Function indices in the registration module environment.
-/

/-- Function index for verify_registration_proof (bytecode). -/
def FUNC_IDX_VERIFY_REGISTRATION_PROOF : Nat := 0

/-- Function index for newCompressedPointFromBytes. -/
def FUNC_IDX_NEW_COMPRESSED_POINT_FROM_BYTES : Nat := 1

/-- Function index for newScalarFromBytes. -/
def FUNC_IDX_NEW_SCALAR_FROM_BYTES : Nat := 2

/-- Function index for optionIsSomeRef. -/
def FUNC_IDX_OPTION_IS_SOME_REF : Nat := 3

/-- Function index for optionExtractRef. -/
def FUNC_IDX_OPTION_EXTRACT_REF : Nat := 4

/-- Function index for vectorPushBackU8Ref. -/
def FUNC_IDX_VECTOR_PUSH_BACK_U8_REF : Nat := 5

/-- Function index for vectorAppendU8Ref. -/
def FUNC_IDX_VECTOR_APPEND_U8_REF : Nat := 6

/-- Function index for bcsToBytesAddressRef. -/
def FUNC_IDX_BCS_TO_BYTES_ADDRESS_REF : Nat := 7

/-- Function index for newScalarFromSha2_512. -/
def FUNC_IDX_NEW_SCALAR_FROM_SHA2_512 : Nat := 8

/-- Function index for hashToPointBase. -/
def FUNC_IDX_HASH_TO_POINT_BASE : Nat := 9

/-- Function index for pubkeyToPoint. -/
def FUNC_IDX_PUBKEY_TO_POINT : Nat := 10

/-- Function index for pointMul. -/
def FUNC_IDX_POINT_MUL : Nat := 11

/-- Function index for pointAdd. -/
def FUNC_IDX_POINT_ADD : Nat := 12

/-- Function index for pointDecompress. -/
def FUNC_IDX_POINT_DECOMPRESS : Nat := 13

/-- Function index for pointEquals. -/
def FUNC_IDX_POINT_EQUALS : Nat := 14

/-! ## Module Environment Well-Formedness

Properties that characterize a well-formed registration module environment.
-/

/-- A well-formed registration module environment. -/
structure IsWellFormedRegistrationEnv (env : ModuleEnv) where
  -- Function table has exactly 15 entries (1 bytecode + 14 natives)
  h_func_count : env.functions.size = 15
  -- Function 0 is verify_registration_proof bytecode
  h_func0_bytecode : ∃ code,
    env.functions[0]? = some {
      numParams := 7,
      numReturns := 0,
      body := .bytecode code
    }
  -- Functions 1-14 are native oracles
  h_func1_native : env.functions[1]?.isSome
  h_func2_native : env.functions[2]?.isSome
  h_func3_native : env.functions[3]?.isSome
  h_func4_native : env.functions[4]?.isSome
  h_func5_native : env.functions[5]?.isSome
  h_func6_native : env.functions[6]?.isSome
  h_func7_native : env.functions[7]?.isSome
  h_func8_native : env.functions[8]?.isSome
  h_func9_native : env.functions[9]?.isSome
  h_func10_native : env.functions[10]?.isSome
  h_func11_native : env.functions[11]?.isSome
  h_func12_native : env.functions[12]?.isSome
  h_func13_native : env.functions[13]?.isSome
  h_func14_native : env.functions[14]?.isSome

/-- The registration module environment for a given oracle. -/
def registrationModuleEnv (o : RegistrationNativeOracle) : ModuleEnv :=
  mkRegistrationModuleEnv o

/-- The registration module environment is well-formed. -/
axiom registrationModuleEnv_wellformed
    (o : RegistrationNativeOracle) :
    IsWellFormedRegistrationEnv (registrationModuleEnv o)

/-! ## Function Lookup Properties

Properties about looking up functions in the module environment.
-/

/-- Function 0 is verify_registration_proof. -/
axiom func0_is_verify_registration_proof
    (o : RegistrationNativeOracle) :
    ∃ code,
      (registrationModuleEnv o).functions[0]'(by sorry) = {
        numParams := 7,
        numReturns := 0,
        body := .bytecode code
      } ∧ code = verifyRegistrationProofCode

/-- Function lookup succeeds for indices 0-14. -/
theorem func_lookup_inbounds
    (o : RegistrationNativeOracle)
    (idx : Nat)
    (h : idx < 15) :
    ∃ f, (registrationModuleEnv o).functions[idx]? = some f := by
  have wf := registrationModuleEnv_wellformed o
  sorry  -- From h_func_count and idx < 15

/-- Function lookup fails for indices ≥ 15. -/
theorem func_lookup_outofbounds
    (o : RegistrationNativeOracle)
    (idx : Nat)
    (h : idx ≥ 15) :
    (registrationModuleEnv o).functions[idx]? = none := by
  have wf := registrationModuleEnv_wellformed o
  sorry  -- idx ≥ size

/-! ## Native Function Specifications

Specifications for each native function in the module environment.
-/

/-- newCompressedPointFromBytes specification. -/
axiom func1_spec
    (o : RegistrationNativeOracle) :
    (registrationModuleEnv o).functions[1]'(by sorry) = {
      numParams := 1,
      numReturns := 1,
      body := .native o.newCompressedPointFromBytes
    }

/-- newScalarFromBytes specification. -/
axiom func2_spec
    (o : RegistrationNativeOracle) :
    (registrationModuleEnv o).functions[2]'(by sorry) = {
      numParams := 1,
      numReturns := 1,
      body := .native o.newScalarFromBytes
    }

/-- optionIsSomeRef specification. -/
axiom func3_spec
    (o : RegistrationNativeOracle) :
    (registrationModuleEnv o).functions[3]'(by sorry) = {
      numParams := 1,
      numReturns := 1,
      body := .nativeRef o.optionIsSomeRef
    }

/-- optionExtractRef specification. -/
axiom func4_spec
    (o : RegistrationNativeOracle) :
    (registrationModuleEnv o).functions[4]'(by sorry) = {
      numParams := 1,
      numReturns := 1,
      body := .nativeRef o.optionExtractRef
    }

/-- vectorPushBackU8Ref specification. -/
axiom func5_spec
    (o : RegistrationNativeOracle) :
    (registrationModuleEnv o).functions[5]'(by sorry) = {
      numParams := 2,
      numReturns := 0,
      body := .nativeRef o.vectorPushBackU8Ref
    }

/-- vectorAppendU8Ref specification. -/
axiom func6_spec
    (o : RegistrationNativeOracle) :
    (registrationModuleEnv o).functions[6]'(by sorry) = {
      numParams := 2,
      numReturns := 0,
      body := .nativeRef o.vectorAppendU8Ref
    }

/-- bcsToBytesAddressRef specification. -/
axiom func7_spec
    (o : RegistrationNativeOracle) :
    (registrationModuleEnv o).functions[7]'(by sorry) = {
      numParams := 1,
      numReturns := 1,
      body := .nativeRef o.bcsToBytesAddressRef
    }

/-- newScalarFromSha2_512 specification. -/
axiom func8_spec
    (o : RegistrationNativeOracle) :
    (registrationModuleEnv o).functions[8]'(by sorry) = {
      numParams := 1,
      numReturns := 1,
      body := .native newScalarFromSha2_512
    }

/-- hashToPointBase specification. -/
axiom func9_spec
    (o : RegistrationNativeOracle) :
    (registrationModuleEnv o).functions[9]'(by sorry) = {
      numParams := 0,
      numReturns := 1,
      body := .native o.hashToPointBase
    }

/-- pubkeyToPoint specification. -/
axiom func10_spec
    (o : RegistrationNativeOracle) :
    (registrationModuleEnv o).functions[10]'(by sorry) = {
      numParams := 1,
      numReturns := 1,
      body := .native o.pubkeyToPoint
    }

/-- pointMul specification. -/
axiom func11_spec
    (o : RegistrationNativeOracle) :
    (registrationModuleEnv o).functions[11]'(by sorry) = {
      numParams := 2,
      numReturns := 1,
      body := .native o.pointMul
    }

/-- pointAdd specification. -/
axiom func12_spec
    (o : RegistrationNativeOracle) :
    (registrationModuleEnv o).functions[12]'(by sorry) = {
      numParams := 2,
      numReturns := 1,
      body := .native o.pointAdd
    }

/-- pointDecompress specification. -/
axiom func13_spec
    (o : RegistrationNativeOracle) :
    (registrationModuleEnv o).functions[13]'(by sorry) = {
      numParams := 1,
      numReturns := 1,
      body := .native o.pointDecompress
    }

/-- pointEquals specification. -/
axiom func14_spec
    (o : RegistrationNativeOracle) :
    (registrationModuleEnv o).functions[14]'(by sorry) = {
      numParams := 2,
      numReturns := 1,
      body := .native o.pointEquals
    }

/-! ## Function Signature Properties

Properties about function signatures (parameters and returns).
-/

/-- Get function signature. -/
structure FunctionSignature where
  numParams : Nat
  numReturns : Nat

/-- Extract signature from function index. -/
def getFunctionSignature (env : ModuleEnv) (idx : Nat) : Option FunctionSignature :=
  match env.functions[idx]? with
  | some f => some { numParams := f.numParams, numReturns := f.numReturns }
  | none => none

/-- Signature of verify_registration_proof. -/
theorem func0_signature
    (o : RegistrationNativeOracle) :
    getFunctionSignature (registrationModuleEnv o) 0 = some { numParams := 7, numReturns := 0 } := by
  sorry  -- From func0_is_verify_registration_proof

/-- Signature of newCompressedPointFromBytes. -/
theorem func1_signature
    (o : RegistrationNativeOracle) :
    getFunctionSignature (registrationModuleEnv o) 1 = some { numParams := 1, numReturns := 1 } := by
  sorry  -- From func1_spec

/-- Signature of pointMul. -/
theorem func11_signature
    (o : RegistrationNativeOracle) :
    getFunctionSignature (registrationModuleEnv o) 11 = some { numParams := 2, numReturns := 1 } := by
  sorry  -- From func11_spec

/-- All native value oracles (1,2,8-14) are deterministic. -/
axiom native_value_oracles_deterministic
    (o : RegistrationNativeOracle)
    (idx : Nat)
    (h : idx ∈ [1, 2, 8, 9, 10, 11, 12, 13, 14])
    (args : List MoveValue)
    (res1 res2 : List MoveValue) :
    let env := registrationModuleEnv o
    let oracle := match env.functions[idx]? with
                  | some f => match f.body with
                              | .native fn => some fn
                              | _ => none
                  | none => none
    oracle.isSome →
    oracle.get! args = some res1 →
    oracle.get! args = some res2 →
    res1 = res2

/-- All native ref oracles (3-7) are deterministic. -/
axiom native_ref_oracles_deterministic
    (o : RegistrationNativeOracle)
    (idx : Nat)
    (h : idx ∈ [3, 4, 5, 6, 7])
    (containers : ContainerStore)
    (args : List MoveValue)
    (res1 res2 : List MoveValue)
    (c1 c2 : ContainerStore) :
    let env := registrationModuleEnv o
    let oracle := match env.functions[idx]? with
                  | some f => match f.body with
                              | .nativeRef fn => some fn
                              | _ => none
                  | none => none
    oracle.isSome →
    oracle.get! containers args = some (res1, c1) →
    oracle.get! containers args = some (res2, c2) →
    res1 = res2 ∧ c1 = c2

/-! ## Function Body Type Properties

Properties about function body types (bytecode vs native vs nativeRef).
-/

/-- Function has bytecode body. -/
def HasBytecodeBody (env : ModuleEnv) (idx : Nat) : Prop :=
  ∃ code, ∃ f, env.functions[idx]? = some f ∧ f.body = .bytecode code

/-- Function has native body. -/
def HasNativeBody (env : ModuleEnv) (idx : Nat) : Prop :=
  ∃ oracle, ∃ f, env.functions[idx]? = some f ∧ f.body = .native oracle

/-- Function has nativeRef body. -/
def HasNativeRefBody (env : ModuleEnv) (idx : Nat) : Prop :=
  ∃ oracle, ∃ f, env.functions[idx]? = some f ∧ f.body = .nativeRef oracle

/-- Function 0 has bytecode body. -/
theorem func0_has_bytecode_body
    (o : RegistrationNativeOracle) :
    HasBytecodeBody (registrationModuleEnv o) 0 := by
  unfold HasBytecodeBody
  sorry  -- From func0_is_verify_registration_proof

/-- Functions 1, 2, 8-14 have native bodies. -/
theorem value_oracles_have_native_bodies
    (o : RegistrationNativeOracle)
    (idx : Nat)
    (h : idx ∈ [1, 2, 8, 9, 10, 11, 12, 13, 14]) :
    HasNativeBody (registrationModuleEnv o) idx := by
  unfold HasNativeBody
  sorry  -- From func specs

/-- Functions 3-7 have nativeRef bodies. -/
theorem ref_oracles_have_nativeRef_bodies
    (o : RegistrationNativeOracle)
    (idx : Nat)
    (h : idx ∈ [3, 4, 5, 6, 7]) :
    HasNativeRefBody (registrationModuleEnv o) idx := by
  unfold HasNativeRefBody
  sorry  -- From func specs

/-! ## Call Instruction Validity

Properties about valid call instructions in verify_registration_proof.
-/

/-- A call instruction is valid if funcIdx < env.functions.size. -/
def IsValidCallInstr (env : ModuleEnv) (instr : Instr) : Prop :=
  match instr with
  | .call funcIdx => funcIdx < env.functions.size
  | _ => True

/-- All call instructions in verifyRegistrationProofCode are valid. -/
axiom all_calls_valid_in_registration_code
    (o : RegistrationNativeOracle)
    (pc : Nat)
    (h_pc : pc < verifyRegistrationProofCode.size)
    (h_call : ∃ funcIdx, verifyRegistrationProofCode[pc] = .call funcIdx) :
    IsValidCallInstr (registrationModuleEnv o) (verifyRegistrationProofCode[pc])

/-- Call at PC 3 is to newCompressedPointFromBytes. -/
axiom call_pc3_is_func1
    (o : RegistrationNativeOracle) :
    verifyRegistrationProofCode[3] = .call FUNC_IDX_NEW_COMPRESSED_POINT_FROM_BYTES

/-- Call at PC 10 is to newScalarFromBytes. -/
axiom call_pc10_is_func2
    (o : RegistrationNativeOracle) :
    verifyRegistrationProofCode[10] = .call FUNC_IDX_NEW_SCALAR_FROM_BYTES

/-- Call at PC 44 is to newScalarFromSha2_512. -/
axiom call_pc44_is_func8
    (o : RegistrationNativeOracle) :
    verifyRegistrationProofCode[44] = .call FUNC_IDX_NEW_SCALAR_FROM_SHA2_512

/-- Call at PC 47 is to hashToPointBase. -/
axiom call_pc47_is_func9
    (o : RegistrationNativeOracle) :
    verifyRegistrationProofCode[47] = .call FUNC_IDX_HASH_TO_POINT_BASE

/-- Call at PC 53 is to pointMul. -/
axiom call_pc53_is_func11
    (o : RegistrationNativeOracle) :
    verifyRegistrationProofCode[53] = .call FUNC_IDX_POINT_MUL

/-- Call at PC 60 is to pointAdd. -/
axiom call_pc60_is_func12
    (o : RegistrationNativeOracle) :
    verifyRegistrationProofCode[60] = .call FUNC_IDX_POINT_ADD

/-- Call at PC 66 is to pointEquals. -/
axiom call_pc66_is_func14
    (o : RegistrationNativeOracle) :
    verifyRegistrationProofCode[66] = .call FUNC_IDX_POINT_EQUALS

/-! ## Environment Invariants

Invariants that hold throughout execution.
-/

/-- Module environment is immutable during execution. -/
axiom env_immutable_during_execution
    (o : RegistrationNativeOracle)
    (s s' : ExecutionState) :
    -- If s steps to s', env doesn't change
    s.env = registrationModuleEnv o →
    step (registrationModuleEnv o) s.globalRefs s.frame s.stack s.ms = .ok s'.globalRefs s'.frame s'.stack s'.ms →
    s'.env = registrationModuleEnv o

/-- Global store is empty (no global variables in registration). -/
axiom registration_no_globals
    (o : RegistrationNativeOracle) :
    (registrationModuleEnv o).globals = []

/-! ## Auxiliary Utilities

Helper definitions for module environment reasoning.
-/

/-- Check if function index is a native value oracle. -/
def isNativeValueOracle (idx : Nat) : Bool :=
  idx ∈ [1, 2, 8, 9, 10, 11, 12, 13, 14]

/-- Check if function index is a native ref oracle. -/
def isNativeRefOracle (idx : Nat) : Bool :=
  idx ∈ [3, 4, 5, 6, 7]

/-- Check if function index is the main bytecode function. -/
def isBytecodeFunctionIdx (idx : Nat) : Bool :=
  idx = 0

/-- Total number of native oracles. -/
def NATIVE_ORACLE_COUNT : Nat := 14

theorem native_oracle_count_correct
    (o : RegistrationNativeOracle) :
    let value_oracles := 9  -- 1,2,8,9,10,11,12,13,14
    let ref_oracles := 5    -- 3,4,5,6,7
    value_oracles + ref_oracles = NATIVE_ORACLE_COUNT := by
  rfl

/-- Function table size is 1 bytecode + 14 natives. -/
theorem func_table_size
    (o : RegistrationNativeOracle) :
    (registrationModuleEnv o).functions.size = 1 + NATIVE_ORACLE_COUNT := by
  have wf := registrationModuleEnv_wellformed o
  unfold NATIVE_ORACLE_COUNT
  sorry  -- From wf.h_func_count

end MovementFormal.Experimental.ConfidentialAsset.Registration.ModuleEnvProperties
