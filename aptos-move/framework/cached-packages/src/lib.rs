// Copyright © Aptos Foundation
// SPDX-License-Identifier: Apache-2.0

use aptos_framework::ReleaseBundle;
use once_cell::sync::Lazy;

pub mod aptos_framework_sdk_builder;
pub mod aptos_stdlib;
pub mod aptos_token_objects_sdk_builder;
pub mod aptos_token_sdk_builder;

#[cfg(unix)]
const HEAD_RELEASE_BUNDLE_BYTES: &[u8] = include_bytes!(concat!(env!("OUT_DIR"), "/head.mrb"));
#[cfg(windows)]
const HEAD_RELEASE_BUNDLE_BYTES: &[u8] = include_bytes!(concat!(env!("OUT_DIR"), "\\head.mrb"));

static HEAD_RELEASE_BUNDLE: Lazy<ReleaseBundle> = Lazy::new(|| {
    bcs::from_bytes::<ReleaseBundle>(HEAD_RELEASE_BUNDLE_BYTES).expect("bcs succeeds")
});

/// Returns the release bundle for the current code.
pub fn head_release_bundle() -> &'static ReleaseBundle {
    &HEAD_RELEASE_BUNDLE
}

#[cfg(test)]
mod tests {
    use super::head_release_bundle;
    use move_core_types::account_address::AccountAddress;

    #[test]
    fn shipped_bundle_excludes_experimental_modules() {
        let bundle = head_release_bundle();
        assert!(bundle
            .packages
            .iter()
            .all(|package| package.name() != "AptosExperimental"));
        assert!(bundle
            .compiled_modules()
            .iter()
            .all(|module| module.self_id().address() != &AccountAddress::SEVEN));
        assert!(bundle
            .source_dirs
            .iter()
            .all(|path| !path.contains("aptos-experimental")));
    }
}
