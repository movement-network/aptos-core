# Justfile for Aptos Core with Nix build system

# Set the shell to bash
set shell := ["bash", "-c"]

# Default target
default: build

# ==============================================================================
# Development Shell Commands (fast iteration with cargo)
# ==============================================================================

# Build the project or a specific binary using Nix development shell (for development)
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

# Build any binary by package name (cargo-based)
build-bin package:
    @echo "Building {{package}} with Nix development shell..."
    nix develop -c cargo build --release -p {{package}}
    @echo "Binary available at target/release/{{package}}"

# ==============================================================================
# Nix Build Commands (reproducible builds with Cachix caching)
# ==============================================================================

# Build a specific binary using Nix (reproducible, cached via Cachix)
build-nix binary="aptos-node":
    #!/usr/bin/env bash
    echo "Building {{binary}} with Nix (reproducible build)..."
    echo "This build can be cached and shared via Cachix."
    echo ""
    nix build .#{{binary}} -L
    RESULT_PATH=$(readlink result)
    echo ""
    echo "Build complete!"
    echo "Binary path: $RESULT_PATH/bin/{{binary}}"
    echo ""
    echo "To run: ./result/bin/{{binary}}"

# Build all binaries using Nix (reproducible, cached via Cachix)
build-all-nix:
    #!/usr/bin/env bash
    echo "Building all binaries with Nix (reproducible build)..."
    echo "This build can be cached and shared via Cachix."
    echo ""
    nix build .#all-binaries -L
    RESULT_PATH=$(readlink result)
    echo ""
    echo "Build complete! All binaries available at:"
    echo "  $RESULT_PATH/bin/aptos-node"
    echo "  $RESULT_PATH/bin/movement"
    echo "  $RESULT_PATH/bin/l1-migration"
    echo "  $RESULT_PATH/bin/aptos-faucet-service"
    echo "  $RESULT_PATH/bin/aptos-transaction-emitter"

# ==============================================================================
# Cachix Commands (share builds with team)
# ==============================================================================

# Push a built binary to Cachix (requires auth: cachix authtoken YOUR_TOKEN)
cache-push binary="all-binaries":
    #!/usr/bin/env bash
    if ! command -v cachix &> /dev/null; then
        echo "Error: Cachix CLI not installed."
        echo "Install with: nix profile install nixpkgs#cachix"
        echo "Then authenticate: cachix authtoken YOUR_TOKEN"
        exit 1
    fi

    echo "Building and pushing {{binary}} to Cachix..."
    echo ""

    # Build first if result doesn't exist or is different target
    if [ ! -L result ] || [ "$(readlink result)" != "$(nix build .#{{binary}} --print-out-paths 2>/dev/null)" ]; then
        nix build .#{{binary}} -L
    fi

    echo ""
    echo "Pushing to Cachix..."
    cachix push movementlabs ./result

    echo ""
    echo "Done! Others can now pull this build with:"
    echo "  nix build .#{{binary}}"

# Push all binaries to Cachix
cache-push-all:
    #!/usr/bin/env bash
    if ! command -v cachix &> /dev/null; then
        echo "Error: Cachix CLI not installed."
        echo "Install with: nix profile install nixpkgs#cachix"
        echo "Then authenticate: cachix authtoken YOUR_TOKEN"
        exit 1
    fi

    echo "Building and pushing all binaries to Cachix..."
    echo "This may take a while for the initial build (~30-60 min)."
    echo ""

    nix build .#all-binaries -L

    echo ""
    echo "Pushing to Cachix..."
    cachix push movementlabs ./result

    echo ""
    echo "Done! Others can now pull these builds with:"
    echo "  nix build .#all-binaries"
    echo ""
    echo "Individual binaries are also cached:"
    echo "  nix build .#aptos-node"
    echo "  nix build .#movement"
    echo "  etc."

# Check Cachix authentication status
cache-status:
    #!/usr/bin/env bash
    echo "Cachix Status"
    echo "============="
    echo ""
    if ! command -v cachix &> /dev/null; then
        echo "Cachix CLI: NOT INSTALLED"
        echo "  Install with: nix profile install nixpkgs#cachix"
    else
        echo "Cachix CLI: $(cachix --version)"
        echo ""
        if cachix authtoken --check 2>/dev/null; then
            echo "Authentication: OK"
        else
            echo "Authentication: NOT CONFIGURED"
            echo "  Run: cachix authtoken YOUR_TOKEN"
        fi
    fi
    echo ""
    echo "Nix trusted-users:"
    nix show-config 2>/dev/null | grep trusted-users || echo "  (not configured)"
    echo ""
    echo "Cachix substituters configured:"
    nix show-config 2>/dev/null | grep -i cachix || echo "  (using flake config)"

# ==============================================================================
# Container Commands (Nix-based container builds)
# ==============================================================================

# Build a container image using Nix dockerTools (Linux only)
container-nix container="aptos-node":
    #!/usr/bin/env bash
    echo "Building container image for {{container}} with Nix..."
    echo ""
    nix build .#container-{{container}} -L
    RESULT_PATH=$(readlink result)
    echo ""
    echo "Container image built!"
    echo "Image tarball: $RESULT_PATH"
    echo ""
    echo "To load into Docker: docker load < $RESULT_PATH"
    echo "Or use: just container-load {{container}}"

