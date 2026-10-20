#!/bin/bash
# lib/release-tags.sh — the one place that resolves "the latest release tag" (T-4431)
#
# Bleeding-edge pre-releases are tagged vX.Y.Z-be.N (T-4023) so field projects
# can pin them. They are NOT releases: a -be tag cut on bleeding-edge becomes the
# nearest tag, and a bare `git describe --tags` reads it as the release version
# (1.8.14-be.1 — and 1.8.14-be.1-3-gSHA is not even semver). Every latest-release,
# tag-floor and next-version lookup therefore goes through release_tags_describe,
# which always passes --exclude "$RELEASE_PRERELEASE_TAG_EXCLUDE".
#
# Two callers cannot source this file and inline the same --exclude instead:
# bin/fw _derive_version (runs before FW_LIB_DIR is resolved) and the pre-push
# VERSION stamp in agents/git/lib/hooks.sh. tests/unit/t4431_be_tags.bats pins
# that every `describe --tags` in lib/, bin/fw and agents/ carries the exclude.

RELEASE_PRERELEASE_TAG_EXCLUDE='*-be.*'

# release_tags_describe <root> [git-describe args...]
#   git describe --tags with -be pre-release tags excluded. No error suppression:
#   callers decide what an empty answer means.
release_tags_describe() {
    local root="${1:-${PROJECT_ROOT:-$(pwd)}}"
    shift || true
    git -C "$root" describe --tags --exclude "$RELEASE_PRERELEASE_TAG_EXCLUDE" "$@"
}

# release_tags_latest <root> [pattern]  — newest reachable release tag, or empty.
#   pattern defaults to v[0-9]*; pass "" for any tag (consumer projects whose
#   tags are not v-prefixed).
release_tags_latest() {
    local root="${1:-${PROJECT_ROOT:-$(pwd)}}"
    local pattern="${2-v[0-9]*}"
    if [ -n "$pattern" ]; then
        release_tags_describe "$root" --match "$pattern" --abbrev=0 2>/dev/null || true
    else
        release_tags_describe "$root" --abbrev=0 2>/dev/null || true
    fi
}

# release_be_next_tag <root> <X.Y.Z>  — vX.Y.Z-be.N with N one past the highest
#   existing vX.Y.Z-be.* tag (1 when none).
release_be_next_tag() {
    local root="$1" ver="$2" t n max=0
    while IFS= read -r t; do
        n="${t##*-be.}"
        [[ "$n" =~ ^[0-9]+$ ]] && [ "$n" -gt "$max" ] && max="$n"
    done < <(git -C "$root" tag -l "v${ver}-be.*")
    echo "v${ver}-be.$((max + 1))"
}

# release_be_upgrade_notice <tag>  — how a field project upgrades to a -be tag (T-4500).
#   A shallow clone of the tag cannot see the consumer's recorded version_sha, so
#   fw upgrade refuses it as foreign-source (lib/version-relation.sh, T-3714).
#   Say so before anyone clones. Pinned by tests/unit/t4500_be_notice_non_shallow.bats.
release_be_upgrade_notice() {
    local tag="$1"
    echo "Field projects: upgrade from a NON-SHALLOW clone of $tag (no --depth):"
    echo "  git clone --branch $tag <framework repo URL> <dir> && <dir>/bin/fw upgrade /path/to/project"
    echo "  A shallow clone cannot see the project's recorded version_sha, so fw upgrade refuses it as foreign-source."
    echo "  Already cloned shallow? git -C <dir> fetch --unshallow, then re-run fw upgrade."
    # T-4515 (G-122): v1.8.14-be.3 and v1.8.15-be.1 commented out project lines in git hooks.
    echo "  Check your git hooks: be.3/be.1 commented out your own lines in .git/hooks (G-122); fw doctor names them — uncomment yours."
}

# release_be_tag [--version X.Y.Z] [--dry-run] [--push] — fw release be-tag
#   Creates an ANNOTATED vX.Y.Z-be.N tag on HEAD of the dev branch
#   (FW_DEV_BRANCH, default bleeding-edge). X.Y.Z defaults to the patch after
#   the latest release tag. Refuses on any other branch (master above all: it is
#   the consumer install surface), on a detached HEAD, and when X.Y.Z is not
#   above the latest release. Pushes only with --push (origin, the tag only).
release_be_tag() {
    local root="${PROJECT_ROOT:-$(pwd)}"
    local ver="" dry_run=false push=false
    while [ $# -gt 0 ]; do
        case "$1" in
            --version) ver="${2#v}"; shift ;;
            --dry-run) dry_run=true ;;
            --push)    push=true ;;
            -h|--help)
                echo "Usage: fw release be-tag [--version X.Y.Z] [--dry-run] [--push]"
                echo "Tag HEAD of ${FW_DEV_BRANCH:-bleeding-edge} as vX.Y.Z-be.N (annotated). Refuses on any other branch."
                return 0 ;;
            *) echo "Unknown flag: $1" >&2; return 2 ;;
        esac
        shift
    done

    local dev="${FW_DEV_BRANCH:-bleeding-edge}" branch
    branch="$(git -C "$root" symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
    if [ -z "$branch" ]; then
        echo -e "${RED}ERROR:${NC} detached HEAD — be-tag only tags the tip of $dev" >&2
        return 1
    fi
    if [ "$branch" != "$dev" ]; then
        echo -e "${RED}ERROR:${NC} on '$branch', not '$dev' — bleeding-edge pre-release tags are cut on $dev only" >&2
        [ "$branch" = "${FW_RELEASE_BRANCH:-master}" ] && \
            echo "  $branch is the release train; it receives vX.Y.Z tags from 'fw release tag-and-release' only." >&2
        return 1
    fi

    local latest
    latest="$(release_tags_latest "$root")"
    if [ -z "$ver" ]; then
        if [ -z "$latest" ]; then
            echo -e "${RED}ERROR:${NC} no v* release tag reachable — pass --version X.Y.Z" >&2
            return 1
        fi
        ver="$(release_bump_version "$latest" patch)"
        ver="${ver#v}"
    fi
    if ! [[ "$ver" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo -e "${RED}ERROR:${NC} version '$ver' is not X.Y.Z" >&2
        return 2
    fi
    if [ -n "$latest" ] && ! release_version_lt "${latest#v}" "$ver"; then
        echo -e "${RED}ERROR:${NC} $ver is not above the latest release $latest — a pre-release names the NEXT version" >&2
        return 1
    fi

    local head existing
    head="$(git -C "$root" rev-parse HEAD)"
    existing="$(git -C "$root" tag -l "v${ver}-be.*" --points-at "$head" | head -1)"
    if [ -n "$existing" ]; then
        echo "HEAD is already tagged $existing — nothing to do"
        release_be_upgrade_notice "$existing"
        return 0
    fi

    local tag
    tag="$(release_be_next_tag "$root" "$ver")"
    if [ "$dry_run" = true ]; then
        echo "would tag: $tag at ${head:0:12} on $dev (base release: ${latest:-none})"
        return 0
    fi
    git -C "$root" tag -a "$tag" -m "Bleeding-edge pre-release ${tag#v} (base ${latest:-none}, T-4023)" "$head" || return 1
    echo -e "${GREEN}Tagged${NC} $tag at ${head:0:12} on $dev (base release: ${latest:-none})"
    if [ "$push" = true ]; then
        git -C "$root" push origin "refs/tags/${tag}:refs/tags/${tag}" || return 1
    else
        echo "Push when ready: git -C $root push origin refs/tags/${tag}:refs/tags/${tag}"
    fi
    release_be_upgrade_notice "$tag"
}
