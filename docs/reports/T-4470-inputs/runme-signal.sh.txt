# runme-signal.sh — runme.sh tells the agent what it is doing, as it happens (832 T-1003).
#
# SOURCE IT from every runme.sh, right after the log is set up:
#     . "$PROJ/tools/runme-signal.sh"; runme_signal_init "T-988 land upgrade" "$LOG"
#     runme_signal step "1/2 confirmed: pristine commit"
#     runme_signal step "1/2 done: $(git rev-parse --short HEAD)"
# runme_signal_init installs an EXIT trap that records `done rc=0` or `STOPPED rc=N` however the
# script ends (fail(), Ctrl-C, a crash), so the agent hears about a stop even when no line says so.
#
# WHY. The operator runs runme.sh from a plain command prompt; the agent only acts when something
# wakes it. A message alone does not (a sidecar inbox is read at the next prompt). So each event
# is one short line, written two ways, and the agent keeps tools/runme-watch.sh armed in the
# background, which exits on the first new line and so wakes it:
#   1. appended to .context/working/runme.events   (local, always works)
#   2. posted to TermLink topic runme-832           (durable, visible to Watchtower and other
#      agents, works across hosts; best effort)
# Neither may slow or break the script: the TermLink post runs detached with a 5 s timeout, and
# every failure is swallowed — a missing hub costs nothing but the second copy.
#
# Line format:  <utc-iso> <run-id> <event> <text>     event: started | step | done | STOPPED

# The project root comes from THIS file's location, not the caller's cwd: the 0.15.3 release was run
# from another directory and its events reached the topic but not this file (2026-10-03).
RUNME_EVENTS_FILE="${RUNME_EVENTS_FILE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd)/.context/working/runme.events}"
RUNME_SIGNAL_TOPIC="${RUNME_SIGNAL_TOPIC:-runme-832}"
RUNME_RUN_ID="${RUNME_RUN_ID:-runme-$(date +%Y%m%dT%H%M%S)-$$}"
# T-1203: the post is signed with 832's own key, not the host key every co-resident session shares. The launcher
# runs in the operator's terminal, which has no project env, so the key is chosen here. FAIL CLOSED: TermLink
# CREATES a key at a missing TERMLINK_IDENTITY_FILE path, so with no key file the hub copy is skipped, never minted.
RUNME_SIGNAL_KEY="${RUNME_SIGNAL_KEY:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd)/.context/secrets/termlink-identity.key}"

runme_signal() {  # runme_signal <event> <text...>
    local ev="$1"; shift
    local line
    line="$(date -u +%Y-%m-%dT%H:%M:%SZ) $RUNME_RUN_ID $ev $*"
    { mkdir -p "$(dirname "$RUNME_EVENTS_FILE")" && printf '%s\n' "$line" >> "$RUNME_EVENTS_FILE"; } 2>/dev/null || true
    if [ "${RUNME_SIGNAL_NO_TERMLINK:-0}" != 1 ] && command -v termlink >/dev/null 2>&1 \
            && [ -f "$RUNME_SIGNAL_KEY" ]; then
        ( TERMLINK_IDENTITY_FILE="$RUNME_SIGNAL_KEY" TERMLINK_IDENTITY_NO_CREATE=1 setsid timeout 5 termlink channel post "$RUNME_SIGNAL_TOPIC" \
              --ensure-topic --msg-type runme-event --payload "$line" >/dev/null 2>&1 & ) 2>/dev/null || true
    fi
    return 0
}

runme_signal_init() {  # runme_signal_init <what this run does> [log path]
    runme_signal started "$1${2:+ — log: $2}"
    trap '_rc=$?; if [ "$_rc" = 0 ]; then runme_signal done "rc=0"; else runme_signal STOPPED "rc=$_rc"; fi' EXIT
    trap 'runme_signal STOPPED "interrupted (Ctrl-C)"; trap - INT EXIT; kill -INT $$' INT
    trap 'runme_signal STOPPED "terminated (SIGTERM)"; trap - TERM EXIT; kill -TERM $$' TERM
    trap 'runme_signal STOPPED "terminal closed (SIGHUP)"; trap - HUP EXIT; kill -HUP $$' HUP
}

# runme_confirm <question>: y/N from the TERMINAL, with typeahead discarded first. Keys pressed
# while an earlier step was still busy sit in the tty buffer and would otherwise answer this
# prompt before it is asked (seen 2026-10-02: a 10-minute post-commit hook, and step 2 of the
# T-988 landing was confirmed the instant step 1 returned). Use it for every confirmation.
runme_confirm() {
    local a _junk
    while read -r -t 0.05 -n 10000 _junk </dev/tty 2>/dev/null; do :; done
    read -r -p "$1 [y/N] " a </dev/tty || a=n
    [ "$a" = y ] || [ "$a" = Y ]
}
