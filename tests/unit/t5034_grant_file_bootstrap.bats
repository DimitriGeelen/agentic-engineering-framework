#!/usr/bin/env bats
# T-5034 (ring20-dashboard a14cb4c1, MEDIUM): with NO grant file yet, the agent must not be able
# to create policy/access-grants.yaml by a typed command (self-grant bootstrap). A policy/ folder
# that does not exist is guarded too (creating it could carry a prepared grant file); an existing
# policy/ stays ordinary (T-4988 control).

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    HOOK="$FRAMEWORK_ROOT/agents/context/check-project-boundary.sh"
    P="$TEST_TEMP_DIR/proj"
    mkdir -p "$P/policy" "$P/.context/working"
    printf 'project_name: g\nversion: 1.0\n' > "$P/.framework.yaml"
    printf 'x: 1\n' > "$P/policy/other.yaml"
    git -C "$P" init -q
    git -C "$P" add -A
    git -C "$P" -c user.name=t -c user.email=t@t commit -q -m "no grants"
    export PROJECT_ROOT="$P"
    GF="$P/policy/access-grants.yaml"
}

teardown() { rm -rf "$TEST_TEMP_DIR"; }

hook() {
    local payload
    payload=$(python3 -c '
import json, sys
print(json.dumps({"tool_name": "Bash", "tool_input": {"command": sys.argv[1]}}))' "$1")
    echo "$payload" | (cd "$P" && bash "$HOOK")
}

allows() { run hook "$1"; [ "$status" -eq 0 ] || { echo "status=$status $output"; false; }; }
blocks() { run hook "$1"; [ "$status" -eq 2 ] || { echo "status=$status $output"; false; }; }

# ── no grant file, policy/ exists: the file itself is refused ──
@test "redirect creates the grant file: refused"      { blocks "printf 'grants: []\n' > $GF"; }
@test "relative redirect creates the grant file: refused" { blocks "echo x > policy/access-grants.yaml"; }
@test "tee creates the grant file: refused"           { blocks "echo x | tee $GF"; }
@test "cp creates the grant file: refused"            { blocks "cp /tmp/g.yaml $GF"; }
@test "mv creates the grant file: refused"            { blocks "mv /tmp/g.yaml $GF"; }
@test "the predicate itself says guarded with no grant file" {
    run python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); import access_grants as a; print(a.is_grant_file_or_ancestor(sys.argv[2], sys.argv[3]))' \
        "$FRAMEWORK_ROOT/lib" "$GF" "$P"
    [ "$output" = "True" ]
}

# ── no grant file, policy/ exists: ordinary use stays allowed (T-4988 control) ──
@test "control: mv of an existing policy/ is allowed" { allows "mv $P/policy $P/policy.old"; }
@test "control: other files under policy/ are writable" { allows "echo y: 2 > $P/policy/other.yaml"; }
@test "control: a new file under policy/ is writable"   { allows "echo z > $P/policy/new.yaml"; }

# ── no grant file, no policy/: creating policy/ by a move or copy is refused ──
@test "no policy/: mv of a prepared folder into policy is refused" {
    rm -rf "$P/policy"
    blocks "mv /tmp/prepared $P/policy"
}
@test "no policy/: cp -r of a prepared folder into policy is refused" {
    rm -rf "$P/policy"
    blocks "cp -r /tmp/prepared $P/policy"
}

@test "install creates the grant file: refused" { blocks "install -m 644 /tmp/g.yaml $GF"; }
@test "ln -s creates the grant file: refused"   { blocks "ln -s /tmp/g.yaml $GF"; }
