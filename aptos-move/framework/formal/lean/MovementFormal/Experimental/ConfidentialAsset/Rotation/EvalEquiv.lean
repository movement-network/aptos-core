import MovementFormal.MoveModel.Programs.Rotation
import MovementFormal.MoveModel.StepLemmas.Basic
import MovementFormal.MoveModel.StepLemmas.Locals
import MovementFormal.MoveModel.StepLemmas.Structs
import MovementFormal.MoveModel.StepLemmas.Calls
import MovementFormal.MoveModel.StepLemmas.Run
import MovementFormal.MoveModel.ExecResultDropMs

/-!
# Bytecode eval ≡ functional simulation for `verify_rotation_proof` — Phase 4

Proves that the `verify_rotation_proof` bytecode (15 instructions dispatching to
`verify_rotation_sigma_proof` + `verify_new_balance_range_proof`) evaluates to the
functional simulation result under the module oracle.

Same architecture as `Normalization/EvalEquiv.lean` — 15 PCs instead of 14,
8 params instead of 7. The extra param is `new_ek` at local 4.
-/

namespace MovementFormal.Experimental.ConfidentialAsset.Rotation.EvalEquiv

open MovementFormal.MoveModel
open MovementFormal.MoveModel.Programs.Rotation

def rotationArgs (chainId : UInt8) (sender contract : ByteArray)
    (curEkRef newEkRef curBalRef newBalRef proofRef : MoveValue) : List MoveValue :=
  [.u8 chainId, .address sender, .address contract,
   curEkRef, newEkRef, curBalRef, newBalRef, proofRef]

/-! ## Module environment simp lemmas -/

@[simp] theorem rotationModuleEnv_functions_size (o : RotationModuleOracle) :
    (rotationModuleEnv o).functions.size = 3 := by
  unfold rotationModuleEnv; rfl

@[simp] theorem rotationModuleEnv_fn0_numParams (o : RotationModuleOracle) :
    (rotationModuleEnv o).functions[0].numParams = 8 := by
  unfold rotationModuleEnv; rfl

@[simp] theorem rotationModuleEnv_fn0_numReturns (o : RotationModuleOracle) :
    (rotationModuleEnv o).functions[0].numReturns = 0 := by
  unfold rotationModuleEnv; rfl

@[simp] theorem rotationModuleEnv_fn0_body (o : RotationModuleOracle) :
    (rotationModuleEnv o).functions[0].body = .nativeRef o.verifySigmaProof := by
  unfold rotationModuleEnv; rfl

@[simp] theorem rotationModuleEnv_fn1_numParams (o : RotationModuleOracle) :
    (rotationModuleEnv o).functions[1].numParams = 2 := by
  unfold rotationModuleEnv; rfl

@[simp] theorem rotationModuleEnv_fn1_numReturns (o : RotationModuleOracle) :
    (rotationModuleEnv o).functions[1].numReturns = 0 := by
  unfold rotationModuleEnv; rfl

@[simp] theorem rotationModuleEnv_fn1_body (o : RotationModuleOracle) :
    (rotationModuleEnv o).functions[1].body = .nativeRef o.verifyRangeProof := by
  unfold rotationModuleEnv; rfl

@[simp] theorem rotationModuleEnv_fn2_numParams (o : RotationModuleOracle) :
    (rotationModuleEnv o).functions[2].numParams = 8 := by
  unfold rotationModuleEnv verifyRotationProofDesc; rfl

@[simp] theorem rotationModuleEnv_fn2_body (o : RotationModuleOracle) :
    (rotationModuleEnv o).functions[2].body = .bytecode verifyRotationProofCode 8 := by
  unfold rotationModuleEnv verifyRotationProofDesc; rfl

/-! ## Bytecode access lemmas -/

