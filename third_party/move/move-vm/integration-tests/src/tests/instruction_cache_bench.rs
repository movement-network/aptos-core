// Copyright (c) The Move Contributors
// SPDX-License-Identifier: Apache-2.0

//! Micro-benchmark for the per-instruction cache hot path (Vec vs HashMap
//! representation). Exercises all four memoized instruction kinds — `Call`,
//! `CallGeneric`, `Pack`, `PackGeneric` — on the cache-hit path inside a tight
//! loop, which is where a HashMap lookup would cost more than a Vec index.
//!
//! Ignored by default (it is a benchmark, not a correctness test). Run with:
//!   cargo test -p move-vm-integration-tests instruction_cache_hot_path_bench \
//!     -- --ignored --nocapture

use crate::{
    compiler::{as_module, compile_units},
    tests::execute_function_with_single_storage_for_test,
};
use move_core_types::{
    account_address::AccountAddress, identifier::Identifier, value::MoveValue,
};
use move_vm_test_utils::InMemoryStorage;
use std::time::Instant;

const TEST_ADDR: AccountAddress = AccountAddress::new([42; AccountAddress::LENGTH]);

#[ignore]
#[test]
fn instruction_cache_hot_path_bench() {
    // Each loop iteration performs: foo->step (Call), step->wrap<u64>
    // (CallGeneric), Box<T> construction (PackGeneric), step->pk (Call),
    // P construction (Pack). After the first iteration every one of these is a
    // cache hit, so the loop measures hit-path lookup cost.
    let code = format!(
        r#"
        module 0x{}::M {{
            struct Box<T> has drop {{ v: T }}
            struct P has drop {{ a: u64 }}

            fun wrap<T>(v: T): Box<T> {{ Box<T> {{ v }} }}
            fun pk(x: u64): u64 {{ let _p = P {{ a: x }}; x }}

            fun step(x: u64): u64 {{
                let _b = wrap<u64>(x);
                pk(x)
            }}

            fun foo(n: u64): u64 {{
                let i = 0;
                let acc = 0;
                while (i < n) {{
                    acc = acc + step(i);
                    i = i + 1;
                }};
                acc
            }}
        }}
    "#,
        TEST_ADDR.to_hex()
    );

    let mut units = compile_units(&code).unwrap();
    let m = as_module(units.pop().unwrap());
    let mut blob = vec![];
    m.serialize(&mut blob).unwrap();

    let mut storage = InMemoryStorage::new();
    storage.add_module_bytes(m.self_addr(), m.self_name(), blob.into());

    let module_id = m.self_id();
    let fun_name = Identifier::new("foo").unwrap();

    const N: u64 = 3_000_000;
    const RUNS: usize = 5;

    let call = || {
        let args = vec![MoveValue::U64(N).simple_serialize().unwrap()];
        execute_function_with_single_storage_for_test(
            &storage, &module_id, &fun_name, &[], args,
        )
        .expect("execution succeeds");
    };

    // Warm up (module load, type resolution) so we time steady-state execution.
    call();

    let mut best = f64::MAX;
    for run in 0..RUNS {
        let start = Instant::now();
        call();
        let elapsed = start.elapsed();
        let ns_per_iter = elapsed.as_nanos() as f64 / N as f64;
        best = best.min(ns_per_iter);
        println!(
            "run {}: {:?} total, {:.3} ns/iter ({} iters)",
            run, elapsed, ns_per_iter, N
        );
    }
    println!(
        "instruction_cache_hot_path_bench: best = {:.3} ns/iter over {} runs of {} iters",
        best, RUNS, N
    );
}
