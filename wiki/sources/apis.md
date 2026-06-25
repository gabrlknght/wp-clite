# Entity: WordPress.org REST API Endpoints

**Type:** external service references  
**Count:** 3 endpoints used  

## 1. Plugin Info API

```
GET https://api.wordpress.org/plugins/info/1.0/<slug>.json
```

Returns JSON describing a plugin including `version`, `requires` (min WP version), `requires_php`.

Used for: update discovery (`query_wp_api`, type="plugin")

## 2. Theme Info API

```
GET https://api.wordpress.org/themes/info/1.2/?action=theme_information&request%5Bslug%5D=<slug>
```

Returns JSON describing a theme including `version`, `requires` (min WP version), `requires_php`.

Used for: update discovery (`query_wp_api`, type="theme")

## 3. Core Checksums API

```
GET https://api.wordpress.org/core/checksums/1.0/?version=<wp_version>&locale=en_US
```

Returns JSON with `"checksums"` — a map of `<relative_path>` → `expected_md5` for every tracked WordPress core file.

Used for: `--verify-checksums` mode

## Response Parsing Strategy

All endpoints are parsed via shell tooling only — no JSON library dependency in the main flow:

```bash
version=$(echo "$response" | grep -o '"version":"[^"]*"' | head -1 | cut -d'"' -f4)
requires=$(echo "$response"  | grep -o '"requires":"[^"]*"'    | head -1 | cut -d'"' -f4)
req_php=$(echo "$response"   | grep -o '"requires_php":"[^"]*"'| head -1 | cut -d'"' -f4)
```

The checksums endpoint is the only one that uses `python3` (via inline heredoc) because it needs to iterate thousands of entries — `grep`/`cut` is not viable for that scale.

## Error Handling

- Network failure → logs "N/A|" as latest version; plugin/theme classified as "none"
- No `version` field in response → same treatment (invalid response)
- Checksums API no `"checksums"` key → treated as unexpected; reports error and exits

## Cross-References

- [Concept: Update Status Classification](../concepts/update-status-classification.md)
