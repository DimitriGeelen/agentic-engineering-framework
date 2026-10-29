#!/bin/bash
# lib/release.sh - Release tagging + GitHub Release automation (T-1256)
#
# Cuts a new annotated tag based on the latest v* tag (bumping patch by default),
# fast-forwards the release branch, pushes branch + tag to every remote in ONE
# atomic push per remote (T-3822), and creates a GitHub Release if gh
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

# T-4431: -be pre-release tags never count as the latest release.
# shellcheck source=release-tags.sh
source "$(dirname "${BASH_SOURCE[0]}")/release-tags.sh"

# ---------------------------------------------------------------------------
# release_latest_tag  — echo latest v* tag, or empty
# ---------------------------------------------------------------------------
release_latest_tag() {
    local root="${1:-${PROJECT_ROOT:-$(pwd)}}"
    local pattern="${2:-v[0-9]*}"
    release_tags_latest "$root" "$pattern"
}

# release_tag_pattern  — the configured release-tag glob (FW_RELEASE_TAG_PATTERN,
# T-3585). Default is this repo's own v* tags.
release_tag_pattern() {
    echo "${FW_RELEASE_TAG_PATTERN:-v[0-9]*}"
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
# release_version_lt <A> <B>  — numeric semver compare; true (0) when A < B
#   Component-wise, NOT lexical: 1.6.72 < 1.6.176 (a lexical/sort compare gets
#   this wrong, and 72-vs-176 is the exact pair the origin incident produced).
#   Pre-release suffixes are stripped; non-numeric input is "not less" (rc 1).
# ---------------------------------------------------------------------------
release_version_lt() {
    local a="${1%%+*}" b="${2%%+*}"   # T-4055: drop +N.gSHA build metadata
    a="${a%%-*}"; b="${b%%-*}"
    case "$a$b" in ''|*[!0-9.]*) return 1 ;; esac
    [ "$a" = "$b" ] && return 1
    local a1 a2 a3 b1 b2 b3
    IFS=. read -r a1 a2 a3 <<< "$a"
    IFS=. read -r b1 b2 b3 <<< "$b"
    a1=${a1:-0}; a2=${a2:-0}; a3=${a3:-0}
    b1=${b1:-0}; b2=${b2:-0}; b3=${b3:-0}
    if [ "$a1" -ne "$b1" ]; then [ "$a1" -lt "$b1" ]; return $?; fi
    if [ "$a2" -ne "$b2" ]; then [ "$a2" -lt "$b2" ]; return $?; fi
    [ "$a3" -lt "$b3" ]
}

# ---------------------------------------------------------------------------
# release_version_tag_parity <root>  — T-3242 doctor predicate
#   Echoes exactly one of:
#     no-git             — root has no .git (vendored consumer copy)
#     no-tags            — no v* tag reachable from HEAD (fresh clone)
#     no-version         — no VERSION file to disagree with anything
#     ok <ver> <tagver>      — VERSION equals the newest reachable tag
#     ahead <ver> <tagver>   — VERSION above the tag (pre-release bump; allowed)
#     behind <ver> <tagver>  — VERSION BELOW the tag: the non-monotonic state
#   The tag is canonical (T-3242 ruling); only `behind` is a failure.
#   Read-only, one `git describe` — cheap enough for every doctor run.
# ---------------------------------------------------------------------------
release_version_tag_parity() {
    local root="${1:-${PROJECT_ROOT:-$(pwd)}}"
    if [ ! -d "$root/.git" ] && [ ! -f "$root/.git" ]; then
        echo "no-git"; return 0
    fi
    local tag
    tag="$(release_latest_tag "$root")"
    if [ -z "$tag" ]; then echo "no-tags"; return 0; fi
    if [ ! -f "$root/VERSION" ]; then echo "no-version"; return 0; fi
    local ver tagver="${tag#v}"
    ver="$(tr -d '[:space:]' < "$root/VERSION")"
    if [ "$ver" = "$tagver" ]; then
        echo "ok $ver $tagver"
    elif release_version_lt "$ver" "$tagver"; then
        echo "behind $ver $tagver"
    else
        echo "ahead $ver $tagver"
    fi
}

# ---------------------------------------------------------------------------
# release_reconcile_version <root> <next_tag>  — T-3242 tag-as-canonical write
#   Writes ${next#v} into VERSION (and the vendored copy when present) and
#   commits ONLY those paths, so the commit the tag lands on carries the
#   version the tag names. Caller has already refused the decreasing case.
# ---------------------------------------------------------------------------
release_reconcile_version() {
    local root="$1" next="$2"
    local want="${next#v}"
    local paths=("VERSION")
    echo "$want" > "$root/VERSION" || return 1
    if [ -f "$root/.agentic-framework/VERSION" ]; then
        echo "$want" > "$root/.agentic-framework/VERSION"
        paths+=(".agentic-framework/VERSION")
    fi
    git -C "$root" add -- "${paths[@]}" || return 1
    # T-3821: already equal to HEAD's committed content is success, not an
    # empty commit. (A hook-stamped working tree used to send the release down
    # here with nothing to commit; `git commit` failed and the release refused.)
    if git -C "$root" diff --cached --quiet HEAD -- "${paths[@]}" 2>/dev/null; then
        return 0
    fi
    # Pathspec commit: other staged/unstaged work in the tree stays out of it.
    git -C "$root" commit -q -m "$next: reconcile VERSION to $want (tag-as-canonical, T-3242)" -- "${paths[@]}"
}

