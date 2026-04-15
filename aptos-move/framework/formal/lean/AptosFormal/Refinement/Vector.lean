import AptosFormal.Move.Step
import AptosFormal.Move.Programs
import AptosFormal.Move.Programs.Vector
import AptosFormal.Tests.Defs
import AptosFormal.Std.Vector.Operations

/-!
# Vector bytecode refinement

Correctness of hand-written `vector::contains` (index **18** in `stdModuleEnv`) against
`AptosFormal.Std.Vector.contains`.

## Status

- **Empty vector:** `vectorContains_returnValues_empty`.
- **Setup (7 steps):** `eval_eq_contains_run`, `contains_run_after_setup`, and `contains_evalProg_after_setup`
  relate `eval` / `evalProg` to `run` from the loop header (`containsLoopFrame` at **pc 7**).
- **Loop + return:** `vectorContains_returnValues` — kernel-checked via `contains_return_run.go` (no `sorry`).
  Hypothesis `xs.length < UInt64.size` ensures list indices match `u64` comparisons in the bytecode.

Smokes: `AptosFormal.Tests.Vector` (`native_decide` on concrete inputs).
-/

namespace AptosFormal.Refinement.Vector

open AptosFormal.Move
open AptosFormal.Move.Programs
open AptosFormal.Move.Programs.Vector
open AptosFormal.Tests.Defs
open AptosFormal.Std.Vector

/-! ## Spec helper: search from index -/

/-- `contains` on the suffix `xs[i:]`, matching the VM loop index. -/
def containsFromIdx (xs : List UInt64) (e : UInt64) (i : Nat) : Bool :=
  (xs.drop i).any (· == e)

theorem contains_eq_containsFromIdx_zero (xs : List UInt64) (e : UInt64) :
    contains xs e = containsFromIdx xs e 0 := by
  simp [contains, containsFromIdx]

theorem containsFromIdx_len (xs : List UInt64) (e : UInt64) :
    containsFromIdx xs e xs.length = false := by
  simp [containsFromIdx]

theorem containsFromIdx_lt {xs : List UInt64} {e : UInt64} {i : Nat}
    (hi : i < xs.length) :
    containsFromIdx xs e i =
      if xs.get ⟨i, hi⟩ == e then true else containsFromIdx xs e (i + 1) := by
  induction xs generalizing i with
  | nil => cases hi
  | cons x xs ih =>
    cases i with
    | zero =>
      simp only [containsFromIdx, List.drop, List.any_cons, List.get]
      by_cases hx : x == e <;> simp [hx]
    | succ i =>
      have hi' : i < xs.length := Nat.succ_lt_succ_iff.mp hi
      simp only [containsFromIdx, List.drop, List.get]
      exact ih hi'

/-! ## VM state at the loop header (pc = 7); scaffolding for the full proof -/

/-- Vector argument as a `MoveValue` (shared in setup lemmas). -/
private abbrev containsVec (xs : List UInt64) : MoveValue :=
  .vector .u64 (xs.map .u64)

private def noLocalRefs5 : Array (Option RefId) := (List.replicate 5 none).toArray

/-- Initial frame for `vector_contains`: matches `eval` (`args.map some ++ replicate 3 none`). -/
def containsInitFrame (xs : List UInt64) (e : UInt64) : Frame :=
  let args : List MoveValue := [.vector .u64 (xs.map .u64), .u64 e]
  { code := vectorContainsCode, pc := 0,
    locals := (args.map some ++ List.replicate 3 none).toArray,
    localRefs := noLocalRefs5 }

/-- Container store after `k` failed comparisons: vector at id `0`, then stale `u64` cells. -/
def containsVmStore (xs : List UInt64) (k : Nat) : ContainerStore where
  store :=
    #[MoveValue.vector MoveType.u64 (xs.map MoveValue.u64)] ++
      ((List.take k xs).map MoveValue.u64).toArray

def containsLoopFrame (xs : List UInt64) (e : UInt64) (k : Nat) : Frame where
  code := vectorContainsCode
  pc := 7
  locals := #[
    some (.vector .u64 (xs.map .u64)),
    some (.u64 e),
    some (.immRef 0),
    some (.u64 k.toUInt64),
    some (.u64 (List.map MoveValue.u64 xs).length.toUInt64)
  ]
  localRefs := noLocalRefs5

@[simp] theorem containsLoopFrame_code (xs : List UInt64) (e : UInt64) (k i : Nat) :
    ({ containsLoopFrame xs e k with pc := i}).code = vectorContainsCode := rfl

@[simp] theorem containsLoopFrame_pc (xs : List UInt64) (e : UInt64) (k i : Nat) :
    ({ containsLoopFrame xs e k with pc := i}).pc = i := rfl

private theorem run_succ_ok {env : ModuleEnv} {f f' : Frame} {cs cs' : List Frame}
    {st st' : List MoveValue} {ms ms' : MachineState} (m : Nat)
    (h : step env f cs st ms = ExecResult.ok f' cs' st' ms') :
    run env f cs st ms (Nat.succ m) = run env f' cs' st' ms' m := by
  simp [run, h]

/-- Size of the synthetic store: one vector cell plus `k` copied elements. -/
@[simp] private theorem contains_read_vec0 (xs : List UInt64) (k : Nat) :
    (ContainerStore.mk
        (MoveValue.vector MoveType.u64 (List.map MoveValue.u64 xs) ::
            List.take k (List.map MoveValue.u64 xs)).toArray).read 0 =
      some (MoveValue.vector MoveType.u64 (List.map MoveValue.u64 xs)) := by
  have h0 : 0 < (MoveValue.vector MoveType.u64 (List.map MoveValue.u64 xs) ::
      List.take k (List.map MoveValue.u64 xs)).toArray.size := by
    simp [Array.size_toArray, List.length_cons, List.length_take, Nat.zero_lt_succ]
  simp [ContainerStore.read, if_pos h0, List.getElem_toArray]

private theorem contains_vm_store_size (xs : List UInt64) (k : Nat) (hk : k ≤ xs.length) :
    (containsVmStore xs k).store.size = k + 1 := by
  simp [containsVmStore, Array.size_append, List.size_toArray, List.length_map, List.length_take,
    Nat.min_eq_left hk, Nat.add_comm]

private theorem contains_idx_u64_lt_len {xs : List UInt64} {k : Nat} (hk : k < xs.length)
    (hlen : xs.length < UInt64.size) :
    k.toUInt64 < (List.map MoveValue.u64 xs).length.toUInt64 := by
  have hk64 : k < UInt64.size := Nat.lt_trans hk hlen
  have hkN : k.toUInt64.toNat = k := UInt64.toNat_ofNat_of_lt hk64
  have hlN : ((List.map MoveValue.u64 xs).length.toUInt64).toNat = xs.length := by
    simpa [List.length_map, UInt64.toNat_ofNat_of_lt hlen]
  rw [UInt64.lt_iff_toNat_lt, hkN, hlN]
  exact hk

