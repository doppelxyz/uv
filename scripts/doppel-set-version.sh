#!/usr/bin/env bash
#
# Set the Doppel fork version across all crates.
#
# Usage:
#   ./scripts/doppel-set-version.sh 0.12.0   # sets 0.12.0-dev.0 in Cargo, 0.12.0.dev0 in pyproject
#
# Maturin auto-converts SemVer "0.12.0-dev.0" → PEP 440 "0.12.0.dev0" so the
# same Cargo.toml version works for both the Rust binary and Python wheels.
# `uv --version` prints "uv 0.12.0-dev.0".
#
# What it updates:
#   Cargo (SemVer: X.Y.Z-dev.0):
#   - Cargo.toml           (workspace uv-version dep)
#   - crates/uv/Cargo.toml
#   - crates/uv-build/Cargo.toml
#   - crates/uv-version/Cargo.toml
#   - Cargo.lock           (via cargo update)
#
#   Python (PEP 440: X.Y.Z.dev0) — auto-converted by maturin from the Cargo version:
#   - pyproject.toml
#   - crates/uv-build/pyproject.toml

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <version>"
    echo "  e.g. $0 0.12.0 → Cargo: 0.12.0-dev.0, Python: 0.12.0.dev0"
    exit 1
fi

INPUT="$1"

# Strip any existing suffix to get base version
BASE="${INPUT%-dev.0}"
BASE="${BASE%-doppel}"
BASE="${BASE%.dev0}"

if ! [[ "$BASE" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "ERROR: '$BASE' is not a valid semver (expected X.Y.Z)" >&2
    exit 1
fi

# SemVer for Cargo — maturin converts this to PEP 440 automatically
CARGO_VERSION="${BASE}-dev.0"
# PEP 440 for pyproject.toml (maturin reads Cargo.toml but pyproject.toml
# also carries the version for tools that read it directly)
PEP440_VERSION="${BASE}.dev0"

echo "Setting versions:"
echo "  Cargo (SemVer):   $CARGO_VERSION  (uv --version)"
echo "  Python (PEP 440): $PEP440_VERSION (pyproject.toml / wheels)"
echo ""

_sed() {
    if [[ "$(uname)" == "Darwin" ]]; then
        sed -i '' "$@"
    else
        sed -i "$@"
    fi
}

# --- Cargo files (SemVer: X.Y.Z-dev.0) ---

CRATE_FILES=(
    "$REPO_ROOT/crates/uv/Cargo.toml"
    "$REPO_ROOT/crates/uv-build/Cargo.toml"
    "$REPO_ROOT/crates/uv-version/Cargo.toml"
)

for file in "${CRATE_FILES[@]}"; do
    if [[ ! -f "$file" ]]; then
        echo "WARNING: $file not found, skipping" >&2
        continue
    fi
    _sed "s/^version = \"[0-9][^\"]*\"/version = \"${CARGO_VERSION}\"/" "$file"
    echo "  Updated: $file"
done

_sed "s/uv-version = { version = \"[0-9][^\"]*\"/uv-version = { version = \"${CARGO_VERSION}\"/" "$REPO_ROOT/Cargo.toml"
echo "  Updated: Cargo.toml (workspace dep)"

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
    _sed "s/^version = \"[0-9][^\"]*\"/version = \"${PEP440_VERSION}\"/" "$file"
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
