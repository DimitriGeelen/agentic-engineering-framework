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

# T-1668 §ACD Layer A — headline_mechanic validation.
# Forces user-facing deliverable description before any work begins.
_arc_validate_headline_mechanic() {
    local text="$1"
    local len=${#text}
    if [ "$len" -lt 30 ] || [ "$len" -gt 500 ]; then
        echo "Error: --headline-mechanic must be 30-500 chars (got $len)." >&2
        echo "  Describe a user-observable deliverable, e.g.:" >&2
        echo "  \"agent dispatches a task without --model → orchestrator picks based on task_type and history → user watches the decision on /orchestrator\"" >&2
        return 1
    fi
    local allowed='dispatch(es)?|route(s)?|select(s)?|pick(s)?|run(s)?|observe(s)?|watch(es)?|see(s)?|receive(s)?|get(s)?|execute(s)?|fire(s)?|complete(s)?|ask(s)?|request(s)?|land(s)?|trigger(s)?|invoke(s)?|edit(s)?|commit(s)?'
    if ! printf '%s' "$text" | grep -qiE "($allowed)"; then
        echo "Error: --headline-mechanic must describe an observable action." >&2
        echo "  Include a verb like: dispatches, runs, picks, sees, observes, receives, executes." >&2
        echo "  Got: \"$text\"" >&2
        return 1
    fi
    local substrate='infrastructure|groundwork|substrate|metadata capture|governance hook|audit page|framework path|the framework (populates|renders|captures|logs|tracks|warns|stores)'
    local has_substrate=0 has_user=0
    printf '%s' "$text" | grep -qiE "$substrate" && has_substrate=1
    printf '%s' "$text" | grep -qiE '(user|human|agent|developer|operator|caller|they|their)' && has_user=1
    if [ "$has_substrate" = "1" ] && [ "$has_user" = "0" ]; then
        echo "Error: --headline-mechanic appears to describe substrate, not a user-observable mechanic." >&2
        echo "  A real headline mechanic names WHO observes WHAT — not what the framework does internally." >&2
        return 1
    fi
    return 0
}

# T-1668 §ACD Layer B — demo path validation.
_arc_validate_demo_path() {
    local demo="$1" arc_id="$2" arc_yaml="$3"
    [ -f "$demo" ] || { echo "Error: --demo path '$demo' does not exist." >&2; return 1; }
    local size
    size=$(wc -c < "$demo" 2>/dev/null || echo 0)
    if [ "$size" -lt 256 ]; then
        echo "Error: --demo file '$demo' is too small ($size bytes; need ≥256)." >&2
        echo "  This gate exists to prevent trivial bypass with hand-typed placeholder files." >&2
        return 1
    fi
    case "$demo" in
        *.json|*.jsonl|*.yaml|*.yml|*.md|*.cast|*.mp4|*.log|*.txt|*.html|*.png|*.jpg|*.jpeg|*.gif|*.svg|*.webm) ;;
        *)
            echo "Error: --demo extension not in evidence allowlist." >&2
            echo "  Allowed: .json .jsonl .yaml .yml .md .cast .mp4 .log .txt .html .png .jpg .jpeg .gif .svg .webm" >&2
            return 1 ;;
    esac
    case "$demo" in
        *.json|*.jsonl|*.yaml|*.yml|*.md|*.log|*.txt|*.html|*.cast)
            if grep -qE "(${arc_id}|T-[0-9]+)" "$demo" 2>/dev/null; then
                local matched=0
                if grep -qE "${arc_id}" "$demo" 2>/dev/null; then matched=1; fi
                if [ "$matched" = "0" ]; then
                    while IFS= read -r tid; do
                        [ -z "$tid" ] && continue
                        grep -qE "${tid}" "$demo" 2>/dev/null && { matched=1; break; }
                    done < <(grep -oE 'T-[0-9]+' "$arc_yaml" 2>/dev/null | sort -u)
                fi
                if [ "$matched" = "0" ]; then
                    echo "Error: --demo file '$demo' references task IDs but none belong to arc '${arc_id}'." >&2
                    return 1
                fi
            else
                echo "Error: --demo file '$demo' does not reference arc id '${arc_id}' or any task id." >&2
                echo "  Wire-level evidence must be traceable to this arc." >&2
                return 1
            fi
            ;;
    esac
    return 0
}

