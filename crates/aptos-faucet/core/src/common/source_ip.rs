// Copyright © Aptos Foundation
// SPDX-License-Identifier: Apache-2.0

use poem::{
    http::{header::HeaderMap, HeaderName},
    web::RealIp,
    Addr, FromRequest, Request, RequestBody, Result,
};
use std::net::{IpAddr, SocketAddr};

const X_FORWARDED_FOR: HeaderName = HeaderName::from_static("x-forwarded-for");

/// How many reverse proxies in front of the faucet append to X-Forwarded-For.
/// This is attached to every request as request data (see `RunConfig::run`)
/// so that the `SourceIp` extractor can read it.
#[derive(Clone, Copy, Debug, Default, Eq, PartialEq)]
pub struct TrustedProxyHops(pub Option<u32>);

/// Extracts the IP of the client that made the request. Use this instead of
/// `RealIp` everywhere the faucet determines a source IP.
///
/// If no `TrustedProxyHops` is configured, this is exactly poem's `RealIp`:
/// it trusts a client-supplied X-Real-IP, then Forwarded, then the leftmost
/// X-Forwarded-For entry, then the socket address. That is only safe if a proxy
/// in front of the faucet overwrites all of those headers.
///
/// If `TrustedProxyHops(Some(n))` is configured, see `ip_from_trusted_proxies`.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct SourceIp(pub Option<IpAddr>);

impl<'a> FromRequest<'a> for SourceIp {
    async fn from_request(req: &'a Request, body: &mut RequestBody) -> Result<Self> {
        let trusted_proxy_hops = req.data::<TrustedProxyHops>().copied().unwrap_or_default();
        match trusted_proxy_hops.0 {
            None => Ok(SourceIp(RealIp::from_request(req, body).await?.0)),
            Some(hops) => {
                let socket_ip = match req.remote_addr().0 {
                    Addr::SocketAddr(addr) => Some(addr.ip()),
                    _ => None,
                };
                Ok(SourceIp(ip_from_trusted_proxies(
                    req.headers(),
                    socket_ip,
                    hops,
                )))
            },
        }
    }
}

/// Determine the client IP when the faucet sits behind `hops` reverse proxies,
/// each of which appends the address it received the request from to
/// X-Forwarded-For (as an AWS ALB does). The client controls everything to the
/// left of what our proxies appended, so the client IP is the `hops`-th entry
/// from the right. For a single ALB, `hops` is 1: the entry the ALB appended.
///
/// X-Real-IP and Forwarded are ignored, since a proxy that only appends to
/// X-Forwarded-For passes them through from the client unchanged. Multiple
/// X-Forwarded-For header lines are treated as one comma separated list, in
/// order.
///
/// If X-Forwarded-For has fewer than `hops` entries (or `hops` is 0), or the
/// selected entry is not an IP address, the socket address is used.
pub fn ip_from_trusted_proxies(
    headers: &HeaderMap,
    socket_ip: Option<IpAddr>,
    hops: u32,
) -> Option<IpAddr> {
    if hops == 0 {
        return socket_ip;
    }
    let entries: Vec<&str> = headers
        .get_all(X_FORWARDED_FOR)
        .iter()
        .filter_map(|value| value.to_str().ok())
        .flat_map(|value| value.split(','))
        .map(|entry| entry.trim())
        .collect();
    let index = match entries.len().checked_sub(hops as usize) {
        Some(index) => index,
        None => return socket_ip,
    };
    parse_forwarded_ip(entries[index]).or(socket_ip)
}

/// Parse an X-Forwarded-For entry, which is normally a bare IP address but may
/// carry a port, e.g. `203.0.113.7:4321` or `[2001:db8::1]:4321`.
fn parse_forwarded_ip(entry: &str) -> Option<IpAddr> {
    entry
        .parse::<IpAddr>()
        .ok()
        .or_else(|| entry.parse::<SocketAddr>().ok().map(|addr| addr.ip()))
}

#[cfg(test)]
mod test {
    use super::*;

    fn headers(pairs: &[(&str, &str)]) -> HeaderMap {
        let mut headers = HeaderMap::new();
        for (name, value) in pairs {
            headers.append(
                HeaderName::from_bytes(name.as_bytes()).unwrap(),
                value.parse().unwrap(),
            );
        }
        headers
    }

    fn ip(s: &str) -> Option<IpAddr> {
        Some(s.parse().unwrap())
    }

    const SOCKET: &str = "10.0.0.5";

    #[test]
    fn test_spoofed_x_real_ip_is_ignored() {
        let headers = headers(&[
            ("x-real-ip", "1.1.1.1"),
            ("forwarded", "for=2.2.2.2"),
            ("x-forwarded-for", "203.0.113.7"),
        ]);
        assert_eq!(
            ip_from_trusted_proxies(&headers, ip(SOCKET), 1),
            ip("203.0.113.7")
        );
    }

    #[test]
    fn test_spoofed_leftmost_x_forwarded_for_is_ignored() {
        // The client sent "X-Forwarded-For: 1.1.1.1" and the ALB appended the
        // real client address.
        let headers = headers(&[("x-forwarded-for", "1.1.1.1, 203.0.113.7")]);
        assert_eq!(
            ip_from_trusted_proxies(&headers, ip(SOCKET), 1),
            ip("203.0.113.7")
        );
    }

