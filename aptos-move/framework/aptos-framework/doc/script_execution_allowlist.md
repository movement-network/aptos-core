
<a id="0x1_script_execution_allowlist"></a>

# Module `0x1::script_execution_allowlist`

Explicit primary-sender membership for standalone Move script execution.
Enforcement is enabled and disabled by framework governance.


-  [Resource `AllowedSenders`](#0x1_script_execution_allowlist_AllowedSenders)
-  [Struct `AllowedSenderChanged`](#0x1_script_execution_allowlist_AllowedSenderChanged)
-  [Struct `EnabledChanged`](#0x1_script_execution_allowlist_EnabledChanged)
-  [Constants](#@Constants_0)
-  [Function `initialize`](#0x1_script_execution_allowlist_initialize)
-  [Function `enable`](#0x1_script_execution_allowlist_enable)
-  [Function `disable`](#0x1_script_execution_allowlist_disable)
-  [Function `add`](#0x1_script_execution_allowlist_add)
-  [Function `remove`](#0x1_script_execution_allowlist_remove)
-  [Function `get_allowed_senders`](#0x1_script_execution_allowlist_get_allowed_senders)
-  [Function `is_allowed`](#0x1_script_execution_allowlist_is_allowed)
-  [Function `is_enabled`](#0x1_script_execution_allowlist_is_enabled)


<pre><code><b>use</b> <a href="allowlist.md#0x1_allowlist">0x1::allowlist</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error">0x1::error</a>;
<b>use</b> <a href="event.md#0x1_event">0x1::event</a>;
<b>use</b> <a href="system_addresses.md#0x1_system_addresses">0x1::system_addresses</a>;
</code></pre>



<a id="0x1_script_execution_allowlist_AllowedSenders"></a>

## Resource `AllowedSenders`



<pre><code><b>struct</b> <a href="script_execution_allowlist.md#0x1_script_execution_allowlist_AllowedSenders">AllowedSenders</a> <b>has</b> key
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code><a href="allowlist.md#0x1_allowlist">allowlist</a>: <a href="allowlist.md#0x1_allowlist_Allowlist">allowlist::Allowlist</a></code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_script_execution_allowlist_AllowedSenderChanged"></a>

## Struct `AllowedSenderChanged`



<pre><code>#[<a href="event.md#0x1_event">event</a>]
<b>struct</b> <a href="script_execution_allowlist.md#0x1_script_execution_allowlist_AllowedSenderChanged">AllowedSenderChanged</a> <b>has</b> drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>sender: <b>address</b></code>
</dt>
<dd>

</dd>
<dt>
<code>allowed: bool</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_script_execution_allowlist_EnabledChanged"></a>

## Struct `EnabledChanged`



<pre><code>#[<a href="event.md#0x1_event">event</a>]
<b>struct</b> <a href="script_execution_allowlist.md#0x1_script_execution_allowlist_EnabledChanged">EnabledChanged</a> <b>has</b> drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>enabled: bool</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="@Constants_0"></a>

## Constants


<a id="0x1_script_execution_allowlist_ENOT_INITIALIZED"></a>



<pre><code><b>const</b> <a href="script_execution_allowlist.md#0x1_script_execution_allowlist_ENOT_INITIALIZED">ENOT_INITIALIZED</a>: u64 = 3;
</code></pre>



<a id="0x1_script_execution_allowlist_initialize"></a>

## Function `initialize`

Create an empty list without changing existing membership or enabling enforcement.
Core-resources administration and governance proposals supply the framework signer.


<pre><code><b>public</b> entry <b>fun</b> <a href="script_execution_allowlist.md#0x1_script_execution_allowlist_initialize">initialize</a>(framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="script_execution_allowlist.md#0x1_script_execution_allowlist_initialize">initialize</a>(framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>) {
    <a href="system_addresses.md#0x1_system_addresses_assert_aptos_framework">system_addresses::assert_aptos_framework</a>(framework);
    <b>if</b> (!<b>exists</b>&lt;<a href="script_execution_allowlist.md#0x1_script_execution_allowlist_AllowedSenders">AllowedSenders</a>&gt;(@aptos_framework)) {
        <b>move_to</b>(framework, <a href="script_execution_allowlist.md#0x1_script_execution_allowlist_AllowedSenders">AllowedSenders</a> { <a href="allowlist.md#0x1_allowlist">allowlist</a>: <a href="allowlist.md#0x1_allowlist_new">allowlist::new</a>() });
    };
}
</code></pre>



</details>

<a id="0x1_script_execution_allowlist_enable"></a>

## Function `enable`



<pre><code><b>public</b> entry <b>fun</b> <a href="script_execution_allowlist.md#0x1_script_execution_allowlist_enable">enable</a>(framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="script_execution_allowlist.md#0x1_script_execution_allowlist_enable">enable</a>(framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>) <b>acquires</b> <a href="script_execution_allowlist.md#0x1_script_execution_allowlist_AllowedSenders">AllowedSenders</a> {
    <a href="system_addresses.md#0x1_system_addresses_assert_aptos_framework">system_addresses::assert_aptos_framework</a>(framework);
    <b>assert</b>!(<b>exists</b>&lt;<a href="script_execution_allowlist.md#0x1_script_execution_allowlist_AllowedSenders">AllowedSenders</a>&gt;(@aptos_framework), <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_not_found">error::not_found</a>(<a href="script_execution_allowlist.md#0x1_script_execution_allowlist_ENOT_INITIALIZED">ENOT_INITIALIZED</a>));
    <b>let</b> allowed_senders = &<b>mut</b> <b>borrow_global_mut</b>&lt;<a href="script_execution_allowlist.md#0x1_script_execution_allowlist_AllowedSenders">AllowedSenders</a>&gt;(@aptos_framework).<a href="allowlist.md#0x1_allowlist">allowlist</a>;
    <b>if</b> (<a href="allowlist.md#0x1_allowlist_enable">allowlist::enable</a>(allowed_senders)) {
        <a href="event.md#0x1_event_emit">event::emit</a>(<a href="script_execution_allowlist.md#0x1_script_execution_allowlist_EnabledChanged">EnabledChanged</a> { enabled: <b>true</b> });
    };
}
</code></pre>



</details>

<a id="0x1_script_execution_allowlist_disable"></a>

## Function `disable`



<pre><code><b>public</b> entry <b>fun</b> <a href="script_execution_allowlist.md#0x1_script_execution_allowlist_disable">disable</a>(framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="script_execution_allowlist.md#0x1_script_execution_allowlist_disable">disable</a>(framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>) <b>acquires</b> <a href="script_execution_allowlist.md#0x1_script_execution_allowlist_AllowedSenders">AllowedSenders</a> {
    <a href="system_addresses.md#0x1_system_addresses_assert_aptos_framework">system_addresses::assert_aptos_framework</a>(framework);
    <b>assert</b>!(<b>exists</b>&lt;<a href="script_execution_allowlist.md#0x1_script_execution_allowlist_AllowedSenders">AllowedSenders</a>&gt;(@aptos_framework), <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_not_found">error::not_found</a>(<a href="script_execution_allowlist.md#0x1_script_execution_allowlist_ENOT_INITIALIZED">ENOT_INITIALIZED</a>));
    <b>let</b> allowed_senders = &<b>mut</b> <b>borrow_global_mut</b>&lt;<a href="script_execution_allowlist.md#0x1_script_execution_allowlist_AllowedSenders">AllowedSenders</a>&gt;(@aptos_framework).<a href="allowlist.md#0x1_allowlist">allowlist</a>;
    <b>if</b> (<a href="allowlist.md#0x1_allowlist_disable">allowlist::disable</a>(allowed_senders)) {
        <a href="event.md#0x1_event_emit">event::emit</a>(<a href="script_execution_allowlist.md#0x1_script_execution_allowlist_EnabledChanged">EnabledChanged</a> { enabled: <b>false</b> });
    };
}
</code></pre>



</details>

<a id="0x1_script_execution_allowlist_add"></a>

## Function `add`



<pre><code><b>public</b> entry <b>fun</b> <a href="script_execution_allowlist.md#0x1_script_execution_allowlist_add">add</a>(framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, sender: <b>address</b>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="script_execution_allowlist.md#0x1_script_execution_allowlist_add">add</a>(framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, sender: <b>address</b>) <b>acquires</b> <a href="script_execution_allowlist.md#0x1_script_execution_allowlist_AllowedSenders">AllowedSenders</a> {
    <a href="system_addresses.md#0x1_system_addresses_assert_aptos_framework">system_addresses::assert_aptos_framework</a>(framework);
    <b>assert</b>!(<b>exists</b>&lt;<a href="script_execution_allowlist.md#0x1_script_execution_allowlist_AllowedSenders">AllowedSenders</a>&gt;(@aptos_framework), <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_not_found">error::not_found</a>(<a href="script_execution_allowlist.md#0x1_script_execution_allowlist_ENOT_INITIALIZED">ENOT_INITIALIZED</a>));
    <b>if</b> (<a href="allowlist.md#0x1_allowlist_add">allowlist::add</a>(&<b>mut</b> <b>borrow_global_mut</b>&lt;<a href="script_execution_allowlist.md#0x1_script_execution_allowlist_AllowedSenders">AllowedSenders</a>&gt;(@aptos_framework).<a href="allowlist.md#0x1_allowlist">allowlist</a>, sender)) {
        <a href="event.md#0x1_event_emit">event::emit</a>(<a href="script_execution_allowlist.md#0x1_script_execution_allowlist_AllowedSenderChanged">AllowedSenderChanged</a> { sender, allowed: <b>true</b> });
    };
}
</code></pre>



</details>

<a id="0x1_script_execution_allowlist_remove"></a>

## Function `remove`



<pre><code><b>public</b> entry <b>fun</b> <a href="script_execution_allowlist.md#0x1_script_execution_allowlist_remove">remove</a>(framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, sender: <b>address</b>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="script_execution_allowlist.md#0x1_script_execution_allowlist_remove">remove</a>(framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, sender: <b>address</b>) <b>acquires</b> <a href="script_execution_allowlist.md#0x1_script_execution_allowlist_AllowedSenders">AllowedSenders</a> {
    <a href="system_addresses.md#0x1_system_addresses_assert_aptos_framework">system_addresses::assert_aptos_framework</a>(framework);
    <b>assert</b>!(<b>exists</b>&lt;<a href="script_execution_allowlist.md#0x1_script_execution_allowlist_AllowedSenders">AllowedSenders</a>&gt;(@aptos_framework), <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_not_found">error::not_found</a>(<a href="script_execution_allowlist.md#0x1_script_execution_allowlist_ENOT_INITIALIZED">ENOT_INITIALIZED</a>));
    <b>if</b> (<a href="allowlist.md#0x1_allowlist_remove">allowlist::remove</a>(&<b>mut</b> <b>borrow_global_mut</b>&lt;<a href="script_execution_allowlist.md#0x1_script_execution_allowlist_AllowedSenders">AllowedSenders</a>&gt;(@aptos_framework).<a href="allowlist.md#0x1_allowlist">allowlist</a>, sender)) {
        <a href="event.md#0x1_event_emit">event::emit</a>(<a href="script_execution_allowlist.md#0x1_script_execution_allowlist_AllowedSenderChanged">AllowedSenderChanged</a> { sender, allowed: <b>false</b> });
    };
}
</code></pre>



</details>

<a id="0x1_script_execution_allowlist_get_allowed_senders"></a>

## Function `get_allowed_senders`

Return configured members; an uninitialized list has no members.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="script_execution_allowlist.md#0x1_script_execution_allowlist_get_allowed_senders">get_allowed_senders</a>(): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="script_execution_allowlist.md#0x1_script_execution_allowlist_get_allowed_senders">get_allowed_senders</a>(): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt; <b>acquires</b> <a href="script_execution_allowlist.md#0x1_script_execution_allowlist_AllowedSenders">AllowedSenders</a> {
    <b>if</b> (<b>exists</b>&lt;<a href="script_execution_allowlist.md#0x1_script_execution_allowlist_AllowedSenders">AllowedSenders</a>&gt;(@aptos_framework)) {
        <a href="allowlist.md#0x1_allowlist_get_allowed_senders">allowlist::get_allowed_senders</a>(&<a href="script_execution_allowlist.md#0x1_script_execution_allowlist_AllowedSenders">AllowedSenders</a>[@aptos_framework].<a href="allowlist.md#0x1_allowlist">allowlist</a>)
    } <b>else</b> {
        <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>[]
    }
}
</code></pre>



</details>

<a id="0x1_script_execution_allowlist_is_allowed"></a>

## Function `is_allowed`

Check membership only. The module's enabled state determines whether enforcement is active.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="script_execution_allowlist.md#0x1_script_execution_allowlist_is_allowed">is_allowed</a>(sender: <b>address</b>): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="script_execution_allowlist.md#0x1_script_execution_allowlist_is_allowed">is_allowed</a>(sender: <b>address</b>): bool <b>acquires</b> <a href="script_execution_allowlist.md#0x1_script_execution_allowlist_AllowedSenders">AllowedSenders</a> {
    <b>exists</b>&lt;<a href="script_execution_allowlist.md#0x1_script_execution_allowlist_AllowedSenders">AllowedSenders</a>&gt;(@aptos_framework)
        && <a href="allowlist.md#0x1_allowlist_is_allowed">allowlist::is_allowed</a>(&<a href="script_execution_allowlist.md#0x1_script_execution_allowlist_AllowedSenders">AllowedSenders</a>[@aptos_framework].<a href="allowlist.md#0x1_allowlist">allowlist</a>, sender)
}
</code></pre>



</details>

<a id="0x1_script_execution_allowlist_is_enabled"></a>

## Function `is_enabled`



<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="script_execution_allowlist.md#0x1_script_execution_allowlist_is_enabled">is_enabled</a>(): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="script_execution_allowlist.md#0x1_script_execution_allowlist_is_enabled">is_enabled</a>(): bool <b>acquires</b> <a href="script_execution_allowlist.md#0x1_script_execution_allowlist_AllowedSenders">AllowedSenders</a> {
    <b>exists</b>&lt;<a href="script_execution_allowlist.md#0x1_script_execution_allowlist_AllowedSenders">AllowedSenders</a>&gt;(@aptos_framework) && <a href="allowlist.md#0x1_allowlist_is_enabled">allowlist::is_enabled</a>(&<a href="script_execution_allowlist.md#0x1_script_execution_allowlist_AllowedSenders">AllowedSenders</a>[@aptos_framework].<a href="allowlist.md#0x1_allowlist">allowlist</a>)
}
</code></pre>



</details>


[move-book]: https://aptos.dev/move/book/SUMMARY
