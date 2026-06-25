# Concept: Update Status Classification

**Category:** core workflow  
**Implemented in:** `get_update_status()` function  

## Summary

Every plugin/theme encountered during scanning is classified into one of four statuses by comparing local version against the WordPress.org API response and the user's environment constraints. This mirrors the `unavailable` update state introduced in WP-CLI v2.12.0.

## Four States

| Status | Condition | User Action |
|--------|-----------|-------------|
| **none** | Installed == latest (or no latest available) | No action needed; counted as "up to date" |
| **available** | Latest exists, WP/PHP requirements met, not pinned | Update offered (prompt or auto-approve) |
| **unavailable** | Newer version exists but requires higher WP/PHP than installed | Auto-skipped with notice; counted separately |
| **pinned** | Newer version exists but excluded by `--minor` or `--patch` | Auto-skipped; user can adjust pinning flags to override |

## Decision Flow

```
get_update_status(current, latest, req_wp, req_php):
  if latest is empty/none/current: return "none"
  
  if req_wp exists AND current WP version < req_wp: return "unavailable"
  if req_php exists AND current PHP version < req_php: return "unavailable"
  
  if PATCH_ONLY: check same major.minor → "pinned" || continue
  if MINOR_ONLY: check same major → "pinned" || continue
  
  return "available"
```

## Version Comparison

Uses `sort -V` (version sort) for `version_gte()`:

```bash
version_gte() {
    local installed="$1" required="$2"
    [ -z "$required" ] && return 0
    [ "$(printf '%s\n' "$required" "$installed" | sort -V | head -n1)" = "$required" ]
}
```

This is a clever one-liner that sorts two versions numerically and checks if the first (required) line is the required value — meaning installed ≥ required.

## Cross-References

- [Entity: CLI Flags](../entities/cli-flags.md) — `--minor`, `--patch`
- [Concept: Version Pinning](version-pinning.md)
