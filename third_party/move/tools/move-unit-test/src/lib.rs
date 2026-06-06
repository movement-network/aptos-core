// Copyright (c) The Diem Core Contributors
// Copyright (c) The Move Contributors
// SPDX-License-Identifier: Apache-2.0

pub mod extensions;
pub mod test_reporter;
pub mod test_runner;

use crate::test_runner::TestRunner;
use clap::*;
use legacy_move_compiler::{
    self,
    shared::{self, NumericalAddress},
    unit_test::TestPlan,
};
use move_command_line_common::files::verify_and_create_named_address_mapping;
use legacy_move_compiler::unit_test::{ExpectedFailure, TestCase};
use move_compiler_v2::{
    fuzz::{
        DefaultFuzzSource, FuzzConfig, FuzzPlanMetadata, FuzzValueSource,
        DEFAULT_FUZZ_DICTIONARY_WEIGHT, DEFAULT_FUZZ_RUNS, DEFAULT_FUZZ_SEED,
    },
    fuzz_corpus, plan_builder as plan_builder_v2,
};
use std::sync::Arc;

/// Sidecar attached to [`TestPlan::runner_metadata`] when a fuzz source is
/// active. The runner downcasts to this type to drive shrinking on failing
/// fuzz cases and corpus persistence. Holding both the metadata and the
/// source means the runner doesn't need to know how to build either.
pub struct FuzzRunnerCtx {
    pub metadata: FuzzPlanMetadata,
    pub source: Arc<dyn FuzzValueSource>,
    /// When set, the runner appends failing fuzz arguments to
    /// `<corpus_dir>/failures/...` and replays prior entries on next run.
    pub corpus_dir: Option<std::path::PathBuf>,
}
use move_core_types::{effects::ChangeSet, language_storage::ModuleId};
use move_model::metadata::{CompilerVersion, LanguageVersion};
use move_package::compilation::compiled_package::build_and_report_v2_driver;
use move_vm_runtime::native_functions::NativeFunctionTable;
use std::{
    collections::BTreeMap,
    io::{Result, Write},
    marker::Send,
    sync::Mutex,
};
use test_reporter::UnitTestFactory;

/// The default value bounding the amount of gas consumed in a test.
const DEFAULT_EXECUTION_BOUND: u64 = 1_000_000;

/// Default number of threads used to run tests. Single source of truth shared
/// by the `--threads` CLI default and `UnitTestingConfig::default`, which must
/// agree (the latter is what every programmatic embedder gets).
const DEFAULT_NUM_THREADS: usize = 8;

/// Upper bound on regression cases replayed from the corpus per function.
/// Compile-time fuzz expansion is capped by `MAX_FUZZ_CASES` in the plan
/// builder, but regression cases are appended to the plan *after* planning, so
/// without a ceiling here a corpus that has grown across many CI runs would run
/// an unbounded number of in-process VM executions. When the corpus exceeds
/// this, the most recent entries are replayed and the overflow is reported.
const MAX_REGRESSION_REPLAYS_PER_FN: usize = 256;

#[derive(Debug, Parser, Clone)]
#[clap(author, version, about)]
pub struct UnitTestingConfig {
    /// A filter string to determine which unit tests to run
    #[clap(name = "filter", short = 'f', long = "filter")]
    pub filter: Option<String>,

    /// List all tests
    #[clap(name = "list", short = 'l', long = "list")]
    pub list: bool,

