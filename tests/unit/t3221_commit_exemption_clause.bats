#!/usr/bin/env bats
#
# T-3221 — the `git commit` exemptions in check-active-task.sh matched a
# MENTION of a commit, not a commit.
#
# Two branches admit a Bash command with no active task (T-2054, focus null
# after `--status work-completed`) or with a partial-complete one (T-3179).
# Both tested whether the raw command string CONTAINED the words, unanchored to
# any clause — so a trailing `; rm -rf …` rode through, and an arbitrary binary
# was admitted because a quoted ARGUMENT said "please git commit this".
#
# Reported by peer 832-Workflow-designer (their T-638); confirmed in-tree
# against the live hook before anything was changed.
#
# WHAT THIS FILE ASSERTS, and why it is built the way it is:
#
#   * Every probe runs the SHIPPED hook, in a temp PROJECT_ROOT, through its
#     real stdin JSON contract. Nothing here re-implements the predicate — a
#     test that paraphrases the thing it guards passes when the paraphrase is
#     right and the shipped file is wrong.
#   * A MUTATION CONTROL reverts the predicate to the old substring match in a
#     copy of the live source. If that copy does not admit what the fix blocks,
#     this suite is not measuring the fix, and it says so out loud.
#   * A NO-WIDENING leg asserts the fixed hook admits nothing the pre-fix
#     mutant blocked. A gate fix that quietly loosens something else is the
#     failure mode a green "it blocks the bad cases" run cannot see.
#
# `! cmd` at statement position is INERT in bats (L-628, T-3199) — this file
# uses `if cmd; then false; fi` and explicit status compares.
#
# Fixtures live in BATS_TEST_TMPDIR (L-599). Task IDs in probe strings are
# spelled TT-9 rather than T-9: a real-looking T-NNNN inside this file is read
# as an action target by the focus-drift gate when the suite is edited, which
# is the same mention-for-action class the file is about. It bit this task
# during measurement.

setup() {
    ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    HOOK="$ROOT/agents/context/check-active-task.sh"
    export ROOT HOOK
}

# Build a throwaway project root with the hook + libs, and a focus state.
# $1 = null | partial ; echoes the root.
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
# Echoes ADMITTED or blocked. Never fails the test itself — the caller compares.
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

# The pre-fix hook, derived from LIVE source so reverting the fix reddens this
# suite rather than leaving a frozen copy that agrees with itself forever.
_mkmutant() {
    local m="$BATS_TEST_TMPDIR/root-mutant"
    [ -d "$m" ] && { printf '%s' "$m"; return 0; }
    cp -r "$(_mkroot null)" "$m"
    # NOTHING here may write to stdout: the caller captures this function's
    # output as a path. An earlier version printed the substitution count, so
    # every probe ran against "1\n/tmp/…" — not a directory, so the mutant
    # blocked EVERYTHING and the no-widening leg reported eight false
    # widenings that looked exactly like a real regression. The mutation is
    # asserted by exit status instead, and python's stream is sent to stderr.
    python3 - "$m/agents/context/check-active-task.sh" <<'PY' >&2 || return 1
import sys
p = sys.argv[1]
s = open(p).read()
# Two call sites at different indents (7 and 11 spaces). Both are mutated: a
# mutant that reverts only one branch cannot show the other was ever broken.
n = 0
for ind in ('       ', '           '):
    old = ('type is_commit_checkpoint_command &>/dev/null && \\\n'
           + ind + 'is_commit_checkpoint_command "$BASH_CMD"')
    new = ('[[ "$BASH_CMD" =~ (^|[[:space:]])git[[:space:]]+commit($|[[:space:]]) ]] && \\\n'
           + ind + '! [[ "$BASH_CMD" =~ (^|[[:space:]])(--no-verify|-n)([[:space:]]|$) ]]')
    n += s.count(old)
    s = s.replace(old, new)
if n != 2:
    sys.stderr.write("mutation matched %d of 2 call sites\n" % n)
    sys.exit(1)
open(p, 'w').write(s)
PY
    bash -n "$m/agents/context/check-active-task.sh" || return 1
    printf '%s' "$m"
}

# ── the shapes the fix must now block, at BOTH branches ──────────────────────

@test "a trailing clause no longer rides through on the commit (null focus)" {
    [ "$(_verdict "$(_mkroot null)" "$HOOK" 'git commit -m "TT-9: x" ; rm -rf /tmp/zzz')" = blocked ]
}

@test "a trailing clause no longer rides through on the commit (partial-complete)" {
    [ "$(_verdict "$(_mkroot partial)" "$HOOK" 'git commit -m "TT-9: x" ; rm -rf /tmp/zzz')" = blocked ]
}

@test "a write the gate already flagged is not admitted anyway — defect 2" {
    # has_bash_write_pattern classified this correctly and then fell through
    # with `:` instead of exiting, so the exemption handed it exit 0. The gate
    # saw the write and admitted it.
    [ "$(_verdict "$(_mkroot null)" "$HOOK" 'git commit -m "TT-9: x" | tee /tmp/zzz')" = blocked ]
    [ "$(_verdict "$(_mkroot partial)" "$HOOK" 'git commit -m "TT-9: x" | tee /tmp/zzz')" = blocked ]
}

