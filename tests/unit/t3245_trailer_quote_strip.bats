#!/usr/bin/env bats
#
# T-3245 — the mandated Co-Authored-By trailer voided the partial-complete
# bare-commit allowance.
#
# CLAUDE.md requires every commit to carry:
#
#     Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
#
# `is_commit_checkpoint_command` (safe-commands.sh) judged has_bash_write_pattern
# against the RAW command line. The trailer's `<noreply@anthropic.com>` sits
# inside a quoted `-m` argument, and the redirect regex `[^2>&]>[^>&]|>>` cannot
# tell it from a real `<` operator — so a commit carrying the mandated trailer
# was never "bare", and the T-3179 block message's own remedy ("drop the
# redirect and run the commit bare") was unreachable for the trailer the
# framework itself requires. Reproduced live at T-3243's close, T-3246's close,
# and T-3254's close (three occurrences in three days, task body has the
# full log).
#
# Fixed by judging the write-pattern on a quote-stripped view (_fw_strip_quoted,
# the same primitive _fw_is_git_commit_clause already trusts) rather than the
# raw line — scoped to is_commit_checkpoint_command only, not to
# has_bash_write_pattern itself (see the fix's own comment for the blast-radius
# argument).
#
# Structure mirrors tests/unit/t3221_commit_exemption_clause.bats: real hook,
# real stdin JSON, a mutation control derived from live source so reverting the
# fix reddens this suite rather than leaving a frozen copy that agrees with
# itself forever.

setup() {
    ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    HOOK="$ROOT/agents/context/check-active-task.sh"
    export ROOT HOOK
    TRAILER='Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>'
    export TRAILER
}

# Build a throwaway project root with the hook + libs, and a focus state.
# $1 = null | partial ; echoes the root. Mirrors t3221's _mkroot.
_mkroot() {
    local mode="$1" t="$BATS_TEST_TMPDIR/root-$mode"
    [ -d "$t" ] && { printf '%s' "$t"; return 0; }
    mkdir -p "$t/.context/working" "$t/.tasks/active" "$t/.tasks/completed"
    cp -r "$ROOT/agents" "$ROOT/lib" "$t/" 2>/dev/null
    if [ "$mode" = "partial" ]; then
        printf 'current_task: T-9999\n' > "$t/.context/working/focus.yaml"
        printf -- '---\nid: T-9999\nname: "p"\nstatus: work-completed\nworkflow_type: build\nowner: human\n---\n' \
            > "$t/.tasks/active/T-9999-p.md"
    else
        printf 'current_task: null\n' > "$t/.context/working/focus.yaml"
    fi
    printf '%s' "$t"
}

# Run a command past a hook. $1 = project root, $2 = hook path, $3 = command.
_verdict() {
    local root="$1" hook="$2" cmd="$3" json
    json="$(python3 -c 'import json,sys; print(json.dumps({"tool_name":"Bash","tool_input":{"command":sys.argv[1]}}))' "$cmd")"
    if printf '%s' "$json" | PROJECT_ROOT="$root" FRAMEWORK_ROOT="$root" \
        CLAUDE_PROJECT_DIR="$root" bash "$hook" >/dev/null 2>&1; then
        printf 'ADMITTED'
    else
        printf 'blocked'
    fi
}

# Pre-fix mutant: reverts is_commit_checkpoint_command's write-pattern check to
# judge the RAW command instead of the quote-stripped view. Derived from live
# source so reverting the fix reddens this suite.
_mkmutant() {
    local m="$BATS_TEST_TMPDIR/root-mutant"
    [ -d "$m" ] && { printf '%s' "$m"; return 0; }
    cp -r "$(_mkroot null)" "$m"
    python3 - "$m/agents/context/lib/safe-commands.sh" <<'PY' >&2 || return 1
import sys
p = sys.argv[1]
s = open(p).read()
old = ('    local cmd_view\n'
       '    cmd_view="$(_fw_strip_quoted "$cmd")" || cmd_view="$cmd"\n'
       '    has_bash_write_pattern "$cmd_view" && return 1')
new = '    has_bash_write_pattern "$cmd" && return 1'
n = s.count(old)
if n != 1:
    sys.stderr.write("mutation matched %d call sites (want 1)\n" % n)
    sys.exit(1)
s = s.replace(old, new)
open(p, 'w').write(s)
PY
    bash -n "$m/agents/context/lib/safe-commands.sh" || return 1
    printf '%s' "$m"
}

# ── the two commands the task body reproduces the defect with ───────────────

