# Paused confidential-asset interface (0x1)

PAUSED: confidential assets are disabled on Movement; interface retained for upgrade compatibility only.

Movement testnet already has `0x1::confidential_asset`, `confidential_balance`, `confidential_proof` and
`ristretto255_twisted_elgamal`; mainnet does not. These four modules let one `AptosFramework` build upgrade
both chains under the compatible upgrade policy while the feature stays disabled.

- Every struct that exists in the testnet bytecode is kept with identical name, abilities, type parameters and
  field layout. The compatible policy refuses to remove or change a struct, so they cannot be deleted.
- Every `public` function (including `public entry` and `#[view]`) is kept with an identical signature, and its
  body is `abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)` (`E_CONFIDENTIAL_ASSETS_PAUSED = 1` in each
  module).
- Private functions, `public(friend)` functions, `friend` declarations, `init_module`, constants, spec blocks and
  `#[test_only]` code are removed. The modules publish no resource, emit no event and write no state.
- The aptos-experimental copy (address 0x7) is a separate, unrelated package and is untouched.
