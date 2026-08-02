#!/bin/bash
# lib/verification-verdict.sh — unjudged-test-run detection (T-2738)
#
# Single definition of the predicate. Sourced by:
#   - agents/task-create/update-task.sh  (the P-011 close gate)
#   - tests/unit/verification_unjudged_test_run.bats
#
# It lives here rather than inline in the gate for the same reason as its sibling
# lib/verification-port.sh: the regression suite has to run the REAL predicate
# over the real corpus. A test that re-types the producer's expression into a
# local helper can only ever check the sites its author already knew about
# (L-533, from the T-2729/T-2730/T-2731 escape family).
#
# Usage: source "$FRAMEWORK_ROOT/lib/verification-verdict.sh"
#        find_unjudged_test_runs "$text"   # prints offending lines, one per line

[[ -n "${_FW_VERIFICATION_VERDICT_LOADED:-}" ]] && return 0
_FW_VERIFICATION_VERDICT_LOADED=1

# ── What this detects, and why the obvious framings are all wrong ────────────
#
# P-011 evaluates each verification line at update-task.sh:1085 as
#     if ( cd "$PROJECT_ROOT" && eval "$cmd" ); then PASS; else FAIL; fi
# under the script's `set -euo pipefail` (:14).
#
# `pipefail` is a shell option and stays in force, so every PIPELINE shape is
# judged correctly — `pytest … | tail -5` and `pytest … | grep -qE "[0-9]+ passed"`
# both go red on a failing suite. But `set -e` is SUPPRESSED inside an `if`
# condition, so for a SEQUENCE (`cmd1; cmd2`) the verdict is `cmd2`'s status
# alone. Whatever ran before the last `;` is unjudged.
#
# That alone is not the defect. The capture idiom
#     out=$(cmd 2>&1); echo "$out" | grep -q "PATTERN"
# is prescribed by CLAUDE.md as the L-387 SIGPIPE remedy, and 821 corpus lines
# use it soundly: `fw doctor` exits non-zero for unrelated warnings, so the grep
# IS the assertion and the discarded exit code is genuinely irrelevant.
#
# The defect needs the conjunction:
#   (a) the unjudged command is a TEST RUNNER, whose exit code was the real
#       verdict — not an advisory tool whose exit code never meant much; and
#   (b) the replacement assertion is a PASS MARKER that a partially-failing run
#       still emits.
# Then the grep is strictly WEAKER than what it replaced. Measured live against
# a 2-pass/1-fail suite: pytest prints "1 failed, 2 passed", `grep -q "2 passed"`
# matches, the gate records PASS. `grep -qE "[0-9]+ passed"` matches too — so
# generalising the count does not help, which is why "the line pins a literal
# count" (OBS-132's original framing) named the wrong defect.
#
# A line carrying an explicit absence-of-failure guard is clean: the guard is
# what restores the strength the exit code used to supply.
#
# Deliberately narrow. Flagging every sequence line whose head does real work
# would hit 937 lines, the overwhelming majority of them correct — a gate that
# fires mostly on sound input trains people to bypass it.

# Print every offending line of $1, one per line. Prints nothing when clean.
# Always exits 0 (pipefail-safe, L-302) — callers decide what non-empty means.
find_unjudged_test_runs() {
    local line head tail

    while IFS= read -r line; do
        [ -z "$line" ] && continue

        # Sequence only. Without a `;` the runner's status reaches the verdict.
        case "$line" in *";"*) ;; *) continue ;; esac

        head="${line%;*}"      # everything before the LAST top-level `;`
        tail="${line##*;}"     # the segment that actually supplies the verdict

        # (a1) the head DISCARDS an exit code — swallowed by a command
        #      substitution assignment, or explicitly neutered with `|| true`.
        printf '%s\n' "$head" | grep -qE \
            '[A-Za-z_][A-Za-z0-9_]*=\$\(|\|\|[[:space:]]*true' \
            || continue

        # (a2) and what it discarded is a TEST RUNNER, whose exit code was the
        #      real verdict. Matched as a COMMAND: preceded by start-of-string,
        #      `(`, `;`, `&`, `|` or space — which is what keeps a filename like
        #      `tests/unit/foo.bats` (preceded by `.`) from matching, as a bare
        #      \bbats\b word boundary would.
        printf '%s\n' "$head" | grep -qE \
            '(^|[(;&|]|[[:space:]])(pytest|bats)[[:space:]]' \
            || continue

        # (b) the verdict segment asserts a pass marker and nothing stronger.
        # `ok` is matched on a non-alphanumeric left boundary rather than a
        # whitespace one: in `grep -q "ok 1 "` the character before it is a
        # quote, and requiring whitespace silently missed every bats line.
        printf '%s\n' "$tail" | grep -qE \
            'grep[^|]*(passed|(^|[^a-zA-Z0-9])ok [0-9]|PASS)' \
            || continue

        # An explicit absence-of-failure guard anywhere on the line restores the
        # strength the discarded exit code used to carry.
        printf '%s\n' "$line" | grep -qE \
            '![[:space:]]*(echo|grep|printf|tail)|not ok|0 failures?|no tests ran|grep -qv|grep -c' \
            && continue

        printf '%s\n' "$line"
    done < <(printf '%s\n' "$1")
    return 0
}
