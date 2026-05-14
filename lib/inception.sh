#!/bin/bash
# fw inception - Inception phase workflow
# Manages exploration-phase work: problem definition, assumptions, go/no-go

# Ensure _fw_cmd/_emit_user_command are available (T-1143)
[[ -z "${_FW_PATHS_LOADED:-}" ]] && source "${FRAMEWORK_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}/lib/paths.sh" 2>/dev/null || true

do_inception() {
    local subcmd="${1:-}"
    shift || true

    case "$subcmd" in
        start)
            do_inception_start "$@"
            ;;
        status)
            do_inception_status "$@"
            ;;
        decide)
            do_inception_decide "$@"
            ;;
        sweep)
            do_inception_sweep "$@"
            ;;
        retrofit-rec|retrofit-recommendations)
            do_inception_retrofit_recommendations "$@"
            ;;
        ""|-h|--help)
            show_inception_help
            ;;
        *)
            echo -e "${RED}Unknown inception subcommand: $subcmd${NC}"
            show_inception_help
            exit 1
            ;;
    esac
}

show_inception_help() {
    echo -e "${BOLD}fw inception${NC} - Inception phase workflow"
    echo ""
    echo -e "${BOLD}Commands:${NC}"
    echo "  start <name>                      Create inception task + set focus"
    echo "  status                            Show all inception tasks"
    echo "  decide <T-XXX> go|no-go|defer     Record go/no-go decision"
    echo "  sweep [--dry-run]                 Retroactively finalize inceptions with"
    echo "                                    recorded decisions but unchecked Human ACs"
    echo "  retrofit-rec [--apply]            T-1716 retrofit: scan active inceptions"
    echo "                                    with template-only Recommendation blocks"
    echo "                                    and inject DEFER stubs (read-only by default)"
    echo ""
    echo -e "${BOLD}Options:${NC}"
    echo "  start --owner <owner>             Set task owner (default: human)"
    echo "  start --recommendation GO|NO-GO|DEFER   Required under \$CLAUDECODE=1 (T-1715)"
    echo "  start --rationale '<reason>'      Required under \$CLAUDECODE=1 (T-1715)"
    echo "  start --i-am-human                Bypass filing-time gate (logged)"
    echo "  decide --rationale '<reason>'     Required: explain the decision"
    echo ""
    echo -e "${BOLD}Examples:${NC}"
    echo "  fw inception start 'Evaluate notification system' \\"
    echo "    --recommendation DEFER --rationale 'Captured for later, no exploration done'"
    echo "  fw inception status"
    echo "  fw inception decide T-085 go --rationale 'All assumptions validated'"
}

do_inception_start() {
    local name="${1:-}"
    shift || true

    if [ -z "$name" ]; then
        echo -e "${RED}Usage: fw inception start '<name>' [--owner <owner>] \\${NC}"
        echo -e "${RED}         --recommendation GO|NO-GO|DEFER --rationale '<reason>'${NC}"
        exit 1
    fi

    # Parse args
    local owner="human"
    local recommendation=""
    local rationale=""
    local i_am_human=false
    while [[ $# -gt 0 ]]; do
        case $1 in
            --owner) owner="$2"; shift 2 ;;
            --recommendation) recommendation="$2"; shift 2 ;;
            --rationale) rationale="$2"; shift 2 ;;
            --i-am-human) i_am_human=true; shift ;;
            *) shift ;;
        esac
    done

    # Validate --recommendation value if provided
    if [ -n "$recommendation" ]; then
        case "$recommendation" in
            GO|NO-GO|DEFER) ;;
            *)
                echo -e "${RED}Invalid --recommendation: '$recommendation' (must be GO, NO-GO, or DEFER)${NC}" >&2
                exit 1
                ;;
        esac
    fi

    # Filing-time recommendation gate (T-1715/T-1716): under $CLAUDECODE=1,
    # require --recommendation + --rationale so the agent's advisory is captured
    # at filing time rather than recurring "blank decision for human" pattern.
    # Override: --i-am-human (scripts/tests/Watchtower) — logged.
    if [ "${CLAUDECODE:-}" = "1" ] && [ "$i_am_human" = false ]; then
        if [ -z "$recommendation" ] || [ -z "$rationale" ]; then
            echo -e "${RED}ERROR: --recommendation and --rationale required when filing under \$CLAUDECODE=1 (T-1715, T-679)${NC}" >&2
            echo "" >&2
            echo -e "Filing an inception under an agent session must include the agent's recommendation." >&2
            echo -e "The human is the decision-maker; the agent is the advisory." >&2
            echo "" >&2
            echo -e "Correct invocation:" >&2
            echo -e "  fw inception start '$name' \\" >&2
            echo -e "    --recommendation GO|NO-GO|DEFER \\" >&2
            echo -e "    --rationale '<one-paragraph reason citing evidence>'" >&2
            echo "" >&2
            echo -e "Acceptable values: GO, NO-GO, DEFER. Use DEFER if you don't yet have evidence." >&2
            echo -e "See CLAUDE.md §Presenting Work for Human Review (T-679)." >&2
            exit 1
        fi
    fi

    # Log bypass if --i-am-human used (T-1716)
    if [ "$i_am_human" = true ]; then
        local _log_file="${PROJECT_ROOT}/.context/working/.gate-bypass-log.yaml"
        local _ts
        _ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        {
            echo "- timestamp: '$_ts'"
            echo "  task: '<filing: $name>'"
            echo "  flag: '--i-am-human'"
            echo "  caller: 'do_inception_start'"
            echo "  reason: 'filing-time recommendation gate (T-1715/T-1716)'"
        } >> "$_log_file"
    fi

    # Create inception task using create-task.sh
    # T-554: Inception tasks start as captured (not started-work).
    # Use fw work-on T-XXX to explicitly start work when ready.
    local output
    output=$("$AGENTS_DIR/task-create/create-task.sh" \
        --name "$name" \
        --description "Inception: $name" \
        --type inception \
        --owner "$owner" 2>&1)

    echo "$output"

    # Extract task ID and set focus
    local task_id
    task_id=$(echo "$output" | grep "^ID:" | sed 's/ID:[[:space:]]*//')
    if [ -n "$task_id" ]; then
        # Inject Recommendation block if provided (T-1715/T-1716)
        if [ -n "$recommendation" ] && [ -n "$rationale" ]; then
            _inject_recommendation_block "$task_id" "$recommendation" "$rationale"
        fi

        "$AGENTS_DIR/context/context.sh" focus "$task_id"
        echo ""
        echo -e "${YELLOW}Next steps:${NC}"
        echo "1. Fill in Problem Statement, Constraints, Plan, Criteria"
        echo "2. Register assumptions:"
        echo "     fw assumption add 'Users want X' --task $task_id"
        echo "3. Conduct exploration (spikes, prototypes, research)"
        echo "4. Record decision via Watchtower:"
        echo "     fw task review $task_id"
    fi
}

