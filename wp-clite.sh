#!/bin/bash

# -----------------------------------------------------------------------------
# WP-CLite — WP-CLI "Lite" Edition
# Version: 2.1.0
#
# Manages WordPress plugin and theme updates without requiring WP-CLI or
# direct database access. Uses the WordPress.org REST API for version and
# compatibility data, and downloads files directly from WordPress.org.
#
# Features:
#   --dry-run              Simulate updates without making changes.
#   --log [file]           Log actions to a file (default: timestamped name).
#   --yes / --auto-yes     Automatically approve all updates (no prompts).
#   --plugins-only         Update only plugins.
#   --themes-only          Update only themes.
#   --no-git               Skip all git operations.
#   --minor                Only update within the same major version (e.g. 2.x).
#   --patch                Only update within the same major.minor (e.g. 2.1.x).
#   --skip-update-check    List installed items without querying the API.
#   --verify-checksums     Verify WP core file integrity via checksums API.
#   --maintenance-mode     Write .maintenance to WP root during updates.
#   --wp-path <path>       Path to WordPress root (default: current directory).
#   --wp-version <ver>     Override detected WP version for compat checks.
#   --php-version <ver>    Override detected PHP version for compat checks.
#   --help                 Show this help message.
# -----------------------------------------------------------------------------

# ---- Flags & Defaults -------------------------------------------------------
DRY_RUN=0
LOG_FILE=""
AUTO_YES=0
PLUGINS_ONLY=0
THEMES_ONLY=0
NO_GIT=0
SHOW_HELP=0
MINOR_ONLY=0
PATCH_ONLY=0
SKIP_UPDATE_CHECK=0
VERIFY_CHECKSUMS=0
MAINTENANCE_MODE=0
WP_PATH="."
WP_VERSION_OVERRIDE=""
PHP_VERSION_OVERRIDE=""

# ---- Counters ---------------------------------------------------------------
COUNT_UPDATED=0
COUNT_UPTODATE=0
COUNT_UNAVAILABLE=0
COUNT_PINNED=0
COUNT_SKIPPED=0
COUNT_FAILED=0

# ---- Help -------------------------------------------------------------------
show_help() {
    echo "Usage: bash $0 [options]"
    echo
    echo "Options:"
    echo "  --dry-run              Simulate updates without making changes."
    echo "  --log [file]           Write actions to a log file (default: timestamped name)."
    echo "  --yes / --auto-yes     Automatically approve all updates."
    echo "  --plugins-only         Only update plugins."
    echo "  --themes-only          Only update themes."
    echo "  --no-git               Skip all git operations."
    echo "  --minor                Only update within the same major version."
    echo "  --patch                Only update within the same major.minor version."
    echo "  --skip-update-check    List installed versions; skip all API queries."
    echo "  --verify-checksums     Verify WP core file integrity via checksums API."
    echo "  --maintenance-mode     Create .maintenance in WP root during updates."
    echo "  --wp-path <path>       Path to WordPress root (default: current directory)."
    echo "  --wp-version <ver>     Override WP version for compatibility checks."
    echo "  --php-version <ver>    Override PHP version for compatibility checks."
    echo "  --help                 Show this help message."
    echo
    echo "Examples:"
    echo "  bash $0 --wp-path /var/www/html --dry-run --log update.log"
    echo "  bash $0 --wp-path /var/www/html --patch --yes --maintenance-mode"
    echo "  bash $0 --wp-path /var/www/html --verify-checksums"
    echo "  bash $0 --wp-path /var/www/html --plugins-only --skip-update-check"
}

