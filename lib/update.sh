#!/bin/bash
# fw update - Update the framework (vendored projects only)
#
# Vendored projects (.agentic-framework/): clones upstream into temp dir,
# re-vendors from there. Uses upstream_repo from .framework.yaml.
#
# T-2854/D-377: the git-based global-install path (_do_update_git) was
# dropped. It was only reachable via a global install (~/.agentic-framework
# as a git clone), and T-2800 eliminated the producer of those — install.sh
# now clones to a tempdir and deletes it. There is no global install left to
# update in place.

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

    # T-2853: order matters here, and it used to be wrong.
    #
    # A global install lives at ~/.agentic-framework — the SAME layout as a
    # consumer's vendored copy: a directory of that name beside a project root,
    # containing a VERSION. So the vendored test below matched the global install
    # too, and the git-based branch was unreachable for it. `fw update` then
    # demanded `upstream_repo` from ~/.framework.yaml, a key install.sh never
    # writes — because it obtains the framework by `git clone`, and the clone's
    # own `origin` is already the answer. Operator hit this on a default host and
    # ran it three times against an error that could not be acted on.
    #
    # The discriminator was available in both conditions all along: a git-based
    # install carries `.git`; a vendored copy is a file copy and does not
    # (verified — this repo's own .agentic-framework/ has VERSION and no .git).
    #
    # The test is on `$vendored_dir/.git` SPECIFICALLY, not on
    # `$FRAMEWORK_ROOT/.git`. In the framework repo itself FRAMEWORK_ROOT is the
    # checkout and does have .git — keying on it would have misrouted this
    # repo's own self-update. The question being asked is "is the framework
    # COPY this project uses a clone?", and only the vendored path answers it.
    # (T-2854: the git-based branch this guarded against — _do_update_git — is
    # gone; a `.git`-carrying vendored_dir is now residue, handled below.)
    if [ -d "$vendored_dir" ] && [ -f "$vendored_dir/VERSION" ] && [ ! -d "$vendored_dir/.git" ]; then
        _do_update_vendored "$project_root" "$vendored_dir" "$check_only" "$target_branch"
    else
        # T-2854: reworded — the old text offered "install the framework
        # globally" as a remedy. There is no such thing since T-2800/D-377.
        echo -e "${RED}ERROR: No vendored framework at ${vendored_dir}${NC}" >&2
        echo "Run 'fw init' to set up this project. There is no global install to fall"
        echo "back on by design (T-2800/D-377)."
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
        # T-2853: name the ABSOLUTE path. This message used to say only
        # ".framework.yaml", and the file it means is the one beside the project
        # root — not necessarily anywhere near the operator's cwd. Following it
        # literally (creating .framework.yaml where you are standing) does
        # nothing, which is why it got run three times unchanged.
        echo -e "${RED}ERROR: No upstream_repo in ${project_root}/.framework.yaml${NC}" >&2
        echo ""
        echo "Add to ${project_root}/.framework.yaml:"
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
    # shellcheck disable=SC2064  # tmpdir is set, we want it expanded now
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
    # T-1841: write .fw-not-a-project sentinel — find_project_root must skip
    # the rollback dir so an agent CWD inside it doesn't trap on
    # .tasks/templates/ inherited from the vendored framework.
    cat > "$rollback_dir/.fw-not-a-project" <<'SENTINEL'
This is a rollback copy of a previously vendored Agentic Engineering Framework.
fw's find_project_root skips it so an agent CWD here resolves to the real
consumer project (the parent), not this rollback copy. Restore with
'fw update --rollback'. T-1841.
SENTINEL
    echo -e "  ${GREEN}✓${NC} Backup saved to .agentic-framework.rollback/"

    # Re-vendor from upstream using do_vendor (T-1184/G-037: single includes list)
    # do_vendor (bin/fw:118) maintains the canonical includes/excludes.
    # Eliminates enumeration-divergence — same fix as T-1157 applied to do_upgrade.
    echo ""
    echo -e "${YELLOW}Applying update...${NC}"
    do_vendor --source "$tmpdir/upstream" --target "$project_root" 2>&1 | sed 's/^/  /'

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
