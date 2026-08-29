/-!
# Lean specification for `std::type_name`

`type_name::TypeName` carries a logical name as raw bytes with each code unit in `0..=127`
(the range used for on-chain type-name strings in this stack). `get<T>()` is **native** —
we only model the record shape and accessors `borrow_string` / `into_string`.

**Source:** `aptos-move/framework/move-stdlib/sources/type_name.move`.
-/

namespace MovementFormal.Std.TypeName

/-- Each name byte is a single-byte code unit in `0..=127` (per `move-stdlib` `type_name`). -/
def validNameByte (b : UInt8) : Bool :=
  decide (b.toNat ≤ 127)

structure TypeName where
  nameBytes : List UInt8
  inv : nameBytes.all (fun b => validNameByte b) = true

def borrow_string_bytes (t : TypeName) : List UInt8 := t.nameBytes

def into_string_bytes (t : TypeName) : List UInt8 := t.nameBytes

theorem borrow_eq_into (t : TypeName) : borrow_string_bytes t = into_string_bytes t := rfl

end MovementFormal.Std.TypeName
