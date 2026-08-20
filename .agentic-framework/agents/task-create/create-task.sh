#!/bin/bash
# Task Creation Agent - Mechanical Operations
# Creates properly structured tasks following the framework specification

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$FRAMEWORK_ROOT/lib/paths.sh"

# Source enumerations (single source of truth)
# Note: lib/errors.sh already sourced via lib/paths.sh (die, warn, error, info, success)
source "$FRAMEWORK_ROOT/lib/enums.sh"

# T-1279/T-1424: serialize ID allocation to prevent concurrent invocations from
# colliding on the same T-NNNN. Without this, 4+ parallel `fw work-on`
# calls all read the same max_id and all write T-${max+1}. See G-052.
# T-1424: fail loudly if the lock primitive can't be loaded — silent skip means silent race.
source "$FRAMEWORK_ROOT/lib/keylock.sh" || {
    echo "create-task.sh: failed to source lib/keylock.sh — cannot serialize ID allocation" >&2
    exit 1
}
type keylock_acquire >/dev/null 2>&1 || {
    echo "create-task.sh: keylock_acquire not defined after sourcing keylock.sh" >&2
    exit 1
}

# Colors provided by lib/colors.sh (via paths.sh chain)

# Parse arguments
NAME=""
DESCRIPTION=""
WORKFLOW_TYPE=""
OWNER=""
TAGS=""
RELATED=""
HORIZON="now"
START_WORK=false
# T-2207 (T-2204 Slice B'): filing-time recommendation gate for inception
# tasks — CLI mirror of T-1716's contract on do_inception_start.
RECOMMENDATION=""
RATIONALE=""
I_AM_HUMAN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --name) NAME="$2"; shift 2 ;;
        --description) DESCRIPTION="$2"; shift 2 ;;
        --type) WORKFLOW_TYPE="$2"; shift 2 ;;
        --owner) OWNER="$2"; shift 2 ;;
        --tags) TAGS="$2"; shift 2 ;;
        --related) RELATED="$2"; shift 2 ;;
        --horizon) HORIZON="$2"; shift 2 ;;
        --start) START_WORK=true; shift ;;
        --recommendation) RECOMMENDATION="$2"; shift 2 ;;
        --rationale) RATIONALE="$2"; shift 2 ;;
        --i-am-human) I_AM_HUMAN=true; shift ;;
        # T-1890: focus-drift hook sentinel; consumed silently. Sibling of the
        # identical branch in update-task.sh:1290. T-2830 found this leg missing:
        # `fw work-on <name> --switch-focus` shells to THIS script on the create
        # path, so a contract that only update-task.sh honours is incomplete
        # (L-399 — a bypass mechanism must be honoured by every consumer the
        # gating hook can route to, or the caller is pushed onto an ungoverned path).
        --switch-focus) shift ;;
        -h|--help)
            echo "Usage: create-task.sh [options]"
            echo ""
            echo "Options:"
            echo "  --name             Task name (required)"
            echo "  --description      Task description (required)"
            echo "  --type             Workflow type: $VALID_TYPES"
            echo "  --owner            Task owner (required)"
            echo "  --tags             Comma-separated tags (e.g. \"watchtower,ui,inception\")"
            echo "  --related          Comma-separated related task IDs (e.g. \"T-084,T-085\")"
            echo "  --horizon          Priority horizon: now (default), next, later"
            echo "  --start            Set status to started-work instead of captured"
            echo "  --recommendation   GO|NO-GO|DEFER — required for inception under \$CLAUDECODE=1 (T-1716, T-2207)"
            echo "  --rationale        Evidence-cited reason — required for inception under \$CLAUDECODE=1"
            echo "  --i-am-human       Bypass agent gate (scripts/tests/Watchtower) — logged Tier-2"
            echo "  -h, --help         Show this help"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# T-2207: validate --recommendation value if provided (parity with do_inception_start)
