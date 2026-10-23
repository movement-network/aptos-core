
<a id="0x1_allowlist"></a>

# Module `0x1::allowlist`



-  [Struct `Allowlist`](#0x1_allowlist_Allowlist)
-  [Constants](#@Constants_0)
-  [Function `new`](#0x1_allowlist_new)
-  [Function `enable`](#0x1_allowlist_enable)
-  [Function `disable`](#0x1_allowlist_disable)
-  [Function `add`](#0x1_allowlist_add)
-  [Function `remove`](#0x1_allowlist_remove)
-  [Function `is_enabled`](#0x1_allowlist_is_enabled)
-  [Function `is_allowed`](#0x1_allowlist_is_allowed)
-  [Function `get_allowed_senders`](#0x1_allowlist_get_allowed_senders)


<pre><code><b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error">0x1::error</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">0x1::vector</a>;
</code></pre>



<a id="0x1_allowlist_Allowlist"></a>

## Struct `Allowlist`



<pre><code><b>struct</b> <a href="allowlist.md#0x1_allowlist_Allowlist">Allowlist</a> <b>has</b> store
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
<code>senders: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="@Constants_0"></a>

## Constants


<a id="0x1_allowlist_EALLOWLIST_FULL"></a>



<pre><code><b>const</b> <a href="allowlist.md#0x1_allowlist_EALLOWLIST_FULL">EALLOWLIST_FULL</a>: u64 = 2;
</code></pre>



<a id="0x1_allowlist_MAX_ALLOWED_SENDERS"></a>



<pre><code><b>const</b> <a href="allowlist.md#0x1_allowlist_MAX_ALLOWED_SENDERS">MAX_ALLOWED_SENDERS</a>: u64 = 256;
</code></pre>



<a id="0x1_allowlist_new"></a>

## Function `new`



<pre><code><b>public</b> <b>fun</b> <a href="allowlist.md#0x1_allowlist_new">new</a>(): <a href="allowlist.md#0x1_allowlist_Allowlist">allowlist::Allowlist</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="allowlist.md#0x1_allowlist_new">new</a>(): <a href="allowlist.md#0x1_allowlist_Allowlist">Allowlist</a> {
    <a href="allowlist.md#0x1_allowlist_Allowlist">Allowlist</a> { enabled: <b>false</b>, senders: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>[] }
}
</code></pre>



</details>

<a id="0x1_allowlist_enable"></a>

## Function `enable`



<pre><code><b>public</b> <b>fun</b> <a href="allowlist.md#0x1_allowlist_enable">enable</a>(<a href="allowlist.md#0x1_allowlist">allowlist</a>: &<b>mut</b> <a href="allowlist.md#0x1_allowlist_Allowlist">allowlist::Allowlist</a>): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="allowlist.md#0x1_allowlist_enable">enable</a>(<a href="allowlist.md#0x1_allowlist">allowlist</a>: &<b>mut</b> <a href="allowlist.md#0x1_allowlist_Allowlist">Allowlist</a>): bool {
    <b>if</b> (<a href="allowlist.md#0x1_allowlist">allowlist</a>.enabled) {
        <b>false</b>
    } <b>else</b> {
        <a href="allowlist.md#0x1_allowlist">allowlist</a>.enabled = <b>true</b>;
        <b>true</b>
    }
}
</code></pre>



</details>

<a id="0x1_allowlist_disable"></a>

## Function `disable`



<pre><code><b>public</b> <b>fun</b> <a href="allowlist.md#0x1_allowlist_disable">disable</a>(<a href="allowlist.md#0x1_allowlist">allowlist</a>: &<b>mut</b> <a href="allowlist.md#0x1_allowlist_Allowlist">allowlist::Allowlist</a>): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="allowlist.md#0x1_allowlist_disable">disable</a>(<a href="allowlist.md#0x1_allowlist">allowlist</a>: &<b>mut</b> <a href="allowlist.md#0x1_allowlist_Allowlist">Allowlist</a>): bool {
    <b>if</b> (!<a href="allowlist.md#0x1_allowlist">allowlist</a>.enabled) {
        <b>false</b>
    } <b>else</b> {
        <a href="allowlist.md#0x1_allowlist">allowlist</a>.enabled = <b>false</b>;
        <b>true</b>
    }
}
</code></pre>



</details>

<a id="0x1_allowlist_add"></a>

## Function `add`



<pre><code><b>public</b> <b>fun</b> <a href="allowlist.md#0x1_allowlist_add">add</a>(<a href="allowlist.md#0x1_allowlist">allowlist</a>: &<b>mut</b> <a href="allowlist.md#0x1_allowlist_Allowlist">allowlist::Allowlist</a>, sender: <b>address</b>): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="allowlist.md#0x1_allowlist_add">add</a>(<a href="allowlist.md#0x1_allowlist">allowlist</a>: &<b>mut</b> <a href="allowlist.md#0x1_allowlist_Allowlist">Allowlist</a>, sender: <b>address</b>): bool {
    <b>let</b> (found, _) = <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_index_of">vector::index_of</a>(&<a href="allowlist.md#0x1_allowlist">allowlist</a>.senders, &sender);
    <b>if</b> (found) {
        <b>false</b>
    } <b>else</b> {
        <b>assert</b>!(<a href="allowlist.md#0x1_allowlist">allowlist</a>.senders.length() &lt; <a href="allowlist.md#0x1_allowlist_MAX_ALLOWED_SENDERS">MAX_ALLOWED_SENDERS</a>, <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_resource_exhausted">error::resource_exhausted</a>(<a href="allowlist.md#0x1_allowlist_EALLOWLIST_FULL">EALLOWLIST_FULL</a>));
        <a href="allowlist.md#0x1_allowlist">allowlist</a>.senders.push_back(sender);
        <b>true</b>
    }
}
</code></pre>



</details>

<a id="0x1_allowlist_remove"></a>

## Function `remove`



<pre><code><b>public</b> <b>fun</b> <a href="allowlist.md#0x1_allowlist_remove">remove</a>(<a href="allowlist.md#0x1_allowlist">allowlist</a>: &<b>mut</b> <a href="allowlist.md#0x1_allowlist_Allowlist">allowlist::Allowlist</a>, sender: <b>address</b>): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="allowlist.md#0x1_allowlist_remove">remove</a>(<a href="allowlist.md#0x1_allowlist">allowlist</a>: &<b>mut</b> <a href="allowlist.md#0x1_allowlist_Allowlist">Allowlist</a>, sender: <b>address</b>): bool {
    <b>let</b> (found, index) = <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_index_of">vector::index_of</a>(&<a href="allowlist.md#0x1_allowlist">allowlist</a>.senders, &sender);
    <b>if</b> (found) {
        <a href="allowlist.md#0x1_allowlist">allowlist</a>.senders.<a href="allowlist.md#0x1_allowlist_remove">remove</a>(index);
        <b>true</b>
    } <b>else</b> {
        <b>false</b>
    }
}
</code></pre>



</details>

<a id="0x1_allowlist_is_enabled"></a>

## Function `is_enabled`



<pre><code><b>public</b> <b>fun</b> <a href="allowlist.md#0x1_allowlist_is_enabled">is_enabled</a>(<a href="allowlist.md#0x1_allowlist">allowlist</a>: &<a href="allowlist.md#0x1_allowlist_Allowlist">allowlist::Allowlist</a>): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="allowlist.md#0x1_allowlist_is_enabled">is_enabled</a>(<a href="allowlist.md#0x1_allowlist">allowlist</a>: &<a href="allowlist.md#0x1_allowlist_Allowlist">Allowlist</a>): bool {
    <a href="allowlist.md#0x1_allowlist">allowlist</a>.enabled
}
</code></pre>



</details>

<a id="0x1_allowlist_is_allowed"></a>

## Function `is_allowed`



<pre><code><b>public</b> <b>fun</b> <a href="allowlist.md#0x1_allowlist_is_allowed">is_allowed</a>(<a href="allowlist.md#0x1_allowlist">allowlist</a>: &<a href="allowlist.md#0x1_allowlist_Allowlist">allowlist::Allowlist</a>, sender: <b>address</b>): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="allowlist.md#0x1_allowlist_is_allowed">is_allowed</a>(<a href="allowlist.md#0x1_allowlist">allowlist</a>: &<a href="allowlist.md#0x1_allowlist_Allowlist">Allowlist</a>, sender: <b>address</b>): bool {
    <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_contains">vector::contains</a>(&<a href="allowlist.md#0x1_allowlist">allowlist</a>.senders, &sender)
}
</code></pre>



</details>

<a id="0x1_allowlist_get_allowed_senders"></a>

## Function `get_allowed_senders`



<pre><code><b>public</b> <b>fun</b> <a href="allowlist.md#0x1_allowlist_get_allowed_senders">get_allowed_senders</a>(<a href="allowlist.md#0x1_allowlist">allowlist</a>: &<a href="allowlist.md#0x1_allowlist_Allowlist">allowlist::Allowlist</a>): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="allowlist.md#0x1_allowlist_get_allowed_senders">get_allowed_senders</a>(<a href="allowlist.md#0x1_allowlist">allowlist</a>: &<a href="allowlist.md#0x1_allowlist_Allowlist">Allowlist</a>): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt; {
    <a href="allowlist.md#0x1_allowlist">allowlist</a>.senders
}
</code></pre>



</details>


[move-book]: https://aptos.dev/move/book/SUMMARY
