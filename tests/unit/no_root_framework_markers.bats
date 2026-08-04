#!/usr/bin/env bats
# T-2787 — nothing framework-shaped may exist at the filesystem root.
#
# Origin, measured 2026-08-04 on this host:
#
#     /.tasks/active/T-994-unjudged.md     Aug  3 15:01
#     /.tasks/active/T-995-port.md         Aug  3 15:01
#     /.tasks/active/T-9999-test.md        Jun 27 19:28
#     /.context/working/.fw-secret-key
#
# `T-994-unjudged` / `T-995-port` are the fixtures from
# tests/unit/verification_unjudged_test_run.bats (T-2738) and the T-2732
# port-literal work. They escaped their temp directory.
#
# MECHANISM — one missing guard repeated 106 times. Bats files build fixture
# paths as `mkdir -p "$PROJECT_ROOT/.tasks/active"`, with $PROJECT_ROOT assigned
# inside each file's own setup(). Unset it — a setup() that errors before the
# assignment, a file that forgot, a helper called outside bats — and the
# expression is literally `mkdir -p "/.tasks/active"`, which succeeds silently
# when the suite runs as root.
#
# WHY A GUARD AND NOT A CLEANUP. The damage is not the three stray files; it is
# that lib/hook_paths.py:reanchor_project_root walks up from a hook's cwd and
# returns the first directory holding .framework.yaml or .tasks. While /.tasks
# exists, `/` IS a project root by that rule, so any hook firing outside a
# project resolves PROJECT_ROOT=/ and reads or writes /.tasks and /.context.
# tests/unit/test_hook_paths.py::test_noop_when_cwd_outside_any_project has been
# red for exactly this reason and is a TRUE POSITIVE: the function is correct,
# the host is polluted. That test reports the symptom; this one names the cause.
#
# WHY .bats AND NOT .py (T-2787, measured). `fw test unit` runs
# `bats "$FRAMEWORK_ROOT/tests/unit/"` (bin/fw:7638) and `fw test all` points
# pytest at `web/test_app.py tests/web/` (bin/fw:7789) — never at tests/unit.
# So the 164 .py files / 2095 pytest tests in this directory are executed by no
# fw runner (OBS-145). Writing this guard as pytest would have made it the
# 2096th unexecuted test — the T-2696 trap it exists to help close.
#
# Removing the directories is Tier 0 (`rm -rf` at filesystem root) and belongs to
# the operator — see T-2787's Human AC. Until then this test is RED, which is the
# intended state. A guard that passed while /.tasks existed would be precisely
# the false green that T-2732 (371 verification lines against a foreign server)
# and T-2738 (a pass-marker grep on an unjudged run) exist to prevent.

load ../test_helper

# The markers that make a directory look like a framework project to the
# resolver. Kept in step with lib/hook_paths.py:reanchor_project_root and
# lib/paths.sh:fw_reanchor_from_cwd — those decide what a project root IS; this
# list only has to cover what they look for.
MARKERS=(.tasks .context .framework.yaml)

# Print the markers present directly under $1, one per line, sorted.
#
# Parameterised on the root so the predicate can be exercised against both a
# clean and a polluted directory. A guard that has only ever run against the one
# state the host happens to be in is evidence that it is implemented, not that
# it works (L-530).
markers_at() {
    local base="$1" m
    for m in "${MARKERS[@]}"; do
        [ -e "$base/$m" ] && echo "$m"
    done
    return 0
}

@test "predicate reports a clean root as clean (negative control)" {
    local d; d="$(mktemp -d)"
    run markers_at "$d"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    rm -rf "$d"
}

@test "predicate detects every marker kind, dir or file (positive control)" {
    local d; d="$(mktemp -d)"
    mkdir -p "$d/.tasks/active" "$d/.context/working"
    echo "version: test" > "$d/.framework.yaml"
    run markers_at "$d"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q '^\.tasks$'
    echo "$output" | grep -q '^\.context$'
    echo "$output" | grep -q '^\.framework\.yaml$'
    rm -rf "$d"
}

@test "predicate detects a partially polluted root" {
    # The real-world shape: .tasks alone is enough to make a directory a project
    # root, because the resolver stops at the first marker it finds.
    local d; d="$(mktemp -d)"
    mkdir -p "$d/.tasks/active"
    run markers_at "$d"
    [ "$status" -eq 0 ]
    [ "$output" = ".tasks" ]
    rm -rf "$d"
}

@test "filesystem root carries no framework markers" {
    run markers_at "/"
    [ "$status" -eq 0 ]

    if [ -n "$output" ]; then
        {
            echo "Framework markers exist at the filesystem root:"
            local m
            while read -r m; do
                [ -z "$m" ] && continue
                if [ -d "/$m" ]; then
                    echo "    /$m/  ->  $(find "/$m" -type f 2>/dev/null | head -10 | tr '\n' ' ')"
                else
                    echo "    /$m"
                fi
            done <<< "$output"
            echo ""
            echo "WHAT THIS MEANS"
            echo "  lib/hook_paths.py:reanchor_project_root walks up from a hook's cwd"
            echo "  and returns the first directory holding .framework.yaml or .tasks."
            echo "  While these exist, / is a valid project root by that rule, so any"
            echo "  hook firing outside a project resolves PROJECT_ROOT=/ and reads or"
            echo "  writes /.tasks and /.context."
            echo ""
            echo "HOW IT HAPPENS"
            echo "  106 bats files build fixture paths as"
            echo '      mkdir -p "$PROJECT_ROOT/.tasks/active"'
            echo "  with \$PROJECT_ROOT assigned inside each file's own setup(). If it"
            echo "  is unset when that line runs, the path is literally /.tasks/active"
            echo "  and the mkdir succeeds silently under a root-owned suite."
            echo ""
            echo "REMEDY (operator — Tier 0, destructive, at filesystem root)"
            echo "  1. Inspect:  ls -la /.tasks/active/ /.context/working/"
            echo "  2. Confirm every entry is a test fixture, not real project state."
            echo "  3. Remove:   sudo rm -rf /.tasks /.context"
            echo "  Tracked as T-2787. Do not delete blind — if the markers return"
            echo "  after a full suite run, capture which test recreated them instead."
        } >&2
        return 1
    fi
}
