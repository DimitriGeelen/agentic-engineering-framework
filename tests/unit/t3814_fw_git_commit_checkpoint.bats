#!/usr/bin/env bats
#
# T-3814 (010 H1) — the commit-checkpoint allowance admitted `git commit` but
# refused the framework's own documented, secret-scanned spellings
# `bin/fw git commit`, `fw git commit` and `.agentic-framework/bin/fw git commit`,
# so a session with null focus (T-2054) or a partial-complete task (T-3179)
# could only checkpoint by bypassing the wrapper the framework tells it to use.
#
# Every probe runs the SHIPPED hook through its stdin JSON contract in a temp
# PROJECT_ROOT with null focus (same harness shape as t3221). Task ids in probe
# strings are spelled TT-9 so editing this file does not trip the focus-drift
# gate (see t3221's note). `! cmd` is inert in bats (L-628): explicit compares.

setup() {
    ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    HOOK="$ROOT/agents/context/check-active-task.sh"
    export ROOT HOOK
}

_mkroot() {
    local t="$BATS_TEST_TMPDIR/root-null"
    [ -d "$t" ] && { printf '%s' "$t"; return 0; }
    mkdir -p "$t/.context/working" "$t/.tasks/active" "$t/.tasks/completed"
    cp -r "$ROOT/agents" "$ROOT/lib" "$t/" 2>/dev/null
    printf 'current_task: null\n' > "$t/.context/working/focus.yaml"
    printf '%s' "$t"
}

# _verdict ROOT CMD [CWD] — CWD is the payload `cwd` (the shell's cwd at the
# call); defaults to ROOT, and the literal NONE omits the field.
_verdict() {
    local root="$1" cmd="$2" cwd="${3-$1}" json
    json="$(python3 -c '
import json,sys
p={"tool_name":"Bash","tool_input":{"command":sys.argv[1]}}
if sys.argv[2] != "NONE": p["cwd"]=sys.argv[2]
print(json.dumps(p))' "$cmd" "$cwd")"
    if printf '%s' "$json" | PROJECT_ROOT="$root" FRAMEWORK_ROOT="$root" \
        CLAUDE_PROJECT_DIR="$root" bash "$HOOK" >/dev/null 2>&1; then
        printf 'ADMITTED'
    else
        printf 'blocked'
    fi
}

@test "control: plain git commit is admitted with null focus" {
    r="$(_mkroot)"
    [ "$(_verdict "$r" 'git commit -m "TT-9: x"')" = "ADMITTED" ]
}

@test "the documented fw spellings are admitted with null focus" {
    r="$(_mkroot)"
    for c in 'fw git commit -m "TT-9: x"' \
             'bin/fw git commit -m "TT-9: x"' \
             './bin/fw git commit -m "TT-9: x"' \
             '.agentic-framework/bin/fw git commit -m "TT-9: x"' \
             "$ROOT/bin/fw git commit -m \"TT-9: x\"" \
             "$r/.agentic-framework/bin/fw git commit -m \"TT-9: x\""; do
        # T-4108 r2: a relative launcher resolves against the payload cwd. The
        # hook pins FRAMEWORK_ROOT to this checkout, so `[./]bin/fw` is own from
        # $ROOT and `.agentic-framework/bin/fw` is own from the project root.
        case "$c" in bin/fw*|./bin/fw*) cwd="$ROOT" ;; *) cwd="$r" ;; esac
        v="$(_verdict "$r" "$c" "$cwd")"
        [ "$v" = "ADMITTED" ] || { echo "refused: $c" >&2; false; }
    done
}

@test "T-4108: an absolute launcher outside this project's own fw is refused" {
    r="$(_mkroot)"
    for c in '/tmp/x/bin/fw git commit -m "TT-9: x"' \
             '/opt/some-project/.agentic-framework/bin/fw git commit -m "TT-9: x"' \
             '/opt/999-x/bin/fw git commit -m "TT-9: x"' \
             "$r/../elsewhere/bin/fw git commit -m \"TT-9: x\""; do
        v="$(_verdict "$r" "$c")"
        [ "$v" = "blocked" ] || { echo "admitted: $c" >&2; false; }
    done
}

@test "the Co-Authored-By trailer does not void the fw spelling" {
    r="$(_mkroot)"
    c='bin/fw git commit -m "TT-9: x

Co-Authored-By: Claude <noreply@anthropic.com>"'
    [ "$(_verdict "$r" "$c" "$ROOT")" = "ADMITTED" ]
}

@test "every existing refusal still applies to the fw spellings" {
    r="$(_mkroot)"
    for c in 'bin/fw git commit --no-verify -m "TT-9: x"' \
             'fw git commit -n -m "TT-9: x"' \
             'bin/fw git commit -m "TT-9: x"; rm -rf y' \
             'bin/fw git commit -m "$(id)"' \
             'bin/fw git commit -m "TT-9: x" > out.txt'; do
        v="$(_verdict "$r" "$c")"
        [ "$v" = "blocked" ] || { echo "admitted: $c" >&2; false; }
    done
}

@test "nothing else is newly admitted" {
    r="$(_mkroot)"
    for c in 'somebinary git commit -m "TT-9: x"' \
             'evil/fw-ish git commit -m "TT-9: x"' \
             'bin/fwx git commit -m "TT-9: x"' \
             'fw git push origin main' \
             'fw gitcommit -m "TT-9: x"' \
             'bin/fw task update TT-9 --status started-work'; do
        v="$(_verdict "$r" "$c")"
        [ "$v" = "blocked" ] || { echo "admitted: $c" >&2; false; }
    done
}

