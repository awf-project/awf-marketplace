# Self-Update (awf upgrade)

`awf upgrade` updates the AWF binary in-place. It downloads the platform-specific binary from GitHub Releases, verifies the SHA-256 checksum, and atomically replaces the current executable.

## Synopsis

```bash
awf upgrade [flags]
```

| Flag | Description |
|------|-------------|
| `--check` | Check for a newer version without downloading |
| `--force` | Download and install even if already on the latest version |
| `--version <tag>` | Install a specific release tag (e.g. `v0.6.33`) |

## Basic Usage

```bash
# Upgrade to the latest release
awf upgrade

# Check for a newer version without installing
awf upgrade --check

# Install a specific version
awf upgrade --version v0.6.20

# Force reinstall of the current version
awf upgrade --force
```

## How It Works

1. Resolves the target version from GitHub Releases (latest, or the tag given via `--version`).
2. Downloads the platform-specific archive (`linux_amd64`, `darwin_arm64`, etc.).
3. Verifies the SHA-256 checksum against the release manifest.
4. Atomically replaces the running binary: tries `os.Rename` (same filesystem) and falls back to a copy-then-rename when the temp directory and the binary live on different filesystems (e.g. `/tmp` vs `/usr/local/bin`).

The current binary path is detected at startup via `os.Executable()`.

## Package Manager Detection

When AWF detects it was installed through a system package manager (Homebrew, apt, etc.), it refuses to self-update and prints guidance to use the package manager instead. Use `--force` to bypass this check and overwrite the binary directly.

```bash
# Bypass package manager detection
awf upgrade --force
```

## GitHub API Rate Limiting

Set `GITHUB_TOKEN` to authenticate GitHub API requests and avoid the unauthenticated rate limit (60 requests/hour per IP).

```bash
export GITHUB_TOKEN=ghp_...
awf upgrade
```

This is the same token used by `awf plugin install` and `awf workflow install`.

## Error Codes

| Code | Description |
|------|-------------|
| `USER.UPGRADE.VERSION_NOT_FOUND` | The requested `--version` tag does not exist on GitHub Releases |
| `USER.UPGRADE.ALREADY_LATEST` | Already on the latest version (only surfaced without `--force`) |
| `SYSTEM.UPGRADE.CHECKSUM_MISMATCH` | Downloaded archive SHA-256 does not match the release manifest |
| `SYSTEM.UPGRADE.BINARY_REPLACE_FAILED` | Could not replace the running binary (permissions, locked file) |
| `SYSTEM.UPGRADE.DOWNLOAD_FAILED` | Network error or GitHub API failure during download |

## Examples

```bash
# Check current version first
awf version
# awf v0.6.20

# Check for upgrade without downloading
awf upgrade --check
# Latest: v0.6.33 (current: v0.6.20)

# Upgrade
awf upgrade
# Downloading awf v0.6.33 for linux_amd64...
# Checksum verified.
# Binary replaced: /usr/local/bin/awf

# Verify
awf version
# awf v0.6.33
```
