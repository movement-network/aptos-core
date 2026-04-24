import MovementFormal.MoveModel.Value
import MovementFormal.MoveModel.State
import MovementFormal.MoveModel.Programs.Registration

/-! # Frame Construction Helpers

This file provides comprehensive utilities for constructing Frame states in the
registration singleton branch proof. Frame construction is pervasive throughout
the PC-by-PC proof, appearing at every step to represent the execution state.

## Frame Structure

A Frame consists of:
- `code`: The bytecode array (verifyRegistrationProofCode)
- `pc`: Program counter (0-70 for singleton branch)
- `locals`: Array of optional values (size 19 for registration proof)
- `localRefs`: Array of optional RefIds (size 19 for registration proof)

## Locals Layout (19 entries, indices 0-18)

Based on `verify_registration_proof` bytecode transcription:
- 0: chain_id (u8)
- 1: sender (address)
- 2: contract (address)
- 3: token (address)
- 4: ek (vector<u8>)
- 5: commit_ba (vector<u8>)
- 6: resp_ba (vector<u8>)
- 7: v (Option<CompressedPoint>) - result from newCompressedPointFromBytes
- 8: r_compressed (CompressedPoint) - extracted from v
- 9: s_opt (Option<Scalar>) - result from newScalarFromBytes
- 10: scalar (Scalar) - extracted from s_opt
- 11: message buffer (vector<u8>) - Fiat-Shamir message
- 12: challenge (Scalar) - result from newScalarFromSha2_512
- 13: h_base (CompressedPoint) - result from hashToPointBase
- 14: ek_point (CompressedPoint) - result from pubkeyToPoint
- 15: h_s (CompressedPoint) - result from pointMul(h_base, scalar)
- 16: ek_e (CompressedPoint) - result from pointMul(ek_point, challenge)
- 17: lhs (CompressedPoint) - result from pointAdd(h_s, ek_e)
- 18: rhs (Point) - result from pointDecompress(r_compressed)

## LocalRefs Layout

LocalRefs track which locals have been allocated into the container store:
- Most entries start as `none`
- Populated by immBorrowLoc/mutBorrowLoc when locals are referenced
- Key allocations:
  - localRefs[7]: Option value v (allocated at PC 3/4)
  - localRefs[9]: Option value s_opt (allocated at PC 12)
  - localRefs[11]: Message buffer (allocated at PC 21/22)
  - localRefs[10], [12], [13], [14]: Scalars and points (allocated during PC 43-70)

-/

namespace MovementFormal.Experimental.ConfidentialAsset.Registration.FrameConstructionHelpers

open MovementFormal.MoveModel
open MovementFormal.MoveModel.Programs.Registration

/-! ## Base Locals Construction

Fundamental builders for locals arrays at different execution points.
-/

/-- Initial locals at entry to verify_registration_proof (PC 0).
All parameters populated, local variables uninitialized. -/
def buildInitialLocals
    (chainId : UInt8)
    (sender contract token : ByteArray)
    (ekBa commitBa respBa : ByteArray) :
    Array (Option MoveValue) :=
  #[
    some (.u8 chainId),
    some (.address sender),
    some (.address contract),
    some (.address token),
    some (.vector .u8 (ekBa.toList.map .u8)),
    some (.vector .u8 (commitBa.toList.map .u8)),
    some (.vector .u8 (respBa.toList.map .u8)),
    none,  -- 7: v (not yet computed)
    none,  -- 8: r_compressed (not yet extracted)
    none,  -- 9: s_opt (not yet computed)
    none,  -- 10: scalar (not yet extracted)
    none,  -- 11: message buffer (not yet created)
    none,  -- 12: challenge (not yet computed)
    none,  -- 13: h_base (not yet computed)
    none,  -- 14: ek_point (not yet computed)
    none,  -- 15: h_s (not yet computed)
    none,  -- 16: ek_e (not yet computed)
    none,  -- 17: lhs (not yet computed)
    none   -- 18: rhs (not yet computed)
  ]

/-- Locals after PC 4 (v computed and stored). -/
def buildLocalsAtPC4
    (chainId : UInt8)
    (sender contract token : ByteArray)
    (ekBa commitBa respBa : ByteArray)
    (v : MoveValue) :
    Array (Option MoveValue) :=
  (buildInitialLocals chainId sender contract token ekBa commitBa respBa).set! 7 (some v)

