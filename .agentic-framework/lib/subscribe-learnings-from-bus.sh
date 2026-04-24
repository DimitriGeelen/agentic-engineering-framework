#!/bin/bash
# subscribe-learnings-from-bus.sh — T-1168 B2 consumer-side poller for channel:learnings.
#
# Drains new learning envelopes from a hub session's event bus and appends
# de-duplicated entries to ${PROJECT_ROOT}/.context/project/received-learnings.yaml.
# Mirror of the publisher (lib/publish-learning-to-bus.sh, T-1168 B1).
#
# Design (revised per T-1219 after T-1217 v1 bug):
#   - Consumes via `termlink event poll <session> --topic channel:learnings
#     --since=<cursor>`. Events broadcast to `channel:learnings` fan out to
#     every registered session's private event bus; polling any one session
#     gets the full stream. (v1 used `event collect` which only delivers
#     events broadcast by the collector's own session — missed cross-session
#     traffic entirely.)
#   - Per-session cursor stored in `.context/working/.subscribe-learnings-bus.cursor`
#     (YAML: target_session + since). Cursor resets to 0 when target_session
#     is no longer registered; composite-key dedup against existing yaml
#     keeps replay idempotent.
#   - Composite-key dedup `(origin_project, learning_id)` retained as safety net.
#   - Non-fatal: any error path exits 0 — cron-safe.
#   - Opt-out: FW_LEARNINGS_BUS_SUBSCRIBE=0 disables entirely.
#   - Silent no-op when termlink missing, hub down, or no sessions.
#   - Self-filter: envelopes whose origin_project matches ours are filtered.
#
# Recommended install: */5 * * * * /path/to/subscribe-learnings-from-bus.sh
#
# See: T-1217 (original), T-1219 (this fix), T-1168 (publisher), T-1155 (bus).

set -u
set -o pipefail

# Opt-out
[ "${FW_LEARNINGS_BUS_SUBSCRIBE:-1}" = "0" ] && exit 0

PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
RECEIVED_FILE="${PROJECT_ROOT}/.context/project/received-learnings.yaml"
CURSOR_FILE="${PROJECT_ROOT}/.context/working/.subscribe-learnings-bus.cursor"
LOG="${PROJECT_ROOT}/.context/working/.subscribe-learnings-bus.log"

mkdir -p "$(dirname "$LOG")" "$(dirname "$RECEIVED_FILE")" 2>/dev/null || true

_log() { printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >> "$LOG" 2>/dev/null || true; }

if ! command -v termlink >/dev/null 2>&1; then
    _log "skip-no-termlink"
    exit 0
fi

TIMEOUT="${FW_LEARNINGS_BUS_TIMEOUT:-5}"
OURS="${FW_ORIGIN_PROJECT:-$(basename "$PROJECT_ROOT")}"
TOPIC="channel:learnings"

# Seed received file if missing
if [ ! -f "$RECEIVED_FILE" ]; then
    {
        printf -- '# Received learnings mirrored from %s topic (T-1217/T-1219).\n' "$TOPIC"
        printf -- '# Managed by lib/subscribe-learnings-from-bus.sh — do not hand-edit.\n'
        printf -- 'received: []\n'
    } > "$RECEIVED_FILE" 2>/dev/null || true
fi

# --- pick target session + load cursor ---
# List ready sessions. If list fails (hub down), silent no-op.
SESSIONS_JSON=$(termlink list --json 2>/dev/null) || {
    _log "skip-list-failed"
    exit 0
}

# Read saved cursor (simple grep — only 2 fields)
SAVED_SESSION=$(grep -E '^target_session:' "$CURSOR_FILE" 2>/dev/null | awk -F': *' '{print $2}' | tr -d "\"' ")
SAVED_SINCE=$(grep -E '^since:' "$CURSOR_FILE" 2>/dev/null | awk -F': *' '{print $2}' | tr -d "\"' ")
[ -z "$SAVED_SINCE" ] && SAVED_SINCE=0

# Validate that SAVED_SESSION is still in the ready list; else pick first ready
TARGET=$(python3 <<PY
import json, sys
data = json.loads('''${SESSIONS_JSON//\'/\\\'}''')
saved = "${SAVED_SESSION}"
ready = [s for s in data.get("sessions", []) if s.get("state") == "ready"]
if not ready:
    sys.exit(0)
# Prefer saved if still present
for s in ready:
    if s.get("display_name") == saved:
        print(saved)
        sys.exit(0)
# Else first ready
print(ready[0].get("display_name", ""))
PY
)
if [ -z "$TARGET" ]; then
    _log "skip-no-ready-sessions"
    exit 0
