#!/bin/bash
# Copyright (c) Aptos
# SPDX-License-Identifier: Apache-2.0
set -e

PROFILE=${PROFILE:-release}
FEATURES=${FEATURES:-""}

echo "Building aptos-node (core path)"
echo "PROFILE: $PROFILE"
echo "FEATURES: $FEATURES"
echo "CARGO_TARGET_DIR: $CARGO_TARGET_DIR"

if [ -n "$FEATURES" ]; then
    cargo build --profile="$PROFILE" --features="$FEATURES" -p aptos-node "$@"
else
    cargo build --locked --profile="$PROFILE" -p aptos-node "$@"
fi

# Copy required runtime binary out of target cache mount.
mkdir dist
cp "$CARGO_TARGET_DIR/$PROFILE/aptos-node" dist/aptos-node
