# Docker Buildx Bake definition for rust image builds.
# Modeled after Aptos Labs' bake-driven image pipeline and adapted for GHCR.

variable "CI" {
  default = "false"
}

variable "TARGET_CACHE_ID" {
  default = "local"
}

variable "BUILD_DATE" {
  default = ""
}

variable "GIT_SHA" {
  default = "dev"
}

variable "GIT_BRANCH" {
  default = "unknown"
}

variable "GIT_TAG" {
  default = "none"
}

variable "GIT_CREDENTIALS" {
  default = ""
}

variable "BUILT_VIA_BUILDKIT" {
  default = "true"
}

variable "GHCR_DOCKER_ARTIFACT_REPO" {
  default = "ghcr.io/movementlabsxyz"
}

variable "TARGET_REGISTRY" {
  # Supported: "local" | "ghcr"
  default = CI == "true" ? "ghcr" : "local"
}

variable "NORMALIZED_GIT_BRANCH_OR_PR" {
  default = "local"
}

variable "IMAGE_TAG_PREFIX" {
  default = ""
}

variable "PROFILE" {
  default = "release"
}

variable "FEATURES" {
  default = ""
}

variable "CARGO_TARGET_DIR" {
  default = "target/default"
}

variable "CARGO_BUILD_JOBS" {
  default = "2"
}

group "all" {
  targets = flatten([
    "validator",
    "node-checker",
    "tools",
    "faucet",
    "forge",
    "telemetry-service",
    "keyless-pepper-service",
    "indexer-grpc",
    "validator-testing",
    "nft-metadata-crawler",
  ])
}

group "forge-images" {
  targets = ["validator-testing", "tools", "forge"]
}

# Minimal Movement-focused group for the alternate pipeline rollout.
group "movement-core" {
  targets = ["aptos-node", "aptos-faucet-service"]
}

target "debian-base" {
  dockerfile = "docker/builder/debian-base.Dockerfile"
  contexts = {
    # Run `docker buildx imagetools inspect debian:bullseye` to refresh this digest.
    debian = "docker-image://debian:bullseye@sha256:cf48c31af360e1c0a0aedd33aae4d928b68c2cdf093f1612650eb1ff434d1c34"
  }
}

target "builder-base" {
  dockerfile = "docker/builder/builder.Dockerfile"
  target     = "builder-base"
  context    = "."
  contexts = {
    # Run `docker buildx imagetools inspect rust:1.80.1-bullseye` to refresh this digest.
    rust = "docker-image://rust:1.80.1-bullseye@sha256:f6f599d3f027a97fb60cb87854199fcde390e25cee216712c3f9eede545b052e"
  }
  args = {
    PROFILE            = "${PROFILE}"
    FEATURES           = "${FEATURES}"
    CARGO_TARGET_DIR   = "${CARGO_TARGET_DIR}"
    CARGO_BUILD_JOBS   = "${CARGO_BUILD_JOBS}"
    BUILT_VIA_BUILDKIT = "true"
  }
  secret = [
    "id=GIT_CREDENTIALS,env=GIT_CREDENTIALS"
  ]
}

target "aptos-node-builder" {
  dockerfile = "docker/builder/builder.Dockerfile"
  target     = "aptos-node-builder"
  contexts = {
    builder-base = "target:builder-base"
  }
  secret = [
    "id=GIT_CREDENTIALS,env=GIT_CREDENTIALS"
  ]
}

target "tools-builder" {
  dockerfile = "docker/builder/builder.Dockerfile"
  target     = "tools-builder"
  contexts = {
    builder-base = "target:builder-base"
  }
  secret = [
    "id=GIT_CREDENTIALS,env=GIT_CREDENTIALS"
  ]
}

target "indexer-builder" {
  dockerfile = "docker/builder/builder.Dockerfile"
  target     = "indexer-builder"
  contexts = {
    builder-base = "target:builder-base"
  }
  secret = [
    "id=GIT_CREDENTIALS,env=GIT_CREDENTIALS"
  ]
}

