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

@[simp] private theorem verifyRegistrationProofCode_idx5 :
    verifyRegistrationProofCode[5]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .brFalse 79 := rfl

@[simp] private theorem verifyRegistrationProofCode_idx6 :
    verifyRegistrationProofCode[6]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .mutBorrowLoc 7 := rfl

@[simp] private theorem verifyRegistrationProofCode_idx7 :
    verifyRegistrationProofCode[7]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .call 2 := rfl

@[simp] private theorem verifyRegistrationProofCode_idx8 :
    verifyRegistrationProofCode[8]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .stLoc 8 := rfl

@[simp] private theorem verifyRegistrationProofCode_idx9 :
    verifyRegistrationProofCode[9]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .moveLoc 6 := rfl

@[simp] private theorem verifyRegistrationProofCode_idx10 :
    verifyRegistrationProofCode[10]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .call 3 := rfl

@[simp] private theorem verifyRegistrationProofCode_idx11 :
    verifyRegistrationProofCode[11]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .stLoc 9 := rfl

@[simp] private theorem verifyRegistrationProofCode_idx12 :
    verifyRegistrationProofCode[12]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .immBorrowLoc 9 := rfl

@[simp] private theorem verifyRegistrationProofCode_idx13 :
    verifyRegistrationProofCode[13]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .call 1 := rfl

@[simp] private theorem verifyRegistrationProofCode_idx14 :
    verifyRegistrationProofCode[14]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .brFalse 74 := rfl

@[simp] private theorem takeN_one_singleton (v : MoveValue) : takeN [v] 1 = some ([v], []) := by
  simp [takeN]

@[simp] private theorem takeN_two_pair (a b : MoveValue) : takeN [a, b] 2 = some ([b, a], []) := by
  simp [takeN]

@[simp] private theorem takeN_two_cons_cons (a b : MoveValue) (rest : List MoveValue) :
    takeN (a :: b :: rest) 2 = some ([b, a], rest) := by
  simp [takeN]

@[simp] private theorem takeN_one_cons (a : MoveValue) (rest : List MoveValue) :
    takeN (a :: rest) 1 = some ([a], rest) := by
  simp [takeN]

@[simp] private theorem takeN_two_one (a b : MoveValue) : takeN [a, b] 1 = some ([a], [b]) := by
  simp [takeN]

@[simp] private theorem takeN_nil_zero : takeN [] 0 = some ([], []) := by
  simp [takeN]

@[simp] private theorem registration_env_funcIdx1_lt (o : RegistrationNativeOracle) :
    1 < (registrationModuleEnv o).functions.size := by
  rw [registration_module_env_size o]; decide

@[simp] private theorem registrationModuleEnv_functions_at1 (o : RegistrationNativeOracle)
    (h : 1 < (registrationModuleEnv o).functions.size) :
    (registrationModuleEnv o).functions[1]'h = optionIsSomeRefDesc := by
  simp [registrationModuleEnv, optionIsSomeRefDesc]

@[simp] private theorem registration_env_funcIdx2_lt (o : RegistrationNativeOracle) :
    2 < (registrationModuleEnv o).functions.size := by
  rw [registration_module_env_size o]; decide

@[simp] private theorem registrationModuleEnv_functions_at2 (o : RegistrationNativeOracle)
    (h : 2 < (registrationModuleEnv o).functions.size) :
    (registrationModuleEnv o).functions[2]'h = optionExtractRefDesc := by
  simp [registrationModuleEnv, optionExtractRefDesc]

@[simp] private theorem registration_env_funcIdx3_lt (o : RegistrationNativeOracle) :
    3 < (registrationModuleEnv o).functions.size := by
  rw [registration_module_env_size o]; decide

@[simp] private theorem registrationModuleEnv_functions_at3 (o : RegistrationNativeOracle)
    (h : 3 < (registrationModuleEnv o).functions.size) :
    (registrationModuleEnv o).functions[3]'h =
      { numParams := 1, numReturns := 1, body := .native o.newScalarFromBytes } := by
  simp [registrationModuleEnv]

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

/-- `step` unfolds `registrationMsAfterImmBorrow7` to `MachineState.empty.containers.alloc …` (same `ContainerStore`). -/
private theorem registration_ms_after_immBorrow7_containers (mv : MoveValue) :
    (MachineState.empty.containers.alloc mv).1 = (registrationMsAfterImmBorrow7 mv).containers := rfl

/-- After `immBorrowLoc`, ref `0` reads back the stored `MoveValue` (single-cell store). -/
private theorem registration_ms_after_imm_read0 (mv : MoveValue) :
    (registrationMsAfterImmBorrow7 mv).containers.read 0 = some mv := by
  have hstore : (registrationMsAfterImmBorrow7 mv).containers.store = #[mv] := by
    simp [registrationMsAfterImmBorrow7, MachineState.containers, registration_alloc_ms_empty_fst mv]
  simp only [ContainerStore.read, hstore]
  split_ifs with hlt
  · exact congrArg some rfl
  · simp [Array.size] at hlt

private theorem registrationFrame_localRefs_size_19 (args : List MoveValue) (h : args.length = 7) (mv : MoveValue) :
    (registrationFramePc4AfterImmBorrow args h mv).localRefs.size = 19 := by
  simp [registrationFramePc4AfterImmBorrow, registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame, h,
    List.size_toArray, List.length_replicate]

private theorem registrationFrame_idx7_localRefs_lt (args : List MoveValue) (h : args.length = 7) (mv : MoveValue) :
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

private theorem registration_dup7_store (mv : MoveValue) :
    (registrationMsAfterMutBorrowDup7 mv).containers.store = #[mv, mv] := by
  have h1 : (registrationMsAfterImmBorrow7 mv).containers.store = #[mv] := by
    simp [registrationMsAfterImmBorrow7, MachineState.empty, MachineState.containers, ContainerStore.alloc,
      ContainerStore.empty, Array.push]
  simp [registrationMsAfterMutBorrowDup7, ContainerStore.alloc, h1, Array.push]

private theorem registration_dup7_read1 (mv : MoveValue) :
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

private theorem registration_dup7_size (mv : MoveValue) :
    (registrationMsAfterMutBorrowDup7 mv).containers.store.size = 2 := by
  rw [registration_dup7_store]; rfl

private theorem registration_dup7_lt1 (mv : MoveValue) :
    1 < (registrationMsAfterMutBorrowDup7 mv).containers.store.size := by
  rw [registration_dup7_size]; decide

private theorem registration_dup7_write1_exists (mv : MoveValue) :
    ∃ cs', (registrationMsAfterMutBorrowDup7 mv).containers.write 1 (.struct_ [.bool false]) = some cs' := by
  refine ⟨⟨(registrationMsAfterMutBorrowDup7 mv).containers.store.set 1 (.struct_ [.bool false])
    (registration_dup7_lt1 mv)⟩, ?_⟩
  simp [ContainerStore.write, registration_dup7_lt1]

private theorem registration_write_dup7_eq_option_extract_ms (mv : MoveValue) :
    (registrationMsAfterMutBorrowDup7 mv).containers.write 1 (.struct_ [.bool false]) =
      some (registrationMsAfterOptionExtractDup1 mv).containers := by
  obtain ⟨cs', hw⟩ := registration_dup7_write1_exists mv
  have hms : (registrationMsAfterOptionExtractDup1 mv).containers = cs' := by
    dsimp [registrationMsAfterOptionExtractDup1]
    rw [hw]
  rw [hw, hms]

private theorem optionExtractRef_registration_dup7 (mv rCompressed : MoveValue) (rest : List MoveValue)
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

private theorem registration_locals_after_set5_idx8_lt (args : List MoveValue) (h : args.length = 7) :
    8 < ((registrationInitFrame args).locals.set 5 none (registrationInitFrame_idx5_lt args h)).size := by
  rw [Array.size_set, registrationInitFrame_locals_size args h]; decide

private theorem registration_locals_after_set5_set7_idx8_lt (args : List MoveValue) (h : args.length = 7) (mv : MoveValue) :
    8 < (((registrationInitFrame args).locals.set 5 none (registrationInitFrame_idx5_lt args h)).set 7 (some mv)
          (registration_locals_after_set5_idx7_lt args h)).size := by
  rw [Array.size_set, Array.size_set, registrationInitFrame_locals_size args h]; decide

private theorem registration_locals_after_set5_set7_idx9_lt (args : List MoveValue) (h : args.length = 7) (mv : MoveValue) :
    9 < (((registrationInitFrame args).locals.set 5 none (registrationInitFrame_idx5_lt args h)).set 7 (some mv)
          (registration_locals_after_set5_idx7_lt args h)).size := by
  rw [Array.size_set, Array.size_set, registrationInitFrame_locals_size args h]; decide

private theorem registration_locals_after_set5_set7_set8_idx9_lt (args : List MoveValue) (h : args.length = 7) (mv rCompressed : MoveValue) :
    9 < ((((registrationInitFrame args).locals.set 5 none (registrationInitFrame_idx5_lt args h)).set 7 (some mv)
          (registration_locals_after_set5_idx7_lt args h)).set 8 (some rCompressed)
          (registration_locals_after_set5_set7_idx8_lt args h mv)).size := by
  rw [Array.size_set, Array.size_set, Array.size_set, registrationInitFrame_locals_size args h]; decide

private theorem registrationFramePc7_locals_size (args : List MoveValue) (h : args.length = 7) (mv : MoveValue) :
    (registrationFramePc7AfterMutBorrowLoc7 args h mv).locals.size = 19 := by
  simp [registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
    registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame_locals_size args h]

private theorem registrationFramePc7_locals_idx8_lt (args : List MoveValue) (h : args.length = 7) (mv : MoveValue) :
    8 < (registrationFramePc7AfterMutBorrowLoc7 args h mv).locals.size := by
  rw [registrationFramePc7_locals_size args h mv]; decide

/-- Frame after `stLoc 8` (PC 8): local 8 holds `rCompressed`, PC 9, localRefs still has ref 1 on slot 7. -/
def registrationFramePc9AfterStLoc8 (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed : MoveValue) : Frame :=
  let fr := registrationFramePc7AfterMutBorrowLoc7 args h mv
  { fr with
    pc := 9
    locals := fr.locals.set 8 (some rCompressed) (registrationFramePc7_locals_idx8_lt args h mv) }

private theorem registrationFramePc9_locals_size (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed : MoveValue) :
    (registrationFramePc9AfterStLoc8 args h mv rCompressed).locals.size = 19 := by
  simp [registrationFramePc9AfterStLoc8, registrationFramePc7_locals_size args h mv]

private theorem registrationFramePc9_locals_idx6_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed : MoveValue) :
    6 < (registrationFramePc9AfterStLoc8 args h mv rCompressed).locals.size := by
  rw [registrationFramePc9_locals_size args h mv rCompressed]; decide

private theorem registrationFramePc9_localRefs_size (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed : MoveValue) :
    (registrationFramePc9AfterStLoc8 args h mv rCompressed).localRefs.size = 19 := by
  simp [registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7,
    registrationFrame_localRefs_size_19 args h mv]

private theorem registrationFramePc9_localRefs_idx6_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed : MoveValue) :
    6 < (registrationFramePc9AfterStLoc8 args h mv rCompressed).localRefs.size := by
  rw [registrationFramePc9_localRefs_size args h mv rCompressed]; decide

/-- Local 6 is unchanged by the earlier setters (5, 7, 8), so it still holds `respBytes`. -/
private theorem registrationFramePc9_locals_idx6_eq
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
private theorem registrationFramePc9_localRefs_idx6_eq (args : List MoveValue) (h : args.length = 7)
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

private theorem registrationFramePc11_locals_size (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed : MoveValue) :
    (registrationFramePc11AfterCall3 args h mv rCompressed).locals.size = 19 := by
  simp [registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
    registrationFramePc9_locals_size args h mv rCompressed]

private theorem registrationFramePc11_locals_idx9_lt (args : List MoveValue) (h : args.length = 7)
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

private theorem registrationFramePc12_locals_size (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt : MoveValue) :
    (registrationFramePc12AfterStLoc9 args h mv rCompressed sOpt).locals.size = 19 := by
  simp [registrationFramePc12AfterStLoc9, registrationFramePc11_locals_size args h mv rCompressed]

private theorem registrationFramePc12_locals_idx9_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt : MoveValue) :
    9 < (registrationFramePc12AfterStLoc9 args h mv rCompressed sOpt).locals.size := by
  rw [registrationFramePc12_locals_size args h mv rCompressed sOpt]; decide

private theorem registrationFramePc12_localRefs_size (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt : MoveValue) :
    (registrationFramePc12AfterStLoc9 args h mv rCompressed sOpt).localRefs.size = 19 := by
  simp [registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
    registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7,
    registrationFrame_localRefs_size_19 args h mv]

private theorem registrationFramePc12_localRefs_idx9_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt : MoveValue) :
    9 < (registrationFramePc12AfterStLoc9 args h mv rCompressed sOpt).localRefs.size := by
  rw [registrationFramePc12_localRefs_size args h mv rCompressed sOpt]; decide

/-- Dup store after PC 12: `[mv, .struct_ [.bool false], sOpt]`. -/
private theorem registration_imm9_store (mv sOpt : MoveValue) :
    (registrationMsAfterImmBorrow9 mv sOpt).containers.store =
      (registrationMsAfterOptionExtractDup1 mv).containers.store.push sOpt := by
  simp [registrationMsAfterImmBorrow9, ContainerStore.alloc]

private theorem registration_imm9_containers (mv sOpt : MoveValue) :
    ((registrationMsAfterOptionExtractDup1 mv).containers.alloc sOpt).1 =
      (registrationMsAfterImmBorrow9 mv sOpt).containers := rfl

private theorem registrationMsAfterOptionExtractDup1_store_size (mv : MoveValue) :
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

private theorem registrationMsAfterImmBorrow9_store_size (mv sOpt : MoveValue) :
    (registrationMsAfterImmBorrow9 mv sOpt).containers.store.size = 3 := by
  rw [registration_imm9_store]
  rw [Array.size_push, registrationMsAfterOptionExtractDup1_store_size]

/-- After PC 12 imm-borrow, reading ref 2 returns `sOpt`. -/
private theorem registration_imm9_read2 (mv sOpt : MoveValue) :
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

@[simp] private theorem verifyRegistrationProofCode_idx15 :
    verifyRegistrationProofCode[15]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .mutBorrowLoc 9 := rfl
@[simp] private theorem verifyRegistrationProofCode_idx16 :
    verifyRegistrationProofCode[16]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .call 2 := rfl
@[simp] private theorem verifyRegistrationProofCode_idx17 :
    verifyRegistrationProofCode[17]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .stLoc 10 := rfl

/-- `MachineState` after PC 15 `mutBorrowLoc 9`: allocates a duplicate `sOpt` at ref `3` on top of
the PC 12 imm-borrow store. Store is `[mv, .struct_[.bool false], sOpt, sOpt]`. -/
def registrationMsAfterMutBorrow9 (mv sOpt : MoveValue) : MachineState :=
  let cs := (registrationMsAfterImmBorrow9 mv sOpt).containers
  { MachineState.empty with containers := (cs.alloc sOpt).1 }

private theorem registration_mut9_store (mv sOpt : MoveValue) :
    (registrationMsAfterMutBorrow9 mv sOpt).containers.store =
      (registrationMsAfterImmBorrow9 mv sOpt).containers.store.push sOpt := by
  simp [registrationMsAfterMutBorrow9, ContainerStore.alloc]

private theorem registrationMsAfterMutBorrow9_store_size (mv sOpt : MoveValue) :
    (registrationMsAfterMutBorrow9 mv sOpt).containers.store.size = 4 := by
  rw [registration_mut9_store, Array.size_push, registrationMsAfterImmBorrow9_store_size]

private theorem registration_mut9_lt3 (mv sOpt : MoveValue) :
    3 < (registrationMsAfterMutBorrow9 mv sOpt).containers.store.size := by
  rw [registrationMsAfterMutBorrow9_store_size]; decide

/-- After PC 15 mut-borrow, reading ref 3 returns `sOpt`. -/
private theorem registration_mut9_read3 (mv sOpt : MoveValue) :
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

private theorem registration_mut9_write3_exists (mv sOpt : MoveValue) :
    ∃ cs', (registrationMsAfterMutBorrow9 mv sOpt).containers.write 3 (.struct_ [.bool false]) = some cs' := by
  refine ⟨⟨(registrationMsAfterMutBorrow9 mv sOpt).containers.store.set 3 (.struct_ [.bool false])
    (registration_mut9_lt3 mv sOpt)⟩, ?_⟩
  simp [ContainerStore.write, registration_mut9_lt3]

private theorem registration_write_mut9_eq_option_extract_ms (mv sOpt : MoveValue) :
    (registrationMsAfterMutBorrow9 mv sOpt).containers.write 3 (.struct_ [.bool false]) =
      some (registrationMsAfterOptionExtractDup3 mv sOpt).containers := by
  obtain ⟨cs', hw⟩ := registration_mut9_write3_exists mv sOpt
  have hms : (registrationMsAfterOptionExtractDup3 mv sOpt).containers = cs' := by
    dsimp [registrationMsAfterOptionExtractDup3]
    rw [hw]
  rw [hw, hms]

