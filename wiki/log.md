# wiki/ — Change Log

**Format:** `## [YYYY-MM-DD] type | title`  
**Purpose:** Chronological, append-only record of wiki creation and maintenance events. Parseable with `grep "^## \[" log.md`.

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
