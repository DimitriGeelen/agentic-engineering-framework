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
# release_ff_state <root> <release_branch>
#   Can <release_branch> fast-forward to HEAD? Echoes exactly one of:
#     missing      — no such local branch (consumer repo, fresh clone)
#     uptodate     — already at HEAD; nothing to advance
#     clean        — strict ancestor of HEAD; a fast-forward is available
#     branch-ahead — HEAD is an ancestor of it; releasing would MOVE IT BACK
#     diverged     — neither is an ancestor of the other
#
#   Read-only by construction: no checkout, no ref write, no network.
#
#   G-096: this is the discrimination the release path never made. Under the
#   release train (T-3185) `master` is the consumer install surface, and a
#   release whose whole job is to advance it must be able to say whether that
#   advance is actually possible BEFORE it publishes anything.
# ---------------------------------------------------------------------------
release_ff_state() {
    local root="$1"
    local rb="$2"
    if ! git -C "$root" rev-parse --verify -q "refs/heads/$rb" >/dev/null 2>&1; then
        echo "missing"; return 0
    fi
    local head_sha rb_sha
    head_sha="$(git -C "$root" rev-parse HEAD 2>/dev/null)"
    rb_sha="$(git -C "$root" rev-parse "refs/heads/$rb" 2>/dev/null)"
    if [ -z "$head_sha" ] || [ -z "$rb_sha" ]; then
        echo "missing"; return 0
    fi
    if [ "$head_sha" = "$rb_sha" ]; then
        echo "uptodate"; return 0
    fi
    if git -C "$root" merge-base --is-ancestor "$rb_sha" "$head_sha" 2>/dev/null; then
        echo "clean"; return 0
    fi
    if git -C "$root" merge-base --is-ancestor "$head_sha" "$rb_sha" 2>/dev/null; then
        echo "branch-ahead"; return 0
    fi
    echo "diverged"
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

    # ── Release-train leg (G-096, T-3190) ────────────────────────────────
    # Under T-3185 a release IS the fast-forward of the install surface; the
    # tag merely names it. So the advance is decided FIRST, before a tag
    # exists and long before one is published. A release that cannot move
    # `master` must fail loudly here rather than tag, push, exit 0, and leave
    # the operator with every signal saying it worked.
    local release_branch="${FW_RELEASE_BRANCH:-master}"
    # Declared here, not at the tag-push loop below: the release-branch push
    # runs FIRST and must be able to record its own failure. A `local failed=0`
    # after that point would silently reset it.
    local failed=0
    local ff_state ff_count=0
    ff_state="$(release_ff_state "$root" "$release_branch")"
    if [ "$ff_state" = "clean" ]; then
        ff_count="$(git -C "$root" rev-list --count "refs/heads/${release_branch}..HEAD" 2>/dev/null || echo 0)"
    fi

    case "$ff_state" in
        branch-ahead)
            echo -e "${RED}REFUSING to release:${NC} '$release_branch' is AHEAD of HEAD." >&2
            echo "  Releasing would move the install surface BACKWARD — consumers would" >&2
            echo "  receive an older tree than they already have." >&2
            echo "  No tag was created. Merge or rebase '$release_branch' first, then retry." >&2
            return 1
            ;;
        diverged)
            echo -e "${RED}REFUSING to release:${NC} '$release_branch' has DIVERGED from HEAD." >&2
            echo "  Neither is an ancestor of the other, so no fast-forward exists and a" >&2
            echo "  release cannot advance the install surface without a merge decision" >&2
            echo "  that is not this command's to make." >&2
            echo "  No tag was created. Reconcile the branches first, then retry." >&2
            return 1
            ;;
    esac

    if $dry_run; then
        echo -e "${CYAN}would tag $next${NC} ($commits commits since $latest, bump=$bump)"
        case "$ff_state" in
            clean)    echo -e "${CYAN}would fast-forward $release_branch${NC} by $ff_count commit(s) to $next" ;;
            uptodate) echo "$release_branch is already at HEAD — no fast-forward needed" ;;
            missing)  echo -e "${YELLOW}no local '$release_branch'${NC} — would skip the fast-forward" ;;
        esac
        return 0
    fi

    # Create annotated tag
    echo -e "${CYAN}Creating annotated tag $next...${NC}"
    if ! git -C "$root" tag -a "$next" -m "$next: auto-release ($commits commits since $latest)"; then
        echo -e "${RED}Failed to create tag${NC}" >&2
        return 1
    fi

    # Advance the install surface BEFORE publishing the tag. A tag pushed to a
    # commit that `master` never received is worse than no tag: it advertises a
    # release that consumers cannot obtain. If the advance fails, the local tag
    # is removed so a retry is clean.
    if [ "$ff_state" = "clean" ]; then
        echo -e "${CYAN}Fast-forwarding $release_branch ($ff_count commit(s))...${NC}"
        local rb_before
        rb_before="$(git -C "$root" rev-parse "refs/heads/${release_branch}" 2>/dev/null)"
        if ! git -C "$root" branch -f "$release_branch" HEAD 2>&1; then
            echo -e "${RED}Failed to advance local '$release_branch'${NC} — is it checked out in a worktree?" >&2
            git -C "$root" tag -d "$next" >/dev/null 2>&1
            echo "  Tag $next was removed; nothing was published." >&2
            return 1
        fi
        # The LOCAL fast-forward succeeding does not mean the install surface
        # moved — release_ff_state only inspects the local ref. A remote can
        # still reject the push as non-fast-forward (someone else wrote the
        # branch), so reaching NO remote at all means the release did not
        # happen and the tag must not survive to advertise it.
        local rb_pushed=0 rb_attempted=0
        while IFS= read -r remote; do
            [ -z "$remote" ] && continue
            rb_attempted=$((rb_attempted + 1))
            echo -e "${CYAN}Pushing $release_branch to $remote...${NC}"
            if git -C "$root" push "$remote" "refs/heads/${release_branch}:refs/heads/${release_branch}" 2>&1; then
                echo -e "  ${GREEN}✓ $remote${NC}"
                rb_pushed=$((rb_pushed + 1))
            else
                echo -e "  ${YELLOW}WARN: push of $release_branch to $remote failed${NC}" >&2
                failed=1
            fi
        done < <(git -C "$root" remote 2>/dev/null)
        if [ "$rb_attempted" -gt 0 ] && [ "$rb_pushed" -eq 0 ]; then
            echo -e "${RED}REFUSING to publish:${NC} '$release_branch' reached no remote." >&2
            echo "  The local branch advanced but no consumer can see it, so the tag" >&2
            echo "  would advertise a release nobody can obtain." >&2
            git -C "$root" branch -f "$release_branch" "$rb_before" >/dev/null 2>&1
            git -C "$root" tag -d "$next" >/dev/null 2>&1
            echo "  Rolled back: $release_branch restored, tag $next removed; nothing was published." >&2
            return 1
        fi
    elif [ "$ff_state" = "missing" ]; then
        echo -e "${YELLOW}No local '$release_branch' — skipping the fast-forward${NC}" >&2
    else
        echo -e "${GREEN}$release_branch already at HEAD — no fast-forward needed${NC}"
    fi

    # Push tag to every remote
    # (failed is declared above, with the release-branch push that also sets it)
    #
    # T-3193: this leg is the mirror image of the release-branch guard above,
    # and it used to have none. The branch push refuses when it reaches no
    # remote; the tag push only set `failed` and fell through to `gh release
    # create`, which happily published a GitHub Release naming a tag that no
    # remote has. Consumers then see the install surface at the new commit,
    # nothing naming it, and a release page asserting the release shipped.
    #
    # Retry before giving up (AC2). The observed cause was not a broken remote
    # — it was our own pre-push audit lock, held by the daily cron. That is the
    # COMMON case, not the rare one, and failing a release on first contention
    # turns a two-minute wait into a half-published release.
    local tag_pushed=0 tag_attempted=0
    local remote
    while IFS= read -r remote; do
        [ -z "$remote" ] && continue
        tag_attempted=$((tag_attempted + 1))
        echo -e "${CYAN}Pushing $next to $remote...${NC}"
        local _try _ok=0
        for _try in 1 2 3; do
            if git -C "$root" push "$remote" "$next" 2>&1; then
                _ok=1
                break
            fi
            if [ "$_try" -lt 3 ]; then
                echo -e "  ${YELLOW}retry $_try/3 in ${RELEASE_TAG_RETRY_SLEEP:-20}s${NC} (a held audit lock clears on its own)" >&2
                sleep "${RELEASE_TAG_RETRY_SLEEP:-20}"
            fi
        done
        if [ "$_ok" -eq 1 ]; then
            echo -e "  ${GREEN}✓ $remote${NC}"
            tag_pushed=$((tag_pushed + 1))
        else
            echo -e "  ${YELLOW}WARN: push to $remote failed after 3 attempts${NC}" >&2
            failed=1
        fi
    done < <(git -C "$root" remote 2>/dev/null)

    # T-3193 (AC3): which invariant wins when the branch already advanced?
    #
    # HOLD THE RELEASE OPEN. Do NOT roll the release branch back.
    #
    # By this point `$release_branch` has been pushed and consumers may already
    # have fetched it. Retracting it means a force-push to the install surface
    # — a Tier 0 action, destructive, and one that breaks anyone who pulled in
    # between. The branch-push guard above CAN roll back precisely because it
    # fires when the branch reached NO remote, so there is nothing published to
    # retract. Here there is.
    #
    # So the release stays open: the local tag survives, no GitHub Release is
    # created, the command exits non-zero, and re-running it pushes the tag.
    # The visible state is "master advanced, tag pending" — untidy, honest, and
    # recoverable — rather than "release published, tag missing", which is
    # tidy, false, and the thing this guard exists to prevent.
    if [ "$tag_attempted" -gt 0 ] && [ "$tag_pushed" -eq 0 ]; then
        echo -e "${RED}REFUSING to publish:${NC} tag $next reached no remote." >&2
        echo "  '$release_branch' HAS been pushed and is not being rolled back —" >&2
        echo "  retracting a published install surface is worse than an untagged one." >&2
        echo "  No GitHub Release was created; the local tag $next is kept." >&2
        echo "  Resume with: bin/fw release tag-and-release   (re-pushes the tag)" >&2
        return 1
    fi

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