private theorem optionExtractRef_registration_mut9 (mv sOpt sVal : MoveValue) (srest' : List MoveValue)
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

private theorem registrationFramePc16_locals_size (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt : MoveValue) :
    (registrationFramePc16AfterMutBorrow9 args h mv rCompressed sOpt).locals.size = 19 := by
  simp [registrationFramePc16AfterMutBorrow9, registrationFramePc12_locals_size args h mv rCompressed sOpt]

private theorem registrationFramePc16_locals_idx10_lt (args : List MoveValue) (h : args.length = 7)
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

@[simp] private theorem verifyRegistrationProofCode_idx18 :
    verifyRegistrationProofCode[18]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .ldConst 5 := rfl
@[simp] private theorem verifyRegistrationProofCode_idx19 :
    verifyRegistrationProofCode[19]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .stLoc 11 := rfl
@[simp] private theorem verifyRegistrationProofCode_idx20 :
    verifyRegistrationProofCode[20]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .mutBorrowLoc 11 := rfl

private theorem registrationModuleEnv_constants_idx5 (o : RegistrationNativeOracle)
    (h : 5 < (registrationModuleEnv o).constants.size) :
    (registrationModuleEnv o).constants[5]'h =
      { type := .vector .u8, value := fiatShamirRegistrationDstValue } := by
  simp [registrationModuleEnv, registrationConstPool]

private theorem registrationModuleEnv_constants_size_gt5 (o : RegistrationNativeOracle) :
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

private theorem registrationFramePc18_locals_size (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    (registrationFramePc18AfterStLoc10 args h mv rCompressed sOpt sVal).locals.size = 19 := by
  simp [registrationFramePc18AfterStLoc10, registrationFramePc16_locals_size args h mv rCompressed sOpt]

private theorem registrationFramePc18_locals_idx11_lt (args : List MoveValue) (h : args.length = 7)
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

private theorem registrationFramePc20_locals_size (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    (registrationFramePc20AfterStLoc11 args h mv rCompressed sOpt sVal).locals.size = 19 := by
  simp [registrationFramePc20AfterStLoc11, registrationFramePc18_locals_size args h mv rCompressed sOpt sVal]

private theorem registrationFramePc20_locals_idx11_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    11 < (registrationFramePc20AfterStLoc11 args h mv rCompressed sOpt sVal).locals.size := by
  rw [registrationFramePc20_locals_size args h mv rCompressed sOpt sVal]; decide

private theorem registrationFramePc20_localRefs_size (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    (registrationFramePc20AfterStLoc11 args h mv rCompressed sOpt sVal).localRefs.size = 19 := by
  simp [registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
    registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
    registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7,
    registrationFrame_localRefs_size_19 args h mv]

private theorem registrationFramePc20_localRefs_idx11_lt (args : List MoveValue) (h : args.length = 7)
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

private theorem registrationMsAfterOptionExtractDup3_store_size (mv sOpt : MoveValue) :
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

@[simp] private theorem verifyRegistrationProofCode_idx21 :
    verifyRegistrationProofCode[21]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .moveLoc 0 := rfl
@[simp] private theorem verifyRegistrationProofCode_idx22 :
    verifyRegistrationProofCode[22]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .call 4 := rfl
@[simp] private theorem verifyRegistrationProofCode_idx23 :
    verifyRegistrationProofCode[23]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .mutBorrowLoc 11 := rfl

private theorem registration_env_funcIdx4_lt (o : RegistrationNativeOracle) :
    4 < (registrationModuleEnv o).functions.size := by
  rw [registration_module_env_size o]; decide

private theorem registrationModuleEnv_functions_at4 (o : RegistrationNativeOracle)
    (h : 4 < (registrationModuleEnv o).functions.size) :
    (registrationModuleEnv o).functions[4]'h =
      { numParams := 2, numReturns := 0, body := .nativeRef vectorPushBackU8Ref } := by
  simp [registrationModuleEnv, vectorPushBackU8RefDesc]

private theorem registrationFramePc21_locals_size (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    (registrationFramePc21AfterMutBorrowMsg args h mv rCompressed sOpt sVal).locals.size = 19 := by
  simp [registrationFramePc21AfterMutBorrowMsg, registrationFramePc20AfterStLoc11,
    registrationFramePc18_locals_size args h mv rCompressed sOpt sVal]

private theorem registrationFramePc21_locals_idx0_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    0 < (registrationFramePc21AfterMutBorrowMsg args h mv rCompressed sOpt sVal).locals.size := by
  rw [registrationFramePc21_locals_size args h mv rCompressed sOpt sVal]; decide

private theorem registrationFramePc21_localRefs_size (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    (registrationFramePc21AfterMutBorrowMsg args h mv rCompressed sOpt sVal).localRefs.size = 19 := by
  simp [registrationFramePc21AfterMutBorrowMsg, Array.size_set,
    registrationFramePc20_localRefs_size args h mv rCompressed sOpt sVal]

private theorem registrationFramePc21_localRefs_idx0_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    0 < (registrationFramePc21AfterMutBorrowMsg args h mv rCompressed sOpt sVal).localRefs.size := by
  rw [registrationFramePc21_localRefs_size args h mv rCompressed sOpt sVal]; decide

private theorem registrationFramePc21_localRefs_idx11_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    11 < (registrationFramePc21AfterMutBorrowMsg args h mv rCompressed sOpt sVal).localRefs.size := by
  rw [registrationFramePc21_localRefs_size args h mv rCompressed sOpt sVal]; decide

private theorem registrationFramePc21_locals_idx0_eq
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

private theorem registrationFramePc21_localRefs_idx0_eq (args : List MoveValue) (h : args.length = 7)
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

/-- The "next" `msg` value: DST bytes (as a `List MoveValue`) extended with a list of further bytes. -/
def fiatShamirRegistrationDstBytesList : List MoveValue :=
  [77, 111, 118, 101, 109, 101, 110, 116, 67, 111, 110, 102, 105, 100, 101, 110, 116, 105, 97, 108,
   65, 115, 115, 101, 116, 47, 82, 101, 103, 105, 115, 116, 114, 97, 116, 105, 111, 110].map MoveValue.u8

private theorem fiatShamirRegistrationDstValue_eq :
    fiatShamirRegistrationDstValue = .vector .u8 fiatShamirRegistrationDstBytesList := by
  simp [fiatShamirRegistrationDstValue, fiatShamirRegistrationDstBytesList]

private theorem registrationMsAfterMutBorrowMsg_store_size (mv sOpt : MoveValue) :
    (registrationMsAfterMutBorrowMsg mv sOpt).containers.store.size = 5 := by
  simp [registrationMsAfterMutBorrowMsg, ContainerStore.alloc, Array.size_push,
    registrationMsAfterOptionExtractDup3_store_size]

private theorem registration_mutMsg_lt4 (mv sOpt : MoveValue) :
    4 < (registrationMsAfterMutBorrowMsg mv sOpt).containers.store.size := by
  rw [registrationMsAfterMutBorrowMsg_store_size]; decide

private theorem registration_mutMsg_read4 (mv sOpt : MoveValue) :
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

private theorem registration_mutMsg_write4_chainId_exists (mv sOpt : MoveValue) (chainId : UInt8) :
    ∃ cs', (registrationMsAfterMutBorrowMsg mv sOpt).containers.write 4
        (.vector .u8 (fiatShamirRegistrationDstBytesList ++ [.u8 chainId])) = some cs' := by
  refine ⟨⟨(registrationMsAfterMutBorrowMsg mv sOpt).containers.store.set 4
      (.vector .u8 (fiatShamirRegistrationDstBytesList ++ [.u8 chainId]))
      (registration_mutMsg_lt4 mv sOpt)⟩, ?_⟩
  simp [ContainerStore.write, registration_mutMsg_lt4]

private theorem registration_write_mutMsg_chainId_eq (mv sOpt : MoveValue) (chainId : UInt8) :
    (registrationMsAfterMutBorrowMsg mv sOpt).containers.write 4
        (.vector .u8 (fiatShamirRegistrationDstBytesList ++ [.u8 chainId])) =
      some (registrationMsAfterPushBackChainId mv sOpt chainId).containers := by
  obtain ⟨cs', hw⟩ := registration_mutMsg_write4_chainId_exists mv sOpt chainId
  have hms : (registrationMsAfterPushBackChainId mv sOpt chainId).containers = cs' := by
    dsimp [registrationMsAfterPushBackChainId]
    rw [hw]
  rw [hw, hms]

private theorem vectorPushBackU8Ref_registration_mutMsg_chainId (mv sOpt : MoveValue) (chainId : UInt8) :
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

private theorem registrationFramePc22_locals_size (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).locals.size = 19 := by
  simp [registrationFramePc22AfterMoveLoc0, Array.size_set,
    registrationFramePc21_locals_size args h mv rCompressed sOpt sVal]

private theorem registrationFramePc22_locals_idx11_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    11 < (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).locals.size := by
  rw [registrationFramePc22_locals_size args h mv rCompressed sOpt sVal]; decide

private theorem registrationFramePc22_localRefs_size (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).localRefs.size = 19 := by
  simp [registrationFramePc22AfterMoveLoc0,
    registrationFramePc21_localRefs_size args h mv rCompressed sOpt sVal]

private theorem registrationFramePc22_localRefs_idx11_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    11 < (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).localRefs.size := by
  rw [registrationFramePc22_localRefs_size args h mv rCompressed sOpt sVal]; decide

private theorem registrationFramePc22_locals_idx11_eq
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

private theorem registrationFramePc22_localRefs_idx11_eq
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

@[simp] private theorem verifyRegistrationProofCode_idx24 :
    verifyRegistrationProofCode[24]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .immBorrowLoc 1 := rfl

private theorem registrationFramePc22_locals_idx1_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    1 < (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).locals.size := by
  rw [registrationFramePc22_locals_size args h mv rCompressed sOpt sVal]; decide

private theorem registrationFramePc22_localRefs_idx1_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    1 < (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).localRefs.size := by
  rw [registrationFramePc22_localRefs_size args h mv rCompressed sOpt sVal]; decide

private theorem registrationFramePc22_locals_idx1_eq
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

private theorem registrationFramePc22_localRefs_idx1_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).localRefs[1]'
      (registrationFramePc22_localRefs_idx1_lt args h mv rCompressed sOpt sVal) = none := by
  simp [registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg, registrationFramePc20AfterStLoc11,
    registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9, registrationFramePc12AfterStLoc9,
    registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6, registrationFramePc9AfterStLoc8,
    registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow, registrationFramePc3AfterStLoc,
    registrationFrameAtPc2, registrationInitFrame]

private theorem registrationMsAfterPushBackChainId_store_size (mv sOpt : MoveValue) (chainId : UInt8) :
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

@[simp] private theorem verifyRegistrationProofCode_idx25 :
    verifyRegistrationProofCode[25]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .call 5 := rfl

private theorem registration_env_funcIdx5_lt (o : RegistrationNativeOracle) :
    5 < (registrationModuleEnv o).functions.size := by
  rw [registration_module_env_size o]; decide

private theorem registrationModuleEnv_functions_at5 (o : RegistrationNativeOracle)
    (h : 5 < (registrationModuleEnv o).functions.size) :
    (registrationModuleEnv o).functions[5]'h =
      { numParams := 1, numReturns := 1, body := .nativeRef bcsToBytesAddressRef } := by
  simp [registrationModuleEnv, bcsToBytesAddressRefDesc]

private theorem registration_imm5_read_sender (mv sOpt : MoveValue) (chainId : UInt8) (sender : ByteArray) :
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

private theorem bcsToBytesAddressRef_registration_sender (mv sOpt : MoveValue) (chainId : UInt8) (sender : ByteArray) :
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

@[simp] private theorem verifyRegistrationProofCode_idx26 :
    verifyRegistrationProofCode[26]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .call 6 := rfl

private theorem registration_env_funcIdx6_lt (o : RegistrationNativeOracle) :
    6 < (registrationModuleEnv o).functions.size := by
  rw [registration_module_env_size o]; decide

private theorem registrationModuleEnv_functions_at6 (o : RegistrationNativeOracle)
    (h : 6 < (registrationModuleEnv o).functions.size) :
    (registrationModuleEnv o).functions[6]'h =
      { numParams := 2, numReturns := 0, body := .nativeRef vectorAppendU8Ref } := by
  simp [registrationModuleEnv, vectorAppendU8RefDesc]

private theorem registrationMsAfterImmBorrow1_sender_store_size
    (mv sOpt : MoveValue) (chainId : UInt8) (sender : ByteArray) :
    (registrationMsAfterImmBorrow1_sender mv sOpt chainId sender).containers.store.size = 6 := by
  simp [registrationMsAfterImmBorrow1_sender, ContainerStore.alloc, Array.size_push,
    registrationMsAfterPushBackChainId_store_size]

private theorem registration_sender_lt4 (mv sOpt : MoveValue) (chainId : UInt8) (sender : ByteArray) :
    4 < (registrationMsAfterImmBorrow1_sender mv sOpt chainId sender).containers.store.size := by
  rw [registrationMsAfterImmBorrow1_sender_store_size]; decide

/-- Reading ref 4 in `registrationMsAfterImmBorrow1_sender` gives back the msg DST++chainId value. -/
private theorem registration_sender_read4 (mv sOpt : MoveValue) (chainId : UInt8) (sender : ByteArray) :
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

private theorem registration_write_append_sender_eq (mv sOpt : MoveValue) (chainId : UInt8) (sender : ByteArray) :
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

private theorem vectorAppendU8Ref_registration_sender (mv sOpt : MoveValue) (chainId : UInt8) (sender : ByteArray) :
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

@[simp] private theorem verifyRegistrationProofCode_idx27 :
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

@[simp] private theorem verifyRegistrationProofCode_idx28 :
    verifyRegistrationProofCode[28]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .immBorrowLoc 2 := rfl

private theorem registrationFramePc22_locals_idx2_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    2 < (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).locals.size := by
  rw [registrationFramePc22_locals_size args h mv rCompressed sOpt sVal]; decide

private theorem registrationFramePc22_localRefs_idx2_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    2 < (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).localRefs.size := by
  rw [registrationFramePc22_localRefs_size args h mv rCompressed sOpt sVal]; decide

private theorem registrationFramePc22_locals_idx2_eq
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

private theorem registrationFramePc22_localRefs_idx2_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).localRefs[2]'
      (registrationFramePc22_localRefs_idx2_lt args h mv rCompressed sOpt sVal) = none := by
  simp [registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg, registrationFramePc20AfterStLoc11,
    registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9, registrationFramePc12AfterStLoc9,
    registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6, registrationFramePc9AfterStLoc8,
    registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow, registrationFramePc3AfterStLoc,
    registrationFrameAtPc2, registrationInitFrame]

/-- `registrationMsAfterAppendSender` has store size 6 (same as after alloc sender — write does not change size). -/
private theorem registrationMsAfterAppendSender_store_size
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

@[simp] private theorem verifyRegistrationProofCode_idx29 :
    verifyRegistrationProofCode[29]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .call 5 := rfl

private theorem registration_imm6_read_contract (mv sOpt : MoveValue) (chainId : UInt8) (sender contract : ByteArray) :
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

private theorem bcsToBytesAddressRef_registration_contract
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

@[simp] private theorem verifyRegistrationProofCode_idx30 :
    verifyRegistrationProofCode[30]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .call 6 := rfl

private theorem registration_contract_lt4
    (mv sOpt : MoveValue) (chainId : UInt8) (sender contract : ByteArray) :
    4 < (registrationMsAfterImmBorrow2_contract mv sOpt chainId sender contract).containers.store.size := by
  have halloc :
      (registrationMsAfterImmBorrow2_contract mv sOpt chainId sender contract).containers =
        ((registrationMsAfterAppendSender mv sOpt chainId sender).containers.alloc (.address contract)).1 := rfl
  rw [halloc]
  simp only [ContainerStore.alloc, Array.size_push]
  rw [registrationMsAfterAppendSender_store_size]; decide

/-- Reading ref 4 in `registrationMsAfterImmBorrow2_contract` yields DST++[chainId]++senderBytes. -/
private theorem registration_contract_read4
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

private theorem registration_write_append_contract_eq
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

private theorem vectorAppendU8Ref_registration_contract
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

/-! ### PC 31–34: `mutBorrowLoc 11`, `immBorrowLoc 4` (token → ref 7), `call 5`, `call 6`.

For scalability, PC 31–34 are stated generically over an arbitrary input `MachineState`.
This avoids the exponential whnf blow-up that would happen if we directly referred to the
deep MS chain `registrationMsAfterAppendContract` in the theorem signature. The specialised
corollaries (used downstream) are obtained by applying the generic lemma. -/

@[simp] private theorem verifyRegistrationProofCode_idx31 :
    verifyRegistrationProofCode[31]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .mutBorrowLoc 11 := rfl

-- PC 31 (generic): `mutBorrowLoc 11` reuses existing ref 4, same as PC 23/27.
set_option maxHeartbeats 800000 in
theorem registration_step_pc31_mutBorrowLoc11_generic (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal : MoveValue) (ms : MachineState) :
    step (registrationModuleEnv o)
        ({ registrationFramePc22AfterMoveLoc0 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 31 })
        [] [] ms =
      ExecResult.ok
        ({ registrationFramePc22AfterMoveLoc0 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 32 })
        [] [.mutRef 4] ms := by
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  let hlen : args.length = 7 := registrationVerifyArgs_len _ _ _ _ _ _ _
  let fr' := ({ registrationFramePc22AfterMoveLoc0 args hlen mv rCompressed sOpt sVal with pc := 31 })
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
      verifyRegistrationProofCode_size_val, verifyRegistrationProofCode_idx31]
  have hlocLt : 11 < fr'.locals.size :=
    registrationFramePc22_locals_idx11_lt args hlen mv rCompressed sOpt sVal
  have hlocVal := registrationFramePc22_locals_idx11_eq chainId sender contract token ekBa commitBa respBa
    mv rCompressed sOpt sVal
  have hlocRefLt : 11 < fr'.localRefs.size :=
    registrationFramePc22_localRefs_idx11_lt args hlen mv rCompressed sOpt sVal
  have hlocRefVal := registrationFramePc22_localRefs_idx11_eq args hlen mv rCompressed sOpt sVal
  simp only [step, dif_pos hpc, hc, dif_pos hlocLt, hlocVal, dif_pos hlocRefLt, hlocRefVal]
  rfl

@[simp] private theorem verifyRegistrationProofCode_idx32 :
    verifyRegistrationProofCode[32]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .immBorrowLoc 4 := rfl

private theorem registrationFramePc22_locals_idx4_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    4 < (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).locals.size := by
  rw [registrationFramePc22_locals_size args h mv rCompressed sOpt sVal]; decide

private theorem registrationFramePc22_localRefs_idx4_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    4 < (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).localRefs.size := by
  rw [registrationFramePc22_localRefs_size args h mv rCompressed sOpt sVal]; decide

private theorem registrationFramePc22_locals_idx4_eq
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal : MoveValue) :
    (registrationFramePc22AfterMoveLoc0 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
      (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal).locals[4]'
      (registrationFramePc22_locals_idx4_lt _ _ mv rCompressed sOpt sVal) = some (.address token) := by
  simp [registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg, registrationFramePc20AfterStLoc11,
    registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9, registrationFramePc12AfterStLoc9,
    registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6, registrationFramePc9AfterStLoc8,
    registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow, registrationFramePc3AfterStLoc,
    registrationFrameAtPc2, registrationInitFrame, registrationVerifyArgs]

private theorem registrationFramePc22_localRefs_idx4_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).localRefs[4]'
      (registrationFramePc22_localRefs_idx4_lt args h mv rCompressed sOpt sVal) = none := by
  simp [registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg, registrationFramePc20AfterStLoc11,
    registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9, registrationFramePc12AfterStLoc9,
    registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6, registrationFramePc9AfterStLoc8,
    registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow, registrationFramePc3AfterStLoc,
    registrationFrameAtPc2, registrationInitFrame]

-- Frame after PC 32: same base but with pc := 33. `immBorrowLoc` does not update `localRefs`.
def registrationFramePc33AfterImmBorrow4 (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) : Frame :=
  { registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal with pc := 33 }

-- PC 32 (generic): `immBorrowLoc 4` — alloc `token` at `ms.store.size`, push `immRef`.
set_option maxHeartbeats 800000 in
theorem registration_step_pc32_immBorrowLoc4_generic (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal : MoveValue) (ms : MachineState) :
    step (registrationModuleEnv o)
        ({ registrationFramePc22AfterMoveLoc0 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 32 })
        [] [.mutRef 4] ms =
      ExecResult.ok
        (registrationFramePc33AfterImmBorrow4 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal)
        [] [.immRef (ms.containers.alloc (.address token)).2, .mutRef 4]
        { ms with containers := (ms.containers.alloc (.address token)).1 } := by
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  let hlen : args.length = 7 := registrationVerifyArgs_len _ _ _ _ _ _ _
  let fr' := ({ registrationFramePc22AfterMoveLoc0 args hlen mv rCompressed sOpt sVal with pc := 32 })
  have hpc : fr'.pc < fr'.code.size := by
    simp [fr', registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
      registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
      registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
      registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
      registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame, verifyRegistrationProofCode_size_val]
  have hc : fr'.code[fr'.pc]'hpc = MoveInstr.immBorrowLoc 4 := by
    simp [fr', registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
      registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
      registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
      registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
      registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame, verifyRegistrationProofCode_size_val,
      verifyRegistrationProofCode_idx32]
  have hlocLt : 4 < fr'.locals.size :=
    registrationFramePc22_locals_idx4_lt args hlen mv rCompressed sOpt sVal
  have hlocVal := registrationFramePc22_locals_idx4_eq chainId sender contract token ekBa commitBa respBa
    mv rCompressed sOpt sVal
  have hlocRefLt : 4 < fr'.localRefs.size :=
    registrationFramePc22_localRefs_idx4_lt args hlen mv rCompressed sOpt sVal
  have hlocRefVal := registrationFramePc22_localRefs_idx4_eq args hlen mv rCompressed sOpt sVal
  simp only [step, dif_pos hpc, hc, dif_pos hlocLt, hlocVal, dif_pos hlocRefLt, hlocRefVal]
  rfl

@[simp] private theorem verifyRegistrationProofCode_idx33 :
    verifyRegistrationProofCode[33]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .call 5 := rfl

-- PC 33 (generic): `call 5` = `bcs::to_bytes<address>`; reads address at `refId`, pushes bytes.
set_option maxHeartbeats 800000 in
theorem registration_step_pc33_call_bcsToBytes_generic (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal : MoveValue) (ms : MachineState) (refId : RefId) (addr : ByteArray)
    (hread : ms.containers.read refId = some (.address addr)) :
    step (registrationModuleEnv o)
        (registrationFramePc33AfterImmBorrow4 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal)
        [] [.immRef refId, .mutRef 4] ms =
      ExecResult.ok
        ({ registrationFramePc33AfterImmBorrow4 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 34 })
        [] [.vector .u8 (addr.toList.map .u8), .mutRef 4] ms := by
  have hnative : bcsToBytesAddressRef ms.containers [.immRef refId] =
      some ([.vector .u8 (addr.toList.map .u8)], ms.containers) := by
    simp only [bcsToBytesAddressRef]; rw [hread]
  simp only [step, registrationModuleEnv, registrationFramePc33AfterImmBorrow4,
    registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
    registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
    registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
    registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
    registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame, registrationVerifyArgs,
    verifyRegistrationProofCode, verifyRegistrationProofCode_size_val, verifyRegistrationProofCode_idx33,
    registrationInitFrame_idx5_lt, registration_locals_after_set5_idx7_lt, registrationVerifyArgs_len,
    registration_env_funcIdx5_lt, registrationModuleEnv_functions_at5, FuncDesc.body, bcsToBytesAddressRefDesc,
    takeN_two_one, List.map_cons, List.map_nil, Nat.reduceSub, List.reduceReplicate,
    List.cons_append, List.nil_append, List.size_toArray, List.length_cons, List.length_nil, zero_add,
    Nat.reduceAdd, Nat.reduceLT, Nat.one_lt_ofNat, ↓reduceDIte, List.getElem_toArray, List.getElem_cons_succ,
    List.getElem_cons_zero, Nat.ofNat_pos, Nat.reduceBEq, Bool.false_eq_true, BEq.rfl, List.set_toArray,
    List.set_cons_succ, List.set_cons_zero, beq_iff_eq]
  rw [hnative]
  simp only [handleNativeResult_ret1]

@[simp] private theorem verifyRegistrationProofCode_idx34 :
    verifyRegistrationProofCode[34]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .call 6 := rfl

-- PC 34 (generic): `call 6` = `vector::append<u8>`; appends second arg to vector at ref 4.
set_option maxHeartbeats 800000 in
theorem registration_step_pc34_call_append_generic (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal : MoveValue) (ms : MachineState)
    (existing appended : List MoveValue) (cs' : ContainerStore)
    (hread : ms.containers.read 4 = some (.vector .u8 existing))
    (hwrite : ms.containers.write 4 (.vector .u8 (existing ++ appended)) = some cs') :
    step (registrationModuleEnv o)
        ({ registrationFramePc33AfterImmBorrow4 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 34 })
        [] [.vector .u8 appended, .mutRef 4] ms =
      ExecResult.ok
        ({ registrationFramePc33AfterImmBorrow4 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 35 })
        [] [] { ms with containers := cs' } := by
  have hnative : vectorAppendU8Ref ms.containers [.mutRef 4, .vector .u8 appended] =
      some ([], cs') := by
    simp only [vectorAppendU8Ref]; rw [hread]; simp only; rw [hwrite]
  simp only [step, registrationModuleEnv, registrationFramePc33AfterImmBorrow4,
    registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
    registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
    registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
    registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
    registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame, registrationVerifyArgs,
    verifyRegistrationProofCode, verifyRegistrationProofCode_size_val, verifyRegistrationProofCode_idx34,
    registrationInitFrame_idx5_lt, registration_locals_after_set5_idx7_lt, registrationVerifyArgs_len,
    registration_env_funcIdx6_lt, registrationModuleEnv_functions_at6, FuncDesc.body, vectorAppendU8RefDesc,
    takeN_two_pair, List.map_cons, List.map_nil, Nat.reduceSub, List.reduceReplicate, List.cons_append,
    List.nil_append, List.size_toArray, List.length_cons, List.length_nil, zero_add, Nat.reduceAdd,
    Nat.reduceLT, Nat.one_lt_ofNat, ↓reduceDIte, List.getElem_toArray, List.getElem_cons_succ,
    List.getElem_cons_zero, Nat.ofNat_pos, Nat.reduceBEq, Bool.false_eq_true, BEq.rfl, List.set_toArray,
    List.set_cons_succ, List.set_cons_zero, beq_iff_eq]
  rw [hnative]
  simp only [handleNativeResult_ret0]

/-! ### PC 35–38: second iteration of Fiat–Shamir append for `ek`.
PC 35 `mutBorrowLoc 11`, PC 36 `copyLoc 3` (push `ek` struct),
PC 37 `call 7` `pubkey_to_bytes(&CompressedPubkey) → vector<u8>`,
PC 38 `call 6` `vector::append<u8>(&mut msg, ekBytes)`.
All stated generically over an arbitrary input `MachineState`. -/

@[simp] private theorem verifyRegistrationProofCode_idx35 :
    verifyRegistrationProofCode[35]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .mutBorrowLoc 11 := rfl

-- PC 35 (generic): `mutBorrowLoc 11` reuses existing ref 4, pc 35→36.
set_option maxHeartbeats 800000 in
theorem registration_step_pc35_mutBorrowLoc11_generic (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal : MoveValue) (ms : MachineState) :
    step (registrationModuleEnv o)
        ({ registrationFramePc22AfterMoveLoc0 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 35 })
        [] [] ms =
      ExecResult.ok
        ({ registrationFramePc22AfterMoveLoc0 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 36 })
        [] [.mutRef 4] ms := by
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  let hlen : args.length = 7 := registrationVerifyArgs_len _ _ _ _ _ _ _
  let fr' := ({ registrationFramePc22AfterMoveLoc0 args hlen mv rCompressed sOpt sVal with pc := 35 })
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
      verifyRegistrationProofCode_size_val, verifyRegistrationProofCode_idx35]
  have hlocLt : 11 < fr'.locals.size :=
    registrationFramePc22_locals_idx11_lt args hlen mv rCompressed sOpt sVal
  have hlocVal := registrationFramePc22_locals_idx11_eq chainId sender contract token ekBa commitBa respBa
    mv rCompressed sOpt sVal
  have hlocRefLt : 11 < fr'.localRefs.size :=
    registrationFramePc22_localRefs_idx11_lt args hlen mv rCompressed sOpt sVal
  have hlocRefVal := registrationFramePc22_localRefs_idx11_eq args hlen mv rCompressed sOpt sVal
  simp only [step, dif_pos hpc, hc, dif_pos hlocLt, hlocVal, dif_pos hlocRefLt, hlocRefVal]
  rfl

@[simp] private theorem verifyRegistrationProofCode_idx36 :
    verifyRegistrationProofCode[36]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .copyLoc 3 := rfl

private theorem registrationFramePc22_locals_idx3_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    3 < (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).locals.size := by
  rw [registrationFramePc22_locals_size args h mv rCompressed sOpt sVal]; decide

private theorem registrationFramePc22_localRefs_idx3_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    3 < (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).localRefs.size := by
  rw [registrationFramePc22_localRefs_size args h mv rCompressed sOpt sVal]; decide

private theorem registrationFramePc22_locals_idx3_eq
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal : MoveValue) :
    (registrationFramePc22AfterMoveLoc0 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
      (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal).locals[3]'
      (registrationFramePc22_locals_idx3_lt _ _ mv rCompressed sOpt sVal) =
        some (.struct_ [.vector .u8 (ekBa.toList.map .u8)]) := by
  simp [registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg, registrationFramePc20AfterStLoc11,
    registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9, registrationFramePc12AfterStLoc9,
    registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6, registrationFramePc9AfterStLoc8,
    registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow, registrationFramePc3AfterStLoc,
    registrationFrameAtPc2, registrationInitFrame, registrationVerifyArgs]

private theorem registrationFramePc22_localRefs_idx3_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).localRefs[3]'
      (registrationFramePc22_localRefs_idx3_lt args h mv rCompressed sOpt sVal) = none := by
  simp [registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg, registrationFramePc20AfterStLoc11,
    registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9, registrationFramePc12AfterStLoc9,
    registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6, registrationFramePc9AfterStLoc8,
    registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow, registrationFramePc3AfterStLoc,
    registrationFrameAtPc2, registrationInitFrame]

-- PC 36 (generic): `copyLoc 3` pushes `ek` struct value on stack (no ref tracked at local 3).
set_option maxHeartbeats 800000 in
theorem registration_step_pc36_copyLoc3_generic (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal : MoveValue) (ms : MachineState) :
    step (registrationModuleEnv o)
        ({ registrationFramePc22AfterMoveLoc0 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 36 })
        [] [.mutRef 4] ms =
      ExecResult.ok
        ({ registrationFramePc22AfterMoveLoc0 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 37 })
        [] [.struct_ [.vector .u8 (ekBa.toList.map .u8)], .mutRef 4] ms := by
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  let hlen : args.length = 7 := registrationVerifyArgs_len _ _ _ _ _ _ _
  let fr' := ({ registrationFramePc22AfterMoveLoc0 args hlen mv rCompressed sOpt sVal with pc := 36 })
  have hpc : fr'.pc < fr'.code.size := by
    simp [fr', registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
      registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
      registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
      registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
      registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame, verifyRegistrationProofCode_size_val]
  have hc : fr'.code[fr'.pc]'hpc = MoveInstr.copyLoc 3 := by
    simp [fr', registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
      registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
      registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
      registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
      registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame,
      verifyRegistrationProofCode_size_val, verifyRegistrationProofCode_idx36]
  have hlocLt : 3 < fr'.locals.size :=
    registrationFramePc22_locals_idx3_lt args hlen mv rCompressed sOpt sVal
  have hlocVal := registrationFramePc22_locals_idx3_eq chainId sender contract token ekBa commitBa respBa
    mv rCompressed sOpt sVal
  have hlocRefLt : 3 < fr'.localRefs.size :=
    registrationFramePc22_localRefs_idx3_lt args hlen mv rCompressed sOpt sVal
  have hlocRefVal := registrationFramePc22_localRefs_idx3_eq args hlen mv rCompressed sOpt sVal
  simp only [step, dif_pos hpc, hc, dif_pos hlocLt, hlocVal, dif_pos hlocRefLt, hlocRefVal]
  rfl

@[simp] private theorem verifyRegistrationProofCode_idx37 :
    verifyRegistrationProofCode[37]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .call 7 := rfl

private theorem registration_env_funcIdx7_lt (o : RegistrationNativeOracle) :
    7 < (registrationModuleEnv o).functions.size := by
  rw [registration_module_env_size o]; decide

private theorem registrationModuleEnv_functions_at7 (o : RegistrationNativeOracle)
    (h : 7 < (registrationModuleEnv o).functions.size) :
    (registrationModuleEnv o).functions[7]'h =
      { numParams := 1, numReturns := 1, body := .nativeRef (wrapOracleImmRef1 o.pubkeyToBytes) } := by
  simp [registrationModuleEnv]

-- PC 37 (generic): `call 7` = `pubkey_to_bytes`; consumes the `ek` struct on stack, pushes `ekBytes`.
-- Specialised to the struct shape produced by `copyLoc 3`, so `derefImm` collapses to identity.
set_option maxHeartbeats 800000 in
theorem registration_step_pc37_call_pubkeyToBytes_generic (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal : MoveValue) (ms : MachineState)
    (ekBytes : MoveValue)
    (horacle : o.pubkeyToBytes [.struct_ [.vector .u8 (ekBa.toList.map .u8)]] = some [ekBytes]) :
    step (registrationModuleEnv o)
        ({ registrationFramePc22AfterMoveLoc0 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 37 })
        [] [.struct_ [.vector .u8 (ekBa.toList.map .u8)], .mutRef 4] ms =
      ExecResult.ok
        ({ registrationFramePc22AfterMoveLoc0 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 38 })
        [] [ekBytes, .mutRef 4] ms := by
  have hnative : wrapOracleImmRef1 o.pubkeyToBytes ms.containers
        [.struct_ [.vector .u8 (ekBa.toList.map .u8)]] =
      some ([ekBytes], ms.containers) := by
    show (Option.bind (derefImm ms.containers
            (.struct_ [.vector .u8 (ekBa.toList.map .u8)]))
          (fun v => Option.bind (o.pubkeyToBytes [v])
              (fun results => some (results, ms.containers)))) =
        some ([ekBytes], ms.containers)
    simp only [derefImm, Option.bind_some]
    rw [horacle]
    rfl
  simp only [step, registrationModuleEnv, registrationFramePc22AfterMoveLoc0,
    registrationFramePc21AfterMutBorrowMsg, registrationFramePc20AfterStLoc11,
    registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
    registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
    registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
    registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame, registrationVerifyArgs,
    verifyRegistrationProofCode, verifyRegistrationProofCode_size_val, verifyRegistrationProofCode_idx37,
    registrationInitFrame_idx5_lt, registration_locals_after_set5_idx7_lt, registrationVerifyArgs_len,
    registration_env_funcIdx7_lt, registrationModuleEnv_functions_at7, FuncDesc.body,
    takeN_two_one, List.map_cons, List.map_nil, Nat.reduceSub, List.reduceReplicate,
    List.cons_append, List.nil_append, List.size_toArray, List.length_cons, List.length_nil, zero_add,
    Nat.reduceAdd, Nat.reduceLT, Nat.one_lt_ofNat, ↓reduceDIte, List.getElem_toArray, List.getElem_cons_succ,
    List.getElem_cons_zero, Nat.ofNat_pos, Nat.reduceBEq, Bool.false_eq_true, BEq.rfl, List.set_toArray,
    List.set_cons_succ, List.set_cons_zero, beq_iff_eq]
  rw [hnative]
  simp only [handleNativeResult_ret1]

@[simp] private theorem verifyRegistrationProofCode_idx38 :
    verifyRegistrationProofCode[38]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .call 6 := rfl

-- PC 38 (generic): `call 6` = `vector::append<u8>`; appends `appended` bytes to `existing` at ref 4.
-- Same pattern as PC 34 generic; only pc changes (38→39).
set_option maxHeartbeats 800000 in
theorem registration_step_pc38_call_append_generic (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal : MoveValue) (ms : MachineState)
    (existing appended : List MoveValue) (cs' : ContainerStore)
    (hread : ms.containers.read 4 = some (.vector .u8 existing))
    (hwrite : ms.containers.write 4 (.vector .u8 (existing ++ appended)) = some cs') :
    step (registrationModuleEnv o)
        ({ registrationFramePc22AfterMoveLoc0 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 38 })
        [] [.vector .u8 appended, .mutRef 4] ms =
      ExecResult.ok
        ({ registrationFramePc22AfterMoveLoc0 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 39 })
        [] [] { ms with containers := cs' } := by
  have hnative : vectorAppendU8Ref ms.containers [.mutRef 4, .vector .u8 appended] =
      some ([], cs') := by
    simp only [vectorAppendU8Ref]; rw [hread]; simp only; rw [hwrite]
  simp only [step, registrationModuleEnv, registrationFramePc22AfterMoveLoc0,
    registrationFramePc21AfterMutBorrowMsg, registrationFramePc20AfterStLoc11,
    registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
    registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
    registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
    registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame, registrationVerifyArgs,
    verifyRegistrationProofCode, verifyRegistrationProofCode_size_val, verifyRegistrationProofCode_idx38,
    registrationInitFrame_idx5_lt, registration_locals_after_set5_idx7_lt, registrationVerifyArgs_len,
    registration_env_funcIdx6_lt, registrationModuleEnv_functions_at6, FuncDesc.body, vectorAppendU8RefDesc,
    takeN_two_pair, List.map_cons, List.map_nil, Nat.reduceSub, List.reduceReplicate, List.cons_append,
    List.nil_append, List.size_toArray, List.length_cons, List.length_nil, zero_add, Nat.reduceAdd,
    Nat.reduceLT, Nat.one_lt_ofNat, ↓reduceDIte, List.getElem_toArray, List.getElem_cons_succ,
    List.getElem_cons_zero, Nat.ofNat_pos, Nat.reduceBEq, Bool.false_eq_true, BEq.rfl, List.set_toArray,
    List.set_cons_succ, List.set_cons_zero, beq_iff_eq]
  rw [hnative]
  simp only [handleNativeResult_ret0]

/-! ### PC 39–45: Fiat–Shamir append of `r_compressed`, `moveLoc 11`, SHA2-512 scalar.
- PC 39 `mutBorrowLoc 11`  (≈ PC 35)
- PC 40 `copyLoc 8`        (push `r_compressed` value from local 8)
- PC 41 `call 8`           (`compressed_point_to_bytes`, native oracle)
- PC 42 `call 6`           (`vector::append<u8>`, ≈ PC 38)
- PC 43 `moveLoc 11`       (push `msg` from ref 4, clear local 11 / localRefs[11])
- PC 44 `call 9`           (`new_scalar_from_sha2_512`, native)
- PC 45 `stLoc 12`         (store `e`)
All stated generically over an arbitrary input `MachineState`. -/

/-- Helper for `copyLoc 8`: `locals[8]` at the PC 22 frame equals `some rCompressed`. -/
private theorem registrationFramePc22_locals_idx8_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    8 < (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).locals.size := by
  rw [registrationFramePc22_locals_size args h mv rCompressed sOpt sVal]; decide

private theorem registrationFramePc22_localRefs_idx8_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    8 < (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).localRefs.size := by
  rw [registrationFramePc22_localRefs_size args h mv rCompressed sOpt sVal]; decide

private theorem registrationFramePc22_locals_idx8_eq
    (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).locals[8]'
      (registrationFramePc22_locals_idx8_lt args h mv rCompressed sOpt sVal) = some rCompressed := by
  simp [registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg, registrationFramePc20AfterStLoc11,
    registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9, registrationFramePc12AfterStLoc9,
    registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6, registrationFramePc9AfterStLoc8,
    registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow, registrationFramePc3AfterStLoc,
    registrationFrameAtPc2, registrationInitFrame]

private theorem registrationFramePc22_localRefs_idx8_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).localRefs[8]'
      (registrationFramePc22_localRefs_idx8_lt args h mv rCompressed sOpt sVal) = none := by
  simp [registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg, registrationFramePc20AfterStLoc11,
    registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9, registrationFramePc12AfterStLoc9,
    registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6, registrationFramePc9AfterStLoc8,
    registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow, registrationFramePc3AfterStLoc,
    registrationFrameAtPc2, registrationInitFrame]

@[simp] private theorem verifyRegistrationProofCode_idx40 :
    verifyRegistrationProofCode[40]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .copyLoc 8 := rfl

-- PC 40 (generic): `copyLoc 8` pushes `rCompressed` value from local 8 (no ref tracked).
set_option maxHeartbeats 800000 in
theorem registration_step_pc40_copyLoc8_generic (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal : MoveValue) (ms : MachineState) :
    step (registrationModuleEnv o)
        ({ registrationFramePc22AfterMoveLoc0 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 40 })
        [] [.mutRef 4] ms =
      ExecResult.ok
        ({ registrationFramePc22AfterMoveLoc0 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 41 })
        [] [rCompressed, .mutRef 4] ms := by
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  let hlen : args.length = 7 := registrationVerifyArgs_len _ _ _ _ _ _ _
  let fr' := ({ registrationFramePc22AfterMoveLoc0 args hlen mv rCompressed sOpt sVal with pc := 40 })
  have hpc : fr'.pc < fr'.code.size := by
    simp [fr', registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
      registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
      registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
      registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
      registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame, verifyRegistrationProofCode_size_val]
  have hc : fr'.code[fr'.pc]'hpc = MoveInstr.copyLoc 8 := by
    simp [fr', registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
      registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
      registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
      registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
      registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame,
      verifyRegistrationProofCode_size_val, verifyRegistrationProofCode_idx40]
  have hlocLt : 8 < fr'.locals.size :=
    registrationFramePc22_locals_idx8_lt args hlen mv rCompressed sOpt sVal
  have hlocVal := registrationFramePc22_locals_idx8_eq args hlen mv rCompressed sOpt sVal
  have hlocRefLt : 8 < fr'.localRefs.size :=
    registrationFramePc22_localRefs_idx8_lt args hlen mv rCompressed sOpt sVal
  have hlocRefVal := registrationFramePc22_localRefs_idx8_eq args hlen mv rCompressed sOpt sVal
  simp only [step, dif_pos hpc, hc, dif_pos hlocLt, hlocVal, dif_pos hlocRefLt, hlocRefVal]
  rfl

@[simp] private theorem verifyRegistrationProofCode_idx41 :
    verifyRegistrationProofCode[41]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .call 8 := rfl

private theorem registration_env_funcIdx8_lt (o : RegistrationNativeOracle) :
    8 < (registrationModuleEnv o).functions.size := by
  rw [registration_module_env_size o]; decide

private theorem registrationModuleEnv_functions_at8 (o : RegistrationNativeOracle)
    (h : 8 < (registrationModuleEnv o).functions.size) :
    (registrationModuleEnv o).functions[8]'h =
      { numParams := 1, numReturns := 1, body := .native o.compressedPointToBytes } := by
  simp [registrationModuleEnv]

-- PC 41 (generic): `call 8` = `compressed_point_to_bytes` (native); consumes `rCompressed`, pushes `rcBytes`.
set_option maxHeartbeats 800000 in
theorem registration_step_pc41_call_compressedPointToBytes_generic (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal : MoveValue) (ms : MachineState)
    (rcBytes : MoveValue)
    (horacle : o.compressedPointToBytes [rCompressed] = some [rcBytes]) :
    step (registrationModuleEnv o)
        ({ registrationFramePc22AfterMoveLoc0 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 41 })
        [] [rCompressed, .mutRef 4] ms =
      ExecResult.ok
        ({ registrationFramePc22AfterMoveLoc0 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 42 })
        [] [rcBytes, .mutRef 4] ms := by
  simp only [step, registrationModuleEnv, registrationFramePc22AfterMoveLoc0,
    registrationFramePc21AfterMutBorrowMsg, registrationFramePc20AfterStLoc11,
    registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
    registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
    registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
    registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame, registrationVerifyArgs,
    verifyRegistrationProofCode, verifyRegistrationProofCode_size_val, verifyRegistrationProofCode_idx41,
    registrationInitFrame_idx5_lt, registration_locals_after_set5_idx7_lt, registrationVerifyArgs_len,
    registration_env_funcIdx8_lt, registrationModuleEnv_functions_at8, FuncDesc.body,
    takeN_two_one, List.map_cons, List.map_nil, Nat.reduceSub, List.reduceReplicate,
    List.cons_append, List.nil_append, List.size_toArray, List.length_cons, List.length_nil, zero_add,
    Nat.reduceAdd, Nat.reduceLT, Nat.one_lt_ofNat, ↓reduceDIte, List.getElem_toArray, List.getElem_cons_succ,
    List.getElem_cons_zero, Nat.ofNat_pos, Nat.reduceBEq, Bool.false_eq_true, BEq.rfl, List.set_toArray,
    List.set_cons_succ, List.set_cons_zero, beq_iff_eq]
  rw [horacle]
  simp only [handleNativeResult_ret1]

/-! ### PC 39, 42: more occurrences of `mutBorrowLoc 11` / `call 6` (append).
Same patterns as PC 35 / PC 38, with PC labels shifted by 4. -/

@[simp] private theorem verifyRegistrationProofCode_idx39 :
    verifyRegistrationProofCode[39]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .mutBorrowLoc 11 := rfl

-- PC 39 (generic): `mutBorrowLoc 11` — reuses existing ref 4, pc 39→40.
set_option maxHeartbeats 800000 in
theorem registration_step_pc39_mutBorrowLoc11_generic (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal : MoveValue) (ms : MachineState) :
    step (registrationModuleEnv o)
        ({ registrationFramePc22AfterMoveLoc0 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 39 })
        [] [] ms =
      ExecResult.ok
        ({ registrationFramePc22AfterMoveLoc0 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 40 })
        [] [.mutRef 4] ms := by
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  let hlen : args.length = 7 := registrationVerifyArgs_len _ _ _ _ _ _ _
  let fr' := ({ registrationFramePc22AfterMoveLoc0 args hlen mv rCompressed sOpt sVal with pc := 39 })
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
      verifyRegistrationProofCode_size_val, verifyRegistrationProofCode_idx39]
  have hlocLt : 11 < fr'.locals.size :=
    registrationFramePc22_locals_idx11_lt args hlen mv rCompressed sOpt sVal
  have hlocVal := registrationFramePc22_locals_idx11_eq chainId sender contract token ekBa commitBa respBa
    mv rCompressed sOpt sVal
  have hlocRefLt : 11 < fr'.localRefs.size :=
    registrationFramePc22_localRefs_idx11_lt args hlen mv rCompressed sOpt sVal
  have hlocRefVal := registrationFramePc22_localRefs_idx11_eq args hlen mv rCompressed sOpt sVal
  simp only [step, dif_pos hpc, hc, dif_pos hlocLt, hlocVal, dif_pos hlocRefLt, hlocRefVal]
  rfl

@[simp] private theorem verifyRegistrationProofCode_idx42 :
    verifyRegistrationProofCode[42]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .call 6 := rfl

-- PC 42 (generic): `call 6` = `vector::append<u8>`; same pattern as PC 34/38, pc 42→43.
set_option maxHeartbeats 800000 in
theorem registration_step_pc42_call_append_generic (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal : MoveValue) (ms : MachineState)
    (existing appended : List MoveValue) (cs' : ContainerStore)
    (hread : ms.containers.read 4 = some (.vector .u8 existing))
    (hwrite : ms.containers.write 4 (.vector .u8 (existing ++ appended)) = some cs') :
    step (registrationModuleEnv o)
        ({ registrationFramePc22AfterMoveLoc0 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 42 })
        [] [.vector .u8 appended, .mutRef 4] ms =
      ExecResult.ok
        ({ registrationFramePc22AfterMoveLoc0 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 43 })
        [] [] { ms with containers := cs' } := by
  have hnative : vectorAppendU8Ref ms.containers [.mutRef 4, .vector .u8 appended] =
      some ([], cs') := by
    simp only [vectorAppendU8Ref]; rw [hread]; simp only; rw [hwrite]
  simp only [step, registrationModuleEnv, registrationFramePc22AfterMoveLoc0,
    registrationFramePc21AfterMutBorrowMsg, registrationFramePc20AfterStLoc11,
    registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
    registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
    registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
    registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame, registrationVerifyArgs,
    verifyRegistrationProofCode, verifyRegistrationProofCode_size_val, verifyRegistrationProofCode_idx42,
    registrationInitFrame_idx5_lt, registration_locals_after_set5_idx7_lt, registrationVerifyArgs_len,
    registration_env_funcIdx6_lt, registrationModuleEnv_functions_at6, FuncDesc.body, vectorAppendU8RefDesc,
    takeN_two_pair, List.map_cons, List.map_nil, Nat.reduceSub, List.reduceReplicate, List.cons_append,
    List.nil_append, List.size_toArray, List.length_cons, List.length_nil, zero_add, Nat.reduceAdd,
    Nat.reduceLT, Nat.one_lt_ofNat, ↓reduceDIte, List.getElem_toArray, List.getElem_cons_succ,
    List.getElem_cons_zero, Nat.ofNat_pos, Nat.reduceBEq, Bool.false_eq_true, BEq.rfl, List.set_toArray,
    List.set_cons_succ, List.set_cons_zero, beq_iff_eq]
  rw [hnative]
  simp only [handleNativeResult_ret0]

@[simp] private theorem verifyRegistrationProofCode_idx43 :
    verifyRegistrationProofCode[43]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .moveLoc 11 := rfl

/-- Frame after `moveLoc 11` (PC 43): local 11 and localRef 11 cleared, pc := 44.
The stack holds the current container value at ref 4 (the accumulated FS message). -/
def registrationFramePc44AfterMoveLoc11 (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) : Frame :=
  let fr := registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal
  { fr with
      pc := 44,
      locals := fr.locals.set 11 none (registrationFramePc22_locals_idx11_lt args h mv rCompressed sOpt sVal)
      localRefs := fr.localRefs.set 11 none (registrationFramePc22_localRefs_idx11_lt args h mv rCompressed sOpt sVal) }

-- PC 43 (generic): `moveLoc 11` consumes `msg`:
--   * `locals[11] = some _` (initial DST vector — ignored; the pushed value comes from `containers.read 4`)
--   * `localRefs[11] = some 4` (ref was allocated by PC 20 `mutBorrowLoc 11`)
-- Result: clears `locals[11]` and `localRefs[11]`, pushes the **current** container value at ref 4
-- (i.e. the accumulated message `DST ++ [chainId] ++ senderBytes ++ contractBytes ++ tokenBytes ++ ekBytes ++ rcBytes`),
-- pc 43→44.
set_option maxHeartbeats 800000 in
theorem registration_step_pc43_moveLoc11_generic (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal : MoveValue) (ms : MachineState)
    (msgVal : MoveValue)
    (hread : ms.containers.read 4 = some msgVal) :
    step (registrationModuleEnv o)
        ({ registrationFramePc22AfterMoveLoc0 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 43 })
        [] [] ms =
      ExecResult.ok
        (registrationFramePc44AfterMoveLoc11 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal)
        [] [msgVal] ms := by
  show step (registrationModuleEnv o)
      ({ registrationFramePc22AfterMoveLoc0 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 43 })
      [] [] ms =
    ExecResult.ok
      (let fr := registrationFramePc22AfterMoveLoc0 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
                   (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal
       { fr with
           pc := 44
           locals := fr.locals.set 11 none
             (registrationFramePc22_locals_idx11_lt _ _ mv rCompressed sOpt sVal)
           localRefs := fr.localRefs.set 11 none
             (registrationFramePc22_localRefs_idx11_lt _ _ mv rCompressed sOpt sVal) })
      [] [msgVal] ms
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  let hlen : args.length = 7 := registrationVerifyArgs_len _ _ _ _ _ _ _
  set fr' := ({ registrationFramePc22AfterMoveLoc0 args hlen mv rCompressed sOpt sVal with pc := 43 }) with hfr'
  have hpc : fr'.pc < fr'.code.size := by
    simp [fr', registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
      registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
      registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
      registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
      registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame,
      verifyRegistrationProofCode_size_val]
  have hc : fr'.code[fr'.pc]'hpc = MoveInstr.moveLoc 11 := by
    simp [fr', registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
      registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
      registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
      registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
      registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame,
      verifyRegistrationProofCode_size_val, verifyRegistrationProofCode_idx43]
  have hlocLt : 11 < fr'.locals.size :=
    registrationFramePc22_locals_idx11_lt args hlen mv rCompressed sOpt sVal
  have hlocVal : fr'.locals[11]'hlocLt = some fiatShamirRegistrationDstValue :=
    registrationFramePc22_locals_idx11_eq chainId sender contract token ekBa commitBa respBa
      mv rCompressed sOpt sVal
  have hlocRefLt : 11 < fr'.localRefs.size :=
    registrationFramePc22_localRefs_idx11_lt args hlen mv rCompressed sOpt sVal
  have hlocRefVal : fr'.localRefs[11]'hlocRefLt = some 4 :=
    registrationFramePc22_localRefs_idx11_eq args hlen mv rCompressed sOpt sVal
  simp only [step, dif_pos hpc, hc, dif_pos hlocLt, hlocVal, dif_pos hlocRefLt, hlocRefVal]
  rw [hread]

/-! ### PC 44 (`call 9` = `new_scalar_from_sha2_512`) and PC 45 (`stLoc 12`) -/

@[simp] private theorem verifyRegistrationProofCode_idx44 :
    verifyRegistrationProofCode[44]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .call 9 := rfl

private theorem registration_env_funcIdx9_lt (o : RegistrationNativeOracle) :
    9 < (registrationModuleEnv o).functions.size := by
  rw [registration_module_env_size o]; decide

private theorem registrationModuleEnv_functions_at9 (o : RegistrationNativeOracle)
    (h : 9 < (registrationModuleEnv o).functions.size) :
    (registrationModuleEnv o).functions[9]'h = newScalarFromSha2_512Desc := by
  simp [registrationModuleEnv]

-- PC 44 (generic): `call 9` = `new_scalar_from_sha2_512` (native, 1 param, 1 return).
-- Consumes `msgVal`, produces the scalar `e = Scalar.fromSha2_512(msg)`.
set_option maxHeartbeats 800000 in
theorem registration_step_pc44_call_newScalarFromSha2_512_generic (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal : MoveValue) (ms : MachineState)
    (msgVal eScalar : MoveValue)
    (hnative : newScalarFromSha2_512 [msgVal] = some [eScalar]) :
    step (registrationModuleEnv o)
        ({ registrationFramePc44AfterMoveLoc11 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 44 })
        [] [msgVal] ms =
      ExecResult.ok
        ({ registrationFramePc44AfterMoveLoc11 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 45 })
        [] [eScalar] ms := by
  simp only [step, registrationModuleEnv, registrationFramePc44AfterMoveLoc11,
    registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
    registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
    registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
    registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
    registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame, registrationVerifyArgs,
    verifyRegistrationProofCode, verifyRegistrationProofCode_size_val, verifyRegistrationProofCode_idx44,
    registrationInitFrame_idx5_lt, registration_locals_after_set5_idx7_lt, registrationVerifyArgs_len,
    registration_env_funcIdx9_lt, registrationModuleEnv_functions_at9, newScalarFromSha2_512Desc, FuncDesc.body,
    takeN_one_singleton, List.map_cons, List.map_nil, Nat.reduceSub, List.reduceReplicate,
    List.cons_append, List.nil_append, List.size_toArray, List.length_cons, List.length_nil, zero_add,
    Nat.reduceAdd, Nat.reduceLT, Nat.one_lt_ofNat, ↓reduceDIte, List.getElem_toArray, List.getElem_cons_succ,
    List.getElem_cons_zero, Nat.ofNat_pos, Nat.reduceBEq, Bool.false_eq_true, BEq.rfl, List.set_toArray,
    List.set_cons_succ, List.set_cons_zero, beq_iff_eq]
  rw [hnative]
  simp only [handleNativeResult_ret1]

@[simp] private theorem verifyRegistrationProofCode_idx45 :
    verifyRegistrationProofCode[45]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .stLoc 12 := rfl

private theorem registrationFramePc44_locals_size (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    (registrationFramePc44AfterMoveLoc11 args h mv rCompressed sOpt sVal).locals.size = 19 := by
  simp [registrationFramePc44AfterMoveLoc11, Array.size_set,
    registrationFramePc22_locals_size args h mv rCompressed sOpt sVal]

private theorem registrationFramePc44_locals_idx12_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    12 < (registrationFramePc44AfterMoveLoc11 args h mv rCompressed sOpt sVal).locals.size := by
  rw [registrationFramePc44_locals_size args h mv rCompressed sOpt sVal]; decide

/-- Frame after `stLoc 12` (PC 45): locals[12] = some eScalar, pc := 46. -/
def registrationFramePc46AfterStLoc12 (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar : MoveValue) : Frame :=
  let fr := registrationFramePc44AfterMoveLoc11 args h mv rCompressed sOpt sVal
  { fr with
      pc := 46
      locals := fr.locals.set 12 (some eScalar)
        (registrationFramePc44_locals_idx12_lt args h mv rCompressed sOpt sVal) }

-- PC 45 (generic): `stLoc 12` pops `eScalar`, stores in local 12, pc 45→46.
set_option maxHeartbeats 800000 in
theorem registration_step_pc45_stLoc12_generic (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal eScalar : MoveValue) (ms : MachineState) :
    step (registrationModuleEnv o)
        ({ registrationFramePc44AfterMoveLoc11 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 45 })
        [] [eScalar] ms =
      ExecResult.ok
        (registrationFramePc46AfterStLoc12 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal eScalar)
        [] [] ms := by
  simp [step, registrationModuleEnv, registrationFramePc46AfterStLoc12, registrationFramePc44AfterMoveLoc11,
    registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
    registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
    registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
    registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
    registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame, registrationVerifyArgs,
    verifyRegistrationProofCode, verifyRegistrationProofCode_size_val, verifyRegistrationProofCode_idx45,
    registrationInitFrame_idx5_lt, registration_locals_after_set5_idx7_lt,
    registration_locals_after_set5_set7_idx8_lt, registrationVerifyArgs_len]

/-! ### PC 46 (`call 10` = `hash_to_point_base`) and PC 47 (`stLoc 13`) -/

@[simp] private theorem verifyRegistrationProofCode_idx46 :
    verifyRegistrationProofCode[46]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .call 10 := rfl

private theorem registration_env_funcIdx10_lt (o : RegistrationNativeOracle) :
    10 < (registrationModuleEnv o).functions.size := by
  rw [registration_module_env_size o]; decide

private theorem registrationModuleEnv_functions_at10 (o : RegistrationNativeOracle)
    (h : 10 < (registrationModuleEnv o).functions.size) :
    (registrationModuleEnv o).functions[10]'h =
      { numParams := 0, numReturns := 1, body := .native o.hashToPointBase } := by
  simp [registrationModuleEnv]

set_option maxHeartbeats 800000 in
theorem registration_step_pc46_call_hashToPointBase_generic (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal eScalar : MoveValue) (ms : MachineState)
    (h : MoveValue)
    (horacle : o.hashToPointBase [] = some [h]) :
    step (registrationModuleEnv o)
        ({ registrationFramePc46AfterStLoc12 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal eScalar with
            pc := 46 })
        [] [] ms =
      ExecResult.ok
        ({ registrationFramePc46AfterStLoc12 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal eScalar with
            pc := 47 })
        [] [h] ms := by
  simp only [step, registrationModuleEnv, registrationFramePc46AfterStLoc12, registrationFramePc44AfterMoveLoc11,
    registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
    registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
    registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
    registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
    registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame, registrationVerifyArgs,
    verifyRegistrationProofCode, verifyRegistrationProofCode_size_val, verifyRegistrationProofCode_idx46,
    registrationInitFrame_idx5_lt, registration_locals_after_set5_idx7_lt, registrationVerifyArgs_len,
    registration_env_funcIdx10_lt, registrationModuleEnv_functions_at10, FuncDesc.body,
    takeN_nil_zero, List.map_cons, List.map_nil, Nat.reduceSub, List.reduceReplicate,
    List.cons_append, List.nil_append, List.size_toArray, List.length_cons, List.length_nil, zero_add,
    Nat.reduceAdd, Nat.reduceLT, Nat.one_lt_ofNat, ↓reduceDIte, List.getElem_toArray, List.getElem_cons_succ,
    List.getElem_cons_zero, Nat.ofNat_pos, Nat.reduceBEq, Bool.false_eq_true, BEq.rfl, List.set_toArray,
    List.set_cons_succ, List.set_cons_zero, beq_iff_eq]
  rw [horacle]
  simp only [handleNativeResult_ret1]

@[simp] private theorem verifyRegistrationProofCode_idx47 :
    verifyRegistrationProofCode[47]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .stLoc 13 := rfl

private theorem registrationFramePc46_locals_size (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar : MoveValue) :
    (registrationFramePc46AfterStLoc12 args h mv rCompressed sOpt sVal eScalar).locals.size = 19 := by
  simp [registrationFramePc46AfterStLoc12, Array.size_set,
    registrationFramePc44_locals_size args h mv rCompressed sOpt sVal]

private theorem registrationFramePc46_locals_idx13_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar : MoveValue) :
    13 < (registrationFramePc46AfterStLoc12 args h mv rCompressed sOpt sVal eScalar).locals.size := by
  rw [registrationFramePc46_locals_size args h mv rCompressed sOpt sVal eScalar]; decide

/-- Frame after `stLoc 13` (PC 47): locals[13] = some h, pc := 48. -/
def registrationFramePc48AfterStLoc13 (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint : MoveValue) : Frame :=
  let fr := registrationFramePc46AfterStLoc12 args h mv rCompressed sOpt sVal eScalar
  { fr with
      pc := 48
      locals := fr.locals.set 13 (some hPoint)
        (registrationFramePc46_locals_idx13_lt args h mv rCompressed sOpt sVal eScalar) }

set_option maxHeartbeats 800000 in
theorem registration_step_pc47_stLoc13_generic (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal eScalar hPoint : MoveValue) (ms : MachineState) :
    step (registrationModuleEnv o)
        ({ registrationFramePc46AfterStLoc12 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal eScalar with
            pc := 47 })
        [] [hPoint] ms =
      ExecResult.ok
        (registrationFramePc48AfterStLoc13 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal eScalar hPoint)
        [] [] ms := by
  simp [step, registrationModuleEnv, registrationFramePc48AfterStLoc13, registrationFramePc46AfterStLoc12,
    registrationFramePc44AfterMoveLoc11, registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
    registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
    registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
    registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
    registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame, registrationVerifyArgs,
    verifyRegistrationProofCode, verifyRegistrationProofCode_size_val, verifyRegistrationProofCode_idx47,
    registrationInitFrame_idx5_lt, registration_locals_after_set5_idx7_lt,
    registration_locals_after_set5_set7_idx8_lt, registrationVerifyArgs_len]

/-! ### PC 48 (`moveLoc 3` push ek), PC 49 (`call 11` = `pubkey_to_point`), PC 50 (`stLoc 14`) -/

@[simp] private theorem verifyRegistrationProofCode_idx48 :
    verifyRegistrationProofCode[48]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .moveLoc 3 := rfl

private theorem registrationFramePc48_locals_size (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint : MoveValue) :
    (registrationFramePc48AfterStLoc13 args h mv rCompressed sOpt sVal eScalar hPoint).locals.size = 19 := by
  simp [registrationFramePc48AfterStLoc13, Array.size_set,
    registrationFramePc46_locals_size args h mv rCompressed sOpt sVal eScalar]

private theorem registrationFramePc48_localRefs_size (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint : MoveValue) :
    (registrationFramePc48AfterStLoc13 args h mv rCompressed sOpt sVal eScalar hPoint).localRefs.size = 19 := by
  simp [registrationFramePc48AfterStLoc13, registrationFramePc46AfterStLoc12, registrationFramePc44AfterMoveLoc11,
    registrationFramePc22_localRefs_size args h mv rCompressed sOpt sVal]

private theorem registrationFramePc48_locals_idx3_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint : MoveValue) :
    3 < (registrationFramePc48AfterStLoc13 args h mv rCompressed sOpt sVal eScalar hPoint).locals.size := by
  rw [registrationFramePc48_locals_size args h mv rCompressed sOpt sVal eScalar hPoint]; decide

private theorem registrationFramePc48_localRefs_idx3_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint : MoveValue) :
    3 < (registrationFramePc48AfterStLoc13 args h mv rCompressed sOpt sVal eScalar hPoint).localRefs.size := by
  rw [registrationFramePc48_localRefs_size args h mv rCompressed sOpt sVal eScalar hPoint]; decide

set_option maxHeartbeats 800000 in
private theorem registrationFramePc48_locals_idx3_eq
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal eScalar hPoint : MoveValue) :
    (registrationFramePc48AfterStLoc13 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
      (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
      mv rCompressed sOpt sVal eScalar hPoint).locals[3]'
      (registrationFramePc48_locals_idx3_lt _ _ mv rCompressed sOpt sVal eScalar hPoint) =
        some (.struct_ [.vector .u8 (ekBa.toList.map .u8)]) := by
  have hpc22 := registrationFramePc22_locals_idx3_eq chainId sender contract token ekBa commitBa respBa
    mv rCompressed sOpt sVal
  have hne11 : (11 : Nat) ≠ 3 := by decide
  have hne12 : (12 : Nat) ≠ 3 := by decide
  have hne13 : (13 : Nat) ≠ 3 := by decide
  simp only [registrationFramePc48AfterStLoc13, registrationFramePc46AfterStLoc12, registrationFramePc44AfterMoveLoc11,
    Array.getElem_set_ne (h := hne11),
    Array.getElem_set_ne (h := hne12),
    Array.getElem_set_ne (h := hne13)]
  exact hpc22

set_option maxHeartbeats 800000 in
private theorem registrationFramePc48_localRefs_idx3_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint : MoveValue) :
    (registrationFramePc48AfterStLoc13 args h mv rCompressed sOpt sVal eScalar hPoint).localRefs[3]'
      (registrationFramePc48_localRefs_idx3_lt args h mv rCompressed sOpt sVal eScalar hPoint) = none := by
  have hpc22 := registrationFramePc22_localRefs_idx3_eq args h mv rCompressed sOpt sVal
  have hne11 : (11 : Nat) ≠ 3 := by decide
  simp only [registrationFramePc48AfterStLoc13, registrationFramePc46AfterStLoc12, registrationFramePc44AfterMoveLoc11,
    Array.getElem_set_ne (h := hne11)]
  exact hpc22

/-- Frame after `moveLoc 3` (PC 48): locals[3] := none, pc := 49. LocalRefs[3] stays none. -/
def registrationFramePc49AfterMoveLoc3 (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint : MoveValue) : Frame :=
  let fr := registrationFramePc48AfterStLoc13 args h mv rCompressed sOpt sVal eScalar hPoint
  { fr with
      pc := 49
      locals := fr.locals.set 3 none
        (registrationFramePc48_locals_idx3_lt args h mv rCompressed sOpt sVal eScalar hPoint) }

set_option maxHeartbeats 800000 in
theorem registration_step_pc48_moveLoc3_generic (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal eScalar hPoint : MoveValue) (ms : MachineState) :
    step (registrationModuleEnv o)
        ({ registrationFramePc48AfterStLoc13 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal eScalar hPoint with
            pc := 48 })
        [] [] ms =
      ExecResult.ok
        (registrationFramePc49AfterMoveLoc3 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
          mv rCompressed sOpt sVal eScalar hPoint)
        [] [.struct_ [.vector .u8 (ekBa.toList.map .u8)]] ms := by
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  let hlen : args.length = 7 := registrationVerifyArgs_len _ _ _ _ _ _ _
  set fr' := ({ registrationFramePc48AfterStLoc13 args hlen mv rCompressed sOpt sVal eScalar hPoint with pc := 48 }) with hfr'
  have hpc : fr'.pc < fr'.code.size := by
    simp [fr', registrationFramePc48AfterStLoc13, registrationFramePc46AfterStLoc12, registrationFramePc44AfterMoveLoc11,
      registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
      registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
      registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
      registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
      registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame,
      verifyRegistrationProofCode_size_val]
  have hc : fr'.code[fr'.pc]'hpc = MoveInstr.moveLoc 3 := by
    simp [fr', registrationFramePc48AfterStLoc13, registrationFramePc46AfterStLoc12, registrationFramePc44AfterMoveLoc11,
      registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
      registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
      registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
      registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
      registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame,
      verifyRegistrationProofCode_size_val, verifyRegistrationProofCode_idx48]
  have hlocLt : 3 < fr'.locals.size :=
    registrationFramePc48_locals_idx3_lt args hlen mv rCompressed sOpt sVal eScalar hPoint
  have hlocVal : fr'.locals[3]'hlocLt = some (.struct_ [.vector .u8 (ekBa.toList.map .u8)]) :=
    registrationFramePc48_locals_idx3_eq chainId sender contract token ekBa commitBa respBa
      mv rCompressed sOpt sVal eScalar hPoint
  have hlocRefLt : 3 < fr'.localRefs.size :=
    registrationFramePc48_localRefs_idx3_lt args hlen mv rCompressed sOpt sVal eScalar hPoint
  have hlocRefVal : fr'.localRefs[3]'hlocRefLt = none :=
    registrationFramePc48_localRefs_idx3_eq args hlen mv rCompressed sOpt sVal eScalar hPoint
  simp only [step, dif_pos hpc, hc, dif_pos hlocLt, hlocVal, dif_pos hlocRefLt, hlocRefVal]
  rfl

@[simp] private theorem verifyRegistrationProofCode_idx49 :
    verifyRegistrationProofCode[49]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .call 11 := rfl

private theorem registration_env_funcIdx11_lt (o : RegistrationNativeOracle) :
    11 < (registrationModuleEnv o).functions.size := by
  rw [registration_module_env_size o]; decide

private theorem registrationModuleEnv_functions_at11 (o : RegistrationNativeOracle)
    (h : 11 < (registrationModuleEnv o).functions.size) :
    (registrationModuleEnv o).functions[11]'h =
      { numParams := 1, numReturns := 1, body := .nativeRef (wrapOracleImmRef1 o.pubkeyToPoint) } := by
  simp [registrationModuleEnv]

set_option maxHeartbeats 800000 in
theorem registration_step_pc49_call_pubkeyToPoint_generic (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal eScalar hPoint : MoveValue) (ms : MachineState)
    (ekPt : MoveValue)
    (horacle : o.pubkeyToPoint [.struct_ [.vector .u8 (ekBa.toList.map .u8)]] = some [ekPt]) :
    step (registrationModuleEnv o)
        ({ registrationFramePc49AfterMoveLoc3 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal eScalar hPoint with
            pc := 49 })
        [] [.struct_ [.vector .u8 (ekBa.toList.map .u8)]] ms =
      ExecResult.ok
        ({ registrationFramePc49AfterMoveLoc3 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal eScalar hPoint with
            pc := 50 })
        [] [ekPt] ms := by
  have hnative : wrapOracleImmRef1 o.pubkeyToPoint ms.containers
        [.struct_ [.vector .u8 (ekBa.toList.map .u8)]] =
      some ([ekPt], ms.containers) := by
    show (Option.bind (derefImm ms.containers
            (.struct_ [.vector .u8 (ekBa.toList.map .u8)]))
          (fun v => Option.bind (o.pubkeyToPoint [v])
              (fun results => some (results, ms.containers)))) =
        some ([ekPt], ms.containers)
    simp only [derefImm, Option.bind_some]
    rw [horacle]
    rfl
  simp only [step, registrationModuleEnv, registrationFramePc49AfterMoveLoc3,
    registrationFramePc48AfterStLoc13, registrationFramePc46AfterStLoc12, registrationFramePc44AfterMoveLoc11,
    registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
    registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
    registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
    registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
    registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame, registrationVerifyArgs,
    verifyRegistrationProofCode, verifyRegistrationProofCode_size_val, verifyRegistrationProofCode_idx49,
    registrationInitFrame_idx5_lt, registration_locals_after_set5_idx7_lt, registrationVerifyArgs_len,
    registration_env_funcIdx11_lt, registrationModuleEnv_functions_at11, FuncDesc.body,
    takeN_one_singleton, List.map_cons, List.map_nil, Nat.reduceSub, List.reduceReplicate,
    List.cons_append, List.nil_append, List.size_toArray, List.length_cons, List.length_nil, zero_add,
    Nat.reduceAdd, Nat.reduceLT, Nat.one_lt_ofNat, ↓reduceDIte, List.getElem_toArray, List.getElem_cons_succ,
    List.getElem_cons_zero, Nat.ofNat_pos, Nat.reduceBEq, Bool.false_eq_true, BEq.rfl, List.set_toArray,
    List.set_cons_succ, List.set_cons_zero, beq_iff_eq]
  rw [hnative]
  simp only [handleNativeResult_ret1]

@[simp] private theorem verifyRegistrationProofCode_idx50 :
    verifyRegistrationProofCode[50]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .stLoc 14 := rfl

private theorem registrationFramePc49_locals_size (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint : MoveValue) :
    (registrationFramePc49AfterMoveLoc3 args h mv rCompressed sOpt sVal eScalar hPoint).locals.size = 19 := by
  simp [registrationFramePc49AfterMoveLoc3, Array.size_set,
    registrationFramePc48_locals_size args h mv rCompressed sOpt sVal eScalar hPoint]

private theorem registrationFramePc49_locals_idx14_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint : MoveValue) :
    14 < (registrationFramePc49AfterMoveLoc3 args h mv rCompressed sOpt sVal eScalar hPoint).locals.size := by
  rw [registrationFramePc49_locals_size args h mv rCompressed sOpt sVal eScalar hPoint]; decide

/-- Frame after `stLoc 14` (PC 50): locals[14] = some ekPt, pc := 51. -/
def registrationFramePc51AfterStLoc14 (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt : MoveValue) : Frame :=
  let fr := registrationFramePc49AfterMoveLoc3 args h mv rCompressed sOpt sVal eScalar hPoint
  { fr with
      pc := 51
      locals := fr.locals.set 14 (some ekPt)
        (registrationFramePc49_locals_idx14_lt args h mv rCompressed sOpt sVal eScalar hPoint) }

set_option maxHeartbeats 800000 in
theorem registration_step_pc50_stLoc14_generic (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt : MoveValue) (ms : MachineState) :
    step (registrationModuleEnv o)
        ({ registrationFramePc49AfterMoveLoc3 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
              mv rCompressed sOpt sVal eScalar hPoint with
            pc := 50 })
        [] [ekPt] ms =
      ExecResult.ok
        (registrationFramePc51AfterStLoc14 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
          mv rCompressed sOpt sVal eScalar hPoint ekPt)
        [] [] ms := by
  simp [step, registrationModuleEnv, registrationFramePc51AfterStLoc14, registrationFramePc49AfterMoveLoc3,
    registrationFramePc48AfterStLoc13, registrationFramePc46AfterStLoc12, registrationFramePc44AfterMoveLoc11,
    registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
    registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
    registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
    registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
    registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame, registrationVerifyArgs,
    verifyRegistrationProofCode, verifyRegistrationProofCode_size_val, verifyRegistrationProofCode_idx50,
    registrationInitFrame_idx5_lt, registration_locals_after_set5_idx7_lt,
    registration_locals_after_set5_set7_idx8_lt, registrationVerifyArgs_len]

/-! ### PC 51 (`immBorrowLoc 13` — alloc h at new ref, push immRef) -/

@[simp] private theorem verifyRegistrationProofCode_idx51 :
    verifyRegistrationProofCode[51]'(by rw [verifyRegistrationProofCode_size_val]; decide) =
      .immBorrowLoc 13 := rfl

private theorem registrationFramePc51_locals_size (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt : MoveValue) :
    (registrationFramePc51AfterStLoc14 args h mv rCompressed sOpt sVal eScalar hPoint ekPt).locals.size = 19 := by
  simp [registrationFramePc51AfterStLoc14, Array.size_set,
    registrationFramePc49AfterMoveLoc3, registrationFramePc48_locals_size args h mv rCompressed sOpt sVal eScalar hPoint]

private theorem registrationFramePc51_localRefs_size (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt : MoveValue) :
    (registrationFramePc51AfterStLoc14 args h mv rCompressed sOpt sVal eScalar hPoint ekPt).localRefs.size = 19 := by
  simp [registrationFramePc51AfterStLoc14, registrationFramePc49AfterMoveLoc3,
    registrationFramePc48_localRefs_size args h mv rCompressed sOpt sVal eScalar hPoint]

private theorem registrationFramePc51_locals_idx13_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt : MoveValue) :
    13 < (registrationFramePc51AfterStLoc14 args h mv rCompressed sOpt sVal eScalar hPoint ekPt).locals.size := by
  rw [registrationFramePc51_locals_size args h mv rCompressed sOpt sVal eScalar hPoint ekPt]; decide

private theorem registrationFramePc51_localRefs_idx13_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt : MoveValue) :
    13 < (registrationFramePc51AfterStLoc14 args h mv rCompressed sOpt sVal eScalar hPoint ekPt).localRefs.size := by
  rw [registrationFramePc51_localRefs_size args h mv rCompressed sOpt sVal eScalar hPoint ekPt]; decide

