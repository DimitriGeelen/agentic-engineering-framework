#!/usr/bin/env bats
# T-2850 — greenfield onboarding integration coverage.
#
# WHY THIS FILE EXISTS
#
# Four defects reached the operator's hands in a single by-hand onboarding run
# on 2026-08-06 (T-2839 fw upgrade, T-2843 path ambiguity, T-2844 cron drift,
# T-2845 upgrade advisory target). Every one of them had, or immediately got, a
# green unit test. None was caught before the operator saw it, because the only
# integration coverage for onboarding was two assertions that a command printed
# a string containing "nboarding" — neither of which checked an exit status.
#
# The unit tests answer "is this predicate correct?". They cannot answer "what
# does an operator see after `fw init`?", because that answer is a property of
# the ASSEMBLY, and each of the four defects lived in a join: a checker pointed
# at the wrong object, a comparison between two different kinds of value, a
# health check run against the wrong copy of the framework.
#
# So this file asserts on the assembly. It runs ONE real `fw init` into a temp
# directory and ONE real `fw doctor` against it, then makes every assertion
# against those captured artefacts. That is deliberately expensive (~2 min) and
# deliberately singular — the cost is the point: it is the only way to observe
# what the operator observes.
#
# THE LOAD-BEARING TEST is "no project-scope WARN". It uses a closed allowlist:
# a warning passes only if it matches a pattern explicitly enumerated below with
# a reason. A new project-scope warning therefore turns this red by default
# rather than needing someone to think to add an assertion for it. That
# default-deny shape is what generalises past the four known defects.

bats_require_minimum_version 1.5.0

setup_file() {
    FW="${BATS_TEST_DIRNAME}/../../bin/fw"
    export FW

    # Outside the framework tree, for the OBS-162 reason recorded in
    # init_head_bootstrap.bats: a fixture nested under the repo can exercise a
    # different vendor code path than a real consumer does.
    GDIR="${BATS_FILE_TMPDIR:-/tmp}/t2850"
    export GDIR
    rm -rf "$GDIR"; mkdir -p "$GDIR/home" "$GDIR/proj"

    # PRECONDITION: the fixture must not sit inside an existing git repository.
    #
    # This is not paranoia — it happened. During T-2850 a stray `fw init`
    # turned /tmp itself into a framework project (T-2746/T-2835 class: fw
    # auto-initialising in a caller's cwd). Every fixture under /tmp then
    # inherited that repo, so `fw init` found an enclosing worktree, skipped
    # `git init`, and produced a project with ZERO tracked files. The suite did
    # not fail cleanly — it reported "Untracked task files", which reads exactly
    # like a genuine day-zero defect in the framework. Contamination that
    # disguises itself as a finding is worse than contamination that crashes.
    #
    # Detect and refuse, rather than measuring the wrong object quietly.
    if git -C "$GDIR/proj" rev-parse --show-toplevel >/dev/null 2>&1; then
        local enclosing
        enclosing=$(git -C "$GDIR/proj" rev-parse --show-toplevel 2>/dev/null)
        printf 'PRECONDITION FAILED: fixture %s is inside git repo %s.\n' "$GDIR/proj" "$enclosing" >&2
        printf 'fw init will skip git init and every tracking assertion measures the wrong repo.\n' >&2
        printf 'Clean the stray repo (T-2746/T-2835) before running this suite.\n' >&2
        return 1
    fi

    # `env -u` mirrors what the onboarding prompt tells the agent to do (T-2795):
    # an inherited FRAMEWORK_ROOT/PROJECT_ROOT wins over fw's own location, so a
    # test run from inside a live session would otherwise measure THIS project.
    env -u FRAMEWORK_ROOT -u PROJECT_ROOT HOME="$GDIR/home" \
        "$FW" init "$GDIR/proj" --provider claude > "$GDIR/init.log" 2>&1
    echo "$?" > "$GDIR/init.rc"

    # A git identity, because `fw init` itself instructs the operator to set one
    # before doing anything else. Testing the state an operator reaches by
    # FOLLOWING the instructions, not the state they are dropped in.
    git -C "$GDIR/proj" config user.email "greenfield@example.com"
    git -C "$GDIR/proj" config user.name "Greenfield Test"

    # Run doctor from a foreign CWD (/tmp), not from inside the project. This is
    # the shape that exposed the T-2709 hook-resolution false positive: hooks
    # that resolve when invoked from the project root and fail from anywhere
    # else. `cd` first so a project-root-relative bug cannot hide.
    ( cd /tmp && env -u FRAMEWORK_ROOT -u PROJECT_ROOT HOME="$GDIR/home" \
        "$GDIR/proj/.agentic-framework/bin/fw" doctor > "$GDIR/doctor.log" 2>&1
      echo "$?" > "$GDIR/doctor.rc" )
}

