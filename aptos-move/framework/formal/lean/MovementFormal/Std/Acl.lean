/-
Copyright (c) Move Industries.

Lean specification for `std::acl` — ordered list of account addresses (as in Move `vector<address>`).

**Source:** `aptos-move/framework/move-stdlib/sources/acl.move`
-/

namespace MovementFormal.Std.Acl

/-- ACL payload: addresses in insertion order (duplicates disallowed by `add`). -/
abbrev MvAcl := List ByteArray

def ECONTAIN : UInt64 := 0
def ENOT_CONTAIN : UInt64 := 1

def empty : MvAcl := []

def contains (a : MvAcl) (x : ByteArray) : Bool := a.any (· == x)

def add (a : MvAcl) (x : ByteArray) : Except UInt64 MvAcl :=
  if contains a x then .error ECONTAIN else .ok (a ++ [x])

partial def removeFirst (xs : MvAcl) (x : ByteArray) : Option MvAcl :=
  match xs with
  | [] => none
  | y :: ys =>
    if y == x then some ys
    else (y :: ·) <$> removeFirst ys x

def remove (a : MvAcl) (x : ByteArray) : Except UInt64 MvAcl :=
  match removeFirst a x with
  | some a' => .ok a'
  | none => .error ENOT_CONTAIN

def assertContains (a : MvAcl) (x : ByteArray) : Except UInt64 Unit :=
  if contains a x then .ok () else .error ENOT_CONTAIN

end MovementFormal.Std.Acl
