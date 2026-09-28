#!/usr/bin/env bats
# T-3534: project identity — minted once, shared by instances, never derived
# from a path or a name.
#
# THE INVARIANT UNDER TEST
#
#   Operator, 2026-09-28: "sometimes we also want to have different instances of
#   a project and we definitely want the same id. Only if you fork it, then it
#   should be a separate process."
#
# So the properties are asymmetric and both need controls:
#   - a clone/copy MUST keep the id (instances are the same project)
#   - a rename or a move MUST keep the id (identity is not a path or a name)
#   - re-running init MUST keep the id (re-identification must never be silent)
#   - two DIFFERENT projects must get DIFFERENT ids
#
# The last one is the control. Without it, a function that returned a constant
# would pass every other test here — the same false-green shape as a length
# threshold standing in for a sufficiency check (OBS-560).

setup() {
    REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    LIB="$REPO_ROOT/lib/project_identity.sh"
    [ -f "$LIB" ] || skip "lib/project_identity.sh not found"
    FIX="$(mktemp -d)"
    mkdir -p "$FIX/proj"
    printf 'project_name: demo\n' > "$FIX/proj/.framework.yaml"
}

teardown() { rm -rf "$FIX" 2>/dev/null; }

_id() { bash -c "source '$LIB'; fw_project_id '$1'"; }
_ensure() { bash -c "source '$LIB'; fw_project_identity_ensure '$1'"; }
_instance() { bash -c "source '$LIB'; fw_project_instance '$1'"; }

# ── minting ───────────────────────────────────────────────────────────────────

@test "t3534: a project with no id gets one" {
    [ -z "$(_id "$FIX/proj")" ]
    run _ensure "$FIX/proj"
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^pid-[0-9a-f]{16}$ ]]
}

@test "t3534: the id persists into .framework.yaml" {
    _ensure "$FIX/proj" > /dev/null
    run grep -c '^project_id: pid-' "$FIX/proj/.framework.yaml"
    [ "$status" -eq 0 ]
}

@test "t3534 CONTROL: two DIFFERENT projects get DIFFERENT ids" {
    mkdir -p "$FIX/other"
    printf 'project_name: other\n' > "$FIX/other/.framework.yaml"
    a=$(_ensure "$FIX/proj")
    b=$(_ensure "$FIX/other")
    [ "$a" != "$b" ]
}

# ── the invariant: minted once ────────────────────────────────────────────────

@test "t3534: re-running ensure PRESERVES the id (re-init must not re-identify)" {
    first=$(_ensure "$FIX/proj")
    second=$(_ensure "$FIX/proj")
    third=$(_ensure "$FIX/proj")
    [ "$first" = "$second" ]
    [ "$second" = "$third" ]
}

@test "t3534: ensure writes exactly ONE project_id line, however often it runs" {
    _ensure "$FIX/proj" > /dev/null
    _ensure "$FIX/proj" > /dev/null
    _ensure "$FIX/proj" > /dev/null
    run bash -c "grep -c '^project_id:' '$FIX/proj/.framework.yaml'"
    [ "$output" -eq 1 ]
}

# ── identity is not a path and not a name ─────────────────────────────────────

@test "t3534: MOVING the project keeps its id" {
    before=$(_ensure "$FIX/proj")
    mv "$FIX/proj" "$FIX/moved-elsewhere"
    after=$(_id "$FIX/moved-elsewhere")
    [ "$before" = "$after" ]
}

@test "t3534: RENAMING project_name does not change the id" {
    before=$(_ensure "$FIX/proj")
    sed -i 's/^project_name: .*/project_name: totally-different/' "$FIX/proj/.framework.yaml"
    after=$(_id "$FIX/proj")
    [ "$before" = "$after" ]
}

# ── instances: same project, different checkouts ──────────────────────────────

@test "t3534: a COPY (clone) shares the project id — instances are one project" {
    before=$(_ensure "$FIX/proj")
    cp -r "$FIX/proj" "$FIX/clone"
    [ "$(_id "$FIX/clone")" = "$before" ]
}

@test "t3534: ...but the two instances are distinguishable" {
    _ensure "$FIX/proj" > /dev/null
    cp -r "$FIX/proj" "$FIX/clone"
    [ "$(_instance "$FIX/proj")" != "$(_instance "$FIX/clone")" ]
}

@test "t3534: the instance string carries id, host and root" {
    id=$(_ensure "$FIX/proj")
    run _instance "$FIX/proj"
    [[ "$output" == "$id@"* ]]
    [[ "$output" == *":"* ]]
}

# ── degraded inputs fail closed, not open ─────────────────────────────────────

@test "t3534: a project with no .framework.yaml reports no id rather than inventing one" {
    mkdir -p "$FIX/bare"
    [ -z "$(_id "$FIX/bare")" ]
}
