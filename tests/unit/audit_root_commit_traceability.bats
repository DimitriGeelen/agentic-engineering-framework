#!/usr/bin/env bats
# T-2851 — the audit's commit-traceability check must exempt ROOT commits.
#
# `fw init` closes with a bootstrap commit subject `T-000: fw init bootstrap …`
# so the new project has a resolvable HEAD (lib/init.sh:742). `T-000` satisfies
# the commit-msg hook, which only requires the subject to MATCH `T-[0-9]+`, but
# it never resolves to a task file — so the audit's existence check fired on it
# and every fresh project failed its own traceability audit on day zero.
#
# Both directions are asserted here. The exemption test alone would be satisfied
# by a "fix" that disabled the check outright, which is the failure mode this
# whole family keeps producing (T-2843/T-2844/T-2845: green about the wrong
# object). The negative control is the load-bearing half.

setup_file() {
    FW_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    export FW_ROOT

    GITFX="$(mktemp -d)"
    export GITFX

    # Its own repo. The enclosing directory may itself be inside a git repo (on
    # this host /tmp has been one — T-2850); an explicit `git init` here means
    # every `git -C "$GITFX"` below resolves to THIS history regardless.
    git -C "$GITFX" init -q
    git -C "$GITFX" config user.email "t2851@localhost"
    git -C "$GITFX" config user.name "T-2851 fixture"

    # Root commit — the fw init bootstrap shape.
    git -C "$GITFX" commit -q --allow-empty -m "T-000: fw init bootstrap commit (framework scaffolding)"
    ROOT_SHA="$(git -C "$GITFX" rev-parse HEAD)"
    export ROOT_SHA

    # Child commit referencing an equally non-existent task.
    git -C "$GITFX" commit -q --allow-empty -m "T-999999: a task that was never created"
    CHILD_SHA="$(git -C "$GITFX" rev-parse HEAD)"
    export CHILD_SHA
}

teardown_file() {
    [ -n "${GITFX:-}" ] && [ -d "$GITFX" ] && rm -rf "$GITFX"
    return 0
}

setup() {
    # shellcheck source=/dev/null
    source "$FW_ROOT/lib/traceability.sh"
}

@test "fixture is a distinct repo with exactly two commits" {
    # Anti-vacuity anchor: if the fixture silently resolved to an ENCLOSING
    # repository, both assertions below would be measuring someone else's
    # history and could pass or fail for reasons having nothing to do with
    # the predicate (T-2850: contamination that answers plausibly).
    run git -C "$GITFX" rev-list --count HEAD
    [ "$status" -eq 0 ]
    [ "$output" = "2" ]
    [ "$ROOT_SHA" != "$CHILD_SHA" ]
}

@test "root commit is recognised as parentless" {
    run trace_is_root_commit "$GITFX" "$ROOT_SHA"
    [ "$status" -eq 0 ]
}

@test "NEGATIVE CONTROL: a non-root commit is NOT exempt" {
    # Without this, a fix that made trace_is_root_commit return 0 unconditionally
    # — or that removed the traceability check altogether — would satisfy every
    # other test in this file.
    run trace_is_root_commit "$GITFX" "$CHILD_SHA"
    [ "$status" -ne 0 ]
}

@test "predicate does not blow up on a bad sha or empty args" {
    run trace_is_root_commit "$GITFX" "definitely-not-a-sha"
    [ "$status" -ne 0 ]
    run trace_is_root_commit "" ""
    [ "$status" -ne 0 ]
}

@test "the audit actually SOURCES and CALLS the predicate" {
    # A correct lib that nothing invokes is the T-2845 shape: 4/4 tests green,
    # zero change live. Assert the wiring, not just the definition.
    run grep -q 'source "\$FRAMEWORK_ROOT/lib/traceability.sh"' "$FW_ROOT/agents/audit/audit.sh"
    [ "$status" -eq 0 ]
    run grep -q 'trace_is_root_commit "\$PROJECT_ROOT" "\$commit_sha"' "$FW_ROOT/agents/audit/audit.sh"
    [ "$status" -eq 0 ]
}

@test "the exemption is keyed on parentlessness, not on the T-000 sentinel" {
    # Keying on the literal string would let any commit opt out of P-002 by
    # writing `T-000:`. Assert the predicate ignores the subject entirely: a
    # root commit with an ORDINARY task ref is still root, and a child commit
    # carrying the sentinel is still NOT exempt.
    local alt sentinel_child
    alt="$(mktemp -d)"
    git -C "$alt" init -q
    git -C "$alt" config user.email "t2851@localhost"
    git -C "$alt" config user.name "T-2851 fixture"
    git -C "$alt" commit -q --allow-empty -m "T-4242: an ordinary first commit"
    run trace_is_root_commit "$alt" "$(git -C "$alt" rev-parse HEAD)"
    [ "$status" -eq 0 ]

    git -C "$alt" commit -q --allow-empty -m "T-000: sentinel on a non-root commit"
    sentinel_child="$(git -C "$alt" rev-parse HEAD)"
    run trace_is_root_commit "$alt" "$sentinel_child"
    [ "$status" -ne 0 ]

    rm -rf "$alt"
}
