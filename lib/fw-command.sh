#!/usr/bin/env bash
# lib/fw-command.sh — the shell builder for every fw command the framework PRINTS
# (rule T-5302 GO; builder T-5303; moved here T-5304).
#
# Every command printed for a person or an agent is
#     cd <absolute project root> && <fw path> <args>
# with <fw path> = bin/fw in the framework repo (FRAMEWORK.md + bin/fw at the
# root) and .agentic-framework/bin/fw in a vendored project. Never bare `fw`:
# the PATH fw is not the T-2793 router on every host (ring20 .122 keeps the old
# fw-shim) nor on every PATH a worker or hook runs with (1409). Never
# bin/watchtower.sh: Watchtower is `<fw path> watchtower ...`.
#
# Python twin: lib/fw_command.py; Watchtower global: fw_cmd. Parity is pinned by
# tests/unit/test_t5303_fw_command_builder.py. Args are ONE pre-formed string,
# concatenated unchanged (no re-quoting: printf %q and shlex.quote differ);
# only the root is quoted, with shlex.quote rules (_fw_quote_word).
#
# Sourceable and side-effect free by contract (same contract as
# lib/worktree-identity.sh, T-3111): no `set -e`, no exports, no output on
# source, no path resolution. bin/fw sources it (it cannot source lib/paths.sh,
# which resolves and exports paths as a side effect); lib/paths.sh sources it
# too, so every agent keeps the old function names. The functions read
# PROJECT_ROOT as they find it when called (falling back to $PWD), or take the
# root as an argument (_fw_cmd ROOT, _emit_user_command_in ROOT ARGS).

[ -n "${_FW_COMMAND_LOADED:-}" ] && return 0
_FW_COMMAND_LOADED=1

# _fw_cmd [ROOT] — the project-relative fw path to print.
_fw_cmd() {
    local root="${1:-${PROJECT_ROOT:-$PWD}}"
    if [ -f "$root/FRAMEWORK.md" ] && [ -f "$root/bin/fw" ]; then
        echo "bin/fw"
    else
        echo ".agentic-framework/bin/fw"
    fi
}

# shlex.quote, in bash: unchanged when every char is [A-Za-z0-9@%+=:,./_-],
# else single-quoted with ' written as '"'"'.
_fw_quote_word() {
    local LC_ALL=C s="$1" sq="'" rep="'\"'\"'"
    if [ -z "$s" ]; then
        printf "''"
    elif [[ "$s" =~ ^[A-Za-z0-9@%+=:,./_-]+$ ]]; then
        printf '%s' "$s"
    else
        printf "'%s'" "${s//$sq/$rep}"
    fi
}

# _emit_user_command_in ROOT [ARGS] — `cd <abs ROOT> && <fw path> ARGS`, newline-terminated.
_emit_user_command_in() {
    local root="${1:-${PROJECT_ROOT:-$PWD}}"
    case "$root" in /*) ;; *) root="$(cd "$root" 2>/dev/null && pwd || printf '%s' "$root")" ;; esac
    if [ -n "${2:-}" ]; then
        printf 'cd %s && %s %s\n' "$(_fw_quote_word "$root")" "$(_fw_cmd "$root")" "$2"
    else
        printf 'cd %s && %s\n' "$(_fw_quote_word "$root")" "$(_fw_cmd "$root")"
    fi
}

# Emit a full copy-pasteable command with cd prefix (T-609/T-1102/T-5303)
# Usage: _emit_user_command "inception decide T-XXX go"
_emit_user_command() {
    _emit_user_command_in "${PROJECT_ROOT:-$PWD}" "${1:-}"
}
