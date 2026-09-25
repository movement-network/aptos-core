/// OpenZeppelin-compatible Merkle membership verification.
///
/// Matches @openzeppelin/merkle-tree and OpenZeppelin's MerkleProof.sol exactly:
///   leaf  = keccak256(keccak256(preimage))     (standardLeafHash)
///   node  = keccak256(min(a,b) || max(a,b))    (standardNodeHash / commutativeKeccak256)
///
/// Sorted-pair hashing is what removes the leaf index from the API: the verifier never
/// needs to know whether a sibling is on the left or the right. The double-hashed leaf is
/// what replaces domain-separation prefixes; without it, the concatenation of a sorted pair
/// of internal nodes can be reinterpreted as a leaf. That is the 64-byte hazard
/// MerkleProof.sol warns about, and it is the whole reason the leaf is hashed twice.
///
/// Written for Move 2.1: no resource index syntax, explicit vector:: calls.
module aptos_framework::merkle_proof {
    use std::error;
    use std::vector;
    use aptos_framework::aptos_hash;
    use aptos_framework::comparator;

    /// Proof length cap. OpenZeppelin trees are complete but not perfect, so leaves sit at
    /// two different depths and proof length varies per leaf. Exact-depth checks are
    /// therefore not available; cap instead. 32 covers 2^32 leaves.
    const MAX_PROOF_LEN: u64 = 32;

    /// The proof has more than MAX_PROOF_LEN siblings.
    const E_PROOF_TOO_LONG: u64 = 1;
    /// A leaf or sibling is not exactly 32 bytes.
    const E_BAD_DIGEST_LEN: u64 = 2;

    /// commutativeKeccak256: sort the pair, concatenate, hash the 64 bytes.
    fun hash_pair(a: vector<u8>, b: vector<u8>): vector<u8> {
        let cmp = comparator::compare_u8_vector(copy a, copy b);
        let buf = if (comparator::is_smaller_than(&cmp)) {
            let t = a;
            vector::append(&mut t, b);
            t
        } else {
            let t = b;
            vector::append(&mut t, a);
            t
        };
        aptos_hash::keccak256(buf)
    }

    /// standardLeafHash. `preimage` is the ABI encoding of the leaf tuple. Keep every field
    /// a 32-byte value (bytes32 on the JavaScript side) so plain concatenation here matches
    /// abi.encode there; see the note on encoding at the bottom of this file.
    public fun leaf_hash(preimage: vector<u8>): vector<u8> {
        aptos_hash::keccak256(aptos_hash::keccak256(preimage))
    }

    /// MerkleProof.processProof: fold the leaf upward through the sibling hashes.
    public fun process_proof(leaf: vector<u8>, proof: vector<vector<u8>>): vector<u8> {
        assert!(
            vector::length(&proof) <= MAX_PROOF_LEN,
            error::invalid_argument(E_PROOF_TOO_LONG)
        );
        assert!(vector::length(&leaf) == 32, error::invalid_argument(E_BAD_DIGEST_LEN));
        let computed = leaf;
        let i = 0;
        let n = vector::length(&proof);
        while ({
            spec {
                invariant n == len(proof);
                invariant i <= n;
                invariant i == 0 ==> computed == leaf;
            };
            i < n
        }) {
            let sibling = *vector::borrow(&proof, i);
            assert!(
                vector::length(&sibling) == 32,
                error::invalid_argument(E_BAD_DIGEST_LEN)
            );
            computed = hash_pair(computed, sibling);
            i = i + 1;
        };
        computed
    }

    /// MerkleProof.verify.
    public fun verify(root: vector<u8>, leaf: vector<u8>, proof: vector<vector<u8>>): bool {
        process_proof(leaf, proof) == root
    }

    // ------------------------------------------------------------------
    // Registry-facing shape: address in, proof in, bool out.
    // ------------------------------------------------------------------

    /// Bind the leaf to this registry so a proof issued for one registry cannot be replayed
    /// against another that happens to adopt the same root. Both fields are 32 bytes, so the
    /// preimage is bytes32 || bytes32 and the JS side is
    ///   StandardMerkleTree.of([[registry, subject]], ['bytes32','bytes32'])
    ///
    /// Deliberately NOT included: the epoch. Leaving it out lets the registry accept the
    /// previous root during a rotation grace window without recomputing the leaf.
    public fun subject_leaf(registry: address, subject: address): vector<u8> {
        let buf = std::bcs::to_bytes(&registry);
        vector::append(&mut buf, std::bcs::to_bytes(&subject));
        leaf_hash(buf)
    }

