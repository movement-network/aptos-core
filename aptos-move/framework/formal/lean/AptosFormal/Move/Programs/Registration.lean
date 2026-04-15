import AptosFormal.Move.Native.Registration

/-!
# Transcribed bytecode for `verify_registration_proof`

Faithful `MoveInstr` array transcribed from the **`movement` v7.4.0**
disassembly output (`movement move disassemble`) for
`aptos_experimental::confidential_proof::verify_registration_proof`
(`confidential_proof.mv.asm`, def_idx 39, PC 0–82).

## Local layout (19 locals: 7 params + 12 temporaries)

| Index | Name | Type |
|-------|------|------|
| 0 | `chain_id` | `u8` |
| 1 | `sender` | `address` |
| 2 | `contract_address` | `address` |
| 3 | `ek` | `&CompressedPubkey` (immutable reference) |
| 4 | `token_address` | `address` |
| 5 | `commitment_bytes` | `vector<u8>` |
| 6 | `response_bytes` | `vector<u8>` |
| 7 | `r_point` | `Option<CompressedRistretto>` |
| 8 | `r_compressed` | `CompressedRistretto` |
| 9 | `s` (Option) | `Option<Scalar>` |
| 10 | `s` (extracted) | `Scalar` |
| 11 | `msg` | `vector<u8>` |
| 12 | `e` | `Scalar` |
| 13 | `h` | `RistrettoPoint` |
| 14 | `ek_point` | `RistrettoPoint` |
| 15 | `$t41` | `RistrettoPoint` |
| 16 | `$t45` | `RistrettoPoint` |
| 17 | `lhs` | `RistrettoPoint` |
| 18 | `rhs` | `RistrettoPoint` |

## Function table

See `AptosFormal.Move.Native.Registration` for the full index table (indices 0–17).
-/

namespace AptosFormal.Move.Programs.Registration

open AptosFormal.Move
open AptosFormal.Move.Native.Registration

/-- `FIAT_SHAMIR_REGISTRATION_SIGMA_DST` = `b"MovementConfidentialAsset/Registration"` (38 bytes). -/
def fiatShamirRegistrationDstValue : MoveValue :=
  .vector .u8 (
    [77, 111, 118, 101, 109, 101, 110, 116, 67, 111, 110, 102, 105, 100, 101, 110, 116, 105, 97, 108,
     65, 115, 115, 101, 116, 47, 82, 101, 103, 105, 115, 116, 114, 97, 116, 105, 111, 110
    ].map MoveValue.u8)

/-- Constant pool entry for `LdConst[5]` — the DST tag:
    `[38, 77, 111, ..., 110]` = length-prefixed
    `"MovementConfidentialAsset/Registration"`. -/
def registrationConstPool : Array ConstPoolEntry := #[
  { type := .vector .u8, value := .vector .u8 [] },  -- 0: unused
  { type := .vector .u8, value := .vector .u8 [] },  -- 1: unused
  { type := .vector .u8, value := .vector .u8 [] },  -- 2: unused
  { type := .vector .u8, value := .vector .u8 [] },  -- 3: unused
  { type := .vector .u8, value := .vector .u8 [] },  -- 4: unused
  { type := .vector .u8, value := fiatShamirRegistrationDstValue }  -- 5
]

/-- Transcribed 83-instruction bytecode from `movement` v7.4.0 disassembly.
    7 parameters, 19 locals total (7 params + 12 temporaries). -/
