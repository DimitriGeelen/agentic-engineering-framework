#!/bin/bash
# Handover Agent - Mechanical Operations
# Creates handover documents for session continuity

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$FRAMEWORK_ROOT/lib/paths.sh"
HANDOVER_DIR="$CONTEXT_DIR/handovers"

# T-1461: Resolve Watchtower URL once for inline link rendering.
# Falls back to the literal port file or 3000 if `fw watchtower url` fails — the
# handover should never crash if Watchtower isn't running. Renders as plain text
# (just the task ID) when WT_URL is empty.
WT_URL=$("$FRAMEWORK_ROOT/bin/fw" watchtower url 2>/dev/null | head -1 || true)
if [ -z "$WT_URL" ]; then
    WT_URL=""  # explicit empty → renderer skips link wrapping
fi

# Colors provided by lib/colors.sh (via paths.sh chain)

_resolve_commit_task() {
    # If task already set by --task flag, keep it
    if [ -n "$COMMIT_TASK" ]; then return; fi
    # T-1477: Check T-012 in active/ ONLY. The original code matched completed/
    # too, so every handover commit carried "T-012" even after that task was
    # closed long ago — producing a recurring "Task T-012 is closed" warning
    # from pre-commit. The auto-create branch below handles "no active handover
    # task" correctly.
    if [ -n "$(ls "$TASKS_DIR/active/T-012-"*.md 2>/dev/null)" ]; then
        COMMIT_TASK="T-012"
        return
    fi
    # Look for any task with "handover" in its slug
    local handover_task
    handover_task=$(find "$TASKS_DIR/active" "$TASKS_DIR/completed" -maxdepth 1 -name '*handover*.md' -type f 2>/dev/null | head -1)
    if [ -n "$handover_task" ]; then
        COMMIT_TASK=$(basename "$handover_task" | grep -oE "T-[0-9]+" | head -1)
        if [ -n "$COMMIT_TASK" ]; then return; fi
    fi
    # Auto-create a handover maintenance task for this project
    if [ -x "$FRAMEWORK_ROOT/agents/task-create/create-task.sh" ]; then
        local create_output
        create_output=$(PROJECT_ROOT="$PROJECT_ROOT" "$FRAMEWORK_ROOT/agents/task-create/create-task.sh" \
            --name "Session handover maintenance" --type build --owner agent \
            --description "Ongoing task for session handover commits" 2>&1)
        COMMIT_TASK=$(echo "$create_output" | grep "^ID:" | awk '{print $2}')
        if [ -n "$COMMIT_TASK" ]; then
            echo -e "${CYAN}Auto-created handover task: $COMMIT_TASK${NC}"
            return
        fi
    fi
    # Absolute fallback — use T-000 placeholder (will pass hook regex)
    # Note: focused task fallback was removed (T-556) — handover commits
    # are session-level and must never borrow a work task's ID.
    COMMIT_TASK="T-000"
}

# Parse arguments
SESSION_ID=""
AUTO_COMMIT=true
COMMIT_TASK=""
CHECKPOINT_MODE=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --session) SESSION_ID="$2"; shift 2 ;;
        --commit) AUTO_COMMIT=true; shift ;;
        --no-commit) AUTO_COMMIT=false; shift ;;
        --task|-t) COMMIT_TASK="$2"; shift 2 ;;
        --owner) AGENT_OWNER="$2"; shift 2 ;;
        --emergency) AUTO_COMMIT=true; shift ;;  # Deprecated (D-028): treated as normal handover
        --checkpoint) CHECKPOINT_MODE=true; AUTO_COMMIT=true; shift ;;
        -h|--help)
            echo "Usage: handover.sh [options]"
            echo ""
            echo "Options:"
            echo "  --session ID   Use specific session ID (default: auto-generated)"
            echo "  --commit       Auto-commit handover via git agent (default)"
            echo "  --no-commit    Skip auto-commit"
            echo "  --task, -t ID  Task ID for commit (default: T-012)"
            echo "  --owner NAME   Agent/provider name (default: \$AGENT_OWNER or claude-code)"
            echo "  --checkpoint   Mid-session checkpoint (does not replace LATEST.md)"
            echo "  -h, --help     Show this help"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# Generate session ID if not provided
if [ -z "$SESSION_ID" ]; then
    SESSION_ID="S-$(date +%Y-%m%d-%H%M)"
fi

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Ensure directories exist
mkdir -p "$HANDOVER_DIR"

