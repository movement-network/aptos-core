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

## Building with Nix

We recommend using [Determinate Nix](https://determinate.systems/nix/) for reproducible builds. Determinate Nix is a validated downstream distribution of Nix with performance enhancements (parallel evaluation, lazy trees) and flakes enabled by default.

### Quick Start

```bash
# Install Determinate Nix
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install

# Restart your shell, then build
nix build .#aptos-node -L

# Or enter development shell
nix develop
```

### Why Determinate Nix?

| Feature | Standard Nix | Determinate Nix |
|---------|-------------|-----------------|
| Flakes | Experimental | **Stable** |
| Parallel evaluation | No | **Yes (2x faster)** |
| Lazy trees | No | **Yes (3x faster, 20x less disk)** |
| Native Linux builder (macOS) | Manual setup | **Built-in** |

### Troubleshooting: "public key is not valid" Error

If you encounter `error: public key is not valid` when running nix commands, this is caused by FlakeHub cache keys that Determinate Nix adds by default. To fix:

```bash
sudo nano /etc/nix/nix.conf
# Comment out or remove the line starting with: extra-trusted-public-keys = cache.flakehub.com-3:...
sudo launchctl stop org.nixos.nix-daemon && sudo launchctl start org.nixos.nix-daemon
```

For detailed setup instructions, see:
- [Nix Build Setup Guide](docs/nix-build-setup.md)
- [Binary Cache Setup Guide](docs/nix-cachix-setup.md)

## Contributing

You can learn more about contributing to the Movement project by reading our [Contribution Guide](./CONTRIBUTING.md) and by viewing our [Code of Conduct](./CODE_OF_CONDUCT.md).

Aptos Core is licensed under [Apache 2.0](./LICENSE).
