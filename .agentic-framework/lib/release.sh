#!/bin/bash
# lib/release.sh - Release tagging + GitHub Release automation (T-1256)
#
# Cuts a new annotated tag based on the latest v* tag (bumping patch by default),
# pushes to all remotes with --follow-tags, and creates a GitHub Release if gh
# is available. Idempotent: exits cleanly when there are no commits since the
# latest tag.
#
# Designed to be run from cron on a weekly schedule and manually via `fw release`.

# shellcheck disable=SC2034  # colors may be unset when sourced standalone
: "${RED:=\\033[0;31m}"
: "${GREEN:=\\033[0;32m}"
: "${YELLOW:=\\033[1;33m}"
: "${CYAN:=\\033[0;36m}"
: "${NC:=\\033[0m}"

# ---------------------------------------------------------------------------
# release_latest_tag  — echo latest v* tag, or empty
# ---------------------------------------------------------------------------
release_latest_tag() {
    local root="${1:-${PROJECT_ROOT:-$(pwd)}}"
    git -C "$root" describe --tags --match 'v[0-9]*' --abbrev=0 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# release_commits_since <tag>
# ---------------------------------------------------------------------------
release_commits_since() {
    local tag="$1"
    local root="${2:-${PROJECT_ROOT:-$(pwd)}}"
    git -C "$root" rev-list "${tag}..HEAD" --count 2>/dev/null || echo 0
}

# ---------------------------------------------------------------------------
# release_bump_version <tag> <bump>
#   Input:  v1.5.742  patch  -> v1.5.743
#           v1.5.742  minor  -> v1.6.0
#           v1.5.742  major  -> v2.0.0
# ---------------------------------------------------------------------------
release_bump_version() {
    local tag="$1"
    local bump="${2:-patch}"
    local stripped="${tag#v}"
    local major minor patch rest
    major="${stripped%%.*}"
    rest="${stripped#*.}"
    minor="${rest%%.*}"
    patch="${rest#*.}"
    # Handle v1.5 without patch — treat patch as 0
    if [ "$patch" = "$rest" ]; then
        patch=0
    fi
    # Strip any pre-release suffix (e.g. 742-rc1 -> 742)
    patch="${patch%%-*}"

    case "$bump" in
        major) major=$((major + 1)); minor=0; patch=0 ;;
        minor) minor=$((minor + 1)); patch=0 ;;
        patch|*) patch=$((patch + 1)) ;;
    esac
    echo "v${major}.${minor}.${patch}"
}

# ---------------------------------------------------------------------------
# release_tag_and_release  — main entrypoint
#   Flags: --dry-run, --bump {patch|minor|major}, --repo <owner/name>
# ---------------------------------------------------------------------------
release_tag_and_release() {
    local dry_run=false
    local bump=patch
    local gh_repo=""
    local root="${PROJECT_ROOT:-$(pwd)}"

    while [ $# -gt 0 ]; do
        case "$1" in
            --dry-run) dry_run=true ;;
            --bump)    bump="$2"; shift ;;
            --repo)    gh_repo="$2"; shift ;;
            *) echo "Unknown flag: $1" >&2; return 2 ;;
        esac
        shift
    done

    local latest
    latest="$(release_latest_tag "$root")"
    if [ -z "$latest" ]; then
        echo -e "${RED}ERROR:${NC} no v* tags found — bootstrap with a manual tag first" >&2
        return 1
    fi

    local commits
    commits="$(release_commits_since "$latest" "$root")"
    if [ "$commits" = "0" ]; then
        echo -e "${GREEN}No commits since $latest — nothing to release (idempotent no-op)${NC}"
        echo "would skip: $latest"
        return 0
    fi

    local next
    next="$(release_bump_version "$latest" "$bump")"

    if $dry_run; then
        echo -e "${CYAN}would tag $next${NC} ($commits commits since $latest, bump=$bump)"
        return 0
    fi

    # Create annotated tag
    echo -e "${CYAN}Creating annotated tag $next...${NC}"
    if ! git -C "$root" tag -a "$next" -m "$next: auto-release ($commits commits since $latest)"; then
        echo -e "${RED}Failed to create tag${NC}" >&2
        return 1
    fi

    # Push tag to every remote
    local failed=0
    local remote
    while IFS= read -r remote; do
        [ -z "$remote" ] && continue
        echo -e "${CYAN}Pushing $next to $remote...${NC}"
        if git -C "$root" push "$remote" "$next" 2>&1; then
            echo -e "  ${GREEN}✓ $remote${NC}"
        else
            echo -e "  ${YELLOW}WARN: push to $remote failed${NC}" >&2
            failed=1
        fi
    done < <(git -C "$root" remote 2>/dev/null)

    # Create GitHub Release (best-effort)
    if command -v gh >/dev/null 2>&1; then
        echo -e "${CYAN}Creating GitHub Release $next...${NC}"
        local gh_flags=(--generate-notes --latest)
        if [ -n "$gh_repo" ]; then
            gh_flags+=(--repo "$gh_repo")
        fi
        if gh release create "$next" "${gh_flags[@]}" 2>&1; then
            echo -e "  ${GREEN}✓ GitHub Release created${NC}"
        else
            echo -e "  ${YELLOW}WARN: gh release create failed (non-fatal)${NC}" >&2
        fi
    else
        echo -e "${YELLOW}gh CLI not found — skipping GitHub Release${NC}"
    fi

    return $failed
}

# ---------------------------------------------------------------------------
# release_status  — show current release state
# ---------------------------------------------------------------------------
release_status() {
    local root="${PROJECT_ROOT:-$(pwd)}"
    local latest
    latest="$(release_latest_tag "$root")"
    local commits=0
    [ -n "$latest" ] && commits="$(release_commits_since "$latest" "$root")"
    echo "Latest tag:       ${latest:-<none>}"
    echo "Commits since:    $commits"
    if [ -n "$latest" ]; then
        echo "Would bump to:    $(release_bump_version "$latest" patch) (patch)"
    fi
    echo "Remotes:"
    git -C "$root" remote -v | awk '{print "  " $1 " " $2}' | sort -u
}

# ---------------------------------------------------------------------------
# release_main  — entrypoint for `fw release`
# ---------------------------------------------------------------------------
release_main() {
    local subcmd="${1:-tag-and-release}"
    shift || true

    case "$subcmd" in
        tag-and-release|""|--dry-run|--bump|--repo)
            # If first arg was actually a flag, it belongs to tag-and-release
            if [[ "$subcmd" == --* ]]; then
                set -- "$subcmd" "$@"
            fi
            release_tag_and_release "$@"
            ;;
        status)
            release_status
            ;;
        -h|--help|help)
            cat <<'EOF'
Usage: fw release [subcommand] [flags]

Subcommands:
  tag-and-release   Cut new tag, push, create GitHub Release (default)
  status            Show current tag and remote state

Flags (for tag-and-release):
  --dry-run         Show what would happen, change nothing
  --bump LEVEL      patch (default) | minor | major
  --repo OWNER/NAME Override gh release target repo
EOF
            ;;
        *)
            echo "Unknown release subcommand: $subcmd" >&2
            echo "Run: fw release --help" >&2
            return 2
            ;;
    esac
}

# Execute if called directly
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    release_main "$@"
fi
