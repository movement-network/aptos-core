
<a id="0x1_transaction_permissions"></a>

# Module `0x1::transaction_permissions`

An on-chain rule table that decides whether a transaction is allowed to run.

Each rule matches a sender (a specific account, or all accounts) and a
transaction kind (module deploy, module upgrade, script, or anything else)
and carries an allow/deny verdict. Rules are evaluated in order and the
first match wins; when no rule matches, the transaction is allowed.

The table is only data here: enforcement happens in the VM, which reads
this resource when the <code>TRANSACTION_PERMISSIONS</code> feature is enabled. The VM
never denies approved governance scripts, framework-reserved or
core-resources senders, or <code><a href="aptos_governance.md#0x1_aptos_governance">aptos_governance</a></code> entry functions, so the table
cannot lock out the governance path needed to edit it.


-  [Struct `Rule`](#0x1_transaction_permissions_Rule)
-  [Resource `TransactionPermissions`](#0x1_transaction_permissions_TransactionPermissions)
-  [Struct `RuleInserted`](#0x1_transaction_permissions_RuleInserted)
-  [Struct `RuleRemoved`](#0x1_transaction_permissions_RuleRemoved)
-  [Constants](#@Constants_0)
-  [Function `initialize`](#0x1_transaction_permissions_initialize)
-  [Function `initialize_extension`](#0x1_transaction_permissions_initialize_extension)
-  [Function `insert_rule_for_sender`](#0x1_transaction_permissions_insert_rule_for_sender)
-  [Function `insert_rule_for_all`](#0x1_transaction_permissions_insert_rule_for_all)
-  [Function `insert_rule`](#0x1_transaction_permissions_insert_rule)
-  [Function `remove_rule`](#0x1_transaction_permissions_remove_rule)
-  [Function `get_rules`](#0x1_transaction_permissions_get_rules)
-  [Function `check`](#0x1_transaction_permissions_check)
-  [Function `is_allowed`](#0x1_transaction_permissions_is_allowed)
-  [Function `kind_deploy`](#0x1_transaction_permissions_kind_deploy)
-  [Function `kind_upgrade`](#0x1_transaction_permissions_kind_upgrade)
-  [Function `kind_script`](#0x1_transaction_permissions_kind_script)
-  [Function `kind_other`](#0x1_transaction_permissions_kind_other)
-  [Function `max_rules`](#0x1_transaction_permissions_max_rules)
-  [Function `assert_initialized`](#0x1_transaction_permissions_assert_initialized)


<pre><code><b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error">0x1::error</a>;
<b>use</b> <a href="event.md#0x1_event">0x1::event</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option">0x1::option</a>;
<b>use</b> <a href="system_addresses.md#0x1_system_addresses">0x1::system_addresses</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">0x1::vector</a>;
</code></pre>



<a id="0x1_transaction_permissions_Rule"></a>

## Struct `Rule`



<pre><code><b>struct</b> <a href="transaction_permissions.md#0x1_transaction_permissions_Rule">Rule</a> <b>has</b> <b>copy</b>, drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>sender: <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_Option">option::Option</a>&lt;<b>address</b>&gt;</code>
</dt>
<dd>
 The sender this rule applies to; <code>none</code> matches all accounts.
</dd>
<dt>
<code>kind: u8</code>
</dt>
<dd>
 One of <code><a href="transaction_permissions.md#0x1_transaction_permissions_KIND_DEPLOY">KIND_DEPLOY</a></code>, <code><a href="transaction_permissions.md#0x1_transaction_permissions_KIND_UPGRADE">KIND_UPGRADE</a></code>, <code><a href="transaction_permissions.md#0x1_transaction_permissions_KIND_SCRIPT">KIND_SCRIPT</a></code>, <code><a href="transaction_permissions.md#0x1_transaction_permissions_KIND_OTHER">KIND_OTHER</a></code>.
</dd>
<dt>
<code>allow: bool</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_transaction_permissions_TransactionPermissions"></a>

## Resource `TransactionPermissions`

The ordered rule table, stored under @aptos_framework. Read by the VM
during transaction validation, so its layout must stay in sync with the
Rust-side <code>OnChainConfig</code> mirror.


<pre><code><b>struct</b> <a href="transaction_permissions.md#0x1_transaction_permissions_TransactionPermissions">TransactionPermissions</a> <b>has</b> key
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>rules: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="transaction_permissions.md#0x1_transaction_permissions_Rule">transaction_permissions::Rule</a>&gt;</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_transaction_permissions_RuleInserted"></a>

## Struct `RuleInserted`



<pre><code>#[<a href="event.md#0x1_event">event</a>]
<b>struct</b> <a href="transaction_permissions.md#0x1_transaction_permissions_RuleInserted">RuleInserted</a> <b>has</b> drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>index: u64</code>
</dt>
<dd>

</dd>
<dt>
<code>sender: <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_Option">option::Option</a>&lt;<b>address</b>&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>kind: u8</code>
</dt>
<dd>

</dd>
<dt>
<code>allow: bool</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_transaction_permissions_RuleRemoved"></a>

## Struct `RuleRemoved`



<pre><code>#[<a href="event.md#0x1_event">event</a>]
<b>struct</b> <a href="transaction_permissions.md#0x1_transaction_permissions_RuleRemoved">RuleRemoved</a> <b>has</b> drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>index: u64</code>
</dt>
<dd>

</dd>
<dt>
<code>sender: <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_Option">option::Option</a>&lt;<b>address</b>&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>kind: u8</code>
</dt>
<dd>

</dd>
<dt>
<code>allow: bool</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="@Constants_0"></a>

## Constants


<a id="0x1_transaction_permissions_EINVALID_TRANSACTION_KIND"></a>

The transaction kind is not one of the defined kinds.


<pre><code><b>const</b> <a href="transaction_permissions.md#0x1_transaction_permissions_EINVALID_TRANSACTION_KIND">EINVALID_TRANSACTION_KIND</a>: u64 = 3;
</code></pre>



<a id="0x1_transaction_permissions_ENOT_INITIALIZED"></a>

The permission table has not been initialized.


<pre><code><b>const</b> <a href="transaction_permissions.md#0x1_transaction_permissions_ENOT_INITIALIZED">ENOT_INITIALIZED</a>: u64 = 4;
</code></pre>



<a id="0x1_transaction_permissions_ERULE_INDEX_OUT_OF_BOUNDS"></a>

The rule index is past the end of the table.


<pre><code><b>const</b> <a href="transaction_permissions.md#0x1_transaction_permissions_ERULE_INDEX_OUT_OF_BOUNDS">ERULE_INDEX_OUT_OF_BOUNDS</a>: u64 = 1;
</code></pre>



<a id="0x1_transaction_permissions_ETOO_MANY_RULES"></a>

The table already holds the maximum number of rules.


<pre><code><b>const</b> <a href="transaction_permissions.md#0x1_transaction_permissions_ETOO_MANY_RULES">ETOO_MANY_RULES</a>: u64 = 2;
</code></pre>



<a id="0x1_transaction_permissions_KIND_DEPLOY"></a>

A transaction that publishes a package whose modules do not yet exist.


<pre><code><b>const</b> <a href="transaction_permissions.md#0x1_transaction_permissions_KIND_DEPLOY">KIND_DEPLOY</a>: u8 = 0;
</code></pre>



<a id="0x1_transaction_permissions_KIND_OTHER"></a>

Any other transaction (entry functions, multisig).


<pre><code><b>const</b> <a href="transaction_permissions.md#0x1_transaction_permissions_KIND_OTHER">KIND_OTHER</a>: u8 = 3;
</code></pre>



<a id="0x1_transaction_permissions_KIND_SCRIPT"></a>

A script transaction.


<pre><code><b>const</b> <a href="transaction_permissions.md#0x1_transaction_permissions_KIND_SCRIPT">KIND_SCRIPT</a>: u8 = 2;
</code></pre>



<a id="0x1_transaction_permissions_KIND_UPGRADE"></a>

A transaction that publishes over already-existing modules.


<pre><code><b>const</b> <a href="transaction_permissions.md#0x1_transaction_permissions_KIND_UPGRADE">KIND_UPGRADE</a>: u8 = 1;
</code></pre>



<a id="0x1_transaction_permissions_MAX_RULES"></a>

Rule evaluation runs unmetered during transaction validation, so the
table length is capped to bound the cost of a scan.


<pre><code><b>const</b> <a href="transaction_permissions.md#0x1_transaction_permissions_MAX_RULES">MAX_RULES</a>: u64 = 256;
</code></pre>



<a id="0x1_transaction_permissions_initialize"></a>

## Function `initialize`

Genesis step: create the empty rule table.


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="transaction_permissions.md#0x1_transaction_permissions_initialize">initialize</a>(aptos_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="transaction_permissions.md#0x1_transaction_permissions_initialize">initialize</a>(aptos_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>) {
    <a href="system_addresses.md#0x1_system_addresses_assert_aptos_framework">system_addresses::assert_aptos_framework</a>(aptos_framework);
    <b>if</b> (!<b>exists</b>&lt;<a href="transaction_permissions.md#0x1_transaction_permissions_TransactionPermissions">TransactionPermissions</a>&gt;(@aptos_framework)) {
        <b>move_to</b>(aptos_framework, <a href="transaction_permissions.md#0x1_transaction_permissions_TransactionPermissions">TransactionPermissions</a> { rules: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>[] });
    }
}
</code></pre>



</details>

<a id="0x1_transaction_permissions_initialize_extension"></a>

## Function `initialize_extension`

One-off initialization for chains that upgraded past genesis, invoked
through governance or a core-resources script.


<pre><code><b>public</b> entry <b>fun</b> <a href="transaction_permissions.md#0x1_transaction_permissions_initialize_extension">initialize_extension</a>(aptos_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="transaction_permissions.md#0x1_transaction_permissions_initialize_extension">initialize_extension</a>(aptos_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>) {
    <a href="transaction_permissions.md#0x1_transaction_permissions_initialize">initialize</a>(aptos_framework);
}
</code></pre>



</details>

<a id="0x1_transaction_permissions_insert_rule_for_sender"></a>

## Function `insert_rule_for_sender`

Insert a rule for one sender at <code>index</code> (0 = evaluated first; <code>index</code>
equal to the current length appends). Earlier rules take precedence.


<pre><code><b>public</b> entry <b>fun</b> <a href="transaction_permissions.md#0x1_transaction_permissions_insert_rule_for_sender">insert_rule_for_sender</a>(aptos_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, index: u64, sender: <b>address</b>, kind: u8, allow: bool)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="transaction_permissions.md#0x1_transaction_permissions_insert_rule_for_sender">insert_rule_for_sender</a>(
    aptos_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    index: u64,
    sender: <b>address</b>,
    kind: u8,
    allow: bool,
) <b>acquires</b> <a href="transaction_permissions.md#0x1_transaction_permissions_TransactionPermissions">TransactionPermissions</a> {
    <a href="transaction_permissions.md#0x1_transaction_permissions_insert_rule">insert_rule</a>(aptos_framework, index, <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_some">option::some</a>(sender), kind, allow);
}
</code></pre>



</details>

<a id="0x1_transaction_permissions_insert_rule_for_all"></a>

## Function `insert_rule_for_all`

Insert a rule matching all senders at <code>index</code> (0 = evaluated first;
<code>index</code> equal to the current length appends).


<pre><code><b>public</b> entry <b>fun</b> <a href="transaction_permissions.md#0x1_transaction_permissions_insert_rule_for_all">insert_rule_for_all</a>(aptos_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, index: u64, kind: u8, allow: bool)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="transaction_permissions.md#0x1_transaction_permissions_insert_rule_for_all">insert_rule_for_all</a>(
    aptos_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    index: u64,
    kind: u8,
    allow: bool,
) <b>acquires</b> <a href="transaction_permissions.md#0x1_transaction_permissions_TransactionPermissions">TransactionPermissions</a> {
    <a href="transaction_permissions.md#0x1_transaction_permissions_insert_rule">insert_rule</a>(aptos_framework, index, <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_none">option::none</a>(), kind, allow);
}
</code></pre>



</details>

<a id="0x1_transaction_permissions_insert_rule"></a>

## Function `insert_rule`

Insert a rule at <code>index</code>; <code>sender</code> of <code>none</code> matches all accounts.
Not an entry function only because the SDK builder cannot encode
<code>Option</code> arguments; use the <code>insert_rule_for_*</code> entry points or call
this from a governance script.


<pre><code><b>public</b> <b>fun</b> <a href="transaction_permissions.md#0x1_transaction_permissions_insert_rule">insert_rule</a>(aptos_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, index: u64, sender: <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_Option">option::Option</a>&lt;<b>address</b>&gt;, kind: u8, allow: bool)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="transaction_permissions.md#0x1_transaction_permissions_insert_rule">insert_rule</a>(
    aptos_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    index: u64,
    sender: Option&lt;<b>address</b>&gt;,
    kind: u8,
    allow: bool,
) <b>acquires</b> <a href="transaction_permissions.md#0x1_transaction_permissions_TransactionPermissions">TransactionPermissions</a> {
    <a href="system_addresses.md#0x1_system_addresses_assert_aptos_framework">system_addresses::assert_aptos_framework</a>(aptos_framework);
    <a href="transaction_permissions.md#0x1_transaction_permissions_assert_initialized">assert_initialized</a>();
    <b>assert</b>!(kind &lt;= <a href="transaction_permissions.md#0x1_transaction_permissions_KIND_OTHER">KIND_OTHER</a>, <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="transaction_permissions.md#0x1_transaction_permissions_EINVALID_TRANSACTION_KIND">EINVALID_TRANSACTION_KIND</a>));
    <b>let</b> rules = &<b>mut</b> <b>borrow_global_mut</b>&lt;<a href="transaction_permissions.md#0x1_transaction_permissions_TransactionPermissions">TransactionPermissions</a>&gt;(@aptos_framework).rules;
    <b>assert</b>!(<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_length">vector::length</a>(rules) &lt; <a href="transaction_permissions.md#0x1_transaction_permissions_MAX_RULES">MAX_RULES</a>, <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_out_of_range">error::out_of_range</a>(<a href="transaction_permissions.md#0x1_transaction_permissions_ETOO_MANY_RULES">ETOO_MANY_RULES</a>));
    <b>assert</b>!(index &lt;= <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_length">vector::length</a>(rules), <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_out_of_range">error::out_of_range</a>(<a href="transaction_permissions.md#0x1_transaction_permissions_ERULE_INDEX_OUT_OF_BOUNDS">ERULE_INDEX_OUT_OF_BOUNDS</a>));
    <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_insert">vector::insert</a>(rules, index, <a href="transaction_permissions.md#0x1_transaction_permissions_Rule">Rule</a> { sender, kind, allow });
    <a href="event.md#0x1_event_emit">event::emit</a>(<a href="transaction_permissions.md#0x1_transaction_permissions_RuleInserted">RuleInserted</a> { index, sender, kind, allow });
}
</code></pre>



</details>

<a id="0x1_transaction_permissions_remove_rule"></a>

## Function `remove_rule`

Remove the rule at <code>index</code>; later rules shift down by one.


<pre><code><b>public</b> entry <b>fun</b> <a href="transaction_permissions.md#0x1_transaction_permissions_remove_rule">remove_rule</a>(aptos_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, index: u64)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="transaction_permissions.md#0x1_transaction_permissions_remove_rule">remove_rule</a>(
    aptos_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    index: u64,
) <b>acquires</b> <a href="transaction_permissions.md#0x1_transaction_permissions_TransactionPermissions">TransactionPermissions</a> {
    <a href="system_addresses.md#0x1_system_addresses_assert_aptos_framework">system_addresses::assert_aptos_framework</a>(aptos_framework);
    <a href="transaction_permissions.md#0x1_transaction_permissions_assert_initialized">assert_initialized</a>();
    <b>let</b> rules = &<b>mut</b> <b>borrow_global_mut</b>&lt;<a href="transaction_permissions.md#0x1_transaction_permissions_TransactionPermissions">TransactionPermissions</a>&gt;(@aptos_framework).rules;
    <b>assert</b>!(index &lt; <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_length">vector::length</a>(rules), <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_out_of_range">error::out_of_range</a>(<a href="transaction_permissions.md#0x1_transaction_permissions_ERULE_INDEX_OUT_OF_BOUNDS">ERULE_INDEX_OUT_OF_BOUNDS</a>));
    <b>let</b> <a href="transaction_permissions.md#0x1_transaction_permissions_Rule">Rule</a> { sender, kind, allow } = <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_remove">vector::remove</a>(rules, index);
    <a href="event.md#0x1_event_emit">event::emit</a>(<a href="transaction_permissions.md#0x1_transaction_permissions_RuleRemoved">RuleRemoved</a> { index, sender, kind, allow });
}
</code></pre>



</details>

<a id="0x1_transaction_permissions_get_rules"></a>

## Function `get_rules`

The full rule table, in evaluation order.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="transaction_permissions.md#0x1_transaction_permissions_get_rules">get_rules</a>(): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="transaction_permissions.md#0x1_transaction_permissions_Rule">transaction_permissions::Rule</a>&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="transaction_permissions.md#0x1_transaction_permissions_get_rules">get_rules</a>(): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="transaction_permissions.md#0x1_transaction_permissions_Rule">Rule</a>&gt; <b>acquires</b> <a href="transaction_permissions.md#0x1_transaction_permissions_TransactionPermissions">TransactionPermissions</a> {
    <b>if</b> (!<b>exists</b>&lt;<a href="transaction_permissions.md#0x1_transaction_permissions_TransactionPermissions">TransactionPermissions</a>&gt;(@aptos_framework)) {
        <b>return</b> <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>[]
    };
    <b>borrow_global</b>&lt;<a href="transaction_permissions.md#0x1_transaction_permissions_TransactionPermissions">TransactionPermissions</a>&gt;(@aptos_framework).rules
}
</code></pre>



</details>

<a id="0x1_transaction_permissions_check"></a>

## Function `check`

The verdict of the first rule matching <code>sender</code> and <code>kind</code>, or <code>none</code>
when no rule matches.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="transaction_permissions.md#0x1_transaction_permissions_check">check</a>(sender: <b>address</b>, kind: u8): <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_Option">option::Option</a>&lt;bool&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="transaction_permissions.md#0x1_transaction_permissions_check">check</a>(sender: <b>address</b>, kind: u8): Option&lt;bool&gt; <b>acquires</b> <a href="transaction_permissions.md#0x1_transaction_permissions_TransactionPermissions">TransactionPermissions</a> {
    <b>assert</b>!(kind &lt;= <a href="transaction_permissions.md#0x1_transaction_permissions_KIND_OTHER">KIND_OTHER</a>, <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="transaction_permissions.md#0x1_transaction_permissions_EINVALID_TRANSACTION_KIND">EINVALID_TRANSACTION_KIND</a>));
    <b>if</b> (!<b>exists</b>&lt;<a href="transaction_permissions.md#0x1_transaction_permissions_TransactionPermissions">TransactionPermissions</a>&gt;(@aptos_framework)) {
        <b>return</b> <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_none">option::none</a>()
    };
    <b>let</b> rules = &<b>borrow_global</b>&lt;<a href="transaction_permissions.md#0x1_transaction_permissions_TransactionPermissions">TransactionPermissions</a>&gt;(@aptos_framework).rules;
    <b>let</b> i = 0;
    <b>let</b> n = <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_length">vector::length</a>(rules);
    <b>while</b> (i &lt; n) {
        <b>let</b> rule = <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_borrow">vector::borrow</a>(rules, i);
        <b>let</b> sender_matches =
            <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_is_none">option::is_none</a>(&rule.sender) || *<a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_borrow">option::borrow</a>(&rule.sender) == sender;
        <b>if</b> (sender_matches && rule.kind == kind) {
            <b>return</b> <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_some">option::some</a>(rule.allow)
        };
        i = i + 1;
    };
    <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_none">option::none</a>()
}
</code></pre>



</details>

<a id="0x1_transaction_permissions_is_allowed"></a>

## Function `is_allowed`

Whether a transaction from <code>sender</code> of <code>kind</code> is allowed: the first
matching rule's verdict, or true when no rule matches.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="transaction_permissions.md#0x1_transaction_permissions_is_allowed">is_allowed</a>(sender: <b>address</b>, kind: u8): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="transaction_permissions.md#0x1_transaction_permissions_is_allowed">is_allowed</a>(sender: <b>address</b>, kind: u8): bool <b>acquires</b> <a href="transaction_permissions.md#0x1_transaction_permissions_TransactionPermissions">TransactionPermissions</a> {
    <b>let</b> verdict = <a href="transaction_permissions.md#0x1_transaction_permissions_check">check</a>(sender, kind);
    <b>if</b> (<a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_is_some">option::is_some</a>(&verdict)) {
        *<a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_borrow">option::borrow</a>(&verdict)
    } <b>else</b> {
        <b>true</b>
    }
}
</code></pre>



</details>

<a id="0x1_transaction_permissions_kind_deploy"></a>

## Function `kind_deploy`



<pre><code><b>public</b> <b>fun</b> <a href="transaction_permissions.md#0x1_transaction_permissions_kind_deploy">kind_deploy</a>(): u8
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="transaction_permissions.md#0x1_transaction_permissions_kind_deploy">kind_deploy</a>(): u8 { <a href="transaction_permissions.md#0x1_transaction_permissions_KIND_DEPLOY">KIND_DEPLOY</a> }
</code></pre>



</details>

<a id="0x1_transaction_permissions_kind_upgrade"></a>

## Function `kind_upgrade`



<pre><code><b>public</b> <b>fun</b> <a href="transaction_permissions.md#0x1_transaction_permissions_kind_upgrade">kind_upgrade</a>(): u8
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="transaction_permissions.md#0x1_transaction_permissions_kind_upgrade">kind_upgrade</a>(): u8 { <a href="transaction_permissions.md#0x1_transaction_permissions_KIND_UPGRADE">KIND_UPGRADE</a> }
</code></pre>



</details>

<a id="0x1_transaction_permissions_kind_script"></a>

## Function `kind_script`



<pre><code><b>public</b> <b>fun</b> <a href="transaction_permissions.md#0x1_transaction_permissions_kind_script">kind_script</a>(): u8
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="transaction_permissions.md#0x1_transaction_permissions_kind_script">kind_script</a>(): u8 { <a href="transaction_permissions.md#0x1_transaction_permissions_KIND_SCRIPT">KIND_SCRIPT</a> }
</code></pre>



</details>

<a id="0x1_transaction_permissions_kind_other"></a>

## Function `kind_other`



<pre><code><b>public</b> <b>fun</b> <a href="transaction_permissions.md#0x1_transaction_permissions_kind_other">kind_other</a>(): u8
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="transaction_permissions.md#0x1_transaction_permissions_kind_other">kind_other</a>(): u8 { <a href="transaction_permissions.md#0x1_transaction_permissions_KIND_OTHER">KIND_OTHER</a> }
</code></pre>



</details>

<a id="0x1_transaction_permissions_max_rules"></a>

## Function `max_rules`



<pre><code><b>public</b> <b>fun</b> <a href="transaction_permissions.md#0x1_transaction_permissions_max_rules">max_rules</a>(): u64
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="transaction_permissions.md#0x1_transaction_permissions_max_rules">max_rules</a>(): u64 { <a href="transaction_permissions.md#0x1_transaction_permissions_MAX_RULES">MAX_RULES</a> }
</code></pre>



</details>

<a id="0x1_transaction_permissions_assert_initialized"></a>

## Function `assert_initialized`



<pre><code><b>fun</b> <a href="transaction_permissions.md#0x1_transaction_permissions_assert_initialized">assert_initialized</a>()
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="transaction_permissions.md#0x1_transaction_permissions_assert_initialized">assert_initialized</a>() {
    <b>assert</b>!(
        <b>exists</b>&lt;<a href="transaction_permissions.md#0x1_transaction_permissions_TransactionPermissions">TransactionPermissions</a>&gt;(@aptos_framework),
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_not_found">error::not_found</a>(<a href="transaction_permissions.md#0x1_transaction_permissions_ENOT_INITIALIZED">ENOT_INITIALIZED</a>),
    );
}
</code></pre>



</details>


[move-book]: https://aptos.dev/move/book/SUMMARY
