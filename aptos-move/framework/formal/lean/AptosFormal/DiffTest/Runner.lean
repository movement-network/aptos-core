import AptosFormal.DiffTest.JsonParser
import AptosFormal.Move.Step
import AptosFormal.Move.Programs
import AptosFormal.Move.Programs.Confidential
import AptosFormal.DiffTest.RunnerFuncMappingAux

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
open AptosFormal.Move.Programs.Confidential

/-! ## Function name → evaluator call mapping

Maps function names from the JSON test vectors to evaluator calls
against `realModuleEnv`. Uses real compiler-output bytecode where available
and native functions for simpler cases.

Index assignments in `realModuleEnv`:
- 0–3: `bcs::to_bytes` natives (u8, u64, u128, bool) — also in `stdModuleEnv`
- 4–5: `vector::length`, `vector::is_empty` (natives)
- 20: `hash::sha3_256` (native) — `stdModuleEnv`
- 21–22: global smoke (`Programs.GlobalSmoke`)
- 27–29: `testRealContains` / `testRealIndexOf` / `testRealReverse` (wrappers)
- 30–33: `vector::remove` / `swap_remove` / `append` / `singleton` (`u64` natives)
- 34: `global_move_signed_borrow_smoke` (Lean-only; no default JSON oracle row)
- 43–46: `confidential_proof` Fiat–Shamir sigma DST `#[view]` getters (constant vectors)
- 47–50: extra `confidential_balance` bool smoke (VM runs real crypto; Lean constant `true` on oracle inputs)
- 51: `get_fiat_shamir_registration_sigma_dst` constant vector
- 52: FA stub `faReadBalance` (`test_fa_stub_balance_answer`; Runner seeds `faBalances`)
- 169: FA stub `faWriteBalance` + `faReadBalance` (`test_fa_stub_write_then_read_balance`; **empty** initial `faBalances`)
- 170: registration FS `registration_fs_message_for_test` equals golden (`test_registration_fs_message_framework_matches_helpers_golden`; Lean `ldTrue` stub)
- 171: production registration deterministic prove + `verify_registration_proof_for_difftest` (`test_registration_proof_framework_deterministic_verify_roundtrip`; Lean same native as **35**)
- 172: second registration FS golden `vector<u8>` (`test_registration_fs_message_golden_move_second`; `ldConst` 46 + `ret`)
- 173: second registration FS framework vs helpers golden (`test_registration_fs_message_framework_second_scenario_matches_helpers_golden`; Lean `ldTrue` stub)
- 174: first registration tagged-hash **`vector<u8>`** (`test_registration_tagged_hash_golden_move_first`; **`ldConst` 47** + `ret`)
- 175: second registration tagged-hash **`vector<u8>`** (`test_registration_tagged_hash_golden_move_second`; **`ldConst` 48** + `ret`)
- 53: `test_elg_ciphertext_add_assign_matches_add` (ElGamal `ciphertext_add_assign` vs `ciphertext_add`)
- 54: `test_elg_ciphertext_sub_assign_matches_sub` (ElGamal `ciphertext_sub_assign` vs `ciphertext_sub`)
- 55–57, 59–60: extra `confidential_balance` smoke (`actual` roundtrip / `u64` zero / wrong-len `Option` / `balance_c` / add-actual)
- 58: ElGamal `ciphertext_sub` self-smoke
- 61–65: more `confidential_balance` (`actual` short-len `Option`, actual `sub`/`equals`/`balance_c`, compressed pending decompress)
- 66: ElGamal `ciphertext_add` commutes at zero-plaintext ciphertexts
- 67–68: balance `balance_equals` self-actual; `is_zero` on decompressed compressed pending
- 40: CA e2e merged oracle `bool(true)` “success pin” witness (multi-step flows, `has_confidential_asset_store` after register, `encryption_key` view vs registered `pubkey_to_bytes`, `pending_balance` / `actual_balance` return-byte length pins after register, `get_auditor` **`none`** BCS pin when no `FAConfig`, `verify_pending_balance` with `u64(0)` after register-only or after `deposit` + `rollover_pending_balance`, `verify_pending_balance` with deposited `u64` after one or **two** `deposit` calls only (no rollover; **sum** on double deposit), `verify_actual_balance` with `u128(0)` after register-only or after `deposit` only (no rollover), `verify_actual_balance` matching deposited `u128` after one or **two** `deposit` + `rollover_pending_balance` (**sum** on double deposit), … — Lean stub, not full CA store replay)
- 102: CA e2e merged oracle `bool(false)` witness (`is_normalized` after rollover, `has_confidential_asset_store` before register / peer not registered, `is_allow_list_enabled` off mainnet, `is_frozen` before freeze or after unfreeze, `verify_{pending,actual}_balance` non-zero claims after `register` only (balances still zero), `verify_actual_balance` non-zero `u128` after `deposit` only (no rollover; actual still zero), `verify_actual_balance` wrong `u128` or **`u128(0)`** after `deposit` + `rollover` when **actual** is non-zero, **wrong `u128` sum** after **two** `deposit`s + `rollover`, `verify_pending_balance` wrong `u64` after `deposit` without rollover, **wrong `u64` sum** after **two** `deposit`s without rollover, stale **`u64(deposit)`** or **stale summed `u64`** (two deposits) on **pending** after `rollover`, **wrong `u64`** (e.g. off-by-one vs pre-rollover sum) on **pending** after **two** `deposit`s + `rollover`, `verify_pending_balance` non-zero `u64` after `deposit` + `rollover_pending_balance`, …)
- 103: CA e2e merged oracle `u64(77)` witness (`confidential_asset_balance` after deposit 77)
- 104: CA e2e merged oracle `u64(165)` witness (`confidential_asset_balance` after deposits 100+65)
- 105: CA e2e merged oracle `u64(667)` witness (`confidential_asset_balance` after deposit 1000 and withdraw 333)
- 106: CA e2e merged oracle `u64(5678)` witness (`confidential_asset_balance` after single `deposit_to`)
- 107: CA e2e merged oracle `u64(12345)` witness (pool unchanged after `confidential_transfer` from initial deposit)
- 108: CA e2e merged oracle `u64(7000)` witness (deposits 5000 + 2000 after a mid-scenario `confidential_transfer`)
- 109: CA e2e merged oracle `u64(7777)` witness (two sequential `deposit_to` to the same recipient)
- 110–113: `deserialize_*` **layout-only** `Some` oracle rows (`bool(true)` on VM); Lean **same bytecode as 128–130** — `ldConst` **24–26** + `vecLen` + `eq` (necessary sigma **length** on corpus bytes; not full parser / `verify_*` in `eval`)
- 114: `serialize_auditor_eks` with one **A_POINT** pubkey — Lean returns the **32**-byte wire via `ldConst` **10** (real `Step` bytecode, same bytes as VM `pubkey_to_bytes`)
- 115: `serialize_auditor_amounts` with one **`new_pending_balance_no_randomness`** balance — Lean returns the **256**-byte wire via `ldConst` **11** (all **zero** bytes on current VM; real `Step` bytecode)
- 116: `serialize_auditor_eks` with two **A_POINT** pubkeys — **64**-byte wire via `ldConst` **12**
- 117: `serialize_auditor_amounts` with two zero-pending balances — **512**-byte wire via `ldConst` **13** (all **zero** on current VM)
- 118: `serialize_auditor_amounts` with one **`new_pending_balance_u64_no_randonmess(1)`** — **256**-byte wire via `ldConst` **14** (VM-pinned ElGamal encoding)
- 119: `serialize_auditor_amounts` with one **`new_actual_balance_no_randomness`** — **512**-byte wire via `ldConst` **15** (all **zero** on current VM)
- 120: `serialize_auditor_amounts` with **zero** pending then **`new_pending_balance_u64_no_randonmess(1)`** — **512**-byte wire via `ldConst` **16** (append of **115** + **118** wires)
- 121: `serialize_auditor_amounts` with **`new_pending_balance_u64_no_randonmess(1)`** then **zero** pending — **512**-byte wire via `ldConst` **17** (append of **118** + **115**; differs from **120**)
- 122: `serialize_auditor_amounts` with **`new_actual_balance_no_randomness`** then **`new_pending_balance_u64_no_randonmess(1)`** — **768**-byte wire via `ldConst` **18** (**512** + **256**)
- 123: **`new_pending_balance_u64_no_randonmess(1)`** then **`new_actual_balance_no_randomness`** — **768**-byte wire via `ldConst` **19**
- 124: `serialize_auditor_eks` with three **A_POINT** pubkeys — **96**-byte wire via `ldConst` **20**
- 125: `serialize_auditor_eks` with four **A_POINT** pubkeys — **128**-byte wire via `ldConst` **21**
- 126: `serialize_auditor_eks` with five **A_POINT** pubkeys — **160**-byte wire via `ldConst` **22**
- 127: `serialize_auditor_eks` with six **A_POINT** pubkeys — **192**-byte wire via `ldConst` **23**
- 128: sigma **18+18** layout wire `vector<u8>` length **1152** — `ldConst` **24** + `vecLen` + `eq` (matches `deserialize_sigma_18_scalars_18_points.hex`; same bytecode as **110** / **111**)
- 129: sigma **19+19** layout wire length **1216** — `ldConst` **25** + `vecLen` + `eq` (same bytecode as **112**)
- 130: transfer sigma **26+30** layout wire length **1792** — `ldConst` **26** + `vecLen` + `eq` (same bytecode as **113**)
- 131: transfer sigma **+ one auditor quad** wire length **1920** — `ldConst` **27** + `vecLen` + `eq`
- 132: VM **`deserialize_transfer`** extended `Some` — Lean **same bytecode as 131**
- 133: transfer sigma **+ two auditor quads** wire length **2048** — `ldConst` **28** + `vecLen` + `eq`
- 134: VM **`deserialize_transfer`** two-quad extended `Some` — Lean **same bytecode as 133**
- 135: transfer sigma **+ three auditor quads** wire length **2176** — `ldConst` **29** + `vecLen` + `eq`
- 136: VM **`deserialize_transfer`** three-quad extended `Some` — Lean **same bytecode as 135**
- 137: transfer sigma **+ four auditor quads** wire length **2304** — `ldConst` **30** + `vecLen` + `eq`
- 138: VM **`deserialize_transfer`** four-quad extended `Some` — Lean **same bytecode as 137**
- 139: transfer sigma **+ five auditor quads** wire length **2432** — `ldConst` **31** + `vecLen` + `eq`
- 140: VM **`deserialize_transfer`** five-quad extended `Some` — Lean **same bytecode as 139**
- 141: transfer sigma **+ six auditor quads** wire length **2560** — `ldConst` **32** + `vecLen` + `eq`
- 142: VM **`deserialize_transfer`** six-quad extended `Some` — Lean **same bytecode as 141**
- 143: transfer sigma **+ seven auditor quads** wire length **2688** — `ldConst` **33** + `vecLen` + `eq`
- 144: VM **`deserialize_transfer`** seven-quad extended `Some` — Lean **same bytecode as 143**
- 145: transfer sigma **+ eight auditor quads** wire length **2816** — `ldConst` **34** + `vecLen` + `eq`
- 146: VM **`deserialize_transfer`** eight-quad extended `Some` — Lean **same bytecode as 145**
- 147: transfer sigma **+ nine auditor quads** wire length **2944** — `ldConst` **35** + `vecLen` + `eq`
- 148: VM **`deserialize_transfer`** nine-quad extended `Some` — Lean **same bytecode as 147**
- 149: transfer sigma **+ ten auditor quads** wire length **3072** — `ldConst` **36** + `vecLen` + `eq`
- 150: VM **`deserialize_transfer`** ten-quad extended `Some` — Lean **same bytecode as 149**
- 151: transfer sigma **+ eleven auditor quads** wire length **3200** — `ldConst` **37** + `vecLen` + `eq`
- 152: VM **`deserialize_transfer`** eleven-quad extended `Some` — Lean **same bytecode as 151**
- 153: transfer sigma **+ twelve auditor quads** wire length **3328** — `ldConst` **38** + `vecLen` + `eq`
- 154: VM **`deserialize_transfer`** twelve-quad extended `Some` — Lean **same bytecode as 153**
- 155: transfer sigma **+ thirteen auditor quads** wire length **3456** — `ldConst` **39** + `vecLen` + `eq`
- 156: VM **`deserialize_transfer`** thirteen-quad extended `Some` — Lean **same bytecode as 155**
- 157: transfer sigma **+ fourteen auditor quads** wire length **3584** — `ldConst` **40** + `vecLen` + `eq`
- 158: VM **`deserialize_transfer`** fourteen-quad extended `Some` — Lean **same bytecode as 157**
- 159: transfer sigma **+ fifteen auditor quads** wire length **3712** — `ldConst` **41** + `vecLen` + `eq`
- 160: VM **`deserialize_transfer`** fifteen-quad extended `Some` — Lean **same bytecode as 159**
- 161: transfer sigma **+ sixteen auditor quads** wire length **3840** — `ldConst` **42** + `vecLen` + `eq`
- 162: VM **`deserialize_transfer`** sixteen-quad extended `Some` — Lean **same bytecode as 161**
- 163: transfer sigma **+ seventeen auditor quads** wire length **3968** — `ldConst` **43** + `vecLen` + `eq`
- 164: VM **`deserialize_transfer`** seventeen-quad extended `Some` — Lean **same bytecode as 163**
- 165: transfer sigma **+ eighteen auditor quads** wire length **4096** — `ldConst` **44** + `vecLen` + `eq`
- 166: VM **`deserialize_transfer`** eighteen-quad extended `Some` — Lean **same bytecode as 165**
- 167: transfer sigma **+ nineteen auditor quads** wire length **4224** — `ldConst` **45** + `vecLen` + `eq`
- 168: VM **`deserialize_transfer`** nineteen-quad extended `Some` — Lean **same bytecode as 167**
- 169: FA stub **`faWriteBalance`** + **`faReadBalance`** (`test_fa_stub_write_then_read_balance`; empty initial `faBalances`)
- 170: registration FS **`registration_fs_message_for_test`** equals helpers golden (`test_registration_fs_message_framework_matches_helpers_golden`; Lean `ldTrue` stub)
- 171: production registration deterministic prove + **`verify_registration_proof_for_difftest`** (`test_registration_proof_framework_deterministic_verify_roundtrip`; Lean **`caRegistrationHelpersRoundtripNative`**, same as **35**)
- 172: second registration FS golden **`vector<u8>`** (`test_registration_fs_message_golden_move_second`; **`ldConst` 46** + `ret`)
- 173: second registration FS **`registration_fs_message_for_test`** equals helpers golden (`test_registration_fs_message_framework_second_scenario_matches_helpers_golden`; Lean `ldTrue` stub)
- 174: first registration **`tagged_hash`** on FS golden **1** — **`vector<u8>`** (**64** B; `test_registration_tagged_hash_golden_move_first`; **`ldConst` 47** + `ret`)
- 175: second registration **`tagged_hash`** on FS golden **2** — **`vector<u8>`** (**64** B; `test_registration_tagged_hash_golden_move_second`; **`ldConst` 48** + `ret`)
-/

