mod compiler;
mod schema;
mod suites;
mod typed_value;
mod vm;

use anyhow::{Context, Result};
use std::path::{Path, PathBuf};

const DEFAULT_ORACLE_ALL: &str = "difftest_oracle.json";

struct Args {
    quiet: bool,
    /// Empty = all suites (`vector`, `bcs`, `hash`).
    suite_filter: Vec<String>,
    output: Option<PathBuf>,
}

fn parse_args() -> Result<Args> {
    let mut quiet = false;
    let mut suite_filter = Vec::new();
    let mut output: Option<PathBuf> = None;
    let mut it = std::env::args().skip(1);
    while let Some(arg) = it.next() {
        match arg.as_str() {
            "--quiet" => quiet = true,
            "--suite" => {
                let id = it
                    .next()
                    .ok_or_else(|| anyhow::anyhow!("--suite requires an argument (vector, bcs, hash)"))?;
                suite_filter.push(id);
            },
            "--output" | "-o" => {
                let p = it
                    .next()
                    .ok_or_else(|| anyhow::anyhow!("--output requires a path"))?;
                output = Some(PathBuf::from(p));
            },
            "--help" | "-h" => {
                eprintln!(
                    "\
move-lean-difftest — run the real Move VM and write a JSON oracle for Lean difftest

Usage:
  cargo run -p move-lean-difftest [-- ARGS]

Options:
  --suite ID   Run only one suite (repeatable): vector | bcs | hash. Omit = all suites.
  -o, --output PATH   Write JSON here (relative to this crate dir, or absolute).
  --quiet    Do not print progress to stderr or JSON to stdout (file is still written)
  -h, --help This help

Default output path (when --output omitted):
  - all suites: {DEFAULT_ORACLE_ALL}
  - --suite bcs: difftest_oracle_bcs.json
  - --suite bcs --suite hash: difftest_oracle_bcs_hash.json (ids sorted)

The JSON is the VM ground truth for `lake exe difftest <path>` — not specific to vector.move.
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

fn main() -> Result<()> {
    let args = parse_args()?;

    let log = |msg: &str| {
        if !args.quiet {
            eprintln!("{msg}");
        }
    };

    let manifest_dir = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
    let output_path = resolve_output_path(&args, &manifest_dir);

    log("move-lean-difftest: setting up Move VM with stdlib natives...");
    let mut storage = vm::setup_storage()?;

    log("move-lean-difftest: compiling and loading stdlib modules...");
    vm::load_stdlib_modules(&mut storage)?;

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
        let cases = suite.generate_test_cases(&storage)?;
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
