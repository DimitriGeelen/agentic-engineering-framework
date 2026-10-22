#!/bin/bash
# lib/hook-degraded.sh — fail-closed fallback for the PreToolUse gates (T-4652)
#
# check-tier0.sh and check-project-boundary.sh decode the hook payload and run their
# matchers in python3. When python3 is missing, broken, or the matcher crashes, the
# decoded command is empty and both hooks used to `exit 0` — every tool call allowed,
# no message. This library is the bash-only scan they fall back to: it greps the RAW
# payload (no decoding, no python) and blocks on a hit.
#
#   hook_python_ok                      0 when python3 can import what the hooks need
#   hook_degraded_tier0   INPUT WHY     exit 2 on a destructive keyword, else warn + return
#   hook_degraded_boundary INPUT WHY    exit 2 on a foreign absolute path, else warn + return
#
# Over-blocking is the accepted trade-off and only happens while degraded: the scan sees
# the escaped JSON text, so a destructive word inside prose or a heredoc blocks too.

hook_python_ok() {
    python3 -c 'import sys, json, re, os, hashlib' >/dev/null 2>&1
}

_hook_degraded_banner() {
    # $1 hook name, $2 reason, $3 verdict line
    echo "" >&2
    echo "══════════════════════════════════════════════════════════" >&2
    echo "  HOOK DEGRADED — $1 cannot run its python matcher" >&2
    echo "══════════════════════════════════════════════════════════" >&2
    echo "  Why:   $2" >&2
    echo "  $3" >&2
}

_hook_degraded_warn() {
    echo "WARNING: $1 is DEGRADED ($2); bash-only scan found nothing, allowing. Fix python3 on PATH." >&2
}

hook_degraded_tier0() {
    local input="$1" why="$2"
    local pat='(^|[^[:alnum:]_])rm[[:space:]]+(-[[:alnum:]]*[rR]|--recursive)|git[[:space:]].*push[[:space:]].*(--force|-f([[:space:]"\\]|$)|[[:space:]]\+[[:alnum:]_./-])|reset[[:space:]]+--hard|git[[:space:]].*branch[[:space:]]+(-D|--delete[[:space:]]+--force)|git[[:space:]]+clean[[:space:]]+-[[:alnum:]]*f|DROP[[:space:]]+(TABLE|DATABASE|SCHEMA)|TRUNCATE[[:space:]]|mkfs|dd[[:space:]]+if=|tier0'
    if printf '%s' "$input" | grep -qEi -- "$pat"; then
        _hook_degraded_banner "check-tier0" "$why" "The raw payload matches a Tier 0 keyword, so the call is BLOCKED (fail closed)."
        echo "  This may over-block while degraded. Repair python3 (it must import json, re," >&2
        echo "  os, hashlib) or ask the operator to approve." >&2
        echo "  Policy: T-4652 (hooks must not fail open)" >&2
        echo "══════════════════════════════════════════════════════════" >&2
        exit 2
    fi
    _hook_degraded_warn "check-tier0" "$why"
    return 0
}

hook_degraded_boundary() {
    local input="$1" why="$2" root="${PROJECT_ROOT:-}" home="${BOUNDARY_HOME:-}"
    local rest="$input"
    # Remove everything that is legitimately ours, then look for any other project-ish path.
    [ -n "$root" ] && rest="${rest//"$root"/}"
    [ -n "$home" ] && rest="${rest//"$home/.claude"/}"
    rest="${rest//\/root\/.claude/}"
    rest="${rest//\/root\/.local/}"
    if printf '%s' "$rest" | grep -qE '(/opt/[A-Za-z0-9._-]|/home/[A-Za-z0-9._-]|/root/[A-Za-z0-9._-]|/srv/[A-Za-z0-9._-]|/mnt/[A-Za-z0-9._-])'; then
        _hook_degraded_banner "check-project-boundary" "$why" "The raw payload names an absolute path outside this project, so the call is BLOCKED (fail closed)."
        echo "  Project root: ${root:-unknown}" >&2
        echo "  This may over-block while degraded. Repair python3 (it must import json, re," >&2
        echo "  os, hashlib) and retry." >&2
        echo "  Policy: T-4652 (hooks must not fail open)" >&2
        echo "══════════════════════════════════════════════════════════" >&2
        exit 2
    fi
    _hook_degraded_warn "check-project-boundary" "$why"
    return 0
}
