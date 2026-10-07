
<a id="0x1_zktls"></a>

# Module `0x1::zktls`

Onchain verification of zkTLS attestations, at enrollment.

The chain verifies the attestation itself: it recomputes the claim digest with keccak256 and
recovers one signer per signature with <code><a href="../../aptos-stdlib/doc/secp256k1.md#0x1_secp256k1_ecdsa_recover">secp256k1::ecdsa_recover</a></code> against an epoch-registered
attestor set, rejecting duplicates and requiring a threshold. Both primitives are ungated
natives, so this module needs no Rust change, no new native and no feature flag. The shape is
borrowed from Reclaim's onchain verifier, which contains no zero-knowledge verification at all:
it is a digest recomputation plus N public-key recoveries plus a threshold and a duplicate
check.

This is ENROLLMENT and must never sit in a per-action path. A proxy or MPC-TLS session takes
seconds, needs the user to log into the provider inside the flow, and depends on a provider
template that breaks when the provider changes its markup. Verify once at the boundary, write a
fact through <code>aptos_framework::attestation</code>, then read the fact from then on. The failure mode
of a broken template is then that new enrollment degrades, not that existing subjects break.

Known offchain dependency, stated plainly because it cannot be fixed here: <code>template_id</code> is the
hash of a provider config (the request URL, the response regex, the redaction rules) that lives
in the provider's own registry. An attestor cannot run a session without resolving that hash to
the config, so if the provider delists it the onchain template becomes a dead pointer that
governance cannot repair.