private theorem registrationFramePc22_localRefs_idx13_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    13 < (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).localRefs.size := by
  rw [registrationFramePc22_localRefs_size args h mv rCompressed sOpt sVal]; decide

private theorem registrationFramePc22_localRefs_idx13_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).localRefs[13]'
      (registrationFramePc22_localRefs_idx13_lt args h mv rCompressed sOpt sVal) = none := by
  simp [registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg, registrationFramePc20AfterStLoc11,
    registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9, registrationFramePc12AfterStLoc9,
    registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6, registrationFramePc9AfterStLoc8,
    registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow, registrationFramePc3AfterStLoc,
    registrationFrameAtPc2, registrationInitFrame]

set_option maxHeartbeats 1600000 in
private theorem registrationFramePc51_locals_idx13_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt : MoveValue) :
    (registrationFramePc51AfterStLoc14 args h mv rCompressed sOpt sVal eScalar hPoint ekPt).locals[13]'
      (registrationFramePc51_locals_idx13_lt args h mv rCompressed sOpt sVal eScalar hPoint ekPt) =
        some hPoint := by
  have hne14 : (14 : Nat) ≠ 13 := by decide
  have hne3 : (3 : Nat) ≠ 13 := by decide
  have hsz46 := registrationFramePc46_locals_size args h mv rCompressed sOpt sVal eScalar
  unfold registrationFramePc51AfterStLoc14 registrationFramePc49AfterMoveLoc3 registrationFramePc48AfterStLoc13
  rw [Array.getElem_set_ne (h := hne14)
    (pj := by simp [Array.size_set, hsz46])
    (h' := by simp [Array.size_set, hsz46])]
  rw [Array.getElem_set_ne (h := hne3)
    (pj := by simp [Array.size_set, hsz46])
    (h' := by simp [Array.size_set, hsz46])]
  rw [Array.getElem_set_self]

set_option maxHeartbeats 3200000 in
private theorem registrationFramePc51_localRefs_idx13_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt : MoveValue) :
    (registrationFramePc51AfterStLoc14 args h mv rCompressed sOpt sVal eScalar hPoint ekPt).localRefs[13]'
      (registrationFramePc51_localRefs_idx13_lt args h mv rCompressed sOpt sVal eScalar hPoint ekPt) = none := by
  have hne11 : (11 : Nat) ≠ 13 := by decide
  have hpc22 := registrationFramePc22_localRefs_idx13_eq args h mv rCompressed sOpt sVal
  have hsz22 := registrationFramePc22_localRefs_size args h mv rCompressed sOpt sVal
  unfold registrationFramePc51AfterStLoc14 registrationFramePc49AfterMoveLoc3
    registrationFramePc48AfterStLoc13 registrationFramePc46AfterStLoc12 registrationFramePc44AfterMoveLoc11
  rw [Array.getElem_set_ne (h := hne11)
    (pj := by rw [hsz22]; decide)
    (h' := by rw [hsz22]; decide)]
  exact hpc22

/-- Frame after `immBorrowLoc 13` (PC 51): pc := 52, localRefs unchanged (none case allocates
fresh ref but doesn't record it). -/
def registrationFramePc52AfterImmBorrow13 (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt : MoveValue) : Frame :=
  { registrationFramePc51AfterStLoc14 args h mv rCompressed sOpt sVal eScalar hPoint ekPt with pc := 52 }

set_option maxHeartbeats 3200000 in
theorem registration_step_pc51_immBorrowLoc13_generic (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt : MoveValue) (ms : MachineState)
    (rest : List MoveValue) :
    step (registrationModuleEnv o)
        ({ registrationFramePc51AfterStLoc14 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
              mv rCompressed sOpt sVal eScalar hPoint ekPt with
            pc := 51 })
        [] rest ms =
      ExecResult.ok
        (registrationFramePc52AfterImmBorrow13 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
          mv rCompressed sOpt sVal eScalar hPoint ekPt)
        [] (.immRef (ms.containers.alloc hPoint).2 :: rest)
        { ms with containers := (ms.containers.alloc hPoint).1 } := by
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  let hlen : args.length = 7 := registrationVerifyArgs_len _ _ _ _ _ _ _
  set fr' := ({ registrationFramePc51AfterStLoc14 args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt with
                pc := 51 }) with hfr'
  have hpc : fr'.pc < fr'.code.size := by
    simp [fr', registrationFramePc51AfterStLoc14, registrationFramePc49AfterMoveLoc3,
      registrationFramePc48AfterStLoc13, registrationFramePc46AfterStLoc12, registrationFramePc44AfterMoveLoc11,
      registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
      registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
      registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
      registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
      registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame,
      verifyRegistrationProofCode_size_val]
  have hc : fr'.code[fr'.pc]'hpc = MoveInstr.immBorrowLoc 13 := by
    simp [fr', registrationFramePc51AfterStLoc14, registrationFramePc49AfterMoveLoc3,
      registrationFramePc48AfterStLoc13, registrationFramePc46AfterStLoc12, registrationFramePc44AfterMoveLoc11,
      registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
      registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
      registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
      registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
      registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame,
      verifyRegistrationProofCode_size_val, verifyRegistrationProofCode_idx51]
  have hlocLt : 13 < fr'.locals.size :=
    registrationFramePc51_locals_idx13_lt args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt
  have hlocVal : fr'.locals[13]'hlocLt = some hPoint :=
    registrationFramePc51_locals_idx13_eq args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt
  have hlocRefLt : 13 < fr'.localRefs.size :=
    registrationFramePc51_localRefs_idx13_lt args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt
  have hlocRefVal : fr'.localRefs[13]'hlocRefLt = none :=
    registrationFramePc51_localRefs_idx13_eq args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt
  simp only [step, dif_pos hpc, hc, dif_pos hlocLt, hlocVal, dif_pos hlocRefLt, hlocRefVal]
  rfl

/-! ### PC 52 (`immBorrowLoc 10` — alloc s at new ref, push immRef over existing immRef) -/

@[simp] private theorem verifyRegistrationProofCode_idx52 :
    verifyRegistrationProofCode[52]'(by rw [verifyRegistrationProofCode_size_val]; decide) =
      .immBorrowLoc 10 := rfl

-- Pc22.locals[10] = some sVal (stLoc 10 at PC 17 sets it; no subsequent change).
private theorem registrationFramePc22_locals_idx10_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    10 < (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).locals.size := by
  rw [registrationFramePc22_locals_size args h mv rCompressed sOpt sVal]; decide

private theorem registrationFramePc22_localRefs_idx10_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    10 < (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).localRefs.size := by
  rw [registrationFramePc22_localRefs_size args h mv rCompressed sOpt sVal]; decide

private theorem registrationFramePc22_locals_idx10_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).locals[10]'
      (registrationFramePc22_locals_idx10_lt args h mv rCompressed sOpt sVal) = some sVal := by
  simp [registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg, registrationFramePc20AfterStLoc11,
    registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9, registrationFramePc12AfterStLoc9,
    registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6, registrationFramePc9AfterStLoc8,
    registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow, registrationFramePc3AfterStLoc,
    registrationFrameAtPc2, registrationInitFrame]

private theorem registrationFramePc22_localRefs_idx10_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).localRefs[10]'
      (registrationFramePc22_localRefs_idx10_lt args h mv rCompressed sOpt sVal) = none := by
  simp [registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg, registrationFramePc20AfterStLoc11,
    registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9, registrationFramePc12AfterStLoc9,
    registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6, registrationFramePc9AfterStLoc8,
    registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow, registrationFramePc3AfterStLoc,
    registrationFrameAtPc2, registrationInitFrame]

-- Pc52AfterImmBorrow13 frame has same locals/localRefs as Pc51AfterStLoc14 (just pc := 52).
-- So we build idx10 eq/lt helpers for Pc52.

private theorem registrationFramePc52_locals_size (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt : MoveValue) :
    (registrationFramePc52AfterImmBorrow13 args h mv rCompressed sOpt sVal eScalar hPoint ekPt).locals.size = 19 :=
  registrationFramePc51_locals_size args h mv rCompressed sOpt sVal eScalar hPoint ekPt

private theorem registrationFramePc52_localRefs_size (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt : MoveValue) :
    (registrationFramePc52AfterImmBorrow13 args h mv rCompressed sOpt sVal eScalar hPoint ekPt).localRefs.size = 19 :=
  registrationFramePc51_localRefs_size args h mv rCompressed sOpt sVal eScalar hPoint ekPt

private theorem registrationFramePc52_locals_idx10_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt : MoveValue) :
    10 < (registrationFramePc52AfterImmBorrow13 args h mv rCompressed sOpt sVal eScalar hPoint ekPt).locals.size := by
  rw [registrationFramePc52_locals_size]; decide

