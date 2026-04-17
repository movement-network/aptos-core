import MovementFormal.Experimental.ConfidentialAsset.Registration.FunctionalSim
import MovementFormal.MoveModel.Step
import MovementFormal.MoveModel.Programs.Registration

/-!
# Bytecode eval ≡ functional simulation (L2 ≡ L1.5)

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

/-! ## eval = func (direct proof)

The proof uses `simp` with the fusion lemmas above to normalize both sides.
After `simp` aligns the match trees, `split <;> simp` handles remaining
abstract branches (oracle calls and `MoveValue` constructor matching). -/

set_option maxRecDepth 8192 in
set_option maxHeartbeats 1600000000 in
set_option linter.unusedSimpArgs false in
/-- Refinement: `eval` on the real 83-instruction bytecode agrees with
    `verifyRegistrationBytecodeResult` up to `MachineState`.

    The bytecode uses value args (struct for ek, not `.immRef`). The
    `nativeRef` wrappers handle non-ref values via `derefImm` (which
    passes them through). The `.dropMs` projection strips the populated
    `ContainerStore` that reference operations create during execution.

    **Status:** `sorry` — proving this requires symbolic bytecode stepping
    through 83 instructions with container-store threading (each
    `immBorrowLoc` / `mutBorrowLoc` allocates; each `nativeRef` call
    reads/writes). Concrete instances are verified by `native_decide`
    in `BytecodeDifftestEval.lean`. -/
theorem eval_eq_func_100
    (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray) :
    (eval (registrationModuleEnv o) verifyRegistrationProofIdx
      [.u8 chainId, .address sender, .address contract,
       .struct_ [.vector .u8 (ekBa.toList.map .u8)],
       .address token,
       .vector .u8 (commitBa.toList.map .u8),
       .vector .u8 (respBa.toList.map .u8)]
      200 MachineState.empty).dropMs =
    verifyRegistrationBytecodeResult o
      [.u8 chainId, .address sender, .address contract,
       .struct_ [.vector .u8 (ekBa.toList.map .u8)],
       .address token,
       .vector .u8 (commitBa.toList.map .u8),
       .vector .u8 (respBa.toList.map .u8)] := by
  sorry

end MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquiv
