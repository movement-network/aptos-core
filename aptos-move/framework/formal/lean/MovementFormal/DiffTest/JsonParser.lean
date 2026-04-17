import Lean.Data.Json
import MovementFormal.MoveModel.Value

/-!
# JSON test vector parser

**Source:** `aptos-move/framework/formal/difftest/` — JSON schema `schema::TestSuite` / `TestCase` emitted by Rust crate `move-lean-difftest`.

Parses the JSON test vectors produced by `move-lean-difftest` (the Rust
harness) into Lean structures for comparison with the Move evaluator.
-/

namespace MovementFormal.DiffTest

open MovementFormal.MoveModel
open Lean (Json toJson FromJson)

inductive ExpectedResult where
  | returned (values : List MoveValue)
  | aborted (code : UInt64)

structure TestCase where
  function : String
  args : List MoveValue
  expected : ExpectedResult
  /-- When true, Lean skips evaluation (`skip_lean` in JSON). -/
  skipLean : Bool := false

structure TestSuite where
  schemaVersion : Option Nat
  generator : String
  module_ : String
  testCases : List TestCase

/-! ## JSON → MoveValue conversion -/

private def tyStrToMoveType : String → MoveType
  | "bool" => .bool
  | "u8" => .u8
  | "u16" => .u16
  | "u32" => .u32
  | "u64" => .u64
  | "u128" => .u128
  | "u256" => .u256
  | "address" => .address
  | _ => .u8

private def isHexChar (c : Char) : Bool :=
  c.isDigit || ('a' ≤ c && c ≤ 'f') || ('A' ≤ c && c ≤ 'F')

private def hexNibble (c : Char) : Option Nat :=
  if c.isDigit then some (c.toNat - '0'.toNat)
  else if 'a' ≤ c ∧ c ≤ 'f' then some (10 + (c.toNat - 'a'.toNat))
  else if 'A' ≤ c ∧ c ≤ 'F' then some (10 + (c.toNat - 'A'.toNat))
  else none

private def hexByte? (a b : Char) : Option UInt8 :=
  match hexNibble a, hexNibble b with
  | some hi, some lo => some (UInt8.ofNat (16 * hi + lo))
  | _, _ => none

private partial def hexCharsToBytes (cs : List Char) : Except String (List UInt8) :=
  match cs with
  | [] => pure []
  | a :: b :: rest => do
      let u ← match hexByte? a b with
        | some u => pure u
        | none => throw "invalid hex pair in address"
      let t ← hexCharsToBytes rest
      pure (u :: t)
  | [_] => throw "odd-length hex in address"

/-- Movement-style 32-byte account address from `0x…` / `@0x…` hex (left-padded to 64 hex digits). -/
private def parseMovementAddressHex (s : String) : Except String ByteArray := do
  let s' := if s.startsWith "@" then s.drop 1 else s
  let hex := if s'.startsWith "0x" then s'.drop 2 else s'
  if hex.any (fun c => !isHexChar c) then throw s!"non-hex in address: {s}"
  if hex.length > 64 then throw s!"address hex too long: {hex.length} nibbles"
  let pad := 64 - hex.length
  let padded := String.mk (List.replicate pad '0') ++ hex
  let bytes ← hexCharsToBytes padded.toList
  pure (ByteArray.mk bytes.toArray)

