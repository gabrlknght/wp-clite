# Concept: Pre-update Backup

**Category:** safety mechanism  
**Implemented in:** `create_backup()` function  

## Summary

When `--backup` is passed, the script creates a timestamped copy of the plugin or theme directory before replacing it with the updated version. This provides a rollback point if the update breaks something.

## How It Works

1. Before `do_update()` replaces the directory, `create_backup()` is called with the type, slug, and source directory — but only when `--backup` was passed (checked via `$BACKUP_BEFORE`).
2. A timestamp is generated: `YYYYMMDD-HHMMSS`
3. `$BACKUP_DIR` is created on demand (`mkdir -p`), then the backup directory is created: `$BACKUP_DIR/<type>-<slug>-<timestamp>/`
4. `cp -r` copies the entire original directory to the backup path.
5. If the source directory doesn't exist (already removed somehow), the function returns silently.

## Backup Path Format

```
/tmp/wp-clite-backups/<type>-<slug>-<YYYYMMDD-HHMMSS>/
```

Examples:
```
/tmp/wp-clite-backups/plugin-yoast-seo-20260628-143022/
/tmp/wp-clite-backups/theme-twentytwentyfour-20260628-143023/
```

## Persistence

`$BACKUP_DIR` (`/tmp/wp-clite-backups`) is a fixed path independent of `$TEMP_DIR` (`/tmp/wp-updates-<PID>`), the latter being the per-run scratch space for downloads that is removed via `rm -rf` at the end of every run. Backups survive that cleanup and accumulate across runs in timestamped subdirectories, since the entire point of a backup is to be available *after* the script exits — that's when you'd discover an update broke something. Backups are not auto-pruned; clean up `/tmp/wp-clite-backups` manually if disk usage becomes a concern.

## Interaction with Other Flags

| Flag | Effect on backup behavior |
|------|--------------------------|
| `--dry-run` | Backup no-ops — no files are modified, so no backup is needed or created |
| `--backup` not set | No backup created; update proceeds directly |
| `--yes` | Backup is created even in auto-approve mode, so you can roll back automated updates |

## Limitations

- Uses `cp -r` which copies the entire directory. Large plugins (e.g. WooCommerce) may take noticeable time.
- No incremental backup — full copy every time.
- No automatic pruning — old backups accumulate in `/tmp/wp-clite-backups` until manually removed.
- Not a replacement for proper version control (use `--backup` as a quick safety net, not a substitute for git).

## Cross-References

- [Entity: CLI Flags](../entities/cli-flags.md) — `--backup`
- [Entity: wp-clite.sh](../entities/wp-clite.sh.md) — `create_backup()` function
- [Concept: Git Integration](git-integration.md) — alternative audit trail for updates
