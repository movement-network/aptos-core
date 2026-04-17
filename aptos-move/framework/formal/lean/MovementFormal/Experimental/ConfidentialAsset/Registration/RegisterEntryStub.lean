import MovementFormal.Experimental.ConfidentialAsset.Registration.FunctionalSim
import MovementFormal.Experimental.ConfidentialAsset.Registration.Refinement

/-!
# L4: `register` entry-point specification stub

The Move `register` entry function (`confidential_asset.move`, lines 249–272):

```move
public entry fun register(
    sender: &signer,
    token: Object<Metadata>,
    ek: vector<u8>,
    registration_proof_commitment: vector<u8>,
    registration_proof_response: vector<u8>
) acquires FAController, FAConfig {
    let ek = twisted_elgamal::new_pubkey_from_bytes(ek).extract();
    let cid = (chain_id::get() as u8);
    let user = signer::address_of(sender);
    confidential_proof::verify_registration_proof(
        cid, user, @aptos_experimental, &ek, object::object_address(&token),
        registration_proof_commitment, registration_proof_response
    );
    register_internal(sender, token, ek);
}
```

## What this file captures

1. **Entry-point decomposition**: `register` = parse ek + verify proof + global move_to
2. **Verify-then-store property**: if `register` returns normally, the proof was accepted
3. **Global state mutation**: `register_internal` creates a `ConfidentialAssetStore` resource

## What this file does NOT capture (future work)

- Full bytecode transcription of `register` (needs signer/chain_id/object natives)
- `register_internal` body (needs `move_to`, `borrow_global`, FAConfig access)
- Abort conditions (ek parse failure, FAConfig checks, already registered)

## Refinement path

```
L4  register bytecode eval
  ↠  L3  registerEntrySpec (this file)
    ↠  L2  verify_registration_proof bytecode eval (BytecodeDifftestEval)
      ↠  L0  verifyRegistrationProofProp (VerifyMath)
```
-/

namespace MovementFormal.Experimental.ConfidentialAsset.Registration.RegisterEntryStub

open MovementFormal.MoveModel
open MovementFormal.MoveModel.Native.Registration
open MovementFormal.Experimental.ConfidentialAsset.Registration.FunctionalSim

/-! ## Global state model (simplified) -/

structure ConfidentialAssetStore where
  ekBytes : ByteArray

/-- Global resource state: maps (owner address, token address) → store. -/
def GlobalCAState := List (ByteArray × ByteArray × ConfidentialAssetStore)

/-! ## Entry-point functional specification

`registerEntrySpec` captures the essential behavior of the `register` function:
1. Parse ek from bytes (must be a valid 32-byte compressed pubkey)
2. Verify the registration proof (delegates to `verifyRegistrationBytecodeResult`)
3. Create the global resource (returns updated state) -/

inductive RegisterResult where
  | success (newStore : ConfidentialAssetStore)
  | verifyFailed
  | ekParseFailed
  | error

def registerEntrySpec (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token : ByteArray)
    (ekRawBytes : ByteArray) (commitmentBytes responseBytes : ByteArray)
    : RegisterResult :=
  if ekRawBytes.size ≠ 32 then .ekParseFailed
  else
    let ekMv := MoveValue.struct_ [.vector .u8 (ekRawBytes.toList.map .u8)]
    let args := [.u8 chainId, .address sender, .address contract, ekMv,
                 .address token,
                 .vector .u8 (commitmentBytes.toList.map .u8),
                 .vector .u8 (responseBytes.toList.map .u8)]
    match verifyRegistrationBytecodeResult o args with
    | .returned [] _ => .success { ekBytes := ekRawBytes }
    | .aborted _ => .verifyFailed
    | _ => .error

/-! ## Key property: verify-then-store

If `registerEntrySpec` succeeds, the embedded proof verification also succeeded. -/

theorem register_success_implies_verify_success (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekRaw commitBa respBa : ByteArray)
    (hreg : ∃ store, registerEntrySpec o chainId sender contract token ekRaw commitBa respBa =
            .success store) :
    ∃ ms, verifyRegistrationBytecodeResult o
      [.u8 chainId, .address sender, .address contract,
       .struct_ [.vector .u8 (ekRaw.toList.map .u8)],
       .address token,
       .vector .u8 (commitBa.toList.map .u8),
       .vector .u8 (respBa.toList.map .u8)] =
      .returned [] ms := by
  obtain ⟨store, hreg⟩ := hreg
  unfold registerEntrySpec at hreg
  by_cases hsize : ekRaw.size ≠ 32
  · simp [hsize] at hreg
  · simp only [hsize, ↓reduceIte] at hreg
    split at hreg
    · exact ⟨_, by assumption⟩
    · simp at hreg
    · simp at hreg

/-- The stored ek matches the input bytes. -/
theorem register_success_stores_ek (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekRaw commitBa respBa : ByteArray)
    (store : ConfidentialAssetStore)
    (hreg : registerEntrySpec o chainId sender contract token ekRaw commitBa respBa =
            .success store) :
    store.ekBytes = ekRaw := by
  unfold registerEntrySpec at hreg
  by_cases hsize : ekRaw.size ≠ 32
  · simp [hsize] at hreg
  · simp only [hsize, ↓reduceIte] at hreg
    split at hreg
    · injection hreg with hreg; exact hreg ▸ rfl
    · simp at hreg
    · simp at hreg

end MovementFormal.Experimental.ConfidentialAsset.Registration.RegisterEntryStub
