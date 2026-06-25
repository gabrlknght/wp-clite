# Concept: Git Integration

**Category:** version control automation  
**Implemented in:** `check_git()` and `git_handle_update()` functions  

## Summary

When updates are applied, the script optionally stages and commits changes to a git repository if the WordPress root is inside one. This gives an automatic audit trail of what changed and when.

## Detection Logic

Two checks gate on git availability:

1. **CLI present:** `command -v git >/dev/null` — fails silently if git isn't installed
2. **Repo exists:** `git -C "$WP_PATH" rev-parse --is-inside-work-tree` — verifies the WP root is a git working tree

Both must pass to create commits. Failing either prints "Git not installed" or "Not a git repository" and returns without error (non-destructive).

## Commit Format

```
chore: <Plugin/Theme Name> update from v<old_version> to v<new_version>
```

Example: `chore: Yoast SEO update from v21.8 to v22.0`

## Scope

Only the updated plugin/theme directory is staged and committed:

```bash
git add "${target_dir}/${slug}"
git commit -m "chore: ${name} update from v${old_ver} to v${new_ver}"
```

Other changed files in the repo are left untouched by the script (it does not do `git add .`).

## Interaction with Other Flags

| Flag | Effect on git behavior |
|------|----------------------|
| `--dry-run` | Auto-disabled (no commits during simulation) |
| `--no-git` | Explicitly disabled even if repo detected |
| No git installed | Non-destructive skip with message |

## Limitations

- Single commit per update (not batched at end — each plugin/theme gets its own commit)
- No merge conflict resolution (relies on user handling conflicts)
- Does not handle submodules (only adds the updated directory path)

## Cross-References

- [Entity: CLI Flags](../entities/cli-flags.md) — `--no-git`
- [Entity: wp-clite.sh](../entities/wp-clite.sh.md) — main script flow
