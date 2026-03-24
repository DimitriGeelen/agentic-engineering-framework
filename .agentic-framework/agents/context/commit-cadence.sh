#!/bin/bash
# Commit Cadence Warning — PostToolUse hook for Write/Edit
# Counts source file edits since last commit, warns when count is high.
#
# Thresholds:
#   10 edits → soft warning (consider committing)
#   20 edits → strong warning (commit now, risk of context exhaustion)
#
# Exempt paths (not counted):
#   .context/, .tasks/, .claude/, .agentic-framework/
#
# Counter reset: post-commit git hook resets .edit-counter to 0
#
# Exit code: always 0 (PostToolUse hooks are advisory, cannot block)
# Output: JSON with additionalContext when warning threshold reached
#
# Part of: Agentic Engineering Framework
# Created by: T-591

set -uo pipefail

# Read stdin JSON from Claude Code
INPUT=$(cat)

# Parse tool call, check if it's a source file edit, increment counter, warn
echo "$INPUT" | python3 -c "
import sys, json, os

try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)

tool = data.get('tool_name', '')
if tool not in ('Write', 'Edit'):
    sys.exit(0)

# Extract file path from tool input
tool_input = data.get('tool_input', {})
file_path = tool_input.get('file_path', '')

# Exempt paths — these are framework/governance files, not source edits
exempt_prefixes = ('.context/', '.tasks/', '.claude/', '.agentic-framework/')
for prefix in exempt_prefixes:
    if prefix in file_path:
        sys.exit(0)

# Find counter file
project_root = os.environ.get('PROJECT_ROOT', '')
if not project_root:
    # Walk up from cwd
    d = os.getcwd()
    while d != '/':
        if os.path.isdir(os.path.join(d, '.tasks')):
            project_root = d
            break
        d = os.path.dirname(d)

if not project_root:
    sys.exit(0)

counter_file = os.path.join(project_root, '.context', 'working', '.edit-counter')

# Read current count
try:
    count = int(open(counter_file).read().strip())
except Exception:
    count = 0

# Increment
count += 1

# Write back
try:
    os.makedirs(os.path.dirname(counter_file), exist_ok=True)
    with open(counter_file, 'w') as f:
        f.write(str(count))
except Exception:
    sys.exit(0)

# Warn at thresholds
if count >= 20:
    result = {
        'additionalContext': (
            f'COMMIT CADENCE: {count} source file edits since last commit. '
            'This is well above the safety threshold. Commit your work NOW to '
            'create a checkpoint. If context runs out, all uncommitted work is lost.'
        )
    }
    json.dump(result, sys.stdout)
elif count >= 10:
    result = {
        'additionalContext': (
            f'COMMIT CADENCE: {count} source file edits since last commit. '
            'Consider committing soon to create a checkpoint. '
            'Target: at least one commit every 15-20 minutes of active work.'
        )
    }
    json.dump(result, sys.stdout)
" 2>/dev/null || true

exit 0
