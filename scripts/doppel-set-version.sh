#!/usr/bin/env bash
#
# Set the Doppel fork version across all crates.
#
# Usage:
#   ./scripts/doppel-set-version.sh 0.12.0     # sets 0.12.0-doppel everywhere
#   ./scripts/doppel-set-version.sh 0.12.0-doppel  # also works (keeps suffix as-is)
#
# What it updates:
#   - Cargo.toml           (workspace uv-version dep)
#   - crates/uv/Cargo.toml
#   - crates/uv-build/Cargo.toml
#   - crates/uv-version/Cargo.toml
#   - Cargo.lock           (via cargo update)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <version>"
    echo "  e.g. $0 0.12.0        → sets 0.12.0-doppel"
    echo "  e.g. $0 0.12.0-doppel → sets 0.12.0-doppel"
    exit 1
fi

INPUT="$1"

# Append -doppel if not already present
if [[ "$INPUT" == *-doppel ]]; then
    VERSION="$INPUT"
else
    VERSION="${INPUT}-doppel"
fi

# Extract the base version (without -doppel) for validation
BASE="${VERSION%-doppel}"
if ! [[ "$BASE" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "ERROR: '$BASE' is not a valid semver (expected X.Y.Z)" >&2
    exit 1
fi

echo "Setting version to: $VERSION (base: $BASE)"

# Files to update
CRATE_FILES=(
    "$REPO_ROOT/crates/uv/Cargo.toml"
    "$REPO_ROOT/crates/uv-build/Cargo.toml"
    "$REPO_ROOT/crates/uv-version/Cargo.toml"
)
WORKSPACE_FILE="$REPO_ROOT/Cargo.toml"

# Update crate versions: version = "X.Y.Z..." → version = "X.Y.Z-doppel"
for file in "${CRATE_FILES[@]}"; do
    if [[ ! -f "$file" ]]; then
        echo "WARNING: $file not found, skipping" >&2
        continue
    fi
    # Only replace the top-level version field (first occurrence of ^version = "...")
    if [[ "$(uname)" == "Darwin" ]]; then
        sed -i '' "s/^version = \"[0-9][0-9.]*\(-doppel\)\{0,1\}\"/version = \"${VERSION}\"/" "$file"
    else
        sed -i "s/^version = \"[0-9][0-9.]*\(-doppel\)\{0,1\}\"/version = \"${VERSION}\"/" "$file"
    fi
    echo "  Updated: $file"
done

# Update workspace dependency: uv-version = { version = "...", path = "..." }
if [[ "$(uname)" == "Darwin" ]]; then
    sed -i '' "s/uv-version = { version = \"[0-9][0-9.]*\(-doppel\)\{0,1\}\"/uv-version = { version = \"${VERSION}\"/" "$WORKSPACE_FILE"
else
    sed -i "s/uv-version = { version = \"[0-9][0-9.]*\(-doppel\)\{0,1\}\"/uv-version = { version = \"${VERSION}\"/" "$WORKSPACE_FILE"
fi
echo "  Updated: $WORKSPACE_FILE (workspace dep)"

# Update Cargo.lock
echo "Updating Cargo.lock..."
(cd "$REPO_ROOT" && cargo update -p uv-version -p uv -p uv-build 2>&1 | grep -v "^$")

echo ""
echo "Done. Verify with:"
echo "  cargo check -p uv-version"
echo "  grep '^version' crates/uv-version/Cargo.toml"
