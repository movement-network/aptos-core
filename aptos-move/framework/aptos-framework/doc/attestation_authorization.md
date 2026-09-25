
<a id="0x1_attestation_authorization"></a>

# Module `0x1::attestation_authorization`

Per-action authorization: a short-lived signed capability that satisfies one step-up decision
for one action.

The point is not freshness, although a sixty-second capability does make revocation trivial,
since revoking means declining to issue the next one and no denylist, epoch or status list is
involved on this path. The point is the AUDIT RECORD. A view call leaves no trace and a
transaction-prologue rejection is a discard with no ledger record at all, so a design built only
on persistent facts cannot answer "prove this address was authorized at the moment this exact
transaction executed, and show the basis". An authorization is a transaction argument, so it is
in the ledger permanently, naming the policy, the action and the moment.

The symmetric cost, stated because it is a disclosure decision rather than an oversight:
everything an authorization names is public forever. That is why the amount is committed as a
BUCKET rather than a value, so the authorizer commits to a ceiling instead of publishing a
customer's exact transaction size.

Replay protection is a nonce table. The clever alternative is to bind the capability to the
account's sequence number, which costs no storage because the number advances when the
transaction lands, but orderless transactions carry a <code>Nonce</code> replay protector instead and
leave the sequence number untouched, so a capability bound to it would stay reusable there.
Orderless transactions are in this fork's genesis default features, so the clever version is a
footgun and this module does not use it.

Batched pre-authorization needs no separate mechanism: a batch is N authorizations with distinct
nonces over the same window, which drops the liveness dependency on the authorizer from
per-transaction to per-window. This note exists so nobody builds a second code path for it.


