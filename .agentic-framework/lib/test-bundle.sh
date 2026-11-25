#!/bin/bash
# lib/test-bundle.sh: package a commit so the unit suite can run somewhere else.
#
# Builds a git bundle of one commit's tree, the same way every time:
#   - from a commit (git archive), never from the working folder, so a bundle names one
#     code version and carries no half-finished edit;
#   - without three history folders the code under test does not read;
#   - one commit made with git plumbing (write-tree/commit-tree), which runs no hooks, so
#     no hook setting is touched; author, committer and dates come from the source commit,
#     so the same ref always gives the same bundle commit id;
#   - with --max-mb N, refused (exit 1, nothing written) when over N MB. No cap by default:
#     a size limit belongs to whatever receives the bundle, so its caller passes it.
#
# fw_test_bundle [--ref REF] [--out FILE] [--max-mb N]

FW_TEST_BUNDLE_EXCLUDES=(
    ".context/handovers"
    ".context/message-archive"
    ".context/reviews/evidence"
)

fw_test_bundle() {
    local ref="HEAD" out="" max_mb="" root="${PROJECT_ROOT:-$PWD}"
    while [ $# -gt 0 ]; do
        case "$1" in
            --ref) ref="${2-}"; shift $(( $# < 2 ? $# : 2 )) ;;
            --out) out="${2-}"; shift $(( $# < 2 ? $# : 2 )) ;;
            --max-mb) max_mb="${2-}"; [ -n "$max_mb" ] || max_mb="x"; shift $(( $# < 2 ? $# : 2 )) ;;
            -h|--help)
                echo "Usage: fw test bundle [--ref REF] [--out FILE] [--max-mb N]"
                echo "  Build a git bundle of REF's tree (default HEAD) with one commit, without"
                echo "  ${FW_TEST_BUNDLE_EXCLUDES[*]}."
                echo "  Default out: .context/scratch/test-bundles/unit-suite-<sha12>.bundle"
                echo "  --max-mb N  refuse (exit 1, nothing written) when the bundle is over N MB; no cap by default"
                return 0 ;;
            *) echo "fw test bundle: unknown option: $1" >&2; return 2 ;;
        esac
    done
    case "$max_mb" in *[!0-9]*|-*) echo "fw test bundle: --max-mb must be a whole number" >&2; return 2 ;; esac

    local sha
    sha=$(git -C "$root" rev-parse --verify -q "${ref}^{commit}") || {
        echo "fw test bundle: not a commit: $ref" >&2; return 2; }
    [ -n "$out" ] || out="$root/.context/scratch/test-bundles/unit-suite-${sha:0:12}.bundle"
    mkdir -p "$(dirname "$out")"

    local work
    work=$(mktemp -d "${TMPDIR:-/tmp}/fw-test-bundle.XXXXXX") || return 1
    # shellcheck disable=SC2064  # expand $work now: the trap must remove THIS dir
    trap "rm -rf -- '$work'" RETURN

    local -a pathspec=(.)
    local x
    for x in "${FW_TEST_BUNDLE_EXCLUDES[@]}"; do pathspec+=(":(exclude)$x"); done
    mkdir -p "$work/tree"
    git -C "$root" archive --format=tar "$sha" -- "${pathspec[@]}" | tar -xf - -C "$work/tree" || {
        echo "fw test bundle: git archive of $sha failed" >&2; return 1; }

    # One commit, by plumbing: no porcelain, no hooks.
    local an ae ad cn ce cdate tree commit
    an=$(git -C "$root" log -1 --format=%an "$sha"); ae=$(git -C "$root" log -1 --format=%ae "$sha")
    ad=$(git -C "$root" log -1 --format=%ad --date=raw "$sha")
    cn=$(git -C "$root" log -1 --format=%cn "$sha"); ce=$(git -C "$root" log -1 --format=%ce "$sha")
    cdate=$(git -C "$root" log -1 --format=%cd --date=raw "$sha")
    (
        cd "$work/tree" || exit 1
        git init -q -b bleeding-edge . || exit 1
        git add -A -f . || exit 1
        tree=$(git write-tree) || exit 1
        commit=$(printf 'unit-suite bundle of %s\n' "$sha" |
            GIT_AUTHOR_NAME="$an" GIT_AUTHOR_EMAIL="$ae" GIT_AUTHOR_DATE="$ad" \
            GIT_COMMITTER_NAME="$cn" GIT_COMMITTER_EMAIL="$ce" GIT_COMMITTER_DATE="$cdate" \
            git commit-tree "$tree") || exit 1
        git update-ref refs/heads/bleeding-edge "$commit" || exit 1
        # HEAD must be in the bundle too: without it `git clone <bundle>` finds no HEAD and
        # checks nothing out (measured on the first build).
        git bundle create -q "$work/out.bundle" HEAD bleeding-edge || exit 1
        echo "$commit" > "$work/commit"
    ) || { echo "fw test bundle: building the one-commit repository failed" >&2; return 1; }

    local bytes
    bytes=$(stat -c %s "$work/out.bundle" 2>/dev/null || wc -c < "$work/out.bundle")
    if [ -n "$max_mb" ] && [ "$bytes" -gt $(( max_mb * 1048576 )) ]; then
        echo "fw test bundle: REFUSED — $(( bytes / 1048576 )) MB is over the ${max_mb} MB cap; nothing written" >&2
        return 1
    fi
    mv -f "$work/out.bundle" "$out" || return 1
    printf 'source_ref:     %s (%s)\n' "$sha" "$ref"
    printf 'bundle_commit:  %s\n' "$(cat "$work/commit")"
    # T-5411: format the fraction inside awk (always a decimal point). Bash's printf %.1f
    # reads its argument in LC_NUMERIC; under a comma-decimal locale (de_DE, inherited by
    # cron) "50.2069" was an invalid number and a scheduled caller's bundle build failed.
    printf 'size_bytes:     %s (%s MB, %s)\n' "$bytes" "$(awk -v b="$bytes" 'BEGIN{printf "%.1f", b/1048576}')" \
        "$([ -n "$max_mb" ] && echo "cap $max_mb MB" || echo "no cap")"
    printf 'sha256:         %s\n' "$(sha256sum "$out" | cut -c1-64)"
    printf 'file:           %s\n' "$out"
}
