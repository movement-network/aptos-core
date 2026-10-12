// Bare #[test] on a function with parameters now treats the parameters as
// implicit fuzz inputs. With no FuzzValueSource registered the compiler reports
// a clear diagnostic instead of the old "Missing test parameter assignment".
module 0x1::M {
    #[test]
    public fun bare_with_signer(_a: signer) { }

    #[test]
    public fun bare_with_two(_a: signer, _b: address) { }

    // No parameters: no fuzz, no error.
    #[test]
    public fun bare_zero_args() { }
}

// Implicit fuzzing — intended behavior (read me)
// ===============================================
// A `#[test]` function whose parameters are NOT explicitly assigned (no
// `#[test(a = ..)]`, `a in ..`, or `a != ..`) treats each unassigned parameter
// as an implicit fuzz input over an unrestricted domain. This is a deliberate,
// backwards-incompatible change from the legacy compiler, which rejected such a
// test with a hard "Missing test parameter assignment in test" error.
//
// What you observe depends on whether a `FuzzValueSource` is registered:
//   * move-unit-test runner: installs `DefaultFuzzSource`, so each parameter is
//     sampled and the test expands into `--fuzz-runs` cases (default 16). A
//     bare `#[test] fun f(a: u64)` therefore RUNS rather than failing to build.
//   * compiler-only golden tests (this suite): a source is registered, so the
//     diagnostics show `fuzz: expanded <fn> to N cases`. With no source at all,
//     the planner reports a clear "no fuzz value source registered" error
//     instead of the old missing-assignment error.
//
// Functions with zero parameters are unaffected: no fuzzing, no error.
//
// Migration note: a pre-existing test that relied on the missing-assignment
// error to flag an under-specified signature will now be fuzzed instead. Assign
// the parameter explicitly (e.g. `#[test(a = 0)]`) to pin it to a fixed value.
