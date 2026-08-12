#!/usr/bin/env bats
# T-2930 / OBS-221 — the pre-push audit gate failed OPEN under lock contention.
#
# audit.sh exited 0 when another audit held the lock, and the generated pre-push
# hook read 0 as "audited, no failures". Observed live 2026-08-11: a push printed
#
#     === Pre-Push Audit Check ===
#     Another audit is already running — exiting
#
# and was allowed through while an invariant was RED moments earlier. Nothing in
# the output distinguished "audited and clean" from "not audited at all".
#
# The defect was NOT "contention exits 0". Exit 0 was deliberate and documented,
# for cron's zero-zombie contract — a blanket non-zero would have fixed the push
# gate by breaking cron. The defect was that ONE code carried TWO meanings and the
# two callers need opposite things from it. So the code now says what HAPPENED
# ("did not run"), and each caller decides what that is worth.
#
# Exit codes after this change:
#   0   ran, no failures     1   ran, warnings     2   ran, FAILURES
#   75  DID NOT RUN (EX_TEMPFAIL) — verdict unknown, which is not the same as clean
#
# 75 rather than a private code like 3: EX_TEMPFAIL from sysexits.h already means
# transient/retry to any reader. Remedy shape accepted from 832 (rail 539/541),
# filed as OBS-224.

setup() {
    FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    AUDIT="$FRAMEWORK_ROOT/agents/audit/audit.sh"
    HOOKS="$FRAMEWORK_ROOT/agents/git/lib/hooks.sh"
    PROJ="$BATS_TEST_TMPDIR/proj"
    mkdir -p "$PROJ/.context/locks" "$PROJ/.tasks/active" "$PROJ/.tasks/completed"
}

# Builds a PATH that genuinely lacks flock, so audit.sh takes its FALLBACK lock
# arm. Only the binaries needed to reach the lock check are linked — contention
# exits before any section runs, so the audit never gets far enough to need more.
_stripped_path() {
    local d="$PROJ/bin"
    mkdir -p "$d"
    local b p
    for b in bash sh dirname basename pwd date stat mkdir rm cat grep sed python3 \
             git tr head cut wc ls mktemp uname awk sort find tail env touch chmod \
             cp mv id hostname sleep kill ps; do
        p=$(command -v "$b" 2>/dev/null) && ln -sf "$p" "$d/$b"
    done
    printf '%s\n' "$d"
}

# ── The producer: contention must report "did not run" in BOTH lock modes ──────

@test "t2930: flock arm exits 75 under contention" {
    exec 201>"$PROJ/.context/locks/audit.lock"
    flock -n 201
    run env PROJECT_ROOT="$PROJ" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
        bash "$AUDIT" --section structure
    exec 201>&-
    [ "$status" -eq 75 ] || { echo "expected 75, got $status: $output" >&2; return 1; }
}

@test "t2930: flock arm says no verdict was produced, not just that it exited" {
    # "exiting" alone reads as an orderly finish. The operator has to be able to
    # tell, from the message, that nothing was evaluated.
    exec 201>"$PROJ/.context/locks/audit.lock"
    flock -n 201
    run env PROJECT_ROOT="$PROJ" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
        bash "$AUDIT" --section structure
    exec 201>&-
    [[ "$output" == *"no verdict produced"* ]]
}

@test "t2930: no-flock fallback arm also exits 75 under contention" {
    # "in ALL modes" is the point of the remedy. flock's presence varies by
    # platform, and a fix applied only to the arm this host happens to take would
    # leave every mac and slim container on the old fail-open contract.
    local sp; sp=$(_stripped_path)
    : > "$PROJ/.context/locks/audit.lock"
    run env -u LD_PRELOAD PATH="$sp" PROJECT_ROOT="$PROJ" \
        FRAMEWORK_ROOT="$FRAMEWORK_ROOT" "$sp/bash" "$AUDIT" --section structure
    [ "$status" -eq 75 ] || { echo "expected 75, got $status: $output" >&2; return 1; }
}

