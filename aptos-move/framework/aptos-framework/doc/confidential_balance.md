
<a id="0x1_confidential_balance"></a>

# Module `0x1::confidential_balance`

PAUSED: confidential assets are disabled on Movement; interface retained for upgrade compatibility only

Confidential balance abstraction over Twisted ElGamal ciphertexts.

Every public function and every entry function aborts with <code><a href="confidential_balance.md#0x1_confidential_balance_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code> (wrapped in
<code><a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a></code>). All structs are retained with identical names, abilities and field layout because the compatible upgrade policy refuses to
remove or change a published struct. No resource is published, no event is emitted and no state is changed.


-  [Struct `CompressedConfidentialBalance`](#0x1_confidential_balance_CompressedConfidentialBalance)
-  [Struct `ConfidentialBalance`](#0x1_confidential_balance_ConfidentialBalance)
-  [Constants](#@Constants_0)
-  [Function `new_pending_balance_no_randomness`](#0x1_confidential_balance_new_pending_balance_no_randomness)
-  [Function `new_actual_balance_no_randomness`](#0x1_confidential_balance_new_actual_balance_no_randomness)
-  [Function `new_compressed_pending_balance_no_randomness`](#0x1_confidential_balance_new_compressed_pending_balance_no_randomness)
-  [Function `new_compressed_actual_balance_no_randomness`](#0x1_confidential_balance_new_compressed_actual_balance_no_randomness)
-  [Function `new_pending_balance_u64_no_randonmess`](#0x1_confidential_balance_new_pending_balance_u64_no_randonmess)
-  [Function `new_pending_balance_from_bytes`](#0x1_confidential_balance_new_pending_balance_from_bytes)
-  [Function `new_actual_balance_from_bytes`](#0x1_confidential_balance_new_actual_balance_from_bytes)
-  [Function `compress_balance`](#0x1_confidential_balance_compress_balance)
-  [Function `decompress_balance`](#0x1_confidential_balance_decompress_balance)
-  [Function `balance_to_bytes`](#0x1_confidential_balance_balance_to_bytes)
-  [Function `balance_to_points_c`](#0x1_confidential_balance_balance_to_points_c)
-  [Function `balance_to_points_d`](#0x1_confidential_balance_balance_to_points_d)
-  [Function `add_balances_mut`](#0x1_confidential_balance_add_balances_mut)
-  [Function `balance_equals`](#0x1_confidential_balance_balance_equals)
-  [Function `balance_c_equals`](#0x1_confidential_balance_balance_c_equals)
-  [Function `is_zero_balance`](#0x1_confidential_balance_is_zero_balance)
-  [Function `split_into_chunks_u64`](#0x1_confidential_balance_split_into_chunks_u64)
-  [Function `split_into_chunks_u128`](#0x1_confidential_balance_split_into_chunks_u128)
-  [Function `get_pending_balance_chunks`](#0x1_confidential_balance_get_pending_balance_chunks)
-  [Function `get_actual_balance_chunks`](#0x1_confidential_balance_get_actual_balance_chunks)
-  [Function `get_chunk_size_bits`](#0x1_confidential_balance_get_chunk_size_bits)


<pre><code><b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error">0x1::error</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option">0x1::option</a>;
<b>use</b> <a href="../../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255">0x1::ristretto255</a>;
<b>use</b> <a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal">0x1::ristretto255_twisted_elgamal</a>;
</code></pre>



<a id="0x1_confidential_balance_CompressedConfidentialBalance"></a>

## Struct `CompressedConfidentialBalance`

Represents a compressed confidential balance, where each chunk is a compressed Twisted ElGamal ciphertext.


<pre><code><b>struct</b> <a href="confidential_balance.md#0x1_confidential_balance_CompressedConfidentialBalance">CompressedConfidentialBalance</a> <b>has</b> <b>copy</b>, drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>chunks: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_CompressedCiphertext">ristretto255_twisted_elgamal::CompressedCiphertext</a>&gt;</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_confidential_balance_ConfidentialBalance"></a>

## Struct `ConfidentialBalance`

Represents a confidential balance, where each chunk is a Twisted ElGamal ciphertext.


<pre><code><b>struct</b> <a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">ConfidentialBalance</a> <b>has</b> drop
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>chunks: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_Ciphertext">ristretto255_twisted_elgamal::Ciphertext</a>&gt;</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="@Constants_0"></a>

## Constants


<a id="0x1_confidential_balance_E_CONFIDENTIAL_ASSETS_PAUSED"></a>

Confidential assets are paused: every function in this module aborts.


<pre><code><b>const</b> <a href="confidential_balance.md#0x1_confidential_balance_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>: u64 = 1;
</code></pre>



<a id="0x1_confidential_balance_new_pending_balance_no_randomness"></a>

## Function `new_pending_balance_no_randomness`

Paused: always aborts with <code><a href="confidential_balance.md#0x1_confidential_balance_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code><b>public</b> <b>fun</b> <a href="confidential_balance.md#0x1_confidential_balance_new_pending_balance_no_randomness">new_pending_balance_no_randomness</a>(): <a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_balance.md#0x1_confidential_balance_new_pending_balance_no_randomness">new_pending_balance_no_randomness</a>(): <a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">ConfidentialBalance</a> {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="confidential_balance.md#0x1_confidential_balance_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_confidential_balance_new_actual_balance_no_randomness"></a>

## Function `new_actual_balance_no_randomness`

Paused: always aborts with <code><a href="confidential_balance.md#0x1_confidential_balance_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code><b>public</b> <b>fun</b> <a href="confidential_balance.md#0x1_confidential_balance_new_actual_balance_no_randomness">new_actual_balance_no_randomness</a>(): <a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_balance.md#0x1_confidential_balance_new_actual_balance_no_randomness">new_actual_balance_no_randomness</a>(): <a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">ConfidentialBalance</a> {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="confidential_balance.md#0x1_confidential_balance_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_confidential_balance_new_compressed_pending_balance_no_randomness"></a>

## Function `new_compressed_pending_balance_no_randomness`

Paused: always aborts with <code><a href="confidential_balance.md#0x1_confidential_balance_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code><b>public</b> <b>fun</b> <a href="confidential_balance.md#0x1_confidential_balance_new_compressed_pending_balance_no_randomness">new_compressed_pending_balance_no_randomness</a>(): <a href="confidential_balance.md#0x1_confidential_balance_CompressedConfidentialBalance">confidential_balance::CompressedConfidentialBalance</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_balance.md#0x1_confidential_balance_new_compressed_pending_balance_no_randomness">new_compressed_pending_balance_no_randomness</a>(): <a href="confidential_balance.md#0x1_confidential_balance_CompressedConfidentialBalance">CompressedConfidentialBalance</a> {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="confidential_balance.md#0x1_confidential_balance_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_confidential_balance_new_compressed_actual_balance_no_randomness"></a>

## Function `new_compressed_actual_balance_no_randomness`

Paused: always aborts with <code><a href="confidential_balance.md#0x1_confidential_balance_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code><b>public</b> <b>fun</b> <a href="confidential_balance.md#0x1_confidential_balance_new_compressed_actual_balance_no_randomness">new_compressed_actual_balance_no_randomness</a>(): <a href="confidential_balance.md#0x1_confidential_balance_CompressedConfidentialBalance">confidential_balance::CompressedConfidentialBalance</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_balance.md#0x1_confidential_balance_new_compressed_actual_balance_no_randomness">new_compressed_actual_balance_no_randomness</a>(): <a href="confidential_balance.md#0x1_confidential_balance_CompressedConfidentialBalance">CompressedConfidentialBalance</a> {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="confidential_balance.md#0x1_confidential_balance_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_confidential_balance_new_pending_balance_u64_no_randonmess"></a>

## Function `new_pending_balance_u64_no_randonmess`

Paused: always aborts with <code><a href="confidential_balance.md#0x1_confidential_balance_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code><b>public</b> <b>fun</b> <a href="confidential_balance.md#0x1_confidential_balance_new_pending_balance_u64_no_randonmess">new_pending_balance_u64_no_randonmess</a>(_amount: u64): <a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_balance.md#0x1_confidential_balance_new_pending_balance_u64_no_randonmess">new_pending_balance_u64_no_randonmess</a>(_amount: u64): <a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">ConfidentialBalance</a> {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="confidential_balance.md#0x1_confidential_balance_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_confidential_balance_new_pending_balance_from_bytes"></a>

## Function `new_pending_balance_from_bytes`

Paused: always aborts with <code><a href="confidential_balance.md#0x1_confidential_balance_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code><b>public</b> <b>fun</b> <a href="confidential_balance.md#0x1_confidential_balance_new_pending_balance_from_bytes">new_pending_balance_from_bytes</a>(_bytes: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_Option">option::Option</a>&lt;<a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_balance.md#0x1_confidential_balance_new_pending_balance_from_bytes">new_pending_balance_from_bytes</a>(_bytes: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): Option&lt;<a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">ConfidentialBalance</a>&gt; {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="confidential_balance.md#0x1_confidential_balance_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_confidential_balance_new_actual_balance_from_bytes"></a>

## Function `new_actual_balance_from_bytes`

Paused: always aborts with <code><a href="confidential_balance.md#0x1_confidential_balance_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code><b>public</b> <b>fun</b> <a href="confidential_balance.md#0x1_confidential_balance_new_actual_balance_from_bytes">new_actual_balance_from_bytes</a>(_bytes: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_Option">option::Option</a>&lt;<a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_balance.md#0x1_confidential_balance_new_actual_balance_from_bytes">new_actual_balance_from_bytes</a>(_bytes: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): Option&lt;<a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">ConfidentialBalance</a>&gt; {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="confidential_balance.md#0x1_confidential_balance_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_confidential_balance_compress_balance"></a>

## Function `compress_balance`

Paused: always aborts with <code><a href="confidential_balance.md#0x1_confidential_balance_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code><b>public</b> <b>fun</b> <a href="confidential_balance.md#0x1_confidential_balance_compress_balance">compress_balance</a>(_balance: &<a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>): <a href="confidential_balance.md#0x1_confidential_balance_CompressedConfidentialBalance">confidential_balance::CompressedConfidentialBalance</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_balance.md#0x1_confidential_balance_compress_balance">compress_balance</a>(_balance: &<a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">ConfidentialBalance</a>): <a href="confidential_balance.md#0x1_confidential_balance_CompressedConfidentialBalance">CompressedConfidentialBalance</a> {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="confidential_balance.md#0x1_confidential_balance_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_confidential_balance_decompress_balance"></a>

## Function `decompress_balance`

Paused: always aborts with <code><a href="confidential_balance.md#0x1_confidential_balance_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code><b>public</b> <b>fun</b> <a href="confidential_balance.md#0x1_confidential_balance_decompress_balance">decompress_balance</a>(_balance: &<a href="confidential_balance.md#0x1_confidential_balance_CompressedConfidentialBalance">confidential_balance::CompressedConfidentialBalance</a>): <a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_balance.md#0x1_confidential_balance_decompress_balance">decompress_balance</a>(_balance: &<a href="confidential_balance.md#0x1_confidential_balance_CompressedConfidentialBalance">CompressedConfidentialBalance</a>): <a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">ConfidentialBalance</a> {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="confidential_balance.md#0x1_confidential_balance_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_confidential_balance_balance_to_bytes"></a>

## Function `balance_to_bytes`

Paused: always aborts with <code><a href="confidential_balance.md#0x1_confidential_balance_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code><b>public</b> <b>fun</b> <a href="confidential_balance.md#0x1_confidential_balance_balance_to_bytes">balance_to_bytes</a>(_balance: &<a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_balance.md#0x1_confidential_balance_balance_to_bytes">balance_to_bytes</a>(_balance: &<a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">ConfidentialBalance</a>): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt; {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="confidential_balance.md#0x1_confidential_balance_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_confidential_balance_balance_to_points_c"></a>

## Function `balance_to_points_c`

Paused: always aborts with <code><a href="confidential_balance.md#0x1_confidential_balance_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code><b>public</b> <b>fun</b> <a href="confidential_balance.md#0x1_confidential_balance_balance_to_points_c">balance_to_points_c</a>(_balance: &<a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255_RistrettoPoint">ristretto255::RistrettoPoint</a>&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_balance.md#0x1_confidential_balance_balance_to_points_c">balance_to_points_c</a>(_balance: &<a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">ConfidentialBalance</a>): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;RistrettoPoint&gt; {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="confidential_balance.md#0x1_confidential_balance_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_confidential_balance_balance_to_points_d"></a>

## Function `balance_to_points_d`

Paused: always aborts with <code><a href="confidential_balance.md#0x1_confidential_balance_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code><b>public</b> <b>fun</b> <a href="confidential_balance.md#0x1_confidential_balance_balance_to_points_d">balance_to_points_d</a>(_balance: &<a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255_RistrettoPoint">ristretto255::RistrettoPoint</a>&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_balance.md#0x1_confidential_balance_balance_to_points_d">balance_to_points_d</a>(_balance: &<a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">ConfidentialBalance</a>): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;RistrettoPoint&gt; {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="confidential_balance.md#0x1_confidential_balance_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_confidential_balance_add_balances_mut"></a>

## Function `add_balances_mut`

Paused: always aborts with <code><a href="confidential_balance.md#0x1_confidential_balance_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code><b>public</b> <b>fun</b> <a href="confidential_balance.md#0x1_confidential_balance_add_balances_mut">add_balances_mut</a>(_lhs: &<b>mut</b> <a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>, _rhs: &<a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_balance.md#0x1_confidential_balance_add_balances_mut">add_balances_mut</a>(_lhs: &<b>mut</b> <a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">ConfidentialBalance</a>, _rhs: &<a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">ConfidentialBalance</a>) {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="confidential_balance.md#0x1_confidential_balance_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_confidential_balance_balance_equals"></a>

## Function `balance_equals`

Paused: always aborts with <code><a href="confidential_balance.md#0x1_confidential_balance_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code><b>public</b> <b>fun</b> <a href="confidential_balance.md#0x1_confidential_balance_balance_equals">balance_equals</a>(_lhs: &<a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>, _rhs: &<a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_balance.md#0x1_confidential_balance_balance_equals">balance_equals</a>(_lhs: &<a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">ConfidentialBalance</a>, _rhs: &<a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">ConfidentialBalance</a>): bool {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="confidential_balance.md#0x1_confidential_balance_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_confidential_balance_balance_c_equals"></a>

## Function `balance_c_equals`

Paused: always aborts with <code><a href="confidential_balance.md#0x1_confidential_balance_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code><b>public</b> <b>fun</b> <a href="confidential_balance.md#0x1_confidential_balance_balance_c_equals">balance_c_equals</a>(_lhs: &<a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>, _rhs: &<a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_balance.md#0x1_confidential_balance_balance_c_equals">balance_c_equals</a>(_lhs: &<a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">ConfidentialBalance</a>, _rhs: &<a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">ConfidentialBalance</a>): bool {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="confidential_balance.md#0x1_confidential_balance_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_confidential_balance_is_zero_balance"></a>

## Function `is_zero_balance`

Paused: always aborts with <code><a href="confidential_balance.md#0x1_confidential_balance_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code><b>public</b> <b>fun</b> <a href="confidential_balance.md#0x1_confidential_balance_is_zero_balance">is_zero_balance</a>(_balance: &<a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_balance.md#0x1_confidential_balance_is_zero_balance">is_zero_balance</a>(_balance: &<a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">ConfidentialBalance</a>): bool {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="confidential_balance.md#0x1_confidential_balance_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_confidential_balance_split_into_chunks_u64"></a>

## Function `split_into_chunks_u64`

Paused: always aborts with <code><a href="confidential_balance.md#0x1_confidential_balance_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code><b>public</b> <b>fun</b> <a href="confidential_balance.md#0x1_confidential_balance_split_into_chunks_u64">split_into_chunks_u64</a>(_amount: u64): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255_Scalar">ristretto255::Scalar</a>&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_balance.md#0x1_confidential_balance_split_into_chunks_u64">split_into_chunks_u64</a>(_amount: u64): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;Scalar&gt; {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="confidential_balance.md#0x1_confidential_balance_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_confidential_balance_split_into_chunks_u128"></a>

## Function `split_into_chunks_u128`

Paused: always aborts with <code><a href="confidential_balance.md#0x1_confidential_balance_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code><b>public</b> <b>fun</b> <a href="confidential_balance.md#0x1_confidential_balance_split_into_chunks_u128">split_into_chunks_u128</a>(_amount: u128): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255_Scalar">ristretto255::Scalar</a>&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_balance.md#0x1_confidential_balance_split_into_chunks_u128">split_into_chunks_u128</a>(_amount: u128): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;Scalar&gt; {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="confidential_balance.md#0x1_confidential_balance_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_confidential_balance_get_pending_balance_chunks"></a>

## Function `get_pending_balance_chunks`

Paused: always aborts with <code><a href="confidential_balance.md#0x1_confidential_balance_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="confidential_balance.md#0x1_confidential_balance_get_pending_balance_chunks">get_pending_balance_chunks</a>(): u64
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_balance.md#0x1_confidential_balance_get_pending_balance_chunks">get_pending_balance_chunks</a>(): u64 {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="confidential_balance.md#0x1_confidential_balance_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_confidential_balance_get_actual_balance_chunks"></a>

## Function `get_actual_balance_chunks`

Paused: always aborts with <code><a href="confidential_balance.md#0x1_confidential_balance_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="confidential_balance.md#0x1_confidential_balance_get_actual_balance_chunks">get_actual_balance_chunks</a>(): u64
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_balance.md#0x1_confidential_balance_get_actual_balance_chunks">get_actual_balance_chunks</a>(): u64 {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="confidential_balance.md#0x1_confidential_balance_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_confidential_balance_get_chunk_size_bits"></a>

## Function `get_chunk_size_bits`

Paused: always aborts with <code><a href="confidential_balance.md#0x1_confidential_balance_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="confidential_balance.md#0x1_confidential_balance_get_chunk_size_bits">get_chunk_size_bits</a>(): u64
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_balance.md#0x1_confidential_balance_get_chunk_size_bits">get_chunk_size_bits</a>(): u64 {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="confidential_balance.md#0x1_confidential_balance_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>


[move-book]: https://aptos.dev/move/book/SUMMARY