/-- Locals after PC 8 (r_compressed extracted and stored). -/
def buildLocalsAtPC8
    (chainId : UInt8)
    (sender contract token : ByteArray)
    (ekBa commitBa respBa : ByteArray)
    (v rCompressed : MoveValue) :
    Array (Option MoveValue) :=
  (buildLocalsAtPC4 chainId sender contract token ekBa commitBa respBa v).set! 8 (some rCompressed)

/-- Locals after PC 11 (s_opt computed and stored, resp_ba consumed). -/
def buildLocalsAtPC11
    (chainId : UInt8)
    (sender contract token : ByteArray)
    (ekBa commitBa respBa : ByteArray)
    (v rCompressed s_opt : MoveValue) :
    Array (Option MoveValue) :=
  ((buildLocalsAtPC8 chainId sender contract token ekBa commitBa respBa v rCompressed).set! 6 none).set! 9 (some s_opt)

/-- Locals after PC 18 (scalar extracted and stored). -/
def buildLocalsAtPC18
    (chainId : UInt8)
    (sender contract token : ByteArray)
    (ekBa commitBa respBa : ByteArray)
    (v rCompressed s_opt scalar : MoveValue) :
    Array (Option MoveValue) :=
  (buildLocalsAtPC11 chainId sender contract token ekBa commitBa respBa v rCompressed s_opt).set! 10 (some scalar)

/-- Locals after PC 20 (message buffer created). -/
def buildLocalsAtPC20
    (chainId : UInt8)
    (sender contract token : ByteArray)
    (ekBa commitBa respBa : ByteArray)
    (v rCompressed s_opt scalar msgBuf : MoveValue) :
    Array (Option MoveValue) :=
  (buildLocalsAtPC18 chainId sender contract token ekBa commitBa respBa v rCompressed s_opt scalar).set! 11 (some msgBuf)

/-- Locals after PC 43 (message assembly complete, ready for challenge). -/
def buildLocalsAtPC43
    (chainId : UInt8)
    (sender contract token : ByteArray)
    (ekBa commitBa respBa : ByteArray)
    (v rCompressed s_opt scalar msgBuf : MoveValue) :
    Array (Option MoveValue) :=
  buildLocalsAtPC20 chainId sender contract token ekBa commitBa respBa v rCompressed s_opt scalar msgBuf

/-- Locals after PC 50 (challenge and base computed, ready for point operations). -/
def buildLocalsAtPC50
    (chainId : UInt8)
    (sender contract token : ByteArray)
    (ekBa commitBa respBa : ByteArray)
    (v rCompressed s_opt scalar msgBuf challenge h_base ek_point : MoveValue) :
    Array (Option MoveValue) :=
  (((buildLocalsAtPC43 chainId sender contract token ekBa commitBa respBa v rCompressed s_opt scalar msgBuf).set! 12 (some challenge)).set! 13 (some h_base)).set! 14 (some ek_point)

/-- Locals after PC 58 (h_s and ek_e computed, ready for pointAdd). -/
def buildLocalsAtPC58
    (chainId : UInt8)
    (sender contract token : ByteArray)
    (ekBa commitBa respBa : ByteArray)
    (v rCompressed s_opt scalar msgBuf challenge h_base ek_point h_s ek_e : MoveValue) :
    Array (Option MoveValue) :=
  ((buildLocalsAtPC50 chainId sender contract token ekBa commitBa respBa v rCompressed s_opt scalar msgBuf challenge h_base ek_point).set! 15 (some h_s)).set! 16 (some ek_e)

/-! ## LocalRefs Construction

Builders for localRefs arrays tracking container allocations.
-/

/-- Initial localRefs (all none). -/
def buildInitialLocalRefs : Array (Option RefId) :=
  (List.replicate 19 none).toArray

/-- LocalRefs after v is allocated (PC 3/4). -/
def buildLocalRefsWithV (rid_v : RefId) : Array (Option RefId) :=
  buildInitialLocalRefs.set! 7 (some rid_v)

/-- LocalRefs after v and s_opt are allocated (PC 12). -/
def buildLocalRefsWithVAndS (rid_v rid_s : RefId) : Array (Option RefId) :=
  (buildLocalRefsWithV rid_v).set! 9 (some rid_s)