@test "t2930: the stripped PATH genuinely hides flock" {
    # Anti-vacuity for the leg above. If flock were still visible, that test would
    # have taken the flock arm and passed while asserting nothing about the
    # fallback — a green that means the opposite of what it reads as.
    local sp; sp=$(_stripped_path)
    run env PATH="$sp" bash -c 'command -v flock'
    [ "$status" -ne 0 ]
    # ...and flock IS present on this host, so the strip is doing real work rather
    # than describing a machine that never had it.
    run command -v flock
    [ "$status" -eq 0 ]
}

@test "t2930: 75 means contention specifically — an uncontended run does not return it" {
    # Without this, 'exit 75' unconditionally at the top of audit.sh would pass
    # every leg above.
    run env PROJECT_ROOT="$PROJ" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
        bash "$AUDIT" --section structure
    [ "$status" -ne 75 ] || { echo "uncontended run returned 75: $output" >&2; return 1; }
}

# ── The consumer: the pre-push gate must refuse on could-not-evaluate ──────────
#
# Drives the SHIPPED decision block out of hooks.sh rather than a retyped copy,
# so the test cannot pass against source that no longer matches what gets
# installed. Same technique as t2927.

_decision_block() {
    awk '/^if \[ \$audit_exit -eq 75 \]; then$/,/^fi$/' "$HOOKS"
}

_run_decision() {
    local block; block=$(_decision_block)
    [ -n "$block" ] || { echo "could not extract the decision block from hooks.sh" >&2; return 1; }
    run bash -c "audit_exit=$1
$block
exit 0"
}

@test "t2930: the PRE-FIX block waved a contended push through, silently" {
    # Anti-vacuity: proves the legs below are testing a repair rather than
    # describing behaviour that was always there.
    #
    # The pre-fix bytes are RECONSTRUCTED inline, not read from git. t2927 read
    # its pre-fix bytes via `git show HEAD:<file>` — valid when written, red
    # within the hour, because committing the fix made HEAD stop being pre-fix.
    # A leg whose subject moves is worse than no leg: it goes green for the wrong
    # reason first, then red for the wrong reason.
    local old_block='if [ $audit_exit -eq 2 ]; then
    echo "ERROR: Push blocked - audit has FAILURES"
    exit 1
elif [ $audit_exit -eq 1 ]; then
    echo "WARNING: Audit has warnings (push allowed)"
fi'
    run bash -c "audit_exit=75
$old_block
exit 0"
    [ "$status" -eq 0 ]
    # And nothing was printed — the operator had no signal at all. This is why it
    # went unnoticed: not a wrong message, an ABSENT one, in a hook whose banner
    # ("=== Pre-Push Audit Check ===") had already claimed the check happened.
    [ -z "$output" ]
}

@test "t2930: audit_exit=75 BLOCKS the push" {
    _run_decision 75
    [ "$status" -eq 1 ] || { echo "contention did not block: $output" >&2; return 1; }
}

@test "t2930: the 75 block says the audit could not run, not that it failed" {
    # These are different operator actions: a failure means fix something, a
    # contention means wait. A message that conflates them sends the operator
    # hunting for a defect that does not exist.
    _run_decision 75
    [[ "$output" == *"COULD NOT RUN"* ]]
    [[ "$output" == *"not an audit failure"* ]]
    [[ "$output" == *"push again"* ]]
}

@test "t2930: audit_exit=2 still blocks, with the FAILURES message" {
    _run_decision 2
    [ "$status" -eq 1 ]
    [[ "$output" == *"audit has FAILURES"* ]]
    [[ "$output" != *"COULD NOT RUN"* ]]
}

@test "t2930: audit_exit=1 warns and allows" {
    _run_decision 1
    [ "$status" -eq 0 ]
    [[ "$output" == *"warnings"* ]]
}

@test "t2930: audit_exit=0 allows silently" {
    _run_decision 0
    [ "$status" -eq 0 ]
    [[ "$output" != *"ERROR"* ]]
}

