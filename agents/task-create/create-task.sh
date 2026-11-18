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
# T-5221: the rules a new task must pass, shared with fw task create-batch.
source "$FRAMEWORK_ROOT/lib/task-create-rules.sh"

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
ORIGIN=""
# T-5227: inception lifecycle fields — who holds the next step, and when it comes back.
WAITING_ON=""
REVISIT_AT=""

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
        --waiting-on) WAITING_ON="$2"; shift 2 ;;
        --revisit-at) REVISIT_AT="$2"; shift 2 ;;
        --i-am-human) I_AM_HUMAN=true; shift ;;
        # T-3897: where this task came from (operator | agent | peer | pickup |
        # proposal)[:source[:ref]] — shown as a badge on the approvals queue.
        --origin) ORIGIN="$2"; shift 2 ;;
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
            echo "  --recommendation   EXPLORING|GO|NO-GO|DEFER — inception; agent filings default to EXPLORING (T-5226)"
            echo "  --rationale        Evidence-cited reason — required for inception under \$CLAUDECODE=1"
            echo "  --waiting-on       agent|peer|operator — inception only; who holds the next step (default agent, T-5227)"
            echo "  --revisit-at       YYYY-MM-DD — inception only; when it comes back (default filing date + 7)"
            echo "  --i-am-human       Bypass agent gate (scripts/tests/Watchtower) — logged Tier-2"
            echo "  --origin           Where the task came from: operator|agent|peer|pickup|proposal[:source[:ref]]"
            echo "                     (T-3897; e.g. peer:ring20-dashboard:7881482d — shown on /approvals)"
            echo "  -h, --help         Show this help"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# T-2207: validate --recommendation value if provided (parity with do_inception_start)
if [ -n "$RECOMMENDATION" ]; then
    case "$RECOMMENDATION" in
        EXPLORING|GO|NO-GO|DEFER) ;;
        *)
            echo -e "${RED}Invalid --recommendation: '$RECOMMENDATION' (must be EXPLORING, GO, NO-GO, or DEFER)${NC}" >&2
            exit 1
            ;;
    esac
fi

# T-5227: waiting_on / revisit_at belong to inceptions only, and take fixed shapes.
# One rule, lib/inception_lifecycle.py validate_fields (also the Write/Edit hook's).
if [ -n "$WAITING_ON" ] || [ -n "$REVISIT_AT" ]; then
    if ! python3 "$FRAMEWORK_ROOT/lib/inception_lifecycle.py" --validate \
            "${WORKFLOW_TYPE:--}" "${WAITING_ON:--}" "${REVISIT_AT:--}"; then
        echo -e "${RED}Refused: --waiting-on/--revisit-at (T-5227, see above)${NC}" >&2
        exit 1
    fi
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

# T-555: Reject template placeholder names (rule lives in lib/task-create-rules.sh, T-5221)
task_rule_name "$NAME" || exit 1

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

# T-3897: refuse an unknown origin kind before anything is written.
if [ -n "$ORIGIN" ]; then
    case "${ORIGIN%%:*}" in
        operator|agent|peer|pickup|proposal) ;;
        *) echo -e "${RED}ERROR: --origin kind '${ORIGIN%%:*}' unknown (operator|agent|peer|pickup|proposal)${NC}" >&2
           exit 2 ;;
    esac
fi

# Validate workflow type, horizon (T-2160), owner (T-2674) and recursive audit-warn names
# (T-100202). T-5221: the rules live in lib/task-create-rules.sh, shared with create-batch.
task_rule_fields "$NAME" "$WORKFLOW_TYPE" "$HORIZON" "$OWNER" || exit 1

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

#
# T-5217 (slice 1 of T-5212): the rules above now live in lib/idalloc.sh, the one
# task-id allocator. fw_id_allocate keeps one authoritative counter at
# <main worktree>/.tasks/.id-highwater (the T-4189 mark, made authoritative), an
# append-only reservation ledger beside it, and runs the union scan described
# above as a once-per-reservation check (FW_ID_CHECK, default on). One allocator
# per repository is a hard rule: a second "max + 1" next to a block allocator
# reissues ids from an aborted reservation (1409, T-5212). fw doctor warns.
source "$FRAMEWORK_ROOT/lib/idalloc.sh"

generate_id() {
    fw_id_allocate 1 "create-task"
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
# T-4841: the lock itself is taken further down, just before generate_id.

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
    # T-3412: ${NAME} is free text (task title) and can contain a single quote,
    # which is the YAML escape character for this single-quoted scalar. Double
    # it per the YAML single-quoted-scalar rule (same idiom as T-1861 in
    # check-active-task.sh) instead of interpolating it raw.
    local _t3412_esc_name="${NAME//\'/\'\'}"
    local _t3412_esc_reason="${_reason//\'/\'\'}"
    {
        echo "- timestamp: '$_ts'"
        echo "  task: '<filing: ${_t3412_esc_name}>'"
        echo "  flag: '$_flag'"
        echo "  caller: 'create-task.sh'"
        echo "  reason: '$_t3412_esc_reason'"
    } >> "$_log_file" 2>/dev/null || true
}