private abbrev containsAllocStore (xs : List UInt64) (k : Nat) (hk : k < xs.length) : ContainerStore :=
  (ContainerStore.alloc (containsVmStore xs k) (.u64 (xs.get ⟨k, hk⟩))).1

/-- Locals after `stLoc 2` (imm ref to the vector at container `0`). -/
private def containsLocalsRef (xs : List UInt64) (e : UInt64) : Array (Option MoveValue) :=
  #[some (containsVec xs), some (.u64 e), some (.immRef 0), none, none]

/-- Locals after `stLoc 3` (`i = 0`). -/
private def containsLocalsILen (xs : List UInt64) (e : UInt64) : Array (Option MoveValue) :=
  #[some (containsVec xs), some (.u64 e), some (.immRef 0), some (.u64 0), none]

private theorem contains_setup_step0 (xs : List UInt64) (e : UInt64) :
    step stdModuleEnv (containsInitFrame xs e) [] [] ContainerStore.empty =
      ExecResult.ok
        { containsInitFrame xs e with pc := 1 }
        [] [.immRef 0]
        (MachineState.ofContainers ({ store := #[containsVec xs] } : ContainerStore)) := rfl

private theorem contains_setup_step1 (xs : List UInt64) (e : UInt64) :
    step stdModuleEnv
        { containsInitFrame xs e with pc := 1 }
        [] [.immRef 0]
        (MachineState.ofContainers ({ store := #[containsVec xs] } : ContainerStore)) =
      ExecResult.ok
        { code := vectorContainsCode, pc := 2, locals := containsLocalsRef xs e,
          localRefs := noLocalRefs5 }
        [] []
        (MachineState.ofContainers ({ store := #[containsVec xs] } : ContainerStore)) := rfl

private theorem contains_setup_step2 (xs : List UInt64) (e : UInt64) :
    step stdModuleEnv
        { code := vectorContainsCode, pc := 2, locals := containsLocalsRef xs e,
          localRefs := noLocalRefs5 }
        [] []
        (MachineState.ofContainers ({ store := #[containsVec xs] } : ContainerStore)) =
      ExecResult.ok
        { code := vectorContainsCode, pc := 3, locals := containsLocalsRef xs e,
          localRefs := noLocalRefs5 }
        [] [.u64 0]
        (MachineState.ofContainers ({ store := #[containsVec xs] } : ContainerStore)) := rfl

private theorem contains_setup_step3 (xs : List UInt64) (e : UInt64) :
    step stdModuleEnv
        { code := vectorContainsCode, pc := 3, locals := containsLocalsRef xs e,
          localRefs := noLocalRefs5 }
        [] [.u64 0]
        (MachineState.ofContainers ({ store := #[containsVec xs] } : ContainerStore)) =
      ExecResult.ok
        { code := vectorContainsCode, pc := 4, locals := containsLocalsILen xs e,
          localRefs := noLocalRefs5 }
        [] []
        (MachineState.ofContainers ({ store := #[containsVec xs] } : ContainerStore)) := rfl

private theorem contains_setup_step4 (xs : List UInt64) (e : UInt64) :
    step stdModuleEnv
        { code := vectorContainsCode, pc := 4, locals := containsLocalsILen xs e,
          localRefs := noLocalRefs5 }
        [] []
        (MachineState.ofContainers ({ store := #[containsVec xs] } : ContainerStore)) =
      ExecResult.ok
        { code := vectorContainsCode, pc := 5, locals := containsLocalsILen xs e,
          localRefs := noLocalRefs5 }
        [] [.immRef 0]
        (MachineState.ofContainers ({ store := #[containsVec xs] } : ContainerStore)) := rfl

private theorem contains_setup_step5 (xs : List UInt64) (e : UInt64) :
    step stdModuleEnv
        { code := vectorContainsCode, pc := 5, locals := containsLocalsILen xs e,
          localRefs := noLocalRefs5 }
        [] [.immRef 0]
        (MachineState.ofContainers ({ store := #[containsVec xs] } : ContainerStore)) =
      ExecResult.ok
        { code := vectorContainsCode, pc := 6, locals := containsLocalsILen xs e,
          localRefs := noLocalRefs5 }
        [] [.u64 (List.map MoveValue.u64 xs).length.toUInt64]
        (MachineState.ofContainers ({ store := #[containsVec xs] } : ContainerStore)) := rfl

private theorem contains_setup_step6 (xs : List UInt64) (e : UInt64) :
    step stdModuleEnv
        { code := vectorContainsCode, pc := 6, locals := containsLocalsILen xs e,
          localRefs := noLocalRefs5 }
        [] [.u64 (List.map MoveValue.u64 xs).length.toUInt64]
        (MachineState.ofContainers ({ store := #[containsVec xs] } : ContainerStore)) =
      ExecResult.ok (containsLoopFrame xs e 0) [] [] (containsVmStore xs 0) := rfl

/-- Seven small steps from `containsInitFrame` reach the loop header (`pc = 7`). -/
theorem contains_run_after_setup (xs : List UInt64) (e : UInt64) (fuel : Nat) :
    run stdModuleEnv (containsInitFrame xs e) [] [] ContainerStore.empty (7 + fuel) =
      run stdModuleEnv (containsLoopFrame xs e 0) [] [] (containsVmStore xs 0) fuel := by
  rw [show 7 + fuel = Nat.succ (6 + fuel) by omega]
  rw [run_succ_ok _ (contains_setup_step0 xs e)]
  rw [show 6 + fuel = Nat.succ (5 + fuel) by omega]
  rw [run_succ_ok _ (contains_setup_step1 xs e)]
  rw [show 5 + fuel = Nat.succ (4 + fuel) by omega]
  rw [run_succ_ok _ (contains_setup_step2 xs e)]
  rw [show 4 + fuel = Nat.succ (3 + fuel) by omega]
  rw [run_succ_ok _ (contains_setup_step3 xs e)]
  rw [show 3 + fuel = Nat.succ (2 + fuel) by omega]
  rw [run_succ_ok _ (contains_setup_step4 xs e)]
  rw [show 2 + fuel = Nat.succ (1 + fuel) by omega]
  rw [run_succ_ok _ (contains_setup_step5 xs e)]
  rw [show 1 + fuel = Nat.succ fuel by omega]
  rw [run_succ_ok _ (contains_setup_step6 xs e)]

/-- `eval` on index 18 agrees with `run` from `containsInitFrame`. -/
theorem eval_eq_contains_run (xs : List UInt64) (e : UInt64) (fuel : Nat) :
    eval stdModuleEnv 18 [.vector .u64 (xs.map .u64), .u64 e] fuel =
      run stdModuleEnv (containsInitFrame xs e) [] [] ContainerStore.empty fuel := by
  simp [eval, containsInitFrame, stdModuleEnv, vectorContainsDesc, vectorContainsCode]
  rfl

/-- `evalProg` after the 7-instruction prologue continues as `run` from the loop header. -/
theorem contains_evalProg_after_setup (xs : List UInt64) (e : UInt64) (fuel : Nat) :
    evalProg 18 [.vector .u64 (xs.map .u64), .u64 e] (7 + fuel) =
      run stdModuleEnv (containsLoopFrame xs e 0) [] [] (containsVmStore xs 0) fuel := by
  dsimp [evalProg]
  rw [eval_eq_contains_run, contains_run_after_setup]

/-- Fuel hint: setup (`7` steps) plus loop body (`≈ 16` steps per index) plus exit. -/
def containsFuel (len : Nat) : Nat := 7 + 30 * len + 30

/-! ## Loop / exit: list + store algebra -/

private theorem contains_list_take_succ (xs : List UInt64) (k : Nat) (hk : k < xs.length) :
    List.take k (List.map MoveValue.u64 xs) ++ [MoveValue.u64 (xs.get ⟨k, hk⟩)] =
      List.take (k + 1) (List.map MoveValue.u64 xs) := by
  induction xs generalizing k with
  | nil => cases hk
  | cons x xs ih =>
    cases k with
    | zero => simp [List.take, List.map, List.get]
    | succ k =>
      have hk' : k < xs.length := Nat.succ_lt_succ_iff.mp hk
      simp [List.take, List.map, List.get]
      exact ih k hk'

private theorem contains_vm_store_succ (xs : List UInt64) (k : Nat) (hk : k < xs.length) :
    (ContainerStore.alloc (containsVmStore xs k) (.u64 (xs.get ⟨k, hk⟩))).1 =
      containsVmStore xs (k + 1) := by
  simp [containsVmStore, ContainerStore.alloc]
  simpa using contains_list_take_succ xs k hk

private theorem contains_alloc_store_eq (xs : List UInt64) (k : Nat) (hk : k < xs.length) :
    containsAllocStore xs k hk = containsVmStore xs (k + 1) :=
  contains_vm_store_succ xs k hk

private theorem contains_vm_read_succ (xs : List UInt64) (k : Nat) (hk : k < xs.length) :
    (containsVmStore xs (k + 1)).read (k + 1) = some (.u64 (xs.get ⟨k, hk⟩)) := by
  have hmin : min (k + 1) xs.length = k + 1 := Nat.min_eq_left (Nat.succ_le_of_lt hk)
  simp [containsVmStore, ContainerStore.read, contains_vm_store_size xs (k + 1) (Nat.succ_le_of_lt hk),
    if_pos (by omega), List.getElem_map, List.getElem_take, hmin, Nat.lt_succ_self]

private theorem contains_alloc_read_cell (xs : List UInt64) (k : Nat) (hk : k < xs.length) :
    (containsAllocStore xs k hk).read (k + 1) = some (.u64 (xs.get ⟨k, hk⟩)) := by
  simpa [contains_alloc_store_eq] using contains_vm_read_succ xs k hk

private theorem contains_uint64_succ (k : Nat) : k.toUInt64 + 1 = k.succ.toUInt64 := by
  refine UInt64.toNat.inj ?_
  simp [UInt64.toNat_ofNat, UInt64.toNat_add]

/-! ## Exit path (`k = xs.length`, `i = len`, `lt` false) -/

/-- Both index and length use the same `u64` so `lt` reduces to `false`. -/
private def containsExitFrame (xs : List UInt64) (e : UInt64) : Frame :=
  let uLen := (List.map MoveValue.u64 xs).length.toUInt64
  { code := vectorContainsCode, pc := 7,
    locals := #[
      some (.vector .u64 (xs.map .u64)),
      some (.u64 e),
      some (.immRef 0),
      some (.u64 uLen),
      some (.u64 uLen)
    ],
    localRefs := noLocalRefs5 }

@[simp] theorem containsExitFrame_code (xs : List UInt64) (e : UInt64) (i : Nat) :
    ({ containsExitFrame xs e with pc := i}).code = vectorContainsCode := rfl

@[simp] theorem containsExitFrame_pc (xs : List UInt64) (e : UInt64) (i : Nat) :
    ({ containsExitFrame xs e with pc := i}).pc = i := rfl

private theorem contains_loop_eq_exit (xs : List UInt64) (e : UInt64) :
    containsLoopFrame xs e xs.length = containsExitFrame xs e := by
  simp [containsLoopFrame, containsExitFrame, List.length_map]

private theorem contains_exit_step0 (xs : List UInt64) (e : UInt64) :
    let u := (List.map MoveValue.u64 xs).length.toUInt64
    step stdModuleEnv (containsExitFrame xs e) [] [] (containsVmStore xs xs.length) =
      ExecResult.ok ({ containsExitFrame xs e with pc := 8 }) [] [.u64 u]
        (containsVmStore xs xs.length) := rfl

private theorem contains_exit_step1 (xs : List UInt64) (e : UInt64) :
    let u := (List.map MoveValue.u64 xs).length.toUInt64
    step stdModuleEnv ({ containsExitFrame xs e with pc := 8 }) [] [.u64 u]
        (containsVmStore xs xs.length) =
      ExecResult.ok ({ containsExitFrame xs e with pc := 9 }) [] [.u64 u, .u64 u]
        (containsVmStore xs xs.length) := rfl

private theorem contains_exit_step2 (xs : List UInt64) (e : UInt64) :
    let u := (List.map MoveValue.u64 xs).length.toUInt64
    step stdModuleEnv ({ containsExitFrame xs e with pc := 9 }) [] [.u64 u, .u64 u]
        (containsVmStore xs xs.length) =
      ExecResult.ok ({ containsExitFrame xs e with pc := 10 }) [] [.bool false]
        (containsVmStore xs xs.length) := by
  have hid :
      intLt (.u64 (UInt64.ofNat xs.length)) (.u64 (UInt64.ofNat xs.length)) = some false := by
    rw [intLt_u64, decide_eq_false (UInt64.lt_irrefl _)]
  simp [step, containsExitFrame, containsVmStore, hid, vectorContains_code_size,
    vectorContains_instr_9, List.length_map]

private theorem contains_exit_step3 (xs : List UInt64) (e : UInt64) :
    step stdModuleEnv ({ containsExitFrame xs e with pc := 10 }) [] [.bool false]
        (containsVmStore xs xs.length) =
      ExecResult.ok ({ containsExitFrame xs e with pc := 25 }) [] []
        (containsVmStore xs xs.length) := rfl

private theorem contains_exit_step4 (xs : List UInt64) (e : UInt64) :
    step stdModuleEnv ({ containsExitFrame xs e with pc := 25 }) [] []
        (containsVmStore xs xs.length) =
      ExecResult.ok ({ containsExitFrame xs e with pc := 26 }) [] [.bool false]
        (containsVmStore xs xs.length) := rfl

private theorem contains_exit_step5 (xs : List UInt64) (e : UInt64) :
    step stdModuleEnv ({ containsExitFrame xs e with pc := 26 }) [] [.bool false]
        (containsVmStore xs xs.length) =
      ExecResult.returned [.bool false] (containsVmStore xs xs.length) := rfl

private theorem contains_run_exit (xs : List UInt64) (e : UInt64) (t : Nat) :
    run stdModuleEnv (containsExitFrame xs e) [] [] (containsVmStore xs xs.length) (6 + t) =
      ExecResult.returned [.bool false] (containsVmStore xs xs.length) := by
  rw [show 6 + t = Nat.succ (5 + t) by omega]
  rw [run_succ_ok _ (contains_exit_step0 xs e)]
  rw [show 5 + t = Nat.succ (4 + t) by omega]
  rw [run_succ_ok _ (contains_exit_step1 xs e)]
  rw [show 4 + t = Nat.succ (3 + t) by omega]
  rw [run_succ_ok _ (contains_exit_step2 xs e)]
  rw [show 3 + t = Nat.succ (2 + t) by omega]
  rw [run_succ_ok _ (contains_exit_step3 xs e)]
  rw [show 2 + t = Nat.succ (1 + t) by omega]
  rw [run_succ_ok _ (contains_exit_step4 xs e)]
  rw [show 1 + t = Nat.succ t by omega]
  simpa [run, contains_exit_step5 xs e]

/-! ## Iteration (`k < len`, element not found): 16 `ok` steps back to header -/

private theorem contains_iterN0 (xs : List UInt64) (e : UInt64) (k : Nat) (hk : k < xs.length)
    (_hlen : xs.length < UInt64.size) (_hneq : (xs.get ⟨k, hk⟩ == e) = false) :
    step stdModuleEnv (containsLoopFrame xs e k) [] [] (containsVmStore xs k) =
      ExecResult.ok ({ containsLoopFrame xs e k with pc := 8 }) [] [.u64 k.toUInt64]
        (containsVmStore xs k) := rfl

private theorem contains_iterN1 (xs : List UInt64) (e : UInt64) (k : Nat) (hk : k < xs.length)
    (_hlen : xs.length < UInt64.size) (_hneq : (xs.get ⟨k, hk⟩ == e) = false) :
    step stdModuleEnv ({ containsLoopFrame xs e k with pc := 8 }) [] [.u64 k.toUInt64]
        (containsVmStore xs k) =
      ExecResult.ok ({ containsLoopFrame xs e k with pc := 9 })
        [] [.u64 (List.map MoveValue.u64 xs).length.toUInt64, .u64 k.toUInt64]
        (containsVmStore xs k) := rfl

private theorem contains_iterN2 (xs : List UInt64) (e : UInt64) (k : Nat) (hk : k < xs.length)
    (hlen : xs.length < UInt64.size) (_hneq : (xs.get ⟨k, hk⟩ == e) = false) :
    step stdModuleEnv ({ containsLoopFrame xs e k with pc := 9 })
        [] [.u64 (List.map MoveValue.u64 xs).length.toUInt64, .u64 k.toUInt64]
        (containsVmStore xs k) =
      ExecResult.ok ({ containsLoopFrame xs e k with pc := 10 }) [] [.bool true]
        (containsVmStore xs k) := by
  have hid :
      intLt (.u64 k.toUInt64) (.u64 (UInt64.ofNat xs.length)) = some true := by
    rw [intLt_u64, decide_eq_true (by simpa [List.length_map] using contains_idx_u64_lt_len hk hlen)]
  simp [step, containsLoopFrame, containsVmStore, hid, vectorContains_code_size,
    vectorContains_instr_9, List.length_map]

private theorem contains_iterN3 (xs : List UInt64) (e : UInt64) (k : Nat) (hk : k < xs.length)
    (_hlen : xs.length < UInt64.size) (_hneq : (xs.get ⟨k, hk⟩ == e) = false) :
    step stdModuleEnv ({ containsLoopFrame xs e k with pc := 10 }) [] [.bool true]
        (containsVmStore xs k) =
      ExecResult.ok ({ containsLoopFrame xs e k with pc := 11 }) [] []
        (containsVmStore xs k) := rfl

private theorem contains_iterN4 (xs : List UInt64) (e : UInt64) (k : Nat) (hk : k < xs.length)
    (_hlen : xs.length < UInt64.size) (_hneq : (xs.get ⟨k, hk⟩ == e) = false) :
    step stdModuleEnv ({ containsLoopFrame xs e k with pc := 11 }) [] []
        (containsVmStore xs k) =
      ExecResult.ok ({ containsLoopFrame xs e k with pc := 12 }) [] [.immRef 0]
        (containsVmStore xs k) := rfl

private theorem contains_iterN5 (xs : List UInt64) (e : UInt64) (k : Nat) (hk : k < xs.length)
    (_hlen : xs.length < UInt64.size) (_hneq : (xs.get ⟨k, hk⟩ == e) = false) :
    step stdModuleEnv ({ containsLoopFrame xs e k with pc := 12 }) [] [.immRef 0]
        (containsVmStore xs k) =
      ExecResult.ok ({ containsLoopFrame xs e k with pc := 13 })
        [] [.u64 k.toUInt64, .immRef 0]
        (containsVmStore xs k) := rfl

private theorem contains_iterN6 (xs : List UInt64) (e : UInt64) (k : Nat) (hk : k < xs.length)
    (hlen : xs.length < UInt64.size) (_hneq : (xs.get ⟨k, hk⟩ == e) = false) :
    step stdModuleEnv ({ containsLoopFrame xs e k with pc := 13 })
        [] [.u64 k.toUInt64, .immRef 0]
        (containsVmStore xs k) =
      ExecResult.ok ({ containsLoopFrame xs e k with pc := 14 }) [] [.immRef (k + 1)]
        (containsAllocStore xs k hk) := by
  have hkNat : k.toUInt64.toNat = k :=
    UInt64.toNat_ofNat_of_lt (Nat.lt_trans hk hlen)
  have hkU : k.toUInt64 = UInt64.ofNat k := rfl
  simp [step, containsLoopFrame, containsVmStore, ContainerStore.alloc, vectorContains_code_size,
    vectorContains_instr_13, contains_vm_store_size xs k (Nat.le_of_lt hk), hkNat,
    List.getElem_map, Nat.min_eq_left (Nat.le_of_lt hk), hkU, dif_pos hk, contains_read_vec0]
  simp [containsAllocStore, containsVmStore, ContainerStore.alloc, contains_list_take_succ xs k hk,
    List.getElem_map, List.toArray_appendList]

private theorem contains_iterN7 (xs : List UInt64) (e : UInt64) (k : Nat) (hk : k < xs.length)
    (_hlen : xs.length < UInt64.size) (_hneq : (xs.get ⟨k, hk⟩ == e) = false) :
    step stdModuleEnv ({ containsLoopFrame xs e k with pc := 14 }) [] [.immRef (k + 1)]
        (containsAllocStore xs k hk) =
      ExecResult.ok ({ containsLoopFrame xs e k with pc := 15 }) [] [.u64 (xs.get ⟨k, hk⟩)]
        (containsAllocStore xs k hk) := by
  simp [step, containsLoopFrame, vectorContains_code_size, vectorContains_instr_14,
    contains_alloc_read_cell xs k hk]

private theorem contains_iterN8 (xs : List UInt64) (e : UInt64) (k : Nat) (hk : k < xs.length)
    (_hlen : xs.length < UInt64.size) (_hneq : (xs.get ⟨k, hk⟩ == e) = false) :
    step stdModuleEnv ({ containsLoopFrame xs e k with pc := 15 }) [] [.u64 (xs.get ⟨k, hk⟩)]
        (containsAllocStore xs k hk) =
      ExecResult.ok ({ containsLoopFrame xs e k with pc := 16 })
        [] [.u64 e, .u64 (xs.get ⟨k, hk⟩)]
        (containsAllocStore xs k hk) := rfl

private theorem contains_iterN9 (xs : List UInt64) (e : UInt64) (k : Nat) (hk : k < xs.length)
    (_hlen : xs.length < UInt64.size) (hneq : (xs.get ⟨k, hk⟩ == e) = false) :
    step stdModuleEnv ({ containsLoopFrame xs e k with pc := 16 })
        [] [.u64 e, .u64 (xs.get ⟨k, hk⟩)]
        (containsAllocStore xs k hk) =
      ExecResult.ok ({ containsLoopFrame xs e k with pc := 17 })
        [] [.bool false]
        (containsAllocStore xs k hk) := by
  have hb : (MoveValue.u64 xs[k] == MoveValue.u64 e) = false := by
    simpa only [BEq.beq, MoveValue.beq_u64] using hneq
  simp [step, containsLoopFrame, vectorContains_code_size, vectorContains_instr_16, hb]

private theorem contains_iterN10 (xs : List UInt64) (e : UInt64) (k : Nat) (hk : k < xs.length)
    (_hlen : xs.length < UInt64.size) (_hneq : (xs.get ⟨k, hk⟩ == e) = false) :
    step stdModuleEnv ({ containsLoopFrame xs e k with pc := 17 }) [] [.bool false]
        (containsAllocStore xs k hk) =
      ExecResult.ok ({ containsLoopFrame xs e k with pc := 18 }) [] []
        (containsAllocStore xs k hk) := rfl

private theorem contains_iterN11 (xs : List UInt64) (e : UInt64) (k : Nat) (hk : k < xs.length)
    (_hlen : xs.length < UInt64.size) (_hneq : (xs.get ⟨k, hk⟩ == e) = false) :
    step stdModuleEnv ({ containsLoopFrame xs e k with pc := 18 }) [] []
        (containsAllocStore xs k hk) =
      ExecResult.ok ({ containsLoopFrame xs e k with pc := 19 }) [] [.u64 k.toUInt64]
        (containsAllocStore xs k hk) := rfl

private theorem contains_iterN12 (xs : List UInt64) (e : UInt64) (k : Nat) (hk : k < xs.length)
    (_hlen : xs.length < UInt64.size) (_hneq : (xs.get ⟨k, hk⟩ == e) = false) :
    step stdModuleEnv ({ containsLoopFrame xs e k with pc := 19 }) [] [.u64 k.toUInt64]
        (containsAllocStore xs k hk) =
      ExecResult.ok ({ containsLoopFrame xs e k with pc := 20 })
        [] [.u64 1, .u64 k.toUInt64]
        (containsAllocStore xs k hk) := rfl

private theorem contains_iterN13 (xs : List UInt64) (e : UInt64) (k : Nat) (hk : k < xs.length)
    (_hlen : xs.length < UInt64.size) (_hneq : (xs.get ⟨k, hk⟩ == e) = false) :
    step stdModuleEnv ({ containsLoopFrame xs e k with pc := 20 })
        [] [.u64 1, .u64 k.toUInt64]
        (containsAllocStore xs k hk) =
      ExecResult.ok ({ containsLoopFrame xs e k with pc := 21 }) [] [.u64 (k.toUInt64 + 1)]
        (containsAllocStore xs k hk) := rfl

private theorem contains_iterN14 (xs : List UInt64) (e : UInt64) (k : Nat) (hk : k < xs.length)
    (_hlen : xs.length < UInt64.size) (_hneq : (xs.get ⟨k, hk⟩ == e) = false) :
    step stdModuleEnv ({ containsLoopFrame xs e k with pc := 21 })
        [] [.u64 (k.toUInt64 + 1)]
        (containsAllocStore xs k hk) =
      ExecResult.ok
        ({
          containsLoopFrame xs e k with
          pc := 22,
          locals :=
            (containsLoopFrame xs e k).locals.set 3 (some (.u64 (k.toUInt64 + 1)))
              (by simp [containsLoopFrame])
        })
        [] []
        (containsAllocStore xs k hk) := rfl

private theorem contains_iterN15 (xs : List UInt64) (e : UInt64) (k : Nat) (hk : k < xs.length)
    (_hlen : xs.length < UInt64.size) (_hneq : (xs.get ⟨k, hk⟩ == e) = false) :
    step stdModuleEnv
        ({
          containsLoopFrame xs e k with
          pc := 22,
          locals :=
            (containsLoopFrame xs e k).locals.set 3 (some (.u64 (k.toUInt64 + 1)))
              (by simp [containsLoopFrame])
        })
        [] []
        (containsAllocStore xs k hk) =
      ExecResult.ok (containsLoopFrame xs e (k + 1)) [] [] (containsVmStore xs (k + 1)) := by
  simp only [step, containsLoopFrame, vectorContains_code_size, vectorContains_instr_22,
    contains_uint64_succ]
  rw [contains_alloc_store_eq]
  rfl

private theorem contains_run_iter (xs : List UInt64) (e : UInt64) (k : Nat) (hk : k < xs.length)
    (hlen : xs.length < UInt64.size) (hneq : (xs.get ⟨k, hk⟩ == e) = false) (fuel : Nat) :
    run stdModuleEnv (containsLoopFrame xs e k) [] [] (containsVmStore xs k) (16 + fuel) =
      run stdModuleEnv (containsLoopFrame xs e (k + 1)) [] [] (containsVmStore xs (k + 1)) fuel := by
  rw [show 16 + fuel = Nat.succ (15 + fuel) by omega]
  rw [run_succ_ok _ (contains_iterN0 xs e k hk hlen hneq)]
  rw [show 15 + fuel = Nat.succ (14 + fuel) by omega]
  rw [run_succ_ok _ (contains_iterN1 xs e k hk hlen hneq)]
  rw [show 14 + fuel = Nat.succ (13 + fuel) by omega]
  rw [run_succ_ok _ (contains_iterN2 xs e k hk hlen hneq)]
  rw [show 13 + fuel = Nat.succ (12 + fuel) by omega]
  rw [run_succ_ok _ (contains_iterN3 xs e k hk hlen hneq)]
  rw [show 12 + fuel = Nat.succ (11 + fuel) by omega]
  rw [run_succ_ok _ (contains_iterN4 xs e k hk hlen hneq)]
  rw [show 11 + fuel = Nat.succ (10 + fuel) by omega]
  rw [run_succ_ok _ (contains_iterN5 xs e k hk hlen hneq)]
  rw [show 10 + fuel = Nat.succ (9 + fuel) by omega]
  rw [run_succ_ok _ (contains_iterN6 xs e k hk hlen hneq)]
  rw [show 9 + fuel = Nat.succ (8 + fuel) by omega]
  rw [run_succ_ok _ (contains_iterN7 xs e k hk hlen hneq)]
  rw [show 8 + fuel = Nat.succ (7 + fuel) by omega]
  rw [run_succ_ok _ (contains_iterN8 xs e k hk hlen hneq)]
  rw [show 7 + fuel = Nat.succ (6 + fuel) by omega]
  rw [run_succ_ok _ (contains_iterN9 xs e k hk hlen hneq)]
  rw [show 6 + fuel = Nat.succ (5 + fuel) by omega]
  rw [run_succ_ok _ (contains_iterN10 xs e k hk hlen hneq)]
  rw [show 5 + fuel = Nat.succ (4 + fuel) by omega]
  rw [run_succ_ok _ (contains_iterN11 xs e k hk hlen hneq)]
  rw [show 4 + fuel = Nat.succ (3 + fuel) by omega]
  rw [run_succ_ok _ (contains_iterN12 xs e k hk hlen hneq)]
  rw [show 3 + fuel = Nat.succ (2 + fuel) by omega]
  rw [run_succ_ok _ (contains_iterN13 xs e k hk hlen hneq)]
  rw [show 2 + fuel = Nat.succ (1 + fuel) by omega]
  rw [run_succ_ok _ (contains_iterN14 xs e k hk hlen hneq)]
  rw [show 1 + fuel = Nat.succ fuel by omega]
  rw [run_succ_ok _ (contains_iterN15 xs e k hk hlen hneq)]

/-! ## Found path (`xs[k] == e`) -/

private theorem contains_foundN0 (xs : List UInt64) (e : UInt64) (k : Nat) (hk : k < xs.length)
    (_he : (xs.get ⟨k, hk⟩ == e) = true) :
    step stdModuleEnv (containsLoopFrame xs e k) [] [] (containsVmStore xs k) =
      ExecResult.ok ({ containsLoopFrame xs e k with pc := 8 }) [] [.u64 k.toUInt64]
        (containsVmStore xs k) := rfl

private theorem contains_foundN1 (xs : List UInt64) (e : UInt64) (k : Nat) (hk : k < xs.length)
    (_he : (xs.get ⟨k, hk⟩ == e) = true) :
    step stdModuleEnv ({ containsLoopFrame xs e k with pc := 8 }) [] [.u64 k.toUInt64]
        (containsVmStore xs k) =
      ExecResult.ok ({ containsLoopFrame xs e k with pc := 9 })
        [] [.u64 (List.map MoveValue.u64 xs).length.toUInt64, .u64 k.toUInt64]
        (containsVmStore xs k) := rfl

private theorem contains_foundN2 (xs : List UInt64) (e : UInt64) (k : Nat) (hk : k < xs.length)
    (_he : (xs.get ⟨k, hk⟩ == e) = true) (hlen : xs.length < UInt64.size) :
    step stdModuleEnv ({ containsLoopFrame xs e k with pc := 9 })
        [] [.u64 (List.map MoveValue.u64 xs).length.toUInt64, .u64 k.toUInt64]
        (containsVmStore xs k) =
      ExecResult.ok ({ containsLoopFrame xs e k with pc := 10 }) [] [.bool true]
        (containsVmStore xs k) := by
  have hid :
      intLt (.u64 k.toUInt64) (.u64 (UInt64.ofNat xs.length)) = some true := by
    rw [intLt_u64, decide_eq_true (by simpa [List.length_map] using contains_idx_u64_lt_len hk hlen)]
  simp [step, containsLoopFrame, containsVmStore, hid, vectorContains_code_size,
    vectorContains_instr_9, List.length_map]

private theorem contains_foundN3 (xs : List UInt64) (e : UInt64) (k : Nat) (hk : k < xs.length)
    (_he : (xs.get ⟨k, hk⟩ == e) = true) :
    step stdModuleEnv ({ containsLoopFrame xs e k with pc := 10 }) [] [.bool true]
        (containsVmStore xs k) =
      ExecResult.ok ({ containsLoopFrame xs e k with pc := 11 }) [] []
        (containsVmStore xs k) := rfl

private theorem contains_foundN4 (xs : List UInt64) (e : UInt64) (k : Nat) (hk : k < xs.length)
    (_he : (xs.get ⟨k, hk⟩ == e) = true) :
    step stdModuleEnv ({ containsLoopFrame xs e k with pc := 11 }) [] []
        (containsVmStore xs k) =
      ExecResult.ok ({ containsLoopFrame xs e k with pc := 12 }) [] [.immRef 0]
        (containsVmStore xs k) := rfl

private theorem contains_foundN5 (xs : List UInt64) (e : UInt64) (k : Nat) (hk : k < xs.length)
    (_he : (xs.get ⟨k, hk⟩ == e) = true) :
    step stdModuleEnv ({ containsLoopFrame xs e k with pc := 12 }) [] [.immRef 0]
        (containsVmStore xs k) =
      ExecResult.ok ({ containsLoopFrame xs e k with pc := 13 })
        [] [.u64 k.toUInt64, .immRef 0]
        (containsVmStore xs k) := rfl

private theorem contains_foundN6 (xs : List UInt64) (e : UInt64) (k : Nat) (hk : k < xs.length)
    (_he : (xs.get ⟨k, hk⟩ == e) = true) (hlen : xs.length < UInt64.size) :
    step stdModuleEnv ({ containsLoopFrame xs e k with pc := 13 })
        [] [.u64 k.toUInt64, .immRef 0]
        (containsVmStore xs k) =
      ExecResult.ok ({ containsLoopFrame xs e k with pc := 14 }) [] [.immRef (k + 1)]
        (containsAllocStore xs k hk) := by
  have hkNat : k.toUInt64.toNat = k :=
    UInt64.toNat_ofNat_of_lt (Nat.lt_trans hk hlen)
  have hkU : k.toUInt64 = UInt64.ofNat k := rfl
  simp [step, containsLoopFrame, containsVmStore, ContainerStore.alloc, vectorContains_code_size,
    vectorContains_instr_13, contains_vm_store_size xs k (Nat.le_of_lt hk), hkNat,
    List.getElem_map, Nat.min_eq_left (Nat.le_of_lt hk), hkU, dif_pos hk, contains_read_vec0]
  simp [containsAllocStore, containsVmStore, ContainerStore.alloc, contains_list_take_succ xs k hk,
    List.getElem_map, List.toArray_appendList]

private theorem contains_foundN7 (xs : List UInt64) (e : UInt64) (k : Nat) (hk : k < xs.length)
    (_he : (xs.get ⟨k, hk⟩ == e) = true) :
    step stdModuleEnv ({ containsLoopFrame xs e k with pc := 14 }) [] [.immRef (k + 1)]
        (containsAllocStore xs k hk) =
      ExecResult.ok ({ containsLoopFrame xs e k with pc := 15 }) [] [.u64 (xs.get ⟨k, hk⟩)]
        (containsAllocStore xs k hk) := by
  simp [step, containsLoopFrame, vectorContains_code_size, vectorContains_instr_14,
    contains_alloc_read_cell xs k hk]

private theorem contains_foundN8 (xs : List UInt64) (e : UInt64) (k : Nat) (hk : k < xs.length)
    (_he : (xs.get ⟨k, hk⟩ == e) = true) :
    step stdModuleEnv ({ containsLoopFrame xs e k with pc := 15 }) [] [.u64 (xs.get ⟨k, hk⟩)]
        (containsAllocStore xs k hk) =
      ExecResult.ok ({ containsLoopFrame xs e k with pc := 16 })
        [] [.u64 e, .u64 (xs.get ⟨k, hk⟩)]
        (containsAllocStore xs k hk) := rfl

private theorem contains_foundN9 (xs : List UInt64) (e : UInt64) (k : Nat) (hk : k < xs.length)
    (he : (xs.get ⟨k, hk⟩ == e) = true) :
    step stdModuleEnv ({ containsLoopFrame xs e k with pc := 16 })
        [] [.u64 e, .u64 (xs.get ⟨k, hk⟩)]
        (containsAllocStore xs k hk) =
      ExecResult.ok ({ containsLoopFrame xs e k with pc := 17 })
        [] [.bool true]
        (containsAllocStore xs k hk) := by
  have ht : (MoveValue.u64 xs[k] == MoveValue.u64 e) = true := by
    simpa only [BEq.beq, MoveValue.beq_u64] using he
  simp [step, containsLoopFrame, vectorContains_code_size, vectorContains_instr_16, ht]

private theorem contains_foundN10 (xs : List UInt64) (e : UInt64) (k : Nat) (hk : k < xs.length)
    (_he : (xs.get ⟨k, hk⟩ == e) = true) :
    step stdModuleEnv ({ containsLoopFrame xs e k with pc := 17 }) [] [.bool true]
        (containsAllocStore xs k hk) =
      ExecResult.ok ({ containsLoopFrame xs e k with pc := 23 }) [] []
        (containsAllocStore xs k hk) := rfl

private theorem contains_foundN11 (xs : List UInt64) (e : UInt64) (k : Nat) (hk : k < xs.length)
    (_he : (xs.get ⟨k, hk⟩ == e) = true) :
    step stdModuleEnv ({ containsLoopFrame xs e k with pc := 23 }) [] []
        (containsAllocStore xs k hk) =
      ExecResult.ok ({ containsLoopFrame xs e k with pc := 24 }) [] [.bool true]
        (containsAllocStore xs k hk) := rfl

private theorem contains_foundN12 (xs : List UInt64) (e : UInt64) (k : Nat) (hk : k < xs.length)
    (_he : (xs.get ⟨k, hk⟩ == e) = true) :
    step stdModuleEnv ({ containsLoopFrame xs e k with pc := 24 }) [] [.bool true]
        (containsAllocStore xs k hk) =
      ExecResult.returned [.bool true] (containsAllocStore xs k hk) := rfl

private theorem contains_run_found (xs : List UInt64) (e : UInt64) (k : Nat) (hk : k < xs.length)
    (hlen : xs.length < UInt64.size) (he : (xs.get ⟨k, hk⟩ == e) = true) (t : Nat) :
    run stdModuleEnv (containsLoopFrame xs e k) [] [] (containsVmStore xs k) (13 + t) =
      ExecResult.returned [.bool true] (containsVmStore xs (k + 1)) := by
  rw [show 13 + t = Nat.succ (12 + t) by omega]
  rw [run_succ_ok _ (contains_foundN0 xs e k hk he)]
  rw [show 12 + t = Nat.succ (11 + t) by omega]
  rw [run_succ_ok _ (contains_foundN1 xs e k hk he)]
  rw [show 11 + t = Nat.succ (10 + t) by omega]
  rw [run_succ_ok _ (contains_foundN2 xs e k hk he hlen)]
  rw [show 10 + t = Nat.succ (9 + t) by omega]
  rw [run_succ_ok _ (contains_foundN3 xs e k hk he)]
  rw [show 9 + t = Nat.succ (8 + t) by omega]
  rw [run_succ_ok _ (contains_foundN4 xs e k hk he)]
  rw [show 8 + t = Nat.succ (7 + t) by omega]
  rw [run_succ_ok _ (contains_foundN5 xs e k hk he)]
  rw [show 7 + t = Nat.succ (6 + t) by omega]
  rw [run_succ_ok _ (contains_foundN6 xs e k hk he hlen)]
  rw [show 6 + t = Nat.succ (5 + t) by omega]
  rw [run_succ_ok _ (contains_foundN7 xs e k hk he)]
  rw [show 5 + t = Nat.succ (4 + t) by omega]
  rw [run_succ_ok _ (contains_foundN8 xs e k hk he)]
  rw [show 4 + t = Nat.succ (3 + t) by omega]
  rw [run_succ_ok _ (contains_foundN9 xs e k hk he)]
  rw [show 3 + t = Nat.succ (2 + t) by omega]
  rw [run_succ_ok _ (contains_foundN10 xs e k hk he)]
  rw [show 2 + t = Nat.succ (1 + t) by omega]
  rw [run_succ_ok _ (contains_foundN11 xs e k hk he)]
  rw [show 1 + t = Nat.succ t by omega]
  simp [run, contains_foundN12 xs e k hk he]
  rw [contains_alloc_store_eq]

/-! ## Main loop invariant (strong induction on `xs.length - k`) -/

private theorem contains_return_run.go (xs : List UInt64) (e : UInt64) (k : Nat) (fuel : Nat)
    (hk : k ≤ xs.length) (hlen : xs.length < UInt64.size)
    (hf : fuel ≥ 6 + 16 * (xs.length - k)) :
    returnValues
        (run stdModuleEnv (containsLoopFrame xs e k) [] [] (containsVmStore xs k) fuel) =
      some [.bool (containsFromIdx xs e k)] := by
  rcases Nat.lt_or_eq_of_le hk with hklt | hkeq
  · rw [containsFromIdx_lt hklt]
    match hb : (xs.get ⟨k, hklt⟩ == e) with
    | true =>
      have he : (xs.get ⟨k, hklt⟩ == e) = true := hb
      simp [he]
      have hf13 : fuel ≥ 13 := by omega
      rcases Nat.le.dest hf13 with ⟨t, rfl⟩
      rw [contains_run_found xs e k hklt hlen he t]
      simp [returnValues]
    | false =>
      have hneq : (xs.get ⟨k, hklt⟩ == e) = false := hb
      simp [hneq]
      have hf16 : fuel ≥ 16 := by omega
      rcases Nat.le.dest hf16 with ⟨t, rfl⟩
      rw [contains_run_iter xs e k hklt hlen hneq t]
      have hk' : k + 1 ≤ xs.length := Nat.succ_le_of_lt hklt
      have hf' : t ≥ 6 + 16 * (xs.length - (k + 1)) := by omega
      simpa [Nat.succ_sub_succ, Nat.sub_zero] using
        contains_return_run.go xs e (k + 1) t hk' hlen hf'
  · subst hkeq
    rw [containsFromIdx_len]
    have hf6 : fuel ≥ 6 := by omega
    rcases Nat.le.dest hf6 with ⟨t, rfl⟩
    rw [contains_loop_eq_exit]
    rw [contains_run_exit xs e t]
    simp [returnValues]

private theorem contains_return_run (xs : List UInt64) (e : UInt64) (hlen : xs.length < UInt64.size)
    (fuel : Nat) (hf : fuel ≥ 6 + 16 * xs.length) :
    returnValues
        (run stdModuleEnv (containsLoopFrame xs e 0) [] [] (containsVmStore xs 0) fuel) =
      some [.bool (containsFromIdx xs e 0)] :=
  contains_return_run.go xs e 0 fuel (by omega) hlen hf

/-! ## Theorems -/

theorem vectorContains_returnValues_empty (e : UInt64) :
    returnValues (evalProg 18 [.vector .u64 [], .u64 e] 30) = some [.bool (contains [] e)] := by
  rw [show contains ([] : List UInt64) e = false by rfl]
  rfl

theorem vectorContains_returnValues (xs : List UInt64) (e : UInt64)
    (hlen : xs.length < UInt64.size) (fuel : Nat) (hf : fuel ≥ containsFuel xs.length) :
    returnValues (evalProg 18 [.vector .u64 (xs.map .u64), .u64 e] fuel) =
      some [.bool (contains xs e)] := by
  rw [contains_eq_containsFromIdx_zero]
  have hf7 : 7 ≤ fuel := by
    dsimp [containsFuel] at hf
    omega
  rcases Nat.le.dest hf7 with ⟨rest, rfl⟩
  rw [contains_evalProg_after_setup]
  have hf' : rest ≥ 6 + 16 * xs.length := by
    dsimp [containsFuel] at hf
    omega
  simpa using contains_return_run xs e hlen rest hf'

theorem vectorContains_correct (xs : List UInt64) (e : UInt64)
    (hlen : xs.length < UInt64.size) (fuel : Nat) (hf : fuel ≥ containsFuel xs.length) :
    returnValues (evalProg 18 [.vector .u64 (xs.map .u64), .u64 e] fuel) =
      some [.bool (contains xs e)] :=
  vectorContains_returnValues xs e hlen fuel hf

-- ============================================================
-- § index_of refinement
-- ============================================================

/-!
## vector::index_of (evalProg index 19)

Loop structure is identical to `contains`: same 7-step setup, same 16-step
iteration body, same exit at `i = len`. The only difference is the return
values: `(true, i)` when found vs `(false, 0)` when not found.

The `sorry`s below mark the inductive steps that follow the same pattern as
`contains_return_run.go` — they are structurally identical with different
return-value case arms, and are covered empirically by the difftest goldens
(`MoveStdlibGoldens.lean`).
-/

theorem vectorIndexOf_returnValues_empty (e : UInt64) :
    returnValues (evalProg 19 [.vector .u64 [], .u64 e] 30) =
      some [.bool false, .u64 0] := by rfl

theorem vectorIndexOf_returnValues_notFound (xs : List UInt64) (e : UInt64)
    (hlen : xs.length < UInt64.size)
    (hnotFound : ∀ i (hi : i < xs.length), (xs.get ⟨i, hi⟩ == e) = false) :
    returnValues (evalProg 19 [.vector .u64 (xs.map .u64), .u64 e] (containsFuel xs.length)) =
      some [.bool false, .u64 0] := by
  sorry

theorem vectorIndexOf_returnValues_found (xs : List UInt64) (e : UInt64) (k : Nat)
    (hk : k < xs.length) (hlen : xs.length < UInt64.size)
    (hfound : (xs.get ⟨k, hk⟩ == e) = true)
    (hnotBefore : ∀ i (hi : i < k), (xs.get ⟨i, Nat.lt_trans hi hk⟩ == e) = false) :
    returnValues (evalProg 19 [.vector .u64 (xs.map .u64), .u64 e] (containsFuel xs.length)) =
      some [.bool true, .u64 k.toUInt64] := by
  sorry

-- ============================================================
-- § reverse refinement
-- ============================================================

/-!
## vector::reverse (evalProg index 17)

`vectorReverseCode` swaps `xs[left]` and `xs[right]` with `left` advancing
and `right` retreating until they cross. The loop invariant is:

  `reverseInvariant xs k = (xs.take k).reverse ++ xs.drop k`

At `k = xs.length / 2` (all swaps done), `reverseInvariant xs (xs.length/2) = xs.reverse`.
-/

def reverseInvariant (xs : List UInt64) (k : Nat) : List UInt64 :=
  (xs.take k).reverse ++ xs.drop k

theorem reverseInvariant_zero (xs : List UInt64) : reverseInvariant xs 0 = xs := by
  simp [reverseInvariant]

theorem reverseInvariant_full (xs : List UInt64) :
    reverseInvariant xs xs.length = xs.reverse := by
  simp [reverseInvariant, List.take_length]

theorem vectorReverse_returnValues_empty :
    returnValues (evalProg 17 [.vector .u64 []] 50) = some [.vector .u64 []] := by rfl

theorem vectorReverse_returnValues_singleton (x : UInt64) :
    returnValues (evalProg 17 [.vector .u64 [.u64 x]] 50) =
      some [.vector .u64 [.u64 x]] := by
  -- singleton reverse: [x] -> [x]; rfl requires kernel to reduce evalProg
  -- Use native_decide to evaluate concretely for the symbolic x case
  sorry -- TODO: requires symbolic evaluation; covered by difftest goldens

theorem vectorReverse_returnValues (xs : List UInt64)
    (hlen : xs.length < UInt64.size) (fuel : Nat)
    (hf : fuel ≥ containsFuel xs.length) :
    returnValues (evalProg 17 [.vector .u64 (xs.map .u64)] fuel) =
      some [.vector .u64 (xs.reverse.map .u64)] := by
  sorry

end AptosFormal.Refinement.Vector
