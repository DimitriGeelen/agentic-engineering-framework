#!/usr/bin/env bash
# lib/arc.sh — Arc system (T-1653 Phase 1 / T-1661 / T-1848)
#
# Arcs are first-class workspaces grouping tasks by theme. Two identities:
#
#   • slug  — human-readable filename stem (e.g., `orchestrator-rethink`).
#             Used in URLs, tags (arc:<slug>), and discussion. Stable but
#             not immutable — a slug may be renamed (rare; never auto).
#   • arc-NNN — immutable sequential numeric ID (e.g., `arc-001`) written
#             into the YAML's `id:` field at creation time. Never renumbered,
#             never reused, never deleted (status flips, file stays).
#
# D-Immutability axiom (T-1846 inception §11.3, captured here so future
# changes find it):
#
#   1. arc-NNN IDs are NEVER renumbered. Once `id: arc-007` is allocated,
#      arc-007 forever points at THAT yaml (whatever its slug becomes).
#   2. arc-NNN IDs are NEVER reused. If arc-007 is abandoned, the next
#      `fw arc create` allocates arc-008, not arc-007.
#   3. arc YAMLs are NOT deleted as part of normal flow. Abandonment is
#      a status transition (status: abandoned), not a file delete.
#      Manual `rm` is only permitted for fresh-mistake recovery (an arc
#      created within the current uncommitted session and not yet
#      referenced by any task or commit). All other state changes route
#      through `fw arc <verb>`.
#   4. The slug → arc-NNN mapping is read-only from the filename + `id:`
#      field. If a slug needs to change, both filename rename AND
#      task-tag migration must happen atomically (rare; covered by
#      a follow-up migration helper, not this script).
#
# Arcs surface via:
#   - `.context/arcs/<slug>.yaml` registry (filename stem = slug)
#   - `.context/working/arc-focus.yaml` (single-arc focus)
#   - `arc:<slug>` tag namespace (canonical during transition; T-NEW-3
#                                  introduces `arc_id:` task-frontmatter
#                                  field as the post-migration target)
#   - handover.sh `## Current Arc` section
#   - Watchtower landing-page section + `/tasks?arc=<slug>` filter chip
#   - Watchtower `/arcs/<slug>` AND `/arcs/<arc-NNN>` both resolve to the
#                                  same arc detail page
#
# Verbs:
#   create <slug> --name "..." --headline-mechanic "..." [--anchor T-XXXX]
#                 [--description "..."]
#       Allocates next arc-NNN, writes id: arc-NNN, file becomes <slug>.yaml.
#   focus <slug-or-id>                    # write arc-focus.yaml
#   list                                   # table of all arcs
#   show <slug-or-id>                      # detail
#   tag <slug-or-id> T-XXXX                # link task to arc (bidirectional)
#   close <slug-or-id> [--decision "..."]  # mark closed
#   migrate <slug> --anchor T-XXXX         # seed from related_tasks + legacy tags
#
# Source order (PROJECT_ROOT must be set by caller — bin/fw or test harness).

set -u

PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
ARCS_DIR="${PROJECT_ROOT}/.context/arcs"
ARC_FOCUS_FILE="${PROJECT_ROOT}/.context/working/arc-focus.yaml"

# T-1852 (T-NEW-5a): Lifecycle state machine.
# Four allowed states. arc_create defaults to `draft` going forward;
# arc_start transitions draft → in-progress; arc_close transitions
# in-progress → closed; arc_abandon (T-1854) transitions draft|in-progress
# → abandoned. Pre-T-1852 arcs remain `in-progress` (no force-migration).
# D-Immutability: status flips, file stays.
ARC_STATES=("draft" "in-progress" "closed" "abandoned")

# T-1914: source the canonical membership-scan helpers. lib/arc_membership.sh
# defines `arc_tasks_with_tag`, `arc_tasks_with_arc_id`, `arc_tasks_for`,
# and `task_has_arc_membership`. The private `_arc_tasks_*` wrappers below
# delegate to these (was: inline duplicates, kept drifting from canonical).
# Idempotent guard inside the lib prevents double-sourcing.
_arc_source_membership_lib() {
    local script_dir
    script_dir="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
    # shellcheck source=lib/arc_membership.sh
    . "${script_dir}/arc_membership.sh"
}
_arc_source_membership_lib

# ─── helpers ────────────────────────────────────────────────────────────────

_arc_validate_id() {
    local id="$1"
    if ! [[ "$id" =~ ^[a-z][a-z0-9-]{1,63}$ ]]; then
        echo "Error: arc id must be lowercase slug ([a-z0-9-], 2-64 chars). Got: '$id'" >&2
        return 1
    fi
}

# T-1852: state-machine helpers.
_arc_get_status() {
    local id="$1" f
    f="$(_arc_path "$id")"
    [ -f "$f" ] || return 1
    awk -F': ' '/^status:/ {sub(/^status:[[:space:]]*/, ""); print; exit}' "$f" \
        | tr -d ' "' | head -c 32
}

_arc_require_status() {
    # Refuse unless the arc is currently in one of the expected states.
    # Usage: _arc_require_status <id> <verb> <expected1> [expected2 ...]
    local id="$1" verb="$2"; shift 2
    local cur expected
    cur="$(_arc_get_status "$id")"
    for expected in "$@"; do
        [ "$cur" = "$expected" ] && return 0
    done
    echo "Error: 'fw arc ${verb}' refused — arc '$id' is currently '${cur:-unknown}'." >&2
    echo "       Expected one of: $*" >&2
    echo "       Allowed transitions (T-1852):" >&2
    echo "         draft       → in-progress (fw arc start)" >&2
    echo "         draft       → abandoned   (fw arc abandon, T-1854)" >&2
    echo "         in-progress → closed      (fw arc close)" >&2
    echo "         in-progress → abandoned   (fw arc abandon, T-1854)" >&2
    return 1
}

_arc_path() {
    echo "${ARCS_DIR}/$1.yaml"
}

_arc_exists() {
    [ -f "$(_arc_path "$1")" ]
}

# T-1848: allocate next sequential arc-NNN ID.
# Scans existing .context/arcs/*.yaml for `id: arc-NNN` patterns, returns
# `arc-<max+1>` zero-padded to 3 digits. D-Immutability axiom (rule 2)
# means we use MAX not COUNT — abandoned/missing slots are NEVER reused.
_arc_next_numeric_id() {
    _arc_ensure_dir
    local max=0 cur
    if compgen -G "${ARCS_DIR}/*.yaml" >/dev/null 2>&1; then
        for f in "${ARCS_DIR}"/*.yaml; do
            cur=$(awk '/^id:[[:space:]]*arc-[0-9]/ {gsub(/[^0-9]/, "", $2); print $2; exit}' "$f")
            # T-1877: force decimal base — `008`/`009` are invalid octal and would
            # break the printf arithmetic expansion at the tail of this function.
            # Normalize at extract time so `max` is always integer-form.
            [ -n "$cur" ] || continue
            cur=$((10#$cur))
            if [ "$cur" -gt "$max" ]; then
                max="$cur"
            fi
        done
    fi
    printf 'arc-%03d\n' $((max + 1))
}

# T-1848: dual identity resolver.
# Given `slug` (filename stem) OR `arc-NNN` (numeric id), return the
# canonical slug (filename stem). Used by route handlers and the CLI
# to accept either form.
#
# Returns:
#   0 + slug-on-stdout when match found
#   1 + nothing        when no match
_arc_resolve_slug() {
    local input="$1"
    [ -n "$input" ] || return 1
    _arc_ensure_dir

    # Direct filename match (slug case)
    if [ -f "${ARCS_DIR}/${input}.yaml" ]; then
        echo "$input"
        return 0
    fi

    # Numeric id scan (arc-NNN case)
    if [[ "$input" =~ ^arc-[0-9]+$ ]]; then
        if compgen -G "${ARCS_DIR}/*.yaml" >/dev/null 2>&1; then
            for f in "${ARCS_DIR}"/*.yaml; do
                local stored
                stored=$(awk '/^id:[[:space:]]*/ {print $2; exit}' "$f")
                if [ "$stored" = "$input" ]; then
                    basename "$f" .yaml
                    return 0
                fi
            done
        fi
    fi

    return 1
}