if [ "$WORKFLOW_TYPE" = "inception" ] \
   && [ "${CLAUDECODE:-}" = "1" ] \
   && [ "$I_AM_HUMAN" != "true" ] \
   && [ "${FW_INCEPTION_PRE_GATED:-}" != "1" ]; then
    # T-5226: the recommendation defaults to EXPLORING (not ready for decision);
    # the rationale is still required.
    if [ -z "$RECOMMENDATION" ] && [ -n "$RATIONALE" ]; then
        RECOMMENDATION="EXPLORING"
    fi
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
            echo -e "  ${RED}         --rationale (recommendation defaults to EXPLORING)${NC}" >&2
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
            echo -e "           --rationale '<one-paragraph reason citing evidence>'" >&2
            echo -e "       (or use the canonical: fw inception start '$NAME' --rationale ...)" >&2
            echo -e "       The recommendation starts as EXPLORING (not ready for decision);" >&2
            echo -e "       write GO, NO-GO or DEFER once every IW question is disposed (T-5226)." >&2
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
#
# T-4841: hold task-id-allocation only around id allocation plus the task-file
# write, and never let a child inherit the lock fd. flock locks belong to the
# open file description, so a child holding an inherited copy (git, python3, a
# hook) keeps the lock after this script is killed (1409: a create killed by
# timeout left children blocking every later create). Children run in
# subshells that close the fd first (keylock_subshell_close_cmd, T-1493); the
# EXIT trap covers an early exit, the explicit release below the normal path.
keylock_acquire "task-id-allocation"
trap 'keylock_release "task-id-allocation" 2>/dev/null' EXIT
TASK_ID=$(eval "$(keylock_subshell_close_cmd)"; generate_id)

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

# Render and write the task file (T-5221): lib/render_task.py is the one task-file writer,
# shared with fw task create-batch. It picks the template (project templates/, then the
# framework's copy, T-4597; an inline fallback when neither exists), renders it exactly as
# the three inline writers here did (T-2778, T-4787, T-4863), and links the file into place
# exclusively. Values pass as argv, never interpolated into source (T-595).
# T-4841: subshell with the lock fd closed, so the writer never inherits it.
FILEPATH=$(
    eval "$(keylock_subshell_close_cmd)"
    python3 "$FRAMEWORK_ROOT/lib/render_task.py" write-one \
        --tasks-dir "$TASKS_DIR" --framework-root "$FRAMEWORK_ROOT" \
        --id="$TASK_ID" --name="$NAME" --description="$DESCRIPTION" \
        --type="$WORKFLOW_TYPE" --owner="$OWNER" --horizon="$HORIZON" --status="$STATUS" \
        --tags="$TAGS" --related="$RELATED" --timestamp="$TIMESTAMP" \
        --waiting-on="$WAITING_ON" --revisit-at="$REVISIT_AT"
) || { echo -e "${RED}ERROR: Task file could not be written for $TASK_ID${NC}" >&2; exit 1; }
# T-4841: id persisted (.id-highwater) and the file written — release now, so
# nothing after this point (origin, recommendation, --start focus) holds it.
# T-5217: the ledger's created row first, still under the lock.
[ -f "$FILEPATH" ] && fw_id_ledger_created "$TASK_ID"
keylock_release "task-id-allocation"

# Validate the created file
if ! grep -q "^id: $TASK_ID" "$FILEPATH"; then
    echo -e "${RED}ERROR: Task file validation failed${NC}"
    exit 1
fi

# T-3897: record the origin in frontmatter, after whichever write path ran
# (two templates + the inline fallback above), so there is one place to keep.
if [ -n "$ORIGIN" ]; then
    if ! TC_ORIGIN="$ORIGIN" TC_FILEPATH="$FILEPATH" python3 - << 'ORIGINEOF'
import json, os, re
path, raw = os.environ["TC_FILEPATH"], os.environ["TC_ORIGIN"]
kind, _, rest = raw.partition(":")
source, _, ref = rest.partition(":")
fields = {"kind": kind}
if source:
    fields["source"] = source
if ref:
    fields["ref"] = ref
line = "origin: {" + ", ".join(f"{k}: {json.dumps(v)}" for k, v in fields.items()) + "}"
text = open(path, encoding="utf-8").read()
text, n = re.subn(r"(?m)^(related_tasks:.*)$", lambda m: m.group(1) + "\n" + line, text, count=1)
if not n:  # no related_tasks: line — close of the frontmatter instead, never dropped
    text, n = re.subn(r"\A(---\n.*?\n)(---\n)", lambda m: m.group(1) + line + "\n" + m.group(2),
                      text, count=1, flags=re.S)
if not n:
    raise SystemExit(f"--origin not recorded: no frontmatter found in {path}")
open(path, "w", encoding="utf-8").write(text)
ORIGINEOF
    then
        echo -e "${RED}ERROR: --origin could not be recorded in $FILEPATH${NC}" >&2
        exit 1
    fi
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
        echo "Fix the template at: ${INCEPTION_TEMPLATE:-$TASKS_DIR/templates/inception.md}" >&2
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