partial def parseTypedValue (obj : Json) : Except String MoveValue := do
  let ty ← obj.getObjValAs? String "type"
  let val := (obj.getObjVal? "value").toOption.getD Json.null
  match ty with
  | "bool" =>
    let b ← val.getBool?
    return .bool b
  | "u8" =>
    let n ← val.getNat?
    return .u8 n.toUInt8
  | "u16" =>
    let n ← val.getNat?
    return .u16 n.toUInt16
  | "u32" =>
    let n ← val.getNat?
    return .u32 n.toUInt32
  | "u64" =>
    let n ← val.getNat?
    return .u64 n.toUInt64
  | "u128" =>
    match val with
    | Json.str s =>
      match s.toNat? with
      | some n =>
        if h : n < 2 ^ 128 then return .u128 ⟨n, h⟩
        else throw s!"u128 overflow: {n}"
      | none => throw s!"invalid u128 string: {s}"
    | _ =>
      let n ← val.getNat?
      if h : n < 2 ^ 128 then return .u128 ⟨n, h⟩
      else throw s!"u128 overflow: {n}"
  | "u256" =>
    match val with
    | Json.str s =>
      match s.toNat? with
      | some n =>
        if h : n < 2 ^ 256 then return .u256 ⟨n, h⟩
        else throw s!"u256 overflow: {n}"
      | none => throw s!"invalid u256 string: {s}"
    | _ =>
      let n ← val.getNat?
      if h : n < 2 ^ 256 then return .u256 ⟨n, h⟩
      else throw s!"u256 overflow: {n}"
  | "address" =>
    let s ← val.getStr?
    match parseMovementAddressHex s with
    | Except.ok bs => return .address bs
    | Except.error e => throw e
  | "signer" =>
    let s ← val.getStr?
    match parseMovementAddressHex s with
    | Except.ok bs => return .signer bs
    | Except.error e => throw e
  | "option_u64" =>
    match val with
    | Json.null => return .struct_ [.vector .u64 []]
    | _ =>
      let n ← val.getNat?
      return .struct_ [.vector .u64 [.u64 n.toUInt64]]
  | "bit_vector" =>
    let len ← val.getObjValAs? Nat "length"
    let bitsArr ← val.getObjValAs? (Array Json) "bits"
    let bs ← bitsArr.toList.mapM (·.getBool?)
    return .struct_ [.u64 len.toUInt64, .vector .bool (bs.map MoveValue.bool)]
  | "acl" =>
    let arr ← val.getArr?
    let xs ← arr.toList.mapM fun j => do
      let s ← j.getStr?
      match parseMovementAddressHex s with
      | Except.ok bs => return bs
      | Except.error e => throw e
    return .struct_ [.vector .address (xs.map MoveValue.address)]
  | _ =>
    if ty.startsWith "vector<" && ty.endsWith ">" then
      let innerTy := (ty.drop 7).dropRight 1
      let arr ← val.getArr?
      let elems ← arr.toList.mapM fun elem =>
        parseTypedValue (Json.mkObj [("type", Json.str innerTy), ("value", elem)])
      let moveType := tyStrToMoveType innerTy
      return .vector moveType elems
    else
      throw s!"unsupported type: {ty}"

private def parseResult (obj : Json) : Except String ExpectedResult := do
  let status ← obj.getObjValAs? String "status"
  match status with
  | "returned" =>
    let valsArr ← obj.getObjValAs? (Array Json) "values"
    let vals ← valsArr.toList.mapM parseTypedValue
    return .returned vals
  | "aborted" =>
    let code ← obj.getObjValAs? Nat "abort_code"
    return .aborted code.toUInt64
  | other => throw s!"unknown status: {other}"

private def parseTestCase (obj : Json) : Except String TestCase := do
  let function ← obj.getObjValAs? String "function"
  let argsArr ← obj.getObjValAs? (Array Json) "args"
  let args ← argsArr.toList.mapM parseTypedValue
  let resultObj ← obj.getObjVal? "result"
  let expected ← parseResult resultObj
  let skipLean :=
    match (obj.getObjVal? "skip_lean").toOption with
    | none => false
    | some j =>
      match j.getBool? with
      | Except.ok b => b
      | Except.error _ => false
  return { function, args, expected, skipLean }

def parseTestSuite (jsonStr : String) : Except String TestSuite := do
  let json ← Json.parse jsonStr
  let schemaVersion ← match (json.getObjVal? "schema_version").toOption with
    | Option.none => pure (Option.none : Option Nat)
    | Option.some j =>
      match j.getNat? with
      | Except.ok n => pure (Option.some n)
      | Except.error _ => pure (Option.none : Option Nat)
  let generator ← json.getObjValAs? String "generator"
  let module_ ← json.getObjValAs? String "module"
  let casesArr ← json.getObjValAs? (Array Json) "test_cases"
  let cases ← casesArr.toList.mapM parseTestCase
  return { schemaVersion, generator, module_, testCases := cases : TestSuite }

end MovementFormal.DiffTest
