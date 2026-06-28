# Entity: CLI Flags

**Type:** command-line argument flags  
**Count:** 18 flags + path/version options  
**Parsing method:** `while [[ $# -gt 0 ]]` case dispatch

## Flag Reference

### Mode Selectors

| Flag | Type | Default | Effect |
|------|------|---------|--------|
| `--dry-run` | boolean | 0 | Simulate everything; auto-enables `--no-git` |
| `--plugins-only` | boolean | 0 | Scan plugins only, skip themes |
| `--themes-only` | boolean | 0 | Scan themes only, skip plugins |
| `--yes / --auto-yes` | boolean | 0 | Auto-approve all updates (no prompts) |

### Version Pinning

| Flag | Type | Default | Effect |
|------|------|---------|--------|
| `--minor` | boolean | 0 | Only allow same-major updates (2.x → 2.y) |
| `--patch` | boolean | 0 | Only allow same-major.minor updates (2.1.x → 2.1.y) |

### Skip / Override

| Flag | Type | Default | Effect |
|------|------|---------|--------|
| `--skip-update-check` | boolean | 0 | List installed versions only; no API queries |
| `--no-git` | boolean | auto | Skip all git operations |
| `--verify-checksums` | boolean | 0 | Check WP core file integrity via checksums API |
| `--maintenance-mode` | boolean | 0 | Write `.maintenance` before updates, remove after |
| `--skip <slug ...>` | space-separated list | (empty) | Skip specific plugins/themes by slug. Multiple space-separated slugs: `--skip yoast-seo cf7` |
| `--backup` | boolean | 0 | Create timestamped backup of plugin/theme dir before replacing. Backups in `/tmp/wp-clite-backups/`, persistent across runs |
| `--changelog` | boolean | 0 | Show changelog from WordPress.org API before update prompt. Extracted via python3 for reliable JSON parsing. Plugins only — the theme_information API doesn't expose changelog data, so this no-ops for themes |

### Configuration Options

| Flag | Type | Default | Effect |
|------|------|---------|--------|
| `--wp-path <path>` | string | `.` | WordPress root directory (auto-detects wp-content/) |
| `--wp-version <ver>` | string | auto-detected | Override detected WP version |
| `--php-version <ver>` | string | auto-detected | Override detected PHP version |

### Utility

| Flag | Type | Default | Effect |
|------|------|---------|--------|
| `--log [file]` | string (optional) | timestamped | Log file path; defaults to `wp-update-logfile-YYYYMMDD-HHMMSS.txt` |
| `--help / -h` | boolean | 0 | Shows usage + examples, then prompts Enter to exit |

## Flag Interactions

- `--dry-run` → implicitly sets `NO_GIT=1` (no git commits in simulation mode)
- `--minor` + `--patch` — both can be set; `--patch` is stricter and takes precedence
- `--skip-update-check` makes all API-dependent flags (`--verify-checksums`, download) no-op
- `--dry-run` → `--backup` no-ops (no real backup created, no files modified)
- `--skip` slugs checked before API query — skipped entries never reach the update prompt
- `--changelog` only displayed for `available` entries; up-to-date/pinned/unavailable items skip changelog display
- `--backup` stores backups in `$BACKUP_DIR` (`/tmp/wp-clite-backups/`), independent of `$TEMP_DIR` — not cleaned up on exit, so they remain available for rollback

## Cross-References

- [Concept: Update Status Classification](../concepts/update-status-classification.md)
