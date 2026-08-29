# Build stage
FROM ubuntu:24.04 as builder

# Install Rust
RUN apt-get update && apt-get install -y curl && \
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y && \
    rm -rf /var/lib/apt/lists/*
ENV PATH="/root/.cargo/bin:${PATH}"

# Install dependencies for building
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    clang \
    pkg-config \
    libssl-dev \
    libdw-dev \
    libelf-dev \
    libudev-dev \
    lld \
    && rm -rf /var/lib/apt/lists/*

# Copy source code
COPY . /aptos-core
WORKDIR /aptos-core

# Build binaries separately to avoid feature flag conflicts
RUN cargo build --release --bin aptos --package aptos
RUN cargo build --release --bin aptos-node --package aptos-node

# Runtime stage
FROM ubuntu:24.04

RUN apt-get update && apt-get install -y \
    curl \
    libdw1 \
    libelf1 \
    libssl3 \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create validator user
RUN useradd -r -u 1001 -m -c "validator account" -d /opt/aptos/data -s /bin/bash validator

# Copy binaries from build stage
COPY --from=builder /aptos-core/target/release/aptos-node /usr/local/bin/aptos-node
COPY --from=builder /aptos-core/target/release/aptos /usr/local/bin/aptos
RUN chmod +x /usr/local/bin/aptos-node /usr/local/bin/aptos

USER validator
WORKDIR /opt/aptos/data

CMD ["/usr/local/bin/aptos-node", "-f", "/opt/aptos/etc/validator.yaml"]