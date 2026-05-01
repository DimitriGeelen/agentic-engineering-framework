#!/usr/bin/env bash
# lib/arc.sh — Arc system (T-1653 Phase 1 / T-1661)
#
# Arcs are first-class workspaces grouping tasks by theme. An arc has
# a slug id (`orchestrator-rethink`), a name, an optional anchor task,
# and a list of constituent tasks. Arcs surface via:
#   - `.context/arcs/<id>.yaml` registry
#   - `.context/working/arc-focus.yaml` (single-arc focus, single-task analog)
#   - `arc:<id>` tag namespace (canonical; legacy `from-T-XXXX` mapped on migrate)
#   - handover.sh `## Current Arc` section
#   - Watchtower landing-page section + `/tasks?arc=<id>` filter chip
#
# Verbs:
#   create <id> --name "..." [--anchor T-XXXX] [--description "..."]
#   focus <id>                            # write arc-focus.yaml
#   list                                   # table of all arcs
#   show <id>                              # detail
#   tag <id> T-XXXX                        # link task to arc (bidirectional)
#   close <id> [--decision "..."]          # mark closed
#   migrate <id> --anchor T-XXXX           # seed from related_tasks + legacy tags
#
# Source order (PROJECT_ROOT must be set by caller — bin/fw or test harness).

set -u

PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
ARCS_DIR="${PROJECT_ROOT}/.context/arcs"
ARC_FOCUS_FILE="${PROJECT_ROOT}/.context/working/arc-focus.yaml"

# ─── helpers ────────────────────────────────────────────────────────────────

_arc_validate_id() {
    local id="$1"
    if ! [[ "$id" =~ ^[a-z][a-z0-9-]{1,63}$ ]]; then
        echo "Error: arc id must be lowercase slug ([a-z0-9-], 2-64 chars). Got: '$id'" >&2
        return 1
    fi
}

_arc_path() {
    echo "${ARCS_DIR}/$1.yaml"
}

_arc_exists() {
    [ -f "$(_arc_path "$1")" ]
}

_arc_ensure_dir() {
    mkdir -p "$ARCS_DIR" "$(dirname "$ARC_FOCUS_FILE")"
}

_arc_now() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

_arc_current_focus() {
    [ -f "$ARC_FOCUS_FILE" ] || return 0
    grep -E '^current_arc:' "$ARC_FOCUS_FILE" 2>/dev/null \
        | head -1 | awk -F': ' '{print $2}' | tr -d ' "'
}