# T-1848: normalize CLI input to the canonical slug (filename stem).
# Pure CLI ergonomics — any verb that takes <arc-id> arg routes through this.
# Returns the input unchanged when no match found (so error paths fire on
# the original user input, not a confused empty string).
_arc_normalize_input() {
    local input="$1"
    local slug
    slug=$(_arc_resolve_slug "$input") && [ -n "$slug" ] && { echo "$slug"; return 0; }
    echo "$input"
    return 0
}

# T-1848: return the canonical arc-NNN id for a slug (or arc-NNN passthrough).
# Returns:
#   0 + arc-NNN-on-stdout when arc has an allocated numeric id
#   0 + slug-on-stdout    when arc predates T-1848 migration (still in `id: <slug>` form)
#   1                     when arc not found
_arc_numeric_id_for() {
    local input="$1"
    local slug
    slug=$(_arc_resolve_slug "$input") || return 1
    awk '/^id:[[:space:]]*/ {print $2; exit}' "${ARCS_DIR}/${slug}.yaml"
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

# Membership-scan helpers. T-1914 consolidation: these three private wrappers
# delegate to the canonical helpers in `lib/arc_membership.sh` (sourced at
# script load via _arc_source_membership_lib). The inline implementations
# previously here drifted from the canonical helper (T-1913 had to patch
# both sides for the slug↔NNN union fix) — that's the L-397 silent-corpus
# pattern one layer deeper (equivalence-logic-inside-canonical-vs-inline).
# Names preserved (`_arc_*`) so existing call sites at lines 561, 601, 965,
# 972 keep working unchanged.
_arc_tasks_with_tag() { arc_tasks_with_tag "$@"; }
_arc_tasks_with_arc_id() { arc_tasks_with_arc_id "$@"; }
_arc_tasks_for() { arc_tasks_for "$@"; }

# ─── verbs ──────────────────────────────────────────────────────────────────

arc_create() {
    local id="" name="" anchor="" description="" headline_mechanic="" start_now=0
    while [ $# -gt 0 ]; do
        case "$1" in
            --name) name="$2"; shift 2;;
            --anchor) anchor="$2"; shift 2;;
            --description) description="$2"; shift 2;;
            --headline-mechanic) headline_mechanic="$2"; shift 2;;
            --start) start_now=1; shift;;
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

    # T-1848: allocate next sequential arc-NNN. D-Immutability: never reused.
    local arc_numeric_id
    arc_numeric_id="$(_arc_next_numeric_id)"

    # T-1816: yaml-safe-quote all free-text string fields. Origin: dispatch-safety
    # arc shipped with `name: Dispatch safety: Worker uncertainty handling` —
    # unquoted colon parsed as a nested mapping, broke Watchtower /arcs/dispatch-safety.
    # Quote name, description, headline_mechanic via yaml.safe_dump (handles colons,
    # arrows, quotes, hash marks). Anchor stays bare (validated as a task ID).
    local name_yaml desc_yaml hm_yaml
    name_yaml=$(printf '%s' "$name" | python3 -c 'import yaml,sys; print(yaml.safe_dump(sys.stdin.read().rstrip("\n"), default_style=chr(34)).rstrip())')
    desc_yaml=$(printf '%s' "$description" | python3 -c 'import yaml,sys; print(yaml.safe_dump(sys.stdin.read().rstrip("\n"), default_style=chr(34)).rstrip())')
    hm_yaml=$(printf '%s' "$headline_mechanic" | python3 -c 'import yaml,sys; print(yaml.safe_dump(sys.stdin.read().rstrip("\n"), default_style=chr(34)).rstrip())')

    # T-1851: constituent_tasks: field deprecated. Source-of-truth for arc
    # membership is task-side arc_id: (T-1849). Legacy arcs created before
    # 2026-05-16 retain their entries untouched (D-Immutability). Readers
    # (web/blueprints/arcs.py, agents/audit/audit.sh) already merge
    # arc_id/tag scan with legacy constituent_tasks via .get(..., []).
    # T-1852: new arcs are born `draft` by default. Use `fw arc start <slug>` to
    # transition to `in-progress` once the arc is ready to actively work.
    # --start flag (T-1852 counter-proposal): one-step convenience for the
    # "scaffold + immediately work" case — writes status: in-progress directly.
    local initial_status="draft"
    [ "$start_now" = "1" ] && initial_status="in-progress"

    cat > "$(_arc_path "$id")" <<YAML
id: ${arc_numeric_id}
slug: ${id}
name: ${name_yaml}
description: ${desc_yaml}
status: ${initial_status}
anchor_task: ${anchor}
headline_mechanic: ${hm_yaml}
demo_evidence: null
created: ${now}
closed_at: null
decision: null
# T-1918 (arc-006, value-prioritisation): BVP scoring fields. Semantics in
# docs/reports/T-1915-bvp-inception.md §4 (D7-reframe) and §7 (M2).
bvp_scores: {}
scoped_drivers: []           # max 3, weight ≤6 each (M2). Approved by fw arc approve-driver (T-1926).
proposed_scoped_drivers: []  # uncapped persistence (D7-reframe). Estimator may write here freely.
YAML

    echo "Created arc '${id}' (${arc_numeric_id}) → $(_arc_path "$id")"
    [ -n "$anchor" ] && echo "  anchor: ${anchor}"
    echo "  headline_mechanic: ${headline_mechanic}"
    if [ "$start_now" = "1" ]; then
        echo "  status: in-progress (created with --start)"
    else
        echo "  status: draft (use 'fw arc start ${id}' to begin)"
    fi
    return 0
}

