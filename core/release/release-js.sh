#!/bin/bash
set -euo pipefail

# Publish the JS SDK to npm.
#
# Usage:
#   bash core/release/release-js.sh [version]
#
# If version is omitted, reads from the VERSION file.
#
# Required environment variables:
#   NPM_TOKEN — npm authentication token with publish access

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CORE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_DIR="$(cd "$CORE_DIR/.." && pwd)"
SDK_DIR="$REPO_DIR/sdks/js"

VERSION="${1:-$(cat "$REPO_DIR/VERSION" | tr -d '[:space:]')}"
echo "Publishing @atheon/verity@$VERSION to npm"

if [ -z "${NPM_TOKEN:-}" ]; then
    echo "ERROR: NPM_TOKEN is not set"
    exit 1
fi

cd "$SDK_DIR"

# Update version in package.json
npm version "$VERSION" --no-git-tag-version --allow-same-version

# Install and build
npm ci
npm run build

# Publish
echo "//registry.npmjs.org/:_authToken=\${NPM_TOKEN}" > .npmrc
npm publish --access public
rm -f .npmrc

echo "Published @atheon/verity@$VERSION"
