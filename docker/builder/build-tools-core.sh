#!/bin/bash
# Copyright (c) Aptos
# SPDX-License-Identifier: Apache-2.0
set -e

PROFILE=cli

echo "Building core tools for movement-core images"
echo "PROFILE: $PROFILE"
echo "CARGO_TARGET_DIR: $CARGO_TARGET_DIR"

# Build only binaries required by movement-core images.
cargo build --locked --profile="$PROFILE" \
    -p movement \
    -p aptos-debugger \
    -p aptos-faucet-service \
    "$@"

mkdir dist
cp "$CARGO_TARGET_DIR/$PROFILE/movement" dist/movement
cp "$CARGO_TARGET_DIR/$PROFILE/aptos-debugger" dist/aptos-debugger
cp "$CARGO_TARGET_DIR/$PROFILE/aptos-faucet-service" dist/aptos-faucet-service

# Keep historical CLI binary name for downstream images/scripts.
cp "$CARGO_TARGET_DIR/$PROFILE/movement" dist/aptos
