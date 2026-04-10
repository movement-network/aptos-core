/-
Copyright (c) Move Industries.

Mathematical **interface** for `aptos_experimental::confidential_proof::verify_registration_proof`.

Depends on **`AptosFormal.Std`** for hash/scalar types shared with the wider `aptos_framework` story,
and **`AptosFormal.Experimental.ConfidentialAsset.Registration.Formal`** for the transcript + abstract Schnorr spec.

Move reference: `aptos-move/framework/aptos-experimental/sources/confidential_asset/confidential_proof.move`.
-/

import AptosFormal.Experimental.ConfidentialAsset.Registration.Formal
import AptosFormal.AptosStd.Crypto.Ristretto255
import AptosFormal.AptosStd.Hash.Sha3_512

open AptosFormal.Experimental.ConfidentialAsset.Registration.Formal
open AptosFormal.AptosStd.Crypto.Ristretto255
open AptosFormal.AptosStd.Hash.Sha3_512

namespace RegistrationVerify

def fiatShamirRegistrationDst : ByteArray :=
  ByteArray.mk #[
    77, 111, 118, 101, 109, 101, 110, 116, 67, 111, 110, 102, 105, 100, 101, 110, 116, 105, 97, 108,
    65, 115, 115, 101, 116, 47, 82, 101, 103, 105, 115, 116, 114, 97, 116, 105, 111, 110
  ]

def compressed32? (b : ByteArray) : Option CompressedRistretto32 :=
  if hb : b.size = 32 then
    some { bytes := b, size_eq := hb }
  else
    none

structure CryptoOracle (Point : Type) where
  scalarFromBytes : ByteArray → Option RistrettoScalar
  challengeScalarFromMsg : ByteArray → Option RistrettoScalar
  hashToPointBase : Point
  pointMul : Point → RistrettoScalar → Point
  pointAdd : Point → Point → Point
  pointEq : Point → Point → Prop
  pointDecompress : CompressedRistretto32 → Option Point
  pubkeyToPoint : CompressedRistretto32 → Option Point

structure AptosAddressBcs (Address : Type) where
  toBytes : Address → ByteArray

structure AptosAddress32 where
  bytes : ByteArray
  size_eq : bytes.size = 32

def aptosAddress32Bcs : AptosAddressBcs AptosAddress32 where
  toBytes a := a.bytes

def mkRegistrationInputs {Address : Type} (bcs : AptosAddressBcs Address)
    (chainId : UInt8) (sender contract token : Address) (ekBytes commitmentRBytes : ByteArray) :
    RegistrationFiatShamirInputs where
  chainId := chainId
  senderBcs := bcs.toBytes sender
  contractBcs := bcs.toBytes contract
  tokenBcs := bcs.toBytes token
  ekBytes := ekBytes
  commitmentRBytes := commitmentRBytes

abbrev mkRegistrationInputs32 :=
  @mkRegistrationInputs AptosAddress32 aptosAddress32Bcs

def verifyRegistrationProofProp {Point : Type} (C : CryptoOracle Point)
    (i : RegistrationFiatShamirInputs) (responseBytes : ByteArray) : Prop :=
  match C.scalarFromBytes responseBytes,
    compressed32? i.commitmentRBytes,
    compressed32? i.ekBytes with
  | some s, some rComm, some ekComm =>
      match C.pointDecompress rComm, C.pubkeyToPoint ekComm,
        C.challengeScalarFromMsg (registrationFiatShamirMsg i) with
      | some rhs, some ek, some e =>
          let H := C.hashToPointBase
          let lhs := C.pointAdd (C.pointMul H s) (C.pointMul ek e)
          C.pointEq lhs rhs
      | _, _, _ => False
  | _, _, _ => False

theorem verifyRegistrationProofProp_eq {Point : Type} (C : CryptoOracle Point)
    (i : RegistrationFiatShamirInputs) (responseBytes : ByteArray)
    (s : RistrettoScalar) (rComm ekComm : CompressedRistretto32)
    (rhs ek : Point) (e : RistrettoScalar)
    (hs : C.scalarFromBytes responseBytes = some s)
    (hr : compressed32? i.commitmentRBytes = some rComm)
    (hek : compressed32? i.ekBytes = some ekComm)
    (hR : C.pointDecompress rComm = some rhs)
    (hek2 : C.pubkeyToPoint ekComm = some ek)
    (he : C.challengeScalarFromMsg (registrationFiatShamirMsg i) = some e) :
    verifyRegistrationProofProp C i responseBytes ↔
      C.pointEq
        (C.pointAdd (C.pointMul C.hashToPointBase s) (C.pointMul ek e)) rhs := by
  simp [verifyRegistrationProofProp, hs, hr, hek, hR, hek2, he]

def registrationChallengeScalarMove (msg : ByteArray) : Option RistrettoScalar :=
  scalarUniformFrom64Bytes (taggedHash fiatShamirRegistrationDst msg)

theorem registrationChallengeScalarMove_eq_uniform_tagged (msg : ByteArray) :
    registrationChallengeScalarMove msg =
      scalarUniformFrom64Bytes (taggedHash fiatShamirRegistrationDst msg) :=
  rfl

theorem verifyRegistrationProofProp_challenge_congr {Point : Type}
    (C C' : CryptoOracle Point) (i : RegistrationFiatShamirInputs) (responseBytes : ByteArray)
    (hch : ∀ msg, C.challengeScalarFromMsg msg = C'.challengeScalarFromMsg msg)
    (hrest :
      C.scalarFromBytes = C'.scalarFromBytes ∧
        C.hashToPointBase = C'.hashToPointBase ∧
          C.pointMul = C'.pointMul ∧
            C.pointAdd = C'.pointAdd ∧
              C.pointEq = C'.pointEq ∧
                C.pointDecompress = C'.pointDecompress ∧ C.pubkeyToPoint = C'.pubkeyToPoint) :
    verifyRegistrationProofProp C i responseBytes ↔
      verifyRegistrationProofProp C' i responseBytes := by
  rcases hrest with
    ⟨hs, hH, hmul, hadd, heq, hdec, hpk⟩
  simp [verifyRegistrationProofProp, hs, hH, hmul, hadd, heq, hdec, hpk,
    hch (registrationFiatShamirMsg i)]

end RegistrationVerify
