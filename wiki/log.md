# wiki/ — Change Log

**Format:** `## [YYYY-MM-DD] type | title`  
**Purpose:** Chronological, append-only record of wiki creation and maintenance events. Parseable with `grep "^## \[" log.md`.

---

## [2026-08-19] docs | WordPress 7+ compatibility audit

Audited all wiki and README content against the current WordPress 7.x ecosystem and WP-CLI v2.12.0 releases. Verified live against the WordPress.org plugin/info REST API (tested with Akismet: `requires: 5.8`, `tested: 7.1`, `requires_php: 7.2`).

Findings and corrections:

| Area | Finding | Action |
|------|---------|--------|
| README CI example | `--wp-version 6.5.3` is stale (WP 7.1 is now live) | Updated both CI and admin examples to `--wp-version 7.1.0` |
| Overview — WP-CLI parity | Script claimed parity with v2.10–v2.12, but v2.12.0 introduced PHP 8.4 compat (implicitly nullable params, CSV escaping deprecations, E_STRICT removal) and a configurable user-agent flag that are notable | Added a "Recent v2.12.0 additions" row noting PHP 8.4 compatibility and configurable user-agent |
| Sources/apis.md | All 3 API endpoints still function identically for WP 7.x | Confirmed no changes needed; endpoint URLs and response shapes unchanged |
| Script line count | wiki says ~676 lines, `wc -l` reports 684 | Updated all references to state "684 lines" (or "~684 lines" where approximate) |
| wiki/index.md | Last-generated dates stale | Updated index.md generated date to 2026-08-19 |
| No WP 7.x mention anywhere | Documentation never mentioned WP 7.x compatibility | Added WP 7.x compatibility note to overview.md capabilities section |

The script itself requires no code changes — it doesn't hardcode WordPress version limits and the `requires`/`requires_php` compatibility checks work correctly against WP 7.x plugin metadata. The primary updates are documentation freshness.

---

## [2026-06-28] fix | v2.2.0 — skip/backup bugfixes

Sanity-checked the v2.2.0 `--skip`/`--backup`/`--changelog` feature additions and fixed four issues found in `wp-clite.sh`:

| Bug | Location | Fix |
|-----|----------|-----|
| `--skip` parser checked `"$2"` instead of `"$1"` in its while-condition, plus a stray trailing `shift` | arg-parsing loop, `--skip` case | Loop condition now checks `"$1"`; removed the erroneous trailing `shift`. Previously the last (or only) slug passed to `--skip` was silently dropped. |
| `--backup` flag set `BACKUP_BEFORE` but nothing read it — `create_backup()` ran unconditionally on every update | `scan_extensions()`, both `AUTO_YES` and confirm-prompt branches | Wrapped both `create_backup` calls in `if [ "$BACKUP_BEFORE" -eq 1 ]`; backups are now only created when `--backup` is passed. |
| Backups were stored under `$TEMP_DIR`, which is `rm -rf`'d at the end of every run — deleting backups before the script even finished | `BACKUP_DIR` definition, `create_backup()` | `BACKUP_DIR` changed to the fixed, persistent path `/tmp/wp-clite-backups` (independent of `$TEMP_DIR`); `create_backup()` now `mkdir -p`s it lazily. Backups now survive past script exit, which is the entire point of a rollback safety net. |
| `latest_ver` printed in the `is_skipped` branch before it was ever assigned (population happens later, via `query_wp_api`, which that branch skips) | `scan_extensions()`, `is_skipped` early-continue | Removed the bogus `Latest: v$latest_ver` column for skipped entries; now prints `Latest: (skipped by --skip)`, matching the existing `--skip-update-check` output convention. |

Also removed dead `[ "$DRY_RUN" -eq 0 ] &&` guards around the `create_backup` calls — both call sites are already inside branches where `DRY_RUN` is guaranteed `0`.

Verified against the live WordPress.org API: `--changelog` works correctly for plugins (`sections.changelog` is present), but the `theme_information` endpoint never returns changelog content for any theme tested (astra, hello-elementor, oceanwp, twentytwentyfour all return only a `description` section). This isn't a crash — `get_changelog()` already gracefully no-ops when the field is absent — but the code comment and docs previously claimed theme changelog support ("handles nested theme sections"), which was never true. Corrected the comment in `get_changelog()` and the corresponding claims in `wiki/entities/wp-clite.sh.md` and `wiki/entities/cli-flags.md`.

