/// Minimal `borrow_global` smoke for `move-lean-difftest`: a single `has key` resource at `@std`
/// (`0x1`). The Rust harness publishes `Counter` via BCS before invoking `read_std_counter`.
module 0x1::difftest_global_smoke {
    struct Counter has key {
        n: u64,
    }

    public fun read_std_counter(): u64 acquires Counter {
        borrow_global<Counter>(@0x1).n
    }
}
