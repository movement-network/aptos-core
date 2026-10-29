// Copyright (c) Aptos Foundation
// SPDX-License-Identifier: Apache-2.0

//! Replace the host protocol of one BCS-encoded on-chain network address.
//!
//! This is intentionally an offline review helper. It neither fetches chain state
//! nor submits a transaction. The input must be the `0x`-prefixed BCS encoding of
//! `Vec<NetworkAddress>` copied from the resource being reviewed.
//!
//! ```text
//! cargo run -p aptos-types --example swap_network_address_host -- \
//!   0x<BCS_VEC_NETWORK_ADDRESSES> 0 /dns/new-validator.example.com
//! ```

use anyhow::{anyhow, bail, Context, Result};
use aptos_types::network_address::{NetworkAddress, Protocol};
use std::{env, str::FromStr};

fn decode_addresses(encoded: &str) -> Result<Vec<NetworkAddress>> {
    let encoded = encoded
        .strip_prefix("0x")
        .or_else(|| encoded.strip_prefix("0X"))
        .ok_or_else(|| anyhow!("encoded addresses must start with 0x"))?;
    let bytes = hex::decode(encoded).context("encoded addresses are not valid hex")?;
    bcs::from_bytes(&bytes).context("encoded addresses are not BCS Vec<NetworkAddress>")
}

fn host_protocol(host: &str) -> Result<Protocol> {
    let protocols: Vec<_> = NetworkAddress::from_str(host)
        .context("replacement host is not a valid network address protocol")?
        .into_iter()
        .collect();

    match protocols.as_slice() {
        [protocol @ (Protocol::Ip4(_)
        | Protocol::Ip6(_)
        | Protocol::Dns(_)
        | Protocol::Dns4(_)
        | Protocol::Dns6(_))] => Ok(protocol.clone()),
        _ => bail!(
            "replacement host must contain exactly one /ip4, /ip6, /dns, /dns4, or /dns6 protocol"
        ),
    }
}

/// Decode, validate, and replace only the leading host protocol at `index`.
///
/// Addresses must be canonical production Aptos network addresses, so malformed
/// BCS or incomplete/non-production protocol stacks are rejected rather than
/// being rewritten.
pub fn swap_host(
    encoded: &str,
    index: usize,
    replacement_host: &str,
) -> Result<(Vec<NetworkAddress>, Vec<NetworkAddress>, String)> {
    let before = decode_addresses(encoded)?;
    let replacement = host_protocol(replacement_host)?;
    let original = before.get(index).ok_or_else(|| {
        anyhow!(
            "address index {index} is out of range for {} addresses",
            before.len()
        )
    })?;

    if !original.is_aptosnet_addr() {
        bail!("address at index {index} is not a complete production Aptos network address");
    }

    let mut after = before.clone();
    let mut protocols: Vec<_> = original.clone().into_iter().collect();
    protocols[0] = replacement;
    after[index] = NetworkAddress::from_protocols(protocols)
        .context("replacement would produce an invalid network address")?;
    let encoded = format!("0x{}", hex::encode(bcs::to_bytes(&after)?));
    Ok((before, after, encoded))
}

fn main() -> Result<()> {
    let args: Vec<_> = env::args().skip(1).collect();
    if args.len() != 3 {
        bail!(
            "usage: swap_network_address_host <0x_bcs_vec_network_addresses> <index> <replacement_host>"
        );
    }
    let index = args[1]
        .parse()
        .context("index must be a non-negative integer")?;
    let (before, after, encoded) = swap_host(&args[0], index, &args[2])?;
    println!(
        "{}",
        serde_json::to_string_pretty(&serde_json::json!({
            "before": before.iter().map(ToString::to_string).collect::<Vec<_>>(),
            "after": after.iter().map(ToString::to_string).collect::<Vec<_>>(),
            "replacement_bcs_hex": encoded,
        }))?
    );
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    const KEY: &str = "080e287879c918794170e258bfaddd75acac5b3e350419044655e4983a487120";

    fn address(host: &str, port: u16, handshake: u8) -> NetworkAddress {
        NetworkAddress::from_str(&format!(
            "{host}/tcp/{port}/noise-ik/{KEY}/handshake/{handshake}"
        ))
        .unwrap()
    }

    fn encoded(addresses: &[NetworkAddress]) -> String {
        format!(
            "0x{}",
            hex::encode(bcs::to_bytes(&addresses.to_vec()).unwrap())
        )
    }

    #[test]
    fn swaps_only_selected_host_and_round_trips_bcs() {
        let addresses = vec![
            address("/dns4/old.example.com", 6180, 0),
            address("/ip4/192.0.2.10", 6181, 1),
        ];
        let (before, after, replacement) =
            swap_host(&encoded(&addresses), 0, "/dns6/new.example.com").unwrap();

        assert_eq!(before, addresses);
        assert_eq!(after[0].as_slice()[1..], before[0].as_slice()[1..]);
        assert_eq!(
            after[0].to_string(),
            format!("/dns6/new.example.com/tcp/6180/noise-ik/0x{KEY}/handshake/0")
        );
        assert_eq!(after[1], before[1]);
        assert_eq!(decode_addresses(&replacement).unwrap(), after);
    }

    #[test]
    fn accepts_dns_and_ip_host_variants() {
        for host in [
            "/dns/name.example",
            "/dns4/name.example",
            "/dns6/name.example",
            "/ip4/198.51.100.7",
            "/ip6/2001:db8::7",
        ] {
            let (_, after, _) =
                swap_host(&encoded(&[address("/dns/old.example", 6180, 0)]), 0, host).unwrap();
            assert!(after[0].to_string().starts_with(host));
        }
    }

    #[test]
    fn rejects_bad_input_and_empty_vectors() {
        assert!(swap_host("not-hex", 0, "/dns/new.example").is_err());
        assert!(swap_host("0xff", 0, "/dns/new.example").is_err());
        assert!(swap_host("0x00", 0, "/dns/new.example").is_err());
        assert!(swap_host(&encoded(&[]), 0, "/dns/new.example").is_err());
        let incomplete = NetworkAddress::from_str("/dns/old.example/tcp/6180").unwrap();
        assert!(swap_host(&encoded(&[incomplete]), 0, "/dns/new.example").is_err());
        assert!(swap_host(
            &encoded(&[address("/dns/old.example", 6180, 0)]),
            0,
            "/tcp/6180"
        )
        .is_err());
        assert!(swap_host(
            &encoded(&[address("/dns/old.example", 6180, 0)]),
            0,
            "/dns/new.example/tcp/6180"
        )
        .is_err());
        assert!(swap_host(
            &encoded(&[address("/dns/old.example", 6180, 0)]),
            2,
            "/dns/new.example"
        )
        .is_err());
    }
}
