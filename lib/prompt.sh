#!/bin/bash
# fw prompt — reusable agent-prompt register (T-1283)
#
# Subcommands:
#   create   Create a new prompt file under prompts/
#   list     List all prompts
#   show     Print the body of a prompt (frontmatter stripped)
#   copy     Print the body with {{var}} substitutions applied
#
# Prompt file schema: markdown with YAML frontmatter.
#   ---
#   id: <slug>                     # filename stem; unique within this repo
#   qid: <agent-id>/P-NNN          # cross-fleet stable reference (B2)
#   agent_id: <agent-id>           # originating host id (B2)
#   counter: NNN                   # sequential within originating agent (B2)
#   name: <string>
#   description: <string>
#   kind: agent|system|user
#   tags: [csv]
#   variables: [csv of {{var}} names]
#   created: <ISO-8601>
#   updated: <ISO-8601>
#   ---
#   <prompt body, may contain {{var}} placeholders>

set -uo pipefail

_prompt_dir() {
    printf '%s' "${PROJECT_ROOT:-$PWD}/prompts"
}

_prompt_path() {
    local id="$1"
    printf '%s/%s.md' "$(_prompt_dir)" "$id"
}

_prompt_slug() {
    # Lowercase, replace non-alphanumerics with hyphen, trim.
    printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]\+/-/g; s/^-\+//; s/-\+$//'
}

_prompt_iso_now() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

_prompt_resolve_agent_id() {
    # Env override beats everything.
    if [ -n "${FW_AGENT_ID:-}" ]; then
        printf '%s' "$FW_AGENT_ID"
        return 0
    fi
    # Explicit config in .framework.yaml
    local cfg="${PROJECT_ROOT:-$PWD}/.framework.yaml"
    if [ -f "$cfg" ]; then
        local cfg_id
        cfg_id=$(awk -F: '/^agent_id:/ {sub(/^[[:space:]]+/,"",$2); sub(/[[:space:]]+$/,"",$2); gsub(/"/,"",$2); print $2; exit}' "$cfg")
        if [ -n "$cfg_id" ]; then
            printf '%s' "$cfg_id"
            return 0
        fi
    fi
    # Derive from last octet of first non-loopback IPv4.
    local ip
    ip=$(hostname -I 2>/dev/null | awk '{for(i=1;i<=NF;i++) if ($i ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/ && $i != "127.0.0.1") {print $i; exit}}')
    if [ -n "$ip" ]; then
        printf '%s' "${ip##*.}"
        return 0
    fi
    printf '%s' "local"
}

_prompt_counter_file() {
    printf '%s' "${PROJECT_ROOT:-$PWD}/.context/working/.prompt-counter"
}

_prompt_next_counter() {
    local file; file="$(_prompt_counter_file)"
    mkdir -p "$(dirname "$file")"
    [ -f "$file" ] || echo 0 > "$file"
    local next
    if command -v flock >/dev/null 2>&1; then
        next=$(flock "$file" bash -c '
            cur=$(cat "$1" 2>/dev/null)
            [ -z "$cur" ] && cur=0
            n=$((cur + 1))
            echo "$n" > "$1"
            printf "%s" "$n"
        ' _ "$file")
    else
        local cur; cur=$(cat "$file" 2>/dev/null)
        [ -z "$cur" ] && cur=0
        next=$((cur + 1))
        echo "$next" > "$file"
    fi
    printf '%s' "$next"
}

_prompt_format_qid() {
    # Format counter as zero-padded 3-digit inside agent-id/P- prefix.
    local agent_id="$1" counter="$2"
    printf '%s/P-%03d' "$agent_id" "$counter"
}

_prompt_resolve_qid() {
    # Given an FQID (e.g., 107/P-042), print the local slug if found.
    local qid="$1"
    local dir; dir="$(_prompt_dir)"
    [ -d "$dir" ] || return 1
    local f
    for f in "$dir"/*.md; do
        [ -f "$f" ] || continue
        [ "$(basename "$f")" = "README.md" ] && continue
        local file_qid
        file_qid="$(_prompt_get_field "$f" qid)"
        if [ "$file_qid" = "$qid" ]; then
            basename "$f" .md
            return 0
        fi
    done
    return 1
}

_prompt_find_path() {
    # Accepts a local slug OR an FQID (<agent-id>/P-NNN); prints the file path.
    local ref="$1"
    local direct; direct="$(_prompt_path "$ref")"
    if [ -f "$direct" ]; then
        printf '%s' "$direct"
        return 0
    fi
    if [[ "$ref" == */P-* ]]; then
        local slug
        if slug="$(_prompt_resolve_qid "$ref")"; then
            printf '%s' "$(_prompt_path "$slug")"
            return 0
        fi
    fi
    return 1
}