if [ -n "$RECOMMENDATION" ]; then
    case "$RECOMMENDATION" in
        GO|NO-GO|DEFER) ;;
        *)
            echo -e "${RED}Invalid --recommendation: '$RECOMMENDATION' (must be GO, NO-GO, or DEFER)${NC}" >&2
            exit 1
            ;;
    esac
fi

# T-2543: gate-level enforcement for promote-origin creates (Dimitri sovereignty bar,
# rail offset 60). When a caller marks a create as originating from `fw bpmn promote`
# (FW_TASK_ORIGIN=bpmn-promote), the GATE — not the caller — refuses anything but
# owner:human + captured. This closes the hole a future promote-caller bug could open:
# an owner:agent or --start promote-origin create is refused HERE, never silently
# written. Non-promote-origin creates are wholly unaffected (keyed off the marker).
# T-2577 extends the same gate to designer-ghost origin (T-2571 S4): save-time
# documentation-task minting for off-page ghost refs must land owner:human +
# captured — enforced HERE, caller-irrelevant, exactly like promote-origin.
case "${FW_TASK_ORIGIN:-}" in
  bpmn-promote|designer-ghost)
    if [ "$OWNER" != "human" ]; then
        echo -e "${RED}BLOCKED: ${FW_TASK_ORIGIN}-origin create must be owner:human (got '${OWNER:-<empty>}').${NC}" >&2
        echo "  Gated writers (fw bpmn promote / designer ghost minting) materialize human-owned tasks; the gate refuses otherwise." >&2
        echo "  Policy: T-2543 gate-level enforcement (Dimitri sovereignty bar, rail offset 60); T-2577 designer-ghost leg." >&2
        exit 1
    fi
    if [ "$START_WORK" = true ]; then
        echo -e "${RED}BLOCKED: ${FW_TASK_ORIGIN}-origin create must be captured (no --start).${NC}" >&2
        echo "  Gated-writer creates land captured for human review before work-start (G-020)." >&2
        echo "  Policy: T-2543 gate-level enforcement (Dimitri sovereignty bar, rail offset 60); T-2577 designer-ghost leg." >&2
        exit 1
    fi
    ;;
esac

# Interactive mode if required fields missing.
# T-100160 (OBS-086): prompt ONLY when stdin is a tty. In no-tty contexts
# (background dispatch, cron, TermLink workers) stdin is a socket/pipe that
# never delivers — `read -r` blocks forever (two >1h hangs, 2026-07-04).
# Non-interactive callers get a fail-fast error naming the missing flags.
if [ ! -t 0 ]; then
    _missing=""
    [ -z "$NAME" ] && _missing="$_missing --name"
    [ -z "$DESCRIPTION" ] && _missing="$_missing --description"
    [ -z "$WORKFLOW_TYPE" ] && _missing="$_missing --type"
    [ -z "$OWNER" ] && _missing="$_missing --owner"
    if [ -n "$_missing" ]; then
        die "Missing required flag(s):$_missing (stdin is not a tty — interactive prompts disabled; pass all required flags)"
    fi
fi

if [ -z "$NAME" ]; then
    echo -e "${YELLOW}Task name:${NC}"
    read -r NAME
fi

# T-555: Reject template placeholder names
_name_lower=$(echo "$NAME" | tr '[:upper:]' '[:lower:]' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
case "$_name_lower" in
    "task name"|"name"|"description"|"first criterion"|"second criterion"|\
    "task"|"my task"|"new task"|"test task"|"todo"|"fix bug"|"implement feature"|\
    "criterion"|"placeholder"|"example task"|"untitled")
        echo "ERROR: '$NAME' looks like a template placeholder, not a real task name." >&2
        echo "" >&2
        echo "  Provide a specific, descriptive name. Examples:" >&2
        echo "    --name \"Fix login timeout on slow connections\"" >&2
        echo "    --name \"Add retry logic to API client\"" >&2
        echo "    --name \"Inception: Evaluate caching strategy\"" >&2
        echo "" >&2
        exit 1
        ;;
esac