# Replace the template Recommendation comment block with a real Recommendation
# section using the provided recommendation + rationale. T-1715/T-1716.
_inject_recommendation_block() {
    local task_id="$1"
    local recommendation="$2"
    local rationale="$3"

    local task_file
    task_file=$(find_task_file "$task_id" active)
    if [ -z "$task_file" ] || [ ! -f "$task_file" ]; then
        echo -e "${YELLOW}WARNING: Could not find task file for $task_id; Recommendation NOT injected${NC}" >&2
        return 1
    fi

    REC="$recommendation" RAT="$rationale" python3 - "$task_file" <<'PYINJECT'
import os, re, sys
fp = sys.argv[1]
rec = os.environ['REC']
rat = os.environ['RAT']
with open(fp) as f:
    content = f.read()

# Match the template comment block under ## Recommendation, terminating
# at the next "##" heading or end-of-file. Use non-greedy .*? with DOTALL.
pattern = re.compile(
    r'(## Recommendation\n)\s*<!--.*?-->[ \t]*\n+(?=##|\Z)',
    re.DOTALL
)
new_block = (
    f"\n**Recommendation:** {rec}\n\n"
    f"**Rationale:**\n\n{rat}\n\n"
    f"**Evidence:**\n\n"
    "<!-- Add evidence bullets as exploration progresses (file paths,\n"
    "     commit hashes, test results). The filing-time recommendation\n"
    "     can be revised before fw inception decide. -->\n\n"
)

m = pattern.search(content)
if not m:
    print(f"WARNING: Recommendation template-comment not found in {fp}; skipping inject", file=sys.stderr)
    sys.exit(0)

new_content = content[:m.start()] + "## Recommendation\n" + new_block + content[m.end():]
with open(fp, 'w') as f:
    f.write(new_content)
print(f"Injected Recommendation: {rec}")
PYINJECT
}

do_inception_status() {
    python3 << 'PYINCEPTION'
import os, yaml

GREEN = '\033[0;32m'
YELLOW = '\033[1;33m'
CYAN = '\033[0;36m'
BOLD = '\033[1m'
NC = '\033[0m'

project_root = os.environ.get('PROJECT_ROOT', '.')
tasks = []

for status_dir in ['active', 'completed']:
    task_dir = os.path.join(project_root, '.tasks', status_dir)
    if not os.path.isdir(task_dir):
        continue
    for fn in sorted(os.listdir(task_dir)):
        if not fn.endswith('.md'):
            continue
        path = os.path.join(task_dir, fn)
        try:
            with open(path) as f:
                text = f.read()
            if not text.startswith('---'):
                continue
            end = text.index('---', 3)
            fm = yaml.safe_load(text[3:end]) or {}
            if fm.get('workflow_type') != 'inception':
                continue

            # Extract decision from body
            decision = 'pending'
            body = text[end+3:]
            for line in body.split('\n'):
                if line.startswith('**Decision**:'):
                    val = line.replace('**Decision**:', '').strip()
                    if val and val not in ('', '[GO / NO-GO / DEFER]'):
                        decision = val

            tasks.append({
                'id': fm.get('id', '?'),
                'name': fm.get('name', '?'),
                'status': fm.get('status', '?'),
                'decision': decision,
                'dir': status_dir,
            })
        except Exception:
            continue

if not tasks:
    print(f'{YELLOW}No inception tasks found{NC}')
    print('Create one with: fw inception start "<name>"')
else:
    active = [t for t in tasks if t['dir'] == 'active']
    completed = [t for t in tasks if t['dir'] == 'completed']

    print(f'{BOLD}Inception Tasks{NC} ({len(active)} active, {len(completed)} completed)')
    print()
    print(f'  {"ID":<8} {"Status":<16} {"Decision":<10} {"Name"}')
    print(f'  {"─"*8} {"─"*16} {"─"*10} {"─"*40}')
    for t in tasks:
        sc = GREEN if t['status'] == 'work-completed' else CYAN
        print(f'  {t["id"]:<8} {sc}{t["status"]:<16}{NC} {t["decision"]:<10} {t["name"]}')
PYINCEPTION
}

