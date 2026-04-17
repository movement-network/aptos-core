import MovementFormal.MoveModel.Step
import MovementFormal.MoveModel.Programs

/-!
# Core refinement proofs

Universally quantified correctness theorems for basic bytecode programs.
Each theorem proves that `eval` on a program produces results matching
the specification **for all inputs**, using `rfl` — Lean's kernel verifies
the full evaluation chain by definitional reduction.
-/

namespace MovementFormal.Refinement.Std.Core

open MovementFormal.MoveModel
open MovementFormal.MoveModel.Programs

abbrev evalProg (idx : FuncIndex) (args : List MoveValue) (fuel : Nat) :=
  eval stdModuleEnv idx args fuel

/-! ## add_u64 correctness -/

theorem addU64_correct (a b : UInt64) :
    evalProg 8 [.u64 a, .u64 b] 5 =
      .returned [.u64 (a + b)] ContainerStore.empty := by
  rfl

/-! ## is_zero_u64 correctness -/

theorem isZeroU64_correct (n : UInt64) :
    evalProg 10 [.u64 n] 5 =
      .returned [.bool (MoveValue.u64 n == MoveValue.u64 0)]
        ContainerStore.empty := by
  rfl

/-! ## bcs_to_bytes_u64 correctness -/

private def bytesToMoveVec (bs : ByteArray) : MoveValue :=
  .vector .u8 (bs.toList.map .u8)

theorem bcsU64_correct (v : UInt64) :
    evalProg 13 [.u64 v] 5 =
      .returned [bytesToMoveVec (MovementFormal.Std.Bcs.u64Le v)]
        ContainerStore.empty := by
  rfl

/-! ## read_via_ref correctness -/

theorem readViaRef_correct (n : UInt64) :
    evalProg 14 [.u64 n] 5 =
      .returned [.u64 n] (MachineState.ofContainers { store := #[.u64 n] }) := by
  rfl

/-! ## inc_via_ref correctness -/

theorem incViaRef_correct (n : UInt64) :
    evalProg 15 [.u64 n] 15 =
      .returned [.u64 (n + 1)] (MachineState.ofContainers { store := #[.u64 (n + 1)] }) := by
  rfl

/-! ## vec_push_and_len correctness -/

theorem vecPushAndLen_correct (elems : List MoveValue) (val : UInt64) :
    let pushed := elems ++ [MoveValue.u64 val]
    evalProg 16 [.vector .u64 elems, .u64 val] 10 =
      .returned [.u64 pushed.length.toUInt64]
        (MachineState.ofContainers { store := #[.vector .u64 pushed] }) := by
  rfl

end MovementFormal.Refinement.Std.Core
