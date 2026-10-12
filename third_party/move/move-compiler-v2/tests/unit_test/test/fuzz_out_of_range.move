// Out-of-range fuzz constraints are rejected at plan-build time — the same
// policy applied to concrete `#[test(a = ..)]` values — rather than silently
// wrapped (e.g. `!= 300` on a u8 must NOT become `!= 44`).
module 0x1::M {
    #[test(_a != 300)]
    public fun exclude_out_of_range(_a: u8) { }

    #[test(_a in 250..300)]
    public fun range_out_of_range(_a: u8) { }
}
