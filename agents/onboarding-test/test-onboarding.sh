#!/bin/bash
# Test Onboarding — End-to-End Flow Test for New Projects
# Exercises the full onboarding path: init → first task → commit → audit → handover
# Runs 8 checkpoints and reports PASS/WARN/FAIL for each.
#
# Usage:
#   agents/onboarding-test/test-onboarding.sh              # Use temp dir (auto-cleanup)
#   agents/onboarding-test/test-onboarding.sh /path/to/dir  # Use specific dir (no cleanup)
#   agents/onboarding-test/test-onboarding.sh --keep        # Use temp dir, don't cleanup
#   agents/onboarding-test/test-onboarding.sh --quiet       # Machine-readable output
#
# Exit codes: 0=all pass, 1=warnings, 2=failures
#
# From T-307 inception GO → T-317 build task.

set -uo pipefail

# --- Path Resolution (no fw dependency) ---
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# --- Arguments ---
TARGET_DIR=""
KEEP=false
QUIET=false
for arg in "$@"; do
    case "$arg" in
        --keep)  KEEP=true ;;
        --quiet) QUIET=true ;;
        -*)      echo "Unknown flag: $arg"; exit 1 ;;
        *)       TARGET_DIR="$arg" ;;
    esac
done

# --- Target Directory ---
if [ -n "$TARGET_DIR" ]; then
    KEEP=true  # User-specified dir is never auto-cleaned
    mkdir -p "$TARGET_DIR"
else
    TARGET_DIR=$(mktemp -d "/tmp/fw-onboarding-test-XXXXXX")
fi

# --- Cleanup ---
cleanup() {
    if [ "$KEEP" = false ] && [ -d "$TARGET_DIR" ]; then
        rm -rf "$TARGET_DIR"
    fi
}
trap cleanup EXIT

# --- Colors ---
if [ "$QUIET" = true ] || [ ! -t 1 ]; then
    RED="" GREEN="" YELLOW="" CYAN="" NC="" DIM="" BOLD=""
else
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    CYAN='\033[0;36m'
    NC='\033[0m'
    DIM='\033[2m'
    BOLD='\033[1m'
fi

# --- Counters ---
PASS=0
WARN=0
FAIL=0
SKIP=0
CHECKPOINT=0
LAST_CHECKPOINT_OK=true

pass()  { echo -e "${GREEN}[PASS]${NC} $1"; PASS=$((PASS + 1)); }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; WARN=$((WARN + 1)); }
fail()  { echo -e "${RED}[FAIL]${NC} $1"; FAIL=$((FAIL + 1)); LAST_CHECKPOINT_OK=false; }
skip()  { echo -e "${DIM}[SKIP]${NC} $1"; SKIP=$((SKIP + 1)); LAST_CHECKPOINT_OK=false; }
info()  { echo -e "${CYAN}[INFO]${NC} $1"; }
detail() { echo -e "       ${DIM}$1${NC}"; }

checkpoint_start() {
    CHECKPOINT=$((CHECKPOINT + 1))
    LAST_CHECKPOINT_OK=true
    echo ""
    echo -e "${BOLD}=== CHECKPOINT $CHECKPOINT: $1 ===${NC}"
}

# --- Capture command output + exit code ---
# Usage: run_cmd command args...
# Sets: CMD_OUT, CMD_EXIT
CMD_OUT=""
CMD_EXIT=0

run_cmd() {
    CMD_OUT=$("$@" 2>&1)
    CMD_EXIT=$?
    return 0  # Always return 0 so set -e doesn't kill us
}

# ============================================================
# HEADER
# ============================================================

echo ""
echo "=== ONBOARDING TEST ==="
echo "Timestamp:  $(date -Iseconds 2>/dev/null || date '+%Y-%m-%dT%H:%M:%S')"
echo "Framework:  $FRAMEWORK_ROOT"
echo "Target:     $TARGET_DIR"
echo "Keep:       $KEEP"

# ============================================================
# C1: PROJECT SCAFFOLD (fw init)
# ============================================================

checkpoint_start "PROJECT SCAFFOLD"

# Verify framework exists
if [ ! -x "$FRAMEWORK_ROOT/bin/fw" ]; then
    fail "Framework not found at $FRAMEWORK_ROOT"
    echo -e "\n${RED}Cannot continue — framework missing.${NC}"
    exit 2
fi

# Initialize git repo first (fw init doesn't create repos)
run_cmd git init "$TARGET_DIR"
if [ $CMD_EXIT -eq 0 ]; then
    pass "git init completed"
else
    fail "git init failed (exit $CMD_EXIT)"
fi

# Run fw init on target directory
run_cmd "$FRAMEWORK_ROOT/bin/fw" init "$TARGET_DIR" --no-first-run

if [ $CMD_EXIT -eq 0 ]; then
    pass "fw init completed (exit 0)"
