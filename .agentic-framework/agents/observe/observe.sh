#!/bin/bash
# Observe Agent - Lightweight observation capture
# The fastest path from "I noticed something" to "it's recorded"
#
# Usage:
#   ./agents/observe/observe.sh "observation text"           # Capture
#   ./agents/observe/observe.sh "text" --tag bug --task T-XX # Capture with context
#   ./agents/observe/observe.sh list                         # Show pending
#   ./agents/observe/observe.sh count                        # Pending count
#   ./agents/observe/observe.sh promote OBS-001              # Promote to task
#   ./agents/observe/observe.sh dismiss OBS-001 --reason "..." # Dismiss
#   ./agents/observe/observe.sh triage                       # Interactive review

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$FRAMEWORK_ROOT/lib/paths.sh"
INBOX_FILE="$PROJECT_ROOT/.context/inbox.yaml"

# Colors provided by lib/colors.sh (via paths.sh chain)

ensure_inbox() {
    mkdir -p "$(dirname "$INBOX_FILE")"
    if [ ! -f "$INBOX_FILE" ]; then
        cat > "$INBOX_FILE" << 'EOF'
# Observation Inbox - Unprocessed observations
# Capture: fw note "text"
# Review:  fw note list
# Triage:  fw note triage
observations: []
EOF
    fi
}

# T-2966: two independent defects lived in one grep, and neither fix subsumes
# the other.
#
#   1. FIELD-BLINDNESS. The scan was `grep -oE 'OBS-[0-9]+' "$INBOX_FILE"` — over
#      the whole file, not over `id:` fields. So an observation whose BODY cited
#      a peer's id permanently dragged the counter up to it. 832 measured their
#      own inbox jumping OBS-049 → OBS-239 by quoting one of ours, in a note
#      written to record this very defect.
#
#   2. MAX-OVER-SURVIVORS. Triage REMOVES the entry it converts into a task, so
#      triaging the highest-numbered observation lowered the maximum and the next
#      note reused its id. Confirmed live: T-2950 is titled "OBS-238: audit
#      CTL-013 holds a third copy…" and a later note was also issued OBS-238 —
#      two unrelated observations, one id, the older unreachable by it.
#
# Field-scoping stops the counter being pushed UP by prose. The high-water mark
# stops it being pulled DOWN by triage. Both are needed.
#
# Ids must be unique, not contiguous — so the mark is persisted at generation
# time rather than after a successful write. A crash between the two skips an
# id, which is harmless; the failure this exists to prevent is reuse.
OBS_HIGHWATER_FILE="$PROJECT_ROOT/.context/working/.obs-highwater"

# `id:` fields only. Never body text — that is defect 1.
_obs_max_in_inbox() {
    [ -f "$INBOX_FILE" ] || return 0
    grep -oE '^[[:space:]]*-?[[:space:]]*id:[[:space:]]*OBS-[0-9]+' "$INBOX_FILE" 2>/dev/null \
        | grep -oE '[0-9]+$' | sort -n | tail -1 || true
}

# Triage renames the observation into a task titled "OBS-NNN: …", which is the
# only surviving record that the id was ever issued once the inbox entry is gone.
# Anchored to the `name:` field so a task BODY citing a peer id cannot move it.
_obs_max_in_tasks() {
    grep -rhoE '^name:[[:space:]]*"?OBS-[0-9]+' \
        "$PROJECT_ROOT/.tasks/active" "$PROJECT_ROOT/.tasks/completed" 2>/dev/null \
        | grep -oE '[0-9]+$' | sort -n | tail -1 || true
}

