#!/bin/bash
# Fabric Registration Reminder — PostToolUse hook for Write tool
# When a NEW source file is created matching watch-patterns.yaml globs,
# emits an advisory reminder to register it in the Component Fabric.
#
# Exit code: always 0 (advisory only, never blocks)
# Output: JSON with additionalContext when reminder needed
#
# Part of: Agentic Engineering Framework (T-371)

set -uo pipefail

INPUT=$(cat)

echo "$INPUT" | python3 -c "
import sys, json, os, fnmatch, yaml

try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)

tool_name = data.get('tool_name', '')
if tool_name != 'Write':
    sys.exit(0)

# Get the file path from tool input
tool_input = data.get('tool_input', {})
if isinstance(tool_input, str):
    try:
        tool_input = json.loads(tool_input)
    except Exception:
        sys.exit(0)

file_path = tool_input.get('file_path', '')
if not file_path:
    sys.exit(0)

PROJECT_ROOT = os.environ.get('PROJECT_ROOT', os.getcwd())

# Make relative
try:
    rel_path = os.path.relpath(file_path, PROJECT_ROOT)
except ValueError:
    sys.exit(0)

# Skip context/task/fabric/handover files (framework internals)
skip_prefixes = ('.context/', '.tasks/', '.fabric/', '.claude/', 'docs/generated/')
if any(rel_path.startswith(p) for p in skip_prefixes):
    sys.exit(0)

# Check if fabric card already exists
comp_dir = os.path.join(PROJECT_ROOT, '.fabric', 'components')
if os.path.isdir(comp_dir):
    import glob as globmod
    for card_file in globmod.glob(os.path.join(comp_dir, '*.yaml')):
        try:
            with open(card_file) as f:
                card = yaml.safe_load(f)
            if card and card.get('location') == rel_path:
                sys.exit(0)  # Already registered
        except Exception:
            pass

# Check if file matches watch patterns
watch_file = os.path.join(PROJECT_ROOT, '.fabric', 'watch-patterns.yaml')
if not os.path.isfile(watch_file):
    sys.exit(0)

try:
    with open(watch_file) as f:
        wp = yaml.safe_load(f)
except Exception:
    sys.exit(0)

patterns = wp.get('patterns', []) if wp else []
matches = False
for p in patterns:
    g = p.get('glob', '') if isinstance(p, dict) else str(p)
    if g and fnmatch.fnmatch(rel_path, g):
        matches = True
        break

if not matches:
    sys.exit(0)

# Emit advisory reminder
advice = f'NOTE: New source file created: {rel_path}\nConsider: fw fabric register {rel_path}'
result = {
    'hookSpecificOutput': {
        'hookEventName': 'PostToolUse',
        'additionalContext': advice
    }
}
print(json.dumps(result))
" 2>/dev/null || true
