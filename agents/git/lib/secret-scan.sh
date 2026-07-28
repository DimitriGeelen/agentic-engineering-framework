#!/usr/bin/env bash
# agents/git/lib/secret-scan.sh — Secret-scan library for the pre-commit hook (T-1844).
#
# Origin: T-1828/T-1834 incident — an Azure DevOps PAT was committed to framework
# history at 79e3361d (T-1736 spike). GitHub mirror blocked for 9+ hours.
# The framework had no structural gate against secrets reaching commits.
#
# This module is invoked by the pre-commit hook installed by
# agents/git/lib/hooks.sh:install_hooks. It can also be run standalone:
#
#   secret-scan.sh scan-staged       Scan git staged diff (the hook's mode)
#   secret-scan.sh scan-tree         Scan the entire working tree (audit mode)
#   secret-scan.sh scan-file <path>  Scan a specific file
#
# Configuration:
#   .secret-scan-patterns   TSV catalogue (name<TAB>regex)
#   .secret-scan-allowlist  One regex per line; matching findings suppressed
#
# Optional escalation:
#   If `gitleaks` is on PATH, run it as a second pass and treat any finding
#   as a match. The baseline regex catalogue is the always-on guarantee.

set -u
set -o pipefail

# Resolve the project root in framework / consumer / arbitrary cwd shapes.
_secret_scan_project_root() {
    # If PROJECT_ROOT is set by the caller, trust it.
    [ -n "${PROJECT_ROOT:-}" ] && [ -d "$PROJECT_ROOT" ] && { echo "$PROJECT_ROOT"; return; }
    # Else walk up from cwd looking for a .git or FRAMEWORK.md / .framework.yaml
    local dir="$PWD"
    while [ "$dir" != "/" ]; do
        if [ -d "$dir/.git" ] || [ -f "$dir/FRAMEWORK.md" ] || [ -f "$dir/.framework.yaml" ]; then
            echo "$dir"
            return
        fi
        dir="$(dirname "$dir")"
    done
    echo "$PWD"
}

# Resolve the secret-scan config dir: prefer project-local files in the project
# root, fall back to a vendored .agentic-framework/ copy for consumers.
_secret_scan_config_dir() {
    local root="$1"
    if [ -f "$root/.secret-scan-patterns" ]; then
        echo "$root"
        return
    fi
    if [ -f "$root/.agentic-framework/.secret-scan-patterns" ]; then
        echo "$root/.agentic-framework"
        return
    fi
    # No config — return root anyway; the scanner will report "no patterns".
    echo "$root"
}

# Build the allowlist regex (pipe-joined) from the allowlist file.
_secret_scan_build_allowlist() {
    local allow_file="$1"
    [ ! -f "$allow_file" ] && { echo ""; return; }
    # Strip blank lines + comments; pipe-join the rest with '|'.
    local _joined
    _joined=$(grep -v '^[[:space:]]*$' "$allow_file" 2>/dev/null \
              | grep -v '^[[:space:]]*#' \
              | tr '\n' '|' \
              | sed 's/|$//')
    echo "$_joined"
}

# Check whether a given "filepath:linecontent" string matches the allowlist.
_secret_scan_is_allowed() {
    local hit_line="$1" allow_re="$2"
    [ -z "$allow_re" ] && return 1
    echo "$hit_line" | grep -qE -e "$allow_re"
}

# Core scanner: takes a stream of "filepath:linenumber:linecontent" rows on stdin,
# emits hits to stdout. Returns 0 if no hits, 1 if any hit.
_secret_scan_run_patterns() {
    local patterns_file="$1" allow_re="$2"
    [ ! -f "$patterns_file" ] && { echo "secret-scan: no patterns file ($patterns_file)" >&2; return 0; }

    local _hits=0
    local _input
    _input=$(cat)
    [ -z "$_input" ] && return 0

    local _name _re
    while IFS=$'\t' read -r _name _re; do
        # Skip comments + blank lines
        case "$_name" in ''|\#*) continue ;; esac
        [ -z "$_re" ] && continue

        # Find lines matching the pattern. `-e` ensures patterns starting with
        # `-` (e.g. `-----BEGIN ...`) aren't interpreted as grep options. We
        # don't pass `-n` because the awk-prepared input already encodes
        # "filepath:diffline:content"; prefixing grep's own line number would
        # break allowlist regexes anchored at `^`.
        local _matches
        _matches=$(echo "$_input" | grep -E -e "$_re" 2>/dev/null || true)
        [ -z "$_matches" ] && continue

        while IFS= read -r _hit; do
            [ -z "$_hit" ] && continue
            if _secret_scan_is_allowed "$_hit" "$allow_re"; then
                continue
            fi
            printf '  [%s] %s\n' "$_name" "$_hit"
            _hits=$((_hits + 1))
        done <<< "$_matches"
    done < "$patterns_file"

    [ "$_hits" -gt 0 ] && return 1
    return 0
}

