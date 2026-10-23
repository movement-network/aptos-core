// Copyright © Aptos Foundation
// Parts of the project are originally copyright © Meta Platforms, Inc.
// SPDX-License-Identifier: Apache-2.0

//! DO NOT USE OUTSIDE OF SMOKE_TEST CRATE
//!
//! This utility is to only be used inside of smoke test.

use aptos_forge::cargo_build_common_args;
use aptos_logger::prelude::*;
use once_cell::sync::Lazy;
use std::{collections::HashSet, env, path::PathBuf, process::Command, sync::Mutex};

const BINARY_BUILD_ERROR_MSG: &str = r#"
    Unable to build requested workspace binary. Cannot continue running tests.

    Try running `cargo build --workspace --bin <binary>` yourself.
"#;

// Binaries are built lazily so smoke tests only compile the helpers they actually use. The mutex
// also prevents parallel tests from rebuilding the same binary.
static BUILT_BINS: Lazy<Mutex<HashSet<String>>> = Lazy::new(|| Mutex::new(HashSet::new()));

// Path to top level workspace.
pub fn workspace_root() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .parent()
        .and_then(|path| path.parent())
        .expect("smoke-test crate must be under the workspace root")
        .to_path_buf()
}

// Path to the directory where build artifacts live.
// TODO maybe add an Environment Variable which points to built binaries.
fn build_dir() -> PathBuf {
    env::current_exe()
        .ok()
        .map(|mut path| {
            path.pop();
            if path.ends_with("deps") {
                path.pop();
            }
            path
        })
        .expect("Can't find the build directory. Cannot continue running tests")
}

// Path to a specified binary
pub fn get_bin<S: AsRef<str>>(bin_name: S) -> PathBuf {
    let bin_name = bin_name.as_ref();
    assert_ne!(
        "aptos-node", bin_name,
        "aptos-node must be built and used via local swarm cargo_build_aptos_node"
    );

    let mut built_bins = BUILT_BINS
        .lock()
        .expect("workspace binary build lock poisoned");
    if !built_bins.contains(bin_name) {
        info!(binary = bin_name, "Building project binary");
        let mut args = cargo_build_common_args();
        args.extend(["--workspace", "--exclude", "aptos-node", "--bin"]);

        let cargo_build = Command::new("cargo")
            .current_dir(workspace_root())
            .args(&args)
            .arg(bin_name)
            .output()
            .expect(BINARY_BUILD_ERROR_MSG);
        if !cargo_build.status.success() {
            error!(binary = bin_name, output = ?cargo_build, "Failed building project binary");
            panic!("{}", BINARY_BUILD_ERROR_MSG);
        }
        built_bins.insert(bin_name.to_owned());
        info!(binary = bin_name, "Finished building project binary");
    }
    drop(built_bins);

    let bin_path = build_dir().join(format!("{}{}", bin_name, env::consts::EXE_SUFFIX));

    // If the binary doesn't exist then either building it failed somehow or the supplied binary
    // name doesn't match any binaries this workspace can produce.
    if !bin_path.exists() {
        panic!(
            "Can't find binary '{}' in expected path {:?}",
            bin_name, bin_path
        );
    }

    bin_path
}