@test "a bare-focus commit carrying the mandated trailer is admitted (null focus, T-2054)" {
    local c="git commit -q -m \"T-3243: partial-complete work\" -m \"$TRAILER\""
    [ "$(_verdict "$(_mkroot null)" "$HOOK" "$c")" = ADMITTED ]
}

@test "a partial-complete commit carrying the mandated trailer is admitted (T-3179)" {
    # T-9999, not T-3243: _mkroot partial focuses T-9999, and the focus-drift
    # gate (T-1730) runs BEFORE the partial-complete status branch — a message
    # naming a different task ID trips drift first and would fail this test
    # for a reason unrelated to the fix under test.
    local c="git commit -q -m \"T-9999: partial-complete work\" -m \"$TRAILER\""
    [ "$(_verdict "$(_mkroot partial)" "$HOOK" "$c")" = ADMITTED ]
}

# NOTE: a `-F -` heredoc form is deliberately NOT tested here. It is refused for
# an unrelated, already-documented reason (task body "Fourth occurrence": the
# heredoc SHAPE itself is not on the read-only allowlist, so it never reaches
# has_bash_write_pattern at all) — a separate gap, out of this task's AC scope.

# ── control legs: fixing the false positive must not open a false negative ──

@test "a REAL redirect outside quotes is still refused (null focus)" {
    [ "$(_verdict "$(_mkroot null)" "$HOOK" 'git commit -m "x" > /tmp/t3245-should-not-happen')" = blocked ]
}

@test "a REAL redirect outside quotes is still refused (partial-complete)" {
    [ "$(_verdict "$(_mkroot partial)" "$HOOK" 'git commit -m "x" > /tmp/t3245-should-not-happen')" = blocked ]
}

@test "rm is still refused (unchanged behaviour, both branches)" {
    [ "$(_verdict "$(_mkroot null)" "$HOOK" 'git commit -m "x" ; rm -rf /tmp/t3245-zzz')" = blocked ]
    [ "$(_verdict "$(_mkroot partial)" "$HOOK" 'git commit -m "x" ; rm -rf /tmp/t3245-zzz')" = blocked ]
}

@test "tee outside quotes is still refused (T-3221 defect 2, unchanged)" {
    [ "$(_verdict "$(_mkroot null)" "$HOOK" 'git commit -m "TT-9: x" | tee /tmp/t3245-zzz')" = blocked ]
    [ "$(_verdict "$(_mkroot partial)" "$HOOK" 'git commit -m "TT-9: x" | tee /tmp/t3245-zzz')" = blocked ]
}

@test "sed -i outside quotes is still refused (unchanged)" {
    [ "$(_verdict "$(_mkroot partial)" "$HOOK" 'git commit -m "x" ; sed -i s/a/b/ f')" = blocked ]
}

@test "an unbalanced quote fails closed, not open" {
    # _fw_strip_quoted returns non-zero on an unterminated quote; cmd_view falls
    # back to the untouched original, which still carries the stray `<` and
    # still blocks. Both failure directions of the stripper must fail toward
    # BLOCKING (same contract t2936 pins for the bootstrap exemption).
    [ "$(_verdict "$(_mkroot partial)" "$HOOK" 'git commit -m "unclosed <noreply@anthropic.com>')" = blocked ]
}

# ── MUTATION CONTROL ─────────────────────────────────────────────────────────

@test "the pre-fix mutant reproduces the deadlock the fix closes" {
    local m; m="$(_mkmutant)"
    local c="git commit -q -m \"T-3243: partial-complete work\" -m \"$TRAILER\""
    [ "$(_verdict "$m" "$m/agents/context/check-active-task.sh" "$c")" = blocked ]
}

@test "the fix admits nothing the pre-fix mutant blocked (no widening)" {
    local m; m="$(_mkmutant)"
    local mh="$m/agents/context/check-active-task.sh"
    local root; root="$(_mkroot partial)"
    local c widened=0
    local -a corpus=(
        'git commit -m "x" ; rm -rf /tmp/t3245-zzz'
        'git commit -m "TT-9: x" | tee /tmp/t3245-zzz'
        'git commit -m "x" > /tmp/t3245-should-not-happen'
        'git commit -m "x" ; sed -i s/a/b/ f'
        'git commit --no-verify -m "x"'
    )
    for c in "${corpus[@]}"; do
        if [ "$(_verdict "$m" "$mh" "$c")" = blocked ] \
           && [ "$(_verdict "$root" "$HOOK" "$c")" = ADMITTED ]; then
            echo "WIDENED: mutant blocked but fixed hook admits: $c" >&2
            widened=$((widened+1))
        fi
    done
    [ "$widened" -eq 0 ]
}
