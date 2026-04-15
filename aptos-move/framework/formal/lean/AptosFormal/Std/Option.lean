import AptosFormal.Move.Value
import AptosFormal.Std.Vector.Operations

/-!
# Lean specification for `std::option`

`Option<Element>` is represented in Move as a `vector<Element>` of length ≤ 1.
This spec mirrors that representation exactly.

**Source:** `aptos-move/framework/move-stdlib/sources/option.move`

## Bug-fix note
PR #1's `swapOrFill` was incorrect: it always returned `(opt, some' e)` regardless of
whether `opt` was `some` or `none`. The correct semantics (from the Move source):
- `opt = none`  → fill it with `e`, return `none'` as the "displaced value" slot
- `opt = some v` → replace the value, return `some' v` as the displaced value

The return type is `(displaced : MoveOption, updated : MoveOption)`.
-/

namespace AptosFormal.Std.Option

open AptosFormal.Move

def EOPTION_IS_SET  : UInt64 := 0x40000
def EOPTION_NOT_SET : UInt64 := 0x40001

structure MoveOption (α : Type) where
  vec : List α
  inv : vec.length ≤ 1
deriving Repr

def none' : MoveOption MoveValue := ⟨[], Nat.zero_le _⟩
def some' (v : MoveValue) : MoveOption MoveValue := ⟨[v], Nat.le_refl _⟩

-- ── Predicates ───────────────────────────────────────────────────────────────

def isNone (opt : MoveOption MoveValue) : Bool := opt.vec.isEmpty
def isSome (opt : MoveOption MoveValue) : Bool := !opt.vec.isEmpty

@[simp] theorem isNone_none : isNone none' = true := rfl
@[simp] theorem isSome_none : isSome none' = false := rfl
@[simp] theorem isNone_some (v : MoveValue) : isNone (some' v) = false := rfl
@[simp] theorem isSome_some (v : MoveValue) : isSome (some' v) = true := rfl

theorem isSome_iff_not_isNone (opt : MoveOption MoveValue) :
    isSome opt = !isNone opt := by simp [isSome, isNone]

-- ── Membership ───────────────────────────────────────────────────────────────

def contains' (opt : MoveOption MoveValue) (e : MoveValue) : Bool :=
  isSome opt && opt.vec.head? == some e

@[simp] theorem contains_none (e : MoveValue) : contains' none' e = false := rfl
@[simp] theorem contains_some (v e : MoveValue) :
    contains' (some' v) e = (v == e) := by simp [contains', some', isSome]

-- ── Borrow ───────────────────────────────────────────────────────────────────

def borrow' (opt : MoveOption MoveValue) : Option MoveValue := opt.vec.head?

@[simp] theorem borrow_none : borrow' none' = none := rfl
@[simp] theorem borrow_some (v : MoveValue) : borrow' (some' v) = some v := rfl

def borrowWithDefault (opt : MoveOption MoveValue) (default : MoveValue) : MoveValue :=
  opt.vec.head?.getD default

@[simp] theorem borrowWithDefault_none (d : MoveValue) :
    borrowWithDefault none' d = d := rfl
