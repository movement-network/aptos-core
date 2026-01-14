/// Test module that uses aptos-stdlib types to verify framework dependencies work
module framework_test::framework_module {
    use std::string::String;
    use aptos_std::string_utils;

    #[view]
    public fun greet(): String {
        let addr = @0x123;
        string_utils::to_string(&addr)
    }
}