private theorem registrationFramePc52_localRefs_idx10_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt : MoveValue) :
    10 < (registrationFramePc52AfterImmBorrow13 args h mv rCompressed sOpt sVal eScalar hPoint ekPt).localRefs.size := by
  rw [registrationFramePc52_localRefs_size]; decide

set_option maxHeartbeats 3200000 in
private theorem registrationFramePc52_locals_idx10_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt : MoveValue) :
    (registrationFramePc52AfterImmBorrow13 args h mv rCompressed sOpt sVal eScalar hPoint ekPt).locals[10]'
      (registrationFramePc52_locals_idx10_lt args h mv rCompressed sOpt sVal eScalar hPoint ekPt) =
        some sVal := by
  have hne14 : (14 : Nat) ≠ 10 := by decide
  have hne3 : (3 : Nat) ≠ 10 := by decide
  have hne13 : (13 : Nat) ≠ 10 := by decide
  have hne12 : (12 : Nat) ≠ 10 := by decide
  have hne11 : (11 : Nat) ≠ 10 := by decide
  have hsz22 := registrationFramePc22_locals_size args h mv rCompressed sOpt sVal
  have hpc22 := registrationFramePc22_locals_idx10_eq args h mv rCompressed sOpt sVal
  unfold registrationFramePc52AfterImmBorrow13 registrationFramePc51AfterStLoc14 registrationFramePc49AfterMoveLoc3
    registrationFramePc48AfterStLoc13 registrationFramePc46AfterStLoc12 registrationFramePc44AfterMoveLoc11
  rw [Array.getElem_set_ne (h := hne14)
    (pj := by simp [Array.size_set, hsz22])
    (h' := by simp [Array.size_set, hsz22])]
  rw [Array.getElem_set_ne (h := hne3)
    (pj := by simp [Array.size_set, hsz22])
    (h' := by simp [Array.size_set, hsz22])]
  rw [Array.getElem_set_ne (h := hne13)
    (pj := by simp [Array.size_set, hsz22])
    (h' := by simp [Array.size_set, hsz22])]
  rw [Array.getElem_set_ne (h := hne12)
    (pj := by simp [Array.size_set, hsz22])
    (h' := by simp [Array.size_set, hsz22])]
  rw [Array.getElem_set_ne (h := hne11)
    (pj := by rw [hsz22]; decide)
    (h' := by rw [hsz22]; decide)]
  exact hpc22

set_option maxHeartbeats 3200000 in
private theorem registrationFramePc52_localRefs_idx10_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt : MoveValue) :
    (registrationFramePc52AfterImmBorrow13 args h mv rCompressed sOpt sVal eScalar hPoint ekPt).localRefs[10]'
      (registrationFramePc52_localRefs_idx10_lt args h mv rCompressed sOpt sVal eScalar hPoint ekPt) = none := by
  have hne11 : (11 : Nat) ≠ 10 := by decide
  have hpc22 := registrationFramePc22_localRefs_idx10_eq args h mv rCompressed sOpt sVal
  have hszR22 := registrationFramePc22_localRefs_size args h mv rCompressed sOpt sVal
  unfold registrationFramePc52AfterImmBorrow13 registrationFramePc51AfterStLoc14 registrationFramePc49AfterMoveLoc3
    registrationFramePc48AfterStLoc13 registrationFramePc46AfterStLoc12 registrationFramePc44AfterMoveLoc11
  rw [Array.getElem_set_ne (h := hne11)
    (pj := by rw [hszR22]; decide)
    (h' := by rw [hszR22]; decide)]
  exact hpc22

/-- Frame after `immBorrowLoc 10` (PC 52): pc := 53, same locals/localRefs. -/
def registrationFramePc53AfterImmBorrow10 (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt : MoveValue) : Frame :=
  { registrationFramePc52AfterImmBorrow13 args h mv rCompressed sOpt sVal eScalar hPoint ekPt with pc := 53 }

set_option maxHeartbeats 3200000 in
theorem registration_step_pc52_immBorrowLoc10_generic (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt : MoveValue) (ms : MachineState)
    (rest : List MoveValue) :
    step (registrationModuleEnv o)
        ({ registrationFramePc52AfterImmBorrow13 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
              mv rCompressed sOpt sVal eScalar hPoint ekPt with
            pc := 52 })
        [] rest ms =
      ExecResult.ok
        (registrationFramePc53AfterImmBorrow10 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
          mv rCompressed sOpt sVal eScalar hPoint ekPt)
        [] (.immRef (ms.containers.alloc sVal).2 :: rest)
        { ms with containers := (ms.containers.alloc sVal).1 } := by
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  let hlen : args.length = 7 := registrationVerifyArgs_len _ _ _ _ _ _ _
  set fr' := ({ registrationFramePc52AfterImmBorrow13 args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt with
                pc := 52 }) with hfr'
  have hpc : fr'.pc < fr'.code.size := by
    simp [fr', registrationFramePc52AfterImmBorrow13, registrationFramePc51AfterStLoc14, registrationFramePc49AfterMoveLoc3,
      registrationFramePc48AfterStLoc13, registrationFramePc46AfterStLoc12, registrationFramePc44AfterMoveLoc11,
      registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
      registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
      registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
      registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
      registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame,
      verifyRegistrationProofCode_size_val]
  have hc : fr'.code[fr'.pc]'hpc = MoveInstr.immBorrowLoc 10 := by
    simp [fr', registrationFramePc52AfterImmBorrow13, registrationFramePc51AfterStLoc14, registrationFramePc49AfterMoveLoc3,
      registrationFramePc48AfterStLoc13, registrationFramePc46AfterStLoc12, registrationFramePc44AfterMoveLoc11,
      registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
      registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
      registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
      registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
      registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame,
      verifyRegistrationProofCode_size_val, verifyRegistrationProofCode_idx52]
  have hlocLt : 10 < fr'.locals.size :=
    registrationFramePc52_locals_idx10_lt args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt
  have hlocVal : fr'.locals[10]'hlocLt = some sVal :=
    registrationFramePc52_locals_idx10_eq args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt
  have hlocRefLt : 10 < fr'.localRefs.size :=
    registrationFramePc52_localRefs_idx10_lt args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt
  have hlocRefVal : fr'.localRefs[10]'hlocRefLt = none :=
    registrationFramePc52_localRefs_idx10_eq args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt
  simp only [step, dif_pos hpc, hc, dif_pos hlocLt, hlocVal, dif_pos hlocRefLt, hlocRefVal]
  rfl

/-! ### PC 53 (`call 12` = `point_mul` via `wrapOracleImmRef2`) -/

@[simp] private theorem verifyRegistrationProofCode_idx53 :
    verifyRegistrationProofCode[53]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .call 12 := rfl

private theorem registration_env_funcIdx12_lt (o : RegistrationNativeOracle) :
    12 < (registrationModuleEnv o).functions.size := by
  rw [registration_module_env_size o]; decide

private theorem registrationModuleEnv_functions_at12 (o : RegistrationNativeOracle)
    (h : 12 < (registrationModuleEnv o).functions.size) :
    (registrationModuleEnv o).functions[12]'h =
      { numParams := 2, numReturns := 1, body := .nativeRef (wrapOracleImmRef2 o.pointMul) } := by
  simp [registrationModuleEnv]

set_option maxHeartbeats 3200000 in
theorem registration_step_pc53_call_pointMul_generic (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt : MoveValue) (ms : MachineState)
    (ridH ridS : RefId) (hVal sValForMul hsPt : MoveValue)
    (hreadH : ms.containers.read ridH = some hVal)
    (hreadS : ms.containers.read ridS = some sValForMul)
    (horacle : o.pointMul [hVal, sValForMul] = some [hsPt]) :
    step (registrationModuleEnv o)
        (registrationFramePc53AfterImmBorrow10 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
          mv rCompressed sOpt sVal eScalar hPoint ekPt)
        [] [.immRef ridS, .immRef ridH] ms =
      ExecResult.ok
        ({ registrationFramePc53AfterImmBorrow10 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
              mv rCompressed sOpt sVal eScalar hPoint ekPt with
            pc := 54 })
        [] [hsPt] ms := by
  have hnative : wrapOracleImmRef2 o.pointMul ms.containers
        [.immRef ridH, .immRef ridS] =
      some ([hsPt], ms.containers) := by
    show (Option.bind (derefImm ms.containers (.immRef ridH))
          (fun v1 => Option.bind (derefImm ms.containers (.immRef ridS))
            (fun v2 => Option.bind (o.pointMul [v1, v2])
              (fun results => some (results, ms.containers))))) =
        some ([hsPt], ms.containers)
    simp only [derefImm]
    rw [hreadH]
    simp only [Option.bind_some]
    rw [hreadS]
    simp only [Option.bind_some]
    rw [horacle]
    rfl
  simp only [step, registrationModuleEnv, registrationFramePc53AfterImmBorrow10,
    registrationFramePc52AfterImmBorrow13, registrationFramePc51AfterStLoc14, registrationFramePc49AfterMoveLoc3,
    registrationFramePc48AfterStLoc13, registrationFramePc46AfterStLoc12, registrationFramePc44AfterMoveLoc11,
    registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
    registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
    registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
    registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
    registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame, registrationVerifyArgs,
    verifyRegistrationProofCode, verifyRegistrationProofCode_size_val, verifyRegistrationProofCode_idx53,
    registrationInitFrame_idx5_lt, registration_locals_after_set5_idx7_lt, registrationVerifyArgs_len,
    registration_env_funcIdx12_lt, registrationModuleEnv_functions_at12, FuncDesc.body,
    takeN_two_pair, List.map_cons, List.map_nil, Nat.reduceSub, List.reduceReplicate,
    List.cons_append, List.nil_append, List.size_toArray, List.length_cons, List.length_nil, zero_add,
    Nat.reduceAdd, Nat.reduceLT, Nat.one_lt_ofNat, ↓reduceDIte, List.getElem_toArray, List.getElem_cons_succ,
    List.getElem_cons_zero, Nat.ofNat_pos, Nat.reduceBEq, Bool.false_eq_true, BEq.rfl, List.set_toArray,
    List.set_cons_succ, List.set_cons_zero, beq_iff_eq]
  rw [hnative]
  simp only [handleNativeResult_ret1]

/-! ### PC 54 (`stLoc 15` — store hs into local 15) -/

@[simp] private theorem verifyRegistrationProofCode_idx54 :
    verifyRegistrationProofCode[54]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .stLoc 15 := rfl

private theorem registrationFramePc53_locals_size (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt : MoveValue) :
    (registrationFramePc53AfterImmBorrow10 args h mv rCompressed sOpt sVal eScalar hPoint ekPt).locals.size = 19 :=
  registrationFramePc51_locals_size args h mv rCompressed sOpt sVal eScalar hPoint ekPt

private theorem registrationFramePc53_locals_idx15_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt : MoveValue) :
    15 < (registrationFramePc53AfterImmBorrow10 args h mv rCompressed sOpt sVal eScalar hPoint ekPt).locals.size := by
  rw [registrationFramePc53_locals_size]; decide

/-- Frame after `stLoc 15` (PC 54): locals[15] = some hs, pc := 55. -/
def registrationFramePc55AfterStLoc15 (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt : MoveValue) : Frame :=
  let fr := registrationFramePc53AfterImmBorrow10 args h mv rCompressed sOpt sVal eScalar hPoint ekPt
  { fr with
      pc := 55
      locals := fr.locals.set 15 (some hsPt)
        (registrationFramePc53_locals_idx15_lt args h mv rCompressed sOpt sVal eScalar hPoint ekPt) }

set_option maxHeartbeats 3200000 in
theorem registration_step_pc54_stLoc15_generic (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt : MoveValue) (ms : MachineState)
    (rest : List MoveValue) :
    step (registrationModuleEnv o)
        ({ registrationFramePc53AfterImmBorrow10 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
              mv rCompressed sOpt sVal eScalar hPoint ekPt with
            pc := 54 })
        [] (hsPt :: rest) ms =
      ExecResult.ok
        (registrationFramePc55AfterStLoc15 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
          mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt)
        [] rest ms := by
  simp [step, registrationModuleEnv, registrationFramePc55AfterStLoc15, registrationFramePc53AfterImmBorrow10,
    registrationFramePc52AfterImmBorrow13, registrationFramePc51AfterStLoc14, registrationFramePc49AfterMoveLoc3,
    registrationFramePc48AfterStLoc13, registrationFramePc46AfterStLoc12, registrationFramePc44AfterMoveLoc11,
    registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
    registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
    registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
    registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
    registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame, registrationVerifyArgs,
    verifyRegistrationProofCode, verifyRegistrationProofCode_size_val, verifyRegistrationProofCode_idx54,
    registrationInitFrame_idx5_lt, registration_locals_after_set5_idx7_lt,
    registration_locals_after_set5_set7_idx8_lt, registrationVerifyArgs_len]

/-! ### PC 22 base helpers for indices 12, 14, 15, 16, 17, 18 (all `none` at Pc22) -/

private theorem registrationFramePc22_locals_idx12_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    12 < (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).locals.size := by
  rw [registrationFramePc22_locals_size args h mv rCompressed sOpt sVal]; decide

private theorem registrationFramePc22_localRefs_idx12_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    12 < (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).localRefs.size := by
  rw [registrationFramePc22_localRefs_size args h mv rCompressed sOpt sVal]; decide

private theorem registrationFramePc22_localRefs_idx12_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).localRefs[12]'
      (registrationFramePc22_localRefs_idx12_lt args h mv rCompressed sOpt sVal) = none := by
  simp [registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg, registrationFramePc20AfterStLoc11,
    registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9, registrationFramePc12AfterStLoc9,
    registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6, registrationFramePc9AfterStLoc8,
    registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow, registrationFramePc3AfterStLoc,
    registrationFrameAtPc2, registrationInitFrame]

private theorem registrationFramePc22_locals_idx14_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    14 < (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).locals.size := by
  rw [registrationFramePc22_locals_size args h mv rCompressed sOpt sVal]; decide

private theorem registrationFramePc22_localRefs_idx14_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    14 < (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).localRefs.size := by
  rw [registrationFramePc22_localRefs_size args h mv rCompressed sOpt sVal]; decide

private theorem registrationFramePc22_localRefs_idx14_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).localRefs[14]'
      (registrationFramePc22_localRefs_idx14_lt args h mv rCompressed sOpt sVal) = none := by
  simp [registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg, registrationFramePc20AfterStLoc11,
    registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9, registrationFramePc12AfterStLoc9,
    registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6, registrationFramePc9AfterStLoc8,
    registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow, registrationFramePc3AfterStLoc,
    registrationFrameAtPc2, registrationInitFrame]

private theorem registrationFramePc22_localRefs_idx15_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    15 < (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).localRefs.size := by
  rw [registrationFramePc22_localRefs_size args h mv rCompressed sOpt sVal]; decide

private theorem registrationFramePc22_localRefs_idx15_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).localRefs[15]'
      (registrationFramePc22_localRefs_idx15_lt args h mv rCompressed sOpt sVal) = none := by
  simp [registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg, registrationFramePc20AfterStLoc11,
    registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9, registrationFramePc12AfterStLoc9,
    registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6, registrationFramePc9AfterStLoc8,
    registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow, registrationFramePc3AfterStLoc,
    registrationFrameAtPc2, registrationInitFrame]

/-! ### PC 55 (`immBorrowLoc 15` — borrow hs) -/

@[simp] private theorem verifyRegistrationProofCode_idx55 :
    verifyRegistrationProofCode[55]'(by rw [verifyRegistrationProofCode_size_val]; decide) =
      .immBorrowLoc 15 := rfl

private theorem registrationFramePc55_locals_size (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt : MoveValue) :
    (registrationFramePc55AfterStLoc15 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt).locals.size = 19 := by
  have hsz53 := registrationFramePc53_locals_size args h mv rCompressed sOpt sVal eScalar hPoint ekPt
  simp [registrationFramePc55AfterStLoc15, Array.size_set, hsz53]

private theorem registrationFramePc55_localRefs_size (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt : MoveValue) :
    (registrationFramePc55AfterStLoc15 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt).localRefs.size = 19 :=
  registrationFramePc51_localRefs_size args h mv rCompressed sOpt sVal eScalar hPoint ekPt

private theorem registrationFramePc55_locals_idx15_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt : MoveValue) :
    15 < (registrationFramePc55AfterStLoc15 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt).locals.size := by
  rw [registrationFramePc55_locals_size]; decide

private theorem registrationFramePc55_localRefs_idx15_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt : MoveValue) :
    15 < (registrationFramePc55AfterStLoc15 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt).localRefs.size := by
  rw [registrationFramePc55_localRefs_size]; decide

set_option maxHeartbeats 3200000 in
private theorem registrationFramePc55_locals_idx15_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt : MoveValue) :
    (registrationFramePc55AfterStLoc15 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt).locals[15]'
      (registrationFramePc55_locals_idx15_lt args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt) =
        some hsPt := by
  unfold registrationFramePc55AfterStLoc15
  rw [Array.getElem_set_self]

set_option maxHeartbeats 3200000 in
private theorem registrationFramePc55_localRefs_idx15_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt : MoveValue) :
    (registrationFramePc55AfterStLoc15 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt).localRefs[15]'
      (registrationFramePc55_localRefs_idx15_lt args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt) = none := by
  have hne11 : (11 : Nat) ≠ 15 := by decide
  have hszR22 := registrationFramePc22_localRefs_size args h mv rCompressed sOpt sVal
  have hpc22 := registrationFramePc22_localRefs_idx15_eq args h mv rCompressed sOpt sVal
  unfold registrationFramePc55AfterStLoc15 registrationFramePc53AfterImmBorrow10
    registrationFramePc52AfterImmBorrow13 registrationFramePc51AfterStLoc14 registrationFramePc49AfterMoveLoc3
    registrationFramePc48AfterStLoc13 registrationFramePc46AfterStLoc12 registrationFramePc44AfterMoveLoc11
  rw [Array.getElem_set_ne (h := hne11)
    (pj := by rw [hszR22]; decide)
    (h' := by rw [hszR22]; decide)]
  exact hpc22

/-- Frame after `immBorrowLoc 15` (PC 55): same frame, pc := 56. -/
def registrationFramePc56AfterImmBorrow15 (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt : MoveValue) : Frame :=
  { registrationFramePc55AfterStLoc15 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt with pc := 56 }

set_option maxHeartbeats 3200000 in
theorem registration_step_pc55_immBorrowLoc15_generic (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt : MoveValue) (ms : MachineState)
    (rest : List MoveValue) :
    step (registrationModuleEnv o)
        ({ registrationFramePc55AfterStLoc15 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
              mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt with
            pc := 55 })
        [] rest ms =
      ExecResult.ok
        (registrationFramePc56AfterImmBorrow15 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
          mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt)
        [] (.immRef (ms.containers.alloc hsPt).2 :: rest)
        { ms with containers := (ms.containers.alloc hsPt).1 } := by
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  let hlen : args.length = 7 := registrationVerifyArgs_len _ _ _ _ _ _ _
  set fr' := ({ registrationFramePc55AfterStLoc15 args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt with
                pc := 55 }) with hfr'
  have hpc : fr'.pc < fr'.code.size := by
    simp [fr', registrationFramePc55AfterStLoc15, registrationFramePc53AfterImmBorrow10,
      registrationFramePc52AfterImmBorrow13, registrationFramePc51AfterStLoc14, registrationFramePc49AfterMoveLoc3,
      registrationFramePc48AfterStLoc13, registrationFramePc46AfterStLoc12, registrationFramePc44AfterMoveLoc11,
      registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
      registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
      registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
      registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
      registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame,
      verifyRegistrationProofCode_size_val]
  have hc : fr'.code[fr'.pc]'hpc = MoveInstr.immBorrowLoc 15 := by
    simp [fr', registrationFramePc55AfterStLoc15, registrationFramePc53AfterImmBorrow10,
      registrationFramePc52AfterImmBorrow13, registrationFramePc51AfterStLoc14, registrationFramePc49AfterMoveLoc3,
      registrationFramePc48AfterStLoc13, registrationFramePc46AfterStLoc12, registrationFramePc44AfterMoveLoc11,
      registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
      registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
      registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
      registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
      registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame,
      verifyRegistrationProofCode_size_val, verifyRegistrationProofCode_idx55]
  have hlocLt : 15 < fr'.locals.size :=
    registrationFramePc55_locals_idx15_lt args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt
  have hlocVal : fr'.locals[15]'hlocLt = some hsPt :=
    registrationFramePc55_locals_idx15_eq args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt
  have hlocRefLt : 15 < fr'.localRefs.size :=
    registrationFramePc55_localRefs_idx15_lt args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt
  have hlocRefVal : fr'.localRefs[15]'hlocRefLt = none :=
    registrationFramePc55_localRefs_idx15_eq args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt
  simp only [step, dif_pos hpc, hc, dif_pos hlocLt, hlocVal, dif_pos hlocRefLt, hlocRefVal]
  rfl