else
    fail "fw init failed (exit $CMD_EXIT)"
    detail "Output: $(echo "$CMD_OUT" | tail -3)"
fi

# Check expected directories
scaffold_ok=0
scaffold_total=0
for dir in .tasks .tasks/active .tasks/completed .tasks/templates \
           .context .context/working .context/project .context/episodic \
           .context/handovers .context/audits .claude .git; do
    scaffold_total=$((scaffold_total + 1))
    if [ -d "$TARGET_DIR/$dir" ]; then
        scaffold_ok=$((scaffold_ok + 1))
    else
        fail "Missing directory: $dir"
    fi
done
if [ $scaffold_ok -eq $scaffold_total ]; then
    pass "All $scaffold_total directories created"
fi

# Check key files
for file in CLAUDE.md .tasks/templates/default.md .framework.yaml; do
    if [ -f "$TARGET_DIR/$file" ]; then
        pass "$file created"
    else
        fail "$file missing"
    fi
done

# Check CLAUDE.md placeholder substitution
if [ -f "$TARGET_DIR/CLAUDE.md" ]; then
    if grep -q "__PROJECT_NAME__\|__FRAMEWORK_ROOT__\|__PROJECT_ROOT__" "$TARGET_DIR/CLAUDE.md"; then
        fail "CLAUDE.md has unsubstituted placeholders"
    else
        pass "CLAUDE.md placeholders substituted"
    fi
fi

C1_OK=$LAST_CHECKPOINT_OK

# ============================================================
# C2: HOOK INSTALLATION (settings.json + git hooks)
# ============================================================

checkpoint_start "HOOK INSTALLATION"

if [ "$C1_OK" != true ]; then
    skip "Skipped — C1 scaffold failed"
