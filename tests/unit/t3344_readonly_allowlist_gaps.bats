#!/usr/bin/env bats
#
# T-3344 — three read-only invocations were blocked by the task gate whenever
# focus sat on a completed task (OBS-379): `checkpoint.sh budget` (the
# G-087-safe budget read /resume prescribes), `termlink pty output` (worker
# observability), and `fw bvp 2>&1` (already allowlisted, but the trailing
# redirect corrupted the positional sub-verb read — 4th instance of the
# T-1908/T-2988/T-3096 affix class).
#
# `! cmd` at statement position is INERT in bats (L-628) — this file uses
# `if cmd; then false; fi` for NOT-SAFE assertions.

setup() {
    ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    LIB="$ROOT/agents/context/lib/safe-commands.sh"
    source "$LIB"
}

# ── checkpoint.sh: verified read-only subcommands ────────────────────────────

@test "T-3344: checkpoint.sh budget is SAFE (G-087-safe budget read)" {
    is_bash_safe_command "./agents/context/checkpoint.sh budget"
}

@test "T-3344: checkpoint.sh status is SAFE" {
    is_bash_safe_command "agents/context/checkpoint.sh status"
}

@test "T-3344 control: bare checkpoint.sh is NOT-SAFE" {
    if is_bash_safe_command "./agents/context/checkpoint.sh"; then false; fi
}

@test "T-3344 control: checkpoint.sh post-tool (writes counters) is NOT-SAFE" {
    if is_bash_safe_command "./agents/context/checkpoint.sh post-tool"; then false; fi
}

@test "T-3344 control: checkpoint.sh reset (writes) is NOT-SAFE" {
    if is_bash_safe_command "./agents/context/checkpoint.sh reset"; then false; fi
}

# ── termlink pty: output reads, inject/mode write ────────────────────────────

@test "T-3344: termlink pty output is SAFE" {
    is_bash_safe_command "termlink pty output some-session --strip-ansi"
}

@test "T-3344 control: termlink pty inject is NOT-SAFE" {
    if is_bash_safe_command "termlink pty inject some-session --enter 'hi'"; then false; fi
}

@test "T-3344 control: termlink pty mode is NOT-SAFE" {
    if is_bash_safe_command "termlink pty mode some-session raw"; then false; fi
}

# ── trailing-redirect stripper: fd-dups and /dev/null sinks only ─────────────

@test "T-3344: fw bvp with trailing 2>&1 is SAFE (stripper exposes sub-verb)" {
    is_bash_safe_command "bin/fw bvp 2>&1"
}

@test "T-3344: fw bvp --include-proposed 2>&1 is SAFE" {
    is_bash_safe_command "bin/fw bvp --include-proposed 2>&1"
}

@test "T-3344: termlink pty output with 2>/dev/null is SAFE" {
    is_bash_safe_command "termlink pty output s1 --strip-ansi 2>/dev/null"
}

@test "T-3344: fw doctor with >/dev/null 2>&1 is SAFE" {
    is_bash_safe_command "bin/fw doctor >/dev/null 2>&1"
}

@test "T-3344 control: a redirect to a REAL FILE is not stripped — still NOT-SAFE" {
    # The stripper only eats fd-dups and /dev/null; `fw bvp > /tmp/x` keeps its
    # redirect, the sub-verb read sees it, and the segment stays unsafe here
    # (has_bash_write_pattern additionally judges the original line upstream).
    if is_bash_safe_command "bin/fw bvp > /tmp/t3344-out"; then false; fi
}

@test "T-3344 control: stripper does not admit an unsafe base — rm 2>&1 NOT-SAFE" {
    if is_bash_safe_command "rm -rf sometree 2>&1"; then false; fi
}
