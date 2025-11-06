use crate::{
    alert::{AlertSink, LogAlert, SlackAlert},
    config::BotConfig,
    sources::rest::RestClient,
    threshold::{compute_dynamic_low_threshold, ThresholdParams},
};
use std::sync::Arc;
use tokio::time::{sleep, Duration};

pub async fn run_bot(cfg: BotConfig) -> anyhow::Result<()> {
    let rest = RestClient::new(cfg.rest_url.clone());

    let mut sinks: Vec<Arc<dyn AlertSink>> = vec![Arc::new(LogAlert)];
    if let Some(url) = &cfg.slack_webhook_url { sinks.push(Arc::new(SlackAlert::new(url.clone()))); }

    // Start health check server if port is configured
    if let Some(port) = cfg.health_check_port {
        let cfg_clone = cfg.clone();
        tokio::spawn(async move {
            if let Err(e) = start_health_check_server(port, cfg_clone).await {
                tracing::error!(error = %e, "health check server failed");
            }
        });
    }

    loop {
        if let Err(e) = tick(&cfg, &rest, &sinks).await {
            tracing::error!(error = %e, "tick failed");
        }
        sleep(Duration::from_secs(cfg.poll_secs)).await;
    }
}

async fn tick(
    cfg: &BotConfig,
    rest: &RestClient,
    sinks: &[Arc<dyn AlertSink>],
) -> anyhow::Result<()> {
    // Get GGP balance via Move view function (canonical way)
    let balance = rest.get_ggp_balance_via_view().await?;

    // Derive num_validators_hint from chain at runtime
    let num_validators_hint = rest.get_active_validator_count().await?;

    // Compute threshold locally (base params from env, num_validators_hint from chain)
    let p = ThresholdParams {
        base_per_validator: cfg.local_threshold.base_per_validator,
        runway_epochs: cfg.local_threshold.runway_epochs,
        safety_bps: cfg.local_threshold.safety_bps,
        num_validators_hint,
    };
    let threshold = compute_dynamic_low_threshold(Some(p));

    tracing::info!(%balance, %threshold, "GGP balance check");

    // Force alert in test mode, or alert if balance is below threshold
    if cfg.force_alert_test || (threshold > 0 && balance < threshold) {
        if cfg.force_alert_test {
            tracing::warn!("FORCE_ALERT_TEST mode: forcing alert for testing");
        }
        for s in sinks { s.alert_low_balance(balance, threshold).await; }
    }
    Ok(())
}

/// Start a simple HTTP health check server for PagerDuty/SRE monitoring.
/// Returns 200 OK if the bot is running, 503 if health checks fail.
async fn start_health_check_server(port: u16, cfg: BotConfig) -> anyhow::Result<()> {
    use hyper::service::{make_service_fn, service_fn};
    use hyper::{Body, Request, Response, Server, StatusCode};
    use std::convert::Infallible;

    let make_svc = make_service_fn(move |_conn| {
        let cfg = cfg.clone();
        async move {
            Ok::<_, Infallible>(service_fn(move |req: Request<Body>| {
                let cfg = cfg.clone();
                async move {
                    let response = match req.uri().path() {
                        "/health" | "/healthz" => {
                            // Perform basic health check: can we reach the REST endpoint?
                            let rest = RestClient::new(cfg.rest_url.clone());
                            match rest.get_ggp_address_via_view().await {
                                Ok(_) => Response::builder()
                                    .status(StatusCode::OK)
                                    .body(Body::from("OK"))
                                    .unwrap(),
                                Err(e) => {
                                    tracing::warn!(error = %e, "health check failed");
                                    Response::builder()
                                        .status(StatusCode::SERVICE_UNAVAILABLE)
                                        .body(Body::from(format!("Unhealthy: {}", e)))
                                        .unwrap()
                                }
                            }
                        }
                        _ => Response::builder()
                            .status(StatusCode::NOT_FOUND)
                            .body(Body::from("Not Found"))
                            .unwrap(),
                    };
                    Ok::<_, Infallible>(response)
                }
            }))
        }
    });

    let addr = ([0, 0, 0, 0], port).into();
    let server = Server::bind(&addr).serve(make_svc);
    tracing::info!(port = %port, "health check server started");
    server.await?;
    Ok(())
}
