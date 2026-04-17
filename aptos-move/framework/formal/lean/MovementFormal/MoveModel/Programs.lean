import MovementFormal.MoveModel.Programs.Core
import MovementFormal.MoveModel.Programs.GlobalSmoke
import MovementFormal.MoveModel.Programs.Vector

/-!
# Module environments

Assembles bytecode programs from `Core` and `Vector` into `ModuleEnv`
values with concrete function index tables.

Two environments are provided:

- `stdModuleEnv` — hand-written programs only (used by `rfl` refinement proofs)
- `realModuleEnv` — adds real compiler-output programs (used by smoke tests)
-/

namespace MovementFormal.MoveModel.Programs

open MovementFormal.MoveModel
open MovementFormal.MoveModel.Native
open MovementFormal.MoveModel.Programs.Core
open MovementFormal.MoveModel.Programs.GlobalSmoke
open MovementFormal.MoveModel.Programs.Vector

/-! ## Hand-written module environment

| Index | Function |
|-------|----------|
| 0–7   | Standard natives (from `Native.stdNatives`) |
| 8     | `add_u64` |
| 9     | `max_u64` |
| 10    | `is_zero_u64` |
| 11    | `abs_diff_u64` |
| 12    | `sum_to_n` |
| 13    | `bcs_to_bytes_u64` |
| 14    | `read_via_ref` |
| 15    | `inc_via_ref` |
| 16    | `vec_push_and_len` |
| 17    | `vector_reverse` (hand-written, self-contained) |
| 18    | `vector_contains` (hand-written, self-contained) |
| 19    | `vector_index_of` (hand-written, self-contained) |
| 20    | `hash::sha3_256` (native) |
| 21    | `global_exists_smoke` (`GlobalSmoke`, empty store → `false`) |
| 22    | `global_move_exists_borrow_smoke` (`GlobalSmoke`, publish `7` → read) |
| 23    | `global_move_signed_borrow_smoke` (`GlobalSmoke`, signer-checked publish → read) |
-/

def sha3_256NativeDesc : FuncDesc :=
  { numParams := 1, numReturns := 1, body := .native sha3_256_native }

def stdModuleEnv : ModuleEnv :=
  { constants := #[]
    functions := stdNatives ++ #[
      addU64Desc,
      maxU64Desc,
      isZeroU64Desc,
      absDiffU64Desc,
      sumToNDesc,
      bcsU64Desc,
      readViaRefDesc,
      incViaRefDesc,
      vecPushAndLenDesc,
      vectorReverseDesc,
      vectorContainsDesc,
      vectorIndexOfDesc,
      sha3_256NativeDesc,
      globalExistsFalseDesc,
      globalMoveExistsBorrowDesc,
      globalMoveSignedBorrowDesc
    ] }

/-! ## Real compiler module environment

Extends `stdModuleEnv` with programs transcribed from actual
`movement move disassemble` output on `move-stdlib`.

| Index | Function |
|-------|----------|
| 0–22  | Same as `stdModuleEnv` through `global_move_exists_borrow_smoke` |
| 23–33 | `realReverseSlice` … `vector::singleton` (unchanged indices vs pre–L4-gap fill) |
| 34    | `global_move_signed_borrow_smoke` (signer-checked global smoke; Lean-only tail slot) |
-/

def vectorRemoveDesc : FuncDesc :=
  { numParams := 2, numReturns := 2, body := .native vectorRemove }

def vectorSwapRemoveDesc : FuncDesc :=
  { numParams := 2, numReturns := 2, body := .native vectorSwapRemove }

def vectorAppendDesc : FuncDesc :=
  { numParams := 2, numReturns := 1, body := .native vectorAppend }

def vectorSingletonDesc : FuncDesc :=
  { numParams := 1, numReturns := 1, body := .native vectorSingleton }

def realModuleEnv : ModuleEnv :=
  { constants := #[]
    functions := stdNatives ++ #[
      addU64Desc,
      maxU64Desc,
      isZeroU64Desc,
      absDiffU64Desc,
      sumToNDesc,
      bcsU64Desc,
      readViaRefDesc,
      incViaRefDesc,
      vecPushAndLenDesc,
      vectorReverseDesc,
      vectorContainsDesc,
      vectorIndexOfDesc,
      sha3_256NativeDesc,
      globalExistsFalseDesc,
      globalMoveExistsBorrowDesc,
      realReverseSliceDesc,
      realReverseDesc 23,
      realContainsDesc,
      realIndexOfDesc,
      testRealContainsDesc 25,
      testRealIndexOfDesc 26,
      testRealReverseDesc 24,
      vectorRemoveDesc,
      vectorSwapRemoveDesc,
      vectorAppendDesc,
      vectorSingletonDesc,
      globalMoveSignedBorrowDesc
    ] }

end MovementFormal.MoveModel.Programs
