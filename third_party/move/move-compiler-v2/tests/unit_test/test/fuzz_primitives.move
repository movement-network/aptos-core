// End-to-end: implicit fuzz on primitive types now produces actual test cases.
// Diagnostics-side, all we see is the `[NOTE] fuzz: expanded …` line per
// function — the expanded cases live in the runner's plan, not in compiler
// diagnostics.
module 0x1::M {
    #[test]
    public fun fuzz_u64(_a: u64) { }

    #[test]
    public fun fuzz_u8(_a: u8) { }

    #[test]
    public fun fuzz_bool(_a: bool) { }

    #[test]
    public fun fuzz_address(_a: address) { }

    #[test]
    public fun fuzz_pair(_a: u64, _b: address) { }

    #[test(_a in 1..=10)]
    public fun fuzz_range_u64(_a: u64) { }

    #[test(_a != 42)]
    public fun fuzz_exclude_u64(_a: u64) { }

    #[test(_a in [@0x1, @0x2, @0x3])]
    public fun fuzz_addr_list(_a: signer) { }
}
