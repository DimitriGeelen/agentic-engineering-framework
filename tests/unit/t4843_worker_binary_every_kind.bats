#!/usr/bin/env bats
# T-4843 (832 msg 36c65b40, be.38 test E): run.sh wrote `worker binary: <path> (<version>)` to
# stderr.log on the claude branch only (T-4775). A codex/opencode review seat or an ollama-loop
# worker left no version anywhere, so a stale binary was invisible after the fact. Now one helper
# (_fw_record_worker_bin) writes the stderr line and the meta.json keys worker_bin/worker_version
# for every launch path; a --version that fails or hangs is recorded and never blocks the launch.
#
# House style (t4776_watchdog_sigkill.bats): the helper is lifted out of the LIVE run.sh template
# between its markers. Sandbox only: every binary is a stub under $BATS_TEST_TMPDIR.

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
SRC="$FRAMEWORK_ROOT/agents/termlink/termlink.sh"

setup() {
    T="$BATS_TEST_TMPDIR"
    WDIR="$T/dispatch/w1"; P="$T/proj"; STUB="$T/stub"
    mkdir -p "$WDIR" "$P" "$STUB"
    printf '{\n  "name": "w1",\n  "project": "%s",\n  "status": "running"\n}\n' "$P" > "$WDIR/meta.json"
}

extract() {  # <marker-name>
    python3 - "$SRC" "$1" <<'PY'
import sys
lines = open(sys.argv[1]).read().split("\n")
tag = sys.argv[2]
start = [i for i, l in enumerate(lines) if l.startswith("# --- %s (start)" % tag)]
end = [i for i, l in enumerate(lines) if l.startswith("# --- %s (end)" % tag)]
if not start or not end:
    raise SystemExit("%s markers not found in termlink.sh" % tag)
print("\n".join(lines[start[0]:end[0] + 1]))
PY
}

runsh_template() {
    python3 - "$SRC" <<'PY'
import sys
src = open(sys.argv[1]).read()
head = "cat > \"$wdir/run.sh\" <<'RUNEOF'\n"
s = src.index(head) + len(head)
print(src[s:src.index("\nRUNEOF\n", s)])
PY
}

# Run the live helper on <bin> [version-override] in a shell holding only WDIR.
record() {
    local block
    block=$(extract "T-4843 worker binary record") || return 1
    WDIR="$WDIR" bash -c "$block"'
_fw_record_worker_bin "$@"' _ "$@"
}

stub() {  # <name> <body>
    printf '#!/bin/bash\n%s\n' "$2" > "$STUB/$1"; chmod +x "$STUB/$1"
}

meta_key() { jq -r --arg k "$1" '.[$k] // "MISSING"' "$WDIR/meta.json"; }

@test "the helper is in the live run.sh template and every launch branch calls it" {
    run runsh_template
    [ "$status" -eq 0 ]
    tpl="$output"
    [[ "$tpl" == *"_fw_record_worker_bin() {"* ]]
    # claude, ollama-loop and the harness branch (codex/opencode/antigravity): one call each.
    [ "$(grep -c '^ *_fw_record_worker_bin ' <<<"$tpl")" -ge 3 ]
    # No per-branch copy of the worker --version probe survives outside the helper.
    helper=$(extract 'T-4843 worker binary record')
    outside=${tpl/"$helper"/}
    [ "$outside" != "$tpl" ]
    ! grep -E '"\$(WORKER_BIN|_WB|LOOP_BIN)" --version' <<<"$outside" || false
    [ "$(grep -c 'worker binary: ' <<<"$outside")" -eq 0 ]
}

@test "a binary that prints a version: stderr line and meta.json keys" {
    stub codex 'echo "codex-cli 9.9.43"; echo second-line'
    run record "$STUB/codex"
    [ "$status" -eq 0 ]
    grep -qxF "worker binary: $STUB/codex (codex-cli 9.9.43)" "$WDIR/stderr.log"
    [ "$(meta_key worker_bin)" = "$STUB/codex" ]
    [ "$(meta_key worker_version)" = "codex-cli 9.9.43" ]
    # The rest of meta.json is kept.
    [ "$(meta_key status)" = running ]
}

@test "a binary whose --version fails is recorded as such, and the helper still returns 0" {
    stub opencode 'echo "unknown flag" >&2; exit 3'
    run record "$STUB/opencode"
    [ "$status" -eq 0 ]
    grep -qF "worker binary: $STUB/opencode (version unknown: --version exited 3: unknown flag)" "$WDIR/stderr.log"
    [ "$(meta_key worker_version)" = "version unknown: --version exited 3: unknown flag" ]
}

