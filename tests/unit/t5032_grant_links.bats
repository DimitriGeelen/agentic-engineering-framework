#!/usr/bin/env bats
# T-5032 (ring20-dashboard a14cb4c1, HIGH): no typed command creates or carries a link into a
# create grant. Plain and dereferencing copies stay allowed; link verbs outside any grant keep
# today's verdict.

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
  - path: /srv/fwt-share/create
    level: create
    via: /srv/fwt-share
never_write: [/srv/fwt-admin]
YAML
    git -C "$P" init -q
    git -C "$P" add -A
    git -C "$P" -c user.name=t -c user.email=t@t commit -q -m "grants" -m "Grants-Change: operator"
    export PROJECT_ROOT="$P"
    S="$TEST_TEMP_DIR/src"; mkdir -p "$S/dirlinks" "$S/plaindir"
    echo data > "$S/file.txt"
    echo data > "$S/plaindir/a.txt"
    ln -s /etc/passwd "$S/link"
    ln -s /etc "$S/dirlinks/out"
}

teardown() { rm -rf "$TEST_TEMP_DIR"; }

hook() {   # hook CMD [CWD] — CWD is the session cwd Claude Code puts in the payload
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
blocks() { run hook "$1" "${2:-}"; [ "$status" -eq 2 ] || { echo "status=$status $output"; false; }; [[ "$output" == *"T-5032"* ]] || { echo "not T-5032: $output"; false; }; }

# ── refused: link creation into the grant ──
@test "ln -s into the grant"                  { blocks "ln -s /etc/passwd $C/x"; }
@test "ln (hard) into the grant"              { blocks "ln $S/file.txt $C/x"; }
@test "ln -s with a relative name, session cwd in the grant" { blocks "ln -s /etc/passwd x" "$C"; }
@test "ln -s with one argument, session cwd in the grant" { blocks "ln -s /etc/passwd" "$C"; }
@test "a typed cd into the grant before ln is refused (earlier rule)" {
    run hook "cd $C && ln -s /etc/passwd x"; [ "$status" -eq 2 ]
}
@test "ln -t DIR into the grant"              { blocks "ln -s -t $C /etc/passwd"; }
@test "cp -s into the grant"                  { blocks "cp -s $S/file.txt $C/x"; }
@test "cp --symbolic-link into the grant"     { blocks "cp --symbolic-link $S/file.txt $C/x"; }
@test "cp -l into the grant"                  { blocks "cp -l $S/file.txt $C/x"; }

# ── refused: carrying an existing link in ──
@test "mv of a symlink into the grant"        { blocks "mv $S/link $C/x"; }
@test "mv of a folder that holds a symlink"   { blocks "mv $S/dirlinks $C/"; }
@test "cp -a of a symlink into the grant"     { blocks "cp -a $S/link $C/x"; }
@test "cp -r of a folder that holds a symlink" { blocks "cp -r $S/dirlinks $C/"; }
@test "rsync -a of a folder that holds a symlink" { blocks "rsync -a $S/dirlinks/ $C/d/"; }
@test "quoted link source is still seen"      { blocks "mv \"$S/link\" '$C/x'"; }

# ── allowed: no link reaches the grant ──
@test "control: plain cp of a regular file"   { allows "cp $S/file.txt $C/x"; }
@test "control: mv of a regular file"         { allows "mv $S/file.txt $C/x"; }
@test "control: cp of a symlink WITHOUT -a copies its content" { allows "cp $S/link $C/x"; }
@test "control: cp -aL of a symlink (dereferenced)" { allows "cp -aL $S/link $C/x"; }
@test "control: rsync -aL of a folder with links (dereferenced)" { allows "rsync -aL $S/dirlinks/ $C/d/"; }
@test "control: rsync -a --no-links"          { allows "rsync -a --no-links $S/dirlinks/ $C/d/"; }
@test "control: rsync -a of a folder without links" { allows "rsync -a $S/plaindir/ $C/d/"; }
@test "control: cp -r of a folder without links" { allows "cp -r $S/plaindir $C/"; }
@test "control: ln -s inside /tmp, outside any grant" { allows "ln -s /etc/passwd $TEST_TEMP_DIR/l"; }
