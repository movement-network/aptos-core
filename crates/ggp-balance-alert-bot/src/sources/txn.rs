use serde::Deserialize;

#[derive(Debug, Deserialize)]
pub struct Transaction {
    pub version: String,
    pub changes: Option<Vec<WriteChange>>,
}

#[derive(Debug, Deserialize)]
#[serde(tag = "type")]
pub enum WriteChange {
    #[serde(rename = "write_resource")]
    WriteResource { address: String, data: ResourceData },
    #[serde(other)]
    Other,
}

#[derive(Debug, Deserialize)]
pub struct ResourceData {
    pub r#type: String,
    pub data: serde_json::Value,
}

pub fn extract_ggp_balance_from_txn_changes(ggp_addr: &str, txns: &[Transaction]) -> Option<u64> {
    for t in txns {
        if let Some(changes) = &t.changes {
            for ch in changes {
                if let WriteChange::WriteResource { address, data } = ch {
                    if address.eq_ignore_ascii_case(ggp_addr)
                        && data.r#type.starts_with("0x1::coin::CoinStore<0x1::aptos_coin::AptosCoin>")
                    {
                        if let Some(v) = data.data.get("coin").and_then(|c| c.get("value")).and_then(|v| v.as_u64()) {
                            return Some(v);
                        }
                    }
                }
            }
        }
    }
    None
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_balance_update() {
        let json = r#"[
          {
            "version": "123",
            "changes": [{
              "type": "write_resource",
              "address": "0x1",
              "data": {
                "type": "0x1::coin::CoinStore<0x1::aptos_coin::AptosCoin>",
                "data": {"coin": {"value": 4242}}
              }
            }]
          }
        ]"#;
        let txns: Vec<Transaction> = serde_json::from_str(json).unwrap();
        assert_eq!(extract_ggp_balance_from_txn_changes("0x1", &txns), Some(4242));
    }
}
