// Copyright © Aptos Foundation
// SPDX-License-Identifier: Apache-2.0

//! Machine-readable CLI metadata for automation and agents.

use crate::common::types::{CliCommand, CliError, CliResult, CliTypedResult};
use async_trait::async_trait;
use clap::{CommandFactory, Parser, Subcommand};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};

/// Introspection and schema helpers for the CLI.
#[derive(Subcommand)]
pub enum MetaTool {
    /// Emit the full command tree, arguments, and help text as JSON (for agents and tooling).
    CommandsSchema(CommandsSchemaArgs),
}

impl MetaTool {
    pub async fn execute(self) -> CliResult {
        match self {
            MetaTool::CommandsSchema(c) => c.execute_serialized().await,
        }
    }
}

/// Arguments for `movement meta commands-schema`.
#[derive(Parser, Default)]
pub struct CommandsSchemaArgs {
    /// Only emit the subcommand at this path (space-separated names, e.g. `move publish`).
    #[clap(long, value_name = "PATH")]
    pub path: Option<String>,
    /// Omit `help` and `about` text; keep structural fields only (smaller JSON for agents).
    #[clap(long)]
    pub brief: bool,
}

#[derive(Debug, Serialize, Deserialize)]
pub(crate) struct CommandSchemaNode {
    pub name: String,
    #[serde(skip_serializing_if = "Vec::is_empty")]
    pub aliases: Vec<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub about: Option<String>,
    #[serde(skip_serializing_if = "Vec::is_empty")]
    pub args: Vec<ArgSchema>,
    #[serde(skip_serializing_if = "Vec::is_empty")]
    pub subcommands: Vec<CommandSchemaNode>,
}

#[derive(Debug, Serialize, Deserialize)]
pub(crate) struct ArgSchema {
    pub id: String,
    pub long: Option<String>,
    pub short: Option<char>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub help: Option<String>,
    pub required: bool,
    pub num_args: String,
}

fn command_schema_tree(cmd: &clap::Command, brief: bool) -> CommandSchemaNode {
    let mut args = Vec::new();
    for arg in cmd.get_arguments() {
        let id = arg.get_id().as_str();
        if id == "help" || id == "version" {
            continue;
        }
        let long = arg.get_long().map(String::from);
        let short = arg.get_short();
        let help = if brief {
            None
        } else {
            arg.get_help().map(|h| h.to_string())
        };
        args.push(ArgSchema {
            id: id.to_string(),
            long,
            short,
            help,
            required: arg.is_required_set(),
            num_args: format!("{:?}", arg.get_num_args()),
        });
    }
    args.sort_by(|a, b| a.id.cmp(&b.id));

    let mut subcommands: Vec<CommandSchemaNode> = cmd
        .get_subcommands()
        .map(|s| command_schema_tree(s, brief))
        .collect();
    subcommands.sort_by(|a, b| a.name.cmp(&b.name));

    let about = if brief {
        None
    } else {
        cmd.get_about().map(|s| s.to_string())
    };

    CommandSchemaNode {
        name: cmd.get_name().to_string(),
        aliases: cmd.get_aliases().map(String::from).collect(),
        about,
        args,
        subcommands,
    }
}

/// Walk from `root` along subcommand names in `path` (whitespace-separated).
fn resolve_command_path<'a>(
    root: &'a clap::Command,
    path: &str,
) -> Result<&'a clap::Command, CliError> {
    let segments: Vec<&str> = path.split_whitespace().filter(|s| !s.is_empty()).collect();
    if segments.is_empty() {
        return Err(CliError::CommandArgumentError(
            "commands-schema: --path must contain at least one subcommand name".to_string(),
        ));
    }
    let mut current = root;
    for seg in &segments {
        current = current
            .get_subcommands()
            .find(|s| s.get_name() == *seg)
            .ok_or_else(|| {
                let names: Vec<_> = current.get_subcommands().map(|s| s.get_name()).collect();
                CliError::CommandArgumentError(format!(
                    "commands-schema: no subcommand {:?} under {:?}; valid: {}",
                    seg,
                    current.get_name(),
                    names.join(", ")
                ))
            })?;
    }
    Ok(current)
}

/// Build a JSON value describing `cmd` and all nested subcommands.
pub fn command_schema_value(cmd: &clap::Command, brief: bool) -> Value {
    let tree = command_schema_tree(cmd, brief);
    serde_json::to_value(tree).unwrap_or(json!({ "Error": "failed to serialize schema" }))
}

#[async_trait]
impl CliCommand<Value> for CommandsSchemaArgs {
    fn command_name(&self) -> &'static str {
        "MetaCommandsSchema"
    }

    async fn execute(self) -> CliTypedResult<Value> {
        let root = crate::MovementCli::command();
        let target = match self
            .path
            .as_deref()
            .map(str::trim)
            .filter(|s| !s.is_empty())
        {
            None => &root,
            Some(p) => resolve_command_path(&root, p)?,
        };
        Ok(command_schema_value(target, self.brief))
    }
}
