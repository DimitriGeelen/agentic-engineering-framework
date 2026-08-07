#!/bin/bash
# lib/traceability.sh — commit-traceability predicates (T-2851)
#
# Single definition of the predicate. Sourced by:
#   - agents/audit/audit.sh                         (the P-002 traceability check)
#   - tests/unit/audit_root_commit_traceability.bats
#
# It lives here rather than inline in the audit because the regression suite has
# to run the REAL predicate — a test that re-types the producer's expression into
# a local helper only ever checks the shape its author already had in mind
# (L-533, from the T-2729/T-2730/T-2731 escape family).
#
# Usage: source "$FRAMEWORK_ROOT/lib/traceability.sh"
#        trace_is_root_commit "$repo_dir" "$sha"   # rc 0 = root commit

[[ -n "${_FW_TRACEABILITY_LOADED:-}" ]] && return 0
_FW_TRACEABILITY_LOADED=1

# True when $2 is a root commit (has no parent) in the repo at $1.
#
# Why this exemption exists (T-2851): `fw init` closes with a bootstrap commit so
# the new project has a resolvable HEAD over a non-empty tree (lib/init.sh:742,
# the T-2821/T-2827 fix). Its subject is `T-000: fw init bootstrap commit (…)`.
# `T-000` is the framework's own sentinel for "no real task applies" — see
# agents/handover/handover.sh:57 — and it exists to satisfy the commit-msg hook,
# which only requires the subject to MATCH `T-[0-9]+`.
#
# The audit applies a different predicate to the same string: every `T-NNNN` must
# RESOLVE to a file in .tasks/. `T-000` never resolves, by design. Two gates, two
# predicates, one string — so every project fw init created failed its own
# traceability audit at its very first commit, on day zero, before the operator
# had done anything (measured on /opt/001-test-install, 2026-08-07).
#
# The exemption is deliberately keyed on PARENTLESSNESS, not on the literal
# `T-000`. A root commit cannot reference a task, because no task existed when it
# was authored — that is a structural fact, not a naming convention. And a history
# has exactly one root commit, so this cannot become a general escape hatch. Keying
# it on the sentinel string instead would let ANY commit opt out of P-002 by
# writing `T-000:`, which is precisely the traceability hole the check exists to
# close.
#
# Always returns cleanly (never trips `set -e` in a caller's condition).
trace_is_root_commit() {
    local repo="$1" sha="$2" parents

    [ -n "$repo" ] && [ -n "$sha" ] || return 1

    # `rev-list --parents -n 1 <sha>` prints "<sha> <parent>…" — a root commit
    # prints the sha alone.
    parents=$(git -C "$repo" rev-list --parents -n 1 "$sha" 2>/dev/null)

    # Unresolvable sha / not a repo → empty. That is NOT a root commit; saying
    # otherwise would exempt every ref the audit failed to resolve.
    [ -n "$parents" ] || return 1

    # No space in the line ⇒ no parent fields ⇒ root commit.
    #
    # Do NOT reach for `cut -d' ' -f2-` here. cut passes a line containing no
    # delimiter through UNCHANGED rather than emitting an empty field, so the
    # root commit — the one case this predicate exists to catch — came back as
    # its own sha and read as "has parents", while an unresolvable sha produced
    # empty output and read as "is root". Exactly inverted, and silently: the
    # audit would have stopped warning about genuinely dangling refs while
    # continuing to warn about the bootstrap commit. Caught by the negative
    # control in tests/unit/audit_root_commit_traceability.bats.
    [ "$parents" = "${parents%% *}" ]
}
