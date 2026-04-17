import MovementFormal.MoveModel.Instr

/-!
# Move execution state

Pure-functional model of the Move VM's runtime state: operand stack, call
stack, locals, and program counter.

**Source:**
- `third_party/move/move-vm/runtime/src/interpreter.rs` — `InterpreterImpl`, `Stack`
- `third_party/move/move-vm/runtime/src/frame.rs` — `Frame`
-/

namespace MovementFormal.MoveModel

/-! ## Frame

A `Frame` represents a single function activation.  It holds the function's
bytecode, the program counter, and the local variable slots.  Locals use
`Option MoveValue` — `none` represents the "invalid" state before first
assignment (or while borrowed). -/

structure Frame where
  code : Array MoveInstr
  pc : Nat
  locals : Array (Option MoveValue)
  /-- Tracks which locals are "container-backed" from `MutBorrowLoc`.
      When `localRefs[idx] = some rid`, reads of local `idx` go through
      `ContainerStore.read rid` (getting the current value, which may have
      been modified through a mutable reference). -/
  localRefs : Array (Option RefId) := #[]
  deriving BEq

/-! ## Container store theorems

`ContainerStore` structure and basic operations are in `Value.lean` (to avoid
an import cycle with `FuncBody.nativeRef` in `Instr.lean`). Theorems live here. -/

