#!/usr/bin/env bats
# T-3234 — no project marker may sit on the path from the bats temp base up to "/".
#
# WHY THIS IS AN INVARIANT AND NOT A TEST OF OUR CODE. Nearly every hook suite
# builds its fixture root under BATS_TEST_TMPDIR, i.e. under BATS_TMPDIR (/tmp
# by default). The hooks call lib/paths.sh:fw_reanchor_from_cwd, which walks UP
# from the per-call stdin `cwd` looking for .framework.yaml or .tasks and stops
# before "/". So the fixture's ancestry is part of every one of those tests'
# inputs, and it is host state that no suite declares, asserts, or controls.
#
# ORIGIN (OBS-358, measured 2026-08-31): a full `fw init` ran with cwd=/tmp on
# this host — /tmp/.framework.yaml, /tmp/.tasks with six seed tasks, /tmp/.context,
# /tmp/.agentic-framework, /tmp/.claude with hooks pointing into /tmp — with a
# `git init` behind it. /tmp became a project, so every fixture under it
# re-anchored to /tmp and read /tmp's focus.yaml (null) instead of its own.
#
# The visible symptom was one red leg — check_active_task_cwd_resolution.bats
# "cwd outside any project" — which blocked an unrelated task close at the P-011
# gate and read exactly like a code regression. That is the mild direction. The
# dangerous direction is the other one: a suite whose fixture root has NO markers
# of its own, or one that means to assert a block, can be silently satisfied by
# the ambient /tmp project and go GREEN for a reason that has nothing to do with
# the code under test. Same false-green family the gate suites exist to catch,
# one level down in the environment.
#
# The failure mode this replaces is a cryptic `[ "$status" -eq 0 ]' failed` in
# whichever suite happens to notice first. This says which directory, which
# marker, and that the host — not the code — is what changed.
#
# THE WALK MIRRORS THE RESOLVER EXACTLY, including its stop condition. It stops
# BEFORE "/", because fw_reanchor_from_cwd does (lib/paths.sh, `while [ -n "$d" ]
# && [ "$d" != "/" ]`). That is not an oversight here: this host also carries
# /.framework.yaml and /.tasks, and they are out of the resolver's reach, so
# flagging them would be a false positive against the code as it actually
# behaves. If that stop condition ever changes, this walk must change with it —
# the two are one contract, which is what the second and third legs pin.

# TO SEE THIS GUARD FAIL ON DEMAND — the subject of leg 1 is not a variable you
# can set directly (bats overwrites BATS_TMPDIR at startup, libexec/bats-core/bats:
# `export BATS_TMPDIR="${TMPDIR:-/tmp}"`). TMPDIR is the lever:
#
#   mkdir -p .context/working/.proof
#   TMPDIR=$PWD/.context/working/.proof bats tests/lint/no-project-markers-above-bats-tmpdir.bats
#
# which puts the repo's own .framework.yaml above the base and reddens leg 1.

RESOLVER="$BATS_TEST_DIRNAME/../../lib/paths.sh"

# The walk, factored out so the guard and its own red/green proof run the SAME
# code. A guard whose proof exercises a copy of the logic proves nothing about
# the guard.
_markers_above() {
    local d found=""
    d="$(cd "$1" 2>/dev/null && pwd -P)" || return 2
    while [ -n "$d" ] && [ "$d" != "/" ]; do
        [ -f "$d/.framework.yaml" ] && found+="$d/.framework.yaml"$'\n'
        [ -d "$d/.tasks" ]          && found+="$d/.tasks/"$'\n'
        d="$(dirname "$d")"
    done
    printf '%s' "$found"
}

@test "no .framework.yaml / .tasks between the bats temp base and /" {
    local base="${BATS_TMPDIR:-/tmp}" found
    found="$(_markers_above "$base")" || {
        echo "cannot resolve BATS_TMPDIR=$base" >&2; return 1
    }
    if [ -n "$found" ]; then
        {
            echo "HOST POLLUTED — a project marker sits above the bats temp base."
            echo "Every fixture root under $base re-anchors to it"
            echo "(lib/paths.sh:fw_reanchor_from_cwd), so hook suites read that"
            echo "project's focus.yaml instead of their own. A suite can go GREEN"
            echo "for a reason unrelated to the code it names."
            echo "This is host state, not a code regression. Found:"
            # %s\n, not %s: command substitution stripped the trailing
            # newline off $found, so the last entry would otherwise run into
            # the line below it.
            printf '%s\n' "$found" | sed 's/^/  /'
            echo "Fix: move the stray project aside — do not assume it is yours"
            echo "to delete; another agent or user may own it."
            echo "Context: OBS-358, T-3234."
        } >&2
        return 1
    fi
}

@test "the guard is red against a polluted ancestry and green against a clean one" {
    # Without this leg, "it passes today" is indistinguishable from "it can
    # never fail" — the exact class tests/lint exists to catch.
    # Hermetic on purpose: asserted on markers UNDER this test's own tmpdir, not
    # on the walk being empty. A polluted host would otherwise redden this leg
    # too, with a message ("green against a clean one" failed) that contradicts
    # what actually happened and buries leg 1's accurate diagnosis.
    local clean="$BATS_TEST_TMPDIR/clean/a/b"
    mkdir -p "$clean"
    local seen; seen="$(_markers_above "$clean")"
    case "$seen" in
        *"$BATS_TEST_TMPDIR"*)
            echo "clean ancestry reported a marker under its own tmpdir: $seen" >&2
            return 1 ;;
    esac

    local dirty="$BATS_TEST_TMPDIR/dirty/a/b"
    mkdir -p "$dirty" "$BATS_TEST_TMPDIR/dirty/.tasks"
    [ -n "$(_markers_above "$dirty")" ]

    # and it must name the marker, not merely report non-empty
    _markers_above "$dirty" | grep -q '/dirty/\.tasks/$'
}

@test "the resolver still stops before / — this walk mirrors that" {
    # If the resolver's stop condition changes, the walk above is measuring a
    # different path than the code does, and its green stops meaning anything.
    grep -q 'while \[ -n "\$d" \] && \[ "\$d" != "/" \]' "$RESOLVER"
}

@test "the marker set matches the one the resolver looks for" {
    # Same reason: a resolver that gains a third marker leaves this guard
    # measuring two of three, which is a green that no longer covers its subject.
    grep -q '\[ -f "\$d/\.framework\.yaml" \] || \[ -d "\$d/\.tasks" \]' "$RESOLVER"
}
