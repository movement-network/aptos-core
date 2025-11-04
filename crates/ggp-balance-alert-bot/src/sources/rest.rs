use anyhow::Context;
use serde::Deserialize;

#[derive(Clone)]
pub struct RestClient {
    base: String,
    http: reqwest::Client,
}

impl RestClient {
    pub fn new(base: String) -> Self { Self { base, http: reqwest::Client::new() } }

    pub async fn get_apt_balance(&self, account: &str) -> anyhow::Result<u64> {
        // GET /v1/accounts/{address}/resource/0x1::coin::CoinStore<0x1::aptos_coin::AptosCoin>
        let url = format!(
            "{}/accounts/{}/resource/0x1::coin::CoinStore<0x1::aptos_coin::AptosCoin>",
            self.base, account
        );
        let resp = self.http.get(url).send().await?.error_for_status()?;
        let r: ResourceCoinStore = resp.json().await?;
        Ok(r.data.coin.value)
    }

    pub async fn get_ggp_address_via_view(&self) -> anyhow::Result<String> {
        let url = format!("{}/view", self.base);
        let payload = serde_json::json!({
            "function": "0x1::governed_gas_pool::governed_gas_pool_address",
            "type_arguments": [],
            "arguments": []
        });
        let resp = self.http.post(url).json(&payload).send().await?;
        let status = resp.status();
        let body = resp.text().await?;
        if !status.is_success() { anyhow::bail!("view governed_gas_pool_address failed: {} body: {}", status, body); }
        let vals: Vec<String> = serde_json::from_str(&body).context("parse ggp address view")?;
        vals.get(0).cloned().context("empty ggp address view result")
    }

    pub async fn get_active_validator_count(&self) -> anyhow::Result<u64> {
        // GET /v1/accounts/0x1/resource/0x1::stake::ValidatorSet
        // Count active + pending_active validators for reserve planning.
        // We include pending_active because these validators will need gas reserves soon,
        // so the threshold calculation should account for them to ensure sufficient reserves.
        let url = format!("{}/accounts/0x1/resource/0x1::stake::ValidatorSet", self.base);
        let resp = self.http.get(&url).send().await?.error_for_status()?;
        let r: ValidatorSetResp = resp.json().await.context("parse ValidatorSet response")?;
        let count = (r.data.active_validators.len() + r.data.pending_active.len()) as u64;
        Ok(count)
    }
}

#[derive(Debug, Deserialize)]
struct ResourceCoinStore { data: CoinStoreData }

#[derive(Debug, Deserialize)]
struct CoinStoreData { coin: Coin }

#[derive(Debug, Deserialize)]
struct Coin { value: u64 }

#[derive(Debug, Deserialize)]
struct ValidatorSetResp {
    data: ValidatorSetData,
}

#[derive(Debug, Deserialize)]
struct ValidatorSetData {
    active_validators: Vec<serde_json::Value>,
    #[serde(default)]
    pending_active: Vec<serde_json::Value>,
}
