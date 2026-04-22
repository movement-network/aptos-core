import MovementFormal.MoveModel.Programs.Withdrawal
import MovementFormal.MoveModel.StepLemmas.Basic
import MovementFormal.MoveModel.StepLemmas.Locals
import MovementFormal.MoveModel.StepLemmas.Structs
import MovementFormal.MoveModel.StepLemmas.Calls
import MovementFormal.MoveModel.StepLemmas.Run
import MovementFormal.MoveModel.ExecResultDropMs

/-!
# Bytecode eval ≡ functional simulation for `verify_withdrawal_proof` — Phase 4

Proves that the `verify_withdrawal_proof` bytecode (15 instructions dispatching to
`verify_withdrawal_sigma_proof` + `verify_new_balance_range_proof`) evaluates to the
functional simulation result under the module oracle.

Withdrawal has 8 params (includes `amount: u64` at local 4 instead of a ref).
Otherwise same pattern as Rotation/Normalization.
-/

namespace MovementFormal.Experimental.ConfidentialAsset.Withdrawal.EvalEquiv

open MovementFormal.MoveModel
open MovementFormal.MoveModel.Programs.Withdrawal

def withdrawalArgs (chainId : UInt8) (sender contract : ByteArray)
    (ekRef : MoveValue) (amount : UInt64) (curBalRef newBalRef proofRef : MoveValue)
    : List MoveValue :=
  [.u8 chainId, .address sender, .address contract,
   ekRef, .u64 amount, curBalRef, newBalRef, proofRef]

/-! ## Module environment simp lemmas -/

@[simp] theorem withdrawalModuleEnv_functions_size (o : WithdrawalModuleOracle) :
    (withdrawalModuleEnv o).functions.size = 3 := by
  unfold withdrawalModuleEnv; rfl

@[simp] theorem withdrawalModuleEnv_fn0_numParams (o : WithdrawalModuleOracle) :
    (withdrawalModuleEnv o).functions[0].numParams = 8 := by
  unfold withdrawalModuleEnv; rfl

@[simp] theorem withdrawalModuleEnv_fn0_numReturns (o : WithdrawalModuleOracle) :
    (withdrawalModuleEnv o).functions[0].numReturns = 0 := by
  unfold withdrawalModuleEnv; rfl

@[simp] theorem withdrawalModuleEnv_fn0_body (o : WithdrawalModuleOracle) :
    (withdrawalModuleEnv o).functions[0].body = .nativeRef o.verifySigmaProof := by
  unfold withdrawalModuleEnv; rfl

@[simp] theorem withdrawalModuleEnv_fn1_numParams (o : WithdrawalModuleOracle) :
    (withdrawalModuleEnv o).functions[1].numParams = 2 := by
  unfold withdrawalModuleEnv; rfl

@[simp] theorem withdrawalModuleEnv_fn1_numReturns (o : WithdrawalModuleOracle) :
    (withdrawalModuleEnv o).functions[1].numReturns = 0 := by
  unfold withdrawalModuleEnv; rfl

@[simp] theorem withdrawalModuleEnv_fn1_body (o : WithdrawalModuleOracle) :
    (withdrawalModuleEnv o).functions[1].body = .nativeRef o.verifyRangeProof := by
  unfold withdrawalModuleEnv; rfl

@[simp] theorem withdrawalModuleEnv_fn2_numParams (o : WithdrawalModuleOracle) :
    (withdrawalModuleEnv o).functions[2].numParams = 8 := by
  unfold withdrawalModuleEnv verifyWithdrawalProofDesc; rfl

@[simp] theorem withdrawalModuleEnv_fn2_body (o : WithdrawalModuleOracle) :
    (withdrawalModuleEnv o).functions[2].body = .bytecode verifyWithdrawalProofCode 8 := by
  unfold withdrawalModuleEnv verifyWithdrawalProofDesc; rfl

/-! ## Bytecode access lemmas -/