private theorem rot_code_pc0  : verifyRotationProofCode[0]'(by decide) = .moveLoc 0 := by unfold verifyRotationProofCode; rfl
private theorem rot_code_pc1  : verifyRotationProofCode[1]'(by decide) = .moveLoc 1 := by unfold verifyRotationProofCode; rfl
private theorem rot_code_pc2  : verifyRotationProofCode[2]'(by decide) = .moveLoc 2 := by unfold verifyRotationProofCode; rfl
private theorem rot_code_pc3  : verifyRotationProofCode[3]'(by decide) = .moveLoc 3 := by unfold verifyRotationProofCode; rfl
private theorem rot_code_pc4  : verifyRotationProofCode[4]'(by decide) = .moveLoc 4 := by unfold verifyRotationProofCode; rfl
private theorem rot_code_pc5  : verifyRotationProofCode[5]'(by decide) = .moveLoc 5 := by unfold verifyRotationProofCode; rfl
private theorem rot_code_pc6  : verifyRotationProofCode[6]'(by decide) = .copyLoc 6 := by unfold verifyRotationProofCode; rfl
private theorem rot_code_pc7  : verifyRotationProofCode[7]'(by decide) = .copyLoc 7 := by unfold verifyRotationProofCode; rfl
private theorem rot_code_pc8  : verifyRotationProofCode[8]'(by decide) = .immBorrowField 0 := by unfold verifyRotationProofCode; rfl
private theorem rot_code_pc9  : verifyRotationProofCode[9]'(by decide) = .call 0 := by unfold verifyRotationProofCode; rfl
private theorem rot_code_pc10 : verifyRotationProofCode[10]'(by decide) = .moveLoc 6 := by unfold verifyRotationProofCode; rfl
private theorem rot_code_pc11 : verifyRotationProofCode[11]'(by decide) = .moveLoc 7 := by unfold verifyRotationProofCode; rfl
private theorem rot_code_pc12 : verifyRotationProofCode[12]'(by decide) = .immBorrowField 1 := by unfold verifyRotationProofCode; rfl
private theorem rot_code_pc13 : verifyRotationProofCode[13]'(by decide) = .call 1 := by unfold verifyRotationProofCode; rfl
private theorem rot_code_pc14 : verifyRotationProofCode[14]'(by decide) = .ret := by unfold verifyRotationProofCode; rfl

/-! ## `eval` → `run` entry-point unfolding -/

theorem eval_rotation_eq_run (o : RotationModuleOracle)
    (args : List MoveValue) (fuel : Nat) (initMs : MachineState) :
    eval (rotationModuleEnv o) verifyRotationProofIdx args fuel initMs =
      run (rotationModuleEnv o)
        { code := verifyRotationProofCode,
          pc := 0,
          locals := (args.map some).toArray,
          localRefs := (List.replicate 8 none).toArray }
        [] [] initMs fuel := by
  unfold eval verifyRotationProofIdx
  simp only [rotationModuleEnv_functions_size, show (2 : Nat) < 3 from by decide, dif_pos,
             rotationModuleEnv_fn2_body, rotationModuleEnv_fn2_numParams]
  simp [List.replicate]

/-! ## Per-PC step theorems (moveLoc PCs 0–5) -/

