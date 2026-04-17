import Init.Data.String

/-!
# Lean specification for `std::string` (UTF-8)

Move exposes UTF-8 validation via **`native`** functions (`internal_check_utf8`, …).
In Lean we use the standard library’s UTF-8 decoder on `ByteArray` as the reference
predicate: a byte sequence is **well-formed UTF-8** iff `String.fromUTF8?` succeeds.

This matches the behavior of Rust’s `str::from_utf8` used by the Move VM for the
same bytes (UTF-8 is uniquely defined at the byte level).
-/

namespace MovementFormal.Std.String

/-- Predicate aligned with Move `string::utf8` / `try_utf8` success: valid UTF-8 bytes. -/
def utf8_bytes_well_formed (bytes : List UInt8) : Bool :=
  match String.fromUTF8? (ByteArray.mk bytes.toArray) with
  | some _ => true
  | none => false

/-- `std::string::try_utf8` / `utf8` success without modeling abort — `Option` carrier. -/
def try_utf8 (bytes : List UInt8) : Option (List UInt8) :=
  if utf8_bytes_well_formed bytes then some bytes else none

/-- Length in bytes (for spec reasoning; matches `vector::length` of inner `bytes`). -/
def byte_length (bytes : List UInt8) : Nat := bytes.length

end MovementFormal.Std.String
