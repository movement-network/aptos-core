import MovementFormal.Std.TypeName

/-!
# Smoke tests for `MovementFormal.Std.TypeName`

**Source:** `MovementFormal.Std.TypeName` → `aptos-move/framework/move-stdlib/sources/type_name.move`.
-/

namespace MovementFormal.SmokeTests.TypeName

open MovementFormal.Std
open MovementFormal.Std.TypeName

/-- Sample name bytes for `"hi"`. -/
def hiBytes : List UInt8 := [0x68, 0x69]

theorem hi_valid : hiBytes.all (fun b => validNameByte b) = true := rfl

example : borrow_string_bytes (⟨hiBytes, hi_valid⟩ : TypeName) = hiBytes := rfl

end MovementFormal.SmokeTests.TypeName