/-- LocalRefs after message buffer is allocated (PC 21/22). -/
def buildLocalRefsWithMsg (rid_v rid_s rid_msg : RefId) : Array (Option RefId) :=
  (buildLocalRefsWithVAndS rid_v rid_s).set! 11 (some rid_msg)

/-- LocalRefs with all major allocations (PC 50+). -/
def buildLocalRefsComplete
    (rid_v rid_s rid_msg rid_scalar rid_challenge rid_h rid_ek : RefId) :
    Array (Option RefId) :=
  ((((buildLocalRefsWithMsg rid_v rid_s rid_msg).set! 10 (some rid_scalar)).set! 12 (some rid_challenge)).set! 13 (some rid_h)).set! 14 (some rid_ek)

/-! ## Complete Frame Builders

High-level builders for complete frames at key execution points.
-/

/-- Frame at PC 0 (entry). -/
def buildFramePC0
    (chainId : UInt8)
    (sender contract token : ByteArray)
    (ekBa commitBa respBa : ByteArray) :
    Frame :=
  {
    code := verifyRegistrationProofCode,
    pc := 0,
    locals := buildInitialLocals chainId sender contract token ekBa commitBa respBa,
    localRefs := buildInitialLocalRefs
  }

/-- Frame at PC 4 (after v allocated). -/
def buildFramePC4
    (chainId : UInt8)
    (sender contract token : ByteArray)
    (ekBa commitBa respBa : ByteArray)
    (v : MoveValue)
    (rid_v : RefId) :
    Frame :=
  {
    code := verifyRegistrationProofCode,
    pc := 4,
    locals := buildLocalsAtPC4 chainId sender contract token ekBa commitBa respBa v,
    localRefs := buildLocalRefsWithV rid_v
  }

/-- Frame at PC 20 (after message buffer created). -/
def buildFramePC20
    (chainId : UInt8)
    (sender contract token : ByteArray)
    (ekBa commitBa respBa : ByteArray)
    (v rCompressed s_opt scalar msgBuf : MoveValue)
    (rid_v rid_s rid_msg : RefId) :
    Frame :=
  {
    code := verifyRegistrationProofCode,
    pc := 20,
    locals := buildLocalsAtPC20 chainId sender contract token ekBa commitBa respBa v rCompressed s_opt scalar msgBuf,
    localRefs := buildLocalRefsWithMsg rid_v rid_s rid_msg
  }

/-- Frame at PC 43 (message assembly complete). -/
def buildFramePC43
    (chainId : UInt8)
    (sender contract token : ByteArray)
    (ekBa commitBa respBa : ByteArray)
    (v rCompressed s_opt scalar msgBuf : MoveValue)
    (rid_v rid_s rid_msg : RefId) :
    Frame :=
  {
    code := verifyRegistrationProofCode,
    pc := 43,
    locals := buildLocalsAtPC43 chainId sender contract token ekBa commitBa respBa v rCompressed s_opt scalar msgBuf,
    localRefs := buildLocalRefsWithMsg rid_v rid_s rid_msg
  }

/-- Frame at PC 70 (final verification complete, before ret). -/
def buildFramePC70
    (chainId : UInt8)
    (sender contract token : ByteArray)
    (ekBa commitBa respBa : ByteArray)
    (v rCompressed s_opt scalar msgBuf challenge h_base ek_point h_s ek_e lhs rhs : MoveValue)
    (rid_v rid_s rid_msg rid_scalar rid_challenge rid_h rid_ek : RefId) :
    Frame :=
  {
    code := verifyRegistrationProofCode,
    pc := 70,
    locals := ((buildLocalsAtPC58 chainId sender contract token ekBa commitBa respBa v rCompressed s_opt scalar msgBuf challenge h_base ek_point h_s ek_e).set! 17 (some lhs)).set! 18 (some rhs),
    localRefs := buildLocalRefsComplete rid_v rid_s rid_msg rid_scalar rid_challenge rid_h rid_ek
  }

/-! ## Frame State Properties

Lemmas establishing properties of constructed frames.
-/

/-- Initial frame has correct PC. -/
theorem buildFramePC0_pc
    (chainId : UInt8)
    (sender contract token : ByteArray)
    (ekBa commitBa respBa : ByteArray) :
    (buildFramePC0 chainId sender contract token ekBa commitBa respBa).pc = 0 := by
  rfl

