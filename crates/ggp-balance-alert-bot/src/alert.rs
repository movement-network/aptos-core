use async_trait::async_trait;

#[async_trait]
pub trait AlertSink: Send + Sync {
    async fn alert_low_balance(&self, balance: u64, threshold: u64);
}

pub struct LogAlert;

#[async_trait]
impl AlertSink for LogAlert {
    async fn alert_low_balance(&self, balance: u64, threshold: u64) {
        tracing::warn!(%balance, %threshold, "GGP low balance alert");
    }
}

pub struct SlackAlert {
    webhook_url: String,
}

impl SlackAlert {
    pub fn new(webhook_url: String) -> Self { Self { webhook_url } }
}

#[derive(serde::Serialize)]
struct SlackMessage { text: String }

#[async_trait]
impl AlertSink for SlackAlert {
    async fn alert_low_balance(&self, balance: u64, threshold: u64) {
        let msg = SlackMessage { text: format!("GGP low balance: {} (threshold {})", balance, threshold) };
        let _ = reqwest::Client::new()
            .post(&self.webhook_url)
            .json(&msg)
            .send()
            .await
            .map_err(|e| tracing::error!(error = %e, "failed to send slack alert"));
    }
}

pub struct PagerDutyAlert; // TODO: implement
