#!/bin/bash
# Self-Audit — Standalone Framework Integrity Check
# Verifies Layers 1-4 of the Agentic Engineering Framework
# without depending on fw CLI (solves chicken-and-egg problem).
#
# Usage:
#   agents/audit/self-audit.sh                 # Run from framework root
#   agents/audit/self-audit.sh /path/to/project # Audit a specific project
#   agents/audit/self-audit.sh --quiet          # Machine-readable (no color)
#
# Exit codes: 0=pass, 1=warnings, 2=failures

set -uo pipefail

# --- Path Resolution (no fw dependency) ---
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$FRAMEWORK_ROOT/lib/paths.sh"

# Allow auditing a different project
if [ -n "${1:-}" ] && [ "$1" != "--quiet" ]; then
    PROJECT_ROOT="$1"
    shift
else
fi

QUIET=false
if [ "${1:-}" = "--quiet" ]; then
    QUIET=true
fi

# Colors provided by lib/colors.sh (via paths.sh chain)
# Override to no-color in quiet mode
if [ "$QUIET" = true ]; then
    RED="" GREEN="" YELLOW="" CYAN="" BOLD="" NC=""
fi

# --- Counters ---
PASS=0
WARN=0
FAIL=0

pass() { echo -e "${GREEN}[PASS]${NC} $1"; PASS=$((PASS + 1)); }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; WARN=$((WARN + 1)); }
fail() { echo -e "${RED}[FAIL]${NC} $1"; FAIL=$((FAIL + 1)); }
info() { echo -e "${CYAN}[INFO]${NC} $1"; }

# ============================================================
# LAYER 1: Foundation (Path Resolution & Core Files)
# ============================================================

echo ""
echo "=== SELF-AUDIT REPORT ==="
echo "Timestamp: $(date -Iseconds 2>/dev/null || date '+%Y-%m-%dT%H:%M:%S')"
echo "Framework: $FRAMEWORK_ROOT"
echo "Project:   $PROJECT_ROOT"
echo ""
echo "=== LAYER 1: FOUNDATION ==="

# 1.1 Framework Root Detection
if [ -x "$FRAMEWORK_ROOT/bin/fw" ]; then
    pass "bin/fw executable"
else
    if [ -f "$FRAMEWORK_ROOT/bin/fw" ]; then
        fail "bin/fw exists but NOT executable"
    else
        fail "bin/fw MISSING"
    fi
fi

if [ -f "$FRAMEWORK_ROOT/FRAMEWORK.md" ]; then
    pass "FRAMEWORK.md exists"
else
    fail "FRAMEWORK.md missing (framework identity file)"
fi

if [ -f "$PROJECT_ROOT/CLAUDE.md" ]; then
    pass "CLAUDE.md exists"
else
    fail "CLAUDE.md MISSING — agent has zero governance instructions"
fi

# 1.2 Agent Directories
agent_pass=0
agent_fail=0
for agent in audit context git handover healing resume task-create fabric; do
    dir="$FRAMEWORK_ROOT/agents/$agent"
    if [ ! -d "$dir" ]; then
        fail "Agent directory missing: $dir"
        agent_fail=$((agent_fail + 1))
    else
        scripts=$(find "$dir" -maxdepth 1 -name "*.sh" -type f 2>/dev/null)
        if [ -z "$scripts" ]; then
            warn "No scripts in agents/$agent/"
        else
            all_exec=true
            for s in $scripts; do
                if [ ! -x "$s" ]; then
                    fail "$(basename "$s") exists but NOT executable in agents/$agent/"
                    all_exec=false
                    agent_fail=$((agent_fail + 1))
                fi
            done
            if [ "$all_exec" = true ]; then
                agent_pass=$((agent_pass + 1))
            fi
        fi
    fi
done
if [ $agent_fail -eq 0 ]; then
    pass "All $agent_pass agent directories OK (scripts executable)"
fi

# 1.3 Library Scripts
lib_missing=0
for script in inception.sh promote.sh assumption.sh bus.sh init.sh upgrade.sh setup.sh harvest.sh; do
    if [ ! -f "$FRAMEWORK_ROOT/lib/$script" ]; then
        fail "lib/$script missing"
        lib_missing=$((lib_missing + 1))
    fi
done
if [ $lib_missing -eq 0 ]; then
    pass "All 8 library scripts present"
fi