_prompt_extract_vars() {
    # Extract unique {{var}} names from stdin.
    # grep returns non-zero on no-match; swallow that to 0 so callers
    # under `set -e` don't blow up on bodies without placeholders.
    local all
    all=$(cat)
    printf '%s' "$all" \
        | grep -oE '\{\{[a-zA-Z_][a-zA-Z0-9_]*\}\}' 2>/dev/null \
        | sed 's/[{}]//g' \
        | sort -u \
        | tr '\n' ',' | sed 's/,$//' || true
}

_prompt_get_field() {
    # Read a top-level YAML frontmatter field from a prompt file.
    local file="$1" key="$2"
    awk -v k="$key" '
        BEGIN { in_fm = 0; found = 0 }
        /^---$/ { in_fm = !in_fm; if (!in_fm && found) exit; next }
        in_fm && $0 ~ "^" k ":" {
            sub("^" k ":[[:space:]]*", "")
            gsub(/^"/, ""); gsub(/"$/, "")
            print; found = 1; exit
        }
    ' "$file"
}

_prompt_body() {
    # Print body (everything after the closing frontmatter ---).
    awk '
        BEGIN { seen = 0; in_fm = 0 }
        /^---$/ {
            if (!seen) { in_fm = 1; seen = 1; next }
            else if (in_fm) { in_fm = 0; next }
        }
        !in_fm && seen { print }
    ' "$1"
}

do_prompt_create() {
    local name="" description="" kind="agent" tags="" body="" id=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --name) name="$2"; shift 2 ;;
            --description) description="$2"; shift 2 ;;
            --kind) kind="$2"; shift 2 ;;
            --tags) tags="$2"; shift 2 ;;
            --body) body="$2"; shift 2 ;;
            --id) id="$2"; shift 2 ;;
            -h|--help)
                cat <<'EOF'
fw prompt create - Create a prompt file

Usage: fw prompt create --name "NAME" [options]

Options:
  --name NAME         Human-readable name (required)
  --description DESC  One-line description
  --kind KIND         agent | system | user (default: agent)
  --tags "a,b"        Comma-separated tags
  --body TEXT         Prompt text (can include {{var}} placeholders)
  --id SLUG           Explicit slug id (default: derived from --name)
EOF
                return 0
                ;;
            *)
                echo "Unknown argument: $1" >&2
                return 2
                ;;
        esac
    done

    if [ -z "$name" ]; then
        echo "ERROR: --name is required" >&2
        return 2
    fi
    case "$kind" in agent|system|user) ;; *)
        echo "ERROR: --kind must be agent|system|user (got: $kind)" >&2
        return 2
    ;; esac

    [ -z "$id" ] && id="$(_prompt_slug "$name")"
    local dir; dir="$(_prompt_dir)"
    mkdir -p "$dir"
    local path; path="$(_prompt_path "$id")"

    if [ -e "$path" ]; then
        echo "ERROR: prompt already exists: $path" >&2
        return 1
    fi

    local variables; variables="$(printf '%s' "$body" | _prompt_extract_vars)"
    local now; now="$(_prompt_iso_now)"
    local agent_id; agent_id="$(_prompt_resolve_agent_id)"
    local counter; counter="$(_prompt_next_counter)"
    local qid; qid="$(_prompt_format_qid "$agent_id" "$counter")"

    {
        printf -- '---\n'
        printf 'id: %s\n' "$id"
        printf 'qid: %s\n' "$qid"
        printf 'agent_id: %s\n' "$agent_id"
        printf 'counter: %s\n' "$counter"
        printf 'name: "%s"\n' "$name"
        printf 'description: "%s"\n' "$description"
        printf 'kind: %s\n' "$kind"
        printf 'tags: [%s]\n' "$tags"
        printf 'variables: [%s]\n' "$variables"
        printf 'created: %s\n' "$now"
        printf 'updated: %s\n' "$now"
        printf -- '---\n\n'
        printf '%s\n' "$body"
    } > "$path"

    echo "Created: $path"
    echo "  QID: $qid"
    if [ -n "$variables" ]; then
        echo "  Variables: $variables"
    fi
    return 0
}