if [ -z "$DESCRIPTION" ]; then
    echo -e "${YELLOW}Task description:${NC}"
    read -r DESCRIPTION
fi

if [ -z "$WORKFLOW_TYPE" ]; then
    echo -e "${YELLOW}Workflow type ($VALID_TYPES):${NC}"
    read -r WORKFLOW_TYPE
fi

if [ -z "$OWNER" ]; then
    echo -e "${YELLOW}Owner (human or agent name):${NC}"
    read -r OWNER
fi

# Validate required fields
if [ -z "$NAME" ] || [ -z "$DESCRIPTION" ] || [ -z "$WORKFLOW_TYPE" ] || [ -z "$OWNER" ]; then
    die "Missing required fields"
fi

# Validate workflow type
if ! is_valid_type "$WORKFLOW_TYPE"; then
    error "Invalid workflow type '$WORKFLOW_TYPE'"
    die "Valid types: $VALID_TYPES"
fi

# Validate horizon
# T-2160 (arc-009 Slice 1): explicit guard against --horizon past at creation too.
if [ "$HORIZON" = "past" ]; then
    error "'--horizon past' rejected — past is a derived render-time value, not settable"
    error "  Past is computed from file location: .tasks/completed/ → renders as past."
    die "  Storage enum is now/next/later. Per T-2159 Q1=(b); arc-009."
fi
if ! is_valid_horizon "$HORIZON"; then
    error "Invalid horizon '$HORIZON'"
    die "Valid horizons: $VALID_HORIZONS"
fi

# Validate owner (T-2674, closes the residual G-040 creation-side hole: the
# predicate existed since T-1180 but was never called here — any --owner string
# was written verbatim while Watchtower's dropdowns whitelist the enum).
if ! is_valid_owner "$OWNER"; then
    error "Invalid owner '$OWNER'"
    die "Valid owners: $VALID_OWNERS (enum source: status-transitions.yaml)"
fi

# T-100202 AC4 (recursion guard): refuse names carrying the self-feeding
# audit-emitter signature — a WARN task named after another WARN task, e.g.
# "Audit WARN — Task T-2488-audit-warn--task-t-2462-…". The emitter itself is
# removed from HEAD (audit emits observations via `fw note`, hash-deduped),
# but this gate makes the recursion class structurally impossible for ANY
# future emitter path, not just the removed one.
if printf '%s' "$NAME" | grep -qiE 'audit[ -]?warn.*audit[ -]?warn'; then
    error "Recursive audit-warn task name refused (T-100202)"
    error "  A task about an audit-warn task re-audits its own emission and inflates"
    error "  the ID space unboundedly (origin: T-99971 seed, 2026-07-03)."
    die   "  Capture the finding as an observation instead: fw note \"<finding>\" (hash-deduped, no ID minted)"
fi

# Generate next task ID.
#
# T-100202: the allocator is "MAIN-CLUSTER max + 1", not "global max + 1".
# A block of IDs separated from the rest by a gap larger than
# FW_ID_QUARANTINE_GAP (default 1000) is treated as a quarantined outlier band
# and excluded from the ceiling. Rationale: a removed self-feeding audit-finding
# emitter inflated one ID to T-99971 in a single leap (2026-07-03), and the old
# "global max + 1" then chained every new task into the T-100xxx band while real
# work sat at ~T-2524. Quarantining lets new tasks resume at sane numbers
# (T-2525…) WITHOUT renumbering the existing band (zero blast radius — those
# files keep their IDs and all cross-references). Collision-safe: normal work
# only ever increments by 1, so a >1000 gap always signals inflation, never
# legitimate spacing; and the ~97k gap means the main sequence can never climb
# into the band in any realistic lifetime. Backward-compatible: with no outlier
# band, the main-cluster max == the global max (original behaviour).
#
# Hardening: the id is parsed from the LEADING `^T-<n>` only — never from an
# embedded T-NNNN inside a recursive inflation-era slug.
#
# T-100202 AC3 (cross-view guard): a linked git worktree checks out its own
# snapshot of .tasks/ — possibly behind the main checkout — so scanning ONE
# view computes a stale max and mints a duplicate ID (the T-100200 dup class).
# generate_id therefore union-scans the .tasks/ of EVERY worktree of the repo
# that owns TASKS_DIR.
#
# T-3104: `_task_view_dirs` was lifted out of this file — it now lives as
# `fw_task_view_dirs` in lib/paths.sh (sourced at the top of this script), so
# the ID allocator and the audit duplicate-ID check share ONE definition of the
# corpus view set. Read the contract and the L-506-leg-2 rationale there.