_arc_validate_demo_url() {
    local url="$1" arc_id="$2"
    if ! command -v curl >/dev/null 2>&1; then
        echo "Error: curl required to validate --demo URL." >&2
        return 1
    fi
    local code
    code=$(curl -s -o /dev/null -w "%{http_code}" -m 5 -L -I "$url" 2>/dev/null || echo "000")
    case "$code" in
        2*) ;;
        *) echo "Error: --demo URL '$url' returned HTTP $code (need 2xx)." >&2; return 1 ;;
    esac
    local body
    body=$(curl -s -m 5 -L --max-filesize 65536 "$url" 2>/dev/null || true)
    if ! printf '%s' "$body" | grep -qE "${arc_id}"; then
        echo "Error: --demo URL '$url' body does not reference arc id '${arc_id}' in first 32KB." >&2
        return 1
    fi
    return 0
}

_arc_log_bypass() {
    local arc_id="$1" reason="$2" justification="$3"
    local logf="$PROJECT_ROOT/.context/audits/arc-bypass.jsonl"
    mkdir -p "$(dirname "$logf")"
    local now
    now="$(_arc_now)"
    printf '{"arc":"%s","ts":"%s","reason":"%s","justification":%s}\n' \
        "$arc_id" "$now" "$reason" "$(printf '%s' "$justification" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')" \
        >> "$logf"
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
    local id="" name="" anchor="" description="" headline_mechanic=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --name) name="$2"; shift 2;;
            --anchor) anchor="$2"; shift 2;;
            --description) description="$2"; shift 2;;
            --headline-mechanic) headline_mechanic="$2"; shift 2;;
            -*) echo "Unknown flag: $1" >&2; return 2;;
            *) [ -z "$id" ] && id="$1" || { echo "Unexpected arg: $1" >&2; return 2; }; shift;;
        esac
    done

    [ -n "$id" ]   || { echo "Usage: fw arc create <arc-id> --name \"...\" --headline-mechanic \"...\" [--anchor T-XXXX]" >&2; return 2; }
    [ -n "$name" ] || { echo "Error: --name is required" >&2; return 2; }
    _arc_validate_id "$id" || return 2
    # T-1668 §ACD Layer A: refuse without a user-observable headline mechanic.
    if [ -z "$headline_mechanic" ]; then
        echo "Error: --headline-mechanic is required (§ACD/G-062)." >&2
        echo "  Describe the user-observable deliverable in one sentence:" >&2
        echo "    fw arc create $id --name \"$name\" \\" >&2
        echo "      --headline-mechanic \"<who> <does what> <observes what user-visible result>\"" >&2
        echo "  Example: \"agent dispatches a task without --model → orchestrator picks based on task_type and history → user watches the decision on /orchestrator\"" >&2
        return 2
    fi
    _arc_validate_headline_mechanic "$headline_mechanic" || return 2
    _arc_ensure_dir

    if _arc_exists "$id"; then
        echo "Error: arc '$id' already exists at $(_arc_path "$id")" >&2
        return 1
    fi

    local now
    now="$(_arc_now)"

    # T-1816: yaml-safe-quote all free-text string fields. Origin: dispatch-safety
    # arc shipped with `name: Dispatch safety: Worker uncertainty handling` —
    # unquoted colon parsed as a nested mapping, broke Watchtower /arcs/dispatch-safety.
    # Quote name, description, headline_mechanic via yaml.safe_dump (handles colons,
    # arrows, quotes, hash marks). Anchor stays bare (validated as a task ID).
    local name_yaml desc_yaml hm_yaml
    name_yaml=$(printf '%s' "$name" | python3 -c 'import yaml,sys; print(yaml.safe_dump(sys.stdin.read().rstrip("\n"), default_style=chr(34)).rstrip())')
    desc_yaml=$(printf '%s' "$description" | python3 -c 'import yaml,sys; print(yaml.safe_dump(sys.stdin.read().rstrip("\n"), default_style=chr(34)).rstrip())')
    hm_yaml=$(printf '%s' "$headline_mechanic" | python3 -c 'import yaml,sys; print(yaml.safe_dump(sys.stdin.read().rstrip("\n"), default_style=chr(34)).rstrip())')

    cat > "$(_arc_path "$id")" <<YAML
