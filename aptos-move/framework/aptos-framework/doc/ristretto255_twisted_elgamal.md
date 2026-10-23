
<a id="0x1_ristretto255_twisted_elgamal"></a>

# Module `0x1::ristretto255_twisted_elgamal`

PAUSED: confidential assets are disabled on Movement; interface retained for upgrade compatibility only

Twisted ElGamal encryption API over the Ristretto255 curve.

Every public function and every entry function aborts with <code><a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code> (wrapped in
<code><a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a></code>). All structs are retained with identical names, abilities and field layout because the compatible upgrade policy refuses to
remove or change a published struct. No resource is published, no event is emitted and no state is changed.


-  [Struct `Ciphertext`](#0x1_ristretto255_twisted_elgamal_Ciphertext)
-  [Struct `CompressedCiphertext`](#0x1_ristretto255_twisted_elgamal_CompressedCiphertext)
-  [Struct `CompressedPubkey`](#0x1_ristretto255_twisted_elgamal_CompressedPubkey)
-  [Constants](#@Constants_0)
-  [Function `new_pubkey_from_bytes`](#0x1_ristretto255_twisted_elgamal_new_pubkey_from_bytes)
-  [Function `is_identity_pubkey`](#0x1_ristretto255_twisted_elgamal_is_identity_pubkey)
-  [Function `pubkey_to_bytes`](#0x1_ristretto255_twisted_elgamal_pubkey_to_bytes)
-  [Function `pubkey_to_point`](#0x1_ristretto255_twisted_elgamal_pubkey_to_point)
-  [Function `pubkey_to_compressed_point`](#0x1_ristretto255_twisted_elgamal_pubkey_to_compressed_point)
-  [Function `new_ciphertext_from_bytes`](#0x1_ristretto255_twisted_elgamal_new_ciphertext_from_bytes)
-  [Function `new_ciphertext_no_randomness`](#0x1_ristretto255_twisted_elgamal_new_ciphertext_no_randomness)
-  [Function `ciphertext_from_points`](#0x1_ristretto255_twisted_elgamal_ciphertext_from_points)
-  [Function `ciphertext_from_compressed_points`](#0x1_ristretto255_twisted_elgamal_ciphertext_from_compressed_points)
-  [Function `ciphertext_to_bytes`](#0x1_ristretto255_twisted_elgamal_ciphertext_to_bytes)
-  [Function `ciphertext_into_points`](#0x1_ristretto255_twisted_elgamal_ciphertext_into_points)
-  [Function `ciphertext_as_points`](#0x1_ristretto255_twisted_elgamal_ciphertext_as_points)
-  [Function `compress_ciphertext`](#0x1_ristretto255_twisted_elgamal_compress_ciphertext)
-  [Function `decompress_ciphertext`](#0x1_ristretto255_twisted_elgamal_decompress_ciphertext)
-  [Function `ciphertext_add`](#0x1_ristretto255_twisted_elgamal_ciphertext_add)
-  [Function `ciphertext_add_assign`](#0x1_ristretto255_twisted_elgamal_ciphertext_add_assign)
-  [Function `ciphertext_sub`](#0x1_ristretto255_twisted_elgamal_ciphertext_sub)
-  [Function `ciphertext_sub_assign`](#0x1_ristretto255_twisted_elgamal_ciphertext_sub_assign)
-  [Function `ciphertext_clone`](#0x1_ristretto255_twisted_elgamal_ciphertext_clone)
-  [Function `ciphertext_equals`](#0x1_ristretto255_twisted_elgamal_ciphertext_equals)
-  [Function `get_value_component`](#0x1_ristretto255_twisted_elgamal_get_value_component)


<pre><code><b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error">0x1::error</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option">0x1::option</a>;
<b>use</b> <a href="../../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255">0x1::ristretto255</a>;
</code></pre>



<a id="0x1_ristretto255_twisted_elgamal_Ciphertext"></a>

## Struct `Ciphertext`

A Twisted ElGamal ciphertext, consisting of two Ristretto255 points.


<pre><code><b>struct</b> <a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_Ciphertext">Ciphertext</a> <b>has</b> drop
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>left: <a href="../../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255_RistrettoPoint">ristretto255::RistrettoPoint</a></code>
</dt>
<dd>

</dd>
<dt>
<code>right: <a href="../../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255_RistrettoPoint">ristretto255::RistrettoPoint</a></code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_ristretto255_twisted_elgamal_CompressedCiphertext"></a>

## Struct `CompressedCiphertext`

A compressed Twisted ElGamal ciphertext, consisting of two compressed Ristretto255 points.


<pre><code><b>struct</b> <a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_CompressedCiphertext">CompressedCiphertext</a> <b>has</b> <b>copy</b>, drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>left: <a href="../../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255_CompressedRistretto">ristretto255::CompressedRistretto</a></code>
</dt>
<dd>

</dd>
<dt>
<code>right: <a href="../../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255_CompressedRistretto">ristretto255::CompressedRistretto</a></code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_ristretto255_twisted_elgamal_CompressedPubkey"></a>

## Struct `CompressedPubkey`

A Twisted ElGamal public key, represented as a compressed Ristretto255 point.


<pre><code><b>struct</b> <a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_CompressedPubkey">CompressedPubkey</a> <b>has</b> <b>copy</b>, drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>point: <a href="../../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255_CompressedRistretto">ristretto255::CompressedRistretto</a></code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="@Constants_0"></a>

## Constants


<a id="0x1_ristretto255_twisted_elgamal_E_CONFIDENTIAL_ASSETS_PAUSED"></a>

Confidential assets are paused: every function in this module aborts.


<pre><code><b>const</b> <a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>: u64 = 1;
</code></pre>



<a id="0x1_ristretto255_twisted_elgamal_new_pubkey_from_bytes"></a>

## Function `new_pubkey_from_bytes`

Paused: always aborts with <code><a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code><b>public</b> <b>fun</b> <a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_new_pubkey_from_bytes">new_pubkey_from_bytes</a>(_bytes: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_Option">option::Option</a>&lt;<a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_CompressedPubkey">ristretto255_twisted_elgamal::CompressedPubkey</a>&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_new_pubkey_from_bytes">new_pubkey_from_bytes</a>(_bytes: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): Option&lt;<a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_CompressedPubkey">CompressedPubkey</a>&gt; {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_ristretto255_twisted_elgamal_is_identity_pubkey"></a>

## Function `is_identity_pubkey`

Paused: always aborts with <code><a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code><b>public</b> <b>fun</b> <a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_is_identity_pubkey">is_identity_pubkey</a>(_pubkey: &<a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_CompressedPubkey">ristretto255_twisted_elgamal::CompressedPubkey</a>): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_is_identity_pubkey">is_identity_pubkey</a>(_pubkey: &<a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_CompressedPubkey">CompressedPubkey</a>): bool {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_ristretto255_twisted_elgamal_pubkey_to_bytes"></a>

## Function `pubkey_to_bytes`

Paused: always aborts with <code><a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code><b>public</b> <b>fun</b> <a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_pubkey_to_bytes">pubkey_to_bytes</a>(_pubkey: &<a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_CompressedPubkey">ristretto255_twisted_elgamal::CompressedPubkey</a>): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_pubkey_to_bytes">pubkey_to_bytes</a>(_pubkey: &<a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_CompressedPubkey">CompressedPubkey</a>): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt; {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_ristretto255_twisted_elgamal_pubkey_to_point"></a>

## Function `pubkey_to_point`

Paused: always aborts with <code><a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code><b>public</b> <b>fun</b> <a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_pubkey_to_point">pubkey_to_point</a>(_pubkey: &<a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_CompressedPubkey">ristretto255_twisted_elgamal::CompressedPubkey</a>): <a href="../../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255_RistrettoPoint">ristretto255::RistrettoPoint</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_pubkey_to_point">pubkey_to_point</a>(_pubkey: &<a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_CompressedPubkey">CompressedPubkey</a>): RistrettoPoint {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_ristretto255_twisted_elgamal_pubkey_to_compressed_point"></a>

## Function `pubkey_to_compressed_point`

Paused: always aborts with <code><a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code><b>public</b> <b>fun</b> <a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_pubkey_to_compressed_point">pubkey_to_compressed_point</a>(_pubkey: &<a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_CompressedPubkey">ristretto255_twisted_elgamal::CompressedPubkey</a>): <a href="../../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255_CompressedRistretto">ristretto255::CompressedRistretto</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_pubkey_to_compressed_point">pubkey_to_compressed_point</a>(_pubkey: &<a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_CompressedPubkey">CompressedPubkey</a>): CompressedRistretto {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_ristretto255_twisted_elgamal_new_ciphertext_from_bytes"></a>

## Function `new_ciphertext_from_bytes`

Paused: always aborts with <code><a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code><b>public</b> <b>fun</b> <a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_new_ciphertext_from_bytes">new_ciphertext_from_bytes</a>(_bytes: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_Option">option::Option</a>&lt;<a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_Ciphertext">ristretto255_twisted_elgamal::Ciphertext</a>&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_new_ciphertext_from_bytes">new_ciphertext_from_bytes</a>(_bytes: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): Option&lt;<a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_Ciphertext">Ciphertext</a>&gt; {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_ristretto255_twisted_elgamal_new_ciphertext_no_randomness"></a>

## Function `new_ciphertext_no_randomness`

Paused: always aborts with <code><a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code><b>public</b> <b>fun</b> <a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_new_ciphertext_no_randomness">new_ciphertext_no_randomness</a>(_val: &<a href="../../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255_Scalar">ristretto255::Scalar</a>): <a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_Ciphertext">ristretto255_twisted_elgamal::Ciphertext</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_new_ciphertext_no_randomness">new_ciphertext_no_randomness</a>(_val: &Scalar): <a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_Ciphertext">Ciphertext</a> {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_ristretto255_twisted_elgamal_ciphertext_from_points"></a>

## Function `ciphertext_from_points`

Paused: always aborts with <code><a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code><b>public</b> <b>fun</b> <a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_ciphertext_from_points">ciphertext_from_points</a>(_left: <a href="../../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255_RistrettoPoint">ristretto255::RistrettoPoint</a>, _right: <a href="../../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255_RistrettoPoint">ristretto255::RistrettoPoint</a>): <a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_Ciphertext">ristretto255_twisted_elgamal::Ciphertext</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_ciphertext_from_points">ciphertext_from_points</a>(_left: RistrettoPoint, _right: RistrettoPoint): <a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_Ciphertext">Ciphertext</a> {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_ristretto255_twisted_elgamal_ciphertext_from_compressed_points"></a>

## Function `ciphertext_from_compressed_points`

Paused: always aborts with <code><a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code><b>public</b> <b>fun</b> <a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_ciphertext_from_compressed_points">ciphertext_from_compressed_points</a>(_left: <a href="../../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255_CompressedRistretto">ristretto255::CompressedRistretto</a>, _right: <a href="../../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255_CompressedRistretto">ristretto255::CompressedRistretto</a>): <a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_CompressedCiphertext">ristretto255_twisted_elgamal::CompressedCiphertext</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_ciphertext_from_compressed_points">ciphertext_from_compressed_points</a>(
    _left: CompressedRistretto,
    _right: CompressedRistretto
): <a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_CompressedCiphertext">CompressedCiphertext</a> {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_ristretto255_twisted_elgamal_ciphertext_to_bytes"></a>

## Function `ciphertext_to_bytes`

Paused: always aborts with <code><a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code><b>public</b> <b>fun</b> <a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_ciphertext_to_bytes">ciphertext_to_bytes</a>(_ct: &<a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_Ciphertext">ristretto255_twisted_elgamal::Ciphertext</a>): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_ciphertext_to_bytes">ciphertext_to_bytes</a>(_ct: &<a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_Ciphertext">Ciphertext</a>): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt; {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_ristretto255_twisted_elgamal_ciphertext_into_points"></a>

## Function `ciphertext_into_points`

Paused: always aborts with <code><a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code><b>public</b> <b>fun</b> <a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_ciphertext_into_points">ciphertext_into_points</a>(_c: <a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_Ciphertext">ristretto255_twisted_elgamal::Ciphertext</a>): (<a href="../../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255_RistrettoPoint">ristretto255::RistrettoPoint</a>, <a href="../../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255_RistrettoPoint">ristretto255::RistrettoPoint</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_ciphertext_into_points">ciphertext_into_points</a>(_c: <a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_Ciphertext">Ciphertext</a>): (RistrettoPoint, RistrettoPoint) {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_ristretto255_twisted_elgamal_ciphertext_as_points"></a>

## Function `ciphertext_as_points`

Paused: always aborts with <code><a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code><b>public</b> <b>fun</b> <a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_ciphertext_as_points">ciphertext_as_points</a>(_c: &<a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_Ciphertext">ristretto255_twisted_elgamal::Ciphertext</a>): (&<a href="../../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255_RistrettoPoint">ristretto255::RistrettoPoint</a>, &<a href="../../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255_RistrettoPoint">ristretto255::RistrettoPoint</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_ciphertext_as_points">ciphertext_as_points</a>(_c: &<a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_Ciphertext">Ciphertext</a>): (&RistrettoPoint, &RistrettoPoint) {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_ristretto255_twisted_elgamal_compress_ciphertext"></a>

## Function `compress_ciphertext`

Paused: always aborts with <code><a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code><b>public</b> <b>fun</b> <a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_compress_ciphertext">compress_ciphertext</a>(_ct: &<a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_Ciphertext">ristretto255_twisted_elgamal::Ciphertext</a>): <a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_CompressedCiphertext">ristretto255_twisted_elgamal::CompressedCiphertext</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_compress_ciphertext">compress_ciphertext</a>(_ct: &<a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_Ciphertext">Ciphertext</a>): <a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_CompressedCiphertext">CompressedCiphertext</a> {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_ristretto255_twisted_elgamal_decompress_ciphertext"></a>

## Function `decompress_ciphertext`

Paused: always aborts with <code><a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code><b>public</b> <b>fun</b> <a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_decompress_ciphertext">decompress_ciphertext</a>(_ct: &<a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_CompressedCiphertext">ristretto255_twisted_elgamal::CompressedCiphertext</a>): <a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_Ciphertext">ristretto255_twisted_elgamal::Ciphertext</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_decompress_ciphertext">decompress_ciphertext</a>(_ct: &<a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_CompressedCiphertext">CompressedCiphertext</a>): <a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_Ciphertext">Ciphertext</a> {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_ristretto255_twisted_elgamal_ciphertext_add"></a>

## Function `ciphertext_add`

Paused: always aborts with <code><a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code><b>public</b> <b>fun</b> <a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_ciphertext_add">ciphertext_add</a>(_lhs: &<a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_Ciphertext">ristretto255_twisted_elgamal::Ciphertext</a>, _rhs: &<a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_Ciphertext">ristretto255_twisted_elgamal::Ciphertext</a>): <a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_Ciphertext">ristretto255_twisted_elgamal::Ciphertext</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_ciphertext_add">ciphertext_add</a>(_lhs: &<a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_Ciphertext">Ciphertext</a>, _rhs: &<a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_Ciphertext">Ciphertext</a>): <a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_Ciphertext">Ciphertext</a> {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_ristretto255_twisted_elgamal_ciphertext_add_assign"></a>

## Function `ciphertext_add_assign`

Paused: always aborts with <code><a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code><b>public</b> <b>fun</b> <a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_ciphertext_add_assign">ciphertext_add_assign</a>(_lhs: &<b>mut</b> <a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_Ciphertext">ristretto255_twisted_elgamal::Ciphertext</a>, _rhs: &<a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_Ciphertext">ristretto255_twisted_elgamal::Ciphertext</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_ciphertext_add_assign">ciphertext_add_assign</a>(_lhs: &<b>mut</b> <a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_Ciphertext">Ciphertext</a>, _rhs: &<a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_Ciphertext">Ciphertext</a>) {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_ristretto255_twisted_elgamal_ciphertext_sub"></a>

## Function `ciphertext_sub`

Paused: always aborts with <code><a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code><b>public</b> <b>fun</b> <a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_ciphertext_sub">ciphertext_sub</a>(_lhs: &<a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_Ciphertext">ristretto255_twisted_elgamal::Ciphertext</a>, _rhs: &<a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_Ciphertext">ristretto255_twisted_elgamal::Ciphertext</a>): <a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_Ciphertext">ristretto255_twisted_elgamal::Ciphertext</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_ciphertext_sub">ciphertext_sub</a>(_lhs: &<a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_Ciphertext">Ciphertext</a>, _rhs: &<a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_Ciphertext">Ciphertext</a>): <a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_Ciphertext">Ciphertext</a> {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_ristretto255_twisted_elgamal_ciphertext_sub_assign"></a>

## Function `ciphertext_sub_assign`

Paused: always aborts with <code><a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code><b>public</b> <b>fun</b> <a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_ciphertext_sub_assign">ciphertext_sub_assign</a>(_lhs: &<b>mut</b> <a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_Ciphertext">ristretto255_twisted_elgamal::Ciphertext</a>, _rhs: &<a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_Ciphertext">ristretto255_twisted_elgamal::Ciphertext</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_ciphertext_sub_assign">ciphertext_sub_assign</a>(_lhs: &<b>mut</b> <a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_Ciphertext">Ciphertext</a>, _rhs: &<a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_Ciphertext">Ciphertext</a>) {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_ristretto255_twisted_elgamal_ciphertext_clone"></a>

## Function `ciphertext_clone`

Paused: always aborts with <code><a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code><b>public</b> <b>fun</b> <a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_ciphertext_clone">ciphertext_clone</a>(_c: &<a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_Ciphertext">ristretto255_twisted_elgamal::Ciphertext</a>): <a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_Ciphertext">ristretto255_twisted_elgamal::Ciphertext</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_ciphertext_clone">ciphertext_clone</a>(_c: &<a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_Ciphertext">Ciphertext</a>): <a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_Ciphertext">Ciphertext</a> {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_ristretto255_twisted_elgamal_ciphertext_equals"></a>

## Function `ciphertext_equals`

Paused: always aborts with <code><a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code><b>public</b> <b>fun</b> <a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_ciphertext_equals">ciphertext_equals</a>(_lhs: &<a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_Ciphertext">ristretto255_twisted_elgamal::Ciphertext</a>, _rhs: &<a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_Ciphertext">ristretto255_twisted_elgamal::Ciphertext</a>): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_ciphertext_equals">ciphertext_equals</a>(_lhs: &<a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_Ciphertext">Ciphertext</a>, _rhs: &<a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_Ciphertext">Ciphertext</a>): bool {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_ristretto255_twisted_elgamal_get_value_component"></a>

## Function `get_value_component`

Paused: always aborts with <code><a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code><b>public</b> <b>fun</b> <a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_get_value_component">get_value_component</a>(_ct: &<a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_Ciphertext">ristretto255_twisted_elgamal::Ciphertext</a>): &<a href="../../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255_RistrettoPoint">ristretto255::RistrettoPoint</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_get_value_component">get_value_component</a>(_ct: &<a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_Ciphertext">Ciphertext</a>): &RistrettoPoint {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>


[move-book]: https://aptos.dev/move/book/SUMMARY
