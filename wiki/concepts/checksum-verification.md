# Concept: Core File Checksum Verification

**Category:** integrity checking  
**Implemented in:** `verify_wp_checksums()` function  

## Summary

Fetches the official MD5 checksums for every file in the installed WordPress core version and compares them against local files. Reports any mismatches, indicating that files have been modified or corrupted.

## How It Works

1. Queries `https://api.wordpress.org/core/checksums/1.0/?version=<wp>&locale=en_US`
2. Unpacks the JSON checksums manifest into a temporary file
3. Runs an inline `python3` script that:
   - Reads each `<path> → <expected_md5>` entry from the manifest
   - Computes `hashlib.md5(open(full_path, "rb").read()).hexdigest()` on disk
   - Collects mismatches
4. Reports all mismatched relative paths

## Why Python?

The checksums manifest contains thousands of entries (every WordPress core file). Pure shell processing is impractical for reliable JSON iteration; python3's `json` and `hashlib` modules handle it correctly in one pass.

## Output Example

```
✅ WordPress core checksums verified. No modifications detected.
```

or

```
⚠️ WP core checksum mismatches detected:
   - wp-admin/option-header.php
   - wp-includes/blocks/file/block.json
```

## Requirements

- `python3` — hard dep when `--verify-checksums` is active (validated before any API call)
- Readable `wp-includes/version.php` or `--wp-version` override
- Internet access to WordPress.org checksums API

## Cross-References

- [Entity: CLI Flags](../entities/cli-flags.md) — `--verify-checksums`, `--wp-version`
- [Source: Checksums API](../sources/apis.md)
