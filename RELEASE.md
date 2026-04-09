# Releasing the Doppel uv fork

This is a fork of [astral-sh/uv](https://github.com/astral-sh/uv) maintained at
[doppelxyz/uv](https://github.com/doppelxyz/uv). It adds midnight-truncated `exclude-newer`
timestamps to reduce lockfile churn.

## Quick release

```bash
# 1. Set the version (appends -doppel automatically)
./scripts/doppel-set-version.sh 0.12.0

# 2. Commit
git add -A && git commit -m "Bump version to 0.12.0-doppel"

# 3. Tag and push
git tag 0.12.0-doppel
git push origin main --tags
```

The release workflow triggers on `workflow_dispatch` with a tag input. It builds binaries for:

| Target                      | Runner           |
| --------------------------- | ---------------- |
| `aarch64-apple-darwin`      | macOS 14 (arm64) |
| `x86_64-unknown-linux-gnu`  | Ubuntu latest    |
| `aarch64-unknown-linux-gnu` | Ubuntu 24.04     |

## Syncing with upstream

```bash
# Add upstream remote (one-time)
git remote add upstream https://github.com/astral-sh/uv.git

# Fetch the upstream release tag
git fetch upstream --tags

# Rebase the Doppel branch onto the new release
git rebase <upstream-tag>

# Resolve any conflicts in exclude_newer.rs, then set the version
./scripts/doppel-set-version.sh <new-version>

# Commit, tag, push
git add -A && git commit -m "Bump version to <new-version>-doppel"
git tag <new-version>-doppel
git push origin main --tags
```

### What to watch for during rebase

- **`crates/uv-distribution-types/src/exclude_newer.rs`** — our `start_of_day()` truncation in
  `recompute()` and `FromStr`. If upstream changes these methods, re-apply the truncation.
- **`.github/workflows/build-release-binaries.yml`** — upstream may add new platforms or change
  runner names. We only keep 3 targets + Safe Chain.
- **`crates/uv-version/Cargo.toml`** — upstream bumps the version here. Run `doppel-set-version.sh`
  after rebasing to re-apply the `-doppel` suffix.

## Version scheme

Format: `<upstream-version>-doppel` (e.g., `0.11.5-doppel`)

The `-doppel` suffix is a valid SemVer pre-release identifier. It makes `uv --version` clearly
identify the fork. The script `scripts/doppel-set-version.sh` updates the 4 files that carry the
version:

- `Cargo.toml` (workspace `uv-version` dependency)
- `crates/uv/Cargo.toml`
- `crates/uv-build/Cargo.toml`
- `crates/uv-version/Cargo.toml`

## Using the fork in the monorepo

The Doppel monorepo uses `mise` to manage uv. To use the fork locally:

```bash
# Install the built binary as a custom mise version
mkdir -p ~/.local/share/mise/installs/uv/0.11.5-doppel/uv-aarch64-apple-darwin
cp target/release/uv ~/.local/share/mise/installs/uv/0.11.5-doppel/uv-aarch64-apple-darwin/uv
ln -s uv ~/.local/share/mise/installs/uv/0.11.5-doppel/uv-aarch64-apple-darwin/uvx

# Override in .mise.local.toml (gitignored)
echo '[tools]\nuv = "0.11.5-doppel"' > .mise.local.toml
```

## CI

CI runs `check-fmt` and `check-lint` (Linux clippy only, no Windows) on every push/PR. Release
binaries are only built via the Release workflow.

All build jobs include [Aikido Safe Chain](https://github.com/AikidoSec/safe-chain) which blocks pip
installs of packages published less than 72 hours ago.