# ---- Dependencies -----------------------------------------------------------
check_dependencies() {
    local missing_critical=() missing_optional=()

    if ! command -v curl >/dev/null 2>&1; then
        if [ "$SKIP_UPDATE_CHECK" -eq 0 ]; then
            missing_critical+=("curl      — needed for WordPress.org API queries and plugin/theme downloads")
        else
            missing_optional+=("curl      — needed to download updates (not required with --skip-update-check)")
        fi
    fi

    if ! command -v unzip >/dev/null 2>&1; then
        if [ "$DRY_RUN" -eq 0 ] && [ "$SKIP_UPDATE_CHECK" -eq 0 ]; then
            missing_critical+=("unzip     — needed to extract downloaded plugin/theme zip archives")
        else
            missing_optional+=("unzip     — needed to extract archives when applying updates")
        fi
    fi

    if [ "$VERIFY_CHECKSUMS" -eq 1 ] && ! command -v python3 >/dev/null 2>&1; then
        missing_critical+=("python3   — needed for --verify-checksums (JSON parsing and MD5 hashing)")
    fi

    if [ "$NO_GIT" -eq 0 ] && ! command -v git >/dev/null 2>&1; then
        missing_optional+=("git       — not found; git commits will be skipped (suppress with --no-git)")
    fi

    if [ ${#missing_critical[@]} -gt 0 ] || [ ${#missing_optional[@]} -gt 0 ]; then
        echo "=== Dependency Check ==="
        echo
    fi

    if [ ${#missing_critical[@]} -gt 0 ]; then
        echo "❌ Missing required tools:"
        for dep in "${missing_critical[@]}"; do echo "     • $dep"; done
        echo
    fi

    if [ ${#missing_optional[@]} -gt 0 ]; then
        echo "⚠️  Missing optional tools:"
        for dep in "${missing_optional[@]}"; do echo "     • $dep"; done
        echo
    fi

    if [ ${#missing_critical[@]} -gt 0 ]; then
        echo "Install the missing tool(s) above and re-run, or adjust your flags to work around them."
        echo
        exit 1
    fi
}

# ---- Argument Parsing -------------------------------------------------------
INVOKED_CMD="$0 $*"
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=1
            NO_GIT=1
            shift ;;
        --log)
            if [[ -z "${2:-}" || "${2:-}" == --* ]]; then
                LOG_FILE="wp-update-logfile-$(date +%Y%m%d-%H%M%S).txt"
                shift
            else
                LOG_FILE="$2"; shift 2
            fi ;;
        --yes|--auto-yes)    AUTO_YES=1; shift ;;
        --plugins-only)      PLUGINS_ONLY=1; shift ;;
        --themes-only)       THEMES_ONLY=1; shift ;;
        --no-git)            NO_GIT=1; shift ;;
        --minor)             MINOR_ONLY=1; shift ;;
        --patch)             PATCH_ONLY=1; shift ;;
        --skip-update-check) SKIP_UPDATE_CHECK=1; shift ;;
        --verify-checksums)  VERIFY_CHECKSUMS=1; shift ;;
        --maintenance-mode)  MAINTENANCE_MODE=1; shift ;;
        --wp-path)           WP_PATH="${2:-.}"; shift 2 ;;
        --wp-version)        WP_VERSION_OVERRIDE="$2"; shift 2 ;;
        --php-version)       PHP_VERSION_OVERRIDE="$2"; shift 2 ;;
        --help|-h)           SHOW_HELP=1; shift ;;
        *)                   shift ;;
    esac
done

# ---- Log Setup --------------------------------------------------------------
: "${LOG_FILE:=wp-update-logfile-$(date +%Y%m%d-%H%M%S).txt}"
echo "$INVOKED_CMD" > "$LOG_FILE"
echo >> "$LOG_FILE"
exec > >(tee -a "$LOG_FILE") 2>&1

if [ "$SHOW_HELP" -eq 1 ]; then
    show_help
    echo
    read -r -p "Press Enter to exit..." _dummy
    exit 0
fi

check_dependencies

# ---- Paths ------------------------------------------------------------------
WP_PATH="${WP_PATH%/}"

if [ -d "${WP_PATH}/wp-content/plugins" ]; then
    PLUGIN_DIR="${WP_PATH}/wp-content/plugins"
    THEME_DIR="${WP_PATH}/wp-content/themes"
else
    PLUGIN_DIR="${WP_PATH}/plugins"
    THEME_DIR="${WP_PATH}/themes"
fi

TEMP_DIR="/tmp/wp-updates-$$"
MAINTENANCE_FILE="${WP_PATH}/.maintenance"

# ---- Environment Detection --------------------------------------------------
detect_wp_version() {
    local vfile="${WP_PATH}/wp-includes/version.php"
    [ -f "$vfile" ] && grep -o "\$wp_version = '[^']*'" "$vfile" | cut -d"'" -f2 || echo ""
}

