#!/usr/bin/env bats
# T-3220 — the P-011 gate's failure paths must EXIT, and the reason must be the
# real one.
#
# WHAT WENT WRONG. T-3219 shipped the reconciliation guard with `exit 1` and a
# comment justifying it: "the caller (do_update) invokes this function BARE ...
# so a non-zero return is discarded". Both halves were false. There is no
# `do_update` in the file, and a bare call under `set -euo pipefail` (line 14)
# aborts on a non-zero return — so `return 1` blocks too. Measured, one byte
# apart, on the real script: both shapes print the ERROR and exit 1.
#
# The fix was right; the stated mechanism was not. A comment describing a
# mechanism is a model of it, and this one had drifted before the ink dried.
# Caught by peer 832-Workflow-designer, who ran the same shape in their tree and
# reported the opposite result rather than assuming ours transferred.
#
# WHAT THE REAL REASON IS, AND WHY IT NEEDS A TEST. `exit` is still correct, for
# a reason invisible at the guard: the teeth are `set -e` at line 14, ~1700 lines
# away. Wrap the call site in `if`/`||`, or drop the `-e`, and every
# `return`-based guard in the function disarms at once — with no diff to any
# guard and no diff to any of their tests. `exit` survives that. So the property
# worth pinning is not "the guard blocks" (it does, either way, today) but
# "the guard blocks WITHOUT depending on errexit".
#
# That is what the behavioural legs measure: with errexit REMOVED, `exit` still
# halts and `return` runs on into the downstream gates. Four cells, because
# three of them are the control that stops this from being a test that would
# pass against anything:
#
#     guard    errexit   halts at the guard?
#     exit     present   yes
#     return   present   yes      <- return is NOT broken today; the naive
#     exit     absent    yes         claim the old comment made
#     return   absent    NO       <- the dependency, exposed
#
# `! cmd` at statement position is INERT in bats (L-628, T-3199) — this file
# uses `if cmd; then false; fi`.
#
# SCOPE LIMIT. Like t3219, these assert on the GATE'S OUTPUT, not on whether the
# task reaches completed/ — a synthetic project root blocks the close further
# downstream regardless. In the one cell where the guard IS disarmed the task
# still ends in active/, caught by an unrelated later gate. That accident is
# precisely why "did it complete" is not the observable here.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    SHIPPED="$REPO_ROOT/agents/task-create/update-task.sh"
    TMP="$BATS_TEST_TMPDIR/t3220"
    mkdir -p "$TMP"
}

# The body of run_verification_commands, from its definition to the next
# top-level function definition. Emitted on stdout.
gate_body() {
    awk '/^run_verification_commands\(\) \{/{f=1} f{print} f&&/^\}/{exit}' "$SHIPPED"
}