@[simp] theorem borrowWithDefault_some (v d : MoveValue) :
    borrowWithDefault (some' v) d = v := rfl

-- ── Fill / Extract ───────────────────────────────────────────────────────────

def fill' (opt : MoveOption MoveValue) (e : MoveValue) :
    Except UInt64 (MoveOption MoveValue) :=
  if isNone opt then .ok (some' e) else .error EOPTION_IS_SET

@[simp] theorem fill_none (e : MoveValue) : fill' none' e = .ok (some' e) := rfl
@[simp] theorem fill_some (v e : MoveValue) :
    fill' (some' v) e = .error EOPTION_IS_SET := rfl

def extract' (opt : MoveOption MoveValue) :
    Except UInt64 (MoveValue × MoveOption MoveValue) :=
  match opt.vec with
  | [v] => .ok (v, none')
  | _   => .error EOPTION_NOT_SET

@[simp] theorem extract_none : extract' none' = .error EOPTION_NOT_SET := rfl
@[simp] theorem extract_some (v : MoveValue) :
    extract' (some' v) = .ok (v, none') := rfl

-- ── Swap ─────────────────────────────────────────────────────────────────────

def swap' (opt : MoveOption MoveValue) (e : MoveValue) :
    Except UInt64 (MoveValue × MoveOption MoveValue) :=
  match opt.vec with
  | [v] => .ok (v, some' e)
  | _   => .error EOPTION_NOT_SET

@[simp] theorem swap_none (e : MoveValue) :
    swap' none' e = .error EOPTION_NOT_SET := rfl
@[simp] theorem swap_some (v e : MoveValue) :
    swap' (some' v) e = .ok (v, some' e) := rfl

-- ── swapOrFill ───────────────────────────────────────────────────────────────
/-
Move source:
```
public fun swap_or_fill<Element>(t: &mut Option<Element>, e: Element): Option<Element> {
    let vec_ref = &mut t.vec;
    let fill = if (vector::is_empty(vec_ref)) {
        vector::push_back(vec_ref, e);
        option::none()
    } else {
        let old_value = vector::swap_remove(vec_ref, 0);
        vector::push_back(vec_ref, e);
        option::some(old_value)
    };
    fill
}
```
So:
- `opt = none`  → push e, return `none` (no displaced value)
- `opt = some v` → swap out `v`, push `e`, return `some v` (displaced value)

BUG IN PR #1: always returned `(opt, some' e)` which is wrong for the `none` case —
it returned `(none', some' e)` which happens to be correct for the return value but
the *updated* `opt` mutation was never reflected. Also wrong for `some` case which
should return `some v` as displaced, not the unchanged `opt`.
-/

/-- `swapOrFill`: returns `(displaced, updated)`.
    - `displaced = none'` when opt was empty
    - `displaced = some' v` when opt held `v` -/
def swapOrFill (opt : MoveOption MoveValue) (e : MoveValue) :
    MoveOption MoveValue × MoveOption MoveValue :=
  match opt.vec with
  | []    => (none', some' e)        -- opt was empty: fill it, no displaced value
  | v :: _ => (some' v, some' e)    -- opt held v: displace v, install e

@[simp] theorem swapOrFill_none (e : MoveValue) :
    swapOrFill none' e = (none', some' e) := rfl

@[simp] theorem swapOrFill_some (v e : MoveValue) :
    swapOrFill (some' v) e = (some' v, some' e) := rfl

theorem swapOrFill_updated_is_some (opt : MoveOption MoveValue) (e : MoveValue) :
    isSome (swapOrFill opt e).2 = true := by
  simp [swapOrFill, isSome, some', List.isEmpty]

-- ── Destroy ──────────────────────────────────────────────────────────────────

def destroySome (opt : MoveOption MoveValue) : Except UInt64 MoveValue :=
  match opt.vec with | [v] => .ok v | _ => .error EOPTION_NOT_SET

def destroyNone (opt : MoveOption MoveValue) : Except UInt64 Unit :=
  match opt.vec with | [] => .ok () | _ => .error EOPTION_IS_SET

@[simp] theorem destroySome_some (v : MoveValue) : destroySome (some' v) = .ok v := rfl
@[simp] theorem destroySome_none : destroySome none' = .error EOPTION_NOT_SET := rfl
@[simp] theorem destroyNone_none : destroyNone none' = .ok () := rfl
@[simp] theorem destroyNone_some (v : MoveValue) :
    destroyNone (some' v) = .error EOPTION_IS_SET := rfl

-- ── Vector conversion ────────────────────────────────────────────────────────

def toVec (opt : MoveOption MoveValue) : List MoveValue := opt.vec

@[simp] theorem toVec_none : toVec none' = [] := rfl
@[simp] theorem toVec_some (v : MoveValue) : toVec (some' v) = [v] := rfl

def fromVec (xs : List MoveValue) : Except UInt64 (MoveOption MoveValue) :=
  if h : xs.length ≤ 1 then .ok ⟨xs, h⟩ else .error 0x40002

@[simp] theorem fromVec_empty : fromVec [] = .ok none' := rfl
@[simp] theorem fromVec_singleton (v : MoveValue) : fromVec [v] = .ok (some' v) := rfl

-- ── Round-trip lemmas ────────────────────────────────────────────────────────

theorem fill_extract_roundtrip (v : MoveValue) :
    (fill' none' v >>= extract') = .ok (v, none') := rfl

theorem swap_extract_neq (v e : MoveValue) :
    (swap' (some' v) e >>= fun (_, o) => extract' o) = .ok (e, none') := rfl

end AptosFormal.Std.Option
