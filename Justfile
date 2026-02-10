# Justfile for Aptos Core with Nix build system

# Set the shell to bash
set shell := ["bash", "-c"]

# Default target
default: build

# Build the project or a specific binary using Nix development shell
build binary="all" profile="dev":
    #!/usr/bin/env bash
    if [ "{{profile}}" != "release" ]; then
        PROFILE_ARG="--profile {{profile}}"
    else
        PROFILE_ARG="--release"
    fi
    echo "Using profile: $PROFILE_ARG"
    if [ "{{binary}}" = "all" ]; then
        echo "Building Aptos Core with Nix development shell..."
        nix --extra-experimental-features "nix-command flakes" develop -c cargo build $PROFILE_ARG
    else
        echo "Building {{binary}} with Nix development shell..."
        nix --extra-experimental-features "nix-command flakes" develop -c cargo build $PROFILE_ARG -p {{binary}}
        echo "Binary available at target/release/{{binary}}"
    fi

# Enter the development environment
dev:
    @echo "Entering development environment..."
    nix --extra-experimental-features "nix-command flakes" develop

# Run tests
test:
    @echo "Running tests..."
    nix --extra-experimental-features "nix-command flakes" develop -c cargo test

# Check code formatting
fmt:
    @echo "Checking code formatting..."
    nix --extra-experimental-features "nix-command flakes" develop -c cargo fmt -- --check

# Run clippy
clippy:
    @echo "Running clippy..."
    nix --extra-experimental-features "nix-command flakes" develop -c cargo clippy -- --deny warnings

# Clean build artifacts
clean:
    @echo "Cleaning build artifacts..."
    rm -rf result target

# Update flake.lock
update:
    @echo "Updating flake.lock..."
    nix flake update

# Build Docker image
container-build container="aptos-node" tag="latest" profile="release":
    #!/usr/bin/env bash
    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        echo "Error: Docker is not installed. Please install Docker to build the image."
        exit 1
    fi

    # Check if Docker Buildx is available
    if ! docker buildx version &> /dev/null; then
        echo "Error: Docker Buildx is not available. Please install Docker Buildx."
        echo "You can typically install it by updating Docker Desktop or installing the buildx plugin."
        exit 1
    fi

    # Validate the docker folder exists
    if [ ! -d "docker/{{container}}" ]; then
        echo "Error: Docker folder 'docker/{{container}}' does not exist."
        exit 1
    fi

    # Build the binary first
    echo "Building {{container}}..."
    # Case for docker containers that need multiple binaries
    case "{{container}}" in
        "aptos-node")
            just build aptos-node {{profile}}
            just build aptos {{profile}}
            just build l1-migration {{profile}}
            ;;
        "aptos-faucet-service")
            just build aptos-faucet-service {{profile}}
            ;;
        *)
            just build {{container}} {{profile}}
            ;;
    esac
    

    # Set binary path based on profile
    if [ "{{profile}}" = "release" ]; then
        BINARY_PATH="target/release"
    elif [ "{{profile}}" = "dev" ]; then
        BINARY_PATH="target/debug"
    else
        BINARY_PATH="target/{{profile}}"
    fi
    
    echo "Building Docker image for '{{container}}' using binary at $BINARY_PATH..."
    docker build \
        --build-arg BINARY_PATH="$BINARY_PATH" \
        -f docker/{{container}}/Dockerfile \
        -t ghcr.io/movementlabsxyz/{{container}}:{{tag}} .
    
    # Clean up the copied binary
    rm -f aptos-test

# Build any binary by package name
build-bin package:
    @echo "Building {{package}} with Nix development shell..."
    nix develop -c cargo build --release -p {{package}}
    @echo "Binary available at target/release/{{package}}"

# Build images using Aptos-Labs-style Docker Buildx Bake pipeline
# Examples:
#   just container-bake
#   just container-bake aptos-node
#   just container-bake movement-core true
container-bake target="movement-core" push="false":
    #!/usr/bin/env bash
    set -euo pipefail

    if ! command -v docker &> /dev/null; then
        echo "Error: Docker is not installed."
        exit 1
    fi

    if ! docker buildx version &> /dev/null; then
        echo "Error: Docker Buildx is not available."
        exit 1
    fi

    if [ "{{push}}" = "true" ] && [ -z "${INFRA_GH_PAT:-}" ]; then
        echo "Error: push=true requires INFRA_GH_PAT and INFRA_GH_USER env vars."
        echo "Example: INFRA_GH_USER=<user> INFRA_GH_PAT=<token> just container-bake {{target}} true"
        exit 1
    fi

    if [ "{{push}}" = "true" ]; then
        echo "$INFRA_GH_PAT" | docker login ghcr.io -u "$INFRA_GH_USER" --password-stdin
        TARGET_REGISTRY="ghcr"
    else
        TARGET_REGISTRY="local"
    fi

    export CI=true
    export TARGET_CACHE_ID="local-$(git rev-parse --short HEAD)-$(uname -m)"
    export TARGET_REGISTRY
    export PUSH_IMAGES="{{push}}"
    export GHCR_DOCKER_ARTIFACT_REPO="ghcr.io/movementlabsxyz"
    export CUSTOM_IMAGE_TAG_PREFIX="$(uname -m)"
    export GIT_CREDENTIALS="${GIT_CREDENTIALS:-}"

    chmod +x docker/builder/docker-bake-rust-all.sh
    docker/builder/docker-bake-rust-all.sh "{{target}}"

# List available binary build targets
list-binaries:
    @echo "Available binary build targets:"
    @echo "  Generic: just build <binary-name>"
    @echo "  Common binaries:"
    @echo "    aptos-node          - Main Aptos node"
    @echo "    aptos               - Aptos CLI tool"
    @echo "    aptos-debugger      - Debugging tool"
    @echo "    aptos-backup-cli    - Backup CLI tool"
    @echo "    aptos-keygen        - Key generation tool"
    @echo "    transaction-emitter - Transaction emitter"
    @echo "    aptos-node-checker  - Node checker tool"
    @echo ""
    @echo "Use 'just build' to build all packages"
    @echo "Use 'just build-bin <package-name>' for custom package builds"

# Help - list available recipes
help:
    @just --list
    @echo ""
    @echo "Binary Build Options:"
    @echo "  Use 'just list-binaries' to see available binary build targets"
    @echo "  Use 'just build <binary-name>' for common binary builds"
    @echo "  Use 'just build' to build all packages"
    @echo "  Use 'just build-bin <package-name>' for custom package builds"
    @echo ""
    @echo "Docker Bake Options:"
    @echo "  Use 'just container-bake' to build movement-core images with buildx bake"
    @echo "  Use 'just container-bake aptos-node' to build only aptos-node image"
    @echo "  Use 'just container-bake movement-core true' to push images to GHCR"
