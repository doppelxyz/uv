#!/usr/bin/env bash
#
# Set the Doppel fork version across all crates and pyproject files.
#
# Usage:
#   ./scripts/doppel-set-version.sh 0.12.0     # sets 0.12.0-doppel everywhere
#   ./scripts/doppel-set-version.sh 0.12.0-doppel  # also works (keeps suffix as-is)
#
# What it updates:
#   Cargo (SemVer: X.Y.Z-doppel):
#   - Cargo.toml           (workspace uv-version dep)
#   - crates/uv/Cargo.toml
#   - crates/uv-build/Cargo.toml
#   - crates/uv-version/Cargo.toml
#   - Cargo.lock           (via cargo update)
#
#   Python (PEP 440: X.Y.Z.dev0):
#   - pyproject.toml
#   - crates/uv-build/pyproject.toml

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <version>"
    echo "  e.g. $0 0.12.0        → Cargo: 0.12.0-doppel, Python: 0.12.0.dev0"
    echo "  e.g. $0 0.12.0-doppel → same"
    exit 1
fi

INPUT="$1"

# Append -doppel if not already present
if [[ "$INPUT" == *-doppel ]]; then
    CARGO_VERSION="$INPUT"
else
    CARGO_VERSION="${INPUT}-doppel"
fi

# Extract the base version (without -doppel) for validation
BASE="${CARGO_VERSION%-doppel}"
if ! [[ "$BASE" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "ERROR: '$BASE' is not a valid semver (expected X.Y.Z)" >&2
    exit 1
fi

# PEP 440 version for Python/maturin (SemVer pre-release → PEP 440 dev)
PEP440_VERSION="${BASE}.dev0"

echo "Setting versions:"
echo "  Cargo (SemVer):   $CARGO_VERSION"
echo "  Python (PEP 440): $PEP440_VERSION"
echo ""

# --- Cargo files (SemVer: X.Y.Z-doppel) ---

CRATE_FILES=(
    "$REPO_ROOT/crates/uv/Cargo.toml"
    "$REPO_ROOT/crates/uv-build/Cargo.toml"
    "$REPO_ROOT/crates/uv-version/Cargo.toml"
)
WORKSPACE_FILE="$REPO_ROOT/Cargo.toml"

_sed() {
    if [[ "$(uname)" == "Darwin" ]]; then
        sed -i '' "$@"
    else
        sed -i "$@"
    fi
}

for file in "${CRATE_FILES[@]}"; do
    if [[ ! -f "$file" ]]; then
        echo "WARNING: $file not found, skipping" >&2
        continue
    fi
    _sed "s/^version = \"[0-9][0-9.]*\(-doppel[^\"]*\)\{0,1\}\"/version = \"${CARGO_VERSION}\"/" "$file"
    echo "  Updated: $file"
done

_sed "s/uv-version = { version = \"[0-9][0-9.]*\(-doppel[^\"]*\)\{0,1\}\"/uv-version = { version = \"${CARGO_VERSION}\"/" "$WORKSPACE_FILE"
echo "  Updated: $WORKSPACE_FILE (workspace dep)"

# --- Python files (PEP 440: X.Y.Z.dev0) ---

PYPROJECT_FILES=(
    "$REPO_ROOT/pyproject.toml"
    "$REPO_ROOT/crates/uv-build/pyproject.toml"
)

for file in "${PYPROJECT_FILES[@]}"; do
    if [[ ! -f "$file" ]]; then
        echo "WARNING: $file not found, skipping" >&2
        continue
    fi
    _sed "s/^version = \"[0-9][0-9.]*\(\.dev[0-9]*\)\{0,1\}\"/version = \"${PEP440_VERSION}\"/" "$file"
    echo "  Updated: $file (PEP 440)"
done

# --- Cargo.lock ---

echo ""
echo "Updating Cargo.lock..."
(cd "$REPO_ROOT" && cargo update -p uv-version -p uv -p uv-build 2>&1 | grep -v "^$")

echo ""
echo "Done. Verify with:"
echo "  cargo check -p uv-version"
echo "  grep '^version' crates/uv-version/Cargo.toml pyproject.toml"
