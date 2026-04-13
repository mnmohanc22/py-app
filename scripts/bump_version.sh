#!/bin/bash
# scripts/bump_version.sh
# Usage:
#   bash scripts/bump_version.sh patch    → 1.4.1 → 1.4.2
#   bash scripts/bump_version.sh minor    → 1.4.2 → 1.5.0
#   bash scripts/bump_version.sh major    → 1.4.2 → 2.0.0

set -e

BUMP_TYPE=${1:-patch}
CURRENT=$(cat VERSION)

IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT"

case "$BUMP_TYPE" in
    major)
        MAJOR=$((MAJOR + 1))
        MINOR=0
        PATCH=0
        ;;
    minor)
        MINOR=$((MINOR + 1))
        PATCH=0
        ;;
    patch)
        PATCH=$((PATCH + 1))
        ;;
    *)
        echo "Usage: $0 [major|minor|patch]"
        exit 1
        ;;
esac

NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}"

echo "Bumping version: ${CURRENT} → ${NEW_VERSION}"

# Update VERSION file
echo "$NEW_VERSION" > VERSION

# Update CHANGELOG — move [Unreleased] to new version
DATE=$(date +%Y-%m-%d)
sed -i "s/## \[Unreleased\]/## [Unreleased]\n\n## [${NEW_VERSION}] — ${DATE}/" CHANGELOG.md

# Commit and tag
git add VERSION CHANGELOG.md
git commit -m "chore: bump version to ${NEW_VERSION}"
git tag -a "v${NEW_VERSION}" -m "Release v${NEW_VERSION}"

echo "Version bumped to ${NEW_VERSION}"
echo "Run: git push origin main --tags"