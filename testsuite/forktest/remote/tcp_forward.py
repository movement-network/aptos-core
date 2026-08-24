#!/usr/bin/env python3

# Copyright © Aptos Foundation
# SPDX-License-Identifier: Apache-2.0

import argparse
import select
import socket
import socketserver


class ForwardHandler(socketserver.BaseRequestHandler):
    target: tuple[str, int]

    def handle(self) -> None:
        with socket.create_connection(self.target, timeout=10) as upstream:
            peers = {
                self.request: upstream,
                upstream: self.request,
            }
            while True:
                readable, _, _ = select.select(peers, [], [], 30)
                if not readable:
                    continue
                for source in readable:
                    data = source.recv(64 * 1024)
                    if not data:
                        return
                    peers[source].sendall(data)


class ForwardServer(socketserver.ThreadingTCPServer):
    allow_reuse_address = True
    daemon_threads = True


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Forward one TCP listener to a loopback service."
    )
    parser.add_argument("--listen-host", default="0.0.0.0")
    parser.add_argument("--listen-port", type=int, required=True)
    parser.add_argument("--target-host", default="127.0.0.1")
    parser.add_argument("--target-port", type=int, required=True)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    for name, port in (
        ("listen port", args.listen_port),
        ("target port", args.target_port),
    ):
        if not 1 <= port <= 65535:
            raise ValueError(f"{name} must be between 1 and 65535")

    ForwardHandler.target = (args.target_host, args.target_port)
    with ForwardServer((args.listen_host, args.listen_port), ForwardHandler) as server:
        server.serve_forever()


if __name__ == "__main__":
    main()