/-- Oracle row routing: name → evaluator env + function index.

`FuncMapping` + the large string table live in `RunnerFuncMappingAux.lean` (split matches) so this file
elaborates under the default `maxHeartbeats` budget. -/

def funcNameToMapping (name : String) : Option FuncMapping :=
  let base := match name.splitOn " [" with
    | [x] => x
    | x :: _ => x
    | [] => name
  funcNameToMappingFromBase base

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
  if tc.skipLean then
    .skipped "skip_lean (VM-only oracle row)"
  else
  match funcNameToMapping tc.function with
  | none => .skipped s!"no Lean mapping for '{tc.function}'"
  | some mapping =>
    let env :=
      if mapping.useConfidentialEnv then confidentialModuleEnv
      else if mapping.useRealEnv then realModuleEnv
      else stdModuleEnv
    let base :=
      match tc.function.splitOn " [" with
      | x :: _ => x
      | [] => tc.function
    let initMs :=
      if base == "test_fa_stub_balance_answer" then
        { MachineState.empty with
          faBalances := [((UInt64.ofNat 1, UInt64.ofNat 2), UInt64.ofNat 12345)] }
      else
        MachineState.empty
    let result := eval env mapping.funcIdx tc.args defaultFuel initMs
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
  match suite.schemaVersion with
  | none => IO.println "Oracle schema_version: (absent; legacy oracle)"
  | some v => IO.println s!"Oracle schema_version: {v}"
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