# T-1852: state transition — draft → in-progress.
arc_start() {
    local id="${1:-}"
    [ -n "$id" ] || { echo "Usage: fw arc start <arc-id>" >&2; return 2; }
    id="$(_arc_normalize_input "$id")"
    _arc_validate_id "$id" || return 2
    _arc_exists "$id" || { echo "Error: arc '$id' not found" >&2; return 1; }
    _arc_require_status "$id" "start" "draft" || return 1

    local f
    f="$(_arc_path "$id")"
    # In-place status flip. D-Immutability: file stays, only status: line edits.
    python3 - "$f" <<'PY'
import re, sys
fn = sys.argv[1]
text = open(fn).read()
new = re.sub(r'^status:\s*draft\s*$', 'status: in-progress', text, count=1, flags=re.MULTILINE)
if new == text:
    print("Error: status: draft line not found", file=sys.stderr)
    sys.exit(1)
open(fn, "w").write(new)
PY
    echo "Arc '$id' started: draft → in-progress"
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

    # T-1848: accept slug or arc-NNN; normalize to canonical slug for storage.
    id="$(_arc_normalize_input "$id")"

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
        local id slug status name task_count marker
        id=$(awk -F': ' '/^id:/ {print $2; exit}' "$f")
        # T-1848: slug is the tag namespace; arc-NNN is the display id.
        slug=$(awk -F': ' '/^slug:/ {print $2; exit}' "$f")
        [ -z "$slug" ] && slug="$(basename "$f" .yaml)"
        status=$(awk -F': ' '/^status:/ {print $2; exit}' "$f")
        name=$(awk -F': ' '/^name:/ {sub(/^name: /,""); print; exit}' "$f")
        task_count=$(_arc_tasks_for "${slug}" | wc -l | tr -d ' ')
        marker="  "
        if [ "$id" = "$current" ] || [ "$slug" = "$current" ]; then marker=" *"; fi
        printf "%-2s %-30s %-12s %-7s %s\n" "$marker" "$id" "$status" "$task_count" "$name"
    done
    [ -n "$current" ] && echo "" && echo "(* = focused arc)"
    return 0
}

arc_show() {
    local id="${1:-}"
    [ -n "$id" ] || { echo "Usage: fw arc show <arc-id>" >&2; return 2; }
    # T-1848: accept slug or arc-NNN.
    id="$(_arc_normalize_input "$id")"
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
    done < <(_arc_tasks_for "${id}")
    [ "$found" -eq 0 ] && echo "  (no tasks yet — set 'arc_id: $id' on a task's frontmatter)"

    [ "$id" = "$current" ] && echo "" && echo "[FOCUSED]"
    return 0
}

arc_tag() {
    local id="${1:-}" tid="${2:-}"
    [ -n "$id" ] && [ -n "$tid" ] || { echo "Usage: fw arc tag <arc-id> T-XXXX" >&2; return 2; }
    # T-1848: accept slug or arc-NNN; tag uses slug namespace (T-NEW-3 will switch).
    id="$(_arc_normalize_input "$id")"
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
    # T-1851: field deprecated for new arcs (post-2026-05-16). When the field
    # is absent, the Python heredoc below returns early via `if not m: sys.exit(0)`
    # — silent no-op for new arcs, continued maintenance for legacy arcs.
    # Canonical source-of-truth is task-side arc_id: (T-1849).
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
    # T-1848: accept slug or arc-NNN; downstream paths use canonical slug.
    id="$(_arc_normalize_input "$id")"
    _arc_validate_id "$id" || return 2
    _arc_exists "$id" || { echo "Error: arc '$id' not found" >&2; return 1; }

    # T-1852 state-machine guard: only `in-progress` arcs can be closed.
    # draft → closed is REFUSED — start the arc first (or abandon it via
    # fw arc abandon, T-1854). closed/abandoned arcs cannot be re-closed.
    _arc_require_status "$id" "close" "in-progress" || return 1

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

# T-1854 (T-NEW-6): abandon an arc that is no longer being pursued.
# Allowed source states: draft, in-progress (rejected from closed, abandoned).
# Refuses without --reason (≥30 chars). Refuses under $CLAUDECODE=1 unless
# --i-am-human or --from-watchtower (T-1671 agent-gate copy-paste from arc_close).
# Appends to .context/audits/arc-abandon.jsonl (separate from arc-bypass.jsonl).
# D-Immutability: arc YAML stays in .context/arcs/, never moved or deleted.
arc_abandon() {
    local id="" reason=""
    local i_am_human=false from_watchtower=false
    while [ $# -gt 0 ]; do
        case "$1" in
            --reason) reason="$2"; shift 2;;
            --i-am-human) i_am_human=true; shift;;
            --from-watchtower) from_watchtower=true; shift;;
            *) [ -z "$id" ] && id="$1" || { echo "Unexpected arg: $1" >&2; return 2; }; shift;;
        esac
    done
    [ -n "$id" ] || { echo "Usage: fw arc abandon <arc-id> --reason \"<≥30 chars>\"" >&2; return 2; }
    id="$(_arc_normalize_input "$id")"
    _arc_validate_id "$id" || return 2
    _arc_exists "$id" || { echo "Error: arc '$id' not found" >&2; return 1; }

    # T-1852 state-machine guard: draft and in-progress can be abandoned.
    # closed and abandoned arcs cannot be re-abandoned.
    _arc_require_status "$id" "abandon" "draft" "in-progress" || return 1

    # T-1671 §ACD/G-062 Default-to-OPEN agent gate. Abandonment is a closure
    # decision — same authority weight as arc_close + inception decide. Mirror
    # the exact gate pattern from arc_close so the override semantics match.
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
        echo "Error: agents must not invoke 'fw arc abandon' directly (§ACD/G-062, T-1671)." >&2
        echo "" >&2
        echo "  You appear to be running inside Claude Code (\$CLAUDECODE=1)." >&2
        echo "  Arc abandonment carries the same authority weight as arc closure" >&2
        echo "  and belongs to the human (Default-to-OPEN: ≥2 prior pushbacks → OPEN" >&2
        echo "  regardless of new evidence)." >&2
        echo "" >&2
        echo "  Correct flow:" >&2
        if [ -n "$anchor" ]; then
            echo "    1. Agent: bin/fw task review ${anchor}" >&2
        else
            echo "    1. Agent: bin/fw task review <arc-anchor-task>" >&2
        fi
        echo "    2. Human: open the Watchtower URL, review the reasoning," >&2
        echo "       run 'bin/fw arc abandon ${id} --reason \"...\"'" >&2
        echo "" >&2
        echo "  Arc detail: ${wt_url}/arcs/${id}" >&2
        echo "" >&2
        echo "  Overrides (mirror T-1259 inception-decide): --i-am-human (human typing" >&2
        echo "  into an agent session, rare); --from-watchtower (Flask backend)." >&2
        echo "  See CLAUDE.md §Arc Completion Discipline." >&2
        return 1
    fi

    # --reason validation. Symmetric to arc_close --justification (≥30 chars).
    if [ -z "$reason" ] || [ "${#reason}" -lt 30 ]; then
        echo "Error: --reason \"<≥30 chars>\" is required." >&2
        echo "  Abandonment is a final-state event — capture WHY in enough detail" >&2
        echo "  that a reader 6 months from now can understand the call:" >&2
        echo "    fw arc abandon $id --reason \"<detailed rationale, ≥30 chars>\"" >&2
        return 2
    fi

    local f now status_at
    f="$(_arc_path "$id")"
    now="$(_arc_now)"
    status_at="$(_arc_get_status "$id")"

    # Append JSONL audit row BEFORE the YAML mutation so a partial-write leaves
    # the audit trail intact even if the python rewrite fails.
    local logf="$PROJECT_ROOT/.context/audits/arc-abandon.jsonl"
    mkdir -p "$(dirname "$logf")"
    printf '{"arc":"%s","ts":"%s","status_at_abandon":"%s","abandonment_reason":%s}\n' \
        "$id" "$now" "$status_at" \
        "$(printf '%s' "$reason" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')" \
        >> "$logf"

    python3 - "$f" "$now" "$reason" <<'PY'
