<div align="center" style="display: flex; justify-content: center; align-items: center; gap: 20px;">
	<img src="./.assets/movement.png" alt="Movement" style="width: 300px;" />
	<img src="./.assets/movement_logo.png" alt="Movement Logo" style="width: 50px;" />
</div>

---

[![License](https://img.shields.io/badge/license-Apache-green.svg)](LICENSE)

Movement is a layer 1 blockchain bringing a paradigm shift to Web3 through better technology and user experience. Built with Move to create a home for developers building next-gen applications.

## Getting Started

* [Movement Foundation](https://www.movementnetwork.xyz/)
* [Move Industries](https://www.moveindustries.xyz/)
* [Movement Explorer](https://explorer.movementnetwork.xyz/?network=mainnet)
* [Movement Documentation](https://docs.movementnetwork.xyz/general)
* [Guide (Aptos)](https://aptos.dev/guides/system-integrators-guide)
* [Tutorials (Aptos)](https://aptos.dev/tutorials)
* Follow us on [Twitter](https://x.com/MoveIndFDN).
* Join us on the [Movement Discord](https://discord.com/invite/moveindustries).

## Nix Build System

This project uses [Nix](https://nixos.org/) for reproducible builds. All binaries (`aptos-node`, `movement`, `l1-migration`) can be built with a single command.

### Prerequisites

#### Install Nix

Install Nix using the [Determinate Systems installer](https://determinate.systems/nix/macos/overview/):

```bash
just install-nix
# or manually:
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

#### Install 1Password CLI (for Cachix push access)

The [1Password CLI](https://developer.1password.com/docs/cli/get-started/) (`op`) is used to securely fetch the Cachix auth token from the `team-move-dev` vault.

```bash
just install-op
# or manually on macOS:
brew install --cask 1password-cli
```

After installing, sign in:

```bash
op signin
```

#### Setup Cachix (binary cache)

Pre-built binaries are shared via [Cachix](https://app.cachix.org/cache/movement-m1) (`movement-m1`). To configure push access:

```bash
just setup-cachix
```

This fetches `CACHIX_AUTH_TOKEN` from 1Password (`team-move-dev` vault) and configures cachix.

To pull from the cache (no auth needed):

```bash
cachix use movement-m1
```

### Build

```bash
# Build all binaries
nix build .#all-binaries -L

# Build individual binaries
nix build .#aptos-node
nix build .#movement
nix build .#l1-migration

# Enter development shell (cargo builds)
nix develop
```

### Push to Cache

```bash
just setup-cachix       # One-time setup
just cache-push-all     # Build and push all binaries
just cache-push aptos-node  # Push a single binary
just cache-status       # Check setup status
```

### Docker

Build a Linux container using Docker buildx (works on macOS/Apple Silicon):

```bash
just container-buildx aptos-node
```

### More Commands

```bash
just help              # List all available commands
just list-binaries     # List all build targets
```

## Contributing

You can learn more about contributing to the Movement project by reading our [Contribution Guide](./CONTRIBUTING.md) and by viewing our [Code of Conduct](./CODE_OF_CONDUCT.md).

Aptos Core is licensed under [Apache 2.0](./LICENSE).
