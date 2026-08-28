#!/usr/bin/env bats
# T-3209: doctor must not infer a CAUSE from the absence of a file.
#
# The missing-ledger branch used to say, unconditionally:
#   "Expected when the session was not launched via claude-fw. Launch with: claude-fw"
# That is a claim about why the file is missing, and it is false whenever a
# claude-fw wrapper is actually running. Two ways to reach that state:
#   1. transient — the wrapper armed before T-3206 shipped the start event
#   2. permanent — _record_loop_event is non-fatal by design (T-3206), so a
#      recorder that cannot write fails silently and lands in the same branch
#
# These tests drive the SHIPPED block (sed-extracted from bin/fw), never a
# restatement of it. A test that reimplements the code it guards cannot detect
# that code being fixed — the tell is an assertion that would still hold if
# bin/fw were deleted. Every test here reads bin/fw.
#
# The process table is controlled with a fake `pgrep` earlier on PATH, so the
# three states are reachable deterministically rather than depending on what
# happens to be running on the host.
#
# `! cmd` at statement position is INERT in bats (T-3199) — uses `if cmd; then false; fi`.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    FW="$REPO_ROOT/bin/fw"
    TMP="$BATS_TEST_TMPDIR/t3209"
    mkdir -p "$TMP/proj/.context/working" "$TMP/bin"
}

# Extract the shipped block, dropping the trailing anchor comment line.
extract_block() {
    sed -n '/# Check: continuous-run loop ledger (T-3206/,/# Check: on-PATH claude-fw drift/p' "$FW" | head -n -1
}

# Install a fake `ps` whose process table we control. "" = empty table.
# NOTE the shape: the block reads `ps -eo pid=,args=`, so each line is
# "<pid> <argv0> <argv1> ...". The fake reproduces that layout exactly, because
# the defect this file guards lives in WHICH FIELD is matched.
fake_ps() {
    cat > "$TMP/bin/ps" <<PSEOF
#!/usr/bin/env bash
cat <<'TABLE'
$1
TABLE
exit 0
PSEOF
    chmod +x "$TMP/bin/ps"
}

# Run the shipped block against a synthetic PROJECT_ROOT.
run_block() {
    local blk; blk="$(extract_block)"
    cat > "$TMP/run.sh" <<RUNNER
CYAN=''; NC=''; YELLOW=''; GREEN=''; RED=''
warnings=0
PROJECT_ROOT="$TMP/proj"
_check() {
$blk
}
_check
echo "WARNCOUNT=\$warnings"
RUNNER
    PATH="$TMP/bin:$PATH" bash "$TMP/run.sh" 2>&1
}

# ── controls ─────────────────────────────────────────────────────────────────

@test "CONTROL: the block extracts from bin/fw and is substantial" {
    # Without this, every test below could pass against an empty string.
    local blk; blk="$(extract_block)"
    [ -n "$blk" ]
    [ "$(printf '%s' "$blk" | wc -l)" -gt 20 ]
}

@test "CONTROL: the two no-ledger states produce DIFFERENT output" {
    # Proves the suite can tell them apart at all — if this fails, every
    # state-specific assertion below is meaningless.
    fake_ps ""
    local without; without="$(run_block)"
    fake_ps "4242 /bin/bash $TMP/proj/bin/claude-fw -c"
    local with; with="$(run_block)"
    if [ "$without" = "$with" ]; then
        echo "no-wrapper and wrapper-running produced identical output" >&2
        false
    fi
}

# ── state 1: no ledger, no wrapper — the genuinely expected case ─────────────

@test "no ledger and no wrapper reports SKIP, not WARN" {
    fake_ps ""
    local out; out="$(run_block)"
    echo "$out" | grep -q "SKIP" 
    echo "$out" | grep -q "never recorded"
    echo "$out" | grep -q "WARNCOUNT=0"
}

@test "no ledger and no wrapper states the absence rather than leaving it inferred" {
    fake_ps ""
    run_block | grep -q "No claude-fw wrapper is running for this project"
}

# ── state 2: no ledger, wrapper running — the defect ─────────────────────────

@test "no ledger WITH a live wrapper is a WARN naming the pid" {
    fake_ps "4242 /bin/bash $TMP/proj/bin/claude-fw -c"
    local out; out="$(run_block)"
    echo "$out" | grep -q "WARN"
    echo "$out" | grep -q "4242"
    echo "$out" | grep -q "WARNCOUNT=1"
}

