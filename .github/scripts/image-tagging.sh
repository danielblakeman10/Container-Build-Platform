#!/bin/bash
# image-tagging.sh - Generate Docker image tags based on version and commit
# Usage: ./scripts/image-tagging.sh <image-name> [tag-type]
# tag-types: latest, semver, sha, timestamp

set -euo pipefail

IMAGE_NAME="${1:-myapp}"
TAG_TYPE="${2:-all}"
SHA=$(git rev-parse --short HEAD)
DATE=$(date +%Y%m%d)
VERSION=$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || echo "0.0.0")

echo "📦 Generating image tags for: $IMAGE_NAME"
echo "   Commit SHA: $SHA"
echo "   Date: $DATE"
echo "   Version: $VERSION"
echo ""

tags=()

case "$TAG_TYPE" in
    all)
        tags+=("$IMAGE_NAME:latest")
        tags+=("$IMAGE_NAME:$VERSION")
        tags+=("$IMAGE_NAME:${VERSION%.*}")   # MAJOR.MINOR
        tags+=("$IMAGE_NAME:${VERSION%%.*}")  # MAJOR
        tags+=("$IMAGE_NAME:$SHA")
        tags+=("$IMAGE_NAME:${DATE}-${SHA}")
        ;;
    latest)
        tags+=("$IMAGE_NAME:latest")
        ;;
    semver)
        tags+=("$IMAGE_NAME:$VERSION")
        tags+=("$IMAGE_NAME:${VERSION%.*}")   # MAJOR.MINOR
        tags+=("$IMAGE_NAME:${VERSION%%.*}")  # MAJOR
        ;;
    sha)
        tags+=("$IMAGE_NAME:$SHA")
        ;;
    timestamp)
        tags+=("$IMAGE_NAME:${DATE}-${SHA}")
        ;;
esac

echo "✅ Generated tags:"
for tag in "${tags[@]}"; do
    echo "   - $tag"
done

# If called with --push, push all tags
if [ "${3:-}" == "--push" ]; then
    for tag in "${tags[@]}"; do
        echo "   Pushing: $tag"
    done
fi
