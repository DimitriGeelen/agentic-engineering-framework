#!/bin/bash
# lib/yaml.sh — Shared YAML frontmatter field extraction
#
# Provides get_yaml_field() to replace the inconsistent
# grep/sed/cut patterns duplicated across 30+ files.
#
# Usage: source "$FRAMEWORK_ROOT/lib/yaml.sh"

# Guard against double-sourcing
[[ -n "${_FW_YAML_LOADED:-}" ]] && return 0
_FW_YAML_LOADED=1

# Extract a YAML frontmatter field value from a file
# Handles: quoted values, leading whitespace, colon-containing values
# Usage: get_yaml_field /path/to/file.md "status"
# Returns: field value on stdout, or empty string if not found
get_yaml_field() {
    local file="$1"
    local field="$2"
    grep "^${field}:" "$file" 2>/dev/null | head -1 | sed "s/^${field}:[[:space:]]*//" | sed 's/^"//;s/"$//' | sed "s/^'//;s/'$//"
}
