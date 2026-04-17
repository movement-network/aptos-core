import MovementFormal.Std.String

/-!
# Smoke tests for UTF-8 well-formedness predicate (`Std.String`)
-/

namespace MovementFormal.SmokeTests.String

open MovementFormal.Std.String

example : utf8_bytes_well_formed [] = true := by native_decide
example : utf8_bytes_well_formed [0xff] = false := by native_decide
example : try_utf8 [0x48, 0x69] = some [0x48, 0x69] := by native_decide

end MovementFormal.SmokeTests.String