Docs updated to match: `README.md`, `wiki/entities/cli-flags.md`, `wiki/entities/wp-clite.sh.md`, `wiki/concepts/pre-update-backup.md` (backup path/persistence semantics and changelog scope corrected).

---

## [2026-06-28] feature | v2.2.0 — skip, backup, changelog

Three new features added to `wp-clite.sh`:

| Feature | Flag | Description |
|---------|------|-------------|
| **Skip list** | `--skip <slug ...>` | Skip specific plugins/themes by slug. Accepts multiple space-separated slugs. Checked before API query; skipped entries counted as "Skipped" in summary. |
| **Pre-update backup** | `--backup` | Creates a timestamped `cp -r` backup of the plugin/theme directory before replacing it. Backups stored in `/tmp/wp-updates-<PID>/backups/`, cleaned up on exit. |
| **Changelog display** | `--changelog` | Shows changelog text from WordPress.org API before prompting to update. Uses python3 for reliable JSON parsing (handles nested theme `sections.changelog`). Truncated to 200 chars. |

Script grew from ~580 to ~676 lines (~10% increase).

Pages updated:
| Page | Change |
|------|--------|
| `overview.md` | Added three new rows to capabilities table and WP-CLI feature mapping |
| `entities/cli-flags.md` | Added --skip, --backup, --changelog to Skip/Override table; added flag interaction notes |
| `entities/wp-clite.sh.md` | Added `get_changelog()`, `create_backup()`, `is_skipped()` to structure table |
| `README.md` | Added flag descriptions, examples, and WP-CLI parity rows |
| `log.md` | This entry |

---

## [2026-06-25] ingest | wp-clite project — initial wiki scaffolding

Initial LLM-generated wiki created from the project's README.md and source script (wp-clite.sh). Processed full codebase (~1 file, ~530 LOC) and repository metadata.

Wiki contents added:

| Page | Category | Description |
|------|----------|-------------|
| `overview.md` | Overview | Synthesized project view: design tenets, architecture diagram, capabilities table, WP-CLI feature mapping, limitations |
| `entities/wp-clite.sh.md` | Entity | Script internals: section-by-section breakdown (~50+ lines per section), key patterns (process substitution, inline python3, pipe-delimited entities) |
| `entities/cli-flags.md` | Entity | All 15 CLI flags: mode selectors, version pinning, skip/override, configuration/utility — with types, defaults, and cross-flag interactions |
| `sources/apis.md` | Source | Three WordPress.org REST endpoints: plugin info (1.0), theme info (1.2), core checksums (1.0) — URLs, parsing via grep/cut vs python3 heredoc, error handling |
| `concepts/update-status-classification.md` | Concept | Four-state update status workflow (none/available/unavailable/pinned), the decision flow, and the `sort -V` version comparison one-liner technique |
| `concepts/checksum-verification.md` | Concept | Core file integrity checking: fetch manifest → inline python3 MD5 comparison → report format; why python3 is required for thousands of entries |
| `concepts/version-pinning.md` | Concept | `--minor` (same major) and `--patch` (same major.minor) constraints with table examples, cut-based comparison logic, and priority ordering |
| `concepts/git-integration.md` | Concept | Auto-commit on update: dual detection (CLI + work-tree), commit format (`chore: name v<old>→v<new>`), per-update-scoped staging, flag interactions (--dry-run, --no-git) |
| `index.md` | Index | Content-oriented catalog with categorized tables, cross-reference links, and grep navigation tips |
| `log.md` | Log (this file) | Chronological change record |

Source material: `[raw] wp-clite.sh` (~530 lines), `README.md`, git history (8 commits), project root structure.

---

## [2026-06-24] lint | Corrected script line count and missing structure sections

Accuracy pass comparing the wiki against `wp-clite.sh` and `README.md` found the script's line count was understated and two real sections were missing from its structure breakdown.

Pages corrected:

| Page | Fix |
|------|-----|
| `overview.md` | Architecture diagram: `wp-clite.sh` line count corrected from ~530 to the actual 580 lines |
| `entities/wp-clite.sh.md` | Size field corrected from ~530 lines (~18 KB) to 580 lines (~22 KB); structure table now includes the previously omitted **Directory validation** (`wp-clite.sh:231-241`) and **Maintenance mode** (`wp-clite.sh:246-258`) sections |

All other wiki content (CLI flags, API endpoints, update-status classification, version pinning, checksum verification, git integration) was verified against the source and found accurate.
