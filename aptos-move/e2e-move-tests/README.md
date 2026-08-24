# e2e-move-tests

## Confidential assets (`confidential_asset_e2e`)

These tests compile large Move bundles; if you see a **stack overflow** on the test thread, raise the stack before running, for example:

```bash
export RUST_MIN_STACK=8388608   # 8 MiB; same order as MSVC `/STACK:8000000` for Windows hosts
cargo test -p e2e-move-tests confidential_asset
```

## Keyless

To run the keyless VM tests:

```
cargo test -- keyless
```
