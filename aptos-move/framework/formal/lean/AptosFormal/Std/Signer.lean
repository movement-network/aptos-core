import AptosFormal.Move.Value

/-!
# Lean specification for `std::signer`
-/

namespace AptosFormal.Std.Signer

open AptosFormal.Move

def borrowAddress : MoveValue → Option MoveValue
  | .signer a => some (.address a)
  | _         => none

def addressOf : MoveValue → Option MoveValue
  | .signer a => some (.address a)
  | _         => none

theorem addressOf_eq_borrowAddress (v : MoveValue) : addressOf v = borrowAddress v := by
  cases v <;> rfl

theorem borrowAddress_signer (a : UInt128) : borrowAddress (.signer a) = some (.address a) := rfl
theorem addressOf_signer (a : UInt128) : addressOf (.signer a) = some (.address a) := rfl

def borrowAddress_native : List MoveValue → Option (List MoveValue)
  | [.signer a] => some [.address a]
  | _           => none

def addressOf_native : List MoveValue → Option (List MoveValue)
  | [.signer a] => some [.address a]
  | _           => none

theorem borrowAddress_native_correct (a : UInt128) :
    borrowAddress_native [.signer a] = some [.address a] := rfl

end AptosFormal.Std.Signer
