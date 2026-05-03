import MovementFormal.Std.String

/-!
# Smoke tests for UTF-8 well-formedness predicate (`Std.String`)

**Source:** `MovementFormal.Std.String` → `aptos-move/framework/move-stdlib/sources/string.move`.
-/

namespace MovementFormal.SmokeTests.String

open MovementFormal.Std.String

example : utf8_bytes_well_formed [] = true := by native_decide
example : utf8_bytes_well_formed [0xff] = false := by native_decide
example : try_utf8 [0x48, 0x69] = some [0x48, 0x69] := by native_decide

example : utf8CharBoundaryAt [0x48, 0x69] 1 = true := by native_decide
example : utf8CharBoundaryAt [0xe2, 0x82, 0xac] 1 = false := by native_decide

end MovementFormal.SmokeTests.String