detect_php_version() {
    command -v php >/dev/null 2>&1 \
        && php -r "echo PHP_MAJOR_VERSION . '.' . PHP_MINOR_VERSION . '.' . PHP_RELEASE_VERSION;" \
        || echo ""
}

if [ -n "$WP_VERSION_OVERRIDE" ]; then
    INSTALLED_WP_VERSION="$WP_VERSION_OVERRIDE"
else
    INSTALLED_WP_VERSION=$(detect_wp_version)
fi

if [ -n "$PHP_VERSION_OVERRIDE" ]; then
    INSTALLED_PHP_VERSION="$PHP_VERSION_OVERRIDE"
else
    INSTALLED_PHP_VERSION=$(detect_php_version)
fi

[ -n "$INSTALLED_WP_VERSION" ] \
    && echo "Detected WP version:  $INSTALLED_WP_VERSION" \
    || echo "⚠️  Could not detect WP version (use --wp-version to override)."
[ -n "$INSTALLED_PHP_VERSION" ] \
    && echo "Detected PHP version: $INSTALLED_PHP_VERSION" \
    || echo "⚠️  Could not detect PHP version (use --php-version to override)."
echo

[ "$DRY_RUN" -eq 1 ]           && echo "Starting DRY RUN — no real changes will be made." && echo
[ "$SKIP_UPDATE_CHECK" -eq 1 ] && echo "Note: --skip-update-check is active; WordPress.org API queries skipped." && echo

# ---- Directory Validation ---------------------------------------------------
if [ "$THEMES_ONLY" -eq 0 ] && [ ! -d "$PLUGIN_DIR" ]; then
    echo "Error: Plugins directory not found: ${PLUGIN_DIR}"
    echo "Use --wp-path to specify your WordPress root directory."
    exit 1
fi

if [ "$PLUGINS_ONLY" -eq 0 ] && [ ! -d "$THEME_DIR" ]; then
    echo "Error: Themes directory not found: ${THEME_DIR}"
    echo "Use --wp-path to specify your WordPress root directory."
    exit 1
fi

mkdir -p "$TEMP_DIR"

# ---- Maintenance Mode -------------------------------------------------------
enable_maintenance_mode() {
    if [ "$MAINTENANCE_MODE" -eq 1 ] && [ "$DRY_RUN" -eq 0 ]; then
        printf '<?php $upgrading = %s; ?>\n' "$(date +%s)" > "$MAINTENANCE_FILE"
        echo "🔒 Maintenance mode enabled."
    fi
}

disable_maintenance_mode() {
    if [ "$MAINTENANCE_MODE" -eq 1 ] && [ "$DRY_RUN" -eq 0 ]; then
        rm -f "$MAINTENANCE_FILE"
        echo "🔓 Maintenance mode disabled."
    fi
}

# ---- Version Utilities ------------------------------------------------------

# Returns 0 (true) if installed version $1 satisfies requirement $2.
version_gte() {
    local installed="$1" required="$2"
    [ -z "$required" ] && return 0
    [ "$(printf '%s\n' "$required" "$installed" | sort -V | head -n1)" = "$required" ]
}

# Returns 0 (true) if updating from $1 to $2 is allowed under --minor/--patch.
update_allowed_by_pinning() {
    local current="$1" latest="$2"
    if [ "$PATCH_ONLY" -eq 1 ]; then
        [ "$(echo "$current" | cut -d. -f1,2)" = "$(echo "$latest" | cut -d. -f1,2)" ]
    elif [ "$MINOR_ONLY" -eq 1 ]; then
        [ "$(echo "$current" | cut -d. -f1)" = "$(echo "$latest" | cut -d. -f1)" ]
    else
        return 0
    fi
}

# Echoes one of: available | unavailable | pinned | none
# Args: current latest req_wp req_php
get_update_status() {
    local current="$1" latest="$2" req_wp="$3" req_php="$4"

    if [ -z "$latest" ] || [ "$latest" = "N/A" ] || [ "$current" = "$latest" ]; then
        echo "none"; return
    fi

    if [ -n "$req_wp" ] && [ -n "$INSTALLED_WP_VERSION" ]; then
        version_gte "$INSTALLED_WP_VERSION" "$req_wp" || { echo "unavailable"; return; }
    fi

    if [ -n "$req_php" ] && [ -n "$INSTALLED_PHP_VERSION" ]; then
        version_gte "$INSTALLED_PHP_VERSION" "$req_php" || { echo "unavailable"; return; }
    fi

    update_allowed_by_pinning "$current" "$latest" || { echo "pinned"; return; }

    echo "available"
}

