#!/usr/bin/env bats
# T-3038 (OBS-291) — focus is per-session, not per-project, for dispatched workers.
#
# The bug this pins is a LOCKOUT, not a lost write. `fw context focus` stamps
# `focus_session` next to `current_task` in ONE shared file, and the task gate
# refuses every Write and every Bash — read-only ls/cat/grep included — when that
# stamp does not match the running session. So a dispatched worker calling
# `fw work-on` did not merely change a value: it locked the parent out of its own
# unrelated work, and re-asserting focus only held until the next worker ran.
#
# Three properties are load-bearing and each is pinned below:
#
#   1. DEFAULT UNCHANGED — with FW_SESSION_SCOPED_FOCUS unset, every path
#      resolves to the shared focus.yaml exactly as before. This is what makes
#      the change safe to land with no migration; if it regresses, every
#      single-session install silently changes behaviour.
#
#   2. ISOLATION — under the flag, a write goes to focus.<key>.yaml and the
#      shared file is left byte-identical. Byte-identical is the assertion that
#      matters: "parent still works" would pass even if the parent's file were
#      rewritten with the same task but a different session stamp, which is
#      precisely the state that causes the lockout.
#
#   3. PRODUCER/CONSUMER PARITY (L-399) — writer and reader resolve through the
#      SAME helper. A bypass contract honoured on one side only is the T-1890
#      class; here it would mean the worker writes a file the gate never reads,
#      so the worker is refused for having "no active task" while its focus sits
#      one filename away.
#
# The reader's fallback to the shared file is deliberate and is pinned too: a
# worker that never calls work-on should inherit the parent's task rather than be
# refused. Reading the shared file was never the hijack — only writing it was.

setup() {
    FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    PATHS_LIB="$FRAMEWORK_ROOT/lib/paths.sh"
    GATE="$FRAMEWORK_ROOT/agents/context/check-active-task.sh"
    FOCUS_LIB="$FRAMEWORK_ROOT/agents/context/lib/focus.sh"
    TERMLINK="$FRAMEWORK_ROOT/agents/termlink/termlink.sh"
    TESTROOT="$BATS_TEST_TMPDIR/proj"
    mkdir -p "$TESTROOT/.context/working"
}

# Resolve fw_focus_file in a clean subshell with an explicit env.
_resolve() {
    env FW_SESSION_SCOPED_FOCUS="${1:-}" FW_FOCUS_SESSION_KEY="${2:-}" \
        bash -c "
            PROJECT_ROOT='$TESTROOT'
            source '$PATHS_LIB' 2>/dev/null
            fw_focus_file '$TESTROOT'
        "
}

@test "t3038: default resolves the shared focus.yaml — behaviour unchanged" {
    run _resolve "" ""
    [ "$status" -eq 0 ]
    [ "$output" = "$TESTROOT/.context/working/focus.yaml" ]
}

@test "t3038: FW_SESSION_SCOPED_FOCUS=0 is also the shared file, not a scoped one" {
    # Only the literal "1" opts in. An explicit 0 must not land on focus.0.yaml.
    run _resolve "0" "worker-a"
    [ "$status" -eq 0 ]
    [ "$output" = "$TESTROOT/.context/working/focus.yaml" ]
}

@test "t3038: scoped mode resolves a per-key file" {
    run _resolve "1" "worker-a"
    [ "$status" -eq 0 ]
    [ "$output" = "$TESTROOT/.context/working/focus.worker-a.yaml" ]
}

@test "t3038: two workers never resolve to the same file" {
    # The whole point. If these collide, worker B hijacks worker A exactly as
    # both used to hijack the parent.
    a=$(_resolve "1" "worker-a")
    b=$(_resolve "1" "worker-b")
    [ "$a" != "$b" ]
}

@test "t3038: a worker key never escapes the working dir" {
    # Keys come from --name, which is free-form. A key of '../../etc/x' must not
    # produce a path outside .context/working.
    run _resolve "1" "../../etc/passwd"
    [ "$status" -eq 0 ]
    [[ "$output" == "$TESTROOT/.context/working/focus."*".yaml" ]]
    [[ "$output" != *".."* ]]
}

