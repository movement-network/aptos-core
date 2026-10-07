
<a id="0x1_merkle_proof"></a>

# Module `0x1::merkle_proof`

OpenZeppelin-compatible Merkle membership verification.

Matches @openzeppelin/merkle-tree and OpenZeppelin's MerkleProof.sol exactly:
leaf  = keccak256(keccak256(preimage))     (standardLeafHash)
node  = keccak256(min(a,b) || max(a,b))    (standardNodeHash / commutativeKeccak256)

Sorted-pair hashing is what removes the leaf index from the API: the verifier never
needs to know whether a sibling is on the left or the right. The double-hashed leaf is
what replaces domain-separation prefixes; without it, the concatenation of a sorted pair
of internal nodes can be reinterpreted as a leaf. That is the 64-byte hazard
MerkleProof.sol warns about, and it is the whole reason the leaf is hashed twice.

Written for Move 2.1: no resource index syntax, explicit vector:: calls.


-  [Constants](#@Constants_0)
-  [Function `hash_pair`](#0x1_merkle_proof_hash_pair)
-  [Function `leaf_hash`](#0x1_merkle_proof_leaf_hash)
-  [Function `process_proof`](#0x1_merkle_proof_process_proof)
-  [Function `verify`](#0x1_merkle_proof_verify)
-  [Function `subject_leaf`](#0x1_merkle_proof_subject_leaf)
-  [Specification](#@Specification_1)
    -  [High-level Requirements](#high-level-req)
    -  [Module-level Specification](#module-level-spec)
    -  [Function `leaf_hash`](#@Specification_1_leaf_hash)
    -  [Function `process_proof`](#@Specification_1_process_proof)
    -  [Function `verify`](#@Specification_1_verify)
    -  [Function `subject_leaf`](#@Specification_1_subject_leaf)


<pre><code><b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/hash.md#0x1_aptos_hash">0x1::aptos_hash</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/bcs.md#0x1_bcs">0x1::bcs</a>;
<b>use</b> <a href="../../aptos-stdlib/doc/comparator.md#0x1_comparator">0x1::comparator</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error">0x1::error</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">0x1::vector</a>;
</code></pre>



<a id="@Constants_0"></a>

## Constants


<a id="0x1_merkle_proof_E_BAD_DIGEST_LEN"></a>

A leaf or sibling is not exactly 32 bytes.


<pre><code><b>const</b> <a href="merkle_proof.md#0x1_merkle_proof_E_BAD_DIGEST_LEN">E_BAD_DIGEST_LEN</a>: u64 = 2;
</code></pre>



<a id="0x1_merkle_proof_E_PROOF_TOO_LONG"></a>

The proof has more than MAX_PROOF_LEN siblings.


<pre><code><b>const</b> <a href="merkle_proof.md#0x1_merkle_proof_E_PROOF_TOO_LONG">E_PROOF_TOO_LONG</a>: u64 = 1;
</code></pre>



<a id="0x1_merkle_proof_MAX_PROOF_LEN"></a>

Proof length cap. OpenZeppelin trees are complete but not perfect, so leaves sit at
two different depths and proof length varies per leaf. Exact-depth checks are
therefore not available; cap instead. 32 covers 2^32 leaves.


<pre><code><b>const</b> <a href="merkle_proof.md#0x1_merkle_proof_MAX_PROOF_LEN">MAX_PROOF_LEN</a>: u64 = 32;
</code></pre>



<a id="0x1_merkle_proof_hash_pair"></a>

## Function `hash_pair`

commutativeKeccak256: sort the pair, concatenate, hash the 64 bytes.


<pre><code><b>fun</b> <a href="merkle_proof.md#0x1_merkle_proof_hash_pair">hash_pair</a>(a: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, b: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="merkle_proof.md#0x1_merkle_proof_hash_pair">hash_pair</a>(a: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, b: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt; {
    <b>let</b> <a href="../../aptos-stdlib/../move-stdlib/doc/cmp.md#0x1_cmp">cmp</a> = <a href="../../aptos-stdlib/doc/comparator.md#0x1_comparator_compare_u8_vector">comparator::compare_u8_vector</a>(<b>copy</b> a, <b>copy</b> b);
    <b>let</b> buf = <b>if</b> (<a href="../../aptos-stdlib/doc/comparator.md#0x1_comparator_is_smaller_than">comparator::is_smaller_than</a>(&<a href="../../aptos-stdlib/../move-stdlib/doc/cmp.md#0x1_cmp">cmp</a>)) {
        <b>let</b> t = a;
        <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_append">vector::append</a>(&<b>mut</b> t, b);
        t
    } <b>else</b> {
        <b>let</b> t = b;
        <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_append">vector::append</a>(&<b>mut</b> t, a);
        t
    };
    <a href="../../aptos-stdlib/../move-stdlib/doc/hash.md#0x1_aptos_hash_keccak256">aptos_hash::keccak256</a>(buf)
}
</code></pre>



</details>

<a id="0x1_merkle_proof_leaf_hash"></a>

## Function `leaf_hash`

standardLeafHash. <code>preimage</code> is the ABI encoding of the leaf tuple. Keep every field
a 32-byte value (bytes32 on the JavaScript side) so plain concatenation here matches
abi.encode there; see the note on encoding at the bottom of this file.


<pre><code><b>public</b> <b>fun</b> <a href="merkle_proof.md#0x1_merkle_proof_leaf_hash">leaf_hash</a>(preimage: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="merkle_proof.md#0x1_merkle_proof_leaf_hash">leaf_hash</a>(preimage: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt; {
    <a href="../../aptos-stdlib/../move-stdlib/doc/hash.md#0x1_aptos_hash_keccak256">aptos_hash::keccak256</a>(<a href="../../aptos-stdlib/../move-stdlib/doc/hash.md#0x1_aptos_hash_keccak256">aptos_hash::keccak256</a>(preimage))
}
</code></pre>



</details>

<a id="0x1_merkle_proof_process_proof"></a>

## Function `process_proof`

MerkleProof.processProof: fold the leaf upward through the sibling hashes.


<pre><code><b>public</b> <b>fun</b> <a href="merkle_proof.md#0x1_merkle_proof_process_proof">process_proof</a>(leaf: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, proof: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="merkle_proof.md#0x1_merkle_proof_process_proof">process_proof</a>(leaf: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, proof: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt; {
    <b>assert</b>!(
        <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_length">vector::length</a>(&proof) &lt;= <a href="merkle_proof.md#0x1_merkle_proof_MAX_PROOF_LEN">MAX_PROOF_LEN</a>,
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="merkle_proof.md#0x1_merkle_proof_E_PROOF_TOO_LONG">E_PROOF_TOO_LONG</a>)
    );
    <b>assert</b>!(<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_length">vector::length</a>(&leaf) == 32, <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="merkle_proof.md#0x1_merkle_proof_E_BAD_DIGEST_LEN">E_BAD_DIGEST_LEN</a>));
    <b>let</b> computed = leaf;
    <b>let</b> i = 0;
    <b>let</b> n = <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_length">vector::length</a>(&proof);
    <b>while</b> ({
        <b>spec</b> {
            <b>invariant</b> n == len(proof);
            <b>invariant</b> i &lt;= n;
            <b>invariant</b> i == 0 ==&gt; computed == leaf;
        };
        i &lt; n
    }) {
        <b>let</b> sibling = *<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_borrow">vector::borrow</a>(&proof, i);
        <b>assert</b>!(
            <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_length">vector::length</a>(&sibling) == 32,
            <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="merkle_proof.md#0x1_merkle_proof_E_BAD_DIGEST_LEN">E_BAD_DIGEST_LEN</a>)
        );
        computed = <a href="merkle_proof.md#0x1_merkle_proof_hash_pair">hash_pair</a>(computed, sibling);
        i = i + 1;
    };
    computed
}
</code></pre>



</details>

<a id="0x1_merkle_proof_verify"></a>

## Function `verify`

MerkleProof.verify.


<pre><code><b>public</b> <b>fun</b> <a href="merkle_proof.md#0x1_merkle_proof_verify">verify</a>(root: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, leaf: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, proof: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;&gt;): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="merkle_proof.md#0x1_merkle_proof_verify">verify</a>(root: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, leaf: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, proof: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;&gt;): bool {
    <a href="merkle_proof.md#0x1_merkle_proof_process_proof">process_proof</a>(leaf, proof) == root
}
</code></pre>



</details>

<a id="0x1_merkle_proof_subject_leaf"></a>

## Function `subject_leaf`

Bind the leaf to this registry so a proof issued for one registry cannot be replayed
against another that happens to adopt the same root. Both fields are 32 bytes, so the
preimage is bytes32 || bytes32 and the JS side is
StandardMerkleTree.of([[registry, subject]], ['bytes32','bytes32'])

Deliberately NOT included: the epoch. Leaving it out lets the registry accept the
previous root during a rotation grace window without recomputing the leaf.


<pre><code><b>public</b> <b>fun</b> <a href="merkle_proof.md#0x1_merkle_proof_subject_leaf">subject_leaf</a>(registry: <b>address</b>, subject: <b>address</b>): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="merkle_proof.md#0x1_merkle_proof_subject_leaf">subject_leaf</a>(registry: <b>address</b>, subject: <b>address</b>): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt; {
    <b>let</b> buf = std::bcs::to_bytes(&registry);
    <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_append">vector::append</a>(&<b>mut</b> buf, std::bcs::to_bytes(&subject));
    <a href="merkle_proof.md#0x1_merkle_proof_leaf_hash">leaf_hash</a>(buf)
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
<td>Leaves are double hashed, as in OpenZeppelin's standardLeafHash, so no 64-byte leaf preimage can be confused with an internal node.</td>
<td>Critical</td>
<td>leaf_hash applies keccak256 twice; subject_leaf builds the preimage as bcs(registry) || bcs(subject), both 32 bytes, and hashes it with leaf_hash.</td>
<td>Formally verified that <a href="#high-level-req-1.1">leaf_hash</a> and <a href="#high-level-req-1.2">subject_leaf</a> never abort. The hash values themselves are pinned against @openzeppelin/merkle-tree vectors in unit tests: the keccak256 native's abstract spec does not propagate through these call sites, so an ensures over spec_keccak256 cannot be proven here.</td>
</tr>

<tr>
<td>2</td>
<td>Internal nodes hash the sorted pair, as in OpenZeppelin's commutativeKeccak256, so the verifier needs no leaf index.</td>
<td>High</td>
<td>hash_pair concatenates the smaller operand first and hashes the 64 bytes.</td>
<td>Audited in unit tests (test_two_leaf_tree checks commutativity, test_leaf_is_not_an_internal_node checks a node against OpenZeppelin). Not formally specified, for the same keccak256 reason as requirement 1.</td>
</tr>

<tr>
<td>3</td>
<td>Proofs are bounded, and every leaf and sibling is a 32-byte digest.</td>
<td>Medium</td>
<td>process_proof asserts len(proof) <= MAX_PROOF_LEN and a 32-byte leaf before folding, and a 32-byte sibling at each step.</td>
<td>Formally verified via <a href="#high-level-req-3">process_proof</a> for the proof length and leaf length. The per-sibling check sits inside the fold loop, which the prover havocs, and is covered by unit tests.</td>
</tr>

<tr>
<td>4</td>
<td>An empty proof verifies exactly when the leaf is the root, which is the one-leaf tree.</td>
<td>Medium</td>
<td>process_proof returns the leaf unchanged when the proof is empty.</td>
<td>Formally verified via <a href="#high-level-req-4">verify</a>.</td>
</tr>

</table>



<a id="module-level-spec"></a>

### Module-level Specification


<pre><code><b>pragma</b> verify = <b>true</b>;
<b>pragma</b> aborts_if_is_strict = <b>false</b>;
</code></pre>



<a id="@Specification_1_leaf_hash"></a>

### Function `leaf_hash`


<pre><code><b>public</b> <b>fun</b> <a href="merkle_proof.md#0x1_merkle_proof_leaf_hash">leaf_hash</a>(preimage: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
</code></pre>




<pre><code>// This enforces <a id="high-level-req-1.1" href="#high-level-req">high-level requirement 1</a>:
<b>aborts_if</b> <b>false</b>;
</code></pre>



<a id="@Specification_1_process_proof"></a>

### Function `process_proof`


<pre><code><b>public</b> <b>fun</b> <a href="merkle_proof.md#0x1_merkle_proof_process_proof">process_proof</a>(leaf: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, proof: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
</code></pre>




<pre><code><b>pragma</b> aborts_if_is_partial;
// This enforces <a id="high-level-req-3" href="#high-level-req">high-level requirement 3</a>:
<b>aborts_if</b> len(proof) &gt; <a href="merkle_proof.md#0x1_merkle_proof_MAX_PROOF_LEN">MAX_PROOF_LEN</a>;
<b>aborts_if</b> len(leaf) != 32;
<b>ensures</b> len(proof) == 0 ==&gt; result == leaf;
</code></pre>



<a id="@Specification_1_verify"></a>

### Function `verify`


<pre><code><b>public</b> <b>fun</b> <a href="merkle_proof.md#0x1_merkle_proof_verify">verify</a>(root: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, leaf: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, proof: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;&gt;): bool
</code></pre>




<pre><code><b>pragma</b> aborts_if_is_partial;
<b>aborts_if</b> len(proof) &gt; <a href="merkle_proof.md#0x1_merkle_proof_MAX_PROOF_LEN">MAX_PROOF_LEN</a>;
<b>aborts_if</b> len(leaf) != 32;
// This enforces <a id="high-level-req-4" href="#high-level-req">high-level requirement 4</a>:
<b>ensures</b> len(proof) == 0 ==&gt; result == (leaf == root);
</code></pre>



<a id="@Specification_1_subject_leaf"></a>

### Function `subject_leaf`


<pre><code><b>public</b> <b>fun</b> <a href="merkle_proof.md#0x1_merkle_proof_subject_leaf">subject_leaf</a>(registry: <b>address</b>, subject: <b>address</b>): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
</code></pre>




<pre><code>// This enforces <a id="high-level-req-1.2" href="#high-level-req">high-level requirement 1</a>:
<b>aborts_if</b> <b>false</b>;
</code></pre>


[move-book]: https://aptos.dev/move/book/SUMMARY
