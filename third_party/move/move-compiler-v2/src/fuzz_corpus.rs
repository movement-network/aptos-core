// Copyright (c) Aptos Foundation
// SPDX-License-Identifier: Apache-2.0

//! On-disk fuzz corpus.
//!
//! Layout — one BCS-encoded file per `(module, test)`:
//!
//! ```text
//! <corpus-dir>/failures/<addr>.<module>.<test>.bcs    Vec<Vec<MoveValue>>
//! <corpus-dir>/seeds/<addr>.<module>.<test>.bcs       Vec<Vec<MoveValue>>
//! ```
//!
//! - `failures/` — argument vectors that previously caused this test to fail.
//!   Always replayed first on the next run, so a regression never silently
//!   disappears.
//! - `seeds/` — argument vectors deemed interesting (e.g. mutated from
//!   prior runs). Replayed if `--fuzz-corpus-replay-seeds` is set.
//!
//! This is intentionally schema-thin: only the `Vec<MoveValue>` arguments
//! are persisted, not the full `ArgOrigin` metadata. Replayed entries run as
//! `Fixed`-origin TestCases — they reproduce the failing input but are not
//! eligible for further shrinking. The user can still get shrinking on the
//! fresh fuzz draws that run alongside them.

use anyhow::{anyhow, Context, Result};
use move_core_types::{
    account_address::AccountAddress, language_storage::ModuleId, u256, value::MoveValue,
};
use serde::{Deserialize, Serialize};
use std::{
    collections::BTreeSet,
    fs,
    path::{Path, PathBuf},
};

/// Wire format for corpus entries. `MoveValue` cannot be (de)serialized
/// without a `MoveTypeLayout`, so we round-trip through this proxy that
/// covers exactly the primitive set the default fuzz source produces.
#[derive(Debug, Clone, Serialize, Deserialize)]
enum WireValue {
    U8(u8),
    U16(u16),
    U32(u32),
    U64(u64),
    U128(u128),
    U256([u8; 32]),
    Bool(bool),
    Address([u8; AccountAddress::LENGTH]),
    Signer([u8; AccountAddress::LENGTH]),
}

impl WireValue {
    fn from_move(value: &MoveValue) -> Result<Self> {
        Ok(match value {
            MoveValue::U8(x) => WireValue::U8(*x),
            MoveValue::U16(x) => WireValue::U16(*x),
            MoveValue::U32(x) => WireValue::U32(*x),
            MoveValue::U64(x) => WireValue::U64(*x),
            MoveValue::U128(x) => WireValue::U128(*x),
            MoveValue::U256(x) => WireValue::U256(x.to_le_bytes()),
            MoveValue::Bool(b) => WireValue::Bool(*b),
            MoveValue::Address(a) => WireValue::Address(a.into_bytes()),
            MoveValue::Signer(a) => WireValue::Signer(a.into_bytes()),
            other => {
                return Err(anyhow!(
                    "corpus: unsupported MoveValue variant `{:?}` (only primitives are serialized)",
                    other
                ));
            },
        })
    }

    fn into_move(self) -> MoveValue {
        match self {
            WireValue::U8(x) => MoveValue::U8(x),
            WireValue::U16(x) => MoveValue::U16(x),
            WireValue::U32(x) => MoveValue::U32(x),
            WireValue::U64(x) => MoveValue::U64(x),
            WireValue::U128(x) => MoveValue::U128(x),
            WireValue::U256(bytes) => MoveValue::U256(u256::U256::from_le_bytes(&bytes)),
            WireValue::Bool(b) => MoveValue::Bool(b),
            WireValue::Address(a) => MoveValue::Address(AccountAddress::new(a)),
            WireValue::Signer(a) => MoveValue::Signer(AccountAddress::new(a)),
        }
    }
}

fn to_wire(args: &[MoveValue]) -> Result<Vec<WireValue>> {
    args.iter().map(WireValue::from_move).collect()
}

fn from_wire(args: Vec<WireValue>) -> Vec<MoveValue> {
    args.into_iter().map(WireValue::into_move).collect()
}

/// Subdirectory holding regression cases that previously failed.
const FAILURES_SUBDIR: &str = "failures";

/// Subdirectory holding mutated/seeded interesting cases.
const SEEDS_SUBDIR: &str = "seeds";

/// Compose the on-disk filename for one `(module, test)` pair.
fn corpus_filename(module_id: &ModuleId, test_name: &str) -> String {
    // Test names may contain `[`/`]`/`=`/`,` from expansion suffixes; replace
    // them with `_` so filenames stay portable.
    let sanitized: String = test_name
        .chars()
        .map(|c| match c {
            'A'..='Z' | 'a'..='z' | '0'..='9' | '_' | '-' | '.' => c,
            _ => '_',
        })
        .collect();
    format!(
        "{}.{}.{}.bcs",
        module_id.address().short_str_lossless(),
        module_id.name().as_str(),
        sanitized
    )
}

