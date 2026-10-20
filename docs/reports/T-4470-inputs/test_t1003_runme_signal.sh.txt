#!/usr/bin/env bash
# T-1003: runme-signal.sh + runme-watch.sh, end to end, on a scratch event file and a test topic.
# Run: bash tests/test_t1003_runme_signal.sh   (exit 0 = all legs pass)
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
export RUNME_SIGNAL_TOPIC="runme-832-test"
pass=0; fail=0
ok() { if [ "$1" = 0 ]; then pass=$((pass+1)); echo "PASS $2"; else fail=$((fail+1)); echo "FAIL $2 ${3:-}"; fi; }

fake() {  # fake <rc> : a minimal runme.sh that sources the helper
cat > "$T/fake.sh" <<EOF
. "$ROOT/tools/runme-signal.sh"
runme_signal_init "test run" "$T/log"
runme_signal step "1/1 confirmed"
${2:-}
exit $1
EOF
}

# 1. success: watcher armed BEFORE the run exits on the first event; file has started/step/done
export RUNME_EVENTS_FILE="$T/ev1"
bash "$ROOT/tools/runme-watch.sh" 60 > "$T/w1" 2>&1 & W=$!
sleep 4; fake 0; bash "$T/fake.sh"
wait $W; rc=$?
grep -q " started test run" "$T/w1"; ok $(( rc==0 ? $? : 1 )) "1 watcher armed before the run exits on its first event (rc=$rc)"
grep -q " started " "$T/ev1" && grep -q " step 1/1 confirmed" "$T/ev1" && grep -q " done rc=0" "$T/ev1"; ok $? "1b success run writes started, step, done rc=0"

# 2. failure: STOPPED with the exit code, written by the EXIT trap (no line in the script says so)
export RUNME_EVENTS_FILE="$T/ev2"; fake 1; bash "$T/fake.sh"
grep -q " STOPPED rc=1" "$T/ev2"; ok $? "2 failing run records STOPPED rc=1 via the trap"

# 3. Ctrl-C: STOPPED interrupted
# (launched from python in its own process group, and the GROUP is signalled — as a terminal does
#  on Ctrl-C. A background job of a non-interactive shell starts with SIGINT ignored, which bash
#  cannot trap; and a signal to bash alone waits for the foreground child before the trap runs.)
for sig in INT TERM HUP; do
  export RUNME_EVENTS_FILE="$T/ev3-$sig"; fake 0 "sleep 20"
  python3 -c "import subprocess,signal,time,sys; import os; p=subprocess.Popen(['bash','$T/fake.sh'], start_new_session=True); time.sleep(2); os.killpg(p.pid, getattr(signal,'SIG$sig')); p.wait(timeout=10)" 2>/dev/null
  grep -q " STOPPED " "$T/ev3-$sig" && ! grep -q " done rc=0" "$T/ev3-$sig"; ok $? "3 SIG$sig records STOPPED (and not done): $(grep -o 'STOPPED.*' "$T/ev3-$sig" | head -1)"
done

# 4. a hanging termlink must not slow the script (post runs detached)
mkdir -p "$T/bin"; printf '#!/bin/sh\nsleep 30\n' > "$T/bin/termlink"; chmod +x "$T/bin/termlink"
export RUNME_EVENTS_FILE="$T/ev4"; fake 0; s=$(date +%s); PATH="$T/bin:$PATH" bash "$T/fake.sh"; d=$(( $(date +%s) - s ))
[ "$d" -le 2 ] && grep -q " done rc=0" "$T/ev4"; ok $? "4 hanging termlink: run took ${d}s, file still written"

# 5. topic path alone: the watcher reads a DIFFERENT file, so only TermLink can wake it
if command -v termlink >/dev/null && timeout 10 termlink channel list >/dev/null 2>&1; then
    RUNME_EVENTS_FILE="$T/unused" bash "$ROOT/tools/runme-watch.sh" 60 > "$T/w5" 2>&1 & W=$!
    sleep 6; export RUNME_EVENTS_FILE="$T/ev5"; fake 0; bash "$T/fake.sh"
    wait $W; rc=$?
    grep -q "topic runme-832-test" "$T/w5" && grep -q "started test run" "$T/w5"; ok $(( rc==0 ? $? : 1 )) "5 watcher woken over the TermLink topic alone (rc=$rc)"
else
    echo "SKIP 5 hub unreachable: topic path not measured"; fail=$((fail+1))
fi

# 7. another project posting to the same topic does not wake us (2026-10-03, 055-agentic-fleet-cockpit)
if command -v termlink >/dev/null && timeout 10 termlink channel list >/dev/null 2>&1; then
    mkdir -p "$T/foreign"
    RUNME_EVENTS_FILE="$T/unused7" bash "$ROOT/tools/runme-watch.sh" 25 > "$T/w7" 2>&1 & W=$!
    sleep 6; ( cd "$T/foreign" && timeout 10 termlink channel post "$RUNME_SIGNAL_TOPIC" --ensure-topic \
        --payload "runme-event: foreign STOPPED rc=1" >/dev/null 2>&1 )
    wait $W; rc=$?
    [ "$rc" = 3 ]; ok $? "7 a post from another project on the same topic does not wake the watcher (rc=$rc)"
else
    echo "SKIP 7 hub unreachable"; fail=$((fail+1))
fi

# 8. run from ANOTHER directory, the default events file is still this project's (2026-10-03: the
#    0.15.3 release ran from elsewhere and its events never reached .context/working/runme.events)
got=$(cd "$T" && env -u RUNME_EVENTS_FILE bash -c '. "$1/tools/runme-signal.sh"; echo "$RUNME_EVENTS_FILE"' _ "$ROOT")
[ "$got" = "$ROOT/.context/working/runme.events" ]; ok $? "8 default events file follows the script, not the caller's cwd ($got)"

# 6. timeout exit is distinct and says so
RUNME_EVENTS_FILE="$T/quiet" RUNME_SIGNAL_TOPIC="runme-832-test-quiet" bash "$ROOT/tools/runme-watch.sh" 2 > "$T/w6" 2>&1; rc=$?
[ "$rc" = 3 ] && grep -q "no event" "$T/w6"; ok $? "6 nothing happens: watcher exits 3 and says so"

echo; echo "T-1003 runme signal: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
