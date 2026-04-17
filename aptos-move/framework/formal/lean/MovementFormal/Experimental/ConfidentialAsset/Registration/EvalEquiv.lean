import MovementFormal.Experimental.ConfidentialAsset.Registration.FunctionalSim
import MovementFormal.MoveModel.Step
import MovementFormal.MoveModel.Programs.Registration

/-!
# Bytecode eval ≡ functional simulation (L2 ≡ L1.5)

**Source:** `aptos-move/framework/aptos-experimental/sources/confidential_asset/confidential_proof.move`; bytecode `MovementFormal.MoveModel.Programs.Registration`.

Proof that the bytecode evaluator `eval` on the transcribed 83-instruction
`verify_registration_proof` (reference-semantic, from `movement` v7.4
compiler output) agrees with the functional simulation
`verifyRegistrationBytecodeResult` for any oracle — up to MachineState
(the container store is non-empty after execution but irrelevant to the
return values / abort code).

## MachineState note

The real bytecode uses `immBorrowLoc` / `mutBorrowLoc` / `nativeRef`
calls, so `eval` returns `.returned [] ms` where `ms` has a populated
`ContainerStore`. The functional sim returns `.returned [] MachineState.empty`.
We compare via `ExecResult.dropMs` which projects away the `MachineState`.

## Proof architecture

The proof uses `@[simp]` lemmas to normalize both sides to the same
match tree:

**Eval side:**
1. `run_succ_runStep` rewrites `run env frame cs stack ms (n+1)` →
   `runStep env (step env frame cs stack ms) n`
2. `step` unfolds to `handleNativeResult (impl args) numReturns ...`
   (or `nativeRef` dispatch for ref-aware functions)
3. `runStep_handleNativeResult_ret1` collapses to
   `match oracleResult with | some [v] => run env ... | _ => .error`

**Func side:**
4. `match_single?` rewrites `match (single? x) with | some v => f v | _ => g`
   to `match x with | some [v] => f v | _ => g`
5. `bind_single?` rewrites `single? x >>= f` to
   `match x with | some [v] => f v | _ => none`