# T-1324: Tick the Human AC that authorizes the inception decision.
# After `fw inception decide` writes the Decision block, the templated
# `[REVIEW] Review exploration findings and approve go/no-go decision`
# (or `[RUBBER-STAMP] Record ... decision`) Human AC is structurally
# satisfied by the same command — leaving it unchecked keeps the task
# in partial-complete forever (G-008 contributor; T-1322 / P-039).
#
# Idempotent. Only ticks ACs whose text matches the templated predicate
# under the `### Human` subsection — never touches custom ACs or `### Agent`.
#
# T-1194: also ticks the 3 ceremonial Agent ACs when a `## Recommendation`
# section exists (same structural-satisfaction pattern). Never touches
# user-customized Agent ACs.
tick_inception_decide_acs() {
    local task_file="$1"
    [ -f "$task_file" ] || return 0
    python3 - "$task_file" << 'PYTICK'
import re
import sys

task_file = sys.argv[1]
with open(task_file) as f:
    content = f.read()

PATTERNS = [
    re.compile(r'\[REVIEW\].*go/?no-go decision', re.IGNORECASE),
    re.compile(r'\[RUBBER-STAMP\].*[Rr]ecord.*decision'),
    # T-1837: broader '[REVIEW] Decide ...' coverage. The original literal
    # 'go/no-go decision' phrasing missed real-world variants like
    # 'Decide go/no-go AND which approach' (T-1829), 'Decide GO/NO-GO/DEFER on...'
    # (T-1830), 'Decide on prevention pattern' (T-1831). For inception tasks
    # — the only context this function runs — '[REVIEW] Decide ...' is
    # canonically the go/no-go authorization, so a broad match is safe.
    re.compile(r'\[REVIEW\].*\bdecide\b', re.IGNORECASE),
]

# T-1194: when Recommendation section exists, also tick the 3 ceremonial
# Agent ACs from the default inception template. Never touches custom ACs.
# T-1472 (OBS-019 Level D): primary detection is now `<!-- @auto-tick-on-decide -->`
# marker — adjacent to the AC line or on the line above. AGENT_PATTERNS regex
# is retained as a fallback for tasks predating the marker (most existing
# inception tasks). Markered detection wins on text-wording independence.
AGENT_PATTERNS = [
    re.compile(r'^Problem statement validated', re.IGNORECASE),
    re.compile(r'^Assumptions tested', re.IGNORECASE),
    re.compile(r'^Recommendation written with rationale', re.IGNORECASE),
    # T-1466: ACs added by pickup imports / authored manually that simply
    # restate "decision recorded" — the decide command itself satisfies them.
    re.compile(r'\[Inception decision recorded\]', re.IGNORECASE),
]
TICK_MARKER = '<!-- @auto-tick-on-decide -->'
has_recommendation = bool(re.search(r'^## Recommendation\s*$', content, re.MULTILINE))

lines = content.split('\n')
in_human = False
in_agent = False
out = []
prev_line = ''
for line in lines:
    stripped = line.strip()
    if stripped == '### Human':
        in_human = True
        in_agent = False
        out.append(line)
        prev_line = line
        continue
    if stripped == '### Agent':
        in_agent = True
        in_human = False
        out.append(line)
        prev_line = line
        continue
    # Exit subsection at next ## or ### header.
    if (in_human or in_agent) and (line.startswith('## ') or line.startswith('### ')):
        in_human = False
        in_agent = False
    if in_human:
        m = re.match(r'^(\s*)- \[ \](.*)$', line)
        if m:
            # T-1472: marker on this line OR on the line above wins
            has_marker = (TICK_MARKER in line) or (TICK_MARKER in prev_line)
            if has_marker or any(p.search(m.group(2)) for p in PATTERNS):
                line = f'{m.group(1)}- [x]{m.group(2)}'
    elif in_agent and has_recommendation:
        m = re.match(r'^(\s*)- \[ \]\s*(.*)$', line)
        if m:
            has_marker = (TICK_MARKER in line) or (TICK_MARKER in prev_line)
            if has_marker or any(p.search(m.group(2)) for p in AGENT_PATTERNS):
                line = f'{m.group(1)}- [x] {m.group(2)}'
    out.append(line)
    prev_line = line

with open(task_file, 'w') as f:
    f.write('\n'.join(out))
PYTICK
}

