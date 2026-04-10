import AptosFormal.DiffTest.JsonParser
import AptosFormal.Move.Step
import AptosFormal.Move.Programs

/-!
# Differential test runner

Reads JSON test vectors produced by the Rust `move-lean-difftest` harness,
runs each test case through the Lean Move evaluator, and compares results.

Full workflow: `./aptos-move/framework/formal/difftest.sh` from the repo root, or see
`aptos-move/framework/formal/difftest/README.md`. The default VM oracle is `difftest/difftest_oracle.json`.

Usage: `lake exe difftest <path-to-oracle.json>`

This is a runtime comparison (not a proof). It reports pass/fail for each
test case, providing empirical evidence of model fidelity between our Lean
evaluator and the real Move VM.
-/

namespace AptosFormal.DiffTest

open AptosFormal.Move
open AptosFormal.Move.Programs

/-! ## Function name → evaluator call mapping

Maps function names from the JSON test vectors to evaluator calls
against `realModuleEnv`. Uses real compiler-output bytecode where available
and native functions for simpler cases.

Index assignments in `realModuleEnv`:
- 0–3: `bcs::to_bytes` natives (u8, u64, u128, bool) — also in `stdModuleEnv`
- 4–5: `vector::length`, `vector::is_empty` (natives)
- 20: `hash::sha3_256` (native) — `stdModuleEnv`
- 25–27: `testRealContains` / `testRealIndexOf` / `testRealReverse` (wrappers) -/

structure FuncMapping where
  funcIdx : FuncIndex
  useRealEnv : Bool := true

def funcNameToMapping (name : String) : Option FuncMapping :=
  let base := match name.splitOn " [" with
    | [x] => x
    | x :: _ => x
    | [] => name
  match base with
  | "test_contains"    => some { funcIdx := 25 }
  | "test_index_of"    => some { funcIdx := 26 }
  | "test_reverse"     => some { funcIdx := 27 }
  | "test_is_empty"    => some { funcIdx := 5, useRealEnv := false }
  | "test_length"      => some { funcIdx := 4, useRealEnv := false }
  | "test_bcs_u8"      => some { funcIdx := 0, useRealEnv := false }
  | "test_bcs_u64"     => some { funcIdx := 1, useRealEnv := false }
  | "test_bcs_u128"    => some { funcIdx := 2, useRealEnv := false }
  | "test_bcs_bool"    => some { funcIdx := 3, useRealEnv := false }
  | "test_sha3_256"    => some { funcIdx := 20, useRealEnv := false }
  | _                  => none

def defaultFuel : Nat := 10000

/-! ## Result extraction and comparison -/

def extractReturnValues : ExecResult → Option (List MoveValue)
  | .returned vs _ => some vs
  | _ => none

def moveValueToString : MoveValue → String
  | .bool b => s!"bool({b})"
  | .u8 n => s!"u8({n})"
  | .u16 n => s!"u16({n})"
  | .u32 n => s!"u32({n})"
  | .u64 n => s!"u64({n})"
  | .u128 n => s!"u128({n.val})"
  | .u256 n => s!"u256({n.val})"
  | .address _ => "address(...)"
  | .signer _ => "signer(...)"
  | .vector _ elems => s!"vector[{", ".intercalate (elems.map moveValueToString)}]"
  | .struct_ fields => s!"struct\{{", ".intercalate (fields.map moveValueToString)}}"
  | .mutRef id => s!"mutRef({id})"
  | .immRef id => s!"immRef({id})"

def moveValuesToString (vs : List MoveValue) : String :=
  s!"[{", ".intercalate (vs.map moveValueToString)}]"

def execResultToString : ExecResult → String
  | .returned vs _ => s!"returned {moveValuesToString vs}"
  | .aborted code => s!"aborted({code})"
  | .error => "error"
  | .ok _ _ _ _ => "incomplete (needs more fuel?)"

/-! ## Run a single test case -/

inductive TestOutcome where
  | pass
  | fail (reason : String)
  | skipped (reason : String)

/-! The Lean evaluator returns values in stack order (head = top of stack),
while the real VM serializes them in source-declaration order. For
multi-return functions the two orderings are reversed. We reverse the
Lean result to match the VM's convention before comparing. -/
def runTestCase (tc : TestCase) : TestOutcome :=
  match funcNameToMapping tc.function with
  | none => .skipped s!"no Lean mapping for '{tc.function}'"
  | some mapping =>
    let env := if mapping.useRealEnv then realModuleEnv else stdModuleEnv
    let result := eval env mapping.funcIdx tc.args defaultFuel
    match tc.expected, result with
    | .returned expectedVals, .returned actualVals _ =>
      let actualOrdered := actualVals.reverse
      if expectedVals == actualOrdered then .pass
      else .fail s!"expected {moveValuesToString expectedVals}, got {moveValuesToString actualOrdered}"
    | .aborted expectedCode, .aborted actualCode =>
      if expectedCode == actualCode then .pass
      else .fail s!"expected abort({expectedCode}), got abort({actualCode})"
    | .returned _, other =>
      .fail s!"expected return, got {execResultToString other}"
    | .aborted _, other =>
      .fail s!"expected abort, got {execResultToString other}"

end AptosFormal.DiffTest

/-! ## Main -/

open AptosFormal.DiffTest in
def main (args : List String) : IO UInt32 := do
  let path ← match args with
    | [p] => pure p
    | _ =>
      IO.eprintln "Usage: lake exe difftest <path-to-oracle.json>"
      return 1

  let contents ← IO.FS.readFile path
  let suite ← match parseTestSuite contents with
    | .ok s => pure s
    | .error e =>
      IO.eprintln s!"JSON parse error: {e}"
      return 1

  IO.println s!"DiffTest runner: {suite.generator} / {suite.module_}"
  IO.println s!"Test cases: {suite.testCases.length}"
  IO.println ""

  let mut passed := 0
  let mut failed := 0
  let mut skipped := 0

  for tc in suite.testCases do
    let outcome := runTestCase tc
    match outcome with
    | .pass =>
      IO.println s!"  PASS  {tc.function}"
      passed := passed + 1
    | .fail reason =>
      IO.println s!"  FAIL  {tc.function}"
      IO.println s!"        {reason}"
      failed := failed + 1
    | .skipped reason =>
      IO.println s!"  SKIP  {tc.function}"
      IO.println s!"        {reason}"
      skipped := skipped + 1

  IO.println ""
  IO.println s!"Results: {passed} passed, {failed} failed, {skipped} skipped"

  return if failed > 0 then 1 else 0
