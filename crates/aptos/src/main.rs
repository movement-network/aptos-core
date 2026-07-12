// Copyright © Aptos Foundation
// SPDX-License-Identifier: Apache-2.0

//! Aptos is a one stop tool for operations, debugging, and other operations with the blockchain

#![forbid(unsafe_code)]

#[cfg(unix)]
#[global_allocator]
static ALLOC: jemallocator::Jemalloc = jemallocator::Jemalloc;

use clap::Parser;
use movement::{move_tool, MovementCli};
use std::{process::exit, time::Duration};

fn main() {
    // Register hooks.
    move_tool::register_package_hooks();

    // Create a runtime.
    let runtime = tokio::runtime::Builder::new_multi_thread()
        .enable_all()
        .build()
        .unwrap();

    let cli = MovementCli::parse();
    cli.install_output_mode();

    // Run the corresponding tool.
    let result = runtime.block_on(cli.execute());

    // Shutdown the runtime with a timeout. We do this to make sure that we don't sit
    // here waiting forever waiting for tasks that sometimes don't want to exit on
    // their own (e.g. telemetry, containers spawned by the localnet, etc).
    runtime.shutdown_timeout(Duration::from_millis(50));

    match result {
        Ok(inner) => println!("{}", inner),
        Err(inner) => {
            println!("{}", inner);
            exit(1);
        },
    }
}
