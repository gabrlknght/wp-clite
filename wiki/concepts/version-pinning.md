# Concept: Version Pinning

**Category:** update safety mechanism  
**Implemented in:** `update_allowed_by_pinning()` function  

## Summary

Prevents automatic major or minor version updates when the user specifies a constraint (`--minor` or `--patch`). This is a rollback prevention measure — if an older WordPress installation gets flagged with a new major WP core update, pinning avoids accidentally stepping up too far.

## Constraint Levels

### `--minor` (same major only)

| Current | Latest | Allowed? |
|---------|--------|----------|
| 2.1.0   | 3.0.0  | ❌ No   |
| 2.1.0   | 2.2.0  | ✅ Yes  |
| 6.5.3   | 6.6.0  | ✅ Yes  |
| 7.0.0   | 7.1.0  | ✅ Yes  |

Implementation: compares `cut -d. -f1` (first segment only)

### `--patch` (same major.minor only)

| Current | Latest | Allowed? |
|---------|--------|----------|
| 2.1.3   | 2.2.0  | ❌ No   |
| 2.1.3   | 2.1.9  | ✅ Yes  |
| 6.5.0   | 6.5.3  | ✅ Yes  |
| 7.0.0   | 7.0.2  | ✅ Yes  |

Implementation: compares `cut -d. -f1,2` (first two segments)

## Priority

When both flags are set, `--patch` is strictly more restrictive and effectively wins since a patch-level update is always minor-level but not vice versa. The logic evaluates `--patch` first in the if/elif chain.

## Cross-References

- [Entity: CLI Flags](../entities/cli-flags.md) — `--minor`, `--patch`
- [Concept: Update Status Classification](update-status-classification.md) — generates "pinned" status
