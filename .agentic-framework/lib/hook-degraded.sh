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
    # T-4851: one class per fast-path keyword in check-tier0.sh — that filter decides
    # what reaches the matcher, so every class it sends there must block here too.
    # tests/unit/t4851_degraded_gate_classes.bats fails when a keyword has no case.
    local e='([[:space:]"\\]|$)' b='(^|[^[:alnum:]_])'
    local pat="${b}rm[[:space:]]+(-[[:alnum:]]*[rR]|--recursive)"
    pat+="|git[[:space:]].*push[[:space:]](.*[[:space:]])?(-[[:alnum:]]*[fd][[:alnum:]]*$e|--fo|--d|\+[[:alnum:]_./-]|:[^[:space:]\"\\])"
    pat+="|git[[:space:]].*reset[[:space:]].*--h|git[[:space:]].*clean[[:space:]].*-[[:alnum:]]*f"
    pat+="|git[[:space:]].*(checkout|restore)[[:space:]]+\.([[:space:];&|)\"\\]|$)"
    pat+="|git[[:space:]].*branch[[:space:]](.*[[:space:]])?(-[[:alpha:]]*D|--d.*--f|--f.*--d)"
    pat+="|git[[:space:]].*commit[^;|&]*[[:space:]]-[[:alpha:]]*n|--no-v|hookspath|include\.path|includeif"
    pat+="|${b}(HOME|XDG_CONFIG_HOME|GIT_CONFIG[[:alnum:]_]*)=.*git[[:space:]].*(push|commit|merge|pull|rebase|am|cherry-pick|revert)$e"
    pat+="|DROP[[:space:]]+(TABLE|DATABASE|SCHEMA)|TRUNCATE[[:space:]]|mkfs|dd[[:space:]]+if=|tier0"
    pat+="|docker[[:space:]]+system|kubectl[[:space:]]+delete|find[[:space:]].*-delete|chmod[[:space:]].*[[:space:]]000"
    pat+="|${b}(pkill|killall)[[:space:]]|kill-se|${b}fw[[:space:]].*--force|${b}fw[[:space:]].*inception[[:space:]].*decide"
    # The fast path also scans a dequoted copy (tier""0) and sends ANSI-C quoting
    # ($'...') to python unread; while degraded, both are blocked here.
    local dq; dq=$(printf '%s' "$input" | tr -d "\"'\\\\\$")
    if [[ "$input" == *"\$'"* ]] || printf '%s\n%s\n' "$input" "$dq" | grep -qEi -- "$pat"; then
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
    # T-4852: system roots are refused only on a WRITE — reads (`cat /etc/os-release`,
    # `/usr/bin/env`, `2>/dev/null`) stay allowed. A write is a redirect, a write verb,
    # dd of=, a cd into the root, or a Write/Edit tool aimed at it.
    local sys='/(etc|usr|var|boot)([/"[:space:]\\]|$)'
    local wverb='(^|[^[:alnum:]_.-])(tee|cp|mv|install|ln|rsync|dd|sed|perl|truncate|chmod|chown|chgrp|touch|mkdir|rm|rmdir|unlink|shred|patch|tar|unzip|curl|wget)[[:space:]][^|;&]*'
    local wtool='"tool_name"[[:space:]]*:[[:space:]]*"(Write|Edit|MultiEdit|NotebookEdit)"'
    if printf '%s' "$rest" | grep -qE -- ">[>|]?[[:space:]]*$sys|$wverb$sys|of=$sys|(^|[^[:alnum:]_])(cd|pushd)[[:space:]]+$sys" \
       || { printf '%s' "$rest" | grep -qE -- "$wtool" \
            && printf '%s' "$rest" | grep -qE -- "\"(file_path|notebook_path)\"[[:space:]]*:[[:space:]]*\"$sys"; }; then
        _hook_degraded_banner "check-project-boundary" "$why" "The raw payload writes under a system root (/etc /usr /var /boot), so the call is BLOCKED (fail closed)."
        echo "  Project root: ${root:-unknown}" >&2
        echo "  This may over-block while degraded. Repair python3 (it must import json, re," >&2
        echo "  os, hashlib) and retry." >&2
        echo "  Policy: T-4652, T-4852 (hooks must not fail open)" >&2
        echo "══════════════════════════════════════════════════════════" >&2
        exit 2
    fi
    _hook_degraded_warn "check-project-boundary" "$why"
    return 0
}