private theorem wdl_code_pc0  : verifyWithdrawalProofCode[0]'(by decide) = .moveLoc 0 := by unfold verifyWithdrawalProofCode; rfl
private theorem wdl_code_pc1  : verifyWithdrawalProofCode[1]'(by decide) = .moveLoc 1 := by unfold verifyWithdrawalProofCode; rfl
private theorem wdl_code_pc2  : verifyWithdrawalProofCode[2]'(by decide) = .moveLoc 2 := by unfold verifyWithdrawalProofCode; rfl
private theorem wdl_code_pc3  : verifyWithdrawalProofCode[3]'(by decide) = .moveLoc 3 := by unfold verifyWithdrawalProofCode; rfl
private theorem wdl_code_pc4  : verifyWithdrawalProofCode[4]'(by decide) = .moveLoc 4 := by unfold verifyWithdrawalProofCode; rfl
private theorem wdl_code_pc5  : verifyWithdrawalProofCode[5]'(by decide) = .moveLoc 5 := by unfold verifyWithdrawalProofCode; rfl
private theorem wdl_code_pc6  : verifyWithdrawalProofCode[6]'(by decide) = .copyLoc 6 := by unfold verifyWithdrawalProofCode; rfl
private theorem wdl_code_pc7  : verifyWithdrawalProofCode[7]'(by decide) = .copyLoc 7 := by unfold verifyWithdrawalProofCode; rfl
private theorem wdl_code_pc8  : verifyWithdrawalProofCode[8]'(by decide) = .immBorrowField 0 := by unfold verifyWithdrawalProofCode; rfl
private theorem wdl_code_pc9  : verifyWithdrawalProofCode[9]'(by decide) = .call 0 := by unfold verifyWithdrawalProofCode; rfl
private theorem wdl_code_pc10 : verifyWithdrawalProofCode[10]'(by decide) = .moveLoc 6 := by unfold verifyWithdrawalProofCode; rfl
private theorem wdl_code_pc11 : verifyWithdrawalProofCode[11]'(by decide) = .moveLoc 7 := by unfold verifyWithdrawalProofCode; rfl
private theorem wdl_code_pc12 : verifyWithdrawalProofCode[12]'(by decide) = .immBorrowField 1 := by unfold verifyWithdrawalProofCode; rfl
private theorem wdl_code_pc13 : verifyWithdrawalProofCode[13]'(by decide) = .call 1 := by unfold verifyWithdrawalProofCode; rfl
private theorem wdl_code_pc14 : verifyWithdrawalProofCode[14]'(by decide) = .ret := by unfold verifyWithdrawalProofCode; rfl

/-! ## `eval` → `run` entry-point unfolding -/

theorem eval_withdrawal_eq_run (o : WithdrawalModuleOracle)
    (args : List MoveValue) (fuel : Nat) (initMs : MachineState) :
    eval (withdrawalModuleEnv o) verifyWithdrawalProofIdx args fuel initMs =
      run (withdrawalModuleEnv o)
        { code := verifyWithdrawalProofCode,
          pc := 0,
          locals := (args.map some).toArray,
          localRefs := (List.replicate 8 none).toArray }
        [] [] initMs fuel := by
  unfold eval verifyWithdrawalProofIdx
  simp only [withdrawalModuleEnv_functions_size, show (2 : Nat) < 3 from by decide, dif_pos,
             withdrawalModuleEnv_fn2_body, withdrawalModuleEnv_fn2_numParams]
  simp [List.replicate]

/-! ## Per-PC step theorems (moveLoc PCs 0–5) -/