    #[test]
    fn test_one_hop_picks_rightmost_entry() {
        let headers = headers(&[("x-forwarded-for", "1.1.1.1, 2.2.2.2,203.0.113.7")]);
        assert_eq!(
            ip_from_trusted_proxies(&headers, ip(SOCKET), 1),
            ip("203.0.113.7")
        );
        // Two proxies: the client address is the second entry from the right.
        assert_eq!(
            ip_from_trusted_proxies(&headers, ip(SOCKET), 2),
            ip("2.2.2.2")
        );
    }

    #[test]
    fn test_multiple_header_lines_are_one_list() {
        let headers = headers(&[
            ("x-forwarded-for", "1.1.1.1"),
            ("x-forwarded-for", "203.0.113.7"),
        ]);
        assert_eq!(
            ip_from_trusted_proxies(&headers, ip(SOCKET), 1),
            ip("203.0.113.7")
        );
    }

    #[test]
    fn test_entry_with_port() {
        let headers = headers(&[("x-forwarded-for", "1.1.1.1, [2001:db8::1]:4321")]);
        assert_eq!(
            ip_from_trusted_proxies(&headers, ip(SOCKET), 1),
            ip("2001:db8::1")
        );
    }

    #[test]
    fn test_fewer_entries_than_hops_falls_back_to_socket() {
        let headers_one = headers(&[("x-forwarded-for", "203.0.113.7")]);
        assert_eq!(
            ip_from_trusted_proxies(&headers_one, ip(SOCKET), 2),
            ip(SOCKET)
        );
        // No X-Forwarded-For at all, but a spoofed X-Real-IP.
        let headers_none = headers(&[("x-real-ip", "1.1.1.1")]);
        assert_eq!(
            ip_from_trusted_proxies(&headers_none, ip(SOCKET), 1),
            ip(SOCKET)
        );
        // An unparseable selected entry also falls back to the socket.
        let headers_bad = headers(&[("x-forwarded-for", "1.1.1.1, unknown")]);
        assert_eq!(
            ip_from_trusted_proxies(&headers_bad, ip(SOCKET), 1),
            ip(SOCKET)
        );
        assert_eq!(
            ip_from_trusted_proxies(&headers_one, ip(SOCKET), 0),
            ip(SOCKET)
        );
    }

    fn request(pairs: &[(&str, &str)], hops: Option<TrustedProxyHops>) -> Request {
        let mut builder = Request::builder();
        for (name, value) in pairs {
            builder = builder.header(*name, *value);
        }
        let mut request = builder.finish();
        if let Some(hops) = hops {
            request.set_data(hops);
        }
        request
    }

    #[tokio::test]
    async fn test_default_is_unchanged_real_ip() {
        let cases: Vec<Vec<(&str, &str)>> = vec![
            vec![
                ("x-real-ip", "1.1.1.1"),
                ("x-forwarded-for", "2.2.2.2, 3.3.3.3"),
            ],
            vec![("forwarded", "for=4.4.4.4"), ("x-forwarded-for", "2.2.2.2")],
            vec![("x-forwarded-for", "2.2.2.2, 3.3.3.3")],
            vec![],
        ];
        for pairs in cases {
            let real_ip = RealIp::from_request_without_body(&request(&pairs, None))
                .await
                .unwrap()
                .0;
            for hops in [None, Some(TrustedProxyHops(None))] {
                let source_ip = SourceIp::from_request_without_body(&request(&pairs, hops))
                    .await
                    .unwrap()
                    .0;
                assert_eq!(source_ip, real_ip, "headers {:?}", pairs);
            }
        }
        // Spot check that the default really is the spoofable behaviour.
        let pairs = [("x-real-ip", "1.1.1.1"), ("x-forwarded-for", "2.2.2.2")];
        assert_eq!(
            SourceIp::from_request_without_body(&request(&pairs, None))
                .await
                .unwrap()
                .0,
            ip("1.1.1.1")
        );
    }

    #[tokio::test]
    async fn test_extractor_uses_trusted_proxy_hops() {
        let pairs = [
            ("x-real-ip", "1.1.1.1"),
            ("forwarded", "for=4.4.4.4"),
            ("x-forwarded-for", "2.2.2.2, 203.0.113.7"),
        ];
        let source_ip =
            SourceIp::from_request_without_body(&request(&pairs, Some(TrustedProxyHops(Some(1)))))
                .await
                .unwrap()
                .0;
        assert_eq!(source_ip, ip("203.0.113.7"));
    }

    /// The server attaches `TrustedProxyHops` as data outside the log middleware
    /// and the nested API routes (see `RunConfig::run`). Check that an endpoint
    /// behind that same shape sees it.
    #[tokio::test]
    async fn test_trusted_proxy_hops_reaches_nested_endpoints() {
        use crate::middleware::middleware_log;
        use poem::{handler, Endpoint, EndpointExt, Route};

        #[handler]
        fn echo(source_ip: SourceIp) -> String {
            format!("{:?}", source_ip.0)
        }

        let app = Route::new()
            .nest("", Route::new().at("/fund", poem::post(echo)))
            .around(middleware_log)
            .data(TrustedProxyHops(Some(1)));
        let request = Request::builder()
            .method(poem::http::Method::POST)
            .uri(poem::http::Uri::from_static("/fund"))
            .header("x-real-ip", "1.1.1.1")
            .header("x-forwarded-for", "2.2.2.2, 203.0.113.7")
            .finish();
        let body = app
            .call(request)
            .await
            .unwrap()
            .into_body()
            .into_string()
            .await
            .unwrap();
        assert_eq!(body, format!("{:?}", ip("203.0.113.7")));
    }
}