import re, sys
fn, now, reason = sys.argv[1], sys.argv[2], sys.argv[3]
text = open(fn).read()
text = re.sub(r'^status:.*$', 'status: abandoned', text, count=1, flags=re.MULTILINE)

safe_reason = reason.replace('"', '\\"')
# abandoned_at: add if missing, else replace.
if re.search(r'^abandoned_at:', text, re.MULTILINE):
    text = re.sub(r'^abandoned_at:.*$', f'abandoned_at: {now}', text, count=1, flags=re.MULTILINE)
else:
    text = text.rstrip("\n") + f'\nabandoned_at: {now}\n'
# abandonment_reason: same pattern.
if re.search(r'^abandonment_reason:', text, re.MULTILINE):
    text = re.sub(r'^abandonment_reason:.*$', f'abandonment_reason: "{safe_reason}"', text, count=1, flags=re.MULTILINE)
else:
    text = text.rstrip("\n") + f'\nabandonment_reason: "{safe_reason}"\n'
open(fn, "w").write(text)
PY

    echo "Abandoned arc '${id}' at ${now} (was: ${status_at})"
    echo "  reason: ${reason}"
    echo "  audit:  .context/audits/arc-abandon.jsonl"

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
                            T-1852: new arcs are born status: draft. Use 'fw arc start'
                            to transition to in-progress when ready.
  start <id>                T-1852: transition draft → in-progress. Refused on any
                            other source state.
  focus <id> | --clear      Set/clear the focused arc (one at a time)
  list                      Show all arcs (* marks focused)
  show <id>                 Detail: metadata + constituent tasks
  tag <id> T-XXXX           Add arc:<id> tag to a task. Legacy: also appends to
                            arc's constituent_tasks: if present (T-1851 deprecation).
                            Source-of-truth is task-side arc_id: (T-1849).
  close <id> --demo <path|url|none> [--justification "..."] [--decision "..."]
                            Mark arc closed. --demo is REQUIRED (§ACD/G-062):
                            wire-level evidence of the headline_mechanic firing.
                            Use 'none' + --justification (≥30 chars) for arcs
                            with no runtime mechanic — bypass is logged.
  review <id>               T-1962: print Watchtower /arcs/<id>/close URL + QR code
                            for human approval. Mirrors 'fw task review T-XXX'.
                            Use this under \$CLAUDECODE=1 (T-1671 §ACD) — agents
                            emit the URL, humans submit the form.
  abandon <id> --reason "<≥30 chars>"
                            T-1854: mark arc abandoned (no longer pursued).
                            Allowed source states: draft, in-progress.
                            Refused under \$CLAUDECODE=1 (T-1671 agent-gate).
                            JSON row appended to .context/audits/arc-abandon.jsonl.
                            D-Immutability: YAML stays, never moved/deleted.
  approve-driver <id> "<name>" [--weight N] [--i-am-human|--from-watchtower]
  approve-driver <id> --none --justification "<≥30 chars>"
                            T-1926: append a scoped driver (cap 3, weight ≤6) or
                            declare none. Refused under \$CLAUDECODE=1 (§ACD, M6).
  remove-driver <id> "<name>" --rationale "<≥30 chars>" [--i-am-human|--from-watchtower]
  set-scoped-weight <id> "<name>" --weight N --rationale "<≥30 chars>" [--i-am-human|--from-watchtower]
                            T-1977: mutate scoped_drivers[].weight in place.
                            T-1976: remove a named entry from scoped_drivers:.
                            Refuses on unknown names. Symmetric with
                            'fw bvp driver --remove' for arc-scoped drivers.
                            Refused under \$CLAUDECODE=1 (§ACD, M6).
  show-suggestions <id>     T-1926: read-only render of proposed_scoped_drivers:
                            grouped by event timestamp.
  rescore <id>              T-2076: re-run BVP estimator on every active member
                            task of the arc. Auto-fired by approve-driver as a
                            deterministic consequence of authorisation. Only
                            updates bvp_scores_proposed: (sovereignty boundary).
  migrate <id> --anchor T-XXXX
                            Legacy verb: seed constituent_tasks from anchor's
                            related_tasks and legacy from-T-XXXX tags (idempotent).
                            T-1851: prefer task-side arc_id: + 'fw arc tag'.

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

# T-1962: arc review verb — print Watchtower close-review URL + QR code.
# Mirrors `fw task review T-XXX` shape (T-631/T-634) for arc closure flow.
# Under $CLAUDECODE=1 the agent uses this in place of `fw arc close` (T-1671):
#   agent runs `fw arc review <slug>` → emits clickable URL + QR → human opens
#   /arcs/<slug>/close (T-1911/T-1902) → submits via the §ACD-exempt
#   `--from-watchtower` path which the Flask backend invokes.
arc_review() {
    local id="${1:-}"
    [ -n "$id" ] || { echo "Usage: fw arc review <arc-id-or-slug>" >&2; return 2; }
    id="$(_arc_normalize_input "$id")"
    _arc_validate_id "$id" || return 2
    _arc_exists "$id" || { echo "Error: arc '$id' not found" >&2; return 1; }

    local arc_path status anchor name
    arc_path="$(_arc_path "$id")"
    status=$(awk '/^status:[[:space:]]/ {print $2; exit}' "$arc_path" | tr -d ' "')
    anchor=$(awk '/^anchor_task:[[:space:]]/ {print $2; exit}' "$arc_path" | tr -d ' "')
    name=$(awk -F': ' '/^name:[[:space:]]/ {sub(/^[[:space:]"]+/,"",$2); sub(/[[:space:]"]+$/,"",$2); print $2; exit}' "$arc_path")

    # Refuse on terminal states — no closure review needed.
    if [ "$status" = "closed" ] || [ "$status" = "abandoned" ]; then
        echo "Arc '$id' is $status — no close-review URL emitted." >&2
        echo "View arc detail: \$(fw watchtower url)/arcs/$id" >&2
        return 1
    fi

    # Source Watchtower helper for URL resolution (per-project port, T-885/T-1287/T-1376).
    if ! declare -F _watchtower_url >/dev/null 2>&1; then
        # shellcheck source=lib/watchtower.sh
        source "${FRAMEWORK_ROOT:-${PROJECT_ROOT:-.}}/lib/watchtower.sh" 2>/dev/null || true
    fi
    local base_url review_url
    if declare -F _watchtower_url >/dev/null 2>&1; then
        base_url=$(_watchtower_url "$id" 2>/dev/null || true)
    fi
    [ -z "$base_url" ] && base_url="http://localhost:3000"
    review_url="${base_url}/arcs/${id}/close"

    echo ""
    echo "══════════════════════════════════════════"
    echo "  Arc Close Review: $id"
    [ -n "$name" ]   && echo "  Name:   $name"
    [ -n "$status" ] && echo "  Status: $status"
    [ -n "$anchor" ] && echo "  Anchor: $anchor"
    echo ""
    echo "  $review_url"
    echo ""

    # QR code (mirrors lib/review.sh emit_review).
    python3 -c "
import sys
try:
    import qrcode
    qr = qrcode.QRCode(border=1, box_size=1)
    qr.add_data('$review_url')
    qr.make()
    qr.print_ascii(invert=True)
except ImportError:
    print('  (install python3-qrcode for QR code)')
" 2>/dev/null

    echo ""
    echo "  Scan QR or open link above to review/approve arc closure."
    echo "  Human submits via the form → fw arc close --from-watchtower (T-1671 §ACD-exempt)."
    echo "══════════════════════════════════════════"
    echo ""
}