private def moveLocStep (o : RotationModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (idx nextPc : Nat) (v : MoveValue)
    (_hcode : frame.code = verifyRotationProofCode)
    (hpc : frame.pc = idx)
    (hpc_lt : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc_lt = .moveLoc idx)
    (hlt : idx < frame.locals.size)
    (hv : frame.locals[idx]'hlt = some v)
    (hRefNone : ¬ idx < frame.localRefs.size ∨
        ∃ (h : idx < frame.localRefs.size), frame.localRefs[idx]'h = none)
    (hnext : idx + 1 = nextPc) :
    step (rotationModuleEnv o) frame cs stack ms =
      .ok { frame with pc := nextPc, locals := frame.locals.set idx none (by omega) }
           cs (v :: stack) ms := by
  have h := StepLemmas.step_moveLoc_noRef
    (frame := frame) (env := rotationModuleEnv o) (cs := cs) (stack := stack) (ms := ms)
    idx v hpc_lt hc hlt hv hRefNone
  rw [show frame.pc + 1 = nextPc from by omega] at h; exact h

theorem step_rotation_pc0 (o : RotationModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyRotationProofCode) (hpc : frame.pc = 0)
    (v : MoveValue) (hlt : 0 < frame.locals.size) (hv : frame.locals[0]'hlt = some v)
    (hRefNone : ¬ 0 < frame.localRefs.size ∨ ∃ h : 0 < frame.localRefs.size, frame.localRefs[0]'h = none) :
    step (rotationModuleEnv o) frame cs stack ms =
      .ok { frame with pc := 1, locals := frame.locals.set 0 none (by omega) } cs (v :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .moveLoc 0 := by simp only [hcode, hpc]; exact rot_code_pc0
  exact moveLocStep o frame cs stack ms 0 1 v hcode hpc hpc_lt hc hlt hv hRefNone rfl

theorem step_rotation_pc1 (o : RotationModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyRotationProofCode) (hpc : frame.pc = 1)
    (v : MoveValue) (hlt : 1 < frame.locals.size) (hv : frame.locals[1]'hlt = some v)
    (hRefNone : ¬ 1 < frame.localRefs.size ∨ ∃ h : 1 < frame.localRefs.size, frame.localRefs[1]'h = none) :
    step (rotationModuleEnv o) frame cs stack ms =
      .ok { frame with pc := 2, locals := frame.locals.set 1 none (by omega) } cs (v :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .moveLoc 1 := by simp only [hcode, hpc]; exact rot_code_pc1
  exact moveLocStep o frame cs stack ms 1 2 v hcode hpc hpc_lt hc hlt hv hRefNone rfl

theorem step_rotation_pc2 (o : RotationModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyRotationProofCode) (hpc : frame.pc = 2)
    (v : MoveValue) (hlt : 2 < frame.locals.size) (hv : frame.locals[2]'hlt = some v)
    (hRefNone : ¬ 2 < frame.localRefs.size ∨ ∃ h : 2 < frame.localRefs.size, frame.localRefs[2]'h = none) :
    step (rotationModuleEnv o) frame cs stack ms =
      .ok { frame with pc := 3, locals := frame.locals.set 2 none (by omega) } cs (v :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .moveLoc 2 := by simp only [hcode, hpc]; exact rot_code_pc2
  exact moveLocStep o frame cs stack ms 2 3 v hcode hpc hpc_lt hc hlt hv hRefNone rfl

theorem step_rotation_pc3 (o : RotationModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyRotationProofCode) (hpc : frame.pc = 3)
    (v : MoveValue) (hlt : 3 < frame.locals.size) (hv : frame.locals[3]'hlt = some v)
    (hRefNone : ¬ 3 < frame.localRefs.size ∨ ∃ h : 3 < frame.localRefs.size, frame.localRefs[3]'h = none) :
    step (rotationModuleEnv o) frame cs stack ms =
      .ok { frame with pc := 4, locals := frame.locals.set 3 none (by omega) } cs (v :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .moveLoc 3 := by simp only [hcode, hpc]; exact rot_code_pc3
  exact moveLocStep o frame cs stack ms 3 4 v hcode hpc hpc_lt hc hlt hv hRefNone rfl

theorem step_rotation_pc4 (o : RotationModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyRotationProofCode) (hpc : frame.pc = 4)
    (v : MoveValue) (hlt : 4 < frame.locals.size) (hv : frame.locals[4]'hlt = some v)
    (hRefNone : ¬ 4 < frame.localRefs.size ∨ ∃ h : 4 < frame.localRefs.size, frame.localRefs[4]'h = none) :
    step (rotationModuleEnv o) frame cs stack ms =
      .ok { frame with pc := 5, locals := frame.locals.set 4 none (by omega) } cs (v :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .moveLoc 4 := by simp only [hcode, hpc]; exact rot_code_pc4
  exact moveLocStep o frame cs stack ms 4 5 v hcode hpc hpc_lt hc hlt hv hRefNone rfl

theorem step_rotation_pc5 (o : RotationModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyRotationProofCode) (hpc : frame.pc = 5)
    (v : MoveValue) (hlt : 5 < frame.locals.size) (hv : frame.locals[5]'hlt = some v)
    (hRefNone : ¬ 5 < frame.localRefs.size ∨ ∃ h : 5 < frame.localRefs.size, frame.localRefs[5]'h = none) :
    step (rotationModuleEnv o) frame cs stack ms =
      .ok { frame with pc := 6, locals := frame.locals.set 5 none (by omega) } cs (v :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .moveLoc 5 := by simp only [hcode, hpc]; exact rot_code_pc5
  exact moveLocStep o frame cs stack ms 5 6 v hcode hpc hpc_lt hc hlt hv hRefNone rfl

/-! ## copyLoc PCs 6–7 -/

theorem step_rotation_pc6 (o : RotationModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyRotationProofCode) (hpc : frame.pc = 6)
    (v : MoveValue) (hlt : 6 < frame.locals.size) (hv : frame.locals[6]'hlt = some v)
    (hRefNone : ¬ 6 < frame.localRefs.size ∨ ∃ h : 6 < frame.localRefs.size, frame.localRefs[6]'h = none) :
    step (rotationModuleEnv o) frame cs stack ms = .ok { frame with pc := 7 } cs (v :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .copyLoc 6 := by simp only [hcode, hpc]; exact rot_code_pc6
  have h := StepLemmas.step_copyLoc_noRef
    (frame := frame) (env := rotationModuleEnv o) (cs := cs) (stack := stack) (ms := ms)
    6 v hpc_lt hc hlt hv hRefNone
  rw [show frame.pc + 1 = 7 from by omega] at h; exact h

theorem step_rotation_pc7 (o : RotationModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyRotationProofCode) (hpc : frame.pc = 7)
    (v : MoveValue) (hlt : 7 < frame.locals.size) (hv : frame.locals[7]'hlt = some v)
    (hRefNone : ¬ 7 < frame.localRefs.size ∨ ∃ h : 7 < frame.localRefs.size, frame.localRefs[7]'h = none) :
    step (rotationModuleEnv o) frame cs stack ms = .ok { frame with pc := 8 } cs (v :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .copyLoc 7 := by simp only [hcode, hpc]; exact rot_code_pc7
  have h := StepLemmas.step_copyLoc_noRef
    (frame := frame) (env := rotationModuleEnv o) (cs := cs) (stack := stack) (ms := ms)
    7 v hpc_lt hc hlt hv hRefNone
  rw [show frame.pc + 1 = 8 from by omega] at h; exact h

/-! ## PC 8 — immBorrowField 0 (proof.sigma_proof) -/

theorem step_rotation_pc8 (o : RotationModuleOracle)
    (frame : Frame) (cs : List Frame) (rest : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyRotationProofCode) (hpc : frame.pc = 8)
    (rid : RefId) (proofFields : List MoveValue) (containers' : ContainerStore) (fid : RefId)
    (ref : MoveValue)
    (hRef : getRefId ref = some rid)
    (hread : ms.containers.read rid = some (.struct_ proofFields))
    (hlt : 0 < proofFields.length)
    (halloc : ms.containers.alloc (proofFields[0]'hlt) = (containers', fid)) :
    step (rotationModuleEnv o) frame cs (ref :: rest) ms =
      .ok { frame with pc := 9 } cs (.immRef fid :: rest) { ms with containers := containers' } := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .immBorrowField 0 := by simp only [hcode, hpc]; exact rot_code_pc8
  simp only [step, dif_pos hpc_lt, hc, hRef, hread, dif_pos hlt, halloc]
  rw [show frame.pc + 1 = 9 from by omega]

/-! ## PC 9 — call 0 (verifySigmaProof, 8 args) -/

theorem step_rotation_pc9 (o : RotationModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyRotationProofCode) (hpc : frame.pc = 9)
    (args rest : List MoveValue) (containers' : ContainerStore)
    (htake : takeN stack 8 = some (args, rest))
    (himpl : o.verifySigmaProof ms.containers args = some ([], containers')) :
    step (rotationModuleEnv o) frame cs stack ms =
      .ok { frame with pc := 10 } cs rest { ms with containers := containers', globals := ms.globals } := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .call 0 := by simp only [hcode, hpc]; exact rot_code_pc9
  simp only [step, dif_pos hpc_lt, hc, dif_pos (show 0 < (rotationModuleEnv o).functions.size by simp)]
  simp only [rotationModuleEnv_fn0_numParams, htake, rotationModuleEnv_fn0_body, himpl]
  unfold handleNativeResult
  simp only [rotationModuleEnv_fn0_numReturns, beq_self_eq_true, ↓reduceIte]
  rw [show frame.pc + 1 = 10 from by omega]

theorem step_rotation_pc9_none (o : RotationModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyRotationProofCode) (hpc : frame.pc = 9)
    (args rest : List MoveValue)
    (htake : takeN stack 8 = some (args, rest))
    (himpl : o.verifySigmaProof ms.containers args = none) :
    step (rotationModuleEnv o) frame cs stack ms = .error := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .call 0 := by simp only [hcode, hpc]; exact rot_code_pc9
  simp only [step, dif_pos hpc_lt, hc, dif_pos (show 0 < (rotationModuleEnv o).functions.size by simp)]
  simp only [rotationModuleEnv_fn0_numParams, htake, rotationModuleEnv_fn0_body, himpl]

/-! ## moveLoc PCs 10–11 (after sigma call) -/

theorem step_rotation_pc10 (o : RotationModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyRotationProofCode) (hpc : frame.pc = 10)
    (v : MoveValue) (hlt : 6 < frame.locals.size) (hv : frame.locals[6]'hlt = some v)
    (hRefNone : ¬ 6 < frame.localRefs.size ∨ ∃ h : 6 < frame.localRefs.size, frame.localRefs[6]'h = none) :
    step (rotationModuleEnv o) frame cs stack ms =
      .ok { frame with pc := 11, locals := frame.locals.set 6 none (by omega) } cs (v :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .moveLoc 6 := by simp only [hcode, hpc]; exact rot_code_pc10
  simp only [step, dif_pos hpc_lt, hc, dif_pos hlt, hv]
  rcases hRefNone with hSz | ⟨hSz, hNone⟩
  · simp only [dif_neg hSz]; rw [show frame.pc + 1 = 11 from by omega]
  · simp only [dif_pos hSz, hNone]; rw [show frame.pc + 1 = 11 from by omega]

theorem step_rotation_pc11 (o : RotationModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyRotationProofCode) (hpc : frame.pc = 11)
    (v : MoveValue) (hlt : 7 < frame.locals.size) (hv : frame.locals[7]'hlt = some v)
    (hRefNone : ¬ 7 < frame.localRefs.size ∨ ∃ h : 7 < frame.localRefs.size, frame.localRefs[7]'h = none) :
    step (rotationModuleEnv o) frame cs stack ms =
      .ok { frame with pc := 12, locals := frame.locals.set 7 none (by omega) } cs (v :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .moveLoc 7 := by simp only [hcode, hpc]; exact rot_code_pc11
  simp only [step, dif_pos hpc_lt, hc, dif_pos hlt, hv]
  rcases hRefNone with hSz | ⟨hSz, hNone⟩
  · simp only [dif_neg hSz]; rw [show frame.pc + 1 = 12 from by omega]
  · simp only [dif_pos hSz, hNone]; rw [show frame.pc + 1 = 12 from by omega]

/-! ## PC 12 — immBorrowField 1 (proof.zkrp_new_balance) -/

theorem step_rotation_pc12 (o : RotationModuleOracle)
    (frame : Frame) (cs : List Frame) (rest : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyRotationProofCode) (hpc : frame.pc = 12)
    (rid : RefId) (proofFields : List MoveValue) (containers' : ContainerStore) (fid : RefId)
    (ref : MoveValue)
    (hRef : getRefId ref = some rid)
    (hread : ms.containers.read rid = some (.struct_ proofFields))
    (hlt : 1 < proofFields.length)
    (halloc : ms.containers.alloc (proofFields[1]'hlt) = (containers', fid)) :
    step (rotationModuleEnv o) frame cs (ref :: rest) ms =
      .ok { frame with pc := 13 } cs (.immRef fid :: rest) { ms with containers := containers' } := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .immBorrowField 1 := by simp only [hcode, hpc]; exact rot_code_pc12
  simp only [step, dif_pos hpc_lt, hc, hRef, hread, dif_pos hlt, halloc]
  rw [show frame.pc + 1 = 13 from by omega]

/-! ## PC 13 — call 1 (verifyRangeProof, 2 args) -/

theorem step_rotation_pc13 (o : RotationModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyRotationProofCode) (hpc : frame.pc = 13)
    (args rest : List MoveValue) (containers' : ContainerStore)
    (htake : takeN stack 2 = some (args, rest))
    (himpl : o.verifyRangeProof ms.containers args = some ([], containers')) :
    step (rotationModuleEnv o) frame cs stack ms =
      .ok { frame with pc := 14 } cs rest { ms with containers := containers', globals := ms.globals } := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .call 1 := by simp only [hcode, hpc]; exact rot_code_pc13
  simp only [step, dif_pos hpc_lt, hc, dif_pos (show 1 < (rotationModuleEnv o).functions.size by simp)]
  simp only [rotationModuleEnv_fn1_numParams, htake, rotationModuleEnv_fn1_body, himpl]
  unfold handleNativeResult
  simp only [rotationModuleEnv_fn1_numReturns, beq_self_eq_true, ↓reduceIte]
  rw [show frame.pc + 1 = 14 from by omega]

theorem step_rotation_pc13_none (o : RotationModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyRotationProofCode) (hpc : frame.pc = 13)
    (args rest : List MoveValue)
    (htake : takeN stack 2 = some (args, rest))
    (himpl : o.verifyRangeProof ms.containers args = none) :
    step (rotationModuleEnv o) frame cs stack ms = .error := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .call 1 := by simp only [hcode, hpc]; exact rot_code_pc13
  simp only [step, dif_pos hpc_lt, hc, dif_pos (show 1 < (rotationModuleEnv o).functions.size by simp)]
  simp only [rotationModuleEnv_fn1_numParams, htake, rotationModuleEnv_fn1_body, himpl]

/-! ## PC 14 — ret -/

theorem step_rotation_pc14 (o : RotationModuleOracle)
    (frame : Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyRotationProofCode) (hpc : frame.pc = 14) :
    step (rotationModuleEnv o) frame [] stack ms = .returned stack ms := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .ret := by simp only [hcode, hpc]; exact rot_code_pc14
  exact StepLemmas.step_ret_top hpc_lt hc

end MovementFormal.Experimental.ConfidentialAsset.Rotation.EvalEquiv
