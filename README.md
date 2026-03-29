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

## Contributing

You can learn more about contributing to the Movement project by reading our [Contribution Guide](./CONTRIBUTING.md) and by viewing our [Code of Conduct](./CODE_OF_CONDUCT.md).

## Docker Buildx Bake (Alt Pipeline)

This repository includes an Aptos-Labs-style Docker Buildx/Bake pipeline under
`docker/builder/` as an alternative image build path.

- Local build (no push): `just container-bake`
- Local build for one image: `just container-bake aptos-node`
- Local build with push to GHCR:
  `INFRA_GH_USER=<user> INFRA_GH_PAT=<token> just container-bake movement-core true`

The corresponding CI workflow is `.github/workflows/docker-buildx-bake.yaml` and can be
triggered manually with target selection and optional push.

Aptos Core is licensed under [Apache 2.0](./LICENSE).