arc_dispatch() {
    local verb="${1:-help}"
    shift || true
    case "$verb" in
        create)  arc_create  "$@";;
        start)   arc_start   "$@";;
        focus)   arc_focus   "$@";;
        list|ls) arc_list    "$@";;
        show)    arc_show    "$@";;
        tag)     arc_tag     "$@";;
        close)   arc_close   "$@";;
        review)  arc_review  "$@";;                     # T-1962
        abandon) arc_abandon "$@";;
        migrate) arc_migrate "$@";;
        approve-driver)   arc_approve_driver   "$@";;   # T-1926 (arc-006)
        remove-driver)    arc_remove_driver    "$@";;   # T-1976 (arc-006)
        set-scoped-weight) arc_set_scoped_weight "$@";; # T-1977 (arc-006)
        show-suggestions) arc_show_suggestions "$@";;   # T-1926 (arc-006)
        rescore)          arc_rescore          "$@";;   # T-2076 (T-2065 GO): re-estimate member BVP
        help|--help|-h) arc_help;;
        *) echo "Unknown verb: $verb" >&2; arc_help; return 2;;
    esac
}

# ─────────────────────────────────────────────────────────────────────────────
# T-1926 (arc-006, value-prioritisation): arc approve-driver + show-suggestions.
#
# arc_approve_driver: appends to scoped_drivers: (cap 3, M2 weight ≤6) or accepts
# `--none --justification "..."` to declare zero scoped drivers. On first
# approval (or on --none), flips arc status: draft → in-progress.
#
# arc_show_suggestions: read-only render of proposed_scoped_drivers: grouped by
# event timestamp (D7-reframe — workflow verb the human runs when focus shifts
# to an arc, NOT a debug verb).
#
# §ACD shape from T-1671 reused (refuse under $CLAUDECODE=1 unless --i-am-human
# or --from-watchtower). Form validation precedes authority gate per T-1920
# ordering decision.