generate_id() {
    local gap_threshold="${FW_ID_QUARANTINE_GAP:-1000}"
    local ids=() f id d
    shopt -s nullglob
    while IFS= read -r d; do
        for f in "$d"/active/T-*.md "$d"/completed/T-*.md; do
            [ -f "$f" ] || continue
            id=$(basename "$f" | grep -oE '^T-[0-9]+' | grep -oE '[0-9]+')
            # Use 10# to force base-10 interpretation (avoids octal issues with 008, 009)
            [ -n "$id" ] && ids+=("$((10#$id))")
        done
    done < <(fw_task_view_dirs)
    shopt -u nullglob

    if [ "${#ids[@]}" -eq 0 ]; then
        printf "T-%03d" 1
        return
    fi

    # Ascending unique; walk up from the bottom and stop at the first gap larger
    # than the threshold — everything above that cliff is a quarantined band.
    local n prev="" main_max=0
    while IFS= read -r n; do
        if [ -z "$prev" ]; then
            main_max=$n
        elif [ $((n - prev)) -gt "$gap_threshold" ]; then
            break
        else
            main_max=$n
        fi
        prev=$n
    done < <(printf '%s\n' "${ids[@]}" | sort -n -u)

    printf "T-%03d" $((main_max + 1))
}

# Generate slug from name
generate_slug() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd 'a-z0-9-' | cut -c1-40
}

# Generate timestamp
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# T-1279/T-1424: Acquire lock BEFORE reading max_id; release AFTER file write.
# Without this, concurrent calls all observe the same max_id and collide.
# T-1424: unconditional — the source above already guaranteed the primitive is loaded.
#
# T-100202 AC3: anchor the allocation lock at the repo's MAIN worktree so that
# concurrent minting from different worktrees serializes on ONE lock. The
# per-view default (KEYLOCK_DIR under each checkout's .context/locks) silos the
# lock per worktree and lets two views race to the same ID even with the
# cross-view scan above. `git worktree list` emits the main worktree first.
_main_wt="$(git -C "$(dirname "$TASKS_DIR")" worktree list --porcelain 2>/dev/null | sed -n 's/^worktree //p' | head -1)"
if [ -n "$_main_wt" ] && [ -d "$_main_wt/.context/locks" ]; then
    KEYLOCK_DIR="$_main_wt/.context/locks"
fi
keylock_acquire "task-id-allocation"
trap 'keylock_release "task-id-allocation" 2>/dev/null' EXIT

# T-2207 (T-2204 Slice B'): filing-time recommendation gate — CLI mirror of
# T-1716. Fires before ID allocation so a blocked filing leaves no orphan
# T-NNNN reserved. Producer/consumer parity with T-2205 (Write/Edit hook)
# and T-2206 (emit_review/batch) via shared env-var bypass name.
#
# Triggers: workflow_type=inception AND $CLAUDECODE=1 AND no --i-am-human
# AND no FW_ALLOW_EMPTY_RECOMMENDATION=1 AND no FW_INCEPTION_PRE_GATED=1
# (the trusted-caller signal from do_inception_start) AND missing rec/rationale.
#
# Bypass mechanisms (all logged Tier-2 except the trusted-caller env signal):
#   --i-am-human                          → scripts/tests/Watchtower
#   FW_ALLOW_EMPTY_RECOMMENDATION=1       → agent override (parity w/ T-2205/T-2206)
#   FW_INCEPTION_PRE_GATED=1              → do_inception_start trusted caller (silent)
_log_recommendation_bypass() {
    local _flag="${1:-unknown}"
    local _reason="${2:-filing-time recommendation gate (T-2207)}"
    local _log_dir="${PROJECT_ROOT:-.}/.context/working"
    mkdir -p "$_log_dir" 2>/dev/null || return 0
    local _log_file="$_log_dir/.gate-bypass-log.yaml"
    local _ts
    _ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    {
        echo "- timestamp: '$_ts'"
        echo "  task: '<filing: ${NAME}>'"
        echo "  flag: '$_flag'"
        echo "  caller: 'create-task.sh'"
        echo "  reason: '$_reason'"
    } >> "$_log_file" 2>/dev/null || true
}