# ---- WordPress.org API ------------------------------------------------------

# Echoes "latest_version|requires_wp|requires_php" or "N/A||" on failure.
# Args: $1=type (plugin|theme)  $2=slug
query_wp_api() {
    local type="$1" slug="$2" url response

    if [ "$type" = "plugin" ]; then
        url="https://api.wordpress.org/plugins/info/1.0/${slug}.json"
    else
        url="https://api.wordpress.org/themes/info/1.2/?action=theme_information&request%5Bslug%5D=${slug}"
    fi

    response=$(curl -sf "$url") || { echo "N/A||"; return; }
    [[ "$response" != *'"version"'* ]] && { echo "N/A||"; return; }

    local version requires req_php
    version=$(echo  "$response" | grep -o '"version":"[^"]*"'      | head -1 | cut -d'"' -f4)
    requires=$(echo "$response" | grep -o '"requires":"[^"]*"'     | head -1 | cut -d'"' -f4)
    req_php=$(echo  "$response" | grep -o '"requires_php":"[^"]*"' | head -1 | cut -d'"' -f4)
    echo "${version}|${requires}|${req_php}"
}

# ---- Header Parsers ---------------------------------------------------------
get_plugin_name()    { grep -i "Plugin Name:"                    "$1" 2>/dev/null | head -1 | sed 's/.*Plugin Name:[[:space:]]*//' | sed 's/[[:space:]]*$//'; }
get_plugin_version() { grep -i "^[[:space:]]*\*[[:space:]]*Version:" "$1" 2>/dev/null | head -1 | sed 's/.*Version:[[:space:]]*//'    | sed 's/[[:space:]]*$//'; }
get_plugin_slug()    { dirname "$1" | xargs basename; }
get_theme_name()     { grep -i "^Theme Name:"                    "$1" 2>/dev/null | head -1 | sed 's/.*Theme Name:[[:space:]]*//'  | sed 's/[[:space:]]*$//'; }
get_theme_version()  { grep -i "^Version:"                       "$1" 2>/dev/null | head -1 | sed 's/.*Version:[[:space:]]*//'     | sed 's/[[:space:]]*$//'; }
get_theme_slug() {
    local dir="$1" slug
    slug=$(grep -i "^Text Domain:" "${dir}/style.css" 2>/dev/null | head -1 | sed 's/.*Text Domain:[[:space:]]*//' | sed 's/[[:space:]]*$//')
    [ -z "$slug" ] && slug=$(basename "$dir")
    echo "$slug"
}

# ---- Git Operations ---------------------------------------------------------
check_git() {
    if ! command -v git >/dev/null 2>&1; then
        echo "Git not installed. Skipping version control."; return 1
    fi
    if ! git -C "$WP_PATH" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "Not a git repository. Skipping version control."; return 1
    fi
    return 0
}

git_handle_update() {
    local name="$1" old_ver="$2" new_ver="$3" path="$4"
    [ "$NO_GIT" -eq 1 ] && return 0
    if check_git; then
        echo "Adding changes to git..."
        git add "$path"
        git commit -m "chore: ${name} update from v${old_ver} to v${new_ver}"
        echo "✅ Git commit created"
    fi
}

# ---- Download & Install -----------------------------------------------------

