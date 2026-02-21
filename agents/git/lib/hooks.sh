#!/bin/bash
# Git Agent - Hook installation subcommand

do_install_hooks() {
    local force=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --force|-f)
                force=true
                shift
                ;;
            -h|--help)
                show_hooks_help
                exit 0
                ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}"
                exit 1
                ;;
        esac
    done

    check_git_repo

    local hooks_dir="$PROJECT_ROOT/.git/hooks"
    local commit_msg_hook="$hooks_dir/commit-msg"
    local post_commit_hook="$hooks_dir/post-commit"
    local pre_push_hook="$hooks_dir/pre-push"

    # Check if hooks exist
    if [ -f "$commit_msg_hook" ] && [ "$force" = false ]; then
        local existing_version
        existing_version=$(grep "^# VERSION=" "$commit_msg_hook" 2>/dev/null | cut -d= -f2)
        if [ "$existing_version" = "$VERSION" ]; then
            echo -e "${GREEN}Hooks already installed (version $VERSION)${NC}"
            echo "Use --force to reinstall"
            exit 0
        else
            echo -e "${YELLOW}Updating hooks from version $existing_version to $VERSION${NC}"
        fi
    fi

    # Create commit-msg hook
    cat > "$commit_msg_hook" << 'HOOK_EOF'
#!/bin/bash
# commit-msg hook - Task Reference Enforcement
# Installed by: ./agents/git/git.sh install-hooks
# Part of: Agentic Engineering Framework
# VERSION=1.5

COMMIT_MSG_FILE="$1"
COMMIT_MSG=$(cat "$COMMIT_MSG_FILE")

# Allow merge commits (no task ref required)
if git rev-parse -q --verify MERGE_HEAD >/dev/null 2>&1; then
    exit 0
fi

# Allow rebase commits
if [ -d ".git/rebase-merge" ] || [ -d ".git/rebase-apply" ]; then
    exit 0
fi

# Check for task reference
if ! echo "$COMMIT_MSG" | grep -qE "T-[0-9]+"; then
    echo ""
    echo "ERROR: No task reference found in commit message"
    echo ""
    echo "Your message: $COMMIT_MSG"
    echo ""
    echo "To fix:"
    echo "  1. Add task reference: git commit -m \"T-XXX: your message\""
    echo "  2. Create a task: ./agents/task-create/create-task.sh"
    echo "  3. Emergency bypass (human only): fw tier0 approve && git commit --no-verify"
    echo ""
    echo "Note: --no-verify is Tier 0 protected. Bypasses are logged."
    exit 1
fi

# Extract task reference and project root
TASK_REF=$(echo "$COMMIT_MSG" | grep -oE "T-[0-9]+" | head -1)
PROJECT_ROOT="$(git rev-parse --show-toplevel)"

# --- Inception Gate (T-126) ---
# Block commits on inception tasks after exploration threshold unless decision recorded
if [ -n "$TASK_REF" ]; then
    TASK_FILE=$(find "$PROJECT_ROOT/.tasks/active" -name "${TASK_REF}-*.md" -type f 2>/dev/null | head -1)
    if [ -n "$TASK_FILE" ] && grep -q "^workflow_type: inception" "$TASK_FILE"; then
        # Check if a decision has been recorded by fw inception decide
        HAS_DECISION=false
        if grep -q '^\*\*Decision\*\*: \(GO\|NO-GO\|DEFER\)' "$TASK_FILE" 2>/dev/null; then
            HAS_DECISION=true
        fi

        if [ "$HAS_DECISION" = false ]; then
            # Count existing commits for this inception task
            INCEPTION_COMMITS=$(git log --oneline --grep="$TASK_REF" 2>/dev/null | wc -l | tr -d ' ')

            if [ "$INCEPTION_COMMITS" -ge 2 ]; then
                echo ""
                echo "BLOCKED: Inception gate — $TASK_REF has no go/no-go decision"
                echo ""
                echo "This inception task has $INCEPTION_COMMITS commits but no decision."
                echo "Inception tasks allow 2 exploration commits, then require a decision."
                echo ""
                echo "Record a decision:"
                echo "  fw inception decide $TASK_REF go --rationale 'reason'"
                echo "  fw inception decide $TASK_REF no-go --rationale 'reason'"
                echo ""
                echo "Emergency bypass (human only): fw tier0 approve && git commit --no-verify"
                exit 1
            else
                echo ""
                echo "NOTE: Inception task $TASK_REF — no decision yet (commit $((INCEPTION_COMMITS + 1))/2 before gate)"
                echo "  After exploration: fw inception decide $TASK_REF go|no-go --rationale '...'"
                echo ""
            fi
        fi
    fi