# ─── Checkpoint Mode: lightweight mid-session snapshot ───
if [ "$CHECKPOINT_MODE" = true ]; then
    HANDOVER_FILE="$HANDOVER_DIR/CHECKPOINT-$SESSION_ID.md"
    echo -e "${CYAN}=== Checkpoint Handover ===${NC}"
    echo "Session: $SESSION_ID"

    ACTIVE_TASKS=""
    ACTIVE_DETAILS=""
    shopt -s nullglob
    for f in "$TASKS_DIR/active"/*.md; do
        [ -f "$f" ] || continue
        task_id=$({ grep "^id:" "$f" 2>/dev/null || true; } | head -1 | cut -d: -f2 | tr -d ' ')
        task_name=$({ grep "^name:" "$f" 2>/dev/null || true; } | head -1 | cut -d: -f2- | sed 's/^ *//')
        task_status=$({ grep "^status:" "$f" 2>/dev/null || true; } | head -1 | cut -d: -f2 | tr -d ' ')
        task_wftype=$({ grep "^workflow_type:" "$f" 2>/dev/null || true; } | head -1 | cut -d: -f2 | tr -d ' ')
        [ -n "$task_id" ] && ACTIVE_TASKS="$ACTIVE_TASKS$task_id, "
        # T-1461: render task as a Watchtower link when WT_URL is available.
        # Inception → /inception/T-XXX, otherwise → /review/T-XXX. Plain bold ID when WT_URL empty.
        if [ -n "$WT_URL" ]; then
            if [ "$task_wftype" = "inception" ]; then
                _link="[$task_id]($WT_URL/inception/$task_id)"
            else
                _link="[$task_id]($WT_URL/review/$task_id)"
            fi
        else
            _link="**$task_id**"
        fi
        ACTIVE_DETAILS="$ACTIVE_DETAILS- $_link: $task_name ($task_status)\n"
    done
    shopt -u nullglob
    ACTIVE_TASKS="${ACTIVE_TASKS%, }"

    UNCOMMITTED=$(git -C "$PROJECT_ROOT" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    RECENT_COMMITS=$(git -C "$PROJECT_ROOT" log -5 --pretty=format:"- %h %s" 2>/dev/null)

    cat > "$HANDOVER_FILE" << CHECKPOINT_EOF
---
session_id: $SESSION_ID
timestamp: $TIMESTAMP
type: checkpoint
tasks_active: [$ACTIVE_TASKS]
uncommitted_changes: $UNCOMMITTED
owner: ${AGENT_OWNER:-claude-code}
---

# Checkpoint: $SESSION_ID

## Active Tasks

$(echo -e "$ACTIVE_DETAILS")

## Recent Commits

$RECENT_COMMITS
CHECKPOINT_EOF

    echo -e "${GREEN}Checkpoint created: $HANDOVER_FILE${NC}"
    # Note: checkpoints do NOT replace LATEST.md

    # Reset tool counter
    if [ -f "$FRAMEWORK_ROOT/agents/context/checkpoint.sh" ]; then
        "$FRAMEWORK_ROOT/agents/context/checkpoint.sh" reset 2>/dev/null || true
    fi

    # Auto-commit
    if [ "$AUTO_COMMIT" = true ]; then
        _resolve_commit_task
        GIT_AGENT=""
        if [ -f "$FRAMEWORK_ROOT/agents/git/git.sh" ]; then
            GIT_AGENT="$FRAMEWORK_ROOT/agents/git/git.sh"
        fi
        if [ -n "$GIT_AGENT" ]; then
            git -C "$PROJECT_ROOT" add "$HANDOVER_FILE"
            PROJECT_ROOT="$PROJECT_ROOT" "$GIT_AGENT" commit -m "$COMMIT_TASK: Checkpoint handover $SESSION_ID"
        fi
    fi
    exit 0
fi

# ─── Normal Mode ───
HANDOVER_FILE="$HANDOVER_DIR/$SESSION_ID.md"

# T-1522: Self-lock against concurrent normal-mode invocations. SESSION_ID is
# minute-precision so two callers in the same minute write to the same file;
# the cat > ... cat >> ... interleave produces duplicate sections (T-1520).
# Upstream pre-compact.sh now dedups, but checkpoint.sh and audit.sh have no
# shared dedup with pre-compact, so they could still race.
HANDOVER_LOCK="$HANDOVER_DIR/.handover.lock"
mkdir -p "$HANDOVER_DIR" 2>/dev/null
if command -v flock >/dev/null 2>&1; then
    exec 202>"$HANDOVER_LOCK"
    if ! flock -n 202; then
        echo -e "${YELLOW}Another handover is running — skipping this invocation${NC}" >&2
        exit 0
    fi
fi

echo -e "${CYAN}=== Handover Agent ===${NC}"
echo "Session: $SESSION_ID"
echo "Timestamp: $TIMESTAMP"
echo ""

# Step 1: Gather automatic data
echo -e "${YELLOW}Gathering state...${NC}"

# Get predecessor (previous handover)
PREDECESSOR=""
if [ -f "$HANDOVER_DIR/LATEST.md" ]; then
    PREDECESSOR=$(grep "^session_id:" "$HANDOVER_DIR/LATEST.md" 2>/dev/null | cut -d: -f2 | tr -d ' ')
fi

# Get active tasks
ACTIVE_TASKS=""
shopt -s nullglob
for f in "$TASKS_DIR/active"/*.md; do
    [ -f "$f" ] || continue
    task_id=$({ grep "^id:" "$f" 2>/dev/null || true; } | head -1 | cut -d: -f2 | tr -d ' ')
    if [ -n "$task_id" ]; then
        ACTIVE_TASKS="$ACTIVE_TASKS$task_id, "
    fi
done
shopt -u nullglob
ACTIVE_TASKS="${ACTIVE_TASKS%, }"  # Remove trailing comma

# Get git info
UNCOMMITTED=$(git -C "$PROJECT_ROOT" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
RECENT_COMMITS=$(git -C "$PROJECT_ROOT" log -5 --pretty=format:"- %h %s" 2>/dev/null)

# Get tasks touched recently (modified in last day)
TASKS_TOUCHED=""
while IFS= read -r f; do
    task_id=$({ grep "^id:" "$f" 2>/dev/null || true; } | head -1 | cut -d: -f2 | tr -d ' ')
    if [ -n "$task_id" ]; then
        TASKS_TOUCHED="$TASKS_TOUCHED$task_id, "
    fi
done < <(find "$TASKS_DIR" -name "*.md" -mmin -1440 -type f 2>/dev/null)
TASKS_TOUCHED="${TASKS_TOUCHED%, }"

# Step 1.5: EPISODIC COMPLETENESS GATE
# Check that recently completed tasks have enriched episodic summaries
echo ""
echo -e "${YELLOW}Checking episodic completeness...${NC}"

EPISODIC_DIR="$CONTEXT_DIR/episodic"
EPISODIC_WARNINGS=()

# Find completed tasks modified in last 24 hours (likely completed this session)
shopt -s nullglob
for f in "$TASKS_DIR/completed"/*.md; do
    # Only check files modified in last day
    if [ -z "$(find "$f" -mmin -1440 2>/dev/null)" ]; then
        continue
    fi

    task_id=$({ grep "^id:" "$f" 2>/dev/null || true; } | head -1 | cut -d: -f2 | tr -d ' ')
    [ -z "$task_id" ] && continue

    episodic_file="$EPISODIC_DIR/${task_id}.yaml"

    # Check 1: Does episodic file exist?
    if [ ! -f "$episodic_file" ]; then
        EPISODIC_WARNINGS+=("$task_id: Missing episodic summary")
        continue
    fi

    # Check 2: Is it enriched (not pending)?
    enrichment_status=$(grep "^enrichment_status:" "$episodic_file" 2>/dev/null | cut -d: -f2 | tr -d ' ')

    if [ "$enrichment_status" = "pending" ]; then
        EPISODIC_WARNINGS+=("$task_id: Episodic not enriched (status: pending)")
    elif [ -z "$enrichment_status" ]; then
        # Old format without enrichment_status - check if summary is empty
        summary_line=$(grep -A 1 "^summary:" "$episodic_file" | tail -1)
        if echo "$summary_line" | grep -qE '^\s*>\s*$|\[TODO'; then
            EPISODIC_WARNINGS+=("$task_id: Episodic has empty/TODO summary")
        fi
    fi
done
shopt -u nullglob

# Report episodic warnings
if [ ${#EPISODIC_WARNINGS[@]} -gt 0 ]; then
    echo -e "${YELLOW}⚠ EPISODIC CONTEXT GAPS DETECTED${NC}"
    echo ""
    for warning in "${EPISODIC_WARNINGS[@]}"; do
        echo "  - $warning"
    done
    echo ""
    echo "These gaps will cause context loss. Consider:"
    echo "  - Run: ./agents/context/context.sh generate-episodic T-XXX"
    echo "  - Then enrich the [TODO] sections before this handover"
    echo ""
else
    echo -e "${GREEN}✓ All recent completed tasks have enriched episodics${NC}"
fi

# Step 1.6: Observation inbox status
INBOX_FILE="$CONTEXT_DIR/inbox.yaml"
PENDING_OBS=0
URGENT_OBS=0
if [ -f "$INBOX_FILE" ]; then
    PENDING_OBS=$(grep -c 'status: pending' "$INBOX_FILE" 2>/dev/null) || PENDING_OBS=0
    URGENT_OBS=$(VALIDATE_FILE="$INBOX_FILE" python3 -c "
import re, os
with open(os.environ['VALIDATE_FILE']) as f:
    content = f.read()
blocks = re.split(r'\n  - ', content)
urgent = sum(1 for b in blocks[1:] if 'status: pending' in b and 'urgent: true' in b)
print(urgent)
" 2>/dev/null || echo 0)
fi

if [ "$PENDING_OBS" -gt 0 ]; then
    if [ "$URGENT_OBS" -gt 0 ]; then
        echo -e "${YELLOW}⚠ Observation inbox: $PENDING_OBS pending ($URGENT_OBS urgent)${NC}"
    else
        echo -e "${CYAN}Observation inbox: $PENDING_OBS pending${NC}"
    fi
    echo "  Run: $(_emit_user_command "note triage")"
else
    echo -e "${GREEN}✓ Observation inbox clean${NC}"
fi

# Step 1.7: Gaps register status
# T-397: Unified concerns register (was gaps.yaml)
GAPS_FILE="$CONTEXT_DIR/project/concerns.yaml"
# Fallback to gaps.yaml for backward compat
[ -f "$GAPS_FILE" ] || GAPS_FILE="$CONTEXT_DIR/project/gaps.yaml"
WATCHING_GAPS=0
if [ -f "$GAPS_FILE" ]; then
    WATCHING_GAPS=$(grep -c 'status: watching' "$GAPS_FILE" 2>/dev/null) || WATCHING_GAPS=0
    if [ "$WATCHING_GAPS" -gt 0 ]; then
        echo -e "${CYAN}Concerns register: $WATCHING_GAPS watching${NC}"
    fi
fi

# Step 1.8: Token usage (T-805, T-829)
TOKEN_USAGE=""
TOKEN_TOTAL=""
TOKEN_TURNS=""
TOKEN_CACHE_HIT=""
TOKEN_INPUT=""
TOKEN_CACHE_READ=""
TOKEN_CACHE_CREATE=""
TOKEN_OUTPUT=""
if [ -f "$FRAMEWORK_ROOT/lib/costs.sh" ]; then
    TOKEN_DATA=$(FRAMEWORK_ROOT="$FRAMEWORK_ROOT" PROJECT_ROOT="$PROJECT_ROOT" \
        bash -c 'source "$FRAMEWORK_ROOT/lib/colors.sh" 2>/dev/null; source "$FRAMEWORK_ROOT/lib/costs.sh"; costs_main current 2>/dev/null' || true)
    if [ -n "$TOKEN_DATA" ]; then
        TOKEN_TOTAL=$(echo "$TOKEN_DATA" | grep "^Total:" | awk '{print $2}')
        TOKEN_TURNS=$(echo "$TOKEN_DATA" | grep "^Turns:" | awk '{print $2}' | tr -d ',')
        TOKEN_CACHE_HIT=$(echo "$TOKEN_DATA" | grep "^  Cache Rd:" | awk '{print $3}')
        TOKEN_INPUT=$(echo "$TOKEN_DATA" | grep "^  Input:" | awk '{print $2}')
        TOKEN_CACHE_READ=$(echo "$TOKEN_DATA" | grep "^  Cache Rd:" | awk '{print $3}')
        TOKEN_CACHE_CREATE=$(echo "$TOKEN_DATA" | grep "^  Cache Cr:" | awk '{print $3}')
        TOKEN_OUTPUT=$(echo "$TOKEN_DATA" | grep "^  Output:" | awk '{print $2}')
        TOKEN_USAGE="${TOKEN_TOTAL:-0} tokens, ${TOKEN_TURNS:-0} turns"
    fi
fi

# Step 1.9: Session quality metrics (T-831)
METRICS_CPT=""
METRICS_FCT=""
METRICS_FTC=""
METRICS_FTC_RATE=""
METRICS_EDIT_BURSTS=""
METRICS_PTR=""
# Per-session deltas (T-850)
S_METRICS_CPT=""
S_METRICS_TURNS=""
S_METRICS_COMMITS=""
S_METRICS_FTC=""
S_METRICS_FTC_RATE=""
S_METRICS_EDIT_BURSTS=""
S_METRICS_PTR=""
if [ -f "$FRAMEWORK_ROOT/agents/context/session-metrics.sh" ]; then
    bash "$FRAMEWORK_ROOT/agents/context/session-metrics.sh" 2>/dev/null || true
    METRICS_FILE="$CONTEXT_DIR/working/.session-metrics.yaml"
    if [ -f "$METRICS_FILE" ]; then
        METRICS_CPT=$(grep '^commits_per_turn:' "$METRICS_FILE" | awk '{print $2}')
        METRICS_FCT=$(grep '^first_commit_turn:' "$METRICS_FILE" | awk '{print $2}')
        METRICS_FTC=$(grep '^failed_tool_calls:' "$METRICS_FILE" | awk '{print $2}')
        METRICS_FTC_RATE=$(grep '^failed_tool_call_rate:' "$METRICS_FILE" | awk '{print $2}')
        METRICS_EDIT_BURSTS=$(grep '^edit_bursts:' "$METRICS_FILE" | awk '{print $2}')
        METRICS_PTR=$(grep '^productive_turns_ratio:' "$METRICS_FILE" | awk '{print $2}')
        # Per-session deltas (T-850)
        S_METRICS_TURNS=$(grep '^session_turns:' "$METRICS_FILE" | awk '{print $2}')
        S_METRICS_COMMITS=$(grep '^session_commits:' "$METRICS_FILE" | awk '{print $2}')
        S_METRICS_CPT=$(grep '^session_commits_per_turn:' "$METRICS_FILE" | awk '{print $2}')
        S_METRICS_FTC=$(grep '^session_failed_tool_calls:' "$METRICS_FILE" | awk '{print $2}')
        S_METRICS_FTC_RATE=$(grep '^session_failed_tool_call_rate:' "$METRICS_FILE" | awk '{print $2}')
        S_METRICS_EDIT_BURSTS=$(grep '^session_edit_bursts:' "$METRICS_FILE" | awk '{print $2}')
        S_METRICS_PTR=$(grep '^session_productive_turns_ratio:' "$METRICS_FILE" | awk '{print $2}')
    fi
fi

# Step 2: Create handover template
echo -e "${YELLOW}Creating handover document...${NC}"

# T-1216 / T-1212 follow-up: detect silent-session recovery invocations
# from session-silent-scanner.sh and prepend a banner so the next agent
# immediately knows this handover lacks live agent context.
if [ "${RECOVERED:-0}" = "1" ]; then
    RECOVERED_BANNER="> **[recovered, no agent context]** — this handover was auto-generated
> by the silent-session scanner, not by the originating agent. The original
> Claude Code session skipped SessionEnd (bug #17885 /exit, #20197 API 500,
> SIGKILL, or laptop sleep). Treat below as last-observed state only.
>
> - Recovered session ID: \`${RECOVERED_SESSION_ID:-unknown}\`
> - Idle age at recovery: \`${RECOVERED_AGE_MIN:-unknown} min\`
> - Transcript: \`${RECOVERED_TRANSCRIPT:-unknown}\`

"
else
    RECOVERED_BANNER=""
fi

cat > "$HANDOVER_FILE" << EOF
---
session_id: $SESSION_ID
timestamp: $TIMESTAMP
predecessor: $PREDECESSOR
tasks_active: [$ACTIVE_TASKS]
tasks_touched: [$TASKS_TOUCHED]
tasks_completed: []
uncommitted_changes: $UNCOMMITTED
token_usage: "${TOKEN_USAGE}"
token_input: "${TOKEN_INPUT}"
token_cache_read: "${TOKEN_CACHE_READ}"
token_cache_create: "${TOKEN_CACHE_CREATE}"
token_output: "${TOKEN_OUTPUT}"
commits_per_turn: "${METRICS_CPT}"
first_commit_turn: "${METRICS_FCT}"
failed_tool_calls: "${METRICS_FTC}"
failed_tool_call_rate: "${METRICS_FTC_RATE}"
edit_bursts: "${METRICS_EDIT_BURSTS}"
productive_turns_ratio: "${METRICS_PTR}"
session_turns: "${S_METRICS_TURNS}"
session_commits: "${S_METRICS_COMMITS}"
session_commits_per_turn: "${S_METRICS_CPT}"
session_failed_tool_calls: "${S_METRICS_FTC}"
session_failed_tool_call_rate: "${S_METRICS_FTC_RATE}"
session_edit_bursts: "${S_METRICS_EDIT_BURSTS}"
session_productive_turns_ratio: "${S_METRICS_PTR}"
owner: ${AGENT_OWNER:-claude-code}
session_narrative: ""
---

# Session Handover: $SESSION_ID

${RECOVERED_BANNER}## Where We Are

$(python3 -c "
import subprocess, re, collections
# Build 'Where We Are' from recent commits
out = subprocess.check_output(
    ['git', '-C', '$PROJECT_ROOT', 'log', '--oneline', '-20', '--format=%s'],
    text=True, stderr=subprocess.DEVNULL).strip().splitlines()
# Extract unique task references and their descriptions
tasks_seen = collections.OrderedDict()
for line in out:
    m = re.match(r'(T-\d+):?\s*(.*)', line)
    if m and m.group(1) != 'T-012':
        tid = m.group(1)
        if tid not in tasks_seen:
            desc = m.group(2).strip().rstrip('.')
            if desc:
                tasks_seen[tid] = desc
items = list(tasks_seen.items())[:5]
if items:
    parts = [f'{t} ({d})' for t, d in items]
    count = len(items)
    more = len(tasks_seen) - count
    summary = 'Session worked on: ' + '; '.join(parts)
    if more > 0:
        summary += f'. Plus {more} more commit(s).'
    else:
        summary += '.'
    print(summary)
else:
    print('Session started. See Recent Commits below for activity.')
" 2>/dev/null || echo "See Recent Commits below for session activity.")

$(
# T-1661: Inject ## Current Arc section if arc-focus.yaml has a current_arc value.
# Empty / missing focus file → section omitted entirely (no empty header).
ARC_FOCUS_FILE="$PROJECT_ROOT/.context/working/arc-focus.yaml"
if [ -f "$ARC_FOCUS_FILE" ]; then
    cur_arc=$(grep -E '^current_arc:' "$ARC_FOCUS_FILE" 2>/dev/null | head -1 | awk -F': ' '{print $2}' | tr -d ' "')
    if [ -n "$cur_arc" ] && [ "$cur_arc" != "null" ]; then
        arc_yaml="$PROJECT_ROOT/.context/arcs/${cur_arc}.yaml"
        if [ -f "$arc_yaml" ]; then
            arc_name=$(awk -F': ' '/^name:/ {sub(/^name: /,""); print; exit}' "$arc_yaml")
            arc_status=$(awk -F': ' '/^status:/ {print $2; exit}' "$arc_yaml")
            # T-1880 (T-NEW-15): delegated to shared helper. Counts tasks via
            # union of `arc_id:` frontmatter + legacy `arc:<slug>` tag, using
            # the same library that backs /arcs, /tasks?arc, and audit's
            # stale-arc check. Replaces the tempfile workaround (L-396).
            # shellcheck disable=SC1091
            . "$FRAMEWORK_ROOT/lib/arc_membership.sh"
            task_count=$(PROJECT_ROOT="$PROJECT_ROOT" arc_tasks_for "$cur_arc" | grep -c . 2>/dev/null)
            [ -z "$task_count" ] && task_count=0
            echo "## Current Arc"
            echo ""
            echo "**${cur_arc}** — ${arc_name} (${arc_status}, ${task_count} task(s))"
            echo ""
            echo "Run \`fw arc show ${cur_arc}\` for detail; \`fw arc focus --clear\` to drop focus."
            echo ""
        fi
    fi
fi

# T-1452 / G-053: surface ripe revisit_at deferrals (populated by daily
# revisit-due-scan.sh cron). Silent when the file is absent or empty.
REVISITS_FILE="$PROJECT_ROOT/.context/working/.revisits-due.txt"
if [ -s "$REVISITS_FILE" ]; then
    echo "## Revisits Ripe Today"
    echo ""
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        echo "- $line"
    done < "$REVISITS_FILE"
    echo ""
fi
)
## Work in Progress

EOF

# Add active tasks sorted by horizon (now > next > later)
TASKS_DIR_PY="$TASKS_DIR" WT_URL_PY="$WT_URL" PROJECT_ROOT_PY="$PROJECT_ROOT" python3 << 'PYEOF' >> "$HANDOVER_FILE"
# T-1825: heredoc delimiter quoted ('PYEOF') so shellcheck doesn't lint Python
# `==` as bash (SC2284 false-positive). Shell vars now come in via env; no \$
# escapes needed inside the body.
import os, re, glob

tasks_dir = os.environ["TASKS_DIR_PY"] + "/active"
WT_URL = os.environ.get("WT_URL_PY", "")  # T-1461: empty → plain task ID, no link

def review_link(tid, name):
    """Render a [T-XXX](URL) link to /review/T-XXX, or plain bold ID if no WT_URL."""
    if WT_URL:
        return f'[{tid}]({WT_URL}/review/{tid}): {name}'
    return f'**{tid}**: {name}'

def inception_link(tid, name):
    if WT_URL:
        return f'[{tid}]({WT_URL}/inception/{tid}): {name}'
    return f'**{tid}**: {name}'

def extract_verdict(content):
    """T-1530: Extract GO/DEFER/NO-GO from ## Recommendation. H2+ terminator (L-293).
    T-1576: emit NO-REC when section is missing/empty (agent owes a recommendation)."""
    m = re.search(r'^## Recommendation\s*$(.*?)(?=^#{2,} |\Z)',
                  content, re.MULTILINE | re.DOTALL)
    if not m:
        return 'NO-REC'
    body = re.sub(r'<!--.*?-->', '', m.group(1), flags=re.DOTALL).strip()
    if not body:
        return 'NO-REC'
    v = re.search(r'\*\*Recommendation:\*\*\s*(NO-GO|GO|DEFER)\b',
                  body, re.IGNORECASE)
    return v.group(1).upper() if v else '?'

horizon_order = {'now': 0, 'next': 1, 'later': 2}
tasks = []

for f in sorted(glob.glob(os.path.join(tasks_dir, '*.md'))):
    with open(f) as fh:
        content = fh.read()
    tid = re.search(r'^id:\s*(.+)', content, re.M)
    tname = re.search(r'^name:\s*(.+)', content, re.M)
    tstatus = re.search(r'^status:\s*(.+)', content, re.M)
    thoriz = re.search(r'^horizon:\s*(.+)', content, re.M)
    twf = re.search(r'^workflow_type:\s*(.+)', content, re.M)
    if not tid:
        continue
    h = thoriz.group(1).strip() if thoriz else 'now'
    # T-1530: capture verdict while content is still loaded
    verdict = extract_verdict(content)
    # T-1619: capture workflow_type + Decision to filter DEFER'd inceptions from WIP.
    # Decision (recorded by fw inception decide) is the source of truth, not
    # Recommendation. T-1517's Deferred-Inceptions section uses the same regex.
    wf = twf.group(1).strip() if twf else ''
    dec_m = re.search(r'^\*\*Decision\*\*:\s*(GO|NO-GO|DEFER)\b', content, re.M)
    dec = dec_m.group(1) if dec_m else ''
    tasks.append((horizon_order.get(h, 0), tid.group(1).strip(),
                  tname.group(1).strip() if tname else '',
                  tstatus.group(1).strip() if tstatus else '',
                  h, verdict, wf, dec))

tasks.sort(key=lambda t: (t[0], t[1]))
current_horizon = None
# T-2160 (arc-009 horizon-axis-hardening, Slice 1, Q4 explicit-filter):
# Collect ALL work-completed tasks into a single bottom footer rather than
# flushing per-horizon. Previously each horizon group had its own
# "Awaiting Human Review" sub-section, interleaving 135+ partial-complete
# tasks with active WIP. Single bottom footer = primary signal first.
pending_completed = []
for _, tid, tname, tstatus, h, verdict, wf, dec in tasks:
    # T-1619: DEFER'd inceptions are parked (decision is final, not WIP).
    # Skip from WIP — they are surfaced in the "Deferred Inceptions"
    # section below (T-1517) which already covers visibility.
    if wf == 'inception' and dec == 'DEFER':
        continue
    # T-2160: work-completed in active/ = partial-complete (Human ACs pending).
    # Collect into the single bottom footer; do NOT contribute to horizon buckets.
    if tstatus == 'work-completed':
        pending_completed.append((tid, tname, verdict, h))
        continue
    if h != current_horizon:
        current_horizon = h
        print(f'<!-- horizon: {h} -->')
        print()
    # Auto-fill from git log for this task
    import subprocess
    last_action = 'See git log'
    try:
        gl = subprocess.check_output(
            ['git', '-C', os.environ["PROJECT_ROOT_PY"], 'log', '--oneline', '-1',
             '--grep=' + tid, '--format=%s'],
            text=True, stderr=subprocess.DEVNULL).strip()
        if gl:
            last_action = gl
    except Exception:
        pass
    print(f'### {tid}: {tname}')
    print(f'- **Status:** {tstatus} (horizon: {h})')
    print(f'- **Last action:** {last_action}')
    print(f'- **Next step:** See task file')
    print(f'- **Blockers:** None')
    print()
    print()

# T-2160: single bottom footer (replaces per-horizon flush above).
# All work-completed tasks in active/ are partial-complete = Agent done,
# Human ACs pending. Surfaced explicitly per Q4 (not silent filter).
if pending_completed:
    print('<!-- partial-complete-footer -->')
    print(f'### Partial-Complete — awaiting human ({len(pending_completed)} tasks)')
    print()
    print('Agent ACs done. Human ACs pending — see "Awaiting Your Action" below.')
    print()
    # Group by horizon so the human can see which were most-recently active.
    by_h = {'now': [], 'next': [], 'later': []}
    for pc_tid, pc_name, pc_verdict, pc_h in pending_completed:
        by_h.setdefault(pc_h, []).append((pc_tid, pc_name, pc_verdict))
    for hk in ('now', 'next', 'later'):
        if not by_h.get(hk):
            continue
        print(f'**horizon: {hk}** ({len(by_h[hk])})')
        print()
        for pc_tid, pc_name, pc_verdict in by_h[hk]:
            print(f'- [{pc_verdict}] {review_link(pc_tid, pc_name)}')
        print()

# T-1461: render inception tasks awaiting decision with /inception/T-XXX links
# T-1517: split into "Awaiting Decision" (no recorded Decision) and "Deferred"
#         (Decision == DEFER) — DEFER'd inceptions are parked, not pending,
#         so labelling them as "Awaiting Decision" mismatches /approvals which
#         correctly filters by `decision == 'pending'`.
inception_pending = []
inception_deferred = []
# T-1619: tuple grew to 8 elements (verdict, wf, dec). Reuse the captured
# values; no need to re-read each task file.
for _, tid, tname, tstatus, h, _verdict, wf, dec in tasks:
    if tstatus == 'work-completed':
        continue
    if wf != 'inception':
        continue
    if dec == '':
        inception_pending.append((tid, tname))
    elif dec == 'DEFER':
        inception_deferred.append((tid, tname))
    # GO/NO-GO: in-flight close — sweep handles the move; skip both lists.

if inception_pending:
    print('### Inception Phases — Awaiting Decision')
    print()
    for ip_tid, ip_name in inception_pending:
        print(f'- {inception_link(ip_tid, ip_name)}')
    print()

if inception_deferred:
    print('### Deferred Inceptions — Watching for Recurrence')
    print()
    print('These inceptions reached a DEFER decision and are parked. They are')
    print('NOT awaiting a first decision. They re-surface for promotion if the')
    print('promotion criteria in their Recommendation block are met.')
    print()
    for ip_tid, ip_name in inception_deferred:
        print(f'- {inception_link(ip_tid, ip_name)}')
    print()
PYEOF

# Add inception section if any inception tasks exist
inception_count=0
shopt -s nullglob
for f in "$TASKS_DIR/active"/*.md; do
    [ -f "$f" ] || continue
    if grep -q "workflow_type: inception" "$f" 2>/dev/null; then
        inception_count=$((inception_count + 1))
    fi
done
shopt -u nullglob
if [ "$inception_count" -gt 0 ]; then
    {
        echo "## Inception Phases"
        echo ""
        echo "**$inception_count inception task(s) pending decision** — run \`fw inception status\` for details."
        echo ""
    } >> "$HANDOVER_FILE"
fi

# Step 2.1: Surface partial-complete tasks (T-372 — blind completion anti-pattern)
# Tasks that are work-completed but have unchecked Human ACs
PARTIAL_COMPLETE_SECTION=$(WT_URL_FOR_PYTHON="$WT_URL" python3 << 'PCEOF'
import glob, re, os

tasks_dir = os.environ.get("TASKS_DIR", ".tasks")
WT_URL = os.environ.get("WT_URL_FOR_PYTHON", "")

def extract_verdict(content):
    """T-1530: Extract GO/DEFER/NO-GO from ## Recommendation. H2+ terminator (L-293).
    T-1576: emit NO-REC when section is missing/empty so the human knows the
    agent owes a recommendation (rather than seeing a bare '?' that conflates
    'no section' with 'verdict unparseable').
    """
    m = re.search(r'^## Recommendation\s*$(.*?)(?=^#{2,} |\Z)',
                  content, re.MULTILINE | re.DOTALL)
    if not m:
        return 'NO-REC'
    body = re.sub(r'<!--.*?-->', '', m.group(1), flags=re.DOTALL).strip()
    if not body:
        return 'NO-REC'
    v = re.search(r'\*\*Recommendation:\*\*\s*(NO-GO|GO|DEFER)\b',
                  body, re.IGNORECASE)
    return v.group(1).upper() if v else '?'

partial = []
for f in sorted(glob.glob(os.path.join(tasks_dir, "active", "*.md"))):
    with open(f) as fh:
        content = fh.read()
    if "status: work-completed" not in content:
        continue
    # Find ### Human section
    human_match = re.search(r'### Human\n(.*?)(?=\n### |\n## |\Z)', content, re.DOTALL)
    if not human_match:
        continue
    human_section = human_match.group(1)
    # T-1618: strip <!-- ... --> blocks before counting. The default task template
    # includes an Example AC inside a comment ("- [ ] [REVIEW] Dashboard renders
    # correctly") that must not register as a real unchecked AC. Mirrors the same
    # fix in bin/fw verify-acs (G-047).
    human_section = re.sub(r'<!--.*?-->', '', human_section, flags=re.DOTALL)
    unchecked = len(re.findall(r'^\s*-\s*\[ \]', human_section, re.M))
    if unchecked == 0:
        continue
    tid = re.search(r'^id:\s*(\S+)', content, re.M)
    tname = re.search(r'^name:\s*"?(.+?)"?\s*$', content, re.M)
    if tid:
        # Extract first unchecked AC text (truncated)
        first_ac = re.search(r'^\s*-\s*\[ \]\s*(.+)', human_section, re.M)
        ac_preview = first_ac.group(1)[:60] if first_ac else "?"
        verdict = extract_verdict(content)
        partial.append((tid.group(1), tname.group(1) if tname else "?", unchecked, ac_preview, verdict))

if partial:
    print("## Awaiting Your Action (Human)")
    print()
    print(f"**{len(partial)} task(s) with unchecked Human ACs.** These are waiting for you — not for agent cleanup.")
    # T-1540 iter3: clarify the [?] doc-promise. Partial-complete state requires a
    # Recommendation block (T-1529 structural gate), so [?] is rare and not expected
    # in this queue. The [?] is defensive only.
    print("Review each when ready. No urgency implied. Prefix is the agent's recommendation: `[GO]` confirm, `[DEFER]`/`[NO-GO]` decide. `[NO-REC]` means the agent never wrote a Recommendation block — task isn't ready for review yet (T-1576). (`[?]` would mean a partial-complete task slipped past the T-1529 recommendation gate — should not occur in normal flow.)")
    print()
    for tid, tname, count, preview, verdict in partial:
        # T-1461: render review URL inline if Watchtower is reachable
        # T-1530: prefix with agent recommendation verdict
        if WT_URL:
            print(f"- [{verdict}] [{tid}]({WT_URL}/review/{tid}): {tname} ({count} unchecked)")
        else:
            print(f"- [{verdict}] **{tid}**: {tname} ({count} unchecked)")
        print(f"  - e.g.: {preview}")
    print()
PCEOF
)

if [ -n "$PARTIAL_COMPLETE_SECTION" ]; then
    echo "$PARTIAL_COMPLETE_SECTION" >> "$HANDOVER_FILE"
fi

# Add observation inbox status if any pending
if [ "$PENDING_OBS" -gt 0 ]; then
    {
        echo "## Observation Inbox"
        echo ""
        if [ "$URGENT_OBS" -gt 0 ]; then
            echo "**$PENDING_OBS pending observations ($URGENT_OBS urgent)** — run \`fw note triage\` before starting new work."
        else
            echo "**$PENDING_OBS pending observations** — review with \`fw note list\` or \`fw note triage\`."
        fi
        echo ""
        # List pending observation summaries
        python3 << PYEOF
import re
with open("$INBOX_FILE") as f:
    content = f.read()
blocks = re.split(r'\n  - ', content)
for b in blocks[1:]:
    if 'status: pending' not in b:
        continue
    obs_id = re.search(r'id: (OBS-\d+)', b)
    text = re.search(r'text: "(.*?)"', b)
    urgent = 'urgent: true' in b
    if obs_id and text:
        prefix = "[URGENT] " if urgent else ""
        print(f"- {prefix}{obs_id.group(1)}: {text.group(1)}")
PYEOF
        echo ""
    } >> "$HANDOVER_FILE"
fi

# Add gaps register summary if any watching
if [ "$WATCHING_GAPS" -gt 0 ]; then
    {
        echo "## Gaps Register"
        echo ""
        echo "**$WATCHING_GAPS concern(s) being watched** — see \`.context/project/concerns.yaml\`"
        echo ""
        python3 << PYEOF
import yaml
with open("$GAPS_FILE") as f:
    data = yaml.safe_load(f)
# T-397: concerns.yaml uses 'concerns' key, fallback to 'gaps'
items = data.get('concerns', data.get('gaps', []))
for item in items:
    if item.get('status') != 'watching':
        continue
    sev = item.get('severity', 'unknown')
    print(f"- **{item['id']}** [{sev}]: {item['title']}")
PYEOF
        echo ""
        echo "Run \`fw audit\` to check if any trigger conditions are met."
        echo ""
    } >> "$HANDOVER_FILE"
fi

cat >> "$HANDOVER_FILE" << EOF
## Decisions Made This Session

None

## Things Tried That Failed

None

## Open Questions / Blockers

None

## Token Usage

$(if [ -n "$TOKEN_TOTAL" ]; then
    echo "- **Total:** $TOKEN_TOTAL tokens"
    echo "- **Turns:** ${TOKEN_TURNS:-?}"
    [ -n "$TOKEN_CACHE_HIT" ] && echo "- **Cache read:** $TOKEN_CACHE_HIT"
    echo ""
    echo "Run \`fw costs current\` for detailed breakdown."
else
    echo "No token data available (requires JSONL transcript)."
fi)

## Gotchas / Warnings for Next Session

See gaps register above.

## Suggested First Action

$(python3 -c "
import glob, re, os
tasks_dir = '$TASKS_DIR/active'
# Find first started-work task in horizon:now/next, prefer agent-owned.
# T-1724: skip inception tasks with a recorded DEFER decision — those are
# parked under 'Watching for Recurrence', not actionable. Without this
# guard, the same DEFERed inception (e.g. T-1611) gets recommended every
# session even though it explicitly chose to wait.
candidates = []
for f in sorted(glob.glob(os.path.join(tasks_dir, '*.md'))):
    with open(f) as fh:
        content = fh.read()
    if 'status: started-work' not in content:
        continue
    h = re.search(r'^horizon:\s*(.+)', content, re.M)
    if not h or h.group(1).strip() not in ('now', 'next'):
        continue
    # T-1724: an inception with a recorded DEFER is parked, not active work.
    # Look for a literal '**Decision**: DEFER' line (the inception-decide
    # canonical marker).
    if re.search(r'^\*\*Decision\*\*:\s*DEFER', content, re.M):
        continue
    tid = re.search(r'^id:\s*(.+)', content, re.M)
    tname = re.search(r'^name:\s*(.+)', content, re.M)
    owner = re.search(r'^owner:\s*(.+)', content, re.M)
    is_human = owner and owner.group(1).strip() == 'human'
    hval = 0 if h.group(1).strip() == 'now' else 1
    candidates.append((is_human, hval, tid.group(1).strip() if tid else '', tname.group(1).strip() if tname else ''))
candidates.sort()
if candidates:
    _, _, tid, tname = candidates[0]
    print(f'Continue {tid}: {tname}')
else:
    print('See active tasks')
" 2>/dev/null || echo "See active tasks")

## Files Changed This Session

$(git -C "$PROJECT_ROOT" diff --stat HEAD~5 HEAD 2>/dev/null | tail -5 || echo "See Recent Commits")

## Recent Commits

$RECENT_COMMITS

---

## Handover Quality Feedback (for next session to complete)

- Did this handover help? [ ]
- What was missing?
- What was unnecessary?
EOF

# Step 2b: Check for orphaned TermLink worker outputs (T-818/T-820)
ORPHAN_COUNT=$(find /tmp -maxdepth 1 -name "fw-agent-*.md" -newer "$HANDOVER_DIR/LATEST.md" 2>/dev/null | wc -l)
ORPHAN_COUNT=$(echo "$ORPHAN_COUNT" | tr -d '[:space:]')
if [ "${ORPHAN_COUNT:-0}" -gt 0 ]; then
    echo "" >> "$HANDOVER_FILE"
    echo "## Orphaned Worker Outputs" >> "$HANDOVER_FILE"
    echo "" >> "$HANDOVER_FILE"
    echo "**$ORPHAN_COUNT file(s) in /tmp/fw-agent-\*.md** newer than last handover." >> "$HANDOVER_FILE"
    echo "These may be TermLink worker results that weren't integrated." >> "$HANDOVER_FILE"
    echo "" >> "$HANDOVER_FILE"
    find /tmp -maxdepth 1 -name "fw-agent-*.md" -newer "$HANDOVER_DIR/LATEST.md" 2>/dev/null | while read -r f; do
        echo "- \`$(basename "$f")\` ($(wc -l < "$f") lines)" >> "$HANDOVER_FILE"
    done
    echo "" >> "$HANDOVER_FILE"
    echo -e "${YELLOW}WARNING: $ORPHAN_COUNT orphaned worker output(s) in /tmp${NC}"
fi

# Step 3: Update LATEST.md (symlink so edits to session file auto-reflect)
ln -sf "$(basename "$HANDOVER_FILE")" "$HANDOVER_DIR/LATEST.md"

echo ""
echo -e "${GREEN}=== Handover Created ===${NC}"
echo "File: $HANDOVER_FILE"
echo "Latest: $HANDOVER_DIR/LATEST.md"

# T-709: Push notification — session ended
if [ -f "$FRAMEWORK_ROOT/lib/notify.sh" ]; then
    source "$FRAMEWORK_ROOT/lib/notify.sh"
    ACTIVE_COUNT=$(find "$PROJECT_ROOT/.tasks/active" -maxdepth 1 -name 'T-*.md' -type f 2>/dev/null | wc -l)
    fw_notify "Session Ended: $SESSION_ID" "Handover created. Active tasks: $ACTIVE_COUNT" "manual" "framework"
fi

# Handle auto-commit
if [ "$AUTO_COMMIT" = true ]; then
    _resolve_commit_task

    echo ""
    echo -e "${YELLOW}Auto-committing handover...${NC}"

    # Resolve git agent: FRAMEWORK_ROOT (set by this script), then PROJECT_ROOT fallback
    GIT_AGENT=""
    if [ -n "${FRAMEWORK_ROOT:-}" ] && [ -f "$FRAMEWORK_ROOT/agents/git/git.sh" ]; then
        GIT_AGENT="$FRAMEWORK_ROOT/agents/git/git.sh"
    elif [ -f "$PROJECT_ROOT/agents/git/git.sh" ]; then
        GIT_AGENT="$PROJECT_ROOT/agents/git/git.sh"
    fi

    if [ -n "$GIT_AGENT" ]; then
        # Stage handover files
        git -C "$PROJECT_ROOT" add "$HANDOVER_FILE" "$HANDOVER_DIR/LATEST.md"

        # Commit via git agent
        PROJECT_ROOT="$PROJECT_ROOT" "$GIT_AGENT" commit -m "$COMMIT_TASK: Session handover $SESSION_ID"

        # Push to all remotes (T-1144: prevent unpushed commit accumulation)
        # T-1277: bound the push so an unreachable remote (e.g. onedev behind a
        # down VPN) cannot stall the auto-handover hook for hours.
        # T-1341 (L-019): default raised 15s → 60s because pre-push hook runs
        # fw audit (~10s), leaving too little headroom for the actual push at 15s.
        # Override via FW_HANDOVER_PUSH_TIMEOUT.
        echo ""
        echo -e "${CYAN}Pushing to remotes...${NC}"
        _push_failed=false
        _push_timeout="${FW_HANDOVER_PUSH_TIMEOUT:-60}"
        # T-1255 (G-007): When >1 remote is configured AND `origin` is one of them,
        # push ONLY to origin. Mirroring (e.g. github) is OneDev's job via
        # .onedev-buildspec.yml's PushRepository job. Pushing directly to mirror
        # remotes caused github-ahead-of-onedev divergence whenever onedev briefly
        # 502'd at handover time (T-1253 inception, PL-036).
        # T-1474: Guard against the no-origin case. If no remote is named `origin`,
        # there is no canonical source for OneDev to mirror from, so the assumption
        # that other remotes are "mirrors" is invalid — push to all of them.
        _remote_count=$(git -C "$PROJECT_ROOT" remote 2>/dev/null | wc -l)
        if git -C "$PROJECT_ROOT" remote 2>/dev/null | grep -qx 'origin'; then
            _has_origin=true
        else
            _has_origin=false
        fi
        while IFS= read -r remote_name; do
            [ -z "$remote_name" ] && continue
            if [ "$_has_origin" = true ] && [ "$_remote_count" -gt 1 ] && [ "$remote_name" != "origin" ]; then
                echo -e "  ${CYAN}Skipping $remote_name (mirrored from origin via PushRepository)${NC}"
                continue
            fi
            if timeout "$_push_timeout" git -C "$PROJECT_ROOT" push --follow-tags "$remote_name" HEAD 2>&1; then
                echo -e "  ${GREEN}Pushed to $remote_name ✓${NC}"
            else
                _exit=$?
                if [ "$_exit" -eq 124 ]; then
                    echo -e "  ${YELLOW}WARNING: Push to $remote_name timed out after ${_push_timeout}s (non-blocking, T-1277)${NC}" >&2
                else
                    echo -e "  ${YELLOW}WARNING: Push to $remote_name failed (non-blocking)${NC}" >&2
                fi
                _push_failed=true
            fi
        done < <(git -C "$PROJECT_ROOT" remote 2>/dev/null)
        if [ "$_push_failed" = true ]; then
            echo -e "${YELLOW}Some pushes failed. Run 'git push' manually after resolving.${NC}"
        fi
    else
        error "Git agent not found. Manual commit required."
        echo "Run: git commit -m \"$COMMIT_TASK: Session handover $SESSION_ID\""
    fi
else
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo "1. Review $HANDOVER_FILE (auto-filled from git data)"
    echo "2. Edit if needed — enrich Decisions, Gotchas, Open Questions"
    _resolve_commit_task
    echo "3. Commit with: $(_emit_user_command "git commit -m \"$COMMIT_TASK: Session handover $SESSION_ID\"")"
    echo ""
    echo -e "${CYAN}Key sections to complete:${NC}"
    echo "- Where We Are (summary)"
    echo "- Work in Progress (last action, next step for each task)"
    echo "- Decisions Made (with rationale)"
    echo "- Suggested First Action (most important)"
fi