-  [Struct `AttestorSet`](#0x1_zktls_AttestorSet)
-  [Struct `Template`](#0x1_zktls_Template)
-  [Resource `Verifier`](#0x1_zktls_Verifier)
-  [Struct `SetAttestorSet`](#0x1_zktls_SetAttestorSet)
-  [Struct `RegisterTemplate`](#0x1_zktls_RegisterTemplate)
-  [Struct `RevokeTemplate`](#0x1_zktls_RevokeTemplate)
-  [Struct `Enroll`](#0x1_zktls_Enroll)
-  [Constants](#@Constants_0)
-  [Function `is_initialized`](#0x1_zktls_is_initialized)
-  [Function `current_epoch`](#0x1_zktls_current_epoch)
-  [Function `attestors`](#0x1_zktls_attestors)
-  [Function `threshold`](#0x1_zktls_threshold)
-  [Function `is_epoch_accepted`](#0x1_zktls_is_epoch_accepted)
-  [Function `is_claim_consumed`](#0x1_zktls_is_claim_consumed)
-  [Function `is_template_active`](#0x1_zktls_is_template_active)
-  [Function `claim_digest`](#0x1_zktls_claim_digest)
-  [Function `recover_attestor`](#0x1_zktls_recover_attestor)
-  [Function `verify_claim`](#0x1_zktls_verify_claim)
-  [Function `initialize`](#0x1_zktls_initialize)
-  [Function `set_attestor_set`](#0x1_zktls_set_attestor_set)
-  [Function `register_template`](#0x1_zktls_register_template)
-  [Function `revoke_template`](#0x1_zktls_revoke_template)
-  [Function `enroll`](#0x1_zktls_enroll)
-  [Function `verify_claim_internal`](#0x1_zktls_verify_claim_internal)
-  [Function `epoch_accepted`](#0x1_zktls_epoch_accepted)
-  [Function `claim_binds`](#0x1_zktls_claim_binds)
-  [Function `contains_bytes`](#0x1_zktls_contains_bytes)
-  [Function `lowercase_hex`](#0x1_zktls_lowercase_hex)
-  [Function `decimal_bytes`](#0x1_zktls_decimal_bytes)
-  [Function `assert_initialized`](#0x1_zktls_assert_initialized)
-  [Specification](#@Specification_1)
    -  [High-level Requirements](#high-level-req)
    -  [Module-level Specification](#module-level-spec)
    -  [Function `is_initialized`](#@Specification_1_is_initialized)
    -  [Function `current_epoch`](#@Specification_1_current_epoch)
    -  [Function `threshold`](#@Specification_1_threshold)
    -  [Function `is_epoch_accepted`](#@Specification_1_is_epoch_accepted)
    -  [Function `is_claim_consumed`](#@Specification_1_is_claim_consumed)
    -  [Function `is_template_active`](#@Specification_1_is_template_active)
    -  [Function `verify_claim`](#@Specification_1_verify_claim)
    -  [Function `set_attestor_set`](#@Specification_1_set_attestor_set)
    -  [Function `register_template`](#@Specification_1_register_template)
    -  [Function `revoke_template`](#@Specification_1_revoke_template)
    -  [Function `enroll`](#@Specification_1_enroll)
    -  [Function `epoch_accepted`](#@Specification_1_epoch_accepted)


<pre><code><b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/hash.md#0x1_aptos_hash">0x1::aptos_hash</a>;
<b>use</b> <a href="attestation.md#0x1_attestation">0x1::attestation</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/bcs.md#0x1_bcs">0x1::bcs</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error">0x1::error</a>;
<b>use</b> <a href="event.md#0x1_event">0x1::event</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option">0x1::option</a>;
<b>use</b> <a href="../../aptos-stdlib/doc/secp256k1.md#0x1_secp256k1">0x1::secp256k1</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">0x1::signer</a>;
<b>use</b> <a href="../../aptos-stdlib/doc/table.md#0x1_table">0x1::table</a>;
<b>use</b> <a href="timestamp.md#0x1_timestamp">0x1::timestamp</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">0x1::vector</a>;
</code></pre>



<a id="0x1_zktls_AttestorSet"></a>

## Struct `AttestorSet`

A set of attestors and how many of them must sign.


<pre><code><b>struct</b> <a href="zktls.md#0x1_zktls_AttestorSet">AttestorSet</a> <b>has</b> <b>copy</b>, drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>attestors: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>threshold: u64</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_zktls_Template"></a>

## Struct `Template`

What a successful claim under one provider template entitles the subject to.


<pre><code><b>struct</b> <a href="zktls.md#0x1_zktls_Template">Template</a> <b>has</b> <b>copy</b>, drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>template_id: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>grants_level: u8</code>
</dt>
<dd>

</dd>
<dt>
<code>ttl_secs: u64</code>
</dt>
<dd>

</dd>
<dt>
<code>active: bool</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_zktls_Verifier"></a>

## Resource `Verifier`

Stored under the source's resource account address.


<pre><code><b>struct</b> <a href="zktls.md#0x1_zktls_Verifier">Verifier</a> <b>has</b> key
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>sets: <a href="../../aptos-stdlib/doc/table.md#0x1_table_Table">table::Table</a>&lt;u64, <a href="zktls.md#0x1_zktls_AttestorSet">zktls::AttestorSet</a>&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>current_epoch: u64</code>
</dt>
<dd>

</dd>
<dt>
<code>previous_deadline_secs: u64</code>
</dt>
<dd>

</dd>
<dt>
<code>templates: <a href="../../aptos-stdlib/doc/table.md#0x1_table_Table">table::Table</a>&lt;<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, <a href="zktls.md#0x1_zktls_Template">zktls::Template</a>&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>consumed: <a href="../../aptos-stdlib/doc/table.md#0x1_table_Table">table::Table</a>&lt;<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, bool&gt;</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_zktls_SetAttestorSet"></a>

## Struct `SetAttestorSet`



<pre><code>#[<a href="event.md#0x1_event">event</a>]
<b>struct</b> <a href="zktls.md#0x1_zktls_SetAttestorSet">SetAttestorSet</a> <b>has</b> drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>source: <b>address</b></code>
</dt>
<dd>

</dd>
<dt>
<code>epoch: u64</code>
</dt>
<dd>

</dd>
<dt>
<code>threshold: u64</code>
</dt>
<dd>

</dd>
<dt>
<code>count: u64</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_zktls_RegisterTemplate"></a>

## Struct `RegisterTemplate`



<pre><code>#[<a href="event.md#0x1_event">event</a>]
<b>struct</b> <a href="zktls.md#0x1_zktls_RegisterTemplate">RegisterTemplate</a> <b>has</b> drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>source: <b>address</b></code>
</dt>
<dd>

</dd>
<dt>
<code>template_id: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>grants_level: u8</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_zktls_RevokeTemplate"></a>

## Struct `RevokeTemplate`



<pre><code>#[<a href="event.md#0x1_event">event</a>]
<b>struct</b> <a href="zktls.md#0x1_zktls_RevokeTemplate">RevokeTemplate</a> <b>has</b> drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>source: <b>address</b></code>
</dt>
<dd>

</dd>
<dt>
<code>template_id: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_zktls_Enroll"></a>

## Struct `Enroll`



<pre><code>#[<a href="event.md#0x1_event">event</a>]
<b>struct</b> <a href="zktls.md#0x1_zktls_Enroll">Enroll</a> <b>has</b> drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>source: <b>address</b></code>
</dt>
<dd>

</dd>
<dt>
<code>subject: <b>address</b></code>
</dt>
<dd>

</dd>
<dt>
<code>template_id: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>signers: u64</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="@Constants_0"></a>

## Constants


<a id="0x1_zktls_MAX_U64"></a>



<pre><code><b>const</b> <a href="zktls.md#0x1_zktls_MAX_U64">MAX_U64</a>: u64 = 18446744073709551615;
</code></pre>



<a id="0x1_zktls_EBAD_SIGNATURE"></a>

A signature could not be recovered.


<pre><code><b>const</b> <a href="zktls.md#0x1_zktls_EBAD_SIGNATURE">EBAD_SIGNATURE</a>: u64 = 9;
</code></pre>



<a id="0x1_zktls_ENOT_ADMIN"></a>

The caller is not an admin of the source.


<pre><code><b>const</b> <a href="zktls.md#0x1_zktls_ENOT_ADMIN">ENOT_ADMIN</a>: u64 = 1;
</code></pre>



<a id="0x1_zktls_SIGNATURE_LENGTH"></a>

r (32) plus s (32) plus the recovery id (1).


<pre><code><b>const</b> <a href="zktls.md#0x1_zktls_SIGNATURE_LENGTH">SIGNATURE_LENGTH</a>: u64 = 65;
</code></pre>



<a id="0x1_zktls_EBAD_SIGNATURE_LENGTH"></a>

A signature must be exactly 65 bytes: r, s, then the recovery id.


<pre><code><b>const</b> <a href="zktls.md#0x1_zktls_EBAD_SIGNATURE_LENGTH">EBAD_SIGNATURE_LENGTH</a>: u64 = 14;
</code></pre>



<a id="0x1_zktls_ENOT_INITIALIZED"></a>

This source has no verifier configured.


<pre><code><b>const</b> <a href="zktls.md#0x1_zktls_ENOT_INITIALIZED">ENOT_INITIALIZED</a>: u64 = 12;
</code></pre>



<a id="0x1_zktls_ATTESTOR_LENGTH"></a>

Ethereum-style attestor address length.


<pre><code><b>const</b> <a href="zktls.md#0x1_zktls_ATTESTOR_LENGTH">ATTESTOR_LENGTH</a>: u64 = 20;
</code></pre>



<a id="0x1_zktls_EBAD_ATTESTOR_LENGTH"></a>

An attestor address must be exactly 20 bytes.


<pre><code><b>const</b> <a href="zktls.md#0x1_zktls_EBAD_ATTESTOR_LENGTH">EBAD_ATTESTOR_LENGTH</a>: u64 = 13;
</code></pre>



<a id="0x1_zktls_EBAD_THRESHOLD"></a>

The threshold must be at least 1 and at most the attestor count.


<pre><code><b>const</b> <a href="zktls.md#0x1_zktls_EBAD_THRESHOLD">EBAD_THRESHOLD</a>: u64 = 10;
</code></pre>



<a id="0x1_zktls_EBELOW_THRESHOLD"></a>

Fewer distinct attestors signed than the threshold requires.


<pre><code><b>const</b> <a href="zktls.md#0x1_zktls_EBELOW_THRESHOLD">EBELOW_THRESHOLD</a>: u64 = 4;
</code></pre>



<a id="0x1_zktls_ECLAIM_CONSUMED"></a>

This claim has already been used to enroll.


<pre><code><b>const</b> <a href="zktls.md#0x1_zktls_ECLAIM_CONSUMED">ECLAIM_CONSUMED</a>: u64 = 16;
</code></pre>



<a id="0x1_zktls_EDUPLICATE_ATTESTOR"></a>

The attestor list cannot contain duplicates.


<pre><code><b>const</b> <a href="zktls.md#0x1_zktls_EDUPLICATE_ATTESTOR">EDUPLICATE_ATTESTOR</a>: u64 = 11;
</code></pre>



<a id="0x1_zktls_EDUPLICATE_SIGNER"></a>

The same attestor signed twice.


<pre><code><b>const</b> <a href="zktls.md#0x1_zktls_EDUPLICATE_SIGNER">EDUPLICATE_SIGNER</a>: u64 = 5;
</code></pre>



<a id="0x1_zktls_EMALFORMED_CLAIM"></a>

The claim does not bind this subject and this template.


<pre><code><b>const</b> <a href="zktls.md#0x1_zktls_EMALFORMED_CLAIM">EMALFORMED_CLAIM</a>: u64 = 8;
</code></pre>



<a id="0x1_zktls_ERETIRED_ATTESTOR_EPOCH"></a>

The attestor epoch has been rotated away and its grace window has ended.


<pre><code><b>const</b> <a href="zktls.md#0x1_zktls_ERETIRED_ATTESTOR_EPOCH">ERETIRED_ATTESTOR_EPOCH</a>: u64 = 15;
</code></pre>



<a id="0x1_zktls_ETEMPLATE_REVOKED"></a>

The template has been revoked.


<pre><code><b>const</b> <a href="zktls.md#0x1_zktls_ETEMPLATE_REVOKED">ETEMPLATE_REVOKED</a>: u64 = 3;
</code></pre>



<a id="0x1_zktls_ETH_PREFIX"></a>

The prefix Ethereum wallets and attestor networks apply before signing.


<pre><code><b>const</b> <a href="zktls.md#0x1_zktls_ETH_PREFIX">ETH_PREFIX</a>: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt; = [25, 69, 116, 104, 101, 114, 101, 117, 109, 32, 83, 105, 103, 110, 101, 100, 32, 77, 101, 115, 115, 97, 103, 101, 58, 10];
</code></pre>



<a id="0x1_zktls_EUNKNOWN_ATTESTOR"></a>

A recovered signer is not in the registered attestor set.


<pre><code><b>const</b> <a href="zktls.md#0x1_zktls_EUNKNOWN_ATTESTOR">EUNKNOWN_ATTESTOR</a>: u64 = 6;
</code></pre>



<a id="0x1_zktls_EUNKNOWN_ATTESTOR_EPOCH"></a>

No attestor set is registered for the requested epoch.


<pre><code><b>const</b> <a href="zktls.md#0x1_zktls_EUNKNOWN_ATTESTOR_EPOCH">EUNKNOWN_ATTESTOR_EPOCH</a>: u64 = 7;
</code></pre>



<a id="0x1_zktls_EUNKNOWN_TEMPLATE"></a>

No template is registered under the given id.


<pre><code><b>const</b> <a href="zktls.md#0x1_zktls_EUNKNOWN_TEMPLATE">EUNKNOWN_TEMPLATE</a>: u64 = 2;
</code></pre>



<a id="0x1_zktls_MAX_SIGNATURES"></a>

Largest number of signatures one claim may carry.


<pre><code><b>const</b> <a href="zktls.md#0x1_zktls_MAX_SIGNATURES">MAX_SIGNATURES</a>: u64 = 16;
</code></pre>



<a id="0x1_zktls_is_initialized"></a>

## Function `is_initialized`



<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="zktls.md#0x1_zktls_is_initialized">is_initialized</a>(source: <b>address</b>): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="zktls.md#0x1_zktls_is_initialized">is_initialized</a>(source: <b>address</b>): bool {
    <b>exists</b>&lt;<a href="zktls.md#0x1_zktls_Verifier">Verifier</a>&gt;(source)
}
</code></pre>



</details>

<a id="0x1_zktls_current_epoch"></a>

## Function `current_epoch`



<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="zktls.md#0x1_zktls_current_epoch">current_epoch</a>(source: <b>address</b>): u64
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="zktls.md#0x1_zktls_current_epoch">current_epoch</a>(source: <b>address</b>): u64 <b>acquires</b> <a href="zktls.md#0x1_zktls_Verifier">Verifier</a> {
    <a href="zktls.md#0x1_zktls_assert_initialized">assert_initialized</a>(source);
    <a href="zktls.md#0x1_zktls_Verifier">Verifier</a>[source].current_epoch
}
</code></pre>



</details>

<a id="0x1_zktls_attestors"></a>

## Function `attestors`

Attestor addresses registered for an epoch.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="zktls.md#0x1_zktls_attestors">attestors</a>(source: <b>address</b>, epoch: u64): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="zktls.md#0x1_zktls_attestors">attestors</a>(source: <b>address</b>, epoch: u64): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;&gt; <b>acquires</b> <a href="zktls.md#0x1_zktls_Verifier">Verifier</a> {
    <a href="zktls.md#0x1_zktls_assert_initialized">assert_initialized</a>(source);
    <b>let</b> verifier = &<a href="zktls.md#0x1_zktls_Verifier">Verifier</a>[source];
    <b>assert</b>!(
        <a href="../../aptos-stdlib/doc/table.md#0x1_table_contains">table::contains</a>(&verifier.sets, epoch),
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_not_found">error::not_found</a>(<a href="zktls.md#0x1_zktls_EUNKNOWN_ATTESTOR_EPOCH">EUNKNOWN_ATTESTOR_EPOCH</a>)
    );
    <a href="../../aptos-stdlib/doc/table.md#0x1_table_borrow">table::borrow</a>(&verifier.sets, epoch).attestors
}
</code></pre>



</details>

<a id="0x1_zktls_threshold"></a>

## Function `threshold`



<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="zktls.md#0x1_zktls_threshold">threshold</a>(source: <b>address</b>, epoch: u64): u64
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="zktls.md#0x1_zktls_threshold">threshold</a>(source: <b>address</b>, epoch: u64): u64 <b>acquires</b> <a href="zktls.md#0x1_zktls_Verifier">Verifier</a> {
    <a href="zktls.md#0x1_zktls_assert_initialized">assert_initialized</a>(source);
    <b>let</b> verifier = &<a href="zktls.md#0x1_zktls_Verifier">Verifier</a>[source];
    <b>assert</b>!(
        <a href="../../aptos-stdlib/doc/table.md#0x1_table_contains">table::contains</a>(&verifier.sets, epoch),
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_not_found">error::not_found</a>(<a href="zktls.md#0x1_zktls_EUNKNOWN_ATTESTOR_EPOCH">EUNKNOWN_ATTESTOR_EPOCH</a>)
    );
    <a href="../../aptos-stdlib/doc/table.md#0x1_table_borrow">table::borrow</a>(&verifier.sets, epoch).threshold
}
</code></pre>



</details>

<a id="0x1_zktls_is_epoch_accepted"></a>

## Function `is_epoch_accepted`

Whether claims signed by the given epoch's attestor set are accepted right now.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="zktls.md#0x1_zktls_is_epoch_accepted">is_epoch_accepted</a>(source: <b>address</b>, epoch: u64): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="zktls.md#0x1_zktls_is_epoch_accepted">is_epoch_accepted</a>(source: <b>address</b>, epoch: u64): bool <b>acquires</b> <a href="zktls.md#0x1_zktls_Verifier">Verifier</a> {
    <b>if</b> (!<b>exists</b>&lt;<a href="zktls.md#0x1_zktls_Verifier">Verifier</a>&gt;(source)) {
        <b>return</b> <b>false</b>
    };
    <a href="zktls.md#0x1_zktls_epoch_accepted">epoch_accepted</a>(&<a href="zktls.md#0x1_zktls_Verifier">Verifier</a>[source], epoch)
}
</code></pre>



</details>

<a id="0x1_zktls_is_claim_consumed"></a>

## Function `is_claim_consumed`

Whether a claim has already been used to enroll in this source.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="zktls.md#0x1_zktls_is_claim_consumed">is_claim_consumed</a>(source: <b>address</b>, claim: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="zktls.md#0x1_zktls_is_claim_consumed">is_claim_consumed</a>(source: <b>address</b>, claim: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): bool <b>acquires</b> <a href="zktls.md#0x1_zktls_Verifier">Verifier</a> {
    <b>exists</b>&lt;<a href="zktls.md#0x1_zktls_Verifier">Verifier</a>&gt;(source)
        && <a href="../../aptos-stdlib/doc/table.md#0x1_table_contains">table::contains</a>(&<a href="zktls.md#0x1_zktls_Verifier">Verifier</a>[source].consumed, keccak256(claim))
}
</code></pre>



</details>

<a id="0x1_zktls_is_template_active"></a>

## Function `is_template_active`



<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="zktls.md#0x1_zktls_is_template_active">is_template_active</a>(source: <b>address</b>, template_id: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="zktls.md#0x1_zktls_is_template_active">is_template_active</a>(source: <b>address</b>, template_id: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): bool <b>acquires</b> <a href="zktls.md#0x1_zktls_Verifier">Verifier</a> {
    <b>if</b> (!<b>exists</b>&lt;<a href="zktls.md#0x1_zktls_Verifier">Verifier</a>&gt;(source)) {
        <b>return</b> <b>false</b>
    };
    <b>let</b> templates = &<a href="zktls.md#0x1_zktls_Verifier">Verifier</a>[source].templates;
    <a href="../../aptos-stdlib/doc/table.md#0x1_table_contains">table::contains</a>(templates, template_id)
        && <a href="../../aptos-stdlib/doc/table.md#0x1_table_borrow">table::borrow</a>(templates, template_id).active
}
</code></pre>



</details>

<a id="0x1_zktls_claim_digest"></a>

## Function `claim_digest`

The digest an attestor signs: keccak256 over the Ethereum-prefixed claim. Published so an
attestor implementation can be checked against this module without reading it.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="zktls.md#0x1_zktls_claim_digest">claim_digest</a>(claim: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="zktls.md#0x1_zktls_claim_digest">claim_digest</a>(claim: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt; {
    <b>let</b> prefixed = <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>[];
    prefixed.append(<a href="zktls.md#0x1_zktls_ETH_PREFIX">ETH_PREFIX</a>);
    prefixed.append(<a href="zktls.md#0x1_zktls_decimal_bytes">decimal_bytes</a>(claim.length()));
    prefixed.append(claim);
    keccak256(prefixed)
}
</code></pre>



</details>

<a id="0x1_zktls_recover_attestor"></a>

## Function `recover_attestor`

Recover the 20-byte attestor address that produced a signature over a claim.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="zktls.md#0x1_zktls_recover_attestor">recover_attestor</a>(claim: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, signature: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="zktls.md#0x1_zktls_recover_attestor">recover_attestor</a>(claim: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, signature: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt; {
    <b>assert</b>!(
        signature.length() == <a href="zktls.md#0x1_zktls_SIGNATURE_LENGTH">SIGNATURE_LENGTH</a>,
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="zktls.md#0x1_zktls_EBAD_SIGNATURE_LENGTH">EBAD_SIGNATURE_LENGTH</a>)
    );
    <b>let</b> digest = <a href="zktls.md#0x1_zktls_claim_digest">claim_digest</a>(claim);
    // Ethereum wallets and attestor networks emit v <b>as</b> 27 or 28; the <b>native</b> takes 0 <b>to</b> 3.
    <b>let</b> v = signature[<a href="zktls.md#0x1_zktls_SIGNATURE_LENGTH">SIGNATURE_LENGTH</a> - 1];
    <b>let</b> recovery_id = <b>if</b> (v &gt;= 27) { v - 27 } <b>else</b> { v };
    <b>assert</b>!(recovery_id &lt; 4, <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="zktls.md#0x1_zktls_EBAD_SIGNATURE">EBAD_SIGNATURE</a>));
    <b>let</b> rs = <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>[];
    <b>let</b> index = 0;
    <b>while</b> (index &lt; <a href="zktls.md#0x1_zktls_SIGNATURE_LENGTH">SIGNATURE_LENGTH</a> - 1) {
        rs.push_back(signature[index]);
        index += 1;
    };
    <b>let</b> recovered =
        <a href="../../aptos-stdlib/doc/secp256k1.md#0x1_secp256k1_ecdsa_recover">secp256k1::ecdsa_recover</a>(
            digest, recovery_id, &<a href="../../aptos-stdlib/doc/secp256k1.md#0x1_secp256k1_ecdsa_signature_from_bytes">secp256k1::ecdsa_signature_from_bytes</a>(rs)
        );
    <b>assert</b>!(<a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_is_some">option::is_some</a>(&recovered), <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="zktls.md#0x1_zktls_EBAD_SIGNATURE">EBAD_SIGNATURE</a>));
    <b>let</b> pubkey = <a href="../../aptos-stdlib/doc/secp256k1.md#0x1_secp256k1_ecdsa_raw_public_key_to_bytes">secp256k1::ecdsa_raw_public_key_to_bytes</a>(<a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_borrow">option::borrow</a>(&recovered));
    // Ethereum <b>address</b>: the low 20 bytes of keccak256 over the 64-byte <b>public</b> key.
    <b>let</b> hashed = keccak256(pubkey);
    <b>let</b> address_bytes = <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>[];
    <b>let</b> position = 12;
    <b>while</b> (position &lt; 32) {
        address_bytes.push_back(hashed[position]);
        position += 1;
    };
    address_bytes
}
</code></pre>



</details>

<a id="0x1_zktls_verify_claim"></a>

## Function `verify_claim`

Whether <code>enroll</code> would accept this claim right now, without writing anything: the
signatures meet the threshold, the template is active and the claim is unused. Aborts on
the same malformed inputs <code>enroll</code> aborts on.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="zktls.md#0x1_zktls_verify_claim">verify_claim</a>(source: <b>address</b>, template_id: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, subject: <b>address</b>, claim: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, signatures: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;&gt;, attestor_epoch: u64): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="zktls.md#0x1_zktls_verify_claim">verify_claim</a>(
    source: <b>address</b>,
    template_id: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    subject: <b>address</b>,
    claim: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    signatures: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;&gt;,
    attestor_epoch: u64
): bool <b>acquires</b> <a href="zktls.md#0x1_zktls_Verifier">Verifier</a> {
    <b>let</b> (met, active, consumed, _) =
        <a href="zktls.md#0x1_zktls_verify_claim_internal">verify_claim_internal</a>(
            source, template_id, subject, claim, signatures, attestor_epoch
        );
    met && active && !consumed
}
</code></pre>



</details>

<a id="0x1_zktls_initialize"></a>

## Function `initialize`

Create the verifier for a source. Requires an admin of that source, and obtains the
source's resource-account signer through <code><a href="attestation.md#0x1_attestation">attestation</a></code>'s friend accessor.


<pre><code><b>public</b> entry <b>fun</b> <a href="zktls.md#0x1_zktls_initialize">initialize</a>(admin: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, source: <b>address</b>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="zktls.md#0x1_zktls_initialize">initialize</a>(admin: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, source: <b>address</b>) {
    <b>assert</b>!(
        <a href="attestation.md#0x1_attestation_is_admin">attestation::is_admin</a>(address_of(admin), source),
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_permission_denied">error::permission_denied</a>(<a href="zktls.md#0x1_zktls_ENOT_ADMIN">ENOT_ADMIN</a>)
    );
    <b>let</b> source_signer = <a href="attestation.md#0x1_attestation_source_signer">attestation::source_signer</a>(source);
    <b>move_to</b>(
        &source_signer,
        <a href="zktls.md#0x1_zktls_Verifier">Verifier</a> {
            sets: <a href="../../aptos-stdlib/doc/table.md#0x1_table_new">table::new</a>&lt;u64, <a href="zktls.md#0x1_zktls_AttestorSet">AttestorSet</a>&gt;(),
            current_epoch: 0,
            previous_deadline_secs: 0,
            templates: <a href="../../aptos-stdlib/doc/table.md#0x1_table_new">table::new</a>&lt;<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, <a href="zktls.md#0x1_zktls_Template">Template</a>&gt;(),
            consumed: <a href="../../aptos-stdlib/doc/table.md#0x1_table_new">table::new</a>&lt;<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, bool&gt;()
        }
    );
}
</code></pre>



</details>

<a id="0x1_zktls_set_attestor_set"></a>

## Function `set_attestor_set`

Register a new attestor set under the next epoch. The set it replaces keeps verifying for
<code>previous_grace_secs</code>, so a claim signed moments before the rotation still verifies; every
older set stops verifying immediately. Rotating away a compromised set with a zero grace
window cuts it off at once.

@param admin An admin of the source.
@param source The source address.
@param attestor_addresses 20-byte Ethereum-style addresses, no duplicates.
@param required How many distinct attestors must sign. At least 1, at most the count.
@param previous_grace_secs How long the replaced set keeps verifying. 0 for no grace.


<pre><code><b>public</b> entry <b>fun</b> <a href="zktls.md#0x1_zktls_set_attestor_set">set_attestor_set</a>(admin: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, source: <b>address</b>, attestor_addresses: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;&gt;, required: u64, previous_grace_secs: u64)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="zktls.md#0x1_zktls_set_attestor_set">set_attestor_set</a>(
    admin: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    source: <b>address</b>,
    attestor_addresses: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;&gt;,
    required: u64,
    previous_grace_secs: u64
) <b>acquires</b> <a href="zktls.md#0x1_zktls_Verifier">Verifier</a> {
    <b>assert</b>!(
        <a href="attestation.md#0x1_attestation_is_admin">attestation::is_admin</a>(address_of(admin), source),
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_permission_denied">error::permission_denied</a>(<a href="zktls.md#0x1_zktls_ENOT_ADMIN">ENOT_ADMIN</a>)
    );
    <a href="zktls.md#0x1_zktls_assert_initialized">assert_initialized</a>(source);
    <b>let</b> count = attestor_addresses.length();
    <b>assert</b>!(
        required &gt;= 1 && required &lt;= count,
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="zktls.md#0x1_zktls_EBAD_THRESHOLD">EBAD_THRESHOLD</a>)
    );
    <b>let</b> seen: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;&gt; = <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>[];
    attestor_addresses.for_each_ref(|attestor| {
        <b>assert</b>!(
            attestor.length() == <a href="zktls.md#0x1_zktls_ATTESTOR_LENGTH">ATTESTOR_LENGTH</a>,
            <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="zktls.md#0x1_zktls_EBAD_ATTESTOR_LENGTH">EBAD_ATTESTOR_LENGTH</a>)
        );
        <b>assert</b>!(
            !seen.contains(attestor),
            <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="zktls.md#0x1_zktls_EDUPLICATE_ATTESTOR">EDUPLICATE_ATTESTOR</a>)
        );
        seen.push_back(*attestor);
    });

    <b>let</b> now = now_seconds();
    <b>let</b> verifier = &<b>mut</b> <a href="zktls.md#0x1_zktls_Verifier">Verifier</a>[source];
    <b>let</b> epoch = verifier.current_epoch + 1;
    verifier.current_epoch = epoch;
    verifier.previous_deadline_secs =
        <b>if</b> (previous_grace_secs &gt; <a href="zktls.md#0x1_zktls_MAX_U64">MAX_U64</a> - now) { <a href="zktls.md#0x1_zktls_MAX_U64">MAX_U64</a> }
        <b>else</b> { now + previous_grace_secs };
    <a href="../../aptos-stdlib/doc/table.md#0x1_table_add">table::add</a>(
        &<b>mut</b> verifier.sets,
        epoch,
        <a href="zktls.md#0x1_zktls_AttestorSet">AttestorSet</a> { attestors: attestor_addresses, threshold: required }
    );
    emit(<a href="zktls.md#0x1_zktls_SetAttestorSet">SetAttestorSet</a> { source, epoch, threshold: required, count });
}
</code></pre>



</details>

<a id="0x1_zktls_register_template"></a>

## Function `register_template`

Allow a provider template and say what a claim under it grants.


<pre><code><b>public</b> entry <b>fun</b> <a href="zktls.md#0x1_zktls_register_template">register_template</a>(admin: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, source: <b>address</b>, template_id: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, grants_level: u8, ttl_secs: u64)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="zktls.md#0x1_zktls_register_template">register_template</a>(
    admin: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    source: <b>address</b>,
    template_id: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    grants_level: u8,
    ttl_secs: u64
) <b>acquires</b> <a href="zktls.md#0x1_zktls_Verifier">Verifier</a> {
    <b>assert</b>!(
        <a href="attestation.md#0x1_attestation_is_admin">attestation::is_admin</a>(address_of(admin), source),
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_permission_denied">error::permission_denied</a>(<a href="zktls.md#0x1_zktls_ENOT_ADMIN">ENOT_ADMIN</a>)
    );
    <a href="zktls.md#0x1_zktls_assert_initialized">assert_initialized</a>(source);
    <a href="../../aptos-stdlib/doc/table.md#0x1_table_upsert">table::upsert</a>(
        &<b>mut</b> <a href="zktls.md#0x1_zktls_Verifier">Verifier</a>[source].templates,
        template_id,
        <a href="zktls.md#0x1_zktls_Template">Template</a> { template_id, grants_level, ttl_secs, active: <b>true</b> }
    );
    emit(<a href="zktls.md#0x1_zktls_RegisterTemplate">RegisterTemplate</a> { source, template_id, grants_level });
}
</code></pre>



</details>

<a id="0x1_zktls_revoke_template"></a>

## Function `revoke_template`

Stop accepting new claims under a template. Facts already recorded are untouched; use
<code><a href="attestation.md#0x1_attestation_bump_issuer_epoch">attestation::bump_issuer_epoch</a></code> with issuer id 0, which invalidates every zkTLS
enrollment in the source, or a denial per subject for those.


<pre><code><b>public</b> entry <b>fun</b> <a href="zktls.md#0x1_zktls_revoke_template">revoke_template</a>(admin: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, source: <b>address</b>, template_id: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="zktls.md#0x1_zktls_revoke_template">revoke_template</a>(
    admin: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, source: <b>address</b>, template_id: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
) <b>acquires</b> <a href="zktls.md#0x1_zktls_Verifier">Verifier</a> {
    <b>assert</b>!(
        <a href="attestation.md#0x1_attestation_is_admin">attestation::is_admin</a>(address_of(admin), source),
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_permission_denied">error::permission_denied</a>(<a href="zktls.md#0x1_zktls_ENOT_ADMIN">ENOT_ADMIN</a>)
    );
    <a href="zktls.md#0x1_zktls_assert_initialized">assert_initialized</a>(source);
    <b>let</b> templates = &<b>mut</b> <a href="zktls.md#0x1_zktls_Verifier">Verifier</a>[source].templates;
    <b>assert</b>!(
        <a href="../../aptos-stdlib/doc/table.md#0x1_table_contains">table::contains</a>(templates, template_id),
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_not_found">error::not_found</a>(<a href="zktls.md#0x1_zktls_EUNKNOWN_TEMPLATE">EUNKNOWN_TEMPLATE</a>)
    );
    <a href="../../aptos-stdlib/doc/table.md#0x1_table_borrow_mut">table::borrow_mut</a>(templates, template_id).active = <b>false</b>;
    emit(<a href="zktls.md#0x1_zktls_RevokeTemplate">RevokeTemplate</a> { source, template_id });
}
</code></pre>



</details>

<a id="0x1_zktls_enroll"></a>

## Function `enroll`

Submit a verified claim about yourself. No issuer key is involved on this path: the trust
root is the attestor set plus the provider's TLS certificate, not an operator holding a key.

@param user The subject. Must be the address the claim names.
@param source The source to record the fact in.
@param template_id Registered, active template the claim was produced under.
@param claim Canonically serialized claim. Must contain the subject and the template id.
@param signatures One 65-byte recoverable ECDSA signature per attestor.
@param attestor_epoch Epoch whose attestor set signed.
@param nullifier 32 bytes binding one identity to one subject, or empty to skip. When set,
its lowercase hex must appear in the signed claim, so the attestors vouch for it.
@abort If the claim does not bind the subject (or the nullifier), a signer is unknown or
repeated, the attestor epoch is retired, the template is revoked, the claim was
already used, or fewer than the threshold signed.


<pre><code><b>public</b> entry <b>fun</b> <a href="zktls.md#0x1_zktls_enroll">enroll</a>(user: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, source: <b>address</b>, template_id: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, claim: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, signatures: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;&gt;, attestor_epoch: u64, nullifier: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="zktls.md#0x1_zktls_enroll">enroll</a>(
    user: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    source: <b>address</b>,
    template_id: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    claim: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    signatures: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;&gt;,
    attestor_epoch: u64,
    nullifier: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
) <b>acquires</b> <a href="zktls.md#0x1_zktls_Verifier">Verifier</a> {
    <b>let</b> subject = address_of(user);
    <b>let</b> (met, active, consumed, signers) =
        <a href="zktls.md#0x1_zktls_verify_claim_internal">verify_claim_internal</a>(
            source, template_id, subject, claim, signatures, attestor_epoch
        );
    <b>assert</b>!(active, <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_state">error::invalid_state</a>(<a href="zktls.md#0x1_zktls_ETEMPLATE_REVOKED">ETEMPLATE_REVOKED</a>));
    <b>assert</b>!(!consumed, <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_state">error::invalid_state</a>(<a href="zktls.md#0x1_zktls_ECLAIM_CONSUMED">ECLAIM_CONSUMED</a>));
    <b>assert</b>!(met, <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="zktls.md#0x1_zktls_EBELOW_THRESHOLD">EBELOW_THRESHOLD</a>));
    // A nullifier the attestors did not sign is just a user-chosen value and gives no sybil
    // resistance, so it must be carried by the claim itself.
    <b>assert</b>!(
        nullifier.is_empty() || <a href="zktls.md#0x1_zktls_contains_bytes">contains_bytes</a>(&claim, &<a href="zktls.md#0x1_zktls_lowercase_hex">lowercase_hex</a>(nullifier)),
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="zktls.md#0x1_zktls_EMALFORMED_CLAIM">EMALFORMED_CLAIM</a>)
    );

    <b>let</b> verifier = &<b>mut</b> <a href="zktls.md#0x1_zktls_Verifier">Verifier</a>[source];
    <a href="../../aptos-stdlib/doc/table.md#0x1_table_add">table::add</a>(&<b>mut</b> verifier.consumed, keccak256(claim), <b>true</b>);
    <b>let</b> template = *<a href="../../aptos-stdlib/doc/table.md#0x1_table_borrow">table::borrow</a>(&verifier.templates, template_id);

    <a href="attestation.md#0x1_attestation_record_verified_claim">attestation::record_verified_claim</a>(
        source,
        subject,
        template.grants_level,
        now_seconds() + template.ttl_secs,
        keccak256(claim),
        nullifier
    );

    emit(<a href="zktls.md#0x1_zktls_Enroll">Enroll</a> { source, subject, template_id, signers });
}
</code></pre>



</details>

<a id="0x1_zktls_verify_claim_internal"></a>

## Function `verify_claim_internal`

Structural checks abort. Returns whether the threshold is met, whether the template is
active, whether the claim was already consumed, and how many distinct attestors signed.


<pre><code><b>fun</b> <a href="zktls.md#0x1_zktls_verify_claim_internal">verify_claim_internal</a>(source: <b>address</b>, template_id: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, subject: <b>address</b>, claim: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, signatures: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;&gt;, attestor_epoch: u64): (bool, bool, bool, u64)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="zktls.md#0x1_zktls_verify_claim_internal">verify_claim_internal</a>(
    source: <b>address</b>,
    template_id: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    subject: <b>address</b>,
    claim: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    signatures: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;&gt;,
    attestor_epoch: u64
): (bool, bool, bool, u64) <b>acquires</b> <a href="zktls.md#0x1_zktls_Verifier">Verifier</a> {
    <a href="zktls.md#0x1_zktls_assert_initialized">assert_initialized</a>(source);
    <b>assert</b>!(
        signatures.length() &lt;= <a href="zktls.md#0x1_zktls_MAX_SIGNATURES">MAX_SIGNATURES</a>,
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="zktls.md#0x1_zktls_EBELOW_THRESHOLD">EBELOW_THRESHOLD</a>)
    );

    <b>let</b> verifier = &<a href="zktls.md#0x1_zktls_Verifier">Verifier</a>[source];
    <b>assert</b>!(
        <a href="../../aptos-stdlib/doc/table.md#0x1_table_contains">table::contains</a>(&verifier.templates, template_id),
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_not_found">error::not_found</a>(<a href="zktls.md#0x1_zktls_EUNKNOWN_TEMPLATE">EUNKNOWN_TEMPLATE</a>)
    );
    <b>assert</b>!(
        <a href="../../aptos-stdlib/doc/table.md#0x1_table_contains">table::contains</a>(&verifier.sets, attestor_epoch),
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_not_found">error::not_found</a>(<a href="zktls.md#0x1_zktls_EUNKNOWN_ATTESTOR_EPOCH">EUNKNOWN_ATTESTOR_EPOCH</a>)
    );
    <b>assert</b>!(
        <a href="zktls.md#0x1_zktls_epoch_accepted">epoch_accepted</a>(verifier, attestor_epoch),
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_state">error::invalid_state</a>(<a href="zktls.md#0x1_zktls_ERETIRED_ATTESTOR_EPOCH">ERETIRED_ATTESTOR_EPOCH</a>)
    );
    <b>let</b> set = <a href="../../aptos-stdlib/doc/table.md#0x1_table_borrow">table::borrow</a>(&verifier.sets, attestor_epoch);

    // The single most important check in this <b>module</b>, and the first thing an attacker will
    // look for. Without it a valid <a href="attestation.md#0x1_attestation">attestation</a> for one person is a valid <a href="attestation.md#0x1_attestation">attestation</a> for
    // whoever relays it, and one self-hosted endpoint mints unlimited verified addresses.
    <b>assert</b>!(
        <a href="zktls.md#0x1_zktls_claim_binds">claim_binds</a>(&claim, subject, &template_id),
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="zktls.md#0x1_zktls_EMALFORMED_CLAIM">EMALFORMED_CLAIM</a>)
    );

    <b>let</b> seen: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;&gt; = <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>[];
    signatures.for_each_ref(|signature| {
        <b>let</b> recovered = <a href="zktls.md#0x1_zktls_recover_attestor">recover_attestor</a>(claim, *signature);
        <b>assert</b>!(
            set.attestors.contains(&recovered),
            <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="zktls.md#0x1_zktls_EUNKNOWN_ATTESTOR">EUNKNOWN_ATTESTOR</a>)
        );
        <b>assert</b>!(
            !seen.contains(&recovered),
            <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="zktls.md#0x1_zktls_EDUPLICATE_SIGNER">EDUPLICATE_SIGNER</a>)
        );
        seen.push_back(recovered);
    });

    (
        seen.length() &gt;= set.threshold,
        <a href="../../aptos-stdlib/doc/table.md#0x1_table_borrow">table::borrow</a>(&verifier.templates, template_id).active,
        <a href="../../aptos-stdlib/doc/table.md#0x1_table_contains">table::contains</a>(&verifier.consumed, keccak256(claim)),
        seen.length()
    )
}
</code></pre>



</details>

<a id="0x1_zktls_epoch_accepted"></a>

## Function `epoch_accepted`



<pre><code><b>fun</b> <a href="zktls.md#0x1_zktls_epoch_accepted">epoch_accepted</a>(verifier: &<a href="zktls.md#0x1_zktls_Verifier">zktls::Verifier</a>, epoch: u64): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="zktls.md#0x1_zktls_epoch_accepted">epoch_accepted</a>(verifier: &<a href="zktls.md#0x1_zktls_Verifier">Verifier</a>, epoch: u64): bool {
    epoch != 0
        && (
            epoch == verifier.current_epoch
                || (
                    // Written <b>as</b> a subtraction so an epoch of u64::MAX cannot overflow.
                    epoch &lt; verifier.current_epoch
                        && verifier.current_epoch - epoch == 1
                        && now_seconds() &lt; verifier.previous_deadline_secs
                )
        )
}
</code></pre>



</details>

<a id="0x1_zktls_claim_binds"></a>

## Function `claim_binds`

Whether the claim names this subject and this template. The canonical serialization is the
provider's, so this checks containment of both binding values rather than parsing: a claim
that does not carry them is rejected outright.

Reclaim compatibility means reproducing its ASCII claim serialization exactly, down to the
lowercase hex identifier, the decimal formatting of its integer fields and the newline
joins. One wrong byte fails every proof, so this must be covered by pinned conformance
vectors from a real attestor rather than by a test written from the documentation.


<pre><code><b>fun</b> <a href="zktls.md#0x1_zktls_claim_binds">claim_binds</a>(claim: &<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, subject: <b>address</b>, template_id: &<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="zktls.md#0x1_zktls_claim_binds">claim_binds</a>(
    claim: &<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, subject: <b>address</b>, template_id: &<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
): bool {
    <a href="zktls.md#0x1_zktls_contains_bytes">contains_bytes</a>(claim, &<a href="zktls.md#0x1_zktls_lowercase_hex">lowercase_hex</a>(std::bcs::to_bytes(&subject)))
        && <a href="zktls.md#0x1_zktls_contains_bytes">contains_bytes</a>(claim, &<a href="zktls.md#0x1_zktls_lowercase_hex">lowercase_hex</a>(*template_id))
}
</code></pre>



</details>

<a id="0x1_zktls_contains_bytes"></a>

## Function `contains_bytes`

Whether <code>needle</code> appears in <code>haystack</code>.


<pre><code><b>fun</b> <a href="zktls.md#0x1_zktls_contains_bytes">contains_bytes</a>(haystack: &<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, needle: &<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="zktls.md#0x1_zktls_contains_bytes">contains_bytes</a>(haystack: &<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, needle: &<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): bool {
    <b>let</b> needle_length = needle.length();
    <b>let</b> haystack_length = haystack.length();
    <b>if</b> (needle_length == 0 || needle_length &gt; haystack_length) {
        <b>return</b> needle_length == 0
    };
    <b>let</b> start = 0;
    <b>while</b> (start + needle_length &lt;= haystack_length) {
        <b>let</b> offset = 0;
        <b>let</b> matched = <b>true</b>;
        <b>while</b> (offset &lt; needle_length && matched) {
            <b>if</b> (haystack[start + offset] != needle[offset]) {
                matched = <b>false</b>;
            };
            offset += 1;
        };
        <b>if</b> (matched) {
            <b>return</b> <b>true</b>
        };
        start += 1;
    };
    <b>false</b>
}
</code></pre>



</details>

<a id="0x1_zktls_lowercase_hex"></a>

## Function `lowercase_hex`

Lowercase hex encoding, matching the form attestor networks put in a claim.


<pre><code><b>fun</b> <a href="zktls.md#0x1_zktls_lowercase_hex">lowercase_hex</a>(bytes: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="zktls.md#0x1_zktls_lowercase_hex">lowercase_hex</a>(bytes: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt; {
    <b>let</b> digits = b"0123456789abcdef";
    <b>let</b> out = <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>[];
    bytes.for_each(|byte| {
        out.push_back(digits[((byte &gt;&gt; 4) <b>as</b> u64)]);
        out.push_back(digits[((byte & 0x0f) <b>as</b> u64)]);
    });
    out
}
</code></pre>



</details>

<a id="0x1_zktls_decimal_bytes"></a>

## Function `decimal_bytes`

Decimal ASCII encoding of a length, for the Ethereum signing prefix.


<pre><code><b>fun</b> <a href="zktls.md#0x1_zktls_decimal_bytes">decimal_bytes</a>(value: u64): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="zktls.md#0x1_zktls_decimal_bytes">decimal_bytes</a>(value: u64): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt; {
    <b>if</b> (value == 0) {
        <b>return</b> b"0"
    };
    <b>let</b> digits = <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>[];
    <b>let</b> remaining = value;
    <b>while</b> (remaining &gt; 0) {
        digits.push_back(((remaining % 10) <b>as</b> u8) + 48);
        remaining /= 10;
    };
    digits.reverse();
    digits
}
</code></pre>



</details>

<a id="0x1_zktls_assert_initialized"></a>

## Function `assert_initialized`



<pre><code><b>fun</b> <a href="zktls.md#0x1_zktls_assert_initialized">assert_initialized</a>(source: <b>address</b>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="zktls.md#0x1_zktls_assert_initialized">assert_initialized</a>(source: <b>address</b>) {
    <b>assert</b>!(<b>exists</b>&lt;<a href="zktls.md#0x1_zktls_Verifier">Verifier</a>&gt;(source), <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_not_found">error::not_found</a>(<a href="zktls.md#0x1_zktls_ENOT_INITIALIZED">ENOT_INITIALIZED</a>));
}
</code></pre>



</details>

<a id="@Specification_1"></a>

## Specification




<a id="high-level-req"></a>

### High-level Requirements

<table>
<tr>
<th>No.</th><th>Requirement</th><th>Criticality</th><th>Implementation</th><th>Enforcement</th>
</tr>

<tr>
<td>1</td>
<td>Only an admin of the source can configure its verifier: create it, register attestor sets, and register or revoke templates.</td>
<td>Critical</td>
<td>initialize, set_attestor_set, register_template and revoke_template all assert attestation::is_admin before touching the Verifier.</td>
<td>Formally verified via <a href="#high-level-req-1">set_attestor_set</a> and audited in unit tests for the remaining entry functions.</td>
</tr>

<tr>
<td>2</td>
<td>An attestor set has a threshold of at least one and at most its size, and each rotation moves to a new epoch that is one higher than the last.</td>
<td>High</td>
<td>set_attestor_set asserts 1 <= required <= count, increments current_epoch and adds the set under the new epoch.</td>
<td>Formally verified via <a href="#high-level-req-2">set_attestor_set</a>.</td>
</tr>

<tr>
<td>3</td>
<td>Only the current attestor epoch verifies, plus the immediately previous one until the grace deadline set at rotation. A rotated-away set stops verifying once the deadline passes, and an older one stops immediately.</td>
<td>Critical</td>
<td>epoch_accepted accepts current_epoch, or current_epoch - 1 while now < previous_deadline_secs. verify_claim_internal asserts it.</td>
<td>Formally verified via <a href="#high-level-req-3.1">epoch_accepted</a> and <a href="#high-level-req-3.2">enroll</a>.</td>
</tr>

<tr>
<td>4</td>
<td>A signed claim is single use. Once a claim has been used to enroll it can never enroll again, so it can neither refresh an expiry indefinitely nor undo a revocation.</td>
<td>Critical</td>
<td>enroll records keccak256(claim) in Verifier.consumed and aborts if it is already present. verify_claim returns false for a consumed claim.</td>
<td>Formally verified via <a href="#high-level-req-4.1">enroll</a> and <a href="#high-level-req-4.2">verify_claim</a>.</td>
</tr>

<tr>
<td>5</td>
<td>A claim under a revoked template never enrolls, and verify_claim never reports it as valid.</td>
<td>High</td>
<td>verify_claim_internal returns the template's active flag; enroll aborts with ETEMPLATE_REVOKED and verify_claim folds it into its result.</td>
<td>Formally verified via <a href="#high-level-req-5.1">enroll</a> and <a href="#high-level-req-5.2">verify_claim</a>.</td>
</tr>

<tr>
<td>6</td>
<td>A claim is bound to the subject submitting it and to the template it is redeemed under, and a non-empty nullifier must be carried by the signed claim. A valid attestation for one person is not an attestation for whoever relays it.</td>
<td>Critical</td>
<td>claim_binds checks that the lowercase hex of bcs(subject) and of template_id both appear in the claim, and enroll checks the same for the nullifier.</td>
<td>Audited in unit tests (test_claim_for_another_subject_fails, test_claim_under_another_template_fails, test_nullifier_not_in_claim_fails). The byte-search loops are not amenable to the prover.</td>
</tr>

<tr>
<td>7</td>
<td>Distinct attestors, each a member of the epoch's set, must sign, and at least threshold of them.</td>
<td>Critical</td>
<td>verify_claim_internal recovers each signer with secp256k1::ecdsa_recover, aborts on a signer outside the set or a repeated signer, and compares the distinct count with the threshold.</td>
<td>Audited in unit tests with fixed secp256k1 vectors. The recovery loop runs inside for_each_ref, which the prover havocs.</td>
</tr>

</table>



<a id="module-level-spec"></a>

### Module-level Specification


<pre><code><b>pragma</b> verify = <b>true</b>;
<b>pragma</b> aborts_if_is_strict = <b>false</b>;
</code></pre>




<a id="0x1_zktls_spec_now"></a>


<pre><code><b>fun</b> <a href="zktls.md#0x1_zktls_spec_now">spec_now</a>(): u64 {
   aptos_framework::timestamp::spec_now_seconds()
}
</code></pre>




<a id="0x1_zktls_spec_epoch_accepted"></a>


<pre><code><b>fun</b> <a href="zktls.md#0x1_zktls_spec_epoch_accepted">spec_epoch_accepted</a>(verifier: <a href="zktls.md#0x1_zktls_Verifier">Verifier</a>, epoch: u64): bool {
   epoch != 0
       && (epoch == verifier.current_epoch
           || (epoch &lt; verifier.current_epoch
               && verifier.current_epoch - epoch == 1
               && <a href="zktls.md#0x1_zktls_spec_now">spec_now</a>() &lt; verifier.previous_deadline_secs))
}
</code></pre>



<a id="@Specification_1_is_initialized"></a>

### Function `is_initialized`


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="zktls.md#0x1_zktls_is_initialized">is_initialized</a>(source: <b>address</b>): bool
</code></pre>




<pre><code><b>aborts_if</b> <b>false</b>;
<b>ensures</b> result == <b>exists</b>&lt;<a href="zktls.md#0x1_zktls_Verifier">Verifier</a>&gt;(source);
</code></pre>



<a id="@Specification_1_current_epoch"></a>

### Function `current_epoch`


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="zktls.md#0x1_zktls_current_epoch">current_epoch</a>(source: <b>address</b>): u64
</code></pre>




<pre><code><b>aborts_if</b> !<b>exists</b>&lt;<a href="zktls.md#0x1_zktls_Verifier">Verifier</a>&gt;(source);
<b>ensures</b> result == <b>global</b>&lt;<a href="zktls.md#0x1_zktls_Verifier">Verifier</a>&gt;(source).current_epoch;
</code></pre>



<a id="@Specification_1_threshold"></a>

### Function `threshold`


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="zktls.md#0x1_zktls_threshold">threshold</a>(source: <b>address</b>, epoch: u64): u64
</code></pre>




<pre><code><b>aborts_if</b> !<b>exists</b>&lt;<a href="zktls.md#0x1_zktls_Verifier">Verifier</a>&gt;(source);
<b>aborts_if</b> !<a href="../../aptos-stdlib/doc/table.md#0x1_table_spec_contains">table::spec_contains</a>(<b>global</b>&lt;<a href="zktls.md#0x1_zktls_Verifier">Verifier</a>&gt;(source).sets, epoch);
<b>ensures</b> result == <a href="../../aptos-stdlib/doc/table.md#0x1_table_spec_get">table::spec_get</a>(<b>global</b>&lt;<a href="zktls.md#0x1_zktls_Verifier">Verifier</a>&gt;(source).sets, epoch).threshold;
</code></pre>



<a id="@Specification_1_is_epoch_accepted"></a>

### Function `is_epoch_accepted`


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="zktls.md#0x1_zktls_is_epoch_accepted">is_epoch_accepted</a>(source: <b>address</b>, epoch: u64): bool
</code></pre>




<pre><code><b>pragma</b> aborts_if_is_partial;
<b>ensures</b> !<b>exists</b>&lt;<a href="zktls.md#0x1_zktls_Verifier">Verifier</a>&gt;(source) ==&gt; !result;
<b>ensures</b> <b>exists</b>&lt;<a href="zktls.md#0x1_zktls_Verifier">Verifier</a>&gt;(source) ==&gt; result == <a href="zktls.md#0x1_zktls_spec_epoch_accepted">spec_epoch_accepted</a>(<b>global</b>&lt;<a href="zktls.md#0x1_zktls_Verifier">Verifier</a>&gt;(source), epoch);
</code></pre>



<a id="@Specification_1_is_claim_consumed"></a>

### Function `is_claim_consumed`


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="zktls.md#0x1_zktls_is_claim_consumed">is_claim_consumed</a>(source: <b>address</b>, claim: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): bool
</code></pre>




<pre><code><b>aborts_if</b> <b>false</b>;
<b>ensures</b> result == (<b>exists</b>&lt;<a href="zktls.md#0x1_zktls_Verifier">Verifier</a>&gt;(source)
    && <a href="../../aptos-stdlib/doc/table.md#0x1_table_spec_contains">table::spec_contains</a>(
        <b>global</b>&lt;<a href="zktls.md#0x1_zktls_Verifier">Verifier</a>&gt;(source).consumed, aptos_std::aptos_hash::spec_keccak256(claim)
    ));
</code></pre>



<a id="@Specification_1_is_template_active"></a>

### Function `is_template_active`


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="zktls.md#0x1_zktls_is_template_active">is_template_active</a>(source: <b>address</b>, template_id: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): bool
</code></pre>




<pre><code><b>aborts_if</b> <b>false</b>;
<b>let</b> templates = <b>global</b>&lt;<a href="zktls.md#0x1_zktls_Verifier">Verifier</a>&gt;(source).templates;
<b>ensures</b> result == (<b>exists</b>&lt;<a href="zktls.md#0x1_zktls_Verifier">Verifier</a>&gt;(source)
    && <a href="../../aptos-stdlib/doc/table.md#0x1_table_spec_contains">table::spec_contains</a>(templates, template_id)
    && <a href="../../aptos-stdlib/doc/table.md#0x1_table_spec_get">table::spec_get</a>(templates, template_id).active);
</code></pre>



<a id="@Specification_1_verify_claim"></a>

### Function `verify_claim`


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="zktls.md#0x1_zktls_verify_claim">verify_claim</a>(source: <b>address</b>, template_id: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, subject: <b>address</b>, claim: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, signatures: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;&gt;, attestor_epoch: u64): bool
</code></pre>




<pre><code><b>pragma</b> aborts_if_is_partial;
<b>aborts_if</b> !<b>exists</b>&lt;<a href="zktls.md#0x1_zktls_Verifier">Verifier</a>&gt;(source);
<b>let</b> verifier = <b>global</b>&lt;<a href="zktls.md#0x1_zktls_Verifier">Verifier</a>&gt;(source);
// This enforces <a id="high-level-req-4.2" href="#high-level-req">high-level requirement 4</a>:
<b>ensures</b> result ==&gt; !<a href="../../aptos-stdlib/doc/table.md#0x1_table_spec_contains">table::spec_contains</a>(verifier.consumed, aptos_std::aptos_hash::spec_keccak256(claim));
// This enforces <a id="high-level-req-5.2" href="#high-level-req">high-level requirement 5</a>:
<b>ensures</b> result ==&gt; <a href="../../aptos-stdlib/doc/table.md#0x1_table_spec_get">table::spec_get</a>(verifier.templates, template_id).active;
<b>ensures</b> result ==&gt; <a href="zktls.md#0x1_zktls_spec_epoch_accepted">spec_epoch_accepted</a>(verifier, attestor_epoch);
</code></pre>



<a id="@Specification_1_set_attestor_set"></a>

### Function `set_attestor_set`


<pre><code><b>public</b> entry <b>fun</b> <a href="zktls.md#0x1_zktls_set_attestor_set">set_attestor_set</a>(admin: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, source: <b>address</b>, attestor_addresses: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;&gt;, required: u64, previous_grace_secs: u64)
</code></pre>




<pre><code><b>pragma</b> aborts_if_is_partial;
// This enforces <a id="high-level-req-1" href="#high-level-req">high-level requirement 1</a>:
<b>aborts_if</b> !aptos_framework::attestation::spec_is_source(source);
<b>aborts_if</b> !contains(<b>global</b>&lt;aptos_framework::attestation::Source&gt;(source).admins, address_of(admin));
<b>aborts_if</b> !<b>exists</b>&lt;<a href="zktls.md#0x1_zktls_Verifier">Verifier</a>&gt;(source);
// This enforces <a id="high-level-req-2" href="#high-level-req">high-level requirement 2</a>:
<b>aborts_if</b> required &lt; 1 || required &gt; len(attestor_addresses);
<b>let</b> <b>post</b> verifier = <b>global</b>&lt;<a href="zktls.md#0x1_zktls_Verifier">Verifier</a>&gt;(source);
<b>ensures</b> verifier.current_epoch == <b>old</b>(<b>global</b>&lt;<a href="zktls.md#0x1_zktls_Verifier">Verifier</a>&gt;(source).current_epoch) + 1;
<b>ensures</b> <a href="../../aptos-stdlib/doc/table.md#0x1_table_spec_contains">table::spec_contains</a>(verifier.sets, verifier.current_epoch);
<b>ensures</b> <a href="../../aptos-stdlib/doc/table.md#0x1_table_spec_get">table::spec_get</a>(verifier.sets, verifier.current_epoch).threshold == required;
<b>ensures</b> <a href="../../aptos-stdlib/doc/table.md#0x1_table_spec_get">table::spec_get</a>(verifier.sets, verifier.current_epoch).attestors == attestor_addresses;
<b>ensures</b> verifier.previous_deadline_secs &gt;= <a href="zktls.md#0x1_zktls_spec_now">spec_now</a>();
<b>ensures</b> verifier.consumed == <b>old</b>(<b>global</b>&lt;<a href="zktls.md#0x1_zktls_Verifier">Verifier</a>&gt;(source).consumed);
<b>ensures</b> verifier.templates == <b>old</b>(<b>global</b>&lt;<a href="zktls.md#0x1_zktls_Verifier">Verifier</a>&gt;(source).templates);
</code></pre>



<a id="@Specification_1_register_template"></a>

### Function `register_template`


<pre><code><b>public</b> entry <b>fun</b> <a href="zktls.md#0x1_zktls_register_template">register_template</a>(admin: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, source: <b>address</b>, template_id: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, grants_level: u8, ttl_secs: u64)
</code></pre>




<pre><code><b>pragma</b> aborts_if_is_partial;
<b>aborts_if</b> !<b>exists</b>&lt;<a href="zktls.md#0x1_zktls_Verifier">Verifier</a>&gt;(source);
<b>let</b> <b>post</b> template = <a href="../../aptos-stdlib/doc/table.md#0x1_table_spec_get">table::spec_get</a>(<b>global</b>&lt;<a href="zktls.md#0x1_zktls_Verifier">Verifier</a>&gt;(source).templates, template_id);
<b>ensures</b> template.active;
<b>ensures</b> template.grants_level == grants_level;
<b>ensures</b> template.ttl_secs == ttl_secs;
</code></pre>



<a id="@Specification_1_revoke_template"></a>

### Function `revoke_template`


<pre><code><b>public</b> entry <b>fun</b> <a href="zktls.md#0x1_zktls_revoke_template">revoke_template</a>(admin: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, source: <b>address</b>, template_id: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;)
</code></pre>




<pre><code><b>pragma</b> aborts_if_is_partial;
<b>aborts_if</b> !<b>exists</b>&lt;<a href="zktls.md#0x1_zktls_Verifier">Verifier</a>&gt;(source);
<b>aborts_if</b> !<a href="../../aptos-stdlib/doc/table.md#0x1_table_spec_contains">table::spec_contains</a>(<b>global</b>&lt;<a href="zktls.md#0x1_zktls_Verifier">Verifier</a>&gt;(source).templates, template_id);
<b>ensures</b> !<a href="../../aptos-stdlib/doc/table.md#0x1_table_spec_get">table::spec_get</a>(<b>global</b>&lt;<a href="zktls.md#0x1_zktls_Verifier">Verifier</a>&gt;(source).templates, template_id).active;
<b>ensures</b> <b>global</b>&lt;<a href="zktls.md#0x1_zktls_Verifier">Verifier</a>&gt;(source).consumed == <b>old</b>(<b>global</b>&lt;<a href="zktls.md#0x1_zktls_Verifier">Verifier</a>&gt;(source).consumed);
</code></pre>



<a id="@Specification_1_enroll"></a>

### Function `enroll`


<pre><code><b>public</b> entry <b>fun</b> <a href="zktls.md#0x1_zktls_enroll">enroll</a>(user: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, source: <b>address</b>, template_id: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, claim: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, signatures: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;&gt;, attestor_epoch: u64, nullifier: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;)
</code></pre>




<pre><code><b>pragma</b> aborts_if_is_partial;
<b>let</b> verifier = <b>global</b>&lt;<a href="zktls.md#0x1_zktls_Verifier">Verifier</a>&gt;(source);
<b>let</b> digest = aptos_std::aptos_hash::spec_keccak256(claim);
<b>aborts_if</b> !<b>exists</b>&lt;<a href="zktls.md#0x1_zktls_Verifier">Verifier</a>&gt;(source);
<b>aborts_if</b> !<a href="../../aptos-stdlib/doc/table.md#0x1_table_spec_contains">table::spec_contains</a>(verifier.templates, template_id);
<b>aborts_if</b> !<a href="../../aptos-stdlib/doc/table.md#0x1_table_spec_contains">table::spec_contains</a>(verifier.sets, attestor_epoch);
// This enforces <a id="high-level-req-3.2" href="#high-level-req">high-level requirement 3</a>:
<b>aborts_if</b> !<a href="zktls.md#0x1_zktls_spec_epoch_accepted">spec_epoch_accepted</a>(verifier, attestor_epoch);
// This enforces <a id="high-level-req-5.1" href="#high-level-req">high-level requirement 5</a>:
<b>aborts_if</b> !<a href="../../aptos-stdlib/doc/table.md#0x1_table_spec_get">table::spec_get</a>(verifier.templates, template_id).active;
// This enforces <a id="high-level-req-4.1" href="#high-level-req">high-level requirement 4</a>:
<b>aborts_if</b> <a href="../../aptos-stdlib/doc/table.md#0x1_table_spec_contains">table::spec_contains</a>(verifier.consumed, digest);
<b>ensures</b> <a href="../../aptos-stdlib/doc/table.md#0x1_table_spec_contains">table::spec_contains</a>(<b>global</b>&lt;<a href="zktls.md#0x1_zktls_Verifier">Verifier</a>&gt;(source).consumed, digest);
<b>ensures</b> <b>global</b>&lt;<a href="zktls.md#0x1_zktls_Verifier">Verifier</a>&gt;(source).sets == <b>old</b>(<b>global</b>&lt;<a href="zktls.md#0x1_zktls_Verifier">Verifier</a>&gt;(source).sets);
<b>ensures</b> <b>global</b>&lt;<a href="zktls.md#0x1_zktls_Verifier">Verifier</a>&gt;(source).templates == <b>old</b>(<b>global</b>&lt;<a href="zktls.md#0x1_zktls_Verifier">Verifier</a>&gt;(source).templates);
</code></pre>



<a id="@Specification_1_epoch_accepted"></a>

### Function `epoch_accepted`


<pre><code><b>fun</b> <a href="zktls.md#0x1_zktls_epoch_accepted">epoch_accepted</a>(verifier: &<a href="zktls.md#0x1_zktls_Verifier">zktls::Verifier</a>, epoch: u64): bool
</code></pre>




<pre><code><b>pragma</b> aborts_if_is_partial;
// This enforces <a id="high-level-req-3.1" href="#high-level-req">high-level requirement 3</a>:
<b>ensures</b> result == <a href="zktls.md#0x1_zktls_spec_epoch_accepted">spec_epoch_accepted</a>(verifier, epoch);
</code></pre>


[move-book]: https://aptos.dev/move/book/SUMMARY