else
    SETTINGS_FILE="$TARGET_DIR/.claude/settings.json"

    # settings.json exists and valid JSON
    if [ -f "$SETTINGS_FILE" ]; then
        pass "settings.json created"

        if python3 -c "import json; json.load(open('$SETTINGS_FILE'))" 2>/dev/null; then
            pass "settings.json valid JSON"

            # Count hooks
            hook_count=$(python3 -c "
import json
data = json.load(open('$SETTINGS_FILE'))
print(sum(len(v) for v in data.get('hooks', {}).values()))
" 2>/dev/null || echo "0")

            if [ "$hook_count" -ge 10 ]; then
                pass "Hook count: $hook_count (expected >=10)"
            elif [ "$hook_count" -gt 0 ]; then
                warn "Hook count: $hook_count (expected >=10)"
            else
                fail "No hooks configured"
            fi

            # Check for flat structure (silent failure bug)
            flat_hooks=$(python3 -c "
import json
data = json.load(open('$SETTINGS_FILE'))
flat = 0
for event_type in ['PreToolUse', 'PostToolUse']:
    for group in data.get('hooks', {}).get(event_type, []):
        if isinstance(group, dict) and 'command' in group and 'hooks' not in group:
            flat += 1
print(flat)
" 2>/dev/null || echo "0")

            if [ "$flat_hooks" -gt 0 ]; then
                fail "Found $flat_hooks flat hook(s) — these silently fail"
            else
                pass "Hook structure correct (nested, not flat)"
            fi
        else
            fail "settings.json invalid JSON"
        fi
    else
        fail "settings.json NOT created"
    fi

    # Git hooks
    HOOKS_DIR="$TARGET_DIR/.git/hooks"
    for hook in commit-msg post-commit pre-push; do
        if [ -x "$HOOKS_DIR/$hook" ]; then
            pass "Git hook installed: $hook"
        elif [ -f "$HOOKS_DIR/$hook" ]; then
            fail "Git hook $hook exists but not executable"
        else
            fail "Git hook $hook not installed"
        fi
    done
fi

C2_OK=$LAST_CHECKPOINT_OK

# ============================================================
# C3: FIRST TASK (fw work-on creates task + sets focus)
# ============================================================

checkpoint_start "FIRST TASK"

if [ "$C1_OK" != true ]; then
    skip "Skipped — C1 scaffold failed"
else
    # Create first task using fw work-on
    run_cmd env PROJECT_ROOT="$TARGET_DIR" "$FRAMEWORK_ROOT/bin/fw" work-on "Onboarding test task" --type build

    if [ $CMD_EXIT -eq 0 ]; then
        pass "fw work-on completed (exit 0)"
    else
        # fw work-on may exit non-zero but still work
        if echo "$CMD_OUT" | grep -q "T-001\|created\|focus"; then
            warn "fw work-on exited $CMD_EXIT but task appears created"
        else
            fail "fw work-on failed (exit $CMD_EXIT)"
            detail "Output: $(echo "$CMD_OUT" | tail -3)"
        fi
    fi

    # Check task file exists
    task_file=$(ls "$TARGET_DIR/.tasks/active/"T-001*.md 2>/dev/null | head -1)
    if [ -n "$task_file" ]; then
        pass "Task file created: $(basename "$task_file")"

        # Check required frontmatter fields
        missing_fields=""
        for field in id name status workflow_type owner; do
            if ! grep -q "^${field}:" "$task_file"; then
                missing_fields="$missing_fields $field"
            fi
        done
        if [ -z "$missing_fields" ]; then
            pass "Task frontmatter complete"
        else
            warn "Task missing fields:$missing_fields"
        fi
    else
        fail "No task file in .tasks/active/"
    fi

    # Check focus is set
    focus_file="$TARGET_DIR/.context/working/focus.yaml"
    if [ -f "$focus_file" ]; then
        if grep -q "T-001" "$focus_file"; then
            pass "Focus set to T-001"
        else
            focus_content=$(cat "$focus_file" 2>/dev/null | head -3)
            warn "Focus file exists but doesn't reference T-001: $focus_content"
        fi
    else
        fail "Focus not set (focus.yaml missing)"
    fi
fi

C3_OK=$LAST_CHECKPOINT_OK

# ============================================================
# C4: TASK GATE (hooks enforce task requirement)
# ============================================================

checkpoint_start "TASK GATE"

# Note: We can't truly test Claude Code hooks without a Claude session.
# Instead, verify the hook scripts would work if called.

if [ "$C2_OK" != true ] || [ "$C3_OK" != true ]; then
    skip "Skipped — C2 hooks or C3 task creation failed"
else
    # Test check-active-task.sh can find the task
    # Hook scripts read JSON from stdin (Claude Code protocol) — provide mock input
    MOCK_HOOK_INPUT='{"tool_name":"Write","tool_input":{"file_path":"/tmp/test.txt"}}'

    CMD_OUT=$(echo "$MOCK_HOOK_INPUT" | PROJECT_ROOT="$TARGET_DIR" "$FRAMEWORK_ROOT/agents/context/check-active-task.sh" 2>&1)
    CMD_EXIT=$?

    if [ $CMD_EXIT -eq 0 ]; then
        pass "Task gate would ALLOW (active task exists)"
    else
        warn "Task gate returned $CMD_EXIT — may block in live session"
        detail "Output: $(echo "$CMD_OUT" | tail -2)"
    fi

    # Test budget-gate.sh (also reads stdin)
    CMD_OUT=$(echo "$MOCK_HOOK_INPUT" | PROJECT_ROOT="$TARGET_DIR" "$FRAMEWORK_ROOT/agents/context/budget-gate.sh" 2>&1)
    CMD_EXIT=$?

    if [ $CMD_EXIT -eq 0 ]; then
        pass "Budget gate passes (no transcript = fail-open)"
    else
        warn "Budget gate returned $CMD_EXIT"
    fi
fi

C4_OK=$LAST_CHECKPOINT_OK

# ============================================================
# C5: FIRST COMMIT (fw git commit with task reference)
# ============================================================

checkpoint_start "FIRST COMMIT"

if [ "$C3_OK" != true ]; then
    skip "Skipped — C3 task creation failed"
else
    # Create a test file and commit
    echo "# Test file from onboarding test" > "$TARGET_DIR/test-onboarding-artifact.md"

    # Configure git identity if not set (local to target repo)
    git -C "$TARGET_DIR" config user.email 2>/dev/null || git -C "$TARGET_DIR" config user.email "test@onboarding.local"
    git -C "$TARGET_DIR" config user.name 2>/dev/null || git -C "$TARGET_DIR" config user.name "Onboarding Test"

    git -C "$TARGET_DIR" add test-onboarding-artifact.md 2>/dev/null

    run_cmd git -C "$TARGET_DIR" commit -m "T-001: Test commit from onboarding test"

    if [ $CMD_EXIT -eq 0 ]; then
        pass "First commit succeeded"

        # Verify commit-msg hook accepted it
        last_msg=$(git -C "$TARGET_DIR" log -1 --format='%s' 2>/dev/null)
        if echo "$last_msg" | grep -q "T-001"; then
            pass "Commit message has task reference"
        else
            warn "Commit message may have been modified: $last_msg"
        fi
    else
        fail "First commit failed (exit $CMD_EXIT)"
        detail "Output: $(echo "$CMD_OUT" | tail -3)"
    fi
fi

C5_OK=$LAST_CHECKPOINT_OK

# ============================================================
# C6: AUDIT CLEAN (no false positives on day-1 project)
# ============================================================

checkpoint_start "AUDIT (day-1 project)"

if [ "$C1_OK" != true ]; then
    skip "Skipped — C1 scaffold failed"
else
    AUDIT_OUTPUT=$(PROJECT_ROOT="$TARGET_DIR" "$FRAMEWORK_ROOT/agents/audit/audit.sh" 2>&1) || true
    AUDIT_EXIT=$?

    if [ $AUDIT_EXIT -eq 0 ]; then
        pass "fw audit passed on day-1 project"
    elif [ $AUDIT_EXIT -eq 1 ]; then
        # Warnings are acceptable on day-1 — count them
        warn_count=$(echo "$AUDIT_OUTPUT" | grep -c "\[WARN\]" || true)
        fail_count=$(echo "$AUDIT_OUTPUT" | grep -c "\[FAIL\]" || true)
        if [ "$fail_count" -gt 0 ]; then
            fail "fw audit has $fail_count failure(s) on day-1 project (false positives?)"
            detail "Failures: $(echo "$AUDIT_OUTPUT" | grep '\[FAIL\]' | head -3)"
        else
            warn "fw audit has $warn_count warning(s) on day-1 project"
        fi
    else
        fail "fw audit failed (exit $AUDIT_EXIT)"
        detail "Output: $(echo "$AUDIT_OUTPUT" | tail -3)"
    fi
fi

C6_OK=$LAST_CHECKPOINT_OK

# ============================================================
# C7: SELF-AUDIT CLEAN
# ============================================================

checkpoint_start "SELF-AUDIT"

if [ "$C1_OK" != true ]; then
    skip "Skipped — C1 scaffold failed"
else
    SA_OUTPUT=$("$FRAMEWORK_ROOT/agents/audit/self-audit.sh" "$TARGET_DIR" --quiet 2>&1) || true
    SA_EXIT=$?

    if [ $SA_EXIT -eq 0 ]; then
        pass "Self-audit passed"
    elif [ $SA_EXIT -eq 1 ]; then
        warn_count=$(echo "$SA_OUTPUT" | grep -c "\[WARN\]" || true)
        warn "Self-audit has $warn_count warning(s)"
    else
        fail_count=$(echo "$SA_OUTPUT" | grep -c "\[FAIL\]" || true)
        fail "Self-audit has $fail_count failure(s)"
        detail "$(echo "$SA_OUTPUT" | grep '\[FAIL\]' | head -5)"
    fi
fi

C7_OK=$LAST_CHECKPOINT_OK

# ============================================================
# C8: HANDOVER GENERATION
# ============================================================

checkpoint_start "HANDOVER"

if [ "$C3_OK" != true ]; then
    skip "Skipped — C3 task creation failed"
else
    run_cmd env PROJECT_ROOT="$TARGET_DIR" "$FRAMEWORK_ROOT/agents/handover/handover.sh"

    if [ $CMD_EXIT -eq 0 ]; then
        pass "Handover generation succeeded"
    else
        # Handover may produce warnings but still generate the file
        if [ -f "$TARGET_DIR/.context/handovers/LATEST.md" ]; then
            warn "Handover exited $CMD_EXIT but generated file"
        else
            fail "Handover failed (exit $CMD_EXIT, no output file)"
            detail "Output: $(echo "$CMD_OUT" | tail -3)"
        fi
    fi

    # Check handover file quality
    if [ -f "$TARGET_DIR/.context/handovers/LATEST.md" ]; then
        # Has frontmatter
        if head -1 "$TARGET_DIR/.context/handovers/LATEST.md" | grep -q "^---"; then
            pass "Handover has YAML frontmatter"
        else
            warn "Handover missing frontmatter"
        fi

        # References the task
        if grep -q "T-001" "$TARGET_DIR/.context/handovers/LATEST.md"; then
            pass "Handover references T-001"
        else
            warn "Handover doesn't reference the active task"
        fi
    fi
fi

C8_OK=$LAST_CHECKPOINT_OK

# ============================================================
# SUMMARY
# ============================================================

echo ""
echo "=== SUMMARY ==="
echo -e "${GREEN}Pass:${NC} $PASS"
echo -e "${YELLOW}Warn:${NC} $WARN"
echo -e "${RED}Fail:${NC} $FAIL"
if [ $SKIP -gt 0 ]; then
    echo -e "${DIM}Skip:${NC} $SKIP"
fi
echo ""
echo "Target: $TARGET_DIR"
[ "$KEEP" = true ] && echo "  (preserved for inspection)"
echo ""

if [ $FAIL -gt 0 ]; then
    echo -e "${RED}Verdict: ONBOARDING BROKEN${NC} — $FAIL failure(s) in $CHECKPOINT checkpoints"
    exit 2
elif [ $WARN -gt 0 ]; then
    echo -e "${YELLOW}Verdict: ONBOARDING DEGRADED${NC} — $WARN warning(s) in $CHECKPOINT checkpoints"
    exit 1
else
    echo -e "${GREEN}Verdict: ONBOARDING CLEAN${NC} — All $CHECKPOINT checkpoints passed"
    exit 0
fi