# ---------------------------------------------------------------------------
# release_version_snapshot <root>  /  release_version_restore <root> <snap> <pre_head> <reconciled_sha>
#   T-3820: v1.8.0 attempt 1's rollback restored master and deleted the tag but
#   left the VERSION-reconcile commit on the dev branch; the next ordinary push
#   published "1.8.0" with no release behind it. The reconcile commit cannot
#   move after publish (the tag must point at it, T-3242), so every refusal
#   after it reverts it instead.
#
#   snapshot: echoes a temp dir holding the exact working-tree bytes and index
#   entry of VERSION and .agentic-framework/VERSION, as they were pre-release.
#   restore:  moves HEAD back from <reconciled_sha> to <pre_head> with a
#   compare-and-swap update-ref (refuses if HEAD moved on since), then puts the
#   index entries and bytes back. <reconciled_sha> empty = no commit was made
#   (e.g. the reconcile commit itself failed): only the files are restored.
# ---------------------------------------------------------------------------
release_version_snapshot() {
    local root="$1" snap p key
    snap="$(mktemp -d -t fw-release-version-XXXXXX)" || return 1
    for p in VERSION .agentic-framework/VERSION; do
        key="${p//\//__}"
        if [ -f "$root/$p" ]; then cp -p "$root/$p" "$snap/$key.bytes"; fi
        git -C "$root" ls-files -s -- "$p" > "$snap/$key.index" 2>/dev/null
    done
    echo "$snap"
}

release_version_restore() {
    local root="$1" snap="$2" pre_head="$3" reconciled="$4" p key rc=0
    if [ -n "$reconciled" ]; then
        if git -C "$root" update-ref -m "fw release: revert VERSION reconcile (T-3820)" \
                HEAD "$pre_head" "$reconciled" 2>/dev/null; then
            echo "  Reverted the VERSION reconcile commit ${reconciled:0:9}; HEAD is back at ${pre_head:0:9}." >&2
        else
            echo -e "  ${RED}NOT reverted:${NC} HEAD is no longer the reconcile commit ${reconciled:0:9}," >&2
            echo "  so moving it could discard someone else's work. Revert it by hand:" >&2
            echo "    git revert ${reconciled}" >&2
            rc=1
        fi
    fi
    [ -d "$snap" ] || return $rc
    for p in VERSION .agentic-framework/VERSION; do
        key="${p//\//__}"
        if [ -s "$snap/$key.index" ]; then
            git -C "$root" update-index --index-info < "$snap/$key.index" 2>/dev/null || rc=1
        else
            git -C "$root" rm -q --cached --ignore-unmatch -- "$p" >/dev/null 2>&1
        fi
        if [ -f "$snap/$key.bytes" ]; then
            cp -p "$snap/$key.bytes" "$root/$p" || rc=1
        fi
    done
    rm -rf "$snap"
    return $rc
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
# release_remote_ff_check <root> <release_branch> <offline:true|false>
#   T-3819: release_ff_state grades the LOCAL ref only. v1.8.0 attempt 1 was
#   graded "clean" while origin/master held a commit (eb49ff9) the local ref
#   did not; the release committed VERSION, tagged, and only learned the truth
#   when the push was rejected. This asks every push remote BEFORE anything is
#   written: is your <release_branch> an ancestor of HEAD?
#
#   Returns 0 when every remote can fast-forward (or lacks the branch, which the
#   push will create), 1 when any remote refuses or cannot be reached.
#
#   Decided explicitly, and said in the output:
#     no remotes   -> pass; nothing is published, so there is nothing to grade.
#     unreachable  -> REFUSE, unless --offline. A check that could not run is
#                     not a check that passed (the G-096 false-green shape).
#     --offline    -> pass, with a warning that the remote was NOT inspected.
#
#   Writes no ref: ls-remote, plus a FETCH_HEAD-only fetch when the remote tip
#   is not already in the local object store.
# ---------------------------------------------------------------------------
release_remote_ff_check() {
    local root="$1" rb="$2" offline="${3:-false}"
    local remotes
    remotes="$(git -C "$root" remote 2>/dev/null)"
    if [ -z "$remotes" ]; then
        echo "No remotes configured — remote fast-forward check skipped (nothing is published)."
        return 0
    fi
    if [ "$offline" = true ]; then
        echo -e "${YELLOW}--offline: remote fast-forward check SKIPPED${NC} — '$rb' on the remote(s) was not inspected; the push may still be refused." >&2
        return 0
    fi
    local head_sha remote rsha refused=0
    head_sha="$(git -C "$root" rev-parse HEAD 2>/dev/null)"
    while IFS= read -r remote; do
        [ -z "$remote" ] && continue
        local listing
        if ! listing="$(git -C "$root" ls-remote --heads "$remote" "refs/heads/$rb" 2>/dev/null)"; then
            echo -e "${RED}REFUSING to release:${NC} cannot reach remote '$remote' to check '$rb'." >&2
            echo "  Whether '$remote/$rb' can fast-forward to HEAD is unknown, and an unknown is" >&2
            echo "  not a pass. Fix the remote, or re-run with --offline to release without" >&2
            echo "  the remote check. No tag was created." >&2
            refused=1; continue
        fi
        rsha="$(echo "$listing" | awk -v r="refs/heads/$rb" '$2 == r {print $1; exit}')"
        if [ -z "$rsha" ]; then
            echo "Remote '$remote' has no '$rb' yet — the push will create it."
            continue
        fi
        if ! git -C "$root" cat-file -e "${rsha}^{commit}" 2>/dev/null; then
            if ! git -C "$root" fetch -q --no-tags "$remote" "refs/heads/$rb" 2>/dev/null \
                || ! git -C "$root" cat-file -e "${rsha}^{commit}" 2>/dev/null; then
                echo -e "${RED}REFUSING to release:${NC} could not fetch '$remote/$rb' ($rsha) to grade it." >&2
                echo "  Re-run with --offline to release without the remote check. No tag was created." >&2
                refused=1; continue
            fi
        fi
        if [ "$rsha" = "$head_sha" ] || git -C "$root" merge-base --is-ancestor "$rsha" "$head_sha" 2>/dev/null; then
            echo "Remote '$remote/$rb' is an ancestor of HEAD — fast-forward available."
        else
            echo -e "${RED}REFUSING to release:${NC} '$remote/$rb' has commit(s) HEAD does not contain:" >&2
            git -C "$root" log --oneline -n 10 "${head_sha}..${rsha}" 2>/dev/null | sed 's/^/    /' >&2
            echo "  Pushing '$rb' would be rejected as non-fast-forward — after the release had" >&2
            echo "  already committed VERSION and tagged (v1.8.0 attempt 1, T-3819)." >&2
            echo "  Fix: merge $remote/$rb into your dev branch first:" >&2
            echo "    git fetch $remote $rb && git merge $remote/$rb" >&2
            echo "  No tag was created." >&2
            refused=1
        fi
    done <<< "$remotes"
    return $refused
}

# ---------------------------------------------------------------------------
# release_issue_leg <root> <latest> <next> <repo> <dry_run: true|false>  — T-4340
#   Lifecycle stages 8-9 for the GitHub issues behind this release: `fw issues release`
#   (lib/issues.py, the one outward verb) posts Released for every task in latest..HEAD
#   that carries github_issue:, and applies the close rule. Never fails the release: a
#   GitHub failure is reported and recorded in .context/issues/release-pending.jsonl.
# ---------------------------------------------------------------------------
release_issue_leg() {
    local root="$1" latest="$2" next="$3" repo="$4" dry="$5"
    local here
    here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if ! command -v python3 >/dev/null 2>&1; then
        echo -e "${YELLOW}python3 not found — GitHub issue stages skipped${NC}" >&2
        return 0
    fi
    local envs=("PROJECT_ROOT=$root")
    if [ -n "$repo" ]; then envs+=("FW_ISSUES_REPO=$repo"); fi
    local args=(release "$next" --range "${latest}..HEAD" --root "$root")
    if [ "$dry" = true ]; then args+=(--dry-run); fi
    echo -e "${CYAN}GitHub issues (stages 8-9)...${NC}"
    if ! env "${envs[@]}" python3 "$here/issues.py" "${args[@]}"; then
        echo -e "  ${YELLOW}WARN: issue step did not finish (non-fatal). Retry: bin/fw issues release $next --range ${latest}..HEAD${NC}" >&2
    fi
    return 0
}

# ---------------------------------------------------------------------------
# release_scratch_prune <root> <next> <dry_run: true|false>  — T-4703
#   Retention for release work dirs. Full-suite comparisons and hotfix lanes clone
#   base/hf/tip trees into .context/scratch/v<digits>/ and hf<digits>/ (v1813 =
#   the v1.8.13 lane; docs/reports/T-4246, T-4420), 1-10 GB each, and nothing
#   removed them: 28 GB by 2026-10-23. After a published release this removes the
#   dirs of releases that already shipped: name exactly v<digits> or hf<digits>,
#   a real directory (not a symlink), digits equal to a final vX.Y.Z tag that is
#   OLDER than <next>. The current release's dirs, future lanes, -be-only
#   versions and any other name are kept; fw doctor's size WARN covers those.
#   Never fails the release.
# ---------------------------------------------------------------------------
release_scratch_prune() {
    local root="$1" next="$2" dry="$3"
    local scratch="$root/.context/scratch"
    [ -d "$scratch" ] || return 0
    local shipped="" tag
    while IFS= read -r tag; do
        [[ "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || continue
        release_version_lt "${tag#v}" "${next#v}" || continue
        shipped+=" $(echo "${tag#v}" | tr -d .) "
    done < <(git -C "$root" tag -l 'v*' 2>/dev/null)
    local d name digits
    for d in "$scratch"/*; do
        name="${d##*/}"
        [[ "$name" =~ ^(v|hf)([0-9]+)$ ]] || continue
        digits="${BASH_REMATCH[2]}"
        [ -d "$d" ] && [ ! -L "$d" ] || continue
        case "$shipped" in *" $digits "*) ;; *) continue ;; esac
        if [ "$dry" = true ]; then
            echo -e "${CYAN}would prune release work dir${NC} .context/scratch/$name (release already shipped)"
        elif rm -rf -- "$d"; then
            echo -e "  ${GREEN}✓ pruned .context/scratch/$name${NC} (release already shipped)"
        else
            echo -e "  ${YELLOW}WARN: could not remove .context/scratch/$name (non-fatal)${NC}" >&2
        fi
    done
    return 0
}

# ---------------------------------------------------------------------------
# Release decision record (T-4364) — .context/releases/decisions.jsonl, append-only.
#   Row: {version, decided_by: operator|field-evidence, ref, ts}
#   An unattended run (no TTY on stdin, FW_UNATTENDED=1, or cron) refuses without
#   a row for THAT version. Policy: CLAUDE.md §Release-Train (only verified-working
#   fixes reach master; T-4020, T-4146). Written by `fw release decide`.
# ---------------------------------------------------------------------------
release_decisions_file() { echo "${1:-${PROJECT_ROOT:-$(pwd)}}/.context/releases/decisions.jsonl"; }

# release_decision_for <root> <vX.Y.Z>  — prints the newest matching row, rc 1 when none
release_decision_for() {
    local f; f="$(release_decisions_file "$1")"
    [ -s "$f" ] || return 1
    python3 -I - "$f" "$2" <<'PY'
import json, sys
last = None
for line in open(sys.argv[1]):
    try:
        row = json.loads(line)
    except ValueError:
        continue
    if row.get("version") == sys.argv[2] and row.get("decided_by") in ("operator", "field-evidence") and row.get("ref"):
        last = row
if not last:
    sys.exit(1)
print("%s by %s (%s) at %s" % (last["version"], last["decided_by"], last["ref"], last.get("ts", "?")))
PY
}

release_is_unattended() {
    [ "${FW_UNATTENDED:-0}" = "1" ] && return 0
    [ ! -t 0 ] && return 0
    [ -n "${CRON:-}" ] || [ -n "${FW_CRON:-}" ] && return 0
    return 1
}

# release_decide <vX.Y.Z> --by operator|field-evidence --ref "<task id or operator's words>"
release_decide() {
    local version="${1:-}" by="" ref="" root="${PROJECT_ROOT:-$(pwd)}" human=false
    shift || true
    while [ $# -gt 0 ]; do
        case "$1" in
            --by)         by="$2"; shift ;;
            --ref)        ref="$2"; shift ;;
            --i-am-human) human=true ;;
            *) echo "Unknown flag: $1" >&2; return 2 ;;
        esac
        shift
    done
    if ! [[ "$version" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || [ -z "$by" ] || [ -z "$ref" ]; then
        echo "Usage: fw release decide vX.Y.Z --by operator|field-evidence --ref \"<operator's verbatim words | field-evidence report/task id>\"" >&2
        return 2
    fi
    case "$by" in operator|field-evidence) ;; *) echo "--by must be operator or field-evidence" >&2; return 2 ;; esac
    if [ "${CLAUDECODE:-}" = "1" ] && ! $human; then
        # An agent records what the operator said; it never self-approves.
        if [ "$by" = "operator" ] && [ "${#ref}" -lt 12 ]; then
            echo -e "${RED}REFUSING:${NC} --by operator under agent control needs the operator's verbatim words in --ref (>= 12 chars), not a bare id." >&2
            return 1
        fi
        if [ "$by" = "field-evidence" ] && ! [[ "$ref" =~ (T-[0-9]+|docs/reports/) ]]; then
            echo -e "${RED}REFUSING:${NC} --by field-evidence needs --ref naming the field-evidence report or task (T-XXXX or docs/reports/...)." >&2
            return 1
        fi
    fi
    local f; f="$(release_decisions_file "$root")"
    mkdir -p "$(dirname "$f")"
    python3 -I - "$f" "$version" "$by" "$ref" <<'PY'