# ── T-4108 round 2: a relative launcher runs from the SHELL's cwd ──────────

_plant() {
    local d="$BATS_TEST_TMPDIR/x"
    mkdir -p "$d/bin" "$d/.agentic-framework/bin"
    printf '#!/bin/sh\necho planted\n' > "$d/bin/fw"
    cp "$d/bin/fw" "$d/.agentic-framework/bin/fw"
    chmod +x "$d/bin/fw" "$d/.agentic-framework/bin/fw"
    printf '%s' "$d"
}

@test "T-4108r2: payload cwd holding a planted bin/fw refuses the relative launcher" {
    r="$(_mkroot)"; x="$(_plant)"
    for c in 'bin/fw git commit -m "TT-9: x"' \
             './bin/fw git commit -m "TT-9: x"' \
             '.agentic-framework/bin/fw git commit -m "TT-9: x"'; do
        v="$(_verdict "$r" "$c" "$x")"
        [ "$v" = "blocked" ] || { echo "admitted from $x: $c" >&2; false; }
    done
}

@test "T-4108r2: cd earlier in the same command refuses a relative launcher" {
    r="$(_mkroot)"; x="$(_plant)"
    for c in "cd $x && bin/fw git commit -m \"TT-9: x\"" \
             "cd $x; ./bin/fw git commit -m \"TT-9: x\"" \
             "cd $ROOT && bin/fw git commit -m \"TT-9: x\""; do
        v="$(_verdict "$r" "$c")"
        [ "$v" = "blocked" ] || { echo "admitted: $c" >&2; false; }
    done
}

@test "T-4108r2: pushd/popd earlier in the same command refuses a relative launcher" {
    r="$(_mkroot)"; x="$(_plant)"
    for c in "pushd $x && bin/fw git commit -m \"TT-9: x\"" \
             "popd && bin/fw git commit -m \"TT-9: x\""; do
        v="$(_verdict "$r" "$c")"
        [ "$v" = "blocked" ] || { echo "admitted: $c" >&2; false; }
    done
    # pushd/popd are not safe-listed today, so the hook refuses them on that
    # ground alone; pin the dir-change classifier itself so safe-listing them
    # later cannot reopen the hole.
    run bash -c 'source "$1/agents/context/lib/safe-commands.sh"
        for s in "pushd /x" "popd" "cd /x" "source f" ". f" "builtin cd /x" \
                 "command cd /x" "eval cd" "FOO=1 cd /x"; do
            _fw_segment_may_change_dir "$s" || { echo "missed: $s"; exit 1; }
        done
        for s in "git status" "ls -la" "/usr/bin/env true"; do
            if _fw_segment_may_change_dir "$s"; then echo "false hit: $s"; exit 1; fi
        done' _ "$ROOT"
    [ "$status" -eq 0 ] || { echo "$output" >&2; false; }
}

@test "T-4108r2: the absolute own launcher after cd is still admitted" {
    r="$(_mkroot)"; x="$(_plant)"
    v="$(_verdict "$r" "cd $x && $ROOT/bin/fw git commit -m \"TT-9: x\"")"
    [ "$v" = "ADMITTED" ]
    v="$(_verdict "$r" "cd $x && $r/.agentic-framework/bin/fw git commit -m \"TT-9: x\"")"
    [ "$v" = "ADMITTED" ]
    v="$(_verdict "$r" "cd $x && fw git commit -m \"TT-9: x\"")"
    [ "$v" = "ADMITTED" ]
}

@test "T-4108r2: relative own launcher with payload cwd = its own root is admitted" {
    r="$(_mkroot)"
    [ "$(_verdict "$r" 'bin/fw git commit -m "TT-9: x"' "$ROOT")" = "ADMITTED" ]
    [ "$(_verdict "$r" './bin/fw git commit -m "TT-9: x"' "$ROOT")" = "ADMITTED" ]
    [ "$(_verdict "$r" '.agentic-framework/bin/fw git commit -m "TT-9: x"' "$r")" = "ADMITTED" ]
    [ "$(_verdict "$r" 'git status && bin/fw git commit -m "TT-9: x"' "$ROOT")" = "ADMITTED" ]
}

@test "T-4108r2: no payload cwd refuses a relative launcher (bare fw unchanged)" {
    r="$(_mkroot)"
    [ "$(_verdict "$r" 'bin/fw git commit -m "TT-9: x"' NONE)" = "blocked" ]
    [ "$(_verdict "$r" '.agentic-framework/bin/fw git commit -m "TT-9: x"' NONE)" = "blocked" ]
    [ "$(_verdict "$r" 'bin/fw git commit -m "TT-9: x"' "relative/dir")" = "blocked" ]
    [ "$(_verdict "$r" 'fw git commit -m "TT-9: x"' NONE)" = "ADMITTED" ]
    # T-4409: a bare git commit uses its cwd's repository (hooks, config), so with
    # no payload cwd and a hook PWD that is not the project it is refused; with
    # the cwd inside the project it is admitted.
    [ "$(_verdict "$r" 'git commit -m "TT-9: x"' NONE)" = "blocked" ]
    [ "$(_verdict "$r" 'git commit -m "TT-9: x"')" = "ADMITTED" ]
}