fi

# --- Research Artifact Enforcement (C-001, G-009, T-226) ---
# Block inception commits after the first if no docs/reports/T-XXX artifact exists.
# First commit is allowed (task creation). Subsequent commits must have the artifact
# either on disk already or in the staged changes.
if [ -n "$TASK_REF" ] && [ -n "$TASK_FILE" ] && grep -q "^workflow_type: inception" "$TASK_FILE" 2>/dev/null; then
    INCEPTION_COMMITS=$(git log --oneline --grep="$TASK_REF" 2>/dev/null | wc -l | tr -d ' ')
    if [ "$INCEPTION_COMMITS" -gt 0 ]; then
        # Check if docs/reports/ changes are in this commit
        HAS_STAGED_RESEARCH=$(git diff --cached --name-only | grep -c "^docs/reports/" || true)
        # Check if docs/reports/T-XXX-* already exists on disk
        HAS_EXISTING_ARTIFACT=false
        if ls "$PROJECT_ROOT/docs/reports/${TASK_REF}-"* >/dev/null 2>&1; then
            HAS_EXISTING_ARTIFACT=true
        fi

        if [ "$HAS_STAGED_RESEARCH" -eq 0 ] && [ "$HAS_EXISTING_ARTIFACT" = false ]; then
            echo ""
            echo "BLOCKED: inception commit for $TASK_REF — no research artifact (C-001/G-009)"
            echo ""
            echo "Inception tasks require a research artifact in docs/reports/"
            echo "Create the artifact BEFORE conducting research:"
            echo "  docs/reports/${TASK_REF}-<topic>.md"
            echo ""
            echo "The thinking trail IS the artifact — conversations are ephemeral, files are permanent."
            echo ""
            echo "Emergency bypass: git commit --no-verify"
            exit 1
        fi
    fi
fi

# Check if referenced task is closed (Tier 1 warning — does not block)
if [ -n "$TASK_REF" ] && ls "$PROJECT_ROOT/.tasks/completed/${TASK_REF}-"* >/dev/null 2>&1; then
    echo ""
    echo "WARNING: Task $TASK_REF is closed (in .tasks/completed/)"
    echo "  Consider: create a new task, or reopen this one."
    echo "  Commit allowed (Tier 1 warning)."
    echo ""
fi

exit 0
HOOK_EOF

    chmod +x "$commit_msg_hook"

    # Create post-commit hook for bypass detection + context checkpoint
    cat > "$post_commit_hook" << 'HOOK_EOF'
#!/bin/bash
# post-commit hook - Bypass Detection + Context Checkpoint
# Installed by: ./agents/git/git.sh install-hooks
# Part of: Agentic Engineering Framework
# VERSION=1.4

PROJECT_ROOT="$(git rev-parse --show-toplevel)"

# Get the commit message
COMMIT_MSG=$(git log -1 --format=%B HEAD)

# --- Task reference check ---
if ! echo "$COMMIT_MSG" | grep -qE "T-[0-9]+"; then
    echo ""
    echo "WARNING: Commit made without task reference (bypass detected)"
    echo ""
    echo "Please log this bypass:"
    echo "  ./agents/git/git.sh log-bypass --commit $(git rev-parse --short HEAD) --reason \"your reason\""
    echo ""
fi

# --- Context checkpoint: reset tool counter on commit ---
COUNTER_FILE="$PROJECT_ROOT/.context/working/.tool-counter"
if [ -f "$COUNTER_FILE" ]; then
    echo "0" > "$COUNTER_FILE"
fi