**Bridging:**
6. `match_match_some_single_none` fuses
   `match (match x with | some [v] => f v | _ => none) with | some w => g w | none => h`
   into `match x with | some [v] => match f v with | some w => g w | none => h | _ => h`
   (needed for `buildFSMessageMv`'s `Option MoveValue` boundary in `blockCDE`)

After normalization, `simp`'s congruence closes matching branches.
Remaining abstract branch splits are handled by `split <;> simp`.
-/

/-! ## MachineState projection

The real bytecode populates the `ContainerStore` via `immBorrowLoc` /
`mutBorrowLoc` / `nativeRef` calls, so `eval` returns a non-empty
`MachineState`. The functional sim returns `MachineState.empty`.
`dropMs` projects away the `MachineState` to enable comparison.

Defined in the `MovementFormal.MoveModel` namespace so that dot notation
(`r.dropMs`) resolves for `r : ExecResult`. -/

namespace MovementFormal.MoveModel

def ExecResult.dropMs : ExecResult → ExecResult
  | .returned vs _ => .returned vs MachineState.empty
  | r => r

@[simp] theorem ExecResult.dropMs_returned (vs : List MoveValue) (ms : MachineState) :
    ExecResult.dropMs (.returned vs ms) = .returned vs MachineState.empty := rfl

@[simp] theorem ExecResult.dropMs_aborted (code : UInt64) :
    ExecResult.dropMs (.aborted code) = .aborted code := rfl

@[simp] theorem ExecResult.dropMs_error :
    ExecResult.dropMs .error = .error := rfl

theorem ExecResult.dropMs_eq_returned_iff (r : ExecResult) (vs : List MoveValue) :
    r.dropMs = .returned vs MachineState.empty ↔
    ∃ ms, r = .returned vs ms := by
  constructor
  · intro h; cases r with
    | returned vs' ms' =>
      simp [ExecResult.dropMs] at h
      exact ⟨ms', by obtain ⟨rfl, _⟩ := h; rfl⟩
    | aborted _ => simp [ExecResult.dropMs] at h
    | error => simp [ExecResult.dropMs] at h
    | ok _ _ _ _ => simp [ExecResult.dropMs] at h
  · rintro ⟨ms, rfl⟩; simp [ExecResult.dropMs]

theorem ExecResult.dropMs_eq_aborted_iff (r : ExecResult) (code : UInt64) :
    r.dropMs = .aborted code ↔ r = .aborted code := by
  constructor
  · intro h; cases r with
    | returned _ _ => simp [ExecResult.dropMs] at h
    | aborted c =>
      simp [ExecResult.dropMs] at h
      exact congrArg ExecResult.aborted h
    | error => simp [ExecResult.dropMs] at h
    | ok _ _ _ _ => simp [ExecResult.dropMs] at h
  · rintro rfl; rfl

theorem ExecResult.dropMs_ne_error_of_ne_error {r : ExecResult} (h : r ≠ .error) :
    r.dropMs ≠ .error := by
  cases r with
  | returned _ _ => simp [ExecResult.dropMs]
  | aborted _ => simp [ExecResult.dropMs]
  | error => exact absurd rfl h
  | ok _ _ _ _ => simp [ExecResult.dropMs]

end MovementFormal.MoveModel

namespace MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquiv

open MovementFormal.MoveModel
open MovementFormal.MoveModel.Native.Registration
open MovementFormal.MoveModel.Programs.Registration
open MovementFormal.Experimental.ConfidentialAsset.Registration.FunctionalSim

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

/-! ## Fuel monotonicity -/

theorem run_fuel_ge (env : ModuleEnv) (frame : Frame) (cs : List Frame)
    (stack : List MoveValue) (ms : MachineState) :
    ∀ (fuel₁ fuel₂ : Nat), fuel₁ ≤ fuel₂ →
      run env frame cs stack ms fuel₁ ≠ .error →
      run env frame cs stack ms fuel₂ = run env frame cs stack ms fuel₁ := by
  intro fuel₁
  induction fuel₁ generalizing frame cs stack ms with
  | zero => intro _ _ hne; simp [run] at hne
  | succ n ih =>
    intro fuel₂ hle hne
    obtain ⟨m, rfl⟩ : ∃ m, fuel₂ = m + 1 := ⟨fuel₂ - 1, by omega⟩
    simp only [run]
    cases hStep : step env frame cs stack ms with
    | ok frame' cs' stack' ms' =>
      exact ih frame' cs' stack' ms' m (by omega) (by simp [run, hStep] at hne; exact hne)
    | returned _ _ => rfl
    | aborted _ => rfl
    | error => simp [run, hStep] at hne

theorem eval_fuel_ge (env : ModuleEnv) (funcIdx : FuncIndex) (args : List MoveValue)
    (fuel₁ fuel₂ : Nat) (ms : MachineState) :
    fuel₁ ≤ fuel₂ →
    eval env funcIdx args fuel₁ ms ≠ .error →
    eval env funcIdx args fuel₂ ms = eval env funcIdx args fuel₁ ms := by
  intro hle hne
  simp only [eval] at hne ⊢
  by_cases hBound : funcIdx < env.functions.size
  · simp only [dite_true, hBound] at hne ⊢
    cases hBody : env.functions[funcIdx].body with
    | native impl => rfl
    | nativeAbort impl => rfl
    | nativeRef impl => rfl
    | bytecode code numLocals =>
      simp only [hBody] at hne ⊢
      exact run_fuel_ge _ _ _ _ _ _ _ hle hne
  · simp only [dite_false, hBound] at hne; exact absurd rfl hne

theorem eval_fuel_ge_dropMs (env : ModuleEnv) (funcIdx : FuncIndex) (args : List MoveValue)
    (fuel₁ fuel₂ : Nat) (ms : MachineState) :
    fuel₁ ≤ fuel₂ →
    eval env funcIdx args fuel₁ ms ≠ .error →
    (eval env funcIdx args fuel₂ ms).dropMs = (eval env funcIdx args fuel₁ ms).dropMs := by
  intro hle hne
  exact congrArg ExecResult.dropMs (eval_fuel_ge env funcIdx args fuel₁ fuel₂ ms hle hne)

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

@[simp] private theorem verifyRegistrationProofCode_size_val : verifyRegistrationProofCode.size = 84 := rfl

@[simp] private theorem verifyRegistrationProofCode_idx0 :
    verifyRegistrationProofCode[0]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .moveLoc 5 := rfl

@[simp] private theorem verifyRegistrationProofCode_idx1 :
    verifyRegistrationProofCode[1]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .call 0 := rfl

@[simp] private theorem verifyRegistrationProofCode_idx2 :
    verifyRegistrationProofCode[2]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .stLoc 7 := rfl

@[simp] private theorem verifyRegistrationProofCode_idx3 :
    verifyRegistrationProofCode[3]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .immBorrowLoc 7 := rfl

@[simp] private theorem verifyRegistrationProofCode_idx4 :
    verifyRegistrationProofCode[4]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .call 1 := rfl

@[simp] private theorem takeN_one_singleton (v : MoveValue) : takeN [v] 1 = some ([v], []) := by
  simp [takeN]

@[simp] private theorem registration_env_funcIdx1_lt (o : RegistrationNativeOracle) :
    1 < (registrationModuleEnv o).functions.size := by
  rw [registration_module_env_size o]; decide

@[simp] private theorem registrationModuleEnv_functions_at1 (o : RegistrationNativeOracle)
    (h : 1 < (registrationModuleEnv o).functions.size) :
    (registrationModuleEnv o).functions[1]'h = optionIsSomeRefDesc := by
  simp [registrationModuleEnv, optionIsSomeRefDesc]

/-- `option::is_some` on a ref whose cell holds a struct-encoded `Option` with bool tag `tag`. -/
private theorem optionIsSomeRef_of_read_struct_bool (cs : ContainerStore) (id : RefId) (tag : Bool) (rest : List MoveValue)
    (hread : cs.read id = some (.struct_ (.bool tag :: rest))) :
    optionIsSomeRef cs [.immRef id] = some ([.bool tag], cs) := by
  simp [optionIsSomeRef, hread]

/-- First `ContainerStore` cell allocated from `empty` is ref id `0`. -/
@[simp] private theorem registration_alloc_empty_fst (mv : MoveValue) :
    (ContainerStore.alloc ContainerStore.empty mv).fst.store = #[mv] := by
  simp [ContainerStore.alloc, ContainerStore.empty, Array.push, Array.size]

@[simp] private theorem registration_alloc_empty_snd (mv : MoveValue) :
    (ContainerStore.alloc ContainerStore.empty mv).snd = 0 := by
  simp [ContainerStore.alloc, ContainerStore.empty, Array.push, Array.size]

@[simp] private theorem registration_alloc_ms_empty_fst (mv : MoveValue) :
    (ContainerStore.alloc MachineState.empty.containers mv).fst.store = #[mv] := by
  simpa [MachineState.empty, ContainerStore.empty] using registration_alloc_empty_fst mv

@[simp] private theorem registration_alloc_ms_empty_snd (mv : MoveValue) :
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
private theorem registrationInitFrame_locals_size (args : List MoveValue) (h : args.length = 7) :
    (registrationInitFrame args).locals.size = 19 := by
  simp [registrationInitFrame, h, List.length_map, List.length_append, List.length_replicate, Nat.add_assoc]

private theorem registrationInitFrame_idx5_lt (args : List MoveValue) (h : args.length = 7) :
    5 < (registrationInitFrame args).locals.size := by
  rw [registrationInitFrame_locals_size args h]; decide

private theorem registrationInitFrame_idx7_lt (args : List MoveValue) (h : args.length = 7) :
    7 < (registrationInitFrame args).locals.size := by
  rw [registrationInitFrame_locals_size args h]; decide

private theorem registration_locals_after_set5_idx7_lt (args : List MoveValue) (h : args.length = 7) :
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

/-- After `immBorrowLoc`, ref `0` reads back the stored `MoveValue` (single-cell store). -/
private theorem registration_ms_after_imm_read0 (mv : MoveValue) :
    (registrationMsAfterImmBorrow7 mv).containers.read 0 = some mv := by
  have hstore : (registrationMsAfterImmBorrow7 mv).containers.store = #[mv] := by
    simpa [registrationMsAfterImmBorrow7, MachineState.containers] using registration_alloc_ms_empty_fst mv
  simp only [ContainerStore.read, hstore]
  split_ifs with hlt
  · exact congrArg some rfl
  · simp [Array.size] at hlt

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
  have hread0 := registration_ms_after_imm_read0 mv
  subst hmv
  have hop :=
    optionIsSomeRef_of_read_struct_bool (registrationMsAfterImmBorrow7 _).containers 0 tag rest (by simpa using hread0)
  registration_step_pc4_unfold
  simp [hop, handleNativeResult_ret1]

/-- Two `ok` steps in a row: advance `run` by 2 fuel steps. -/
theorem run_succ_succ_ok (env : ModuleEnv) (f₀ f₁ f₂ : Frame) (cs : List Frame)
    (s₀ s₁ s₂ : List MoveValue) (ms₀ ms₁ ms₂ : MachineState) (n : Nat)
    (h₀ : step env f₀ cs s₀ ms₀ = ExecResult.ok f₁ cs s₁ ms₁)
    (h₁ : step env f₁ cs s₁ ms₁ = ExecResult.ok f₂ cs s₂ ms₂) :
    run env f₀ cs s₀ ms₀ n.succ.succ = run env f₂ cs s₂ ms₂ n := by
  simp only [run, h₀, run, h₁]

/-- After PC 0–1 with singleton native result `[mv]`, `run` from the entry frame equals `run` from PC 2 with stack `[mv]` and `fuel - 2` remaining steps. -/
theorem registration_run_eq_from_pc2_singleton
    (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray) (mv : MoveValue)
    (fuel : Nat) (hf : 2 ≤ fuel)
    (hl : o.newCompressedPointFromBytes [.vector .u8 (commitBa.toList.map .u8)] = some [mv]) :
    run (registrationModuleEnv o)
        (registrationInitFrame (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa))
        [] [] MachineState.empty fuel =
      run (registrationModuleEnv o)
        (registrationFrameAtPc2 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa))
        [] [mv] MachineState.empty (fuel - 2) := by
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  have hlen : args.length = 7 := registrationVerifyArgs_len _ _ _ _ _ _ _
  have hs0 := registration_step0_moveLoc5 o chainId sender contract token ekBa commitBa respBa
  have hs1 := registration_step1_call0_singleton o chainId sender contract token ekBa commitBa respBa mv hl
  have hfuel : fuel = (fuel - 2) + 2 := by omega
  rw [hfuel]
  exact run_succ_succ_ok (registrationModuleEnv o)
    (registrationInitFrame args)
    ({ registrationInitFrame args with
        pc := 1,
        locals :=
          (registrationInitFrame args).locals.set 5 none (registrationInitFrame_idx5_lt args hlen) })
    (registrationFrameAtPc2 args hlen)
    []
    []
    [.vector .u8 (commitBa.toList.map .u8)]
    [mv]
    MachineState.empty MachineState.empty MachineState.empty
    (fuel - 2) hs0 hs1

