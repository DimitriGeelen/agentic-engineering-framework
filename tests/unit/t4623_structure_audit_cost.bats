#!/usr/bin/env bats
# T-4623: the pre-push structure audit ran 262-348s against t3062's 150s budget.
# Three costs were repeated work, not new checks:
#   1. the arc-staleness loop ran one `git log --since -- <tasks>` per in-progress
#      arc (17 walks of ~3,000 commits, ~50s);
#   2. `verdict_ledger.py audit` ran three times (~9s each) for three checks;
#   3. four independent read-only history detectors and the tests/lint suite ran
#      one after another.
# t3062 measures the total. These tests pin each fix so a revert is named, not
# just a slower clock on a loaded host.

setup() {
    AUDIT="$BATS_TEST_DIRNAME/../../agents/audit/audit.sh"
}

# Executable lines only: comments mention the old shapes on purpose.
_code() { grep -v '^[[:space:]]*#' "$AUDIT"; }

@test "T-4623: verdict_ledger.py audit is invoked once, not once per reading check" {
    n=$(_code | grep -c 'lib/verdict_ledger.py" audit' || true)
    [ "$n" -eq 1 ] || { echo "verdict_ledger.py audit invoked $n times in audit.sh"; false; }
}

@test "T-4623: the arc-staleness loop walks history once, not once per arc" {
    # Body of the stale-arc loop: from its `for af` to the stale counter.
    body=$(awk '/recent_task_paths=/{p=1} p{print} /stale_arc_count=\$\(\(stale_arc_count \+ 1\)\)/{if(p)exit}' "$AUDIT" \
           | sed -n '/for af in/,$p' | grep -v '^[[:space:]]*#')
    [ -n "$body" ] || { echo "stale-arc loop not found"; false; }
    if echo "$body" | grep -qE '(^|[^a-z])git +(-C|log)'; then
        echo "a git command runs inside the per-arc loop:"; echo "$body" | grep -E '(^|[^a-z])git +(-C|log)'; false
    fi
}

@test "T-4623: the single window pass agrees with the per-arc pathspec query" {
    command -v git >/dev/null || skip "git needed"
    r="$BATS_TEST_TMPDIR/repo"
    mkdir -p "$r/.tasks/active" "$r/.tasks/completed"
    git -C "$r" init -q
    git -C "$r" config user.email t@t; git -C "$r" config user.name t
    old='2020-01-01T00:00:00'
    echo a > "$r/.tasks/active/T-1-old.md"
    echo b > "$r/.tasks/active/T-2-moved.md"
    echo c > "$r/.tasks/active/T-3-edited.md"
    git -C "$r" add -A
    GIT_AUTHOR_DATE=$old GIT_COMMITTER_DATE=$old git -C "$r" commit -qm old
    git -C "$r" mv .tasks/active/T-2-moved.md .tasks/completed/T-2-moved.md
    echo c2 >> "$r/.tasks/active/T-3-edited.md"
    git -C "$r" commit -qam recent

    # The pass audit.sh runs, verbatim in shape.
    recent_task_paths=$'\n'$(git -C "$r" log --since="30.days.ago" \
        --format= --name-only --no-renames --relative -- .tasks | sort -u)$'\n'

    for p in .tasks/active/T-1-old.md .tasks/completed/T-2-moved.md \
             .tasks/active/T-2-moved.md .tasks/active/T-3-edited.md; do
        old_rc=0; [ -n "$(git -C "$r" log --since=30.days.ago --format=%H -- "$p" | head -1)" ] || old_rc=1
        new_rc=0; case "$recent_task_paths" in *$'\n'"$p"$'\n'*) ;; *) new_rc=1;; esac
        [ "$old_rc" -eq "$new_rc" ] || { echo "disagree on $p: pathspec=$old_rc pass=$new_rc"; false; }
    done
    # And the old-only task really is stale (the comparison is not vacuous).
    case "$recent_task_paths" in *$'\n'".tasks/active/T-1-old.md"$'\n'*) false;; esac
}

@test "T-4623: prefetched detectors report their rc and output; a killed one reads as not-run" {
    eval "$(sed -n '/^_audit_prefetch() {/,/^}/p; /^_audit_collect() {/,/^}/p' "$AUDIT")"
    declare -F _audit_prefetch >/dev/null && declare -F _audit_collect >/dev/null
    _AUDIT_PF_DIR="$BATS_TEST_TMPDIR/pf"; mkdir -p "$_AUDIT_PF_DIR"
    declare -A _AUDIT_PF_PID=()

    _audit_prefetch ok bash -c 'echo line-out; echo line-err >&2; exit 2'
    _audit_prefetch dead sleep 29.4623
    kill -9 "${_AUDIT_PF_PID[dead]}"

    _audit_collect ok
    [ "$_PF_RC" = "2" ]
    [[ "$_PF_OUT" == *line-out* ]]
    [[ "$_PF_OUT" == *line-err* ]]

    _audit_collect dead
    [ "$_PF_RC" = "1" ]
    pkill -f '^sleep 29.4623$' 2>/dev/null || true
}

@test "T-4623: the tests/lint invariant suite runs file-parallel when GNU parallel exists" {
    _code | grep -q -- '--jobs [0-9]* --no-parallelize-within-files' \
        || { echo "check_invariant_suite no longer passes --jobs"; false; }
    _code | grep -q 'command -v parallel' \
        || { echo "--jobs is not guarded on GNU parallel (bats --jobs fails without it)"; false; }
}
