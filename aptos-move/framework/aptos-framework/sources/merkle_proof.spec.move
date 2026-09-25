spec aptos_framework::merkle_proof {
    /// <high-level-req>
    /// No.: 1
    /// Requirement: Leaves are double hashed, as in OpenZeppelin's standardLeafHash, so no 64-byte leaf preimage can be
    /// confused with an internal node.
    /// Criticality: Critical
    /// Implementation: leaf_hash applies keccak256 twice; subject_leaf builds the preimage as bcs(registry) ||
    /// bcs(subject), both 32 bytes, and hashes it with leaf_hash.
    /// Enforcement: Formally verified that [high-level-req-1.1](leaf_hash) and [high-level-req-1.2](subject_leaf)
    /// never abort. The hash values themselves are pinned against @openzeppelin/merkle-tree vectors in unit tests:
    /// the keccak256 native's abstract spec does not propagate through these call sites, so an ensures over
    /// spec_keccak256 cannot be proven here.
    ///
    /// No.: 2
    /// Requirement: Internal nodes hash the sorted pair, as in OpenZeppelin's commutativeKeccak256, so the verifier
    /// needs no leaf index.
    /// Criticality: High
    /// Implementation: hash_pair concatenates the smaller operand first and hashes the 64 bytes.
    /// Enforcement: Audited in unit tests (test_two_leaf_tree checks commutativity, test_leaf_is_not_an_internal_node
    /// checks a node against OpenZeppelin). Not formally specified, for the same keccak256 reason as requirement 1.
    ///
    /// No.: 3
    /// Requirement: Proofs are bounded, and every leaf and sibling is a 32-byte digest.
    /// Criticality: Medium
    /// Implementation: process_proof asserts len(proof) <= MAX_PROOF_LEN and a 32-byte leaf before folding, and a
    /// 32-byte sibling at each step.
    /// Enforcement: Formally verified via [high-level-req-3](process_proof) for the proof length and leaf length. The
    /// per-sibling check sits inside the fold loop, which the prover havocs, and is covered by unit tests.
    ///
    /// No.: 4
    /// Requirement: An empty proof verifies exactly when the leaf is the root, which is the one-leaf tree.
    /// Criticality: Medium
    /// Implementation: process_proof returns the leaf unchanged when the proof is empty.
    /// Enforcement: Formally verified via [high-level-req-4](verify).
    /// </high-level-req>
    spec module {
        pragma verify = true;
        pragma aborts_if_is_strict = false;
    }

    spec leaf_hash(preimage: vector<u8>): vector<u8> {
        /// [high-level-req-1.1]
        aborts_if false;
    }

    spec subject_leaf(registry: address, subject: address): vector<u8> {
        /// [high-level-req-1.2]
        aborts_if false;
    }

    spec process_proof(leaf: vector<u8>, proof: vector<vector<u8>>): vector<u8> {
        pragma aborts_if_is_partial;
        /// [high-level-req-3]
        aborts_if len(proof) > MAX_PROOF_LEN;
        aborts_if len(leaf) != 32;
        ensures len(proof) == 0 ==> result == leaf;
    }

    spec verify(root: vector<u8>, leaf: vector<u8>, proof: vector<vector<u8>>): bool {
        pragma aborts_if_is_partial;
        aborts_if len(proof) > MAX_PROOF_LEN;
        aborts_if len(leaf) != 32;
        /// [high-level-req-4]
        ensures len(proof) == 0 ==> result == (leaf == root);
    }
}
