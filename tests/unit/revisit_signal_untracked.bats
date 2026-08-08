#!/usr/bin/env bats
# T-2866 — the revisit signal files must never be tracked by git.
#
# Both signals rely on an absent==empty contract: revisit-due-scan.sh REMOVES its
# output file when the set is empty, and handover.sh prints nothing when the file
# is absent. A tracked file cannot be absent after a checkout — git restores it —
# so a stale committed copy would be reported as current on any fresh clone.
#
# That is the same failure shape T-2865 fixed (a signal whose truth value is
# decided by something other than the present state of the corpus), and it arrived
# via T-2865's own closing commit, where `git add -A` swept the generated file in.
#
# .revisits-due.txt has been untracked for the project's whole history, but by luck
# rather than by rule — nothing stopped the same accident. Both are pinned here.
#
# ANTI-VACUITY NOTE: this test was written and run BEFORE the untracking landed,
# and observed red on the .revisits-undated.txt leg with the .revisits-due.txt leg
# green. A guard that has only ever been run against an already-clean repo proves
# that the repo is clean today, not that the guard can see anything.

load ../test_helper

SIGNALS=(
    ".context/working/.revisits-undated.txt"
    ".context/working/.revisits-due.txt"
)

@test "T-2866: neither revisit signal file is tracked by git" {
    local tracked=()
    for s in "${SIGNALS[@]}"; do
        if git -C "$FRAMEWORK_ROOT" ls-files --error-unmatch -- "$s" >/dev/null 2>&1; then
            tracked+=("$s")
        fi
    done
    if [ ${#tracked[@]} -gt 0 ]; then
        echo "Tracked signal file(s) — these break the absent==empty contract:" >&2
        printf '  %s\n' "${tracked[@]}" >&2
        echo "Fix: git rm --cached <path> and add it to .gitignore" >&2
    fi
    [ ${#tracked[@]} -eq 0 ]
}

@test "T-2866: .gitignore covers both signal files" {
    # check-ignore is the authority — it evaluates the real rule set, including
    # negations and precedence, rather than grepping for a literal line that a
    # later `!` pattern might have overridden.
    for s in "${SIGNALS[@]}"; do
        run git -C "$FRAMEWORK_ROOT" check-ignore -q -- "$s"
        [ "$status" -eq 0 ]
    done
}

@test "T-2866: ignoring the paths did not stop the scanner writing them" {
    # The contract is "not in git", not "not on disk". If ignoring the path also
    # silenced the signal, this guard would have traded one invisible population
    # for another.
    local root="$BATS_TEST_TMPDIR/proj"
    mkdir -p "$root/.tasks/active" "$root/.context/working"
    touch "$root/FRAMEWORK.md"
    cat > "$root/.tasks/active/T-9101-undated.md" <<'EOF'
---
id: T-9101
name: "undated deferral"
---

## Decision

**Decision**: DEFER
EOF
    PROJECT_ROOT="$root" bash "$FRAMEWORK_ROOT/agents/context/revisit-due-scan.sh"
    [ -f "$root/.context/working/.revisits-undated.txt" ]
    grep -q "T-9101" "$root/.context/working/.revisits-undated.txt"
}
