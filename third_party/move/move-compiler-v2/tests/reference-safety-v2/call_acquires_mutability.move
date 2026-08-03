module 0x42::m {
    struct R has key { value: u64 }

    fun take(addr: address): R acquires R {
        move_from<R>(addr)
    }

    fun mutable_conflict(addr: address) acquires R {
        let reference = borrow_global_mut<R>(addr);
        let R { value } = take(addr);
        reference.value = value
    }

    fun immutable_borrow_is_allowed(addr: address): u64 acquires R {
        let reference = borrow_global<R>(addr);
        let R { value } = take(addr);
        reference.value + value
    }
}