    #[test]
    fun oz_vectors() {
        // Tree over five 32-byte addresses, built with OpenZeppelin's algorithm:
        // double-hashed leaves, leaves sorted by hash (sortLeaves defaults to true),
        // placed in reverse at the tail of a 2n-1 heap, commutative node hashing.
        let root = x"0573ec1d2c71abd9d936aca283796fc8a9fbaddc3266ecd0c390aa1106c3df3f";

        // 0x...0c33, proof depth 3
        let leaf_c33 = leaf_hash(x"0000000000000000000000000000000000000000000000000000000000000c33");
        let proof_c33 = vector[
            x"737a3a3bcf517b50aafa2edc80a736cb71072a5454183b97ae01b5c1dd816a4f",
            x"dd4f35afdc3e50ee9d2d45a15591c2f44e4b230aa130b9e4d75421bf464f560d",
            x"9e9c8062173feba09de411bec52f93f262827a7e380c4bcbcc04f89e17fb02f4",
        ];
        assert!(verify(root, leaf_c33, proof_c33), 100);

        // 0x...0a11, proof depth 2. Different depth, same root: this is why the verifier
        // must cap proof length rather than require an exact depth.
        let leaf_a11 = leaf_hash(x"0000000000000000000000000000000000000000000000000000000000000a11");
        let proof_a11 = vector[
            x"9fa3dd464039702e6b38c256d95997bfc82b1b2914d5f1fb32e548aba08baf98",
            x"025436324c781fd4a75116beb4c2646dea6a532d08fae4c227a4593e0baf2dcf",
        ];
        assert!(verify(root, leaf_a11, proof_a11), 101);

        // An address outside the set does not verify with a well-formed proof.
        let leaf_out = leaf_hash(x"000000000000000000000000000000000000000000000000000000000000ffff");
        let proof_out = vector[
            x"9fa3dd464039702e6b38c256d95997bfc82b1b2914d5f1fb32e548aba08baf98",
            x"025436324c781fd4a75116beb4c2646dea6a532d08fae4c227a4593e0baf2dcf",
        ];
        assert!(!verify(root, leaf_out, proof_out), 102);
    }

    // The vectors below come from @openzeppelin/merkle-tree 1.x itself (StandardMerkleTree.of),
    // not from a reimplementation.

    #[test_only]
    const REGISTRY: address = @0x94d1a87048840daa2ccb24dd50b1176d808ab8dc170a2492845f416a7c5801b1;
    #[test_only]
    /// StandardMerkleTree.of([[REGISTRY, s] for s in a11, b22, c33, d44, e55, f66, 777],
    /// ['bytes32', 'bytes32']). Seven leaves, so proofs have depth 2 or 3.
    const BOUND_ROOT: vector<u8> = x"6b0f31d23e28de5e4a07f4ff973ece0ecd3f044616eae7984a664250a2abdc19";