next_id() {
    local max=0 candidate
    for candidate in \
        "$(cat "$OBS_HIGHWATER_FILE" 2>/dev/null || true)" \
        "$(_obs_max_in_inbox)" \
        "$(_obs_max_in_tasks)"
    do
        [ -n "$candidate" ] || continue
        [ "$((10#$candidate))" -gt "$max" ] && max=$((10#$candidate))
    done
    local next=$((max + 1))
    mkdir -p "$(dirname "$OBS_HIGHWATER_FILE")"
    printf '%s\n' "$next" > "$OBS_HIGHWATER_FILE"
    printf "OBS-%03d" "$next"
}

# Auto-detect current focus task
get_focus_task() {
    local focus_file="$PROJECT_ROOT/.context/working/focus.yaml"
    if [ -f "$focus_file" ]; then
        grep "^current_task:" "$focus_file" 2>/dev/null | sed 's/current_task:[[:space:]]*//' | tr -d '"' || true
    fi
}

# --- Commands ---

do_capture() {
    ensure_inbox
    local text="$1"
    shift || true

    local task="" tags="" urgent=false
    # T-2867: collect unused positional args instead of discarding them.
    # The old loop ended `*) shift` — every positional after the text vanished
    # silently. Combined with the dispatch catch-all (`*) do_capture "$@"` below),
    # `fw note add "a real observation"` captured the word `add` and threw the
    # observation away, exit 0, printing the wrong text back as confirmation.
    # Measured cost: 26 of 191 observations were bare sub-verbs (add x16,
    # resolve x6, show x3, status x1) — 26 notes someone meant to record and lost.
    local -a strays=()
    while [ $# -gt 0 ]; do
        case "$1" in
            --task|-t)   task="$2"; shift 2 ;;
            --tag)       tags="$2"; shift 2 ;;
            --urgent|-u) urgent=true; shift ;;
            *) strays+=("$1"); shift ;;
        esac
    done

    # Refuse rather than discard. The guard is on the general defect — ANY unused
    # positional — not on a blocklist of sub-verb names, because the next lost
    # note will use a word nobody thought to list.
    if [ ${#strays[@]} -gt 0 ]; then
        echo -e "${RED}ERROR: fw note received ${#strays[@]} argument(s) it cannot use.${NC}" >&2
        echo "" >&2
        echo "  Captured as the note text : \"$text\"" >&2
        echo "  Would have been DISCARDED : $(printf '"%s" ' "${strays[@]}")" >&2
        echo "" >&2
        echo "fw note takes the whole observation as ONE quoted argument. There is no" >&2
        echo "'add' sub-verb — the text goes directly after 'note':" >&2
        echo "" >&2
        echo "  fw note \"$(printf '%s ' "${strays[@]}" | sed 's/[[:space:]]*$//')\"" >&2
        echo "" >&2
        echo "Options go after the text: --task T-XXX, --tag <tag>, --urgent." >&2
        echo "Sub-verbs that DO exist: list, count, triage, promote, dismiss." >&2
        exit 1
    fi

    # Auto-detect task context if not provided
    if [ -z "$task" ]; then
        task=$(get_focus_task)
    fi

    local id
    id=$(next_id)
    local ts
    ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Replace empty array marker
    _sed_i 's/^observations: \[\]/observations:/' "$INBOX_FILE"

    local urgent_field=""
    if [ "$urgent" = true ]; then
        urgent_field="  urgent: true"
    fi

    # T-2456 (OBS-084): escape $text for a YAML double-quoted scalar before
    # writing. A raw backslash in the note body (e.g. a regex like '\d+') or an
    # embedded double-quote would otherwise corrupt inbox.yaml: YAML double-quotes
    # process backslash escapes, so an unescaped '\d' is an "unknown escape"
    # ScannerError that crashes EVERY `fw note list/triage` (yaml.safe_load) — the
    # whole inbox goes unreadable. Order matters: backslashes first, then quotes.
    # Origin: OBS-081's '- **IW-(\d+):' (filed via `fw note`) broke the inbox for
    # ~a day. Both readers stay happy — yaml.safe_load unescapes correctly, and the
    # sed reader (do_resolve) still strips the surrounding quotes.
    local text_yaml
    text_yaml=${text//\\/\\\\}        # \  -> \\
    text_yaml=${text_yaml//\"/\\\"}   # "  -> \"

    cat >> "$INBOX_FILE" << EOF
- id: $id
  text: "$text_yaml"
  captured: $ts
  context_task: ${task:-null}
  tags: [${tags}]
  status: pending
  promoted_to: null
EOF

    if [ -n "$urgent_field" ]; then
        echo "$urgent_field" >> "$INBOX_FILE"
    fi

    if [ "$urgent" = true ]; then
        echo -e "${GREEN}$id${NC} ${RED}[URGENT]${NC} captured: \"$text\""
    else
        echo -e "${GREEN}$id${NC} captured: \"$text\""
    fi
    # T-2868: `[ -n "$task" ] && echo …` as the FINAL statement made the empty-task
    # case return 1 — so a note written perfectly reported failure. A fresh project
    # has no focus.yaml, so the first `fw note` in every new project hit it, and any
    # caller that retried on non-zero duplicated the observation. Use an if-block so
    # the exit status is the function's, not the test's.
    if [ -n "$task" ]; then
        echo -e "  context: $task"
    fi
}

do_list() {
    ensure_inbox
    # T-2932: same parsed source as do_count, so the header can never disagree
    # with the rows printed below it. T-2317 fixed the LISTING to parse YAML and
    # left this header on the grep — the sibling-site shape again (L-533).
    local counts pending
    if ! counts=$(_inbox_counts) || [ -z "$counts" ]; then
        echo -e "${RED}Inbox unreadable${NC} — cannot list observations (check $INBOX_FILE)" >&2
        return 1
    fi
    pending=${counts% *}

    if [ "$pending" -eq 0 ]; then
        echo -e "${GREEN}Inbox empty${NC} — no pending observations"
        return
    fi

    echo -e "${BOLD}Observation Inbox${NC} ($pending pending)"
    echo ""

    # Parse and display pending observations (T-2317: yaml.safe_load — was re.split which
    # drifted from the heredoc format and matched tag boundaries as OBS boundaries).
    python3 << PYEOF
import yaml

with open("$INBOX_FILE", "r") as f:
    data = yaml.safe_load(f) or {}

for obs in data.get('observations', []) or []:
    if obs.get('status') != 'pending':
        continue
    obs_id = obs.get('id', '')
    text = obs.get('text', '')
    task = obs.get('context_task')
    tags = obs.get('tags') or []
    urgent = obs.get('urgent') is True

    prefix = "  \033[0;31m[URGENT]\033[0m " if urgent else "  "
    tag_str = f" [{', '.join(tags)}]" if tags else ""
    task_str = f" ({task})" if task and task != "null" else ""
    print(f"{prefix}\033[0;36m{obs_id}\033[0m{tag_str}  {text}{task_str}")
PYEOF
}

# T-2932: counts come from the parsed inbox, not from grepping lines.
#
# The urgent figure was `grep -c 'urgent: true'` over the WHOLE file, with no
# status filter — so every observation ever marked urgent was counted forever.
# Measured when this was found: reported 8, true 4; the four phantoms had been
# dismissed. That figure is the headline in the handover and in the session-start
# ritual, so it was inflating the one number an agent is told to act on.
#
# Over-reporting urgency is not the safe direction. An operator who opens the
# queue and finds half the "urgent" items already dismissed learns the number is
# decorative — an urgency signal dies by inflation, not by silence.
#
# The pending figure moved too, though `grep -c 'status: pending'` happened to be
# correct at the time. It is only correct while no observation's TEXT contains the
# string; observations quote YAML routinely, and this one now does.
#
# Echoes "pending urgent" on success. On a parse failure it prints nothing and
# returns 1 — callers must SAY so rather than print a zero, because "0 pending"
# from a broken inbox is indistinguishable from a healthy empty one (L-578: give
# every check an explicit, loud, distinct refusal path).
_inbox_counts() {
    python3 -c '
import sys, yaml
try:
    with open(sys.argv[1]) as f:
        data = yaml.safe_load(f) or {}
    obs = [o for o in (data.get("observations") or []) if isinstance(o, dict)]
except Exception:
    sys.exit(1)
pending = [o for o in obs if o.get("status") == "pending"]
urgent = [o for o in pending if o.get("urgent") is True]
print(len(pending), len(urgent))
' "$INBOX_FILE" 2>/dev/null
}

do_count() {
    ensure_inbox
    local counts pending urgent
    if ! counts=$(_inbox_counts) || [ -z "$counts" ]; then
        echo "inbox unreadable — count unavailable (check $INBOX_FILE)" >&2
        return 1
    fi
    pending=${counts% *}
    urgent=${counts#* }

    if [ "$urgent" -gt 0 ]; then
        echo "$pending pending ($urgent urgent)"
    else
        echo "$pending pending"
    fi
}

do_promote() {
    local obs_id=""
    local task_type="build"
    while [ $# -gt 0 ]; do
        case "$1" in
            --type|-t) task_type="$2"; shift 2 ;;
            -h|--help)
                echo "Usage: fw note promote OBS-NNN [--type <build|inception|...>]"
                return 0 ;;
            -*)
                echo -e "${RED}Unknown flag: $1${NC}" >&2
                echo "Usage: fw note promote OBS-NNN [--type <build|inception|...>]" >&2
                return 1 ;;
            *)
                if [ -z "$obs_id" ]; then obs_id="$1"; else
                    echo -e "${RED}Unexpected argument: $1${NC}" >&2; return 1
                fi
                shift ;;
        esac
    done
    if [ -z "$obs_id" ]; then
        echo -e "${RED}Usage: fw note promote OBS-NNN [--type <build|inception|...>]${NC}" >&2
        return 1
    fi

    ensure_inbox

    local text
    # Pipeline tolerant of empty matches (set -euo pipefail otherwise kills
    # the script silently when the observation doesn't exist — T-1458).
    text=$(grep -A1 "id: $obs_id" "$INBOX_FILE" 2>/dev/null | grep 'text:' | sed 's/.*text: "//;s/"$//' || true)

    if [ -z "$text" ]; then
        echo -e "${RED}Observation $obs_id not found${NC}" >&2
        return 1
    fi

    echo -e "${YELLOW}Promoting $obs_id to task (type: $task_type)...${NC}"
    echo ""

    # Create task
    PROJECT_ROOT="$PROJECT_ROOT" "$FRAMEWORK_ROOT/agents/task-create/create-task.sh" \
        --name "$text" \
        --description "Promoted from observation $obs_id" \
        --type "$task_type" \
        --owner human

    # Mark as promoted
    _sed_i "/id: $obs_id/,/promoted_to:/{s/status: pending/status: promoted/;s/promoted_to: null/promoted_to: task/}" "$INBOX_FILE"

    echo ""
    echo -e "${GREEN}$obs_id promoted to task${NC}"
}

do_dismiss() {
    local obs_id="${1:-}"
    if [ -z "$obs_id" ]; then
        echo -e "${RED}Usage: fw note dismiss OBS-NNN [--reason \"...\"]${NC}" >&2
        return 1
    fi
    shift

    local reason="not actionable"
    while [ $# -gt 0 ]; do
        case "$1" in
            --reason) reason="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    ensure_inbox

    # T-2928: persist the reason. The previous form parsed --reason into a
    # local, used it in exactly one place — the echo below — and wrote only
    # `status: dismissed`. The reason went to a terminal nobody archives while
    # the confirmation line quoted it back on the way out, which manufactures
    # confidence at precisely the moment someone is being careful.
    #
    # The cost is not lost prose. A dismissed observation with no reason cannot
    # answer the only question anyone asks of one — was this judged and closed,
    # or was it swept? Those are the same row. An inbox that cannot tell them
    # apart eventually gets batch-cleared by someone who reasonably concludes
    # the entries were never triaged, which is the failure the triage ritual
    # exists to prevent. Measured here at the time of the fix: 81 dismissed
    # observations, 0 carrying a reason. Reported by 832 (rail 547 §F), who
    # found it by verifying their own dispositions rather than trusting the
    # success message.
    #
    # Written in python rather than sed: the reason is operator free text and
    # can contain `:`, quotes and newlines, all of which a sed substitution
    # mangles or truncates. json.dumps emits a double-quoted scalar that is
    # valid YAML for every one of those. Only the target entry's lines are
    # touched, so the rest of the file stays byte-identical.
    if ! OBS_ID="$obs_id" OBS_REASON="$reason" INBOX="$INBOX_FILE" python3 -c '
import json, os, sys, datetime

obs_id, reason, path = os.environ["OBS_ID"], os.environ["OBS_REASON"], os.environ["INBOX"]
lines = open(path).read().split("\n")

start = next((i for i, l in enumerate(lines) if l.startswith("- id: %s" % obs_id)), None)
if start is None:
    print("observation %s not found in %s" % (obs_id, path), file=sys.stderr)
    sys.exit(1)

end = next((i for i in range(start + 1, len(lines)) if lines[i].startswith("- ")), len(lines))

status_idx = next((i for i in range(start, end) if lines[i].strip() == "status: pending"), None)
if status_idx is None:
    cur = next((lines[i].strip() for i in range(start, end) if lines[i].strip().startswith("status:")), "unknown")
    print("%s is not pending (%s) — not dismissing" % (obs_id, cur), file=sys.stderr)
    sys.exit(2)

lines[status_idx] = "  status: dismissed"
ts = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
lines[status_idx + 1:status_idx + 1] = [
    "  dismissed_reason: " + json.dumps(reason),
    "  dismissed_at: " + ts,
]
open(path, "w").write("\n".join(lines))
'; then
        echo -e "${RED}$obs_id NOT dismissed — the inbox was not modified${NC}" >&2
        return 1
    fi

    echo -e "${GREEN}$obs_id dismissed:${NC} $reason"
}

do_triage() {
    ensure_inbox
    # T-2932: fourth site of the same grep, and the one with the worst failure —
    # "Nothing to triage — inbox is clean" is an assertion about the queue, and a
    # miscount here tells the operator the ritual is done. Found by the
    # enumerating guard in t2932, not by reading: three sites were converted by
    # hand and this one was missed, in the same file as two of them.
    local counts pending
    if ! counts=$(_inbox_counts) || [ -z "$counts" ]; then
        echo -e "${RED}Inbox unreadable${NC} — cannot triage (check $INBOX_FILE)" >&2
        return 1
    fi
    pending=${counts% *}

    if [ "$pending" -eq 0 ]; then
        echo -e "${GREEN}Nothing to triage${NC} — inbox is clean"
        return
    fi

    echo -e "${BOLD}Observation Triage${NC} — $pending pending"
    echo ""
    echo "For each observation, choose:"
    echo "  [p]romote to task  [d]ismiss  [s]kip"
    echo ""

    # List all pending for non-interactive review
    do_list
    echo ""
    echo -e "${YELLOW}Run individually:${NC}"
    echo "  fw note promote OBS-NNN"
    echo "  fw note dismiss OBS-NNN --reason \"...\""
}

show_help() {
    echo -e "${BOLD}fw note${NC} — Lightweight observation capture"
    echo ""
    echo "Usage:"
    echo "  fw note \"observation text\"              Capture an observation"
    echo "  fw note \"text\" --tag bug --task T-XXX   Capture with context"
    echo "  fw note \"text\" --urgent                 Flag as urgent"
    echo "  fw note list                             Show pending observations"
    echo "  fw note count                            Pending count (for prompts)"
    echo "  fw note triage                           Review pending observations"
    echo "  fw note promote OBS-NNN [--type T]       Promote to task (default type: build)"
    echo "  fw note dismiss OBS-NNN --reason \"...\"   Dismiss with reason"
    echo ""
    echo "The inbox lives at: .context/inbox.yaml"
}

# --- Main ---

case "${1:-}" in
    list)       do_list ;;
    count)      do_count ;;
    triage)     do_triage ;;
    promote)    shift; do_promote "$@" ;;
    dismiss)    shift; do_dismiss "$@" ;;
    -h|--help|help)  show_help ;;
    "")         show_help; exit 1 ;;
    -*)
        echo -e "${RED}Unknown flag: $1${NC}" >&2
        echo "Run 'fw note --help' for usage" >&2
        exit 1
        ;;
    *)          do_capture "$@" ;;
esac
