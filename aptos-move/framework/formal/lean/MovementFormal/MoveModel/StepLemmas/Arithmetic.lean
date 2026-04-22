import MovementFormal.MoveModel.Step

/-!
# Step lemmas: arithmetic and comparison instructions

Parametric step lemmas for `add` / `sub` / `mul` / `div` / `mod_` / `bitOr` / `bitAnd` /
`eq` / `neq` / `lt` / `gt` / `le` / `ge` / `not` / `or` / `and`.

Each lemma takes the two operands (with the Move convention that stack is `[rhs, lhs, …]`)
and the result of the pure-math operation (as an `Option` — `none` for overflow or type
mismatch). This keeps the lemmas agnostic to the underlying `intAdd`/`intSub`/etc.
implementations in `Step.lean`.
-/

set_option linter.unusedSimpArgs false

namespace MovementFormal.MoveModel.StepLemmas

open MovementFormal.MoveModel

variable {env : ModuleEnv} {frame : Frame} {cs : List Frame}
variable {ms : MachineState}

/-! ## Binary arithmetic (two-operand consuming, produces single result) -/

theorem step_add (lhs rhs v : MoveValue) (rest : List MoveValue)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .add)
    (hop : intAdd lhs rhs = some v) :
    step env frame cs (rhs :: lhs :: rest) ms =
      .ok { frame with pc := frame.pc + 1 } cs (v :: rest) ms := by
  simp only [step, dif_pos hpc, hc, hop]

theorem step_sub (lhs rhs v : MoveValue) (rest : List MoveValue)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .sub)
    (hop : intSub lhs rhs = some v) :
    step env frame cs (rhs :: lhs :: rest) ms =
      .ok { frame with pc := frame.pc + 1 } cs (v :: rest) ms := by
  simp only [step, dif_pos hpc, hc, hop]

theorem step_mul (lhs rhs v : MoveValue) (rest : List MoveValue)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .mul)
    (hop : intMul lhs rhs = some v) :
    step env frame cs (rhs :: lhs :: rest) ms =
      .ok { frame with pc := frame.pc + 1 } cs (v :: rest) ms := by
  simp only [step, dif_pos hpc, hc, hop]

theorem step_div (lhs rhs v : MoveValue) (rest : List MoveValue)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .div)
    (hop : intDiv lhs rhs = some v) :
    step env frame cs (rhs :: lhs :: rest) ms =
      .ok { frame with pc := frame.pc + 1 } cs (v :: rest) ms := by
  simp only [step, dif_pos hpc, hc, hop]

theorem step_mod (lhs rhs v : MoveValue) (rest : List MoveValue)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .mod_)
    (hop : intMod lhs rhs = some v) :
    step env frame cs (rhs :: lhs :: rest) ms =
      .ok { frame with pc := frame.pc + 1 } cs (v :: rest) ms := by
  simp only [step, dif_pos hpc, hc, hop]

/-! ## Bitwise -/

theorem step_bitOr (lhs rhs v : MoveValue) (rest : List MoveValue)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .bitOr)
    (hop : intBitOr lhs rhs = some v) :
    step env frame cs (rhs :: lhs :: rest) ms =
      .ok { frame with pc := frame.pc + 1 } cs (v :: rest) ms := by
  simp only [step, dif_pos hpc, hc, hop]

theorem step_bitAnd (lhs rhs v : MoveValue) (rest : List MoveValue)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .bitAnd)
    (hop : intBitAnd lhs rhs = some v) :
    step env frame cs (rhs :: lhs :: rest) ms =
      .ok { frame with pc := frame.pc + 1 } cs (v :: rest) ms := by
  simp only [step, dif_pos hpc, hc, hop]

theorem step_xor (lhs rhs v : MoveValue) (rest : List MoveValue)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .xor)
    (hop : intXor lhs rhs = some v) :
    step env frame cs (rhs :: lhs :: rest) ms =
      .ok { frame with pc := frame.pc + 1 } cs (v :: rest) ms := by
  simp only [step, dif_pos hpc, hc, hop]

/-! ## Logical -/

theorem step_or (l r : Bool) (rest : List MoveValue)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .or) :
    step env frame cs (.bool r :: .bool l :: rest) ms =
      .ok { frame with pc := frame.pc + 1 } cs (.bool (l || r) :: rest) ms := by
  simp only [step, dif_pos hpc, hc]

