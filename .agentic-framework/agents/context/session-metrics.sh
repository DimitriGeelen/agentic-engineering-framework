#!/bin/bash
# Session Quality Metrics — JSONL transcript analyzer (T-831)
#
# Single-pass analysis of current session's JSONL transcript to extract
# quality metrics for handover frontmatter and /timeline display.
#
# Usage:
#   agents/context/session-metrics.sh          # Analyze current session
#   agents/context/session-metrics.sh <path>   # Analyze specific JSONL
#
# Output: .context/working/.session-metrics.yaml
#
# Metrics extracted (P0 from T-830 Agent B design):
#   - commits_per_turn: Productive output density
#   - first_commit_turn: Session startup efficiency
#   - failed_tool_calls: Total failed tool calls
#   - failed_tool_call_rate: Failed / total tool calls
#   - edit_bursts: Same file edited 3+ times in 10-turn window
#   - productive_turns_ratio: Write/Edit/Bash turns / total turns
#
# Origin: T-830 GO decision — build measurement infrastructure for
#         session quality A/B experiment.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
export FRAMEWORK_ROOT
source "$FRAMEWORK_ROOT/lib/paths.sh"

OUTPUT_FILE="$CONTEXT_DIR/working/.session-metrics.yaml"

# Reuse find_transcript from checkpoint.sh
find_transcript() {
    local project_dir_name
    project_dir_name="${PROJECT_ROOT:-$FRAMEWORK_ROOT}"
    project_dir_name="${project_dir_name//\//-}"
    local project_jsonl_dir="$HOME/.claude/projects/${project_dir_name}"
    if [ -d "$project_jsonl_dir" ]; then
        local transcript
        transcript=$(find "$project_jsonl_dir" -maxdepth 1 -name "*.jsonl" -type f ! -name "agent-*" -print0 2>/dev/null | xargs -r -0 ls -t 2>/dev/null | head -1)
        if [ -n "$transcript" ]; then
            echo "$transcript"
        fi
    fi
}

# Determine transcript path
TRANSCRIPT="${1:-}"
if [ -z "$TRANSCRIPT" ]; then
    TRANSCRIPT=$(find_transcript 2>/dev/null) || true
fi

if [ -z "$TRANSCRIPT" ] || [ ! -f "$TRANSCRIPT" ]; then
    echo "# No JSONL transcript found — session metrics unavailable" > "$OUTPUT_FILE"
    echo "session_metrics: unavailable" >> "$OUTPUT_FILE"
    echo "Session metrics: no transcript found"
    exit 0
fi

# Per-session delta tracking (T-850): read previous turn offset
OFFSET_FILE="$CONTEXT_DIR/working/.session-turn-offset"
TURN_OFFSET=0
if [ -f "$OFFSET_FILE" ]; then
    TURN_OFFSET=$(cat "$OFFSET_FILE" 2>/dev/null | head -1 | tr -dc '0-9')
    TURN_OFFSET=${TURN_OFFSET:-0}
fi

# Single-pass Python analyzer
python3 - "$TRANSCRIPT" "$OUTPUT_FILE" "$TURN_OFFSET" "$OFFSET_FILE" << 'PYEOF'
import sys, json, os
from collections import Counter

transcript_path = sys.argv[1]
output_path = sys.argv[2]
turn_offset = int(sys.argv[3]) if len(sys.argv) > 3 else 0
offset_file = sys.argv[4] if len(sys.argv) > 4 else None

turns = 0
tool_calls = 0
tool_errors = 0
commits = 0
first_commit_turn = None
edits_per_file = Counter()
productive_turns = 0
research_turns = 0
recent_edits = []  # (turn, filepath) for burst detection

# Per-session delta counters (T-850)
s_tool_calls = 0
s_tool_errors = 0
s_commits = 0
s_first_commit_turn = None
s_productive_turns = 0
s_research_turns = 0
s_edits = []
s_bursts = 0

# Exclusion list for edit burst detection (files that are legitimately edited many times)
BURST_EXCLUDE = {'.context/', '.tasks/', 'CLAUDE.md', '.fabric/', '.claude/'}