# Find tasks tagged with a given arc tag. Returns T-IDs one per line.
# Always exits 0 — empty output is a valid result, not a failure.
_arc_tasks_with_tag() {
    local tag="$1"
    {
        grep -lE "^tags:.*${tag}" "$PROJECT_ROOT"/.tasks/active/*.md 2>/dev/null || true
        grep -lE "^tags:.*${tag}" "$PROJECT_ROOT"/.tasks/completed/*.md 2>/dev/null || true
    } | while IFS= read -r f; do
        # extract id from frontmatter
        awk -F: '/^id:/ {gsub(/[ "]/,"",$2); print $2; exit}' "$f"
    done | sort -u
}

# ─── verbs ──────────────────────────────────────────────────────────────────

arc_create() {
    local id="" name="" anchor="" description=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --name) name="$2"; shift 2;;
            --anchor) anchor="$2"; shift 2;;
            --description) description="$2"; shift 2;;
            -*) echo "Unknown flag: $1" >&2; return 2;;
            *) [ -z "$id" ] && id="$1" || { echo "Unexpected arg: $1" >&2; return 2; }; shift;;
        esac
    done

    [ -n "$id" ]   || { echo "Usage: fw arc create <arc-id> --name \"...\" [--anchor T-XXXX]" >&2; return 2; }
    [ -n "$name" ] || { echo "Error: --name is required" >&2; return 2; }
    _arc_validate_id "$id" || return 2
    _arc_ensure_dir

    if _arc_exists "$id"; then
        echo "Error: arc '$id' already exists at $(_arc_path "$id")" >&2
        return 1
    fi

    local now
    now="$(_arc_now)"

    cat > "$(_arc_path "$id")" <<YAML
id: ${id}
name: ${name}
description: ${description}
status: in-progress
anchor_task: ${anchor}
constituent_tasks: []
created: ${now}
closed_at: null
decision: null
YAML

    echo "Created arc '${id}' → $(_arc_path "$id")"
    [ -n "$anchor" ] && echo "  anchor: ${anchor}"
    return 0
}

arc_focus() {
    local id="${1:-}"
    [ -n "$id" ] || { echo "Usage: fw arc focus <arc-id> | --clear" >&2; return 2; }

    _arc_ensure_dir

    if [ "$id" = "--clear" ] || [ "$id" = "none" ]; then
        cat > "$ARC_FOCUS_FILE" <<YAML
# Arc focus (T-1661). Set via 'fw arc focus <arc-id>'.
current_arc: null
focused_at: null
YAML
        echo "Arc focus cleared."
        return 0
    fi

    _arc_validate_id "$id" || return 2

    if ! _arc_exists "$id"; then
        echo "Error: arc '$id' not found. Create it with: fw arc create $id --name \"...\"" >&2
        return 1
    fi

    cat > "$ARC_FOCUS_FILE" <<YAML
# Arc focus (T-1661). Set via 'fw arc focus <arc-id>'.
current_arc: ${id}
focused_at: $(_arc_now)
YAML
    echo "Arc focus → ${id}"
}

arc_list() {
    _arc_ensure_dir
    local current
    current="$(_arc_current_focus)"

    if [ ! -d "$ARCS_DIR" ] || ! ls "$ARCS_DIR"/*.yaml >/dev/null 2>&1; then
        echo "No arcs registered. Create one with: fw arc create <id> --name \"...\""
        return 0
    fi

    printf "%-2s %-30s %-12s %-7s %s\n" "" "ID" "STATUS" "TASKS" "NAME"
    printf "%-2s %-30s %-12s %-7s %s\n" "" "----" "------" "-----" "----"
    for f in "$ARCS_DIR"/*.yaml; do
        local id status name task_count marker
        id=$(awk -F': ' '/^id:/ {print $2; exit}' "$f")
        status=$(awk -F': ' '/^status:/ {print $2; exit}' "$f")
        name=$(awk -F': ' '/^name:/ {sub(/^name: /,""); print; exit}' "$f")
        task_count=$(_arc_tasks_with_tag "arc:${id}" | wc -l | tr -d ' ')
        marker="  "
        if [ "$id" = "$current" ]; then marker=" *"; fi
        printf "%-2s %-30s %-12s %-7s %s\n" "$marker" "$id" "$status" "$task_count" "$name"
    done
    [ -n "$current" ] && echo "" && echo "(* = focused arc)"
    return 0
}

arc_show() {
    local id="${1:-}"
    [ -n "$id" ] || { echo "Usage: fw arc show <arc-id>" >&2; return 2; }
    _arc_validate_id "$id" || return 2
    _arc_exists "$id" || { echo "Error: arc '$id' not found" >&2; return 1; }

    local f current
    f="$(_arc_path "$id")"
    current="$(_arc_current_focus)"

    cat "$f"
    echo ""
    echo "─── Tasks tagged arc:${id} ───"
    local found=0
    while IFS= read -r tid; do
        if [ -z "$tid" ]; then continue; fi
        found=1
        # find task file & extract status/horizon
        local tf
        tf=$({ ls "$PROJECT_ROOT"/.tasks/{active,completed}/"$tid"-*.md 2>/dev/null || true; } | head -1)
        if [ -n "$tf" ]; then
            local s h n
            s=$(awk -F': ' '/^status:/ {print $2; exit}' "$tf")
            h=$(awk -F': ' '/^horizon:/ {print $2; exit}' "$tf")
            n=$(awk -F': ' '/^name:/ {sub(/^name: /,""); gsub(/^"/,""); gsub(/"$/,""); print; exit}' "$tf")
            printf "  %s [%s/%s]  %s\n" "$tid" "${s:-?}" "${h:-?}" "${n:-?}"
        else
            printf "  %s (file not found)\n" "$tid"
        fi
    done < <(_arc_tasks_with_tag "arc:${id}")
    [ "$found" -eq 0 ] && echo "  (no tasks yet — use 'fw arc tag $id T-XXXX')"

    [ "$id" = "$current" ] && echo "" && echo "[FOCUSED]"
    return 0
}

arc_tag() {
    local id="${1:-}" tid="${2:-}"
    [ -n "$id" ] && [ -n "$tid" ] || { echo "Usage: fw arc tag <arc-id> T-XXXX" >&2; return 2; }
    _arc_validate_id "$id" || return 2
    _arc_exists "$id" || { echo "Error: arc '$id' not found" >&2; return 1; }

    if ! [[ "$tid" =~ ^T-[0-9]+$ ]]; then
        echo "Error: task id must look like T-NNNN. Got: '$tid'" >&2
        return 2
    fi

    local tf
    # Brace expansion lets ls find the task file in either active/ or completed/.
    # Earlier `ls A || ls B` form was buggy: `ls | head` always exits 0.
    tf=$({ ls "$PROJECT_ROOT"/.tasks/{active,completed}/"$tid"-*.md 2>/dev/null || true; } | head -1)
    [ -n "$tf" ] || { echo "Error: task $tid not found in .tasks/{active,completed}/" >&2; return 1; }

    local arc_tag="arc:${id}"

    # 1. Add tag to task file (idempotent).
    if grep -qE "^tags:.*${arc_tag}" "$tf"; then
        echo "Task $tid already has tag $arc_tag — skipping task edit"
    else
        # update-task.sh handles the tag append safely
        if [ -x "$PROJECT_ROOT/agents/task-create/update-task.sh" ]; then
            (cd "$PROJECT_ROOT" && ./agents/task-create/update-task.sh "$tid" --add-tag "$arc_tag" >/dev/null) \
                || { echo "Error: update-task.sh failed adding tag" >&2; return 1; }
        else
            python3 - "$tf" "$arc_tag" <<'PY'
import re, sys
fn, tag = sys.argv[1], sys.argv[2]
text = open(fn).read()
m = re.search(r'^(tags:\s*)(\[.*?\]|\S.*?)$', text, re.MULTILINE)
if m:
    cur = m.group(2).strip()
    if cur.startswith("["):
        new = cur.rstrip("]").rstrip() + (f', "{tag}"]' if cur != "[]" else f'"{tag}"]')
    else:
        new = f"[{cur}, \"{tag}\"]"
    text = text[:m.start(2)] + new + text[m.end(2):]
else:
    # insert after frontmatter line `---` open
    text = text.replace("---\n", f"---\ntags: [\"{tag}\"]\n", 1)
open(fn, "w").write(text)
PY
        fi
        echo "Tagged task $tid with $arc_tag"
    fi

    # 2. Append to arc's constituent_tasks (idempotent).
    local arc_file
    arc_file="$(_arc_path "$id")"
    python3 - "$arc_file" "$tid" <<'PY'
import re, sys
fn, tid = sys.argv[1], sys.argv[2]
text = open(fn).read()
m = re.search(r'^constituent_tasks:\s*(\[.*?\])\s*$', text, re.MULTILINE)
if not m:
    sys.exit(0)
cur = m.group(1).strip()
inner = cur[1:-1].strip()
items = [s.strip().strip('"').strip("'") for s in inner.split(",") if s.strip()]
if tid in items:
    sys.exit(0)
items.append(tid)
new = "[" + ", ".join(f'"{x}"' for x in items) + "]"
text = text[:m.start(1)] + new + text[m.end(1):]
open(fn, "w").write(text)
print(f"Added {tid} to arc constituents")
PY
    return 0
}

arc_close() {
    local id="" decision=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --decision) decision="$2"; shift 2;;
            *) [ -z "$id" ] && id="$1" || { echo "Unexpected arg: $1" >&2; return 2; }; shift;;
        esac
    done
    [ -n "$id" ] || { echo "Usage: fw arc close <arc-id> [--decision \"...\"]" >&2; return 2; }
    _arc_validate_id "$id" || return 2
    _arc_exists "$id" || { echo "Error: arc '$id' not found" >&2; return 1; }

    local f now
    f="$(_arc_path "$id")"
    now="$(_arc_now)"

    python3 - "$f" "$now" "$decision" <<'PY'
import re, sys
fn, now, decision = sys.argv[1], sys.argv[2], sys.argv[3]
text = open(fn).read()
text = re.sub(r'^status:.*$', 'status: closed', text, count=1, flags=re.MULTILINE)
text = re.sub(r'^closed_at:.*$', f'closed_at: {now}', text, count=1, flags=re.MULTILINE)
if decision:
    text = re.sub(r'^decision:.*$', f'decision: {decision}', text, count=1, flags=re.MULTILINE)
open(fn, "w").write(text)
PY
    echo "Closed arc '${id}' at ${now}${decision:+ — ${decision}}"

    # Clear focus if focused arc was the one closed.
    local current
    current="$(_arc_current_focus)"
    if [ "$current" = "$id" ]; then
        arc_focus --clear
    fi
    return 0
}

arc_migrate() {
    local id="" anchor=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --anchor) anchor="$2"; shift 2;;
            *) [ -z "$id" ] && id="$1" || { echo "Unexpected arg: $1" >&2; return 2; }; shift;;
        esac
    done
    [ -n "$id" ] || { echo "Usage: fw arc migrate <arc-id> --anchor T-XXXX" >&2; return 2; }
    _arc_validate_id "$id" || return 2
    _arc_exists "$id" || { echo "Error: arc '$id' not found — create first with 'fw arc create'" >&2; return 1; }

    local seeded=0
    # 1. Pull anchor's related_tasks.
    if [ -n "$anchor" ]; then
        local af
        af=$({ ls "$PROJECT_ROOT"/.tasks/{active,completed}/"$anchor"-*.md 2>/dev/null || true; } | head -1)
        if [ -n "$af" ]; then
            # extract related_tasks list (bare or array form)
            python3 - "$af" <<'PY' | while IFS= read -r related; do
import re, sys
text = open(sys.argv[1]).read()
m = re.search(r'^related_tasks:\s*\[(.*?)\]', text, re.MULTILINE | re.DOTALL)
if m:
    for tid in re.findall(r'T-\d+', m.group(1)):
        print(tid)
PY
                arc_tag "$id" "$related" >/dev/null && seeded=$((seeded+1))
            done
        fi
        # Also tag the anchor itself.
        arc_tag "$id" "$anchor" >/dev/null && seeded=$((seeded+1))
    fi

    # 2. Find tasks with legacy `from-T-XXXX` tag matching anchor.
    if [ -n "$anchor" ]; then
        while IFS= read -r tid; do
            if [ -z "$tid" ]; then continue; fi
            arc_tag "$id" "$tid" >/dev/null && seeded=$((seeded+1))
        done < <(_arc_tasks_with_tag "from-${anchor}")
    fi

    # 3. Already-tagged-with-arc tasks (idempotency check).
    while IFS= read -r tid; do
        if [ -z "$tid" ]; then continue; fi
        arc_tag "$id" "$tid" >/dev/null
    done < <(_arc_tasks_with_tag "arc:${id}")

    echo "Migration complete: $seeded task(s) processed for arc '${id}'"
    return 0
}

arc_help() {
    cat <<EOF
fw arc — Arc system (T-1653 / T-1661)

Verbs:
  create <id> --name "..." [--anchor T-XXXX] [--description "..."]
                            Register a new arc
  focus <id> | --clear      Set/clear the focused arc (one at a time)
  list                      Show all arcs (* marks focused)
  show <id>                 Detail: metadata + constituent tasks
  tag <id> T-XXXX           Add arc:<id> tag to a task + append to constituents
  close <id> [--decision "..."]
                            Mark arc closed
  migrate <id> --anchor T-XXXX
                            Seed constituent_tasks from anchor's related_tasks
                            and legacy from-T-XXXX tags (idempotent)

Examples:
  fw arc create orchestrator-rethink --name "Orchestrator routing rethink" --anchor T-1641
  fw arc focus orchestrator-rethink
  fw arc tag orchestrator-rethink T-1661
  fw arc list
  fw arc show orchestrator-rethink

Storage:
  .context/arcs/<id>.yaml          — registry
  .context/working/arc-focus.yaml  — focused arc (single)
  Task tags: arc:<id> (canonical); from-T-XXXX as legacy alias

Surfaces:
  - Handover: ## Current Arc section (if focus set)
  - Watchtower /: 'Arcs in flight' section
  - Watchtower /tasks?arc=<id>: filter chip
EOF
}

arc_dispatch() {
    local verb="${1:-help}"
    shift || true
    case "$verb" in
        create)  arc_create  "$@";;
        focus)   arc_focus   "$@";;
        list|ls) arc_list    "$@";;
        show)    arc_show    "$@";;
        tag)     arc_tag     "$@";;
        close)   arc_close   "$@";;
        migrate) arc_migrate "$@";;
        help|--help|-h) arc_help;;
        *) echo "Unknown verb: $verb" >&2; arc_help; return 2;;
    esac
}