if [ "$WORKFLOW_TYPE" = "inception" ] \
   && [ "${CLAUDECODE:-}" = "1" ] \
   && [ "$I_AM_HUMAN" != "true" ] \
   && [ "${FW_INCEPTION_PRE_GATED:-}" != "1" ]; then
    if [ -z "$RECOMMENDATION" ] || [ -z "$RATIONALE" ]; then
        if [ "${FW_ALLOW_EMPTY_RECOMMENDATION:-}" = "1" ]; then
            _log_recommendation_bypass "FW_ALLOW_EMPTY_RECOMMENDATION" \
                "empty-recommendation bypass (create-task.sh inception filing)"
            echo "" >&2
            echo -e "  ${YELLOW}NOTE: filing inception '$NAME' without --recommendation —${NC}" >&2
            echo -e "  ${YELLOW}allowed via FW_ALLOW_EMPTY_RECOMMENDATION=1 (logged).${NC}" >&2
            echo "" >&2
        else
            echo "" >&2
            echo -e "  ${RED}══════════════════════════════════════════${NC}" >&2
            echo -e "  ${RED}BLOCKED: filing inception under \$CLAUDECODE=1 requires${NC}" >&2
            echo -e "  ${RED}         --recommendation GO|NO-GO|DEFER + --rationale${NC}" >&2
            echo -e "  ${RED}══════════════════════════════════════════${NC}" >&2
            echo "" >&2
            echo -e "  Origin: T-679 (governance rule — agent advisory at filing time)," >&2
            echo -e "  T-1715/T-1716 (filing-time gate on fw inception start)," >&2
            echo -e "  T-2204/T-2205/T-2206/T-2207 (producer/consumer parity)." >&2
            echo "" >&2
            echo -e "  To proceed, choose ONE:" >&2
            echo "" >&2
            echo -e "    1. Refile with the recommendation flags:" >&2
            echo -e "         fw task create --type inception --name '$NAME' \\" >&2
            echo -e "           --recommendation GO|NO-GO|DEFER \\" >&2
            echo -e "           --rationale '<one-paragraph reason citing evidence>'" >&2
            echo -e "       (or use the canonical: fw inception start '$NAME' --recommendation ... --rationale ...)" >&2
            echo "" >&2
            echo -e "    2. Override for scripts/tests/Watchtower:" >&2
            echo -e "         --i-am-human   (logged Tier 2)" >&2
            echo "" >&2
            echo -e "    3. Agent override (logged Tier 2):" >&2
            echo -e "         FW_ALLOW_EMPTY_RECOMMENDATION=1 fw task create --type inception ..." >&2
            echo "" >&2
            exit 1
        fi
    fi
fi

# Log --i-am-human bypass (parity with do_inception_start lines 124-136)
if [ "$WORKFLOW_TYPE" = "inception" ] && [ "$I_AM_HUMAN" = "true" ]; then
    _log_recommendation_bypass "--i-am-human" \
        "filing-time recommendation gate (T-2207, CLI parity)"
fi

# Generate ID and filename
TASK_ID=$(generate_id)
SLUG=$(generate_slug "$NAME")
FILENAME="$TASK_ID-$SLUG.md"
FILEPATH="$TASKS_DIR/active/$FILENAME"

