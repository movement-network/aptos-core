import MovementFormal.Experimental.ConfidentialAsset.Registration.FunctionalSim
import MovementFormal.MoveModel.ExecResultDropMs
import MovementFormal.MoveModel.Step
import MovementFormal.MoveModel.Programs.Registration
import MovementFormal.Experimental.ConfidentialAsset.Registration.EvalFuelMonotonicity

/-!
This file is **Part1** of the split `EvalEquiv` proof (see `Registration.EvalEquiv`).
-/


namespace MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquiv

open MovementFormal.MoveModel
open MovementFormal.MoveModel.Native.Registration
open MovementFormal.MoveModel.Programs.Registration
open MovementFormal.Experimental.ConfidentialAsset.Registration.FunctionalSim
open MovementFormal.Experimental.ConfidentialAsset.Registration.Formal

set_option linter.unusedSimpArgs false

/-! ## run unfolding -/

@[simp] theorem run_zero_eq (env frame cs stack ms) :
    run env frame cs stack ms 0 = .error := rfl

theorem run_succ_eq (env : ModuleEnv) (frame : Frame) (cs : List Frame)
    (stack : List MoveValue) (ms : MachineState) (n : Nat) :
    run env frame cs stack ms (n + 1) =
    match step env frame cs stack ms with
    | .ok frame' cs' stack' ms' => run env frame' cs' stack' ms' n
    | result => result := by
  rfl

/-! ## runStep: named wrapper around run's continuation -/

def runStep (env : ModuleEnv) (result : ExecResult) (fuel : Nat) : ExecResult :=
  match result with
  | .ok f cs s ms => run env f cs s ms fuel
  | r => r

@[simp] theorem run_succ_runStep (env : ModuleEnv) (frame : Frame) (cs : List Frame)
    (stack : List MoveValue) (ms : MachineState) (n : Nat) :
    run env frame cs stack ms (n + 1) =
    runStep env (step env frame cs stack ms) n := by
  rfl

@[simp] theorem runStep_handleNativeResult_ret1 (env : ModuleEnv) (fuel : Nat)
    (result : Option (List MoveValue))
    (frame : Frame) (cs : List Frame) (rest : List MoveValue) (ms : MachineState) :
    runStep env (handleNativeResult result 1 frame cs rest ms) fuel =
    (match result with
     | some [v] => run env frame cs (v :: rest) ms fuel
     | _ => .error) := by
  simp only [runStep, handleNativeResult_ret1]
  match result with
  | some [_] => rfl
  | some [] => rfl
  | some (_ :: _ :: _) => rfl
  | none => rfl

@[simp] theorem runStep_handleNativeResult_ret0 (env : ModuleEnv) (fuel : Nat)
    (result : Option (List MoveValue))
    (frame : Frame) (cs : List Frame) (rest : List MoveValue) (ms : MachineState) :
    runStep env (handleNativeResult result 0 frame cs rest ms) fuel =
    (match result with
     | some [] => run env frame cs rest ms fuel
     | _ => .error) := by
  simp only [runStep, handleNativeResult_ret0]
  match result with
  | some [] => rfl
  | some [_] => rfl
  | some (_ :: _ :: _) => rfl
  | none => rfl

@[simp] theorem runStep_ok (env : ModuleEnv) (fuel : Nat) (f : Frame) (cs : List Frame)
    (s : List MoveValue) (ms : MachineState) :
    runStep env (.ok f cs s ms) fuel = run env f cs s ms fuel := rfl

@[simp] theorem runStep_error (env : ModuleEnv) (fuel : Nat) :
    runStep env .error fuel = .error := rfl

@[simp] theorem runStep_returned (env : ModuleEnv) (fuel : Nat) (vals : List MoveValue) (ms : MachineState) :
    runStep env (.returned vals ms) fuel = .returned vals ms := rfl

@[simp] theorem runStep_aborted (env : ModuleEnv) (fuel : Nat) (code : UInt64) :
    runStep env (.aborted code) fuel = .aborted code := rfl

/-! ## single? fusion lemmas

These `@[simp]` lemmas normalize patterns involving `single?` so that the
func side's match trees align structurally with the eval side's
`handleNativeResult_ret1` output (`match x with | some [v] => ...`). -/

@[simp] theorem single?_some_singleton (v : MoveValue) :
    single? (some [v]) = some v := rfl

@[simp] theorem single?_some_nil :
    single? (some ([] : List MoveValue)) = none := rfl

@[simp] theorem single?_none_mv :
    single? (none : Option (List MoveValue)) = none := rfl

/-- Fuse `match (single? x) with | some v => f v | none => g` into
    `match x with | some [v] => f v | _ => g`.

    This is the key lemma bridging the func side (which uses `single?`)
    with the eval side (which matches on `some [v]` directly). -/
@[simp] theorem match_single? {α : Sort _}
    (x : Option (List MoveValue)) (f : MoveValue → α) (g : α) :
    (match single? x with | some v => f v | none => g) =
    (match x with | some [v] => f v | _ => g) := by
  unfold single?
  cases x with
  | none => rfl
  | some l => cases l with
    | nil => rfl
    | cons a t => cases t with
      | nil => rfl
      | cons b r => rfl

/-- Fuse `Option.bind (single? x) f` (from `do` notation in `buildFSMessageMv`). -/
@[simp] theorem bind_single?
    (x : Option (List MoveValue)) (f : MoveValue → Option α) :
    (single? x >>= f) =
    (match x with | some [v] => f v | _ => none) := by
  unfold single?
  cases x with
  | none => rfl
  | some l => cases l with
    | nil => rfl
    | cons a t => cases t with
      | nil => simp [Bind.bind, Option.bind]
      | cons b r => rfl

/-- Fuse an outer `Option` match with a nested `match x with | some [v] => ...`
    pattern — needed when `buildFSMessageMv` (returning `Option MoveValue`)
    is matched by `blockCDE`. -/
@[simp] theorem match_match_some_single_none {β : Type} {α : Sort _}
    (x : Option (List MoveValue)) (inner : MoveValue → Option β) (f : β → α) (g : α) :
    (match (match x with | some [v] => inner v | _ => none) with | some w => f w | none => g) =
    (match x with
     | some [v] => (match inner v with | some w => f w | none => g)
     | _ => g) := by
  cases x with
  | none => simp
  | some l => cases l with
    | nil => simp
    | cons a t => cases t with
      | nil => simp
      | cons b r => simp

/-! ## Registration bytecode: args, frame, `eval` = `run` -/

/-- Canonical 7-tuple of `MoveValue` arguments for `verify_registration_proof`. -/
def registrationVerifyArgs (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray) :
    List MoveValue :=
  [.u8 chainId, .address sender, .address contract,
   .struct_ [.vector .u8 (ekBa.toList.map .u8)],
   .address token,
   .vector .u8 (commitBa.toList.map .u8),
   .vector .u8 (respBa.toList.map .u8)]

/-- Initial `Frame` for `verifyRegistrationProofCode` (matches `eval` on bytecode entry). -/
def registrationInitFrame (args : List MoveValue) : Frame :=
  let numLocals := 19
  { code := verifyRegistrationProofCode
    pc := 0
    locals := (args.map some ++ List.replicate (numLocals - 7) none).toArray
    localRefs := (List.replicate numLocals none).toArray }

theorem registrationVerifyArgs_len (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray) :
    (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa).length = 7 := rfl

theorem registration_module_env_size (o : RegistrationNativeOracle) :
    (registrationModuleEnv o).functions.size = 18 := by
  simp [registrationModuleEnv]

theorem eval_registration_eq_run (o : RegistrationNativeOracle) (args : List MoveValue) (fuel : Nat)
    (ms : MachineState) (_hargs : args.length = 7) :
    eval (registrationModuleEnv o) verifyRegistrationProofIdx args fuel ms =
    run (registrationModuleEnv o) (registrationInitFrame args) [] [] ms fuel := by
  have hidx : verifyRegistrationProofIdx < (registrationModuleEnv o).functions.size := by
    simp [verifyRegistrationProofIdx, registrationModuleEnv]
  simp only [eval, dif_pos hidx]
  have hfdef :
      (registrationModuleEnv o).functions[verifyRegistrationProofIdx]'hidx = verifyRegistrationProofDesc := by
    simp [verifyRegistrationProofIdx, registrationModuleEnv]
  simp only [hfdef]
  cases fuel <;> simp [run, registrationInitFrame, verifyRegistrationProofDesc]

/-! ## `run` composition (for error paths) -/

theorem run_succ_ok (env : ModuleEnv) (f₀ f₁ : Frame) (cs : List Frame) (s₀ s₁ : List MoveValue)
    (ms₀ ms₁ : MachineState) (n : Nat)
    (h₀ : step env f₀ cs s₀ ms₀ = ExecResult.ok f₁ cs s₁ ms₁) :
    run env f₀ cs s₀ ms₀ n.succ = run env f₁ cs s₁ ms₁ n := by
  simp only [run, h₀]

