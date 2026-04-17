import MovementFormal.MoveModel.Native

/-!
# Global resource smoke bytecode

Tiny programs exercising `globalExists` / `globalMoveTo` / `mutBorrowGlobal` with a
fixed `GlobalResourceKey`. Used by `Tests/GlobalSmoke.lean` and as a template for
future CA transcription (see `difftest/STUB_POLICY.md`).
-/

namespace MovementFormal.MoveModel.Programs.GlobalSmoke

open MovementFormal.MoveModel

/-- Non-trivial address bytes (stable across smoke tests). -/
def smokeAddr : ByteArray :=
  ByteArray.mk #[0xCA, 0xFE, 0x00, 0x01]

/-- Non-trivial address + tag hash (`structTag` omitted). -/
def smokeGlobalKey : GlobalResourceKey :=
  { address := smokeAddr,
    structTagHash := 4242,
    instanceNonce := 0 }

/-- Distinct key + optional `StructTag` for signer-checked `move_to` smoke. -/
def smokeSignedStructTag : StructTag :=
  { account := smokeAddr,
    moduleName := ByteArray.mk #[115, 109, 111, 107, 101, 95, 115, 105, 103, 110, 101, 100],
    structName := ByteArray.mk #[82] }

def smokeSignedGlobalKey : GlobalResourceKey :=
  { address := smokeAddr,
    structTagHash := 5252,
    instanceNonce := 0,
    structTag := some smokeSignedStructTag }

def globalExistsFalseCode : Array MoveInstr := #[
  .globalExists smokeGlobalKey,
  .ret
]

def globalExistsFalseDesc : FuncDesc :=
  { numParams := 0, numReturns := 1, body := .bytecode globalExistsFalseCode 0 }

/-- Publish `7` at `smokeGlobalKey`, borrow, read, return. -/
def globalMoveExistsBorrowCode : Array MoveInstr := #[
  .ldU64 7,
  .globalMoveTo smokeGlobalKey,
  .mutBorrowGlobal smokeGlobalKey,
  .readRef,
  .ret
]

def globalMoveExistsBorrowDesc : FuncDesc :=
  { numParams := 0, numReturns := 1, body := .bytecode globalMoveExistsBorrowCode 0 }

/-- Like `globalMoveExistsBorrowCode`, but uses `globalMoveToSigned` + `ldSigner`. -/
def globalMoveSignedBorrowCode : Array MoveInstr := #[
  .ldSigner smokeAddr,
  .ldU64 7,
  .globalMoveToSigned smokeSignedGlobalKey,
  .mutBorrowGlobal smokeSignedGlobalKey,
  .readRef,
  .ret
]

def globalMoveSignedBorrowDesc : FuncDesc :=
  { numParams := 0, numReturns := 1, body := .bytecode globalMoveSignedBorrowCode 0 }

end MovementFormal.MoveModel.Programs.GlobalSmoke