# Determine initial status
if [ "$START_WORK" = true ]; then
    STATUS="started-work"
else
    STATUS="captured"
fi

# Validate status before write (T-2675, companion to T-2674's owner leg —
# 832 rail-316: "two independent holes with separate root causes"). Today
# STATUS is only ever the two internal constants above, so this guard is a
# never-fires invariant; it exists so any FUTURE path that derives STATUS
# from less-trusted input (promote/ghost origins, a --status flag) dies
# here instead of writing an unvalidated value.
if ! is_valid_status "$STATUS"; then
    error "Invalid initial status '$STATUS'"
    die "Valid statuses: $VALID_STATUSES (enum source: status-transitions.yaml)"
fi

# Format tags and related_tasks as YAML arrays
format_yaml_array() {
    local input="$1"
    if [ -z "$input" ]; then
        echo "[]"
        return
    fi
    local result="["
    local first=true
    IFS=',' read -ra items <<< "$input"
    for item in "${items[@]}"; do
        item=$(echo "$item" | xargs)  # trim whitespace
        [ -z "$item" ] && continue
        if [ "$first" = true ]; then
            result="${result}${item}"
            first=false
        else
            result="${result}, ${item}"
        fi
    done
    echo "${result}]"
}

TAGS_YAML=$(format_yaml_array "$TAGS")
RELATED_YAML=$(format_yaml_array "$RELATED")

# Select template content based on workflow type
# All vars passed via env to avoid shell interpolation into Python source (T-595)
if [ "$WORKFLOW_TYPE" = "inception" ] && [ -f "$TASKS_DIR/templates/inception.md" ]; then
    TC_TEMPLATE="$TASKS_DIR/templates/inception.md" \
    TC_TASK_ID="$TASK_ID" TC_STATUS="$STATUS" TC_HORIZON="$HORIZON" \
    TC_OWNER="$OWNER" TC_TAGS_YAML="$TAGS_YAML" TC_RELATED_YAML="$RELATED_YAML" \
    TC_TIMESTAMP="$TIMESTAMP" TC_FILEPATH="$FILEPATH" \
    python3 -c "
import sys, os
e = os.environ
with open(e['TC_TEMPLATE']) as f:
    t = f.read()
name, desc = sys.argv[1], sys.argv[2]
def indent_block(s):
    # T-2778: 'description: >' is a folded scalar, so EVERY line of the value must be
    # indented, not just the first. Indenting only the first line ends the scalar at the
    # first newline; YAML then reads the next paragraph as frontmatter. That fails two
    # different ways, and the loud one is the lucky one: a paragraph containing 'word: word'
    # parses as a junk top-level key and SILENTLY truncates description to its first line
    # (no error, audit sees valid YAML), while a paragraph without a colon raises
    # ScannerError and is caught. Found 5 corpus instances -- 1 loud, 4 silent.
    # Blank lines are emitted bare: whitespace-only lines inside a block scalar are
    # separators, and padding them to the indent width leaves trailing spaces.
    return '\n'.join(('  ' + ln) if ln.strip() else '' for ln in s.split('\n'))
t = t.replace('id: T-XXX', 'id: ' + e['TC_TASK_ID'])
t = t.replace('name:', 'name: \"' + name.replace('\"', '\\\\\"') + '\"', 1)
t = t.replace('description: >', 'description: >\n' + indent_block(desc), 1)
t = t.replace('status: captured', 'status: ' + e['TC_STATUS'])
t = t.replace('horizon: now', 'horizon: ' + e['TC_HORIZON'])
t = t.replace('owner:', 'owner: ' + e['TC_OWNER'], 1)
t = t.replace('tags: []', 'tags: ' + e['TC_TAGS_YAML'])
t = t.replace('related_tasks: []', 'related_tasks: ' + e['TC_RELATED_YAML'])
t = t.replace('created:', 'created: ' + e['TC_TIMESTAMP'], 1)
t = t.replace('last_update:', 'last_update: ' + e['TC_TIMESTAMP'], 1)
t = t.replace('# T-XXX: [Inception Name]', '# ' + e['TC_TASK_ID'] + ': ' + name)
t = t.replace('[Chronological log', '### ' + e['TC_TIMESTAMP'] + ' — task-created [task-create-agent]\n- **Action:** Created inception task\n- **Output:** ' + e['TC_FILEPATH'] + '\n- **Context:** Initial task creation\n\n[Chronological log')
with open(e['TC_FILEPATH'], 'w') as f:
    f.write(t)
