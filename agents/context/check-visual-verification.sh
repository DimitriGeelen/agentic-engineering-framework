#!/bin/bash
# Visual Verification Hook — PreToolUse Bash gate
# Blocks `git commit` when staged changes include .css/.html files
# unless the active task body contains a `## Visual Verification` section
# with at least one image-file reference (.png/.jpg/.jpeg).
#
# Rationale: codifies PL-018 / CLAUDE.md "Visual Verification for UI Changes".
# DOM measurements ≠ visual proof. Element-level Playwright screenshots in
# every visual mode the change spans, READ each screenshot, before claiming fixed.
#
# Canonical failure case: T-489 in 025-WokrshopDesigner (fixed in serif, broke
# mono — caught by user on visual inspection because the agent only used DOM rect
# math). Adopted as framework artifact from 025-WokrshopDesigner (T-2128).
#
# Exit codes (Claude Code PreToolUse semantics):
#   0 — Allow tool execution
#   2 — Block tool execution (stderr shown to agent)
#
# Bypass: pass `--no-verify` to git commit. Use only when visual evidence is
# genuinely inapplicable (e.g., reverting a previous commit, .css change is
# build-only).
#
# Enable in a project:
#   fw hook-enable --event PreToolUse --matcher Bash --name check-visual-verification

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$FRAMEWORK_ROOT/lib/paths.sh"
# PROJECT_ROOT is now set by lib/paths.sh

# Read stdin JSON from Claude Code
INPUT=$(cat)

# T-2465 (OBS-080): re-anchor PROJECT_ROOT to the per-call stdin `cwd` so a
# worktree session reads the worktree's focus/tasks, not main's. Shared resolver
# in lib/paths.sh; no-op for non-worktree sessions. FOCUS_FILE is recomputed from
# PROJECT_ROOT further below, after this re-anchor takes effect.
fw_reanchor_from_hook_stdin "$INPUT"

# Extract tool_name and command
TOOL_NAME=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    print(json.load(sys.stdin).get('tool_name', ''))
except Exception:
    print('')
" 2>/dev/null)

COMMAND=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    print(json.load(sys.stdin).get('tool_input', {}).get('command', ''))
except Exception:
    print('')
" 2>/dev/null)

# Only act on Bash tool
[ "$TOOL_NAME" = "Bash" ] || exit 0

# Only act on git commit commands
# T-4921: here-string, not a pipe — under pipefail a pipe into grep -q can read a match as no match (T-4920).
grep -qE '(^|[^a-zA-Z0-9_-])git[[:space:]]+commit([[:space:]]|$)' <<<"$COMMAND" || exit 0

# Bypass: --no-verify present
grep -qE '(--no-verify|[[:space:]]-n([[:space:]]|$))' <<<"$COMMAND" && exit 0

# Get staged files
STAGED=$(git -C "$PROJECT_ROOT" diff --cached --name-only 2>/dev/null)
[ -n "$STAGED" ] || exit 0

# Filter for visual files
VISUAL_FILES=$(echo "$STAGED" | grep -E '\.(css|html)$' || true)

# T-4213: render-surface files (RENDER_SURFACE_PATTERNS, lib/render_surface.sh) need
# the checklist gate too, even when no css/html is staged (e.g. web/blueprints/*.py).
source "$FRAMEWORK_ROOT/lib/render_surface.sh"
RENDER_STAGED=""
while IFS= read -r staged_path; do
    [ -n "$staged_path" ] && _render_surface_path_matches "$staged_path" && RENDER_STAGED="$RENDER_STAGED$staged_path"$'\n'
done <<< "$STAGED"
[ -n "$VISUAL_FILES" ] || [ -n "$RENDER_STAGED" ] || exit 0

# Find active task
FOCUS_FILE="$PROJECT_ROOT/.context/working/focus.yaml"
[ -f "$FOCUS_FILE" ] || exit 0

# Framework focus.yaml uses `current_task:` (see check-active-task.sh). The
# original 025-WokrshopDesigner copy grepped `task_id:`; accept both so the gate
# fires under the framework convention AND legacy consumer focus files (T-2130).
TASK_ID=$(grep -E '^(current_task|task_id):' "$FOCUS_FILE" 2>/dev/null | head -1 | sed -E 's/^(current_task|task_id):[[:space:]]*"?([^"]*)"?$/\2/')
[ -n "$TASK_ID" ] && [ "$TASK_ID" != "null" ] || exit 0

