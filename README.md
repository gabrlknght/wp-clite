# wp-clite

**WP-CLite — a lightweight WP-CLI alternative: no WP-CLI & no database required.**

A single Bash script that manages WordPress plugin and theme updates using nothing but the [WordPress.org REST API](https://api.wordpress.org) and standard Unix tools (`curl`, `unzip`, optionally `python3` and `git`). Drop it anywhere you have shell access to a WordPress installation — no WP-CLI binary, no `wp-config.php` parsing, and no live database connection needed.

Originally conceived as a lightweight drop-in for environments where WP-CLI installation is impractical (shared hosting, CI pipelines, minimal containers), this script has grown to integrate the featureset of WP-CLI v2.10–v2.12 for the update and integrity-checking workflows. If you need more than what this script provides, support the OG project that inspired it: https://wp-cli.org

---

## Requirements

| Tool | Required | Notes |
|------|----------|-------|
| `bash` 4+ | ✅ Yes | Shipped with every modern Linux/macOS |
| `curl` | ✅ Yes | For all API queries and downloads |
| `unzip` | ✅ Yes | For extracting plugin/theme archives |
| `python3` | Optional | Only needed for `--verify-checksums` |
| `git` | Optional | Only needed for automatic git commits |
| `php` CLI | Optional | Used to auto-detect your PHP version for compatibility checks; can be overridden with `--php-version` |

---

## Installation

```bash
# Clone the repo
git clone https://github.com/gabrlknght/wp-clite.git
cd wp-clite

# Make the script executable
chmod +x wp-clite.sh
```

No package manager, no Composer, no dependencies to install. It's ready to go.

---

## Usage

```
bash wp-clite.sh [options]
```

### Options

| Flag | Description |
|------|-------------|
| `--wp-path <path>` | Path to the WordPress root directory. Defaults to the current directory. The script auto-detects `wp-content/plugins`, `wp-content/themes`, and reads `wp-includes/version.php` for the installed WP version. |
| `--dry-run` | Simulate every action without downloading or modifying any files. All output is still written to the log. Git operations are automatically disabled in this mode. |
| `--log [file]` | Write all output to a log file. If no filename is provided, a timestamped name (`wp-update-logfile-YYYYMMDD-HHMMSS.txt`) is used. |
| `--yes` / `--auto-yes` | Skip all interactive prompts and approve every available update automatically. |
| `--plugins-only` | Scan and update plugins only; skip the themes pass. |
| `--themes-only` | Scan and update themes only; skip the plugins pass. |
| `--minor` | **Version pinning.** Only update within the same major version. An update from `2.1.0` to `3.0.0` is skipped; `2.1.0` to `2.2.0` is allowed. *(Mirrors WP-CLI v2.10.0 `--minor` flag.)* |
| `--patch` | **Version pinning.** Only update within the same major.minor version. An update from `2.1.0` to `2.2.0` is skipped; `2.1.0` to `2.1.4` is allowed. *(Mirrors WP-CLI v2.10.0 `--patch` flag.)* |
| `--skip-update-check` | List all installed plugins and themes with their local versions without querying the WordPress.org API at all. Useful for inventorying an air-gapped site. *(Mirrors WP-CLI v2.12.0 `--skip-update-check` flag.)* |
| `--verify-checksums` | Fetch the official MD5 checksums for your installed WordPress core version from the WordPress.org API and compare them against every tracked file in your installation. Reports any modified or corrupted files. Requires `python3`. *(Mirrors WP-CLI v2.12.0 `wp core verify-checksums`.)* |
| `--maintenance-mode` | Write a `.maintenance` file to the WordPress root before updates begin and remove it when done. This activates WordPress's built-in maintenance screen for site visitors during the update window. |
| `--wp-version <ver>` | Override the auto-detected WordPress version used for compatibility checks (e.g. `6.5.3`). Useful when `wp-includes/version.php` is not readable. |
| `--php-version <ver>` | Override the auto-detected PHP version used for compatibility checks (e.g. `8.1.0`). Useful in environments without a `php` CLI binary. |
| `--no-git` | Skip all git operations even if a repository is detected. |
| `--help` | Print the usage message and exit. |

---

## How It Works

### 1. Environment Detection

On startup, the script:

- Reads `wp-includes/version.php` to determine the installed WordPress version.
- Calls `php -r "echo PHP_VERSION;"` to detect the active PHP version.
- Resolves plugin and theme directories from the WordPress root, supporting both the standard `wp-content/plugins` layout and a legacy flat layout.

Both detected values can be overridden with `--wp-version` and `--php-version`.

### 2. Update Status Classification

For each plugin and theme, the script queries the WordPress.org API and classifies the update status into one of four states — matching the behaviour introduced in WP-CLI v2.12.0:

| Status | Meaning |
|--------|---------|
| `Up to date` | Installed version matches the latest available version. |
| `Update available` | A newer version exists and your environment meets its requirements. |
| `Unavailable` | A newer version exists but requires a higher WordPress or PHP version than your installation provides. The update is skipped automatically. |
| `Pinned` | A newer version exists but falls outside the range allowed by `--minor` or `--patch`. The update is skipped automatically. |

### 3. Download & Install

Updates are downloaded to a temporary directory under `/tmp/wp-updates-<PID>`, extracted, and moved into place atomically (old directory removed, new directory moved in). The temporary directory is cleaned up on exit regardless of success or failure.

### 4. Git Integration

If the working tree is inside a git repository and `--no-git` is not set, the script stages the updated plugin or theme directory and creates a conventional commit:

```
chore: <Plugin Name> update from v<old> to v<new>
```

### 5. WP Core Checksum Verification

When `--verify-checksums` is passed, the script:

1. Fetches the official checksums JSON from `https://api.wordpress.org/core/checksums/1.0/?version=<wp_version>&locale=en_US`.
2. Uses `python3` to iterate every file listed in the checksums manifest.
3. Computes the MD5 hash of each local file and compares it to the expected value.
4. Reports any mismatches (files that have been modified or corrupted).

Files present in the manifest but absent on disk are silently skipped — this covers optional files that not every installation includes.

### 6. Summary

Every run concludes with a results table:

```
================================
          Update Summary
================================
  Updated:       3
  Up to date:    12
  Unavailable:   1
  Pinned:        0
  Skipped:       1
  Failed:        0
================================
```

---

## Examples

```bash
# Preview what would change on a live site — nothing is modified
bash wp-clite.sh \
    --wp-path /var/www/html \
    --dry-run \
    --log dry-run-$(date +%F).log

# Fully automated update of plugins only, with maintenance mode and git commits
bash wp-clite.sh \
    --wp-path /var/www/html \
    --plugins-only \
    --yes \
    --maintenance-mode \
    --log updates-$(date +%F).log

# Only apply patch-level updates (e.g. 2.1.3 → 2.1.9, not 2.1.3 → 2.2.0)
bash wp-clite.sh \
    --wp-path /var/www/html \
    --patch \
    --yes

# Inventory all installed plugins and themes without hitting any external API
bash wp-clite.sh \
    --wp-path /var/www/html \
    --skip-update-check

# Verify WordPress core file integrity — no DB, no WP-CLI needed
bash wp-clite.sh \
    --wp-path /var/www/html \
    --verify-checksums

# CI/CD pipeline: dry-run with known versions, no prompts, no git
bash wp-clite.sh \
    --wp-path /var/www/html \
    --dry-run \
    --yes \
    --no-git \
    --wp-version 6.5.3 \
    --php-version 8.2.0
```

---

## WP-CLI Feature Parity Reference

This script draws directly from behavior introduced in recent WP-CLI releases. The table below maps each feature to its WP-CLI source:

| This script | WP-CLI equivalent | WP-CLI version |
|-------------|------------------|----------------|
| `--minor` / `--patch` | `wp plugin update --minor` / `--patch` | v2.10.0 |
| `requires` / `requires_php` compat check | `unavailable` update state in `wp plugin list` | v2.12.0 |
| `--skip-update-check` | `wp plugin list --skip-update-check` | v2.12.0 |
| `--verify-checksums` | `wp core verify-checksums` | v2.12.0 |
| `--maintenance-mode` | `wp maintenance-mode activate` | v2.x |
| Git commit on update | `wp plugin update` with version control integration | — |
| End-of-run summary table | `wp plugin update` result output | v2.x |

---

## Caveats & Limitations

- **WordPress.org plugins and themes only.** The script queries `api.wordpress.org`. Premium plugins, themes installed from GitHub releases (a WP-CLI v2.11.0 feature), or custom zip URLs are not supported.
- **No multisite awareness.** Network-activated plugins and per-site theme overrides are not considered.
- **No database-dependent operations.** Commands that require a live DB (flushing caches, running upgrade routines, managing options/users/posts) are intentionally out of scope. For those, use WP-CLI directly.
- **`--verify-checksums` requires `python3`.** The checksums manifest is a large JSON object; `python3` is used for reliable parsing. The check is skipped gracefully if `python3` is unavailable.

---

## Contributing

Pull requests are welcome. If you find a bug or have an idea for a new flag that can be implemented without a database or WP-CLI dependency, please open an issue first to discuss it.

---

## License

This project is licensed under the MIT License.

See [LICENSE](LICENSE) for full details.
