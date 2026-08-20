# wp-clite — Project Overview

**WP-CLite** is a lightweight, single-file Bash script that manages WordPress plugin and theme updates without requiring WP-CLI or a database connection.

## What It Is

A drop-in replacement for WP-CLI update commands that uses only the WordPress.org REST API and standard Unix tools (`curl`, `unzip`, optionally `python3` and `git`). Designed for environments where installing full WP-CLI is impractical: shared hosting, CI pipelines, minimal containers.

## Key Design Tenets

- **Zero dependencies** — no WP-CLI binary, no Composer, no database driver
- **Offline capable** — `--skip-update-check` allows inventories without external APIs
- **WP-CLI parity for updates** — mirrors behavior from WP-CLI v2.10–v2.12 for update and integrity workflows only
- **WordPress 7.x compatible** — tested against WP 7.1; `requires`/`requires_php` checks work with WP 7.x plugin metadata
- **Atomic operations** — downloads extracted to `/tmp`, then atomically replaced on disk

## Architecture

```
wp-clite/
├── wp-clite.sh          # Single file: all logic (684 lines)
├── README.md            # Documentation (formatted per repo conventions)
├── wiki/                # LLM-generated wiki index and cross-references
│   ├── overview.md      # This file — synthesized project view
│   ├── index.md         # Content-oriented catalog of all wiki pages
│   ├── log.md           # Chronological change log
│   ├── entities/        # Entity pages (script, flags, APIs)
│   │   ├── wp-clite.sh.md
│   │   ├── cli-flags.md
│   │   └── apis.md
│   └── concepts/       # Concept pages (patterns & workflows)
│       ├── update-status-classification.md
│       ├── checksum-verification.md
│       ├── version-pinning.md
│       └── git-integration.md
└── LICENSE              # MIT License
```

## Core Capabilities

| Capability | Implementation |
|------------|----------------|
| Plugin/theme scanning | `find + grep` on plugin/theme directories (no DB) |
| Update discovery | WordPress.org REST API (`info/1.0/<slug>.json`) |
| Version compatibility | Compares installed WP version against `requires`; PHP version against `requires_php` |
| Download & deploy | `curl -L → /tmp → unzip → mv` (atomic replace) |
| Pre-update backup | `cp -r` to timestamped backup dir before replacing |
| Checksum verification | Fetches checksums JSON from WordPress.org; uses `python3 hashlib.md5` |
| Git commits | `git add + git commit chore: <name> update v<old>→v<new>` |
| Version pinning | `--minor` (same major only), `--patch` (same major.minor only) |
| Slug skip list | `--skip <slug ...>` — linear scan of space-separated slugs before API query |
| Changelog display | `--changelog` — python3-based changelog extraction from API response |
| Maintenance mode | `wp maintenance-mode activate` |

## WP-CLI Feature Mapping

| wp-clite flag | WP-CLI equivalent | Introduced in WP-CLI |
|---------------|-------------------|---------------------|
| `--minor` / `--patch` | `wp plugin update --minor/--patch` | v2.10.0 |
| `requires`/`requires_php` check | `unavailable` state in `wp plugin list` | v2.12.0 |
| PHP 8.4 compatibility | Implicitly nullable params, CSV escaping, `E_STRICT` removal | v2.12.0 |
| `--skip-update-check` | `wp plugin list --skip-update-check` | v2.12.0 |
| `--verify-checksums` | `wp core verify-checksums` | v2.12.0 |
| `--skip <slug>` | `wp plugin update --skip=<slug>` | v2.10.0 |
| `--changelog` (display) | `wp plugin info <slug> --field=changelog` | v1.5.0 |
| `--backup` (pre-update) | (manual backup pattern) | — |
| Maintenance mode | `wp maintenance-mode activate` | v2.x |
| Git commit on update | (native WP-CLI integration) | — |
| Summary table output | `wp plugin update` result rendering | v2.x |

## Limitations (Intentional Scope Boundaries)

- WP.org plugins/themes only — no GitHub releases, no premium/custom zip URLs
- No multisite support
- No database-dependent operations (cache flushing, upgrade routines, user/post management)
- Checksums require `python3` (graceful skip if absent)

## Sources

- [WP-CLI](https://wp-cli.org) — inspiration and feature parity reference
- [WordPress.org REST API docs](https://developer.wordpress.org/rest-api/) — plugin/theme/info endpoints
- [WordPress.org Checksums API](https://developer.wordpress.org/reference/hooks/checksums/) — core checksum verification

## Related Wiki Pages

See [index.md](index.md) for a full catalog of entity and concept pages.