arc_approve_driver() {
    local id="" name="" weight="" rationale="" justification="" want_none=false
    local i_am_human=false from_watchtower=false
    while [ $# -gt 0 ]; do
        case "$1" in
            --weight) weight="$2"; shift 2;;
            --rationale) rationale="$2"; shift 2;;        # T-1976: persist rationale on scoped_drivers entry
            --none) want_none=true; shift;;
            --justification) justification="$2"; shift 2;;
            --i-am-human) i_am_human=true; shift;;
            --from-watchtower) from_watchtower=true; shift;;
            --help|-h) _arc_approve_help; return 0;;
            *)
                if [ -z "$id" ]; then id="$1"
                elif [ -z "$name" ]; then name="$1"
                else echo "Unexpected arg: $1" >&2; return 2; fi
                shift;;
        esac
    done

    if [ -z "$id" ]; then
        _arc_approve_help
        return 2
    fi

    id="$(_arc_normalize_input "$id")"
    _arc_validate_id "$id" || return 2
    _arc_exists "$id" || { echo "Error: arc '$id' not found" >&2; return 1; }

    # ── --none path ──
    if [ "$want_none" = "true" ]; then
        if [ -z "$justification" ]; then
            echo "Error: --none requires --justification (≥30 chars)." >&2
            echo "  Explain why this arc has no driver worth scoring separately." >&2
            return 2
        fi
        if [ "${#justification}" -lt 30 ]; then
            echo "Error: --justification must be ≥30 characters (got ${#justification})." >&2
            return 2
        fi
        if ! _arc_approve_driver_acd_gate "approve-driver --none" "$i_am_human" "$from_watchtower"; then
            return 1
        fi
        _arc_log_scoped_bypass "$id" "$justification"
        _arc_flip_to_in_progress_if_draft "$id"
        echo "OK: arc '$id' approved with no scoped drivers (--none)."
        echo "  Justification logged to .context/audits/arc-scoped-driver-bypass.jsonl"
        return 0
    fi

    # ── approve-driver normal path ──
    if [ -z "$name" ]; then
        echo "Error: driver name is required." >&2
        _arc_approve_help
        return 2
    fi

    local w="${weight:-3}"
    if ! printf '%s' "$w" | grep -qE '^[0-9]+$'; then
        echo "Error: --weight must be an integer (got: $w)" >&2
        return 2
    fi
    if [ "$w" -lt 0 ] || [ "$w" -gt 6 ]; then
        echo "Error: --weight $w out of range. Scoped-driver weight is capped at 6 (M2)." >&2
        echo "  Reason: scoped drivers must not overwhelm the constitutional directives." >&2
        echo "  If you need a higher weight, propose this as a global free driver via fw bvp driver --add." >&2
        return 2
    fi

    local f
    f="$(_arc_path "$id")"

    # T-1979: Dedup check — refuse if name already in scoped_drivers.
    # Root cause of T-1976 round-trip bug: heredoc appended unconditionally.
    local existing_ts
    existing_ts=$(python3 - "$f" "$name" <<'PY'
import sys, yaml
fn, name = sys.argv[1], sys.argv[2]
d = yaml.safe_load(open(fn)) or {}
for sd in (d.get('scoped_drivers') or []):
    if sd.get('name') == name:
        ts = sd.get('approved_at', '?')
        # YAML parses unquoted ISO timestamps to datetime; render back to ISO-Z.
        if hasattr(ts, 'isoformat'):
            ts = ts.isoformat().replace('+00:00', 'Z')
        print(ts)
        break
PY
)
    if [ -n "$existing_ts" ]; then
        echo "Error: driver '$name' already in scoped_drivers (approved at $existing_ts)." >&2
        echo "  To re-approve with a different weight, first remove it:" >&2
        echo "    fw arc remove-driver $id \"$name\" --rationale \"<≥30 chars why>\"" >&2
        return 1
    fi

    # Cap check: max 3 scoped drivers.
    local current_count
    current_count=$(python3 -c "
import yaml
d = yaml.safe_load(open('$f')) or {}
print(len(d.get('scoped_drivers') or []))
")
    if [ "$current_count" -ge 3 ]; then
        echo "Error: scoped_drivers: already at cap (3 entries). M2 enforces max 3 per arc." >&2
        echo "  Current drivers:" >&2
        python3 -c "
import yaml
d = yaml.safe_load(open('$f')) or {}
for sd in (d.get('scoped_drivers') or []):
    print(f\"    - {sd.get('name')} (weight={sd.get('weight')})\")
" >&2
        return 1
    fi

    if ! _arc_approve_driver_acd_gate "approve-driver" "$i_am_human" "$from_watchtower"; then
        return 1
    fi

    # Append + flip-if-draft via python (preserves YAML structure).
    python3 - "$f" "$name" "$w" "$rationale" <<'PY'
import sys, datetime
try:
    from ruamel.yaml import YAML
    yaml_r = YAML(); yaml_r.preserve_quotes = True; yaml_r.indent(mapping=2, sequence=4, offset=2)
    HAS_RUAMEL = True
except ImportError:
    import yaml
    HAS_RUAMEL = False

fn, name, weight, rationale = sys.argv[1], sys.argv[2], int(sys.argv[3]), sys.argv[4]

if HAS_RUAMEL:
    with open(fn) as fh: data = yaml_r.load(fh)
else:
    import yaml
    data = yaml.safe_load(open(fn).read())

sd = data.get('scoped_drivers') or []
ts = datetime.datetime.now(datetime.timezone.utc).isoformat(timespec='seconds').replace('+00:00', 'Z')
entry = {'name': name, 'weight': weight, 'approved_at': ts}
if rationale:
    entry['rationale'] = rationale
sd.append(entry)
data['scoped_drivers'] = sd

# T-1979: remove matching proposal from proposed_scoped_drivers (case-sensitive name match).
# Without this, the Proposed table still shows the driver after approval (T-1976 round-trip bug).
proposed = data.get('proposed_scoped_drivers') or []
new_proposed = [p for p in proposed if p.get('name') != name]
if len(new_proposed) < len(proposed):
    data['proposed_scoped_drivers'] = new_proposed
    print(f"Removed matching proposal for '{name}'.")

if data.get('status') == 'draft':
    data['status'] = 'in-progress'

if HAS_RUAMEL:
    with open(fn, 'w') as fh: yaml_r.dump(data, fh)
else:
    with open(fn, 'w') as fh: yaml.safe_dump(data, fh, sort_keys=False, default_flow_style=False)
PY

    echo "OK: approved scoped driver '$name' (weight=$w) on arc '$id'."
    local new_status
    new_status=$(awk -F': ' '/^status:/ {print $2; exit}' "$f" | tr -d ' ')
    [ "$new_status" = "in-progress" ] && echo "  Arc status: draft → in-progress (first driver decision)."

    # T-2076 (T-2065 GO): deterministic-consequence rescore. Driver authorisation
    # is the sovereign act; BVP re-estimation is its mechanical consequence — runs
    # synchronously here so the constituent task scores reflect the new driver
    # weight immediately. Failure surfaces a WARN but does NOT roll back the
    # approval — sovereignty boundary is the approval, not the rescore.
    if ! arc_rescore "$id"; then
        echo "  WARN: rescore reported a failure (driver approval stands). Re-run: fw arc rescore $id" >&2
    fi
    return 0
}

# T-1976: arc remove-driver — symmetry with `fw bvp driver --remove` for arc-scoped drivers.
# Removes a named entry from scoped_drivers:. Rationale ≥30 chars (R6).
# §ACD-gated (T-1671 / T-1926 pattern).
arc_remove_driver() {
    local id="" name="" rationale=""
    local i_am_human=false from_watchtower=false
    while [ $# -gt 0 ]; do
        case "$1" in
            --rationale) rationale="$2"; shift 2;;
            --i-am-human) i_am_human=true; shift;;
            --from-watchtower) from_watchtower=true; shift;;
            --help|-h) _arc_remove_driver_help; return 0;;
            *)
                if [ -z "$id" ]; then id="$1"
                elif [ -z "$name" ]; then name="$1"
                else echo "Unexpected arg: $1" >&2; return 2; fi
                shift;;
        esac
    done

    if [ -z "$id" ] || [ -z "$name" ]; then
        _arc_remove_driver_help
        return 2
    fi

    if [ -z "$rationale" ]; then
        echo "Error: --rationale is required (≥30 chars, R6)." >&2
        echo "  Explain why this scoped driver is being removed." >&2
        return 2
    fi
    if [ "${#rationale}" -lt 30 ]; then
        echo "Error: --rationale must be ≥30 characters (got ${#rationale})." >&2
        return 2
    fi

    id="$(_arc_normalize_input "$id")"
    _arc_validate_id "$id" || return 2
    _arc_exists "$id" || { echo "Error: arc '$id' not found" >&2; return 1; }

    local f
    f="$(_arc_path "$id")"

    # Refuse on unknown driver name (no silent no-op).
    local found
    found=$(python3 -c "
import yaml
d = yaml.safe_load(open('$f')) or {}
print('1' if any((sd.get('name') == '$name') for sd in (d.get('scoped_drivers') or [])) else '0')
")
    if [ "$found" != "1" ]; then
        echo "Error: scoped driver '$name' not found on arc '$id'." >&2
        echo "  Current drivers:" >&2
        python3 -c "
import yaml
d = yaml.safe_load(open('$f')) or {}
sd = d.get('scoped_drivers') or []
if not sd:
    print('    (none)')
else:
    for x in sd:
        print(f\"    - {x.get('name')} (weight={x.get('weight')})\")
" >&2
        return 1
    fi

    if ! _arc_approve_driver_acd_gate "remove-driver" "$i_am_human" "$from_watchtower"; then
        return 1
    fi

    python3 - "$f" "$name" <<'PY'
import sys, datetime
try:
    from ruamel.yaml import YAML
    yaml_r = YAML(); yaml_r.preserve_quotes = True; yaml_r.indent(mapping=2, sequence=4, offset=2)
    HAS_RUAMEL = True
except ImportError:
    import yaml
    HAS_RUAMEL = False

fn, name = sys.argv[1], sys.argv[2]
if HAS_RUAMEL:
    with open(fn) as fh: data = yaml_r.load(fh)
else:
    data = yaml.safe_load(open(fn).read())

sd = data.get('scoped_drivers') or []
sd2 = [x for x in sd if x.get('name') != name]
data['scoped_drivers'] = sd2

if HAS_RUAMEL:
    with open(fn, 'w') as fh: yaml_r.dump(data, fh)
else:
    with open(fn, 'w') as fh: yaml.safe_dump(data, fh, sort_keys=False, default_flow_style=False)
PY

    # Audit row to the same bypass log used by approve-driver --none (single forensic surface).
    local log="$PROJECT_ROOT/.context/audits/arc-scoped-driver-removals.jsonl"
    mkdir -p "$(dirname "$log")"
    local ts rationale_safe
    ts=$(_arc_now)
    rationale_safe=$(printf '%s' "$rationale" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read())[1:-1])')
    printf '{"arc_id":"%s","ts":"%s","driver":"%s","rationale":"%s","who":"%s","agent_session":%s}\n' \
        "$id" "$ts" "$name" "$rationale_safe" "${USER:-unknown}" \
        "$([ "${CLAUDECODE:-}" = "1" ] && echo true || echo false)" >> "$log"

    echo "OK: removed scoped driver '$name' from arc '$id'."
    echo "  Rationale logged to .context/audits/arc-scoped-driver-removals.jsonl"
    return 0
}

