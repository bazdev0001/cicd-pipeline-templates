#!/usr/bin/env bash
# docker-publish.sh — Build a multi-arch Docker image and push to a registry.
#
# Usage:
#   IMAGE=your-org/your-app TAG=v1.3.0 ./scripts/docker-publish.sh
#
# Environment:
#   IMAGE       Required. Image name without registry prefix (e.g. your-org/your-app)
#   TAG         Required. Image tag (e.g. v1.3.0 or sha-abc1234)
#   REGISTRY    Registry host (default: ghcr.io)
#   PLATFORMS   Comma-separated build targets (default: linux/amd64,linux/arm64)
#   DOCKERFILE  Path to Dockerfile (default: Dockerfile)
#   CONTEXT     Docker build context (default: .)
#   PUSH        Set false to build only, skip push (default: true)
#   EXTRA_TAGS  Space-separated list of additional tags to apply
#   BUILDER     Docker Buildx builder name (default: multiarch-builder)
#
# Examples:
#   # Standard push
#   IMAGE=acme/api TAG=v2.1.0 ./scripts/docker-publish.sh
#
#   # Build only, no push (local test)
#   PUSH=false IMAGE=acme/api TAG=dev ./scripts/docker-publish.sh
#
#   # Also tag as latest
#   IMAGE=acme/api TAG=v2.1.0 EXTRA_TAGS=latest ./scripts/docker-publish.sh

set -euo pipefail

# ── Validate required variables ───────────────────────────────────────────────
: "${IMAGE:?IMAGE must be set (e.g. your-org/your-app)}"
: "${TAG:?TAG must be set (e.g. v1.3.0)}"

# ── Config with defaults ──────────────────────────────────────────────────────
REGISTRY="${REGISTRY:-ghcr.io}"
PLATFORMS="${PLATFORMS:-linux/amd64,linux/arm64}"
DOCKERFILE="${DOCKERFILE:-Dockerfile}"
CONTEXT="${CONTEXT:-.}"
PUSH="${PUSH:-true}"
EXTRA_TAGS="${EXTRA_TAGS:-}"
BUILDER="${BUILDER:-multiarch-builder}"

# ── Helpers ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'
log()  { echo -e "${GREEN}[docker-publish]${NC} $*"; }
info() { echo -e "${CYAN}[docker-publish]${NC} $*"; }
die()  { echo -e "${RED}[docker-publish] ERROR:${NC} $*" >&2; exit 1; }

# ── Verify prerequisites ──────────────────────────────────────────────────────
command -v docker >/dev/null 2>&1 || die "docker is not installed"
docker buildx version >/dev/null 2>&1 || die "docker buildx is not available"
[[ -f "$DOCKERFILE" ]] || die "Dockerfile not found: $DOCKERFILE"

# ── Ensure multi-arch builder exists ─────────────────────────────────────────
if ! docker buildx inspect "$BUILDER" >/dev/null 2>&1; then
    log "Creating buildx builder: $BUILDER"
    docker buildx create --name "$BUILDER" --driver docker-container --bootstrap
fi
docker buildx use "$BUILDER"

# ── Build tag list ────────────────────────────────────────────────────────────
FULL_IMAGE="${REGISTRY}/${IMAGE}"
TAG_ARGS=(--tag "${FULL_IMAGE}:${TAG}")

for extra in $EXTRA_TAGS; do
    TAG_ARGS+=(--tag "${FULL_IMAGE}:${extra}")
    info "  Additional tag: ${FULL_IMAGE}:${extra}"
done

# ── Build args from git context (if in a repo) ────────────────────────────────
BUILD_ARGS=()
if git rev-parse --git-dir >/dev/null 2>&1; then
    GIT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
    BUILD_ARGS+=(--build-arg "VERSION=${TAG}" --build-arg "COMMIT=${GIT_COMMIT}" --build-arg "BRANCH=${GIT_BRANCH}")
    info "  Git context: commit=${GIT_COMMIT} branch=${GIT_BRANCH}"
fi

# ── Print summary ─────────────────────────────────────────────────────────────
info "Building image:"
info "  Image:      ${FULL_IMAGE}:${TAG}"
info "  Platforms:  ${PLATFORMS}"
info "  Dockerfile: ${DOCKERFILE}"
info "  Context:    ${CONTEXT}"
info "  Push:       ${PUSH}"

# ── Run build ─────────────────────────────────────────────────────────────────
PUSH_FLAG="--push"
[[ "$PUSH" == "false" ]] && PUSH_FLAG="--load"

# Note: --load does not support multi-platform; restrict to host platform for local builds
if [[ "$PUSH" == "false" ]]; then
    PLATFORMS=$(docker info --format '{{.Architecture}}' 2>/dev/null | sed 's/x86_64/linux\/amd64/;s/aarch64/linux\/arm64/')
    info "  Local build only — restricting to host platform: ${PLATFORMS}"
fi

docker buildx build \
    --platform "${PLATFORMS}" \
    --file "${DOCKERFILE}" \
    "${TAG_ARGS[@]}" \
    "${BUILD_ARGS[@]}" \
    --cache-from "type=registry,ref=${FULL_IMAGE}:buildcache" \
    --cache-to   "type=registry,ref=${FULL_IMAGE}:buildcache,mode=max" \
    --provenance=true \
    --sbom=true \
    ${PUSH_FLAG} \
    "${CONTEXT}"

log "Build complete: ${FULL_IMAGE}:${TAG}"

# ── Print image digest (for reproducible deployments) ────────────────────────
if [[ "$PUSH" != "false" ]]; then
    DIGEST=$(docker buildx imagetools inspect "${FULL_IMAGE}:${TAG}" --format '{{.Manifest.Digest}}' 2>/dev/null || echo "unavailable")
    info "  Digest: ${DIGEST}"
    echo ""
    echo "Pin this digest in your deployment:"
    echo "  ${FULL_IMAGE}@${DIGEST}"
fi