/-- Initial frame has correct code. -/
theorem buildFramePC0_code
    (chainId : UInt8)
    (sender contract token : ByteArray)
    (ekBa commitBa respBa : ByteArray) :
    (buildFramePC0 chainId sender contract token ekBa commitBa respBa).code = verifyRegistrationProofCode := by
  rfl

/-- Initial frame locals have size 19. -/
theorem buildFramePC0_locals_size
    (chainId : UInt8)
    (sender contract token : ByteArray)
    (ekBa commitBa respBa : ByteArray) :
    (buildFramePC0 chainId sender contract token ekBa commitBa respBa).locals.size = 19 := by
  rfl

/-- Initial frame localRefs have size 19. -/
theorem buildFramePC0_localRefs_size
    (chainId : UInt8)
    (sender contract token : ByteArray)
    (ekBa commitBa respBa : ByteArray) :
    (buildFramePC0 chainId sender contract token ekBa commitBa respBa).localRefs.size = 19 := by
  rfl

/-- Frame at PC 4 has v stored in local 7. -/
theorem buildFramePC4_local7
    (chainId : UInt8)
    (sender contract token : ByteArray)
    (ekBa commitBa respBa : ByteArray)
    (v : MoveValue)
    (rid_v : RefId) :
    (buildFramePC4 chainId sender contract token ekBa commitBa respBa v rid_v).locals[7]? = some (some v) := by
  sorry  -- From buildLocalsAtPC4 definition

/-- Frame at PC 20 has message buffer in local 11. -/
theorem buildFramePC20_local11
    (chainId : UInt8)
    (sender contract token : ByteArray)
    (ekBa commitBa respBa : ByteArray)
    (v rCompressed s_opt scalar msgBuf : MoveValue)
    (rid_v rid_s rid_msg : RefId) :
    (buildFramePC20 chainId sender contract token ekBa commitBa respBa v rCompressed s_opt scalar msgBuf rid_v rid_s rid_msg).locals[11]? =
      some (some msgBuf) := by
  sorry  -- From buildLocalsAtPC20 definition

/-! ## Frame Incremental Construction

Lemmas showing how frames evolve step-by-step.
-/

/-- Advancing from PC 4 to PC 5 updates PC but preserves locals (brFalse not taken). -/
theorem frame_pc4_to_pc5_preserves_locals
    (chainId : UInt8)
    (sender contract token : ByteArray)
    (ekBa commitBa respBa : ByteArray)
    (v : MoveValue)
    (rid_v : RefId)
    (frame_pc5 : Frame)
    (h_pc : frame_pc5.pc = 5)
    (h_code : frame_pc5.code = verifyRegistrationProofCode)
    (h_locals : frame_pc5.locals = (buildFramePC4 chainId sender contract token ekBa commitBa respBa v rid_v).locals)
    (h_localRefs : frame_pc5.localRefs = (buildFramePC4 chainId sender contract token ekBa commitBa respBa v rid_v).localRefs) :
    frame_pc5.locals.size = 19 := by
  sorry  -- From h_locals and buildFramePC4_locals_size

/-- stLoc modifies one local, preserves others. -/
theorem stLoc_preserves_other_locals
    (frame frame' : Frame)
    (idx : Nat)
    (v : MoveValue)
    (h_stLoc : frame'.locals = frame.locals.set! idx (some v))
    (idx' : Nat)
    (h_ne : idx ≠ idx') :
    frame'.locals[idx']? = frame.locals[idx']? := by
  sorry  -- From Array.set! properties

/-! ## Auxiliary Frame Properties

Helper properties for frame manipulation.
-/

/-- Frame with updated PC preserves code. -/
theorem frame_update_pc_preserves_code
    (frame : Frame)
    (pc_new : Nat) :
    { frame with pc := pc_new }.code = frame.code := by
  rfl

/-- Frame with updated locals preserves PC. -/
theorem frame_update_locals_preserves_pc
    (frame : Frame)
    (locals_new : Array (Option MoveValue)) :
    { frame with locals := locals_new }.pc = frame.pc := by
  rfl

/-- Frame with updated localRefs preserves locals. -/
theorem frame_update_localRefs_preserves_locals
    (frame : Frame)
    (localRefs_new : Array (Option RefId)) :
    { frame with localRefs := localRefs_new }.locals = frame.locals := by
  rfl

end MovementFormal.Experimental.ConfidentialAsset.Registration.FrameConstructionHelpers