-  [Resource `Nonces`](#0x1_attestation_authorization_Nonces)
-  [Struct `ConsumeAuthorization`](#0x1_attestation_authorization_ConsumeAuthorization)
-  [Struct `PruneNonces`](#0x1_attestation_authorization_PruneNonces)
-  [Constants](#@Constants_0)
-  [Function `is_initialized`](#0x1_attestation_authorization_is_initialized)
-  [Function `is_nonce_used`](#0x1_attestation_authorization_is_nonce_used)
-  [Function `bucket_ceiling`](#0x1_attestation_authorization_bucket_ceiling)
-  [Function `authorization_message`](#0x1_attestation_authorization_authorization_message)
-  [Function `initialize`](#0x1_attestation_authorization_initialize)
-  [Function `verify_and_consume`](#0x1_attestation_authorization_verify_and_consume)
-  [Function `prune_nonces`](#0x1_attestation_authorization_prune_nonces)
-  [Function `decode`](#0x1_attestation_authorization_decode)
-  [Function `read_u64_le`](#0x1_attestation_authorization_read_u64_le)
-  [Specification](#@Specification_1)
    -  [High-level Requirements](#high-level-req)
    -  [Module-level Specification](#module-level-spec)
    -  [Function `is_initialized`](#@Specification_1_is_initialized)
    -  [Function `is_nonce_used`](#@Specification_1_is_nonce_used)
    -  [Function `bucket_ceiling`](#@Specification_1_bucket_ceiling)
    -  [Function `authorization_message`](#@Specification_1_authorization_message)
    -  [Function `initialize`](#@Specification_1_initialize)
    -  [Function `verify_and_consume`](#@Specification_1_verify_and_consume)
    -  [Function `prune_nonces`](#@Specification_1_prune_nonces)


<pre><code><b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/bcs.md#0x1_bcs">0x1::bcs</a>;
<b>use</b> <a href="chain_id.md#0x1_chain_id">0x1::chain_id</a>;
<b>use</b> <a href="../../aptos-stdlib/doc/ed25519.md#0x1_ed25519">0x1::ed25519</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error">0x1::error</a>;
<b>use</b> <a href="event.md#0x1_event">0x1::event</a>;
<b>use</b> <a href="../../aptos-stdlib/doc/table.md#0x1_table">0x1::table</a>;
<b>use</b> <a href="timestamp.md#0x1_timestamp">0x1::timestamp</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">0x1::vector</a>;
</code></pre>



<a id="0x1_attestation_authorization_Nonces"></a>

## Resource `Nonces`

Consumed nonces, stored at the policy's address. The value is the expiry, retained so an
entry can be pruned once it can no longer be replayed.


<pre><code><b>struct</b> <a href="attestation_authorization.md#0x1_attestation_authorization_Nonces">Nonces</a> <b>has</b> key
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>used: <a href="../../aptos-stdlib/doc/table.md#0x1_table_Table">table::Table</a>&lt;<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, u64&gt;</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_attestation_authorization_ConsumeAuthorization"></a>

## Struct `ConsumeAuthorization`



<pre><code>#[<a href="event.md#0x1_event">event</a>]
<b>struct</b> <a href="attestation_authorization.md#0x1_attestation_authorization_ConsumeAuthorization">ConsumeAuthorization</a> <b>has</b> drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>policy: <b>address</b></code>
</dt>
<dd>

</dd>
<dt>
<code>subject: <b>address</b></code>
</dt>
<dd>

</dd>
<dt>
<code>action: u8</code>
</dt>
<dd>

</dd>
<dt>
<code>amount_bucket: u8</code>
</dt>
<dd>

</dd>
<dt>
<code>nonce: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>issued_at_secs: u64</code>
</dt>
<dd>

</dd>
<dt>
<code>expires_at_secs: u64</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_attestation_authorization_PruneNonces"></a>

## Struct `PruneNonces`



<pre><code>#[<a href="event.md#0x1_event">event</a>]
<b>struct</b> <a href="attestation_authorization.md#0x1_attestation_authorization_PruneNonces">PruneNonces</a> <b>has</b> drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>policy: <b>address</b></code>
</dt>
<dd>

</dd>
<dt>
<code>released: u64</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="@Constants_0"></a>

## Constants


<a id="0x1_attestation_authorization_EEXPIRED"></a>

The authorization has expired.


<pre><code><b>const</b> <a href="attestation_authorization.md#0x1_attestation_authorization_EEXPIRED">EEXPIRED</a>: u64 = 3;
</code></pre>



<a id="0x1_attestation_authorization_EBAD_SIGNATURE"></a>

The authorizer signature did not verify.


<pre><code><b>const</b> <a href="attestation_authorization.md#0x1_attestation_authorization_EBAD_SIGNATURE">EBAD_SIGNATURE</a>: u64 = 2;
</code></pre>



<a id="0x1_attestation_authorization_EBATCH_TOO_LARGE"></a>

The batch exceeds MAX_PRUNE.


<pre><code><b>const</b> <a href="attestation_authorization.md#0x1_attestation_authorization_EBATCH_TOO_LARGE">EBATCH_TOO_LARGE</a>: u64 = 12;
</code></pre>



<a id="0x1_attestation_authorization_PUBKEY_LENGTH"></a>

Required length of an ed25519 public key.


<pre><code><b>const</b> <a href="attestation_authorization.md#0x1_attestation_authorization_PUBKEY_LENGTH">PUBKEY_LENGTH</a>: u64 = 32;
</code></pre>



<a id="0x1_attestation_authorization_SIGNATURE_LENGTH"></a>

Required length of an ed25519 signature.


<pre><code><b>const</b> <a href="attestation_authorization.md#0x1_attestation_authorization_SIGNATURE_LENGTH">SIGNATURE_LENGTH</a>: u64 = 64;
</code></pre>



<a id="0x1_attestation_authorization_DOMAIN_AUTHORIZE"></a>

Domain separator for the signed message, so an authorization cannot be reinterpreted as any
other signed payload.


<pre><code><b>const</b> <a href="attestation_authorization.md#0x1_attestation_authorization_DOMAIN_AUTHORIZE">DOMAIN_AUTHORIZE</a>: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt; = [97, 112, 116, 111, 115, 95, 102, 114, 97, 109, 101, 119, 111, 114, 107, 58, 58, 97, 116, 116, 101, 115, 116, 97, 116, 105, 111, 110, 95, 97, 117, 116, 104, 111, 114, 105, 122, 97, 116, 105, 111, 110, 58, 58, 65, 85, 84, 72];
</code></pre>



<a id="0x1_attestation_authorization_EAMOUNT_OVER_BUCKET"></a>

The amount exceeds the ceiling the authorizer committed to.


<pre><code><b>const</b> <a href="attestation_authorization.md#0x1_attestation_authorization_EAMOUNT_OVER_BUCKET">EAMOUNT_OVER_BUCKET</a>: u64 = 5;
</code></pre>



<a id="0x1_attestation_authorization_EBAD_BUCKET"></a>

The bucket exponent exceeds MAX_BUCKET.


<pre><code><b>const</b> <a href="attestation_authorization.md#0x1_attestation_authorization_EBAD_BUCKET">EBAD_BUCKET</a>: u64 = 10;
</code></pre>



<a id="0x1_attestation_authorization_EBAD_NONCE_LENGTH"></a>

A nonce must be exactly 32 bytes.


<pre><code><b>const</b> <a href="attestation_authorization.md#0x1_attestation_authorization_EBAD_NONCE_LENGTH">EBAD_NONCE_LENGTH</a>: u64 = 8;
</code></pre>



<a id="0x1_attestation_authorization_EBAD_SIGNATURE_LENGTH"></a>

A signature must be exactly 64 bytes.


<pre><code><b>const</b> <a href="attestation_authorization.md#0x1_attestation_authorization_EBAD_SIGNATURE_LENGTH">EBAD_SIGNATURE_LENGTH</a>: u64 = 9;
</code></pre>



<a id="0x1_attestation_authorization_ENONCE_USED"></a>

This nonce has already been consumed.


<pre><code><b>const</b> <a href="attestation_authorization.md#0x1_attestation_authorization_ENONCE_USED">ENONCE_USED</a>: u64 = 4;
</code></pre>



<a id="0x1_attestation_authorization_ENOT_INITIALIZED"></a>

This policy has no nonce store, so it was not created by <code><a href="attestation_policy.md#0x1_attestation_policy">attestation_policy</a></code>.


<pre><code><b>const</b> <a href="attestation_authorization.md#0x1_attestation_authorization_ENOT_INITIALIZED">ENOT_INITIALIZED</a>: u64 = 1;
</code></pre>



<a id="0x1_attestation_authorization_ENOT_YET_VALID"></a>

The authorization was issued in the future.


<pre><code><b>const</b> <a href="attestation_authorization.md#0x1_attestation_authorization_ENOT_YET_VALID">ENOT_YET_VALID</a>: u64 = 11;
</code></pre>



<a id="0x1_attestation_authorization_ENO_AUTHORIZER"></a>

The policy has no authorizer key configured.


<pre><code><b>const</b> <a href="attestation_authorization.md#0x1_attestation_authorization_ENO_AUTHORIZER">ENO_AUTHORIZER</a>: u64 = 7;
</code></pre>



<a id="0x1_attestation_authorization_ETTL_TOO_LONG"></a>

The authorization's validity window is longer than the policy permits.


<pre><code><b>const</b> <a href="attestation_authorization.md#0x1_attestation_authorization_ETTL_TOO_LONG">ETTL_TOO_LONG</a>: u64 = 6;
</code></pre>



<a id="0x1_attestation_authorization_MAX_BUCKET"></a>

Largest bucket exponent. Bucket b covers amounts up to 10^b, saturating at u64 max.


<pre><code><b>const</b> <a href="attestation_authorization.md#0x1_attestation_authorization_MAX_BUCKET">MAX_BUCKET</a>: u8 = 20;
</code></pre>



<a id="0x1_attestation_authorization_MAX_PRUNE"></a>

Largest number of nonces one prune call may release.


<pre><code><b>const</b> <a href="attestation_authorization.md#0x1_attestation_authorization_MAX_PRUNE">MAX_PRUNE</a>: u64 = 1000;
</code></pre>



<a id="0x1_attestation_authorization_NONCE_LENGTH"></a>

Required length of a nonce.


<pre><code><b>const</b> <a href="attestation_authorization.md#0x1_attestation_authorization_NONCE_LENGTH">NONCE_LENGTH</a>: u64 = 32;
</code></pre>



<a id="0x1_attestation_authorization_is_initialized"></a>

## Function `is_initialized`



<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="attestation_authorization.md#0x1_attestation_authorization_is_initialized">is_initialized</a>(policy: <b>address</b>): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="attestation_authorization.md#0x1_attestation_authorization_is_initialized">is_initialized</a>(policy: <b>address</b>): bool {
    <b>exists</b>&lt;<a href="attestation_authorization.md#0x1_attestation_authorization_Nonces">Nonces</a>&gt;(policy)
}
</code></pre>



</details>

<a id="0x1_attestation_authorization_is_nonce_used"></a>

## Function `is_nonce_used`



<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="attestation_authorization.md#0x1_attestation_authorization_is_nonce_used">is_nonce_used</a>(policy: <b>address</b>, nonce: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="attestation_authorization.md#0x1_attestation_authorization_is_nonce_used">is_nonce_used</a>(policy: <b>address</b>, nonce: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): bool <b>acquires</b> <a href="attestation_authorization.md#0x1_attestation_authorization_Nonces">Nonces</a> {
    <b>exists</b>&lt;<a href="attestation_authorization.md#0x1_attestation_authorization_Nonces">Nonces</a>&gt;(policy) && <a href="../../aptos-stdlib/doc/table.md#0x1_table_contains">table::contains</a>(&<a href="attestation_authorization.md#0x1_attestation_authorization_Nonces">Nonces</a>[policy].used, nonce)
}
</code></pre>



</details>

<a id="0x1_attestation_authorization_bucket_ceiling"></a>

## Function `bucket_ceiling`

Ceiling a bucket exponent commits to: 10^bucket, saturating at u64 max.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="attestation_authorization.md#0x1_attestation_authorization_bucket_ceiling">bucket_ceiling</a>(bucket: u8): u64
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="attestation_authorization.md#0x1_attestation_authorization_bucket_ceiling">bucket_ceiling</a>(bucket: u8): u64 {
    <b>assert</b>!(bucket &lt;= <a href="attestation_authorization.md#0x1_attestation_authorization_MAX_BUCKET">MAX_BUCKET</a>, <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="attestation_authorization.md#0x1_attestation_authorization_EBAD_BUCKET">EBAD_BUCKET</a>));
    <b>let</b> ceiling = 1u64;
    <b>let</b> step = 0;
    <b>while</b> (step &lt; bucket) {
        // 10^20 overflows u64, so saturate rather than <b>abort</b>.
        <b>if</b> (ceiling &gt; 1844674407370955161) {
            <b>return</b> 18446744073709551615
        };
        ceiling *= 10;
        step += 1;
    };
    ceiling
}
</code></pre>



</details>

<a id="0x1_attestation_authorization_authorization_message"></a>

## Function `authorization_message`

The message an authorizer signs. Published so an authorizing service can be implemented in
any language without reading this module.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="attestation_authorization.md#0x1_attestation_authorization_authorization_message">authorization_message</a>(policy: <b>address</b>, subject: <b>address</b>, action: u8, amount_bucket: u8, nonce: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, issued_at_secs: u64, expires_at_secs: u64): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="attestation_authorization.md#0x1_attestation_authorization_authorization_message">authorization_message</a>(
    policy: <b>address</b>,
    subject: <b>address</b>,
    action: u8,
    amount_bucket: u8,
    nonce: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    issued_at_secs: u64,
    expires_at_secs: u64
): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt; {
    <b>let</b> message = <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>[];
    message.append(<a href="attestation_authorization.md#0x1_attestation_authorization_DOMAIN_AUTHORIZE">DOMAIN_AUTHORIZE</a>);
    message.append(to_bytes(&<a href="chain_id.md#0x1_chain_id_get">chain_id::get</a>()));
    message.append(to_bytes(&policy));
    message.append(to_bytes(&subject));
    message.append(to_bytes(&action));
    message.append(to_bytes(&amount_bucket));
    message.append(to_bytes(&nonce));
    message.append(to_bytes(&issued_at_secs));
    message.append(to_bytes(&expires_at_secs));
    message
}
</code></pre>



</details>

<a id="0x1_attestation_authorization_initialize"></a>

## Function `initialize`

Create the nonce store. Called by <code><a href="attestation_policy.md#0x1_attestation_policy_create">attestation_policy::create</a></code> with the policy's own
resource-account signer, which is why this needs no permission check of its own.


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="attestation_authorization.md#0x1_attestation_authorization_initialize">initialize</a>(policy_account: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="attestation_authorization.md#0x1_attestation_authorization_initialize">initialize</a>(policy_account: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>) {
    <b>move_to</b>(policy_account, <a href="attestation_authorization.md#0x1_attestation_authorization_Nonces">Nonces</a> { used: <a href="../../aptos-stdlib/doc/table.md#0x1_table_new">table::new</a>&lt;<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, u64&gt;() });
}
</code></pre>



</details>

<a id="0x1_attestation_authorization_verify_and_consume"></a>

## Function `verify_and_consume`

Verify an authorization and consume its nonce.

Every field is checked against the call it is being used for; none is advisory. The policy
supplies the authorizer key and the longest window it will accept, so a compromised
authorizer cannot mint a long-lived capability by setting a distant expiry.

@param policy The policy the authorization was issued for.
@param authorizer_pubkey 32-byte ed25519 key the policy trusts.
@param max_ttl_secs Longest validity window the policy accepts.
@param subject The subject taking the action.
@param action The action being taken.
@param amount The actual amount, which must be within the committed bucket ceiling.
@param authorization BCS of (action, amount_bucket, nonce, issued_at, expires_at) followed
by the 64-byte signature.
@abort If any field disagrees with the call, the window is too long, the signature fails,
or the nonce has already been consumed.


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="attestation_authorization.md#0x1_attestation_authorization_verify_and_consume">verify_and_consume</a>(policy: <b>address</b>, authorizer_pubkey: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, max_ttl_secs: u64, subject: <b>address</b>, action: u8, amount: u64, authorization: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="attestation_authorization.md#0x1_attestation_authorization_verify_and_consume">verify_and_consume</a>(
    policy: <b>address</b>,
    authorizer_pubkey: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    max_ttl_secs: u64,
    subject: <b>address</b>,
    action: u8,
    amount: u64,
    authorization: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
) <b>acquires</b> <a href="attestation_authorization.md#0x1_attestation_authorization_Nonces">Nonces</a> {
    <b>assert</b>!(<b>exists</b>&lt;<a href="attestation_authorization.md#0x1_attestation_authorization_Nonces">Nonces</a>&gt;(policy), <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_not_found">error::not_found</a>(<a href="attestation_authorization.md#0x1_attestation_authorization_ENOT_INITIALIZED">ENOT_INITIALIZED</a>));
    <b>assert</b>!(
        authorizer_pubkey.length() == <a href="attestation_authorization.md#0x1_attestation_authorization_PUBKEY_LENGTH">PUBKEY_LENGTH</a>,
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_state">error::invalid_state</a>(<a href="attestation_authorization.md#0x1_attestation_authorization_ENO_AUTHORIZER">ENO_AUTHORIZER</a>)
    );

    <b>let</b> (signed_action, amount_bucket, nonce, issued_at_secs, expires_at_secs, signature) =
        <a href="attestation_authorization.md#0x1_attestation_authorization_decode">decode</a>(authorization);

    <b>assert</b>!(signed_action == action, <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="attestation_authorization.md#0x1_attestation_authorization_EBAD_SIGNATURE">EBAD_SIGNATURE</a>));
    <b>assert</b>!(
        amount &lt;= <a href="attestation_authorization.md#0x1_attestation_authorization_bucket_ceiling">bucket_ceiling</a>(amount_bucket),
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="attestation_authorization.md#0x1_attestation_authorization_EAMOUNT_OVER_BUCKET">EAMOUNT_OVER_BUCKET</a>)
    );

    <b>let</b> now = now_seconds();
    <b>assert</b>!(issued_at_secs &lt;= now, <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="attestation_authorization.md#0x1_attestation_authorization_ENOT_YET_VALID">ENOT_YET_VALID</a>));
    <b>assert</b>!(now &lt; expires_at_secs, <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_state">error::invalid_state</a>(<a href="attestation_authorization.md#0x1_attestation_authorization_EEXPIRED">EEXPIRED</a>));
    <b>assert</b>!(
        expires_at_secs - issued_at_secs &lt;= max_ttl_secs,
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="attestation_authorization.md#0x1_attestation_authorization_ETTL_TOO_LONG">ETTL_TOO_LONG</a>)
    );

    <b>let</b> message =
        <a href="attestation_authorization.md#0x1_attestation_authorization_authorization_message">authorization_message</a>(
            policy,
            subject,
            action,
            amount_bucket,
            nonce,
            issued_at_secs,
            expires_at_secs
        );
    <b>assert</b>!(
        <a href="../../aptos-stdlib/doc/ed25519.md#0x1_ed25519_signature_verify_strict">ed25519::signature_verify_strict</a>(
            &<a href="../../aptos-stdlib/doc/ed25519.md#0x1_ed25519_new_signature_from_bytes">ed25519::new_signature_from_bytes</a>(signature),
            &<a href="../../aptos-stdlib/doc/ed25519.md#0x1_ed25519_new_unvalidated_public_key_from_bytes">ed25519::new_unvalidated_public_key_from_bytes</a>(authorizer_pubkey),
            message
        ),
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="attestation_authorization.md#0x1_attestation_authorization_EBAD_SIGNATURE">EBAD_SIGNATURE</a>)
    );

    <b>let</b> used = &<b>mut</b> <a href="attestation_authorization.md#0x1_attestation_authorization_Nonces">Nonces</a>[policy].used;
    <b>assert</b>!(!<a href="../../aptos-stdlib/doc/table.md#0x1_table_contains">table::contains</a>(used, nonce), <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_state">error::invalid_state</a>(<a href="attestation_authorization.md#0x1_attestation_authorization_ENONCE_USED">ENONCE_USED</a>));
    <a href="../../aptos-stdlib/doc/table.md#0x1_table_add">table::add</a>(used, nonce, expires_at_secs);

    emit(
        <a href="attestation_authorization.md#0x1_attestation_authorization_ConsumeAuthorization">ConsumeAuthorization</a> {
            policy,
            subject,
            action,
            amount_bucket,
            nonce,
            issued_at_secs,
            expires_at_secs
        }
    );
}
</code></pre>



</details>

<a id="0x1_attestation_authorization_prune_nonces"></a>

## Function `prune_nonces`

Release the storage held by nonces that can no longer be replayed. Permissionless, because
it is pure cleanup and nobody has a reason to withhold it other than the fee, which is the
caller's to pay.


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation_authorization.md#0x1_attestation_authorization_prune_nonces">prune_nonces</a>(_anyone: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, policy: <b>address</b>, nonces: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation_authorization.md#0x1_attestation_authorization_prune_nonces">prune_nonces</a>(
    _anyone: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, policy: <b>address</b>, nonces: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;&gt;
) <b>acquires</b> <a href="attestation_authorization.md#0x1_attestation_authorization_Nonces">Nonces</a> {
    <b>assert</b>!(<b>exists</b>&lt;<a href="attestation_authorization.md#0x1_attestation_authorization_Nonces">Nonces</a>&gt;(policy), <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_not_found">error::not_found</a>(<a href="attestation_authorization.md#0x1_attestation_authorization_ENOT_INITIALIZED">ENOT_INITIALIZED</a>));
    <b>assert</b>!(nonces.length() &lt;= <a href="attestation_authorization.md#0x1_attestation_authorization_MAX_PRUNE">MAX_PRUNE</a>, <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="attestation_authorization.md#0x1_attestation_authorization_EBATCH_TOO_LARGE">EBATCH_TOO_LARGE</a>));
    <b>let</b> now = now_seconds();
    <b>let</b> used = &<b>mut</b> <a href="attestation_authorization.md#0x1_attestation_authorization_Nonces">Nonces</a>[policy].used;
    <b>let</b> released = 0;
    nonces.for_each(|nonce| {
        <b>if</b> (<a href="../../aptos-stdlib/doc/table.md#0x1_table_contains">table::contains</a>(used, nonce) && *<a href="../../aptos-stdlib/doc/table.md#0x1_table_borrow">table::borrow</a>(used, nonce) &lt;= now) {
            <a href="../../aptos-stdlib/doc/table.md#0x1_table_remove">table::remove</a>(used, nonce);
            released += 1;
        };
    });
    emit(<a href="attestation_authorization.md#0x1_attestation_authorization_PruneNonces">PruneNonces</a> { policy, released });
}
</code></pre>



</details>

<a id="0x1_attestation_authorization_decode"></a>

## Function `decode`

Split an authorization blob into its fields and the signature. The layout is fixed width up
to the signature so it can be parsed without a length prefix:
action (1) || bucket (1) || nonce (32) || issued_at (8) || expires_at (8) || signature (64).
Integers are little-endian, matching BCS.


<pre><code><b>fun</b> <a href="attestation_authorization.md#0x1_attestation_authorization_decode">decode</a>(authorization: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): (u8, u8, <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, u64, u64, <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="attestation_authorization.md#0x1_attestation_authorization_decode">decode</a>(authorization: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): (u8, u8, <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, u64, u64, <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;) {
    <b>let</b> expected = 1 + 1 + <a href="attestation_authorization.md#0x1_attestation_authorization_NONCE_LENGTH">NONCE_LENGTH</a> + 8 + 8 + <a href="attestation_authorization.md#0x1_attestation_authorization_SIGNATURE_LENGTH">SIGNATURE_LENGTH</a>;
    <b>assert</b>!(
        authorization.length() == expected,
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="attestation_authorization.md#0x1_attestation_authorization_EBAD_SIGNATURE_LENGTH">EBAD_SIGNATURE_LENGTH</a>)
    );
    <b>let</b> action = authorization[0];
    <b>let</b> amount_bucket = authorization[1];

    <b>let</b> nonce = <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>[];
    <b>let</b> index = 2;
    <b>while</b> (index &lt; 2 + <a href="attestation_authorization.md#0x1_attestation_authorization_NONCE_LENGTH">NONCE_LENGTH</a>) {
        nonce.push_back(authorization[index]);
        index += 1;
    };
    <b>assert</b>!(nonce.length() == <a href="attestation_authorization.md#0x1_attestation_authorization_NONCE_LENGTH">NONCE_LENGTH</a>, <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="attestation_authorization.md#0x1_attestation_authorization_EBAD_NONCE_LENGTH">EBAD_NONCE_LENGTH</a>));

    <b>let</b> issued_at_secs = <a href="attestation_authorization.md#0x1_attestation_authorization_read_u64_le">read_u64_le</a>(&authorization, 2 + <a href="attestation_authorization.md#0x1_attestation_authorization_NONCE_LENGTH">NONCE_LENGTH</a>);
    <b>let</b> expires_at_secs = <a href="attestation_authorization.md#0x1_attestation_authorization_read_u64_le">read_u64_le</a>(&authorization, 2 + <a href="attestation_authorization.md#0x1_attestation_authorization_NONCE_LENGTH">NONCE_LENGTH</a> + 8);

    <b>let</b> signature = <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>[];
    index = 2 + <a href="attestation_authorization.md#0x1_attestation_authorization_NONCE_LENGTH">NONCE_LENGTH</a> + 16;
    <b>while</b> (index &lt; expected) {
        signature.push_back(authorization[index]);
        index += 1;
    };

    (action, amount_bucket, nonce, issued_at_secs, expires_at_secs, signature)
}
</code></pre>



</details>

<a id="0x1_attestation_authorization_read_u64_le"></a>

## Function `read_u64_le`



<pre><code><b>fun</b> <a href="attestation_authorization.md#0x1_attestation_authorization_read_u64_le">read_u64_le</a>(bytes: &<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, offset: u64): u64
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="attestation_authorization.md#0x1_attestation_authorization_read_u64_le">read_u64_le</a>(bytes: &<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, offset: u64): u64 {
    <b>let</b> value = 0u64;
    <b>let</b> index = 0;
    <b>while</b> (index &lt; 8) {
        value += (bytes[offset + index] <b>as</b> u64) &lt;&lt; ((index * 8) <b>as</b> u8);
        index += 1;
    };
    value
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
<td>An authorization is usable at most once, and only inside its validity window (INV-8).</td>
<td>Critical</td>
<td>verify_and_consume aborts if the nonce is already in Nonces.used, if now is before issued_at or at or after expires_at, and otherwise inserts the nonce before returning.</td>
<td>Formally verified via <a href="#high-level-req-1">verify_and_consume</a> that every successful call inserts a nonce that was not present before. The window checks are audited in unit tests, because the fields are decoded by loops the prover havocs.</td>
</tr>

<tr>
<td>2</td>
<td>Only a nonce that can no longer be replayed is ever pruned.</td>
<td>High</td>
<td>prune_nonces removes an entry only when its stored expiry is at or before now; replaying an authorization with that nonce would fail the expiry check anyway.</td>
<td>Audited in unit tests (test_prune_expired_nonces). The removal loop is havocked by the prover.</td>
</tr>

<tr>
<td>3</td>
<td>The nonce store can only be created by attestation_policy, with the policy's own signer, exactly once per policy.</td>
<td>High</td>
<td>initialize and verify_and_consume are public(friend) with attestation_policy as the only friend.</td>
<td>Enforced by the friend declaration, which the compiler checks. Formally verified via <a href="#high-level-req-3">initialize</a> that a second initialization aborts.</td>
</tr>

<tr>
<td>4</td>
<td>An authorization requires a configured 32-byte authorizer key and a blob of the exact fixed layout.</td>
<td>Medium</td>
<td>verify_and_consume asserts the key length and decode asserts the blob length.</td>
<td>Formally verified via <a href="#high-level-req-4">verify_and_consume</a>.</td>
</tr>

</table>



<a id="module-level-spec"></a>

### Module-level Specification


<pre><code><b>pragma</b> verify = <b>true</b>;
<b>pragma</b> aborts_if_is_strict = <b>false</b>;
</code></pre>



<a id="@Specification_1_is_initialized"></a>

### Function `is_initialized`


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="attestation_authorization.md#0x1_attestation_authorization_is_initialized">is_initialized</a>(policy: <b>address</b>): bool
</code></pre>




<pre><code><b>aborts_if</b> <b>false</b>;
<b>ensures</b> result == <b>exists</b>&lt;<a href="attestation_authorization.md#0x1_attestation_authorization_Nonces">Nonces</a>&gt;(policy);
</code></pre>



<a id="@Specification_1_is_nonce_used"></a>

### Function `is_nonce_used`


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="attestation_authorization.md#0x1_attestation_authorization_is_nonce_used">is_nonce_used</a>(policy: <b>address</b>, nonce: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): bool
</code></pre>




<pre><code><b>aborts_if</b> <b>false</b>;
<b>ensures</b> result == (<b>exists</b>&lt;<a href="attestation_authorization.md#0x1_attestation_authorization_Nonces">Nonces</a>&gt;(policy)
    && <a href="../../aptos-stdlib/doc/table.md#0x1_table_spec_contains">table::spec_contains</a>(<b>global</b>&lt;<a href="attestation_authorization.md#0x1_attestation_authorization_Nonces">Nonces</a>&gt;(policy).used, nonce));
</code></pre>



<a id="@Specification_1_bucket_ceiling"></a>

### Function `bucket_ceiling`


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="attestation_authorization.md#0x1_attestation_authorization_bucket_ceiling">bucket_ceiling</a>(bucket: u8): u64
</code></pre>




<pre><code><b>pragma</b> aborts_if_is_partial;
<b>aborts_if</b> bucket &gt; <a href="attestation_authorization.md#0x1_attestation_authorization_MAX_BUCKET">MAX_BUCKET</a>;
</code></pre>



<a id="@Specification_1_authorization_message"></a>

### Function `authorization_message`


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="attestation_authorization.md#0x1_attestation_authorization_authorization_message">authorization_message</a>(policy: <b>address</b>, subject: <b>address</b>, action: u8, amount_bucket: u8, nonce: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, issued_at_secs: u64, expires_at_secs: u64): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
</code></pre>




<pre><code><b>aborts_if</b> !<b>exists</b>&lt;<a href="chain_id.md#0x1_chain_id_ChainId">chain_id::ChainId</a>&gt;(@aptos_framework);
</code></pre>



<a id="@Specification_1_initialize"></a>

### Function `initialize`


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="attestation_authorization.md#0x1_attestation_authorization_initialize">initialize</a>(policy_account: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>)
</code></pre>




<pre><code>// This enforces <a id="high-level-req-3" href="#high-level-req">high-level requirement 3</a>:
<b>aborts_if</b> <b>exists</b>&lt;<a href="attestation_authorization.md#0x1_attestation_authorization_Nonces">Nonces</a>&gt;(std::signer::address_of(policy_account));
<b>ensures</b> <b>exists</b>&lt;<a href="attestation_authorization.md#0x1_attestation_authorization_Nonces">Nonces</a>&gt;(std::signer::address_of(policy_account));
</code></pre>



<a id="@Specification_1_verify_and_consume"></a>

### Function `verify_and_consume`


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="attestation_authorization.md#0x1_attestation_authorization_verify_and_consume">verify_and_consume</a>(policy: <b>address</b>, authorizer_pubkey: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, max_ttl_secs: u64, subject: <b>address</b>, action: u8, amount: u64, authorization: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;)
</code></pre>




<pre><code><b>pragma</b> aborts_if_is_partial;
<b>aborts_if</b> !<b>exists</b>&lt;<a href="attestation_authorization.md#0x1_attestation_authorization_Nonces">Nonces</a>&gt;(policy);
// This enforces <a id="high-level-req-4" href="#high-level-req">high-level requirement 4</a>:
<b>aborts_if</b> len(authorizer_pubkey) != <a href="attestation_authorization.md#0x1_attestation_authorization_PUBKEY_LENGTH">PUBKEY_LENGTH</a>;
<b>aborts_if</b> len(authorization) != 2 + <a href="attestation_authorization.md#0x1_attestation_authorization_NONCE_LENGTH">NONCE_LENGTH</a> + 16 + <a href="attestation_authorization.md#0x1_attestation_authorization_SIGNATURE_LENGTH">SIGNATURE_LENGTH</a>;
<b>let</b> used = <b>global</b>&lt;<a href="attestation_authorization.md#0x1_attestation_authorization_Nonces">Nonces</a>&gt;(policy).used;
<b>let</b> <b>post</b> post_used = <b>global</b>&lt;<a href="attestation_authorization.md#0x1_attestation_authorization_Nonces">Nonces</a>&gt;(policy).used;
// This enforces <a id="high-level-req-1" href="#high-level-req">high-level requirement 1</a>:
<b>ensures</b> <b>exists</b> nonce: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;:
    !<a href="../../aptos-stdlib/doc/table.md#0x1_table_spec_contains">table::spec_contains</a>(used, nonce) && <a href="../../aptos-stdlib/doc/table.md#0x1_table_spec_contains">table::spec_contains</a>(post_used, nonce);
</code></pre>



<a id="@Specification_1_prune_nonces"></a>

### Function `prune_nonces`


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation_authorization.md#0x1_attestation_authorization_prune_nonces">prune_nonces</a>(_anyone: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, policy: <b>address</b>, nonces: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;&gt;)
</code></pre>




<pre><code><b>pragma</b> aborts_if_is_partial;
<b>aborts_if</b> !<b>exists</b>&lt;<a href="attestation_authorization.md#0x1_attestation_authorization_Nonces">Nonces</a>&gt;(policy);
<b>aborts_if</b> len(nonces) &gt; <a href="attestation_authorization.md#0x1_attestation_authorization_MAX_PRUNE">MAX_PRUNE</a>;
</code></pre>


[move-book]: https://aptos.dev/move/book/SUMMARY