    /// Number of threads to use for running tests.
    #[clap(
        name = "num_threads",
        default_value_t = DEFAULT_NUM_THREADS,
        short = 't',
        long = "threads"
    )]
    pub num_threads: usize,

    /// Dependency files
    #[clap(
        name = "dependencies",
        long = "dependencies",
        short = 'd',
        num_args = 0..
    )]
    pub dep_files: Vec<String>,

    /// Report test statistics at the end of testing
    #[clap(name = "report_statistics", short = 's', long = "statistics")]
    pub report_statistics: bool,

    /// Show the storage state at the end of execution of a failing test
    #[clap(name = "global_state_on_error", short = 'g', long = "state_on_error")]
    pub report_storage_on_error: bool,

    #[clap(
        name = "report_stacktrace_on_abort",
        short = 'r',
        long = "stacktrace_on_abort"
    )]
    pub report_stacktrace_on_abort: bool,

    /// Ignore compiler's warning, and continue run tests
    #[clap(name = "ignore_compile_warnings", long = "ignore_compile_warnings")]
    pub ignore_compile_warnings: bool,

    /// Named address mapping
    #[clap(
        name = "NAMED_ADDRESSES",
        short = 'a',
        long = "addresses",
        value_parser = shared::parse_named_address
    )]
    pub named_address_values: Vec<(String, NumericalAddress)>,

    /// Source files
    #[clap(
        name = "sources",
        num_args = 0..
    )]
    pub source_files: Vec<String>,

    /// Use the stackless bytecode interpreter to run the tests and cross check its results with
    /// the execution result from Move VM.
    #[clap(long = "stackless")]
    pub check_stackless_vm: bool,

    /// Verbose mode
    #[clap(short = 'v', long = "verbose")]
    pub verbose: bool,

    /// Number of values to sample per implicit-fuzz `#[test]` parameter.
    #[clap(long = "fuzz-runs", default_value_t = DEFAULT_FUZZ_RUNS)]
    pub fuzz_runs: usize,

    /// Deterministic seed for the fuzz value source. Defaults to 0; change to
    /// search the space differently across CI runs.
    #[clap(long = "fuzz-seed", default_value_t = DEFAULT_FUZZ_SEED)]
    pub fuzz_seed: u64,

    /// Percentage weight (0..=100) of dictionary draws against random+edge
    /// draws when fuzzing primitive parameters. Mirrors Foundry's
    /// `dictionary_weight`.
    #[clap(long = "fuzz-dictionary-weight", default_value_t = DEFAULT_FUZZ_DICTIONARY_WEIGHT)]
    pub fuzz_dictionary_weight: u8,

    /// Directory used as the fuzz corpus. When set, regression cases from
    /// `<dir>/failures/` are replayed alongside fresh fuzz draws, and any
    /// fuzz-generated test that fails is appended to it. Disabled by default.
    #[clap(long = "fuzz-corpus-dir")]
    pub fuzz_corpus_dir: Option<std::path::PathBuf>,
}

fn format_module_id(module_id: &ModuleId) -> String {
    format!(
        "0x{}::{}",
        module_id.address().short_str_lossless(),
        module_id.name()
    )
}

impl Default for UnitTestingConfig {
    fn default() -> Self {
        Self {
            filter: None,
            num_threads: DEFAULT_NUM_THREADS,
            report_statistics: false,
            report_storage_on_error: false,
            report_stacktrace_on_abort: false,
            ignore_compile_warnings: false,
            source_files: vec![],
            dep_files: vec![],
            check_stackless_vm: false,
            verbose: false,
            list: false,
            named_address_values: vec![],
            fuzz_runs: DEFAULT_FUZZ_RUNS,
            fuzz_seed: DEFAULT_FUZZ_SEED,
            fuzz_dictionary_weight: DEFAULT_FUZZ_DICTIONARY_WEIGHT,
            fuzz_corpus_dir: None,
        }
    }
}

impl UnitTestingConfig {
    pub fn with_named_addresses(
        mut self,
        named_address_values: BTreeMap<String, NumericalAddress>,
    ) -> Self {
        assert!(self.named_address_values.is_empty());
        self.named_address_values = named_address_values.into_iter().collect();
        self
    }

