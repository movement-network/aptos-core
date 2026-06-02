// Copyright (c) Aptos Foundation
// SPDX-License-Identifier: Apache-2.0

//! End-to-end coverage for fuzz-expanded `#[test]` execution.
//!
//! The compiler-side golden tests only check diagnostics; they never run the
//! Move VM. These tests build a plan AND execute it, which is the path where an
//! expanded case name (e.g. `prop#3[_x=42]`) must NOT be used as the function
//! identifier — doing so previously panicked in `IdentStr::new(..).unwrap()`.

use move_unit_test::{test_reporter::UnitTestFactoryWithCostTable, UnitTestingConfig};
use std::io::Write;

/// Build a `UnitTestingConfig` for a single in-memory Move source string.
fn config_for(source: &str) -> (tempfile::TempDir, UnitTestingConfig) {
    let dir = tempfile::tempdir().unwrap();
    let src = dir.path().join("fuzz_mod.move");
    let mut f = std::fs::File::create(&src).unwrap();
    f.write_all(source.as_bytes()).unwrap();
    let config = UnitTestingConfig {
        num_threads: 1,
        source_files: vec![src.to_str().unwrap().to_owned()],
        dep_files: move_stdlib::move_stdlib_files(),
        named_address_values: move_stdlib::move_stdlib_named_addresses()
            .into_iter()
            .collect(),
        ..UnitTestingConfig::default()
    };
    (dir, config)
}

fn run(config: &UnitTestingConfig) -> (String, bool, usize) {
    let plan = config.build_test_plan().expect("test plan should build");
    let total_cases: usize = plan.module_tests.values().map(|m| m.tests.len()).sum();
    let (buffer, ok) = config
        .run_and_report_unit_tests(
            plan,
            None,
            None,
            Vec::new(),
            UnitTestFactoryWithCostTable::new(None, None),
        )
        .expect("running unit tests should not error");
    (String::from_utf8(buffer).unwrap(), ok, total_cases)
}

const DEFAULT_FUZZ_RUNS: usize = 16;

/// Implicit-fuzz parameters expand into `DEFAULT_FUZZ_RUNS` *uniquely named*
/// cases that all execute without panicking. Before the fix, the decorated
/// case name was fed to the VM loader and panicked; and a `bool` parameter
/// collapsed to 2 cases via map-key collision instead of staying at 16.
#[test]
fn implicit_fuzz_cases_run_without_panic() {
    let (_dir, config) = config_for(
        r#"
module 0x42::fuzz_mod {
    #[test]
    fun prop_u8(_x: u8) { }

    #[test]
    fun prop_bool(_b: bool) { }
}
"#,
    );
    let (output, ok, total) = run(&config);
    // Two functions, each kept at the full run count thanks to unique names.
    assert_eq!(
        total,
        2 * DEFAULT_FUZZ_RUNS,
        "each fuzz fn must expand to {} unique cases; output:\n{}",
        DEFAULT_FUZZ_RUNS,
        output
    );
    assert!(ok, "all fuzz cases should pass; output:\n{}", output);
    assert_eq!(
        output.matches("[ PASS").count(),
        2 * DEFAULT_FUZZ_RUNS,
        "every expanded case should report PASS; output:\n{}",
        output
    );
}

/// Explicit numeric matrices expand deterministically and run. This exercises
/// the numeric `Concrete`/`Matrix` coercion path (previously only addresses
/// were accepted).
#[test]
fn numeric_matrix_cases_run() {
    let (_dir, config) = config_for(
        r#"
module 0x42::fuzz_mod {
    #[test(_n = [10, 20, 30])]
    fun matrix_u64(_n: u64) { }
}
"#,
    );
    let (output, ok, total) = run(&config);
    assert_eq!(total, 3, "matrix should produce 3 cases; output:\n{}", output);
    assert!(ok, "matrix cases should pass; output:\n{}", output);
    assert_eq!(output.matches("[ PASS").count(), 3, "output:\n{}", output);
}