" "$NAME" "$DESCRIPTION"
elif [ -f "$TASKS_DIR/templates/default.md" ]; then
    TC_TEMPLATE="$TASKS_DIR/templates/default.md" \
    TC_TASK_ID="$TASK_ID" TC_STATUS="$STATUS" TC_WORKFLOW_TYPE="$WORKFLOW_TYPE" \
    TC_HORIZON="$HORIZON" TC_OWNER="$OWNER" TC_TAGS_YAML="$TAGS_YAML" \
    TC_RELATED_YAML="$RELATED_YAML" TC_TIMESTAMP="$TIMESTAMP" TC_FILEPATH="$FILEPATH" \
    python3 -c "
import sys, os
e = os.environ
with open(e['TC_TEMPLATE']) as f:
    t = f.read()
name, desc = sys.argv[1], sys.argv[2]
def indent_block(s):
    # T-2778: 'description: >' is a folded scalar, so EVERY line of the value must be
    # indented, not just the first. Indenting only the first line ends the scalar at the
    # first newline; YAML then reads the next paragraph as frontmatter. That fails two
    # different ways, and the loud one is the lucky one: a paragraph containing 'word: word'
    # parses as a junk top-level key and SILENTLY truncates description to its first line
    # (no error, audit sees valid YAML), while a paragraph without a colon raises
    # ScannerError and is caught. Found 5 corpus instances -- 1 loud, 4 silent.
    # Blank lines are emitted bare: whitespace-only lines inside a block scalar are
    # separators, and padding them to the indent width leaves trailing spaces.
    return '\n'.join(('  ' + ln) if ln.strip() else '' for ln in s.split('\n'))
t = t.replace('id: T-XXX', 'id: ' + e['TC_TASK_ID'])
t = t.replace('name:', 'name: \"' + name.replace('\"', '\\\\\"') + '\"', 1)
t = t.replace('description: >', 'description: >\n' + indent_block(desc), 1)
t = t.replace('status: captured', 'status: ' + e['TC_STATUS'])
t = t.replace('workflow_type:', 'workflow_type: ' + e['TC_WORKFLOW_TYPE'], 1)
t = t.replace('owner:', 'owner: ' + e['TC_OWNER'], 1)
t = t.replace('horizon: now', 'horizon: ' + e['TC_HORIZON'])
t = t.replace('tags: []', 'tags: ' + e['TC_TAGS_YAML'])
t = t.replace('related_tasks: []', 'related_tasks: ' + e['TC_RELATED_YAML'])
t = t.replace('created:', 'created: ' + e['TC_TIMESTAMP'], 1)
t = t.replace('last_update:', 'last_update: ' + e['TC_TIMESTAMP'], 1)
t = t.replace('# T-XXX: [Task Name]', '# ' + e['TC_TASK_ID'] + ': ' + name)
t = t.replace('<!-- Auto-populated by git mining at task completion.\\n     Manual entries optional during execution. -->', '### ' + e['TC_TIMESTAMP'] + ' — task-created [task-create-agent]\n- **Action:** Created task via task-create agent\n- **Output:** ' + e['TC_FILEPATH'] + '\n- **Context:** Initial task creation')
with open(e['TC_FILEPATH'], 'w') as f:
    f.write(t)
" "$NAME" "$DESCRIPTION"
else
    # Fallback: minimal inline template (only if default.md missing)
    # T-2778: indent every line of the description, not just the first — see indent_block()
    # above for why the single-indent form corrupts multi-paragraph descriptions.
    DESCRIPTION_INDENTED=$(printf '%s\n' "$DESCRIPTION" | awk '{ if (length($0)) print "  " $0; else print "" }')
    cat > "$FILEPATH" << EOF