# Locate task file
TASK_FILE=$(find "$PROJECT_ROOT/.tasks/active" "$PROJECT_ROOT/.tasks/completed" -maxdepth 1 -name "${TASK_ID}-*.md" 2>/dev/null | head -1)
[ -f "$TASK_FILE" ] || exit 0

# Checks 1-2 (css/html commits only; a render-only commit goes straight to check 3).
if [ -n "$VISUAL_FILES" ]; then
# Check 1: `## Visual Verification` section present?
if ! grep -qE '^## Visual Verification' "$TASK_FILE"; then
  cat >&2 <<EOF
BLOCKED: Visual evidence required for UI/CSS commits.

Staged visual files (.css/.html):
$(echo "$VISUAL_FILES" | sed 's/^/  /')

Active task: $TASK_ID
Task file:   $TASK_FILE

Missing: a '## Visual Verification' section in the task body.

Why blocked:
  PL-018 (025-WokrshopDesigner T-489): agent fixed CSS with DOM rect math, claimed
  fixed, user caught regression on visual inspection. DOM measurements confirm geometry,
  not rendered output. See CLAUDE.md > "Visual Verification for UI Changes".

To unblock — add a section to $TASK_FILE like:

  ## Visual Verification

  Screenshots (Playwright browser_take_screenshot, element-level, READ via Read tool)
  in every visual mode the change affects:

  - mono mode:  verify-mono.png   — full time visible, clean separation
  - sans mode:  verify-sans.png   — full time visible, no overlap
  - serif mode: verify-serif.png  — full time visible, no overlap

Then re-run the commit.

Genuine exception (build-only css, revert): 'git commit --no-verify' (logged).
EOF
  exit 2
fi

# Check 2: section has image references
SECTION_BODY=$(awk '
  /^## Visual Verification/ { inside=1; next }
  /^## / && inside { exit }
  inside { print }
' "$TASK_FILE")

if ! grep -qE '\.(png|jpg|jpeg)([^a-zA-Z0-9]|$)' <<<"$SECTION_BODY"; then  # T-4921
  cat >&2 <<EOF
BLOCKED: '## Visual Verification' section exists but has no image references.

Active task: $TASK_ID
Task file:   $TASK_FILE

Add screenshot paths (.png/.jpg/.jpeg) under the Visual Verification heading.
Each should be from a Playwright 'browser_take_screenshot' (element-level)
in a specific visual mode (font/theme/density/language/width).

See CLAUDE.md > "Visual Verification for UI Changes".

Genuine exception: 'git commit --no-verify' (logged).
EOF
  exit 2
fi
fi

# Check 3 (T-4213): a render-surface commit needs the checklist, and screenshots at
# every configured width for each listed state. Validator: visual_checklist.py.
if [ -n "$RENDER_STAGED" ]; then
  WIDTHS=$(source "$FRAMEWORK_ROOT/lib/config.sh" && PROJECT_ROOT="$PROJECT_ROOT" fw_config UX_SHOT_WIDTHS 2>/dev/null)
  CHECK_OUT=$(python3 -I "$FRAMEWORK_ROOT/agents/context/visual_checklist.py" \
      --task-file "$TASK_FILE" --root "$PROJECT_ROOT" --task "$TASK_ID" --widths "$WIDTHS" 2>&1)
  CHECK_RC=$?
  if [ "$CHECK_RC" -ne 0 ]; then
    cat >&2 <<EOF
BLOCKED: render-surface commit fails the Visual Verification checklist (T-4213).

Render-surface files staged:
$(echo "$RENDER_STAGED" | sed '/^$/d; s/^/  /')

Active task: $TASK_ID
Task file:   $TASK_FILE

Problems:
$CHECK_OUT

Each listed state needs screenshots at every width in UX_SHOT_WIDTHS (default
1024,1440,1920), taken with \`fw ux shots $TASK_ID <state>=<URL>\`, and a
\`## Visual Verification\` checklist table
  | state | control | 1024 | 1440 | 1920 | note |
where each width cell is ok / clipped / hidden / overlap / unreachable, and any
non-ok cell has a note. Read every shot, control by control, before committing.

Genuine exception: 'git commit --no-verify' (logged).
EOF
    exit 2
  fi
fi

exit 0