def verifyRegistrationProofCode : Array MoveInstr := #[
  -- B0: Decompress commitment point R
  .moveLoc 5,              -- 0: push commitment_bytes
  .call 0,                 -- 1: new_compressed_point_from_bytes → r_point
  .stLoc 7,                -- 2: store r_point
  .immBorrowLoc 7,         -- 3: &r_point
  .call 1,                 -- 4: option::is_some(&Option<CompressedRistretto>) → bool
  .brFalse 78,             -- 5: if false, goto B6 (abort)

  -- B1: Extract r_compressed, parse response scalar
  .mutBorrowLoc 7,         -- 6: &mut r_point
  .call 2,                 -- 7: option::extract(&mut Option<CompressedRistretto>) → CompressedRistretto
  .stLoc 8,                -- 8: store r_compressed
  .moveLoc 6,              -- 9: push response_bytes
  .call 3,                 -- 10: new_scalar_from_bytes → s_opt
  .stLoc 9,                -- 11: store s_opt
  .immBorrowLoc 9,         -- 12: &s_opt
  .call 1,                 -- 13: option::is_some(&Option<Scalar>) → bool
  .brFalse 73,             -- 14: if false, goto B5 (abort)

  -- B2: Extract s, build Fiat-Shamir message, verify
  .mutBorrowLoc 9,         -- 15: &mut s_opt
  .call 2,                 -- 16: option::extract(&mut Option<Scalar>) → Scalar
  .stLoc 10,               -- 17: store s
  .moveLoc 0,              -- 18: push chain_id
  .call 4,                 -- 19: vector::singleton<u8>
  .stLoc 11,               -- 20: store msg
  .mutBorrowLoc 11,        -- 21: &mut msg
  .immBorrowLoc 1,         -- 22: &sender
  .call 5,                 -- 23: bcs::to_bytes<address>(&address) → vector<u8>
  .call 6,                 -- 24: vector::append<u8>(&mut vector<u8>, vector<u8>)
  .mutBorrowLoc 11,        -- 25: &mut msg
  .immBorrowLoc 2,         -- 26: &contract_address
  .call 5,                 -- 27: bcs::to_bytes<address>(&address) → vector<u8>
  .call 6,                 -- 28: vector::append<u8>
  .mutBorrowLoc 11,        -- 29: &mut msg
  .immBorrowLoc 4,         -- 30: &token_address
  .call 5,                 -- 31: bcs::to_bytes<address>(&address) → vector<u8>
  .call 6,                 -- 32: vector::append<u8>
  .mutBorrowLoc 11,        -- 33: &mut msg
  .copyLoc 3,              -- 34: copy ek (&CompressedPubkey — already a ref)
  .call 7,                 -- 35: pubkey_to_bytes(&CompressedPubkey) → vector<u8>
  .call 6,                 -- 36: vector::append<u8>
  .mutBorrowLoc 11,        -- 37: &mut msg
  .copyLoc 8,              -- 38: copy r_compressed (value, not ref)
  .call 8,                 -- 39: compressed_point_to_bytes(CompressedRistretto) → vector<u8>
  .call 6,                 -- 40: vector::append<u8>
  .ldConst 5,              -- 41: push DST tag
  .moveLoc 11,             -- 42: push msg (consumed)
  .call 9,                 -- 43: new_scalar_from_tagged_hash → e
  .stLoc 12,               -- 44: store e
  .call 10,                -- 45: hash_to_point_base → h
  .stLoc 13,               -- 46: store h
  .moveLoc 3,              -- 47: push ek ref (consumed)
  .call 11,                -- 48: pubkey_to_point(&CompressedPubkey) → ek_point
  .stLoc 14,               -- 49: store ek_point
  .immBorrowLoc 13,        -- 50: &h
  .immBorrowLoc 10,        -- 51: &s
  .call 12,                -- 52: point_mul(&RistrettoPoint, &Scalar) → $t41
  .stLoc 15,               -- 53: store $t41
  .immBorrowLoc 15,        -- 54: &$t41
  .immBorrowLoc 14,        -- 55: &ek_point
  .immBorrowLoc 12,        -- 56: &e
  .call 12,                -- 57: point_mul(&RistrettoPoint, &Scalar) → $t45
  .stLoc 16,               -- 58: store $t45
  .immBorrowLoc 16,        -- 59: &$t45
  .call 13,                -- 60: point_add(&RistrettoPoint, &RistrettoPoint) → lhs
  .stLoc 17,               -- 61: store lhs
  .immBorrowLoc 8,         -- 62: &r_compressed
  .call 14,                -- 63: point_decompress(&CompressedRistretto) → rhs
  .stLoc 18,               -- 64: store rhs
  .immBorrowLoc 17,        -- 65: &lhs
  .immBorrowLoc 18,        -- 66: &rhs
  .call 15,                -- 67: point_equals(&RistrettoPoint, &RistrettoPoint) → bool
  .brFalse 70,             -- 68: if false, goto B4 (abort)

  -- B3: Success
  .ret,                    -- 69: return

  -- B4: Verification failed
  .ldU64 1,                -- 70: push 1
  .call 16,                -- 71: error::invalid_argument(1) → 65537
  .abort_,                 -- 72: abort

  -- B5: Scalar parse failed (drop ek ref first)
  .moveLoc 3,              -- 73: push ek ref
  .pop,                    -- 74: drop ek ref
  .ldU64 1,                -- 75: push 1
  .call 16,                -- 76: error::invalid_argument(1) → 65537
  .abort_,                 -- 77: abort

  -- B6: Point parse failed (drop ek ref first)
  .moveLoc 3,              -- 78: push ek ref
  .pop,                    -- 79: drop ek ref
  .ldU64 1,                -- 80: push 1
  .call 16,                -- 81: error::invalid_argument(1) → 65537
  .abort_                  -- 82: abort
]

