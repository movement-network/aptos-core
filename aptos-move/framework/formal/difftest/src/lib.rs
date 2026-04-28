//! Move ↔ Lean differential testing: VM oracle generation, JSON schema, and merge tooling.
//!
//! Downstream crates (for example `e2e-move-tests`) may depend on this library to emit
//! [`schema::OracleFragment`] / [`schema::TestCase`] rows compatible with `lake exe difftest`.
//! The `move-lean-difftest` binary entrypoint is [`run_cli`].

pub mod compiler;
pub mod corpus_verify;
pub mod merge;
pub mod oracle_row;
pub mod schema;
pub mod suites;
pub mod typed_value;
pub mod vm;

use anyhow::{Context, Result};
use std::path::{Path, PathBuf};

const DEFAULT_ORACLE_ALL: &str = "difftest_oracle.json";

struct Args {
    quiet: bool,
    suite_filter: Vec<String>,
    output: Option<PathBuf>,
    list_suites: bool,
}

fn parse_args() -> Result<Args> {
    let mut quiet = false;
    let mut suite_filter = Vec::new();
    let mut output: Option<PathBuf> = None;
    let mut list_suites = false;
    let mut it = std::env::args().skip(1);
    while let Some(arg) = it.next() {
        match arg.as_str() {
            "--quiet" => quiet = true,
            "--list-suites" => list_suites = true,
            "--suite" => {
                let ids = suites::all_suite_ids().join(", ");
                let id = it.next().ok_or_else(|| {
                    anyhow::anyhow!("--suite requires an argument (known ids: {ids})")
                })?;
                suite_filter.push(id);
            },
            "--output" | "-o" => {
                let p = it
                    .next()
                    .ok_or_else(|| anyhow::anyhow!("--output requires a path"))?;
                output = Some(PathBuf::from(p));
            },
            "--help" | "-h" => {
                let ids = suites::all_suite_ids().join(", ");
                eprintln!(
                    "\
move-lean-difftest — run the real Move VM and write a JSON oracle for Lean difftest

Usage:
  cargo run -p move-lean-difftest [-- ARGS]
  cargo run -p move-lean-difftest -- merge -o OUT.json BASE.json APPEND.json [...]
  cargo run -p move-lean-difftest -- verify-corpora   (hex corpus checks for corpora/confidential_assets/)

Options:
  --suite ID   Run only one suite (repeatable). Known IDs: {ids}. Omit = all suites.
  --list-suites   Print known suite IDs and exit (for scripts and inventory docs).
  -o, --output PATH   Write JSON here (relative to this crate dir, or absolute).
  --quiet    Do not print progress to stderr or JSON to stdout (file is still written)
  -h, --help This help

Default output path (when --output omitted):
  - all suites: {DEFAULT_ORACLE_ALL}
  - --suite bcs: difftest_oracle_bcs.json
  - --suite bcs --suite hash: difftest_oracle_bcs_hash.json (ids sorted)

The JSON is the VM ground truth for `lake exe difftest <path>` — Lean checks against it; neither side assumes the other is correct.

See `merge --help` for combining oracle JSON files; appended `skip_lean` flags are preserved unless you pass `--force-skip-lean`.
"
                );
                std::process::exit(0);
            },
            other => anyhow::bail!("unknown argument: {other} (try --help)"),
        }
    }
    Ok(Args {
        quiet,
        suite_filter,
        output,
        list_suites,
    })
}

fn default_output_path(manifest_dir: &Path, suite_filter: &[String]) -> PathBuf {
    if suite_filter.is_empty() {
        return manifest_dir.join(DEFAULT_ORACLE_ALL);
    }
    let mut ids = suite_filter.to_vec();
    ids.sort();
    if ids.len() == 1 {
        manifest_dir.join(format!("difftest_oracle_{}.json", ids[0]))
    } else {
        manifest_dir.join(format!("difftest_oracle_{}.json", ids.join("_")))
    }
}

fn resolve_output_path(args: &Args, manifest_dir: &Path) -> PathBuf {
    if let Some(p) = &args.output {
        if p.is_absolute() {
            return p.clone();
        }
        return manifest_dir.join(p);
    }
    default_output_path(manifest_dir, &args.suite_filter)
}

/// Entry point for the `move-lean-difftest` binary (`merge` subcommand and harness).
pub fn run_cli() -> Result<()> {
    let argv: Vec<String> = std::env::args().collect();
    if argv.len() >= 2 && argv[1] == "merge" {
        return merge::run_merge(argv);
    }
    if argv.len() >= 2 && argv[1] == "verify-corpora" {
        return corpus_verify::run();
    }

    let args = parse_args()?;

    if args.list_suites {
        for id in suites::all_suite_ids() {
            println!("{id}");
        }
        return Ok(());
    }

    let log = |msg: &str| {
        if !args.quiet {
            eprintln!("{msg}");
        }
    };

    let manifest_dir = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
    let output_path = resolve_output_path(&args, &manifest_dir);

    log("move-lean-difftest: setting up Aptos Move VM (head release natives + features)...");
    let mut storage = vm::setup_storage_aptos()?;

    log("move-lean-difftest: loading head framework bundle (stdlib + Aptos + experimental)...");
    vm::load_head_release_bundle(&mut storage)?;
    vm::ensure_sha512_move_stdlib_feature(&mut storage)?;

    let suite_list = suites::suites_filtered(&args.suite_filter)?;
    let mut all_cases = Vec::new();
    let mut module_tags = Vec::new();

    for suite in suite_list {
        log(&format!(
            "move-lean-difftest: loading module for suite {} ({})...",
            suite.id(),
            suite.name()
        ));
        suite.load_module(&mut storage)?;

        log(&format!(
            "move-lean-difftest: generating test cases for {}...",
            suite.id()
        ));
        let cases = suite.generate_test_cases(&mut storage)?;
        log(&format!(
            "move-lean-difftest: {} produced {} test cases",
            suite.id(),
            cases.len()
        ));
        module_tags.push(suite.name().to_string());
        all_cases.extend(cases);
    }

    let module_summary = module_tags.join(", ");
    let suite = schema::TestSuite {
        schema_version: schema::CURRENT_SCHEMA_VERSION,
        generator: "move-lean-difftest".into(),
        module: module_summary,
        test_cases: all_cases,
    };

    let json = serde_json::to_string_pretty(&suite)?;
    std::fs::write(&output_path, &json)
        .with_context(|| format!("write {}", output_path.display()))?;

    if !args.quiet {
        eprintln!(
            "move-lean-difftest: wrote {} test cases to {}",
            suite.test_cases.len(),
            output_path.display()
        );
        println!("{}", json);
    }

    Ok(())
}
