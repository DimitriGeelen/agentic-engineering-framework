#!/bin/bash
# lib/errors.sh — Consistent error/warning/info output for the framework
#
# Provides colored, TTY-aware output functions with standardized exit codes.
# Replaces ad-hoc echo/exit patterns across 25+ agent scripts.
#
# Usage: source "$FRAMEWORK_ROOT/lib/errors.sh"
#
# Functions:
#   die MESSAGE [EXIT_CODE]   — Print error and exit (default: 1)
#   error MESSAGE             — Print error to stderr (no exit)
#   warn MESSAGE              — Print warning to stderr
#   info MESSAGE              — Print info to stdout
#   success MESSAGE           — Print success to stdout
#   block MESSAGE             — Print error to stderr and exit 2 (hook blocking)
#
# Exit code convention:
#   0 — Success
#   1 — General error
#   2 — Blocking error (PreToolUse hook convention: blocks tool execution)

# Guard against double-sourcing
[[ -n "${_FW_ERRORS_LOADED:-}" ]] && return 0
_FW_ERRORS_LOADED=1

# --- Color setup (TTY-aware) ---
if [[ -t 2 ]] && [[ -z "${NO_COLOR:-}" ]]; then
    _ERR_RED='\033[0;31m'
    _ERR_GREEN='\033[0;32m'
    _ERR_YELLOW='\033[1;33m'
    _ERR_CYAN='\033[0;36m'
    _ERR_BOLD='\033[1m'
    _ERR_NC='\033[0m'
else
    _ERR_RED='' _ERR_GREEN='' _ERR_YELLOW='' _ERR_CYAN='' _ERR_BOLD='' _ERR_NC=''
fi

# --- Output functions ---

die() {
    local msg="$1"
    local code="${2:-1}"
    echo -e "${_ERR_RED}ERROR: ${msg}${_ERR_NC}" >&2
    exit "$code"
}

error() {
    echo -e "${_ERR_RED}ERROR: ${1}${_ERR_NC}" >&2
}

warn() {
    echo -e "${_ERR_YELLOW}WARNING: ${1}${_ERR_NC}" >&2
}

info() {
    echo -e "${_ERR_CYAN}${1}${_ERR_NC}"
}

success() {
    echo -e "${_ERR_GREEN}${1}${_ERR_NC}"
}

block() {
    # For PreToolUse hooks — exit 2 tells Claude Code to block the action
    local msg="$1"
    echo -e "${_ERR_RED}BLOCKED: ${msg}${_ERR_NC}" >&2
    exit 2
}