fi
# If target changed, reset cursor
if [ "$TARGET" != "$SAVED_SESSION" ]; then
    _log "target-changed old=$SAVED_SESSION new=$TARGET reset-cursor"
    SAVED_SINCE=0
fi

# --- poll the target session ---
TMP_RAW=$(mktemp 2>/dev/null || echo "/tmp/sub-learnings-$$.json")
trap 'rm -f "$TMP_RAW" 2>/dev/null || true' EXIT

if ! termlink event poll "$TARGET" --topic "$TOPIC" --since "$SAVED_SINCE" \
        --json --timeout "$TIMEOUT" > "$TMP_RAW" 2>/dev/null; then
    _log "poll-failed target=$TARGET since=$SAVED_SINCE"
    exit 0
fi

# --- parse + dedup + append + advance cursor ---
python3 <<PY 2>/dev/null || _log "python-parse-failed"
import os, json, re, datetime
raw_path = "$TMP_RAW"
received_path = "$RECEIVED_FILE"
cursor_path = "$CURSOR_FILE"
log_path = "$LOG"
ours = "$OURS"
target = "$TARGET"
saved_since = int("$SAVED_SINCE") if "$SAVED_SINCE".isdigit() else 0

counts = {"received":0, "appended":0, "skipped_self":0, "skipped_dup":0, "skipped_malformed":0}
max_seq = saved_since

# Existing (origin_project, learning_id) seen set — parse blocks
seen = set()
def _yank(block, key):
    m = re.search(r"(?:^|\n)\s*" + re.escape(key) + r":\s*['\"]?([^'\"\n]+)['\"]?", block)
    return m.group(1).strip() if m else ""
try:
    with open(received_path) as f:
        content = f.read()
    blocks = re.split(r"(?m)^-\s", content)
    for b in blocks[1:]:
        o = _yank(b, "origin_project")
        l = _yank(b, "learning_id")
        if o and l:
            seen.add((o, l))
except FileNotFoundError:
    pass

try:
    with open(raw_path) as f:
        data = json.load(f)
except Exception:
    data = {"events": []}

events = data.get("events") or []
new_entries = []
for ev in events:
    counts["received"] += 1
    seq = ev.get("seq")
    if isinstance(seq, int) and seq > max_seq:
        max_seq = seq
    payload = ev.get("payload") or {}
    if not isinstance(payload, dict):
        counts["skipped_malformed"] += 1
        continue
    origin = payload.get("origin_project", "")
    lid = payload.get("learning_id", "")
    if not origin or not lid:
        counts["skipped_malformed"] += 1
        continue
    if origin == ours:
        counts["skipped_self"] += 1
        continue
    key = (origin, lid)
    if key in seen:
        counts["skipped_dup"] += 1
        continue
    seen.add(key)
    new_entries.append(payload)

if new_entries:
    def q(v):
        if v is None:
            return '""'
        s = str(v).replace("\\\\", "\\\\\\\\").replace('"', '\\\\"').replace("\n", "\\\\n")
        return '"' + s + '"'
    out = []
    for e in new_entries:
        out.append("- origin_project: " + q(e.get("origin_project","")))
        out.append("  origin_hub_fingerprint: " + q(e.get("origin_hub_fingerprint","")))
        out.append("  learning_id: " + q(e.get("learning_id","")))
        out.append("  learning: " + q(e.get("learning","")))
        out.append("  task: " + q(e.get("task","")))
        out.append("  source: " + q(e.get("source","")))
        out.append("  date: " + q(e.get("date","")))
        out.append("  received_at: " + q(datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")))
    try:
        with open(received_path) as f:
            current = f.read()
    except FileNotFoundError:
        current = "received: []\n"
    block = "\n".join(out) + "\n"
    if "received: []" in current:
        current = current.replace("received: []", "received:\n" + block.rstrip() + "\n", 1)
    else:
        if not current.endswith("\n"):
            current += "\n"
        current += block
    with open(received_path, "w") as f:
        f.write(current)
    counts["appended"] = len(new_entries)

# Advance cursor: --since is EXCLUSIVE (seq > since), so store max_seq as-is
next_since = max_seq if max_seq > saved_since else saved_since
with open(cursor_path, "w") as cf:
    cf.write(f"target_session: {target}\nsince: {next_since}\n")

with open(log_path, "a") as lf:
    ts = datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")
    lf.write(f"{ts} poll target={target} since_in={saved_since} since_out={next_since} received={counts['received']} appended={counts['appended']} skipped_self={counts['skipped_self']} skipped_dup={counts['skipped_dup']} skipped_malformed={counts['skipped_malformed']}\n")
PY

exit 0