do_inception_decide() {
    local task_id="${1:-}"
    local decision="${2:-}"
    shift 2 2>/dev/null || true

    if [ -z "$task_id" ] || [ -z "$decision" ]; then
        echo -e "${RED}Usage: fw inception decide T-XXX go --rationale 'reason'${NC}"
        exit 1
    fi

    # Validate decision value
    case "$decision" in
        go|no-go|defer) ;;
        *)
            echo -e "${RED}Decision must be: go, no-go, or defer${NC}"
            exit 1
            ;;
    esac

    # Parse rationale + --i-am-human override (T-1259) + --from-watchtower exemption (T-1262)
    local rationale=""
    local i_am_human=false
    local from_watchtower=false
    while [[ $# -gt 0 ]]; do
        case $1 in
            --rationale) rationale="$2"; shift 2 ;;
            --i-am-human) i_am_human=true; shift ;;
            --from-watchtower) from_watchtower=true; shift ;;
            *) shift ;;
        esac
    done

    if [ -z "$rationale" ]; then
        echo -e "${RED}Rationale required: --rationale 'explanation'${NC}"
        exit 1
    fi

    # Gate (T-1259): block agent invocation — enforces T-679
    # Agents must use `fw task review T-XXX` + Watchtower; never call decide directly.
    # $CLAUDECODE=1 is set by Claude Code when running agent sessions.
    # Overrides: --i-am-human (scripts/tests); --from-watchtower (T-1262, Flask subprocess).
    if [ "${CLAUDECODE:-}" = "1" ] && [ "$i_am_human" = false ] && [ "$from_watchtower" = false ]; then
        echo -e "${RED}ERROR: Agents must not invoke 'fw inception decide' directly (T-679, T-1259)${NC}" >&2
        echo "" >&2
        echo -e "You appear to be running inside Claude Code (\$CLAUDECODE=1)." >&2
        echo -e "Inception decisions belong to the human, recorded via Watchtower." >&2
        echo "" >&2
        echo -e "Correct flow:" >&2
        echo -e "  1. Agent: $(_emit_user_command "task review $task_id")" >&2
        echo -e "  2. Human: open the Watchtower URL, record GO/NO-GO there" >&2
        echo "" >&2
        echo -e "If this is a human running inside an agent session (rare), pass --i-am-human." >&2
        echo -e "See CLAUDE.md §Presenting Work for Human Review." >&2
        exit 1
    fi

    # Find task file
    local task_file
    task_file=$(find_task_file "$task_id" active)
    if [ -z "$task_file" ]; then
        echo -e "${RED}Task $task_id not found in active tasks${NC}"
        exit 1
    fi

    # Verify it's an inception task
    if ! grep -q "workflow_type: inception" "$task_file"; then
        echo -e "${RED}$task_id is not an inception task${NC}"
        exit 1
    fi

    # Gate: placeholder audit chokepoint (T-1111/T-1113). Runs FIRST so that
    # a task edited between review-marker creation and decide-time still
    # catches bleed-through. If the marker exists from a previous review
    # but the task was later edited to introduce placeholders, this blocks.
    if [ -f "$FW_LIB_DIR/task-audit.sh" ]; then
        source "$FW_LIB_DIR/task-audit.sh"
        if ! audit_task_placeholders "$task_file"; then
            exit 1
        fi
    fi

    # Gate: require fw task review before accepting decision (T-973)
    local review_marker="$PROJECT_ROOT/.context/working/.reviewed-$task_id"
    if [ ! -f "$review_marker" ]; then
        echo -e "${RED}ERROR: Task review required before decision${NC}" >&2
        echo "" >&2
        echo -e "Run this first:" >&2
        echo -e "  $(_emit_user_command "task review $task_id")" >&2
        echo "" >&2
        echo -e "Then re-run the decide command." >&2
        exit 1
    fi

    # Gate: require ## Recommendation with actual content (T-974, hardened by T-1497).
    # The previous inline check used `grep -v '^<!--'` which only filtered the opening
    # line of multi-line HTML comments — the Recommendation template's commented
    # `**Recommendation:** GO / NO-GO / DEFER` line leaked past the filter and the
    # gate accepted empty Recommendation sections. T-1501/T-1502 reached the human
    # decision queue with blank bodies. Use the multi-line-aware helper instead.
    if ! audit_inception_recommendation "$task_file"; then
        echo -e "${RED}ERROR: ## Recommendation section required before decision${NC}" >&2
        echo "" >&2
        echo -e "The task file must contain a ## Recommendation section with a non-commented:" >&2
        echo -e "  **Recommendation:** GO / NO-GO / DEFER" >&2
        echo -e "  **Rationale:** Why (cite evidence)" >&2
        echo -e "  **Evidence:** Bullet list of findings" >&2
        echo "" >&2
        echo -e "Watchtower reads this section — without it, the human sees no recommendation." >&2
        echo -e "Write the recommendation outside the HTML comment, then re-run this command." >&2
        exit 1
    fi

    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local decision_upper
    decision_upper=$(echo "$decision" | tr '[:lower:]' '[:upper:]')

    # T-1503: Preflight Agent AC check BEFORE mutating task body.
    # Original bug: tick_inception_decide_acs ran AFTER the Decision/Updates
    # writes, so a task with custom (non-auto-tick) Agent ACs would have its
    # body poisoned (Decision block + Updates entry written) and then
    # update-task.sh would block at the P-010 AC gate, leaving the task
    # in an inconsistent state (decision recorded but status=started-work).
    # Retries appended duplicate Updates entries.
    #
    # Fix: tick first, then count remaining unchecked Agent ACs. If any
    # remain, abort here — task body untouched, no duplicate retries possible.
    # Mirrors update-task.sh:73-105 AC counting logic; no new behavior, just
    # early validation. (T-131 in downstream 003-NTB-ATC-Plugin / P-010.)
    if [ "$decision" = "go" ] || [ "$decision" = "no-go" ]; then
        tick_inception_decide_acs "$task_file"

        local _ac_section _agent_acs _agent_total _agent_checked _agent_unchecked
        _ac_section=$(sed -n '/^## Acceptance Criteria/,/^## /p' "$task_file" 2>/dev/null | sed '$d' | sed '/<!--/,/-->/d')
        if echo "$_ac_section" | grep -q '^### Agent'; then
            _agent_acs=$(echo "$_ac_section" | awk '/^### Agent/{f=1; next} /^### /{f=0} f')
            _agent_total=$(echo "$_agent_acs" | grep -cE '^\s*-\s*\[[ x]\]' || true)
            _agent_checked=$(echo "$_agent_acs" | grep -cE '^\s*-\s*\[x\]' || true)
            _agent_unchecked=$((_agent_total - _agent_checked))
            if [ "$_agent_total" -gt 0 ] && [ "$_agent_unchecked" -gt 0 ]; then
                echo -e "${RED}ERROR: Cannot record decision — $_agent_unchecked/$_agent_total agent AC unchecked${NC}" >&2
                echo "" >&2
                echo "Unchecked Agent ACs:" >&2
                echo "$_agent_acs" | grep -E '^\s*-\s*\[ \]' | head -10 >&2
                echo "" >&2
                # T-1836 (T-1831 C-3): body-vs-checkbox drift hint at decide-preflight.
                local _rec_block _rec_filled=false
                _rec_block=$(sed -n '/^## Recommendation/,/^## /p' "$task_file" 2>/dev/null | sed '$d')
                if [ -n "$_rec_block" ] && echo "$_rec_block" | grep -qE '^\*\*(Recommendation|Rationale|Evidence)(:\*\*|\*\*:)'; then
                    _rec_filled=true
                fi
                if [ "$_rec_filled" = true ]; then
                    echo -e "${YELLOW}Hint:${NC} task body has a filled \`## Recommendation\` block — AC content likely present." >&2
                    echo "  Tick the [x] boxes for each AC whose work is in place, then re-run decide." >&2
                    echo "  See CLAUDE.md §Verification Before Completion → Progressive AC ticking (T-1831 C-4)." >&2
                    echo "" >&2
                else
                    echo -e "${YELLOW}Hint:${NC} tick AC boxes as content is written, not after-the-fact." >&2
                    echo "  See CLAUDE.md §Verification Before Completion → Progressive AC ticking (T-1831 C-4)." >&2
                    echo "" >&2
                fi
                echo -e "${YELLOW}Why this gate exists:${NC} recording the decision before validating ACs would" >&2
                echo "leave the task body with Decision=$decision_upper but status stuck at started-work" >&2
                echo "(T-1503/P-010). Tick the ACs (or remove them if not needed), then re-run." >&2
                exit 1
            fi
        fi
    fi

    # Update Decision section via Python
    python3 - "$task_file" "$decision_upper" "$rationale" "$timestamp" << 'PYDECIDE'
