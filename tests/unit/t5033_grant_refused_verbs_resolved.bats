#!/usr/bin/env bats
# T-5033 (ring20-dashboard a14cb4c1): the refusal of metadata changes and archive extraction
# on create-granted paths (T-4989) judges what the command ACTS ON, not whether the grant's
# text appears in it: a glob, the command's own variables, a relative operand from a cwd in
# the grant. Refused verbs elsewhere keep today's verdict.

load ../test_helper

C=/srv/fwt-share/create

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

teardown() { rm -rf "$TEST_TEMP_DIR"; }

hook() {   # hook CMD [CWD]
    local payload
    payload=$(python3 -c '
import json, sys
d = {"tool_name": "Bash", "tool_input": {"command": sys.argv[1]}}
if len(sys.argv) > 2 and sys.argv[2]:
    d["cwd"] = sys.argv[2]
print(json.dumps(d))' "$1" "${2:-}")
    echo "$payload" | (cd "$P" && bash "$HOOK")
}
allows() { run hook "$1" "${2:-}"; [ "$status" -eq 0 ] || { echo "status=$status $output"; false; }; }
blocks() { run hook "$1" "${2:-}"; [ "$status" -eq 2 ] || { echo "status=$status $output"; false; }; [[ "$output" == *"T-5033"* ]] || { echo "not T-5033: $output"; false; }; }

# ── refused: the grant is reached without its text appearing ──
@test "glob that expands into the grant: chmod /srv/fwt-share/cr*" { blocks "chmod 777 /srv/fwt-share/cr*"; }
@test "glob one level up: touch /srv/fwt-share/*/x"               { blocks "touch /srv/fwt-share/*/x"; }
@test "the command's own variable: D=/srv/fwt-sh; chmod \${D}are/create/x" {
    blocks 'D=/srv/fwt-sh; chmod 777 ${D}are/create/x'
}
@test "export of a variable, then chown \$D/x"                    { blocks 'export D=/srv/fwt-share/create; chown 1000 $D/x'; }
@test "unknown variable after a grant-reaching head: chmod /srv/\$X" { blocks 'chmod 777 /srv/$X'; }
@test "session cwd in the grant: bare relative chmod"             { blocks "chmod 777 x" "$C"; }
@test "session cwd in the grant: tar extraction names no path"    { blocks "tar xf /tmp/a.tar" "$C"; }
@test "unzip -d into the grant (still refused)"                   { blocks "unzip /tmp/a.zip -d $C/out"; }
@test "literal grant path (today's case, still refused)"          { blocks "touch $C/x"; }

# ── kept: no grant reached ──
@test "control: chmod in the project"            { allows "chmod 644 $P/policy/access-grants.yaml.bak 2>/dev/null; true"; }
@test "control: touch in /tmp"                   { allows "touch /tmp/t5033-x"; }
@test "control: glob that cannot reach a grant"  { allows "chmod 644 /tmp/t5033-*"; }
@test "control: an unknown variable alone, cwd in the project" { allows 'touch "$TMPFILE"'; }
@test "control: plain write into the create grant" { allows "echo x > $C/y"; }
@test "control: tar c from the READ grant into /tmp is a read" { allows "tar czf /tmp/t5033.tgz -C /srv/fwt-share/ro ."; }
@test "control: touch in the project after a command that mentions the grant" {
    allows "ls $C && touch $P/notes.txt"
}