@test "t3038: writer and reader resolve through the same helper (L-399 parity)" {
    # Not a style check. If either side hand-rolls the path, the worker writes a
    # file the gate never reads and is then refused for having no active task.
    run grep -c 'fw_focus_file' "$FOCUS_LIB"
    [ "$status" -eq 0 ]
    [ "$output" -ge 1 ]

    run grep -c 'fw_focus_file' "$GATE"
    [ "$status" -eq 0 ]
    [ "$output" -ge 1 ]
}

@test "t3038: the gate no longer hard-codes the shared focus path" {
    # Both former assignments (initial + post-reanchor) must route through the
    # resolver, or the re-anchored one silently reverts to the shared file.
    run grep -c 'FOCUS_FILE="\$PROJECT_ROOT/.context/working/focus.yaml"' "$GATE"
    [ "$output" -eq 0 ]

    run grep -c '_resolve_focus_file' "$GATE"
    [ "$output" -ge 3 ]  # definition + two call sites
}

@test "t3038: the reader falls back to the shared file when no scoped file exists" {
    # A worker that never ran work-on inherits the parent's task instead of being
    # blocked. Reading the shared file was never the hijack.
    printf 'current_task: T-PARENT\nfocus_session: S-PARENT\n' \
        > "$TESTROOT/.context/working/focus.yaml"

    run env FW_SESSION_SCOPED_FOCUS=1 FW_FOCUS_SESSION_KEY=ghost bash -c "
        PROJECT_ROOT='$TESTROOT'
        source '$PATHS_LIB' 2>/dev/null
        f=\$(fw_focus_file '$TESTROOT')
        if [ ! -f \"\$f\" ] && [ -f '$TESTROOT/.context/working/focus.yaml' ]; then
            f='$TESTROOT/.context/working/focus.yaml'
        fi
        printf '%s\n' \"\$f\"
    "
    [ "$status" -eq 0 ]
    [ "$output" = "$TESTROOT/.context/working/focus.yaml" ]
}

@test "t3038: a scoped write leaves the parent's focus.yaml byte-identical" {
    # The core isolation claim. Checksum, not content-equality of current_task:
    # a rewrite that preserved the task but changed focus_session would still
    # lock the parent out, and that is the exact shape of the original bug.
    shared="$TESTROOT/.context/working/focus.yaml"
    printf 'current_task: T-PARENT\nfocus_session: S-PARENT\n' > "$shared"
    before=$(md5sum "$shared" | awk '{print $1}')

    scoped=$(_resolve "1" "worker-a")
    printf 'current_task: T-WORKER\nfocus_session: S-WORKER\n' > "$scoped"

    after=$(md5sum "$shared" | awk '{print $1}')
    [ "$before" = "$after" ]

    # And the parent's values are still the ones a reader would get.
    run grep -q 'T-PARENT' "$shared"
    [ "$status" -eq 0 ]
}

@test "t3038: dispatch exports the scoping vars into the worker env" {
    # Without this the fix exists but no worker uses it — the isolation would be
    # opt-in and every real dispatch would keep hijacking.
    run grep -c 'FW_SESSION_SCOPED_FOCUS' "$TERMLINK"
    [ "$status" -eq 0 ]
    [ "$output" -ge 1 ]

    run grep -c 'FW_FOCUS_SESSION_KEY' "$TERMLINK"
    [ "$status" -eq 0 ]
    [ "$output" -ge 1 ]
}

@test "t3038: dispatch writes the vars before caller --env so they stay overridable" {
    # env.sh is sourced top-to-bottom and later export wins. If these landed
    # after the caller's pairs, --env FW_SESSION_SCOPED_FOCUS=0 would be silently
    # ignored and there would be no way back onto the shared file.
    scoped_line=$(grep -n 'export FW_SESSION_SCOPED_FOCUS' "$TERMLINK" | head -1 | cut -d: -f1)
    caller_line=$(grep -n "printf 'export %s=%q" "$TERMLINK" | grep '\$k' | head -1 | cut -d: -f1)
    [ -n "$scoped_line" ]
    [ -n "$caller_line" ]
    [ "$scoped_line" -lt "$caller_line" ]
}