import re
import sys

task_file, decision, rationale, timestamp = sys.argv[1:5]

with open(task_file, 'r') as f:
    content = f.read()

# T-1262: idempotent Decision section writer.
# Previous bug: only the FIRST `## Decision` got replaced; duplicates from repeated
# Watchtower clicks compounded (T-002 had 3+ duplicate blocks). Now we collapse ALL
# `## Decision` sections into one with the latest decision content.
lines = content.split('\n')
new_lines = []
in_decision = False
decision_written = False

for line in lines:
    if line.strip() == '## Decision':
        in_decision = True
        if not decision_written:
            # First Decision section — emit new content
            new_lines.append(line)
            new_lines.append('')
            new_lines.append(f'**Decision**: {decision}')
            new_lines.append(f'')
            new_lines.append(f'**Rationale**: {rationale}')
            new_lines.append(f'')
            new_lines.append(f'**Date**: {timestamp}')
            decision_written = True
        # Subsequent Decision sections (duplicates) — swallow entirely
        continue
    if in_decision:
        # T-1526: terminate at any heading H2-or-deeper (## or ### or more),
        # not just H2. update-task.sh appends `### timestamp` entries at EOF;
        # if a task lacks a trailing `## Updates` H2, those H3s land between
        # the Decision block and EOF. Old terminator (H2 only) swallowed them
        # on the next decide call. Decision blocks themselves contain only
        # `**Bold**` lines, never headings, so widening to H2+ doesn't break
        # the duplicate-collapse semantics.
        if re.match(r'^#{2,} ', line):
            in_decision = False
            new_lines.append('')
            new_lines.append(line)
        # Skip old decision content (and any content inside duplicate Decision sections)
        continue
    new_lines.append(line)