@test "no ledger WITH a live wrapper names BOTH causes, not just the restart" {
    # A message that names only the transient cause sends an operator whose
    # .context/working is unwritable into an endless restart loop.
    fake_ps "4242 /bin/bash $TMP/proj/bin/claude-fw -c"
    local out; out="$(run_block)"
    echo "$out" | grep -q "armed before the start event shipped"
    echo "$out" | grep -qi "could not write"
    echo "$out" | grep -q "writable"
}

@test "no ledger WITH a live wrapper does NOT repeat the old false claim" {
    # The regression this task exists to prevent: telling an operator who is
    # already inside claude-fw that they did not launch via claude-fw.
    fake_ps "4242 /bin/bash $TMP/proj/bin/claude-fw -c"
    local out; out="$(run_block)"
    if echo "$out" | grep -q "not launched via claude-fw"; then
        echo "the old unconditional false claim is back" >&2
        false
    fi
}

# ── scoping: another project's wrapper must not count ────────────────────────

@test "a claude-fw supervising a DIFFERENT project does not satisfy the check" {
    # Several projects run their own wrapper on this host; an unscoped pgrep
    # would report every one of them as this project's supervisor.
    fake_ps "9999 /bin/bash /opt/832-Workflow-designer/.agentic-framework/bin/claude-fw -c"
    local out; out="$(run_block)"
    echo "$out" | grep -q "SKIP"
    echo "$out" | grep -q "WARNCOUNT=0"
    if echo "$out" | grep -q "9999"; then
        echo "another project's wrapper pid leaked into this project's verdict" >&2
        false
    fi
}

# ── robustness ───────────────────────────────────────────────────────────────

@test "no usable ps degrades to SKIP rather than crashing" {
    rm -f "$TMP/bin/ps"
    cat > "$TMP/bin/ps" <<'NOPG'
#!/usr/bin/env bash
exit 127
NOPG
    chmod +x "$TMP/bin/ps"
    local out; out="$(run_block)"
    echo "$out" | grep -q "WARNCOUNT="
}

@test "an existing ledger is unaffected by this change" {
    # Regression guard on T-3206's three states — this task touched only the
    # else-branch and must not have disturbed the ledger-present path.
    fake_ps ""
    printf '%s\n' '{"event":"start","reason":"armed","ts":"2026-08-28T10:00:00Z","pid":1}' \
        > "$TMP/proj/.context/working/continuous-run.jsonl"
    local out; out="$(run_block)"
    if echo "$out" | grep -q "never recorded"; then
        echo "ledger-present path fell through to the missing-ledger branch" >&2
        false
    fi
}

# ── the false positive that a mocked data source hid ─────────────────────────

@test "a process that merely MENTIONS claude-fw is not a wrapper" {
    # Found live, not theorised. The first implementation was
    #   pgrep -af claude-fw | grep -F "$PROJECT_ROOT"
    # which matched this agent's own `bash -c` shell, because the command text
    # it was running happened to contain both the word claude-fw and the project
    # path. Greps, editors, test runs and CI logs all carry that text.
    #
    # This test existed nowhere in the first suite, and could not have: the
    # suite faked the process table, so it never saw a line shaped like a real
    # one. Mocking the data source removed the exact failure mode.
    fake_ps "7777 /bin/bash -c grep -q claude-fw $TMP/proj/bin/claude-fw && echo yes"
    local out; out="$(run_block)"
    echo "$out" | grep -q "SKIP"
    echo "$out" | grep -q "WARNCOUNT=0"
    if echo "$out" | grep -q "7777"; then
        echo "a process that merely mentions the wrapper was counted as one" >&2
        false
    fi
}

@test "the wrapper is matched at argv position, not anywhere in the line" {
    # The positive half of the test above: the SAME pid, with the wrapper in
    # argv[1] instead of buried in a -c script, must be detected. Without this,
    # the test above is satisfiable by never matching anything at all.
    fake_ps "7777 /bin/bash $TMP/proj/bin/claude-fw -c"
    local out; out="$(run_block)"
    echo "$out" | grep -q "WARN"
    echo "$out" | grep -q "7777"
}

@test "a vendored consumer wrapper path is also recognised" {
    # Consumer projects run .agentic-framework/bin/claude-fw, not bin/claude-fw.
    fake_ps "5555 /bin/bash $TMP/proj/.agentic-framework/bin/claude-fw"
    local out; out="$(run_block)"
    echo "$out" | grep -q "WARN"
    echo "$out" | grep -q "5555"
}