# Public: scan staged content via `git diff --cached`. This is the pre-commit
# hook's primary mode.
scan_staged() {
    local root cfg patterns allowlist
    root="$(_secret_scan_project_root)"
    cfg="$(_secret_scan_config_dir "$root")"
    patterns="$cfg/.secret-scan-patterns"
    allowlist="$cfg/.secret-scan-allowlist"

    local allow_re
    allow_re="$(_secret_scan_build_allowlist "$allowlist")"

    # Format: walk the staged diff, prefix each added line with file:line:
    # — this gives the regex run a stable "filepath:linenumber:content" shape.
    local diff_stream
    diff_stream=$(git -C "$root" diff --cached -U0 2>/dev/null | awk '
        /^diff --git/ { in_file=0; next }
        /^\+\+\+ b\// { file=substr($0, 7); in_file=1; next }
        in_file && /^@@/ {
            n=split($0, parts, " ")
            for (i=1; i<=n; i++) {
                if (parts[i] ~ /^\+/) {
                    sub(/^\+/, "", parts[i])
                    split(parts[i], lc, ",")
                    line_no=lc[1]
                }
            }
            next
        }
        in_file && /^\+[^+]/ {
            content=substr($0, 2)
            printf "%s:%d:%s\n", file, line_no, content
            line_no++
        }
        in_file && /^[^+-]/ { line_no++ }
    ')

    local rc=0
    if [ -n "$diff_stream" ]; then
        echo "$diff_stream" | _secret_scan_run_patterns "$patterns" "$allow_re" || rc=1
    fi

    # Optional escalation: gitleaks (best-effort, never blocks if missing)
    if command -v gitleaks >/dev/null 2>&1; then
        local gl_out
        gl_out=$(gitleaks protect --staged --redact --no-banner 2>&1) || {
            # gitleaks exit 1 = findings. Report and mark rc=1.
            echo "  [gitleaks] $gl_out" | head -10
            rc=1
        }
    fi

    return "$rc"
}

# Public: scan the entire working tree (audit mode). Used by the human-AC
# step to surface pre-existing matches that need allowlisting.
scan_tree() {
    local root cfg patterns allowlist
    root="$(_secret_scan_project_root)"
    cfg="$(_secret_scan_config_dir "$root")"
    patterns="$cfg/.secret-scan-patterns"
    allowlist="$cfg/.secret-scan-allowlist"

    local allow_re
    allow_re="$(_secret_scan_build_allowlist "$allowlist")"

    # Use git grep per pattern — handles binary skip + path filtering natively,
    # and runs entirely in-process (no per-file fork to `file`).
    [ ! -f "$patterns" ] && { echo "secret-scan: no patterns file ($patterns)" >&2; return 0; }

    local _hits=0
    local _name _re _matches
    while IFS=$'\t' read -r _name _re; do
        case "$_name" in ''|\#*) continue ;; esac
        [ -z "$_re" ] && continue
        # git grep flags: -n line nos, -I skip binary, -E extended regex, --no-color
        # Use -e to handle patterns starting with dashes.
        _matches=$(git -C "$root" grep -nIE --no-color -e "$_re" -- ':!.git' 2>/dev/null || true)
        [ -z "$_matches" ] && continue
        # git grep output: "path:lineno:content" — that's already the format
        # _secret_scan_is_allowed expects.
        while IFS= read -r _hit; do
            [ -z "$_hit" ] && continue
            if _secret_scan_is_allowed "$_hit" "$allow_re"; then
                continue
            fi
            printf '  [%s] %s\n' "$_name" "$_hit"
            _hits=$((_hits + 1))
        done <<< "$_matches"
    done < "$patterns"

    [ "$_hits" -gt 0 ] && return 1
    return 0
}

# Public: scan a specific file.
scan_file() {
    local file="$1"
    [ -z "$file" ] && { echo "usage: scan-file <path>" >&2; return 2; }
    [ ! -f "$file" ] && { echo "scan-file: not found: $file" >&2; return 2; }
    local root cfg patterns allowlist
    root="$(_secret_scan_project_root)"
    cfg="$(_secret_scan_config_dir "$root")"
    patterns="$cfg/.secret-scan-patterns"
    allowlist="$cfg/.secret-scan-allowlist"
    local allow_re
    allow_re="$(_secret_scan_build_allowlist "$allowlist")"
    awk -v file="$file" '{ printf "%s:%d:%s\n", file, NR, $0 }' "$file" \
        | _secret_scan_run_patterns "$patterns" "$allow_re"
}

# Entry point when invoked as a script.
_secret_scan_main() {
    local cmd="${1:-scan-staged}"
    shift || true
    case "$cmd" in
        scan-staged|scan_staged) scan_staged "$@" ;;
        scan-tree|scan_tree)     scan_tree "$@" ;;
        scan-file|scan_file)     scan_file "$@" ;;
        -h|--help|help)
            cat <<USAGE
secret-scan.sh — Pre-commit secret scanner (T-1844)

Subcommands:
  scan-staged       Scan git staged diff (pre-commit hook mode)
  scan-tree         Scan entire working tree (audit mode)
  scan-file <path>  Scan a specific file

Configuration:
  .secret-scan-patterns   TSV pattern catalogue
  .secret-scan-allowlist  Suppress known false-positives
USAGE
            return 0
            ;;
        *) echo "secret-scan: unknown subcommand: $cmd" >&2; return 2 ;;
    esac
}

# Only run main when invoked as a script, not when sourced.
if [ "${BASH_SOURCE[0]}" = "$0" ] || [ -z "${BASH_SOURCE[0]:-}" ]; then
    _secret_scan_main "$@"
fi