# T-1832: auto-create `## Decision` section when missing.
# Layer 2 root cause of S-2026-0514 errors 4-5: when a task lacks the singular
# `## Decision` heading (default.md template only has `## Decisions` plural),
# this script silently no-ops — decision_written stays False, no block written.
# Caller then ticks ACs and invokes update-task.sh --status work-completed,
# which fails at check_inception_decision (`**Decision**:` grep) emitting the
# misleading "no decision recorded" error. Fix: synthesize the section before
# `## Updates` (or `## Recommendation` as fallback, or at EOF), emit a warning
# to stderr so the auto-creation is visible. Subsequent decide calls take the
# normal path (the heading now exists).
if not decision_written:
    decision_block = [
        '## Decision',
        '',
        f'**Decision**: {decision}',
        '',
        f'**Rationale**: {rationale}',
        '',
        f'**Date**: {timestamp}',
        '',
    ]
    # Insertion priority: before `## Updates`, then before `## Recommendation`, then EOF.
    insert_at = None
    for anchor in ('## Updates', '## Recommendation'):
        for i, line in enumerate(new_lines):
            if line.strip() == anchor:
                insert_at = i
                break
        if insert_at is not None:
            break
    if insert_at is None:
        # Append at EOF — ensure trailing newline gap.
        if new_lines and new_lines[-1] != '':
            new_lines.append('')
        new_lines.extend(decision_block)
    else:
        new_lines = new_lines[:insert_at] + decision_block + new_lines[insert_at:]
    sys.stderr.write(
        f"WARNING [T-1832]: task file lacked '## Decision' heading — auto-created the section. "
        f"Consider adding the placeholder section explicitly in future. "
        f"(default.md template now includes it for new tasks.)\n"
    )

with open(task_file, 'w') as f:
    f.write('\n'.join(new_lines))
PYDECIDE

    # T-1324: Tick the Human AC that authorizes go/no-go BEFORE update-task.sh's
    # work-completed gate runs — otherwise the AC stays unchecked and the gate
    # keeps the task in partial-complete forever (G-008 contributor; P-039).
    # T-1503: tick now runs as part of the preflight above for go/no-go decisions
    # so we can validate AC state before mutating the task body. Re-run here
    # for the defer path (which skips preflight) and as a safety net for
    # Human ACs added between preflight and now.
    tick_inception_decide_acs "$task_file"

    # Add update entry
    cat >> "$task_file" << EOF

### $timestamp — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** $decision_upper
- **Rationale:** $rationale
EOF

    # Complete task if go or no-go (not defer)
    # --skip-sovereignty bypasses only R-033 (sovereignty gate) because inception decide
    # itself required Tier 0 approval — human authority was already exercised (T-637).
    # P-010 (AC gate) and P-011 (verification gate) are NOT bypassed (T-1101/T-1142).
    #
    # T-1515: Capture and propagate update-task.sh exit codes. Prior code discarded
    # them (T-1491 RCA), causing P-010/P-011 failures to leave tasks in class 2
    # stuck state (started-work + Decision recorded) while the user saw "recorded".
    local _uts_rc=0
    if [ "$decision" = "go" ] || [ "$decision" = "no-go" ]; then
        echo ""
        # T-1223: If task is in captured status, transition to started-work first.
        # The lifecycle requires captured → started-work → work-completed (no skip).
        local _current_status
        # T-1557 / L-302: pipefail guard — if frontmatter lacks status: line, do not silent-exit
        _current_status=$( { grep '^status:' "$task_file" 2>/dev/null || true; } | head -1 | sed 's/status:[[:space:]]*//')
        if [ "$_current_status" = "captured" ]; then
            "$AGENTS_DIR/task-create/update-task.sh" "$task_id" --status started-work --skip-sovereignty --reason "Inception decision in progress" 2>&1
            _uts_rc=$?
            if [ "$_uts_rc" -ne 0 ]; then
                echo "" >&2
                echo -e "${RED}ERROR: status transition captured→started-work failed (exit $_uts_rc)${NC}" >&2
                echo -e "${YELLOW}Decision was recorded but status is stuck. Recover with:${NC}" >&2
                echo "  $(_emit_user_command "inception sweep")" >&2
                echo "  $(_emit_user_command "task verify $task_id")" >&2
                return "$_uts_rc"
            fi
        fi
        "$AGENTS_DIR/task-create/update-task.sh" "$task_id" --status work-completed --skip-sovereignty --reason "Inception decision: $decision_upper" 2>&1
        _uts_rc=$?
        if [ "$_uts_rc" -ne 0 ]; then
            echo "" >&2
            echo -e "${RED}ERROR: status transition started-work→work-completed failed (exit $_uts_rc)${NC}" >&2
            echo -e "${YELLOW}Decision is recorded in the task body but status is stuck at started-work.${NC}" >&2
            echo -e "${YELLOW}Common causes: P-010 (unchecked AC), P-011 (verification command failure).${NC}" >&2
            echo -e "${YELLOW}Recover with:${NC}" >&2
            echo "  $(_emit_user_command "task verify $task_id")  # see what's blocking" >&2
            echo "  $(_emit_user_command "inception sweep")     # if you've fixed the blocker" >&2
            return "$_uts_rc"
        fi
    fi

    # Clean up review marker (T-973)
    rm -f "$PROJECT_ROOT/.context/working/.reviewed-$task_id" 2>/dev/null || true

    echo ""
    echo -e "${GREEN}Inception decision recorded${NC}"
    echo "Task: $task_id"
    echo "Decision: $decision_upper"

    # T-634: Auto-emit review (URL + QR + artifacts) after decision.
    # T-1509: omit task_file arg — update-task.sh has moved go/no-go tasks to
    # completed/ by this point, making the active/ path stale. emit_review
    # rediscovers from $task_id; defense-in-depth lives in review.sh.
    if [ -f "$FW_LIB_DIR/review.sh" ]; then
        source "$FW_LIB_DIR/review.sh"
        emit_review "$task_id"
    fi

    if [ "$decision" = "go" ]; then
        echo -e "${YELLOW}Next: Create build tasks for implementation${NC}"
    elif [ "$decision" = "no-go" ]; then
        echo -e "${YELLOW}Next: Capture learnings from exploration (fw context add-learning)${NC}"
    else
        echo -e "${YELLOW}Next: Continue exploration and decide when ready${NC}"
    fi
}