---
id: $TASK_ID
name: "$NAME"
description: >
$DESCRIPTION_INDENTED
status: $STATUS
workflow_type: $WORKFLOW_TYPE
horizon: $HORIZON
owner: $OWNER
tags: $TAGS_YAML
related_tasks: $RELATED_YAML
created: $TIMESTAMP
last_update: $TIMESTAMP
date_finished: null
---

# $TASK_ID: $NAME

## Context

## Acceptance Criteria

- [ ] [Criterion]

## Verification

## Updates

### $TIMESTAMP — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** $FILEPATH
- **Context:** Initial task creation
EOF
fi

# Validate the created file
if ! grep -q "^id: $TASK_ID" "$FILEPATH"; then
    echo -e "${RED}ERROR: Task file validation failed${NC}"
    exit 1
fi

# T-1263: Inception tasks must have ## Recommendation and ## Decision sections
# Fail-fast at creation time rather than blocking late at fw inception decide
if [ "$WORKFLOW_TYPE" = "inception" ]; then
    _missing=""
    grep -qE '^## Recommendation[[:space:]]*$' "$FILEPATH" || _missing="## Recommendation"
    grep -qE '^## Decision[[:space:]]*$' "$FILEPATH" || _missing="${_missing:+$_missing, }## Decision"
    if [ -n "$_missing" ]; then
        echo -e "${RED}ERROR: Inception template missing required sections: $_missing${NC}" >&2
        echo "The inception decide pipeline requires both ## Recommendation and ## Decision." >&2
        echo "Fix the template at: $TASKS_DIR/templates/inception.md" >&2
        rm -f "$FILEPATH"
        exit 1
    fi
fi

# T-2207 (T-2204 Slice B'): when --recommendation + --rationale were provided
# at filing time, populate the ## Recommendation block of the just-created
# task file. Mirrors lib/inception.sh:_inject_recommendation_block — same shape
# so the populated block is byte-identical regardless of producer path.
if [ "$WORKFLOW_TYPE" = "inception" ] && [ -n "$RECOMMENDATION" ] && [ -n "$RATIONALE" ]; then
    python3 - "$FILEPATH" "$RECOMMENDATION" "$RATIONALE" <<'PYEOF'
import re, sys
path, rec, rationale = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path, 'r') as f:
    text = f.read()
# Strategy: locate the ## Recommendation heading, replace everything between
# it and the next ## heading with our populated block. Idempotent: re-running
# with the same values produces the same body.
new_block = f"## Recommendation\n\n**Recommendation:** {rec}\n\n**Rationale:** {rationale}\n\n"
pattern = re.compile(r'^## Recommendation[ \t]*\n.*?(?=^## )', re.MULTILINE | re.DOTALL)
if pattern.search(text):
    text = pattern.sub(new_block, text, count=1)
else:
    # No Recommendation block — append before ## Decision (T-1263 guarantees it exists)
    text = re.sub(r'(^## Decision)', new_block + r'\1', text, count=1, flags=re.MULTILINE)
with open(path, 'w') as f:
    f.write(text)
PYEOF
fi

# Success output
echo ""
echo -e "${GREEN}=== Task Created ===${NC}"
echo "ID:       $TASK_ID"
echo "Name:     $NAME"
echo "Type:     $WORKFLOW_TYPE"
echo "Status:   $STATUS"
echo "Owner:    $OWNER"
echo "File:     $FILEPATH"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Add context (design docs, specs, predecessor tasks) to the task file"
echo "2. Reference this task in commits: git commit -m \"$TASK_ID: description\""
echo "3. Update task status as work progresses"

# If --start was used, also set focus (T-297)
if [ "$START_WORK" = true ]; then
    "$SCRIPT_DIR/../context/context.sh" focus "$TASK_ID" 2>/dev/null || true
fi