# Load a Nix-built container image into Docker
container-load container="aptos-node":
    #!/usr/bin/env bash
    echo "Loading {{container}} container image into Docker..."
    IMAGE_PATH=$(nix build .#container-{{container}} --print-out-paths)
    docker load < "$IMAGE_PATH"
    echo ""
    echo "Image loaded! Available as:"
    echo "  ghcr.io/movementlabsxyz/{{container}}:nix"
    echo ""
    echo "To run: docker run ghcr.io/movementlabsxyz/{{container}}:nix"

# Push a Nix-built container image to GHCR
container-push container="aptos-node" tag="":
    #!/usr/bin/env bash
    # Default tag to git short SHA if not provided
    if [ -z "{{tag}}" ]; then
        TAG=$(git rev-parse --short HEAD)
    else
        TAG="{{tag}}"
    fi

    echo "Pushing {{container}} container to GHCR with tag: $TAG"
    echo ""

    # Build and load the image first
    IMAGE_PATH=$(nix build .#container-{{container}} --print-out-paths)
    docker load < "$IMAGE_PATH"

    # Tag for the target registry
    docker tag ghcr.io/movementlabsxyz/{{container}}:nix ghcr.io/movementlabsxyz/{{container}}:$TAG

    # Push to GHCR
    echo "Pushing to ghcr.io/movementlabsxyz/{{container}}:$TAG ..."
    docker push ghcr.io/movementlabsxyz/{{container}}:$TAG

    echo ""
    echo "Container pushed successfully!"
    echo "  ghcr.io/movementlabsxyz/{{container}}:$TAG"

# Build Docker image using traditional Dockerfile (legacy method)
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

# ==============================================================================
# Utility Commands
# ==============================================================================

# Clean build artifacts
clean:
    @echo "Cleaning build artifacts..."
    rm -rf result target

# Update flake.lock
update:
    @echo "Updating flake.lock..."
    nix flake update

# List available binary build targets
list-binaries:
    @echo ""
    @echo "================================================================================"
    @echo "                        Available Binary Build Targets"
    @echo "================================================================================"
    @echo ""
    @echo "NIX BUILD TARGETS (reproducible, cached via Cachix):"
    @echo "  just build-nix aptos-node              - Main Aptos node binary"
    @echo "  just build-nix movement                - Movement CLI (renamed from aptos)"
    @echo "  just build-nix l1-migration            - L1 migration tool"
    @echo "  just build-nix aptos-faucet-service    - Faucet service for test networks"
    @echo "  just build-nix aptos-transaction-emitter - Transaction testing tool"
    @echo "  just build-all-nix                     - Build all five binaries"
    @echo ""
    @echo "CARGO BUILD TARGETS (faster iteration, uses dev shell):"
    @echo "  just build aptos-node                  - Build with cargo (dev profile)"
    @echo "  just build aptos-node release          - Build with cargo (release profile)"
    @echo "  just build                             - Build entire workspace"
    @echo "  just build-bin <package-name>          - Build any cargo package"
    @echo ""
    @echo "CONTAINER TARGETS (Nix-based containers):"
    @echo "  just container-nix aptos-node          - Build aptos-node container"
    @echo "  just container-nix aptos-faucet-service - Build faucet container"
    @echo "  just container-load <name>             - Load container into Docker"
    @echo "  just container-push <name> [tag]       - Push container to GHCR"
    @echo ""
    @echo "CACHIX (share builds with team):"
    @echo "  just cache-push <binary>               - Build and push to Cachix"
    @echo "  just cache-push-all                    - Build and push all binaries"
    @echo "  just cache-status                      - Check Cachix setup status"
    @echo ""
    @echo "================================================================================"

# Help - list available recipes
help:
    @just --list
    @echo ""
    @echo "================================================================================"
    @echo "                              Quick Reference"
    @echo "================================================================================"
    @echo ""
    @echo "DEVELOPMENT:"
    @echo "  just dev                 - Enter Nix development shell"
    @echo "  just build               - Build all with cargo (fast iteration)"
    @echo "  just test                - Run tests"
    @echo ""
    @echo "PRODUCTION BUILDS:"
    @echo "  just build-nix <binary>  - Build single binary (reproducible, cached)"
    @echo "  just build-all-nix       - Build all binaries (reproducible, cached)"
    @echo ""
    @echo "CONTAINERS:"
    @echo "  just container-nix <name>  - Build container with Nix"
    @echo "  just container-load <name> - Load into Docker"
    @echo "  just container-push <name> - Push to GHCR"
    @echo ""
    @echo "SHARE BUILDS (Cachix):"
    @echo "  just cache-push-all        - Build all & push to cache"
    @echo "  just cache-status          - Check Cachix setup"
    @echo ""
    @echo "Use 'just list-binaries' for complete list of build targets"
    @echo "================================================================================"
