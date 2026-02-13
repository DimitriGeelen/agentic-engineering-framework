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
# VERSION=1.0

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
    echo "  3. Emergency bypass: git commit --no-verify"
    echo ""
    echo "Note: Bypasses should be logged with: ./agents/git/git.sh log-bypass"
    exit 1
fi

exit 0
HOOK_EOF

    chmod +x "$commit_msg_hook"

    # Create post-commit hook for bypass detection
    cat > "$post_commit_hook" << 'HOOK_EOF'
#!/bin/bash
# post-commit hook - Bypass Detection
# Installed by: ./agents/git/git.sh install-hooks
# Part of: Agentic Engineering Framework
# VERSION=1.0

# Get the commit message
COMMIT_MSG=$(git log -1 --format=%B HEAD)

# Check if it has a task reference
if ! echo "$COMMIT_MSG" | grep -qE "T-[0-9]+"; then
    echo ""
    echo "WARNING: Commit made without task reference (bypass detected)"
    echo ""
    echo "Please log this bypass:"
    echo "  ./agents/git/git.sh log-bypass --commit $(git rev-parse --short HEAD) --reason \"your reason\""
    echo ""
fi
HOOK_EOF

    chmod +x "$post_commit_hook"

    echo -e "${GREEN}=== Hooks Installed ===${NC}"
    echo ""
    echo "Installed:"
    echo "  - $commit_msg_hook (task reference validation)"
    echo "  - $post_commit_hook (bypass detection)"
    echo ""
    echo "Hook behavior:"
    echo "  - Blocks commits without task references (T-XXX)"
    echo "  - Allows merge commits and rebases"
    echo "  - Bypass with: git commit --no-verify (logs warning)"
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

The hooks enforce task traceability (P-002: Structural Enforcement).
EOF
}