# --- helpers ---

# Strip ANSI colour so pattern matching is not defeated by escape sequences.
_plain() { sed 's/\x1b\[[0-9;]*m//g' "$1"; }

# --- init ---

@test "greenfield: fw init exits 0" {
    [ "$(cat "$GDIR/init.rc")" = "0" ]
}

@test "greenfield: init validation passes with no errors" {
    run _plain "$GDIR/init.log"
    [[ "$output" == *"Validation passed"* ]]
    # A "Validation passed" line must not coexist with error markers; T-2740
    # shipped an init whose own audit failed on day zero.
    [[ "$output" != *"Validation: "*"error"* ]]
}

@test "greenfield: init produces a resolvable HEAD (bootstrap commit)" {
    # Pins T-2821: an unborn HEAD deadlocks background-session isolation.
    run git -C "$GDIR/proj" rev-parse -q --verify HEAD
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}

# --- doctor ---

@test "greenfield: fw doctor exits 0 from a foreign CWD" {
    # The operator's 2026-08-06 run exited 2 here.
    [ "$(cat "$GDIR/doctor.rc")" = "0" ]
}

@test "greenfield: doctor output is substantive (guards the checks below from passing vacuously)" {
    # Without this, an empty or truncated doctor.log would make every
    # "no FAIL" / "no bad WARN" assertion below pass while asserting nothing.
    # That vacuous-pass shape is its own recurring defect class here
    # (T-2726/T-2727), so the anchor is explicit rather than assumed.
    run _plain "$GDIR/doctor.log"
    [ "${#output}" -gt 200 ]
    [[ "$output" == *"Active mode"* ]]
}

# Doctor findings are emitted as a status token at the start of a line:
#   "  WARN  Untracked task files: 1"
# The words FAIL and WARN also appear inside doctor's own descriptive prose,
# e.g. "- Runs audit before push (blocks on FAIL, warns on WARN)". A bare
# substring match therefore reports a failure that does not exist — the first
# draft of this file did exactly that. Match the token, not the word.
_findings() {
    _plain "$1" | grep -E '^[[:space:]]*'"$2"'[[:space:]]' || true
}

@test "greenfield: doctor emits zero FAIL findings" {
    run _findings "$GDIR/doctor.log" FAIL
    [ -z "$output" ] || { printf 'Unexpected FAIL finding(s):\n%s\n' "$output" >&2; false; }
}

@test "greenfield: the FAIL matcher does not match doctor's descriptive prose" {
    # Negative control for the matcher itself. Without this, tightening the
    # pattern until the suite goes green is indistinguishable from tightening it
    # until it matches nothing at all.
    run bash -c "printf '  - Runs audit before push (blocks on FAIL, warns on WARN)\n  FAIL  a real finding\n' > '$GDIR/matcher.log'; :"
    run _findings "$GDIR/matcher.log" FAIL
    [[ "$output" == *"a real finding"* ]]
    [[ "$output" != *"Runs audit before push"* ]]
}

@test "greenfield: doctor emits no PROJECT-SCOPE warning" {
    # THE load-bearing assertion. Closed allowlist: a WARN survives only by
    # matching an entry enumerated here, each with a stated reason. Anything
    # else fails, so a newly-introduced project-scope warning turns this red
    # without anyone having to predict it.
    #
    # Allowed, and why:
    #   [host]                — doctor's own scope tag for host-level findings
    #                           (T-1707); by construction not this project's health.
    #   Unsupervised session  — fires whenever the session is not under claude-fw,
    #                           which is always true inside a test runner.
    run _findings "$GDIR/doctor.log" WARN
    local unexplained=""
    while IFS= read -r line; do
        [ -n "$line" ] || continue
        case "$line" in
            *"[host]"*)               continue ;;
            *"Unsupervised session"*) continue ;;
        esac
        unexplained="${unexplained}${line}"$'\n'
    done <<< "$output"
    [ -z "$unexplained" ] || {
        printf 'Unexplained project-scope WARN(s):\n%s' "$unexplained" >&2
        false
    }
}

@test "greenfield: hooks resolve from a foreign CWD" {
    # T-2709 class: the operator saw "15/15 hook(s) failed to resolve" on a
    # stale consumer. Assert the positive, not merely the absence of the word
    # "failed" — an absent hook-exercise section would satisfy a negative test.
    run _plain "$GDIR/doctor.log"
    [[ "$output" == *"hook(s) resolve"* ]]
    [[ "$output" != *"hook(s) failed to resolve"* ]]
}