fn read_corpus_file(path: &Path) -> Result<Vec<Vec<MoveValue>>> {
    let bytes = fs::read(path).with_context(|| format!("reading {}", path.display()))?;
    let wire: Vec<Vec<WireValue>> = bcs::from_bytes(&bytes)
        .with_context(|| format!("decoding {}", path.display()))?;
    Ok(wire.into_iter().map(from_wire).collect())
}

fn write_corpus_file(path: &Path, cases: &[Vec<MoveValue>]) -> Result<()> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)
            .with_context(|| format!("creating {}", parent.display()))?;
    }
    let wire: Vec<Vec<WireValue>> = cases
        .iter()
        .map(|c| to_wire(c))
        .collect::<Result<_>>()?;
    let bytes = bcs::to_bytes(&wire).context("encoding corpus")?;
    fs::write(path, bytes).with_context(|| format!("writing {}", path.display()))?;
    Ok(())
}

/// Load failure-regression entries for `(module, test)`. Returns an empty
/// vector when no file exists.
pub fn load_failures(
    corpus_dir: &Path,
    module_id: &ModuleId,
    test_name: &str,
) -> Result<Vec<Vec<MoveValue>>> {
    let path = corpus_dir
        .join(FAILURES_SUBDIR)
        .join(corpus_filename(module_id, test_name));
    if !path.exists() {
        return Ok(Vec::new());
    }
    read_corpus_file(&path)
}

/// Load seed entries for `(module, test)`. Returns an empty vector when no
/// file exists.
pub fn load_seeds(
    corpus_dir: &Path,
    module_id: &ModuleId,
    test_name: &str,
) -> Result<Vec<Vec<MoveValue>>> {
    let path = corpus_dir
        .join(SEEDS_SUBDIR)
        .join(corpus_filename(module_id, test_name));
    if !path.exists() {
        return Ok(Vec::new());
    }
    read_corpus_file(&path)
}

/// Append `args` to the failures file for `(module, test)`, de-duping against
/// the existing entries. Idempotent.
pub fn append_failure(
    corpus_dir: &Path,
    module_id: &ModuleId,
    test_name: &str,
    args: &[MoveValue],
) -> Result<()> {
    let path = corpus_dir
        .join(FAILURES_SUBDIR)
        .join(corpus_filename(module_id, test_name));
    let mut existing = if path.exists() {
        read_corpus_file(&path)?
    } else {
        Vec::new()
    };
    let mut seen: BTreeSet<Vec<u8>> = existing
        .iter()
        .filter_map(|e| to_wire(e).ok().and_then(|w| bcs::to_bytes(&w).ok()))
        .collect();
    let key = to_wire(args).and_then(|w| bcs::to_bytes(&w).map_err(Into::into));
    let key = match key {
        Ok(k) => k,
        // Propagate rather than silently dropping: a failure we can't persist
        // must not look like a successfully-saved regression.
        Err(e) => return Err(e.context("corpus: cannot serialize failing arguments")),
    };
    if seen.insert(key) {
        existing.push(args.to_vec());
        write_corpus_file(&path, &existing)?;
    }
    Ok(())
}

/// Append `args` to the seeds file for `(module, test)`.
pub fn append_seed(
    corpus_dir: &Path,
    module_id: &ModuleId,
    test_name: &str,
    args: &[MoveValue],
) -> Result<()> {
    let path = corpus_dir
        .join(SEEDS_SUBDIR)
        .join(corpus_filename(module_id, test_name));
    let mut existing = if path.exists() {
        read_corpus_file(&path)?
    } else {
        Vec::new()
    };
    let mut seen: BTreeSet<Vec<u8>> = existing
        .iter()
        .filter_map(|e| to_wire(e).ok().and_then(|w| bcs::to_bytes(&w).ok()))
        .collect();
    let key = to_wire(args).and_then(|w| bcs::to_bytes(&w).map_err(Into::into));
    let key = match key {
        Ok(k) => k,
        Err(e) => return Err(e.context("corpus: cannot serialize seed arguments")),
    };
    if seen.insert(key) {
        existing.push(args.to_vec());
        write_corpus_file(&path, &existing)?;
    }
    Ok(())
}

/// Standard path resolution. Pass through to expose the layout.
pub fn failures_dir(corpus_dir: &Path) -> PathBuf {
    corpus_dir.join(FAILURES_SUBDIR)
}

pub fn seeds_dir(corpus_dir: &Path) -> PathBuf {
    corpus_dir.join(SEEDS_SUBDIR)
}