@test "t2930: the four outcomes are mutually distinguishable" {
    # The bug was two states sharing one code. A repair that produced two states
    # sharing one MESSAGE would be the same defect one layer up.
    local seen=""
    for code in 0 1 2 75; do
        _run_decision "$code"
        seen="$seen|$status:$(echo "$output" | tr -d '\n' | head -c 60)"
    done
    # 4 distinct (status, message-prefix) pairs
    local n
    n=$(printf '%s' "$seen" | tr '|' '\n' | grep -c . )
    [ "$n" -eq 4 ]
    printf '%s' "$seen" | tr '|' '\n' | grep -c . >/dev/null
    local uniq_n
    uniq_n=$(printf '%s' "$seen" | tr '|' '\n' | grep . | sort -u | wc -l)
    [ "$uniq_n" -eq 4 ] || { echo "outcomes not distinct: $seen" >&2; return 1; }
}

# ── Cron: immune today, but by accident — pin it ──────────────────────────────

@test "t2930: every generated audit cron line pipes to logger" {
    # Measured 2026-08-12: audit's exit code never reaches cron, because each
    # generated line ends '2>&1 | logger -t agentic-cron' and a pipeline's status
    # is the LAST command's. That is why the remedy needed no cron-side change.
    #
    # But it is an ACCIDENT of the logging convention, not a decision. Remove the
    # logger pipe (or add 'set -o pipefail') and every contended cron run starts
    # reporting a failure. This leg makes that change go red instead of silent.
    local crontab="$FRAMEWORK_ROOT/.context/cron/agentic-audit.crontab"
    [ -f "$crontab" ] || skip "no generated crontab in this tree"
    local audit_lines bad
    audit_lines=$(grep -v '^#' "$crontab" | grep 'fw" audit' || true)
    [ -n "$audit_lines" ] || skip "no audit cron lines"
    bad=$(printf '%s\n' "$audit_lines" | grep -vc '| logger' || true)
    [ "$bad" -eq 0 ] || {
        echo "audit cron lines not piped to logger — exit 75 would now surface as a cron failure" >&2
        printf '%s\n' "$audit_lines" | grep -v '| logger' >&2
        return 1
    }
}

@test "t2930: a logger pipeline really does swallow 75" {
    # Asserts the mechanism the leg above relies on, rather than trusting the
    # claim that pipelines return the last status.
    run bash -c '(exit 75) 2>&1 | logger -t t2930-probe; echo "rc=$?"'
    [[ "$output" == *"rc=0"* ]]
}

# ── L-533 enumerating guard ───────────────────────────────────────────────────

@test "t2930: no contention path in audit.sh still exits 0" {
    # T-2514's sibling-site lesson: when you fix N instances of a class in one
    # file, ask what would fail if there were an N+1th. Both known arms are fixed
    # above; this catches an arm added later, or one either fix missed.
    #
    # Whole-line comments are stripped FIRST — the block comment added by this
    # very task quotes the old behaviour ("contention exited 0"), and a naive
    # scan flags the explanation of the bug as the bug. Exactly the rake T-2926
    # leg 5 hit against a comment in bin/fw.
    local hits
    hits=$(sed 's/[[:space:]]*#.*$//' "$AUDIT" \
           | grep -n 'already running' -A6 \
           | grep -E '^\s*[0-9]+[-:]\s*exit 0\s*$' || true)
    [ -z "$hits" ] || {
        echo "a contention path still exits 0:" >&2
        echo "$hits" >&2
        return 1
    }
}

@test "t2930: both contention arms are present and both exit 75" {
    # Counts rather than spot-checks: two 'already running' messages, two 75s.
    # If a third arm appears without a 75, the counts diverge and this goes red.
    local msgs codes
    msgs=$(grep -c 'Another audit is already running' "$AUDIT")
    codes=$(sed 's/[[:space:]]*#.*$//' "$AUDIT" | grep -cE '^\s*exit 75\s*$')
    [ "$msgs" -eq 2 ] || { echo "expected 2 contention messages, found $msgs" >&2; return 1; }
    [ "$codes" -eq 2 ] || { echo "expected 2 'exit 75', found $codes" >&2; return 1; }
}