def verifyRegistrationProofDesc : FuncDesc :=
  { numParams := 7
    numReturns := 0
    body := .bytecode verifyRegistrationProofCode 19 }

/-- Build a `ModuleEnv` for the **real** `verify_registration_proof` bytecode
    from a `RegistrationNativeOracle`. Uses ref-aware native descriptors matching
    the `movement` v7.4.0 calling conventions.

    Function index 17 is the verifier entry point. -/
def registrationModuleEnv (o : RegistrationNativeOracle) : ModuleEnv :=
  { constants := registrationConstPool
    functions := #[
      { numParams := 1, numReturns := 1,                                        -- 0: new_compressed_point_from_bytes
        body := .native o.newCompressedPointFromBytes },
      optionIsSomeRefDesc,                                                       -- 1: option::is_some<T>
      optionExtractRefDesc,                                                      -- 2: option::extract<T>
      { numParams := 1, numReturns := 1,                                        -- 3: new_scalar_from_bytes
        body := .native o.newScalarFromBytes },
      { numParams := 1, numReturns := 1,                                        -- 4: vector::singleton<u8>
        body := .native vectorSingletonU8 },
      bcsToBytesAddressRefDesc,                                                  -- 5: bcs::to_bytes<address>
      vectorAppendU8RefDesc,                                                     -- 6: vector::append<u8>
      { numParams := 1, numReturns := 1,                                        -- 7: pubkey_to_bytes (ref)
        body := .nativeRef (wrapOracleImmRef1 o.pubkeyToBytes) },
      { numParams := 1, numReturns := 1,                                        -- 8: compressed_point_to_bytes (value)
        body := .native o.compressedPointToBytes },
      newScalarFromTaggedHashDesc,                                               -- 9: new_scalar_from_tagged_hash
      { numParams := 0, numReturns := 1,                                        -- 10: hash_to_point_base
        body := .native o.hashToPointBase },
      { numParams := 1, numReturns := 1,                                        -- 11: pubkey_to_point (ref)
        body := .nativeRef (wrapOracleImmRef1 o.pubkeyToPoint) },
      { numParams := 2, numReturns := 1,                                        -- 12: point_mul (refs)
        body := .nativeRef (wrapOracleImmRef2 o.pointMul) },
      { numParams := 2, numReturns := 1,                                        -- 13: point_add (refs)
        body := .nativeRef (wrapOracleImmRef2 o.pointAdd) },
      { numParams := 1, numReturns := 1,                                        -- 14: point_decompress (ref)
        body := .nativeRef (wrapOracleImmRef1 o.pointDecompress) },
      { numParams := 2, numReturns := 1,                                        -- 15: point_equals (refs)
        body := .nativeRef (wrapOracleImmRef2 o.pointEquals) },
      errorInvalidArgumentDesc,                                                  -- 16: error::invalid_argument
      verifyRegistrationProofDesc                                                -- 17: bytecode entry
    ] }

/-- The function index of `verify_registration_proof` in `registrationModuleEnv`. -/
def verifyRegistrationProofIdx : Nat := 17

end AptosFormal.Move.Programs.Registration
