# wiki/ — Index

**Generated:** 2026-08-19  
**Purpose:** Content-oriented catalog of all wiki pages, organized by category. The LLM reads this first to locate relevant pages before answering queries.

---

## Overview

| Page | Summary | Last generated |
|------|---------|----------------|
| [overview.md](overview.md) | Synthesized project overview: design tenets, architecture, capabilities, and limitation boundaries | 2026-08-19 |

## Entities

*Concrete components — files, APIs, flags.*

| Page | Summary | Last generated |
|------|---------|----------------|
| [wp-clite.sh](entities/wp-clite.sh.md) | Primary script architecture: sections, patterns, cross-references, line counts | 2026-08-20 |
| [CLI Flags](entities/cli-flags.md) | Full flag reference table (18 flags), types, defaults, interactions | 2026-08-20 |
| [WordPress.org APIs](sources/apis.md) | Three REST API endpoints: plugin info, theme info, core checksums — URLs, parsing, error handling | 2026-08-19 |

## Concepts

*Abstract patterns and workflows the script implements.*

| Page | Summary | Last generated |
|------|---------|----------------|
| [Update Status Classification](concepts/update-status-classification.md) | Four-state classification (none/available/unavailable/pinned), decision flow, version comparison logic | 2026-08-19 |
| [Checksum Verification](concepts/checksum-verification.md) | MD5 integrity checking workflow: fetch manifest → compare against disk → report mismatches; why python3 is required | 2026-08-19 |
| [Version Pinning](concepts/version-pinning.md) | `--minor` and `--patch` constraints, comparison logic, priority ordering | 2026-08-19 |
| [Git Integration](concepts/git-integration.md) | Auto-commit on update: detection, commit format, scope, flag interactions | 2026-08-19 |
| [Pre-update Backup](concepts/pre-update-backup.md) | Timestamped `cp -r` backup before replacing; ephemeral storage in temp dir; cleanup behavior | 2026-08-19 |

## Log

| Page | Summary | Last generated |
|------|---------|----------------|
| [log.md](log.md) | Chronological change log with `## [YYYY-MM-DD] type | title` entries for ingests, queries, and lint passes | 2026-08-20 |

---

**Quick navigation:**
```bash
# Last 5 wiki changes
grep "^## \[" ../wiki/log.md | tail -5

# All entity pages
ls ../wiki/entities/

# All concept pages
ls ../wiki/concepts/
```
