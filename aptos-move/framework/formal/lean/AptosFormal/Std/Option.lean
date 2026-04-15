import AptosFormal.Move.Value
import AptosFormal.Std.Vector.Operations

/-!
# Lean specification for `std::option`

`Option<Element>` is represented in Move as a `vector<Element>` of length
≤ 1.  This spec mirrors that representation exactly.
-/

namespace AptosFormal.Std.Option

open AptosFormal.Move

def EOPTION_IS_SET  : UInt64 := 0x40000
def EOPTION_NOT_SET : UInt64 := 0x40001

structure MoveOption (α : Type) where
  vec : List α
  inv : vec.length ≤ 1

def none' : MoveOption MoveValue := ⟨[], by decide⟩
def some' (v : MoveValue) : MoveOption MoveValue := ⟨[v], by decide⟩

def isNone (opt : MoveOption MoveValue) : Bool := opt.vec.isEmpty
def isSome (opt : MoveOption MoveValue) : Bool := !opt.vec.isEmpty

theorem isNone_none : isNone none' = true := rfl
theorem isSome_none : isSome none' = false := rfl
theorem isNone_some (v : MoveValue) : isNone (some' v) = false := rfl
theorem isSome_some (v : MoveValue) : isSome (some' v) = true := rfl
theorem isSome_iff_not_isNone (opt : MoveOption MoveValue) : isSome opt = !isNone opt := by
  simp [isSome, isNone]

def contains' (opt : MoveOption MoveValue) (e : MoveValue) : Bool :=
  isSome opt && opt.vec.head? == some e

theorem contains_none (e : MoveValue) : contains' none' e = false := rfl
theorem contains_some (v e : MoveValue) : contains' (some' v) e = (v == e) := by
  simp [contains', some', isSome]

def borrow' (opt : MoveOption MoveValue) : Option MoveValue := opt.vec.head?
theorem borrow_none : borrow' none' = none := rfl
theorem borrow_some (v : MoveValue) : borrow' (some' v) = some v := rfl

def borrowWithDefault (opt : MoveOption MoveValue) (default : MoveValue) : MoveValue :=
  opt.vec.head?.getD default
theorem borrowWithDefault_none (d : MoveValue) : borrowWithDefault none' d = d := rfl
theorem borrowWithDefault_some (v d : MoveValue) : borrowWithDefault (some' v) d = v := rfl

def fill' (opt : MoveOption MoveValue) (e : MoveValue) : Except UInt64 (MoveOption MoveValue) :=
  if isNone opt then .ok (some' e) else .error EOPTION_IS_SET
theorem fill_none (e : MoveValue) : fill' none' e = .ok (some' e) := rfl
theorem fill_some (v e : MoveValue) : fill' (some' v) e = .error EOPTION_IS_SET := rfl

def extract' (opt : MoveOption MoveValue) : Except UInt64 (MoveValue × MoveOption MoveValue) :=
  match opt.vec with
  | [v] => .ok (v, none')
  | _   => .error EOPTION_NOT_SET
theorem extract_none : extract' none' = .error EOPTION_NOT_SET := rfl
theorem extract_some (v : MoveValue) : extract' (some' v) = .ok (v, none') := rfl

def swap' (opt : MoveOption MoveValue) (e : MoveValue) : Except UInt64 (MoveValue × MoveOption MoveValue) :=
  match opt.vec with
  | [v] => .ok (v, some' e)
  | _   => .error EOPTION_NOT_SET
theorem swap_none (e : MoveValue) : swap' none' e = .error EOPTION_NOT_SET := rfl
theorem swap_some (v e : MoveValue) : swap' (some' v) e = .ok (v, some' e) := rfl

def swapOrFill (opt : MoveOption MoveValue) (e : MoveValue) : MoveOption MoveValue × MoveOption MoveValue :=
  (opt, some' e)
theorem swapOrFill_none (e : MoveValue) : swapOrFill none' e = (none', some' e) := rfl
theorem swapOrFill_some (v e : MoveValue) : swapOrFill (some' v) e = (some' v, some' e) := rfl

def destroySome (opt : MoveOption MoveValue) : Except UInt64 MoveValue :=
  match opt.vec with | [v] => .ok v | _ => .error EOPTION_NOT_SET
def destroyNone (opt : MoveOption MoveValue) : Except UInt64 Unit :=
  match opt.vec with | [] => .ok () | _ => .error EOPTION_IS_SET
def toVec (opt : MoveOption MoveValue) : List MoveValue := opt.vec
theorem toVec_none : toVec none' = [] := rfl
theorem toVec_some (v : MoveValue) : toVec (some' v) = [v] := rfl

def fromVec (xs : List MoveValue) : Except UInt64 (MoveOption MoveValue) :=
  if h : xs.length ≤ 1 then .ok ⟨xs, h⟩ else .error 0x40002
theorem fromVec_empty : fromVec [] = .ok none' := rfl
theorem fromVec_singleton (v : MoveValue) : fromVec [v] = .ok (some' v) := rfl

theorem fill_extract_roundtrip (v : MoveValue) :
    (fill' none' v >>= extract') = .ok (v, none') := rfl

end AptosFormal.Std.Option
