#!/usr/bin/env bats
# T-3182 (arc-012) — the continuous-run loop must say why it stopped.
#
# Before this, every exit path out of bin/claude-fw's main loop exited in silence.
# That makes "the loop stopped" and "the loop was never armed" the same observable
# state: a supervisor that quit leaves exactly what a supervisor with nothing to do
# leaves. Answering "why is the loop not running?" then costs process forensics on
# PIDs and file mtimes, and only works while that evidence happens to survive.
#
# These tests read the REAL wrapper — they lift its function and statically scan its
# loop — so editing bin/claude-fw moves them. A test written against a transcribed
# copy would stay green against a wrapper that had stopped recording entirely.

setup() {
    SRC="${BATS_TEST_DIRNAME}/../../bin/claude-fw"
    TMP="$(mktemp -d)"
}

teardown() {
    [ -n "${TMP:-}" ] && rm -rf "$TMP"
}

# Lift _record_loop_event out of the real wrapper and run it inside a scratch repo.
run_recorder() {
    local event="$1" reason="$2" detail="${3:-}" code="${4:-}"
    python3 - "$SRC" > "$TMP/fn.sh" <<'PY'
import sys
lines = open(sys.argv[1]).read().split('\n')
start = next(i for i, l in enumerate(lines) if l.startswith('_record_loop_event()'))
end = next(i for i in range(start, len(lines)) if lines[i] == '}')
print('\n'.join(lines[start:end + 1]))
PY
    (
        cd "$TMP" || exit 1
        git init -q . 2>/dev/null
        mkdir -p .context/working
        # shellcheck disable=SC1090
        restart_count=7
        . "$TMP/fn.sh"
        _record_loop_event "$event" "$reason" "$detail" "$code"
    )
}

# Every `exit` inside the wrapper's MAIN LOOP, with whether a _record_loop_event
# call precedes it within the same branch.
scan_loop_exits() {
    python3 - "$SRC" <<'PY'
import re, sys
lines = open(sys.argv[1]).read().split('\n')
# The main loop is the last top-level `while true; do` ... `done` in the file.
start = max(i for i, l in enumerate(lines) if l.strip() == 'while true; do' and not l.startswith(' '))
end = max(i for i, l in enumerate(lines) if l.strip() == 'done' and not l.startswith(' '))
for i in range(start, end + 1):
    if re.match(r'\s*exit\s', lines[i]):
        window = lines[max(start, i - 6):i]
        rec = [w for w in window if '_record_loop_event' in w]
        reason = ''
        if rec:
            m = re.search(r'_record_loop_event\s+\S+\s+(\S+)', rec[-1])
            reason = m.group(1) if m else '?'
        print(f"{'RECORDED' if rec else 'SILENT'}\t{reason}\t{lines[i].strip()}")
PY
}

@test "the recorder can be lifted from the real wrapper and writes a line" {
    run run_recorder exit no-signal "claude exited" 0
    [ "$status" -eq 0 ]
    [ -s "$TMP/.context/working/continuous-run.jsonl" ]
}

@test "the line is valid JSON carrying event, reason, restart_count and pid" {
    run_recorder exit max-restarts "hit the valve" 0
    run python3 -c "
import json
d = json.loads(open('$TMP/.context/working/continuous-run.jsonl').readline())
assert d['event'] == 'exit', d
assert d['reason'] == 'max-restarts', d
assert d['restart_count'] == 7, d
assert d['wrapper_pid'] > 0, d
assert d['exit_code'] == 0, d
assert d['detail'] == 'hit the valve', d
print('ok')
"
    [ "$status" -eq 0 ]
}

@test "ITERATIONS are recorded too, not only exits" {
    # A log that only records endings cannot distinguish 'went round three times
    # then stopped' from 'never started'.
    run_recorder iterate restart "session=S-1 tokens=290000"
    run grep -c '"event": "iterate"' "$TMP/.context/working/continuous-run.jsonl"
    [ "$output" = "1" ]
}

@test "the recorder never fails, even with no repo to write into" {
    # It runs on exit paths. A broken recorder must not change the wrapper's exit
    # code or block a restart.
    python3 - "$SRC" > "$TMP/fn.sh" <<'PY'
import sys
lines = open(sys.argv[1]).read().split('\n')
start = next(i for i, l in enumerate(lines) if l.startswith('_record_loop_event()'))
end = next(i for i in range(start, len(lines)) if lines[i] == '}')
print('\n'.join(lines[start:end + 1]))
PY
    run bash -c "cd /tmp && . '$TMP/fn.sh' && _record_loop_event exit no-git-repo '' 3; echo rc=\$?"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "rc=0"
}

@test "EVERY exit path in the main loop is recorded — none is silent" {
    run scan_loop_exits
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    if echo "$output" | grep -q "^SILENT"; then
        echo "Un-recorded exit path(s) in the main loop:"
        echo "$output" | grep "^SILENT"
        return 1
    fi
}

@test "CONTROL LEG: each exit path records a DISTINCT reason" {
    # Without this, 'record every exit' and 'record something on every exit' are
    # the same diff. A recorder wired with one constant reason satisfies the test
    # above and tells the operator nothing about WHICH path was taken.
    run scan_loop_exits
    [ "$status" -eq 0 ]
    reasons="$(echo "$output" | grep "^RECORDED" | cut -f2)"
    total="$(echo "$reasons" | wc -l)"
    uniq_n="$(echo "$reasons" | sort -u | wc -l)"
    [ "$total" -ge 4 ]
    [ "$total" -eq "$uniq_n" ]
}

@test "the wrapper still parses" {
    run bash -n "$SRC"
    [ "$status" -eq 0 ]
}
