import Lean.Data.Json
import AptosFormal.Move.Value

/-!
# JSON test vector parser

Parses the JSON test vectors produced by `move-lean-difftest` (the Rust
harness) into Lean structures for comparison with the Move evaluator.
-/

namespace AptosFormal.DiffTest

open AptosFormal.Move
open Lean (Json toJson FromJson)

inductive ExpectedResult where
  | returned (values : List MoveValue)
  | aborted (code : UInt64)

structure TestCase where
  function : String
  args : List MoveValue
  expected : ExpectedResult

structure TestSuite where
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
  return { function, args, expected }

def parseTestSuite (jsonStr : String) : Except String TestSuite := do
  let json ← Json.parse jsonStr
  let generator ← json.getObjValAs? String "generator"
  let module_ ← json.getObjValAs? String "module"
  let casesArr ← json.getObjValAs? (Array Json) "test_cases"
  let cases ← casesArr.toList.mapM parseTestCase
  return { generator, module_, testCases := cases }

end AptosFormal.DiffTest
