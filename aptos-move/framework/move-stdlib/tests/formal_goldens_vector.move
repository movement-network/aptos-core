#[test_only]
/// Deterministic `std::vector` scenarios for Lean list/sequence models (length + element checks).
module std::formal_goldens_vector {
    use std::vector as V;

    #[test]
    fun golden_trim_and_append_chain() {
        let v = V::empty<u64>();
        v.push_back(10);
        v.push_back(20);
        v.push_back(30);
        let tail = v.trim(1);
        assert!(v == vector[10], 0);
        assert!(tail == vector[20, 30], 1);
        let w = V::empty<u64>();
        w.push_back(1);
        w.append(tail);
        assert!(w.length() == 3, 2);
        assert!(w[0] == 1, 3);
        assert!(w[1] == 20, 4);
        assert!(w[2] == 30, 5);
    }

    #[test]
    fun golden_reverse_slice() {
        let v = vector[1u8, 2, 3, 4, 5];
        v.reverse_slice(1, 4);
        assert!(v == vector[1u8, 4, 3, 2, 5], 0);
    }
}
