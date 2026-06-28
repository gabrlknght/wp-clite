# Entity: wp-clite.sh (Primary Script)

**Type:** bash executable  
**Size:** 580 lines (~22 KB)  
**Version:** 2.2.0  
**License:** MIT

## Summary

The single entry point and only deliverable of the project. Encapsulates every feature — dependency checking, argument parsing, WordPress version detection, API querying, update scanning, download/install, checksum verification, git integration, and summary reporting.

## Structure (by section)

| Section | Lines | Purpose |
|---------|-------|---------|
| Header + flags/defaults | ~50 | CLI flag variables with defaults |
| `show_help()` | ~20 | Usage display with examples |
| `check_dependencies()` | ~40 | Validates curl/unzip/python3/git availability (critical vs optional) |
| Argument parsing loop | ~25 | `while [[ $# -gt 0 ]]` case dispatch |
| Log setup + exec tee | ~10 | Redirects stdout+stderr to file via process substitution |
| Path resolution | ~15 | Resolves plugin/theme dirs, creates /tmp working dir |
| Environment detection | ~30 | `detect_wp_version()`, `detect_php_version()` |
| Directory validation | ~15 | Verifies plugin/theme dirs exist, errors out with `--wp-path` hint otherwise |
| Maintenance mode | ~15 | `enable_maintenance_mode()`, `disable_maintenance_mode()` — writes/removes `.maintenance` |
| Version utilities | ~30 | `version_gte()`, `update_allowed_by_pinning()`, `get_update_status()` |
| API handler (`query_wp_api`) | ~20 | Fetches `<type>/<slug>` JSON from WordPress.org |
| Header parsers (6 funcs) | ~25 | Extracts name/version/slug from plugin/theme headers |
| Git operations | ~25 | `check_git()`, `git_handle_update()` |
| Updater (`do_update`) | ~30 | Download → unzip → atomic replace flow |
| Checksum verification | ~40 | Spawns python3 inline script against checksums JSON |
| Changelog extraction (`get_changelog`) | ~20 | python3 inline script parses `sections.changelog` from plugin API JSON. The theme_information API doesn't expose changelog data (verified empirically — themes only ever return a `description` section), so this is a no-op for themes |
| Backup creation (`create_backup`) | ~10 | `cp -r` to timestamped backup directory |
| Slug skip check (`is_skipped`) | ~7 | Linear scan of space-separated `SKIP_LIST` |
| Scanner (`scan_extensions`) | ~75 | Iterates plugins/themes, classifies status, prompts or auto-applies |
| Summary output | ~15 | Final table with update counts |

## Key Patterns

- **Process substitution logging:** `exec > >(tee -a "$LOG_FILE") 2>&1` pipes everything to a timestamped log file automatically.
- **Conditional dependency checking:** critical vs optional deps — fails only if required tools are missing for the *chosen* operation.
- **Pipe-delimited entities:** plugin/theme data flows as `"name|version|slug"` strings; parsed with `IFS='|' read`.
- **Inline python3 heredoc:** checksum verification uses embedded Python for reliable JSON parsing and MD5 hashing.

## Cross-References

- [Concept: Update Status Classification](../concepts/update-status-classification.md)
- [Concept: Version Pinning](../concepts/version-pinning.md)
- [Concept: Checksum Verification](../concepts/checksum-verification.md)
- [Entity: CLI Flags](cli-flags.md)
