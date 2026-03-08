#!/bin/bash
# lib/compat.sh — Cross-platform compatibility helpers
#
# Source this file to get portable shell functions that work on
# both GNU (Linux) and BSD (macOS) systems.
#
# Usage: source "$FRAMEWORK_ROOT/lib/compat.sh"

# Portable in-place sed edit.
# Works on both GNU sed (Linux) and BSD sed (macOS).
# Usage: _sed_i 'expression' file
_sed_i() {
    local expr="$1" file="$2"
    if [ ! -f "$file" ]; then
        echo "ERROR: _sed_i: file not found: $file" >&2
        return 1
    fi
    local tmp
    tmp=$(mktemp "${file}.XXXXXX") || return 1
    if sed "$expr" "$file" > "$tmp"; then
        mv "$tmp" "$file"
    else
        rm -f "$tmp"
        return 1
    fi
}