/-! ### PC 56 (`immBorrowLoc 14` — borrow ekPt) -/

@[simp] private theorem verifyRegistrationProofCode_idx56 :
    verifyRegistrationProofCode[56]'(by rw [verifyRegistrationProofCode_size_val]; decide) =
      .immBorrowLoc 14 := rfl

private theorem registrationFramePc56_locals_size (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt : MoveValue) :
    (registrationFramePc56AfterImmBorrow15 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt).locals.size = 19 :=
  registrationFramePc55_locals_size args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt

private theorem registrationFramePc56_localRefs_size (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt : MoveValue) :
    (registrationFramePc56AfterImmBorrow15 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt).localRefs.size = 19 :=
  registrationFramePc55_localRefs_size args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt

private theorem registrationFramePc56_locals_idx14_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt : MoveValue) :
    14 < (registrationFramePc56AfterImmBorrow15 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt).locals.size := by
  rw [registrationFramePc56_locals_size]; decide

private theorem registrationFramePc56_localRefs_idx14_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt : MoveValue) :
    14 < (registrationFramePc56AfterImmBorrow15 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt).localRefs.size := by
  rw [registrationFramePc56_localRefs_size]; decide

set_option maxHeartbeats 3200000 in
private theorem registrationFramePc56_locals_idx14_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt : MoveValue) :
    (registrationFramePc56AfterImmBorrow15 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt).locals[14]'
      (registrationFramePc56_locals_idx14_lt args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt) =
        some ekPt := by
  have hne15 : (15 : Nat) ≠ 14 := by decide
  have hsz49 : (registrationFramePc49AfterMoveLoc3 args h mv rCompressed sOpt sVal eScalar hPoint).locals.size = 19 := by
    simp [registrationFramePc49AfterMoveLoc3, Array.size_set,
      registrationFramePc48_locals_size args h mv rCompressed sOpt sVal eScalar hPoint]
  unfold registrationFramePc56AfterImmBorrow15 registrationFramePc55AfterStLoc15
    registrationFramePc53AfterImmBorrow10 registrationFramePc52AfterImmBorrow13 registrationFramePc51AfterStLoc14
  rw [Array.getElem_set_ne (h := hne15)
    (pj := by simp [Array.size_set, hsz49])
    (h' := by simp [Array.size_set, hsz49])]
  rw [Array.getElem_set_self]

set_option maxHeartbeats 3200000 in
private theorem registrationFramePc56_localRefs_idx14_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt : MoveValue) :
    (registrationFramePc56AfterImmBorrow15 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt).localRefs[14]'
      (registrationFramePc56_localRefs_idx14_lt args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt) = none := by
  have hne11 : (11 : Nat) ≠ 14 := by decide
  have hszR22 := registrationFramePc22_localRefs_size args h mv rCompressed sOpt sVal
  have hpc22 := registrationFramePc22_localRefs_idx14_eq args h mv rCompressed sOpt sVal
  unfold registrationFramePc56AfterImmBorrow15 registrationFramePc55AfterStLoc15
    registrationFramePc53AfterImmBorrow10 registrationFramePc52AfterImmBorrow13 registrationFramePc51AfterStLoc14
    registrationFramePc49AfterMoveLoc3 registrationFramePc48AfterStLoc13 registrationFramePc46AfterStLoc12
    registrationFramePc44AfterMoveLoc11
  rw [Array.getElem_set_ne (h := hne11)
    (pj := by rw [hszR22]; decide)
    (h' := by rw [hszR22]; decide)]
  exact hpc22

/-- Frame after `immBorrowLoc 14` (PC 56): same frame, pc := 57. -/
def registrationFramePc57AfterImmBorrow14 (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt : MoveValue) : Frame :=
  { registrationFramePc56AfterImmBorrow15 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt with pc := 57 }

set_option maxHeartbeats 3200000 in
theorem registration_step_pc56_immBorrowLoc14_generic (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt : MoveValue) (ms : MachineState)
    (rest : List MoveValue) :
    step (registrationModuleEnv o)
        (registrationFramePc56AfterImmBorrow15 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
          mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt)
        [] rest ms =
      ExecResult.ok
        (registrationFramePc57AfterImmBorrow14 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
          mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt)
        [] (.immRef (ms.containers.alloc ekPt).2 :: rest)
        { ms with containers := (ms.containers.alloc ekPt).1 } := by
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  let hlen : args.length = 7 := registrationVerifyArgs_len _ _ _ _ _ _ _
  set fr' := registrationFramePc56AfterImmBorrow15 args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt
    with hfr'
  have hpc : fr'.pc < fr'.code.size := by
    simp [fr', registrationFramePc56AfterImmBorrow15, registrationFramePc55AfterStLoc15,
      registrationFramePc53AfterImmBorrow10, registrationFramePc52AfterImmBorrow13,
      registrationFramePc51AfterStLoc14, registrationFramePc49AfterMoveLoc3,
      registrationFramePc48AfterStLoc13, registrationFramePc46AfterStLoc12, registrationFramePc44AfterMoveLoc11,
      registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
      registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
      registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
      registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
      registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame,
      verifyRegistrationProofCode_size_val]
  have hc : fr'.code[fr'.pc]'hpc = MoveInstr.immBorrowLoc 14 := by
    simp [fr', registrationFramePc56AfterImmBorrow15, registrationFramePc55AfterStLoc15,
      registrationFramePc53AfterImmBorrow10, registrationFramePc52AfterImmBorrow13,
      registrationFramePc51AfterStLoc14, registrationFramePc49AfterMoveLoc3,
      registrationFramePc48AfterStLoc13, registrationFramePc46AfterStLoc12, registrationFramePc44AfterMoveLoc11,
      registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
      registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
      registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
      registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
      registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame,
      verifyRegistrationProofCode_size_val, verifyRegistrationProofCode_idx56]
  have hlocLt : 14 < fr'.locals.size :=
    registrationFramePc56_locals_idx14_lt args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt
  have hlocVal : fr'.locals[14]'hlocLt = some ekPt :=
    registrationFramePc56_locals_idx14_eq args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt
  have hlocRefLt : 14 < fr'.localRefs.size :=
    registrationFramePc56_localRefs_idx14_lt args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt
  have hlocRefVal : fr'.localRefs[14]'hlocRefLt = none :=
    registrationFramePc56_localRefs_idx14_eq args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt
  simp only [step, dif_pos hpc, hc, dif_pos hlocLt, hlocVal, dif_pos hlocRefLt, hlocRefVal]
  rfl

/-! ### PC 57 (`immBorrowLoc 12` — borrow eScalar) -/

@[simp] private theorem verifyRegistrationProofCode_idx57 :
    verifyRegistrationProofCode[57]'(by rw [verifyRegistrationProofCode_size_val]; decide) =
      .immBorrowLoc 12 := rfl

private theorem registrationFramePc57_locals_size (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt : MoveValue) :
    (registrationFramePc57AfterImmBorrow14 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt).locals.size = 19 :=
  registrationFramePc56_locals_size args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt

private theorem registrationFramePc57_localRefs_size (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt : MoveValue) :
    (registrationFramePc57AfterImmBorrow14 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt).localRefs.size = 19 :=
  registrationFramePc56_localRefs_size args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt

private theorem registrationFramePc57_locals_idx12_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt : MoveValue) :
    12 < (registrationFramePc57AfterImmBorrow14 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt).locals.size := by
  rw [registrationFramePc57_locals_size]; decide

private theorem registrationFramePc57_localRefs_idx12_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt : MoveValue) :
    12 < (registrationFramePc57AfterImmBorrow14 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt).localRefs.size := by
  rw [registrationFramePc57_localRefs_size]; decide

set_option maxHeartbeats 3200000 in
private theorem registrationFramePc57_locals_idx12_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt : MoveValue) :
    (registrationFramePc57AfterImmBorrow14 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt).locals[12]'
      (registrationFramePc57_locals_idx12_lt args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt) =
        some eScalar := by
  have hne15 : (15 : Nat) ≠ 12 := by decide
  have hne14 : (14 : Nat) ≠ 12 := by decide
  have hne3 : (3 : Nat) ≠ 12 := by decide
  have hne13 : (13 : Nat) ≠ 12 := by decide
  have hsz44 := registrationFramePc44_locals_size args h mv rCompressed sOpt sVal
  unfold registrationFramePc57AfterImmBorrow14 registrationFramePc56AfterImmBorrow15
    registrationFramePc55AfterStLoc15 registrationFramePc53AfterImmBorrow10
    registrationFramePc52AfterImmBorrow13 registrationFramePc51AfterStLoc14 registrationFramePc49AfterMoveLoc3
    registrationFramePc48AfterStLoc13 registrationFramePc46AfterStLoc12
  rw [Array.getElem_set_ne (h := hne15)
    (pj := by simp [Array.size_set, hsz44])
    (h' := by simp [Array.size_set, hsz44])]
  rw [Array.getElem_set_ne (h := hne14)
    (pj := by simp [Array.size_set, hsz44])
    (h' := by simp [Array.size_set, hsz44])]
  rw [Array.getElem_set_ne (h := hne3)
    (pj := by simp [Array.size_set, hsz44])
    (h' := by simp [Array.size_set, hsz44])]
  rw [Array.getElem_set_ne (h := hne13)
    (pj := by simp [Array.size_set, hsz44])
    (h' := by simp [Array.size_set, hsz44])]
  rw [Array.getElem_set_self]

set_option maxHeartbeats 3200000 in
private theorem registrationFramePc57_localRefs_idx12_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt : MoveValue) :
    (registrationFramePc57AfterImmBorrow14 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt).localRefs[12]'
      (registrationFramePc57_localRefs_idx12_lt args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt) = none := by
  have hne11 : (11 : Nat) ≠ 12 := by decide
  have hszR22 := registrationFramePc22_localRefs_size args h mv rCompressed sOpt sVal
  have hpc22 := registrationFramePc22_localRefs_idx12_eq args h mv rCompressed sOpt sVal
  unfold registrationFramePc57AfterImmBorrow14 registrationFramePc56AfterImmBorrow15
    registrationFramePc55AfterStLoc15 registrationFramePc53AfterImmBorrow10
    registrationFramePc52AfterImmBorrow13 registrationFramePc51AfterStLoc14 registrationFramePc49AfterMoveLoc3
    registrationFramePc48AfterStLoc13 registrationFramePc46AfterStLoc12 registrationFramePc44AfterMoveLoc11
  rw [Array.getElem_set_ne (h := hne11)
    (pj := by rw [hszR22]; decide)
    (h' := by rw [hszR22]; decide)]
  exact hpc22

/-- Frame after `immBorrowLoc 12` (PC 57): same frame, pc := 58. -/
def registrationFramePc58AfterImmBorrow12 (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt : MoveValue) : Frame :=
  { registrationFramePc57AfterImmBorrow14 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt with pc := 58 }

set_option maxHeartbeats 3200000 in
theorem registration_step_pc57_immBorrowLoc12_generic (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt : MoveValue) (ms : MachineState)
    (rest : List MoveValue) :
    step (registrationModuleEnv o)
        (registrationFramePc57AfterImmBorrow14 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
          mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt)
        [] rest ms =
      ExecResult.ok
        (registrationFramePc58AfterImmBorrow12 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
          mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt)
        [] (.immRef (ms.containers.alloc eScalar).2 :: rest)
        { ms with containers := (ms.containers.alloc eScalar).1 } := by
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  let hlen : args.length = 7 := registrationVerifyArgs_len _ _ _ _ _ _ _
  set fr' := registrationFramePc57AfterImmBorrow14 args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt
    with hfr'
  have hpc : fr'.pc < fr'.code.size := by
    simp [fr', registrationFramePc57AfterImmBorrow14, registrationFramePc56AfterImmBorrow15,
      registrationFramePc55AfterStLoc15, registrationFramePc53AfterImmBorrow10,
      registrationFramePc52AfterImmBorrow13, registrationFramePc51AfterStLoc14, registrationFramePc49AfterMoveLoc3,
      registrationFramePc48AfterStLoc13, registrationFramePc46AfterStLoc12, registrationFramePc44AfterMoveLoc11,
      registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
      registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
      registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
      registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
      registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame,
      verifyRegistrationProofCode_size_val]
  have hc : fr'.code[fr'.pc]'hpc = MoveInstr.immBorrowLoc 12 := by
    simp [fr', registrationFramePc57AfterImmBorrow14, registrationFramePc56AfterImmBorrow15,
      registrationFramePc55AfterStLoc15, registrationFramePc53AfterImmBorrow10,
      registrationFramePc52AfterImmBorrow13, registrationFramePc51AfterStLoc14, registrationFramePc49AfterMoveLoc3,
      registrationFramePc48AfterStLoc13, registrationFramePc46AfterStLoc12, registrationFramePc44AfterMoveLoc11,
      registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
      registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
      registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
      registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
      registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame,
      verifyRegistrationProofCode_size_val, verifyRegistrationProofCode_idx57]
  have hlocLt : 12 < fr'.locals.size :=
    registrationFramePc57_locals_idx12_lt args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt
  have hlocVal : fr'.locals[12]'hlocLt = some eScalar :=
    registrationFramePc57_locals_idx12_eq args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt
  have hlocRefLt : 12 < fr'.localRefs.size :=
    registrationFramePc57_localRefs_idx12_lt args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt
  have hlocRefVal : fr'.localRefs[12]'hlocRefLt = none :=
    registrationFramePc57_localRefs_idx12_eq args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt
  simp only [step, dif_pos hpc, hc, dif_pos hlocLt, hlocVal, dif_pos hlocRefLt, hlocRefVal]
  rfl

/-! ### PC 58 (`call 12` = `point_mul` for ekPt * e → eke) -/

@[simp] private theorem verifyRegistrationProofCode_idx58 :
    verifyRegistrationProofCode[58]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .call 12 := rfl

set_option maxHeartbeats 3200000 in
theorem registration_step_pc58_call_pointMul_generic (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt : MoveValue) (ms : MachineState)
    (ridEk ridE : RefId) (ekVal eVal ekePt : MoveValue) (restBelow : List MoveValue)
    (hreadEk : ms.containers.read ridEk = some ekVal)
    (hreadE : ms.containers.read ridE = some eVal)
    (horacle : o.pointMul [ekVal, eVal] = some [ekePt]) :
    step (registrationModuleEnv o)
        (registrationFramePc58AfterImmBorrow12 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
          mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt)
        [] (.immRef ridE :: .immRef ridEk :: restBelow) ms =
      ExecResult.ok
        ({ registrationFramePc58AfterImmBorrow12 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
              mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt with
            pc := 59 })
        [] (ekePt :: restBelow) ms := by
  have hnative : wrapOracleImmRef2 o.pointMul ms.containers
        [.immRef ridEk, .immRef ridE] =
      some ([ekePt], ms.containers) := by
    show (Option.bind (derefImm ms.containers (.immRef ridEk))
          (fun v1 => Option.bind (derefImm ms.containers (.immRef ridE))
            (fun v2 => Option.bind (o.pointMul [v1, v2])
              (fun results => some (results, ms.containers))))) =
        some ([ekePt], ms.containers)
    simp only [derefImm]
    rw [hreadEk]
    simp only [Option.bind_some]
    rw [hreadE]
    simp only [Option.bind_some]
    rw [horacle]
    rfl
  simp only [step, registrationModuleEnv, registrationFramePc58AfterImmBorrow12,
    registrationFramePc57AfterImmBorrow14, registrationFramePc56AfterImmBorrow15,
    registrationFramePc55AfterStLoc15, registrationFramePc53AfterImmBorrow10,
    registrationFramePc52AfterImmBorrow13, registrationFramePc51AfterStLoc14, registrationFramePc49AfterMoveLoc3,
    registrationFramePc48AfterStLoc13, registrationFramePc46AfterStLoc12, registrationFramePc44AfterMoveLoc11,
    registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
    registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
    registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
    registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
    registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame, registrationVerifyArgs,
    verifyRegistrationProofCode, verifyRegistrationProofCode_size_val, verifyRegistrationProofCode_idx58,
    registrationInitFrame_idx5_lt, registration_locals_after_set5_idx7_lt, registrationVerifyArgs_len,
    registration_env_funcIdx12_lt, registrationModuleEnv_functions_at12, FuncDesc.body,
    takeN_two_cons_cons, List.map_cons, List.map_nil, Nat.reduceSub, List.reduceReplicate,
    List.cons_append, List.nil_append, List.size_toArray, List.length_cons, List.length_nil, zero_add,
    Nat.reduceAdd, Nat.reduceLT, Nat.one_lt_ofNat, ↓reduceDIte, List.getElem_toArray, List.getElem_cons_succ,
    List.getElem_cons_zero, Nat.ofNat_pos, Nat.reduceBEq, Bool.false_eq_true, BEq.rfl, List.set_toArray,
    List.set_cons_succ, List.set_cons_zero, beq_iff_eq]
  rw [hnative]
  simp only [handleNativeResult_ret1]

/-! ### PC 59 (`stLoc 16` — store eke into local 16) -/

@[simp] private theorem verifyRegistrationProofCode_idx59 :
    verifyRegistrationProofCode[59]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .stLoc 16 := rfl

private theorem registrationFramePc58_locals_size (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt : MoveValue) :
    (registrationFramePc58AfterImmBorrow12 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt).locals.size = 19 :=
  registrationFramePc57_locals_size args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt

private theorem registrationFramePc58_locals_idx16_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt : MoveValue) :
    16 < (registrationFramePc58AfterImmBorrow12 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt).locals.size := by
  rw [registrationFramePc58_locals_size]; decide

/-- Frame after `stLoc 16` (PC 59). -/
def registrationFramePc60AfterStLoc16 (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt : MoveValue) : Frame :=
  let fr := registrationFramePc58AfterImmBorrow12 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt
  { fr with
      pc := 60
      locals := fr.locals.set 16 (some ekePt)
        (registrationFramePc58_locals_idx16_lt args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt) }

set_option maxHeartbeats 3200000 in
theorem registration_step_pc59_stLoc16_generic (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt : MoveValue) (ms : MachineState)
    (rest : List MoveValue) :
    step (registrationModuleEnv o)
        ({ registrationFramePc58AfterImmBorrow12 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
              mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt with
            pc := 59 })
        [] (ekePt :: rest) ms =
      ExecResult.ok
        (registrationFramePc60AfterStLoc16 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
          mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt)
        [] rest ms := by
  simp [step, registrationModuleEnv, registrationFramePc60AfterStLoc16,
    registrationFramePc58AfterImmBorrow12, registrationFramePc57AfterImmBorrow14, registrationFramePc56AfterImmBorrow15,
    registrationFramePc55AfterStLoc15, registrationFramePc53AfterImmBorrow10,
    registrationFramePc52AfterImmBorrow13, registrationFramePc51AfterStLoc14, registrationFramePc49AfterMoveLoc3,
    registrationFramePc48AfterStLoc13, registrationFramePc46AfterStLoc12, registrationFramePc44AfterMoveLoc11,
    registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
    registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
    registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
    registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
    registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame, registrationVerifyArgs,
    verifyRegistrationProofCode, verifyRegistrationProofCode_size_val, verifyRegistrationProofCode_idx59,
    registrationInitFrame_idx5_lt, registration_locals_after_set5_idx7_lt,
    registration_locals_after_set5_set7_idx8_lt, registrationVerifyArgs_len]

/-! ### localRefs structural identities from Pc44 up to Pc60

Since immBorrowLoc, stLoc, and call instructions don't modify `frame.localRefs`
in this chain, the localRefs field of every intermediate frame from Pc44 onward
is definitionally equal to `Pc44AfterMoveLoc11.localRefs`. We prove these via
`rfl` to avoid deep `whnf` chains. -/

private theorem registrationFramePc46_localRefs_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar : MoveValue) :
    (registrationFramePc46AfterStLoc12 args h mv rCompressed sOpt sVal eScalar).localRefs =
      (registrationFramePc44AfterMoveLoc11 args h mv rCompressed sOpt sVal).localRefs := rfl

private theorem registrationFramePc48_localRefs_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint : MoveValue) :
    (registrationFramePc48AfterStLoc13 args h mv rCompressed sOpt sVal eScalar hPoint).localRefs =
      (registrationFramePc44AfterMoveLoc11 args h mv rCompressed sOpt sVal).localRefs := rfl

private theorem registrationFramePc49_localRefs_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint : MoveValue) :
    (registrationFramePc49AfterMoveLoc3 args h mv rCompressed sOpt sVal eScalar hPoint).localRefs =
      (registrationFramePc44AfterMoveLoc11 args h mv rCompressed sOpt sVal).localRefs := rfl

private theorem registrationFramePc51_localRefs_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt : MoveValue) :
    (registrationFramePc51AfterStLoc14 args h mv rCompressed sOpt sVal eScalar hPoint ekPt).localRefs =
      (registrationFramePc44AfterMoveLoc11 args h mv rCompressed sOpt sVal).localRefs := rfl

private theorem registrationFramePc52_localRefs_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt : MoveValue) :
    (registrationFramePc52AfterImmBorrow13 args h mv rCompressed sOpt sVal eScalar hPoint ekPt).localRefs =
      (registrationFramePc44AfterMoveLoc11 args h mv rCompressed sOpt sVal).localRefs := rfl

private theorem registrationFramePc53_localRefs_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt : MoveValue) :
    (registrationFramePc53AfterImmBorrow10 args h mv rCompressed sOpt sVal eScalar hPoint ekPt).localRefs =
      (registrationFramePc44AfterMoveLoc11 args h mv rCompressed sOpt sVal).localRefs := rfl

private theorem registrationFramePc55_localRefs_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt : MoveValue) :
    (registrationFramePc55AfterStLoc15 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt).localRefs =
      (registrationFramePc44AfterMoveLoc11 args h mv rCompressed sOpt sVal).localRefs := rfl

private theorem registrationFramePc56_localRefs_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt : MoveValue) :
    (registrationFramePc56AfterImmBorrow15 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt).localRefs =
      (registrationFramePc44AfterMoveLoc11 args h mv rCompressed sOpt sVal).localRefs := rfl

private theorem registrationFramePc57_localRefs_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt : MoveValue) :
    (registrationFramePc57AfterImmBorrow14 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt).localRefs =
      (registrationFramePc44AfterMoveLoc11 args h mv rCompressed sOpt sVal).localRefs := rfl

private theorem registrationFramePc58_localRefs_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt : MoveValue) :
    (registrationFramePc58AfterImmBorrow12 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt).localRefs =
      (registrationFramePc44AfterMoveLoc11 args h mv rCompressed sOpt sVal).localRefs := rfl

private theorem registrationFramePc60_localRefs_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt : MoveValue) :
    (registrationFramePc60AfterStLoc16 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt).localRefs =
      (registrationFramePc44AfterMoveLoc11 args h mv rCompressed sOpt sVal).localRefs := rfl

