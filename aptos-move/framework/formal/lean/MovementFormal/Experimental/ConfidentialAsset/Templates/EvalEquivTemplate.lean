/- EvalEquiv Template - Phase 4 Bytecode Proof Pattern -/
import MovementFormal.MoveModel.StepLemmas.Basic
import MovementFormal.MoveModel.StepLemmas.Calls
import MovementFormal.MoveModel.StepLemmas.Run

namespace MovementFormal.Experimental.ConfidentialAsset.NewOperation
open MoveModel StepLemmas

@[irreducible]
def NewOperationState (pc : Nat) (proofRef publicInputsRef : RefValue) (locals : Locals) (stack : Stack) : CallFrame :=
  { initialCallFrame with pc := pc, locals := locals, stack := stack }

@[simp] theorem NewOperationState_pc ... := by simp [NewOperationState]
@[simp] theorem NewOperationState_locals ... := by simp [NewOperationState]
@[simp] theorem NewOperationState_stack ... := by simp [NewOperationState]

theorem step_pc0 : step env (NewOperationState 0 ...) cs ms = ... := by
  rw [step_immBorrowLoc_frame]; rfl

theorem eval_new_operation_eq_run : ... := by
  rw [step_pc0, step_pc1, ..., step_pcN_call, step_pcM_ret]
  cases oracle_result; simp; rfl

end MovementFormal.Experimental.ConfidentialAsset.NewOperation