/-- After **`alloc`**, the new cell at the returned **`RefId`** holds the allocated value. -/
theorem ContainerStore.read_of_alloc (cs : ContainerStore) (v : MoveValue) (cs' : ContainerStore) (rid : RefId)
    (h : ContainerStore.alloc cs v = (cs', rid)) : cs'.read rid = some v := by
  cases cs
  simp [ContainerStore.alloc] at h
  rcases h with ⟨rfl, rfl⟩
  simp [ContainerStore.read]

/-- After a successful in-bounds **`write`**, **`read`** at the same index returns the new value. -/
theorem ContainerStore.read_of_write (cs : ContainerStore) (id : RefId) (v : MoveValue) (cs' : ContainerStore)
    (hlt : id < cs.store.size) (h : cs.write id v = some cs') : cs'.read id = some v := by
  cases cs
  simp [ContainerStore.write, hlt] at h
  cases h
  simp [ContainerStore.read, hlt, Array.getElem_set_self]

/-! ## Global resources (L4 scaffolding)

`GlobalResourceKey` is defined in `Value.lean` (for import order). Real Move uses
**`move_to` / `borrow_global` / `exists`** with **`StructTag` + `address`**; we map
keys to heap cells via `globals`. FA / signer / real file-format opcodes are still
out of scope — see `difftest/STUB_POLICY.md`.

**Source (conceptual):** `interpreter.rs` resource loaders. -/

structure MachineState where
  containers : ContainerStore
  globals : List (GlobalResourceKey × RefId)
  /-- Difftest stub for primary-store style `(metadataKey, ownerKey) → balance` reads.
  Not the real on-chain FA layout — see `difftest/STUB_POLICY.md` Phase L5. -/
  faBalances : List ((UInt64 × UInt64) × UInt64) := []
  deriving BEq

def MachineState.empty : MachineState :=
  { containers := ContainerStore.empty, globals := [], faBalances := [] }

/-- Lift a heap with only locals (no globals) into a full machine state.

Uses `abbrev` so this is **definitionally** `{ containers := ct, globals := [] }`, which keeps
`step`/`ExecResult` reduction and `rfl` proofs (e.g. refinement) aligned. -/
abbrev MachineState.ofContainers (ct : ContainerStore) : MachineState :=
  { containers := ct, globals := [], faBalances := [] }

@[simp] theorem MachineState.containers_of_ofContainers (ct : ContainerStore) :
    (MachineState.ofContainers ct).containers = ct := rfl

@[simp] theorem MachineState.globals_of_ofContainers (ct : ContainerStore) :
    (MachineState.ofContainers ct).globals = [] := rfl

@[simp] theorem MachineState.faBalances_of_ofContainers (ct : ContainerStore) :
    (MachineState.ofContainers ct).faBalances = [] := rfl

@[simp] theorem MachineState.ofContainers_empty :
    MachineState.ofContainers ContainerStore.empty = MachineState.empty := rfl

/-- So existing lemmas that pass only a `ContainerStore` into `step` / `run` keep working. -/
instance : Coe ContainerStore MachineState where
  coe := MachineState.ofContainers

def MachineState.hasGlobal (ms : MachineState) (k : GlobalResourceKey) : Bool :=
  ms.globals.any fun p => p.1 == k

def MachineState.lookupGlobal (ms : MachineState) (k : GlobalResourceKey) : Option RefId :=
  (ms.globals.find? fun p => p.1 == k).map (·.2)

private theorem List_any_eq_false_of_find?_eq_none {α : Type _} (p : α → Bool) (l : List α)
    (h : l.find? p = none) : l.any p = false := by
  induction l with
  | nil => simp at h ⊢
  | cons x xs ih =>
    by_cases hpx : p x = true
    · have hf : List.find? p (x :: xs) = some x := by simp [List.find?, hpx]
      rw [hf] at h
      cases h
    · have hf : List.find? p (x :: xs) = List.find? p xs := by simp [List.find?, hpx]
      rw [hf] at h
      simp [List.any, hpx, ih h]

private theorem List_any_eq_true_of_find?_some {α : Type _} (p : α → Bool) (l : List α) (a : α)
    (h : l.find? p = some a) : l.any p = true := by
  induction l generalizing a with
  | nil => cases h
  | cons x xs ih =>
    by_cases hpx : p x = true
    · simp [List.find?, hpx] at h
      cases h
      simp [List.any, hpx]
    · simp [List.find?, hpx] at h
      simp [List.any, hpx, ih a h]

/-- If **`lookupGlobal k`** is **`some`**, the key is present in the global stub map. -/
theorem MachineState.hasGlobal_of_lookupGlobal_some (ms : MachineState) (k : GlobalResourceKey) (rid : RefId)
    (h : ms.lookupGlobal k = some rid) : ms.hasGlobal k = true := by
  cases hfind : ms.globals.find? (fun p => p.1 == k) with
  | none => simp [lookupGlobal, hfind] at h
  | some pair =>
    simpa [hasGlobal] using List_any_eq_true_of_find?_some (fun p => p.1 == k) ms.globals pair hfind

/-- If **`hasGlobal k`** is **`false`**, **`lookupGlobal k`** is **`none`**. -/
theorem MachineState.lookupGlobal_eq_none_of_hasGlobal_false (ms : MachineState) (k : GlobalResourceKey)
    (h : ms.hasGlobal k = false) : ms.lookupGlobal k = none := by
  cases hfind : ms.globals.find? (fun p => p.1 == k) with
  | none => simp [lookupGlobal, hfind]
  | some pair =>
    have hg : ms.hasGlobal k = true := by
      simpa [hasGlobal] using List_any_eq_true_of_find?_some (fun p => p.1 == k) ms.globals pair hfind
    simp [hg] at h

/-- If **`lookupGlobal k`** is **`none`**, the key is absent from the global stub map. -/
theorem MachineState.hasGlobal_eq_false_of_lookupGlobal_none (ms : MachineState) (k : GlobalResourceKey)
    (h : ms.lookupGlobal k = none) : ms.hasGlobal k = false := by
  cases hfind : ms.globals.find? (fun p => p.1 == k)
  · simp [lookupGlobal, hfind] at h
    simp [hasGlobal, List_any_eq_false_of_find?_eq_none _ _ hfind]
  · simp [lookupGlobal, hfind] at h

/-- **`lookupGlobal k = none`** iff **`hasGlobal k`** is **`false`**. -/
theorem MachineState.lookupGlobal_eq_none_iff_hasGlobal_eq_false (ms : MachineState) (k : GlobalResourceKey) :
    ms.lookupGlobal k = none ↔ ms.hasGlobal k = false :=
  ⟨hasGlobal_eq_false_of_lookupGlobal_none ms k, lookupGlobal_eq_none_of_hasGlobal_false ms k⟩

/-- Insert or replace the mapping for `k` → `rid` (container cell must already hold the resource). -/
def MachineState.registerGlobal (ms : MachineState) (k : GlobalResourceKey) (rid : RefId) : MachineState :=
  { ms with globals := (ms.globals.filter fun p => (p.1 == k) == false) ++ [(k, rid)] }

@[simp] theorem MachineState.registerGlobal_globals (ms : MachineState) (k : GlobalResourceKey) (rid : RefId) :
    (ms.registerGlobal k rid).globals =
      (ms.globals.filter fun p => (p.1 == k) == false) ++ [(k, rid)] := by
  cases ms; rfl

@[simp] theorem MachineState.registerGlobal_containers (ms : MachineState) (k : GlobalResourceKey) (rid : RefId) :
    (ms.registerGlobal k rid).containers = ms.containers := by
  cases ms; rfl

@[simp] theorem MachineState.registerGlobal_faBalances (ms : MachineState) (k : GlobalResourceKey) (rid : RefId) :
    (ms.registerGlobal k rid).faBalances = ms.faBalances := by
  cases ms; rfl

/-- `lookupGlobal` depends only on the `globals` field. -/
theorem MachineState.lookupGlobal_eq_of_globals_eq {ms ms' : MachineState}
    (h : ms'.globals = ms.globals) (k : GlobalResourceKey) :
    ms'.lookupGlobal k = ms.lookupGlobal k := by
  simp [lookupGlobal, h]

/-- `hasGlobal` depends only on the `globals` field. -/
theorem MachineState.hasGlobal_eq_of_globals_eq {ms ms' : MachineState}
    (h : ms'.globals = ms.globals) (k : GlobalResourceKey) :
    ms'.hasGlobal k = ms.hasGlobal k := by
  simp [hasGlobal, h]

def MachineState.lookupFaBalance (ms : MachineState) (metadataId owner : UInt64) : UInt64 :=
  match ms.faBalances.find? fun p => p.1.1 == metadataId && p.1.2 == owner with
  | some (_, bal) => bal
  | none => 0

/-- **`lookupFaBalance`** depends only on **`faBalances`**. -/
theorem MachineState.lookupFaBalance_eq_of_faBalances_eq {ms ms' : MachineState}
    (h : ms'.faBalances = ms.faBalances) (metadataId owner : UInt64) :
    ms'.lookupFaBalance metadataId owner = ms.lookupFaBalance metadataId owner := by
  simp [lookupFaBalance, h]

/-- On **`MachineState.empty`**, the FA stub map is empty — every **`lookupFaBalance`** reads **0**. -/
theorem MachineState.lookupFaBalance_empty (metadataId owner : UInt64) :
    MachineState.empty.lookupFaBalance metadataId owner = 0 := by
  unfold MachineState.empty lookupFaBalance
  rfl

/-- **`registerGlobal`** does not change **`lookupFaBalance`**. -/
theorem MachineState.lookupFaBalance_registerGlobal (ms : MachineState) (k : GlobalResourceKey) (rid : RefId)
    (metadataId owner : UInt64) :
    (ms.registerGlobal k rid).lookupFaBalance metadataId owner = ms.lookupFaBalance metadataId owner :=
  lookupFaBalance_eq_of_faBalances_eq (registerGlobal_faBalances ms k rid) metadataId owner

def MachineState.setFaBalance (ms : MachineState) (metadataId owner amt : UInt64) : MachineState :=
  let k := (metadataId, owner)
  { ms with
    faBalances := (ms.faBalances.filter fun p => p.1 != k) ++ [(k, amt)] }

@[simp] theorem MachineState.setFaBalance_globals (ms : MachineState) (m o amt : UInt64) :
    (ms.setFaBalance m o amt).globals = ms.globals := by
  cases ms; rfl

@[simp] theorem MachineState.setFaBalance_containers (ms : MachineState) (m o amt : UInt64) :
    (ms.setFaBalance m o amt).containers = ms.containers := by
  cases ms; rfl

/-- **`setFaBalance`** does not change **`hasGlobal`**. -/
theorem MachineState.hasGlobal_setFaBalance (ms : MachineState) (m o amt : UInt64) (k : GlobalResourceKey) :
    (ms.setFaBalance m o amt).hasGlobal k = ms.hasGlobal k :=
  hasGlobal_eq_of_globals_eq (setFaBalance_globals ms m o amt) k

/-- **`setFaBalance`** does not change **`lookupGlobal`**. -/
theorem MachineState.lookupGlobal_setFaBalance_eq (ms : MachineState) (m o amt : UInt64) (k : GlobalResourceKey) :
    (ms.setFaBalance m o amt).lookupGlobal k = ms.lookupGlobal k :=
  lookupGlobal_eq_of_globals_eq (setFaBalance_globals ms m o amt) k

/-- **`registerGlobal`** (globals only) commutes with **`setFaBalance`** (FA stub only). -/
theorem MachineState.registerGlobal_setFaBalance_comm (ms : MachineState) (k : GlobalResourceKey) (rid : RefId)
    (m o amt : UInt64) :
    ((ms.registerGlobal k rid).setFaBalance m o amt) = (ms.setFaBalance m o amt).registerGlobal k rid := by
  cases ms
  rfl

namespace MachineState

private abbrev FaEntry := ((UInt64 × UInt64) × UInt64)

private theorem fa_beq_prod_uint64 (p1 p2 m o : UInt64) :
    ((p1, p2) == (m, o)) = (p1 == m && p2 == o) := by
  simp [BEq.beq]

private theorem fa_bne_prod_uint64 (p1 p2 m o : UInt64) :
    ((p1, p2) != (m, o)) = !(p1 == m && p2 == o) := by
  rw [bne, fa_beq_prod_uint64]

private theorem List.find?_append_of_find?_eq_none {α : Type u} (p : α → Bool) (l₁ l₂ : List α)
    (h : l₁.find? p = none) : (l₁ ++ l₂).find? p = l₂.find? p := by
  induction l₁ with
  | nil => simp
  | cons a as ih =>
      simp only [List.find?_cons, List.cons_append] at h ⊢
      by_cases hpa : p a = true <;> simp_all

private theorem UInt64.pair_eq_of_coord_beq {m o p1 p2 : UInt64}
    (h1 : (p1 == m) = true) (h2 : (p2 == o) = true) : (p1, p2) = (m, o) := by
  rw [LawfulBEq.eq_of_beq h1, LawfulBEq.eq_of_beq h2]

private theorem fa_find?_filter_drop_key (m o : UInt64) (bal : List FaEntry) :
    (bal.filter fun p => p.1 != (m, o)).find? (fun p => p.1.1 == m && p.1.2 == o) = none := by
  refine List.find?_eq_none.mpr ?_
  intro p hp hmatch
  rw [List.mem_filter] at hp
  rcases hp with ⟨_, hdrop⟩
  rcases p with ⟨⟨p1, p2⟩, pb⟩
  have hc : (p1 == m) = true ∧ (p2 == o) = true := by
    simpa [Bool.and_eq_true] using hmatch
  have hk : (p1, p2) = (m, o) := UInt64.pair_eq_of_coord_beq hc.1 hc.2
  rw [hk] at hdrop
  simp at hdrop

private theorem fa_find?_append_singleton (m o amt : UInt64) (pref : List FaEntry)
    (hpre : pref.find? (fun p => p.1.1 == m && p.1.2 == o) = none) :
    (pref ++ [((m, o), amt)]).find? (fun p => p.1.1 == m && p.1.2 == o) =
      some ((m, o), amt) := by
  rw [List.find?_append_of_find?_eq_none _ _ _ hpre]
  simp

/-- **`setFaBalance`** on **`(m,o)`** makes **`lookupFaBalance m o`** return the written amount (FA stub map). -/
theorem lookupFaBalance_setFaBalance (ms : MachineState) (m o amt : UInt64) :
    (ms.setFaBalance m o amt).lookupFaBalance m o = amt := by
  cases ms
  simp only [setFaBalance, lookupFaBalance]
  rename_i ct gl fac
  let pref := fac.filter fun p => p.1 != (m, o)
  have hf := fa_find?_filter_drop_key m o fac
  have happ := fa_find?_append_singleton m o amt pref hf
  simp [pref, happ]

/-- Same as **`lookupFaBalance_setFaBalance`** specialized to **`MachineState.empty`**. -/
theorem lookupFaBalance_setFaBalance_from_empty (metadataId owner amt : UInt64) :
    (MachineState.empty.setFaBalance metadataId owner amt).lookupFaBalance metadataId owner = amt :=
  lookupFaBalance_setFaBalance MachineState.empty metadataId owner amt

/-- **`setFaBalance`** is **last-wins** on the same **`(metadataId, owner)`** pair. -/
theorem lookupFaBalance_setFaBalance_setFaBalance (ms : MachineState) (m o amt₁ amt₂ : UInt64) :
    ((ms.setFaBalance m o amt₁).setFaBalance m o amt₂).lookupFaBalance m o = amt₂ := by
  simpa using lookupFaBalance_setFaBalance (ms.setFaBalance m o amt₁) m o amt₂

private theorem UInt64.pair_bne_of_coord_and_false {m o p1 p2 : UInt64}
    (h : (p1 == m && p2 == o) = false) : ((p1, p2) != (m, o)) = true := by
  rw [fa_bne_prod_uint64, h]
  rfl

private theorem fa_lookup_pred_eq_filter_pred {m o m' o' : UInt64} (hne : (m' == m && o' == o) = false) :
    (fun (p : FaEntry) => p.1.1 == m' && p.1.2 == o') =
      fun p => p.1 != (m, o) && (p.1.1 == m' && p.1.2 == o') := by
  funext p
  rcases p with ⟨⟨p1, p2⟩, pb⟩
  by_cases hand : (p1 == m && p2 == o) = true
  · rcases (Bool.and_eq_true_iff.mp hand) with ⟨hp1, hp2⟩
    have hpkeep : (((p1, p2), pb).1 != (m, o)) = false := by
      simp [fa_bne_prod_uint64, hp1, hp2]
    have hlo : (p1 == m' && p2 == o') = false := by
      rw [(LawfulBEq.eq_of_beq hp1 : p1 = m), (LawfulBEq.eq_of_beq hp2 : p2 = o)]
      have hflip : (m == m' && o == o') = (m' == m && o' == o) := by
        simp [Bool.beq_comm]
      rw [hflip, hne]
    simp [hpkeep, hlo]
  · have hband : (p1 == m && p2 == o) = false := by
      cases hb : (p1 == m && p2 == o)
      · rfl
      · exact False.elim (hand hb)
    have hpkeep : (((p1, p2), pb).1 != (m, o)) = true :=
      UInt64.pair_bne_of_coord_and_false hband
    simp [hpkeep, Bool.true_and]

private theorem List.find?_filter_eq_find? {α : Type} (p q : α → Bool) (xs : List α)
    (h : ∀ x, (p x && q x) = q x) : (xs.filter p).find? q = xs.find? q := by
  induction xs with
  | nil => rfl
  | cons x xs ih =>
    have hq_of_not_p : p x = false → q x = false := by
      intro hpx
      have hx := h x
      simpa [hpx] using hx.symm
    by_cases hpx : p x = true
    · simp only [List.filter_cons, hpx, List.find?_cons, ↓reduceIte]
      by_cases hq : q x = true
      · simp only [hq]
      · simp only [hq]
        exact ih
    · have hq : q x = false := hq_of_not_p (Bool.eq_false_iff.mpr hpx)
      simp only [List.filter_cons, hpx, List.find?_cons, hq]
      exact ih

private theorem List.any_filter_eq {α : Type} (p q : α → Bool) (xs : List α)
    (h : ∀ x, (p x && q x) = q x) : (xs.filter p).any q = xs.any q := by
  induction xs with
  | nil => rfl
  | cons x xs ih =>
    have hq_of_not_p : p x = false → q x = false := by
      intro hpx
      have hx := h x
      simpa [hpx] using hx.symm
    by_cases hpx : p x = true
    · simp only [List.filter_cons, hpx, List.any_cons, ↓reduceIte]
      by_cases hq : q x = true
      · simp only [hq, Bool.true_or]
      · simp only [hq, Bool.false_or]
        exact ih
    · have hq : q x = false := hq_of_not_p (Bool.eq_false_iff.mpr hpx)
      simp only [List.filter_cons, hpx, List.any_cons, hq, Bool.false_or]
      exact ih

/-- Updating **`(m,o)`** does not change **`lookupFaBalance m' o'`** when **`(m',o')` ≠ `(m,o)`** (coordinate `BEq`). -/
theorem lookupFaBalance_setFaBalance_of_keys_bne (ms : MachineState) (m o m' o' amt : UInt64)
    (hne : (m' == m && o' == o) = false) :
    (ms.setFaBalance m o amt).lookupFaBalance m' o' = ms.lookupFaBalance m' o' := by
  cases ms
  simp only [setFaBalance, lookupFaBalance]
  rename_i ct gl fac
  let qfa : FaEntry → Bool := fun r => r.1.1 == m' && r.1.2 == o'
  let filt : List FaEntry := fac.filter fun p => p.1 != (m, o)
  let pkeep : FaEntry → Bool := fun r => r.1 != (m, o)
  have hfilt : filt.find? qfa = fac.find? qfa :=
    List.find?_filter_eq_find? pkeep qfa fac fun x =>
      show (pkeep x && qfa x) = qfa x by
        have hp := congrFun (fa_lookup_pred_eq_filter_pred hne) x
        dsimp [pkeep, qfa]
        simp [← hp]
  have hsing : ([((m, o), amt)] : List FaEntry).find? qfa = none := by
    cases hb : (m' == m && o' == o)
    · have hcond : (m == m' && o == o') = false := by
        have hflip : (m == m' && o == o') = (m' == m && o' == o) := by
          simp [Bool.beq_comm]
        rw [hflip, hb]
      simp only [qfa, List.find?_singleton, hcond]
      rfl
    · simp [hb] at hne
  have happ : (filt ++ [((m, o), amt)]).find? qfa = filt.find? qfa := by
    simp [List.find?_append, hsing]
  have hfind : (filt ++ [((m, o), amt)]).find? qfa = fac.find? qfa := by
    rw [happ, hfilt]
  exact congrArg (fun opt => match opt with | some (_, bal) => bal | none => 0) hfind

private abbrev GlobalEntry := (GlobalResourceKey × RefId)

private theorem grk_beq_comm (a b : GlobalResourceKey) : (a == b) = (b == a) := by
  by_cases h : a = b
  · subst h
    simp
  · simp [BEq.beq, h, Ne.symm h]

private theorem global_find?_filter_drop_key (k : GlobalResourceKey) (gl : List GlobalEntry) :
    (gl.filter fun p => (p.1 == k) == false).find? (fun p => p.1 == k) = none := by
  refine List.find?_eq_none.mpr ?_
  intro p hp hmatch
  rw [List.mem_filter] at hp
  rcases hp with ⟨_, hneq⟩
  have hpred : (p.1 == k) = false := by
    cases hb : (p.1 == k) <;> simp_all
  rw [hpred] at hmatch
  simp at hmatch

private theorem global_find?_append_singleton (k : GlobalResourceKey) (rid : RefId)
    (pref : List GlobalEntry)
    (hpre : pref.find? (fun p => p.1 == k) = none) :
    (pref ++ [(k, rid)]).find? (fun p => p.1 == k) = some (k, rid) := by
  rw [List.find?_append_of_find?_eq_none _ _ _ hpre]
  simp

private theorem global_lookup_pred_eq_filter_pred {k k' : GlobalResourceKey} (hne : (k' == k) = false) :
    (fun (p : GlobalEntry) => p.1 == k') =
      fun p => (p.1 == k) == false && p.1 == k' := by
  funext p
  rcases p with ⟨g, r⟩
  by_cases hgk' : (g == k') = true
  · by_cases hgk : (g == k) = true
    · have egk : g = k := LawfulBEq.eq_of_beq hgk
      have egk' : g = k' := LawfulBEq.eq_of_beq hgk'
      have hk_eq : k' = k := Eq.trans (Eq.symm egk') egk
      rw [hk_eq] at hne
      simp at hne
    · have hpkeep : ((g == k) == false) = true := by simp [hgk]
      simp [hpkeep, hgk']
  · simp [hgk']

/-- **`registerGlobal k rid`** makes **`lookupGlobal k`** return **`some rid`** (global stub map). -/
theorem lookupGlobal_registerGlobal (ms : MachineState) (k : GlobalResourceKey) (rid : RefId) :
    (ms.registerGlobal k rid).lookupGlobal k = some rid := by
  cases ms
  simp only [registerGlobal, lookupGlobal]
  rename_i ct gl fac
  let pref := gl.filter fun p => (p.1 == k) == false
  have hf := global_find?_filter_drop_key k gl
  rw [List.find?_append_of_find?_eq_none (fun p : GlobalEntry => p.1 == k) pref [(k, rid)] hf]
  simp

/-- Same as **`lookupGlobal_registerGlobal`** on **`MachineState.empty`**. -/
theorem lookupGlobal_registerGlobal_from_empty (k : GlobalResourceKey) (rid : RefId) :
    (MachineState.empty.registerGlobal k rid).lookupGlobal k = some rid :=
  lookupGlobal_registerGlobal MachineState.empty k rid

/-- **`registerGlobal`** is **last-wins** on the same key: a second publish replaces the ref id. -/
theorem lookupGlobal_registerGlobal_registerGlobal (ms : MachineState) (k : GlobalResourceKey)
    (rid₁ rid₂ : RefId) :
    ((ms.registerGlobal k rid₁).registerGlobal k rid₂).lookupGlobal k = some rid₂ := by
  simpa using lookupGlobal_registerGlobal (ms.registerGlobal k rid₁) k rid₂

/-- Publishing **`k`** does not change **`lookupGlobal k'`** when **`(k' == k) = false`** (global stub map). -/
theorem lookupGlobal_registerGlobal_of_keys_bne (ms : MachineState) (k k' : GlobalResourceKey) (rid : RefId)
    (hne : (k' == k) = false) :
    (ms.registerGlobal k rid).lookupGlobal k' = ms.lookupGlobal k' := by
  cases ms
  simp only [registerGlobal, lookupGlobal]
  rename_i ct gl fac
  let qg : GlobalEntry → Bool := fun r => r.1 == k'
  let filt : List GlobalEntry := gl.filter fun p => (p.1 == k) == false
  let pkeep : GlobalEntry → Bool := fun p => (p.1 == k) == false
  have hfilt : filt.find? qg = gl.find? qg :=
    List.find?_filter_eq_find? pkeep qg gl fun x =>
      show (pkeep x && qg x) = qg x by
        have hp := congrFun (global_lookup_pred_eq_filter_pred hne) x
        dsimp [pkeep, qg]
        simpa using hp
  have hsing : ([(k, rid)] : List GlobalEntry).find? qg = none := by
    cases hb : (k' == k)
    · have hcond : (k == k') = false := by
        rw [← grk_beq_comm k' k]
        exact hb
      simp only [qg, List.find?_singleton, hcond]
      rfl
    · simp [hb] at hne
  have happ : (filt ++ [(k, rid)]).find? qg = filt.find? qg := by
    simp [List.find?_append, hsing]
  have hfind : (filt ++ [(k, rid)]).find? qg = gl.find? qg := by
    rw [happ, hfilt]
  exact congrArg (fun opt => opt.map (·.2)) hfind

/-- Two publishes to **`k`** leave **`lookupGlobal k'`** unchanged when **`(k' == k) = false`**. -/
theorem lookupGlobal_registerGlobal_registerGlobal_of_keys_bne (ms : MachineState)
    (k k' : GlobalResourceKey) (rid₁ rid₂ : RefId) (hne : (k' == k) = false) :
    ((ms.registerGlobal k rid₁).registerGlobal k rid₂).lookupGlobal k' = ms.lookupGlobal k' := by
  rw [lookupGlobal_registerGlobal_of_keys_bne _ k k' rid₂ hne,
    lookupGlobal_registerGlobal_of_keys_bne _ k k' rid₁ hne]

private theorem global_any_singleton_false (k k' : GlobalResourceKey) (rid : RefId) (hne : (k' == k) = false) :
    ([(k, rid)] : List GlobalEntry).any (fun p => p.1 == k') = false := by
  simp only [List.any, Bool.or_false]
  have hcond : (k == k') = false := by
    rw [← grk_beq_comm k' k]
    exact hne
  simp [hcond]

/-- After **`registerGlobal k rid`**, **`hasGlobal k`** is **`true`**. -/
theorem hasGlobal_registerGlobal (ms : MachineState) (k : GlobalResourceKey) (rid : RefId) :
    (ms.registerGlobal k rid).hasGlobal k = true := by
  cases ms
  simp only [hasGlobal, registerGlobal, List.any_append, List.any, Bool.or_false]
  simp

/-- Still **`true`** after a second **`registerGlobal`** on the same key (**last-wins** lookup). -/
theorem hasGlobal_registerGlobal_registerGlobal (ms : MachineState) (k : GlobalResourceKey)
    (rid₁ rid₂ : RefId) :
    ((ms.registerGlobal k rid₁).registerGlobal k rid₂).hasGlobal k = true := by
  simpa using hasGlobal_registerGlobal (ms.registerGlobal k rid₁) k rid₂

/-- **`hasGlobal k'`** is unchanged by **`registerGlobal k rid`** when **`(k' == k) = false`**. -/
theorem hasGlobal_registerGlobal_of_keys_bne (ms : MachineState) (k k' : GlobalResourceKey) (rid : RefId)
    (hne : (k' == k) = false) :
    (ms.registerGlobal k rid).hasGlobal k' = ms.hasGlobal k' := by
  cases ms
  simp only [hasGlobal, registerGlobal]
  rename_i ct gl fac
  let qg : GlobalEntry → Bool := fun p => p.1 == k'
  let filt : List GlobalEntry := gl.filter fun p => (p.1 == k) == false
  let pkeep : GlobalEntry → Bool := fun p => (p.1 == k) == false
  have hf : filt.any qg = gl.any qg :=
    List.any_filter_eq pkeep qg gl fun x =>
      show (pkeep x && qg x) = qg x by
        have hp := congrFun (global_lookup_pred_eq_filter_pred hne) x
        dsimp [pkeep, qg]
        simpa using hp
  have hsing : ([(k, rid)] : List GlobalEntry).any qg = false :=
    global_any_singleton_false k k' rid hne
  rw [List.any_append, hsing, hf, Bool.or_false]

/-- Two publishes to **`k`** leave **`hasGlobal k'`** unchanged when **`(k' == k) = false`**. -/
theorem hasGlobal_registerGlobal_registerGlobal_of_keys_bne (ms : MachineState)
    (k k' : GlobalResourceKey) (rid₁ rid₂ : RefId) (hne : (k' == k) = false) :
    ((ms.registerGlobal k rid₁).registerGlobal k rid₂).hasGlobal k' = ms.hasGlobal k' := by
  rw [hasGlobal_registerGlobal_of_keys_bne _ k k' rid₂ hne,
    hasGlobal_registerGlobal_of_keys_bne _ k k' rid₁ hne]

/-- Same `globals` as **`registerGlobal`**, after a **`ContainerStore.alloc`** that yields **`rid`**, still exposes **`rid`**
at **`k`** (matches **`globalMoveTo`** / **`globalMoveToSigned`** globals update in **`Step.step`**). -/
theorem lookupGlobal_with_globals_of_registerGlobal (ms : MachineState) (k : GlobalResourceKey)
    (v : MoveValue) (containers' : ContainerStore) (rid : RefId)
    (_halloc : ContainerStore.alloc ms.containers v = (containers', rid)) :
    ({ ms with containers := containers', globals := (ms.registerGlobal k rid).globals }).lookupGlobal k =
      some rid := by
  have hg : ({ ms with containers := containers', globals := (ms.registerGlobal k rid).globals }).globals =
      (ms.registerGlobal k rid).globals := rfl
  rw [MachineState.lookupGlobal_eq_of_globals_eq hg]
  exact lookupGlobal_registerGlobal ms k rid

/-- Same situation: **`hasGlobal k`** after publishing matches **`registerGlobal`**. -/
theorem hasGlobal_with_globals_of_registerGlobal (ms : MachineState) (k : GlobalResourceKey)
    (v : MoveValue) (containers' : ContainerStore) (rid : RefId)
    (_halloc : ContainerStore.alloc ms.containers v = (containers', rid)) :
    ({ ms with containers := containers', globals := (ms.registerGlobal k rid).globals }).hasGlobal k = true := by
  have hg : ({ ms with containers := containers', globals := (ms.registerGlobal k rid).globals }).globals =
      (ms.registerGlobal k rid).globals := rfl
  rw [MachineState.hasGlobal_eq_of_globals_eq hg]
  exact hasGlobal_registerGlobal ms k rid

/-- **`lookupGlobal k'`** unchanged when only **`globals`** match **`registerGlobal k rid`** and **`(k' == k) = false`**
(same **`globalMoveTo`** globals update as **`lookupGlobal_with_globals_of_registerGlobal`**, for an unrelated key). -/
theorem lookupGlobal_with_globals_of_registerGlobal_of_keys_bne (ms : MachineState) (k k' : GlobalResourceKey)
    (v : MoveValue) (containers' : ContainerStore) (rid : RefId)
    (_halloc : ContainerStore.alloc ms.containers v = (containers', rid)) (hne : (k' == k) = false) :
    ({ ms with containers := containers', globals := (ms.registerGlobal k rid).globals }).lookupGlobal k' =
      ms.lookupGlobal k' := by
  have hg : ({ ms with containers := containers', globals := (ms.registerGlobal k rid).globals }).globals =
      (ms.registerGlobal k rid).globals := rfl
  rw [MachineState.lookupGlobal_eq_of_globals_eq hg]
  exact lookupGlobal_registerGlobal_of_keys_bne ms k k' rid hne

/-- **`hasGlobal k'`** unchanged under the same **`globalMoveTo`**-shaped update when **`(k' == k) = false`**. -/
theorem hasGlobal_with_globals_of_registerGlobal_of_keys_bne (ms : MachineState) (k k' : GlobalResourceKey)
    (v : MoveValue) (containers' : ContainerStore) (rid : RefId)
    (_halloc : ContainerStore.alloc ms.containers v = (containers', rid)) (hne : (k' == k) = false) :
    ({ ms with containers := containers', globals := (ms.registerGlobal k rid).globals }).hasGlobal k' =
      ms.hasGlobal k' := by
  have hg : ({ ms with containers := containers', globals := (ms.registerGlobal k rid).globals }).globals =
      (ms.registerGlobal k rid).globals := rfl
  rw [MachineState.hasGlobal_eq_of_globals_eq hg]
  exact hasGlobal_registerGlobal_of_keys_bne ms k k' rid hne

end MachineState

/-- Publish **`k`** after an FA stub write: **`lookupGlobal k`** still reads the new ref (**`setFaBalance`** does not touch **`globals`**). -/
theorem MachineState.lookupGlobal_registerGlobal_setFaBalance (ms : MachineState) (k : GlobalResourceKey) (rid : RefId)
    (m o amt : UInt64) :
    ((ms.setFaBalance m o amt).registerGlobal k rid).lookupGlobal k = some rid := by
  rw [← MachineState.registerGlobal_setFaBalance_comm]
  rw [MachineState.lookupGlobal_setFaBalance_eq]
  exact MachineState.lookupGlobal_registerGlobal ms k rid

/-- **`lookupGlobal k'`** for **`k' ≠ k`** ignores **`setFaBalance`** then publish at **`k`** (FA stub + unrelated global key). -/
theorem MachineState.lookupGlobal_setFaBalance_registerGlobal_of_keys_bne (ms : MachineState) (k k' : GlobalResourceKey)
    (rid : RefId) (m o amt : UInt64) (hne : (k' == k) = false) :
    ((ms.setFaBalance m o amt).registerGlobal k rid).lookupGlobal k' = ms.lookupGlobal k' := by
  rw [← MachineState.registerGlobal_setFaBalance_comm]
  rw [MachineState.lookupGlobal_setFaBalance_eq]
  exact MachineState.lookupGlobal_registerGlobal_of_keys_bne ms k k' rid hne

/-- **`hasGlobal k'`** for **`k' ≠ k`** ignores **`setFaBalance`** then publish at **`k`**. -/
theorem MachineState.hasGlobal_setFaBalance_registerGlobal_of_keys_bne (ms : MachineState) (k k' : GlobalResourceKey)
    (rid : RefId) (m o amt : UInt64) (hne : (k' == k) = false) :
    ((ms.setFaBalance m o amt).registerGlobal k rid).hasGlobal k' = ms.hasGlobal k' := by
  rw [← MachineState.registerGlobal_setFaBalance_comm]
  rw [MachineState.hasGlobal_setFaBalance]
  exact MachineState.hasGlobal_registerGlobal_of_keys_bne ms k k' rid hne

/-- **`hasGlobal k'`** for **`k' ≠ k`** ignores **`registerGlobal k`** then **`setFaBalance`**. -/
theorem MachineState.hasGlobal_registerGlobal_setFaBalance_of_keys_bne (ms : MachineState) (k k' : GlobalResourceKey)
    (rid : RefId) (m o amt : UInt64) (hne : (k' == k) = false) :
    ((ms.registerGlobal k rid).setFaBalance m o amt).hasGlobal k' = ms.hasGlobal k' := by
  rw [MachineState.hasGlobal_setFaBalance]
  exact MachineState.hasGlobal_registerGlobal_of_keys_bne ms k k' rid hne

/-- FA read-back after **`setFaBalance`** then **`registerGlobal`** (same as **`setFaBalance`** after **`registerGlobal`**). -/
theorem MachineState.lookupFaBalance_setFaBalance_registerGlobal (ms : MachineState) (k : GlobalResourceKey) (rid : RefId)
    (m o amt : UInt64) :
    ((ms.setFaBalance m o amt).registerGlobal k rid).lookupFaBalance m o = amt := by
  rw [← MachineState.registerGlobal_setFaBalance_comm]
  exact MachineState.lookupFaBalance_setFaBalance (ms.registerGlobal k rid) m o amt

/-- FA read-back after **`registerGlobal`** then **`setFaBalance`** (same as bare **`setFaBalance`** on **`ms`**). -/
theorem MachineState.lookupFaBalance_registerGlobal_setFaBalance (ms : MachineState) (k : GlobalResourceKey) (rid : RefId)
    (m o amt : UInt64) :
    ((ms.registerGlobal k rid).setFaBalance m o amt).lookupFaBalance m o = amt :=
  MachineState.lookupFaBalance_setFaBalance (ms.registerGlobal k rid) m o amt

/-- **`hasGlobal`** unchanged by **`setFaBalance`** after **`registerGlobal`**. -/
theorem MachineState.hasGlobal_registerGlobal_setFaBalance (ms : MachineState) (k : GlobalResourceKey) (rid : RefId)
    (k' : GlobalResourceKey) (m o amt : UInt64) :
    ((ms.registerGlobal k rid).setFaBalance m o amt).hasGlobal k' = (ms.registerGlobal k rid).hasGlobal k' := by
  rw [MachineState.hasGlobal_setFaBalance]

/-! **L4 note:** `registerGlobal` / `setFaBalance` follow a **last-wins** map discipline (filter out prior
bindings for the same key, then append one pair). This matches intuitive “overwrite published resource”
behavior for difftest / future proofs; see also
**[`CONFIDENTIAL_ASSETS_MOVE_AUDIT_NOTES.md`](../../../CONFIDENTIAL_ASSETS_MOVE_AUDIT_NOTES.md)**.
Machine-checked: **`MachineState.registerGlobal_setFaBalance_comm`** (**`registerGlobal`** commutes with **`setFaBalance`**);
**`MachineState.lookupGlobal_registerGlobal_setFaBalance`** (**`lookupGlobal`** after **`setFaBalance`** then **`registerGlobal`**);
**`MachineState.lookupGlobal_setFaBalance_registerGlobal_of_keys_bne`** (**`lookupGlobal k'`** for **`k' ≠ k`** after the same composition);
**`MachineState.hasGlobal_setFaBalance_registerGlobal_of_keys_bne`** (**`hasGlobal k'`** for **`k' ≠ k`** after the same composition);
**`MachineState.hasGlobal_registerGlobal_setFaBalance_of_keys_bne`** (**`hasGlobal k'`** for **`k' ≠ k`** after **`registerGlobal`** then **`setFaBalance`**);
**`MachineState.lookupFaBalance_setFaBalance_registerGlobal`** (**`lookupFaBalance`** after the same composition);
**`MachineState.lookupFaBalance_registerGlobal_setFaBalance`** (**`registerGlobal`** then **`setFaBalance`**),
**`MachineState.hasGlobal_registerGlobal_setFaBalance`** (**`hasGlobal k'`** unchanged by **`setFaBalance`** after **`registerGlobal`**),
**`MachineState.lookupFaBalance_eq_of_faBalances_eq`** (**`lookupFaBalance`** from **`faBalances`** only),
**`MachineState.lookupFaBalance_registerGlobal`** (**`registerGlobal`** preserves FA stub reads),
**`MachineState.lookupFaBalance_setFaBalance`** (read-back after **`setFaBalance`**),
**`lookupFaBalance_setFaBalance_setFaBalance`** (last-wins overwrite on the same FA key) and
**`lookupFaBalance_setFaBalance_setFaBalance_of_keys_bne`** (other FA keys unchanged after two writes to **`(m,o)`**),
**`lookupFaBalance_setFaBalance_from_empty`**, and **`lookupFaBalance_setFaBalance_of_keys_bne`** (other FA keys
unchanged when updating a distinct **`(metadataId, owner)`** pair); **`lookupGlobal_registerGlobal`** /
**`lookupGlobal_registerGlobal_from_empty`** (read-back after **`registerGlobal`** on the same key) and
**`lookupGlobal_registerGlobal_of_keys_bne`** / **`lookupGlobal_registerGlobal_registerGlobal_of_keys_bne`**
(other global keys unchanged after one or **two** publishes to **`k`** when **`k' ≠ k`** in **`BEq`**);
**`hasGlobal_registerGlobal`** / **`hasGlobal_registerGlobal_registerGlobal`** / **`hasGlobal_registerGlobal_of_keys_bne`** /
**`hasGlobal_registerGlobal_registerGlobal_of_keys_bne`** — same **`hasGlobal`** discipline as **`lookupGlobal`** above.
**`registerGlobal_{globals,containers,faBalances}`** simp lemmas, **`lookupGlobal_eq_of_globals_eq`** / **`hasGlobal_eq_of_globals_eq`**, and
**`lookupGlobal_with_globals_of_registerGlobal`** / **`hasGlobal_with_globals_of_registerGlobal`** (link **`Step.globalMoveTo`** globals to **`registerGlobal`** after **`alloc`**);
**`lookupGlobal_with_globals_of_registerGlobal_of_keys_bne`** / **`hasGlobal_with_globals_of_registerGlobal_of_keys_bne`** (same **`globalMoveTo`**-shaped state, unrelated **`k'`** unchanged);
**`lookupGlobal_registerGlobal_registerGlobal`** (last-wins overwrite on the same key);
**`ContainerStore.read_of_alloc`** (read-back after **`ContainerStore.alloc`**); **`ContainerStore.read_of_write`**
(read-back after an in-bounds **`write`**); **`hasGlobal_eq_false_of_lookupGlobal_none`** (**`lookupGlobal k = none`** ⇒ **`hasGlobal k`** is **`false`**);
**`hasGlobal_of_lookupGlobal_some`** (**`lookupGlobal k = some rid`** ⇒ **`hasGlobal k`** is **`true`**);
**`lookupGlobal_eq_none_of_hasGlobal_false`** / **`lookupGlobal_eq_none_iff_hasGlobal_eq_false`** (classify absent keys).
**`setFaBalance_globals`** / **`setFaBalance_containers`**, **`hasGlobal_setFaBalance`**, **`lookupGlobal_setFaBalance_eq`** (FA stub writes do not disturb the global stub map).

## Execution outcome

`ExecResult` captures the four ways a single step can complete:

- `ok s'` — normal transition to a new machine state
- `returned vs` — the top-level function returned values
- `aborted code` — explicit `abort` with an error code
- `error` — runtime error (type mismatch, out of bounds, etc.) -/

inductive ExecResult where
  | ok (frame : Frame) (callStack : List Frame) (stack : List MoveValue)
      (ms : MachineState)
  | returned (values : List MoveValue) (ms : MachineState)
  | aborted (code : UInt64)
  | error
  deriving BEq

namespace ExecResult

/-- Top-level return list; ignores `MachineState` (borrow paths may leave allocated refs). -/
def returnValues : ExecResult → Option (List MoveValue)
  | .returned vs _ => some vs
  | _ => none

end ExecResult

/-! ## Module environment

`ModuleEnv` bundles the constant pool and function table needed by the
evaluator.  Native functions plug in through `FuncBody.native`. -/

structure ModuleEnv where
  constants : Array ConstPoolEntry
  functions : Array FuncDesc

end MovementFormal.MoveModel