/-! `Pc44.localRefs = Pc22.localRefs.set 11 none` (PC 43 moveLoc 11 takes the `some`-branch of localRefs[11]). -/
private theorem registrationFramePc44_localRefs_set_Pc22 (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    (registrationFramePc44AfterMoveLoc11 args h mv rCompressed sOpt sVal).localRefs =
      (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).localRefs.set 11 none
        (registrationFramePc22_localRefs_idx11_lt args h mv rCompressed sOpt sVal) := rfl

private theorem registrationFramePc22_locals_idx16_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    16 < (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).locals.size := by
  rw [registrationFramePc22_locals_size args h mv rCompressed sOpt sVal]; decide

private theorem registrationFramePc22_localRefs_idx16_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    16 < (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).localRefs.size := by
  rw [registrationFramePc22_localRefs_size args h mv rCompressed sOpt sVal]; decide

private theorem registrationFramePc22_localRefs_idx16_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).localRefs[16]'
      (registrationFramePc22_localRefs_idx16_lt args h mv rCompressed sOpt sVal) = none := by
  simp [registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg, registrationFramePc20AfterStLoc11,
    registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9, registrationFramePc12AfterStLoc9,
    registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6, registrationFramePc9AfterStLoc8,
    registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow, registrationFramePc3AfterStLoc,
    registrationFrameAtPc2, registrationInitFrame]

/-! ### PC 60 (`immBorrowLoc 16` — borrow ekePt) -/

@[simp] private theorem verifyRegistrationProofCode_idx60 :
    verifyRegistrationProofCode[60]'(by rw [verifyRegistrationProofCode_size_val]; decide) =
      .immBorrowLoc 16 := rfl

set_option maxHeartbeats 1600000 in
/-- Direct structural equality: `Pc60.locals = Pc58.locals.set 16 (some ekePt) _`. -/
private theorem registrationFramePc60_locals_eq_set (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt : MoveValue) :
    (registrationFramePc60AfterStLoc16 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt).locals =
      (registrationFramePc58AfterImmBorrow12 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt).locals.set 16
          (some ekePt)
          (registrationFramePc58_locals_idx16_lt args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt) := rfl

set_option maxHeartbeats 1600000 in
private theorem registrationFramePc60_locals_size (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt : MoveValue) :
    (registrationFramePc60AfterStLoc16 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt).locals.size = 19 := by
  rw [registrationFramePc60_locals_eq_set, Array.size_set, registrationFramePc58_locals_size]

set_option maxHeartbeats 1600000 in
private theorem registrationFramePc60_localRefs_size (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt : MoveValue) :
    (registrationFramePc60AfterStLoc16 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt).localRefs.size = 19 := by
  rw [registrationFramePc60_localRefs_eq, registrationFramePc44_localRefs_set_Pc22, Array.size_set,
    registrationFramePc22_localRefs_size]

set_option maxHeartbeats 800000 in
private theorem registrationFramePc60_locals_idx16_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt : MoveValue) :
    16 < (registrationFramePc60AfterStLoc16 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt).locals.size := by
  rw [registrationFramePc60_locals_size]; decide

set_option maxHeartbeats 800000 in
private theorem registrationFramePc60_localRefs_idx16_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt : MoveValue) :
    16 < (registrationFramePc60AfterStLoc16 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt).localRefs.size := by
  rw [registrationFramePc60_localRefs_size]; decide

set_option maxHeartbeats 12800000 in
private theorem registrationFramePc60_locals_idx16_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt : MoveValue) :
    (registrationFramePc60AfterStLoc16 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt).locals[16]'
      (registrationFramePc60_locals_idx16_lt args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt) =
        some ekePt := by
  unfold registrationFramePc60AfterStLoc16
  rw [Array.getElem_set_self]

set_option maxHeartbeats 1600000 in
private theorem registrationFramePc60_localRefs_eq_setPc22 (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt : MoveValue) :
    (registrationFramePc60AfterStLoc16 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt).localRefs =
      (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).localRefs.set 11 none
        (registrationFramePc22_localRefs_idx11_lt args h mv rCompressed sOpt sVal) := rfl

private theorem registrationFramePc60_localRefs_idx16_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt : MoveValue) :
    (registrationFramePc60AfterStLoc16 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt).localRefs[16]'
      (registrationFramePc60_localRefs_idx16_lt args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt) = none := by
  have hne : (11 : Nat) ≠ 16 := by decide
  have hpc22 := registrationFramePc22_localRefs_idx16_eq args h mv rCompressed sOpt sVal
  have heq := registrationFramePc60_localRefs_eq_setPc22 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt
  simp only [heq, Array.getElem_set_ne (h := hne)]
  exact hpc22

/-- Frame after `immBorrowLoc 16` (PC 60): same frame, pc := 61. -/
def registrationFramePc61AfterImmBorrow16 (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt : MoveValue) : Frame :=
  { registrationFramePc60AfterStLoc16 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt with pc := 61 }

set_option maxHeartbeats 12800000 in
theorem registration_step_pc60_immBorrowLoc16_generic (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt : MoveValue) (ms : MachineState)
    (rest : List MoveValue) :
    step (registrationModuleEnv o)
        (registrationFramePc60AfterStLoc16 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
          mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt)
        [] rest ms =
      ExecResult.ok
        (registrationFramePc61AfterImmBorrow16 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
          mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt)
        [] (.immRef (ms.containers.alloc ekePt).2 :: rest)
        { ms with containers := (ms.containers.alloc ekePt).1 } := by
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  let hlen : args.length = 7 := registrationVerifyArgs_len _ _ _ _ _ _ _
  set fr' := registrationFramePc60AfterStLoc16 args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt
    with hfr'
  have hpc : fr'.pc < fr'.code.size := by
    simp [fr', registrationFramePc60AfterStLoc16, registrationFramePc58AfterImmBorrow12,
      registrationFramePc57AfterImmBorrow14, registrationFramePc56AfterImmBorrow15,
      registrationFramePc55AfterStLoc15, registrationFramePc53AfterImmBorrow10,
      registrationFramePc52AfterImmBorrow13, registrationFramePc51AfterStLoc14, registrationFramePc49AfterMoveLoc3,
      registrationFramePc48AfterStLoc13, registrationFramePc46AfterStLoc12, registrationFramePc44AfterMoveLoc11,
      registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
      registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
      registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
      registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
      registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame,
      verifyRegistrationProofCode_size_val]
  have hc : fr'.code[fr'.pc]'hpc = MoveInstr.immBorrowLoc 16 := by
    simp [fr', registrationFramePc60AfterStLoc16, registrationFramePc58AfterImmBorrow12,
      registrationFramePc57AfterImmBorrow14, registrationFramePc56AfterImmBorrow15,
      registrationFramePc55AfterStLoc15, registrationFramePc53AfterImmBorrow10,
      registrationFramePc52AfterImmBorrow13, registrationFramePc51AfterStLoc14, registrationFramePc49AfterMoveLoc3,
      registrationFramePc48AfterStLoc13, registrationFramePc46AfterStLoc12, registrationFramePc44AfterMoveLoc11,
      registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
      registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
      registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
      registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
      registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame,
      verifyRegistrationProofCode_size_val, verifyRegistrationProofCode_idx60]
  have hlocLt : 16 < fr'.locals.size :=
    registrationFramePc60_locals_idx16_lt args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt
  have hlocVal : fr'.locals[16]'hlocLt = some ekePt :=
    registrationFramePc60_locals_idx16_eq args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt
  have hlocRefLt : 16 < fr'.localRefs.size :=
    registrationFramePc60_localRefs_idx16_lt args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt
  have hlocRefVal : fr'.localRefs[16]'hlocRefLt = none :=
    registrationFramePc60_localRefs_idx16_eq args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt
  simp only [step, dif_pos hpc, hc, dif_pos hlocLt, hlocVal, dif_pos hlocRefLt, hlocRefVal]
  rfl

/-! ### PC 61 (`call 13` = `point_add` for hsPt + ekePt → lhsPt) -/

@[simp] private theorem verifyRegistrationProofCode_idx61 :
    verifyRegistrationProofCode[61]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .call 13 := rfl

private theorem registration_env_funcIdx13_lt (o : RegistrationNativeOracle) :
    13 < (registrationModuleEnv o).functions.size := by
  rw [registration_module_env_size o]; decide

private theorem registrationModuleEnv_functions_at13 (o : RegistrationNativeOracle)
    (h : 13 < (registrationModuleEnv o).functions.size) :
    (registrationModuleEnv o).functions[13]'h =
      { numParams := 2, numReturns := 1, body := .nativeRef (wrapOracleImmRef2 o.pointAdd) } := by
  simp [registrationModuleEnv]

set_option maxHeartbeats 3200000 in
theorem registration_step_pc61_call_pointAdd_generic (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt : MoveValue) (ms : MachineState)
    (ridHs ridEke : RefId) (hsVal ekeVal lhsPt : MoveValue) (restBelow : List MoveValue)
    (hreadHs : ms.containers.read ridHs = some hsVal)
    (hreadEke : ms.containers.read ridEke = some ekeVal)
    (horacle : o.pointAdd [hsVal, ekeVal] = some [lhsPt]) :
    step (registrationModuleEnv o)
        (registrationFramePc61AfterImmBorrow16 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
          mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt)
        [] (.immRef ridEke :: .immRef ridHs :: restBelow) ms =
      ExecResult.ok
        ({ registrationFramePc61AfterImmBorrow16 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
              mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt with
            pc := 62 })
        [] (lhsPt :: restBelow) ms := by
  have hnative : wrapOracleImmRef2 o.pointAdd ms.containers
        [.immRef ridHs, .immRef ridEke] =
      some ([lhsPt], ms.containers) := by
    show (Option.bind (derefImm ms.containers (.immRef ridHs))
          (fun v1 => Option.bind (derefImm ms.containers (.immRef ridEke))
            (fun v2 => Option.bind (o.pointAdd [v1, v2])
              (fun results => some (results, ms.containers))))) =
        some ([lhsPt], ms.containers)
    simp only [derefImm]
    rw [hreadHs]
    simp only [Option.bind_some]
    rw [hreadEke]
    simp only [Option.bind_some]
    rw [horacle]
    rfl
  simp only [step, registrationModuleEnv, registrationFramePc61AfterImmBorrow16,
    registrationFramePc60AfterStLoc16, registrationFramePc58AfterImmBorrow12,
    registrationFramePc57AfterImmBorrow14, registrationFramePc56AfterImmBorrow15,
    registrationFramePc55AfterStLoc15, registrationFramePc53AfterImmBorrow10,
    registrationFramePc52AfterImmBorrow13, registrationFramePc51AfterStLoc14, registrationFramePc49AfterMoveLoc3,
    registrationFramePc48AfterStLoc13, registrationFramePc46AfterStLoc12, registrationFramePc44AfterMoveLoc11,
    registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
    registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
    registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
    registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
    registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame, registrationVerifyArgs,
    verifyRegistrationProofCode, verifyRegistrationProofCode_size_val, verifyRegistrationProofCode_idx61,
    registrationInitFrame_idx5_lt, registration_locals_after_set5_idx7_lt, registrationVerifyArgs_len,
    registration_env_funcIdx13_lt, registrationModuleEnv_functions_at13, FuncDesc.body,
    takeN_two_cons_cons, List.map_cons, List.map_nil, Nat.reduceSub, List.reduceReplicate,
    List.cons_append, List.nil_append, List.size_toArray, List.length_cons, List.length_nil, zero_add,
    Nat.reduceAdd, Nat.reduceLT, Nat.one_lt_ofNat, ↓reduceDIte, List.getElem_toArray, List.getElem_cons_succ,
    List.getElem_cons_zero, Nat.ofNat_pos, Nat.reduceBEq, Bool.false_eq_true, BEq.rfl, List.set_toArray,
    List.set_cons_succ, List.set_cons_zero, beq_iff_eq]
  rw [hnative]
  simp only [handleNativeResult_ret1]

/-! ### PC 62 (`stLoc 17` — store lhsPt into local 17) -/

@[simp] private theorem verifyRegistrationProofCode_idx62 :
    verifyRegistrationProofCode[62]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .stLoc 17 := rfl

private theorem registrationFramePc61_locals_size (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt : MoveValue) :
    (registrationFramePc61AfterImmBorrow16 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt).locals.size = 19 :=
  registrationFramePc60_locals_size args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt

private theorem registrationFramePc61_locals_idx17_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt : MoveValue) :
    17 < (registrationFramePc61AfterImmBorrow16 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt).locals.size := by
  rw [registrationFramePc61_locals_size]; decide

/-- Frame after `stLoc 17` (PC 62): locals[17] = some lhsPt, pc := 63. -/
def registrationFramePc63AfterStLoc17 (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt : MoveValue) : Frame :=
  let fr := registrationFramePc61AfterImmBorrow16 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt
  { fr with
      pc := 63
      locals := fr.locals.set 17 (some lhsPt)
        (registrationFramePc61_locals_idx17_lt args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt) }

set_option maxHeartbeats 3200000 in
theorem registration_step_pc62_stLoc17_generic (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt : MoveValue) (ms : MachineState)
    (rest : List MoveValue) :
    step (registrationModuleEnv o)
        ({ registrationFramePc61AfterImmBorrow16 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
              mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt with
            pc := 62 })
        [] (lhsPt :: rest) ms =
      ExecResult.ok
        (registrationFramePc63AfterStLoc17 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
          mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt)
        [] rest ms := by
  simp [step, registrationModuleEnv, registrationFramePc63AfterStLoc17,
    registrationFramePc61AfterImmBorrow16, registrationFramePc60AfterStLoc16,
    registrationFramePc58AfterImmBorrow12, registrationFramePc57AfterImmBorrow14, registrationFramePc56AfterImmBorrow15,
    registrationFramePc55AfterStLoc15, registrationFramePc53AfterImmBorrow10,
    registrationFramePc52AfterImmBorrow13, registrationFramePc51AfterStLoc14, registrationFramePc49AfterMoveLoc3,
    registrationFramePc48AfterStLoc13, registrationFramePc46AfterStLoc12, registrationFramePc44AfterMoveLoc11,
    registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
    registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
    registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
    registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
    registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame, registrationVerifyArgs,
    verifyRegistrationProofCode, verifyRegistrationProofCode_size_val, verifyRegistrationProofCode_idx62,
    registrationInitFrame_idx5_lt, registration_locals_after_set5_idx7_lt,
    registration_locals_after_set5_set7_idx8_lt, registrationVerifyArgs_len]

/-! ### PC 63 (`immBorrowLoc 8` — push `&rCompressed`) -/

@[simp] private theorem verifyRegistrationProofCode_idx63 :
    verifyRegistrationProofCode[63]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .immBorrowLoc 8 := rfl

/-! `Pc60.locals[8] = some rCompressed`: unchanged since `Pc8.stLoc 8`. The chain from `Pc60`
back to `Pc22` involves sets at indices 16, 15, 14, 3, 13, 12, 11 — all ≠ 8. -/
set_option maxHeartbeats 12800000 in
private theorem registrationFramePc60_locals_idx8_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt : MoveValue) :
    (registrationFramePc60AfterStLoc16 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt).locals[8]'
      (by rw [registrationFramePc60_locals_size]; decide) = some rCompressed := by
  have hne16 : (16 : Nat) ≠ 8 := by decide
  have hne15 : (15 : Nat) ≠ 8 := by decide
  have hne14 : (14 : Nat) ≠ 8 := by decide
  have hne3 : (3 : Nat) ≠ 8 := by decide
  have hne13 : (13 : Nat) ≠ 8 := by decide
  have hne12 : (12 : Nat) ≠ 8 := by decide
  have hne11 : (11 : Nat) ≠ 8 := by decide
  have hsz22 := registrationFramePc22_locals_size args h mv rCompressed sOpt sVal
  have hpc22 := registrationFramePc22_locals_idx8_eq args h mv rCompressed sOpt sVal
  unfold registrationFramePc60AfterStLoc16 registrationFramePc58AfterImmBorrow12
    registrationFramePc57AfterImmBorrow14 registrationFramePc56AfterImmBorrow15
    registrationFramePc55AfterStLoc15 registrationFramePc53AfterImmBorrow10
    registrationFramePc52AfterImmBorrow13 registrationFramePc51AfterStLoc14 registrationFramePc49AfterMoveLoc3
    registrationFramePc48AfterStLoc13 registrationFramePc46AfterStLoc12 registrationFramePc44AfterMoveLoc11
  rw [Array.getElem_set_ne (h := hne16)
    (pj := by simp [Array.size_set, hsz22])
    (h' := by simp [Array.size_set, hsz22])]
  rw [Array.getElem_set_ne (h := hne15)
    (pj := by simp [Array.size_set, hsz22])
    (h' := by simp [Array.size_set, hsz22])]
  rw [Array.getElem_set_ne (h := hne14)
    (pj := by simp [Array.size_set, hsz22])
    (h' := by simp [Array.size_set, hsz22])]
  rw [Array.getElem_set_ne (h := hne3)
    (pj := by simp [Array.size_set, hsz22])
    (h' := by simp [Array.size_set, hsz22])]
  rw [Array.getElem_set_ne (h := hne13)
    (pj := by simp [Array.size_set, hsz22])
    (h' := by simp [Array.size_set, hsz22])]
  rw [Array.getElem_set_ne (h := hne12)
    (pj := by simp [Array.size_set, hsz22])
    (h' := by simp [Array.size_set, hsz22])]
  rw [Array.getElem_set_ne (h := hne11)
    (pj := by rw [hsz22]; decide)
    (h' := by rw [hsz22]; decide)]
  exact hpc22

private theorem registrationFramePc60_localRefs_idx8_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt : MoveValue) :
    (registrationFramePc60AfterStLoc16 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt).localRefs[8]'
      (by rw [registrationFramePc60_localRefs_size]; decide) = none := by
  have hne : (11 : Nat) ≠ 8 := by decide
  have hpc22 := registrationFramePc22_localRefs_idx8_eq args h mv rCompressed sOpt sVal
  have heq := registrationFramePc60_localRefs_eq_setPc22 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt
  simp only [heq, Array.getElem_set_ne (h := hne)]
  exact hpc22

private theorem registrationFramePc63AfterStLoc17_locals_size (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt : MoveValue) :
    (registrationFramePc63AfterStLoc17 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt).locals.size = 19 := by
  unfold registrationFramePc63AfterStLoc17
  rw [Array.size_set, registrationFramePc61_locals_size]

private theorem registrationFramePc63AfterStLoc17_localRefs_size (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt : MoveValue) :
    (registrationFramePc63AfterStLoc17 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt).localRefs.size = 19 :=
  registrationFramePc60_localRefs_size args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt

private theorem registrationFramePc63AfterStLoc17_locals_idx8_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt : MoveValue) :
    8 < (registrationFramePc63AfterStLoc17 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt).locals.size := by
  rw [registrationFramePc63AfterStLoc17_locals_size]; decide

private theorem registrationFramePc63AfterStLoc17_localRefs_idx8_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt : MoveValue) :
    8 < (registrationFramePc63AfterStLoc17 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt).localRefs.size := by
  rw [registrationFramePc63AfterStLoc17_localRefs_size]; decide

set_option maxHeartbeats 12800000 in
private theorem registrationFramePc63AfterStLoc17_locals_idx8_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt : MoveValue) :
    (registrationFramePc63AfterStLoc17 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt).locals[8]'
      (registrationFramePc63AfterStLoc17_locals_idx8_lt args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt) =
        some rCompressed := by
  have hne : (17 : Nat) ≠ 8 := by decide
  have hsz61 := registrationFramePc61_locals_size args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt
  have hpc60 := registrationFramePc60_locals_idx8_eq args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt
  unfold registrationFramePc63AfterStLoc17
  rw [Array.getElem_set_ne (h := hne)
    (pj := by rw [hsz61]; decide)
    (h' := by rw [hsz61]; decide)]
  exact hpc60

private theorem registrationFramePc63AfterStLoc17_localRefs_idx8_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt : MoveValue) :
    (registrationFramePc63AfterStLoc17 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt).localRefs[8]'
      (registrationFramePc63AfterStLoc17_localRefs_idx8_lt args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt) =
        none := by
  have hpc60 := registrationFramePc60_localRefs_idx8_eq args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt
  unfold registrationFramePc63AfterStLoc17
  exact hpc60

/-- Frame after `immBorrowLoc 8` (PC 63): same frame, pc := 64. -/
def registrationFramePc64AfterImmBorrow8 (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt : MoveValue) : Frame :=
  { registrationFramePc63AfterStLoc17 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt with pc := 64 }

set_option maxHeartbeats 12800000 in
theorem registration_step_pc63_immBorrowLoc8_generic (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt : MoveValue) (ms : MachineState)
    (rest : List MoveValue) :
    step (registrationModuleEnv o)
        (registrationFramePc63AfterStLoc17 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
          mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt)
        [] rest ms =
      ExecResult.ok
        (registrationFramePc64AfterImmBorrow8 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
          mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt)
        [] (.immRef (ms.containers.alloc rCompressed).2 :: rest)
        { ms with containers := (ms.containers.alloc rCompressed).1 } := by
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  let hlen : args.length = 7 := registrationVerifyArgs_len _ _ _ _ _ _ _
  set fr' := registrationFramePc63AfterStLoc17 args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt
    with hfr'
  have hpc : fr'.pc < fr'.code.size := by
    simp [fr', registrationFramePc63AfterStLoc17, registrationFramePc61AfterImmBorrow16,
      registrationFramePc60AfterStLoc16, registrationFramePc58AfterImmBorrow12,
      registrationFramePc57AfterImmBorrow14, registrationFramePc56AfterImmBorrow15,
      registrationFramePc55AfterStLoc15, registrationFramePc53AfterImmBorrow10,
      registrationFramePc52AfterImmBorrow13, registrationFramePc51AfterStLoc14, registrationFramePc49AfterMoveLoc3,
      registrationFramePc48AfterStLoc13, registrationFramePc46AfterStLoc12, registrationFramePc44AfterMoveLoc11,
      registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
      registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
      registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
      registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
      registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame,
      verifyRegistrationProofCode_size_val]
  have hc : fr'.code[fr'.pc]'hpc = MoveInstr.immBorrowLoc 8 := by
    simp [fr', registrationFramePc63AfterStLoc17, registrationFramePc61AfterImmBorrow16,
      registrationFramePc60AfterStLoc16, registrationFramePc58AfterImmBorrow12,
      registrationFramePc57AfterImmBorrow14, registrationFramePc56AfterImmBorrow15,
      registrationFramePc55AfterStLoc15, registrationFramePc53AfterImmBorrow10,
      registrationFramePc52AfterImmBorrow13, registrationFramePc51AfterStLoc14, registrationFramePc49AfterMoveLoc3,
      registrationFramePc48AfterStLoc13, registrationFramePc46AfterStLoc12, registrationFramePc44AfterMoveLoc11,
      registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
      registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
      registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
      registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
      registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame,
      verifyRegistrationProofCode_size_val, verifyRegistrationProofCode_idx63]
  have hlocLt : 8 < fr'.locals.size :=
    registrationFramePc63AfterStLoc17_locals_idx8_lt args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt
  have hlocVal : fr'.locals[8]'hlocLt = some rCompressed :=
    registrationFramePc63AfterStLoc17_locals_idx8_eq args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt
  have hlocRefLt : 8 < fr'.localRefs.size :=
    registrationFramePc63AfterStLoc17_localRefs_idx8_lt args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt
  have hlocRefVal : fr'.localRefs[8]'hlocRefLt = none :=
    registrationFramePc63AfterStLoc17_localRefs_idx8_eq args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt
  simp only [step, dif_pos hpc, hc, dif_pos hlocLt, hlocVal, dif_pos hlocRefLt, hlocRefVal]
  rfl

/-! ### PC 64 (`call 14` = `point_decompress` on `&rCompressed`) -/

@[simp] private theorem verifyRegistrationProofCode_idx64 :
    verifyRegistrationProofCode[64]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .call 14 := rfl

private theorem registration_env_funcIdx14_lt (o : RegistrationNativeOracle) :
    14 < (registrationModuleEnv o).functions.size := by
  rw [registration_module_env_size o]; decide

private theorem registrationModuleEnv_functions_at14 (o : RegistrationNativeOracle)
    (h : 14 < (registrationModuleEnv o).functions.size) :
    (registrationModuleEnv o).functions[14]'h =
      { numParams := 1, numReturns := 1, body := .nativeRef (wrapOracleImmRef1 o.pointDecompress) } := by
  simp [registrationModuleEnv]

set_option maxHeartbeats 3200000 in
theorem registration_step_pc64_call_pointDecompress_generic (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt : MoveValue) (ms : MachineState)
    (ridR : RefId) (rVal rhsPt : MoveValue) (restBelow : List MoveValue)
    (hreadR : ms.containers.read ridR = some rVal)
    (horacle : o.pointDecompress [rVal] = some [rhsPt]) :
    step (registrationModuleEnv o)
        (registrationFramePc64AfterImmBorrow8 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
          mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt)
        [] (.immRef ridR :: restBelow) ms =
      ExecResult.ok
        ({ registrationFramePc64AfterImmBorrow8 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
              mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt with
            pc := 65 })
        [] (rhsPt :: restBelow) ms := by
  have hnative : wrapOracleImmRef1 o.pointDecompress ms.containers
        [.immRef ridR] =
      some ([rhsPt], ms.containers) := by
    show (Option.bind (derefImm ms.containers (.immRef ridR))
          (fun v => Option.bind (o.pointDecompress [v])
              (fun results => some (results, ms.containers)))) =
        some ([rhsPt], ms.containers)
    simp only [derefImm]
    rw [hreadR]
    simp only [Option.bind_some]
    rw [horacle]
    rfl
  simp only [step, registrationModuleEnv, registrationFramePc64AfterImmBorrow8,
    registrationFramePc63AfterStLoc17, registrationFramePc61AfterImmBorrow16,
    registrationFramePc60AfterStLoc16, registrationFramePc58AfterImmBorrow12,
    registrationFramePc57AfterImmBorrow14, registrationFramePc56AfterImmBorrow15,
    registrationFramePc55AfterStLoc15, registrationFramePc53AfterImmBorrow10,
    registrationFramePc52AfterImmBorrow13, registrationFramePc51AfterStLoc14, registrationFramePc49AfterMoveLoc3,
    registrationFramePc48AfterStLoc13, registrationFramePc46AfterStLoc12, registrationFramePc44AfterMoveLoc11,
    registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
    registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
    registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
    registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
    registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame, registrationVerifyArgs,
    verifyRegistrationProofCode, verifyRegistrationProofCode_size_val, verifyRegistrationProofCode_idx64,
    registrationInitFrame_idx5_lt, registration_locals_after_set5_idx7_lt, registrationVerifyArgs_len,
    registration_env_funcIdx14_lt, registrationModuleEnv_functions_at14, FuncDesc.body,
    takeN_one_cons, List.map_cons, List.map_nil, Nat.reduceSub, List.reduceReplicate,
    List.cons_append, List.nil_append, List.size_toArray, List.length_cons, List.length_nil, zero_add,
    Nat.reduceAdd, Nat.reduceLT, Nat.one_lt_ofNat, ↓reduceDIte, List.getElem_toArray, List.getElem_cons_succ,
    List.getElem_cons_zero, Nat.ofNat_pos, Nat.reduceBEq, Bool.false_eq_true, BEq.rfl, List.set_toArray,
    List.set_cons_succ, List.set_cons_zero, beq_iff_eq]
  rw [hnative]
  simp only [handleNativeResult_ret1]

/-! ### PC 65 (`stLoc 18` — store rhsPt into local 18) -/

@[simp] private theorem verifyRegistrationProofCode_idx65 :
    verifyRegistrationProofCode[65]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .stLoc 18 := rfl

private theorem registrationFramePc64_locals_size (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt : MoveValue) :
    (registrationFramePc64AfterImmBorrow8 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt).locals.size = 19 :=
  registrationFramePc63AfterStLoc17_locals_size args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt

private theorem registrationFramePc64_locals_idx18_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt : MoveValue) :
    18 < (registrationFramePc64AfterImmBorrow8 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt).locals.size := by
  rw [registrationFramePc64_locals_size]; decide

/-- Frame after `stLoc 18` (PC 65): locals[18] = some rhsPt, pc := 66. -/
def registrationFramePc66AfterStLoc18 (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt : MoveValue) : Frame :=
  let fr := registrationFramePc64AfterImmBorrow8 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt
  { fr with
      pc := 66
      locals := fr.locals.set 18 (some rhsPt)
        (registrationFramePc64_locals_idx18_lt args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt) }

set_option maxHeartbeats 3200000 in
theorem registration_step_pc65_stLoc18_generic (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt : MoveValue) (ms : MachineState)
    (rest : List MoveValue) :
    step (registrationModuleEnv o)
        ({ registrationFramePc64AfterImmBorrow8 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
              mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt with
            pc := 65 })
        [] (rhsPt :: rest) ms =
      ExecResult.ok
        (registrationFramePc66AfterStLoc18 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
          mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt)
        [] rest ms := by
  simp [step, registrationModuleEnv, registrationFramePc66AfterStLoc18,
    registrationFramePc64AfterImmBorrow8, registrationFramePc63AfterStLoc17,
    registrationFramePc61AfterImmBorrow16, registrationFramePc60AfterStLoc16,
    registrationFramePc58AfterImmBorrow12, registrationFramePc57AfterImmBorrow14, registrationFramePc56AfterImmBorrow15,
    registrationFramePc55AfterStLoc15, registrationFramePc53AfterImmBorrow10,
    registrationFramePc52AfterImmBorrow13, registrationFramePc51AfterStLoc14, registrationFramePc49AfterMoveLoc3,
    registrationFramePc48AfterStLoc13, registrationFramePc46AfterStLoc12, registrationFramePc44AfterMoveLoc11,
    registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
    registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
    registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
    registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
    registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame, registrationVerifyArgs,
    verifyRegistrationProofCode, verifyRegistrationProofCode_size_val, verifyRegistrationProofCode_idx65,
    registrationInitFrame_idx5_lt, registration_locals_after_set5_idx7_lt,
    registration_locals_after_set5_set7_idx8_lt, registrationVerifyArgs_len]

/-! ### PC 66 (`immBorrowLoc 17` — borrow lhsPt) -/

@[simp] private theorem verifyRegistrationProofCode_idx66 :
    verifyRegistrationProofCode[66]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .immBorrowLoc 17 := rfl

private theorem registrationFramePc66AfterStLoc18_locals_size (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt : MoveValue) :
    (registrationFramePc66AfterStLoc18 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt).locals.size = 19 := by
  unfold registrationFramePc66AfterStLoc18
  rw [Array.size_set, registrationFramePc64_locals_size]

private theorem registrationFramePc66AfterStLoc18_localRefs_size (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt : MoveValue) :
    (registrationFramePc66AfterStLoc18 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt).localRefs.size = 19 :=
  registrationFramePc60_localRefs_size args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt

private theorem registrationFramePc66AfterStLoc18_locals_idx17_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt : MoveValue) :
    17 < (registrationFramePc66AfterStLoc18 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt).locals.size := by
  rw [registrationFramePc66AfterStLoc18_locals_size]; decide

private theorem registrationFramePc66AfterStLoc18_localRefs_idx17_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt : MoveValue) :
    17 < (registrationFramePc66AfterStLoc18 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt).localRefs.size := by
  rw [registrationFramePc66AfterStLoc18_localRefs_size]; decide

private theorem registrationFramePc22_localRefs_idx17_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    17 < (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).localRefs.size := by
  rw [registrationFramePc22_localRefs_size args h mv rCompressed sOpt sVal]; decide

private theorem registrationFramePc22_localRefs_idx17_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).localRefs[17]'
      (registrationFramePc22_localRefs_idx17_lt args h mv rCompressed sOpt sVal) = none := by
  simp [registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg, registrationFramePc20AfterStLoc11,
    registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9, registrationFramePc12AfterStLoc9,
    registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6, registrationFramePc9AfterStLoc8,
    registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow, registrationFramePc3AfterStLoc,
    registrationFrameAtPc2, registrationInitFrame]

/-! Direct: `Pc63.locals[17] = some lhsPt` because `Pc63 = stLoc 17`. -/
set_option maxHeartbeats 3200000 in
private theorem registrationFramePc63_locals_idx17_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt : MoveValue) :
    (registrationFramePc63AfterStLoc17 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt).locals[17]'
      (by rw [registrationFramePc63AfterStLoc17_locals_size]; decide) = some lhsPt := by
  unfold registrationFramePc63AfterStLoc17
  rw [Array.getElem_set_self]

/-! `Pc64.locals = Pc63.locals` since Pc64 only changes `pc`. -/
set_option maxHeartbeats 3200000 in
private theorem registrationFramePc64_locals_idx17_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt : MoveValue) :
    (registrationFramePc64AfterImmBorrow8 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt).locals[17]'
      (by rw [registrationFramePc64_locals_size]; decide) = some lhsPt :=
  registrationFramePc63_locals_idx17_eq args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt

set_option maxHeartbeats 25600000 in
private theorem registrationFramePc66AfterStLoc18_locals_idx17_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt : MoveValue) :
    (registrationFramePc66AfterStLoc18 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt).locals[17]'
      (registrationFramePc66AfterStLoc18_locals_idx17_lt args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt) =
        some lhsPt := by
  have hne : (18 : Nat) ≠ 17 := by decide
  have hsz64 := registrationFramePc64_locals_size args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt
  have hpc64 := registrationFramePc64_locals_idx17_eq args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt
  unfold registrationFramePc66AfterStLoc18
  rw [Array.getElem_set_ne (h := hne)
    (pj := by rw [hsz64]; decide)
    (h' := by rw [hsz64]; decide)]
  exact hpc64

set_option maxHeartbeats 3200000 in
private theorem registrationFramePc66AfterStLoc18_localRefs_idx17_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt : MoveValue) :
    (registrationFramePc66AfterStLoc18 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt).localRefs[17]'
      (registrationFramePc66AfterStLoc18_localRefs_idx17_lt args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt) =
        none := by
  have hne : (11 : Nat) ≠ 17 := by decide
  have hpc22 := registrationFramePc22_localRefs_idx17_eq args h mv rCompressed sOpt sVal
  have heq : (registrationFramePc66AfterStLoc18 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt).localRefs =
      (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).localRefs.set 11 none
        (registrationFramePc22_localRefs_idx11_lt args h mv rCompressed sOpt sVal) := rfl
  simp only [heq, Array.getElem_set_ne (h := hne)]
  exact hpc22

/-- Frame after `immBorrowLoc 17` (PC 66): same frame, pc := 67. -/
def registrationFramePc67AfterImmBorrow17 (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt : MoveValue) : Frame :=
  { registrationFramePc66AfterStLoc18 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt with pc := 67 }

set_option maxHeartbeats 25600000 in
theorem registration_step_pc66_immBorrowLoc17_generic (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt : MoveValue) (ms : MachineState)
    (rest : List MoveValue) :
    step (registrationModuleEnv o)
        (registrationFramePc66AfterStLoc18 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
          mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt)
        [] rest ms =
      ExecResult.ok
        (registrationFramePc67AfterImmBorrow17 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
          mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt)
        [] (.immRef (ms.containers.alloc lhsPt).2 :: rest)
        { ms with containers := (ms.containers.alloc lhsPt).1 } := by
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  let hlen : args.length = 7 := registrationVerifyArgs_len _ _ _ _ _ _ _
  set fr' := registrationFramePc66AfterStLoc18 args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt
    with hfr'
  have hpc : fr'.pc < fr'.code.size := by
    simp [fr', registrationFramePc66AfterStLoc18, registrationFramePc64AfterImmBorrow8,
      registrationFramePc63AfterStLoc17, registrationFramePc61AfterImmBorrow16,
      registrationFramePc60AfterStLoc16, registrationFramePc58AfterImmBorrow12,
      registrationFramePc57AfterImmBorrow14, registrationFramePc56AfterImmBorrow15,
      registrationFramePc55AfterStLoc15, registrationFramePc53AfterImmBorrow10,
      registrationFramePc52AfterImmBorrow13, registrationFramePc51AfterStLoc14, registrationFramePc49AfterMoveLoc3,
      registrationFramePc48AfterStLoc13, registrationFramePc46AfterStLoc12, registrationFramePc44AfterMoveLoc11,
      registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
      registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
      registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
      registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
      registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame,
      verifyRegistrationProofCode_size_val]
  have hc : fr'.code[fr'.pc]'hpc = MoveInstr.immBorrowLoc 17 := by
    simp [fr', registrationFramePc66AfterStLoc18, registrationFramePc64AfterImmBorrow8,
      registrationFramePc63AfterStLoc17, registrationFramePc61AfterImmBorrow16,
      registrationFramePc60AfterStLoc16, registrationFramePc58AfterImmBorrow12,
      registrationFramePc57AfterImmBorrow14, registrationFramePc56AfterImmBorrow15,
      registrationFramePc55AfterStLoc15, registrationFramePc53AfterImmBorrow10,
      registrationFramePc52AfterImmBorrow13, registrationFramePc51AfterStLoc14, registrationFramePc49AfterMoveLoc3,
      registrationFramePc48AfterStLoc13, registrationFramePc46AfterStLoc12, registrationFramePc44AfterMoveLoc11,
      registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
      registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
      registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
      registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
      registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame,
      verifyRegistrationProofCode_size_val, verifyRegistrationProofCode_idx66]
  have hlocLt : 17 < fr'.locals.size :=
    registrationFramePc66AfterStLoc18_locals_idx17_lt args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt
  have hlocVal : fr'.locals[17]'hlocLt = some lhsPt :=
    registrationFramePc66AfterStLoc18_locals_idx17_eq args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt
  have hlocRefLt : 17 < fr'.localRefs.size :=
    registrationFramePc66AfterStLoc18_localRefs_idx17_lt args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt
  have hlocRefVal : fr'.localRefs[17]'hlocRefLt = none :=
    registrationFramePc66AfterStLoc18_localRefs_idx17_eq args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt
  simp only [step, dif_pos hpc, hc, dif_pos hlocLt, hlocVal, dif_pos hlocRefLt, hlocRefVal]
  rfl

/-! ### PC 67 (`immBorrowLoc 18` — borrow rhsPt) -/

@[simp] private theorem verifyRegistrationProofCode_idx67 :
    verifyRegistrationProofCode[67]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .immBorrowLoc 18 := rfl

private theorem registrationFramePc67_locals_size (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt : MoveValue) :
    (registrationFramePc67AfterImmBorrow17 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt).locals.size = 19 :=
  registrationFramePc66AfterStLoc18_locals_size args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt

private theorem registrationFramePc67_localRefs_size (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt : MoveValue) :
    (registrationFramePc67AfterImmBorrow17 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt).localRefs.size = 19 :=
  registrationFramePc66AfterStLoc18_localRefs_size args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt

private theorem registrationFramePc67_locals_idx18_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt : MoveValue) :
    18 < (registrationFramePc67AfterImmBorrow17 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt).locals.size := by
  rw [registrationFramePc67_locals_size]; decide

private theorem registrationFramePc67_localRefs_idx18_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt : MoveValue) :
    18 < (registrationFramePc67AfterImmBorrow17 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt).localRefs.size := by
  rw [registrationFramePc67_localRefs_size]; decide

/-- Direct: `Pc66.locals[18] = some rhsPt` because `Pc66 = stLoc 18`. -/
private theorem registrationFramePc66_locals_idx18_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt : MoveValue) :
    (registrationFramePc66AfterStLoc18 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt).locals[18]'
      (by rw [registrationFramePc66AfterStLoc18_locals_size]; decide) = some rhsPt := by
  unfold registrationFramePc66AfterStLoc18
  rw [Array.getElem_set_self]

