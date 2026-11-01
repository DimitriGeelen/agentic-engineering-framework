#!/usr/bin/env bats
# T-4989 (T-4965 GO, slice 2): typed create, modify, rename and delete are allowed on a
# create-level grant (the NAS judges ownership); a read grant, an ungranted path and a
# never_write root stay refused; metadata changes and archive extraction on granted paths are
# refused; allowed grant writes are logged. Includes 050's four acceptance cases.

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

C=/srv/fwt-share/create

# ── allowed on the create grant ──
@test "create: redirect write" { allows Bash "echo x > $C/y"; }
@test "create: rename within the grant" { allows Bash "mv $C/a $C/b"; }
@test "create: delete own file (the NAS judges ownership)" { allows Bash "rm $C/a"; }
@test "create: mkdir -p" { allows Bash "mkdir -p $C/new/dir"; }
@test "create: copy in from the project or /tmp" { allows Bash "cp /tmp/a $C/b"; }
@test "create: variable that assigns a granted path" { allows Bash "p=$C/x; echo x > \"\$p\""; }
@test "create: Write tool" { allows Write "$C/w.txt"; }

# ── refused ──
@test "050 case 1: a write outside every grant is refused" { blocks Bash 'echo x > /srv/fwt-share/other'; }
@test "read grant is not writable" { blocks Bash 'echo x > /srv/fwt-share/ro/y'; }
@test "read grant: Write tool refused" { blocks Write '/srv/fwt-share/ro/w.txt'; }
@test "never_write: Bash refused" { blocks Bash 'echo x > /srv/fwt-admin/z'; }
@test "never_write: Write tool refused" { blocks Write '/srv/fwt-admin/w.txt'; }
@test "move out of the grant to an ungranted path refused" { blocks Bash "mv $C/a /srv/fwt-share/other/b"; }
@test "variable assigning an ungranted outside path stays refused (T-4983)" {
    blocks Bash 'p=/srv/fwt-share/other/x; echo x > "$p"'
}
@test "chmod on a granted path refused" { blocks Bash "chmod 600 $C/y"; }
@test "touch on a granted path refused" { blocks Bash "touch $C/y"; }
@test "chown via a cd into the grant refused" { blocks Bash "cd $C && chown root y"; }
@test "tar extraction into the grant refused" { blocks Bash "tar -xf /tmp/a.tar -C $C"; }
@test "unzip into the grant refused" { blocks Bash "unzip /tmp/a.zip -d $C"; }
@test "050 case 4: the agent cannot edit the grant file" {
    blocks Write "$P/policy/access-grants.yaml"
    blocks Bash "echo x >> $P/policy/access-grants.yaml"
}

@test "a symlink inside the grant that points outside is refused" {
    mkdir -p "$TEST_TEMP_DIR/elsewhere"
    # write_allowed() resolves the path; simulate a grant dir holding a link to elsewhere
    run python3 -c "
import sys; sys.path.insert(0, '$FRAMEWORK_ROOT/lib'); import access_grants as ag, os
g = '$TEST_TEMP_DIR/g'; os.makedirs(g, exist_ok=True)
link = os.path.join(g, 'out')
os.path.islink(link) or os.symlink('$TEST_TEMP_DIR/elsewhere', link)
print(ag.write_allowed(os.path.join(link, 'f'), [g], []), ag.write_allowed(os.path.join(g, 'f'), [g], []))"
    [ "$output" = "False True" ]
}

@test "an allowed grant write is logged; a refused one is not" {
    run hook Bash "echo x > $C/logged"
    [ "$status" -eq 0 ]
    grep -q '"target": "/srv/fwt-share/create/logged"' "$P/.context/grants/audit.jsonl"
    run hook Bash 'echo x > /srv/fwt-share/other/not-logged'
    ! grep -q not-logged "$P/.context/grants/audit.jsonl" || false
}

@test "control: without a grant file the create path is refused" {
    git -C "$P" rm -q policy/access-grants.yaml
    git -C "$P" -c user.name=t -c user.email=t@t commit -q -m "drop grants"
    blocks Bash "echo x > $C/y"
}
