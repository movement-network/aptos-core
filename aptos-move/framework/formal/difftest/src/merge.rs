//! Combine a VM↔Lean oracle (`TestSuite`) with extra `test_cases` from other JSON sources
//! (e.g. transactional e2e export). By default each appended row **keeps** its serialized
//! `skip_lean` flag. Pass **`--force-skip-lean`** to set `skip_lean: true` on every appended case
//! (VM-only merge) when the append file is not trusted for Lean evaluation.

use crate::schema::{OracleFragment, TestCase, TestSuite, CURRENT_SCHEMA_VERSION};
use anyhow::{Context, Result};
use std::path::{Path, PathBuf};

/// Relative paths resolve against `manifest_dir` first (the `difftest` crate), then cwd.
fn resolve_read_path(manifest_dir: &Path, p: &Path) -> PathBuf {
    if p.is_absolute() {
        return p.to_path_buf();
    }
    let under_manifest = manifest_dir.join(p);
    if under_manifest.exists() {
        return under_manifest;
    }
    if let Ok(cwd) = std::env::current_dir() {
        let under_cwd = cwd.join(p);
        if under_cwd.exists() {
            return under_cwd;
        }
    }
    under_manifest
}

/// Relative `-o` paths: prefer **current working directory** when the parent directory exists
/// (typical `cargo run` from repo root); otherwise fall back to the `difftest` crate directory.
fn resolve_write_path(manifest_dir: &Path, p: &Path) -> PathBuf {
    if p.is_absolute() {
        return p.to_path_buf();
    }
    if let Ok(cwd) = std::env::current_dir() {
        let under_cwd = cwd.join(p);
        if under_cwd
            .parent()
            .map(|d| d.exists())
            .unwrap_or(false)
        {
            return under_cwd;
        }
    }
    manifest_dir.join(p)
}

fn read_full_suite(path: &Path) -> Result<TestSuite> {
    let s = std::fs::read_to_string(path).with_context(|| format!("read {}", path.display()))?;
    serde_json::from_str(&s).with_context(|| format!("parse TestSuite {}", path.display()))
}

fn read_append_cases(path: &Path) -> Result<Vec<TestCase>> {
    let s = std::fs::read_to_string(path).with_context(|| format!("read {}", path.display()))?;
    if let Ok(suite) = serde_json::from_str::<TestSuite>(&s) {
        return Ok(suite.test_cases);
    }
    let only: OracleFragment = serde_json::from_str(&s).with_context(|| {
        format!(
            "{}: expected a full `TestSuite` JSON or an `OracleFragment` (`{{\"test_cases\":[...]}}`)",
            path.display()
        )
    })?;
    Ok(only.test_cases)
}

fn print_merge_help() {
    eprintln!(
        "\
merge — concatenate oracle JSON for one `lake exe difftest` run

Usage:
  cargo run -p move-lean-difftest -- merge -o OUT.json BASE.json APPEND.json [APPEND.json ...]

BASE must be a full `TestSuite` (e.g. from move-lean-difftest without `merge`).
Each APPEND may be a full `TestSuite` or an `OracleFragment` (`{{ \"test_cases\": [...] }}`, e.g. from `e2e-move-tests` CA export).

Relative **`-o` / `--output`** paths: written under **current working directory** when that path's parent exists (typical `cargo run` from repo root); otherwise next to this crate's `Cargo.toml`.

By default appended cases **preserve** `skip_lean` from each file. Pass
  --force-skip-lean
to set `skip_lean: true` on every appended row (Lean skips those rows after merge).

Example (repo root):
  cargo run -p move-lean-difftest -- merge -o aptos-move/framework/formal/difftest/difftest_merged.json \\
    aptos-move/framework/formal/difftest/difftest_oracle.json \\
    path/to/e2e_vm_fragment.json
"
    );
}

pub fn run_merge(args: Vec<String>) -> Result<()> {
    let mut output: Option<PathBuf> = None;
    let mut force_skip_lean = false;
    let mut positionals: Vec<PathBuf> = Vec::new();
    let mut it = args.iter().skip(2);
    while let Some(a) = it.next() {
        match a.as_str() {
            "-o" | "--output" => {
                let p = it
                    .next()
                    .ok_or_else(|| anyhow::anyhow!("merge: -o requires a path"))?;
                output = Some(PathBuf::from(p));
            },
            "--force-skip-lean" => force_skip_lean = true,
            // Back-compat: older scripts passed this when default was to force-skip.
            "--no-force-skip-lean" => force_skip_lean = false,
            "--help" | "-h" => {
                print_merge_help();
                std::process::exit(0);
            },
            s if s.starts_with('-') => anyhow::bail!("merge: unknown flag {s} (try merge --help)"),
            _ => positionals.push(PathBuf::from(a)),
        }
    }

    let output = output.context("merge: -o/--output PATH is required (try merge --help)")?;
    if positionals.len() < 2 {
        anyhow::bail!("merge: need BASE.json and at least one APPEND.json");
    }

    let manifest_dir = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
    let output_path = resolve_write_path(&manifest_dir, &output);

    let base_path = resolve_read_path(&manifest_dir, &positionals[0]);
    let mut base = read_full_suite(&base_path)?;
    let append_names: Vec<String> = positionals[1..]
        .iter()
        .map(|p| p.display().to_string())
        .collect();

    for append_path in &positionals[1..] {
        let append_resolved = resolve_read_path(&manifest_dir, append_path);
        let mut cases = read_append_cases(&append_resolved)?;
        if force_skip_lean {
            for c in &mut cases {
                c.skip_lean = true;
            }
        }
        base.test_cases.extend(cases);
    }

    base.schema_version = base.schema_version.max(CURRENT_SCHEMA_VERSION);
    if !append_names.is_empty() {
        base.module = format!(
            "{} | merge_append: {}",
            base.module,
            append_names.join(", ")
        );
    }

    let json = serde_json::to_string_pretty(&base)?;
    std::fs::write(&output_path, &json)
        .with_context(|| format!("write {}", output_path.display()))?;

    eprintln!(
        "merge: wrote {} test cases to {}",
        base.test_cases.len(),
        output_path.display()
    );
    Ok(())
}
