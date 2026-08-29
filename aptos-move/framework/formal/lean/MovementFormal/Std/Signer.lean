import MovementFormal.MoveModel.Value

/-!
# Lean specification for `std::signer`

**Source:** `aptos-move/framework/move-stdlib/sources/signer.move`

`signer` is a built-in Move type representing a verified account address.
In our model, `MoveValue.signer addrBytes` carries the raw address bytes.

The module has exactly two public functions:
- `borrow_address(s: &signer): &address` — native
- `address_of(s: &signer): address` — calls `*borrow_address(s)`
-/

namespace MovementFormal.Std.Signer

open MovementFormal.MoveModel

/-- `borrow_address`: returns the address stored in a signer value. -/
def borrowAddress : MoveValue → Option MoveValue
  | .signer a => some (.address a)
  | _         => none

/-- `address_of`: dereferences `borrow_address` — identical result at value level. -/
def addressOf : MoveValue → Option MoveValue
  | .signer a => some (.address a)
  | _         => none

-- addressOf delegates to borrowAddress
theorem addressOf_eq_borrowAddress (v : MoveValue) : addressOf v = borrowAddress v := by
  cases v <;> rfl

theorem borrowAddress_signer (a : ByteArray) : borrowAddress (.signer a) = some (.address a) := rfl
theorem addressOf_signer (a : ByteArray) : addressOf (.signer a) = some (.address a) := rfl

theorem borrowAddress_non_signer (v : MoveValue) (h : ∀ a, v ≠ .signer a) :
    borrowAddress v = none := by
  cases v <;> simp [borrowAddress] <;> exact h _ rfl

-- Native function signatures for difftest
def borrowAddress_native : List MoveValue → Option (List MoveValue)
  | [.signer a] => some [.address a]
  | _           => none

def addressOf_native : List MoveValue → Option (List MoveValue)
  | [.signer a] => some [.address a]
  | _           => none

theorem borrowAddress_native_correct (a : ByteArray) :
    borrowAddress_native [.signer a] = some [.address a] := rfl

theorem addressOf_native_correct (a : ByteArray) :
    addressOf_native [.signer a] = some [.address a] := rfl

end MovementFormal.Std.Signer
