#!/bin/bash
# parse-version.sh - Parse semantic version from git tag or branch
# Usage: ./scripts/parse-version.sh [ref]
# Output: MAJOR.MINOR.PATCH

set -euo pipefail

REF="${1:-$(git describe --tags --always --abbrev=7 2>/dev/null || echo '0.0.0')}"

# Remove 'v' prefix if present
REF="${REF#v}"

# Check if it's a semver tag
if [[ "$REF" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
    MAJOR="${BASH_REMATCH[1]}"
    MINOR="${BASH_REMATCH[2]}"
    PATCH="${BASH_REMATCH[3]}"
    echo "$REF"
    exit 0
fi

# If not a semver tag, return the git SHA
echo "0.0.0-dev-$(git rev-parse --short HEAD)"