# --- Handover staleness check ---
LATEST="$PROJECT_ROOT/.context/handovers/LATEST.md"
if [ -f "$LATEST" ]; then
    TODO_COUNT=$(grep -c '\[TODO' "$LATEST" 2>/dev/null || true)
    if [ "${TODO_COUNT:-0}" -gt 3 ]; then
        HANDOVER_TIME=$(stat -c %Y "$LATEST" 2>/dev/null || stat -f %m "$LATEST" 2>/dev/null || echo 0)
        NOW=$(date +%s)
        ELAPSED=$(( (NOW - HANDOVER_TIME) / 60 ))
        if [ "$ELAPSED" -gt 60 ]; then
            echo ""
            echo "HANDOVER STALE: Last handover has $TODO_COUNT unfilled [TODO] sections (${ELAPSED}min old)"
            echo "  Run: fw handover --commit"
            echo ""
        fi
    fi
fi
HOOK_EOF

    chmod +x "$post_commit_hook"

    # Create pre-push hook for audit enforcement
    cat > "$pre_push_hook" << 'HOOK_EOF'
#!/bin/bash
# pre-push hook - Audit Enforcement
# Installed by: ./agents/git/git.sh install-hooks
# Part of: Agentic Engineering Framework
# VERSION=1.0

# Find project root (where .git is)
PROJECT_ROOT="$(git rev-parse --show-toplevel)"

# Resolve audit script: check .framework.yaml first, then local agents/
AUDIT_SCRIPT=""
if [ -f "$PROJECT_ROOT/.framework.yaml" ]; then
    FW_PATH=$(grep "^framework_path:" "$PROJECT_ROOT/.framework.yaml" 2>/dev/null | sed 's/framework_path:[[:space:]]*//')
    if [ -n "$FW_PATH" ] && [ -f "$FW_PATH/agents/audit/audit.sh" ]; then
        AUDIT_SCRIPT="$FW_PATH/agents/audit/audit.sh"
    fi
fi
if [ -z "$AUDIT_SCRIPT" ] && [ -f "$PROJECT_ROOT/agents/audit/audit.sh" ]; then
    AUDIT_SCRIPT="$PROJECT_ROOT/agents/audit/audit.sh"
fi

# Skip if audit script not found anywhere
if [ -z "$AUDIT_SCRIPT" ]; then
    echo "ERROR: Audit script not found"
    echo "  Checked: .framework.yaml -> framework_path"
    echo "  Checked: $PROJECT_ROOT/agents/audit/audit.sh"
    echo "  Push blocked — fix framework path or install audit agent"
    exit 1
fi

echo ""
echo "=== Pre-Push Audit Check ==="
echo ""

# Run audit
"$AUDIT_SCRIPT"
audit_exit=$?

if [ $audit_exit -eq 2 ]; then
    echo ""
    echo "ERROR: Push blocked - audit has FAILURES"
    echo ""
    echo "Fix the issues above before pushing."
    echo "Emergency bypass (human only): fw tier0 approve && git push --no-verify"
    echo ""
    exit 1
elif [ $audit_exit -eq 1 ]; then
    echo ""
    echo "WARNING: Audit has warnings (push allowed)"
    echo "Consider addressing the issues above."
    echo ""
fi

exit 0
HOOK_EOF

    chmod +x "$pre_push_hook"

    echo -e "${GREEN}=== Hooks Installed ===${NC}"
    echo ""
    echo "Installed:"
    echo "  - $commit_msg_hook (task reference validation)"
    echo "  - $post_commit_hook (bypass detection)"
    echo "  - $pre_push_hook (audit before push)"
    echo ""
    echo "Hook behavior:"
    echo "  - Blocks commits without task references (T-XXX)"
    echo "  - Allows merge commits and rebases"
    echo "  - Runs audit before push (blocks on FAIL, warns on WARN)"
    echo "  - Bypass: fw tier0 approve && git commit/push --no-verify (Tier 0 protected)"
}

show_hooks_help() {
    cat << EOF
Git Agent - Install Hooks Command

Usage: git.sh install-hooks [options]

Options:
  -f, --force   Force reinstall even if same version
  -h, --help    Show this help

Installs:
  - commit-msg hook: Validates task reference in commit message
  - post-commit hook: Detects bypasses and reminds to log them
  - pre-push hook: Runs audit before push (blocks on FAIL)

The hooks enforce task traceability (P-002: Structural Enforcement).

Pre-push behavior:
  - Audit FAIL (exit 2): Push blocked
  - Audit WARN (exit 1): Push allowed with warning
  - Audit PASS (exit 0): Push allowed
  - Bypass: fw tier0 approve && git push --no-verify (Tier 0 protected)
EOF
}
