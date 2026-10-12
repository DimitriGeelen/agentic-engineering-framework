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

_verdict() {
    local root="$1" cmd="$2" json
    json="$(python3 -c 'import json,sys; print(json.dumps({"tool_name":"Bash","tool_input":{"command":sys.argv[1]}}))' "$cmd")"
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
        v="$(_verdict "$r" "$c")"
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
    [ "$(_verdict "$r" "$c")" = "ADMITTED" ]
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
