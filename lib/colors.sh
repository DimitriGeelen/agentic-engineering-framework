#!/bin/bash
# lib/colors.sh — Shared color variables for the Agentic Engineering Framework
#
# Provides TTY-aware, NO_COLOR-respecting color variables.
# Replaces inline color definitions duplicated across 20+ scripts.
#
# Usage: source "$FRAMEWORK_ROOT/lib/colors.sh"
#
# Variables: RED, GREEN, YELLOW, CYAN, BOLD, NC
#
# Automatically sourced via lib/errors.sh → lib/paths.sh chain.
# Scripts that source lib/paths.sh get colors for free.

# Guard against double-sourcing
[[ -n "${_FW_COLORS_LOADED:-}" ]] && return 0
_FW_COLORS_LOADED=1

# TTY-aware, NO_COLOR-aware color setup
# Check both stdout and stderr — scripts may redirect one or the other
if [[ ( -t 1 || -t 2 ) && -z "${NO_COLOR:-}" ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    DIM='\033[2m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' CYAN='' BOLD='' DIM='' NC=''
fi