# Unified installer for plugins and themes.
# Args: $1=type (plugin|theme)  $2=slug  $3=version  $4=name  $5=old_version
do_update() {
    local type="$1" slug="$2" version="$3" name="$4" old_version="$5"
    local target_dir zip_file extract_dir

    if [ "$type" = "plugin" ]; then
        target_dir="$PLUGIN_DIR"
        zip_file="${TEMP_DIR}/${slug}.zip"
    else
        target_dir="$THEME_DIR"
        zip_file="${TEMP_DIR}/${slug}-theme.zip"
    fi
    extract_dir="${TEMP_DIR}/extract-${slug}"

    echo "Downloading ${type} ${slug} v${version}..."
    if curl -L --fail -o "$zip_file" "https://downloads.wordpress.org/${type}/${slug}.${version}.zip"; then
        mkdir -p "$extract_dir"
        unzip -q -o "$zip_file" -d "$extract_dir"
        if [ -d "${extract_dir}/${slug}" ]; then
            rm -rf "${target_dir:?}/${slug}"
            mv "${extract_dir}/${slug}" "${target_dir}/"
            echo "✅ Updated ${type} '${name}' (${slug}) to v${version}"
            COUNT_UPDATED=$((COUNT_UPDATED + 1))
            git_handle_update "$name" "$old_version" "$version" "${target_dir}/${slug}"
        else
            echo "❌ Extracted directory '${slug}' not found — the ${type} slug may differ."
            COUNT_FAILED=$((COUNT_FAILED + 1))
        fi
        rm -f "$zip_file"
        rm -rf "$extract_dir"
    else
        echo "❌ Download failed for ${type} ${slug} v${version}"
        COUNT_FAILED=$((COUNT_FAILED + 1))
    fi
}

# ---- Checksum Verification --------------------------------------------------
# Mirrors WP-CLI v2.12.0 'wp core verify-checksums'.
verify_wp_checksums() {
    if ! command -v python3 >/dev/null 2>&1; then
        echo "⚠️  python3 is required for --verify-checksums but was not found. Skipping."
        return 1
    fi
    if [ -z "$INSTALLED_WP_VERSION" ]; then
        echo "⚠️  WP version could not be detected; use --wp-version to specify it. Skipping."
        return 1
    fi

    echo "Fetching WP core checksums for v${INSTALLED_WP_VERSION}..."
    local response
    response=$(curl -sf \
        "https://api.wordpress.org/core/checksums/1.0/?version=${INSTALLED_WP_VERSION}&locale=en_US") \
        || { echo "❌ Could not reach the WordPress.org checksums API."; return 1; }

    if [[ "$response" != *'"checksums"'* ]]; then
        echo "❌ Unexpected response from checksums API (version may not exist in the API)."
        return 1
    fi

    local result
    result=$(printf '%s' "$response" | WP_ROOT="$WP_PATH" python3 - <<'PYEOF'
import sys, json, hashlib, os
wp_root = os.environ["WP_ROOT"]
data = json.load(sys.stdin)
checksums = data.get("checksums", {})
failures = []
for rel_path, expected_md5 in checksums.items():
    full_path = os.path.join(wp_root, rel_path)
    if not os.path.exists(full_path):
        continue
    with open(full_path, "rb") as f:
        actual = hashlib.md5(f.read()).hexdigest()
    if actual != expected_md5:
        failures.append(rel_path)
if not failures:
    print("OK")
else:
    for f in failures:
        print("MISMATCH: " + f)
PYEOF
)

    if echo "$result" | grep -q "^MISMATCH:"; then
        echo "⚠️  WP core checksum mismatches detected:"
        echo "$result" | grep "^MISMATCH:" | sed 's/^MISMATCH: /   - /'
        echo "   These files may have been modified or corrupted."
    else
        echo "✅ WordPress core checksums verified. No modifications detected."
    fi
}

# ---- Scanner ----------------------------------------------------------------