import json, sys, datetime
row = {"version": sys.argv[2], "decided_by": sys.argv[3], "ref": sys.argv[4],
       "ts": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")}
with open(sys.argv[1], "a") as fh:
    fh.write(json.dumps(row) + "\n")
PY
    echo -e "${GREEN}Recorded release decision:${NC} $version by $by ($ref)"
}

# ---------------------------------------------------------------------------
# release_tag_and_release  — main entrypoint
#   Flags: --dry-run, --bump {patch|minor|major}, --repo <owner/name>,
#          --offline (skip the remote fast-forward check, T-3819)
# ---------------------------------------------------------------------------
release_tag_and_release() {
    local dry_run=false
    local offline=false
    local bump=patch
    local gh_repo=""
    local root="${PROJECT_ROOT:-$(pwd)}"

    while [ $# -gt 0 ]; do
        case "$1" in
            --dry-run) dry_run=true ;;
            --offline) offline=true ;;
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

    # ── Release-decision leg (T-4364) ─────────────────────────────────────
    # Enforced on the `fw release` entrypoint (release_main sets the flag).
    # --dry-run is never refused; interactive runs only report coverage.
    if [ "${_RELEASE_ENFORCE_DECISION:-0}" = "1" ]; then
        local decision
        if decision="$(release_decision_for "$root" "$next")"; then
            echo "Release decision covering $next: $decision"
        elif $dry_run; then
            echo -e "${YELLOW}No recorded release decision for $next${NC} (an unattended run would refuse)"
        elif release_is_unattended; then
            echo -e "${RED}REFUSING to release $next:${NC} unattended run (no TTY / cron / FW_UNATTENDED) with no recorded release decision." >&2
            echo "  Policy: CLAUDE.md §Release-Train — only verified-working fixes reach master (T-4020, T-4146);" >&2
            echo "  a release needs the operator's yes or positive field-test evidence, and no scheduled release exists." >&2
            echo "  Record one: bin/fw release decide $next --by operator|field-evidence --ref \"<operator's words | T-XXXX>\"" >&2
            echo "  No tag, VERSION or master change was made." >&2
            return 1
        else
            echo -e "${YELLOW}WARN: no recorded release decision for $next${NC} — record one: bin/fw release decide $next --by operator --ref \"...\"" >&2
        fi
    fi

    # ── Release-notes leg (T-4899) ────────────────────────────────────────
    # v1.8.15 went to GitHub with only an auto "Full Changelog" link: the release
    # was created with --generate-notes, which lists merged PRs, and this repo has
    # none. Operator 2026-10-29: human-readable notes are part of the standing
    # release process. A repo that keeps docs/releases/ must have a committed
    # docs/releases/<version>-notes.md before anything is tagged or pushed.
    # Repos without that folder are not affected.
    local notes_rel="docs/releases/${next}-notes.md" notes_ok=""
    if [ -d "$root/docs/releases" ]; then
        local notes_bytes=0
        [ -f "$root/$notes_rel" ] && notes_bytes=$(wc -c < "$root/$notes_rel" | tr -d ' ')
        if [ "$notes_bytes" -lt "${RELEASE_NOTES_MIN_BYTES:-400}" ]; then
            notes_ok="missing"
        elif ! git -C "$root" ls-files --error-unmatch "$notes_rel" >/dev/null 2>&1 \
             || ! git -C "$root" diff --quiet HEAD -- "$notes_rel" 2>/dev/null; then
            notes_ok="uncommitted"
        else
            notes_ok="yes"
            echo "Release notes: $notes_rel"
        fi
        if [ "$notes_ok" != "yes" ]; then
            if $dry_run; then
                echo -e "${YELLOW}Release notes $notes_rel: $notes_ok${NC} (a real run would refuse)"
            else
                echo -e "${RED}REFUSING to release $next:${NC} release notes $notes_rel are $notes_ok." >&2
                echo "  Write human-readable notes for consumers (summary, highlights, behaviour changes," >&2
                echo "  how it was tested, known issues, upgrading; see the earlier docs/releases/*-notes.md)," >&2
                echo "  commit them, and show them to the operator with the release question (T-4899)." >&2
                echo "  No tag, VERSION or master change was made." >&2
                return 1
            fi
        fi
    fi

    # ── VERSION reconciliation leg (T-3242, tag-as-canonical) ────────────
    # VERSION was derived from a resetting commit counter and DECREASED across
    # consecutive releases (1.6.176 → 1.6.72 between v1.6.767 and v1.6.768).
    # The ruling: the tag is canonical, VERSION mirrors it. A release that
    # would write a DECREASED version refuses — same refuse-family as the
    # T-3190 fast-forward gate: better no release than one that tells
    # consumers they downgraded. Repos without a VERSION file have no second
    # answer to reconcile and are left alone (keeps consumer repos untouched).
    # T-3821: graded against HEAD's COMMITTED VERSION, not the working tree.
    # The tree can carry a pre-push stamp (<major.minor>.<commits>, from hooks
    # installed before T-3821) that is neither what consumers read nor what the
    # tag will carry: grading it made the reconcile commit go empty (v1.8.0
    # attempt 2) and could refuse a patch release as a false DECREASE.
    # needs_reconcile also covers a stale vendored copy beside a current root.
    local want_ver="${next#v}" ver_file="$root/VERSION" cur_file_ver="" needs_reconcile=false
    if [ -f "$ver_file" ]; then
        if git -C "$root" cat-file -e HEAD:VERSION 2>/dev/null; then
            cur_file_ver="$(git -C "$root" show HEAD:VERSION 2>/dev/null | tr -d '[:space:]')"
        else
            cur_file_ver="$(tr -d '[:space:]' < "$ver_file")"
        fi
        [ "$cur_file_ver" != "$want_ver" ] && needs_reconcile=true
        if [ -f "$root/.agentic-framework/VERSION" ] \
            && [ "$(git -C "$root" show HEAD:.agentic-framework/VERSION 2>/dev/null | tr -d '[:space:]')" != "$want_ver" ]; then
            needs_reconcile=true
        fi
        if [ -n "$cur_file_ver" ] && release_version_lt "$want_ver" "$cur_file_ver"; then
            echo -e "${RED}REFUSING to release:${NC} tag $next would DECREASE VERSION ($cur_file_ver → $want_ver)." >&2
            echo "  VERSION is ahead of the tag line — a consumer reading VERSION would" >&2
            echo "  conclude it downgraded. The tag is canonical (T-3242); reconcile" >&2
            echo "  VERSION or bump past it (--bump minor|major), then retry." >&2
            echo "  No tag was created." >&2
            return 1
        fi
    fi

    # ── Release-train leg (G-096, T-3190) ────────────────────────────────
    # Under T-3185 a release IS the fast-forward of the install surface; the
    # tag merely names it. So the advance is decided FIRST, before a tag
    # exists and long before one is published. A release that cannot move
    # `master` must fail loudly here rather than tag, push, exit 0, and leave
    # the operator with every signal saying it worked.
    local release_branch="${FW_RELEASE_BRANCH:-master}"
    # Declared here, before the publish loop that sets it (T-3822 merged the
    # old branch-push and tag-push loops into one atomic push per remote).
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

    # T-3819: the local verdict above is only half the question — a remote can
    # hold a commit the local ref does not. Asked here, before VERSION is
    # committed or a tag exists, and in --dry-run too.
    if [ "$ff_state" = "clean" ] || [ "$ff_state" = "uptodate" ]; then
        if ! release_remote_ff_check "$root" "$release_branch" "$offline"; then
            return 1
        fi
    fi

    # T-3848: the dev branch HEAD is on carries the reconcile commit below and
    # is master's only writer. v1.8.1 published master + tag and left
    # origin/bleeding-edge one commit BEHIND origin/master. It rides in the
    # same atomic push, so it is graded on every remote here too.
    local dev_branch=""
    dev_branch="$(git -C "$root" symbolic-ref -q --short HEAD 2>/dev/null)" || dev_branch=""
    [ "$dev_branch" = "$release_branch" ] && dev_branch=""
    if [ -n "$dev_branch" ]; then
        if ! release_remote_ff_check "$root" "$dev_branch" "$offline"; then
            return 1
        fi
    fi

    if $dry_run; then
        echo -e "${CYAN}would tag $next${NC} ($commits commits since $latest, bump=$bump)"
        if [ -f "$ver_file" ]; then
            if $needs_reconcile; then
                echo -e "${CYAN}would reconcile VERSION${NC} $cur_file_ver → $want_ver (tag-as-canonical, T-3242)"
            else
                echo "VERSION already $want_ver — no reconciliation needed"
            fi
        fi
        case "$ff_state" in
            clean)    echo -e "${CYAN}would fast-forward $release_branch${NC} by $ff_count commit(s) to $next" ;;
            uptodate) echo "$release_branch is already at HEAD — no fast-forward needed" ;;
            missing)  echo -e "${YELLOW}no local '$release_branch'${NC} — would skip the fast-forward" ;;
        esac
        [ -n "$dev_branch" ] && echo -e "${CYAN}would push $dev_branch${NC} in the same atomic push (T-3848)"
        release_issue_leg "$root" "$latest" "$next" "$gh_repo" true
        release_scratch_prune "$root" "$next" true
        return 0
    fi

    # Reconcile VERSION to the tag BEFORE the tag exists, so the tagged commit
    # carries the version the tag names (T-3242). HEAD moves by one commit, so
    # the fast-forward leg is recomputed — the refuse cases (branch-ahead /
    # diverged) already fired above and cannot newly appear from advancing HEAD.
    # T-3820: everything below that refuses must leave HEAD and VERSION as they
    # are now. _undo puts them back (and is a no-op when nothing was reconciled).
    local pre_head reconciled_sha="" ver_snap=""
    pre_head="$(git -C "$root" rev-parse HEAD 2>/dev/null)"
    _release_undo_reconcile() {
        [ -n "$ver_snap" ] || return 0
        release_version_restore "$root" "$ver_snap" "$pre_head" "$reconciled_sha"
        ver_snap=""
    }
    if [ -f "$ver_file" ] && $needs_reconcile; then
        echo -e "${CYAN}Reconciling VERSION $cur_file_ver → $want_ver (tag-as-canonical)...${NC}"
        ver_snap="$(release_version_snapshot "$root")"
        if ! release_reconcile_version "$root" "$next"; then
            echo -e "${RED}REFUSING to release:${NC} VERSION reconciliation commit failed." >&2
            _release_undo_reconcile
            echo "  No tag was created; VERSION restored. Check the working tree state of VERSION and retry." >&2
            return 1
        fi
        reconciled_sha="$(git -C "$root" rev-parse HEAD 2>/dev/null)"
        # Nothing committed (already equal to HEAD, T-3821): nothing to revert.
        [ "$reconciled_sha" = "$pre_head" ] && reconciled_sha=""
        ff_state="$(release_ff_state "$root" "$release_branch")"
        ff_count=0
        if [ "$ff_state" = "clean" ]; then
            ff_count="$(git -C "$root" rev-list --count "refs/heads/${release_branch}..HEAD" 2>/dev/null || echo 0)"
        fi
        commits="$(release_commits_since "$latest" "$root")"
    fi

    # Create annotated tag
    echo -e "${CYAN}Creating annotated tag $next...${NC}"
    if ! git -C "$root" tag -a "$next" -m "$next: auto-release ($commits commits since $latest)"; then
        echo -e "${RED}Failed to create tag${NC}" >&2
        _release_undo_reconcile
        return 1
    fi

    # Advance the local install surface, then publish branch AND tag together.
    # If the local advance fails, the tag (and reconcile commit) are removed so
    # a retry is clean.
    local rb_before="" publish_branch=false
    if [ "$ff_state" = "clean" ]; then
        echo -e "${CYAN}Fast-forwarding $release_branch ($ff_count commit(s))...${NC}"
        rb_before="$(git -C "$root" rev-parse "refs/heads/${release_branch}" 2>/dev/null)"
        if ! git -C "$root" branch -f "$release_branch" HEAD 2>&1; then
            echo -e "${RED}Failed to advance local '$release_branch'${NC} — is it checked out in a worktree?" >&2
            git -C "$root" tag -d "$next" >/dev/null 2>&1
            echo "  Tag $next was removed; nothing was published." >&2
            _release_undo_reconcile
            return 1
        fi
        publish_branch=true
    elif [ "$ff_state" = "missing" ]; then
        echo -e "${YELLOW}No local '$release_branch' — skipping the fast-forward${NC}" >&2
    else
        echo -e "${GREEN}$release_branch already at HEAD — no fast-forward needed${NC}"
        # Still published: the remote may be behind the local ref (T-3819 has
        # already proved it is an ancestor), and an equal remote is a no-op.
        publish_branch=true
    fi

    # ── Publish: ONE atomic push per remote (T-3822) ─────────────────────
    # v1.8.0 attempt 3 pushed `master`, then pushed the tag through a second
    # full pre-push audit minutes later; consumers ran `fw upgrade` from master
    # in between and installed a "1.8.0" no tag named. `--atomic` makes each
    # remote take both refs or neither, and one push means the pre-push hook
    # (and its audit) runs once per remote, not once per ref.
    #
    # Atomicity also retires the old T-3193 "hold the release open" state
    # (branch published, tag refused): on a single remote it can no longer
    # arise. What remains is per-remote all-or-nothing:
    #   - no remote took the push -> nothing was published anywhere, so the
    #     branch, tag and reconcile commit are all rolled back (T-3190/T-3820);
    #   - some remotes took it    -> the release IS published; the failures are
    #     reported and the command exits non-zero, nothing is retracted.
    #
    # Retry before giving up (T-3193 AC2): the common refusal is our own
    # pre-push audit lock held by cron, which clears on its own.
    local refspecs=()
    $publish_branch && refspecs+=("refs/heads/${release_branch}:refs/heads/${release_branch}")
    [ -n "$dev_branch" ] && refspecs+=("refs/heads/${dev_branch}:refs/heads/${dev_branch}")
    refspecs+=("refs/tags/${next}:refs/tags/${next}")
    local pub_ok=0 pub_attempted=0 remote
    while IFS= read -r remote; do
        [ -z "$remote" ] && continue
        pub_attempted=$((pub_attempted + 1))
        if $publish_branch; then
            echo -e "${CYAN}Pushing $release_branch${dev_branch:+ + $dev_branch} + $next to $remote (atomic)...${NC}"
        else
            echo -e "${CYAN}Pushing $next to $remote (atomic)...${NC}"
        fi
        local _try _ok=0
        for _try in 1 2 3; do
            if git -C "$root" push --atomic "$remote" "${refspecs[@]}" 2>&1; then
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
            pub_ok=$((pub_ok + 1))
        else
            echo -e "  ${YELLOW}WARN: atomic push to $remote failed after 3 attempts — neither ref landed there${NC}" >&2
            failed=1
        fi
    done < <(git -C "$root" remote 2>/dev/null)

    if [ "$pub_attempted" -gt 0 ] && [ "$pub_ok" -eq 0 ]; then
        echo -e "${RED}REFUSING to publish:${NC} the release reached no remote." >&2
        echo "  Each push was atomic, so no remote has '$release_branch' or $next from" >&2
        echo "  this release: nothing was published and nothing needs retracting." >&2
        [ -n "$rb_before" ] && git -C "$root" branch -f "$release_branch" "$rb_before" >/dev/null 2>&1
        git -C "$root" tag -d "$next" >/dev/null 2>&1
        echo "  Rolled back: $release_branch restored, tag $next removed; nothing was published." >&2
        _release_undo_reconcile
        echo "  No GitHub Release was created. Fix the remote and re-run the release." >&2
        return 1
    fi
    # Published on at least one remote: the reconcile commit is now public and
    # is never reverted from here on.
    [ -n "$ver_snap" ] && rm -rf "$ver_snap"
    ver_snap=""

    # T-4673: a push exit code is not evidence the tag is where consumers look
    # (v1.8.15-be.4 reached origin but never GitHub). Read it back everywhere.
    if [ "$pub_attempted" -gt 0 ] && ! release_tag_verify_remotes "$root" "$next"; then
        echo -e "${RED}RELEASE INCOMPLETE:${NC} $next is missing on the remote(s) above." >&2
        echo "  Push it there: git -C $root push <remote> refs/tags/${next}:refs/tags/${next}  (or fw mirror sync)" >&2
        failed=1
    fi

    # Create GitHub Release (best-effort)
    if command -v gh >/dev/null 2>&1; then
        echo -e "${CYAN}Creating GitHub Release $next...${NC}"
        # T-4899: the human-readable notes lead; GitHub's generated changelog is
        # appended, ranged from the previous release (not GitHub's own guess,
        # which compared v1.8.12...v1.8.15 and skipped v1.8.14).
        local gh_flags=(--title "$next" --generate-notes --notes-start-tag "$latest" --latest)
        local linked_notes=""
        if [ "$notes_ok" = "yes" ]; then
            # T-4903: task ids in the notes link to the task files at the release tag.
            local link_repo="$gh_repo"
            if [ -z "$link_repo" ]; then
                link_repo="$(git -C "$root" remote -v 2>/dev/null | awk '/github\.com/ {print $2; exit}' \
                    | sed -E 's#^(https://|git@)github\.com[:/]##; s#\.git$##')"
            fi
            linked_notes="$(mktemp "${TMPDIR:-/tmp}/fw-release-notes.XXXXXX")"
            if [ -n "$link_repo" ] && python3 "$(dirname "${BASH_SOURCE[0]}")/gh_links.py" \
                    "$root" "$next" "$link_repo" < "$root/$notes_rel" > "$linked_notes" 2>/dev/null \
                    && [ -s "$linked_notes" ]; then
                gh_flags+=(--notes-file "$linked_notes")
            else
                gh_flags+=(--notes-file "$root/$notes_rel")
            fi
        fi
        if [ -n "$gh_repo" ]; then
            gh_flags+=(--repo "$gh_repo")
        fi
        if gh release create "$next" "${gh_flags[@]}" 2>&1; then
            echo -e "  ${GREEN}✓ GitHub Release created${NC}"
        else
            echo -e "  ${YELLOW}WARN: gh release create failed (non-fatal)${NC}" >&2
        fi
        [ -n "$linked_notes" ] && rm -f "$linked_notes"
    else
        echo -e "${YELLOW}gh CLI not found — skipping GitHub Release${NC}"
    fi

    # T-4340: after publish, so the field report and release notes it links to exist on master
    release_issue_leg "$root" "$latest" "$next" "$gh_repo" false

    # T-4703: the shipped lanes' work dirs go once the release is published
    release_scratch_prune "$root" "$next" false

    return $failed
}