theorem step_and (l r : Bool) (rest : List MoveValue)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .and) :
    step env frame cs (.bool r :: .bool l :: rest) ms =
      .ok { frame with pc := frame.pc + 1 } cs (.bool (l && r) :: rest) ms := by
  simp only [step, dif_pos hpc, hc]

theorem step_not (b : Bool) (rest : List MoveValue)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .not) :
    step env frame cs (.bool b :: rest) ms =
      .ok { frame with pc := frame.pc + 1 } cs (.bool (!b) :: rest) ms := by
  simp only [step, dif_pos hpc, hc]

/-! ## Comparison — generic over `intLt`/`intGt`/etc. -/

theorem step_lt (lhs rhs : MoveValue) (b : Bool) (rest : List MoveValue)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .lt)
    (hop : intLt lhs rhs = some b) :
    step env frame cs (rhs :: lhs :: rest) ms =
      .ok { frame with pc := frame.pc + 1 } cs (.bool b :: rest) ms := by
  simp only [step, dif_pos hpc, hc, hop]

theorem step_gt (lhs rhs : MoveValue) (b : Bool) (rest : List MoveValue)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .gt)
    (hop : intGt lhs rhs = some b) :
    step env frame cs (rhs :: lhs :: rest) ms =
      .ok { frame with pc := frame.pc + 1 } cs (.bool b :: rest) ms := by
  simp only [step, dif_pos hpc, hc, hop]

theorem step_le (lhs rhs : MoveValue) (b : Bool) (rest : List MoveValue)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .le)
    (hop : intLe lhs rhs = some b) :
    step env frame cs (rhs :: lhs :: rest) ms =
      .ok { frame with pc := frame.pc + 1 } cs (.bool b :: rest) ms := by
  simp only [step, dif_pos hpc, hc, hop]

theorem step_ge (lhs rhs : MoveValue) (b : Bool) (rest : List MoveValue)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .ge)
    (hop : intGe lhs rhs = some b) :
    step env frame cs (rhs :: lhs :: rest) ms =
      .ok { frame with pc := frame.pc + 1 } cs (.bool b :: rest) ms := by
  simp only [step, dif_pos hpc, hc, hop]

/-! ## Equality — `eq`/`neq`

Move's `Eq`/`Neq` dereference references before comparing (see `IndexedRef::equals` /
`ContainerRef::equals` in `values_impl.rs`). The `_nonRef` variants below cover the common case
where both operands are plain values; for reference-typed operands, apply the deref manually and
reuse these. -/

theorem step_eq_nonRef (lhs rhs : MoveValue) (rest : List MoveValue)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .eq)
    (hLnr : ∀ id, lhs ≠ .immRef id ∧ lhs ≠ .mutRef id)
    (hRnr : ∀ id, rhs ≠ .immRef id ∧ rhs ≠ .mutRef id) :
    step env frame cs (rhs :: lhs :: rest) ms =
      .ok { frame with pc := frame.pc + 1 } cs (.bool (lhs == rhs) :: rest) ms := by
  simp only [step, dif_pos hpc, hc]
  cases lhs <;> cases rhs <;>
    first
    | rfl
    | (first | (exact absurd rfl (hLnr _).1) | (exact absurd rfl (hLnr _).2)
             | (exact absurd rfl (hRnr _).1) | (exact absurd rfl (hRnr _).2))

theorem step_neq_nonRef (lhs rhs : MoveValue) (rest : List MoveValue)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .neq)
    (hLnr : ∀ id, lhs ≠ .immRef id ∧ lhs ≠ .mutRef id)
    (hRnr : ∀ id, rhs ≠ .immRef id ∧ rhs ≠ .mutRef id) :
    step env frame cs (rhs :: lhs :: rest) ms =
      .ok { frame with pc := frame.pc + 1 } cs (.bool (!(lhs == rhs)) :: rest) ms := by
  simp only [step, dif_pos hpc, hc]
  cases lhs <;> cases rhs <;>
    first
    | rfl
    | (first | (exact absurd rfl (hLnr _).1) | (exact absurd rfl (hLnr _).2)
             | (exact absurd rfl (hRnr _).1) | (exact absurd rfl (hRnr _).2))

end MovementFormal.MoveModel.StepLemmas