    #[test_only]
    fun bound_proof(subject: address): vector<vector<u8>> {
        if (subject == @0xa11) {
            vector[
                x"c186e553e4a1243744c5c6ebfb79c16707bd5d312b56362f596dde270a133bff",
                x"acf871e7d55582aae9aae3304b30209eae259960aa7fca4428019394da24a1b9",
                x"4faffc94448d88f74e4a8258458427d33bbdef40c08f92a3f6781d5287547d53"
            ]
        } else if (subject == @0xb22) {
            vector[
                x"7f552b6a6c67b4fa5456123d410524b1d0e93aa4443cd94a3686911d24e7b8f7",
                x"8960379e26e7324933e7b910cd20aefbef17a7dbb57d15e3fb033882ce137759",
                x"4faffc94448d88f74e4a8258458427d33bbdef40c08f92a3f6781d5287547d53"
            ]
        } else if (subject == @0xc33) {
            vector[
                x"1a55aebaecf159477c6111b27420d3a25e96c06ccac0aa6fdc9caf5402991fe7",
                x"da5a4dc375046c385afcbff227285ec0cd4f104456828bbc879d71e377e4961c",
                x"8ab165d1df144e47424dd904f7e966a1a8660127031778fec0aac99dcc44654e"
            ]
        } else if (subject == @0xd44) {
            vector[
                x"504df07c38bf9e166ca2057f30207779393e774f5f36bd8065ac3adc2d06272c",
                x"8960379e26e7324933e7b910cd20aefbef17a7dbb57d15e3fb033882ce137759",
                x"4faffc94448d88f74e4a8258458427d33bbdef40c08f92a3f6781d5287547d53"
            ]
        } else if (subject == @0xe55) {
            vector[
                x"fed2a70bf6fea6bec11a2ce4b69faed68e9f62624bcd16133b1e43eedaa311e5",
                x"8ab165d1df144e47424dd904f7e966a1a8660127031778fec0aac99dcc44654e"
            ]
        } else if (subject == @0xf66) {
            vector[
                x"a160143187a54d94b179c47b4d9dfe9a740228cb6e8b7a65211e4c76314e5eb8",
                x"acf871e7d55582aae9aae3304b30209eae259960aa7fca4428019394da24a1b9",
                x"4faffc94448d88f74e4a8258458427d33bbdef40c08f92a3f6781d5287547d53"
            ]
        } else {
            vector[
                x"48c93a8b18ca17b82e23632554e361469c5cf1cb4bbf55de32b860c12bbd5903",
                x"da5a4dc375046c385afcbff227285ec0cd4f104456828bbc879d71e377e4961c",
                x"8ab165d1df144e47424dd904f7e966a1a8660127031778fec0aac99dcc44654e"
            ]
        }
    }

    #[test]
    fun test_single_leaf_tree() {
        // A one-leaf tree's root is the leaf hash itself, and its proof is empty.
        let leaf = leaf_hash(x"0000000000000000000000000000000000000000000000000000000000000a11");
        let root = x"b7fae45f0386c0f429982dcbe7dd1089a33e9ba104301d2b501d62670840f5e3";
        assert!(leaf == root, 0);
        assert!(process_proof(leaf, vector[]) == leaf, 1);
        assert!(verify(root, leaf, vector[]), 2);
    }

    #[test]
    fun test_two_leaf_tree() {
        let root = x"ade7a8f2ed6d8922b6894eba53abe730c932f16721933db2505456ac63950feb";
        let leaf_a = leaf_hash(x"0000000000000000000000000000000000000000000000000000000000000a11");
        let leaf_b = leaf_hash(x"0000000000000000000000000000000000000000000000000000000000000b22");
        assert!(verify(root, leaf_a, vector[leaf_b]), 0);
        assert!(verify(root, leaf_b, vector[leaf_a]), 1);
        // Commutative: the order of the pair does not matter.
        assert!(hash_pair(leaf_a, leaf_b) == hash_pair(leaf_b, leaf_a), 2);
        // Without its sibling a leaf is not the root.
        assert!(!verify(root, leaf_a, vector[]), 3);
    }

    #[test]
    fun test_subject_leaf_matches_oz() {
        assert!(
            subject_leaf(REGISTRY, @0xa11)
                == x"a160143187a54d94b179c47b4d9dfe9a740228cb6e8b7a65211e4c76314e5eb8",
            0
        );
        let subjects = vector[@0xa11, @0xb22, @0xc33, @0xd44, @0xe55, @0xf66, @0x777];
        subjects.for_each(|subject| {
            assert!(verify(BOUND_ROOT, subject_leaf(REGISTRY, subject), bound_proof(subject)), 1);
        });
    }