# 1.4 Hook Enforcement Scripts (Critical Path)
hook_scripts_missing=0
hook_scripts_ok=0
for script in \
    agents/context/check-active-task.sh \
    agents/context/check-tier0.sh \
    agents/context/budget-gate.sh \
    agents/context/checkpoint.sh \
    agents/context/error-watchdog.sh \
    agents/context/check-dispatch.sh \
    agents/context/pre-compact.sh \
    agents/context/post-compact-resume.sh \
    agents/context/block-plan-mode.sh; do
    full="$FRAMEWORK_ROOT/$script"
    if [ -x "$full" ]; then
        if bash -n "$full" 2>/dev/null; then
            hook_scripts_ok=$((hook_scripts_ok + 1))
        else
            fail "$script has syntax errors"
        fi
    elif [ -f "$full" ]; then
        fail "$script exists but NOT executable"
        hook_scripts_missing=$((hook_scripts_missing + 1))
    else
        fail "$script MISSING — enforcement will silently fail"
        hook_scripts_missing=$((hook_scripts_missing + 1))
    fi
done
if [ $hook_scripts_missing -eq 0 ] && [ $hook_scripts_ok -gt 0 ]; then
    pass "All $hook_scripts_ok hook enforcement scripts OK (executable, syntax valid)"
fi

# ============================================================
# LAYER 2: Directory Structure (State Storage)
# ============================================================

echo ""
echo "=== LAYER 2: DIRECTORY STRUCTURE ==="

# 2.1 Task System
dir_ok=0
for dir in .tasks .tasks/active .tasks/completed .tasks/templates; do
    if [ -d "$PROJECT_ROOT/$dir" ]; then
        dir_ok=$((dir_ok + 1))
    else
        warn "$dir missing"
    fi
done
if [ $dir_ok -eq 4 ]; then
    pass "Task directories complete (4/4)"
else
    warn "Task directories incomplete ($dir_ok/4)"
fi

# Template check
if [ -f "$PROJECT_ROOT/.tasks/templates/default.md" ] || [ -f "$PROJECT_ROOT/.tasks/templates/zzz-default.md" ]; then
    pass "Task template exists"
else
    warn "No task template (default.md)"
fi

# 2.2 Context Fabric
ctx_ok=0
ctx_total=0
for dir in \
    .context \
    .context/working \
    .context/project \
    .context/episodic \
    .context/handovers \
    .context/bus \
    .context/bus/blobs \
    .context/audits \
    .context/audits/cron \
    .context/audits/discoveries; do
    ctx_total=$((ctx_total + 1))
    if [ -d "$PROJECT_ROOT/$dir" ]; then
        ctx_ok=$((ctx_ok + 1))
    else
        warn "$dir missing"
    fi
done
if [ $ctx_ok -eq $ctx_total ]; then
    pass "Context directories complete ($ctx_ok/$ctx_total)"
else
    warn "Context directories incomplete ($ctx_ok/$ctx_total)"
fi

# 2.3 Component Fabric
if [ -d "$PROJECT_ROOT/.fabric" ] && [ -d "$PROJECT_ROOT/.fabric/components" ]; then
    comp_count=$(ls "$PROJECT_ROOT/.fabric/components/"*.yaml 2>/dev/null | wc -l)
    pass "Component fabric: $comp_count components"
elif [ -d "$PROJECT_ROOT/.fabric" ]; then
    warn "Component fabric exists but no components/ directory"
else
    info "Component fabric not initialized (.fabric/)"
fi

# 2.4 Project Memory Files
mem_ok=0
for file in decisions.yaml learnings.yaml patterns.yaml practices.yaml gaps.yaml; do
    if [ -f "$PROJECT_ROOT/.context/project/$file" ]; then
        mem_ok=$((mem_ok + 1))
    fi
done
if [ $mem_ok -eq 5 ]; then
    pass "All 5 project memory files present"
elif [ $mem_ok -gt 0 ]; then
    info "Project memory files: $mem_ok/5 present (others created on first use)"
else
    info "No project memory files yet (created on first use)"
fi

# ============================================================
# LAYER 3: Claude Code Hooks (Runtime Enforcement)
# ============================================================

echo ""
echo "=== LAYER 3: CLAUDE CODE HOOKS ==="

SETTINGS_FILE="$PROJECT_ROOT/.claude/settings.json"

if [ ! -f "$SETTINGS_FILE" ]; then
    fail "settings.json MISSING — NO RUNTIME ENFORCEMENT"
