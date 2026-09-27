#!/usr/bin/env bash
# T-2338 (arc-011 M1 §2) — harness yield-point spike.
#
# Single-host cooperative-poll mechanism. The orchestrator writes a flag file
# at .context/working/.dispatch-flag with content like:
#
#   refuse-write:/abs/path/that/conflicts
#
# Workers invoke `yield-point.sh check <target_path>` before each Write/Edit.
# If the flag is present AND its content matches the target path, the script
# prints a refusal on stderr and exits non-zero — the worker treats the
# non-zero exit as "do not write".
#
# Design properties:
#   - Pure file polling, zero IPC dependency. Works on single host without
#     TermLink.
#   - Stale flag protection: flag older than FW_YIELD_STALE_SECS (default 300s)
#     is ignored with a WARN — orchestrator was meant to clean up, didn't.
#   - Malformed flag: refused parse with WARN, write allowed (fail-open by
#     design — a broken orchestrator signal must not deadlock workers).
#   - Multi-path support: flag may contain multiple "refuse-write:" lines;
#     ANY match triggers refusal.
#
# Exit codes:
#   0  write allowed (no flag, no matching path, stale flag, malformed flag)
#   1  write refused (flag present + path matches)
#   64 usage error

set -u

YP_FLAG_DEFAULT=".context/working/.dispatch-flag"
YP_STALE_SECS_DEFAULT=300

_usage() {
    cat <<'EOF'
agents/dispatch/yield-point.sh — single-host cooperative-poll yield point (T-2338)

Usage:
    yield-point.sh check <target_path>

Reads .context/working/.dispatch-flag and refuses writes to target_path
when the flag contains "refuse-write:<target_path>".

Environment overrides:
    FW_YIELD_FLAG       — path to flag file (default: .context/working/.dispatch-flag)
    FW_YIELD_STALE_SECS — stale-flag threshold in seconds (default: 300)

Exit codes:
    0  write allowed
    1  write refused (flag matched)
    64 usage error
EOF
}

_check() {
    local target="${1:-}"
    if [ -z "$target" ]; then
        echo "usage: yield-point.sh check <target_path>" >&2
        return 64
    fi
    local flag="${FW_YIELD_FLAG:-$YP_FLAG_DEFAULT}"
    local stale_secs="${FW_YIELD_STALE_SECS:-$YP_STALE_SECS_DEFAULT}"

    # No flag → write allowed (the common case).
    [ -e "$flag" ] || return 0

    # Stale flag → ignored with WARN.
    local now mtime age
    now=$(date +%s)
    if mtime=$(stat -c %Y "$flag" 2>/dev/null || stat -f %m "$flag" 2>/dev/null); then
        age=$((now - mtime))
        if [ "$age" -gt "$stale_secs" ]; then
            echo "WARN: dispatch flag at $flag is stale (${age}s > ${stale_secs}s) — ignoring" >&2
            return 0
        fi
    fi

    # Parse refuse-write: lines. Tolerate CRLF and trailing whitespace.
    local matched=0 line clean rule path_re
    # Normalize target — strip trailing slash, leave as-is otherwise (we do
    # path-string comparison, not path resolution; the orchestrator decides
    # what canonical form to write).
    path_re="${target%/}"

    while IFS= read -r line || [ -n "$line" ]; do
        # Strip CR and surrounding whitespace
        clean="${line%$'\r'}"
        clean="${clean#"${clean%%[![:space:]]*}"}"
        clean="${clean%"${clean##*[![:space:]]}"}"
        [ -z "$clean" ] && continue
        case "$clean" in
            refuse-write:*)
                rule="${clean#refuse-write:}"
                rule="${rule#"${rule%%[![:space:]]*}"}"
                rule="${rule%"${rule##*[![:space:]]}"}"
                if [ "$rule" = "$path_re" ]; then
                    matched=1
                    break
                fi
                ;;
            \#*)
                ;;  # comment, ignore
            *)
                ;;  # unknown directive, ignore (fail-open)
        esac
    done < "$flag"

    if [ "$matched" -eq 1 ]; then
        echo "refusing write to $target (matched refuse-write: rule in $flag)" >&2
        return 1
    fi

    # Malformed flag with no parsable refuse-write: line and content present
    # — already returned 0 from the loop fall-through. We default to allow.
    return 0
}

main() {
    local cmd="${1:-}"
    shift || true
    case "$cmd" in
        check)
            _check "$@"
            return $?
            ;;
        ""|--help|-h|help)
            _usage
            return 0
            ;;
        *)
            echo "ERROR: unknown subcommand: $cmd" >&2
            _usage >&2
            return 64
            ;;
    esac
}

main "$@"