# T-1977: arc set-scoped-weight — mutate scoped_drivers[].weight in place.
# Mirrors T-1929 /bvp slider commit at arc scope. §ACD-gated. R6 rationale ≥30 chars.
# Refuses on unknown name; weight constrained to 1-6 (M2).
arc_set_scoped_weight() {
    local id="" name="" weight="" rationale=""
    local i_am_human=false from_watchtower=false
    while [ $# -gt 0 ]; do
        case "$1" in
            --weight) weight="$2"; shift 2;;
            --rationale) rationale="$2"; shift 2;;
            --i-am-human) i_am_human=true; shift;;
            --from-watchtower) from_watchtower=true; shift;;
            --help|-h) _arc_set_scoped_weight_help; return 0;;
            *)
                if [ -z "$id" ]; then id="$1"
                elif [ -z "$name" ]; then name="$1"
                else echo "Unexpected arg: $1" >&2; return 2; fi
                shift;;
        esac
    done

    if [ -z "$id" ] || [ -z "$name" ]; then
        _arc_set_scoped_weight_help
        return 2
    fi

    if [ -z "$weight" ]; then
        echo "Error: --weight is required (1-6, M2)." >&2
        return 2
    fi
    if ! printf '%s' "$weight" | grep -qE '^[0-9]+$'; then
        echo "Error: --weight must be an integer (got: $weight)" >&2
        return 2
    fi
    if [ "$weight" -lt 1 ] || [ "$weight" -gt 6 ]; then
        echo "Error: --weight $weight out of range. Scoped-driver weight is 1-6 (M2 cap)." >&2
        echo "  Reason: scoped drivers must not overwhelm the constitutional directives." >&2
        return 2
    fi

    if [ -z "$rationale" ]; then
        echo "Error: --rationale is required (≥30 chars, R6)." >&2
        echo "  Explain why this weight is changing." >&2
        return 2
    fi
    if [ "${#rationale}" -lt 30 ]; then
        echo "Error: --rationale must be ≥30 characters (got ${#rationale})." >&2
        return 2
    fi

    id="$(_arc_normalize_input "$id")"
    _arc_validate_id "$id" || return 2
    _arc_exists "$id" || { echo "Error: arc '$id' not found" >&2; return 1; }

    local f
    f="$(_arc_path "$id")"

    # Refuse on unknown driver name (no silent no-op).
    local found
    found=$(python3 -c "
import yaml
d = yaml.safe_load(open('$f')) or {}
print('1' if any((sd.get('name') == '$name') for sd in (d.get('scoped_drivers') or [])) else '0')
")
    if [ "$found" != "1" ]; then
        echo "Error: scoped driver '$name' not found on arc '$id'." >&2
        echo "  Current drivers:" >&2
        python3 -c "
import yaml
d = yaml.safe_load(open('$f')) or {}
sd = d.get('scoped_drivers') or []
if not sd:
    print('    (none)')
else:
    for x in sd:
        print(f\"    - {x.get('name')} (weight={x.get('weight')})\")
" >&2
        return 1
    fi

    if ! _arc_approve_driver_acd_gate "set-scoped-weight" "$i_am_human" "$from_watchtower"; then
        return 1
    fi

    # Capture old weight for audit log, then mutate via ruamel (preserve comments).
    local old_weight
    old_weight=$(python3 - "$f" "$name" <<'PY'
import sys, yaml
fn, name = sys.argv[1], sys.argv[2]
d = yaml.safe_load(open(fn)) or {}
for sd in (d.get('scoped_drivers') or []):
    if sd.get('name') == name:
        print(sd.get('weight', '?'))
        break
PY
)

    python3 - "$f" "$name" "$weight" <<'PY'
import sys
try:
    from ruamel.yaml import YAML
    yaml_r = YAML(); yaml_r.preserve_quotes = True; yaml_r.indent(mapping=2, sequence=4, offset=2)
    HAS_RUAMEL = True
except ImportError:
    import yaml
    HAS_RUAMEL = False

fn, name, new_weight = sys.argv[1], sys.argv[2], int(sys.argv[3])

if HAS_RUAMEL:
    with open(fn) as fh: data = yaml_r.load(fh)
else:
    import yaml
    data = yaml.safe_load(open(fn).read())

sd = data.get('scoped_drivers') or []
for entry in sd:
    if entry.get('name') == name:
        entry['weight'] = new_weight
        break

if HAS_RUAMEL:
    with open(fn, 'w') as fh: yaml_r.dump(data, fh)
else:
    with open(fn, 'w') as fh: yaml.safe_dump(data, fh, sort_keys=False, default_flow_style=False)
PY

    # Audit row to dedicated weight-change history.
    local log="$PROJECT_ROOT/.context/audits/arc-scoped-weight-changes.jsonl"
    mkdir -p "$(dirname "$log")"
    local ts rationale_safe
    ts=$(_arc_now)
    rationale_safe=$(printf '%s' "$rationale" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read())[1:-1])')
    printf '{"arc_id":"%s","ts":"%s","driver":"%s","old_weight":%s,"new_weight":%s,"rationale":"%s","who":"%s","agent_session":%s}\n' \
        "$id" "$ts" "$name" "${old_weight:-null}" "$weight" "$rationale_safe" "${USER:-unknown}" \
        "$([ "${CLAUDECODE:-}" = "1" ] && echo true || echo false)" >> "$log"

    echo "OK: set weight of scoped driver '$name' on arc '$id' (${old_weight:-?} → $weight)."
    echo "  Change logged to .context/audits/arc-scoped-weight-changes.jsonl"
    return 0
}

_arc_set_scoped_weight_help() {
    echo "Usage:"
    echo "  fw arc set-scoped-weight <arc-id> \"<name>\" --weight N --rationale \"<≥30 chars>\" [--i-am-human|--from-watchtower]"
    echo ""
    echo "  Mutates scoped_drivers[].weight in place (T-1977, mirrors T-1929 /bvp sliders)."
    echo "  Weight must be 1-6 (M2 cap). Rationale ≥30 chars (R6 anti-Goodhart)."
    echo "  Audit row appended to .context/audits/arc-scoped-weight-changes.jsonl."
    echo ""
    echo "  Refuses under \$CLAUDECODE=1 unless --i-am-human or --from-watchtower (M6, §ACD)."
}

_arc_remove_driver_help() {
    echo "Usage:"
    echo "  fw arc remove-driver <arc-id> \"<name>\" --rationale \"<≥30 chars>\" [--i-am-human|--from-watchtower]"
    echo ""
    echo "  Removes a named entry from scoped_drivers:. Refuses on unknown names."
    echo "  Rationale ≥30 chars (R6). Audit row appended to"
    echo "  .context/audits/arc-scoped-driver-removals.jsonl."
    echo ""
    echo "  Refuses under \$CLAUDECODE=1 unless --i-am-human or --from-watchtower (M6, §ACD)."
}

arc_show_suggestions() {
    local id="${1:-}"
    if [ -z "$id" ] || [ "$id" = "--help" ] || [ "$id" = "-h" ]; then
        echo "Usage: fw arc show-suggestions <arc-id>"
        echo ""
        echo "  Render all entries in proposed_scoped_drivers: grouped by event timestamp."
        echo "  Read-only (D7-reframe: workflow verb the human runs when focus shifts to"
        echo "  an arc, NOT a debug verb)."
        echo ""
        echo "  See: fw arc approve-driver <arc-id> \"<name>\" [--weight N] [--i-am-human]"
        return 0
    fi
    id="$(_arc_normalize_input "$id")"
    _arc_validate_id "$id" || return 2
    _arc_exists "$id" || { echo "Error: arc '$id' not found" >&2; return 1; }
    local f
    f="$(_arc_path "$id")"
    python3 - "$f" "$id" <<'PY'
import sys, yaml
fn, arc_id = sys.argv[1], sys.argv[2]
data = yaml.safe_load(open(fn).read()) or {}
proposed = data.get('proposed_scoped_drivers') or []
approved = data.get('scoped_drivers') or []

print(f"Arc: {arc_id}")
print(f"Status: {data.get('status','-')}")
print()
print(f"Approved scoped_drivers ({len(approved)}/3):")
if approved:
    for sd in approved:
        print(f"  - {sd.get('name')} (weight={sd.get('weight')}, approved_at={sd.get('approved_at','-')})")
else:
    print("  (none yet)")
print()
print(f"Proposed (history, {len(proposed)} entries):")
if not proposed:
    print("  (none — primary agent has not yet proposed any drivers)")
else:
    # Group by ts; newest first.
    groups = {}
    for p in proposed:
        ts = p.get('ts', '?')
        groups.setdefault(ts, []).append(p)
    for ts in sorted(groups.keys(), reverse=True):
        print(f"  [{ts}]")
        for p in groups[ts]:
            print(f"    - {p.get('name','-')} (source={p.get('source','-')})")
            r = p.get('rationale')
            if r:
                print(f"      → {r}")
PY
    return 0
}

