
<a id="0x1_publish_allowlist"></a>

# Module `0x1::publish_allowlist`

Governance-controlled allowlist of addresses that may publish or upgrade packages.
Framework reserved addresses (0x1-0xa) are always allowed.


-  [Resource `PublishAllowlist`](#0x1_publish_allowlist_PublishAllowlist)
-  [Constants](#@Constants_0)
-  [Function `initialize`](#0x1_publish_allowlist_initialize)
-  [Function `set_enabled`](#0x1_publish_allowlist_set_enabled)
-  [Function `add_approved_addresses`](#0x1_publish_allowlist_add_approved_addresses)
-  [Function `remove_approved_addresses`](#0x1_publish_allowlist_remove_approved_addresses)
-  [Function `is_enabled`](#0x1_publish_allowlist_is_enabled)
-  [Function `approved_addresses`](#0x1_publish_allowlist_approved_addresses)
-  [Function `is_publisher_allowed`](#0x1_publish_allowlist_is_publisher_allowed)
-  [Function `assert_publisher_allowed`](#0x1_publish_allowlist_assert_publisher_allowed)
-  [Function `borrow_allowlist_mut`](#0x1_publish_allowlist_borrow_allowlist_mut)
-  [Function `assert_unique`](#0x1_publish_allowlist_assert_unique)


<pre><code><b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error">0x1::error</a>;
<b>use</b> <a href="system_addresses.md#0x1_system_addresses">0x1::system_addresses</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">0x1::vector</a>;
</code></pre>



<a id="0x1_publish_allowlist_PublishAllowlist"></a>

## Resource `PublishAllowlist`



<pre><code><b>struct</b> <a href="publish_allowlist.md#0x1_publish_allowlist_PublishAllowlist">PublishAllowlist</a> <b>has</b> key
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>enabled: bool</code>
</dt>
<dd>

</dd>
<dt>
<code>approved_addresses: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="@Constants_0"></a>

## Constants


<a id="0x1_publish_allowlist_EADDRESS_ALREADY_APPROVED"></a>

The address is already approved.


<pre><code><b>const</b> <a href="publish_allowlist.md#0x1_publish_allowlist_EADDRESS_ALREADY_APPROVED">EADDRESS_ALREADY_APPROVED</a>: u64 = 4;
</code></pre>



<a id="0x1_publish_allowlist_EADDRESS_NOT_APPROVED"></a>

The address is not approved.


<pre><code><b>const</b> <a href="publish_allowlist.md#0x1_publish_allowlist_EADDRESS_NOT_APPROVED">EADDRESS_NOT_APPROVED</a>: u64 = 5;
</code></pre>



<a id="0x1_publish_allowlist_EALLOWLIST_ALREADY_EXISTS"></a>

The allowlist has already been initialized.


<pre><code><b>const</b> <a href="publish_allowlist.md#0x1_publish_allowlist_EALLOWLIST_ALREADY_EXISTS">EALLOWLIST_ALREADY_EXISTS</a>: u64 = 1;
</code></pre>



<a id="0x1_publish_allowlist_EALLOWLIST_DOES_NOT_EXIST"></a>

The allowlist has not been initialized.


<pre><code><b>const</b> <a href="publish_allowlist.md#0x1_publish_allowlist_EALLOWLIST_DOES_NOT_EXIST">EALLOWLIST_DOES_NOT_EXIST</a>: u64 = 2;
</code></pre>



<a id="0x1_publish_allowlist_EDUPLICATE_ADDRESS"></a>

An address was supplied more than once.


<pre><code><b>const</b> <a href="publish_allowlist.md#0x1_publish_allowlist_EDUPLICATE_ADDRESS">EDUPLICATE_ADDRESS</a>: u64 = 3;
</code></pre>



<a id="0x1_publish_allowlist_EPUBLISHER_NOT_APPROVED"></a>

The publisher is not approved to publish or upgrade packages.


<pre><code><b>const</b> <a href="publish_allowlist.md#0x1_publish_allowlist_EPUBLISHER_NOT_APPROVED">EPUBLISHER_NOT_APPROVED</a>: u64 = 6;
</code></pre>



<a id="0x1_publish_allowlist_initialize"></a>

## Function `initialize`



<pre><code><b>public</b> <b>fun</b> <a href="publish_allowlist.md#0x1_publish_allowlist_initialize">initialize</a>(aptos_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, enabled: bool, approved_addresses: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="publish_allowlist.md#0x1_publish_allowlist_initialize">initialize</a>(
    aptos_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    enabled: bool,
    approved_addresses: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;,
) {
    <a href="system_addresses.md#0x1_system_addresses_assert_aptos_framework">system_addresses::assert_aptos_framework</a>(aptos_framework);
    <b>assert</b>!(
        !<b>exists</b>&lt;<a href="publish_allowlist.md#0x1_publish_allowlist_PublishAllowlist">PublishAllowlist</a>&gt;(@aptos_framework),
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_already_exists">error::already_exists</a>(<a href="publish_allowlist.md#0x1_publish_allowlist_EALLOWLIST_ALREADY_EXISTS">EALLOWLIST_ALREADY_EXISTS</a>),
    );
    <a href="publish_allowlist.md#0x1_publish_allowlist_assert_unique">assert_unique</a>(&approved_addresses);
    <b>move_to</b>(aptos_framework, <a href="publish_allowlist.md#0x1_publish_allowlist_PublishAllowlist">PublishAllowlist</a> { enabled, approved_addresses });
}
</code></pre>



</details>

<a id="0x1_publish_allowlist_set_enabled"></a>

## Function `set_enabled`



<pre><code><b>public</b> <b>fun</b> <a href="publish_allowlist.md#0x1_publish_allowlist_set_enabled">set_enabled</a>(aptos_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, enabled: bool)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="publish_allowlist.md#0x1_publish_allowlist_set_enabled">set_enabled</a>(aptos_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, enabled: bool) <b>acquires</b> <a href="publish_allowlist.md#0x1_publish_allowlist_PublishAllowlist">PublishAllowlist</a> {
    <a href="system_addresses.md#0x1_system_addresses_assert_aptos_framework">system_addresses::assert_aptos_framework</a>(aptos_framework);
    <a href="publish_allowlist.md#0x1_publish_allowlist_borrow_allowlist_mut">borrow_allowlist_mut</a>().enabled = enabled;
}
</code></pre>



</details>

<a id="0x1_publish_allowlist_add_approved_addresses"></a>

## Function `add_approved_addresses`



<pre><code><b>public</b> <b>fun</b> <a href="publish_allowlist.md#0x1_publish_allowlist_add_approved_addresses">add_approved_addresses</a>(aptos_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, addresses: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="publish_allowlist.md#0x1_publish_allowlist_add_approved_addresses">add_approved_addresses</a>(
    aptos_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    addresses: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;,
) <b>acquires</b> <a href="publish_allowlist.md#0x1_publish_allowlist_PublishAllowlist">PublishAllowlist</a> {
    <a href="system_addresses.md#0x1_system_addresses_assert_aptos_framework">system_addresses::assert_aptos_framework</a>(aptos_framework);
    <a href="publish_allowlist.md#0x1_publish_allowlist_assert_unique">assert_unique</a>(&addresses);
    <b>let</b> approved = &<b>mut</b> <a href="publish_allowlist.md#0x1_publish_allowlist_borrow_allowlist_mut">borrow_allowlist_mut</a>().approved_addresses;
    <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_for_each">vector::for_each</a>(addresses, |addr| {
        <b>assert</b>!(
            !<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_contains">vector::contains</a>(approved, &addr),
            <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_already_exists">error::already_exists</a>(<a href="publish_allowlist.md#0x1_publish_allowlist_EADDRESS_ALREADY_APPROVED">EADDRESS_ALREADY_APPROVED</a>),
        );
        <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_push_back">vector::push_back</a>(approved, addr);
    });
}
</code></pre>



</details>

<a id="0x1_publish_allowlist_remove_approved_addresses"></a>

## Function `remove_approved_addresses`



<pre><code><b>public</b> <b>fun</b> <a href="publish_allowlist.md#0x1_publish_allowlist_remove_approved_addresses">remove_approved_addresses</a>(aptos_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, addresses: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="publish_allowlist.md#0x1_publish_allowlist_remove_approved_addresses">remove_approved_addresses</a>(
    aptos_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    addresses: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;,
) <b>acquires</b> <a href="publish_allowlist.md#0x1_publish_allowlist_PublishAllowlist">PublishAllowlist</a> {
    <a href="system_addresses.md#0x1_system_addresses_assert_aptos_framework">system_addresses::assert_aptos_framework</a>(aptos_framework);
    <b>let</b> approved = &<b>mut</b> <a href="publish_allowlist.md#0x1_publish_allowlist_borrow_allowlist_mut">borrow_allowlist_mut</a>().approved_addresses;
    <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_for_each">vector::for_each</a>(addresses, |addr| {
        <b>let</b> (found, index) = <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_index_of">vector::index_of</a>(approved, &addr);
        <b>assert</b>!(found, <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_not_found">error::not_found</a>(<a href="publish_allowlist.md#0x1_publish_allowlist_EADDRESS_NOT_APPROVED">EADDRESS_NOT_APPROVED</a>));
        <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_remove">vector::remove</a>(approved, index);
    });
}
</code></pre>



</details>

<a id="0x1_publish_allowlist_is_enabled"></a>

## Function `is_enabled`



<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="publish_allowlist.md#0x1_publish_allowlist_is_enabled">is_enabled</a>(): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="publish_allowlist.md#0x1_publish_allowlist_is_enabled">is_enabled</a>(): bool <b>acquires</b> <a href="publish_allowlist.md#0x1_publish_allowlist_PublishAllowlist">PublishAllowlist</a> {
    <b>exists</b>&lt;<a href="publish_allowlist.md#0x1_publish_allowlist_PublishAllowlist">PublishAllowlist</a>&gt;(@aptos_framework)
        && <b>borrow_global</b>&lt;<a href="publish_allowlist.md#0x1_publish_allowlist_PublishAllowlist">PublishAllowlist</a>&gt;(@aptos_framework).enabled
}
</code></pre>



</details>

<a id="0x1_publish_allowlist_approved_addresses"></a>

## Function `approved_addresses`



<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="publish_allowlist.md#0x1_publish_allowlist_approved_addresses">approved_addresses</a>(): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="publish_allowlist.md#0x1_publish_allowlist_approved_addresses">approved_addresses</a>(): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt; <b>acquires</b> <a href="publish_allowlist.md#0x1_publish_allowlist_PublishAllowlist">PublishAllowlist</a> {
    <b>if</b> (!<b>exists</b>&lt;<a href="publish_allowlist.md#0x1_publish_allowlist_PublishAllowlist">PublishAllowlist</a>&gt;(@aptos_framework)) {
        <b>return</b> <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>[]
    };
    <b>borrow_global</b>&lt;<a href="publish_allowlist.md#0x1_publish_allowlist_PublishAllowlist">PublishAllowlist</a>&gt;(@aptos_framework).approved_addresses
}
</code></pre>



</details>

<a id="0x1_publish_allowlist_is_publisher_allowed"></a>

## Function `is_publisher_allowed`



<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="publish_allowlist.md#0x1_publish_allowlist_is_publisher_allowed">is_publisher_allowed</a>(publisher: <b>address</b>): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="publish_allowlist.md#0x1_publish_allowlist_is_publisher_allowed">is_publisher_allowed</a>(publisher: <b>address</b>): bool <b>acquires</b> <a href="publish_allowlist.md#0x1_publish_allowlist_PublishAllowlist">PublishAllowlist</a> {
    <b>if</b> (!<a href="publish_allowlist.md#0x1_publish_allowlist_is_enabled">is_enabled</a>() || <a href="system_addresses.md#0x1_system_addresses_is_framework_reserved_address">system_addresses::is_framework_reserved_address</a>(publisher)) {
        <b>return</b> <b>true</b>
    };
    <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_contains">vector::contains</a>(
        &<b>borrow_global</b>&lt;<a href="publish_allowlist.md#0x1_publish_allowlist_PublishAllowlist">PublishAllowlist</a>&gt;(@aptos_framework).approved_addresses,
        &publisher,
    )
}
</code></pre>



</details>

<a id="0x1_publish_allowlist_assert_publisher_allowed"></a>

## Function `assert_publisher_allowed`



<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="publish_allowlist.md#0x1_publish_allowlist_assert_publisher_allowed">assert_publisher_allowed</a>(publisher: <b>address</b>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="publish_allowlist.md#0x1_publish_allowlist_assert_publisher_allowed">assert_publisher_allowed</a>(publisher: <b>address</b>) <b>acquires</b> <a href="publish_allowlist.md#0x1_publish_allowlist_PublishAllowlist">PublishAllowlist</a> {
    <b>assert</b>!(
        <a href="publish_allowlist.md#0x1_publish_allowlist_is_publisher_allowed">is_publisher_allowed</a>(publisher),
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_permission_denied">error::permission_denied</a>(<a href="publish_allowlist.md#0x1_publish_allowlist_EPUBLISHER_NOT_APPROVED">EPUBLISHER_NOT_APPROVED</a>),
    );
}
</code></pre>



</details>

<a id="0x1_publish_allowlist_borrow_allowlist_mut"></a>

## Function `borrow_allowlist_mut`



<pre><code><b>fun</b> <a href="publish_allowlist.md#0x1_publish_allowlist_borrow_allowlist_mut">borrow_allowlist_mut</a>(): &<b>mut</b> <a href="publish_allowlist.md#0x1_publish_allowlist_PublishAllowlist">publish_allowlist::PublishAllowlist</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code>inline <b>fun</b> <a href="publish_allowlist.md#0x1_publish_allowlist_borrow_allowlist_mut">borrow_allowlist_mut</a>(): &<b>mut</b> <a href="publish_allowlist.md#0x1_publish_allowlist_PublishAllowlist">PublishAllowlist</a> <b>acquires</b> <a href="publish_allowlist.md#0x1_publish_allowlist_PublishAllowlist">PublishAllowlist</a> {
    <b>assert</b>!(
        <b>exists</b>&lt;<a href="publish_allowlist.md#0x1_publish_allowlist_PublishAllowlist">PublishAllowlist</a>&gt;(@aptos_framework),
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_not_found">error::not_found</a>(<a href="publish_allowlist.md#0x1_publish_allowlist_EALLOWLIST_DOES_NOT_EXIST">EALLOWLIST_DOES_NOT_EXIST</a>),
    );
    <b>borrow_global_mut</b>&lt;<a href="publish_allowlist.md#0x1_publish_allowlist_PublishAllowlist">PublishAllowlist</a>&gt;(@aptos_framework)
}
</code></pre>



</details>

<a id="0x1_publish_allowlist_assert_unique"></a>

## Function `assert_unique`



<pre><code><b>fun</b> <a href="publish_allowlist.md#0x1_publish_allowlist_assert_unique">assert_unique</a>(addresses: &<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="publish_allowlist.md#0x1_publish_allowlist_assert_unique">assert_unique</a>(addresses: &<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;) {
    <b>let</b> len = <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_length">vector::length</a>(addresses);
    <b>let</b> i = 0;
    <b>while</b> (i &lt; len) {
        <b>let</b> j = i + 1;
        <b>while</b> (j &lt; len) {
            <b>assert</b>!(
                <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_borrow">vector::borrow</a>(addresses, i) != <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_borrow">vector::borrow</a>(addresses, j),
                <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="publish_allowlist.md#0x1_publish_allowlist_EDUPLICATE_ADDRESS">EDUPLICATE_ADDRESS</a>),
            );
            j = j + 1;
        };
        i = i + 1;
    };
}
</code></pre>



</details>


[move-book]: https://aptos.dev/move/book/SUMMARY
