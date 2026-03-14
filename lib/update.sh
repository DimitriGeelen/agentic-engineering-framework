#!/bin/bash
# fw update - Update the framework installation to latest version
#
# Updates the framework installation directory (e.g., ~/.agentic-framework)
# by fetching and resetting to the latest upstream version. This updates
# the framework itself, not consumer projects (use fw upgrade for that).

do_update() {
    local check_only=false
    local target_branch="${BRANCH:-master}"

    while [[ $# -gt 0 ]]; do
        case $1 in
            --check) check_only=true; shift ;;
            --branch) target_branch="$2"; shift 2 ;;
            --rollback)
                _do_rollback
                return $?
                ;;
            -h|--help)
                echo -e "${BOLD}fw update${NC} - Update framework installation to latest version"
                echo ""
                echo "Usage: fw update [options]"
                echo ""
                echo "Options:"
                echo "  --check         Check for updates without applying"
                echo "  --branch NAME   Branch to update from (default: master)"
                echo "  --rollback      Restore previous version"
                echo "  -h, --help      Show this help"
                echo ""
                echo "What it does:"
                echo "  1. Fetches latest from upstream"
                echo "  2. Records current version for rollback"
                echo "  3. Resets framework install to latest"
                echo "  4. Shows changelog (commits since last version)"
                echo "  5. Runs fw doctor to verify health"
                echo ""
                echo "Note: This updates the framework itself."
                echo "      To sync improvements to a project, use: fw upgrade"
                return 0
                ;;
            -*)
                echo -e "${RED}Unknown option: $1${NC}" >&2
                return 1
                ;;
            *)
                echo -e "${RED}Unexpected argument: $1${NC}" >&2
                return 1
                ;;
        esac
    done

    # Must be a git repo
    if [ ! -d "$FRAMEWORK_ROOT/.git" ]; then
        echo -e "${RED}ERROR: Framework root is not a git repository: $FRAMEWORK_ROOT${NC}" >&2
        return 1
    fi

    local old_version="$FW_VERSION"
    local old_hash
    old_hash=$(git -C "$FRAMEWORK_ROOT" rev-parse --short HEAD 2>/dev/null || echo "unknown")

    echo -e "${BOLD}fw update${NC} - Checking framework installation"
    echo ""
    echo "  Framework: $FRAMEWORK_ROOT"
    echo "  Current:   v${old_version} (${old_hash})"
    echo "  Branch:    $target_branch"
    echo ""

    # Fetch latest
    echo -e "${YELLOW}Fetching latest...${NC}"
    if ! git -C "$FRAMEWORK_ROOT" fetch origin "$target_branch" --quiet 2>/dev/null; then
        echo -e "${RED}ERROR: Failed to fetch from origin. Check network and remote config.${NC}" >&2
        return 1
    fi

    # Compare
    local remote_hash
    remote_hash=$(git -C "$FRAMEWORK_ROOT" rev-parse --short "origin/$target_branch" 2>/dev/null || echo "unknown")

    if [ "$old_hash" = "$remote_hash" ]; then
        echo -e "${GREEN}Already up to date${NC} (v${old_version}, ${old_hash})"
        return 0
    fi

    # Count commits behind
    local commits_behind
    commits_behind=$(git -C "$FRAMEWORK_ROOT" rev-list --count HEAD.."origin/$target_branch" 2>/dev/null || echo "?")

    echo "  Available: ${remote_hash} (${commits_behind} commit(s) ahead)"
    echo ""

    if [ "$check_only" = true ]; then
        echo -e "${CYAN}Update available:${NC} ${old_hash} → ${remote_hash} (${commits_behind} commits)"
        echo ""
        echo "Changelog:"
        git -C "$FRAMEWORK_ROOT" log --oneline HEAD.."origin/$target_branch" | head -20
        local total
        total=$(git -C "$FRAMEWORK_ROOT" rev-list --count HEAD.."origin/$target_branch" 2>/dev/null || echo 0)
        if [ "$total" -gt 20 ]; then
            echo "  ... and $((total - 20)) more"
        fi
        echo ""
        echo "Run 'fw update' to apply."
        return 0
    fi

    # Record rollback point
    echo -e "${YELLOW}Recording rollback point...${NC}"
    git -C "$FRAMEWORK_ROOT" config --local fw.previousVersion "$old_hash"
    git -C "$FRAMEWORK_ROOT" config --local fw.previousVersionFull "$(git -C "$FRAMEWORK_ROOT" rev-parse HEAD)"

    # Ensure fileMode is off (macOS compat)
    git -C "$FRAMEWORK_ROOT" config core.fileMode false

    # Apply update
    echo -e "${YELLOW}Applying update...${NC}"
    git -C "$FRAMEWORK_ROOT" checkout "$target_branch" --quiet 2>/dev/null || true
    if ! git -C "$FRAMEWORK_ROOT" reset --hard "origin/$target_branch" --quiet; then
        echo -e "${RED}ERROR: Failed to reset to origin/$target_branch${NC}" >&2
        echo "Rollback: fw update --rollback"
        return 1
    fi

    # Read new version
    local new_version="unknown"
    if [ -f "$FRAMEWORK_ROOT/VERSION" ]; then
        new_version=$(cat "$FRAMEWORK_ROOT/VERSION")
    fi
    local new_hash
    new_hash=$(git -C "$FRAMEWORK_ROOT" rev-parse --short HEAD 2>/dev/null || echo "unknown")

    echo ""
    echo -e "${GREEN}Updated:${NC} v${old_version} (${old_hash}) → v${new_version} (${new_hash})"
    echo ""

    # Show changelog
    echo "Changelog:"
    git -C "$FRAMEWORK_ROOT" log --oneline "${old_hash}..HEAD" 2>/dev/null | head -15
    local total_shown
    total_shown=$(git -C "$FRAMEWORK_ROOT" rev-list --count "${old_hash}..HEAD" 2>/dev/null || echo 0)
    if [ "$total_shown" -gt 15 ]; then
        echo "  ... and $((total_shown - 15)) more"
    fi
    echo ""

    # Post-update health check
    echo -e "${YELLOW}Running health check...${NC}"
    echo ""

    if "$FRAMEWORK_ROOT/bin/fw" doctor 2>/dev/null; then
        echo ""
        echo -e "${GREEN}=== Update Complete ===${NC}"
    else
        echo ""
        echo -e "${YELLOW}=== Update Complete (with warnings) ===${NC}"
        echo "Review doctor output above. Rollback: fw update --rollback"
    fi

    echo ""
    echo -e "${BOLD}Next steps:${NC}"
    echo "  - Sync projects: fw upgrade /path/to/project --dry-run"
    echo "  - Rollback:      fw update --rollback"
}

_do_rollback() {
    if [ ! -d "$FRAMEWORK_ROOT/.git" ]; then
        echo -e "${RED}ERROR: Framework root is not a git repository${NC}" >&2
        return 1
    fi

    local prev_hash
    prev_hash=$(git -C "$FRAMEWORK_ROOT" config --get fw.previousVersion 2>/dev/null || true)

    if [ -z "$prev_hash" ]; then
        echo -e "${RED}ERROR: No rollback point recorded. Cannot rollback.${NC}" >&2
        echo "A rollback point is created each time you run 'fw update'."
        return 1
    fi

    local current_hash
    current_hash=$(git -C "$FRAMEWORK_ROOT" rev-parse --short HEAD 2>/dev/null || echo "unknown")

    echo -e "${BOLD}fw update --rollback${NC}"
    echo ""
    echo "  Current:  ${current_hash}"
    echo "  Rollback: ${prev_hash}"
    echo ""

    local prev_full
    prev_full=$(git -C "$FRAMEWORK_ROOT" config --get fw.previousVersionFull 2>/dev/null || echo "$prev_hash")

    if ! git -C "$FRAMEWORK_ROOT" reset --hard "$prev_full" --quiet; then
        echo -e "${RED}ERROR: Rollback failed${NC}" >&2
        return 1
    fi

    # Clear rollback point
    git -C "$FRAMEWORK_ROOT" config --unset fw.previousVersion 2>/dev/null || true
    git -C "$FRAMEWORK_ROOT" config --unset fw.previousVersionFull 2>/dev/null || true

    local new_version="unknown"
    if [ -f "$FRAMEWORK_ROOT/VERSION" ]; then
        new_version=$(cat "$FRAMEWORK_ROOT/VERSION")
    fi

    echo -e "${GREEN}Rolled back to v${new_version} (${prev_hash})${NC}"
    echo ""
    echo "Running health check..."
    "$FRAMEWORK_ROOT/bin/fw" doctor 2>/dev/null || true
}
