// User-declared fixtures. The default fuzz source mines `FIXTURE_<name>`
// constants from the module and pipes them into the matching parameter's
// candidate pool ahead of random + edge values.
module 0x1::M {
    const FIXTURE_AMOUNT: u64 = 42;
    const FIXTURE_AMOUNT_HI: u64 = 18446744073709551610;
    const FIXTURE_RECIPIENT: address = @0xCAFE;

    // `amount` and `recipient` get fixture-biased draws; `salt` does not.
    #[test]
    public fun fuzz_with_fixtures(_amount: u64, _recipient: address, _salt: u32) { }
}
