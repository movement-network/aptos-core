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

use move_compiler_v2::fuzz::DEFAULT_FUZZ_RUNS;

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
    // The plan still expands to one uniquely-named TestCase per draw (this count
    // comes from the plan, not the printed lines).
    assert_eq!(
        total,
        2 * DEFAULT_FUZZ_RUNS,
        "each fuzz fn must expand to {} unique cases; output:\n{}",
        DEFAULT_FUZZ_RUNS,
        output
    );
    assert!(ok, "all fuzz cases should pass; output:\n{}", output);
    // At report time, each fuzzed function collapses to a single aggregated PASS
    // line (every draw gathered into per-parameter arrays), preceded by one FUZZ
    // seed banner. Two fuzzed functions => 2 of each.
    assert_eq!(
        output.matches("[ PASS").count(),
        2,
        "each fuzz fn should report one aggregated PASS line; output:\n{}",
        output
    );
    assert_eq!(
        output.matches("[ FUZZ").count(),
        2,
        "each fuzz fn should print one seed banner; output:\n{}",
        output
    );
}

/// A fuzz batch whose cases fail collapses to a single aggregated `[ FAIL ]`
/// line (the failing draws gathered into the array), not one line per case, and
/// still fails the run. Guards the FAIL side of the batch reporting.
#[test]
fn failing_fuzz_batch_reports_single_fail_line() {
    let (_dir, config) = config_for(
        r#"
module 0x42::fuzz_mod {
    #[test]
    fun always_aborts(_x: u8) { abort 7 }
}
"#,
    );
    let (output, ok, total) = run(&config);
    assert_eq!(
        total, DEFAULT_FUZZ_RUNS,
        "the batch still expands to the full run count; output:\n{}",
        output
    );
    assert!(!ok, "a failing fuzz batch must fail the run; output:\n{}", output);
    assert_eq!(
        output.matches("[ FAIL").count(),
        1,
        "the whole batch should collapse to one aggregated FAIL line; output:\n{}",
        output
    );
    assert_eq!(
        output.matches("[ PASS").count(),
        0,
        "no case passed, so no PASS line; output:\n{}",
        output
    );
    assert_eq!(
        output.matches("[ FUZZ").count(),
        1,
        "one seed banner for the batch; output:\n{}",
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

/// Multiple explicit matrices expand *pairwise* (2-way covering), not as a full
/// Cartesian product. Three `[_,_,_]` matrices would be 3×3×3 = 27 cases under
/// the old Cartesian expansion; pairwise covers every pair of values across any
/// two parameters in 10 cases. This guards the default-pairwise behavior.
#[test]
fn multi_matrix_expands_pairwise_not_cartesian() {
    let (_dir, config) = config_for(
        r#"
module 0x42::fuzz_mod {
    #[test(_a = [1, 2, 3], _b = [1, 2, 3], _c = [1, 2, 3])]
    fun matrix3(_a: u64, _b: u64, _c: u64) { }
}
"#,
    );
    let (output, ok, total) = run(&config);
    assert_eq!(
        total, 10,
        "3x3x3 matrices should expand pairwise to 10 cases (27 under full Cartesian); output:\n{}",
        output
    );
    assert!(ok, "pairwise matrix cases should pass; output:\n{}", output);
    assert_eq!(output.matches("[ PASS").count(), 10, "output:\n{}", output);
}
