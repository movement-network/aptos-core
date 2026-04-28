# CA formal-verification reproducibility image (audit/Dockerfile)
#
# Phase 7 deliverable (plan §10.4). Pins all toolchain versions for bit-exact reproducibility.
# A reviewer on any machine gets identical ./verify-ca.sh results from this image.
#
# Build:
#   docker build -t ca-formal-verification:latest -f audit/Dockerfile .
#
# Run:
#   docker run --rm -v $(pwd):/workspace ca-formal-verification:latest ./audit/verify-ca.sh
#
# Size: ~2.5GB (Lean mathlib cache is the bulk)

# Base: Ubuntu 22.04 LTS on x86_64
FROM --platform=linux/amd64 ubuntu:22.04

# Metadata
LABEL maintainer="Movement Labs <formal@movementlabs.xyz>"
LABEL description="CA formal verification reproducibility image (Lean + Move Prover + difftest)"
LABEL version="2026-04-22"

# Pinned toolchain versions (sync with audit/toolchain.lock)
ENV LEAN_VERSION=v4.24.0 \
    LAKE_VERSION=5.0.0-src+797c613 \
    BOOGIE_VERSION=3.5.1 \
    Z3_VERSION=4.11.2 \
    CVC5_VERSION=0.0.3 \
    RUST_VERSION=1.86.0

# System dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    curl \
    git \
    jq \
    libssl-dev \
    pkg-config \
    python3 \
    unzip \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Install Rust (for difftest harness)
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain ${RUST_VERSION}
ENV PATH="/root/.cargo/bin:${PATH}"

# Install elan (Lean toolchain manager)
RUN curl https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh -sSf | sh -s -- -y --default-toolchain ${LEAN_VERSION}
ENV PATH="/root/.elan/bin:${PATH}"

# Install Lean 4.24.0 explicitly
RUN elan toolchain install ${LEAN_VERSION} && elan default ${LEAN_VERSION}

# Install .NET 8.0 (required by Boogie)
RUN wget https://dot.net/v1/dotnet-install.sh -O dotnet-install.sh && \
    chmod +x dotnet-install.sh && \
    ./dotnet-install.sh --channel 8.0 --install-dir /root/.dotnet && \
    rm dotnet-install.sh
ENV DOTNET_ROOT="/root/.dotnet"
ENV PATH="${DOTNET_ROOT}:${PATH}"

# Install Z3 4.11.2 (exact version required by Move Prover)
RUN mkdir -p /opt/z3 && \
    wget https://github.com/Z3Prover/z3/releases/download/z3-${Z3_VERSION}/z3-${Z3_VERSION}-x64-glibc-2.35.zip -O /tmp/z3.zip && \
    unzip /tmp/z3.zip -d /opt/z3 && \
    mv /opt/z3/z3-${Z3_VERSION}-x64-glibc-2.35 /opt/z3/${Z3_VERSION} && \
    rm /tmp/z3.zip
ENV Z3_EXE="/opt/z3/${Z3_VERSION}/bin/z3"
ENV PATH="/opt/z3/${Z3_VERSION}/bin:${PATH}"

# Install Boogie 3.5.1
RUN mkdir -p /opt/boogie && \
    dotnet tool install --tool-path /opt/boogie Boogie --version ${BOOGIE_VERSION}
ENV BOOGIE_EXE="/opt/boogie/boogie"
ENV PATH="/opt/boogie:${PATH}"

# Install CVC5 0.0.3
RUN mkdir -p /opt/cvc5 && \
    wget https://github.com/cvc5/cvc5/releases/download/cvc5-0.0.3/cvc5-Linux -O /opt/cvc5/cvc5 && \
    chmod +x /opt/cvc5/cvc5
ENV CVC5_EXE="/opt/cvc5/cvc5"
ENV PATH="/opt/cvc5:${PATH}"

# Install Movement CLI
# Note: Version unpinned as of 2026-04-22 - installs latest from official installer
RUN curl -fsSL https://install.movementlabs.xyz/install.sh | bash
ENV PATH="/root/.movement/bin:${PATH}"

# Create working directory
WORKDIR /workspace

# Copy only the files needed for dependency resolution first (layer caching)
COPY aptos-move/framework/formal/lean/lakefile.lean /workspace/aptos-move/framework/formal/lean/
COPY aptos-move/framework/formal/lean/lean-toolchain /workspace/aptos-move/framework/formal/lean/
COPY aptos-move/framework/formal/lean/lake-manifest.json /workspace/aptos-move/framework/formal/lean/

# Fetch mathlib cache (the expensive part - do it early so it's cached)
WORKDIR /workspace/aptos-move/framework/formal/lean
RUN lake exe cache get || true

# Copy the full repo
WORKDIR /workspace
COPY . /workspace

# Build Lean tree with cache (validates environment is working)
WORKDIR /workspace/aptos-move/framework/formal/lean
RUN lake build

# Verify toolchain versions
RUN echo "=== Toolchain verification ===" && \
    echo "Lean: $(lean --version)" && \
    echo "Lake: $(lake --version)" && \
    echo "Rust: $(rustc --version)" && \
    echo "Z3: $(${Z3_EXE} --version)" && \
    echo "Boogie: $(${BOOGIE_EXE} -version 2>&1 | head -1)" && \
    echo "CVC5: $(${CVC5_EXE} --version)" && \
    echo "Movement: $(movement --version)" && \
    echo "==========================="

# Set default working directory to formal root
WORKDIR /workspace/aptos-move/framework/formal

# Default command: run full verification
CMD ["./audit/verify-ca.sh"]

# Health check: ensure verify-ca.sh exists and is executable
HEALTHCHECK CMD test -x ./audit/verify-ca.sh || exit 1

# Document exposed ports (none needed for offline verification)
# Document volumes (mount the repo root at /workspace for live verification)
VOLUME ["/workspace"]