do_prompt_list() {
    local dir; dir="$(_prompt_dir)"
    if [ ! -d "$dir" ]; then
        echo "No prompts directory yet (expected: $dir)" >&2
        return 0
    fi
    local count=0
    local f
    for f in "$dir"/*.md; do
        [ -f "$f" ] || continue
        [ "$(basename "$f")" = "README.md" ] && continue
        local id qid name kind tags
        id="$(_prompt_get_field "$f" id)"
        qid="$(_prompt_get_field "$f" qid)"
        name="$(_prompt_get_field "$f" name)"
        kind="$(_prompt_get_field "$f" kind)"
        tags="$(_prompt_get_field "$f" tags)"
        printf '%-28s  %-14s  %-8s  %-30s  %s\n' "${id:-?}" "${qid:--}" "${kind:-?}" "${name:-?}" "${tags:-}"
        count=$((count + 1))
    done
    if [ "$count" = 0 ]; then
        echo "(no prompts yet — use 'fw prompt create')"
    fi
    return 0
}

do_prompt_show() {
    local id="${1:-}"
    if [ -z "$id" ]; then
        echo "Usage: fw prompt show <id|qid>" >&2
        return 2
    fi
    local path
    if ! path="$(_prompt_find_path "$id")"; then
        echo "ERROR: prompt not found: $id" >&2
        return 1
    fi
    _prompt_body "$path"
}

do_prompt_copy() {
    local id="" raw=0
    declare -A vars
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --var)
                if [[ "${2:-}" != *=* ]]; then
                    echo "ERROR: --var expects KEY=VALUE (got: ${2:-})" >&2
                    return 2
                fi
                vars["${2%%=*}"]="${2#*=}"
                shift 2
                ;;
            --raw) raw=1; shift ;;
            -h|--help)
                cat <<'EOF'
fw prompt copy - Print prompt body with variable substitutions

Usage: fw prompt copy <id> [--var KEY=VALUE]... [--raw]

  --var KEY=VALUE   Substitute {{KEY}} → VALUE in body (repeatable)
  --raw             Skip substitution; print as-is
EOF
                return 0
                ;;
            *)
                if [ -z "$id" ]; then id="$1"; shift
                else echo "Unknown argument: $1" >&2; return 2
                fi
                ;;
        esac
    done
    if [ -z "$id" ]; then
        echo "Usage: fw prompt copy <id|qid> [--var KEY=VALUE]..." >&2
        return 2
    fi
    local path
    if ! path="$(_prompt_find_path "$id")"; then
        echo "ERROR: prompt not found: $id" >&2
        return 1
    fi
    local body; body="$(_prompt_body "$path")"
    if [ "$raw" = 1 ] || [ "${#vars[@]}" = 0 ]; then
        printf '%s\n' "$body"
        return 0
    fi
    local k v
    for k in "${!vars[@]}"; do
        v="${vars[$k]}"
        # Escape sed special chars in replacement.
        local esc_v
        esc_v=$(printf '%s' "$v" | sed -e 's/[\/&]/\\&/g')
        body=$(printf '%s' "$body" | sed "s/{{${k}}}/${esc_v}/g")
    done
    printf '%s\n' "$body"
}

# ---- helpers for edit/backfill ----

_prompt_update_field() {
    # Replace a single top-level frontmatter field in-place.
    # $1 = file, $2 = key, $3 = new value (already formatted, e.g. '"Some Name"' or '[a,b]')
    local file="$1" key="$2" value="$3"
    local tmp; tmp=$(mktemp)
    awk -v k="$key" -v v="$value" '
        BEGIN { fm = 0; replaced = 0 }
        /^---$/ { fm = !fm; print; next }
        fm && !replaced && $0 ~ "^" k ":" {
            print k ": " v
            replaced = 1
            next
        }
        { print }
    ' "$file" > "$tmp" && mv "$tmp" "$file"
}

_prompt_insert_field_after() {
    # Insert a new field after another field, or at the start of frontmatter.
    # $1 = file, $2 = after_key (or empty for start-of-frontmatter), $3 = new key, $4 = value
    local file="$1" after="$2" key="$3" value="$4"
    local tmp; tmp=$(mktemp)
    awk -v after="$after" -v k="$key" -v v="$value" '
        BEGIN { fm = 0; inserted = 0 }
        /^---$/ {
            fm = !fm
            if (fm && after == "" && !inserted) {
                print
                print k ": " v
                inserted = 1
                next
            }
            print
            next
        }
        fm && !inserted && after != "" && $0 ~ "^" after ":" {
            print
            print k ": " v
            inserted = 1
            next
        }
        { print }
    ' "$file" > "$tmp" && mv "$tmp" "$file"
}

_prompt_replace_body() {
    # Replace body (everything after closing ---) with new text.
    # $1 = file, $2 = new body
    local file="$1" new_body="$2"
    local tmp; tmp=$(mktemp)
    awk '
        BEGIN { seen = 0; fm = 0 }
        /^---$/ {
            if (!seen) { fm = 1; seen = 1; print; next }
            else if (fm) { fm = 0; print; print ""; exit }
        }
        { print }
    ' "$file" > "$tmp"
    printf '%s\n' "$new_body" >> "$tmp"
    mv "$tmp" "$file"
}

do_prompt_edit() {
    local id="" body="" tags="" description="" name=""
    local set_body=0 set_tags=0 set_description=0 set_name=0
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --body) body="$2"; set_body=1; shift 2 ;;
            --tags) tags="$2"; set_tags=1; shift 2 ;;
            --description) description="$2"; set_description=1; shift 2 ;;
            --name) name="$2"; set_name=1; shift 2 ;;
            -h|--help)
                cat <<'EOF'
fw prompt edit - Edit an existing prompt

Usage: fw prompt edit <id|qid> [options]

Options:
  --body TEXT         Replace the body (also re-extracts variables)
  --tags "a,b"        Replace tags
  --description TEXT  Update description
  --name TEXT         Update display name (slug is preserved)
EOF
                return 0
                ;;
            *)
                if [ -z "$id" ]; then id="$1"; shift
                else echo "Unknown argument: $1" >&2; return 2
                fi
                ;;
        esac
    done
    if [ -z "$id" ]; then
        echo "Usage: fw prompt edit <id|qid> [options]" >&2
        return 2
    fi
    local path
    if ! path="$(_prompt_find_path "$id")"; then
        echo "ERROR: prompt not found: $id" >&2
        return 1
    fi
    local changed=0
    if [ "$set_body" = 1 ]; then
        _prompt_replace_body "$path" "$body"
        local variables; variables="$(printf '%s' "$body" | _prompt_extract_vars)"
        _prompt_update_field "$path" "variables" "[${variables}]"
        changed=1
    fi
    if [ "$set_tags" = 1 ]; then
        _prompt_update_field "$path" "tags" "[${tags}]"
        changed=1
    fi
    if [ "$set_description" = 1 ]; then
        _prompt_update_field "$path" "description" "\"${description}\""
        changed=1
    fi
    if [ "$set_name" = 1 ]; then
        _prompt_update_field "$path" "name" "\"${name}\""
        changed=1
    fi
    if [ "$changed" = 1 ]; then
        _prompt_update_field "$path" "updated" "$(_prompt_iso_now)"
        echo "Updated: $path"
    else
        echo "No changes specified (use --body, --tags, --description, or --name)" >&2
        return 2
    fi
    return 0
}

do_prompt_delete() {
    local id="" force=0
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --force|-f) force=1; shift ;;
            -h|--help)
                echo "Usage: fw prompt delete <id|qid> [--force]"
                return 0
                ;;
            *)
                if [ -z "$id" ]; then id="$1"; shift
                else echo "Unknown argument: $1" >&2; return 2
                fi
                ;;
        esac
    done
    if [ -z "$id" ]; then
        echo "Usage: fw prompt delete <id|qid> [--force]" >&2
        return 2
    fi
    local path
    if ! path="$(_prompt_find_path "$id")"; then
        echo "ERROR: prompt not found: $id" >&2
        return 1
    fi
    if [ "$force" = 0 ] && [ -t 0 ]; then
        printf 'Delete %s? [y/N] ' "$path" >&2
        local answer; read -r answer
        case "${answer:-}" in y|Y|yes|YES) ;; *) echo "Cancelled" >&2; return 1 ;; esac
    fi
    rm -f "$path"
    echo "Deleted: $path"
    return 0
}

do_prompt_backfill() {
    local dir; dir="$(_prompt_dir)"
    if [ ! -d "$dir" ]; then
        echo "No prompts directory (expected: $dir)" >&2
        return 0
    fi
    local agent_id; agent_id="$(_prompt_resolve_agent_id)"
    local backfilled=0 skipped=0
    local f
    for f in "$dir"/*.md; do
        [ -f "$f" ] || continue
        [ "$(basename "$f")" = "README.md" ] && continue
        local existing_qid
        existing_qid="$(_prompt_get_field "$f" qid)"
        if [ -n "$existing_qid" ]; then
            skipped=$((skipped + 1))
            continue
        fi
        local counter; counter="$(_prompt_next_counter)"
        local qid; qid="$(_prompt_format_qid "$agent_id" "$counter")"
        _prompt_insert_field_after "$f" "id" "qid" "$qid"
        _prompt_insert_field_after "$f" "qid" "agent_id" "$agent_id"
        _prompt_insert_field_after "$f" "agent_id" "counter" "$counter"
        echo "  $(basename "$f" .md) → $qid"
        backfilled=$((backfilled + 1))
    done
    echo "Backfill: ${backfilled} prompt(s) assigned new QIDs, ${skipped} already had QIDs"
    return 0
}

do_prompt() {
    local sub="${1:-}"
    shift 2>/dev/null || true
    case "$sub" in
        create) do_prompt_create "$@" ;;
        list|ls) do_prompt_list "$@" ;;
        show|cat) do_prompt_show "$@" ;;
        copy|render) do_prompt_copy "$@" ;;
        edit) do_prompt_edit "$@" ;;
        delete|rm) do_prompt_delete "$@" ;;
        backfill-qid|backfill) do_prompt_backfill "$@" ;;
        ""|-h|--help|help)
            cat <<'EOF'
fw prompt - Reusable agent-prompt register

Usage: fw prompt <subcommand> [options]

Subcommands:
  create        Create a new prompt file
  list          List prompts
  show          Print the body of a prompt
  copy          Print body with {{var}} substitutions applied
  edit          Edit body/tags/description/name of an existing prompt
  delete        Remove a prompt (--force to skip confirmation)
  backfill-qid  Assign QIDs to any prompts missing them

See 'fw prompt <subcommand> --help' for details.
EOF
            ;;
        *)
            echo "Unknown subcommand: $sub" >&2
            echo "Run 'fw prompt --help' for usage." >&2
            return 2
            ;;
    esac
}