@test "a binary whose --version hangs is cut off at 20 s and recorded, even if it leaves a child holding stdout" {
    stub hangs 'sleep 300 & sleep 300'
    SECONDS=0
    run record "$STUB/hangs"
    took=$SECONDS
    pkill -f "$STUB/hangs" 2>/dev/null || true
    [ "$status" -eq 0 ]
    [ "$took" -lt 40 ]
    grep -qF "worker binary: $STUB/hangs (version unknown: --version timed out after 20s)" "$WDIR/stderr.log"
    [ "$(meta_key worker_version)" = "version unknown: --version timed out after 20s" ]
}

@test "a caller-supplied version (a script run by an interpreter) is recorded verbatim" {
    run record "$STUB/loop.py" "Python 3.99.0; sha256 abc123"
    [ "$status" -eq 0 ]
    grep -qxF "worker binary: $STUB/loop.py (Python 3.99.0; sha256 abc123)" "$WDIR/stderr.log"
    [ "$(meta_key worker_version)" = "Python 3.99.0; sha256 abc123" ]
}

@test "no meta.json: the stderr line is still written and nothing is created" {
    rm "$WDIR/meta.json"
    stub claude 'echo "2.1.310 (Claude Code)"'
    run record "$STUB/claude"
    [ "$status" -eq 0 ]
    grep -qxF "worker binary: $STUB/claude (2.1.310 (Claude Code))" "$WDIR/stderr.log"
    [ ! -e "$WDIR/meta.json" ]
}

# The real run.sh, non-review: <worker-kind or empty>.
run_runsh() {
    runsh_template > "$WDIR/run.sh"
    echo "noop" > "$WDIR/prompt.md"
    [ -n "$1" ] && echo "$1" > "$WDIR/worker_kind.txt"
    stub termlink 'exit 0'
    env -i PATH="$STUB:/usr/bin:/bin" HOME="$T" _FW_RUNTIME_ENV_CLEAN=1 \
        timeout 120 bash "$WDIR/run.sh" w1 "$P" "$WDIR" 60 "" build "$STUB/fw" > "$T/run.out" 2>&1
}

@test "real run.sh, claude worker: binary and version in stderr.log and meta.json" {
    stub claude '[ "$1" = --version ] && { echo "2.1.310 (Claude Code)"; exit 0; }
echo "{\"type\":\"result\",\"result\":\"done\"}"'
    stub fw 'exit 0'
    run_runsh ""
    cat "$T/run.out" "$WDIR/stderr.log"
    grep -qxF "worker binary: $STUB/claude (2.1.310 (Claude Code))" "$WDIR/stderr.log"
    [ "$(meta_key worker_bin)" = "$STUB/claude" ]
    [ "$(meta_key worker_version)" = "2.1.310 (Claude Code)" ]
    [ "$(cat "$WDIR/exit_code")" = 0 ]
}

@test "real run.sh, ollama-loop worker: the loop script and its interpreter version are recorded" {
    mkdir -p "$P/tools"
    printf '#!/usr/bin/env python3\nimport sys\nopen(sys.argv[2] + "/exit_code", "w").write("0\\n")\n' > "$P/tools/ollama-tool-loop.py"
    chmod +x "$P/tools/ollama-tool-loop.py"
    stub fw 'exit 0'
    run_runsh ollama-loop
    cat "$T/run.out" "$WDIR/stderr.log"
    pyver=$(PATH="$STUB:/usr/bin:/bin" python3 --version 2>&1 | head -1)
    sha=$(sha256sum "$P/tools/ollama-tool-loop.py" | cut -c1-12)
    grep -qxF "worker binary: $P/tools/ollama-tool-loop.py ($pyver; sha256 $sha)" "$WDIR/stderr.log"
    [ "$(meta_key worker_bin)" = "$P/tools/ollama-tool-loop.py" ]
    [ "$(meta_key worker_version)" = "$pyver; sha256 $sha" ]
    [ "$(cat "$WDIR/exit_code")" = 0 ]
}

@test "real run.sh, codex and opencode review seats record binary and version (pytest, signed seats)" {
    cd "$FRAMEWORK_ROOT"
    run timeout 600 python3 -m pytest tests/unit/t4843_worker_binary_every_kind_test.py -q -p no:cacheprovider
    echo "$output" | tail -15
    [ "$status" -eq 0 ]
    [[ "$output" == *"2 passed"* ]]
}
