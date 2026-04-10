import AptosFormal.Move.Programs.Core
import AptosFormal.Move.Programs.Vector

/-!
# Module environments

Assembles bytecode programs from `Core` and `Vector` into `ModuleEnv`
values with concrete function index tables.

Two environments are provided:

- `stdModuleEnv` — hand-written programs only (used by `rfl` refinement proofs)
- `realModuleEnv` — adds real compiler-output programs (used by smoke tests)
-/

namespace AptosFormal.Move.Programs

open AptosFormal.Move
open AptosFormal.Move.Native
open AptosFormal.Move.Programs.Core
open AptosFormal.Move.Programs.Vector

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
      sha3_256NativeDesc
    ] }

/-! ## Real compiler module environment

Extends `stdModuleEnv` with programs transcribed from actual
`movement move disassemble` output on `move-stdlib`.

| Index | Function |
|-------|----------|
| 0–20  | Same as `stdModuleEnv` (through `sha3_256_native`) |
| 21    | `realReverseSlice` (compiler output) |
| 22    | `realReverse` (compiler output, calls 21) |
| 23    | `realContains` (compiler output) |
| 24    | `realIndexOf` (compiler output) |
| 25    | `testRealContains` (wrapper, calls 23) |
| 26    | `testRealIndexOf` (wrapper, calls 24) |
| 27    | `testRealReverse` (wrapper, calls 22) |
-/

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
      realReverseSliceDesc,
      realReverseDesc 21,
      realContainsDesc,
      realIndexOfDesc,
      testRealContainsDesc 23,
      testRealIndexOfDesc 24,
      testRealReverseDesc 22
    ] }

end AptosFormal.Move.Programs