# T-1423: Retroactive sweep — tick Human AC + finalize inceptions stuck in active/
# with recorded decisions. Covers the pre-T-1324 backlog and hand-edited decisions
# that bypassed do_inception_decide.
do_inception_sweep() {
    local dry_run=false
    while [ $# -gt 0 ]; do
        case "$1" in
            --dry-run) dry_run=true ;;
            -h|--help)
                echo "fw inception sweep [--dry-run]"
                echo ""
                echo "Finds tasks in .tasks/active/ with status: work-completed AND a"
                echo "recorded ## Decision block. Ticks Human AC, then finalizes."
                return 0
                ;;
        esac
        shift
    done

    local tasks_dir="$PROJECT_ROOT/.tasks"
    local active_dir="$tasks_dir/active"
    local completed_dir="$tasks_dir/completed"

    [ -d "$active_dir" ] || { echo "No active tasks directory"; return 1; }
    mkdir -p "$completed_dir"

    local scanned=0
    local eligible=0
    local ticked=0
    local moved=0
    local still_pending=0
    local skipped=""

    local promoted=0
    for f in "$active_dir"/T-*.md; do
        [ -f "$f" ] || continue
        scanned=$((scanned+1))

        # T-1514: cover two stuck-state classes from T-1491 silent failure:
        #   class 1 — status: work-completed + decision recorded (sweep ticks AC + moves)
        #   class 2 — status: started-work + GO/NO-GO recorded (decide ran but status
        #             update was swallowed; promote to work-completed first)
        # DEFER on a started-work task is the legitimate "keep exploring" state and
        # is left untouched — only closing decisions (GO/NO-GO) trigger promotion.
        local current_status
        # T-1557 / L-302: pipefail guard
        current_status=$( { grep '^status:' "$f" 2>/dev/null || true; } | head -1 | sed 's/status:[[:space:]]*//')
        case "$current_status" in
            work-completed) ;;
            started-work)
                # Only class 2 candidates: must be a closing decision
                grep -qE '^\*\*Decision\*\*: (GO|NO-GO)' "$f" || continue
                ;;
            *) continue ;;
        esac
        # Must have a recorded decision
        grep -qE "^\*\*Decision\*\*: (GO|NO-GO|DEFER)" "$f" || continue

        eligible=$((eligible+1))
        local tid
        tid=$(basename "$f" | grep -oE "^T-[0-9]+")

        if [ "$dry_run" = true ]; then
            local dec
            # T-1557 / L-302: pipefail guard
            dec=$( { grep -E "^\*\*Decision\*\*:" "$f" 2>/dev/null || true; } | head -1 | sed 's/^\*\*Decision\*\*: //; s/ .*//')
            echo "  $tid: status=$current_status decision=$dec"
            continue
        fi

        # Class 2 recovery: status stuck at started-work + closing decision.
        # Promote to work-completed in place — decision is already recorded, so
        # the transition is just finishing what do_inception_decide started
        # before T-1491's exit-code propagation fix landed.
        if [ "$current_status" = "started-work" ]; then
            local _now
            _now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
            _sed_i 's/^status: started-work$/status: work-completed/' "$f"
            _sed_i "s/^last_update:.*/last_update: $_now/" "$f"
            promoted=$((promoted+1))
            echo "  $tid: promoted started-work → work-completed (T-1491 class 2 recovery)"
        fi

        # Tick the Human AC
        tick_inception_decide_acs "$f"
        ticked=$((ticked+1))

        # Recount Human ACs after ticking (grep -c returns exit 1 on zero matches under pipefail)
        # T-1620: strip <!-- ... --> blocks before counting. The default task
        # template's Example block contains "- [ ] [REVIEW] Dashboard renders
        # correctly" inside a comment — without this strip, T-1274-class tasks
        # (template-only Human section) are wrongly counted as having pending
        # Human ACs and never move to completed/. Mirrors the same fix at
        # bin/fw verify-acs (G-047) and agents/handover/handover.sh (T-1618).
        local human_unchecked
        human_unchecked=$(awk '/^### Human/,/^## [A-Z]/' "$f" \
            | python3 -c 'import re,sys; sys.stdout.write(re.sub(r"<!--.*?-->", "", sys.stdin.read(), flags=re.DOTALL))' \
            | grep -cE '^\s*- \[ \]' || true)

        if [ "${human_unchecked:-0}" -eq 0 ]; then
            local dest="$completed_dir/$(basename "$f")"
            mv "$f" "$dest"
            moved=$((moved+1))
            echo "  $tid: ticked + moved to completed/"
        else
            still_pending=$((still_pending+1))
            skipped+="$tid ($human_unchecked Human AC still unchecked)"$'\n'
            echo "  $tid: ticked but $human_unchecked Human AC still unchecked — stays in active/"
        fi
    done

    echo ""
    if [ "$dry_run" = true ]; then
        echo -e "${BOLD}Dry run:${NC} scanned=$scanned  eligible=$eligible"
        echo "Re-run without --dry-run to apply."
    else
        echo -e "${BOLD}Sweep complete:${NC} scanned=$scanned  eligible=$eligible  promoted=$promoted  ticked=$ticked  moved=$moved  stays-pending=$still_pending"
        if [ "$still_pending" -gt 0 ]; then
            echo ""
            echo -e "${YELLOW}Tasks with other Human ACs still pending (tick patterns didn't cover them):${NC}"
            echo "$skipped" | sed 's/^/  /'
        fi
    fi
}

