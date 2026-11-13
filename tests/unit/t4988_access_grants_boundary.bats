#!/usr/bin/env bats
# T-4988 (T-4965 GO): the operator-owned grant file policy/access-grants.yaml, read from HEAD only.
# Read and create grants are readable by typed commands; the grant file and policy/ are never
# written by the agent; an uncommitted edit grants nothing; writes outside stay refused (the
# create level opens in slice 2, T-4989).

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    HOOK="$FRAMEWORK_ROOT/agents/context/check-project-boundary.sh"
    P="$TEST_TEMP_DIR/proj"
    mkdir -p "$P/policy" "$P/.context/working"
    printf 'project_name: g\nversion: 1.0\n' > "$P/.framework.yaml"
    cat > "$P/policy/access-grants.yaml" <<'YAML'
grants:
  - path: /srv/fwt-share/ro
    level: read
    via: /srv/fwt-share
  - path: /srv/fwt-share/create
    level: create
    via: /srv/fwt-share
never_write: [/srv/fwt-admin]
YAML
    git -C "$P" init -q
    git -C "$P" add -A
    git -C "$P" -c user.name=t -c user.email=t@t commit -q -m "grants" -m "Grants-Change: operator"
    export PROJECT_ROOT="$P"
}

hook() {
    local payload
    payload=$(python3 -c '
import json, sys
tool, arg = sys.argv[1], sys.argv[2]
ti = {"command": arg} if tool == "Bash" else {"file_path": arg, "content": "x"}
print(json.dumps({"tool_name": tool, "tool_input": ti}))' "$1" "$2")
    echo "$payload" | (cd "$P" && bash "$HOOK")
}

allows() { run hook "$1" "$2"; [ "$status" -eq 0 ]; }
blocks() { run hook "$1" "$2"; [ "$status" -eq 2 ]; }

@test "read grant: typed read passes" { allows Bash 'ls /srv/fwt-share/ro/x'; }
@test "create grant: typed read passes" { allows Bash 'cat /srv/fwt-share/create/y'; }
@test "an ungranted sibling stays refused" { blocks Bash 'cat /srv/fwt-share/other'; }
@test "never_write root is not readable either (no grant)" { blocks Bash 'cat /srv/fwt-admin/z'; }
# (slice 2, T-4989, opened writes on the create grant; t4989_access_grants_create_level.bats)
@test "a read grant is not writable" { blocks Bash 'echo x > /srv/fwt-share/ro/y'; }
@test "never_write: typed write refused" { blocks Bash 'echo x > /srv/fwt-admin/z'; }

@test "grant file: Bash append refused" { blocks Bash "echo x >> $P/policy/access-grants.yaml"; }
@test "grant file: sed -i refused" { blocks Bash "sed -i s/a/b/ $P/policy/access-grants.yaml"; }
@test "grant file: moving its directory refused" { blocks Bash "mv $P/policy $P/policy.old"; }
@test "grant file: Write tool refused" { blocks Write "$P/policy/access-grants.yaml"; }
@test "control: another file in policy/ stays writable" {
    allows Bash "echo x > $P/policy/other.yaml"
    allows Write "$P/policy/other.yaml"
}
@test "control: a command that only names the project root is not a grant-file write" {
    allows Bash "cd $P && echo x > notes.txt"
}

@test "an uncommitted edit grants nothing" {
    # a valid, wider grant file in the working tree, not committed
    printf 'grants:\n  - path: /srv/fwt-extra\n    level: read\n    via: /srv/fwt-extra\n' > "$P/policy/access-grants.yaml"
    python3 "$FRAMEWORK_ROOT/lib/access_grants.py" show "$P" > "$TEST_TEMP_DIR/show.out"
    ! grep -q fwt-extra "$TEST_TEMP_DIR/show.out" || false
    blocks Bash 'cat /srv/fwt-extra/a'
    allows Bash 'ls /srv/fwt-share/ro/x'
}

@test "control: without a grant file, policy/ is ordinary" {
    # T-5034: keep policy/ itself. `git rm` of its only file removed the folder, so the mv
    # below moved nothing; a MISSING policy/ is now guarded (it could be created with a
    # prepared grant file inside, see t5034_grant_file_bootstrap.bats).
    printf 'x: 1\n' > "$P/policy/other.yaml"
    git -C "$P" add policy/other.yaml
    git -C "$P" rm -q policy/access-grants.yaml
    git -C "$P" -c user.name=t -c user.email=t@t commit -q -m "drop grants"
    allows Bash "mv $P/policy $P/policy.old"
    blocks Bash 'ls /srv/fwt-share/ro/x'
}