else
    pass "settings.json exists"

    # Validate JSON
    if ! python3 -c "import json; json.load(open('$SETTINGS_FILE'))" 2>/dev/null; then
        fail "settings.json is not valid JSON"
    else
        pass "settings.json valid JSON"

        # Validate hook structure and count results
        hook_output=$(python3 -c "
import json, sys

with open('$SETTINGS_FILE') as f:
    settings = json.load(f)

hooks = settings.get('hooks', {})
if not hooks:
    print('FAIL|No hooks section — zero enforcement')
    sys.exit(0)

# Check PreToolUse
expected_pre = {
    'check-active-task': 'Task gate (Write|Edit)',
    'check-tier0': 'Tier 0 gate (Bash)',
    'budget-gate': 'Budget gate (Write|Edit|Bash)',
    'block-plan-mode': 'Plan mode blocker (EnterPlanMode)',
}

for name, desc in expected_pre.items():
    found = any(
        name in h.get('command', '')
        for group in hooks.get('PreToolUse', [])
        for h in group.get('hooks', [])
    )
    if found:
        print(f'PASS|PreToolUse: {desc}')
    else:
        print(f'FAIL|PreToolUse: {desc} NOT configured')

# Check PostToolUse
expected_post = {
    'checkpoint': 'Context checkpoint (*)',
    'error-watchdog': 'Error watchdog (Bash)',
    'check-dispatch': 'Dispatch checker (Task|TaskOutput)',
}

for name, desc in expected_post.items():
    found = any(
        name in h.get('command', '')
        for group in hooks.get('PostToolUse', [])
        for h in group.get('hooks', [])
    )
    if found:
        print(f'PASS|PostToolUse: {desc}')
    else:
        print(f'FAIL|PostToolUse: {desc} NOT configured')

# Check lifecycle hooks
for event in ['PreCompact', 'SessionStart']:
    if hooks.get(event):
        print(f'PASS|{event} hooks configured')
    else:
        print(f'WARN|{event} not configured — lifecycle recovery disabled')

# Check for flat structure (silent failure)
for event_type in ['PreToolUse', 'PostToolUse']:
    for group in hooks.get(event_type, []):
        if isinstance(group, dict) and 'command' in group and 'hooks' not in group:
            print(f'FAIL|{event_type} has FLAT hook structure — silently ignored!')
" 2>/dev/null)

        # Parse Python output and feed into counters
        while IFS='|' read -r level msg; do
            case "$level" in
                PASS) pass "$msg" ;;
                WARN) warn "$msg" ;;
                FAIL) fail "$msg" ;;
            esac
        done <<< "$hook_output"
    fi
fi

# ============================================================
# LAYER 4: Git Hooks (Commit-Level Enforcement)
# ============================================================

echo ""
echo "=== LAYER 4: GIT HOOKS ==="

HOOKS_DIR="$PROJECT_ROOT/.git/hooks"

if [ ! -d "$PROJECT_ROOT/.git" ]; then
    warn "Not a git repository — skipping git hook checks"
else
    # commit-msg
    if [ -x "$HOOKS_DIR/commit-msg" ]; then
        if grep -q 'T-\[0-9\]\|T-[0-9]' "$HOOKS_DIR/commit-msg" 2>/dev/null; then
            pass "commit-msg hook installed (task reference enforcement)"
        else
            warn "commit-msg hook exists but may not enforce task references"
        fi
    elif [ -f "$HOOKS_DIR/commit-msg" ]; then
        fail "commit-msg exists but NOT executable"
    else
        fail "commit-msg NOT installed — commits won't require task references"
    fi

    # post-commit
    if [ -x "$HOOKS_DIR/post-commit" ]; then
        pass "post-commit hook installed"
    else
        warn "post-commit hook not installed (bypass detection disabled)"
    fi

    # pre-push
    if [ -x "$HOOKS_DIR/pre-push" ]; then
        if grep -q 'audit' "$HOOKS_DIR/pre-push" 2>/dev/null; then
            pass "pre-push hook installed (audit enforcement)"
        else
            warn "pre-push hook exists but may not run audit"
        fi
    elif [ -f "$HOOKS_DIR/pre-push" ]; then
        fail "pre-push exists but NOT executable"
    else
        fail "pre-push NOT installed — pushes won't require audit"
    fi
fi

# ============================================================
# SUMMARY
# ============================================================

echo ""
echo "=== SUMMARY ==="
echo -e "${GREEN}Pass:${NC} $PASS"
echo -e "${YELLOW}Warn:${NC} $WARN"
echo -e "${RED}Fail:${NC} $FAIL"
echo ""

if [ $FAIL -gt 0 ]; then
    echo -e "${RED}Verdict: NON-FUNCTIONAL${NC} — $FAIL failure(s) detected"
    echo "Fix failures before relying on framework governance."
    exit 2
elif [ $WARN -gt 0 ]; then
    echo -e "${YELLOW}Verdict: DEGRADED${NC} — $WARN warning(s)"
    echo "Framework is operational but some controls may be missing."
    exit 1
else
    echo -e "${GREEN}Verdict: OPERATIONAL${NC} — All checks passed"
    exit 0
fi
