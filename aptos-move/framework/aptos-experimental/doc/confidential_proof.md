
<a id="0x7_confidential_proof"></a>

# Module `0x7::confidential_proof`

The <code><a href="confidential_proof.md#0x7_confidential_proof">confidential_proof</a></code> module provides the infrastructure for verifying zero-knowledge proofs used in the Confidential Asset protocol.
These proofs ensure correctness for operations such as <code>confidential_transfer</code>, <code>withdraw</code>, <code>rotate_encryption_key</code>, and <code>normalize</code>.


-  [Struct `WithdrawalProof`](#0x7_confidential_proof_WithdrawalProof)
-  [Struct `TransferProof`](#0x7_confidential_proof_TransferProof)
-  [Struct `NormalizationProof`](#0x7_confidential_proof_NormalizationProof)
-  [Struct `RotationProof`](#0x7_confidential_proof_RotationProof)
-  [Struct `WithdrawalSigmaProofXs`](#0x7_confidential_proof_WithdrawalSigmaProofXs)
-  [Struct `WithdrawalSigmaProofAlphas`](#0x7_confidential_proof_WithdrawalSigmaProofAlphas)
-  [Struct `WithdrawalSigmaProofGammas`](#0x7_confidential_proof_WithdrawalSigmaProofGammas)
-  [Struct `WithdrawalSigmaProof`](#0x7_confidential_proof_WithdrawalSigmaProof)
-  [Struct `TransferSigmaProofXs`](#0x7_confidential_proof_TransferSigmaProofXs)
-  [Struct `TransferSigmaProofAlphas`](#0x7_confidential_proof_TransferSigmaProofAlphas)
-  [Struct `TransferSigmaProofGammas`](#0x7_confidential_proof_TransferSigmaProofGammas)
-  [Struct `TransferSigmaProof`](#0x7_confidential_proof_TransferSigmaProof)
-  [Struct `NormalizationSigmaProofXs`](#0x7_confidential_proof_NormalizationSigmaProofXs)
-  [Struct `NormalizationSigmaProofAlphas`](#0x7_confidential_proof_NormalizationSigmaProofAlphas)
-  [Struct `NormalizationSigmaProofGammas`](#0x7_confidential_proof_NormalizationSigmaProofGammas)
-  [Struct `NormalizationSigmaProof`](#0x7_confidential_proof_NormalizationSigmaProof)
-  [Struct `RotationSigmaProofXs`](#0x7_confidential_proof_RotationSigmaProofXs)
-  [Struct `RotationSigmaProofAlphas`](#0x7_confidential_proof_RotationSigmaProofAlphas)
-  [Struct `RotationSigmaProofGammas`](#0x7_confidential_proof_RotationSigmaProofGammas)
-  [Struct `RotationSigmaProof`](#0x7_confidential_proof_RotationSigmaProof)
-  [Constants](#@Constants_0)
-  [Function `verify_registration_proof`](#0x7_confidential_proof_verify_registration_proof)
-  [Function `verify_withdrawal_proof`](#0x7_confidential_proof_verify_withdrawal_proof)
-  [Function `verify_transfer_proof`](#0x7_confidential_proof_verify_transfer_proof)
-  [Function `verify_normalization_proof`](#0x7_confidential_proof_verify_normalization_proof)
-  [Function `verify_rotation_proof`](#0x7_confidential_proof_verify_rotation_proof)
-  [Function `auditors_count_in_transfer_proof`](#0x7_confidential_proof_auditors_count_in_transfer_proof)
-  [Function `transfer_proof_ek_volun_auds_flat_bytes`](#0x7_confidential_proof_transfer_proof_ek_volun_auds_flat_bytes)
-  [Function `deserialize_withdrawal_proof`](#0x7_confidential_proof_deserialize_withdrawal_proof)
-  [Function `deserialize_transfer_proof`](#0x7_confidential_proof_deserialize_transfer_proof)
-  [Function `deserialize_normalization_proof`](#0x7_confidential_proof_deserialize_normalization_proof)
-  [Function `deserialize_rotation_proof`](#0x7_confidential_proof_deserialize_rotation_proof)
-  [Function `get_fiat_shamir_withdrawal_sigma_dst`](#0x7_confidential_proof_get_fiat_shamir_withdrawal_sigma_dst)
-  [Function `get_fiat_shamir_transfer_sigma_dst`](#0x7_confidential_proof_get_fiat_shamir_transfer_sigma_dst)
-  [Function `get_fiat_shamir_normalization_sigma_dst`](#0x7_confidential_proof_get_fiat_shamir_normalization_sigma_dst)
-  [Function `get_fiat_shamir_rotation_sigma_dst`](#0x7_confidential_proof_get_fiat_shamir_rotation_sigma_dst)
-  [Function `get_fiat_shamir_registration_sigma_dst`](#0x7_confidential_proof_get_fiat_shamir_registration_sigma_dst)
-  [Function `get_bulletproofs_dst`](#0x7_confidential_proof_get_bulletproofs_dst)
-  [Function `get_bulletproofs_num_bits`](#0x7_confidential_proof_get_bulletproofs_num_bits)


<pre><code><b>use</b> <a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/bcs.md#0x1_bcs">0x1::bcs</a>;
<b>use</b> <a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error">0x1::error</a>;
<b>use</b> <a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option">0x1::option</a>;
<b>use</b> <a href="../../aptos-framework/../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255">0x1::ristretto255</a>;
<b>use</b> <a href="../../aptos-framework/../aptos-stdlib/doc/ristretto255_bulletproofs.md#0x1_ristretto255_bulletproofs">0x1::ristretto255_bulletproofs</a>;
<b>use</b> <a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">0x1::vector</a>;
<b>use</b> <a href="confidential_balance.md#0x7_confidential_balance">0x7::confidential_balance</a>;
<b>use</b> <a href="ristretto255_twisted_elgamal.md#0x7_ristretto255_twisted_elgamal">0x7::ristretto255_twisted_elgamal</a>;
</code></pre>



<a id="0x7_confidential_proof_WithdrawalProof"></a>

## Struct `WithdrawalProof`

Represents the proof structure for validating a withdrawal operation.


<pre><code><b>struct</b> <a href="confidential_proof.md#0x7_confidential_proof_WithdrawalProof">WithdrawalProof</a> <b>has</b> drop
</code></pre>



<a id="0x7_confidential_proof_TransferProof"></a>

## Struct `TransferProof`

Represents the proof structure for validating a transfer operation.


<pre><code><b>struct</b> <a href="confidential_proof.md#0x7_confidential_proof_TransferProof">TransferProof</a> <b>has</b> drop
</code></pre>



<a id="0x7_confidential_proof_NormalizationProof"></a>

## Struct `NormalizationProof`

Represents the proof structure for validating a normalization operation.


<pre><code><b>struct</b> <a href="confidential_proof.md#0x7_confidential_proof_NormalizationProof">NormalizationProof</a> <b>has</b> drop
</code></pre>



<a id="0x7_confidential_proof_RotationProof"></a>

## Struct `RotationProof`

Represents the proof structure for validating a key rotation operation.


<pre><code><b>struct</b> <a href="confidential_proof.md#0x7_confidential_proof_RotationProof">RotationProof</a> <b>has</b> drop
</code></pre>



<a id="0x7_confidential_proof_WithdrawalSigmaProofXs"></a>

## Struct `WithdrawalSigmaProofXs`



<pre><code><b>struct</b> <a href="confidential_proof.md#0x7_confidential_proof_WithdrawalSigmaProofXs">WithdrawalSigmaProofXs</a> <b>has</b> drop
</code></pre>



<a id="0x7_confidential_proof_WithdrawalSigmaProofAlphas"></a>

## Struct `WithdrawalSigmaProofAlphas`



<pre><code><b>struct</b> <a href="confidential_proof.md#0x7_confidential_proof_WithdrawalSigmaProofAlphas">WithdrawalSigmaProofAlphas</a> <b>has</b> drop
</code></pre>



<a id="0x7_confidential_proof_WithdrawalSigmaProofGammas"></a>

## Struct `WithdrawalSigmaProofGammas`



<pre><code><b>struct</b> <a href="confidential_proof.md#0x7_confidential_proof_WithdrawalSigmaProofGammas">WithdrawalSigmaProofGammas</a> <b>has</b> drop
</code></pre>



<a id="0x7_confidential_proof_WithdrawalSigmaProof"></a>

## Struct `WithdrawalSigmaProof`



<pre><code><b>struct</b> <a href="confidential_proof.md#0x7_confidential_proof_WithdrawalSigmaProof">WithdrawalSigmaProof</a> <b>has</b> drop
</code></pre>



<a id="0x7_confidential_proof_TransferSigmaProofXs"></a>

## Struct `TransferSigmaProofXs`



<pre><code><b>struct</b> <a href="confidential_proof.md#0x7_confidential_proof_TransferSigmaProofXs">TransferSigmaProofXs</a> <b>has</b> drop
</code></pre>



<a id="0x7_confidential_proof_TransferSigmaProofAlphas"></a>

## Struct `TransferSigmaProofAlphas`



<pre><code><b>struct</b> <a href="confidential_proof.md#0x7_confidential_proof_TransferSigmaProofAlphas">TransferSigmaProofAlphas</a> <b>has</b> drop
</code></pre>



<a id="0x7_confidential_proof_TransferSigmaProofGammas"></a>

## Struct `TransferSigmaProofGammas`



<pre><code><b>struct</b> <a href="confidential_proof.md#0x7_confidential_proof_TransferSigmaProofGammas">TransferSigmaProofGammas</a> <b>has</b> drop
</code></pre>



<a id="0x7_confidential_proof_TransferSigmaProof"></a>

## Struct `TransferSigmaProof`



<pre><code><b>struct</b> <a href="confidential_proof.md#0x7_confidential_proof_TransferSigmaProof">TransferSigmaProof</a> <b>has</b> drop
</code></pre>



<a id="0x7_confidential_proof_NormalizationSigmaProofXs"></a>

## Struct `NormalizationSigmaProofXs`



<pre><code><b>struct</b> <a href="confidential_proof.md#0x7_confidential_proof_NormalizationSigmaProofXs">NormalizationSigmaProofXs</a> <b>has</b> drop
</code></pre>



<a id="0x7_confidential_proof_NormalizationSigmaProofAlphas"></a>

## Struct `NormalizationSigmaProofAlphas`



<pre><code><b>struct</b> <a href="confidential_proof.md#0x7_confidential_proof_NormalizationSigmaProofAlphas">NormalizationSigmaProofAlphas</a> <b>has</b> drop
</code></pre>



<a id="0x7_confidential_proof_NormalizationSigmaProofGammas"></a>

## Struct `NormalizationSigmaProofGammas`



<pre><code><b>struct</b> <a href="confidential_proof.md#0x7_confidential_proof_NormalizationSigmaProofGammas">NormalizationSigmaProofGammas</a> <b>has</b> drop
</code></pre>



<a id="0x7_confidential_proof_NormalizationSigmaProof"></a>

## Struct `NormalizationSigmaProof`



<pre><code><b>struct</b> <a href="confidential_proof.md#0x7_confidential_proof_NormalizationSigmaProof">NormalizationSigmaProof</a> <b>has</b> drop
</code></pre>



<a id="0x7_confidential_proof_RotationSigmaProofXs"></a>

## Struct `RotationSigmaProofXs`



<pre><code><b>struct</b> <a href="confidential_proof.md#0x7_confidential_proof_RotationSigmaProofXs">RotationSigmaProofXs</a> <b>has</b> drop
</code></pre>



<a id="0x7_confidential_proof_RotationSigmaProofAlphas"></a>

## Struct `RotationSigmaProofAlphas`



<pre><code><b>struct</b> <a href="confidential_proof.md#0x7_confidential_proof_RotationSigmaProofAlphas">RotationSigmaProofAlphas</a> <b>has</b> drop
</code></pre>



<a id="0x7_confidential_proof_RotationSigmaProofGammas"></a>

## Struct `RotationSigmaProofGammas`



<pre><code><b>struct</b> <a href="confidential_proof.md#0x7_confidential_proof_RotationSigmaProofGammas">RotationSigmaProofGammas</a> <b>has</b> drop
</code></pre>



<a id="0x7_confidential_proof_RotationSigmaProof"></a>

## Struct `RotationSigmaProof`



<pre><code><b>struct</b> <a href="confidential_proof.md#0x7_confidential_proof_RotationSigmaProof">RotationSigmaProof</a> <b>has</b> drop
</code></pre>



<a id="@Constants_0"></a>

## Constants


<a id="0x7_confidential_proof_BULLETPROOFS_DST"></a>



<pre><code><b>const</b> <a href="confidential_proof.md#0x7_confidential_proof_BULLETPROOFS_DST">BULLETPROOFS_DST</a>: <a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt; = [65, 112, 116, 111, 115, 67, 111, 110, 102, 105, 100, 101, 110, 116, 105, 97, 108, 65, 115, 115, 101, 116, 47, 66, 117, 108, 108, 101, 116, 112, 114, 111, 111, 102, 82, 97, 110, 103, 101, 80, 114, 111, 111, 102];
</code></pre>



<a id="0x7_confidential_proof_BULLETPROOFS_NUM_BITS"></a>



<pre><code><b>const</b> <a href="confidential_proof.md#0x7_confidential_proof_BULLETPROOFS_NUM_BITS">BULLETPROOFS_NUM_BITS</a>: u64 = 16;
</code></pre>



<a id="0x7_confidential_proof_ERANGE_PROOF_VERIFICATION_FAILED"></a>



<pre><code><b>const</b> <a href="confidential_proof.md#0x7_confidential_proof_ERANGE_PROOF_VERIFICATION_FAILED">ERANGE_PROOF_VERIFICATION_FAILED</a>: u64 = 2;
</code></pre>



<a id="0x7_confidential_proof_ESIGMA_PROTOCOL_VERIFY_FAILED"></a>



<pre><code><b>const</b> <a href="confidential_proof.md#0x7_confidential_proof_ESIGMA_PROTOCOL_VERIFY_FAILED">ESIGMA_PROTOCOL_VERIFY_FAILED</a>: u64 = 1;
</code></pre>



<a id="0x7_confidential_proof_FIAT_SHAMIR_NORMALIZATION_SIGMA_DST"></a>



<pre><code><b>const</b> <a href="confidential_proof.md#0x7_confidential_proof_FIAT_SHAMIR_NORMALIZATION_SIGMA_DST">FIAT_SHAMIR_NORMALIZATION_SIGMA_DST</a>: <a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt; = [77, 111, 118, 101, 109, 101, 110, 116, 67, 111, 110, 102, 105, 100, 101, 110, 116, 105, 97, 108, 65, 115, 115, 101, 116, 47, 78, 111, 114, 109, 97, 108, 105, 122, 97, 116, 105, 111, 110];
</code></pre>



<a id="0x7_confidential_proof_FIAT_SHAMIR_REGISTRATION_SIGMA_DST"></a>



<pre><code><b>const</b> <a href="confidential_proof.md#0x7_confidential_proof_FIAT_SHAMIR_REGISTRATION_SIGMA_DST">FIAT_SHAMIR_REGISTRATION_SIGMA_DST</a>: <a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt; = [77, 111, 118, 101, 109, 101, 110, 116, 67, 111, 110, 102, 105, 100, 101, 110, 116, 105, 97, 108, 65, 115, 115, 101, 116, 47, 82, 101, 103, 105, 115, 116, 114, 97, 116, 105, 111, 110];
</code></pre>



<a id="0x7_confidential_proof_FIAT_SHAMIR_ROTATION_SIGMA_DST"></a>



<pre><code><b>const</b> <a href="confidential_proof.md#0x7_confidential_proof_FIAT_SHAMIR_ROTATION_SIGMA_DST">FIAT_SHAMIR_ROTATION_SIGMA_DST</a>: <a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt; = [77, 111, 118, 101, 109, 101, 110, 116, 67, 111, 110, 102, 105, 100, 101, 110, 116, 105, 97, 108, 65, 115, 115, 101, 116, 47, 82, 111, 116, 97, 116, 105, 111, 110];
</code></pre>



<a id="0x7_confidential_proof_FIAT_SHAMIR_TRANSFER_SIGMA_DST"></a>



<pre><code><b>const</b> <a href="confidential_proof.md#0x7_confidential_proof_FIAT_SHAMIR_TRANSFER_SIGMA_DST">FIAT_SHAMIR_TRANSFER_SIGMA_DST</a>: <a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt; = [77, 111, 118, 101, 109, 101, 110, 116, 67, 111, 110, 102, 105, 100, 101, 110, 116, 105, 97, 108, 65, 115, 115, 101, 116, 47, 84, 114, 97, 110, 115, 102, 101, 114];
</code></pre>



<a id="0x7_confidential_proof_FIAT_SHAMIR_WITHDRAWAL_SIGMA_DST"></a>



<pre><code><b>const</b> <a href="confidential_proof.md#0x7_confidential_proof_FIAT_SHAMIR_WITHDRAWAL_SIGMA_DST">FIAT_SHAMIR_WITHDRAWAL_SIGMA_DST</a>: <a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt; = [77, 111, 118, 101, 109, 101, 110, 116, 67, 111, 110, 102, 105, 100, 101, 110, 116, 105, 97, 108, 65, 115, 115, 101, 116, 47, 87, 105, 116, 104, 100, 114, 97, 119, 97, 108];
</code></pre>



<a id="0x7_confidential_proof_verify_registration_proof"></a>

## Function `verify_registration_proof`

Verifies a registration proof (ZKPoK of decryption key).

Ensures the registrant knows the decryption key dk such that ek = dk^{-1} * H.
The proof is a Schnorr proof: verifier checks s * H + e * ek == R.


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="confidential_proof.md#0x7_confidential_proof_verify_registration_proof">verify_registration_proof</a>(<a href="../../aptos-framework/doc/chain_id.md#0x1_chain_id">chain_id</a>: u8, sender: <b>address</b>, contract_address: <b>address</b>, ek: &<a href="ristretto255_twisted_elgamal.md#0x7_ristretto255_twisted_elgamal_CompressedPubkey">ristretto255_twisted_elgamal::CompressedPubkey</a>, token_address: <b>address</b>, commitment_bytes: <a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, response_bytes: <a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;)
</code></pre>



<a id="0x7_confidential_proof_verify_withdrawal_proof"></a>

## Function `verify_withdrawal_proof`

Verifies the validity of the <code>withdraw</code> operation.

This function ensures that the provided proof (<code><a href="confidential_proof.md#0x7_confidential_proof_WithdrawalProof">WithdrawalProof</a></code>) meets the following conditions:
1. The current balance (<code>current_balance</code>) and new balance (<code>new_balance</code>) encrypt the corresponding values
under the same encryption key (<code>ek</code>) before and after the withdrawal of the specified amount (<code>amount</code>), respectively.
2. The relationship <code>new_balance = current_balance - amount</code> holds, verifying that the withdrawal amount is deducted correctly.
3. The new balance (<code>new_balance</code>) is normalized, with each chunk adhering to the range [0, 2^16).

If all conditions are satisfied, the proof validates the withdrawal; otherwise, the function causes an error.


<pre><code><b>public</b> <b>fun</b> <a href="confidential_proof.md#0x7_confidential_proof_verify_withdrawal_proof">verify_withdrawal_proof</a>(<a href="../../aptos-framework/doc/chain_id.md#0x1_chain_id">chain_id</a>: u8, sender: <b>address</b>, contract_address: <b>address</b>, ek: &<a href="ristretto255_twisted_elgamal.md#0x7_ristretto255_twisted_elgamal_CompressedPubkey">ristretto255_twisted_elgamal::CompressedPubkey</a>, amount: u64, current_balance: &<a href="confidential_balance.md#0x7_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>, new_balance: &<a href="confidential_balance.md#0x7_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>, proof: &<a href="confidential_proof.md#0x7_confidential_proof_WithdrawalProof">confidential_proof::WithdrawalProof</a>)
</code></pre>



<a id="0x7_confidential_proof_verify_transfer_proof"></a>

## Function `verify_transfer_proof`

Verifies the validity of the <code>confidential_transfer</code> operation.

This function ensures that the provided proof (<code><a href="confidential_proof.md#0x7_confidential_proof_TransferProof">TransferProof</a></code>) meets the following conditions:
1. The transferred amount (<code>recipient_amount</code> and <code>sender_amount</code>) and the auditors' amounts
(<code>auditor_amounts</code>), if provided, encrypt the transfer value using the recipient's, sender's,
and auditors' encryption keys, respectively.
2. The sender's current balance (<code>current_balance</code>) and new balance (<code>new_balance</code>) encrypt the corresponding values
under the sender's encryption key (<code>sender_ek</code>) before and after the transfer, respectively.
3. The relationship <code>new_balance = current_balance - transfer_amount</code> is maintained, ensuring balance integrity.
4. The transferred value (<code>recipient_amount</code>) is properly normalized, with each chunk adhering to the range [0, 2^16).
5. The sender's new balance is normalized, with each chunk in <code>new_balance</code> also adhering to the range [0, 2^16).

If all conditions are satisfied, the proof validates the transfer; otherwise, the function causes an error.

<code>sender_auditor_hint</code> is bound into the transfer sigma Fiat–Shamir transcript (same bytes as emitted on-chain).


<pre><code><b>public</b> <b>fun</b> <a href="confidential_proof.md#0x7_confidential_proof_verify_transfer_proof">verify_transfer_proof</a>(<a href="../../aptos-framework/doc/chain_id.md#0x1_chain_id">chain_id</a>: u8, sender: <b>address</b>, contract_address: <b>address</b>, sender_ek: &<a href="ristretto255_twisted_elgamal.md#0x7_ristretto255_twisted_elgamal_CompressedPubkey">ristretto255_twisted_elgamal::CompressedPubkey</a>, recipient_ek: &<a href="ristretto255_twisted_elgamal.md#0x7_ristretto255_twisted_elgamal_CompressedPubkey">ristretto255_twisted_elgamal::CompressedPubkey</a>, current_balance: &<a href="confidential_balance.md#0x7_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>, new_balance: &<a href="confidential_balance.md#0x7_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>, sender_amount: &<a href="confidential_balance.md#0x7_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>, recipient_amount: &<a href="confidential_balance.md#0x7_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>, auditor_eks: &<a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="ristretto255_twisted_elgamal.md#0x7_ristretto255_twisted_elgamal_CompressedPubkey">ristretto255_twisted_elgamal::CompressedPubkey</a>&gt;, auditor_amounts: &<a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="confidential_balance.md#0x7_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>&gt;, sender_auditor_hint: &<a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, proof: &<a href="confidential_proof.md#0x7_confidential_proof_TransferProof">confidential_proof::TransferProof</a>)
</code></pre>



<a id="0x7_confidential_proof_verify_normalization_proof"></a>

## Function `verify_normalization_proof`

Verifies the validity of the <code>normalize</code> operation.

This function ensures that the provided proof (<code><a href="confidential_proof.md#0x7_confidential_proof_NormalizationProof">NormalizationProof</a></code>) meets the following conditions:
1. The current balance (<code>current_balance</code>) and new balance (<code>new_balance</code>) encrypt the same value
under the same provided encryption key (<code>ek</code>), verifying that the normalization process preserves the balance value.
2. The new balance (<code>new_balance</code>) is properly normalized, with each chunk adhering to the range [0, 2^16),
as verified through the range proof in the normalization process.

If all conditions are satisfied, the proof validates the normalization; otherwise, the function causes an error.


<pre><code><b>public</b> <b>fun</b> <a href="confidential_proof.md#0x7_confidential_proof_verify_normalization_proof">verify_normalization_proof</a>(<a href="../../aptos-framework/doc/chain_id.md#0x1_chain_id">chain_id</a>: u8, sender: <b>address</b>, contract_address: <b>address</b>, ek: &<a href="ristretto255_twisted_elgamal.md#0x7_ristretto255_twisted_elgamal_CompressedPubkey">ristretto255_twisted_elgamal::CompressedPubkey</a>, current_balance: &<a href="confidential_balance.md#0x7_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>, new_balance: &<a href="confidential_balance.md#0x7_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>, proof: &<a href="confidential_proof.md#0x7_confidential_proof_NormalizationProof">confidential_proof::NormalizationProof</a>)
</code></pre>



<a id="0x7_confidential_proof_verify_rotation_proof"></a>

## Function `verify_rotation_proof`

Verifies the validity of the <code>rotate_encryption_key</code> operation.

This function ensures that the provided proof (<code><a href="confidential_proof.md#0x7_confidential_proof_RotationProof">RotationProof</a></code>) meets the following conditions:
1. The current balance (<code>current_balance</code>) and new balance (<code>new_balance</code>) encrypt the same value under the
current encryption key (<code>current_ek</code>) and the new encryption key (<code>new_ek</code>), respectively, verifying
that the key rotation preserves the balance value.
2. The new balance (<code>new_balance</code>) is properly normalized, with each chunk adhering to the range [0, 2^16),
ensuring balance integrity after the key rotation.

If all conditions are satisfied, the proof validates the key rotation; otherwise, the function causes an error.


<pre><code><b>public</b> <b>fun</b> <a href="confidential_proof.md#0x7_confidential_proof_verify_rotation_proof">verify_rotation_proof</a>(<a href="../../aptos-framework/doc/chain_id.md#0x1_chain_id">chain_id</a>: u8, sender: <b>address</b>, contract_address: <b>address</b>, current_ek: &<a href="ristretto255_twisted_elgamal.md#0x7_ristretto255_twisted_elgamal_CompressedPubkey">ristretto255_twisted_elgamal::CompressedPubkey</a>, new_ek: &<a href="ristretto255_twisted_elgamal.md#0x7_ristretto255_twisted_elgamal_CompressedPubkey">ristretto255_twisted_elgamal::CompressedPubkey</a>, current_balance: &<a href="confidential_balance.md#0x7_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>, new_balance: &<a href="confidential_balance.md#0x7_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>, proof: &<a href="confidential_proof.md#0x7_confidential_proof_RotationProof">confidential_proof::RotationProof</a>)
</code></pre>



<a id="0x7_confidential_proof_auditors_count_in_transfer_proof"></a>

## Function `auditors_count_in_transfer_proof`

Returns <code>n</code>, the number of **auditor rows** encoded in the transfer sigma proof — i.e.
<code>proof.sigma_proof.xs.x7s.length()</code>. Each row holds the four <code>x7s</code> curve commitments for one auditor EK.
<code><a href="confidential_asset.md#0x7_confidential_asset">confidential_asset</a></code> uses this to cross-check auditor ciphertext vectors on <code>confidential_transfer</code>.


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="confidential_proof.md#0x7_confidential_proof_auditors_count_in_transfer_proof">auditors_count_in_transfer_proof</a>(proof: &<a href="confidential_proof.md#0x7_confidential_proof_TransferProof">confidential_proof::TransferProof</a>): u64
</code></pre>



<a id="0x7_confidential_proof_transfer_proof_ek_volun_auds_flat_bytes"></a>

## Function `transfer_proof_ek_volun_auds_flat_bytes`

Serializes <code>proof.sigma_proof.xs.x7s</code> for the <code>Transferred</code> event field <code>ek_volun_auds</code>: every commitment
is written as **32 bytes** (<code><a href="../../aptos-framework/../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255_compressed_point_to_bytes">ristretto255::compressed_point_to_bytes</a></code>), outer vector = auditors (same order
as the transfer's auditor EK list), inner vector length is **4** (one compressed point per 16-bit amount
chunk lane). **Total length = <code>128 × <a href="confidential_proof.md#0x7_confidential_proof_auditors_count_in_transfer_proof">auditors_count_in_transfer_proof</a>(proof)</code>** bytes (or <code>0</code> when <code>n = 0</code>).


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="confidential_proof.md#0x7_confidential_proof_transfer_proof_ek_volun_auds_flat_bytes">transfer_proof_ek_volun_auds_flat_bytes</a>(proof: &<a href="confidential_proof.md#0x7_confidential_proof_TransferProof">confidential_proof::TransferProof</a>): <a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
</code></pre>



<a id="0x7_confidential_proof_deserialize_withdrawal_proof"></a>

## Function `deserialize_withdrawal_proof`

Deserializes the <code><a href="confidential_proof.md#0x7_confidential_proof_WithdrawalProof">WithdrawalProof</a></code> from the byte array.
Returns <code>Some(<a href="confidential_proof.md#0x7_confidential_proof_WithdrawalProof">WithdrawalProof</a>)</code> if the deserialization is successful; otherwise, returns <code>None</code>.


<pre><code><b>public</b> <b>fun</b> <a href="confidential_proof.md#0x7_confidential_proof_deserialize_withdrawal_proof">deserialize_withdrawal_proof</a>(sigma_proof_bytes: <a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, zkrp_new_balance_bytes: <a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_Option">option::Option</a>&lt;<a href="confidential_proof.md#0x7_confidential_proof_WithdrawalProof">confidential_proof::WithdrawalProof</a>&gt;
</code></pre>



<a id="0x7_confidential_proof_deserialize_transfer_proof"></a>

## Function `deserialize_transfer_proof`

Deserializes the <code><a href="confidential_proof.md#0x7_confidential_proof_TransferProof">TransferProof</a></code> from the byte array.
Returns <code>Some(<a href="confidential_proof.md#0x7_confidential_proof_TransferProof">TransferProof</a>)</code> if the deserialization is successful; otherwise, returns <code>None</code>.


<pre><code><b>public</b> <b>fun</b> <a href="confidential_proof.md#0x7_confidential_proof_deserialize_transfer_proof">deserialize_transfer_proof</a>(sigma_proof_bytes: <a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, zkrp_new_balance_bytes: <a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, zkrp_transfer_amount_bytes: <a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_Option">option::Option</a>&lt;<a href="confidential_proof.md#0x7_confidential_proof_TransferProof">confidential_proof::TransferProof</a>&gt;
</code></pre>



<a id="0x7_confidential_proof_deserialize_normalization_proof"></a>

## Function `deserialize_normalization_proof`

Deserializes the <code><a href="confidential_proof.md#0x7_confidential_proof_NormalizationProof">NormalizationProof</a></code> from the byte array.
Returns <code>Some(<a href="confidential_proof.md#0x7_confidential_proof_NormalizationProof">NormalizationProof</a>)</code> if the deserialization is successful; otherwise, returns <code>None</code>.


<pre><code><b>public</b> <b>fun</b> <a href="confidential_proof.md#0x7_confidential_proof_deserialize_normalization_proof">deserialize_normalization_proof</a>(sigma_proof_bytes: <a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, zkrp_new_balance_bytes: <a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_Option">option::Option</a>&lt;<a href="confidential_proof.md#0x7_confidential_proof_NormalizationProof">confidential_proof::NormalizationProof</a>&gt;
</code></pre>



<a id="0x7_confidential_proof_deserialize_rotation_proof"></a>

## Function `deserialize_rotation_proof`

Deserializes the <code><a href="confidential_proof.md#0x7_confidential_proof_RotationProof">RotationProof</a></code> from the byte array.
Returns <code>Some(<a href="confidential_proof.md#0x7_confidential_proof_RotationProof">RotationProof</a>)</code> if the deserialization is successful; otherwise, returns <code>None</code>.


<pre><code><b>public</b> <b>fun</b> <a href="confidential_proof.md#0x7_confidential_proof_deserialize_rotation_proof">deserialize_rotation_proof</a>(sigma_proof_bytes: <a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, zkrp_new_balance_bytes: <a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_Option">option::Option</a>&lt;<a href="confidential_proof.md#0x7_confidential_proof_RotationProof">confidential_proof::RotationProof</a>&gt;
</code></pre>



<a id="0x7_confidential_proof_get_fiat_shamir_withdrawal_sigma_dst"></a>

## Function `get_fiat_shamir_withdrawal_sigma_dst`

Returns the Fiat Shamir DST for the <code><a href="confidential_proof.md#0x7_confidential_proof_WithdrawalSigmaProof">WithdrawalSigmaProof</a></code>.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="confidential_proof.md#0x7_confidential_proof_get_fiat_shamir_withdrawal_sigma_dst">get_fiat_shamir_withdrawal_sigma_dst</a>(): <a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
</code></pre>



<a id="0x7_confidential_proof_get_fiat_shamir_transfer_sigma_dst"></a>

## Function `get_fiat_shamir_transfer_sigma_dst`

Returns the Fiat Shamir DST for the <code><a href="confidential_proof.md#0x7_confidential_proof_TransferSigmaProof">TransferSigmaProof</a></code>.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="confidential_proof.md#0x7_confidential_proof_get_fiat_shamir_transfer_sigma_dst">get_fiat_shamir_transfer_sigma_dst</a>(): <a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
</code></pre>



<a id="0x7_confidential_proof_get_fiat_shamir_normalization_sigma_dst"></a>

## Function `get_fiat_shamir_normalization_sigma_dst`

Returns the Fiat Shamir DST for the <code><a href="confidential_proof.md#0x7_confidential_proof_NormalizationSigmaProof">NormalizationSigmaProof</a></code>.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="confidential_proof.md#0x7_confidential_proof_get_fiat_shamir_normalization_sigma_dst">get_fiat_shamir_normalization_sigma_dst</a>(): <a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
</code></pre>



<a id="0x7_confidential_proof_get_fiat_shamir_rotation_sigma_dst"></a>

## Function `get_fiat_shamir_rotation_sigma_dst`

Returns the Fiat Shamir DST for the <code><a href="confidential_proof.md#0x7_confidential_proof_RotationSigmaProof">RotationSigmaProof</a></code>.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="confidential_proof.md#0x7_confidential_proof_get_fiat_shamir_rotation_sigma_dst">get_fiat_shamir_rotation_sigma_dst</a>(): <a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
</code></pre>



<a id="0x7_confidential_proof_get_fiat_shamir_registration_sigma_dst"></a>

## Function `get_fiat_shamir_registration_sigma_dst`

Returns the Fiat Shamir DST for registration sigma (<code>verify_registration_proof</code>).


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="confidential_proof.md#0x7_confidential_proof_get_fiat_shamir_registration_sigma_dst">get_fiat_shamir_registration_sigma_dst</a>(): <a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
</code></pre>



<a id="0x7_confidential_proof_get_bulletproofs_dst"></a>

## Function `get_bulletproofs_dst`

Returns the DST for the range proofs.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="confidential_proof.md#0x7_confidential_proof_get_bulletproofs_dst">get_bulletproofs_dst</a>(): <a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
</code></pre>



<a id="0x7_confidential_proof_get_bulletproofs_num_bits"></a>

## Function `get_bulletproofs_num_bits`

Returns the maximum number of bits of the normalized chunk for the range proofs.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="confidential_proof.md#0x7_confidential_proof_get_bulletproofs_num_bits">get_bulletproofs_num_bits</a>(): u64
</code></pre>
