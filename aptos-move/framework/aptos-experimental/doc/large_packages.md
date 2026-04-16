
<a id="0x7_large_packages"></a>

# Module `0x7::large_packages`


<a id="@Aptos_Large_Packages_Framework_0"></a>

## Aptos Large Packages Framework


This module provides a framework for uploading large packages to the Aptos network, under standard
accounts or objects.
To publish using this API, you must divide your metadata and modules across multiple calls
into <code><a href="large_packages.md#0x7_large_packages_stage_code_chunk">large_packages::stage_code_chunk</a></code>.
In each pass, the caller pushes more code by calling <code>stage_code_chunk</code>.
In the final call, the caller can use <code>stage_code_chunk_and_publish_to_account</code>, <code>stage_code_chunk_and_publish_to_object</code>, or
<code>stage_code_chunk_and_upgrade_object_code</code> to upload the final data chunk and publish or upgrade the package on-chain.

The above logic is currently implemented in the Python
SDK: [<code>aptos-python-sdk</code>](https://github.com/aptos-labs/aptos-python-sdk/blob/main/aptos_sdk/package_publisher.py).

Aptos CLI supports this as well with <code>--chunked-publish</code> flag:
- <code>aptos <b>move</b> publish [OPTIONS] --chunked-publish</code>
- <code>aptos <b>move</b> create-<a href="../../aptos-framework/doc/object.md#0x1_object">object</a>-and-publish-<b>package</b> [OPTIONS] --<b>address</b>-name &lt;ADDRESS_NAME&gt; --chunked-publish</code>
- <code>aptos <b>move</b> upgrade-<a href="../../aptos-framework/doc/object.md#0x1_object">object</a>-<b>package</b> [OPTIONS] --<b>address</b>-name &lt;ADDRESS_NAME&gt; --chunked-publish</code>


<a id="@Usage_1"></a>

## Usage


1. **Stage Code Chunks**:
- Call <code>stage_code_chunk</code> with the appropriate metadata and code chunks.
- Ensure that <code>code_indices</code> are provided from <code>0</code> to <code>last_module_idx</code>, without any
gaps.


2. **Publish or Upgrade**:
- In order to upload the last data chunk and publish the package, call <code>stage_code_chunk_and_publish_to_account</code> or <code>stage_code_chunk_and_publish_to_object</code>.

- For object code upgrades, call <code>stage_code_chunk_and_upgrade_object_code</code> with the argument <code>code_object</code> provided.

3. **Cleanup**:
- In order to remove <code><a href="large_packages.md#0x7_large_packages_StagingArea">StagingArea</a></code> resource from an account, call <code>cleanup_staging_area</code>.


<a id="@Notes_2"></a>

## Notes


* Make sure LargePackages is deployed to your network of choice, you can currently find it both on
mainnet and testnet at <code>0xa29df848eebfe5d981f708c2a5b06d31af2be53bbd8ddc94c8523f4b903f7adb</code>, and
in 0x7 (aptos-experimental) on devnet/localnet.
* Ensure that <code>code_indices</code> have no gaps. For example, if code_indices are
provided as [0, 1, 3] (skipping index 2), the inline function <code>assemble_module_code</code> will abort
since <code><a href="large_packages.md#0x7_large_packages_StagingArea">StagingArea</a>.last_module_idx</code> is set as the max value of the provided index
from <code>code_indices</code>, and <code>assemble_module_code</code> will lookup the <code><a href="large_packages.md#0x7_large_packages_StagingArea">StagingArea</a>.<a href="../../aptos-framework/doc/code.md#0x1_code">code</a></code> SmartTable from
0 to <code><a href="large_packages.md#0x7_large_packages_StagingArea">StagingArea</a>.last_module_idx</code> in turn.


-  [Aptos Large Packages Framework](#@Aptos_Large_Packages_Framework_0)
-  [Usage](#@Usage_1)
-  [Notes](#@Notes_2)
-  [Resource `StagingArea`](#0x7_large_packages_StagingArea)
-  [Constants](#@Constants_3)
-  [Function `stage_code_chunk`](#0x7_large_packages_stage_code_chunk)
-  [Function `stage_code_chunk_and_publish_to_account`](#0x7_large_packages_stage_code_chunk_and_publish_to_account)
-  [Function `stage_code_chunk_and_publish_to_object`](#0x7_large_packages_stage_code_chunk_and_publish_to_object)
-  [Function `stage_code_chunk_and_upgrade_object_code`](#0x7_large_packages_stage_code_chunk_and_upgrade_object_code)
-  [Function `cleanup_staging_area`](#0x7_large_packages_cleanup_staging_area)


<pre><code><b>use</b> <a href="../../aptos-framework/doc/code.md#0x1_code">0x1::code</a>;
<b>use</b> <a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error">0x1::error</a>;
<b>use</b> <a href="../../aptos-framework/doc/object.md#0x1_object">0x1::object</a>;
<b>use</b> <a href="../../aptos-framework/doc/object_code_deployment.md#0x1_object_code_deployment">0x1::object_code_deployment</a>;
<b>use</b> <a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">0x1::signer</a>;
<b>use</b> <a href="../../aptos-framework/../aptos-stdlib/doc/smart_table.md#0x1_smart_table">0x1::smart_table</a>;
<b>use</b> <a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">0x1::vector</a>;
</code></pre>



<a id="0x7_large_packages_StagingArea"></a>

## Resource `StagingArea`



<pre><code><b>struct</b> <a href="large_packages.md#0x7_large_packages_StagingArea">StagingArea</a> <b>has</b> key
</code></pre>



<a id="@Constants_3"></a>

## Constants


<a id="0x7_large_packages_ECODE_MISMATCH"></a>

code_indices and code_chunks should be the same length.


<pre><code><b>const</b> <a href="large_packages.md#0x7_large_packages_ECODE_MISMATCH">ECODE_MISMATCH</a>: u64 = 1;
</code></pre>



<a id="0x7_large_packages_EMISSING_OBJECT_REFERENCE"></a>

Object reference should be provided when upgrading object code.


<pre><code><b>const</b> <a href="large_packages.md#0x7_large_packages_EMISSING_OBJECT_REFERENCE">EMISSING_OBJECT_REFERENCE</a>: u64 = 2;
</code></pre>



<a id="0x7_large_packages_stage_code_chunk"></a>

## Function `stage_code_chunk`



<pre><code><b>public</b> entry <b>fun</b> <a href="large_packages.md#0x7_large_packages_stage_code_chunk">stage_code_chunk</a>(owner: &<a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, metadata_chunk: <a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, code_indices: <a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u16&gt;, code_chunks: <a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;&gt;)
</code></pre>



<a id="0x7_large_packages_stage_code_chunk_and_publish_to_account"></a>

## Function `stage_code_chunk_and_publish_to_account`



<pre><code><b>public</b> entry <b>fun</b> <a href="large_packages.md#0x7_large_packages_stage_code_chunk_and_publish_to_account">stage_code_chunk_and_publish_to_account</a>(owner: &<a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, metadata_chunk: <a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, code_indices: <a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u16&gt;, code_chunks: <a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;&gt;)
</code></pre>



<a id="0x7_large_packages_stage_code_chunk_and_publish_to_object"></a>

## Function `stage_code_chunk_and_publish_to_object`



<pre><code><b>public</b> entry <b>fun</b> <a href="large_packages.md#0x7_large_packages_stage_code_chunk_and_publish_to_object">stage_code_chunk_and_publish_to_object</a>(owner: &<a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, metadata_chunk: <a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, code_indices: <a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u16&gt;, code_chunks: <a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;&gt;)
</code></pre>



<a id="0x7_large_packages_stage_code_chunk_and_upgrade_object_code"></a>

## Function `stage_code_chunk_and_upgrade_object_code`



<pre><code><b>public</b> entry <b>fun</b> <a href="large_packages.md#0x7_large_packages_stage_code_chunk_and_upgrade_object_code">stage_code_chunk_and_upgrade_object_code</a>(owner: &<a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, metadata_chunk: <a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, code_indices: <a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u16&gt;, code_chunks: <a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;&gt;, code_object: <a href="../../aptos-framework/doc/object.md#0x1_object_Object">object::Object</a>&lt;<a href="../../aptos-framework/doc/code.md#0x1_code_PackageRegistry">code::PackageRegistry</a>&gt;)
</code></pre>



<a id="0x7_large_packages_cleanup_staging_area"></a>

## Function `cleanup_staging_area`



<pre><code><b>public</b> entry <b>fun</b> <a href="large_packages.md#0x7_large_packages_cleanup_staging_area">cleanup_staging_area</a>(owner: &<a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>)
</code></pre>