# Scans plugins or themes, checks for updates, and prompts to apply them.
# Args: $1=type (plugin|theme)
scan_extensions() {
    local type="$1"
    local label dir
    [ "$type" = "plugin" ] && { label="plugins"; dir="$PLUGIN_DIR"; } \
                           || { label="themes";  dir="$THEME_DIR";  }

    echo "Scanning ${label}..."
    printf '%.0s=' $(seq 1 $((${#label} + 10))); echo

    declare -a entries=()

    if [ "$type" = "plugin" ]; then
        while IFS= read -r file; do
            grep -q "Plugin Name:" "$file" 2>/dev/null || continue
            local p_name p_ver p_slug
            p_name=$(get_plugin_name "$file")
            p_ver=$(get_plugin_version "$file")
            p_slug=$(get_plugin_slug "$file")
            [ -z "$p_name" ] || [ -z "$p_ver" ] || [ -z "$p_slug" ] && continue
            entries+=("${p_name}|${p_ver}|${p_slug}")
        done < <(find "$dir" -maxdepth 2 -type f -name "*.php")
    else
        while IFS= read -r d; do
            local style_file="${d}/style.css"
            [ -f "$style_file" ] || continue
            local t_name t_ver t_slug
            t_name=$(get_theme_name "$style_file")
            t_ver=$(get_theme_version "$style_file")
            t_slug=$(get_theme_slug "$d")
            [ -z "$t_name" ] || [ -z "$t_ver" ] || [ -z "$t_slug" ] && continue
            entries+=("${t_name}|${t_ver}|${t_slug}")
        done < <(find "$dir" -mindepth 1 -maxdepth 1 -type d)
    fi

    local name current_ver slug
    for entry in "${entries[@]}"; do
        IFS='|' read -r name current_ver slug <<< "$entry"

        if [ "$SKIP_UPDATE_CHECK" -eq 1 ]; then
            printf "%-40s Current: v%-12s Latest: %s\n" "$name" "$current_ver" "(skipped)"
            COUNT_SKIPPED=$((COUNT_SKIPPED + 1))
            continue
        fi

        local latest_ver req_wp req_php
        IFS='|' read -r latest_ver req_wp req_php \
            <<< "$(query_wp_api "$type" "$slug")"

        local status
        status=$(get_update_status "$current_ver" "$latest_ver" "$req_wp" "$req_php")

        printf "%-40s Current: v%-12s Latest: v%-12s" "$name" "$current_ver" "$latest_ver"

        case "$status" in
            none)
                echo " [up to date]"
                COUNT_UPTODATE=$((COUNT_UPTODATE + 1))
                ;;
            unavailable)
                echo " [unavailable — requires WP≥${req_wp} / PHP≥${req_php}]"
                COUNT_UNAVAILABLE=$((COUNT_UNAVAILABLE + 1))
                ;;
            pinned)
                echo " [pinned by version constraint]"
                COUNT_PINNED=$((COUNT_PINNED + 1))
                ;;
            available)
                echo " [UPDATE AVAILABLE]"
                if [ "$DRY_RUN" -eq 1 ]; then
                    echo "  → (dry run) would update to v${latest_ver}"
                    COUNT_UPDATED=$((COUNT_UPDATED + 1))
                elif [ "$AUTO_YES" -eq 1 ]; then
                    do_update "$type" "$slug" "$latest_ver" "$name" "$current_ver"
                else
                    local _confirm
                    read -r -p "  → Update '${name}' to v${latest_ver}? [y/N] " _confirm
                    if [[ "$_confirm" =~ ^[Yy]$ ]]; then
                        do_update "$type" "$slug" "$latest_ver" "$name" "$current_ver"
                    else
                        echo "  → Skipped."
                        COUNT_SKIPPED=$((COUNT_SKIPPED + 1))
                    fi
                fi
                ;;
        esac
        echo
    done
}

# =============================================================================
# Main Execution
# =============================================================================

enable_maintenance_mode

if [ "$VERIFY_CHECKSUMS" -eq 1 ]; then
    echo "=== WP Core Checksum Verification ==="
    verify_wp_checksums
    echo
fi

[ "$THEMES_ONLY"  -eq 0 ] && scan_extensions plugin
[ "$PLUGINS_ONLY" -eq 0 ] && scan_extensions theme

disable_maintenance_mode
echo "Cleaning up temporary files..."
rm -rf "$TEMP_DIR"
echo "✅ Cleanup complete"
echo

# ---- Summary ----------------------------------------------------------------
echo "================================"
echo "          Update Summary        "
echo "================================"
[ "$DRY_RUN" -eq 1 ] && echo "  (DRY RUN — no files changed)"
printf "  %-14s %d\n" "Updated:"     "$COUNT_UPDATED"
printf "  %-14s %d\n" "Up to date:"  "$COUNT_UPTODATE"
printf "  %-14s %d\n" "Unavailable:" "$COUNT_UNAVAILABLE"
printf "  %-14s %d\n" "Pinned:"      "$COUNT_PINNED"
printf "  %-14s %d\n" "Skipped:"     "$COUNT_SKIPPED"
printf "  %-14s %d\n" "Failed:"      "$COUNT_FAILED"
echo "================================"
