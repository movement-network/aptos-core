import MovementFormal.MoveModel.Step
import MovementFormal.MoveModel.Programs.StdPrimitives
import MovementFormal.Std.Error
import MovementFormal.Std.BitVector

/-!
# Refinement: move-stdlib bytecode vs. Lean specs

**Source:** `aptos-move/framework/move-stdlib/sources/error.move`, `aptos-move/framework/move-stdlib/sources/bit_vector.move`; programs `MovementFormal.MoveModel.Programs.StdPrimitives`.

Correctness theorems connecting the bytecode programs in
`MoveModel.Programs.StdPrimitives` to the Lean specs in `Std.Error`
and `Std.BitVector`.

## Proof strategy
We build a minimal single-function `ModuleEnv` for each program and prove
correctness via `rfl` — the Lean kernel reduces `eval` fully by definitional
reduction for concrete programs with no loops.

`stdNatives` occupy indices 0–7, so we put the single test function at
index 8 in a fresh env that prepends `stdNatives`.
-/

namespace MovementFormal.Refinement.Std.StdPrimitives

open MovementFormal.MoveModel
open MovementFormal.MoveModel.Native
open MovementFormal.MoveModel.Programs.StdPrimitives
open MovementFormal.Std.Error

-- ── Helper: single-function env with stdNatives prepended ────────────────────

private def singleEnv (desc : FuncDesc) : ModuleEnv :=
  { constants := #[]
    functions := stdNatives ++ #[desc] }

-- stdNatives has exactly 8 entries → our function is at index 8
private def singleIdx : FuncIndex := 8

private abbrev evalSingle (desc : FuncDesc) (args : List MoveValue) (fuel : Nat) :=
  eval (singleEnv desc) singleIdx args fuel

/-! ─────────────────────────────────────────────────────────────────────────
## std::error::canonical

`canonical(cat, reason) = (cat <<< 16) ||| reason`

The bytecode: ldU64 cat / ldU8 16 / shl / copyLoc 0 / bitOr / ret
reduces definitionally for any concrete `cat` and `reason`.

We prove a **schematic** theorem for all UInt64 values by `rfl`:
the bytecode trace is a finite unrolling with no branching.
────────────────────────────────────────────────────────────────────────── -/

/-- `errorCanonicalDesc` computes `canonical cat reason` (matches VM `bitOr`). -/
theorem errorCanonical_refines (cat reason : UInt64) :
    evalSingle errorCanonicalDesc [.u64 cat, .u64 reason] 20 =
    .returned [.u64 ((cat <<< 16) ||| reason)] MachineState.empty := by
  simp only [evalSingle, singleEnv, singleIdx, eval, Array.size,
             stdNatives, errorCanonicalDesc, errorCanonicalCode]
  rfl

/-- All 13 category wrappers refine `canonical`. -/
theorem errorCategory_refines (cat reason : UInt64) :
    evalSingle (mkErrDesc cat) [.u64 reason] 20 =
    .returned [.u64 ((cat <<< 16) ||| reason)] MachineState.empty := by
  simp only [evalSingle, singleEnv, singleIdx, eval, Array.size,
             stdNatives, mkErrDesc, mkErrCode]
  rfl

-- Concrete instances matching the Lean spec functions
theorem errorInvalidArgument_refines (r : UInt64) :
    evalSingle errorInvalidArgumentDesc [.u64 r] 20 =
    .returned [.u64 (invalid_argument r)] MachineState.empty := by
  simp [invalid_argument, canonical, errorInvalidArgumentDesc]
  exact errorCategory_refines 0x1 r

theorem errorOutOfRange_refines (r : UInt64) :
    evalSingle errorOutOfRangeDesc [.u64 r] 20 =
    .returned [.u64 (out_of_range r)] MachineState.empty :=
  errorCategory_refines 0x2 r

theorem errorInvalidState_refines (r : UInt64) :
    evalSingle errorInvalidStateDesc [.u64 r] 20 =
    .returned [.u64 (invalid_state r)] MachineState.empty :=
  errorCategory_refines 0x3 r

theorem errorUnauthenticated_refines (r : UInt64) :
    evalSingle errorUnauthenticatedDesc [.u64 r] 20 =
    .returned [.u64 (unauthenticated r)] MachineState.empty :=
  errorCategory_refines 0x4 r

theorem errorPermissionDenied_refines (r : UInt64) :
    evalSingle errorPermissionDeniedDesc [.u64 r] 20 =
    .returned [.u64 (permission_denied r)] MachineState.empty :=
  errorCategory_refines 0x5 r

theorem errorNotFound_refines (r : UInt64) :
    evalSingle errorNotFoundDesc [.u64 r] 20 =
    .returned [.u64 (not_found r)] MachineState.empty :=
  errorCategory_refines 0x6 r

theorem errorAborted_refines (r : UInt64) :
    evalSingle errorAbortedDesc [.u64 r] 20 =
    .returned [.u64 (aborted r)] MachineState.empty :=
  errorCategory_refines 0x7 r

theorem errorAlreadyExists_refines (r : UInt64) :
    evalSingle errorAlreadyExistsDesc [.u64 r] 20 =
    .returned [.u64 (already_exists r)] MachineState.empty :=
  errorCategory_refines 0x8 r

theorem errorResourceExhausted_refines (r : UInt64) :
    evalSingle errorResourceExhaustedDesc [.u64 r] 20 =
    .returned [.u64 (resource_exhausted r)] MachineState.empty :=
  errorCategory_refines 0x9 r

theorem errorCancelled_refines (r : UInt64) :
    evalSingle errorCancelledDesc [.u64 r] 20 =
    .returned [.u64 (cancelled r)] MachineState.empty :=
  errorCategory_refines 0xA r

theorem errorInternal_refines (r : UInt64) :
    evalSingle errorInternalDesc [.u64 r] 20 =
    .returned [.u64 (internal r)] MachineState.empty :=
  errorCategory_refines 0xB r

theorem errorNotImplemented_refines (r : UInt64) :
    evalSingle errorNotImplementedDesc [.u64 r] 20 =
    .returned [.u64 (not_implemented r)] MachineState.empty :=
  errorCategory_refines 0xC r

theorem errorUnavailable_refines (r : UInt64) :
    evalSingle errorUnavailableDesc [.u64 r] 20 =
    .returned [.u64 (unavailable r)] MachineState.empty :=
  errorCategory_refines 0xD r

/-! ─────────────────────────────────────────────────────────────────────────
## std::bit_vector::length

The bytecode: moveLoc 0 / unpack 2 2 / pop / ret

`unpack 2 2` on `.struct_ [len, bits]` pushes `[len, bits].reverse = [bits, len]`
(TOS = bits, below = len). `pop` removes bits. Return = len.

Note: `MoveValue.struct_` not `MoveValue.struct` — check exact constructor.
────────────────────────────────────────────────────────────────────────── -/

theorem bitVectorLength_refines (len : UInt64) (bits : List MoveValue) :
    evalSingle bitVectorLengthDesc [.struct_ [.u64 len, .vector .bool bits]] 10 =
    .returned [.u64 len] MachineState.empty := by
  simp only [evalSingle, singleEnv, singleIdx, eval, Array.size,
             stdNatives, bitVectorLengthDesc, bitVectorLengthCode]
  rfl

end MovementFormal.Refinement.Std.StdPrimitives