# ─────────────────────────────────────────────────────────────────────────────
# T-2076 (T-2065 GO scope): arc rescore — re-estimate BVP scores on every active
# member task of an arc. Two callsites:
#   1. Automatically invoked from arc_approve_driver as a deterministic
#      consequence of authorisation — new scoped-driver weight propagates to
#      member task scores immediately.
#   2. Standalone `fw arc rescore <arc-id>` for ad-hoc recompute (e.g. after a
#      bulk weight edit, recovery from a partial failure, or after the
#      estimator rubric_sha changes).
#
# Membership: union of `arc_id:` frontmatter (slug OR arc-NNN form) + legacy
# `arc:<slug>` tag — delegated to arc_tasks_for (lib/arc_membership.sh).
# Skips members already in .tasks/completed/ (final scores don't move).
#
# Sovereignty rail: this is NOT a decision-emitting operation. It re-runs the
# estimator (T-1922) which only writes bvp_scores_proposed: — never bvp_scores:.
# Confirmation still requires `fw bvp confirm` (T-1924). Safe to re-run.
#
# Idempotency: rerunning on the same corpus produces the same proposed scores
# (deterministic per rubric_sha) unless task body content changed.
# ─────────────────────────────────────────────────────────────────────────────
arc_rescore() {
    local input="${1:-}"
    if [ -z "$input" ] || [ "$input" = "--help" ] || [ "$input" = "-h" ]; then
        echo "Usage:"
        echo "  fw arc rescore <arc-id>"
        echo ""
        echo "  Re-run the BVP estimator on every active member task of the arc."
        echo "  Updates bvp_scores_proposed: (advisory layer); never touches"
        echo "  bvp_scores: (sovereignty boundary — confirm with fw bvp confirm)."
        echo ""
        echo "  Automatically fired by 'fw arc approve-driver' as a consequence"
        echo "  of authorisation. Run standalone after bulk weight edits or"
        echo "  estimator-rubric changes."
        [ -z "$input" ] && return 2 || return 0
    fi

    input="$(_arc_normalize_input "$input")"
    _arc_validate_id "$input" || return 2
    _arc_exists "$input" || { echo "Error: arc '$input' not found" >&2; return 1; }

    # Resolve to slug form for membership lookup (arc_tasks_for accepts either).
    local members
    members=$(arc_tasks_for "$input")
    if [ -z "$members" ]; then
        echo "  (no member tasks for arc '$input' — rescore skipped)"
        return 0
    fi

    # Filter to active members only (completed-task scores are frozen).
    local active_members=""
    local tid
    while IFS= read -r tid; do
        [ -n "$tid" ] || continue
        # arc_tasks_for already unioned active+completed; filter here.
        if ls "$PROJECT_ROOT"/.tasks/active/"$tid"-*.md >/dev/null 2>&1; then
            active_members="${active_members}${tid}"$'\n'
        fi
    done <<< "$members"

    if [ -z "$active_members" ]; then
        echo "  (no active member tasks for arc '$input' — rescore skipped)"
        return 0
    fi

    local count=0 failed=0
    echo "  Rescoring member tasks of arc '$input'..."
    while IFS= read -r tid; do
        [ -n "$tid" ] || continue
        # fw bvp estimate writes to stderr on errors; we want a tidy summary.
        if "${FW_BIN:-${PROJECT_ROOT}/bin/fw}" bvp estimate "$tid" >/dev/null 2>&1; then
            count=$((count + 1))
        else
            failed=$((failed + 1))
            echo "    WARN: estimator failed on $tid" >&2
        fi
    done <<< "$active_members"

    if [ "$failed" -eq 0 ]; then
        echo "  OK: rescored $count active member task(s)."
        return 0
    else
        echo "  Rescored $count task(s), $failed failed. See stderr above." >&2
        return 1
    fi
}

_arc_approve_help() {
    echo "Usage:"
    echo "  fw arc approve-driver <arc-id> \"<name>\" [--weight N] [--i-am-human|--from-watchtower]"
    echo "  fw arc approve-driver <arc-id> --none --justification \"<≥30 chars>\""
    echo ""
    echo "  Appends to scoped_drivers: (cap 3, M2 weight ≤6, default weight=3)."
    echo "  On first approval — or on --none — flips arc status: draft → in-progress."
    echo "  --none --justification declares the arc has no scoped drivers worth tracking;"
    echo "  the justification is logged to .context/audits/arc-scoped-driver-bypass.jsonl."
    echo ""
    echo "  Refuses under \$CLAUDECODE=1 unless --i-am-human or --from-watchtower (M6, §ACD)."
}

_arc_approve_driver_acd_gate() {
    local verb="$1" i_am_human="$2" from_watchtower="$3"
    if [ "${CLAUDECODE:-}" = "1" ] && [ "$i_am_human" = "false" ] && [ "$from_watchtower" = "false" ]; then
        echo "Error: agents must not invoke 'fw arc $verb' directly (§ACD, M6)." >&2
        echo "" >&2
        echo "  Driver approval is policy-edit authority (D8 — sovereignty at policy-edit time)" >&2
        echo "  and belongs to the human, recorded via Watchtower." >&2
        echo "" >&2
        echo "  Overrides (mirror T-1259 inception-decide / T-1671 arc-close):" >&2
        echo "    --i-am-human       human typing into an agent session (rare)" >&2
        echo "    --from-watchtower  Flask backend POST" >&2
        return 1
    fi
    return 0
}

_arc_log_scoped_bypass() {
    local arc_id="$1" justification="$2"
    local log="$PROJECT_ROOT/.context/audits/arc-scoped-driver-bypass.jsonl"
    mkdir -p "$(dirname "$log")"
    local ts
    ts=$(_arc_now)
    # Escape any embedded double-quotes in the justification for JSON safety.
    local justification_safe
    justification_safe=$(printf '%s' "$justification" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read())[1:-1])')
    printf '{"arc_id":"%s","ts":"%s","justification":"%s","who":"%s","agent_session":%s}\n' \
        "$arc_id" "$ts" "$justification_safe" "${USER:-unknown}" \
        "$([ "${CLAUDECODE:-}" = "1" ] && echo true || echo false)" >> "$log"
}

_arc_flip_to_in_progress_if_draft() {
    local id="$1"
    local f
    f="$(_arc_path "$id")"
    local cur
    cur=$(awk -F': ' '/^status:/ {print $2; exit}' "$f" | tr -d ' ')
    if [ "$cur" = "draft" ]; then
        python3 - "$f" <<'PY'
import re, sys
fn = sys.argv[1]
text = open(fn).read()
new = re.sub(r'^status:\s*draft\s*$', 'status: in-progress', text, count=1, flags=re.MULTILINE)
open(fn, "w").write(new)
PY
        echo "  Arc status: draft → in-progress (driver decision recorded)."
    fi
}