# update-task.sh derives FRAMEWORK_ROOT from its own location with no env
# override (T-3219 §4, confirmed independently by 832), so a mutant in a scratch
# dir dies in lib/paths.sh before reaching any gate. Build a symlink farm that
# looks like the framework root and put mutants inside it; the repo is untouched.
fake_root() {
    local F="$TMP/fw"
    [ -d "$F/agents/task-create" ] && { printf '%s\n' "$F"; return 0; }
    mkdir -p "$F/agents/task-create"
    local e b
    for e in "$REPO_ROOT"/* "$REPO_ROOT"/.[!.]*; do
        b="$(basename "$e")"; [ "$b" = "agents" ] && continue
        ln -s "$e" "$F/$b" 2>/dev/null || true
    done
    for e in "$REPO_ROOT"/agents/*; do
        b="$(basename "$e")"; [ "$b" = "task-create" ] && continue
        ln -s "$e" "$F/agents/$b" 2>/dev/null || true
    done
    for e in "$REPO_ROOT"/agents/task-create/*; do
        ln -s "$e" "$F/agents/task-create/$(basename "$e")" 2>/dev/null || true
    done
    printf '%s\n' "$F"
}

# A variant of the shipped script. $1=name $2=exit|return $3=errexit yes|no
# Leg 1 of T-3219 (the stdin redirect) is always removed, because the swallow is
# what drives the guard. Every mutation is asserted to have changed bytes.
variant() {
    local name="$1" guard="$2" errexit="$3"
    local F; F="$(fake_root)"
    local out="$F/agents/task-create/$name.sh"
    sed 's|> /tmp/verify-\$\$.out 2>&1 < /dev/null; then|> /tmp/verify-$$.out 2>\&1; then|' \
        "$SHIPPED" > "$out"
    if diff -q "$SHIPPED" "$out" >/dev/null 2>&1; then
        echo "stdin-redirect mutation changed no bytes" >&2; return 1
    fi
    if [ "$guard" = "return" ]; then
        python3 - "$out" <<'PY' || return 1
import sys
p = sys.argv[1]; s = open(p).read()
i = s.index("verification count does not reconcile")
j = s.index("\n        exit 1", i)
out = s[:j] + "\n        return 1" + s[j + len("\n        exit 1"):]
assert out != s, "guard mutation changed no bytes"
open(p, "w").write(out)
PY
    fi
    if [ "$errexit" = "no" ]; then
        sed -i '14s/^set -euo pipefail$/set -uo pipefail/' "$out"
        if grep -q '^set -euo pipefail$' "$out"; then
            echo "errexit mutation did not take — line 14 is not 'set -euo pipefail'" >&2
            return 1
        fi
    fi
    printf '%s\n' "$out"
}

# A synthetic project root with a task whose ## Verification swallows itself.
mkproj() {
    PROJ="$TMP/proj.$RANDOM"
    mkdir -p "$PROJ/.tasks/active" "$PROJ/.tasks/completed" \
             "$PROJ/.context/working" "$PROJ/.context/episodic"
    git -C "$PROJ" init -q .
    git -C "$PROJ" config user.email t@t
    git -C "$PROJ" config user.name t
    git -C "$PROJ" commit -q --allow-empty -m init
    cat > "$PROJ/.tasks/active/T-901-probe.md" <<'HDR'
---
id: T-901
name: "probe"
status: started-work
workflow_type: build
owner: agent
created: 2026-01-01T00:00:00Z
last_update: 2026-01-01T00:00:00Z
---
# T-901: probe

## Acceptance Criteria

### Agent
- [x] probe

## Verification

echo one
cat > /dev/null
echo three
echo four
HDR
}

run_gate() {
    PROJECT_ROOT="$PROJ" TASKS_DIR="$PROJ/.tasks" CONTEXT_DIR="$PROJ/.context" \
        timeout 120 bash "$1" T-901 --status work-completed 2>&1
}

# Everything the script printed after the reconciliation refusal finished its
# message. Empty means the script stopped there.
after_guard() {
    awk '/unreconciled count is not a failure/{f=1;next} f' <<<"$1" | grep -v '^[[:space:]]*$'
}

# ── the static property: no failure path returns ─────────────────────────────

@test "every failure path in run_verification_commands exits, none returns non-zero" {
    local body; body="$(gate_body)"
    [ -n "$body" ]

    # Populated denominator: a broken extraction must not read as "clean".
    local exits; exits="$(grep -c '^[[:space:]]*exit 1[[:space:]]*$' <<<"$body")"
    [ "$exits" -ge 3 ]

    # `return 0` is fine (the empty-block early out). `return <non-zero>` is not.
    local bad; bad="$(grep -nE '^[[:space:]]*return [1-9]' <<<"$body" || true)"
    [ -z "$bad" ]
}

@test "the extraction actually reads the gate function, not an empty string" {
    local body; body="$(gate_body)"
    grep -q 'verification count does not reconcile' <<<"$body"
    grep -q 'Running .* verification command' <<<"$body"
}

@test "the fabricated caller name is gone from the source" {
    if grep -q 'do_update' "$SHIPPED"; then false; fi
}

@test "the corrected comment names the real dependency instead of a discarded return" {
    local body; body="$(gate_body)"
    grep -q 'set -euo pipefail' <<<"$body"
    # and it must not re-assert the false claim
    if grep -qi 'non-zero return is discarded' <<<"$body"; then false; fi
}

# ── the behavioural property: exit does not depend on errexit ────────────────

@test "shipped shape (exit) halts at the guard WITH errexit" {
    local s; s="$(variant a exit yes)"
    mkproj
    local out; out="$(run_gate "$s")" || true
    grep -q 'does not reconcile' <<<"$out"
    [ -z "$(after_guard "$out")" ]
}

@test "control: return ALSO halts WITH errexit — the old comment's claim was false" {
    local s; s="$(variant b return yes)"
    mkproj
    local out; out="$(run_gate "$s")" || true
    grep -q 'does not reconcile' <<<"$out"
    # If this ever fails, the T-3220 premise is wrong and the comment should
    # be re-examined, not this test.
    [ -z "$(after_guard "$out")" ]
}

@test "exit halts at the guard even WITHOUT errexit — the property being pinned" {
    local s; s="$(variant c exit no)"
    mkproj
    local out; out="$(run_gate "$s")" || true
    grep -q 'does not reconcile' <<<"$out"
    [ -z "$(after_guard "$out")" ]
}

@test "return runs straight past the guard WITHOUT errexit — the leg that bites" {
    local s; s="$(variant d return no)"
    mkproj
    local out; out="$(run_gate "$s")" || true
    grep -q 'does not reconcile' <<<"$out"
    # The guard printed its refusal and the script carried on into later gates.
    # This is the whole difference between the two idioms, and it is invisible
    # at the guard itself.
    [ -n "$(after_guard "$out")" ]
}

@test "the errexit mutation is real, not a silent no-op" {
    local with without; with="$(variant e exit yes)"; without="$(variant f exit no)"
    grep -q '^set -euo pipefail$' "$with"
    if grep -q '^set -euo pipefail$' "$without"; then false; fi
    if diff -q "$with" "$without" >/dev/null 2>&1; then false; fi
}