theorem step_withdrawal_pc0 (o : WithdrawalModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyWithdrawalProofCode) (hpc : frame.pc = 0)
    (v : MoveValue) (hlt : 0 < frame.locals.size) (hv : frame.locals[0]'hlt = some v)
    (hRefNone : ¬ 0 < frame.localRefs.size ∨ ∃ h : 0 < frame.localRefs.size, frame.localRefs[0]'h = none) :
    step (withdrawalModuleEnv o) frame cs stack ms =
      .ok { frame with pc := 1, locals := frame.locals.set 0 none (by omega) } cs (v :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .moveLoc 0 := by simp only [hcode, hpc]; exact wdl_code_pc0
  have h := StepLemmas.step_moveLoc_noRef
    (frame := frame) (env := withdrawalModuleEnv o) (cs := cs) (stack := stack) (ms := ms)
    0 v hpc_lt hc hlt hv hRefNone
  rw [show frame.pc + 1 = 1 from by omega] at h; exact h

theorem step_withdrawal_pc1 (o : WithdrawalModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyWithdrawalProofCode) (hpc : frame.pc = 1)
    (v : MoveValue) (hlt : 1 < frame.locals.size) (hv : frame.locals[1]'hlt = some v)
    (hRefNone : ¬ 1 < frame.localRefs.size ∨ ∃ h : 1 < frame.localRefs.size, frame.localRefs[1]'h = none) :
    step (withdrawalModuleEnv o) frame cs stack ms =
      .ok { frame with pc := 2, locals := frame.locals.set 1 none (by omega) } cs (v :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .moveLoc 1 := by simp only [hcode, hpc]; exact wdl_code_pc1
  have h := StepLemmas.step_moveLoc_noRef
    (frame := frame) (env := withdrawalModuleEnv o) (cs := cs) (stack := stack) (ms := ms)
    1 v hpc_lt hc hlt hv hRefNone
  rw [show frame.pc + 1 = 2 from by omega] at h; exact h

theorem step_withdrawal_pc2 (o : WithdrawalModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyWithdrawalProofCode) (hpc : frame.pc = 2)
    (v : MoveValue) (hlt : 2 < frame.locals.size) (hv : frame.locals[2]'hlt = some v)
    (hRefNone : ¬ 2 < frame.localRefs.size ∨ ∃ h : 2 < frame.localRefs.size, frame.localRefs[2]'h = none) :
    step (withdrawalModuleEnv o) frame cs stack ms =
      .ok { frame with pc := 3, locals := frame.locals.set 2 none (by omega) } cs (v :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .moveLoc 2 := by simp only [hcode, hpc]; exact wdl_code_pc2
  have h := StepLemmas.step_moveLoc_noRef
    (frame := frame) (env := withdrawalModuleEnv o) (cs := cs) (stack := stack) (ms := ms)
    2 v hpc_lt hc hlt hv hRefNone
  rw [show frame.pc + 1 = 3 from by omega] at h; exact h

theorem step_withdrawal_pc3 (o : WithdrawalModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyWithdrawalProofCode) (hpc : frame.pc = 3)
    (v : MoveValue) (hlt : 3 < frame.locals.size) (hv : frame.locals[3]'hlt = some v)
    (hRefNone : ¬ 3 < frame.localRefs.size ∨ ∃ h : 3 < frame.localRefs.size, frame.localRefs[3]'h = none) :
    step (withdrawalModuleEnv o) frame cs stack ms =
      .ok { frame with pc := 4, locals := frame.locals.set 3 none (by omega) } cs (v :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .moveLoc 3 := by simp only [hcode, hpc]; exact wdl_code_pc3
  have h := StepLemmas.step_moveLoc_noRef
    (frame := frame) (env := withdrawalModuleEnv o) (cs := cs) (stack := stack) (ms := ms)
    3 v hpc_lt hc hlt hv hRefNone
  rw [show frame.pc + 1 = 4 from by omega] at h; exact h

theorem step_withdrawal_pc4 (o : WithdrawalModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyWithdrawalProofCode) (hpc : frame.pc = 4)
    (v : MoveValue) (hlt : 4 < frame.locals.size) (hv : frame.locals[4]'hlt = some v)
    (hRefNone : ¬ 4 < frame.localRefs.size ∨ ∃ h : 4 < frame.localRefs.size, frame.localRefs[4]'h = none) :
    step (withdrawalModuleEnv o) frame cs stack ms =
      .ok { frame with pc := 5, locals := frame.locals.set 4 none (by omega) } cs (v :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .moveLoc 4 := by simp only [hcode, hpc]; exact wdl_code_pc4
  have h := StepLemmas.step_moveLoc_noRef
    (frame := frame) (env := withdrawalModuleEnv o) (cs := cs) (stack := stack) (ms := ms)
    4 v hpc_lt hc hlt hv hRefNone
  rw [show frame.pc + 1 = 5 from by omega] at h; exact h

theorem step_withdrawal_pc5 (o : WithdrawalModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyWithdrawalProofCode) (hpc : frame.pc = 5)
    (v : MoveValue) (hlt : 5 < frame.locals.size) (hv : frame.locals[5]'hlt = some v)
    (hRefNone : ¬ 5 < frame.localRefs.size ∨ ∃ h : 5 < frame.localRefs.size, frame.localRefs[5]'h = none) :
    step (withdrawalModuleEnv o) frame cs stack ms =
      .ok { frame with pc := 6, locals := frame.locals.set 5 none (by omega) } cs (v :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .moveLoc 5 := by simp only [hcode, hpc]; exact wdl_code_pc5
  have h := StepLemmas.step_moveLoc_noRef
    (frame := frame) (env := withdrawalModuleEnv o) (cs := cs) (stack := stack) (ms := ms)
    5 v hpc_lt hc hlt hv hRefNone
  rw [show frame.pc + 1 = 6 from by omega] at h; exact h

/-! ## copyLoc PCs 6–7 -/

theorem step_withdrawal_pc6 (o : WithdrawalModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyWithdrawalProofCode) (hpc : frame.pc = 6)
    (v : MoveValue) (hlt : 6 < frame.locals.size) (hv : frame.locals[6]'hlt = some v)
    (hRefNone : ¬ 6 < frame.localRefs.size ∨ ∃ h : 6 < frame.localRefs.size, frame.localRefs[6]'h = none) :
    step (withdrawalModuleEnv o) frame cs stack ms = .ok { frame with pc := 7 } cs (v :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .copyLoc 6 := by simp only [hcode, hpc]; exact wdl_code_pc6
  have h := StepLemmas.step_copyLoc_noRef
    (frame := frame) (env := withdrawalModuleEnv o) (cs := cs) (stack := stack) (ms := ms)
    6 v hpc_lt hc hlt hv hRefNone
  rw [show frame.pc + 1 = 7 from by omega] at h; exact h

theorem step_withdrawal_pc7 (o : WithdrawalModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyWithdrawalProofCode) (hpc : frame.pc = 7)
    (v : MoveValue) (hlt : 7 < frame.locals.size) (hv : frame.locals[7]'hlt = some v)
    (hRefNone : ¬ 7 < frame.localRefs.size ∨ ∃ h : 7 < frame.localRefs.size, frame.localRefs[7]'h = none) :
    step (withdrawalModuleEnv o) frame cs stack ms = .ok { frame with pc := 8 } cs (v :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .copyLoc 7 := by simp only [hcode, hpc]; exact wdl_code_pc7
  have h := StepLemmas.step_copyLoc_noRef
    (frame := frame) (env := withdrawalModuleEnv o) (cs := cs) (stack := stack) (ms := ms)
    7 v hpc_lt hc hlt hv hRefNone
  rw [show frame.pc + 1 = 8 from by omega] at h; exact h

/-! ## PC 8 — immBorrowField 0 (proof.sigma_proof) -/

theorem step_withdrawal_pc8 (o : WithdrawalModuleOracle)
    (frame : Frame) (cs : List Frame) (rest : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyWithdrawalProofCode) (hpc : frame.pc = 8)
    (rid : RefId) (proofFields : List MoveValue) (containers' : ContainerStore) (fid : RefId)
    (ref : MoveValue)
    (hRef : getRefId ref = some rid)
    (hread : ms.containers.read rid = some (.struct_ proofFields))
    (hlt : 0 < proofFields.length)
    (halloc : ms.containers.alloc (proofFields[0]'hlt) = (containers', fid)) :
    step (withdrawalModuleEnv o) frame cs (ref :: rest) ms =
      .ok { frame with pc := 9 } cs (.immRef fid :: rest) { ms with containers := containers' } := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .immBorrowField 0 := by simp only [hcode, hpc]; exact wdl_code_pc8
  simp only [step, dif_pos hpc_lt, hc, hRef, hread, dif_pos hlt, halloc]
  rw [show frame.pc + 1 = 9 from by omega]

/-! ## PC 9 — call 0 (verifySigmaProof, 8 args) -/

theorem step_withdrawal_pc9 (o : WithdrawalModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyWithdrawalProofCode) (hpc : frame.pc = 9)
    (args rest : List MoveValue) (containers' : ContainerStore)
    (htake : takeN stack 8 = some (args, rest))
    (himpl : o.verifySigmaProof ms.containers args = some ([], containers')) :
    step (withdrawalModuleEnv o) frame cs stack ms =
      .ok { frame with pc := 10 } cs rest { ms with containers := containers', globals := ms.globals } := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .call 0 := by simp only [hcode, hpc]; exact wdl_code_pc9
  simp only [step, dif_pos hpc_lt, hc, dif_pos (show 0 < (withdrawalModuleEnv o).functions.size by simp)]
  simp only [withdrawalModuleEnv_fn0_numParams, htake, withdrawalModuleEnv_fn0_body, himpl]
  unfold handleNativeResult
  simp only [withdrawalModuleEnv_fn0_numReturns, beq_self_eq_true, ↓reduceIte]
  rw [show frame.pc + 1 = 10 from by omega]

theorem step_withdrawal_pc9_none (o : WithdrawalModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyWithdrawalProofCode) (hpc : frame.pc = 9)
    (args rest : List MoveValue)
    (htake : takeN stack 8 = some (args, rest))
    (himpl : o.verifySigmaProof ms.containers args = none) :
    step (withdrawalModuleEnv o) frame cs stack ms = .error := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .call 0 := by simp only [hcode, hpc]; exact wdl_code_pc9
  simp only [step, dif_pos hpc_lt, hc, dif_pos (show 0 < (withdrawalModuleEnv o).functions.size by simp)]
  simp only [withdrawalModuleEnv_fn0_numParams, htake, withdrawalModuleEnv_fn0_body, himpl]

/-! ## moveLoc PCs 10–11 (after sigma call) -/

theorem step_withdrawal_pc10 (o : WithdrawalModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyWithdrawalProofCode) (hpc : frame.pc = 10)
    (v : MoveValue) (hlt : 6 < frame.locals.size) (hv : frame.locals[6]'hlt = some v)
    (hRefNone : ¬ 6 < frame.localRefs.size ∨ ∃ h : 6 < frame.localRefs.size, frame.localRefs[6]'h = none) :
    step (withdrawalModuleEnv o) frame cs stack ms =
      .ok { frame with pc := 11, locals := frame.locals.set 6 none (by omega) } cs (v :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .moveLoc 6 := by simp only [hcode, hpc]; exact wdl_code_pc10
  simp only [step, dif_pos hpc_lt, hc, dif_pos hlt, hv]
  rcases hRefNone with hSz | ⟨hSz, hNone⟩
  · simp only [dif_neg hSz]; rw [show frame.pc + 1 = 11 from by omega]
  · simp only [dif_pos hSz, hNone]; rw [show frame.pc + 1 = 11 from by omega]

theorem step_withdrawal_pc11 (o : WithdrawalModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyWithdrawalProofCode) (hpc : frame.pc = 11)
    (v : MoveValue) (hlt : 7 < frame.locals.size) (hv : frame.locals[7]'hlt = some v)
    (hRefNone : ¬ 7 < frame.localRefs.size ∨ ∃ h : 7 < frame.localRefs.size, frame.localRefs[7]'h = none) :
    step (withdrawalModuleEnv o) frame cs stack ms =
      .ok { frame with pc := 12, locals := frame.locals.set 7 none (by omega) } cs (v :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .moveLoc 7 := by simp only [hcode, hpc]; exact wdl_code_pc11
  simp only [step, dif_pos hpc_lt, hc, dif_pos hlt, hv]
  rcases hRefNone with hSz | ⟨hSz, hNone⟩
  · simp only [dif_neg hSz]; rw [show frame.pc + 1 = 12 from by omega]
  · simp only [dif_pos hSz, hNone]; rw [show frame.pc + 1 = 12 from by omega]

/-! ## PC 12 — immBorrowField 1 (proof.zkrp_new_balance) -/

theorem step_withdrawal_pc12 (o : WithdrawalModuleOracle)
    (frame : Frame) (cs : List Frame) (rest : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyWithdrawalProofCode) (hpc : frame.pc = 12)
    (rid : RefId) (proofFields : List MoveValue) (containers' : ContainerStore) (fid : RefId)
    (ref : MoveValue)
    (hRef : getRefId ref = some rid)
    (hread : ms.containers.read rid = some (.struct_ proofFields))
    (hlt : 1 < proofFields.length)
    (halloc : ms.containers.alloc (proofFields[1]'hlt) = (containers', fid)) :
    step (withdrawalModuleEnv o) frame cs (ref :: rest) ms =
      .ok { frame with pc := 13 } cs (.immRef fid :: rest) { ms with containers := containers' } := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .immBorrowField 1 := by simp only [hcode, hpc]; exact wdl_code_pc12
  simp only [step, dif_pos hpc_lt, hc, hRef, hread, dif_pos hlt, halloc]
  rw [show frame.pc + 1 = 13 from by omega]

/-! ## PC 13 — call 1 (verifyRangeProof, 2 args) -/

theorem step_withdrawal_pc13 (o : WithdrawalModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyWithdrawalProofCode) (hpc : frame.pc = 13)
    (args rest : List MoveValue) (containers' : ContainerStore)
    (htake : takeN stack 2 = some (args, rest))
    (himpl : o.verifyRangeProof ms.containers args = some ([], containers')) :
    step (withdrawalModuleEnv o) frame cs stack ms =
      .ok { frame with pc := 14 } cs rest { ms with containers := containers', globals := ms.globals } := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .call 1 := by simp only [hcode, hpc]; exact wdl_code_pc13
  simp only [step, dif_pos hpc_lt, hc, dif_pos (show 1 < (withdrawalModuleEnv o).functions.size by simp)]
  simp only [withdrawalModuleEnv_fn1_numParams, htake, withdrawalModuleEnv_fn1_body, himpl]
  unfold handleNativeResult
  simp only [withdrawalModuleEnv_fn1_numReturns, beq_self_eq_true, ↓reduceIte]
  rw [show frame.pc + 1 = 14 from by omega]

theorem step_withdrawal_pc13_none (o : WithdrawalModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyWithdrawalProofCode) (hpc : frame.pc = 13)
    (args rest : List MoveValue)
    (htake : takeN stack 2 = some (args, rest))
    (himpl : o.verifyRangeProof ms.containers args = none) :
    step (withdrawalModuleEnv o) frame cs stack ms = .error := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .call 1 := by simp only [hcode, hpc]; exact wdl_code_pc13
  simp only [step, dif_pos hpc_lt, hc, dif_pos (show 1 < (withdrawalModuleEnv o).functions.size by simp)]
  simp only [withdrawalModuleEnv_fn1_numParams, htake, withdrawalModuleEnv_fn1_body, himpl]

/-! ## PC 14 — ret -/

theorem step_withdrawal_pc14 (o : WithdrawalModuleOracle)
    (frame : Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyWithdrawalProofCode) (hpc : frame.pc = 14) :
    step (withdrawalModuleEnv o) frame [] stack ms = .returned stack ms := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .ret := by simp only [hcode, hpc]; exact wdl_code_pc14
  exact StepLemmas.step_ret_top hpc_lt hc

/-! ## Functional simulation — Phase 6

The functional simulation captures the high-level behavior of `verify_withdrawal_proof`:
wires chain_id, sender, contract, ek, amount, current_balance, new_balance, and the
proof's sigma_proof field (via ImmBorrowField) to the sigma verifier, then new_balance
and the proof's zkrp_new_balance field to the range verifier.

The result is `.returned [] ms_final` on success (both sub-calls return `some`) or
`.error` if either sub-call fails. -/

inductive WithdrawalBytecodeResult where
  | returned (ms : MachineState)
  | error

def verifyWithdrawalBytecodeResult
    (o : WithdrawalModuleOracle) (chainId : UInt8) (sender contract : ByteArray)
    (ekRef : MoveValue) (amount : UInt64) (curBalRef newBalRef : MoveValue)
    (_proofRid : RefId) (proofFields : List MoveValue)
    (initMs : MachineState)
    (hFieldCount : 1 < proofFields.length) : WithdrawalBytecodeResult :=
  let (cs1, sigmaFid) := initMs.containers.alloc (proofFields[0]'(by omega))
  let sigmaArgs := [.u8 chainId, .address sender, .address contract,
                    ekRef, .u64 amount, curBalRef, newBalRef, .immRef sigmaFid]
  match o.verifySigmaProof cs1 sigmaArgs with
  | none => .error
  | some ([], cs2) =>
    let (cs3, zkrpFid) := cs2.alloc (proofFields[1]'hFieldCount)
    let rangeArgs := [newBalRef, .immRef zkrpFid]
    match o.verifyRangeProof cs3 rangeArgs with
    | none => .error
    | some ([], cs4) => .returned { initMs with containers := cs4, globals := initMs.globals }
    | some (_ :: _, _) => .error
  | some (_ :: _, _) => .error

/-! ## Functional simulation shape lemmas -/

/-- Functional simulation shape lemma: sigma failure → .error -/
theorem verifyWithdrawalBytecodeResult_sigmaFails
    (o : WithdrawalModuleOracle)
    (chainId : UInt8) (sender contract : ByteArray)
    (ekRef : MoveValue) (amount : UInt64) (curBalRef newBalRef : MoveValue)
    (proofRid : RefId) (proofFields : List MoveValue)
    (initMs : MachineState)
    (hFieldCount : 1 < proofFields.length)
    (hsigmaFail : ∀ cs args, o.verifySigmaProof cs args = none) :
    verifyWithdrawalBytecodeResult o chainId sender contract
        ekRef amount curBalRef newBalRef proofRid proofFields initMs hFieldCount =
    .error := by
  unfold verifyWithdrawalBytecodeResult
  simp [hsigmaFail]

/-- Functional simulation shape lemma: range failure → .error -/
theorem verifyWithdrawalBytecodeResult_rangeFails
    (o : WithdrawalModuleOracle)
    (chainId : UInt8) (sender contract : ByteArray)
    (ekRef : MoveValue) (amount : UInt64) (curBalRef newBalRef : MoveValue)
    (proofRid : RefId) (proofFields : List MoveValue)
    (initMs : MachineState)
    (hFieldCount : 1 < proofFields.length)
    (sigmaCs : ContainerStore)
    (hsigmaOk : o.verifySigmaProof (initMs.containers.alloc (proofFields[0]'(by omega))).1
                    [.u8 chainId, .address sender, .address contract,
                     ekRef, .u64 amount, curBalRef, newBalRef,
                     .immRef (initMs.containers.alloc (proofFields[0]'(by omega))).2] =
                 some ([], sigmaCs))
    (hrangeFail : ∀ cs args, o.verifyRangeProof cs args = none) :
    verifyWithdrawalBytecodeResult o chainId sender contract
        ekRef amount curBalRef newBalRef proofRid proofFields initMs hFieldCount =
    .error := by
  unfold verifyWithdrawalBytecodeResult
  simp only [hsigmaOk, hrangeFail]

/-- Functional simulation shape lemma: happy path → .returned -/
theorem verifyWithdrawalBytecodeResult_success
    (o : WithdrawalModuleOracle)
    (chainId : UInt8) (sender contract : ByteArray)
    (ekRef : MoveValue) (amount : UInt64) (curBalRef newBalRef : MoveValue)
    (proofRid : RefId) (proofFields : List MoveValue)
    (initMs : MachineState)
    (hFieldCount : 1 < proofFields.length)
    (sigmaCs rangeCs : ContainerStore)
    (sigmaFid : RefId)
    (halloc0 : initMs.containers.alloc (proofFields[0]'(by omega)) = (sigmaCs, sigmaFid))
    (hsigmaOk : o.verifySigmaProof sigmaCs
                    [.u8 chainId, .address sender, .address contract,
                     ekRef, .u64 amount, curBalRef, newBalRef, .immRef sigmaFid] =
                 some ([], rangeCs))
    (hrange : o.verifyRangeProof (rangeCs.alloc (proofFields[1]'hFieldCount)).1
                  [newBalRef, .immRef (rangeCs.alloc (proofFields[1]'hFieldCount)).2] =
               some ([], (rangeCs.alloc (proofFields[1]'hFieldCount)).1)) :
    verifyWithdrawalBytecodeResult o chainId sender contract
        ekRef amount curBalRef newBalRef proofRid proofFields initMs hFieldCount =
    .returned { initMs with containers := (rangeCs.alloc (proofFields[1]'hFieldCount)).1 } := by
  unfold verifyWithdrawalBytecodeResult
  simp only [halloc0, hsigmaOk, hrange]

/-! ## Top-level composition theorem (Phase 6)

The full eval↔functional-sim equivalence. Structure:
1. Unfold eval to run via `eval_withdrawal_eq_run`
2. Chain PCs 0-8 (argument marshaling) using individual step theorems
3. At PC 9, split on sigma oracle outcome
4. On sigma success, chain PCs 10-12
5. At PC 13, split on range oracle outcome
6. On range success, execute PC 14 (ret)
7. Apply shape lemmas to connect to functional sim

The proof requires ~300 lines of frame manipulation and oracle case splitting.
Currently structured with sorry placeholders for incremental completion. -/

theorem withdrawal_eval_equiv_functional_sim
    (o : WithdrawalModuleOracle)
    (chainId : UInt8) (sender contract : ByteArray)
    (ekRef : MoveValue) (amount : UInt64) (curBalRef newBalRef proofRef : MoveValue)
    (proofRid : RefId) (proofFields : List MoveValue)
    (initMs : MachineState)
    (hFieldCount : 1 < proofFields.length)
    (hread : initMs.containers.read proofRid = some (.struct_ proofFields))
    (hproofRef : getRefId proofRef = some proofRid)
    (fuel : Nat)
    (hfuel : fuel ≥ 15) :
    let args := [.u8 chainId, .address sender, .address contract,
                 ekRef, .u64 amount, curBalRef, newBalRef, proofRef]
    (eval (withdrawalModuleEnv o) verifyWithdrawalProofIdx args fuel initMs).dropMs =
    match verifyWithdrawalBytecodeResult o chainId sender contract ekRef amount curBalRef newBalRef
            proofRid proofFields initMs hFieldCount with
    | .returned ms => .returned [] ms
    | .error => .error := by
  -- Unfold eval to run
  show (eval (withdrawalModuleEnv o) verifyWithdrawalProofIdx
          [.u8 chainId, .address sender, .address contract,
           ekRef, .u64 amount, curBalRef, newBalRef, proofRef]
          fuel initMs).dropMs = _
  rw [eval_withdrawal_eq_run]

  -- TODO Phase 6: Chain all 15 PCs using run_succ_ok_of_step
  -- Pattern: apply step theorems sequentially, split on oracle outcomes
  -- at PC 9 (sigma) and PC 13 (range), apply shape lemmas to connect to functional sim
  sorry

end MovementFormal.Experimental.ConfidentialAsset.Withdrawal.EvalEquiv
