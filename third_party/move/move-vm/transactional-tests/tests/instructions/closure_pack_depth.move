//# publish
module 0x99::closure_pack_depth {

    fun apply(f: |u64|u64 has copy + drop, x: u64): u64 {
        f(x)
    }

    // Builds a chain of `n` closures, each capturing the previous one, so the value
    // depth of the result grows with `n` while its type stays flat.
    fun chain(n: u64): |u64|u64 has copy + drop {
        let f: |u64|u64 has copy + drop = |x| x + 1;
        let i = 0;
        while (i < n) {
            let g = f;
            f = |x| apply(g, x);
            i = i + 1;
        };
        f
    }

    // The deepest value captured by `chain(n)` is the chain of `n` closures, so 128
    // is the largest chain the maximum value depth (128) allows to pack.
    public fun pack_within_limit() {
        let f = chain(128);
        assert!(f(0) == 1, 0);
    }

    public fun pack_too_deep() {
        chain(129);
    }

    // A closure packed at the limit is one level deeper than the maximum when counted
    // from its own root (the captured chain plus the closure wrapper), so copying it
    // fails even though packing it succeeded.
    public fun pack_at_limit_then_copy() {
        let f = chain(128);
        let g = copy f;
        assert!(g(0) == f(0), 0);
    }
}

//# run 0x99::closure_pack_depth::pack_within_limit

//# run 0x99::closure_pack_depth::pack_too_deep

//# run 0x99::closure_pack_depth::pack_at_limit_then_copy