with open(transcript_path) as f:
    for line in f:
        try:
            entry = json.loads(line)
        except (json.JSONDecodeError, ValueError):
            continue

        msg = entry.get('message', {})
        if not isinstance(msg, dict):
            continue

        content = msg.get('content', [])
        if not isinstance(content, list):
            continue

        role = msg.get('role', '')
        if role == 'assistant':
            turns += 1

        turn_productive = False
        turn_research = False

        for block in content:
            if not isinstance(block, dict):
                continue
            btype = block.get('type', '')

            if btype == 'tool_use':
                tool_calls += 1
                if turns > turn_offset:
                    s_tool_calls += 1
                name = block.get('name', '')
                inp = block.get('input', {})

                if name in ('Write', 'Edit'):
                    turn_productive = True
                    fp = inp.get('file_path', '')
                    edits_per_file[fp] += 1
                    # Track for burst detection (only source files)
                    if fp and not any(fp.startswith(ex) or ex in fp for ex in BURST_EXCLUDE):
                        recent_edits.append((turns, fp))
                        if turns > turn_offset:
                            s_edits.append((turns, fp))
                elif name == 'Bash':
                    cmd = inp.get('command', '')
                    if 'git commit' in cmd:
                        commits += 1
                        if first_commit_turn is None:
                            first_commit_turn = turns
                        if turns > turn_offset:
                            s_commits += 1
                            if s_first_commit_turn is None:
                                s_first_commit_turn = turns - turn_offset
                    elif not cmd.startswith(('git ', 'fw ', 'bin/fw')):
                        turn_productive = True
                elif name in ('Read', 'Grep', 'Glob', 'Agent'):
                    turn_research = True

            elif btype == 'tool_result' and block.get('is_error'):
                tool_errors += 1
                if turns > turn_offset:
                    s_tool_errors += 1

        if turn_productive:
            productive_turns += 1
        elif turn_research:
            research_turns += 1

        # Per-session delta tracking (T-850): only count turns after offset
        in_session = turns > turn_offset
        if in_session:
            if turn_productive:
                s_productive_turns += 1
            elif turn_research:
                s_research_turns += 1

# Edit burst detection: same file edited within 10-turn window
bursts = 0
for i, (turn_i, fp_i) in enumerate(recent_edits):
    for j in range(max(0, i - 20), i):
        turn_j, fp_j = recent_edits[j]
        if fp_j == fp_i and turn_i - turn_j <= 10 and turn_i != turn_j:
            bursts += 1
            break

# Per-session edit bursts (T-850)
for i, (turn_i, fp_i) in enumerate(s_edits):
    for j in range(max(0, i - 20), i):
        turn_j, fp_j = s_edits[j]
        if fp_j == fp_i and turn_i - turn_j <= 10 and turn_i != turn_j:
            s_bursts += 1
            break

# Compute cumulative metrics
cpt = round(commits / turns, 4) if turns > 0 else 0
ftc_rate = round(tool_errors / tool_calls, 4) if tool_calls > 0 else 0
ptr = round(productive_turns / turns, 4) if turns > 0 else 0

# Compute per-session delta metrics (T-850)
s_turns = max(0, turns - turn_offset)
s_cpt = round(s_commits / s_turns, 4) if s_turns > 0 else 0
s_ftc_rate = round(s_tool_errors / s_tool_calls, 4) if s_tool_calls > 0 else 0
s_ptr = round(s_productive_turns / s_turns, 4) if s_turns > 0 else 0

# Write YAML output
with open(output_path, 'w') as f:
    f.write("# Session quality metrics (T-831, T-850)\n")
    f.write(f"# Extracted from: {os.path.basename(transcript_path)}\n")
    f.write(f"# Turn offset: {turn_offset} (session starts at turn {turn_offset})\n")
    f.write(f"\n# Cumulative (entire transcript)\n")
    f.write(f"turns: {turns}\n")
    f.write(f"tool_calls: {tool_calls}\n")
    f.write(f"commits: {commits}\n")
    f.write(f"commits_per_turn: {cpt}\n")
    f.write(f"first_commit_turn: {first_commit_turn if first_commit_turn else 0}\n")
    f.write(f"failed_tool_calls: {tool_errors}\n")
    f.write(f"failed_tool_call_rate: {ftc_rate}\n")
    f.write(f"edit_bursts: {bursts}\n")
    f.write(f"productive_turns: {productive_turns}\n")
    f.write(f"research_turns: {research_turns}\n")
    f.write(f"productive_turns_ratio: {ptr}\n")
    f.write(f"edit_retry_files: {sum(1 for c in edits_per_file.values() if c >= 3)}\n")
    f.write(f"\n# Per-session (since turn {turn_offset})\n")
    f.write(f"session_turns: {s_turns}\n")
    f.write(f"session_commits: {s_commits}\n")
    f.write(f"session_commits_per_turn: {s_cpt}\n")
    f.write(f"session_first_commit_turn: {s_first_commit_turn if s_first_commit_turn else 0}\n")
    f.write(f"session_failed_tool_calls: {s_tool_errors}\n")
    f.write(f"session_failed_tool_call_rate: {s_ftc_rate}\n")
    f.write(f"session_edit_bursts: {s_bursts}\n")
    f.write(f"session_productive_turns: {s_productive_turns}\n")
    f.write(f"session_research_turns: {s_research_turns}\n")
    f.write(f"session_productive_turns_ratio: {s_ptr}\n")

# Update turn offset for next session (T-850)
if offset_file:
    with open(offset_file, 'w') as f:
        f.write(str(turns))

print(f"Session metrics extracted: {turns} turns, {commits} commits, {tool_errors} errors, {bursts} edit bursts")
print(f"  Cumulative — CPT: {cpt} | FTC rate: {ftc_rate} | PTR: {ptr}")
print(f"  Per-session ({s_turns} turns) — CPT: {s_cpt} | FTC rate: {s_ftc_rate} | PTR: {s_ptr}")
print(f"  Output: {output_path}")
PYEOF