@test "a quoted argument that mentions a commit is not a commit" {
    local c='somebinary --flag "please git commit this"'
    [ "$(_verdict "$(_mkroot null)" "$HOOK" "$c")" = blocked ]
    [ "$(_verdict "$(_mkroot partial)" "$HOOK" "$c")" = blocked ]
}

@test "command substitution in the commit line is refused" {
    [ "$(_verdict "$(_mkroot null)" "$HOOK" 'git commit -m "$(cat /etc/hostname)"')" = blocked ]
    [ "$(_verdict "$(_mkroot null)" "$HOOK" 'git commit -m `cat /etc/hostname`')" = blocked ]
}

# ── the shapes that MUST keep working ────────────────────────────────────────

@test "a bare commit is still admitted at both branches" {
    [ "$(_verdict "$(_mkroot null)" "$HOOK" 'git commit -m "TT-9: x"')" = ADMITTED ]
    [ "$(_verdict "$(_mkroot partial)" "$HOOK" 'git commit -m "TT-9: x"')" = ADMITTED ]
}

@test "git add -A && git commit still works — the documented post-completion form" {
    # This is why the predicate composes over the shared allowlist instead of
    # hand-rolling a "cd or git commit" pair: `git add`'s admissibility lives in
    # is_bash_safe_command, and a hand-written list would have broken this and
    # then drifted from the allowlist forever after.
    local c='git add -A && git commit -m "TT-9: x"'
    [ "$(_verdict "$(_mkroot null)" "$HOOK" "$c")" = ADMITTED ]
    [ "$(_verdict "$(_mkroot partial)" "$HOOK" "$c")" = ADMITTED ]
}

@test "--no-verify still voids the allowance" {
    [ "$(_verdict "$(_mkroot null)" "$HOOK" 'git commit --no-verify -m "TT-9: x"')" = blocked ]
}

@test "a command with no commit clause at all is not admitted" {
    [ "$(_verdict "$(_mkroot null)" "$HOOK" 'rm -rf /tmp/zzz')" = blocked ]
}

# ── MUTATION CONTROL ─────────────────────────────────────────────────────────

@test "the pre-fix mutant admits what the fix blocks" {
    # Without this, every leg above could be green because the hook blocks
    # everything for some unrelated reason — a passing suite that measures
    # nothing. The mutant is derived from live source, so reverting the fix
    # makes the two agree and turns the no-widening leg below red.
    local m; m="$(_mkmutant)"
    [ "$(_verdict "$m" "$m/agents/context/check-active-task.sh" 'git commit -m "TT-9: x" ; rm -rf /tmp/zzz')" = ADMITTED ]
    [ "$(_verdict "$m" "$m/agents/context/check-active-task.sh" 'somebinary --flag "please git commit this"')" = ADMITTED ]
}

# ── NO WIDENING ──────────────────────────────────────────────────────────────

@test "the fix admits nothing the pre-fix hook blocked" {
    # A gate fix that tightens the reported cases while loosening something
    # else passes every leg above. Sweep a corpus through both and assert the
    # fixed hook is never more permissive than the mutant.
    local m; m="$(_mkmutant)"
    local mh="$m/agents/context/check-active-task.sh"
    local root; root="$(_mkroot null)"
    local c widened=0
    local -a corpus=(
        'ls -la'
        'git status'
        'cat README.md'
        'rm -rf /tmp/zzz'
        'echo hi > /tmp/zzz'
        'sed -i s/a/b/ f'
        'git commit -m "TT-9: x"'
        'git add -A && git commit -m "TT-9: x"'
        'git commit --no-verify -m "TT-9: x"'
        'somebinary --flag "please git commit this"'
        'git commit -m "TT-9: x" ; rm -rf /tmp/zzz'
        'git commit -m "TT-9: x" | tee /tmp/zzz'
        'bin/fw doctor'
        'python3 -c "print(1)"'
        'make install'
        'git push origin bleeding-edge'
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

# ── the predicate's own contract ─────────────────────────────────────────────

@test "the quote stripper does not desync on an apostrophe in a double-quoted string" {
    # A regex that strips '…' and "…" independently pairs this apostrophe with
    # the next unrelated quote and mis-reads the rest of the line. Same defect
    # T-3217's linter had; both are state machines for this reason.
    source "$ROOT/agents/context/lib/safe-commands.sh"
    run _fw_strip_quoted 'echo "the agent'"'"'s output" && git commit -m "x"'
    [ "$status" -eq 0 ]
    [[ "$output" == *"git commit"* ]]
    if [[ "$output" == *"agent"* ]]; then false; fi
}

@test "an unterminated quote blocks rather than guessing" {
    source "$ROOT/agents/context/lib/safe-commands.sh"
    run _fw_strip_quoted 'git commit -m "unclosed'
    [ "$status" -ne 0 ]
}

@test "both exemption branches call the same predicate — no second copy to drift" {
    local n
    n="$(grep -c 'is_commit_checkpoint_command "\$BASH_CMD"' "$HOOK")"
    [ "$n" -eq 2 ]
    # and the substring form is gone from both
    if grep -q 'BASH_CMD" =~ (^|\[\[:space:\]\])git\[\[:space:\]\]+commit' "$HOOK"; then false; fi
}