/-- If a single `step` directly returns, then `run` at any positive fuel also returns. -/
theorem run_succ_returned (env : ModuleEnv) (f₀ : Frame) (cs : List Frame) (s₀ : List MoveValue)
    (ms₀ : MachineState) (n : Nat) (vals : List MoveValue) (ms' : MachineState)
    (h₀ : step env f₀ cs s₀ ms₀ = ExecResult.returned vals ms') :
    run env f₀ cs s₀ ms₀ n.succ = ExecResult.returned vals ms' := by
  simp only [run, h₀]

theorem run_error_of_step_error (env : ModuleEnv) (f₀ : Frame) (cs : List Frame) (s₀ : List MoveValue)
    (ms₀ : MachineState) (fuel : Nat) (hf : 0 < fuel)
    (hstep : step env f₀ cs s₀ ms₀ = ExecResult.error) :
    run env f₀ cs s₀ ms₀ fuel = ExecResult.error := by
  cases fuel with
  | zero => nomatch Nat.not_lt_zero _ hf
  | succ fuel' =>
    simp only [run, hstep]

theorem run_ok_then_second_errors (env : ModuleEnv) (f₀ f₁ : Frame) (cs : List Frame)
    (s₀ s₁ : List MoveValue) (ms₀ ms₁ : MachineState) (fuel : Nat) (hf : 2 ≤ fuel)
    (h₀ : step env f₀ cs s₀ ms₀ = ExecResult.ok f₁ cs s₁ ms₁)
    (h₁ : step env f₁ cs s₁ ms₁ = ExecResult.error) :
    run env f₀ cs s₀ ms₀ fuel = ExecResult.error := by
  have h1lt : 1 < fuel := Nat.lt_of_succ_le hf
  have h0fuel : 0 < fuel := Nat.lt_trans (by decide : 0 < 1) h1lt
  have hsub : 0 < fuel - 1 := Nat.sub_pos_of_lt h1lt
  have hfuel : fuel = Nat.succ (fuel - 1) := (Nat.succ_pred_eq_of_pos h0fuel).symm
  rw [hfuel, run_succ_ok env f₀ f₁ cs s₀ s₁ ms₀ ms₁ _ h₀]
  exact run_error_of_step_error env f₁ cs s₁ ms₁ (fuel - 1) hsub h₁

/-! ## Bytecode indices (PC 0–1) for the commitment decompress gate -/

@[simp] theorem verifyRegistrationProofCode_size_val : verifyRegistrationProofCode.size = 84 := rfl

@[simp] theorem verifyRegistrationProofCode_idx0 :
    verifyRegistrationProofCode[0]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .moveLoc 5 := rfl

@[simp] theorem verifyRegistrationProofCode_idx1 :
    verifyRegistrationProofCode[1]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .call 0 := rfl

@[simp] theorem verifyRegistrationProofCode_idx2 :
    verifyRegistrationProofCode[2]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .stLoc 7 := rfl

@[simp] theorem verifyRegistrationProofCode_idx3 :
    verifyRegistrationProofCode[3]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .immBorrowLoc 7 := rfl

@[simp] theorem verifyRegistrationProofCode_idx4 :
    verifyRegistrationProofCode[4]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .call 1 := rfl

@[simp] theorem verifyRegistrationProofCode_idx5 :
    verifyRegistrationProofCode[5]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .brFalse 79 := rfl

@[simp] theorem verifyRegistrationProofCode_idx6 :
    verifyRegistrationProofCode[6]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .mutBorrowLoc 7 := rfl

@[simp] theorem verifyRegistrationProofCode_idx7 :
    verifyRegistrationProofCode[7]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .call 2 := rfl

@[simp] theorem verifyRegistrationProofCode_idx8 :
    verifyRegistrationProofCode[8]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .stLoc 8 := rfl

@[simp] theorem verifyRegistrationProofCode_idx9 :
    verifyRegistrationProofCode[9]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .moveLoc 6 := rfl

@[simp] theorem verifyRegistrationProofCode_idx10 :
    verifyRegistrationProofCode[10]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .call 3 := rfl

@[simp] theorem verifyRegistrationProofCode_idx11 :
    verifyRegistrationProofCode[11]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .stLoc 9 := rfl

@[simp] theorem verifyRegistrationProofCode_idx12 :
    verifyRegistrationProofCode[12]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .immBorrowLoc 9 := rfl

@[simp] theorem verifyRegistrationProofCode_idx13 :
    verifyRegistrationProofCode[13]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .call 1 := rfl

@[simp] theorem verifyRegistrationProofCode_idx14 :
    verifyRegistrationProofCode[14]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .brFalse 74 := rfl

@[simp] theorem takeN_one_singleton (v : MoveValue) : takeN [v] 1 = some ([v], []) := by
  simp [takeN]

@[simp] theorem takeN_two_pair (a b : MoveValue) : takeN [a, b] 2 = some ([b, a], []) := by
  simp [takeN]

@[simp] theorem takeN_two_cons_cons (a b : MoveValue) (rest : List MoveValue) :
    takeN (a :: b :: rest) 2 = some ([b, a], rest) := by
  simp [takeN]

@[simp] theorem takeN_one_cons (a : MoveValue) (rest : List MoveValue) :
    takeN (a :: rest) 1 = some ([a], rest) := by
  simp [takeN]

@[simp] theorem takeN_two_one (a b : MoveValue) : takeN [a, b] 1 = some ([a], [b]) := by
  simp [takeN]

@[simp] theorem takeN_nil_zero : takeN [] 0 = some ([], []) := by
  simp [takeN]

@[simp] theorem registration_env_funcIdx1_lt (o : RegistrationNativeOracle) :
    1 < (registrationModuleEnv o).functions.size := by
  rw [registration_module_env_size o]; decide

@[simp] theorem registrationModuleEnv_functions_at1 (o : RegistrationNativeOracle)
    (h : 1 < (registrationModuleEnv o).functions.size) :
    (registrationModuleEnv o).functions[1]'h = optionIsSomeRefDesc := by
  simp [registrationModuleEnv, optionIsSomeRefDesc]

@[simp] theorem registration_env_funcIdx2_lt (o : RegistrationNativeOracle) :
    2 < (registrationModuleEnv o).functions.size := by
  rw [registration_module_env_size o]; decide

@[simp] theorem registrationModuleEnv_functions_at2 (o : RegistrationNativeOracle)
    (h : 2 < (registrationModuleEnv o).functions.size) :
    (registrationModuleEnv o).functions[2]'h = optionExtractRefDesc := by
  simp [registrationModuleEnv, optionExtractRefDesc]

@[simp] theorem registration_env_funcIdx3_lt (o : RegistrationNativeOracle) :
    3 < (registrationModuleEnv o).functions.size := by
  rw [registration_module_env_size o]; decide

@[simp] theorem registrationModuleEnv_functions_at3 (o : RegistrationNativeOracle)
    (h : 3 < (registrationModuleEnv o).functions.size) :
    (registrationModuleEnv o).functions[3]'h =
      { numParams := 1, numReturns := 1, body := .native o.newScalarFromBytes } := by
  simp [registrationModuleEnv]

/-- `option::is_some` on a ref whose cell holds a struct-encoded `Option` with bool tag `tag`. -/
theorem optionIsSomeRef_of_read_struct_bool (cs : ContainerStore) (id : RefId) (tag : Bool) (rest : List MoveValue)
    (hread : cs.read id = some (.struct_ (.bool tag :: rest))) :
    optionIsSomeRef cs [.immRef id] = some ([.bool tag], cs) := by
  simp [optionIsSomeRef, hread]

/-- First `ContainerStore` cell allocated from `empty` is ref id `0`. -/
@[simp] theorem registration_alloc_empty_fst (mv : MoveValue) :
    (ContainerStore.alloc ContainerStore.empty mv).fst.store = #[mv] := by
  simp [ContainerStore.alloc, ContainerStore.empty, Array.push, Array.size]

@[simp] theorem registration_alloc_empty_snd (mv : MoveValue) :
    (ContainerStore.alloc ContainerStore.empty mv).snd = 0 := by
  simp [ContainerStore.alloc, ContainerStore.empty, Array.push, Array.size]

@[simp] theorem registration_alloc_ms_empty_fst (mv : MoveValue) :
    (ContainerStore.alloc MachineState.empty.containers mv).fst.store = #[mv] := by
  simpa [MachineState.empty, ContainerStore.empty] using registration_alloc_empty_fst mv

@[simp] theorem registration_alloc_ms_empty_snd (mv : MoveValue) :
    (ContainerStore.alloc MachineState.empty.containers mv).snd = 0 := by
  simpa [MachineState.empty, ContainerStore.empty] using registration_alloc_empty_snd mv

/-- Unfold `step` at PC 1 (`call 0`) on the registration frame (generated via `simp?`). -/
local macro "registration_step1_unfold" : tactic =>
  `(tactic| simp only [step, registrationInitFrame, verifyRegistrationProofCode, registrationVerifyArgs,
    List.map_cons, List.map_nil, Nat.reduceSub, List.reduceReplicate, List.cons_append, List.nil_append,
    List.size_toArray, List.length_cons, List.length_nil, zero_add, Nat.reduceAdd, Nat.one_lt_ofNat, ↓reduceDIte,
    List.getElem_toArray, List.getElem_cons_succ, List.getElem_cons_zero, registrationModuleEnv, Nat.ofNat_pos,
    handleNativeResult, Nat.reduceBEq, Bool.false_eq_true, ↓reduceIte, BEq.rfl, List.set_toArray,
    List.set_cons_succ, List.set_cons_zero, beq_iff_eq])

/-- Unfold `step` at PC 4 (`call 1` / `option::is_some` ref) on `registrationFramePc4AfterImmBorrow`. -/
local macro "registration_step_pc4_unfold" : tactic =>
  `(tactic| simp only [step, registrationFramePc4AfterImmBorrow, registrationFramePc3AfterStLoc,
    registrationFrameAtPc2, registrationInitFrame, verifyRegistrationProofCode, registrationVerifyArgs,
    List.map_cons, List.map_nil, Nat.reduceSub, List.reduceReplicate, List.cons_append, List.nil_append,
    List.size_toArray, List.length_cons, List.length_nil, zero_add, Nat.reduceAdd, Nat.one_lt_ofNat, ↓reduceDIte,
    List.getElem_toArray, List.getElem_cons_succ, List.getElem_cons_zero, registrationModuleEnv, Nat.ofNat_pos,
    handleNativeResult, Nat.reduceBEq, Bool.false_eq_true, ↓reduceIte, BEq.rfl, List.set_toArray,
    List.set_cons_succ, List.set_cons_zero, beq_iff_eq, verifyRegistrationProofCode_size_val,
    verifyRegistrationProofCode_idx4, registrationInitFrame_idx5_lt, registration_locals_after_set5_idx7_lt,
    registrationMsAfterImmBorrow7, MachineState.empty, MachineState.containers, MachineState.globals,
    takeN_one_singleton, registration_env_funcIdx1_lt, registrationModuleEnv_functions_at1, FuncDesc.body,
    optionIsSomeRefDesc])

/-- Locals array has length 19 when the entry arguments are the 7 verifier parameters. -/
theorem registrationInitFrame_locals_size (args : List MoveValue) (h : args.length = 7) :
    (registrationInitFrame args).locals.size = 19 := by
  simp [registrationInitFrame, h, List.length_map, List.length_append, List.length_replicate, Nat.add_assoc]

theorem registrationInitFrame_idx5_lt (args : List MoveValue) (h : args.length = 7) :
    5 < (registrationInitFrame args).locals.size := by
  rw [registrationInitFrame_locals_size args h]; decide

theorem registrationInitFrame_idx7_lt (args : List MoveValue) (h : args.length = 7) :
    7 < (registrationInitFrame args).locals.size := by
  rw [registrationInitFrame_locals_size args h]; decide

theorem registration_locals_after_set5_idx7_lt (args : List MoveValue) (h : args.length = 7) :
    7 <
      ((registrationInitFrame args).locals.set 5 none (registrationInitFrame_idx5_lt args h)).size := by
  rw [Array.size_set, registrationInitFrame_locals_size args h]; decide

/-- Frame at PC 2: `moveLoc`/`call 0` done; commitment cleared at local 5; stack will receive `mv` from `call 0`. -/
def registrationFrameAtPc2 (args : List MoveValue) (h : args.length = 7) : Frame :=
  { registrationInitFrame args with
    pc := 2
    locals := (registrationInitFrame args).locals.set 5 none (registrationInitFrame_idx5_lt args h) }

/-- After `stLoc 7` (PC 2): `mv` stored as `r_point` in local 7, PC 3. -/
def registrationFramePc3AfterStLoc (args : List MoveValue) (h : args.length = 7) (mv : MoveValue) : Frame :=
  let locals5 := (registrationInitFrame args).locals.set 5 none (registrationInitFrame_idx5_lt args h)
  { registrationFrameAtPc2 args h with
    pc := 3
    locals := locals5.set 7 (some mv) (registration_locals_after_set5_idx7_lt args h) }

/-- After `immBorrowLoc 7` (PC 3): PC 4, same locals (borrow does not mutate locals in this model). -/
def registrationFramePc4AfterImmBorrow (args : List MoveValue) (h : args.length = 7) (mv : MoveValue) : Frame :=
  { registrationFramePc3AfterStLoc args h mv with pc := 4 }

/-- `MachineState` after allocating local 7’s value for `immBorrowLoc` (first ref id = `0`).

Matches `step`’s `containers.alloc` / `withCG` exactly (so PC 3 proofs close by `rfl`). -/
def registrationMsAfterImmBorrow7 (mv : MoveValue) : MachineState :=
  let p := ContainerStore.alloc MachineState.empty.containers mv
  { MachineState.empty with containers := p.1 }

/-- `step` unfolds `registrationMsAfterImmBorrow7` to `MachineState.empty.containers.alloc …` (same `ContainerStore`). -/
theorem registration_ms_after_immBorrow7_containers (mv : MoveValue) :
    (MachineState.empty.containers.alloc mv).1 = (registrationMsAfterImmBorrow7 mv).containers := rfl

/-- After `immBorrowLoc`, ref `0` reads back the stored `MoveValue` (single-cell store). -/
theorem registration_ms_after_imm_read0 (mv : MoveValue) :
    (registrationMsAfterImmBorrow7 mv).containers.read 0 = some mv := by
  have hstore : (registrationMsAfterImmBorrow7 mv).containers.store = #[mv] := by
    simp [registrationMsAfterImmBorrow7, MachineState.containers, registration_alloc_ms_empty_fst mv]
  simp only [ContainerStore.read, hstore]
  split_ifs with hlt
  · exact congrArg some rfl
  · simp [Array.size] at hlt

theorem registrationFrame_localRefs_size_19 (args : List MoveValue) (h : args.length = 7) (mv : MoveValue) :
    (registrationFramePc4AfterImmBorrow args h mv).localRefs.size = 19 := by
  simp [registrationFramePc4AfterImmBorrow, registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame, h,
    List.size_toArray, List.length_replicate]

theorem registrationFrame_idx7_localRefs_lt (args : List MoveValue) (h : args.length = 7) (mv : MoveValue) :
    7 < (registrationFramePc4AfterImmBorrow args h mv).localRefs.size := by
  rw [registrationFrame_localRefs_size_19 args h mv]; decide

/-- After `mutBorrowLoc 7` at PC 6: duplicate `mv` into ref `1`, record on `localRefs[7]`; PC 7. -/
def registrationFramePc7AfterMutBorrowLoc7 (args : List MoveValue) (h : args.length = 7) (mv : MoveValue) : Frame :=
  let fr := registrationFramePc4AfterImmBorrow args h mv
  { fr with
    pc := 7
    localRefs := fr.localRefs.set 7 (some 1) (registrationFrame_idx7_localRefs_lt args h mv) }

/-- `immBorrow` ref `0` plus `mutBorrow` duplicate: store holds two copies of `mv` at refs `0` and `1`. -/
def registrationMsAfterMutBorrowDup7 (mv : MoveValue) : MachineState :=
  let cs := (registrationMsAfterImmBorrow7 mv).containers
  { MachineState.empty with containers := (cs.alloc mv).1 }

theorem registration_dup7_store (mv : MoveValue) :
    (registrationMsAfterMutBorrowDup7 mv).containers.store = #[mv, mv] := by
  have h1 : (registrationMsAfterImmBorrow7 mv).containers.store = #[mv] := by
    simp [registrationMsAfterImmBorrow7, MachineState.empty, MachineState.containers, ContainerStore.alloc,
      ContainerStore.empty, Array.push]
  simp [registrationMsAfterMutBorrowDup7, ContainerStore.alloc, h1, Array.push]

theorem registration_dup7_read1 (mv : MoveValue) :
    (registrationMsAfterMutBorrowDup7 mv).containers.read 1 = some mv := by
  simp only [ContainerStore.read, registration_dup7_store]
  split_ifs with hlt
  · exact congrArg some rfl
  · simp [Array.size] at hlt

/-- After `option::extract` on ref `1` (`Some` → inner value, cell cleared to `None`). -/
def registrationMsAfterOptionExtractDup1 (mv : MoveValue) : MachineState :=
  match (registrationMsAfterMutBorrowDup7 mv).containers.write 1 (.struct_ [.bool false]) with
  | some cs' => { MachineState.empty with containers := cs' }
  | none => registrationMsAfterMutBorrowDup7 mv

/-- PC 0: `moveLoc 5` — push commitment bytes, clear local 5, PC→1. -/
theorem registration_step0_moveLoc5 (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray) :
    step (registrationModuleEnv o)
        (registrationInitFrame (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa))
        [] [] MachineState.empty =
      ExecResult.ok
        ({ registrationInitFrame (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa) with
            pc := 1,
            locals :=
              (registrationInitFrame (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)).locals.set
                5 none
                (registrationInitFrame_idx5_lt _
                  (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)) })
        []
        [.vector .u8 (commitBa.toList.map .u8)]
        MachineState.empty := by
  simp [step, registrationModuleEnv, registrationInitFrame, registrationVerifyArgs, verifyRegistrationProofCode,
    verifyRegistrationProofCode_size_val, verifyRegistrationProofCode_idx0]

/-- PC 1: `call 0` — `new_compressed_point_from_bytes` returns `none` ⇒ `.error`. -/
theorem registration_step1_call0_none (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (hnone : o.newCompressedPointFromBytes [.vector .u8 (commitBa.toList.map .u8)] = none) :
    step (registrationModuleEnv o)
        ({ registrationInitFrame (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa) with
            pc := 1,
            locals :=
              (registrationInitFrame (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)).locals.set
                5 none
                (registrationInitFrame_idx5_lt _
                  (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)) })
        [] [.vector .u8 (commitBa.toList.map .u8)] MachineState.empty =
      ExecResult.error := by
  registration_step1_unfold
  have hnone' :
      o.newCompressedPointFromBytes
          [.vector .u8 (List.map MoveValue.u8 commitBa.toList)] = none := by
    simpa using hnone
  simp [hnone']

/-- PC 1: `call 0` — non-singleton list ⇒ `.error` (native returns 1 value). -/
theorem registration_step1_call0_not_singleton (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray) (l : List MoveValue)
    (hl : o.newCompressedPointFromBytes [.vector .u8 (commitBa.toList.map .u8)] = some l)
    (hlen : l.length ≠ 1) :
    step (registrationModuleEnv o)
        ({ registrationInitFrame (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa) with
            pc := 1,
            locals :=
              (registrationInitFrame (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)).locals.set
                5 none
                (registrationInitFrame_idx5_lt _
                  (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)) })
        [] [.vector .u8 (commitBa.toList.map .u8)] MachineState.empty =
      ExecResult.error := by
  have hl' :
      o.newCompressedPointFromBytes [.vector .u8 (List.map MoveValue.u8 commitBa.toList)] = some l := by
    simpa using hl
  cases l with
  | nil =>
    registration_step1_unfold
    simp [hl', handleNativeResult]
  | cons a as =>
    cases as with
    | nil =>
      exfalso
      exact hlen (by simp [List.length])
    | cons b t =>
      registration_step1_unfold
      simp [hl', handleNativeResult]

/-- PC 1: `call 0` — singleton `[mv]` ⇒ PC 2 with `mv` on the stack (matches `registrationInitFrame` + cleared local 5). -/
theorem registration_step1_call0_singleton (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray) (mv : MoveValue)
    (hl : o.newCompressedPointFromBytes [.vector .u8 (commitBa.toList.map .u8)] = some [mv]) :
    step (registrationModuleEnv o)
        ({ registrationInitFrame (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa) with
            pc := 1,
            locals :=
              (registrationInitFrame (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)).locals.set
                5 none
                (registrationInitFrame_idx5_lt _
                  (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)) })
        [] [.vector .u8 (commitBa.toList.map .u8)] MachineState.empty =
      ExecResult.ok
        ({ registrationInitFrame (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa) with
            pc := 2,
            locals :=
              (registrationInitFrame (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)).locals.set
                5 none
                (registrationInitFrame_idx5_lt _
                  (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)) })
        []
        [mv]
        MachineState.empty := by
  have hl' :
      o.newCompressedPointFromBytes [.vector .u8 (List.map MoveValue.u8 commitBa.toList)] = some [mv] := by
    simpa using hl
  registration_step1_unfold
  simp [hl', handleNativeResult_ret1]

/-- PC 2: `stLoc 7` — store `mv` as `r_point`, empty stack, PC→3.

This is the first instruction of the bytecode tail (B0 remainder after `call 0`). -/
theorem registration_step_pc2_stLoc7 (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray) (mv : MoveValue) :
    step (registrationModuleEnv o)
        (registrationFrameAtPc2 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa))
        [] [mv] MachineState.empty =
      ExecResult.ok
        (registrationFramePc3AfterStLoc (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv)
        [] [] MachineState.empty := by
  simp [step, registrationModuleEnv, registrationFrameAtPc2, registrationFramePc3AfterStLoc, registrationInitFrame,
    registrationVerifyArgs, verifyRegistrationProofCode, verifyRegistrationProofCode_size_val,
    verifyRegistrationProofCode_idx2, registrationInitFrame_idx5_lt, registration_locals_after_set5_idx7_lt,
    registrationVerifyArgs_len]

/-- PC 3: `immBorrowLoc 7` — push `immRef 0` to `r_point`, PC→4, allocate one container cell. -/
theorem registration_step_pc3_immBorrowLoc7 (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray) (mv : MoveValue) :
    step (registrationModuleEnv o)
        (registrationFramePc3AfterStLoc (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv)
        [] [] MachineState.empty =
      ExecResult.ok
        (registrationFramePc4AfterImmBorrow (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv)
        []
        [.immRef 0]
        (registrationMsAfterImmBorrow7 mv) := by
  simp [step, registrationModuleEnv, registrationFramePc3AfterStLoc, registrationFramePc4AfterImmBorrow,
    registrationFrameAtPc2, registrationInitFrame, registrationVerifyArgs, registrationMsAfterImmBorrow7,
    verifyRegistrationProofCode, verifyRegistrationProofCode_size_val, verifyRegistrationProofCode_idx3,
    registrationInitFrame_idx5_lt, registrationInitFrame_idx7_lt, registrationVerifyArgs_len,
    registration_alloc_empty_fst, registration_alloc_empty_snd, MachineState.ofContainers, ContainerStore.read]

/-- PC 4: `call 1` — `option::is_some` on `&r_point` (ref to struct-encoded `Option` with bool tag). -/
theorem registration_step_pc4_call_optionIsSome (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv : MoveValue) (tag : Bool) (rest : List MoveValue)
    (hmv : mv = .struct_ (.bool tag :: rest)) :
    step (registrationModuleEnv o)
        (registrationFramePc4AfterImmBorrow (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv)
        [] [.immRef 0] (registrationMsAfterImmBorrow7 mv) =
      ExecResult.ok
        ({ registrationFramePc4AfterImmBorrow (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv with
            pc := 5 })
        [] [.bool tag] (registrationMsAfterImmBorrow7 mv) := by
  subst hmv
  let mv' : MoveValue := .struct_ (.bool tag :: rest)
  have hcs := registration_ms_after_immBorrow7_containers mv'
  have hop :=
    optionIsSomeRef_of_read_struct_bool (registrationMsAfterImmBorrow7 mv').containers 0 tag rest
      (registration_ms_after_imm_read0 mv')
  have hopAlloc :
      optionIsSomeRef (MachineState.empty.containers.alloc mv').1 [.immRef 0] =
        some ([.bool tag], (MachineState.empty.containers.alloc mv').1) := by
    have hcs' := hcs.symm
    rw [← congrArg (fun cs : ContainerStore => optionIsSomeRef cs [.immRef 0]) hcs']
    rw [hop]
    exact congrArg some (Prod.ext rfl hcs)
  simp only [step, registrationModuleEnv, registrationFramePc4AfterImmBorrow, registrationFramePc3AfterStLoc,
    registrationFrameAtPc2, registrationInitFrame, registrationVerifyArgs, verifyRegistrationProofCode,
    verifyRegistrationProofCode_size_val, verifyRegistrationProofCode_idx4, registrationInitFrame_idx5_lt,
    registration_locals_after_set5_idx7_lt, registrationVerifyArgs_len, registration_env_funcIdx1_lt,
    registrationModuleEnv_functions_at1, FuncDesc.body, optionIsSomeRefDesc, takeN_one_singleton,
    registrationMsAfterImmBorrow7, MachineState.empty, MachineState.containers, MachineState.globals,
    List.map_cons, List.map_nil, Nat.reduceSub, List.reduceReplicate, List.cons_append, List.nil_append,
    List.size_toArray, List.length_cons, List.length_nil, zero_add, Nat.reduceAdd, Nat.one_lt_ofNat,
    ↓reduceDIte, List.getElem_toArray, List.getElem_cons_succ, List.getElem_cons_zero, Nat.ofNat_pos,
    Nat.reduceBEq, Bool.false_eq_true, ↓reduceIte, BEq.rfl, List.set_toArray, List.set_cons_succ,
    List.set_cons_zero, beq_iff_eq]
  have hstoreeq :
      (ContainerStore.empty.alloc (MoveValue.struct_ (MoveValue.bool tag :: rest))).1 =
        (MachineState.empty.containers.alloc mv').1 := by
    dsimp [mv']
    rfl
  simp_rw [hstoreeq]
  rw [hopAlloc]
  simp only [handleNativeResult]
  rfl

/-- Two `ok` steps in a row: advance `run` by 2 fuel steps. -/
theorem run_succ_succ_ok (env : ModuleEnv) (f₀ f₁ f₂ : Frame) (cs : List Frame)
    (s₀ s₁ s₂ : List MoveValue) (ms₀ ms₁ ms₂ : MachineState) (n : Nat)
    (h₀ : step env f₀ cs s₀ ms₀ = ExecResult.ok f₁ cs s₁ ms₁)
    (h₁ : step env f₁ cs s₁ ms₁ = ExecResult.ok f₂ cs s₂ ms₂) :
    run env f₀ cs s₀ ms₀ n.succ.succ = run env f₂ cs s₂ ms₂ n := by
  simp only [run, h₀, run, h₁]

theorem run_succ_succ_succ_succ_ok (env : ModuleEnv) (f₀ f₁ f₂ f₃ f₄ : Frame) (cs : List Frame)
    (s₀ s₁ s₂ s₃ s₄ : List MoveValue) (ms₀ ms₁ ms₂ ms₃ ms₄ : MachineState) (n : Nat)
    (h₀ : step env f₀ cs s₀ ms₀ = ExecResult.ok f₁ cs s₁ ms₁)
    (h₁ : step env f₁ cs s₁ ms₁ = ExecResult.ok f₂ cs s₂ ms₂)
    (h₂ : step env f₂ cs s₂ ms₂ = ExecResult.ok f₃ cs s₃ ms₃)
    (h₃ : step env f₃ cs s₃ ms₃ = ExecResult.ok f₄ cs s₄ ms₄) :
    run env f₀ cs s₀ ms₀ n.succ.succ.succ.succ = run env f₄ cs s₄ ms₄ n := by
  simp only [run, h₀, run, h₁, run, h₂, run, h₃]

/-- PC 5: `brFalse 79` — if `option::is_some` returned `true`, fall through to PC 6 (no jump). -/
theorem registration_step_pc5_brFalse_fallthrough
    (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv : MoveValue) (tag : Bool) (_rest : List MoveValue)
    (htag : tag = true) :
    step (registrationModuleEnv o)
        ({ registrationFramePc4AfterImmBorrow (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv with
            pc := 5 })
        [] [.bool tag] (registrationMsAfterImmBorrow7 mv) =
      ExecResult.ok
        ({ registrationFramePc4AfterImmBorrow (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv with
            pc := 6 })
        [] [] (registrationMsAfterImmBorrow7 mv) := by
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  let hlen := registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa
  let f5 :=
    ({ registrationFramePc4AfterImmBorrow args hlen mv with pc := 5 })
  have hpc : f5.pc < f5.code.size := by
    simp [f5, registrationFramePc4AfterImmBorrow, registrationFramePc3AfterStLoc, registrationFrameAtPc2,
      registrationInitFrame, verifyRegistrationProofCode_size_val]
  have hc : f5.code[f5.pc]'hpc = MoveInstr.brFalse 79 := by
    simp [f5, registrationFramePc4AfterImmBorrow, registrationFramePc3AfterStLoc, registrationFrameAtPc2,
      registrationInitFrame, verifyRegistrationProofCode_size_val, verifyRegistrationProofCode_idx5]
  subst htag
  rw [step_brFalse_true_stack (registrationModuleEnv o) f5 [] 79 [] (registrationMsAfterImmBorrow7 mv) hpc hc]

/-- PC 6: `mutBorrowLoc 7` — duplicate `r_point` into a fresh `mutRef` (here ref `1`). -/
theorem registration_step_pc6_mutBorrowLoc7 (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray) (mv : MoveValue) :
    step (registrationModuleEnv o)
        ({ registrationFramePc4AfterImmBorrow (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv with pc := 6 })
        [] [] (registrationMsAfterImmBorrow7 mv) =
      ExecResult.ok
        (registrationFramePc7AfterMutBorrowLoc7 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv)
        [] [.mutRef 1] (registrationMsAfterMutBorrowDup7 mv) := by
  simp [step, registrationModuleEnv, registrationFramePc4AfterImmBorrow, registrationFramePc7AfterMutBorrowLoc7,
    registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame, registrationVerifyArgs,
    verifyRegistrationProofCode, verifyRegistrationProofCode_size_val, verifyRegistrationProofCode_idx6,
    registrationInitFrame_idx5_lt, registration_locals_after_set5_idx7_lt, registrationVerifyArgs_len,
    registrationFrame_idx7_localRefs_lt, registrationInitFrame_idx7_lt, registrationInitFrame_locals_size,
    registrationMsAfterImmBorrow7, registrationMsAfterMutBorrowDup7, MachineState.empty, MachineState.containers,
    ContainerStore.alloc, ContainerStore.empty, List.map_cons, List.map_nil, Nat.reduceSub, List.reduceReplicate,
    List.cons_append, List.nil_append, List.size_toArray, List.length_cons, List.length_nil, zero_add, Nat.reduceAdd,
    Nat.one_lt_ofNat, ↓reduceDIte, List.getElem_toArray, List.getElem_cons_succ, List.getElem_cons_zero, Nat.ofNat_pos,
    Nat.reduceBEq, Bool.false_eq_true, ↓reduceIte, BEq.rfl, List.set_toArray, List.set_cons_succ, List.set_cons_zero,
    beq_iff_eq, Array.push]

theorem registration_dup7_size (mv : MoveValue) :
    (registrationMsAfterMutBorrowDup7 mv).containers.store.size = 2 := by
  rw [registration_dup7_store]; rfl

theorem registration_dup7_lt1 (mv : MoveValue) :
    1 < (registrationMsAfterMutBorrowDup7 mv).containers.store.size := by
  rw [registration_dup7_size]; decide

theorem registration_dup7_write1_exists (mv : MoveValue) :
    ∃ cs', (registrationMsAfterMutBorrowDup7 mv).containers.write 1 (.struct_ [.bool false]) = some cs' := by
  refine ⟨⟨(registrationMsAfterMutBorrowDup7 mv).containers.store.set 1 (.struct_ [.bool false])
    (registration_dup7_lt1 mv)⟩, ?_⟩
  simp [ContainerStore.write, registration_dup7_lt1]

theorem registration_write_dup7_eq_option_extract_ms (mv : MoveValue) :
    (registrationMsAfterMutBorrowDup7 mv).containers.write 1 (.struct_ [.bool false]) =
      some (registrationMsAfterOptionExtractDup1 mv).containers := by
  obtain ⟨cs', hw⟩ := registration_dup7_write1_exists mv
  have hms : (registrationMsAfterOptionExtractDup1 mv).containers = cs' := by
    dsimp [registrationMsAfterOptionExtractDup1]
    rw [hw]
  rw [hw, hms]

theorem optionExtractRef_registration_dup7 (mv rCompressed : MoveValue) (rest : List MoveValue)
    (hmv : mv = .struct_ (.bool true :: rCompressed :: rest)) :
    optionExtractRef (registrationMsAfterMutBorrowDup7 mv).containers [.mutRef 1] =
      some ([rCompressed], (registrationMsAfterOptionExtractDup1 mv).containers) := by
  have hread :
      (registrationMsAfterMutBorrowDup7 mv).containers.read 1 =
        some (.struct_ (.bool true :: rCompressed :: rest)) := by
    rw [registration_dup7_read1, hmv]
  exact
    optionExtractRef_mutRef_read_write (registrationMsAfterMutBorrowDup7 mv).containers 1 rCompressed rest
      (registrationMsAfterOptionExtractDup1 mv).containers hread (registration_write_dup7_eq_option_extract_ms mv)

/-- PC 7: `call 2` — `option::extract` on `&mut r_point` (ref `1`). -/
theorem registration_step_pc7_call_optionExtract
    (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed : MoveValue) (rest : List MoveValue)
    (hmv : mv = .struct_ (.bool true :: rCompressed :: rest)) :
    step (registrationModuleEnv o)
        (registrationFramePc7AfterMutBorrowLoc7 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv)
        [] [.mutRef 1] (registrationMsAfterMutBorrowDup7 mv) =
      ExecResult.ok
        ({ registrationFramePc7AfterMutBorrowLoc7 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv with pc := 8 })
        [] [rCompressed] (registrationMsAfterOptionExtractDup1 mv) := by
  have hex := optionExtractRef_registration_dup7 mv rCompressed rest hmv
  simp only [step, registrationModuleEnv, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
    registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame, registrationVerifyArgs,
    verifyRegistrationProofCode, verifyRegistrationProofCode_size_val, verifyRegistrationProofCode_idx7,
    registrationInitFrame_idx5_lt, registration_locals_after_set5_idx7_lt, registrationVerifyArgs_len,
    registration_env_funcIdx2_lt, registrationModuleEnv_functions_at2, FuncDesc.body, optionExtractRefDesc,
    takeN_one_singleton, List.map_cons, List.map_nil, Nat.reduceSub, List.reduceReplicate, List.cons_append,
    List.nil_append, List.size_toArray, List.length_cons, List.length_nil, zero_add, Nat.reduceAdd, Nat.one_lt_ofNat,
    ↓reduceDIte, List.getElem_toArray, List.getElem_cons_succ, List.getElem_cons_zero, Nat.ofNat_pos, Nat.reduceBEq,
    Bool.false_eq_true, ↓reduceIte, BEq.rfl, List.set_toArray, List.set_cons_succ, List.set_cons_zero, beq_iff_eq]
  rw [hex]
  rfl

/-! ### PC 8–14: second block (`stLoc 8`, `moveLoc 6`, `call 3`, `stLoc 9`, `immBorrowLoc 9`, `call 1`, `brFalse 74`) -/

theorem registration_locals_after_set5_idx8_lt (args : List MoveValue) (h : args.length = 7) :
    8 < ((registrationInitFrame args).locals.set 5 none (registrationInitFrame_idx5_lt args h)).size := by
  rw [Array.size_set, registrationInitFrame_locals_size args h]; decide

theorem registration_locals_after_set5_set7_idx8_lt (args : List MoveValue) (h : args.length = 7) (mv : MoveValue) :
    8 < (((registrationInitFrame args).locals.set 5 none (registrationInitFrame_idx5_lt args h)).set 7 (some mv)
          (registration_locals_after_set5_idx7_lt args h)).size := by
  rw [Array.size_set, Array.size_set, registrationInitFrame_locals_size args h]; decide

theorem registration_locals_after_set5_set7_idx9_lt (args : List MoveValue) (h : args.length = 7) (mv : MoveValue) :
    9 < (((registrationInitFrame args).locals.set 5 none (registrationInitFrame_idx5_lt args h)).set 7 (some mv)
          (registration_locals_after_set5_idx7_lt args h)).size := by
  rw [Array.size_set, Array.size_set, registrationInitFrame_locals_size args h]; decide

theorem registration_locals_after_set5_set7_set8_idx9_lt (args : List MoveValue) (h : args.length = 7) (mv rCompressed : MoveValue) :
    9 < ((((registrationInitFrame args).locals.set 5 none (registrationInitFrame_idx5_lt args h)).set 7 (some mv)
          (registration_locals_after_set5_idx7_lt args h)).set 8 (some rCompressed)
          (registration_locals_after_set5_set7_idx8_lt args h mv)).size := by
  rw [Array.size_set, Array.size_set, Array.size_set, registrationInitFrame_locals_size args h]; decide

theorem registrationFramePc7_locals_size (args : List MoveValue) (h : args.length = 7) (mv : MoveValue) :
    (registrationFramePc7AfterMutBorrowLoc7 args h mv).locals.size = 19 := by
  simp [registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
    registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame_locals_size args h]

theorem registrationFramePc7_locals_idx8_lt (args : List MoveValue) (h : args.length = 7) (mv : MoveValue) :
    8 < (registrationFramePc7AfterMutBorrowLoc7 args h mv).locals.size := by
  rw [registrationFramePc7_locals_size args h mv]; decide

/-- Frame after `stLoc 8` (PC 8): local 8 holds `rCompressed`, PC 9, localRefs still has ref 1 on slot 7. -/
def registrationFramePc9AfterStLoc8 (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed : MoveValue) : Frame :=
  let fr := registrationFramePc7AfterMutBorrowLoc7 args h mv
  { fr with
    pc := 9
    locals := fr.locals.set 8 (some rCompressed) (registrationFramePc7_locals_idx8_lt args h mv) }

theorem registrationFramePc9_locals_size (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed : MoveValue) :
    (registrationFramePc9AfterStLoc8 args h mv rCompressed).locals.size = 19 := by
  simp [registrationFramePc9AfterStLoc8, registrationFramePc7_locals_size args h mv]

theorem registrationFramePc9_locals_idx6_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed : MoveValue) :
    6 < (registrationFramePc9AfterStLoc8 args h mv rCompressed).locals.size := by
  rw [registrationFramePc9_locals_size args h mv rCompressed]; decide

theorem registrationFramePc9_localRefs_size (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed : MoveValue) :
    (registrationFramePc9AfterStLoc8 args h mv rCompressed).localRefs.size = 19 := by
  simp [registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7,
    registrationFrame_localRefs_size_19 args h mv]

theorem registrationFramePc9_localRefs_idx6_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed : MoveValue) :
    6 < (registrationFramePc9AfterStLoc8 args h mv rCompressed).localRefs.size := by
  rw [registrationFramePc9_localRefs_size args h mv rCompressed]; decide

/-- Local 6 is unchanged by the earlier setters (5, 7, 8), so it still holds `respBytes`. -/
theorem registrationFramePc9_locals_idx6_eq
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed : MoveValue) :
    (registrationFramePc9AfterStLoc8 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
        (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed).locals[6]'
      (registrationFramePc9_locals_idx6_lt _ _ mv rCompressed) =
      some (.vector .u8 (respBa.toList.map .u8)) := by
  simp [registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7,
    registrationFramePc4AfterImmBorrow, registrationFramePc3AfterStLoc, registrationFrameAtPc2,
    registrationInitFrame, registrationVerifyArgs]

/-- `localRefs[6]` is `none` in the initial frame and all intermediate frames. -/
theorem registrationFramePc9_localRefs_idx6_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed : MoveValue) :
    (registrationFramePc9AfterStLoc8 args h mv rCompressed).localRefs[6]'
      (registrationFramePc9_localRefs_idx6_lt args h mv rCompressed) = none := by
  simp [registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
    registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame]

/-- Frame after `moveLoc 6` (PC 9): local 6 cleared, PC 10, stack gains `respBytes`. -/
def registrationFramePc10AfterMoveLoc6 (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed : MoveValue) : Frame :=
  let fr := registrationFramePc9AfterStLoc8 args h mv rCompressed
  { fr with
    pc := 10
    locals := fr.locals.set 6 none (registrationFramePc9_locals_idx6_lt args h mv rCompressed) }

/-- PC 9: `moveLoc 6` — pop `respBytes` from local 6 (cleared), push to stack, PC→10. -/
theorem registration_step_pc9_moveLoc6 (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed : MoveValue) :
    step (registrationModuleEnv o)
        (registrationFramePc9AfterStLoc8 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed)
        [] [] (registrationMsAfterOptionExtractDup1 mv) =
      ExecResult.ok
        (registrationFramePc10AfterMoveLoc6 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed)
        [] [.vector .u8 (respBa.toList.map .u8)] (registrationMsAfterOptionExtractDup1 mv) := by
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  let hlen : args.length = 7 := registrationVerifyArgs_len _ _ _ _ _ _ _
  have hpc : (registrationFramePc9AfterStLoc8 args hlen mv rCompressed).pc <
      (registrationFramePc9AfterStLoc8 args hlen mv rCompressed).code.size := by
    simp [registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
      registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame, verifyRegistrationProofCode_size_val]
  have hc : (registrationFramePc9AfterStLoc8 args hlen mv rCompressed).code[(registrationFramePc9AfterStLoc8 args hlen mv rCompressed).pc]'hpc
      = MoveInstr.moveLoc 6 := by
    simp [registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
      registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame, verifyRegistrationProofCode_size_val,
      verifyRegistrationProofCode_idx9]
  have hl := registrationFramePc9_locals_idx6_lt args hlen mv rCompressed
  have hlr := registrationFramePc9_localRefs_idx6_lt args hlen mv rCompressed
  have hval := registrationFramePc9_locals_idx6_eq chainId sender contract token ekBa commitBa respBa mv rCompressed
  have href := registrationFramePc9_localRefs_idx6_eq args hlen mv rCompressed
  simp only [step, dif_pos hpc, hc, dif_pos hl, hval, dif_pos hlr, href]
  rfl

/-- Frame after `call 3` (PC 10): stack has `sOpt`, PC 11. Locals & localRefs unchanged from PC 10. -/
def registrationFramePc11AfterCall3 (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed : MoveValue) : Frame :=
  { registrationFramePc10AfterMoveLoc6 args h mv rCompressed with pc := 11 }

/-- PC 10: `call 3` — `new_scalar_from_bytes` on `[respBytes]`. Success case: oracle returns `some [sOpt]`. -/
theorem registration_step_pc10_call3_singleton (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt : MoveValue)
    (hs : o.newScalarFromBytes [.vector .u8 (respBa.toList.map .u8)] = some [sOpt]) :
    step (registrationModuleEnv o)
        (registrationFramePc10AfterMoveLoc6 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed)
        [] [.vector .u8 (respBa.toList.map .u8)] (registrationMsAfterOptionExtractDup1 mv) =
      ExecResult.ok
        (registrationFramePc11AfterCall3 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed)
        [] [sOpt] (registrationMsAfterOptionExtractDup1 mv) := by
  have hs' : o.newScalarFromBytes [.vector .u8 (List.map MoveValue.u8 respBa.toList)] = some [sOpt] := by
    simpa using hs
  simp only [step, registrationModuleEnv, registrationFramePc10AfterMoveLoc6, registrationFramePc9AfterStLoc8,
    registrationFramePc11AfterCall3, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
    registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame, registrationVerifyArgs,
    verifyRegistrationProofCode, verifyRegistrationProofCode_size_val, verifyRegistrationProofCode_idx10,
    registrationInitFrame_idx5_lt, registration_locals_after_set5_idx7_lt, registrationVerifyArgs_len,
    registration_env_funcIdx3_lt, registrationModuleEnv_functions_at3, FuncDesc.body,
    takeN_one_singleton, List.map_cons, List.map_nil, Nat.reduceSub, List.reduceReplicate, List.cons_append,
    List.nil_append, List.size_toArray, List.length_cons, List.length_nil, zero_add, Nat.reduceAdd, Nat.one_lt_ofNat,
    ↓reduceDIte, List.getElem_toArray, List.getElem_cons_succ, List.getElem_cons_zero, Nat.ofNat_pos, Nat.reduceBEq,
    Bool.false_eq_true, ↓reduceIte, BEq.rfl, List.set_toArray, List.set_cons_succ, List.set_cons_zero, beq_iff_eq,
    hs', handleNativeResult_ret1]
  rfl

theorem registrationFramePc11_locals_size (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed : MoveValue) :
    (registrationFramePc11AfterCall3 args h mv rCompressed).locals.size = 19 := by
  simp [registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
    registrationFramePc9_locals_size args h mv rCompressed]

theorem registrationFramePc11_locals_idx9_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed : MoveValue) :
    9 < (registrationFramePc11AfterCall3 args h mv rCompressed).locals.size := by
  rw [registrationFramePc11_locals_size args h mv rCompressed]; decide

/-- Frame after `stLoc 9` (PC 11): local 9 holds `sOpt`, PC 12. -/
def registrationFramePc12AfterStLoc9 (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt : MoveValue) : Frame :=
  let fr := registrationFramePc11AfterCall3 args h mv rCompressed
  { fr with
    pc := 12
    locals := fr.locals.set 9 (some sOpt) (registrationFramePc11_locals_idx9_lt args h mv rCompressed) }

/-- PC 11: `stLoc 9` — pop `sOpt`, store in local 9, PC→12. -/
theorem registration_step_pc11_stLoc9 (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt : MoveValue) :
    step (registrationModuleEnv o)
        (registrationFramePc11AfterCall3 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed)
        [] [sOpt] (registrationMsAfterOptionExtractDup1 mv) =
      ExecResult.ok
        (registrationFramePc12AfterStLoc9 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt)
        [] [] (registrationMsAfterOptionExtractDup1 mv) := by
  simp [step, registrationModuleEnv, registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3,
    registrationFramePc10AfterMoveLoc6, registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7,
    registrationFramePc4AfterImmBorrow, registrationFramePc3AfterStLoc, registrationFrameAtPc2,
    registrationInitFrame, registrationVerifyArgs, verifyRegistrationProofCode, verifyRegistrationProofCode_size_val,
    verifyRegistrationProofCode_idx11, registrationInitFrame_idx5_lt, registration_locals_after_set5_idx7_lt,
    registration_locals_after_set5_set7_idx8_lt, registrationVerifyArgs_len]

/-! ### PC 12–14: second `option::is_some` / `brFalse` -/

/-- `MachineState` after `immBorrowLoc 9` (PC 12): allocates `sOpt` at ref 2. -/
def registrationMsAfterImmBorrow9 (mv sOpt : MoveValue) : MachineState :=
  let cs := (registrationMsAfterOptionExtractDup1 mv).containers
  { MachineState.empty with containers := (cs.alloc sOpt).1 }

theorem registrationFramePc12_locals_size (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt : MoveValue) :
    (registrationFramePc12AfterStLoc9 args h mv rCompressed sOpt).locals.size = 19 := by
  simp [registrationFramePc12AfterStLoc9, registrationFramePc11_locals_size args h mv rCompressed]

theorem registrationFramePc12_locals_idx9_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt : MoveValue) :
    9 < (registrationFramePc12AfterStLoc9 args h mv rCompressed sOpt).locals.size := by
  rw [registrationFramePc12_locals_size args h mv rCompressed sOpt]; decide

theorem registrationFramePc12_localRefs_size (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt : MoveValue) :
    (registrationFramePc12AfterStLoc9 args h mv rCompressed sOpt).localRefs.size = 19 := by
  simp [registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
    registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7,
    registrationFrame_localRefs_size_19 args h mv]

theorem registrationFramePc12_localRefs_idx9_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt : MoveValue) :
    9 < (registrationFramePc12AfterStLoc9 args h mv rCompressed sOpt).localRefs.size := by
  rw [registrationFramePc12_localRefs_size args h mv rCompressed sOpt]; decide

/-- Dup store after PC 12: `[mv, .struct_ [.bool false], sOpt]`. -/
theorem registration_imm9_store (mv sOpt : MoveValue) :
    (registrationMsAfterImmBorrow9 mv sOpt).containers.store =
      (registrationMsAfterOptionExtractDup1 mv).containers.store.push sOpt := by
  simp [registrationMsAfterImmBorrow9, ContainerStore.alloc]

theorem registration_imm9_containers (mv sOpt : MoveValue) :
    ((registrationMsAfterOptionExtractDup1 mv).containers.alloc sOpt).1 =
      (registrationMsAfterImmBorrow9 mv sOpt).containers := rfl

theorem registrationMsAfterOptionExtractDup1_store_size (mv : MoveValue) :
    (registrationMsAfterOptionExtractDup1 mv).containers.store.size = 2 := by
  have heq := registration_write_dup7_eq_option_extract_ms mv
  -- The write is `some c1` with c1 having store.set; compare sizes.
  have hlt := registration_dup7_lt1 mv
  have hw : (registrationMsAfterMutBorrowDup7 mv).containers.write 1 (.struct_ [.bool false]) =
      some ⟨(registrationMsAfterMutBorrowDup7 mv).containers.store.set 1 (.struct_ [.bool false]) hlt⟩ := by
    simp [ContainerStore.write, hlt]
  rw [hw] at heq
  have : (registrationMsAfterOptionExtractDup1 mv).containers.store =
      (registrationMsAfterMutBorrowDup7 mv).containers.store.set 1 (.struct_ [.bool false]) hlt := by
    have h := (Option.some.inj heq).symm
    exact congrArg ContainerStore.store h
  rw [this, Array.size_set, registration_dup7_size]

theorem registrationMsAfterImmBorrow9_store_size (mv sOpt : MoveValue) :
    (registrationMsAfterImmBorrow9 mv sOpt).containers.store.size = 3 := by
  rw [registration_imm9_store]
  rw [Array.size_push, registrationMsAfterOptionExtractDup1_store_size]

/-- After PC 12 imm-borrow, reading ref 2 returns `sOpt`. -/
theorem registration_imm9_read2 (mv sOpt : MoveValue) :
    (registrationMsAfterImmBorrow9 mv sOpt).containers.read 2 = some sOpt := by
  have halloc :
      (registrationMsAfterImmBorrow9 mv sOpt).containers =
        ((registrationMsAfterOptionExtractDup1 mv).containers.alloc sOpt).1 := rfl
  have hid : (((registrationMsAfterOptionExtractDup1 mv).containers.alloc sOpt).2 : Nat) = 2 := by
    simp [ContainerStore.alloc, registrationMsAfterOptionExtractDup1_store_size]
  have hr := ContainerStore.read_of_alloc
    (registrationMsAfterOptionExtractDup1 mv).containers sOpt
    ((registrationMsAfterOptionExtractDup1 mv).containers.alloc sOpt).1
    ((registrationMsAfterOptionExtractDup1 mv).containers.alloc sOpt).2 rfl
  rw [halloc, ← hid]; exact hr

/-- PC 12: `immBorrowLoc 9` — push `immRef 2` for `&sOpt`, allocate ref 2 in container store. -/
theorem registration_step_pc12_immBorrowLoc9 (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt : MoveValue) :
    step (registrationModuleEnv o)
        (registrationFramePc12AfterStLoc9 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt)
        [] [] (registrationMsAfterOptionExtractDup1 mv) =
      ExecResult.ok
        ({ registrationFramePc12AfterStLoc9 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt with
            pc := 13 })
        [] [.immRef 2] (registrationMsAfterImmBorrow9 mv sOpt) := by
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  let hlen : args.length = 7 := registrationVerifyArgs_len _ _ _ _ _ _ _
  have hpc : (registrationFramePc12AfterStLoc9 args hlen mv rCompressed sOpt).pc <
      (registrationFramePc12AfterStLoc9 args hlen mv rCompressed sOpt).code.size := by
    simp [registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
      registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
      registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame, verifyRegistrationProofCode_size_val]
  have hc : (registrationFramePc12AfterStLoc9 args hlen mv rCompressed sOpt).code[(registrationFramePc12AfterStLoc9 args hlen mv rCompressed sOpt).pc]'hpc
      = MoveInstr.immBorrowLoc 9 := by
    simp [registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
      registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
      registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame, verifyRegistrationProofCode_size_val,
      verifyRegistrationProofCode_idx12]
  have hlval :
      (registrationFramePc12AfterStLoc9 args hlen mv rCompressed sOpt).locals[9]'
        (registrationFramePc12_locals_idx9_lt args hlen mv rCompressed sOpt) = some sOpt := by
    simp [registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
      registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
      registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame]
  have hlrval :
      (registrationFramePc12AfterStLoc9 args hlen mv rCompressed sOpt).localRefs[9]'
        (registrationFramePc12_localRefs_idx9_lt args hlen mv rCompressed sOpt) = none := by
    simp [registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
      registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
      registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame]
  simp only [step, dif_pos hpc, hc, dif_pos (registrationFramePc12_locals_idx9_lt args hlen mv rCompressed sOpt),
    hlval, dif_pos (registrationFramePc12_localRefs_idx9_lt args hlen mv rCompressed sOpt), hlrval]
  rfl

/-- PC 13: `call 1` — `option::is_some` on `&s_opt` (ref `2`). Reads tag from the sOpt struct. -/
theorem registration_step_pc13_call_optionIsSome (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt : MoveValue) (stag : Bool) (srest : List MoveValue)
    (hsOpt : sOpt = .struct_ (.bool stag :: srest)) :
    step (registrationModuleEnv o)
        ({ registrationFramePc12AfterStLoc9 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt with
            pc := 13 })
        [] [.immRef 2] (registrationMsAfterImmBorrow9 mv sOpt) =
      ExecResult.ok
        ({ registrationFramePc12AfterStLoc9 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt with
            pc := 14 })
        [] [.bool stag] (registrationMsAfterImmBorrow9 mv sOpt) := by
  have hread : (registrationMsAfterImmBorrow9 mv sOpt).containers.read 2 =
      some (.struct_ (.bool stag :: srest)) := by
    rw [registration_imm9_read2, hsOpt]
  have hop := optionIsSomeRef_of_read_struct_bool
      (registrationMsAfterImmBorrow9 mv sOpt).containers 2 stag srest hread
  simp only [step, registrationModuleEnv, registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3,
    registrationFramePc10AfterMoveLoc6, registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7,
    registrationFramePc4AfterImmBorrow, registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame,
    registrationVerifyArgs, verifyRegistrationProofCode, verifyRegistrationProofCode_size_val,
    verifyRegistrationProofCode_idx13, registrationInitFrame_idx5_lt, registration_locals_after_set5_idx7_lt,
    registrationVerifyArgs_len, registration_env_funcIdx1_lt, registrationModuleEnv_functions_at1, FuncDesc.body,
    optionIsSomeRefDesc, takeN_one_singleton, List.map_cons, List.map_nil, Nat.reduceSub, List.reduceReplicate,
    List.cons_append, List.nil_append, List.size_toArray, List.length_cons, List.length_nil, zero_add, Nat.reduceAdd,
    Nat.reduceLT, Nat.one_lt_ofNat, ↓reduceDIte, List.getElem_toArray, List.getElem_cons_succ,
    List.getElem_cons_zero, Nat.ofNat_pos, Nat.reduceBEq, Bool.false_eq_true, ↓reduceIte, BEq.rfl, List.set_toArray,
    List.set_cons_succ, List.set_cons_zero, beq_iff_eq]
  rw [hop]
  simp only [handleNativeResult_ret1]

/-- PC 14: `brFalse 74` — on success path (`stag = true`), fall through to PC 15. -/
theorem registration_step_pc14_brFalse_fallthrough (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt : MoveValue) (stag : Bool) (_srest : List MoveValue)
    (hstag : stag = true) :
    step (registrationModuleEnv o)
        ({ registrationFramePc12AfterStLoc9 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt with
            pc := 14 })
        [] [.bool stag] (registrationMsAfterImmBorrow9 mv sOpt) =
      ExecResult.ok
        ({ registrationFramePc12AfterStLoc9 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt with
            pc := 15 })
        [] [] (registrationMsAfterImmBorrow9 mv sOpt) := by
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  let hlen := registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa
  let f14 := ({ registrationFramePc12AfterStLoc9 args hlen mv rCompressed sOpt with pc := 14 })
  have hpc : f14.pc < f14.code.size := by
    simp [f14, registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
      registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
      registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame, verifyRegistrationProofCode_size_val]
  have hc : f14.code[f14.pc]'hpc = MoveInstr.brFalse 74 := by
    simp [f14, registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
      registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
      registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame, verifyRegistrationProofCode_size_val,
      verifyRegistrationProofCode_idx14]
  subst hstag
  rw [step_brFalse_true_stack (registrationModuleEnv o) f14 [] 74 [] (registrationMsAfterImmBorrow9 mv sOpt) hpc hc]

/-! ### PC 15–17: second `mutBorrowLoc` / `option::extract` / `stLoc` trio (for `s`) -/

@[simp] theorem verifyRegistrationProofCode_idx15 :
    verifyRegistrationProofCode[15]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .mutBorrowLoc 9 := rfl
@[simp] theorem verifyRegistrationProofCode_idx16 :
    verifyRegistrationProofCode[16]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .call 2 := rfl
@[simp] theorem verifyRegistrationProofCode_idx17 :
    verifyRegistrationProofCode[17]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .stLoc 10 := rfl

/-- `MachineState` after PC 15 `mutBorrowLoc 9`: allocates a duplicate `sOpt` at ref `3` on top of
the PC 12 imm-borrow store. Store is `[mv, .struct_[.bool false], sOpt, sOpt]`. -/
def registrationMsAfterMutBorrow9 (mv sOpt : MoveValue) : MachineState :=
  let cs := (registrationMsAfterImmBorrow9 mv sOpt).containers
  { MachineState.empty with containers := (cs.alloc sOpt).1 }

theorem registration_mut9_store (mv sOpt : MoveValue) :
    (registrationMsAfterMutBorrow9 mv sOpt).containers.store =
      (registrationMsAfterImmBorrow9 mv sOpt).containers.store.push sOpt := by
  simp [registrationMsAfterMutBorrow9, ContainerStore.alloc]

theorem registrationMsAfterMutBorrow9_store_size (mv sOpt : MoveValue) :
    (registrationMsAfterMutBorrow9 mv sOpt).containers.store.size = 4 := by
  rw [registration_mut9_store, Array.size_push, registrationMsAfterImmBorrow9_store_size]

theorem registration_mut9_lt3 (mv sOpt : MoveValue) :
    3 < (registrationMsAfterMutBorrow9 mv sOpt).containers.store.size := by
  rw [registrationMsAfterMutBorrow9_store_size]; decide

/-- After PC 15 mut-borrow, reading ref 3 returns `sOpt`. -/
theorem registration_mut9_read3 (mv sOpt : MoveValue) :
    (registrationMsAfterMutBorrow9 mv sOpt).containers.read 3 = some sOpt := by
  have halloc :
      (registrationMsAfterMutBorrow9 mv sOpt).containers =
        ((registrationMsAfterImmBorrow9 mv sOpt).containers.alloc sOpt).1 := rfl
  have hid : (((registrationMsAfterImmBorrow9 mv sOpt).containers.alloc sOpt).2 : Nat) = 3 := by
    simp [ContainerStore.alloc, registrationMsAfterImmBorrow9_store_size]
  have hr := ContainerStore.read_of_alloc
    (registrationMsAfterImmBorrow9 mv sOpt).containers sOpt
    ((registrationMsAfterImmBorrow9 mv sOpt).containers.alloc sOpt).1
    ((registrationMsAfterImmBorrow9 mv sOpt).containers.alloc sOpt).2 rfl
  rw [halloc, ← hid]; exact hr

/-- Frame after PC 15: localRefs[9] = some 3, PC = 16. -/
def registrationFramePc16AfterMutBorrow9 (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt : MoveValue) : Frame :=
  let fr := registrationFramePc12AfterStLoc9 args h mv rCompressed sOpt
  { fr with
    pc := 16
    localRefs := fr.localRefs.set 9 (some 3) (registrationFramePc12_localRefs_idx9_lt args h mv rCompressed sOpt) }

/-- PC 15: `mutBorrowLoc 9` — duplicate `sOpt` into ref `3`, record on `localRefs[9]`, PC→16. -/
theorem registration_step_pc15_mutBorrowLoc9 (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt : MoveValue) :
    step (registrationModuleEnv o)
        ({ registrationFramePc12AfterStLoc9 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt with
            pc := 15 })
        [] [] (registrationMsAfterImmBorrow9 mv sOpt) =
      ExecResult.ok
        (registrationFramePc16AfterMutBorrow9 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt)
        [] [.mutRef 3] (registrationMsAfterMutBorrow9 mv sOpt) := by
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  let hlen : args.length = 7 := registrationVerifyArgs_len _ _ _ _ _ _ _
  let f15 := ({ registrationFramePc12AfterStLoc9 args hlen mv rCompressed sOpt with pc := 15 })
  have hpc : f15.pc < f15.code.size := by
    simp [f15, registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
      registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
      registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame, verifyRegistrationProofCode_size_val]
  have hc : f15.code[f15.pc]'hpc = MoveInstr.mutBorrowLoc 9 := by
    simp [f15, registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
      registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
      registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame, verifyRegistrationProofCode_size_val,
      verifyRegistrationProofCode_idx15]
  have hlval :
      f15.locals[9]'(registrationFramePc12_locals_idx9_lt args hlen mv rCompressed sOpt) = some sOpt := by
    simp [f15, registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
      registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
      registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame]
  have hlrval :
      f15.localRefs[9]'(registrationFramePc12_localRefs_idx9_lt args hlen mv rCompressed sOpt) = none := by
    simp [f15, registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
      registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
      registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame]
  have hstoreeq :
      ((registrationMsAfterImmBorrow9 mv sOpt).containers.alloc sOpt).2 = 3 := by
    simp [ContainerStore.alloc, registrationMsAfterImmBorrow9_store_size]
  simp only [step, dif_pos hpc, hc, dif_pos (registrationFramePc12_locals_idx9_lt args hlen mv rCompressed sOpt),
    hlval, dif_pos (registrationFramePc12_localRefs_idx9_lt args hlen mv rCompressed sOpt), hlrval, hstoreeq]
  rfl

/-- After `option::extract` on ref `3` (write `.struct_[.bool false]` back). -/
def registrationMsAfterOptionExtractDup3 (mv sOpt : MoveValue) : MachineState :=
  match (registrationMsAfterMutBorrow9 mv sOpt).containers.write 3 (.struct_ [.bool false]) with
  | some cs' => { MachineState.empty with containers := cs' }
  | none => registrationMsAfterMutBorrow9 mv sOpt

theorem registration_mut9_write3_exists (mv sOpt : MoveValue) :
    ∃ cs', (registrationMsAfterMutBorrow9 mv sOpt).containers.write 3 (.struct_ [.bool false]) = some cs' := by
  refine ⟨⟨(registrationMsAfterMutBorrow9 mv sOpt).containers.store.set 3 (.struct_ [.bool false])
    (registration_mut9_lt3 mv sOpt)⟩, ?_⟩
  simp [ContainerStore.write, registration_mut9_lt3]

theorem registration_write_mut9_eq_option_extract_ms (mv sOpt : MoveValue) :
    (registrationMsAfterMutBorrow9 mv sOpt).containers.write 3 (.struct_ [.bool false]) =
      some (registrationMsAfterOptionExtractDup3 mv sOpt).containers := by
  obtain ⟨cs', hw⟩ := registration_mut9_write3_exists mv sOpt
  have hms : (registrationMsAfterOptionExtractDup3 mv sOpt).containers = cs' := by
    dsimp [registrationMsAfterOptionExtractDup3]
    rw [hw]
  rw [hw, hms]

theorem optionExtractRef_registration_mut9 (mv sOpt sVal : MoveValue) (srest' : List MoveValue)
    (hsOpt : sOpt = .struct_ (.bool true :: sVal :: srest')) :
    optionExtractRef (registrationMsAfterMutBorrow9 mv sOpt).containers [.mutRef 3] =
      some ([sVal], (registrationMsAfterOptionExtractDup3 mv sOpt).containers) := by
  have hread :
      (registrationMsAfterMutBorrow9 mv sOpt).containers.read 3 =
        some (.struct_ (.bool true :: sVal :: srest')) := by
    rw [registration_mut9_read3, hsOpt]
  exact
    optionExtractRef_mutRef_read_write (registrationMsAfterMutBorrow9 mv sOpt).containers 3 sVal srest'
      (registrationMsAfterOptionExtractDup3 mv sOpt).containers hread
      (registration_write_mut9_eq_option_extract_ms mv sOpt)

/-- PC 16: `call 2` — `option::extract` on `&mut s_opt` (ref `3`). -/
theorem registration_step_pc16_call_optionExtract (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal : MoveValue) (srest' : List MoveValue)
    (hsOpt : sOpt = .struct_ (.bool true :: sVal :: srest')) :
    step (registrationModuleEnv o)
        (registrationFramePc16AfterMutBorrow9 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt)
        [] [.mutRef 3] (registrationMsAfterMutBorrow9 mv sOpt) =
      ExecResult.ok
        ({ registrationFramePc16AfterMutBorrow9 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt with
            pc := 17 })
        [] [sVal] (registrationMsAfterOptionExtractDup3 mv sOpt) := by
  have hex := optionExtractRef_registration_mut9 mv sOpt sVal srest' hsOpt
  simp only [step, registrationModuleEnv, registrationFramePc16AfterMutBorrow9, registrationFramePc12AfterStLoc9,
    registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6, registrationFramePc9AfterStLoc8,
    registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow, registrationFramePc3AfterStLoc,
    registrationFrameAtPc2, registrationInitFrame, registrationVerifyArgs, verifyRegistrationProofCode,
    verifyRegistrationProofCode_size_val, verifyRegistrationProofCode_idx16, registrationInitFrame_idx5_lt,
    registration_locals_after_set5_idx7_lt, registrationVerifyArgs_len, registration_env_funcIdx2_lt,
    registrationModuleEnv_functions_at2, FuncDesc.body, optionExtractRefDesc, takeN_one_singleton, List.map_cons,
    List.map_nil, Nat.reduceSub, List.reduceReplicate, List.cons_append, List.nil_append, List.size_toArray,
    List.length_cons, List.length_nil, zero_add, Nat.reduceAdd, Nat.reduceLT, Nat.one_lt_ofNat, ↓reduceDIte,
    List.getElem_toArray, List.getElem_cons_succ, List.getElem_cons_zero, Nat.ofNat_pos, Nat.reduceBEq,
    Bool.false_eq_true, ↓reduceIte, BEq.rfl, List.set_toArray, List.set_cons_succ, List.set_cons_zero, beq_iff_eq]
  rw [hex]
  rfl

theorem registrationFramePc16_locals_size (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt : MoveValue) :
    (registrationFramePc16AfterMutBorrow9 args h mv rCompressed sOpt).locals.size = 19 := by
  simp [registrationFramePc16AfterMutBorrow9, registrationFramePc12_locals_size args h mv rCompressed sOpt]

theorem registrationFramePc16_locals_idx10_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt : MoveValue) :
    10 < (registrationFramePc16AfterMutBorrow9 args h mv rCompressed sOpt).locals.size := by
  rw [registrationFramePc16_locals_size args h mv rCompressed sOpt]; decide

/-- Frame after PC 17: locals[10] = some sVal, PC = 18. -/
def registrationFramePc18AfterStLoc10 (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) : Frame :=
  let fr := registrationFramePc16AfterMutBorrow9 args h mv rCompressed sOpt
  { fr with
    pc := 18
    locals := fr.locals.set 10 (some sVal) (registrationFramePc16_locals_idx10_lt args h mv rCompressed sOpt) }

/-- PC 17: `stLoc 10` — pop `sVal`, store in local 10, PC→18. -/
theorem registration_step_pc17_stLoc10 (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal : MoveValue) :
    step (registrationModuleEnv o)
        ({ registrationFramePc16AfterMutBorrow9 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt with
            pc := 17 })
        [] [sVal] (registrationMsAfterOptionExtractDup3 mv sOpt) =
      ExecResult.ok
        (registrationFramePc18AfterStLoc10 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal)
        [] [] (registrationMsAfterOptionExtractDup3 mv sOpt) := by
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  let hlen : args.length = 7 := registrationVerifyArgs_len _ _ _ _ _ _ _
  let f17 := ({ registrationFramePc16AfterMutBorrow9 args hlen mv rCompressed sOpt with pc := 17 })
  have hpc : f17.pc < f17.code.size := by
    simp [f17, registrationFramePc16AfterMutBorrow9, registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3,
      registrationFramePc10AfterMoveLoc6, registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7,
      registrationFramePc4AfterImmBorrow, registrationFramePc3AfterStLoc, registrationFrameAtPc2,
      registrationInitFrame, verifyRegistrationProofCode_size_val]
  have hc : f17.code[f17.pc]'hpc = MoveInstr.stLoc 10 := by
    simp [f17, registrationFramePc16AfterMutBorrow9, registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3,
      registrationFramePc10AfterMoveLoc6, registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7,
      registrationFramePc4AfterImmBorrow, registrationFramePc3AfterStLoc, registrationFrameAtPc2,
      registrationInitFrame, verifyRegistrationProofCode_size_val, verifyRegistrationProofCode_idx17]
  have hlt : 10 < f17.locals.size :=
    registrationFramePc16_locals_idx10_lt args hlen mv rCompressed sOpt
  simp only [step, dif_pos hpc, hc, dif_pos hlt]
  rfl

/-! ### PC 18–20: load DST constant, store as `msg`, take first `&mut msg` -/

@[simp] theorem verifyRegistrationProofCode_idx18 :
    verifyRegistrationProofCode[18]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .ldConst 5 := rfl
@[simp] theorem verifyRegistrationProofCode_idx19 :
    verifyRegistrationProofCode[19]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .stLoc 11 := rfl
@[simp] theorem verifyRegistrationProofCode_idx20 :
    verifyRegistrationProofCode[20]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .mutBorrowLoc 11 := rfl

theorem registrationModuleEnv_constants_idx5 (o : RegistrationNativeOracle)
    (h : 5 < (registrationModuleEnv o).constants.size) :
    (registrationModuleEnv o).constants[5]'h =
      { type := .vector .u8, value := fiatShamirRegistrationDstValue } := by
  simp [registrationModuleEnv, registrationConstPool]

theorem registrationModuleEnv_constants_size_gt5 (o : RegistrationNativeOracle) :
    5 < (registrationModuleEnv o).constants.size := by
  simp [registrationModuleEnv, registrationConstPool]

/-- PC 18: `ldConst 5` — push the DST constant onto stack, PC→19. -/
theorem registration_step_pc18_ldConst5 (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal : MoveValue) :
    step (registrationModuleEnv o)
        (registrationFramePc18AfterStLoc10 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal)
        [] [] (registrationMsAfterOptionExtractDup3 mv sOpt) =
      ExecResult.ok
        ({ registrationFramePc18AfterStLoc10 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 19 })
        [] [fiatShamirRegistrationDstValue] (registrationMsAfterOptionExtractDup3 mv sOpt) := by
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  let hlen : args.length = 7 := registrationVerifyArgs_len _ _ _ _ _ _ _
  let fr' := ({ registrationFramePc16AfterMutBorrow9 args hlen mv rCompressed sOpt with
      pc := 18
      locals := (registrationFramePc16AfterMutBorrow9 args hlen mv rCompressed sOpt).locals.set 10 (some sVal)
        (registrationFramePc16_locals_idx10_lt args hlen mv rCompressed sOpt) })
  have hfr : fr' = registrationFramePc18AfterStLoc10 args hlen mv rCompressed sOpt sVal := rfl
  rw [← hfr]
  have hpc : fr'.pc < fr'.code.size := by
    simp [fr', registrationFramePc16AfterMutBorrow9, registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3,
      registrationFramePc10AfterMoveLoc6, registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7,
      registrationFramePc4AfterImmBorrow, registrationFramePc3AfterStLoc, registrationFrameAtPc2,
      registrationInitFrame, verifyRegistrationProofCode_size_val]
  have hc : fr'.code[fr'.pc]'hpc = MoveInstr.ldConst 5 := by
    simp [fr', registrationFramePc16AfterMutBorrow9, registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3,
      registrationFramePc10AfterMoveLoc6, registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7,
      registrationFramePc4AfterImmBorrow, registrationFramePc3AfterStLoc, registrationFrameAtPc2,
      registrationInitFrame, verifyRegistrationProofCode_size_val, verifyRegistrationProofCode_idx18]
  have hcidx := registrationModuleEnv_constants_size_gt5 o
  have hcv := registrationModuleEnv_constants_idx5 o hcidx
  simp only [step, dif_pos hpc, hc, dif_pos hcidx, hcv]
  rfl

theorem registrationFramePc18_locals_size (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    (registrationFramePc18AfterStLoc10 args h mv rCompressed sOpt sVal).locals.size = 19 := by
  simp [registrationFramePc18AfterStLoc10, registrationFramePc16_locals_size args h mv rCompressed sOpt]

theorem registrationFramePc18_locals_idx11_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    11 < (registrationFramePc18AfterStLoc10 args h mv rCompressed sOpt sVal).locals.size := by
  rw [registrationFramePc18_locals_size args h mv rCompressed sOpt sVal]; decide

/-- Frame after PC 19: locals[11] = some (DST bytes), PC = 20. -/
def registrationFramePc20AfterStLoc11 (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) : Frame :=
  let fr := registrationFramePc18AfterStLoc10 args h mv rCompressed sOpt sVal
  { fr with
    pc := 20
    locals := fr.locals.set 11 (some fiatShamirRegistrationDstValue)
      (registrationFramePc18_locals_idx11_lt args h mv rCompressed sOpt sVal) }

/-- PC 19: `stLoc 11` — pop DST bytes, store in local 11 (`msg`), PC→20. -/
theorem registration_step_pc19_stLoc11 (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal : MoveValue) :
    step (registrationModuleEnv o)
        ({ registrationFramePc18AfterStLoc10 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 19 })
        [] [fiatShamirRegistrationDstValue] (registrationMsAfterOptionExtractDup3 mv sOpt) =
      ExecResult.ok
        (registrationFramePc20AfterStLoc11 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal)
        [] [] (registrationMsAfterOptionExtractDup3 mv sOpt) := by
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  let hlen : args.length = 7 := registrationVerifyArgs_len _ _ _ _ _ _ _
  let f19 := ({ registrationFramePc18AfterStLoc10 args hlen mv rCompressed sOpt sVal with pc := 19 })
  have hpc : f19.pc < f19.code.size := by
    simp [f19, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
      registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
      registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
      registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame, verifyRegistrationProofCode_size_val]
  have hc : f19.code[f19.pc]'hpc = MoveInstr.stLoc 11 := by
    simp [f19, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
      registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
      registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
      registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame, verifyRegistrationProofCode_size_val,
      verifyRegistrationProofCode_idx19]
  have hlt : 11 < f19.locals.size :=
    registrationFramePc18_locals_idx11_lt args hlen mv rCompressed sOpt sVal
  simp only [step, dif_pos hpc, hc, dif_pos hlt]
  rfl

theorem registrationFramePc20_locals_size (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    (registrationFramePc20AfterStLoc11 args h mv rCompressed sOpt sVal).locals.size = 19 := by
  simp [registrationFramePc20AfterStLoc11, registrationFramePc18_locals_size args h mv rCompressed sOpt sVal]

theorem registrationFramePc20_locals_idx11_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    11 < (registrationFramePc20AfterStLoc11 args h mv rCompressed sOpt sVal).locals.size := by
  rw [registrationFramePc20_locals_size args h mv rCompressed sOpt sVal]; decide

theorem registrationFramePc20_localRefs_size (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    (registrationFramePc20AfterStLoc11 args h mv rCompressed sOpt sVal).localRefs.size = 19 := by
  simp [registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
    registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
    registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7,
    registrationFrame_localRefs_size_19 args h mv]

theorem registrationFramePc20_localRefs_idx11_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    11 < (registrationFramePc20AfterStLoc11 args h mv rCompressed sOpt sVal).localRefs.size := by
  rw [registrationFramePc20_localRefs_size args h mv rCompressed sOpt sVal]; decide

/-- `MachineState` after PC 20 `mutBorrowLoc 11`: allocates `msg` (DST bytes) at ref `4`. -/
def registrationMsAfterMutBorrowMsg (mv sOpt : MoveValue) : MachineState :=
  let cs := (registrationMsAfterOptionExtractDup3 mv sOpt).containers
  { MachineState.empty with containers := (cs.alloc fiatShamirRegistrationDstValue).1 }

/-- Frame after PC 20: localRefs[11] = some 4, PC = 21. -/
def registrationFramePc21AfterMutBorrowMsg (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) : Frame :=
  let fr := registrationFramePc20AfterStLoc11 args h mv rCompressed sOpt sVal
  { fr with
    pc := 21
    localRefs := fr.localRefs.set 11 (some 4) (registrationFramePc20_localRefs_idx11_lt args h mv rCompressed sOpt sVal) }

theorem registrationMsAfterOptionExtractDup3_store_size (mv sOpt : MoveValue) :
    (registrationMsAfterOptionExtractDup3 mv sOpt).containers.store.size = 4 := by
  have hw := registration_write_mut9_eq_option_extract_ms mv sOpt
  have hlt := registration_mut9_lt3 mv sOpt
  have hw' : (registrationMsAfterMutBorrow9 mv sOpt).containers.write 3 (.struct_ [.bool false]) =
      some ⟨(registrationMsAfterMutBorrow9 mv sOpt).containers.store.set 3 (.struct_ [.bool false]) hlt⟩ := by
    simp [ContainerStore.write, hlt]
  rw [hw'] at hw
  have : (registrationMsAfterOptionExtractDup3 mv sOpt).containers.store =
      (registrationMsAfterMutBorrow9 mv sOpt).containers.store.set 3 (.struct_ [.bool false]) hlt := by
    have h := (Option.some.inj hw).symm
    exact congrArg ContainerStore.store h
  rw [this, Array.size_set, registrationMsAfterMutBorrow9_store_size]

/-- PC 20: `mutBorrowLoc 11` — allocate `msg` at ref `4`, push `mutRef 4`, PC→21. -/
theorem registration_step_pc20_mutBorrowLoc11 (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal : MoveValue) :
    step (registrationModuleEnv o)
        (registrationFramePc20AfterStLoc11 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal)
        [] [] (registrationMsAfterOptionExtractDup3 mv sOpt) =
      ExecResult.ok
        (registrationFramePc21AfterMutBorrowMsg (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal)
        [] [.mutRef 4] (registrationMsAfterMutBorrowMsg mv sOpt) := by
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  let hlen : args.length = 7 := registrationVerifyArgs_len _ _ _ _ _ _ _
  let fr' := ({ registrationFramePc18AfterStLoc10 args hlen mv rCompressed sOpt sVal with
      pc := 20
      locals := (registrationFramePc18AfterStLoc10 args hlen mv rCompressed sOpt sVal).locals.set 11
        (some fiatShamirRegistrationDstValue)
        (registrationFramePc18_locals_idx11_lt args hlen mv rCompressed sOpt sVal) })
  have hfr : fr' = registrationFramePc20AfterStLoc11 args hlen mv rCompressed sOpt sVal := rfl
  rw [← hfr]
  have hpc : fr'.pc < fr'.code.size := by
    simp [fr', registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
      registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
      registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
      registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame, verifyRegistrationProofCode_size_val]
  have hc : fr'.code[fr'.pc]'hpc = MoveInstr.mutBorrowLoc 11 := by
    simp [fr', registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
      registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
      registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
      registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame, verifyRegistrationProofCode_size_val,
      verifyRegistrationProofCode_idx20]
  have hlval' :
      fr'.locals[11]'(by
        show 11 < fr'.locals.size
        simp [fr', registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
          registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
          registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
          registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame_locals_size args hlen]) =
        some fiatShamirRegistrationDstValue := by
    simp [fr']
  have hlrval' :
      fr'.localRefs[11]'(by
        show 11 < fr'.localRefs.size
        simp [fr', registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
          registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
          registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7,
          registrationFrame_localRefs_size_19 args hlen mv]) = none := by
    simp [fr', registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
      registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
      registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
      registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame]
  have hid :
      ((registrationMsAfterOptionExtractDup3 mv sOpt).containers.alloc fiatShamirRegistrationDstValue).2 = 4 := by
    simp [ContainerStore.alloc, registrationMsAfterOptionExtractDup3_store_size]
  have hlocLt : 11 < fr'.locals.size := by
    show 11 < fr'.locals.size
    simp [fr', registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
      registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
      registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
      registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame_locals_size args hlen]
  have hlocRefLt : 11 < fr'.localRefs.size := by
    show 11 < fr'.localRefs.size
    simp [fr', registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
      registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
      registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7,
      registrationFrame_localRefs_size_19 args hlen mv]
  simp only [step, dif_pos hpc, hc, dif_pos hlocLt, hlval', dif_pos hlocRefLt, hlrval', hid]
  rfl

/-! ### PC 21–23: `moveLoc 0`, `call 4` (`vector::push_back<u8>` chainId), `mutBorrowLoc 11` (reuse) -/

@[simp] theorem verifyRegistrationProofCode_idx21 :
    verifyRegistrationProofCode[21]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .moveLoc 0 := rfl
@[simp] theorem verifyRegistrationProofCode_idx22 :
    verifyRegistrationProofCode[22]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .call 4 := rfl
@[simp] theorem verifyRegistrationProofCode_idx23 :
    verifyRegistrationProofCode[23]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .mutBorrowLoc 11 := rfl

theorem registration_env_funcIdx4_lt (o : RegistrationNativeOracle) :
    4 < (registrationModuleEnv o).functions.size := by
  rw [registration_module_env_size o]; decide

theorem registrationModuleEnv_functions_at4 (o : RegistrationNativeOracle)
    (h : 4 < (registrationModuleEnv o).functions.size) :
    (registrationModuleEnv o).functions[4]'h =
      { numParams := 2, numReturns := 0, body := .nativeRef vectorPushBackU8Ref } := by
  simp [registrationModuleEnv, vectorPushBackU8RefDesc]

theorem registrationFramePc21_locals_size (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    (registrationFramePc21AfterMutBorrowMsg args h mv rCompressed sOpt sVal).locals.size = 19 := by
  simp [registrationFramePc21AfterMutBorrowMsg, registrationFramePc20AfterStLoc11,
    registrationFramePc18_locals_size args h mv rCompressed sOpt sVal]

theorem registrationFramePc21_locals_idx0_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    0 < (registrationFramePc21AfterMutBorrowMsg args h mv rCompressed sOpt sVal).locals.size := by
  rw [registrationFramePc21_locals_size args h mv rCompressed sOpt sVal]; decide

theorem registrationFramePc21_localRefs_size (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    (registrationFramePc21AfterMutBorrowMsg args h mv rCompressed sOpt sVal).localRefs.size = 19 := by
  simp [registrationFramePc21AfterMutBorrowMsg, Array.size_set,
    registrationFramePc20_localRefs_size args h mv rCompressed sOpt sVal]

theorem registrationFramePc21_localRefs_idx0_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    0 < (registrationFramePc21AfterMutBorrowMsg args h mv rCompressed sOpt sVal).localRefs.size := by
  rw [registrationFramePc21_localRefs_size args h mv rCompressed sOpt sVal]; decide

theorem registrationFramePc21_localRefs_idx11_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    11 < (registrationFramePc21AfterMutBorrowMsg args h mv rCompressed sOpt sVal).localRefs.size := by
  rw [registrationFramePc21_localRefs_size args h mv rCompressed sOpt sVal]; decide

theorem registrationFramePc21_locals_idx0_eq
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal : MoveValue) :
    (registrationFramePc21AfterMutBorrowMsg (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
      (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal).locals[0]'
      (registrationFramePc21_locals_idx0_lt _ _ mv rCompressed sOpt sVal) = some (.u8 chainId) := by
  simp [registrationFramePc21AfterMutBorrowMsg, registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10,
    registrationFramePc16AfterMutBorrow9, registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3,
    registrationFramePc10AfterMoveLoc6, registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7,
    registrationFramePc4AfterImmBorrow, registrationFramePc3AfterStLoc, registrationFrameAtPc2,
    registrationInitFrame, registrationVerifyArgs]

theorem registrationFramePc21_localRefs_idx0_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    (registrationFramePc21AfterMutBorrowMsg args h mv rCompressed sOpt sVal).localRefs[0]'
      (registrationFramePc21_localRefs_idx0_lt args h mv rCompressed sOpt sVal) = none := by
  simp [registrationFramePc21AfterMutBorrowMsg, registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10,
    registrationFramePc16AfterMutBorrow9, registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3,
    registrationFramePc10AfterMoveLoc6, registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7,
    registrationFramePc4AfterImmBorrow, registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame]

/-- Frame after PC 21: locals[0] = none, PC = 22. -/
def registrationFramePc22AfterMoveLoc0 (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) : Frame :=
  let fr := registrationFramePc21AfterMutBorrowMsg args h mv rCompressed sOpt sVal
  { fr with
    pc := 22
    locals := fr.locals.set 0 none (registrationFramePc21_locals_idx0_lt args h mv rCompressed sOpt sVal) }

/-- PC 21: `moveLoc 0` — push `chainId`, clear local 0, PC→22. -/
theorem registration_step_pc21_moveLoc0 (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal : MoveValue) :
    step (registrationModuleEnv o)
        (registrationFramePc21AfterMutBorrowMsg (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal)
        [] [.mutRef 4] (registrationMsAfterMutBorrowMsg mv sOpt) =
      ExecResult.ok
        (registrationFramePc22AfterMoveLoc0 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal)
        [] [.u8 chainId, .mutRef 4] (registrationMsAfterMutBorrowMsg mv sOpt) := by
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  let hlen : args.length = 7 := registrationVerifyArgs_len _ _ _ _ _ _ _
  let fr' := registrationFramePc21AfterMutBorrowMsg args hlen mv rCompressed sOpt sVal
  have hpc : fr'.pc < fr'.code.size := by
    simp [fr', registrationFramePc21AfterMutBorrowMsg, registrationFramePc20AfterStLoc11,
      registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9, registrationFramePc12AfterStLoc9,
      registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6, registrationFramePc9AfterStLoc8,
      registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow, registrationFramePc3AfterStLoc,
      registrationFrameAtPc2, registrationInitFrame, verifyRegistrationProofCode_size_val]
  have hc : fr'.code[fr'.pc]'hpc = MoveInstr.moveLoc 0 := by
    simp [fr', registrationFramePc21AfterMutBorrowMsg, registrationFramePc20AfterStLoc11,
      registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9, registrationFramePc12AfterStLoc9,
      registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6, registrationFramePc9AfterStLoc8,
      registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow, registrationFramePc3AfterStLoc,
      registrationFrameAtPc2, registrationInitFrame, verifyRegistrationProofCode_size_val,
      verifyRegistrationProofCode_idx21]
  have hlocLt := registrationFramePc21_locals_idx0_lt args hlen mv rCompressed sOpt sVal
  have hlocRefLt := registrationFramePc21_localRefs_idx0_lt args hlen mv rCompressed sOpt sVal
  have hlocVal := registrationFramePc21_locals_idx0_eq chainId sender contract token ekBa commitBa respBa
    mv rCompressed sOpt sVal
  have hlocRefVal := registrationFramePc21_localRefs_idx0_eq args hlen mv rCompressed sOpt sVal
  simp only [step, dif_pos hpc, hc, dif_pos hlocLt, hlocVal, dif_pos hlocRefLt, hlocRefVal]
  rfl

/-- The DST as `List MoveValue` — same bytes as `Formal.registrationDstBytes` (single source of truth). -/
def fiatShamirRegistrationDstBytesList : List MoveValue :=
  registrationDstBytes.toList.map MoveValue.u8

theorem fiatShamirRegistrationDstValue_eq :
    fiatShamirRegistrationDstValue = .vector .u8 fiatShamirRegistrationDstBytesList :=
  rfl

theorem registrationMsAfterMutBorrowMsg_store_size (mv sOpt : MoveValue) :
    (registrationMsAfterMutBorrowMsg mv sOpt).containers.store.size = 5 := by
  simp [registrationMsAfterMutBorrowMsg, ContainerStore.alloc, Array.size_push,
    registrationMsAfterOptionExtractDup3_store_size]

theorem registration_mutMsg_lt4 (mv sOpt : MoveValue) :
    4 < (registrationMsAfterMutBorrowMsg mv sOpt).containers.store.size := by
  rw [registrationMsAfterMutBorrowMsg_store_size]; decide

theorem registration_mutMsg_read4 (mv sOpt : MoveValue) :
    (registrationMsAfterMutBorrowMsg mv sOpt).containers.read 4 = some fiatShamirRegistrationDstValue := by
  have halloc :
      (registrationMsAfterMutBorrowMsg mv sOpt).containers =
        ((registrationMsAfterOptionExtractDup3 mv sOpt).containers.alloc fiatShamirRegistrationDstValue).1 := rfl
  have hid :
      (((registrationMsAfterOptionExtractDup3 mv sOpt).containers.alloc fiatShamirRegistrationDstValue).2 : Nat) = 4 := by
    simp [ContainerStore.alloc, registrationMsAfterOptionExtractDup3_store_size]
  have hr := ContainerStore.read_of_alloc
    (registrationMsAfterOptionExtractDup3 mv sOpt).containers fiatShamirRegistrationDstValue
    ((registrationMsAfterOptionExtractDup3 mv sOpt).containers.alloc fiatShamirRegistrationDstValue).1
    ((registrationMsAfterOptionExtractDup3 mv sOpt).containers.alloc fiatShamirRegistrationDstValue).2 rfl
  rw [halloc, ← hid]; exact hr

/-- `MachineState` after PC 22 (`vector::push_back<u8>` of `chainId` onto `msg`). -/
def registrationMsAfterPushBackChainId (mv sOpt : MoveValue) (chainId : UInt8) : MachineState :=
  match (registrationMsAfterMutBorrowMsg mv sOpt).containers.write 4
      (.vector .u8 (fiatShamirRegistrationDstBytesList ++ [.u8 chainId])) with
  | some cs' => { MachineState.empty with containers := cs' }
  | none => registrationMsAfterMutBorrowMsg mv sOpt

theorem registration_mutMsg_write4_chainId_exists (mv sOpt : MoveValue) (chainId : UInt8) :
    ∃ cs', (registrationMsAfterMutBorrowMsg mv sOpt).containers.write 4
        (.vector .u8 (fiatShamirRegistrationDstBytesList ++ [.u8 chainId])) = some cs' := by
  refine ⟨⟨(registrationMsAfterMutBorrowMsg mv sOpt).containers.store.set 4
      (.vector .u8 (fiatShamirRegistrationDstBytesList ++ [.u8 chainId]))
      (registration_mutMsg_lt4 mv sOpt)⟩, ?_⟩
  simp [ContainerStore.write, registration_mutMsg_lt4]

theorem registration_write_mutMsg_chainId_eq (mv sOpt : MoveValue) (chainId : UInt8) :
    (registrationMsAfterMutBorrowMsg mv sOpt).containers.write 4
        (.vector .u8 (fiatShamirRegistrationDstBytesList ++ [.u8 chainId])) =
      some (registrationMsAfterPushBackChainId mv sOpt chainId).containers := by
  obtain ⟨cs', hw⟩ := registration_mutMsg_write4_chainId_exists mv sOpt chainId
  have hms : (registrationMsAfterPushBackChainId mv sOpt chainId).containers = cs' := by
    dsimp [registrationMsAfterPushBackChainId]
    rw [hw]
  rw [hw, hms]

theorem vectorPushBackU8Ref_registration_mutMsg_chainId (mv sOpt : MoveValue) (chainId : UInt8) :
    vectorPushBackU8Ref (registrationMsAfterMutBorrowMsg mv sOpt).containers [.mutRef 4, .u8 chainId] =
      some ([], (registrationMsAfterPushBackChainId mv sOpt chainId).containers) := by
  simp only [vectorPushBackU8Ref]
  rw [registration_mutMsg_read4, fiatShamirRegistrationDstValue_eq]
  simp only
  rw [registration_write_mutMsg_chainId_eq mv sOpt chainId]

/-- PC 22: `call 4` — `vector::push_back<u8>(&mut msg, chainId)`; updates ref 4, no return. -/
theorem registration_step_pc22_call_pushBackChainId (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal : MoveValue) :
    step (registrationModuleEnv o)
        (registrationFramePc22AfterMoveLoc0 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal)
        [] [.u8 chainId, .mutRef 4] (registrationMsAfterMutBorrowMsg mv sOpt) =
      ExecResult.ok
        ({ registrationFramePc22AfterMoveLoc0 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 23 })
        [] [] (registrationMsAfterPushBackChainId mv sOpt chainId) := by
  have hnative := vectorPushBackU8Ref_registration_mutMsg_chainId mv sOpt chainId
  simp only [step, registrationModuleEnv, registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
    registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
    registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
    registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
    registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame, registrationVerifyArgs,
    verifyRegistrationProofCode, verifyRegistrationProofCode_size_val, verifyRegistrationProofCode_idx22,
    registrationInitFrame_idx5_lt, registration_locals_after_set5_idx7_lt, registrationVerifyArgs_len,
    registration_env_funcIdx4_lt, registrationModuleEnv_functions_at4, FuncDesc.body, vectorPushBackU8RefDesc,
    takeN_two_pair, List.map_cons, List.map_nil, Nat.reduceSub, List.reduceReplicate, List.cons_append, List.nil_append,
    List.size_toArray, List.length_cons, List.length_nil, zero_add, Nat.reduceAdd, Nat.reduceLT,
    Nat.one_lt_ofNat, ↓reduceDIte, List.getElem_toArray, List.getElem_cons_succ,
    List.getElem_cons_zero, Nat.ofNat_pos, Nat.reduceBEq, Bool.false_eq_true, BEq.rfl, List.set_toArray,
    List.set_cons_succ, List.set_cons_zero, beq_iff_eq]
  rw [hnative]
  simp only [handleNativeResult_ret0]
  rfl

theorem registrationFramePc22_locals_size (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).locals.size = 19 := by
  simp [registrationFramePc22AfterMoveLoc0, Array.size_set,
    registrationFramePc21_locals_size args h mv rCompressed sOpt sVal]

theorem registrationFramePc22_locals_idx11_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    11 < (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).locals.size := by
  rw [registrationFramePc22_locals_size args h mv rCompressed sOpt sVal]; decide

theorem registrationFramePc22_localRefs_size (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).localRefs.size = 19 := by
  simp [registrationFramePc22AfterMoveLoc0,
    registrationFramePc21_localRefs_size args h mv rCompressed sOpt sVal]

theorem registrationFramePc22_localRefs_idx11_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    11 < (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).localRefs.size := by
  rw [registrationFramePc22_localRefs_size args h mv rCompressed sOpt sVal]; decide

theorem registrationFramePc22_locals_idx11_eq
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal : MoveValue) :
    (registrationFramePc22AfterMoveLoc0 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
      (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal).locals[11]'
      (registrationFramePc22_locals_idx11_lt _ _ mv rCompressed sOpt sVal) = some fiatShamirRegistrationDstValue := by
  simp [registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg, registrationFramePc20AfterStLoc11,
    registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9, registrationFramePc12AfterStLoc9,
    registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6, registrationFramePc9AfterStLoc8,
    registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow, registrationFramePc3AfterStLoc,
    registrationFrameAtPc2, registrationInitFrame, registrationVerifyArgs]

theorem registrationFramePc22_localRefs_idx11_eq
    (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).localRefs[11]'
      (registrationFramePc22_localRefs_idx11_lt args h mv rCompressed sOpt sVal) = some 4 := by
  simp [registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg, registrationFramePc20AfterStLoc11,
    registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9, registrationFramePc12AfterStLoc9,
    registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6, registrationFramePc9AfterStLoc8,
    registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow, registrationFramePc3AfterStLoc,
    registrationFrameAtPc2, registrationInitFrame]

/-- PC 23: `mutBorrowLoc 11` — `localRefs[11] = some 4`, push `mutRef 4` (no alloc), PC→24. -/
theorem registration_step_pc23_mutBorrowLoc11 (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal : MoveValue) :
    step (registrationModuleEnv o)
        ({ registrationFramePc22AfterMoveLoc0 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 23 })
        [] [] (registrationMsAfterPushBackChainId mv sOpt chainId) =
      ExecResult.ok
        ({ registrationFramePc22AfterMoveLoc0 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 24 })
        [] [.mutRef 4] (registrationMsAfterPushBackChainId mv sOpt chainId) := by
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  let hlen : args.length = 7 := registrationVerifyArgs_len _ _ _ _ _ _ _
  let fr' := ({ registrationFramePc22AfterMoveLoc0 args hlen mv rCompressed sOpt sVal with pc := 23 })
  have hpc : fr'.pc < fr'.code.size := by
    simp [fr', registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
      registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
      registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
      registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
      registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame,
      verifyRegistrationProofCode_size_val]
  have hc : fr'.code[fr'.pc]'hpc = MoveInstr.mutBorrowLoc 11 := by
    simp [fr', registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
      registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
      registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
      registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
      registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame,
      verifyRegistrationProofCode_size_val, verifyRegistrationProofCode_idx23]
  have hlocLt : 11 < fr'.locals.size :=
    registrationFramePc22_locals_idx11_lt args hlen mv rCompressed sOpt sVal
  have hlocVal := registrationFramePc22_locals_idx11_eq chainId sender contract token ekBa commitBa respBa
    mv rCompressed sOpt sVal
  have hlocRefLt : 11 < fr'.localRefs.size :=
    registrationFramePc22_localRefs_idx11_lt args hlen mv rCompressed sOpt sVal
  have hlocRefVal := registrationFramePc22_localRefs_idx11_eq args hlen mv rCompressed sOpt sVal
  simp only [step, dif_pos hpc, hc, dif_pos hlocLt, hlocVal, dif_pos hlocRefLt, hlocRefVal]
  rfl

/-! ### PC 24–26: `immBorrowLoc 1` (alloc sender at ref 5), `call 5` (`bcs::to_bytes`), `call 6` (`vector::append`) -/

@[simp] theorem verifyRegistrationProofCode_idx24 :
    verifyRegistrationProofCode[24]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .immBorrowLoc 1 := rfl

theorem registrationFramePc22_locals_idx1_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    1 < (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).locals.size := by
  rw [registrationFramePc22_locals_size args h mv rCompressed sOpt sVal]; decide

theorem registrationFramePc22_localRefs_idx1_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    1 < (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).localRefs.size := by
  rw [registrationFramePc22_localRefs_size args h mv rCompressed sOpt sVal]; decide

theorem registrationFramePc22_locals_idx1_eq
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal : MoveValue) :
    (registrationFramePc22AfterMoveLoc0 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
      (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal).locals[1]'
      (registrationFramePc22_locals_idx1_lt _ _ mv rCompressed sOpt sVal) = some (.address sender) := by
  simp [registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg, registrationFramePc20AfterStLoc11,
    registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9, registrationFramePc12AfterStLoc9,
    registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6, registrationFramePc9AfterStLoc8,
    registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow, registrationFramePc3AfterStLoc,
    registrationFrameAtPc2, registrationInitFrame, registrationVerifyArgs]

theorem registrationFramePc22_localRefs_idx1_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).localRefs[1]'
      (registrationFramePc22_localRefs_idx1_lt args h mv rCompressed sOpt sVal) = none := by
  simp [registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg, registrationFramePc20AfterStLoc11,
    registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9, registrationFramePc12AfterStLoc9,
    registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6, registrationFramePc9AfterStLoc8,
    registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow, registrationFramePc3AfterStLoc,
    registrationFrameAtPc2, registrationInitFrame]

theorem registrationMsAfterPushBackChainId_store_size (mv sOpt : MoveValue) (chainId : UInt8) :
    (registrationMsAfterPushBackChainId mv sOpt chainId).containers.store.size = 5 := by
  have hw := registration_write_mutMsg_chainId_eq mv sOpt chainId
  have hlt := registration_mutMsg_lt4 mv sOpt
  have hw' : (registrationMsAfterMutBorrowMsg mv sOpt).containers.write 4
      (.vector .u8 (fiatShamirRegistrationDstBytesList ++ [.u8 chainId])) =
      some ⟨(registrationMsAfterMutBorrowMsg mv sOpt).containers.store.set 4
        (.vector .u8 (fiatShamirRegistrationDstBytesList ++ [.u8 chainId])) hlt⟩ := by
    simp [ContainerStore.write, hlt]
  rw [hw'] at hw
  have hstore : (registrationMsAfterPushBackChainId mv sOpt chainId).containers.store =
      (registrationMsAfterMutBorrowMsg mv sOpt).containers.store.set 4
        (.vector .u8 (fiatShamirRegistrationDstBytesList ++ [.u8 chainId])) hlt := by
    have h := (Option.some.inj hw).symm
    exact congrArg ContainerStore.store h
  rw [hstore, Array.size_set, registrationMsAfterMutBorrowMsg_store_size]

/-- Frame after PC 24: `immBorrowLoc` does not update `localRefs`; only `pc` advances. -/
def registrationFramePc25AfterImmBorrow1 (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) : Frame :=
  { registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal with pc := 25 }

/-- `MachineState` after PC 24: `sender` address allocated at ref 5. -/
def registrationMsAfterImmBorrow1_sender (mv sOpt : MoveValue) (chainId : UInt8) (sender : ByteArray) : MachineState :=
  let cs := (registrationMsAfterPushBackChainId mv sOpt chainId).containers
  { MachineState.empty with containers := (cs.alloc (.address sender)).1 }

/-- PC 24: `immBorrowLoc 1` — alloc `sender` at ref 5, push `immRef 5`, PC→25. -/
theorem registration_step_pc24_immBorrowLoc1 (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal : MoveValue) :
    step (registrationModuleEnv o)
        ({ registrationFramePc22AfterMoveLoc0 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 24 })
        [] [.mutRef 4] (registrationMsAfterPushBackChainId mv sOpt chainId) =
      ExecResult.ok
        (registrationFramePc25AfterImmBorrow1 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal)
        [] [.immRef 5, .mutRef 4] (registrationMsAfterImmBorrow1_sender mv sOpt chainId sender) := by
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  let hlen : args.length = 7 := registrationVerifyArgs_len _ _ _ _ _ _ _
  let fr' := ({ registrationFramePc22AfterMoveLoc0 args hlen mv rCompressed sOpt sVal with pc := 24 })
  have hpc : fr'.pc < fr'.code.size := by
    simp [fr', registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
      registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
      registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
      registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
      registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame, verifyRegistrationProofCode_size_val]
  have hc : fr'.code[fr'.pc]'hpc = MoveInstr.immBorrowLoc 1 := by
    simp [fr', registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
      registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
      registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
      registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
      registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame, verifyRegistrationProofCode_size_val,
      verifyRegistrationProofCode_idx24]
  have hlocLt : 1 < fr'.locals.size :=
    registrationFramePc22_locals_idx1_lt args hlen mv rCompressed sOpt sVal
  have hlocVal := registrationFramePc22_locals_idx1_eq chainId sender contract token ekBa commitBa respBa
    mv rCompressed sOpt sVal
  have hlocRefLt : 1 < fr'.localRefs.size :=
    registrationFramePc22_localRefs_idx1_lt args hlen mv rCompressed sOpt sVal
  have hlocRefVal := registrationFramePc22_localRefs_idx1_eq args hlen mv rCompressed sOpt sVal
  simp only [step, dif_pos hpc, hc, dif_pos hlocLt, hlocVal, dif_pos hlocRefLt, hlocRefVal]
  rfl

/-! ### PC 25: `call 5` = `bcs::to_bytes<address>(&sender)` (nativeRef, 1 param, 1 ret) -/

@[simp] theorem verifyRegistrationProofCode_idx25 :
    verifyRegistrationProofCode[25]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .call 5 := rfl

theorem registration_env_funcIdx5_lt (o : RegistrationNativeOracle) :
    5 < (registrationModuleEnv o).functions.size := by
  rw [registration_module_env_size o]; decide

theorem registrationModuleEnv_functions_at5 (o : RegistrationNativeOracle)
    (h : 5 < (registrationModuleEnv o).functions.size) :
    (registrationModuleEnv o).functions[5]'h =
      { numParams := 1, numReturns := 1, body := .nativeRef bcsToBytesAddressRef } := by
  simp [registrationModuleEnv, bcsToBytesAddressRefDesc]

theorem registration_imm5_read_sender (mv sOpt : MoveValue) (chainId : UInt8) (sender : ByteArray) :
    (registrationMsAfterImmBorrow1_sender mv sOpt chainId sender).containers.read 5 = some (.address sender) := by
  have halloc :
      (registrationMsAfterImmBorrow1_sender mv sOpt chainId sender).containers =
        ((registrationMsAfterPushBackChainId mv sOpt chainId).containers.alloc (.address sender)).1 := rfl
  have hid :
      (((registrationMsAfterPushBackChainId mv sOpt chainId).containers.alloc (.address sender)).2 : Nat) = 5 := by
    simp [ContainerStore.alloc, registrationMsAfterPushBackChainId_store_size]
  have hr := ContainerStore.read_of_alloc
    (registrationMsAfterPushBackChainId mv sOpt chainId).containers (.address sender)
    ((registrationMsAfterPushBackChainId mv sOpt chainId).containers.alloc (.address sender)).1
    ((registrationMsAfterPushBackChainId mv sOpt chainId).containers.alloc (.address sender)).2 rfl
  rw [halloc, ← hid]; exact hr

theorem bcsToBytesAddressRef_registration_sender (mv sOpt : MoveValue) (chainId : UInt8) (sender : ByteArray) :
    bcsToBytesAddressRef (registrationMsAfterImmBorrow1_sender mv sOpt chainId sender).containers [.immRef 5] =
      some ([.vector .u8 (sender.toList.map .u8)],
        (registrationMsAfterImmBorrow1_sender mv sOpt chainId sender).containers) := by
  simp only [bcsToBytesAddressRef]
  rw [registration_imm5_read_sender]

/-- PC 25: `call 5` — `bcs::to_bytes<address>(&sender)`; pushes `senderBytes`, no ms change. -/
theorem registration_step_pc25_call_bcsToBytes_sender (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal : MoveValue) :
    step (registrationModuleEnv o)
        (registrationFramePc25AfterImmBorrow1 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal)
        [] [.immRef 5, .mutRef 4] (registrationMsAfterImmBorrow1_sender mv sOpt chainId sender) =
      ExecResult.ok
        ({ registrationFramePc25AfterImmBorrow1 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 26 })
        [] [.vector .u8 (sender.toList.map .u8), .mutRef 4]
        (registrationMsAfterImmBorrow1_sender mv sOpt chainId sender) := by
  have hnative := bcsToBytesAddressRef_registration_sender mv sOpt chainId sender
  simp only [step, registrationModuleEnv, registrationFramePc25AfterImmBorrow1,
    registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
    registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
    registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
    registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
    registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame, registrationVerifyArgs,
    verifyRegistrationProofCode, verifyRegistrationProofCode_size_val, verifyRegistrationProofCode_idx25,
    registrationInitFrame_idx5_lt, registration_locals_after_set5_idx7_lt, registrationVerifyArgs_len,
    registration_env_funcIdx5_lt, registrationModuleEnv_functions_at5, FuncDesc.body, bcsToBytesAddressRefDesc,
    takeN_two_one, List.map_cons, List.map_nil, Nat.reduceSub, List.reduceReplicate,
    List.cons_append, List.nil_append, List.size_toArray, List.length_cons, List.length_nil, zero_add,
    Nat.reduceAdd, Nat.reduceLT, Nat.one_lt_ofNat, ↓reduceDIte, List.getElem_toArray, List.getElem_cons_succ,
    List.getElem_cons_zero, Nat.ofNat_pos, Nat.reduceBEq, Bool.false_eq_true, BEq.rfl, List.set_toArray,
    List.set_cons_succ, List.set_cons_zero, beq_iff_eq]
  rw [hnative]
  simp only [handleNativeResult_ret1]

/-! ### PC 26: `call 6` = `vector::append<u8>(&mut msg, senderBytes)` (nativeRef, 2 params, 0 ret) -/

@[simp] theorem verifyRegistrationProofCode_idx26 :
    verifyRegistrationProofCode[26]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .call 6 := rfl

theorem registration_env_funcIdx6_lt (o : RegistrationNativeOracle) :
    6 < (registrationModuleEnv o).functions.size := by
  rw [registration_module_env_size o]; decide

theorem registrationModuleEnv_functions_at6 (o : RegistrationNativeOracle)
    (h : 6 < (registrationModuleEnv o).functions.size) :
    (registrationModuleEnv o).functions[6]'h =
      { numParams := 2, numReturns := 0, body := .nativeRef vectorAppendU8Ref } := by
  simp [registrationModuleEnv, vectorAppendU8RefDesc]

theorem registrationMsAfterImmBorrow1_sender_store_size
    (mv sOpt : MoveValue) (chainId : UInt8) (sender : ByteArray) :
    (registrationMsAfterImmBorrow1_sender mv sOpt chainId sender).containers.store.size = 6 := by
  simp [registrationMsAfterImmBorrow1_sender, ContainerStore.alloc, Array.size_push,
    registrationMsAfterPushBackChainId_store_size]

theorem registration_sender_lt4 (mv sOpt : MoveValue) (chainId : UInt8) (sender : ByteArray) :
    4 < (registrationMsAfterImmBorrow1_sender mv sOpt chainId sender).containers.store.size := by
  rw [registrationMsAfterImmBorrow1_sender_store_size]; decide

/-- Reading ref 4 in `registrationMsAfterImmBorrow1_sender` gives back the msg DST++chainId value. -/
theorem registration_sender_read4 (mv sOpt : MoveValue) (chainId : UInt8) (sender : ByteArray) :
    (registrationMsAfterImmBorrow1_sender mv sOpt chainId sender).containers.read 4 =
      some (.vector .u8 (fiatShamirRegistrationDstBytesList ++ [.u8 chainId])) := by
  have hwrite := registration_write_mutMsg_chainId_eq mv sOpt chainId
  have hlt := registration_mutMsg_lt4 mv sOpt
  have hwrite' : (registrationMsAfterMutBorrowMsg mv sOpt).containers.write 4
      (.vector .u8 (fiatShamirRegistrationDstBytesList ++ [.u8 chainId])) =
      some ⟨(registrationMsAfterMutBorrowMsg mv sOpt).containers.store.set 4
        (.vector .u8 (fiatShamirRegistrationDstBytesList ++ [.u8 chainId])) hlt⟩ := by
    simp [ContainerStore.write, hlt]
  rw [hwrite'] at hwrite
  have hstoreChainId : (registrationMsAfterPushBackChainId mv sOpt chainId).containers.store =
      (registrationMsAfterMutBorrowMsg mv sOpt).containers.store.set 4
        (.vector .u8 (fiatShamirRegistrationDstBytesList ++ [.u8 chainId])) hlt := by
    have h := (Option.some.inj hwrite).symm
    exact congrArg ContainerStore.store h
  have hchainRead4 : (registrationMsAfterPushBackChainId mv sOpt chainId).containers.read 4 =
      some (.vector .u8 (fiatShamirRegistrationDstBytesList ++ [.u8 chainId])) := by
    simp only [ContainerStore.read, hstoreChainId, Array.getElem?_set]
    simp [Array.size_set, registrationMsAfterMutBorrowMsg_store_size]
  have hallocSender : (registrationMsAfterImmBorrow1_sender mv sOpt chainId sender).containers =
      ((registrationMsAfterPushBackChainId mv sOpt chainId).containers.alloc (.address sender)).1 := rfl
  rw [hallocSender]
  simp only [ContainerStore.alloc, ContainerStore.read]
  have hlt4 : (4 : Nat) < (registrationMsAfterPushBackChainId mv sOpt chainId).containers.store.size := by
    rw [registrationMsAfterPushBackChainId_store_size]; decide
  have hlt4' : (4 : Nat) < ((registrationMsAfterPushBackChainId mv sOpt chainId).containers.store.push (.address sender)).size := by
    rw [Array.size_push]; omega
  simp only [dif_pos hlt4']
  rw [Array.getElem_push_lt hlt4]
  have := hchainRead4
  simp only [ContainerStore.read, dif_pos hlt4] at this
  exact this

/-- `MachineState` after PC 26: `msg` at ref 4 is now DST ++ [chainId] ++ senderBytes. -/
def registrationMsAfterAppendSender (mv sOpt : MoveValue) (chainId : UInt8) (sender : ByteArray) : MachineState :=
  match (registrationMsAfterImmBorrow1_sender mv sOpt chainId sender).containers.write 4
      (.vector .u8 ((fiatShamirRegistrationDstBytesList ++ [.u8 chainId]) ++ sender.toList.map .u8)) with
  | some cs' => { MachineState.empty with containers := cs' }
  | none => registrationMsAfterImmBorrow1_sender mv sOpt chainId sender

theorem registration_write_append_sender_eq (mv sOpt : MoveValue) (chainId : UInt8) (sender : ByteArray) :
    (registrationMsAfterImmBorrow1_sender mv sOpt chainId sender).containers.write 4
        (.vector .u8 ((fiatShamirRegistrationDstBytesList ++ [.u8 chainId]) ++ sender.toList.map .u8)) =
      some (registrationMsAfterAppendSender mv sOpt chainId sender).containers := by
  have hlt := registration_sender_lt4 mv sOpt chainId sender
  have hw : (registrationMsAfterImmBorrow1_sender mv sOpt chainId sender).containers.write 4
      (.vector .u8 ((fiatShamirRegistrationDstBytesList ++ [.u8 chainId]) ++ sender.toList.map .u8)) =
      some ⟨(registrationMsAfterImmBorrow1_sender mv sOpt chainId sender).containers.store.set 4
        (.vector .u8 ((fiatShamirRegistrationDstBytesList ++ [.u8 chainId]) ++ sender.toList.map .u8)) hlt⟩ := by
    simp [ContainerStore.write, hlt]
  have hms : (registrationMsAfterAppendSender mv sOpt chainId sender).containers =
      ⟨(registrationMsAfterImmBorrow1_sender mv sOpt chainId sender).containers.store.set 4
        (.vector .u8 ((fiatShamirRegistrationDstBytesList ++ [.u8 chainId]) ++ sender.toList.map .u8)) hlt⟩ := by
    dsimp [registrationMsAfterAppendSender]
    rw [hw]
  rw [hw, hms]

theorem vectorAppendU8Ref_registration_sender (mv sOpt : MoveValue) (chainId : UInt8) (sender : ByteArray) :
    vectorAppendU8Ref (registrationMsAfterImmBorrow1_sender mv sOpt chainId sender).containers
        [.mutRef 4, .vector .u8 (sender.toList.map .u8)] =
      some ([], (registrationMsAfterAppendSender mv sOpt chainId sender).containers) := by
  simp only [vectorAppendU8Ref]
  rw [registration_sender_read4]
  simp only
  rw [registration_write_append_sender_eq mv sOpt chainId sender]

/-- PC 26: `call 6` — `vector::append<u8>(&mut msg, senderBytes)`; updates ref 4 with DST ++ [chainId] ++ senderBytes. -/
theorem registration_step_pc26_call_appendSender (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal : MoveValue) :
    step (registrationModuleEnv o)
        ({ registrationFramePc25AfterImmBorrow1 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 26 })
        [] [.vector .u8 (sender.toList.map .u8), .mutRef 4]
        (registrationMsAfterImmBorrow1_sender mv sOpt chainId sender) =
      ExecResult.ok
        ({ registrationFramePc25AfterImmBorrow1 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 27 })
        [] [] (registrationMsAfterAppendSender mv sOpt chainId sender) := by
  have hnative := vectorAppendU8Ref_registration_sender mv sOpt chainId sender
  simp only [step, registrationModuleEnv, registrationFramePc25AfterImmBorrow1,
    registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
    registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
    registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
    registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
    registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame, registrationVerifyArgs,
    verifyRegistrationProofCode, verifyRegistrationProofCode_size_val, verifyRegistrationProofCode_idx26,
    registrationInitFrame_idx5_lt, registration_locals_after_set5_idx7_lt, registrationVerifyArgs_len,
    registration_env_funcIdx6_lt, registrationModuleEnv_functions_at6, FuncDesc.body, vectorAppendU8RefDesc,
    takeN_two_pair, List.map_cons, List.map_nil, Nat.reduceSub, List.reduceReplicate, List.cons_append,
    List.nil_append, List.size_toArray, List.length_cons, List.length_nil, zero_add, Nat.reduceAdd,
    Nat.reduceLT, Nat.one_lt_ofNat, ↓reduceDIte, List.getElem_toArray, List.getElem_cons_succ,
    List.getElem_cons_zero, Nat.ofNat_pos, Nat.reduceBEq, Bool.false_eq_true, BEq.rfl, List.set_toArray,
    List.set_cons_succ, List.set_cons_zero, beq_iff_eq]
  rw [hnative]
  simp only [handleNativeResult_ret0]
  rfl

/-! ### PC 27: `mutBorrowLoc 11` — reuse ref 4, same as PC 23. -/

@[simp] theorem verifyRegistrationProofCode_idx27 :
    verifyRegistrationProofCode[27]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .mutBorrowLoc 11 := rfl

set_option maxHeartbeats 800000 in
theorem registration_step_pc27_mutBorrowLoc11 (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal : MoveValue) :
    step (registrationModuleEnv o)
        ({ registrationFramePc22AfterMoveLoc0 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 27 })
        [] [] (registrationMsAfterAppendSender mv sOpt chainId sender) =
      ExecResult.ok
        ({ registrationFramePc22AfterMoveLoc0 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 28 })
        [] [.mutRef 4] (registrationMsAfterAppendSender mv sOpt chainId sender) := by
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  let hlen : args.length = 7 := registrationVerifyArgs_len _ _ _ _ _ _ _
  let fr' := ({ registrationFramePc22AfterMoveLoc0 args hlen mv rCompressed sOpt sVal with pc := 27 })
  have hpc : fr'.pc < fr'.code.size := by
    simp [fr', registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
      registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
      registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
      registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
      registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame,
      verifyRegistrationProofCode_size_val]
  have hc : fr'.code[fr'.pc]'hpc = MoveInstr.mutBorrowLoc 11 := by
    simp [fr', registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
      registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
      registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
      registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
      registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame,
      verifyRegistrationProofCode_size_val, verifyRegistrationProofCode_idx27]
  have hlocLt : 11 < fr'.locals.size :=
    registrationFramePc22_locals_idx11_lt args hlen mv rCompressed sOpt sVal
  have hlocVal := registrationFramePc22_locals_idx11_eq chainId sender contract token ekBa commitBa respBa
    mv rCompressed sOpt sVal
  have hlocRefLt : 11 < fr'.localRefs.size :=
    registrationFramePc22_localRefs_idx11_lt args hlen mv rCompressed sOpt sVal
  have hlocRefVal := registrationFramePc22_localRefs_idx11_eq args hlen mv rCompressed sOpt sVal
  simp only [step, dif_pos hpc, hc, dif_pos hlocLt, hlocVal, dif_pos hlocRefLt, hlocRefVal]
  rfl

/-! ### PC 28–30: `immBorrowLoc 2` (alloc contract at ref 6), `call 5` (`bcs::to_bytes`), `call 6` (`vector::append`) -/

@[simp] theorem verifyRegistrationProofCode_idx28 :
    verifyRegistrationProofCode[28]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .immBorrowLoc 2 := rfl

theorem registrationFramePc22_locals_idx2_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    2 < (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).locals.size := by
  rw [registrationFramePc22_locals_size args h mv rCompressed sOpt sVal]; decide

theorem registrationFramePc22_localRefs_idx2_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    2 < (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).localRefs.size := by
  rw [registrationFramePc22_localRefs_size args h mv rCompressed sOpt sVal]; decide

theorem registrationFramePc22_locals_idx2_eq
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal : MoveValue) :
    (registrationFramePc22AfterMoveLoc0 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
      (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal).locals[2]'
      (registrationFramePc22_locals_idx2_lt _ _ mv rCompressed sOpt sVal) = some (.address contract) := by
  simp [registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg, registrationFramePc20AfterStLoc11,
    registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9, registrationFramePc12AfterStLoc9,
    registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6, registrationFramePc9AfterStLoc8,
    registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow, registrationFramePc3AfterStLoc,
    registrationFrameAtPc2, registrationInitFrame, registrationVerifyArgs]

theorem registrationFramePc22_localRefs_idx2_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).localRefs[2]'
      (registrationFramePc22_localRefs_idx2_lt args h mv rCompressed sOpt sVal) = none := by
  simp [registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg, registrationFramePc20AfterStLoc11,
    registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9, registrationFramePc12AfterStLoc9,
    registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6, registrationFramePc9AfterStLoc8,
    registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow, registrationFramePc3AfterStLoc,
    registrationFrameAtPc2, registrationInitFrame]

/-- `registrationMsAfterAppendSender` has store size 6 (same as after alloc sender — write does not change size). -/
theorem registrationMsAfterAppendSender_store_size
    (mv sOpt : MoveValue) (chainId : UInt8) (sender : ByteArray) :
    (registrationMsAfterAppendSender mv sOpt chainId sender).containers.store.size = 6 := by
  have hwrite := registration_write_append_sender_eq mv sOpt chainId sender
  have hlt := registration_sender_lt4 mv sOpt chainId sender
  have hw' : (registrationMsAfterImmBorrow1_sender mv sOpt chainId sender).containers.write 4
      (.vector .u8 ((fiatShamirRegistrationDstBytesList ++ [.u8 chainId]) ++ sender.toList.map .u8)) =
      some ⟨(registrationMsAfterImmBorrow1_sender mv sOpt chainId sender).containers.store.set 4
        (.vector .u8 ((fiatShamirRegistrationDstBytesList ++ [.u8 chainId]) ++ sender.toList.map .u8)) hlt⟩ := by
    simp [ContainerStore.write, hlt]
  rw [hw'] at hwrite
  have hstore : (registrationMsAfterAppendSender mv sOpt chainId sender).containers.store =
      (registrationMsAfterImmBorrow1_sender mv sOpt chainId sender).containers.store.set 4
        (.vector .u8 ((fiatShamirRegistrationDstBytesList ++ [.u8 chainId]) ++ sender.toList.map .u8)) hlt := by
    have h := (Option.some.inj hwrite).symm
    exact congrArg ContainerStore.store h
  rw [hstore, Array.size_set, registrationMsAfterImmBorrow1_sender_store_size]

/-- Frame after PC 28: same as PC 22 frame but with `pc := 29`. `immBorrowLoc` does not update `localRefs`. -/
def registrationFramePc29AfterImmBorrow2 (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) : Frame :=
  { registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal with pc := 29 }

/-- `MachineState` after PC 28: `contract` address allocated at ref 6. -/
def registrationMsAfterImmBorrow2_contract (mv sOpt : MoveValue) (chainId : UInt8) (sender contract : ByteArray) : MachineState :=
  let cs := (registrationMsAfterAppendSender mv sOpt chainId sender).containers
  { MachineState.empty with containers := (cs.alloc (.address contract)).1 }

-- PC 28: `immBorrowLoc 2` — alloc `contract` at ref 6, push `immRef 6`, PC→29.
set_option maxHeartbeats 1600000 in
theorem registration_step_pc28_immBorrowLoc2 (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal : MoveValue) :
    step (registrationModuleEnv o)
        ({ registrationFramePc22AfterMoveLoc0 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 28 })
        [] [.mutRef 4] (registrationMsAfterAppendSender mv sOpt chainId sender) =
      ExecResult.ok
        (registrationFramePc29AfterImmBorrow2 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal)
        [] [.immRef 6, .mutRef 4] (registrationMsAfterImmBorrow2_contract mv sOpt chainId sender contract) := by
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  let hlen : args.length = 7 := registrationVerifyArgs_len _ _ _ _ _ _ _
  let fr' := ({ registrationFramePc22AfterMoveLoc0 args hlen mv rCompressed sOpt sVal with pc := 28 })
  have hpc : fr'.pc < fr'.code.size := by
    simp [fr', registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
      registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
      registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
      registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
      registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame, verifyRegistrationProofCode_size_val]
  have hc : fr'.code[fr'.pc]'hpc = MoveInstr.immBorrowLoc 2 := by
    simp [fr', registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
      registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
      registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
      registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
      registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame, verifyRegistrationProofCode_size_val,
      verifyRegistrationProofCode_idx28]
  have hlocLt : 2 < fr'.locals.size :=
    registrationFramePc22_locals_idx2_lt args hlen mv rCompressed sOpt sVal
  have hlocVal := registrationFramePc22_locals_idx2_eq chainId sender contract token ekBa commitBa respBa
    mv rCompressed sOpt sVal
  have hlocRefLt : 2 < fr'.localRefs.size :=
    registrationFramePc22_localRefs_idx2_lt args hlen mv rCompressed sOpt sVal
  have hlocRefVal := registrationFramePc22_localRefs_idx2_eq args hlen mv rCompressed sOpt sVal
  simp only [step, dif_pos hpc, hc, dif_pos hlocLt, hlocVal, dif_pos hlocRefLt, hlocRefVal]
  rfl

/-! ### PC 29: `call 5` = `bcs::to_bytes<address>(&contract)` (nativeRef, 1 param, 1 ret) -/

@[simp] theorem verifyRegistrationProofCode_idx29 :
    verifyRegistrationProofCode[29]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .call 5 := rfl

theorem registration_imm6_read_contract (mv sOpt : MoveValue) (chainId : UInt8) (sender contract : ByteArray) :
    (registrationMsAfterImmBorrow2_contract mv sOpt chainId sender contract).containers.read 6 = some (.address contract) := by
  have halloc :
      (registrationMsAfterImmBorrow2_contract mv sOpt chainId sender contract).containers =
        ((registrationMsAfterAppendSender mv sOpt chainId sender).containers.alloc (.address contract)).1 := rfl
  have hid :
      (((registrationMsAfterAppendSender mv sOpt chainId sender).containers.alloc (.address contract)).2 : Nat) = 6 := by
    simp [ContainerStore.alloc, registrationMsAfterAppendSender_store_size]
  have hr := ContainerStore.read_of_alloc
    (registrationMsAfterAppendSender mv sOpt chainId sender).containers (.address contract)
    ((registrationMsAfterAppendSender mv sOpt chainId sender).containers.alloc (.address contract)).1
    ((registrationMsAfterAppendSender mv sOpt chainId sender).containers.alloc (.address contract)).2 rfl
  rw [halloc, ← hid]; exact hr

theorem bcsToBytesAddressRef_registration_contract
    (mv sOpt : MoveValue) (chainId : UInt8) (sender contract : ByteArray) :
    bcsToBytesAddressRef (registrationMsAfterImmBorrow2_contract mv sOpt chainId sender contract).containers [.immRef 6] =
      some ([.vector .u8 (contract.toList.map .u8)],
        (registrationMsAfterImmBorrow2_contract mv sOpt chainId sender contract).containers) := by
  simp only [bcsToBytesAddressRef]
  rw [registration_imm6_read_contract]

/-- PC 29: `call 5` — `bcs::to_bytes<address>(&contract)`; pushes `contractBytes`, no ms change. -/
theorem registration_step_pc29_call_bcsToBytes_contract (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal : MoveValue) :
    step (registrationModuleEnv o)
        (registrationFramePc29AfterImmBorrow2 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal)
        [] [.immRef 6, .mutRef 4] (registrationMsAfterImmBorrow2_contract mv sOpt chainId sender contract) =
      ExecResult.ok
        ({ registrationFramePc29AfterImmBorrow2 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 30 })
        [] [.vector .u8 (contract.toList.map .u8), .mutRef 4]
        (registrationMsAfterImmBorrow2_contract mv sOpt chainId sender contract) := by
  have hnative := bcsToBytesAddressRef_registration_contract mv sOpt chainId sender contract
  simp only [step, registrationModuleEnv, registrationFramePc29AfterImmBorrow2,
    registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
    registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
    registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
    registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
    registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame, registrationVerifyArgs,
    verifyRegistrationProofCode, verifyRegistrationProofCode_size_val, verifyRegistrationProofCode_idx29,
    registrationInitFrame_idx5_lt, registration_locals_after_set5_idx7_lt, registrationVerifyArgs_len,
    registration_env_funcIdx5_lt, registrationModuleEnv_functions_at5, FuncDesc.body, bcsToBytesAddressRefDesc,
    takeN_two_one, List.map_cons, List.map_nil, Nat.reduceSub, List.reduceReplicate,
    List.cons_append, List.nil_append, List.size_toArray, List.length_cons, List.length_nil, zero_add,
    Nat.reduceAdd, Nat.reduceLT, Nat.one_lt_ofNat, ↓reduceDIte, List.getElem_toArray, List.getElem_cons_succ,
    List.getElem_cons_zero, Nat.ofNat_pos, Nat.reduceBEq, Bool.false_eq_true, BEq.rfl, List.set_toArray,
    List.set_cons_succ, List.set_cons_zero, beq_iff_eq]
  rw [hnative]
  simp only [handleNativeResult_ret1]

/-! ### PC 30: `call 6` = `vector::append<u8>(&mut msg, contractBytes)` (nativeRef, 2 params, 0 ret) -/

@[simp] theorem verifyRegistrationProofCode_idx30 :
    verifyRegistrationProofCode[30]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .call 6 := rfl

theorem registration_contract_lt4
    (mv sOpt : MoveValue) (chainId : UInt8) (sender contract : ByteArray) :
    4 < (registrationMsAfterImmBorrow2_contract mv sOpt chainId sender contract).containers.store.size := by
  have halloc :
      (registrationMsAfterImmBorrow2_contract mv sOpt chainId sender contract).containers =
        ((registrationMsAfterAppendSender mv sOpt chainId sender).containers.alloc (.address contract)).1 := rfl
  rw [halloc]
  simp only [ContainerStore.alloc, Array.size_push]
  rw [registrationMsAfterAppendSender_store_size]; decide

/-- Reading ref 4 in `registrationMsAfterImmBorrow2_contract` yields DST++[chainId]++senderBytes. -/
theorem registration_contract_read4
    (mv sOpt : MoveValue) (chainId : UInt8) (sender contract : ByteArray) :
    (registrationMsAfterImmBorrow2_contract mv sOpt chainId sender contract).containers.read 4 =
      some (.vector .u8 ((fiatShamirRegistrationDstBytesList ++ [.u8 chainId]) ++ sender.toList.map .u8)) := by
  have hlt4 : (4 : Nat) < (registrationMsAfterAppendSender mv sOpt chainId sender).containers.store.size := by
    rw [registrationMsAfterAppendSender_store_size]; decide
  have hwrite := registration_write_append_sender_eq mv sOpt chainId sender
  have hltSender := registration_sender_lt4 mv sOpt chainId sender
  have hw' : (registrationMsAfterImmBorrow1_sender mv sOpt chainId sender).containers.write 4
      (.vector .u8 ((fiatShamirRegistrationDstBytesList ++ [.u8 chainId]) ++ sender.toList.map .u8)) =
      some ⟨(registrationMsAfterImmBorrow1_sender mv sOpt chainId sender).containers.store.set 4
        (.vector .u8 ((fiatShamirRegistrationDstBytesList ++ [.u8 chainId]) ++ sender.toList.map .u8)) hltSender⟩ := by
    simp [ContainerStore.write, hltSender]
  rw [hw'] at hwrite
  have hstoreAppend : (registrationMsAfterAppendSender mv sOpt chainId sender).containers.store =
      (registrationMsAfterImmBorrow1_sender mv sOpt chainId sender).containers.store.set 4
        (.vector .u8 ((fiatShamirRegistrationDstBytesList ++ [.u8 chainId]) ++ sender.toList.map .u8)) hltSender := by
    have h := (Option.some.inj hwrite).symm
    exact congrArg ContainerStore.store h
  have hsenderRead4 : (registrationMsAfterAppendSender mv sOpt chainId sender).containers.read 4 =
      some (.vector .u8 ((fiatShamirRegistrationDstBytesList ++ [.u8 chainId]) ++ sender.toList.map .u8)) := by
    simp only [ContainerStore.read, hstoreAppend, Array.getElem?_set]
    simp [Array.size_set, registrationMsAfterImmBorrow1_sender_store_size]
  have hallocContract : (registrationMsAfterImmBorrow2_contract mv sOpt chainId sender contract).containers =
      ((registrationMsAfterAppendSender mv sOpt chainId sender).containers.alloc (.address contract)).1 := rfl
  rw [hallocContract]
  simp only [ContainerStore.alloc, ContainerStore.read]
  have hlt4' : (4 : Nat) < ((registrationMsAfterAppendSender mv sOpt chainId sender).containers.store.push (.address contract)).size := by
    rw [Array.size_push]; omega
  simp only [dif_pos hlt4']
  rw [Array.getElem_push_lt hlt4]
  have := hsenderRead4
  simp only [ContainerStore.read, dif_pos hlt4] at this
  exact this

/-- `MachineState` after PC 30: `msg` at ref 4 is now DST ++ [chainId] ++ senderBytes ++ contractBytes. -/
def registrationMsAfterAppendContract
    (mv sOpt : MoveValue) (chainId : UInt8) (sender contract : ByteArray) : MachineState :=
  match (registrationMsAfterImmBorrow2_contract mv sOpt chainId sender contract).containers.write 4
      (.vector .u8 (((fiatShamirRegistrationDstBytesList ++ [.u8 chainId]) ++ sender.toList.map .u8)
        ++ contract.toList.map .u8)) with
  | some cs' => { MachineState.empty with containers := cs' }
  | none => registrationMsAfterImmBorrow2_contract mv sOpt chainId sender contract

theorem registration_write_append_contract_eq
    (mv sOpt : MoveValue) (chainId : UInt8) (sender contract : ByteArray) :
    (registrationMsAfterImmBorrow2_contract mv sOpt chainId sender contract).containers.write 4
        (.vector .u8 (((fiatShamirRegistrationDstBytesList ++ [.u8 chainId]) ++ sender.toList.map .u8)
          ++ contract.toList.map .u8)) =
      some (registrationMsAfterAppendContract mv sOpt chainId sender contract).containers := by
  have hlt := registration_contract_lt4 mv sOpt chainId sender contract
  have hw : (registrationMsAfterImmBorrow2_contract mv sOpt chainId sender contract).containers.write 4
      (.vector .u8 (((fiatShamirRegistrationDstBytesList ++ [.u8 chainId]) ++ sender.toList.map .u8)
        ++ contract.toList.map .u8)) =
      some ⟨(registrationMsAfterImmBorrow2_contract mv sOpt chainId sender contract).containers.store.set 4
        (.vector .u8 (((fiatShamirRegistrationDstBytesList ++ [.u8 chainId]) ++ sender.toList.map .u8)
          ++ contract.toList.map .u8)) hlt⟩ := by
    simp [ContainerStore.write, hlt]
  have hms : (registrationMsAfterAppendContract mv sOpt chainId sender contract).containers =
      ⟨(registrationMsAfterImmBorrow2_contract mv sOpt chainId sender contract).containers.store.set 4
        (.vector .u8 (((fiatShamirRegistrationDstBytesList ++ [.u8 chainId]) ++ sender.toList.map .u8)
          ++ contract.toList.map .u8)) hlt⟩ := by
    dsimp [registrationMsAfterAppendContract]
    rw [hw]
  rw [hw, hms]

theorem vectorAppendU8Ref_registration_contract
    (mv sOpt : MoveValue) (chainId : UInt8) (sender contract : ByteArray) :
    vectorAppendU8Ref (registrationMsAfterImmBorrow2_contract mv sOpt chainId sender contract).containers
        [.mutRef 4, .vector .u8 (contract.toList.map .u8)] =
      some ([], (registrationMsAfterAppendContract mv sOpt chainId sender contract).containers) := by
  simp only [vectorAppendU8Ref]
  rw [registration_contract_read4]
  simp only
  rw [registration_write_append_contract_eq mv sOpt chainId sender contract]

/-- PC 30: `call 6` — `vector::append<u8>(&mut msg, contractBytes)`; updates ref 4. -/
theorem registration_step_pc30_call_appendContract (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal : MoveValue) :
    step (registrationModuleEnv o)
        ({ registrationFramePc29AfterImmBorrow2 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 30 })
        [] [.vector .u8 (contract.toList.map .u8), .mutRef 4]
        (registrationMsAfterImmBorrow2_contract mv sOpt chainId sender contract) =
      ExecResult.ok
        ({ registrationFramePc29AfterImmBorrow2 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 31 })
        [] [] (registrationMsAfterAppendContract mv sOpt chainId sender contract) := by
  have hnative := vectorAppendU8Ref_registration_contract mv sOpt chainId sender contract
  simp only [step, registrationModuleEnv, registrationFramePc29AfterImmBorrow2,
    registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
    registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
    registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
    registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
    registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame, registrationVerifyArgs,
    verifyRegistrationProofCode, verifyRegistrationProofCode_size_val, verifyRegistrationProofCode_idx30,
    registrationInitFrame_idx5_lt, registration_locals_after_set5_idx7_lt, registrationVerifyArgs_len,
    registration_env_funcIdx6_lt, registrationModuleEnv_functions_at6, FuncDesc.body, vectorAppendU8RefDesc,
    takeN_two_pair, List.map_cons, List.map_nil, Nat.reduceSub, List.reduceReplicate, List.cons_append,
    List.nil_append, List.size_toArray, List.length_cons, List.length_nil, zero_add, Nat.reduceAdd,
    Nat.reduceLT, Nat.one_lt_ofNat, ↓reduceDIte, List.getElem_toArray, List.getElem_cons_succ,
    List.getElem_cons_zero, Nat.ofNat_pos, Nat.reduceBEq, Bool.false_eq_true, BEq.rfl, List.set_toArray,
    List.set_cons_succ, List.set_cons_zero, beq_iff_eq]
  rw [hnative]
  simp only [handleNativeResult_ret0]
  rfl
