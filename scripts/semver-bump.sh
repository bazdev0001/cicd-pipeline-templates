#!/usr/bin/env bash
# semver-bump.sh — Bump the semantic version, create a git tag, and optionally push.
#
# Usage:
#   ./scripts/semver-bump.sh <patch|minor|major>
#
# Environment:
#   DRY_RUN=true    Print what would happen, don't create or push tags.
#   REMOTE=origin   Git remote to push to (default: origin).
#   PREFIX=v        Tag prefix (default: v).
#
# Examples:
#   ./scripts/semver-bump.sh patch          # 1.2.3 → 1.2.4
#   DRY_RUN=true ./scripts/semver-bump.sh minor   # dry run

set -euo pipefail

# ── Config ──────────────────────────────────────────────────────────────────
BUMP_TYPE="${1:-}"
DRY_RUN="${DRY_RUN:-false}"
REMOTE="${REMOTE:-origin}"
PREFIX="${PREFIX:-v}"
# ────────────────────────────────────────────────────────────────────────────

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; NC='\033[0m'

log()  { echo -e "${GREEN}[semver-bump]${NC} $*"; }
warn() { echo -e "${YELLOW}[semver-bump]${NC} $*"; }
die()  { echo -e "${RED}[semver-bump] ERROR:${NC} $*" >&2; exit 1; }

# ── Validate arguments ───────────────────────────────────────────────────────
[[ -z "$BUMP_TYPE" ]] && die "Usage: $0 <patch|minor|major>"
[[ "$BUMP_TYPE" =~ ^(patch|minor|major)$ ]] || die "Invalid bump type: $BUMP_TYPE (must be patch, minor, or major)"

# ── Ensure working tree is clean ─────────────────────────────────────────────
if [[ -n "$(git status --porcelain)" ]]; then
    die "Working tree is dirty. Commit or stash changes before bumping version."
fi

# ── Get latest tag ───────────────────────────────────────────────────────────
# Fetch all tags so we have the full picture even in shallow clones.
git fetch --tags --quiet 2>/dev/null || warn "Could not fetch tags (offline?)"

LATEST_TAG=$(git tag --list "${PREFIX}*" --sort=-version:refname | head -n 1)

if [[ -z "$LATEST_TAG" ]]; then
    warn "No existing tags found. Starting from ${PREFIX}0.0.0"
    CURRENT_VERSION="0.0.0"
else
    log "Latest tag: $LATEST_TAG"
    CURRENT_VERSION="${LATEST_TAG#"$PREFIX"}"
fi

# ── Parse semver ─────────────────────────────────────────────────────────────
IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"

if ! [[ "$MAJOR" =~ ^[0-9]+$ && "$MINOR" =~ ^[0-9]+$ && "$PATCH" =~ ^[0-9]+$ ]]; then
    die "Could not parse version from tag '$LATEST_TAG'. Expected ${PREFIX}X.Y.Z format."
fi

# ── Compute new version ───────────────────────────────────────────────────────
case "$BUMP_TYPE" in
    patch) PATCH=$(( PATCH + 1 )) ;;
    minor) MINOR=$(( MINOR + 1 )); PATCH=0 ;;
    major) MAJOR=$(( MAJOR + 1 )); MINOR=0; PATCH=0 ;;
esac

NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}"
NEW_TAG="${PREFIX}${NEW_VERSION}"

log "Bumping ${BUMP_TYPE}: ${CURRENT_VERSION} → ${NEW_VERSION}"

# ── Generate annotation message ───────────────────────────────────────────────
ANNOTATION="Release ${NEW_TAG}

Previous: ${LATEST_TAG:-none}
Date: $(date -u '+%Y-%m-%d %H:%M UTC')
Branch: $(git rev-parse --abbrev-ref HEAD)
Commit: $(git rev-parse --short HEAD)

$(git log "${LATEST_TAG}..HEAD" --pretty='- %s' 2>/dev/null | head -20 || echo '- Initial release')"

# ── Create and push tag ───────────────────────────────────────────────────────
if [[ "$DRY_RUN" == "true" ]]; then
    warn "DRY RUN — would create annotated tag: $NEW_TAG"
    echo "$ANNOTATION"
    warn "DRY RUN — would push $NEW_TAG to $REMOTE"
else
    git tag -a "$NEW_TAG" -m "$ANNOTATION"
    log "Created tag $NEW_TAG"

    git push "$REMOTE" "$NEW_TAG"
    log "Pushed $NEW_TAG to $REMOTE"

    log "Done. New version: ${GREEN}${NEW_TAG}${NC}"
fi