# T-1716 Stream C: retrofit retroactive sweep
# Scans active inceptions for template-only Recommendation blocks and
# injects a DEFER stub with rationale 'captured pre-T-1716 gate'. Read-only
# by default (shows diff); --apply mutates files.
do_inception_retrofit_recommendations() {
    local apply=false
    while [ $# -gt 0 ]; do
        case "$1" in
            --apply) apply=true ;;
            -h|--help)
                echo "fw inception retrofit-rec [--apply]"
                echo ""
                echo "Scan .tasks/active/ for inception tasks with template-only"
                echo "Recommendation blocks. Without --apply: print one-per-line list"
                echo "+ proposed retrofit per task. With --apply: mutate files."
                echo ""
                echo "Origin: T-1716 (T-1715 implementation, prevention Path 8)."
                return 0
                ;;
        esac
        shift
    done

    source "$FRAMEWORK_ROOT/lib/inception_recommendation.sh" 2>/dev/null || true

    local active_dir="$PROJECT_ROOT/.tasks/active"
    [ -d "$active_dir" ] || { echo "No active tasks directory"; return 1; }

    local missing
    missing=$(find_inceptions_without_recommendation "$active_dir")
    if [ -z "$missing" ]; then
        echo -e "${GREEN}No active inceptions need Recommendation retrofit.${NC}"
        return 0
    fi

    local count=0
    while IFS= read -r task_id; do
        [ -z "$task_id" ] && continue
        count=$((count + 1))
        local task_file
        task_file=$(find "$active_dir" -maxdepth 1 -name "${task_id}-*.md" -type f 2>/dev/null | head -1)
        [ -z "$task_file" ] && continue

        local task_name
        task_name=$( { grep '^name:' "$task_file" 2>/dev/null || true; } | head -1 | sed 's/name:[[:space:]]*//; s/^"//; s/"$//')

        echo -e "${YELLOW}[$task_id]${NC} $task_name"
        echo "  File: $task_file"
        echo "  Action: inject DEFER stub Recommendation"

        if [ "$apply" = true ]; then
            REC=DEFER \
                RAT="Filed pre-T-1716 gate without Recommendation. Promotion criterion: re-surface when concrete spike data or human-graded evidence emerges. Auto-retrofitted by 'fw inception retrofit-rec --apply'." \
                python3 - "$task_file" <<'PYRETROFIT'
import os, re, sys
fp = sys.argv[1]
rec = os.environ.get('REC', 'DEFER')
rat = os.environ.get('RAT', '')
with open(fp) as f:
    content = f.read()
# Match template-comment Recommendation OR empty Recommendation
template_pat = re.compile(
    r'(## Recommendation\n)\s*<!--.*?-->[ \t]*\n+(?=##|\Z)',
    re.DOTALL
)
empty_pat = re.compile(
    r'(## Recommendation\n)\s*\n+(?=##|\Z)'
)
new_block = (
    f"\n**Recommendation:** {rec}\n\n"
    f"**Rationale:**\n\n{rat}\n\n"
    f"**Evidence:**\n\n"
    "<!-- Pre-gate retrofit. Add concrete evidence when re-surfacing. -->\n\n"
)
m = template_pat.search(content)
if not m:
    m = empty_pat.search(content)
if not m:
    print(f"  SKIP: Recommendation block not found in template/empty form", file=sys.stderr)
    sys.exit(0)
new_content = content[:m.start()] + "## Recommendation\n" + new_block + content[m.end():]
with open(fp, 'w') as f:
    f.write(new_content)
print(f"  WROTE: DEFER stub")
PYRETROFIT
        else
            echo "  (read-only — pass --apply to mutate)"
        fi
        echo ""
    done <<< "$missing"

    echo "---"
    if [ "$apply" = true ]; then
        echo -e "${GREEN}Retrofit applied: $count task(s)${NC}"
        echo "Review changes and edit each Recommendation to match the actual decision (DEFER → GO/NO-GO if applicable)."
    else
        echo -e "${CYAN}Read-only: $count task(s) would be retrofitted${NC}"
        echo "Run with --apply to mutate."
    fi
}