@test "greenfield: no framework path ambiguity warning on a vendored consumer" {
    # T-2843: upstream_repo (a pull source) was compared against FRAMEWORK_ROOT
    # (the running copy) as a plain inequality. Under vendoring those differ by
    # construction, so this fired on every consumer unconditionally.
    run _plain "$GDIR/doctor.log"
    [[ "$output" != *"Framework path ambiguity"* ]]
}

@test "greenfield: an empty cron registry is not reported as drift" {
    # T-2844: `fw init` seeds `jobs: []`; the drift checks gated on the registry
    # FILE existing rather than on it declaring jobs.
    run _plain "$GDIR/doctor.log"
    [[ "$output" != *"Cron registry edited but not generated"* ]]
    [[ "$output" != *"Cron registry present but not generated"* ]]
    # Control: the seed really is empty, so the assertion above is about the
    # checker's logic and not about a registry that happens to be absent.
    run cat "$GDIR/proj/.context/cron-registry.yaml"
    [[ "$output" == *"jobs: []"* ]]
}

# --- the seeded onboarding set (arc-017 invariant) ---

@test "greenfield: seeds a non-empty onboarding task set" {
    run bash -c "ls '$GDIR/proj'/.tasks/active/T-*.md | wc -l"
    [ "$output" -ge 1 ]
}

@test "greenfield: every gated onboarding task is agent-resolvable, or is owner:human" {
    # arc-017's invariant, asserted against the SHIPPED seed rather than against
    # a synthetic fixture. An onboarding-tagged task that is neither owner:human
    # nor agent-resolvable is a structural deadlock: the T-532 gate blocks all
    # other work until it reaches work-completed, and no agent-reachable path
    # exists to get it there.
    local offenders=""
    for f in "$GDIR/proj"/.tasks/active/T-*.md; do
        grep -q '^tags:.*onboarding' "$f" || continue
        local owner wtype
        owner=$(grep -m1 '^owner:' "$f" | sed 's/owner:[[:space:]]*//')
        wtype=$(grep -m1 '^workflow_type:' "$f" | sed 's/workflow_type:[[:space:]]*//')
        [ "$owner" = "human" ] && continue
        # inception is agent-unresolvable: `fw inception decide` refuses under
        # $CLAUDECODE=1 (T-1259/T-1260), so only a human can close it.
        [ "$wtype" = "inception" ] && offenders="${offenders}$(basename "$f") (owner=$owner, type=inception)"$'\n'
        # An unticked `### Human` AC is equally unreachable for an agent.
        if awk '/^### Human/{h=1;next} /^## /{h=0} h' "$f" | grep -q '^- \[ \]'; then
            offenders="${offenders}$(basename "$f") (owner=$owner, unticked Human AC)"$'\n'
        fi
    done
    [ -z "$offenders" ] || {
        printf 'Agent-unresolvable task(s) in the gated onboarding set:\n%s' "$offenders" >&2
        false
    }
}

@test "greenfield: the T-532 gate does not list an owner:human onboarding task as blocking" {
    # arc-017 clause 1 — "readable but never blocking". Focus a task that is NOT
    # part of onboarding, then confirm the gate blocks (it should) while omitting
    # every owner:human onboarding task from the list of what is blocking.
    local humans=()
    for f in "$GDIR/proj"/.tasks/active/T-*.md; do
        grep -q '^tags:.*onboarding' "$f" || continue
        [ "$(grep -m1 '^owner:' "$f" | sed 's/owner:[[:space:]]*//')" = "human" ] || continue
        humans+=("$(grep -m1 '^id:' "$f" | sed 's/id:[[:space:]]*//')")
    done
    # Skip rather than pass silently if the seed has no owner:human task — a
    # green result here would otherwise mean "nothing was checked".
    [ "${#humans[@]}" -gt 0 ] || skip "seed set contains no owner:human onboarding task to exempt"

    ( cd "$GDIR/proj" && env -u FRAMEWORK_ROOT -u PROJECT_ROOT HOME="$GDIR/home" \
        ./.agentic-framework/bin/fw work-on "unrelated feature" --type build ) > /dev/null 2>&1

    local payload
    payload=$(printf '{"tool_name":"Write","tool_input":{"file_path":"%s/src/app.py","content":"x"}}' "$GDIR/proj")
    run bash -c "printf '%s' '$payload' | env -u FRAMEWORK_ROOT PROJECT_ROOT='$GDIR/proj' CLAUDECODE=1 '$GDIR/proj/.agentic-framework/bin/fw' hook check-active-task 2>&1"

    [ "$status" -eq 2 ]
    [[ "$output" == *"Onboarding tasks incomplete"* ]]
    for id in "${humans[@]}"; do
        [[ "$output" != *"$id"* ]] || {
            printf 'owner:human onboarding task %s appears in the blocking list\n' "$id" >&2
            false
        }
    done
}
