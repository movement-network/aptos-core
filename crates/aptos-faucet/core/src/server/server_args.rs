// Copyright © Aptos Foundation
// SPDX-License-Identifier: Apache-2.0

use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, Deserialize, Serialize)]
pub struct ServerConfig {
    /// What address to listen on, e.g. localhost / 0.0.0.0
    #[serde(default = "ServerConfig::default_listen_address")]
    pub listen_address: String,

    /// What port to listen on.
    #[serde(default = "ServerConfig::default_listen_port")]
    pub listen_port: u16,

    /// API path base. e.g. "/v1"
    #[serde(default = "ServerConfig::default_api_path_base")]
    pub api_path_base: String,

    /// How the client IP used by checkers, bypassers and logs is determined.
    /// If unset (the default), the faucet uses poem's `RealIp`, which trusts a
    /// client-supplied X-Real-IP, then Forwarded, then the leftmost
    /// X-Forwarded-For entry. That is spoofable unless a proxy overwrites those
    /// headers. If set to N, the faucet trusts only the N rightmost
    /// X-Forwarded-For entries, i.e. those appended by its own N reverse
    /// proxies, and uses the Nth entry from the right as the client IP,
    /// ignoring X-Real-IP and Forwarded. Behind a single AWS ALB, use 1. If
    /// X-Forwarded-For has fewer than N entries, the socket address is used.
    #[serde(default)]
    pub trusted_proxy_hops: Option<u32>,
}

impl ServerConfig {
    fn default_listen_address() -> String {
        "0.0.0.0".to_string()
    }

    fn default_listen_port() -> u16 {
        10212
    }

    fn default_api_path_base() -> String {
        "".to_string()
    }
}
