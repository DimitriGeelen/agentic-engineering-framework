#!/usr/bin/env bash
# runme-watch.sh — the agent's side of runme-signal.sh (832 T-1003).
#
# Run it in the BACKGROUND when handing the operator a runme.sh. It remembers where the event
# file and the TermLink topic stand now, then exits — printing the new event line(s) — as soon as
# anything new appears in either. Its exit is what wakes the agent; the agent reads the log, acts,
# and re-arms it for the next event.
#
#   bash tools/runme-watch.sh [timeout-seconds]      default 0 = no limit; exit 0 = event, 3 = timeout
#   T-1117: there is no default limit. A background watch already dies with its session (T-1050), so an 8 h
#   cap (copied in T-1003 without a reason) only ended the watch while a run could still come. Pass a limit
#   for tests.
set -u
ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
FILE="${RUNME_EVENTS_FILE:-$ROOT/.context/working/runme.events}"
TOPIC="${RUNME_SIGNAL_TOPIC:-runme-832}"
# Only THIS project's posts count (2026-10-03: 055-agentic-fleet-cockpit posted "STOPPED rc=1" to
# runme-832, a copy of this script with the topic name baked in, and woke us for a run that was not
# ours). TermLink labels each post with the poster's project, e.g. "(832-Workflow-designer)".
LABEL="(${RUNME_WATCH_PROJECT:-$(basename "$ROOT")})"
LIMIT="${1:-0}"

lines() { [ -f "$FILE" ] && wc -l < "$FILE" || echo 0; }
topic_next() {  # next offset on the topic (0 when the topic does not exist / hub unreachable)
    timeout 20 termlink channel subscribe "$TOPIC" --json --limit 1000 --cursor "${1:-0}" 2>/dev/null \
      | python3 -c 'import sys,json
o=[json.loads(l).get("offset") for l in sys.stdin if l.strip().startswith("{")]
o=[x for x in o if isinstance(x,int)]
print(max(o)+1 if o else int(sys.argv[1]))' "${1:-0}" 2>/dev/null || echo "${1:-0}"
}

# T-1050: the watch lives only as long as the Claude session that armed it (a background task dies
# with its session, silently: 2026-10-05). Record who armed it, so scripts/session-start-alerts.sh
# can tell a NEW session that a handed-over runme.sh has nothing listening and the watch must be
# re-armed. Removed when an event is reported (the agent then re-arms, writing a fresh one); left
# in place on timeout or when killed, which is exactly the state the next session must see.
WATCH="${RUNME_WATCH_FILE:-$ROOT/.context/working/runme.watch}"
armer=""; p=$$
while [ -n "$p" ] && [ "$p" -gt 1 ]; do
    [ "$(cat /proc/"$p"/comm 2>/dev/null)" = claude ] && { armer=$p; break; }
    p=$(awk '{print $4}' /proc/"$p"/stat 2>/dev/null)
done
mkdir -p "$(dirname "$WATCH")" 2>/dev/null
printf 'watch_pid=%s claude_pid=%s armed=%s\n' "$$" "${armer:-none}" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$WATCH" 2>/dev/null

f0=$(lines)
t0=0; command -v termlink >/dev/null 2>&1 && { t=$(topic_next 0); while [ "$t" != "$t0" ]; do t0=$t; t=$(topic_next "$t0"); done; }
start=$(date +%s)
while [ "$LIMIT" -eq 0 ] || [ $(( $(date +%s) - start )) -lt "$LIMIT" ]; do
    f=$(lines)
    if [ "$f" -gt "$f0" ]; then
        echo "runme event (file):"; tail -n +"$((f0 + 1))" "$FILE"; rm -f "$WATCH"; exit 0
    fi
    if command -v termlink >/dev/null 2>&1; then
        new=$(timeout 20 termlink channel subscribe "$TOPIC" --cursor "$t0" --limit 50 2>/dev/null | grep -E '^\[[0-9]+\]' | grep -F " $LABEL ")
        [ -n "$new" ] && { echo "runme event (topic $TOPIC):"; echo "$new" | cut -c1-400; rm -f "$WATCH"; exit 0; }
    fi
    sleep 3
done
echo "runme-watch: no event in ${LIMIT}s"
exit 3
