use anyhow::Context;
use serde::{de, Deserialize, Deserializer, Serialize};

#[derive(Clone)]
pub struct IndexerClient {
    endpoint: String,
    http: reqwest::Client,
}

impl IndexerClient {
    pub fn new(endpoint: String) -> Self { Self { endpoint, http: reqwest::Client::new() } }

    /// Query current coin balance (AptosCoin) for an owner address via GraphQL indexer.
    /// Tries `current_coin_balances` first; if unavailable, falls back to latest row from `coin_balances`.
    pub async fn get_latest_apt_balance(&self, owner: &str) -> anyhow::Result<Option<u64>> {
        // Try current_coin_balances query
        let q = GraphQlRequest {
            query: CURRENT_BALANCE_QUERY.to_string(),
            variables: serde_json::json!({
                "owner_address": owner,
                "coin_type": "0x1::aptos_coin::AptosCoin",
            }),
        };
        let resp = self.http.post(&self.endpoint).json(&q).send().await?;
        let status = resp.status();
        let text = resp.text().await?;
        if !status.is_success() {
            tracing::debug!(status = %status, body = %text, "indexer current_coin_balances non-success");
        }
        if let Ok(r) = serde_json::from_str::<GraphQlResponse<CurrentBalancesResp>>(&text) {
            if let Some(nodes) = r.data.and_then(|d| d.current_coin_balances) {
                if let Some(row) = nodes.first() {
                    return Ok(Some(row.amount));
                }
            }
        }
        // Fallback to coin_balances (historical), pick latest by transaction_version
        let q2 = GraphQlRequest {
            query: LATEST_BALANCE_QUERY.to_string(),
            variables: serde_json::json!({
                "owner_address": owner,
                "coin_type": "0x1::aptos_coin::AptosCoin",
                "limit": 1,
            }),
        };
        let resp2 = self.http.post(&self.endpoint).json(&q2).send().await?;
        let status2 = resp2.status();
        let body2 = resp2.text().await?;
        if !status2.is_success() {
            tracing::error!(status = %status2, body = %body2, "indexer coin_balances non-success");
            anyhow::bail!("graphql coin_balances request failed: {}", status2);
        }
        let r2: GraphQlResponse<BalancesResp> = serde_json::from_str(&body2)
            .with_context(|| format!("parse coin_balances resp, body: {}", body2))?;
        if let Some(nodes) = r2.data.and_then(|d| d.coin_balances) {
            if let Some(row) = nodes.first() { return Ok(Some(row.amount)); }
        }
        Ok(None)
    }
}

#[derive(Serialize)]
struct GraphQlRequest { query: String, variables: serde_json::Value }

#[derive(Deserialize)]
struct GraphQlResponse<T> { data: Option<T> }

#[derive(Deserialize)]
struct CurrentBalancesResp { current_coin_balances: Option<Vec<CurrentBalanceRow>> }

#[derive(Deserialize)]
struct CurrentBalanceRow { #[serde(deserialize_with = "de_amount")] amount: u64 }

#[derive(Deserialize)]
struct BalancesResp { coin_balances: Option<Vec<BalanceRow>> }

#[derive(Deserialize)]
struct BalanceRow { #[serde(deserialize_with = "de_amount")] amount: u64 }

const CURRENT_BALANCE_QUERY: &str = r#"
query CurrentBalance($owner_address: String, $coin_type: String) {
  current_coin_balances(
    where: {owner_address: {_eq: $owner_address}, coin_type: {_eq: $coin_type}}
    limit: 1
  ) { amount }
}
"#;

const LATEST_BALANCE_QUERY: &str = r#"
query LatestBalance($owner_address: String, $coin_type: String, $limit: Int) {
  coin_balances(
    where: {owner_address: {_eq: $owner_address}, coin_type: {_eq: $coin_type}}
    order_by: {transaction_version: desc}
    limit: $limit
  ) { amount }
}
"#;

fn de_amount<'de, D>(deserializer: D) -> Result<u64, D::Error>
where
    D: Deserializer<'de>,
{
    #[derive(Deserialize)]
    #[serde(untagged)]
    enum AmountRepr {
        Str(String),
        U64(u64),
        Num(serde_json::Number),
    }

    match AmountRepr::deserialize(deserializer)? {
        AmountRepr::U64(v) => Ok(v),
        AmountRepr::Num(n) => n
            .as_u64()
            .ok_or_else(|| de::Error::custom("amount number out of range for u64")),
        AmountRepr::Str(s) => s
            .parse::<u64>()
            .map_err(|_| de::Error::custom("failed to parse amount string as u64")),
    }
}