id: ${id}
name: ${name_yaml}
description: ${desc_yaml}
status: in-progress
anchor_task: ${anchor}
constituent_tasks: []
headline_mechanic: ${hm_yaml}
demo_evidence: null
created: ${now}
closed_at: null
decision: null
YAML

    echo "Created arc '${id}' → $(_arc_path "$id")"
    [ -n "$anchor" ] && echo "  anchor: ${anchor}"
    echo "  headline_mechanic: ${headline_mechanic}"
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
    local id="" decision="" demo="" justification=""
    local i_am_human=false from_watchtower=false
    while [ $# -gt 0 ]; do
        case "$1" in
            --decision) decision="$2"; shift 2;;
            --demo) demo="$2"; shift 2;;
            --justification) justification="$2"; shift 2;;
            --i-am-human) i_am_human=true; shift;;
            --from-watchtower) from_watchtower=true; shift;;
            *) [ -z "$id" ] && id="$1" || { echo "Unexpected arg: $1" >&2; return 2; }; shift;;
        esac
    done
    [ -n "$id" ] || { echo "Usage: fw arc close <arc-id> --demo <path|url|none> [--justification \"...\"] [--decision \"...\"]" >&2; return 2; }
    _arc_validate_id "$id" || return 2
    _arc_exists "$id" || { echo "Error: arc '$id' not found" >&2; return 1; }

    # T-1671 §ACD/G-062 Default-to-OPEN agent gate. Mirrors lib/inception.sh
    # do_inception_decide (T-1259/T-1260): closure decisions belong to the
    # human, recorded via Watchtower. Origin: 4th-instance auto-close incident
    # 2026-05-02 on this very arc — see T-1670, docs/reports/T-1670-default-to-open-gate-gap.md.
    if [ "${CLAUDECODE:-}" = "1" ] && [ "$i_am_human" = false ] && [ "$from_watchtower" = false ]; then
        local anchor="" wt_url=""
        anchor=$(awk -F': ' '/^anchor_task:/ {print $2; exit}' "$(_arc_path "$id")" 2>/dev/null | tr -d ' "' || true)
        if command -v fw_config >/dev/null 2>&1; then
            wt_url="$(fw_config WATCHTOWER_URL "" 2>/dev/null || true)"
        fi
        if [ -z "$wt_url" ]; then
            wt_url="$(bin/fw watchtower url 2>/dev/null || true)"
        fi
        [ -z "$wt_url" ] && wt_url="http://localhost:3000"
        echo "Error: agents must not invoke 'fw arc close' directly (§ACD/G-062, T-1671)." >&2
        echo "" >&2
        echo "  You appear to be running inside Claude Code (\$CLAUDECODE=1)." >&2
        echo "  Arc closure carries the same authority weight as inception go/no-go" >&2
        echo "  and belongs to the human (Default-to-OPEN: ≥2 prior pushbacks → OPEN" >&2
        echo "  regardless of new evidence)." >&2
        echo "" >&2
        echo "  Correct flow:" >&2
        if [ -n "$anchor" ]; then
            echo "    1. Agent: bin/fw task review ${anchor}" >&2
        else
            echo "    1. Agent: bin/fw task review <arc-anchor-task>" >&2
        fi
        echo "    2. Human: open the Watchtower URL, review the demo evidence," >&2
        echo "       run 'bin/fw arc close ${id} --demo <path> --decision \"...\"'" >&2
        echo "" >&2
        echo "  Arc detail: ${wt_url}/arcs/${id}" >&2
        echo "" >&2
        echo "  Overrides (mirror T-1259 inception-decide): --i-am-human (human typing" >&2
        echo "  into an agent session, rare); --from-watchtower (Flask backend)." >&2
        echo "  See CLAUDE.md §Arc Completion Discipline." >&2
        return 1
    fi

    local f now
    f="$(_arc_path "$id")"
    now="$(_arc_now)"

    # T-1668 §ACD Layer B: refuse without --demo.
    if [ -z "$demo" ]; then
        echo "Error: --demo is required to close an arc (§ACD/G-062)." >&2
        echo "  Provide wire-level evidence the headline mechanic fired:" >&2
        echo "    fw arc close $id --demo <path-to-meta.json|stream-json|screencast> --decision \"...\"" >&2
        echo "    fw arc close $id --demo <https://watchtower-url-showing-mechanic-state> --decision \"...\"" >&2
        echo "  Or — if this arc has no runtime mechanic — bypass with explicit justification:" >&2
        echo "    fw arc close $id --demo none --justification \"<≥30 chars explaining why no demo applies>\" --decision \"...\"" >&2
        if grep -q "^headline_mechanic:" "$f" 2>/dev/null; then
            echo "  Headline mechanic for this arc:" >&2
            grep "^headline_mechanic:" "$f" | sed 's/^/    /' >&2
        fi
        return 2
    fi
    if [ "$demo" = "none" ]; then
        if [ -z "$justification" ] || [ "${#justification}" -lt 30 ]; then
            echo "Error: --demo none requires --justification \"<≥30 chars>\"." >&2
            return 2
        fi
        _arc_log_bypass "$id" "no-runtime-mechanic" "$justification"
        echo "Logged --demo none bypass to .context/audits/arc-bypass.jsonl"
    else
        case "$demo" in
            http://*|https://*) _arc_validate_demo_url "$demo" "$id" || return 1 ;;
            *)                  _arc_validate_demo_path "$demo" "$id" "$f" || return 1 ;;
        esac
    fi

    python3 - "$f" "$now" "$decision" "$demo" <<'PY'
