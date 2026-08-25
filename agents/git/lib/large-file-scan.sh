#!/usr/bin/env bash
# agents/git/lib/large-file-scan.sh — Large-file gate for the pre-commit hook (T-1845).
#
# Origin: T-1828/T-1834 force-push surfaced two tracked binaries — an accidental
# 36MB ImageMagick PostScript at repo root, and a 78MB sqlite-vec index in
# .context/working/ — both flagged by GitHub as oversized objects in history.
# Sibling prevention class to T-1844 (secret-scan): same structural gap (no
# pre-commit gate against accidentally-tracked artefacts), same fix shape.
#
# This module is invoked by the pre-commit hook installed by
# agents/git/lib/hooks.sh:install_hooks. It can also be run standalone:
#
#   large-file-scan.sh scan-staged       Scan git staged paths (the hook's mode)
#   large-file-scan.sh scan-tree         Scan the entire tracked tree (audit mode)
#   large-file-scan.sh scan-file <path>  Scan a specific file
#
# Configuration (env, with .framework.yaml fallbacks):
#   FW_LARGE_FILE_BLOCK_BYTES   Block threshold     (default 10485760 = 10 MiB)
#   FW_LARGE_FILE_WARN_BYTES    Warning threshold   (default  1048576 =  1 MiB)
#   .large-file-allowlist       Path-prefix patterns, one per line; matching
#                               files are exempt from BOTH block and warn

set -u
set -o pipefail

_lf_project_root() {
    [ -n "${PROJECT_ROOT:-}" ] && [ -d "$PROJECT_ROOT" ] && { echo "$PROJECT_ROOT"; return; }
    local dir="$PWD"
    while [ "$dir" != "/" ]; do
        # T-3129: `-e` covers both a `.git` directory and the `.git` FILE a
        # linked worktree carries. With `-d` the walk-up sailed past a worktree
        # root and resolved the scan against the wrong tree.
        if [ -e "$dir/.git" ] || [ -f "$dir/FRAMEWORK.md" ] || [ -f "$dir/.framework.yaml" ]; then
            echo "$dir"
            return
        fi
        dir="$(dirname "$dir")"
    done
    echo "$PWD"
}

_lf_config_dir() {
    local root="$1"
    [ -f "$root/.large-file-allowlist" ] && { echo "$root"; return; }
    [ -f "$root/.agentic-framework/.large-file-allowlist" ] && { echo "$root/.agentic-framework"; return; }
    echo "$root"
}

_lf_threshold_block() {
    local v="${FW_LARGE_FILE_BLOCK_BYTES:-}"
    [ -n "$v" ] && { echo "$v"; return; }
    echo 10485760
}

_lf_threshold_warn() {
    local v="${FW_LARGE_FILE_WARN_BYTES:-}"
    [ -n "$v" ] && { echo "$v"; return; }
    echo 1048576
}

_lf_human_size() {
    local b="$1"
    awk -v b="$b" 'BEGIN {
        if (b > 1073741824) printf "%.1f GiB", b/1073741824;
        else if (b > 1048576) printf "%.1f MiB", b/1048576;
        else if (b > 1024) printf "%.1f KiB", b/1024;
        else printf "%d B", b;
    }'
}

_lf_build_allowlist() {
    local f="$1"
    [ ! -f "$f" ] && { echo ""; return; }
    grep -v '^[[:space:]]*$' "$f" 2>/dev/null \
        | grep -v '^[[:space:]]*#' \
        | tr '\n' '|' \
        | sed 's/|$//'
}

_lf_is_allowed() {
    local path="$1" allow_re="$2"
    [ -z "$allow_re" ] && return 1
    echo "$path" | grep -qE -e "$allow_re"
}

# Public: scan staged content. Iterates the staged path list (added or modified)
# and reports any whose blob size in the index exceeds the block threshold.
# Allowlist entries (path-prefix patterns) suppress matches.
scan_staged() {
    local root cfg allowlist
    root="$(_lf_project_root)"
    cfg="$(_lf_config_dir "$root")"
    allowlist="$cfg/.large-file-allowlist"

    local block warn allow_re
    block="$(_lf_threshold_block)"
    warn="$(_lf_threshold_warn)"
    allow_re="$(_lf_build_allowlist "$allowlist")"

    local hits=0 warns=0
    local path size
    while IFS= read -r path; do
        [ -z "$path" ] && continue
        if _lf_is_allowed "$path" "$allow_re"; then
            continue
        fi
        # Resolve the staged blob size (index-side, the bytes that would land in the commit).
        size=$(git -C "$root" cat-file -s ":$path" 2>/dev/null || echo 0)
        [ -z "$size" ] && size=0
        if [ "$size" -ge "$block" ]; then
            printf '  [BLOCK] %s — %s (threshold %s)\n' \
                "$path" "$(_lf_human_size "$size")" "$(_lf_human_size "$block")"
            hits=$((hits + 1))
        elif [ "$size" -ge "$warn" ]; then
            printf '  [WARN]  %s — %s (warn threshold %s)\n' \
                "$path" "$(_lf_human_size "$size")" "$(_lf_human_size "$warn")"
            warns=$((warns + 1))
        fi
    done < <(git -C "$root" diff --cached --name-only --diff-filter=AM 2>/dev/null)

    if [ "$warns" -gt 0 ] && [ "$hits" -eq 0 ]; then
        echo "large-file-scan: $warns file(s) above warn threshold (not blocking)" >&2
    fi

    [ "$hits" -gt 0 ] && return 1
    return 0
}

