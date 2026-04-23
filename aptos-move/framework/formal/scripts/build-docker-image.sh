#!/usr/bin/env bash
# build-docker-image.sh — Build CA formal verification Docker image
#
# Usage:
#   ./scripts/build-docker-image.sh [--tag TAG] [--push] [--no-cache]
#
# Options:
#   --tag TAG      Tag to apply (default: latest + date)
#   --push         Push to registry after building
#   --no-cache     Build without using cache
#
# Examples:
#   ./scripts/build-docker-image.sh
#   ./scripts/build-docker-image.sh --tag v1.0.0 --push
#   ./scripts/build-docker-image.sh --no-cache

set -euo pipefail

# Configuration
IMAGE_NAME="${IMAGE_NAME:-ca-formal-verification}"
REGISTRY="${REGISTRY:-ghcr.io}"
NAMESPACE="${NAMESPACE:-movementlabs}"
DOCKERFILE="audit/Dockerfile"
BUILD_CONTEXT="../.."  # Repository root from formal/

# Parse arguments
TAG="latest"
PUSH=false
NO_CACHE=""
PLATFORM="linux/amd64"

while [[ $# -gt 0 ]]; do
    case $1 in
        --tag)
            TAG="$2"
            shift 2
            ;;
        --push)
            PUSH=true
            shift
            ;;
        --no-cache)
            NO_CACHE="--no-cache"
            shift
            ;;
        --platform)
            PLATFORM="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

# Derived tags
DATE_TAG=$(date +%Y%m%d)
GIT_TAG=$(git describe --tags --always --dirty 2>/dev/null || echo "unknown")
FULL_IMAGE_NAME="${REGISTRY}/${NAMESPACE}/${IMAGE_NAME}"

echo "========================================"
echo "Building CA Formal Verification Image"
echo "========================================"
echo "Image:    ${FULL_IMAGE_NAME}"
echo "Tag:      ${TAG}"
echo "Platform: ${PLATFORM}"
echo "Date:     ${DATE_TAG}"
echo "Git:      ${GIT_TAG}"
echo "========================================"

# Check prerequisites
if ! command -v docker &> /dev/null; then
    echo "Error: docker not found. Please install Docker." >&2
    exit 1
fi

if [[ ! -f "$DOCKERFILE" ]]; then
    echo "Error: Dockerfile not found at $DOCKERFILE" >&2
    echo "Run this script from aptos-move/framework/formal/" >&2
    exit 1
fi

# Start build
echo "Starting build..."
start_time=$(date +%s)

docker build \
    --platform "$PLATFORM" \
    $NO_CACHE \
    -t "${IMAGE_NAME}:${TAG}" \
    -t "${IMAGE_NAME}:${DATE_TAG}" \
    -t "${IMAGE_NAME}:${GIT_TAG}" \
    -f "$DOCKERFILE" \
    "$BUILD_CONTEXT"

end_time=$(date +%s)
duration=$((end_time - start_time))

echo ""
echo "✅ Build completed in ${duration}s"
echo ""
echo "Local tags:"
echo "  - ${IMAGE_NAME}:${TAG}"
echo "  - ${IMAGE_NAME}:${DATE_TAG}"
echo "  - ${IMAGE_NAME}:${GIT_TAG}"

# Tag for registry
docker tag "${IMAGE_NAME}:${TAG}" "${FULL_IMAGE_NAME}:${TAG}"
docker tag "${IMAGE_NAME}:${TAG}" "${FULL_IMAGE_NAME}:${DATE_TAG}"
docker tag "${IMAGE_NAME}:${TAG}" "${FULL_IMAGE_NAME}:${GIT_TAG}"

echo ""
echo "Registry tags:"
echo "  - ${FULL_IMAGE_NAME}:${TAG}"
echo "  - ${FULL_IMAGE_NAME}:${DATE_TAG}"
echo "  - ${FULL_IMAGE_NAME}:${GIT_TAG}"

# Push if requested
if [[ "$PUSH" == "true" ]]; then
    echo ""
    echo "Pushing to registry..."

    docker push "${FULL_IMAGE_NAME}:${TAG}"
    docker push "${FULL_IMAGE_NAME}:${DATE_TAG}"
    docker push "${FULL_IMAGE_NAME}:${GIT_TAG}"

    echo ""
    echo "✅ Pushed to ${REGISTRY}/${NAMESPACE}/${IMAGE_NAME}"
fi

# Display usage instructions
echo ""
echo "========================================"
echo "Next Steps"
echo "========================================"
echo ""
echo "Test the image:"
echo "  docker run --rm ${IMAGE_NAME}:${TAG} lean --version"
echo ""
echo "Run verification:"
echo "  docker run --rm -v \$(pwd):/workspace -w /workspace \\"
echo "    ${IMAGE_NAME}:${TAG} ./audit/verify-ca.sh"
echo ""
echo "Push to registry:"
echo "  ./scripts/build-docker-image.sh --tag ${TAG} --push"
echo ""