import re, sys
fn, now, decision, demo = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
text = open(fn).read()
text = re.sub(r'^status:.*$', 'status: closed', text, count=1, flags=re.MULTILINE)
text = re.sub(r'^closed_at:.*$', f'closed_at: {now}', text, count=1, flags=re.MULTILINE)
if decision:
    safe = decision.replace('"', '\\"')
    text = re.sub(r'^decision:.*$', f'decision: "{safe}"', text, count=1, flags=re.MULTILINE)
safe_demo = demo.replace('"', '\\"')
if re.search(r'^demo_evidence:', text, re.MULTILINE):
    text = re.sub(r'^demo_evidence:.*$', f'demo_evidence: "{safe_demo}"', text, count=1, flags=re.MULTILINE)
else:
    text = text.rstrip("\n") + f'\ndemo_evidence: "{safe_demo}"\n'
open(fn, "w").write(text)
PY
    echo "Closed arc '${id}' at ${now}${decision:+ — ${decision}}"
    echo "  demo_evidence: ${demo}"

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
  create <id> --name "..." --headline-mechanic "..." [--anchor T-XXXX] [--description "..."]
                            Register a new arc. --headline-mechanic is REQUIRED
                            (§ACD/G-062): describes the user-observable deliverable;
                            substrate-only phrasing is refused.
  focus <id> | --clear      Set/clear the focused arc (one at a time)
  list                      Show all arcs (* marks focused)
  show <id>                 Detail: metadata + constituent tasks
  tag <id> T-XXXX           Add arc:<id> tag to a task + append to constituents
  close <id> --demo <path|url|none> [--justification "..."] [--decision "..."]
                            Mark arc closed. --demo is REQUIRED (§ACD/G-062):
                            wire-level evidence of the headline_mechanic firing.
                            Use 'none' + --justification (≥30 chars) for arcs
                            with no runtime mechanic — bypass is logged.
  migrate <id> --anchor T-XXXX
                            Seed constituent_tasks from anchor's related_tasks
                            and legacy from-T-XXXX tags (idempotent)

Examples:
  fw arc create orchestrator-rethink --name "Orchestrator routing rethink" --anchor T-1641 \\
    --headline-mechanic "agent dispatches without --model → orchestrator picks based on task_type → user observes routing on /orchestrator"
  fw arc close orchestrator-rethink --demo docs/reports/T-1643-Q1-wire-evidence.md --decision "shipped"
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
