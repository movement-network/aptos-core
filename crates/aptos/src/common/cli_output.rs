// Copyright © Aptos Foundation
// SPDX-License-Identifier: Apache-2.0

//! Global CLI output mode (human vs machine-oriented JSON).

use clap::{Parser, ValueEnum};
use std::sync::OnceLock;

static CLI_OUTPUT_MODE: OnceLock<CliOutputMode> = OnceLock::new();

/// How the Movement CLI formats its primary envelope and auxiliary output.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, ValueEnum)]
#[clap(rename_all = "lower")]
pub enum CliOutputMode {
    /// Default: pretty-printed JSON envelope, terminal-oriented escapes, progress on stderr.
    #[default]
    Human,
    /// Automation / agents: compact JSON envelope; avoid printing non-result text to stdout.
    Json,
}

impl CliOutputMode {
    /// Install resolved mode for this process (typically from [`MovementCli`](crate::MovementCli)).
    pub fn install(mode: Self) {
        let _ = CLI_OUTPUT_MODE.set(mode);
    }

    /// Mode used when [`install`](Self::install) was never called (e.g. unit tests, library use).
    #[inline]
    pub fn current() -> Self {
        CLI_OUTPUT_MODE.get().copied().unwrap_or(Self::Human)
    }

    #[inline]
    pub fn is_json_agent_mode(self) -> bool {
        matches!(self, Self::Json)
    }
}

/// Options parsed on every invocation (global arguments).
#[derive(Parser, Debug, Clone)]
pub struct GlobalOptions {
    /// Primary output style. Overridden by the `MOVEMENT_OUTPUT` environment variable when this
    /// flag is omitted (clap: explicit CLI wins over env).
    #[clap(
        long,
        global = true,
        value_enum,
        value_name = "MODE",
        env = "MOVEMENT_OUTPUT"
    )]
    pub output: Option<CliOutputMode>,
}

impl GlobalOptions {
    #[inline]
    pub fn resolved_output_mode(&self) -> CliOutputMode {
        self.output.unwrap_or(CliOutputMode::Human)
    }
}

/// Print to stdout only in human mode so agent/json mode can reserve stdout for the JSON envelope.
#[macro_export]
macro_rules! human_println {
    ($($arg:tt)*) => {{
        if !$crate::common::cli_output::CliOutputMode::current().is_json_agent_mode() {
            println!($($arg)*);
        }
    }};
}

/// Like [`human_println`] but without a trailing newline (`print!` vs `println!`).
#[macro_export]
macro_rules! human_print {
    ($($arg:tt)*) => {{
        if !$crate::common::cli_output::CliOutputMode::current().is_json_agent_mode() {
            print!($($arg)*);
        }
    }};
}

/// Progress on stderr; hidden in agent/json mode to keep stderr minimal for log aggregation.
#[macro_export]
macro_rules! human_eprintln {
    ($($arg:tt)*) => {{
        if !$crate::common::cli_output::CliOutputMode::current().is_json_agent_mode() {
            eprintln!($($arg)*);
        }
    }};
}

#[macro_export]
macro_rules! human_eprint {
    ($($arg:tt)*) => {{
        if !$crate::common::cli_output::CliOutputMode::current().is_json_agent_mode() {
            eprint!($($arg)*);
        }
    }};
}