# Public: scan entire tracked tree. Surfaces existing bloat — used by `fw doctor`
# and audit, and by the human-AC step for T-1845 to validate cleanup is complete.
scan_tree() {
    local root cfg allowlist
    root="$(_lf_project_root)"
    cfg="$(_lf_config_dir "$root")"
    allowlist="$cfg/.large-file-allowlist"

    local block warn allow_re
    block="$(_lf_threshold_block)"
    warn="$(_lf_threshold_warn)"
    allow_re="$(_lf_build_allowlist "$allowlist")"

    local hits=0 warns=0
    local path size
    while IFS= read -r path; do
        [ -z "$path" ] && continue
        if _lf_is_allowed "$path" "$allow_re"; then
            continue
        fi
        size=$(stat -c %s "$root/$path" 2>/dev/null || echo 0)
        [ "$size" = "0" ] && continue
        if [ "$size" -ge "$block" ]; then
            printf '  [BLOCK] %s — %s\n' "$path" "$(_lf_human_size "$size")"
            hits=$((hits + 1))
        elif [ "$size" -ge "$warn" ]; then
            printf '  [WARN]  %s — %s\n' "$path" "$(_lf_human_size "$size")"
            warns=$((warns + 1))
        fi
    done < <(git -C "$root" ls-files 2>/dev/null)

    if [ "$hits" -gt 0 ]; then return 1; fi
    return 0
}

# Public: scan a specific file (working-tree size).
scan_file() {
    local file="${1:-}"
    [ -z "$file" ] && { echo "usage: scan-file <path>" >&2; return 2; }
    [ ! -f "$file" ] && { echo "scan-file: not found: $file" >&2; return 2; }
    local root cfg allowlist
    root="$(_lf_project_root)"
    cfg="$(_lf_config_dir "$root")"
    allowlist="$cfg/.large-file-allowlist"
    local block warn allow_re
    block="$(_lf_threshold_block)"
    warn="$(_lf_threshold_warn)"
    allow_re="$(_lf_build_allowlist "$allowlist")"
    local size
    size=$(stat -c %s "$file" 2>/dev/null || echo 0)
    if _lf_is_allowed "$file" "$allow_re"; then
        echo "$file: $(_lf_human_size "$size") (allowlisted)"
        return 0
    fi
    if [ "$size" -ge "$block" ]; then
        printf '  [BLOCK] %s — %s\n' "$file" "$(_lf_human_size "$size")"
        return 1
    elif [ "$size" -ge "$warn" ]; then
        printf '  [WARN]  %s — %s\n' "$file" "$(_lf_human_size "$size")"
        return 0
    fi
    echo "$file: $(_lf_human_size "$size") (ok)"
    return 0
}

_lf_main() {
    local cmd="${1:-scan-staged}"
    shift || true
    case "$cmd" in
        scan-staged|scan_staged) scan_staged "$@" ;;
        scan-tree|scan_tree)     scan_tree "$@" ;;
        scan-file|scan_file)     scan_file "$@" ;;
        -h|--help|help)
            cat <<USAGE
large-file-scan.sh — Pre-commit large-file gate (T-1845)

Subcommands:
  scan-staged       Scan git staged paths (pre-commit hook mode)
  scan-tree         Scan all tracked files (audit mode)
  scan-file <path>  Scan a specific file

Configuration (env):
  FW_LARGE_FILE_BLOCK_BYTES  Block threshold  (default 10 MiB)
  FW_LARGE_FILE_WARN_BYTES   Warning threshold (default 1 MiB)

Allowlist:
  .large-file-allowlist  Path-prefix regexes for legitimate vendored cases
USAGE
            return 0
            ;;
        *) echo "large-file-scan: unknown subcommand: $cmd" >&2; return 2 ;;
    esac
}

if [ "${BASH_SOURCE[0]}" = "$0" ] || [ -z "${BASH_SOURCE[0]:-}" ]; then
    _lf_main "$@"
fi