# ---------------------------------------------------------------------------
# release_status  — show current release state
# ---------------------------------------------------------------------------
release_status() {
    local root="${PROJECT_ROOT:-$(pwd)}"
    local pattern latest commits used
    pattern="$(release_tag_pattern)"
    used="$pattern"
    latest="$(release_latest_tag "$root" "$pattern")"
    # Prefixed semver (designer-v1.2.3, T-3585): when the configured pattern
    # matches nothing, recognise <prefix>v<semver> before giving up.
    if [ -z "$latest" ]; then
        latest="$(release_latest_tag "$root" '*-v[0-9]*.[0-9]*.[0-9]*')"
        [ -n "$latest" ] && used='*-v[0-9]*.[0-9]*.[0-9]*'
    fi
    if [ -n "$latest" ]; then
        commits="$(release_commits_since "$latest" "$root")"
        echo "Latest tag:       $latest (pattern $used)"
        echo "Commits since:    $commits"
    else
        # Never print 0 here: with no baseline, "nothing is due" is unknown.
        local total
        total="$(git -C "$root" rev-list --count HEAD 2>/dev/null)"
        echo "Latest tag:       no tag matching $pattern"
        echo "Commits since:    UNKNOWN (no matching tag; ${total:-unknown} commits since the root)"
    fi
    if [ -n "$latest" ] && [[ "$latest" =~ ^v[0-9] ]]; then
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
        tag-and-release|""|--dry-run|--bump|--repo|--offline)
            # If first arg was actually a flag, it belongs to tag-and-release
            if [[ "$subcmd" == --* ]]; then
                set -- "$subcmd" "$@"
            fi
            _RELEASE_ENFORCE_DECISION=1 release_tag_and_release "$@"
            ;;
        decide)
            release_decide "$@"
            ;;
        be-tag)
            release_be_tag "$@"
            ;;
        status)
            release_status
            ;;
        -h|--help|help)
            cat <<'EOF'
Usage: fw release [subcommand] [flags]

Subcommands:
  tag-and-release   Cut new tag, push, create GitHub Release (default)
  decide vX.Y.Z     Record a release decision (--by operator|field-evidence --ref ...);
                    unattended runs refuse without one for that version (T-4364)
  status            Show current tag and remote state
  be-tag            Tag HEAD of bleeding-edge as vX.Y.Z-be.N (annotated; refuses on
                    master). --version X.Y.Z, --dry-run, --push (T-4431)

Flags (for tag-and-release):
  --dry-run         Show what would happen, change nothing
  --offline         Skip the remote fast-forward check (an unreachable remote
                    otherwise refuses the release, T-3819)
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
