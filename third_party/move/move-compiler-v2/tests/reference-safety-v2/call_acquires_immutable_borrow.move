// Calling an acquiring function while the resource is immutably borrowed must
// be rejected at the source level: `take` may `move_from` the value under
// `reference`. The v2 processor historically only rejected mutable borrows,
// which let this program through to a bytecode verification failure.
module 0x42::m {
    struct R has key { value: u64 }

    fun take(addr: address): R acquires R {
        move_from<R>(addr)
    }

    fun immutable_conflict(addr: address): u64 acquires R {
        let reference = borrow_global<R>(addr);
        let R { value } = take(addr);
        reference.value + value
    }
}