    fn compile_to_test_plan(
        &self,
        source_files: Vec<String>,
        deps: Vec<String>,
        // Whether to replay the regression corpus into this plan. The deps-only
        // pass in `build_test_plan` discards everything but files/module_info,
        // so replaying there is wasted disk I/O — callers pass `false` for it.
        replay_corpus: bool,
    ) -> Option<TestPlan> {
        let addresses =
            verify_and_create_named_address_mapping(self.named_address_values.clone()).ok()?;
        let (build_opt, files, units, fuzz_source) = {
            let options = move_compiler_v2::Options {
                compile_test_code: true,
                testing: true,
                sources: source_files,
                dependencies: deps,
                compiler_version: Some(CompilerVersion::latest_stable()),
                language_version: Some(LanguageVersion::latest_stable()),
                named_address_mapping: addresses
                    .iter()
                    .map(|(string, num_addr)| format!("{}={}", string, num_addr))
                    .collect(),
                ..Default::default()
            };
            let (files, units, env) = build_and_report_v2_driver(options).unwrap();
            let fuzz_config = FuzzConfig {
                runs: self.fuzz_runs,
                seed: self.fuzz_seed,
                dictionary_weight: self.fuzz_dictionary_weight,
                ..FuzzConfig::default()
            };
            let fuzz_source: Arc<dyn FuzzValueSource> =
                Arc::new(DefaultFuzzSource::new(&env, fuzz_config));
            let build_opt = plan_builder_v2::construct_test_plan_with_fuzz_source(
                &env,
                None,
                fuzz_source.as_ref(),
            );
            (build_opt, files, units, fuzz_source)
        };
        build_opt.map(|build| {
            let mut plans = build.plans;
            // Topic 2: replay regression corpus by appending saved failing
            // argument vectors as extra TestCases. The runner re-runs them
            // before the fresh fuzz draws.
            if let Some(corpus_dir) = self.fuzz_corpus_dir.as_ref().filter(|_| replay_corpus) {
                for module_plan in plans.iter_mut() {
                    let module_id = module_plan.module_id.clone();
                    // Collect one representative `expected_failure` per real
                    // function symbol. Deduping by `function_name` (the real
                    // Move symbol, not the decorated display name) means each
                    // function's corpus file is read exactly once, regardless
                    // of how many expanded cases share it.
                    let mut stems: BTreeMap<String, Option<ExpectedFailure>> = BTreeMap::new();
                    for case in module_plan.tests.values() {
                        stems
                            .entry(case.function_name.clone())
                            .or_insert_with(|| case.expected_failure.clone());
                    }
                    for (stem, expected_failure) in stems {
                        let regressions =
                            fuzz_corpus::load_failures(corpus_dir, &module_id, &stem)
                                .unwrap_or_default();
                        // Bound replays per function. Corpus entries are
                        // appended in discovery order, so the newest failures
                        // are at the tail — keep those and skip the oldest
                        // overflow, reporting what was dropped rather than
                        // silently truncating.
                        let skip = regressions
                            .len()
                            .saturating_sub(MAX_REGRESSION_REPLAYS_PER_FN);
                        if skip > 0 {
                            // Plan assembly runs before any `TestOutput`/diagnostic
                            // sink exists (the compiler `GlobalEnv` is already
                            // dropped, and the corpus is unknown to the compiler),
                            // so stderr is the only channel available here. Keep it
                            // a single, clearly-prefixed line.
                            eprintln!(
                                "warning: fuzz: `{}` has {} saved regression failures; replaying \
                                 the most recent {} and skipping {} (trim the corpus or raise the \
                                 replay cap)",
                                stem,
                                regressions.len(),
                                MAX_REGRESSION_REPLAYS_PER_FN,
                                skip,
                            );
                        }
                        for (i, args) in regressions.into_iter().enumerate().skip(skip) {
                            let replay_name = format!("{}#regression[{}]", stem, i);
                            module_plan.tests.insert(
                                replay_name.clone(),
                                TestCase {
                                    test_name: replay_name,
                                    // Real symbol so the runner can load the
                                    // function; the `#regression[..]` name is
                                    // display-only.
                                    function_name: stem.clone(),
                                    arguments: args,
                                    expected_failure: expected_failure.clone(),
                                },
                            );
                        }
                    }
                }
            }
            let mut plan = TestPlan::new(plans, files, units, vec![]);
            plan.runner_metadata = Some(Arc::new(FuzzRunnerCtx {
                metadata: build.fuzz_metadata,
                source: fuzz_source,
                corpus_dir: self.fuzz_corpus_dir.clone(),
            }));
            plan
        })
    }

    /// Build a test plan from a unit test config
    pub fn build_test_plan(&self) -> Option<TestPlan> {
        let deps = self.dep_files.clone();

        let TestPlan {
            files, module_info, ..
        } = self.compile_to_test_plan(deps.clone(), vec![], false)?;

        let mut test_plan = self.compile_to_test_plan(self.source_files.clone(), deps, true)?;
        test_plan.module_info.extend(module_info);
        test_plan.files.extend(files);
        Some(test_plan)
    }

    /// Public entry point to Move unit testing as a library
    /// Returns `true` if all unit tests passed. Otherwise, returns `false`.
    pub fn run_and_report_unit_tests<W: Write + Send, F: UnitTestFactory + Send>(
        &self,
        test_plan: TestPlan,
        native_function_table: Option<NativeFunctionTable>,
        genesis_state: Option<ChangeSet>,
        writer: W,
        factory: F,
    ) -> Result<(W, bool)> {
        let shared_writer = Mutex::new(writer);
        let shared_options = Mutex::new(factory);

        if self.list {
            for (module_id, test_plan) in &test_plan.module_tests {
                for test_name in test_plan.tests.keys() {
                    writeln!(
                        shared_writer.lock().unwrap(),
                        "{}::{}: test",
                        format_module_id(module_id),
                        test_name
                    )?;
                }
            }
            return Ok((shared_writer.into_inner().unwrap(), true));
        }

        writeln!(shared_writer.lock().unwrap(), "Running Move unit tests")?;
        let mut test_runner = TestRunner::new(
            self.num_threads,
            self.report_storage_on_error,
            self.report_stacktrace_on_abort,
            test_plan,
            native_function_table,
            genesis_state,
            self.verbose,
        )
        .unwrap();

        if let Some(filter_str) = &self.filter {
            test_runner.filter(filter_str)
        }

        let test_results = test_runner.run(&shared_writer, &shared_options).unwrap();
        if self.report_statistics {
            test_results.report_statistics(&shared_writer)?;
        }

        if self.verbose {
            test_results.report_goldens(&shared_writer)?;
        }

        let ok = test_results.summarize(&shared_writer)?;

        let writer = shared_writer.into_inner().unwrap();
        Ok((writer, ok))
    }
}

#[test]
fn verify_tool() {
    use clap::CommandFactory;
    UnitTestingConfig::command().debug_assert()
}