set_option maxHeartbeats 25600000 in
private theorem registrationFramePc67_locals_idx18_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt : MoveValue) :
    (registrationFramePc67AfterImmBorrow17 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt).locals[18]'
      (registrationFramePc67_locals_idx18_lt args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt) =
        some rhsPt :=
  registrationFramePc66_locals_idx18_eq args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt

private theorem registrationFramePc22_localRefs_idx18_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    18 < (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).localRefs.size := by
  rw [registrationFramePc22_localRefs_size args h mv rCompressed sOpt sVal]; decide

private theorem registrationFramePc22_localRefs_idx18_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).localRefs[18]'
      (registrationFramePc22_localRefs_idx18_lt args h mv rCompressed sOpt sVal) = none := by
  simp [registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg, registrationFramePc20AfterStLoc11,
    registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9, registrationFramePc12AfterStLoc9,
    registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6, registrationFramePc9AfterStLoc8,
    registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow, registrationFramePc3AfterStLoc,
    registrationFrameAtPc2, registrationInitFrame]

set_option maxHeartbeats 3200000 in
private theorem registrationFramePc67_localRefs_idx18_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt : MoveValue) :
    (registrationFramePc67AfterImmBorrow17 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt).localRefs[18]'
      (registrationFramePc67_localRefs_idx18_lt args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt) =
        none := by
  have hne : (11 : Nat) ≠ 18 := by decide
  have hpc22 := registrationFramePc22_localRefs_idx18_eq args h mv rCompressed sOpt sVal
  have heq : (registrationFramePc67AfterImmBorrow17 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt).localRefs =
      (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).localRefs.set 11 none
        (registrationFramePc22_localRefs_idx11_lt args h mv rCompressed sOpt sVal) := rfl
  simp only [heq, Array.getElem_set_ne (h := hne)]
  exact hpc22

/-- Frame after `immBorrowLoc 18` (PC 67): same frame, pc := 68. -/
def registrationFramePc68AfterImmBorrow18 (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt : MoveValue) : Frame :=
  { registrationFramePc67AfterImmBorrow17 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt with pc := 68 }

set_option maxHeartbeats 25600000 in
theorem registration_step_pc67_immBorrowLoc18_generic (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt : MoveValue) (ms : MachineState)
    (rest : List MoveValue) :
    step (registrationModuleEnv o)
        (registrationFramePc67AfterImmBorrow17 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
          mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt)
        [] rest ms =
      ExecResult.ok
        (registrationFramePc68AfterImmBorrow18 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
          mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt)
        [] (.immRef (ms.containers.alloc rhsPt).2 :: rest)
        { ms with containers := (ms.containers.alloc rhsPt).1 } := by
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  let hlen : args.length = 7 := registrationVerifyArgs_len _ _ _ _ _ _ _
  set fr' := registrationFramePc67AfterImmBorrow17 args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt
    with hfr'
  have hpc : fr'.pc < fr'.code.size := by
    simp [fr', registrationFramePc67AfterImmBorrow17, registrationFramePc66AfterStLoc18,
      registrationFramePc64AfterImmBorrow8, registrationFramePc63AfterStLoc17,
      registrationFramePc61AfterImmBorrow16, registrationFramePc60AfterStLoc16,
      registrationFramePc58AfterImmBorrow12, registrationFramePc57AfterImmBorrow14, registrationFramePc56AfterImmBorrow15,
      registrationFramePc55AfterStLoc15, registrationFramePc53AfterImmBorrow10,
      registrationFramePc52AfterImmBorrow13, registrationFramePc51AfterStLoc14, registrationFramePc49AfterMoveLoc3,
      registrationFramePc48AfterStLoc13, registrationFramePc46AfterStLoc12, registrationFramePc44AfterMoveLoc11,
      registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
      registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
      registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
      registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
      registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame,
      verifyRegistrationProofCode_size_val]
  have hc : fr'.code[fr'.pc]'hpc = MoveInstr.immBorrowLoc 18 := by
    simp [fr', registrationFramePc67AfterImmBorrow17, registrationFramePc66AfterStLoc18,
      registrationFramePc64AfterImmBorrow8, registrationFramePc63AfterStLoc17,
      registrationFramePc61AfterImmBorrow16, registrationFramePc60AfterStLoc16,
      registrationFramePc58AfterImmBorrow12, registrationFramePc57AfterImmBorrow14, registrationFramePc56AfterImmBorrow15,
      registrationFramePc55AfterStLoc15, registrationFramePc53AfterImmBorrow10,
      registrationFramePc52AfterImmBorrow13, registrationFramePc51AfterStLoc14, registrationFramePc49AfterMoveLoc3,
      registrationFramePc48AfterStLoc13, registrationFramePc46AfterStLoc12, registrationFramePc44AfterMoveLoc11,
      registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
      registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
      registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
      registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
      registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame,
      verifyRegistrationProofCode_size_val, verifyRegistrationProofCode_idx67]
  have hlocLt : 18 < fr'.locals.size :=
    registrationFramePc67_locals_idx18_lt args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt
  have hlocVal : fr'.locals[18]'hlocLt = some rhsPt :=
    registrationFramePc67_locals_idx18_eq args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt
  have hlocRefLt : 18 < fr'.localRefs.size :=
    registrationFramePc67_localRefs_idx18_lt args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt
  have hlocRefVal : fr'.localRefs[18]'hlocRefLt = none :=
    registrationFramePc67_localRefs_idx18_eq args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt
  simp only [step, dif_pos hpc, hc, dif_pos hlocLt, hlocVal, dif_pos hlocRefLt, hlocRefVal]
  rfl

/-! ### PC 68 (`call 15` = `point_equals` for lhsPt = rhsPt) -/

@[simp] private theorem verifyRegistrationProofCode_idx68 :
    verifyRegistrationProofCode[68]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .call 15 := rfl

private theorem registration_env_funcIdx15_lt (o : RegistrationNativeOracle) :
    15 < (registrationModuleEnv o).functions.size := by
  rw [registration_module_env_size o]; decide

private theorem registrationModuleEnv_functions_at15 (o : RegistrationNativeOracle)
    (h : 15 < (registrationModuleEnv o).functions.size) :
    (registrationModuleEnv o).functions[15]'h =
      { numParams := 2, numReturns := 1, body := .nativeRef (wrapOracleImmRef2 o.pointEquals) } := by
  simp [registrationModuleEnv]

set_option maxHeartbeats 3200000 in
theorem registration_step_pc68_call_pointEquals_generic (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt : MoveValue) (ms : MachineState)
    (ridLhs ridRhs : RefId) (lhsVal rhsVal : MoveValue) (b : Bool) (restBelow : List MoveValue)
    (hreadLhs : ms.containers.read ridLhs = some lhsVal)
    (hreadRhs : ms.containers.read ridRhs = some rhsVal)
    (horacle : o.pointEquals [lhsVal, rhsVal] = some [.bool b]) :
    step (registrationModuleEnv o)
        (registrationFramePc68AfterImmBorrow18 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
          mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt)
        [] (.immRef ridRhs :: .immRef ridLhs :: restBelow) ms =
      ExecResult.ok
        ({ registrationFramePc68AfterImmBorrow18 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
              mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt with
            pc := 69 })
        [] (.bool b :: restBelow) ms := by
  have hnative : wrapOracleImmRef2 o.pointEquals ms.containers
        [.immRef ridLhs, .immRef ridRhs] =
      some ([.bool b], ms.containers) := by
    show (Option.bind (derefImm ms.containers (.immRef ridLhs))
          (fun v1 => Option.bind (derefImm ms.containers (.immRef ridRhs))
            (fun v2 => Option.bind (o.pointEquals [v1, v2])
              (fun results => some (results, ms.containers))))) =
        some ([.bool b], ms.containers)
    simp only [derefImm]
    rw [hreadLhs]
    simp only [Option.bind_some]
    rw [hreadRhs]
    simp only [Option.bind_some]
    rw [horacle]
    rfl
  simp only [step, registrationModuleEnv, registrationFramePc68AfterImmBorrow18,
    registrationFramePc67AfterImmBorrow17, registrationFramePc66AfterStLoc18,
    registrationFramePc64AfterImmBorrow8, registrationFramePc63AfterStLoc17,
    registrationFramePc61AfterImmBorrow16, registrationFramePc60AfterStLoc16,
    registrationFramePc58AfterImmBorrow12, registrationFramePc57AfterImmBorrow14, registrationFramePc56AfterImmBorrow15,
    registrationFramePc55AfterStLoc15, registrationFramePc53AfterImmBorrow10,
    registrationFramePc52AfterImmBorrow13, registrationFramePc51AfterStLoc14, registrationFramePc49AfterMoveLoc3,
    registrationFramePc48AfterStLoc13, registrationFramePc46AfterStLoc12, registrationFramePc44AfterMoveLoc11,
    registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
    registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
    registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
    registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
    registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame, registrationVerifyArgs,
    verifyRegistrationProofCode, verifyRegistrationProofCode_size_val, verifyRegistrationProofCode_idx68,
    registrationInitFrame_idx5_lt, registration_locals_after_set5_idx7_lt, registrationVerifyArgs_len,
    registration_env_funcIdx15_lt, registrationModuleEnv_functions_at15, FuncDesc.body,
    takeN_two_cons_cons, List.map_cons, List.map_nil, Nat.reduceSub, List.reduceReplicate,
    List.cons_append, List.nil_append, List.size_toArray, List.length_cons, List.length_nil, zero_add,
    Nat.reduceAdd, Nat.reduceLT, Nat.one_lt_ofNat, ↓reduceDIte, List.getElem_toArray, List.getElem_cons_succ,
    List.getElem_cons_zero, Nat.ofNat_pos, Nat.reduceBEq, Bool.false_eq_true, BEq.rfl, List.set_toArray,
    List.set_cons_succ, List.set_cons_zero, beq_iff_eq]
  rw [hnative]
  simp only [handleNativeResult_ret1]

/-! ### PC 69 (`brFalse 71` — branch on equality result) -/

@[simp] private theorem verifyRegistrationProofCode_idx69 :
    verifyRegistrationProofCode[69]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .brFalse 71 := rfl

set_option maxHeartbeats 3200000 in
theorem registration_step_pc69_brFalse_true_generic (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt : MoveValue) (ms : MachineState)
    (rest : List MoveValue) :
    step (registrationModuleEnv o)
        ({ registrationFramePc68AfterImmBorrow18 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
              mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt with
            pc := 69 })
        [] (.bool true :: rest) ms =
      ExecResult.ok
        ({ registrationFramePc68AfterImmBorrow18 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
              mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt with
            pc := 70 })
        [] rest ms := by
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  let hlen : args.length = 7 := registrationVerifyArgs_len _ _ _ _ _ _ _
  set fr' := ({ registrationFramePc68AfterImmBorrow18 args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt with pc := 69 })
    with hfr'
  have hpc : fr'.pc < fr'.code.size := by
    simp [fr', registrationFramePc68AfterImmBorrow18, registrationFramePc67AfterImmBorrow17,
      registrationFramePc66AfterStLoc18, registrationFramePc64AfterImmBorrow8, registrationFramePc63AfterStLoc17,
      registrationFramePc61AfterImmBorrow16, registrationFramePc60AfterStLoc16,
      registrationFramePc58AfterImmBorrow12, registrationFramePc57AfterImmBorrow14, registrationFramePc56AfterImmBorrow15,
      registrationFramePc55AfterStLoc15, registrationFramePc53AfterImmBorrow10,
      registrationFramePc52AfterImmBorrow13, registrationFramePc51AfterStLoc14, registrationFramePc49AfterMoveLoc3,
      registrationFramePc48AfterStLoc13, registrationFramePc46AfterStLoc12, registrationFramePc44AfterMoveLoc11,
      registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
      registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
      registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
      registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
      registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame,
      verifyRegistrationProofCode_size_val]
  have hc : fr'.code[fr'.pc]'hpc = MoveInstr.brFalse 71 := by
    simp [fr', registrationFramePc68AfterImmBorrow18, registrationFramePc67AfterImmBorrow17,
      registrationFramePc66AfterStLoc18, registrationFramePc64AfterImmBorrow8, registrationFramePc63AfterStLoc17,
      registrationFramePc61AfterImmBorrow16, registrationFramePc60AfterStLoc16,
      registrationFramePc58AfterImmBorrow12, registrationFramePc57AfterImmBorrow14, registrationFramePc56AfterImmBorrow15,
      registrationFramePc55AfterStLoc15, registrationFramePc53AfterImmBorrow10,
      registrationFramePc52AfterImmBorrow13, registrationFramePc51AfterStLoc14, registrationFramePc49AfterMoveLoc3,
      registrationFramePc48AfterStLoc13, registrationFramePc46AfterStLoc12, registrationFramePc44AfterMoveLoc11,
      registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
      registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
      registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
      registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
      registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame,
      verifyRegistrationProofCode_size_val, verifyRegistrationProofCode_idx69]
  exact step_brFalse_true_stack (registrationModuleEnv o) fr' [] 71 rest ms hpc hc

set_option maxHeartbeats 3200000 in
theorem registration_step_pc69_brFalse_false_generic (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt : MoveValue) (ms : MachineState)
    (rest : List MoveValue) :
    step (registrationModuleEnv o)
        ({ registrationFramePc68AfterImmBorrow18 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
              mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt with
            pc := 69 })
        [] (.bool false :: rest) ms =
      ExecResult.ok
        ({ registrationFramePc68AfterImmBorrow18 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
              mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt with
            pc := 71 })
        [] rest ms := by
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  let hlen : args.length = 7 := registrationVerifyArgs_len _ _ _ _ _ _ _
  set fr' := ({ registrationFramePc68AfterImmBorrow18 args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt with pc := 69 })
    with hfr'
  have hpc : fr'.pc < fr'.code.size := by
    simp [fr', registrationFramePc68AfterImmBorrow18, registrationFramePc67AfterImmBorrow17,
      registrationFramePc66AfterStLoc18, registrationFramePc64AfterImmBorrow8, registrationFramePc63AfterStLoc17,
      registrationFramePc61AfterImmBorrow16, registrationFramePc60AfterStLoc16,
      registrationFramePc58AfterImmBorrow12, registrationFramePc57AfterImmBorrow14, registrationFramePc56AfterImmBorrow15,
      registrationFramePc55AfterStLoc15, registrationFramePc53AfterImmBorrow10,
      registrationFramePc52AfterImmBorrow13, registrationFramePc51AfterStLoc14, registrationFramePc49AfterMoveLoc3,
      registrationFramePc48AfterStLoc13, registrationFramePc46AfterStLoc12, registrationFramePc44AfterMoveLoc11,
      registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
      registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
      registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
      registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
      registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame,
      verifyRegistrationProofCode_size_val]
  have hc : fr'.code[fr'.pc]'hpc = MoveInstr.brFalse 71 := by
    simp [fr', registrationFramePc68AfterImmBorrow18, registrationFramePc67AfterImmBorrow17,
      registrationFramePc66AfterStLoc18, registrationFramePc64AfterImmBorrow8, registrationFramePc63AfterStLoc17,
      registrationFramePc61AfterImmBorrow16, registrationFramePc60AfterStLoc16,
      registrationFramePc58AfterImmBorrow12, registrationFramePc57AfterImmBorrow14, registrationFramePc56AfterImmBorrow15,
      registrationFramePc55AfterStLoc15, registrationFramePc53AfterImmBorrow10,
      registrationFramePc52AfterImmBorrow13, registrationFramePc51AfterStLoc14, registrationFramePc49AfterMoveLoc3,
      registrationFramePc48AfterStLoc13, registrationFramePc46AfterStLoc12, registrationFramePc44AfterMoveLoc11,
      registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
      registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
      registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
      registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
      registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame,
      verifyRegistrationProofCode_size_val, verifyRegistrationProofCode_idx69]
  exact step_brFalse_false_stack (registrationModuleEnv o) fr' [] 71 rest ms hpc hc

/-! ### PC 70 (`ret` — return from function) -/

@[simp] private theorem verifyRegistrationProofCode_idx70 :
    verifyRegistrationProofCode[70]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .ret := rfl

set_option maxHeartbeats 3200000 in
theorem registration_step_pc70_ret_generic (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt : MoveValue) (ms : MachineState)
    (rest : List MoveValue) :
    step (registrationModuleEnv o)
        ({ registrationFramePc68AfterImmBorrow18 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
              mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt with
            pc := 70 })
        [] rest ms =
      ExecResult.returned rest ms := by
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  let hlen : args.length = 7 := registrationVerifyArgs_len _ _ _ _ _ _ _
  set fr' := ({ registrationFramePc68AfterImmBorrow18 args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt with pc := 70 })
    with hfr'
  have hpc : fr'.pc < fr'.code.size := by
    simp [fr', registrationFramePc68AfterImmBorrow18, registrationFramePc67AfterImmBorrow17,
      registrationFramePc66AfterStLoc18, registrationFramePc64AfterImmBorrow8, registrationFramePc63AfterStLoc17,
      registrationFramePc61AfterImmBorrow16, registrationFramePc60AfterStLoc16,
      registrationFramePc58AfterImmBorrow12, registrationFramePc57AfterImmBorrow14, registrationFramePc56AfterImmBorrow15,
      registrationFramePc55AfterStLoc15, registrationFramePc53AfterImmBorrow10,
      registrationFramePc52AfterImmBorrow13, registrationFramePc51AfterStLoc14, registrationFramePc49AfterMoveLoc3,
      registrationFramePc48AfterStLoc13, registrationFramePc46AfterStLoc12, registrationFramePc44AfterMoveLoc11,
      registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
      registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
      registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
      registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
      registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame,
      verifyRegistrationProofCode_size_val]
  have hc : fr'.code[fr'.pc]'hpc = MoveInstr.ret := by
    simp [fr', registrationFramePc68AfterImmBorrow18, registrationFramePc67AfterImmBorrow17,
      registrationFramePc66AfterStLoc18, registrationFramePc64AfterImmBorrow8, registrationFramePc63AfterStLoc17,
      registrationFramePc61AfterImmBorrow16, registrationFramePc60AfterStLoc16,
      registrationFramePc58AfterImmBorrow12, registrationFramePc57AfterImmBorrow14, registrationFramePc56AfterImmBorrow15,
      registrationFramePc55AfterStLoc15, registrationFramePc53AfterImmBorrow10,
      registrationFramePc52AfterImmBorrow13, registrationFramePc51AfterStLoc14, registrationFramePc49AfterMoveLoc3,
      registrationFramePc48AfterStLoc13, registrationFramePc46AfterStLoc12, registrationFramePc44AfterMoveLoc11,
      registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
      registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
      registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
      registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
      registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame,
      verifyRegistrationProofCode_size_val, verifyRegistrationProofCode_idx70]
  simp only [step, dif_pos hpc, hc]

/-- PC 8: `stLoc 8` — pop `rCompressed`, store in local 8, PC→9. -/
theorem registration_step_pc8_stLoc8 (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed : MoveValue) :
    step (registrationModuleEnv o)
        ({ registrationFramePc7AfterMutBorrowLoc7 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv with pc := 8 })
        [] [rCompressed] (registrationMsAfterOptionExtractDup1 mv) =
      ExecResult.ok
        (registrationFramePc9AfterStLoc8 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed)
        [] [] (registrationMsAfterOptionExtractDup1 mv) := by
  simp [step, registrationModuleEnv, registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7,
    registrationFramePc4AfterImmBorrow, registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame,
    registrationVerifyArgs, verifyRegistrationProofCode, verifyRegistrationProofCode_size_val,
    verifyRegistrationProofCode_idx8, registrationInitFrame_idx5_lt, registration_locals_after_set5_idx7_lt,
    registration_locals_after_set5_set7_idx8_lt, registrationVerifyArgs_len]