/-! ## Functional sim: same early errors as bytecode -/

theorem verifyRegistration_func_error_of_compressed_none
    (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (h : o.newCompressedPointFromBytes
          [.vector .u8 (commitBa.toList.map .u8)] = none) :
    verifyRegistrationBytecodeResult o
        (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa) = .error := by
  simp only [verifyRegistrationBytecodeResult, registrationVerifyArgs, h, single?]

theorem verifyRegistration_func_error_of_compressed_not_singleton
    (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (l : List MoveValue)
    (hl : o.newCompressedPointFromBytes [.vector .u8 (commitBa.toList.map .u8)] = some l)
    (hlen : l.length ≠ 1) :
    verifyRegistrationBytecodeResult o
        (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa) = .error := by
  simp only [verifyRegistrationBytecodeResult, registrationVerifyArgs, hl]
  cases l with
  | nil => simp [single?]
  | cons a as =>
    cases as with
    | nil => simp at hlen
    | cons b t => simp [single?]

/-- Bytecode `eval` reaches `.error` on the same early paths as the functional sim:
    after `moveLoc 5`, `call 0` (`new_compressed_point_from_bytes`) fails in one step
    when the oracle returns `none` or a non-singleton list. -/
theorem registration_eval_early_error_matches_func
    (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (fuel : Nat) (hf : 2 ≤ fuel)
    (hnp : o.newCompressedPointFromBytes [.vector .u8 (commitBa.toList.map .u8)] = none ∨
      ∃ l, o.newCompressedPointFromBytes [.vector .u8 (commitBa.toList.map .u8)] = some l ∧ l.length ≠ 1) :
    eval (registrationModuleEnv o) verifyRegistrationProofIdx
        (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
        fuel MachineState.empty = .error := by
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  have hlen : args.length = 7 := registrationVerifyArgs_len _ _ _ _ _ _ _
  rw [eval_registration_eq_run o args fuel MachineState.empty hlen]
  let f1 :=
    ({ registrationInitFrame args with
        pc := 1,
        locals :=
          (registrationInitFrame args).locals.set 5 none (registrationInitFrame_idx5_lt args hlen) })
  have hs0 := registration_step0_moveLoc5 o chainId sender contract token ekBa commitBa respBa
  have hs1 :
      step (registrationModuleEnv o) f1 [] [.vector .u8 (commitBa.toList.map .u8)] MachineState.empty =
        ExecResult.error := by
    rcases hnp with hnone | ⟨l, hl, hlne⟩
    · exact registration_step1_call0_none o chainId sender contract token ekBa commitBa respBa hnone
    · exact registration_step1_call0_not_singleton o chainId sender contract token ekBa commitBa respBa l hl hlne
  exact run_ok_then_second_errors (registrationModuleEnv o) (registrationInitFrame args) f1 [] []
    [.vector .u8 (commitBa.toList.map .u8)] MachineState.empty MachineState.empty fuel hf hs0 hs1

/-! ## L2 ≡ L1.5: `eval` vs `verifyRegistrationBytecodeResult`

**Status.** Early-error paths and `single?` scaffolding are proved. After `moveLoc` / `call 0`,
singleton `[mv]` reaches PC 2 (`registration_step1_call0_singleton`, `registration_run_eq_from_pc2_singleton`).
The first two tail instructions are mechanized (`registration_step_pc2_stLoc7`, `registration_step_pc3_immBorrowLoc7`).
The remainder of the tail (PC 4→`ret` vs `blockB` / `blockCDE`) is still the single axiom
`registration_eval_equiv_singleton_tail`
(see docstring). Concrete checks: `BytecodeDifftestEval.lean`. -/

set_option maxRecDepth 8192 in
set_option maxHeartbeats 800000 in

/-- **Trusted bridge (L2 ≡ L1.5 tail).**

States that executing the transcribed bytecode from **PC 2** (stack `[mv]` after a singleton
`new_compressed_point_from_bytes` return, frame `registrationFrameAtPc2`) with remaining fuel
`fuel - 2` agrees—up to `ExecResult.dropMs`—with `verifyRegistrationBytecodeResult`.

This is exactly the long symbolic simulation (refs, `nativeRef`, ~68 instructions through `ret`)
that would otherwise be proved by per-PC `step`/`run` lemmas. It is **not** derived from smaller
rules in this repo; regression evidence lives in `BytecodeDifftestEval.lean` (`native_decide`).

**To eliminate this axiom:** prove the same statement by symbolic execution matching
`FunctionalSim.verifyRegistrationBytecodeResult` (`blockB` / `blockCDE`). -/
axiom registration_eval_equiv_singleton_tail
    (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv : MoveValue) (fuel : Nat)
    (hfuel : fuel ≥ 200)
    (hl : o.newCompressedPointFromBytes [.vector .u8 (commitBa.toList.map .u8)] = some [mv]) :
    (run (registrationModuleEnv o)
        (registrationFrameAtPc2 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa))
        [] [mv] MachineState.empty (fuel - 2)).dropMs =
      verifyRegistrationBytecodeResult o
        (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)

/-- Singleton compressed-point path: `eval.dropMs` vs functional sim (uses `registration_eval_equiv_singleton_tail`). -/
theorem registration_eval_equiv_functional_sim_core
    (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (fuel : Nat) (_hfuel : fuel ≥ 200)
    (l : List MoveValue)
    (hl : o.newCompressedPointFromBytes [.vector .u8 (commitBa.toList.map .u8)] = some l)
    (hlen : l.length = 1) :
    (eval (registrationModuleEnv o) verifyRegistrationProofIdx
        (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
        fuel MachineState.empty).dropMs =
    verifyRegistrationBytecodeResult o
        (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa) := by
  obtain ⟨mv, rfl⟩ : ∃ mv, l = [mv] := by
    cases l with
    | nil => simp at hlen
    | cons a as =>
      cases as with
      | nil => exact ⟨a, rfl⟩
      | cons b t =>
        exfalso
        rw [List.length_cons, List.length_cons, show (1 : Nat) = Nat.succ 0 by rfl] at hlen
        exact Nat.succ_ne_zero _ (Nat.succ_injective hlen)
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  have hargs : args.length = 7 := registrationVerifyArgs_len _ _ _ _ _ _ _
  have hf2 : 2 ≤ fuel := by omega
  rw [eval_registration_eq_run o args fuel MachineState.empty hargs]
  rw [registration_run_eq_from_pc2_singleton o chainId sender contract token ekBa commitBa respBa mv fuel hf2
    (by simpa [args] using hl)]
  exact registration_eval_equiv_singleton_tail o chainId sender contract token ekBa commitBa respBa mv fuel _hfuel
    (by simpa [args] using hl)

theorem registration_eval_equiv_functional_sim
    (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (fuel : Nat) (hfuel : fuel ≥ 200) :
    (eval (registrationModuleEnv o) verifyRegistrationProofIdx
        (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
        fuel MachineState.empty).dropMs =
    verifyRegistrationBytecodeResult o
        (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa) := by
  have hf2 : 2 ≤ fuel := by omega
  cases hnp : o.newCompressedPointFromBytes [.vector .u8 (commitBa.toList.map .u8)] with
  | none =>
    have hf := verifyRegistration_func_error_of_compressed_none o chainId sender contract token ekBa commitBa respBa hnp
    have he := registration_eval_early_error_matches_func o chainId sender contract token ekBa commitBa respBa fuel hf2
        (Or.inl hnp)
    simp [hf, he, ExecResult.dropMs]
  | some l =>
    by_cases hsing : l.length = 1
    · obtain ⟨mv, rfl⟩ : ∃ mv, l = [mv] := by
        cases l with
        | nil => simp at hsing
        | cons a as =>
          cases as with
          | nil => exact ⟨a, rfl⟩
          | cons b t =>
            exfalso
            rw [List.length_cons, List.length_cons, show (1 : Nat) = Nat.succ 0 by rfl] at hsing
            have hs := Nat.succ_injective hsing
            exact absurd hs (Nat.succ_ne_zero _)
      exact registration_eval_equiv_functional_sim_core o chainId sender contract token ekBa commitBa respBa fuel hfuel
          [mv] (by simpa using hnp) (by rfl)
    · have hne : l.length ≠ 1 := by simpa using hsing
      have hf := verifyRegistration_func_error_of_compressed_not_singleton o chainId sender contract token ekBa commitBa respBa l hnp hne
      have he := registration_eval_early_error_matches_func o chainId sender contract token ekBa commitBa respBa fuel hf2
          (Or.inr ⟨l, hnp, hne⟩)
      simp [hf, he, ExecResult.dropMs]

theorem eval_eq_func_200
    (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray) :
    (eval (registrationModuleEnv o) verifyRegistrationProofIdx
        (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
        200 MachineState.empty).dropMs =
    verifyRegistrationBytecodeResult o
        (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa) :=
  registration_eval_equiv_functional_sim o chainId sender contract token ekBa commitBa respBa 200 (by omega)

end MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquiv
