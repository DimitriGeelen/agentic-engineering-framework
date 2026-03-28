#!/bin/bash
# fw update - Update the framework (vendored or global)
#
# Vendored projects (.agentic-framework/): clones upstream into temp dir,
# re-vendors from there. Uses upstream_repo from .framework.yaml.
#
# Global installs (~/.agentic-framework with .git): fetches and resets
# to latest upstream (legacy path, pre-T-499).

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
                echo -e "${BOLD}fw update${NC} - Update framework to latest version"
                echo ""
                echo "Usage: fw update [options]"
                echo ""
                echo "Options:"
                echo "  --check         Check for updates without applying"
                echo "  --branch NAME   Branch to update from (default: master)"
                echo "  --rollback      Restore previous version"
                echo "  -h, --help      Show this help"
                echo ""
                echo "Vendored projects (.agentic-framework/):"
                echo "  1. Clones upstream repo into temp directory"
                echo "  2. Compares versions and shows changelog"
                echo "  3. Re-vendors from upstream (overwrites .agentic-framework/)"
                echo "  4. Saves rollback backup"
                echo ""
                echo "Global installs (git-based):"
                echo "  1. Fetches latest from upstream"
                echo "  2. Resets to latest (git reset --hard)"
                echo "  3. Shows changelog"
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

    # Detect mode: vendored vs git-based
    local project_root="${PROJECT_ROOT:-$PWD}"
    local vendored_dir="$project_root/.agentic-framework"

    if [ -d "$vendored_dir" ] && [ -f "$vendored_dir/VERSION" ]; then
        _do_update_vendored "$project_root" "$vendored_dir" "$check_only" "$target_branch"
    elif [ -d "$FRAMEWORK_ROOT/.git" ]; then
        _do_update_git "$check_only" "$target_branch"
    else
        echo -e "${RED}ERROR: No vendored framework (.agentic-framework/) and no git-based install${NC}" >&2
        echo "Run 'fw init' to set up a project, or install the framework globally."
        return 1
    fi
}

# ── Vendored update (T-499) ──────────────────────────────────────────

_do_update_vendored() {
    local project_root="$1"
    local vendored_dir="$2"
    local check_only="$3"
    local target_branch="$4"

    local old_version
    old_version=$(cat "$vendored_dir/VERSION" 2>/dev/null || echo "unknown")

    # Get upstream URL from .framework.yaml
    local upstream_url=""
    if [ -f "$project_root/.framework.yaml" ]; then
        upstream_url=$(grep "^upstream_repo:" "$project_root/.framework.yaml" 2>/dev/null | sed 's/^upstream_repo:[[:space:]]*//' || true)
    fi

    if [ -z "$upstream_url" ]; then
        echo -e "${RED}ERROR: No upstream_repo in .framework.yaml${NC}" >&2
        echo ""
        echo "Add to .framework.yaml:"
        echo "  upstream_repo: https://github.com/USER/REPO.git"
        echo ""
        echo "Or if using a local repo:"
        echo "  upstream_repo: /path/to/framework-repo"
        return 1
    fi

    # Normalize upstream URL (handle GitHub shorthand like "user/repo")
    local clone_url="$upstream_url"
    if [[ "$upstream_url" != /* ]] && [[ "$upstream_url" != *://* ]] && [[ "$upstream_url" =~ ^[a-zA-Z0-9_-]+/[a-zA-Z0-9_-]+$ ]]; then
        clone_url="https://github.com/${upstream_url}.git"
    fi

    echo -e "${BOLD}fw update${NC} - Checking vendored framework"
    echo ""
    echo "  Project:   $project_root"
    echo "  Vendored:  $vendored_dir"
    echo "  Current:   v${old_version}"
    echo "  Upstream:  $clone_url"
    echo "  Branch:    $target_branch"
    echo ""

    # Clone upstream into temp dir
    local tmpdir
    tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/fw-update-XXXXXX")

    # Cleanup on exit
    trap "rm -rf '$tmpdir'" EXIT

    echo -e "${YELLOW}Fetching upstream...${NC}"
    if ! git clone --depth 1 --branch "$target_branch" --quiet "$clone_url" "$tmpdir/upstream" 2>/dev/null; then
        echo -e "${RED}ERROR: Failed to clone upstream: $clone_url (branch: $target_branch)${NC}" >&2
        echo ""
        echo "Check:"
        echo "  - upstream_repo in .framework.yaml is correct"
        echo "  - Network connectivity"
        echo "  - Branch '$target_branch' exists"
        return 1
    fi

    # Read upstream version
    local new_version="unknown"
    if [ -f "$tmpdir/upstream/VERSION" ]; then
        new_version=$(cat "$tmpdir/upstream/VERSION")
    fi
    local new_hash
    new_hash=$(git -C "$tmpdir/upstream" rev-parse --short HEAD 2>/dev/null || echo "unknown")

    # Compare versions
    if [ "$old_version" = "$new_version" ]; then
        echo -e "${GREEN}Already up to date${NC} (v${old_version})"
        echo ""
        echo "Upstream hash: $new_hash"
        rm -rf "$tmpdir"
        trap - EXIT
        return 0
    fi

    # Show what's available
    echo ""
    echo -e "  Current:   v${old_version}"
    echo -e "  Available: v${new_version} (${new_hash})"
    echo ""

    # Show changelog
    echo "Changelog (latest commits):"
    git -C "$tmpdir/upstream" log --oneline -15 2>/dev/null
    echo ""

    if [ "$check_only" = true ]; then
        echo -e "${CYAN}Update available:${NC} v${old_version} → v${new_version}"
        echo ""
        echo "Run 'fw update' to apply."
        rm -rf "$tmpdir"
        trap - EXIT
        return 0
    fi

    # Save rollback backup
    local rollback_dir="$project_root/.agentic-framework.rollback"
    echo -e "${YELLOW}Saving rollback backup...${NC}"
    rm -rf "$rollback_dir"
    cp -r "$vendored_dir" "$rollback_dir"
    echo -e "  ${GREEN}✓${NC} Backup saved to .agentic-framework.rollback/"

    # Re-vendor from upstream
    echo ""
    echo -e "${YELLOW}Applying update...${NC}"

    # Use the same include list as do_vendor
    local includes=(
        bin
        lib
        agents
        web
        docs
        .tasks/templates
        FRAMEWORK.md
        metrics.sh
    )

    local excludes=(
        __pycache__
        "*.pyc"
        ".DS_Store"
    )

    # Build rsync exclude args
    local rsync_excludes=""
    for item in "${excludes[@]}"; do
        rsync_excludes="$rsync_excludes --exclude=$item"
    done

    # Copy each include from upstream
    for item in "${includes[@]}"; do
        if [ -e "$tmpdir/upstream/$item" ]; then
            local dest_dir
            dest_dir=$(dirname "$vendored_dir/$item")
            mkdir -p "$dest_dir"

            if [ -d "$tmpdir/upstream/$item" ]; then
                if command -v rsync &>/dev/null; then
                    rsync -a --delete $rsync_excludes "$tmpdir/upstream/$item/" "$vendored_dir/$item/"
                else
                    rm -rf "$vendored_dir/$item"
                    cp -r "$tmpdir/upstream/$item" "$vendored_dir/$item"
                    find "$vendored_dir/$item" -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
                    find "$vendored_dir/$item" -name "*.pyc" -delete 2>/dev/null || true
                    find "$vendored_dir/$item" -name ".DS_Store" -delete 2>/dev/null || true
                fi
            else
                cp "$tmpdir/upstream/$item" "$vendored_dir/$item"
            fi
            echo -e "  ${GREEN}✓${NC} $item"
        else
            echo -e "  ${YELLOW}⊘${NC} $item (not in upstream)"
        fi
    done

    # Update VERSION file
    echo "$new_version" > "$vendored_dir/VERSION"
    echo -e "  ${GREEN}✓${NC} VERSION ($new_version)"

    # Ensure bin/fw is executable
    chmod +x "$vendored_dir/bin/fw" 2>/dev/null || true

    # Update version in .framework.yaml
    if [ -f "$project_root/.framework.yaml" ]; then
        if grep -q "^version:" "$project_root/.framework.yaml" 2>/dev/null; then
            _sed_i "s/^version:.*/version: $new_version/" "$project_root/.framework.yaml"
        fi
    fi

    # Cleanup
    rm -rf "$tmpdir"
    trap - EXIT

    echo ""
    echo -e "${GREEN}Updated:${NC} v${old_version} → v${new_version}"
    echo ""
    echo -e "${BOLD}Next steps:${NC}"
    echo "  - Review changes: git diff .agentic-framework/"
    echo "  - Commit: fw git commit -m 'T-012: fw update — framework v${new_version}'"
    echo "  - Rollback: fw update --rollback"
}

# ── Git-based update (legacy, pre-T-499) ─────────────────────────────

_do_update_git() {
    local check_only="$1"
    local target_branch="$2"

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
    echo "  - Rollback: fw update --rollback"
}

# ── Rollback ─────────────────────────────────────────────────────────

_do_rollback() {
    local project_root="${PROJECT_ROOT:-$PWD}"
    local vendored_dir="$project_root/.agentic-framework"
    local rollback_dir="$project_root/.agentic-framework.rollback"

    # Vendored rollback
    if [ -d "$rollback_dir" ]; then
        local current_version
        current_version=$(cat "$vendored_dir/VERSION" 2>/dev/null || echo "unknown")
        local rollback_version
        rollback_version=$(cat "$rollback_dir/VERSION" 2>/dev/null || echo "unknown")

        echo -e "${BOLD}fw update --rollback${NC} (vendored)"
        echo ""
        echo "  Current:  v${current_version}"
        echo "  Rollback: v${rollback_version}"
        echo ""

        # Swap directories
        rm -rf "$vendored_dir"
        mv "$rollback_dir" "$vendored_dir"

        # Update .framework.yaml version
        if [ -f "$project_root/.framework.yaml" ] && grep -q "^version:" "$project_root/.framework.yaml" 2>/dev/null; then
            _sed_i "s/^version:.*/version: $rollback_version/" "$project_root/.framework.yaml"
        fi

        echo -e "${GREEN}Rolled back to v${rollback_version}${NC}"
        echo ""
        echo "The rollback backup has been consumed. Run 'fw update' again to re-fetch upstream."
        return 0
    fi

    # Git-based rollback (legacy)
    if [ -d "$FRAMEWORK_ROOT/.git" ]; then
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
        return 0
    fi

    echo -e "${RED}ERROR: No rollback available${NC}" >&2
    echo "No .agentic-framework.rollback/ directory and no git-based rollback point found."
    return 1
}
