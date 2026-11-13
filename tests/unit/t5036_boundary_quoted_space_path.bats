#!/usr/bin/env bats
# T-5036 (050 msg 86069e19): a quoted path containing a space is ONE path to the boundary
# hook. Under a grant whose folder name has a space, typed commands were refused with
# "Outside-path argument …/106" because the quoted argument was split at the space.
# Refusals must not weaken: outside every grant, read-level write, never_write still refused.

load ../test_helper

# The GRANTED folder itself has a space (050's case): its left half is outside the grant.
G='/srv/fwt-share/106 Kuhlhausen'
R='/srv/fwt-share/ro 2'

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    HOOK="$FRAMEWORK_ROOT/agents/context/check-project-boundary.sh"
    P="$TEST_TEMP_DIR/proj"
    mkdir -p "$P/policy" "$P/.context/working"
    printf 'project_name: g\nversion: 1.0\n' > "$P/.framework.yaml"
    cat > "$P/policy/access-grants.yaml" <<'YAML'
grants:
  - path: /srv/fwt-share/ro 2
    level: read
    via: /srv/fwt-share
  - path: /srv/fwt-share/106 Kuhlhausen
    level: create
    via: /srv/fwt-share
  - path: /mnt/nas-t5036-create/508-Sprin-D
    level: create
    via: /mnt/nas-t5036-create
  - path: /mnt/nas-t5036-create/106 Kuhlhausen/0200-SonneStall-Entwicklung
    level: create
    via: /mnt/nas-t5036-create
never_write: [/srv/fwt-admin]
YAML
    git -C "$P" init -q
    git -C "$P" add -A
    git -C "$P" -c user.name=t -c user.email=t@t commit -q -m "grants" -m "Grants-Change: operator"
    export PROJECT_ROOT="$P"
}

teardown() { rm -rf "$TEST_TEMP_DIR"; }

hook() {
    local payload
    payload=$(python3 -c '
import json, sys
print(json.dumps({"tool_name": "Bash", "tool_input": {"command": sys.argv[1]}}))' "$1")
    echo "$payload" | (cd "$P" && bash "$HOOK")
}

allows() { run hook "$1"; [ "$status" -eq 0 ] || { echo "$output"; false; }; }
blocks() { run hook "$1"; [ "$status" -eq 2 ] || { echo "status=$status $output"; false; }; }

# ── allowed: a granted folder whose name has a space ──
@test "find on a double-quoted granted path with a space" { allows "find \"$G/0200-x\" -name '*.pdf'"; }
@test "ls on a single-quoted granted path with a space"   { allows "ls -la '$G'"; }
@test "cat of a file under a quoted granted path"         { allows "cat \"$G/notes.txt\""; }
@test "read-level grant: reading a quoted path with a space" { allows "cat \"$R/a.txt\""; }
@test "write into a quoted create-granted path with a space" { allows "echo x > \"$G/new.txt\""; }
@test "copy into a quoted create-granted path with a space"  { allows "cp /tmp/a \"$G/b c.txt\""; }

@test "050's exact command: find over two granted paths, one quoted with a space" {
    allows 'find /mnt/nas-t5036-create/508-Sprin-D "/mnt/nas-t5036-create/106 Kuhlhausen/0200-SonneStall-Entwicklung" -type l'
}

# ── still refused ──
@test "the parent of a nested granted folder with a space stays outside" {
    blocks 'ls "/mnt/nas-t5036-create/106 Kuhlhausen"'
}
@test "quoted path with a space outside every grant" { blocks "cat \"/srv/fwt-share/other/106 Kuhlhausen/a\""; }
@test "write to a quoted read-level path with a space" { blocks "echo x > \"$R/y.txt\""; }
@test "never_write path with a space"                 { blocks "echo x > \"/srv/fwt-admin/a b/z\""; }
@test "unquoted path with a space is two words, as bash reads it: the stray half is judged" {
    blocks "cat /srv/fwt-share/106 Kuhlhausen/a"
}
@test "quoting does not hide another project's path" { blocks "cat \"/opt/010-termlink/a b.txt\""; }