target "_common" {
  contexts = {
    debian-base     = "target:debian-base"
    node-builder    = "target:aptos-node-builder"
    tools-builder   = "target:tools-builder"
    indexer-builder = "target:indexer-builder"
  }
  labels = {
    "org.label-schema.schema-version" = "1.0",
    "org.label-schema.build-date"     = "${BUILD_DATE}"
    "org.label-schema.git-sha"        = "${GIT_SHA}"
  }
  args = {
    PROFILE    = "${PROFILE}"
    FEATURES   = "${FEATURES}"
    GIT_SHA    = "${GIT_SHA}"
    GIT_BRANCH = "${GIT_BRANCH}"
    GIT_TAG    = "${GIT_TAG}"
    BUILD_DATE = "${BUILD_DATE}"
  }
  output     = ["type=image,compression=zstd,force-compression=true"]
  cache-from = generate_cache_from("shared")
  cache-to   = generate_cache_to("shared")
}

target "validator-testing" {
  inherits   = ["_common"]
  dockerfile = "docker/builder/validator-testing.Dockerfile"
  target     = "validator-testing"
  tags       = generate_tags("validator-testing")
}

target "validator" {
  inherits   = ["_common"]
  dockerfile = "docker/builder/validator.Dockerfile"
  target     = "validator"
  tags       = generate_tags("validator")
}

# Alias for existing external naming conventions in movement repos.
target "aptos-node" {
  inherits   = ["_common"]
  dockerfile = "docker/builder/validator.Dockerfile"
  target     = "validator"
  tags       = generate_tags("aptos-node")
}

target "tools" {
  inherits   = ["_common"]
  dockerfile = "docker/builder/tools.Dockerfile"
  target     = "tools"
  tags       = generate_tags("tools")
}

target "forge" {
  inherits   = ["_common"]
  dockerfile = "docker/builder/forge.Dockerfile"
  target     = "forge"
  tags       = generate_tags("forge")
}

target "node-checker" {
  inherits   = ["_common"]
  dockerfile = "docker/builder/node-checker.Dockerfile"
  target     = "node-checker"
  tags       = generate_tags("node-checker")
}

target "faucet" {
  inherits   = ["_common"]
  dockerfile = "docker/builder/faucet.Dockerfile"
  target     = "faucet"
  tags       = generate_tags("faucet")
}

# Alias for existing external naming conventions in movement repos.
target "aptos-faucet-service" {
  inherits   = ["_common"]
  dockerfile = "docker/builder/faucet.Dockerfile"
  target     = "faucet"
  tags       = generate_tags("aptos-faucet-service")
}

target "telemetry-service" {
  inherits   = ["_common"]
  dockerfile = "docker/builder/telemetry-service.Dockerfile"
  target     = "telemetry-service"
  tags       = generate_tags("telemetry-service")
}

target "keyless-pepper-service" {
  inherits   = ["_common"]
  dockerfile = "docker/builder/keyless-pepper-service.Dockerfile"
  target     = "keyless-pepper-service"
  tags       = generate_tags("keyless-pepper-service")
}

target "indexer-grpc" {
  inherits   = ["_common"]
  dockerfile = "docker/builder/indexer-grpc.Dockerfile"
  target     = "indexer-grpc"
  tags       = generate_tags("indexer-grpc")
}

target "nft-metadata-crawler" {
  inherits   = ["_common"]
  dockerfile = "docker/builder/nft-metadata-crawler.Dockerfile"
  target     = "nft-metadata-crawler"
  tags       = generate_tags("nft-metadata-crawler")
}

function "generate_tags" {
  params = [target]
  result = TARGET_REGISTRY == "ghcr" ? [
    "${GHCR_DOCKER_ARTIFACT_REPO}/${target}:${IMAGE_TAG_PREFIX}${GIT_SHA}",
    "${GHCR_DOCKER_ARTIFACT_REPO}/${target}:${IMAGE_TAG_PREFIX}${NORMALIZED_GIT_BRANCH_OR_PR}",
    ] : [
      "aptos-core/${target}:${IMAGE_TAG_PREFIX}${GIT_SHA}-from-local",
      "aptos-core/${target}:${IMAGE_TAG_PREFIX}from-local",
  ]
}

function "generate_cache_from" {
  params = [scope]
  result = CI == "true" ? ["type=gha,scope=${scope}-${TARGET_CACHE_ID}"] : []
}

function "generate_cache_to" {
  params = [scope]
  result = CI == "true" ? ["type=gha,scope=${scope}-${TARGET_CACHE_ID},mode=max"] : []
}