    #[test]
    fun test_wrong_proofs_fail() {
        let leaf = subject_leaf(REGISTRY, @0xa11);
        // Another leaf's proof.
        assert!(!verify(BOUND_ROOT, leaf, bound_proof(@0xb22)), 0);
        // A tampered sibling.
        let proof = bound_proof(@0xa11);
        let sibling = &mut proof[0];
        sibling[31] ^= 1;
        assert!(!verify(BOUND_ROOT, leaf, proof), 1);
        // Levels out of order.
        let proof = bound_proof(@0xa11);
        proof.swap(0, 1);
        assert!(!verify(BOUND_ROOT, leaf, proof), 2);
        // A truncated proof.
        let proof = bound_proof(@0xa11);
        proof.pop_back();
        assert!(!verify(BOUND_ROOT, leaf, proof), 3);
        // A subject outside the set, with a member's proof.
        assert!(!verify(BOUND_ROOT, subject_leaf(REGISTRY, @0x888), bound_proof(@0xa11)), 4);
        // The same subject under another registry: the leaf binds the registry, so a proof cannot
        // be replayed against a different source that adopted the same root.
        assert!(!verify(BOUND_ROOT, subject_leaf(@0x1, @0xa11), bound_proof(@0xa11)), 5);
    }

    #[test]
    fun test_leaf_is_not_an_internal_node() {
        // The 64-byte hazard. Node 0x8960... is the parent of the a11 and f66 leaves. Presenting the
        // concatenation of its children as a leaf preimage must not reproduce it, which is what
        // the double hash guarantees.
        let a11 = x"a160143187a54d94b179c47b4d9dfe9a740228cb6e8b7a65211e4c76314e5eb8";
        let f66 = x"c186e553e4a1243744c5c6ebfb79c16707bd5d312b56362f596dde270a133bff";
        let parent = x"8960379e26e7324933e7b910cd20aefbef17a7dbb57d15e3fb033882ce137759";
        assert!(hash_pair(a11, f66) == parent, 0);
        let preimage = a11;
        vector::append(&mut preimage, f66);
        assert!(leaf_hash(preimage) != parent, 1);
    }

    #[test]
    fun test_proof_at_the_length_cap_is_accepted() {
        let proof = vector[];
        let i = 0;
        while (i < MAX_PROOF_LEN) {
            proof.push_back(x"0000000000000000000000000000000000000000000000000000000000000001");
            i += 1;
        };
        assert!(!verify(BOUND_ROOT, subject_leaf(REGISTRY, @0xa11), proof), 0);
    }

    #[test]
    #[expected_failure(abort_code = 0x10001, location = Self)]
    fun test_proof_over_the_length_cap_fails() {
        let proof = vector[];
        let i = 0;
        while (i <= MAX_PROOF_LEN) {
            proof.push_back(x"0000000000000000000000000000000000000000000000000000000000000001");
            i += 1;
        };
        process_proof(subject_leaf(REGISTRY, @0xa11), proof);
    }

    #[test]
    #[expected_failure(abort_code = 0x10002, location = Self)]
    fun test_short_leaf_fails() {
        process_proof(x"01", vector[]);
    }

    #[test]
    #[expected_failure(abort_code = 0x10002, location = Self)]
    fun test_short_sibling_fails() {
        process_proof(subject_leaf(REGISTRY, @0xa11), vector[x"01"]);
    }
}

// Encoding note, and the reason this interoperates at all.
//
// ABI encoding is not BCS. abi.encode pads every value to a 32-byte word, so a JS leaf of
// ['address','uint8','address'] is 96 bytes while the BCS equivalent in Move is 65. Roots
// built by the two toolchains would not match.
//
// The fix is to make every leaf field a 32-byte value and declare it as bytes32 in the
// JavaScript types array. abi.encode of bytes32 is the 32 raw bytes, and bcs::to_bytes of a
// Move address is also the 32 raw bytes with no length prefix, so plain concatenation on
// this side reproduces abi.encode on that side byte for byte. Anything narrower than 32
// bytes (a u8 status, a u64 expiry) must be left-padded to a full word in Move before it is
// appended, or declared as bytes32 and padded on the JS side. Do not mix in BCS integers.
//
// Two consequences worth writing into the spec:
//
// 1. Commutative hashing commits to a SET, not a sequence. There is no position, so a proof
//    cannot establish "this subject is at index i". Never derive a nullifier, a dedup key or
//    a replay identifier from proof bytes: the sibling multiset determines the outcome, so a
//    proof is not a canonical encoding. Hash the leaf for that, never the proof.
//
// 2. Every root in the tests above has been checked against @openzeppelin/merkle-tree 1.x:
//    the `oz_vectors` root is StandardMerkleTree.of over the bytes32 values 0x...0a11,
//    0x...0b22, 0x...0c33, 0x...0d44 and 0x...0e55 with type ['bytes32'].
