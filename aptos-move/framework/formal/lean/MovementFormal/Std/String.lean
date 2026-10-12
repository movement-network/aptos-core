import Init.Data.String

/-!
# Lean specification for `std::string` (UTF-8)

Move exposes UTF-8 validation via **`native`** functions (`internal_check_utf8`, …).
In Lean we use the standard library’s UTF-8 decoder on `ByteArray` as the reference
predicate: a byte sequence is **well-formed UTF-8** iff `String.fromUTF8?` succeeds.

This matches the behavior of Rust’s `str::from_utf8` used by the Move VM for the
same bytes (UTF-8 is uniquely defined at the byte level).

**Source:** `aptos-move/framework/move-stdlib/sources/string.move`; VM natives `aptos-move/framework/move-stdlib/src/natives/string.rs`.
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

/-! ## UTF-8 byte indices (VM `std::string` natives, Rust `str` view)

The Move VM implements `internal_is_char_boundary` using Rust `str::is_char_boundary` on a
`from_utf8_unchecked` view — for byte `i` with `0 < i < len`, a boundary iff the byte is
**not** a UTF-8 continuation byte (`10xxxxxx`, i.e. `(b & 0xC0) = 0x80`).
-/

/-- Matches Rust/Move VM `str::is_char_boundary` / `internal_is_char_boundary` on raw bytes. -/
def utf8CharBoundaryAt (bytes : List UInt8) (i : Nat) : Bool :=
  if i > bytes.length then false
  else if i == 0 || i == bytes.length then true
  else match bytes[i]? with
  | none => false
  | some b => (b.toNat &&& 0xC0) != 0x80

/-- Byte slice `bytes[i:j]` when `i ≤ j` (VM `internal_sub_string` on `&str` for valid UTF-8). -/
def internalSubStringBytes (bytes : List UInt8) (i j : Nat) : List UInt8 :=
  (bytes.drop i).take (j - i)

/-- First byte index of `needle` in `hay`, or `hay.length` if not found (`str::find` semantics). -/
def byteIndexOf (hay needle : List UInt8) : Nat :=
  if needle.isEmpty then 0
  else
    (List.range (hay.length + 1)).find? (fun pos =>
      decide (pos + needle.length ≤ hay.length) &&
        ((hay.drop pos).take needle.length == needle))
    |>.getD hay.length

theorem utf8_bytes_well_formed_empty : utf8_bytes_well_formed ([] : List UInt8) = true := by
  native_decide

end MovementFormal.Std.String
