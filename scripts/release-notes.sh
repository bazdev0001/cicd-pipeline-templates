#!/usr/bin/env bash
# release-notes.sh — Generate release notes from conventional commits.
#
# Reads git log between two refs (defaults to latest tag → HEAD) and groups
# commits by Conventional Commits type: feat, fix, perf, chore, docs, etc.
#
# Usage:
#   ./scripts/release-notes.sh                   # since last tag to HEAD
#   ./scripts/release-notes.sh v1.2.0 v1.3.0    # between two specific tags
#   ./scripts/release-notes.sh > RELEASE_NOTES.md
#
# Conventional Commits spec: https://www.conventionalcommits.org

set -euo pipefail

# ── Arguments ─────────────────────────────────────────────────────────────────
FROM_REF="${1:-}"
TO_REF="${2:-HEAD}"

# Auto-detect FROM_REF if not provided
if [[ -z "$FROM_REF" ]]; then
    FROM_REF=$(git tag --list 'v*' --sort=-version:refname | head -n 1)
    if [[ -z "$FROM_REF" ]]; then
        # No tags — include all commits
        FROM_REF=$(git rev-list --max-parents=0 HEAD)
    fi
fi

# ── Collect commits ───────────────────────────────────────────────────────────
# Format: <hash> <subject>
mapfile -t COMMITS < <(git log "${FROM_REF}..${TO_REF}" --pretty='%h %s' --no-merges)

if [[ ${#COMMITS[@]} -eq 0 ]]; then
    echo "No commits found between ${FROM_REF} and ${TO_REF}." >&2
    exit 0
fi

# ── Categorise commits ────────────────────────────────────────────────────────
declare -a BREAKING FEATURES FIXES PERF REFACTOR DOCS CHORES OTHER

for commit in "${COMMITS[@]}"; do
    hash="${commit%% *}"
    subject="${commit#* }"

    # Detect breaking changes: trailing ! or BREAKING CHANGE in footer
    # We check body too but for notes we use subject only
    if [[ "$subject" =~ ^[a-z]+(\(.+\))?!: ]]; then
        BREAKING+=("$subject (#${hash})")
        continue
    fi

    type="${subject%%(*}"   # grab everything before first ( or :
    type="${type%%:*}"
    type=$(echo "$type" | tr '[:upper:]' '[:lower:]' | xargs)

    case "$type" in
        feat|feature)     FEATURES+=("$subject (#${hash})") ;;
        fix|bugfix)       FIXES+=("$subject (#${hash})") ;;
        perf|performance) PERF+=("$subject (#${hash})") ;;
        refactor)         REFACTOR+=("$subject (#${hash})") ;;
        docs|doc)         DOCS+=("$subject (#${hash})") ;;
        chore|build|ci|cd|deps|test) CHORES+=("$subject (#${hash})") ;;
        *)                OTHER+=("$subject (#${hash})") ;;
    esac
done

# ── Render output ─────────────────────────────────────────────────────────────
echo "## What's Changed"
echo ""
echo "> Generated from \`${FROM_REF}..${TO_REF}\` on $(date -u '+%Y-%m-%d %H:%M UTC')"
echo ""

print_section() {
    local title="$1"
    shift
    local -n items="$1"
    if [[ ${#items[@]} -gt 0 ]]; then
        echo "### ${title}"
        for item in "${items[@]}"; do
            # Strip conventional-commit prefix for readability
            clean="${item#*: }"
            echo "- ${clean}"
        done
        echo ""
    fi
}

if [[ ${#BREAKING[@]} -gt 0 ]]; then
    echo "### ⚠ Breaking Changes"
    for item in "${BREAKING[@]}"; do
        clean="${item#*!: }"
        echo "- **BREAKING:** ${clean}"
    done
    echo ""
fi

print_section "Features"     FEATURES
print_section "Bug Fixes"    FIXES
print_section "Performance"  PERF
print_section "Refactoring"  REFACTOR
print_section "Documentation" DOCS

if [[ ${#OTHER[@]} -gt 0 ]]; then
    print_section "Other Changes" OTHER
fi

# Always print chores last and only if not empty
if [[ ${#CHORES[@]} -gt 0 ]]; then
    echo "<details>"
    echo "<summary>Maintenance</summary>"
    echo ""
    for item in "${CHORES[@]}"; do
        clean="${item#*: }"
        echo "- ${clean}"
    done
    echo ""
    echo "</details>"
fi

echo ""
echo "**Full changelog:** \`git log ${FROM_REF}..${TO_REF}\`"