/-- Four `ok` steps: PC 2→3→4→5→6 with `mv = Option<CompressedPoint>` struct tag `true` on the `is_some` path. -/
theorem registration_run_from_pc2_to_pc6_somePath
    (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv : MoveValue) (tag : Bool) (rest : List MoveValue)
    (hmv : mv = .struct_ (.bool tag :: rest)) (htag : tag = true)
    (fuel : Nat) (_hf : 6 ≤ fuel) :
    run (registrationModuleEnv o)
        (registrationFrameAtPc2 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa))
        [] [mv] MachineState.empty (fuel - 2) =
      run (registrationModuleEnv o)
        ({ registrationFramePc4AfterImmBorrow (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv with
            pc := 6 })
        [] [] (registrationMsAfterImmBorrow7 mv) (fuel - 6) := by
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  let hlen := registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa
  have hfuel : fuel - 2 = (fuel - 6) + 4 := by omega
  rw [hfuel]
  have hs2 :=
    registration_step_pc2_stLoc7 o chainId sender contract token ekBa commitBa respBa mv
  have hs3 :=
    registration_step_pc3_immBorrowLoc7 o chainId sender contract token ekBa commitBa respBa mv
  have hs4 :=
    registration_step_pc4_call_optionIsSome o chainId sender contract token ekBa commitBa respBa mv tag rest hmv
  have hs5 := registration_step_pc5_brFalse_fallthrough o chainId sender contract token ekBa commitBa respBa mv tag rest htag
  exact run_succ_succ_succ_succ_ok (registrationModuleEnv o)
    (registrationFrameAtPc2 args hlen)
    (registrationFramePc3AfterStLoc args hlen mv)
    (registrationFramePc4AfterImmBorrow args hlen mv)
    ({ registrationFramePc4AfterImmBorrow args hlen mv with pc := 5 })
    ({ registrationFramePc4AfterImmBorrow args hlen mv with pc := 6 })
    []
    [mv] [] [.immRef 0] [.bool tag] []
    MachineState.empty MachineState.empty (registrationMsAfterImmBorrow7 mv) (registrationMsAfterImmBorrow7 mv)
      (registrationMsAfterImmBorrow7 mv)
    (fuel - 6) hs2 hs3 hs4 hs5

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

/-- From function entry through PC 6 on the `option::is_some` / `brFalse` fall-through path
(singleton decompress + struct tag `true`). -/
theorem registration_run_from_entry_to_pc6_somePath
    (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv : MoveValue) (tag : Bool) (rest : List MoveValue)
    (hmv : mv = .struct_ (.bool tag :: rest)) (htag : tag = true)
    (fuel : Nat) (hf : 6 ≤ fuel)
    (hl : o.newCompressedPointFromBytes [.vector .u8 (commitBa.toList.map .u8)] = some [mv]) :
    run (registrationModuleEnv o)
        (registrationInitFrame (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa))
        [] [] MachineState.empty fuel =
      run (registrationModuleEnv o)
        ({ registrationFramePc4AfterImmBorrow (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv with
            pc := 6 })
        [] [] (registrationMsAfterImmBorrow7 mv) (fuel - 6) := by
  have hf2 : 2 ≤ fuel := by omega
  rw [registration_run_eq_from_pc2_singleton o chainId sender contract token ekBa commitBa respBa mv fuel hf2 hl]
  exact registration_run_from_pc2_to_pc6_somePath o chainId sender contract token ekBa commitBa respBa mv tag rest hmv htag
    fuel hf

/-! ## Run-chain: three-step helper (PC 6 → 7 → 8 → 9 success) -/

theorem run_succ_succ_succ_ok (env : ModuleEnv) (f₀ f₁ f₂ f₃ : Frame) (cs : List Frame)
    (s₀ s₁ s₂ s₃ : List MoveValue) (ms₀ ms₁ ms₂ ms₃ : MachineState) (n : Nat)
    (h₀ : step env f₀ cs s₀ ms₀ = ExecResult.ok f₁ cs s₁ ms₁)
    (h₁ : step env f₁ cs s₁ ms₁ = ExecResult.ok f₂ cs s₂ ms₂)
    (h₂ : step env f₂ cs s₂ ms₂ = ExecResult.ok f₃ cs s₃ ms₃) :
    run env f₀ cs s₀ ms₀ n.succ.succ.succ = run env f₃ cs s₃ ms₃ n := by
  simp only [run, h₀, run, h₁, run, h₂]

/-- From `pc 6` (after PC 5 fall-through) through PCs 6 (mutBorrowLoc 7), 7 (call 2 optionExtract)
and 8 (stLoc 8) to the start of PC 9. -/
theorem registration_run_from_pc6_to_pc9_somePath
    (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed : MoveValue) (rest : List MoveValue)
    (hmv : mv = .struct_ (.bool true :: rCompressed :: rest))
    (fuel : Nat) (_hf : 3 ≤ fuel) :
    run (registrationModuleEnv o)
        ({ registrationFramePc4AfterImmBorrow (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv with pc := 6 })
        [] [] (registrationMsAfterImmBorrow7 mv) fuel =
      run (registrationModuleEnv o)
        (registrationFramePc9AfterStLoc8 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed)
        [] [] (registrationMsAfterOptionExtractDup1 mv) (fuel - 3) := by
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  let hlen := registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa
  have hfuel : fuel = (fuel - 3) + 3 := by omega
  rw [hfuel]
  have hs6 := registration_step_pc6_mutBorrowLoc7 o chainId sender contract token ekBa commitBa respBa mv
  have hs7 := registration_step_pc7_call_optionExtract o chainId sender contract token ekBa commitBa respBa mv rCompressed rest hmv
  have hs8 := registration_step_pc8_stLoc8 o chainId sender contract token ekBa commitBa respBa mv rCompressed
  exact run_succ_succ_succ_ok (registrationModuleEnv o)
    ({ registrationFramePc4AfterImmBorrow args hlen mv with pc := 6 })
    (registrationFramePc7AfterMutBorrowLoc7 args hlen mv)
    ({ registrationFramePc7AfterMutBorrowLoc7 args hlen mv with pc := 8 })
    (registrationFramePc9AfterStLoc8 args hlen mv rCompressed)
    []
    [] [.mutRef 1] [rCompressed] []
    (registrationMsAfterImmBorrow7 mv)
    (registrationMsAfterMutBorrowDup7 mv)
    (registrationMsAfterOptionExtractDup1 mv)
    (registrationMsAfterOptionExtractDup1 mv)
    (fuel - 3) hs6 hs7 hs8

/-- From `pc 9` through PCs 9 (moveLoc 6), 10 (call 3 = newScalarFromBytes), 11 (stLoc 9)
to the start of PC 12, given the singleton `newScalarFromBytes` hypothesis. -/
theorem registration_run_from_pc9_to_pc12_singletonPath
    (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt : MoveValue)
    (hs : o.newScalarFromBytes [.vector .u8 (respBa.toList.map .u8)] = some [sOpt])
    (fuel : Nat) (_hf : 3 ≤ fuel) :
    run (registrationModuleEnv o)
        (registrationFramePc9AfterStLoc8 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed)
        [] [] (registrationMsAfterOptionExtractDup1 mv) fuel =
      run (registrationModuleEnv o)
        (registrationFramePc12AfterStLoc9 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt)
        [] [] (registrationMsAfterOptionExtractDup1 mv) (fuel - 3) := by
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  let hlen := registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa
  have hfuel : fuel = (fuel - 3) + 3 := by omega
  rw [hfuel]
  have hs9 := registration_step_pc9_moveLoc6 o chainId sender contract token ekBa commitBa respBa mv rCompressed
  have hs10 := registration_step_pc10_call3_singleton o chainId sender contract token ekBa commitBa respBa mv rCompressed sOpt hs
  have hs11 := registration_step_pc11_stLoc9 o chainId sender contract token ekBa commitBa respBa mv rCompressed sOpt
  exact run_succ_succ_succ_ok (registrationModuleEnv o)
    (registrationFramePc9AfterStLoc8 args hlen mv rCompressed)
    (registrationFramePc10AfterMoveLoc6 args hlen mv rCompressed)
    (registrationFramePc11AfterCall3 args hlen mv rCompressed)
    (registrationFramePc12AfterStLoc9 args hlen mv rCompressed sOpt)
    []
    [] [.vector .u8 (respBa.toList.map .u8)] [sOpt] []
    (registrationMsAfterOptionExtractDup1 mv)
    (registrationMsAfterOptionExtractDup1 mv)
    (registrationMsAfterOptionExtractDup1 mv)
    (registrationMsAfterOptionExtractDup1 mv)
    (fuel - 3) hs9 hs10 hs11

/-- From `pc 12` through PCs 12 (immBorrowLoc 9), 13 (call 1 isSome on &sOpt),
14 (brFalse 74 fallthrough when stag=true) to `pc := 15`. -/
theorem registration_run_from_pc12_to_pc15_someSOptPath
    (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt : MoveValue) (stag : Bool) (srest : List MoveValue)
    (hsOpt : sOpt = .struct_ (.bool stag :: srest)) (hstag : stag = true)
    (fuel : Nat) (_hf : 3 ≤ fuel) :
    run (registrationModuleEnv o)
        (registrationFramePc12AfterStLoc9 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt)
        [] [] (registrationMsAfterOptionExtractDup1 mv) fuel =
      run (registrationModuleEnv o)
        ({ registrationFramePc12AfterStLoc9 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt with
            pc := 15 })
        [] [] (registrationMsAfterImmBorrow9 mv sOpt) (fuel - 3) := by
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  let hlen := registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa
  have hfuel : fuel = (fuel - 3) + 3 := by omega
  rw [hfuel]
  have hs12 := registration_step_pc12_immBorrowLoc9 o chainId sender contract token ekBa commitBa respBa mv rCompressed sOpt
  have hs13 := registration_step_pc13_call_optionIsSome o chainId sender contract token ekBa commitBa respBa mv rCompressed sOpt stag srest hsOpt
  have hs14 := registration_step_pc14_brFalse_fallthrough o chainId sender contract token ekBa commitBa respBa mv rCompressed sOpt stag srest hstag
  exact run_succ_succ_succ_ok (registrationModuleEnv o)
    (registrationFramePc12AfterStLoc9 args hlen mv rCompressed sOpt)
    ({ registrationFramePc12AfterStLoc9 args hlen mv rCompressed sOpt with pc := 13 })
    ({ registrationFramePc12AfterStLoc9 args hlen mv rCompressed sOpt with pc := 14 })
    ({ registrationFramePc12AfterStLoc9 args hlen mv rCompressed sOpt with pc := 15 })
    []
    [] [.immRef 2] [.bool stag] []
    (registrationMsAfterOptionExtractDup1 mv)
    (registrationMsAfterImmBorrow9 mv sOpt)
    (registrationMsAfterImmBorrow9 mv sOpt)
    (registrationMsAfterImmBorrow9 mv sOpt)
    (fuel - 3) hs12 hs13 hs14

/-- From `pc 15` through PCs 15 (mutBorrowLoc 9), 16 (call 2 extract on &mut sOpt),
17 (stLoc 10 for sVal) to pre-PC 18. -/
theorem registration_run_from_pc15_to_pc18_singletonSomePath
    (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal : MoveValue) (srest' : List MoveValue)
    (hsOpt : sOpt = .struct_ (.bool true :: sVal :: srest'))
    (fuel : Nat) (_hf : 3 ≤ fuel) :
    run (registrationModuleEnv o)
        ({ registrationFramePc12AfterStLoc9 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt with
            pc := 15 })
        [] [] (registrationMsAfterImmBorrow9 mv sOpt) fuel =
      run (registrationModuleEnv o)
        (registrationFramePc18AfterStLoc10 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal)
        [] [] (registrationMsAfterOptionExtractDup3 mv sOpt) (fuel - 3) := by
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  let hlen := registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa
  have hfuel : fuel = (fuel - 3) + 3 := by omega
  rw [hfuel]
  have hs15 := registration_step_pc15_mutBorrowLoc9 o chainId sender contract token ekBa commitBa respBa mv rCompressed sOpt
  have hs16 := registration_step_pc16_call_optionExtract o chainId sender contract token ekBa commitBa respBa mv rCompressed sOpt sVal srest' hsOpt
  have hs17 := registration_step_pc17_stLoc10 o chainId sender contract token ekBa commitBa respBa mv rCompressed sOpt sVal
  exact run_succ_succ_succ_ok (registrationModuleEnv o)
    ({ registrationFramePc12AfterStLoc9 args hlen mv rCompressed sOpt with pc := 15 })
    (registrationFramePc16AfterMutBorrow9 args hlen mv rCompressed sOpt)
    ({ registrationFramePc16AfterMutBorrow9 args hlen mv rCompressed sOpt with pc := 17 })
    (registrationFramePc18AfterStLoc10 args hlen mv rCompressed sOpt sVal)
    []
    [] [.mutRef 3] [sVal] []
    (registrationMsAfterImmBorrow9 mv sOpt)
    (registrationMsAfterMutBorrow9 mv sOpt)
    (registrationMsAfterOptionExtractDup3 mv sOpt)
    (registrationMsAfterOptionExtractDup3 mv sOpt)
    (fuel - 3) hs15 hs16 hs17

/-- From `pc 18` through PCs 18 (ldConst 5 DST), 19 (stLoc 11 for msg) to pre-PC 20. -/
theorem registration_run_from_pc18_to_pc20_path
    (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal : MoveValue)
    (fuel : Nat) (_hf : 2 ≤ fuel) :
    run (registrationModuleEnv o)
        (registrationFramePc18AfterStLoc10 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal)
        [] [] (registrationMsAfterOptionExtractDup3 mv sOpt) fuel =
      run (registrationModuleEnv o)
        (registrationFramePc20AfterStLoc11 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal)
        [] [] (registrationMsAfterOptionExtractDup3 mv sOpt) (fuel - 2) := by
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  let hlen := registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa
  have hfuel : fuel = (fuel - 2) + 2 := by omega
  rw [hfuel]
  have hs18 := registration_step_pc18_ldConst5 o chainId sender contract token ekBa commitBa respBa mv rCompressed sOpt sVal
  have hs19 := registration_step_pc19_stLoc11 o chainId sender contract token ekBa commitBa respBa mv rCompressed sOpt sVal
  exact run_succ_succ_ok (registrationModuleEnv o)
    (registrationFramePc18AfterStLoc10 args hlen mv rCompressed sOpt sVal)
    ({ registrationFramePc18AfterStLoc10 args hlen mv rCompressed sOpt sVal with pc := 19 })
    (registrationFramePc20AfterStLoc11 args hlen mv rCompressed sOpt sVal)
    []
    [] [fiatShamirRegistrationDstValue] []
    (registrationMsAfterOptionExtractDup3 mv sOpt)
    (registrationMsAfterOptionExtractDup3 mv sOpt)
    (registrationMsAfterOptionExtractDup3 mv sOpt)
    (fuel - 2) hs18 hs19

/-- From `pc 20` through PCs 20 (mutBorrowLoc 11 alloc msg), 21 (moveLoc 0 push chainId) to pre-PC 22. -/
theorem registration_run_from_pc20_to_pc22_path
    (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal : MoveValue)
    (fuel : Nat) (_hf : 2 ≤ fuel) :
    run (registrationModuleEnv o)
        (registrationFramePc20AfterStLoc11 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal)
        [] [] (registrationMsAfterOptionExtractDup3 mv sOpt) fuel =
      run (registrationModuleEnv o)
        (registrationFramePc22AfterMoveLoc0 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal)
        [] [.u8 chainId, .mutRef 4] (registrationMsAfterMutBorrowMsg mv sOpt) (fuel - 2) := by
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  let hlen := registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa
  have hfuel : fuel = (fuel - 2) + 2 := by omega
  rw [hfuel]
  have hs20 := registration_step_pc20_mutBorrowLoc11 o chainId sender contract token ekBa commitBa respBa mv rCompressed sOpt sVal
  have hs21 := registration_step_pc21_moveLoc0 o chainId sender contract token ekBa commitBa respBa mv rCompressed sOpt sVal
  exact run_succ_succ_ok (registrationModuleEnv o)
    (registrationFramePc20AfterStLoc11 args hlen mv rCompressed sOpt sVal)
    (registrationFramePc21AfterMutBorrowMsg args hlen mv rCompressed sOpt sVal)
    (registrationFramePc22AfterMoveLoc0 args hlen mv rCompressed sOpt sVal)
    []
    [] [.mutRef 4] [.u8 chainId, .mutRef 4]
    (registrationMsAfterOptionExtractDup3 mv sOpt)
    (registrationMsAfterMutBorrowMsg mv sOpt)
    (registrationMsAfterMutBorrowMsg mv sOpt)
    (fuel - 2) hs20 hs21

/-- From `pc 22` through PCs 22 (call 4 pushBack chainId), 23 (mutBorrowLoc 11 reuse),
24 (immBorrowLoc 1 alloc sender) to `Pc25AfterImmBorrow1`. -/
theorem registration_run_from_pc22_to_pc25_path
    (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal : MoveValue)
    (fuel : Nat) (_hf : 3 ≤ fuel) :
    run (registrationModuleEnv o)
        (registrationFramePc22AfterMoveLoc0 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal)
        [] [.u8 chainId, .mutRef 4] (registrationMsAfterMutBorrowMsg mv sOpt) fuel =
      run (registrationModuleEnv o)
        (registrationFramePc25AfterImmBorrow1 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal)
        [] [.immRef 5, .mutRef 4] (registrationMsAfterImmBorrow1_sender mv sOpt chainId sender) (fuel - 3) := by
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  let hlen := registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa
  have hfuel : fuel = (fuel - 3) + 3 := by omega
  rw [hfuel]
  have hs22 := registration_step_pc22_call_pushBackChainId o chainId sender contract token ekBa commitBa respBa mv rCompressed sOpt sVal
  have hs23 := registration_step_pc23_mutBorrowLoc11 o chainId sender contract token ekBa commitBa respBa mv rCompressed sOpt sVal
  have hs24 := registration_step_pc24_immBorrowLoc1 o chainId sender contract token ekBa commitBa respBa mv rCompressed sOpt sVal
  exact run_succ_succ_succ_ok (registrationModuleEnv o)
    (registrationFramePc22AfterMoveLoc0 args hlen mv rCompressed sOpt sVal)
    ({ registrationFramePc22AfterMoveLoc0 args hlen mv rCompressed sOpt sVal with pc := 23 })
    ({ registrationFramePc22AfterMoveLoc0 args hlen mv rCompressed sOpt sVal with pc := 24 })
    (registrationFramePc25AfterImmBorrow1 args hlen mv rCompressed sOpt sVal)
    []
    [.u8 chainId, .mutRef 4] [] [.mutRef 4] [.immRef 5, .mutRef 4]
    (registrationMsAfterMutBorrowMsg mv sOpt)
    (registrationMsAfterPushBackChainId mv sOpt chainId)
    (registrationMsAfterPushBackChainId mv sOpt chainId)
    (registrationMsAfterImmBorrow1_sender mv sOpt chainId sender)
    (fuel - 3) hs22 hs23 hs24

/-- From `pc 25` (via `Pc25AfterImmBorrow1`) through PCs 25 (call 5 bcs sender), 26 (call 6 append sender),
27 (mutBorrowLoc 11 reuse) to `{ Pc22 with pc := 28 }`. -/
theorem registration_run_from_pc25_to_pc28_path
    (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal : MoveValue)
    (fuel : Nat) (_hf : 3 ≤ fuel) :
    run (registrationModuleEnv o)
        (registrationFramePc25AfterImmBorrow1 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal)
        [] [.immRef 5, .mutRef 4] (registrationMsAfterImmBorrow1_sender mv sOpt chainId sender) fuel =
      run (registrationModuleEnv o)
        ({ registrationFramePc22AfterMoveLoc0 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 28 })
        [] [.mutRef 4] (registrationMsAfterAppendSender mv sOpt chainId sender) (fuel - 3) := by
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  let hlen := registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa
  have hfuel : fuel = (fuel - 3) + 3 := by omega
  rw [hfuel]
  have hs25 := registration_step_pc25_call_bcsToBytes_sender o chainId sender contract token ekBa commitBa respBa mv rCompressed sOpt sVal
  have hs26 := registration_step_pc26_call_appendSender o chainId sender contract token ekBa commitBa respBa mv rCompressed sOpt sVal
  have hs27 := registration_step_pc27_mutBorrowLoc11 o chainId sender contract token ekBa commitBa respBa mv rCompressed sOpt sVal
  exact run_succ_succ_succ_ok (registrationModuleEnv o)
    (registrationFramePc25AfterImmBorrow1 args hlen mv rCompressed sOpt sVal)
    ({ registrationFramePc25AfterImmBorrow1 args hlen mv rCompressed sOpt sVal with pc := 26 })
    ({ registrationFramePc25AfterImmBorrow1 args hlen mv rCompressed sOpt sVal with pc := 27 })
    ({ registrationFramePc22AfterMoveLoc0 args hlen mv rCompressed sOpt sVal with pc := 28 })
    []
    [.immRef 5, .mutRef 4] [.vector .u8 (sender.toList.map .u8), .mutRef 4] [] [.mutRef 4]
    (registrationMsAfterImmBorrow1_sender mv sOpt chainId sender)
    (registrationMsAfterImmBorrow1_sender mv sOpt chainId sender)
    (registrationMsAfterAppendSender mv sOpt chainId sender)
    (registrationMsAfterAppendSender mv sOpt chainId sender)
    (fuel - 3) hs25 hs26 hs27

/-- From `{Pc22 with pc := 28}` through PCs 28 (immBorrowLoc 2 alloc contract),
29 (call 5 bcs contract), 30 (call 6 append contract) to `{Pc22 with pc := 31}`. -/
theorem registration_run_from_pc28_to_pc31_path
    (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal : MoveValue)
    (fuel : Nat) (_hf : 3 ≤ fuel) :
    run (registrationModuleEnv o)
        ({ registrationFramePc22AfterMoveLoc0 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 28 })
        [] [.mutRef 4] (registrationMsAfterAppendSender mv sOpt chainId sender) fuel =
      run (registrationModuleEnv o)
        ({ registrationFramePc22AfterMoveLoc0 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 31 })
        [] [] (registrationMsAfterAppendContract mv sOpt chainId sender contract) (fuel - 3) := by
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  let hlen := registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa
  have hfuel : fuel = (fuel - 3) + 3 := by omega
  rw [hfuel]
  have hs28 := registration_step_pc28_immBorrowLoc2 o chainId sender contract token ekBa commitBa respBa mv rCompressed sOpt sVal
  have hs29 := registration_step_pc29_call_bcsToBytes_contract o chainId sender contract token ekBa commitBa respBa mv rCompressed sOpt sVal
  have hs30 := registration_step_pc30_call_appendContract o chainId sender contract token ekBa commitBa respBa mv rCompressed sOpt sVal
  exact run_succ_succ_succ_ok (registrationModuleEnv o)
    ({ registrationFramePc22AfterMoveLoc0 args hlen mv rCompressed sOpt sVal with pc := 28 })
    (registrationFramePc29AfterImmBorrow2 args hlen mv rCompressed sOpt sVal)
    ({ registrationFramePc29AfterImmBorrow2 args hlen mv rCompressed sOpt sVal with pc := 30 })
    ({ registrationFramePc22AfterMoveLoc0 args hlen mv rCompressed sOpt sVal with pc := 31 })
    []
    [.mutRef 4] [.immRef 6, .mutRef 4] [.vector .u8 (contract.toList.map .u8), .mutRef 4] []
    (registrationMsAfterAppendSender mv sOpt chainId sender)
    (registrationMsAfterImmBorrow2_contract mv sOpt chainId sender contract)
    (registrationMsAfterImmBorrow2_contract mv sOpt chainId sender contract)
    (registrationMsAfterAppendContract mv sOpt chainId sender contract)
    (fuel - 3) hs28 hs29 hs30

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
On the success path, per-PC step lemmas are mechanized through PC 20:

- PC 2 `stLoc 7`, PC 3 `immBorrowLoc 7`, PC 4 `call 1` (`option::is_some`),
  PC 5 `brFalse 79` (fall-through when `tag = true`), PC 6 `mutBorrowLoc 7`,
  PC 7 `call 2` (`option::extract`), PC 8 `stLoc 8` (store `rCompressed`),
  PC 9 `moveLoc 6` (push `respBytes`), PC 10 `call 3` (`new_scalar_from_bytes`, singleton case),
  PC 11 `stLoc 9` (store `sOpt`), PC 12 `immBorrowLoc 9` (alloc `sOpt` at ref `2`),
  PC 13 `call 1` (`option::is_some` on `&sOpt`), PC 14 `brFalse 74` (fall-through when `stag = true`),
  PC 15 `mutBorrowLoc 9` (alloc `sOpt` at ref `3`), PC 16 `call 2` (`option::extract` on `&mut sOpt`),
  PC 17 `stLoc 10` (store `sVal`), PC 18 `ldConst 5` (push DST), PC 19 `stLoc 11` (store `msg`),
  PC 20 `mutBorrowLoc 11` (alloc `msg` at ref `4`), PC 21 `moveLoc 0` (push `chainId`),
  PC 22 `call 4` (`vector::push_back<u8>` chainId onto `&mut msg`),
  PC 23 `mutBorrowLoc 11` (reuse existing ref `4` — no realloc),
  PC 24 `immBorrowLoc 1` (alloc `sender` address at ref `5`, push `immRef 5`;
         `immBorrowLoc` does NOT update `localRefs` since `&` refs are not tracked per-slot
         in the current step semantics — see `Step.lean`),
  PC 25 `call 5` (`bcs::to_bytes<address>(&sender)` — reads ref 5, pushes senderBytes),
  PC 26 `call 6` (`vector::append<u8>(&mut msg, senderBytes)` — ref 4 becomes DST ++ [chainId] ++ senderBytes),
  PC 27 `mutBorrowLoc 11` (reuse ref 4, pc→28),
  PC 28 `immBorrowLoc 2` (alloc `contract_address` at ref `6`),
  PC 29 `call 5` (`bcs::to_bytes<address>(&contract)` — pushes contractBytes),
  PC 30 `call 6` (`vector::append<u8>` — ref 4 becomes DST ++ [chainId] ++ senderBytes ++ contractBytes),
  PC 31 `mutBorrowLoc 11` (generic form; reuse ref 4, pc→32),
  PC 32 `immBorrowLoc 4` (generic form; alloc at `ms.containers.store.size`),
  PC 33 `call 5` `bcs::to_bytes<address>` (generic form; takes `refId` and `addr` with `ms.containers.read refId = some (.address addr)`),
  PC 34 `call 6` `vector::append<u8>` (generic form; takes `existing`/`appended`/`cs'` with read+write hypotheses),
  PC 35 `mutBorrowLoc 11` (generic form; reuse ref 4, pc→36),
  PC 36 `copyLoc 3` (generic form; push `ek` struct value, no localRef),
  PC 37 `call 7` `pubkey_to_bytes` (generic form; takes `ekBytes` output with `o.pubkeyToBytes [ek] = some [ekBytes]`; `wrapOracleImmRef1` deref is identity on struct),
  PC 38 `call 6` `vector::append<u8>` (generic form; pc 38→39),
  PC 39 `mutBorrowLoc 11` (generic form; pc 39→40),
  PC 40 `copyLoc 8` (generic form; push `rCompressed` from local 8, no localRef at idx 8),
  PC 41 `call 8` `compressed_point_to_bytes` (generic form; `.native o.compressedPointToBytes`; takes `rcBytes` output),
  PC 42 `call 6` `vector::append<u8>` (generic form; pc 42→43).

**Scalability note:** PC 31 onward are stated generically over an arbitrary input `MachineState`
(via `..._generic` lemmas). This avoids the exponential whnf blow-up that occurred when earlier
PCs directly referred to the deep MS chain (`registrationMsAfterAppendContract`, etc.) in the
theorem signature — each layer roughly doubles elaboration cost, quickly exceeding even
`maxHeartbeats 3200000`. The specialised corollaries used downstream are obtained by applying
the generic lemma with the actual MS and read/write hypotheses.

Combinator `registration_run_from_pc2_to_pc6_somePath` / `registration_run_from_entry_to_pc6_somePath`
chain PC 2 → PC 6. The individual PC 7–42 lemmas exist but are not yet threaded into a
run-level chain past PC 6.

Eliminating `registration_eval_equiv_singleton_tail` still requires per-PC (or block) lemmas
from PC 43 (`moveLoc 11` consumes `msg` via ref 4) through `ret` — SHA2-512 scalar (PCs 43–45),
curve operations (PCs 46–68 — `hash_to_point_base`, `pubkey_to_point`, `point_mul`, `point_add`,
`point_decompress`, `point_equals`), `brFalse 71`, and `ret` — then composing with `func ≡ exec`
(`FunctionalSim` / `Refinement`). The generic-MS pattern established for PC 31–42 scales
naturally to the remaining PCs.

**PC 43 note:** `moveLoc 11` reads via `localRefs[11] = some 4`, which triggers the complex
ref-reading branch of `moveLoc` (containing nested matches on `containers.read rid`). The
standard `simp only [step, dif_pos hpc, hc, …, hread]; rfl` pattern that works for the other
generic lemmas here does not collapse the instruction-level `match` in this branch; a targeted
tactic (e.g. `conv`-based rewriting, or an intermediate `show` to make `instr` concrete before
`step` unfolds the match) is needed and is left as the next step.

Until the full chain is in place the singleton path still relies on this axiom; concrete
agreement is checked by `native_decide` in `BytecodeDifftestEval.lean`. -/

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
