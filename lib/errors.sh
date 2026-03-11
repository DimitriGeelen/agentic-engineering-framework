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

# --- Color setup (via shared lib/colors.sh) ---
# Resolve framework root for sourcing (errors.sh may be sourced before paths.sh)
_ERRORS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$_ERRORS_DIR/colors.sh" 2>/dev/null || {
    # Inline fallback if colors.sh is missing
    if [[ ( -t 1 || -t 2 ) && -z "${NO_COLOR:-}" ]]; then
        RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[1;33m'
        CYAN='\033[0;36m' BOLD='\033[1m' NC='\033[0m'
    else
        RED='' GREEN='' YELLOW='' CYAN='' BOLD='' NC=''
    fi
}
unset _ERRORS_DIR

# --- Output functions ---

die() {
    local msg="$1"
    local code="${2:-1}"
    echo -e "${RED}ERROR: ${msg}${NC}" >&2
    exit "$code"
}

error() {
    echo -e "${RED}ERROR: ${1}${NC}" >&2
}

warn() {
    echo -e "${YELLOW}WARNING: ${1}${NC}" >&2
}

info() {
    echo -e "${CYAN}${1}${NC}"
}

success() {
    echo -e "${GREEN}${1}${NC}"
}

block() {
    # For PreToolUse hooks — exit 2 tells Claude Code to block the action
    local msg="$1"
    echo -e "${RED}BLOCKED: ${msg}${NC}" >&2
    exit 2
}
