
<a id="0x1_confidential_proof"></a>

# Module `0x1::confidential_proof`

PAUSED: confidential assets are disabled on Movement; interface retained for upgrade compatibility only

Sigma and range proof verification for confidential assets.

Every public function and every entry function aborts with <code><a href="confidential_proof.md#0x1_confidential_proof_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code> (wrapped in
<code><a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a></code>). All structs are retained with identical names, abilities and field layout because the compatible upgrade policy refuses to
remove or change a published struct. No resource is published, no event is emitted and no state is changed.


-  [Struct `WithdrawalProof`](#0x1_confidential_proof_WithdrawalProof)
-  [Struct `TransferProof`](#0x1_confidential_proof_TransferProof)
-  [Struct `NormalizationProof`](#0x1_confidential_proof_NormalizationProof)
-  [Struct `RotationProof`](#0x1_confidential_proof_RotationProof)
-  [Struct `WithdrawalSigmaProofXs`](#0x1_confidential_proof_WithdrawalSigmaProofXs)
-  [Struct `WithdrawalSigmaProofAlphas`](#0x1_confidential_proof_WithdrawalSigmaProofAlphas)
-  [Struct `WithdrawalSigmaProofGammas`](#0x1_confidential_proof_WithdrawalSigmaProofGammas)
-  [Struct `WithdrawalSigmaProof`](#0x1_confidential_proof_WithdrawalSigmaProof)
-  [Struct `TransferSigmaProofXs`](#0x1_confidential_proof_TransferSigmaProofXs)
-  [Struct `TransferSigmaProofAlphas`](#0x1_confidential_proof_TransferSigmaProofAlphas)
-  [Struct `TransferSigmaProofGammas`](#0x1_confidential_proof_TransferSigmaProofGammas)
-  [Struct `TransferSigmaProof`](#0x1_confidential_proof_TransferSigmaProof)
-  [Struct `NormalizationSigmaProofXs`](#0x1_confidential_proof_NormalizationSigmaProofXs)
-  [Struct `NormalizationSigmaProofAlphas`](#0x1_confidential_proof_NormalizationSigmaProofAlphas)
-  [Struct `NormalizationSigmaProofGammas`](#0x1_confidential_proof_NormalizationSigmaProofGammas)
-  [Struct `NormalizationSigmaProof`](#0x1_confidential_proof_NormalizationSigmaProof)
-  [Struct `RotationSigmaProofXs`](#0x1_confidential_proof_RotationSigmaProofXs)
-  [Struct `RotationSigmaProofAlphas`](#0x1_confidential_proof_RotationSigmaProofAlphas)
-  [Struct `RotationSigmaProofGammas`](#0x1_confidential_proof_RotationSigmaProofGammas)
-  [Struct `RotationSigmaProof`](#0x1_confidential_proof_RotationSigmaProof)
-  [Constants](#@Constants_0)
-  [Function `verify_withdrawal_proof`](#0x1_confidential_proof_verify_withdrawal_proof)
-  [Function `verify_transfer_proof`](#0x1_confidential_proof_verify_transfer_proof)
-  [Function `verify_normalization_proof`](#0x1_confidential_proof_verify_normalization_proof)
-  [Function `verify_rotation_proof`](#0x1_confidential_proof_verify_rotation_proof)
-  [Function `deserialize_withdrawal_proof`](#0x1_confidential_proof_deserialize_withdrawal_proof)
-  [Function `deserialize_transfer_proof`](#0x1_confidential_proof_deserialize_transfer_proof)
-  [Function `deserialize_normalization_proof`](#0x1_confidential_proof_deserialize_normalization_proof)
-  [Function `deserialize_rotation_proof`](#0x1_confidential_proof_deserialize_rotation_proof)
-  [Function `get_fiat_shamir_withdrawal_sigma_dst`](#0x1_confidential_proof_get_fiat_shamir_withdrawal_sigma_dst)
-  [Function `get_fiat_shamir_transfer_sigma_dst`](#0x1_confidential_proof_get_fiat_shamir_transfer_sigma_dst)
-  [Function `get_fiat_shamir_normalization_sigma_dst`](#0x1_confidential_proof_get_fiat_shamir_normalization_sigma_dst)
-  [Function `get_fiat_shamir_rotation_sigma_dst`](#0x1_confidential_proof_get_fiat_shamir_rotation_sigma_dst)
-  [Function `get_fiat_shamir_registration_sigma_dst`](#0x1_confidential_proof_get_fiat_shamir_registration_sigma_dst)
-  [Function `get_bulletproofs_dst`](#0x1_confidential_proof_get_bulletproofs_dst)
-  [Function `get_bulletproofs_num_bits`](#0x1_confidential_proof_get_bulletproofs_num_bits)


<pre><code><b>use</b> <a href="confidential_balance.md#0x1_confidential_balance">0x1::confidential_balance</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error">0x1::error</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option">0x1::option</a>;
<b>use</b> <a href="../../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255">0x1::ristretto255</a>;
<b>use</b> <a href="../../aptos-stdlib/doc/ristretto255_bulletproofs.md#0x1_ristretto255_bulletproofs">0x1::ristretto255_bulletproofs</a>;
<b>use</b> <a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal">0x1::ristretto255_twisted_elgamal</a>;
</code></pre>



<a id="0x1_confidential_proof_WithdrawalProof"></a>

## Struct `WithdrawalProof`

Represents the proof structure for validating a withdrawal operation.


<pre><code><b>struct</b> <a href="confidential_proof.md#0x1_confidential_proof_WithdrawalProof">WithdrawalProof</a> <b>has</b> drop
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>sigma_proof: <a href="confidential_proof.md#0x1_confidential_proof_WithdrawalSigmaProof">confidential_proof::WithdrawalSigmaProof</a></code>
</dt>
<dd>
 Sigma proof ensuring that the withdrawal operation maintains balance integrity.
</dd>
<dt>
<code>zkrp_new_balance: <a href="../../aptos-stdlib/doc/ristretto255_bulletproofs.md#0x1_ristretto255_bulletproofs_RangeProof">ristretto255_bulletproofs::RangeProof</a></code>
</dt>
<dd>
 Range proof ensuring that the resulting balance chunks are normalized (i.e., within the 16-bit limit).
</dd>
</dl>


</details>

<a id="0x1_confidential_proof_TransferProof"></a>

## Struct `TransferProof`

Represents the proof structure for validating a transfer operation.


<pre><code><b>struct</b> <a href="confidential_proof.md#0x1_confidential_proof_TransferProof">TransferProof</a> <b>has</b> drop
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>sigma_proof: <a href="confidential_proof.md#0x1_confidential_proof_TransferSigmaProof">confidential_proof::TransferSigmaProof</a></code>
</dt>
<dd>
 Sigma proof ensuring that the transfer operation maintains balance integrity and correctness.
</dd>
<dt>
<code>zkrp_new_balance: <a href="../../aptos-stdlib/doc/ristretto255_bulletproofs.md#0x1_ristretto255_bulletproofs_RangeProof">ristretto255_bulletproofs::RangeProof</a></code>
</dt>
<dd>
 Range proof ensuring that the resulting balance chunks for the sender are normalized (i.e., within the 16-bit limit).
</dd>
<dt>
<code>zkrp_transfer_amount: <a href="../../aptos-stdlib/doc/ristretto255_bulletproofs.md#0x1_ristretto255_bulletproofs_RangeProof">ristretto255_bulletproofs::RangeProof</a></code>
</dt>
<dd>
 Range proof ensuring that the transferred amount chunks are normalized (i.e., within the 16-bit limit).
</dd>
</dl>


</details>

<a id="0x1_confidential_proof_NormalizationProof"></a>

## Struct `NormalizationProof`

Represents the proof structure for validating a normalization operation.


<pre><code><b>struct</b> <a href="confidential_proof.md#0x1_confidential_proof_NormalizationProof">NormalizationProof</a> <b>has</b> drop
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>sigma_proof: <a href="confidential_proof.md#0x1_confidential_proof_NormalizationSigmaProof">confidential_proof::NormalizationSigmaProof</a></code>
</dt>
<dd>
 Sigma proof ensuring that the normalization operation maintains balance integrity.
</dd>
<dt>
<code>zkrp_new_balance: <a href="../../aptos-stdlib/doc/ristretto255_bulletproofs.md#0x1_ristretto255_bulletproofs_RangeProof">ristretto255_bulletproofs::RangeProof</a></code>
</dt>
<dd>
 Range proof ensuring that the resulting balance chunks are normalized (i.e., within the 16-bit limit).
</dd>
</dl>


</details>

<a id="0x1_confidential_proof_RotationProof"></a>

## Struct `RotationProof`

Represents the proof structure for validating a key rotation operation.


<pre><code><b>struct</b> <a href="confidential_proof.md#0x1_confidential_proof_RotationProof">RotationProof</a> <b>has</b> drop
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>sigma_proof: <a href="confidential_proof.md#0x1_confidential_proof_RotationSigmaProof">confidential_proof::RotationSigmaProof</a></code>
</dt>
<dd>
 Sigma proof ensuring that the key rotation operation preserves balance integrity.
</dd>
<dt>
<code>zkrp_new_balance: <a href="../../aptos-stdlib/doc/ristretto255_bulletproofs.md#0x1_ristretto255_bulletproofs_RangeProof">ristretto255_bulletproofs::RangeProof</a></code>
</dt>
<dd>
 Range proof ensuring that the resulting balance chunks after key rotation are normalized (i.e., within the 16-bit limit).
</dd>
</dl>


</details>

<a id="0x1_confidential_proof_WithdrawalSigmaProofXs"></a>

## Struct `WithdrawalSigmaProofXs`



<pre><code><b>struct</b> <a href="confidential_proof.md#0x1_confidential_proof_WithdrawalSigmaProofXs">WithdrawalSigmaProofXs</a> <b>has</b> drop
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>x1: <a href="../../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255_CompressedRistretto">ristretto255::CompressedRistretto</a></code>
</dt>
<dd>

</dd>
<dt>
<code>x2: <a href="../../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255_CompressedRistretto">ristretto255::CompressedRistretto</a></code>
</dt>
<dd>

</dd>
<dt>
<code>x3s: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255_CompressedRistretto">ristretto255::CompressedRistretto</a>&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>x4s: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255_CompressedRistretto">ristretto255::CompressedRistretto</a>&gt;</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_confidential_proof_WithdrawalSigmaProofAlphas"></a>

## Struct `WithdrawalSigmaProofAlphas`



<pre><code><b>struct</b> <a href="confidential_proof.md#0x1_confidential_proof_WithdrawalSigmaProofAlphas">WithdrawalSigmaProofAlphas</a> <b>has</b> drop
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>a1s: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255_Scalar">ristretto255::Scalar</a>&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>a2: <a href="../../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255_Scalar">ristretto255::Scalar</a></code>
</dt>
<dd>

</dd>
<dt>
<code>a3: <a href="../../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255_Scalar">ristretto255::Scalar</a></code>
</dt>
<dd>

</dd>
<dt>
<code>a4s: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255_Scalar">ristretto255::Scalar</a>&gt;</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_confidential_proof_WithdrawalSigmaProofGammas"></a>

## Struct `WithdrawalSigmaProofGammas`



<pre><code><b>struct</b> <a href="confidential_proof.md#0x1_confidential_proof_WithdrawalSigmaProofGammas">WithdrawalSigmaProofGammas</a> <b>has</b> drop
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>g1: <a href="../../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255_Scalar">ristretto255::Scalar</a></code>
</dt>
<dd>

</dd>
<dt>
<code>g2: <a href="../../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255_Scalar">ristretto255::Scalar</a></code>
</dt>
<dd>

</dd>
<dt>
<code>g3s: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255_Scalar">ristretto255::Scalar</a>&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>g4s: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255_Scalar">ristretto255::Scalar</a>&gt;</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_confidential_proof_WithdrawalSigmaProof"></a>

## Struct `WithdrawalSigmaProof`



<pre><code><b>struct</b> <a href="confidential_proof.md#0x1_confidential_proof_WithdrawalSigmaProof">WithdrawalSigmaProof</a> <b>has</b> drop
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>alphas: <a href="confidential_proof.md#0x1_confidential_proof_WithdrawalSigmaProofAlphas">confidential_proof::WithdrawalSigmaProofAlphas</a></code>
</dt>
<dd>

</dd>
<dt>
<code>xs: <a href="confidential_proof.md#0x1_confidential_proof_WithdrawalSigmaProofXs">confidential_proof::WithdrawalSigmaProofXs</a></code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_confidential_proof_TransferSigmaProofXs"></a>

## Struct `TransferSigmaProofXs`



<pre><code><b>struct</b> <a href="confidential_proof.md#0x1_confidential_proof_TransferSigmaProofXs">TransferSigmaProofXs</a> <b>has</b> drop
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>x1: <a href="../../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255_CompressedRistretto">ristretto255::CompressedRistretto</a></code>
</dt>
<dd>

</dd>
<dt>
<code>x2s: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255_CompressedRistretto">ristretto255::CompressedRistretto</a>&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>x3s: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255_CompressedRistretto">ristretto255::CompressedRistretto</a>&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>x4s: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255_CompressedRistretto">ristretto255::CompressedRistretto</a>&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>x5: <a href="../../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255_CompressedRistretto">ristretto255::CompressedRistretto</a></code>
</dt>
<dd>

</dd>
<dt>
<code>x6s: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255_CompressedRistretto">ristretto255::CompressedRistretto</a>&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>x7s: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255_CompressedRistretto">ristretto255::CompressedRistretto</a>&gt;&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>x8s: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255_CompressedRistretto">ristretto255::CompressedRistretto</a>&gt;</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_confidential_proof_TransferSigmaProofAlphas"></a>

## Struct `TransferSigmaProofAlphas`



<pre><code><b>struct</b> <a href="confidential_proof.md#0x1_confidential_proof_TransferSigmaProofAlphas">TransferSigmaProofAlphas</a> <b>has</b> drop
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>a1s: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255_Scalar">ristretto255::Scalar</a>&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>a2: <a href="../../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255_Scalar">ristretto255::Scalar</a></code>
</dt>
<dd>

</dd>
<dt>
<code>a3s: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255_Scalar">ristretto255::Scalar</a>&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>a4s: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255_Scalar">ristretto255::Scalar</a>&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>a5: <a href="../../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255_Scalar">ristretto255::Scalar</a></code>
</dt>
<dd>

</dd>
<dt>
<code>a6s: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255_Scalar">ristretto255::Scalar</a>&gt;</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_confidential_proof_TransferSigmaProofGammas"></a>

## Struct `TransferSigmaProofGammas`



<pre><code><b>struct</b> <a href="confidential_proof.md#0x1_confidential_proof_TransferSigmaProofGammas">TransferSigmaProofGammas</a> <b>has</b> drop
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>g1: <a href="../../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255_Scalar">ristretto255::Scalar</a></code>
</dt>
<dd>

</dd>
<dt>
<code>g2s: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255_Scalar">ristretto255::Scalar</a>&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>g3s: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255_Scalar">ristretto255::Scalar</a>&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>g4s: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255_Scalar">ristretto255::Scalar</a>&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>g5: <a href="../../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255_Scalar">ristretto255::Scalar</a></code>
</dt>
<dd>

</dd>
<dt>
<code>g6s: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255_Scalar">ristretto255::Scalar</a>&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>g7s: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255_Scalar">ristretto255::Scalar</a>&gt;&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>g8s: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255_Scalar">ristretto255::Scalar</a>&gt;</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_confidential_proof_TransferSigmaProof"></a>

## Struct `TransferSigmaProof`



<pre><code><b>struct</b> <a href="confidential_proof.md#0x1_confidential_proof_TransferSigmaProof">TransferSigmaProof</a> <b>has</b> drop
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>alphas: <a href="confidential_proof.md#0x1_confidential_proof_TransferSigmaProofAlphas">confidential_proof::TransferSigmaProofAlphas</a></code>
</dt>
<dd>

</dd>
<dt>
<code>xs: <a href="confidential_proof.md#0x1_confidential_proof_TransferSigmaProofXs">confidential_proof::TransferSigmaProofXs</a></code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_confidential_proof_NormalizationSigmaProofXs"></a>

## Struct `NormalizationSigmaProofXs`



<pre><code><b>struct</b> <a href="confidential_proof.md#0x1_confidential_proof_NormalizationSigmaProofXs">NormalizationSigmaProofXs</a> <b>has</b> drop
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>x1: <a href="../../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255_CompressedRistretto">ristretto255::CompressedRistretto</a></code>
</dt>
<dd>

</dd>
<dt>
<code>x2: <a href="../../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255_CompressedRistretto">ristretto255::CompressedRistretto</a></code>
</dt>
<dd>

</dd>
<dt>
<code>x3s: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255_CompressedRistretto">ristretto255::CompressedRistretto</a>&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>x4s: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255_CompressedRistretto">ristretto255::CompressedRistretto</a>&gt;</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_confidential_proof_NormalizationSigmaProofAlphas"></a>

## Struct `NormalizationSigmaProofAlphas`



<pre><code><b>struct</b> <a href="confidential_proof.md#0x1_confidential_proof_NormalizationSigmaProofAlphas">NormalizationSigmaProofAlphas</a> <b>has</b> drop
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>a1s: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255_Scalar">ristretto255::Scalar</a>&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>a2: <a href="../../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255_Scalar">ristretto255::Scalar</a></code>
</dt>
<dd>

</dd>
<dt>
<code>a3: <a href="../../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255_Scalar">ristretto255::Scalar</a></code>
</dt>
<dd>

</dd>
<dt>
<code>a4s: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255_Scalar">ristretto255::Scalar</a>&gt;</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_confidential_proof_NormalizationSigmaProofGammas"></a>

## Struct `NormalizationSigmaProofGammas`



<pre><code><b>struct</b> <a href="confidential_proof.md#0x1_confidential_proof_NormalizationSigmaProofGammas">NormalizationSigmaProofGammas</a> <b>has</b> drop
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>g1: <a href="../../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255_Scalar">ristretto255::Scalar</a></code>
</dt>
<dd>

</dd>
<dt>
<code>g2: <a href="../../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255_Scalar">ristretto255::Scalar</a></code>
</dt>
<dd>

</dd>
<dt>
<code>g3s: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255_Scalar">ristretto255::Scalar</a>&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>g4s: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255_Scalar">ristretto255::Scalar</a>&gt;</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_confidential_proof_NormalizationSigmaProof"></a>

## Struct `NormalizationSigmaProof`



<pre><code><b>struct</b> <a href="confidential_proof.md#0x1_confidential_proof_NormalizationSigmaProof">NormalizationSigmaProof</a> <b>has</b> drop
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>alphas: <a href="confidential_proof.md#0x1_confidential_proof_NormalizationSigmaProofAlphas">confidential_proof::NormalizationSigmaProofAlphas</a></code>
</dt>
<dd>

</dd>
<dt>
<code>xs: <a href="confidential_proof.md#0x1_confidential_proof_NormalizationSigmaProofXs">confidential_proof::NormalizationSigmaProofXs</a></code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_confidential_proof_RotationSigmaProofXs"></a>

## Struct `RotationSigmaProofXs`



<pre><code><b>struct</b> <a href="confidential_proof.md#0x1_confidential_proof_RotationSigmaProofXs">RotationSigmaProofXs</a> <b>has</b> drop
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>x1: <a href="../../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255_CompressedRistretto">ristretto255::CompressedRistretto</a></code>
</dt>
<dd>

</dd>
<dt>
<code>x2: <a href="../../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255_CompressedRistretto">ristretto255::CompressedRistretto</a></code>
</dt>
<dd>

</dd>
<dt>
<code>x3: <a href="../../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255_CompressedRistretto">ristretto255::CompressedRistretto</a></code>
</dt>
<dd>

</dd>
<dt>
<code>x4s: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255_CompressedRistretto">ristretto255::CompressedRistretto</a>&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>x5s: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255_CompressedRistretto">ristretto255::CompressedRistretto</a>&gt;</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_confidential_proof_RotationSigmaProofAlphas"></a>

## Struct `RotationSigmaProofAlphas`



<pre><code><b>struct</b> <a href="confidential_proof.md#0x1_confidential_proof_RotationSigmaProofAlphas">RotationSigmaProofAlphas</a> <b>has</b> drop
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>a1s: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255_Scalar">ristretto255::Scalar</a>&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>a2: <a href="../../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255_Scalar">ristretto255::Scalar</a></code>
</dt>
<dd>

</dd>
<dt>
<code>a3: <a href="../../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255_Scalar">ristretto255::Scalar</a></code>
</dt>
<dd>

</dd>
<dt>
<code>a4: <a href="../../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255_Scalar">ristretto255::Scalar</a></code>
</dt>
<dd>

</dd>
<dt>
<code>a5s: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255_Scalar">ristretto255::Scalar</a>&gt;</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_confidential_proof_RotationSigmaProofGammas"></a>

## Struct `RotationSigmaProofGammas`



<pre><code><b>struct</b> <a href="confidential_proof.md#0x1_confidential_proof_RotationSigmaProofGammas">RotationSigmaProofGammas</a> <b>has</b> drop
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>g1: <a href="../../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255_Scalar">ristretto255::Scalar</a></code>
</dt>
<dd>

</dd>
<dt>
<code>g2: <a href="../../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255_Scalar">ristretto255::Scalar</a></code>
</dt>
<dd>

</dd>
<dt>
<code>g3: <a href="../../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255_Scalar">ristretto255::Scalar</a></code>
</dt>
<dd>

</dd>
<dt>
<code>g4s: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255_Scalar">ristretto255::Scalar</a>&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>g5s: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255_Scalar">ristretto255::Scalar</a>&gt;</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_confidential_proof_RotationSigmaProof"></a>

## Struct `RotationSigmaProof`



<pre><code><b>struct</b> <a href="confidential_proof.md#0x1_confidential_proof_RotationSigmaProof">RotationSigmaProof</a> <b>has</b> drop
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>alphas: <a href="confidential_proof.md#0x1_confidential_proof_RotationSigmaProofAlphas">confidential_proof::RotationSigmaProofAlphas</a></code>
</dt>
<dd>

</dd>
<dt>
<code>xs: <a href="confidential_proof.md#0x1_confidential_proof_RotationSigmaProofXs">confidential_proof::RotationSigmaProofXs</a></code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="@Constants_0"></a>

## Constants


<a id="0x1_confidential_proof_E_CONFIDENTIAL_ASSETS_PAUSED"></a>

Confidential assets are paused: every function in this module aborts.


<pre><code><b>const</b> <a href="confidential_proof.md#0x1_confidential_proof_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>: u64 = 1;
</code></pre>



<a id="0x1_confidential_proof_verify_withdrawal_proof"></a>

## Function `verify_withdrawal_proof`

Paused: always aborts with <code><a href="confidential_proof.md#0x1_confidential_proof_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code><b>public</b> <b>fun</b> <a href="confidential_proof.md#0x1_confidential_proof_verify_withdrawal_proof">verify_withdrawal_proof</a>(_chain_id: u8, _sender: <b>address</b>, _contract_address: <b>address</b>, _token_address: <b>address</b>, _ek: &<a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_CompressedPubkey">ristretto255_twisted_elgamal::CompressedPubkey</a>, _amount: u64, _current_balance: &<a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>, _new_balance: &<a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>, _proof: &<a href="confidential_proof.md#0x1_confidential_proof_WithdrawalProof">confidential_proof::WithdrawalProof</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_proof.md#0x1_confidential_proof_verify_withdrawal_proof">verify_withdrawal_proof</a>(
    _chain_id: u8,
    _sender: <b>address</b>,
    _contract_address: <b>address</b>,
    _token_address: <b>address</b>,
    _ek: &twisted_elgamal::CompressedPubkey,
    _amount: u64,
    _current_balance: &<a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>,
    _new_balance: &<a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>,
    _proof: &<a href="confidential_proof.md#0x1_confidential_proof_WithdrawalProof">WithdrawalProof</a>) {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="confidential_proof.md#0x1_confidential_proof_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_confidential_proof_verify_transfer_proof"></a>

## Function `verify_transfer_proof`

Paused: always aborts with <code><a href="confidential_proof.md#0x1_confidential_proof_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code><b>public</b> <b>fun</b> <a href="confidential_proof.md#0x1_confidential_proof_verify_transfer_proof">verify_transfer_proof</a>(_chain_id: u8, _sender: <b>address</b>, _contract_address: <b>address</b>, _token_address: <b>address</b>, _sender_ek: &<a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_CompressedPubkey">ristretto255_twisted_elgamal::CompressedPubkey</a>, _recipient_ek: &<a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_CompressedPubkey">ristretto255_twisted_elgamal::CompressedPubkey</a>, _current_balance: &<a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>, _new_balance: &<a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>, _sender_amount: &<a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>, _recipient_amount: &<a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>, _auditor_eks: &<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_CompressedPubkey">ristretto255_twisted_elgamal::CompressedPubkey</a>&gt;, _auditor_amounts: &<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>&gt;, _sender_auditor_hint: &<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, _proof: &<a href="confidential_proof.md#0x1_confidential_proof_TransferProof">confidential_proof::TransferProof</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_proof.md#0x1_confidential_proof_verify_transfer_proof">verify_transfer_proof</a>(
    _chain_id: u8,
    _sender: <b>address</b>,
    _contract_address: <b>address</b>,
    _token_address: <b>address</b>,
    _sender_ek: &twisted_elgamal::CompressedPubkey,
    _recipient_ek: &twisted_elgamal::CompressedPubkey,
    _current_balance: &<a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>,
    _new_balance: &<a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>,
    _sender_amount: &<a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>,
    _recipient_amount: &<a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>,
    _auditor_eks: &<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;twisted_elgamal::CompressedPubkey&gt;,
    _auditor_amounts: &<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>&gt;,
    _sender_auditor_hint: &<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    _proof: &<a href="confidential_proof.md#0x1_confidential_proof_TransferProof">TransferProof</a>) {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="confidential_proof.md#0x1_confidential_proof_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_confidential_proof_verify_normalization_proof"></a>

## Function `verify_normalization_proof`

Paused: always aborts with <code><a href="confidential_proof.md#0x1_confidential_proof_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code><b>public</b> <b>fun</b> <a href="confidential_proof.md#0x1_confidential_proof_verify_normalization_proof">verify_normalization_proof</a>(_chain_id: u8, _sender: <b>address</b>, _contract_address: <b>address</b>, _token_address: <b>address</b>, _ek: &<a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_CompressedPubkey">ristretto255_twisted_elgamal::CompressedPubkey</a>, _current_balance: &<a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>, _new_balance: &<a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>, _proof: &<a href="confidential_proof.md#0x1_confidential_proof_NormalizationProof">confidential_proof::NormalizationProof</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_proof.md#0x1_confidential_proof_verify_normalization_proof">verify_normalization_proof</a>(
    _chain_id: u8,
    _sender: <b>address</b>,
    _contract_address: <b>address</b>,
    _token_address: <b>address</b>,
    _ek: &twisted_elgamal::CompressedPubkey,
    _current_balance: &<a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>,
    _new_balance: &<a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>,
    _proof: &<a href="confidential_proof.md#0x1_confidential_proof_NormalizationProof">NormalizationProof</a>) {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="confidential_proof.md#0x1_confidential_proof_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_confidential_proof_verify_rotation_proof"></a>

## Function `verify_rotation_proof`

Paused: always aborts with <code><a href="confidential_proof.md#0x1_confidential_proof_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code><b>public</b> <b>fun</b> <a href="confidential_proof.md#0x1_confidential_proof_verify_rotation_proof">verify_rotation_proof</a>(_chain_id: u8, _sender: <b>address</b>, _contract_address: <b>address</b>, _token_address: <b>address</b>, _current_ek: &<a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_CompressedPubkey">ristretto255_twisted_elgamal::CompressedPubkey</a>, _new_ek: &<a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_CompressedPubkey">ristretto255_twisted_elgamal::CompressedPubkey</a>, _current_balance: &<a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>, _new_balance: &<a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>, _proof: &<a href="confidential_proof.md#0x1_confidential_proof_RotationProof">confidential_proof::RotationProof</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_proof.md#0x1_confidential_proof_verify_rotation_proof">verify_rotation_proof</a>(
    _chain_id: u8,
    _sender: <b>address</b>,
    _contract_address: <b>address</b>,
    _token_address: <b>address</b>,
    _current_ek: &twisted_elgamal::CompressedPubkey,
    _new_ek: &twisted_elgamal::CompressedPubkey,
    _current_balance: &<a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>,
    _new_balance: &<a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>,
    _proof: &<a href="confidential_proof.md#0x1_confidential_proof_RotationProof">RotationProof</a>) {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="confidential_proof.md#0x1_confidential_proof_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_confidential_proof_deserialize_withdrawal_proof"></a>

## Function `deserialize_withdrawal_proof`

Paused: always aborts with <code><a href="confidential_proof.md#0x1_confidential_proof_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code><b>public</b> <b>fun</b> <a href="confidential_proof.md#0x1_confidential_proof_deserialize_withdrawal_proof">deserialize_withdrawal_proof</a>(_sigma_proof_bytes: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, _zkrp_new_balance_bytes: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_Option">option::Option</a>&lt;<a href="confidential_proof.md#0x1_confidential_proof_WithdrawalProof">confidential_proof::WithdrawalProof</a>&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_proof.md#0x1_confidential_proof_deserialize_withdrawal_proof">deserialize_withdrawal_proof</a>(
    _sigma_proof_bytes: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    _zkrp_new_balance_bytes: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): Option&lt;<a href="confidential_proof.md#0x1_confidential_proof_WithdrawalProof">WithdrawalProof</a>&gt; {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="confidential_proof.md#0x1_confidential_proof_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_confidential_proof_deserialize_transfer_proof"></a>

## Function `deserialize_transfer_proof`

Paused: always aborts with <code><a href="confidential_proof.md#0x1_confidential_proof_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code><b>public</b> <b>fun</b> <a href="confidential_proof.md#0x1_confidential_proof_deserialize_transfer_proof">deserialize_transfer_proof</a>(_sigma_proof_bytes: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, _zkrp_new_balance_bytes: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, _zkrp_transfer_amount_bytes: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_Option">option::Option</a>&lt;<a href="confidential_proof.md#0x1_confidential_proof_TransferProof">confidential_proof::TransferProof</a>&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_proof.md#0x1_confidential_proof_deserialize_transfer_proof">deserialize_transfer_proof</a>(
    _sigma_proof_bytes: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    _zkrp_new_balance_bytes: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    _zkrp_transfer_amount_bytes: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): Option&lt;<a href="confidential_proof.md#0x1_confidential_proof_TransferProof">TransferProof</a>&gt; {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="confidential_proof.md#0x1_confidential_proof_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_confidential_proof_deserialize_normalization_proof"></a>

## Function `deserialize_normalization_proof`

Paused: always aborts with <code><a href="confidential_proof.md#0x1_confidential_proof_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code><b>public</b> <b>fun</b> <a href="confidential_proof.md#0x1_confidential_proof_deserialize_normalization_proof">deserialize_normalization_proof</a>(_sigma_proof_bytes: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, _zkrp_new_balance_bytes: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_Option">option::Option</a>&lt;<a href="confidential_proof.md#0x1_confidential_proof_NormalizationProof">confidential_proof::NormalizationProof</a>&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_proof.md#0x1_confidential_proof_deserialize_normalization_proof">deserialize_normalization_proof</a>(
    _sigma_proof_bytes: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    _zkrp_new_balance_bytes: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): Option&lt;<a href="confidential_proof.md#0x1_confidential_proof_NormalizationProof">NormalizationProof</a>&gt; {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="confidential_proof.md#0x1_confidential_proof_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_confidential_proof_deserialize_rotation_proof"></a>

## Function `deserialize_rotation_proof`

Paused: always aborts with <code><a href="confidential_proof.md#0x1_confidential_proof_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code><b>public</b> <b>fun</b> <a href="confidential_proof.md#0x1_confidential_proof_deserialize_rotation_proof">deserialize_rotation_proof</a>(_sigma_proof_bytes: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, _zkrp_new_balance_bytes: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_Option">option::Option</a>&lt;<a href="confidential_proof.md#0x1_confidential_proof_RotationProof">confidential_proof::RotationProof</a>&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_proof.md#0x1_confidential_proof_deserialize_rotation_proof">deserialize_rotation_proof</a>(
    _sigma_proof_bytes: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    _zkrp_new_balance_bytes: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): Option&lt;<a href="confidential_proof.md#0x1_confidential_proof_RotationProof">RotationProof</a>&gt; {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="confidential_proof.md#0x1_confidential_proof_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_confidential_proof_get_fiat_shamir_withdrawal_sigma_dst"></a>

## Function `get_fiat_shamir_withdrawal_sigma_dst`

Paused: always aborts with <code><a href="confidential_proof.md#0x1_confidential_proof_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="confidential_proof.md#0x1_confidential_proof_get_fiat_shamir_withdrawal_sigma_dst">get_fiat_shamir_withdrawal_sigma_dst</a>(): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_proof.md#0x1_confidential_proof_get_fiat_shamir_withdrawal_sigma_dst">get_fiat_shamir_withdrawal_sigma_dst</a>(): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt; {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="confidential_proof.md#0x1_confidential_proof_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_confidential_proof_get_fiat_shamir_transfer_sigma_dst"></a>

## Function `get_fiat_shamir_transfer_sigma_dst`

Paused: always aborts with <code><a href="confidential_proof.md#0x1_confidential_proof_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="confidential_proof.md#0x1_confidential_proof_get_fiat_shamir_transfer_sigma_dst">get_fiat_shamir_transfer_sigma_dst</a>(): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_proof.md#0x1_confidential_proof_get_fiat_shamir_transfer_sigma_dst">get_fiat_shamir_transfer_sigma_dst</a>(): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt; {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="confidential_proof.md#0x1_confidential_proof_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_confidential_proof_get_fiat_shamir_normalization_sigma_dst"></a>

## Function `get_fiat_shamir_normalization_sigma_dst`

Paused: always aborts with <code><a href="confidential_proof.md#0x1_confidential_proof_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="confidential_proof.md#0x1_confidential_proof_get_fiat_shamir_normalization_sigma_dst">get_fiat_shamir_normalization_sigma_dst</a>(): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_proof.md#0x1_confidential_proof_get_fiat_shamir_normalization_sigma_dst">get_fiat_shamir_normalization_sigma_dst</a>(): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt; {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="confidential_proof.md#0x1_confidential_proof_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_confidential_proof_get_fiat_shamir_rotation_sigma_dst"></a>

## Function `get_fiat_shamir_rotation_sigma_dst`

Paused: always aborts with <code><a href="confidential_proof.md#0x1_confidential_proof_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="confidential_proof.md#0x1_confidential_proof_get_fiat_shamir_rotation_sigma_dst">get_fiat_shamir_rotation_sigma_dst</a>(): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_proof.md#0x1_confidential_proof_get_fiat_shamir_rotation_sigma_dst">get_fiat_shamir_rotation_sigma_dst</a>(): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt; {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="confidential_proof.md#0x1_confidential_proof_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_confidential_proof_get_fiat_shamir_registration_sigma_dst"></a>

## Function `get_fiat_shamir_registration_sigma_dst`

Paused: always aborts with <code><a href="confidential_proof.md#0x1_confidential_proof_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="confidential_proof.md#0x1_confidential_proof_get_fiat_shamir_registration_sigma_dst">get_fiat_shamir_registration_sigma_dst</a>(): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_proof.md#0x1_confidential_proof_get_fiat_shamir_registration_sigma_dst">get_fiat_shamir_registration_sigma_dst</a>(): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt; {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="confidential_proof.md#0x1_confidential_proof_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_confidential_proof_get_bulletproofs_dst"></a>

## Function `get_bulletproofs_dst`

Paused: always aborts with <code><a href="confidential_proof.md#0x1_confidential_proof_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="confidential_proof.md#0x1_confidential_proof_get_bulletproofs_dst">get_bulletproofs_dst</a>(): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_proof.md#0x1_confidential_proof_get_bulletproofs_dst">get_bulletproofs_dst</a>(): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt; {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="confidential_proof.md#0x1_confidential_proof_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_confidential_proof_get_bulletproofs_num_bits"></a>

## Function `get_bulletproofs_num_bits`

Paused: always aborts with <code><a href="confidential_proof.md#0x1_confidential_proof_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="confidential_proof.md#0x1_confidential_proof_get_bulletproofs_num_bits">get_bulletproofs_num_bits</a>(): u64
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_proof.md#0x1_confidential_proof_get_bulletproofs_num_bits">get_bulletproofs_num_bits</a>(): u64 {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="confidential_proof.md#0x1_confidential_proof_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>


[move-book]: https://aptos.dev/move/book/SUMMARY
