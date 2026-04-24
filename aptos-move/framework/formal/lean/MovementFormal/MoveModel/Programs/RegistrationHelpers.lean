import MovementFormal.MoveModel.Value
import MovementFormal.MoveModel.State
import MovementFormal.MoveModel.Native

/-! # Registration Program Helpers

Helper functions for constructing registration verification program state.
-/

namespace MovementFormal.MoveModel.Programs.Registration

open MovementFormal.MoveModel
open MovementFormal.MoveModel.Native

/-! ## Local Variable Construction

The `verify_registration_proof` function has 7 parameters and allocates 12 additional locals
for intermediate values during execution (total 19 locals).

Parameters (locals 0-6):
- 0: chainId (u8)
- 1: sender (address)
- 2: contract (address)
- 3: token (address)
- 4: ekBa (vector<u8>)
- 5: commitBa (vector<u8>)
- 6: respBa (vector<u8>)

Intermediate locals (7-18):
- 7: v (Option<CompressedPoint> from newCompressedPointFromBytes)
- 8: rCompressed (extracted CompressedPoint)
- 9: s_opt (Option<Scalar> from newScalarFromBytes)
- 10: scalar (extracted Scalar)
- 11-18: various intermediate computation results
-/

/-- Construct initial locals array for verify_registration_proof.
    Parameters are required, intermediate locals default to none. -/
def registrationLocals
    (chainId : UInt8)
    (sender : ByteArray)
    (contract : ByteArray)
    (token : ByteArray)
    (ekBa : ByteArray)
    (commitBa : ByteArray)
    (respBa : ByteArray)
    (local7 : Option MoveValue := none)
    (local8 : Option MoveValue := none)
    (local9 : Option MoveValue := none)
    (local10 : Option MoveValue := none)
    (local11 : Option MoveValue := none)
    (local12 : Option MoveValue := none)
    (local13 : Option MoveValue := none)
    (local14 : Option MoveValue := none)
    (local15 : Option MoveValue := none)
    (local16 : Option MoveValue := none)
    (local17 : Option MoveValue := none)
    (local18 : Option MoveValue := none) : Array (Option MoveValue) :=
  #[
    some (.u8 chainId),                                     -- 0
    some (.address sender),                                 -- 1
    some (.address contract),                               -- 2
    some (.address token),                                  -- 3
    some (bytesToMoveVec ekBa),                            -- 4
    some (bytesToMoveVec commitBa),                        -- 5
    some (bytesToMoveVec respBa),                          -- 6
    local7,                       -- 7
    local8,                       -- 8
    local9,                       -- 9
    local10,                      -- 10
    local11,                      -- 11
    local12,                      -- 12
    local13,                      -- 13
    local14,                      -- 14
    local15,                      -- 15
    local16,                      -- 16
    local17,                      -- 17
    local18                       -- 18
  ]

/-! ## Basic Properties -/

theorem registrationLocals_size
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (l7 l8 l9 l10 l11 l12 l13 l14 l15 l16 l17 l18 : Option MoveValue) :
    (registrationLocals chainId sender contract token ekBa commitBa respBa
      l7 l8 l9 l10 l11 l12 l13 l14 l15 l16 l17 l18).size = 19 := by
  rfl

theorem registrationLocals_param0
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (l7 l8 l9 l10 l11 l12 l13 l14 l15 l16 l17 l18 : Option MoveValue)
    (h : 0 < 19) :
    (registrationLocals chainId sender contract token ekBa commitBa respBa
      l7 l8 l9 l10 l11 l12 l13 l14 l15 l16 l17 l18)[0]'h = some (.u8 chainId) := by
  rfl

theorem registrationLocals_param1
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (l7 l8 l9 l10 l11 l12 l13 l14 l15 l16 l17 l18 : Option MoveValue)
    (h : 1 < 19) :
    (registrationLocals chainId sender contract token ekBa commitBa respBa
      l7 l8 l9 l10 l11 l12 l13 l14 l15 l16 l17 l18)[1]'h = some (.address sender) := by
  rfl

theorem registrationLocals_local7
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (l7 l8 l9 l10 l11 l12 l13 l14 l15 l16 l17 l18 : Option MoveValue)
    (h : 7 < 19) :
    (registrationLocals chainId sender contract token ekBa commitBa respBa
      l7 l8 l9 l10 l11 l12 l13 l14 l15 l16 l17 l18)[7]'h = l7 := by
  rfl

end MovementFormal.MoveModel.Programs.Registration
