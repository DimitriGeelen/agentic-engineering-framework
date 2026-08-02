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
# Returns: field value on stdout, or empty string if not found.
# Pipefail-safe: returns 0 even when the field is absent (T-1557 / L-302).
# T-2731: two defects in the previous one-line implementation, both silent:
#
#   (a) it grepped the WHOLE file, so a body line beginning `name:` was a
#       candidate. `head -1` hid this whenever frontmatter also had the field
#       and exposed it whenever frontmatter did not.
#   (b) it kept only the FIRST PHYSICAL LINE of the value, truncating every
#       multi-line scalar mid-sentence and returning a bare `>` or `|` for block
#       scalars.
#
# Both now handled: the search is scoped to the frontmatter block when the file
# begins with `---`, and continuation lines are folded onto one line with a
# single space, which is what YAML means by a line break inside a folded or
# double-quoted scalar.
#
# Measured before changing (T-2731): over 2717 task files x 9 fields, `id`,
# `status`, `owner`, `workflow_type`, `created` and `last_update` are
# byte-identical under both implementations. Only `name` (1041 files),
# `description` (2717) and `tags` (15) differ, and in every case the new value
# is the complete one. Of the six live callers only `name` is read
# (healing/diagnose, healing/suggest, healing/resolve, resume) — those now show
# the whole task name instead of a truncated one.
get_yaml_field() {
    local file="$1"
    local field="$2"
    local block

    if [ "$(head -1 "$file" 2>/dev/null)" = "---" ]; then
        block=$(sed -n '2,/^---$/p' "$file" 2>/dev/null)
    else
        block=$(cat "$file" 2>/dev/null)
    fi

    printf '%s\n' "$block" \
        | awk -v f="^${field}:" '
            $0 ~ f {
                found = 1
                sub(/^[^:]*:[[:space:]]*/, "")
                if ($0 ~ /^[|>][+-]?$/) $0 = ""      # block scalar indicator
                printf "%s", $0
                next
            }
            found {
                if ($0 ~ /^[A-Za-z_#-]/ || $0 ~ /^---/) exit   # next top-level key
                sub(/^[[:space:]]+/, "")
                if ($0 != "") printf " %s", $0
            }
            END { if (found) print "" }' \
        | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' \
        | sed 's/^"//;s/"$//' | sed "s/^'//;s/'$//"
}
