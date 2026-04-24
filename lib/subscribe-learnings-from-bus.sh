#!/bin/bash
# subscribe-learnings-from-bus.sh — T-1168 B2 consumer-side poller for channel:learnings.
#
# Drains new learning envelopes from the hub event bus and appends de-duplicated
# entries to ${PROJECT_ROOT}/.context/project/received-learnings.yaml.
# Mirror of the publisher (lib/publish-learning-to-bus.sh, T-1168 B1).
#
# Design (per T-1217 discovery spike):
#   - Consumes via `termlink event collect --topic channel:learnings --payload-only`.
#     event.collect returns one payload per listening hub session per broadcast,
#     so composite-key dedup (origin_project, learning_id) is load-bearing.
#   - No --since cursor (per-session seq numbers can't form a single cursor).
#     Idempotence is achieved by the dedup set already on disk.
#   - Non-fatal: any error path exits 0 — cron-safe.
#   - Opt-out: FW_LEARNINGS_BUS_SUBSCRIBE=0 disables entirely.
#   - Silent no-op when termlink is missing, hub unreachable, or no events.
#   - Self-learning skip: envelopes whose origin_project matches ours are filtered.
#
# Recommended install: */5 * * * * /path/to/subscribe-learnings-from-bus.sh
#
# See: T-1217 (this task), T-1168 (publisher), T-1155 (bus), T-1214 (federation).

set -u
set -o pipefail

# Opt-out
[ "${FW_LEARNINGS_BUS_SUBSCRIBE:-1}" = "0" ] && exit 0

PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
RECEIVED_FILE="${PROJECT_ROOT}/.context/project/received-learnings.yaml"
LOG="${PROJECT_ROOT}/.context/working/.subscribe-learnings-bus.log"

mkdir -p "$(dirname "$LOG")" "$(dirname "$RECEIVED_FILE")" 2>/dev/null || true

_log() { printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >> "$LOG" 2>/dev/null || true; }

# Missing termlink → silent no-op
if ! command -v termlink >/dev/null 2>&1; then
    _log "skip-no-termlink"
    exit 0
fi

TIMEOUT="${FW_LEARNINGS_BUS_TIMEOUT:-30}"
OURS="${FW_ORIGIN_PROJECT:-$(basename "$PROJECT_ROOT")}"
TOPIC="channel:learnings"

# Seed the received file if missing
if [ ! -f "$RECEIVED_FILE" ]; then
    {
        printf -- '# Received learnings mirrored from %s topic (T-1217).\n' "$TOPIC"
        printf -- '# Managed by lib/subscribe-learnings-from-bus.sh — do not hand-edit.\n'
        printf -- 'received: []\n'
    } > "$RECEIVED_FILE" 2>/dev/null || true
fi

# Collect live events for $TIMEOUT seconds. Hub unreachable / no events → empty output.
TMP_RAW=$(mktemp 2>/dev/null || echo "/tmp/sub-learnings-$$.ndjson")
trap 'rm -f "$TMP_RAW" 2>/dev/null || true' EXIT

if ! termlink event collect --topic "$TOPIC" --timeout "$TIMEOUT" \
        --json --payload-only > "$TMP_RAW" 2>/dev/null; then
    _log "collect-failed (hub unreachable?)"
    exit 0
fi

RECEIVED=0
APPENDED=0
SKIPPED_SELF=0
SKIPPED_DUP=0
SKIPPED_MALFORMED=0

# Feed the NDJSON to python for parse + dedup + append. jq alone is awkward
# for the composite-key dedup against existing yaml.
python3 <<PY 2>/dev/null || _log "python-parse-failed"
import os, json, sys, re
raw_path = "$TMP_RAW"
received_path = "$RECEIVED_FILE"
log_path = "$LOG"
ours = "$OURS"

counts = {"received":0, "appended":0, "skipped_self":0, "skipped_dup":0, "skipped_malformed":0}

# Load existing composite keys from received-learnings.yaml. Split into
# per-entry blocks on lines starting with "- ", then pull origin_project +
# learning_id from each block (any order, any intervening fields).
seen = set()
def _yank(block, key):
    m = re.search(r"(?:^|\n)\s*" + re.escape(key) + r":\s*['\"]?([^'\"\n]+)['\"]?", block)
    return m.group(1).strip() if m else ""
try:
    with open(received_path) as f:
        content = f.read()
    blocks = re.split(r"(?m)^-\s", content)
    for b in blocks[1:]:  # skip preamble
        o = _yank(b, "origin_project")
        l = _yank(b, "learning_id")
        if o and l:
            seen.add((o, l))
except FileNotFoundError:
    pass

new_entries = []
try:
    with open(raw_path) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            counts["received"] += 1
            try:
                obj = json.loads(line)
            except Exception:
                counts["skipped_malformed"] += 1
                continue
            origin = obj.get("origin_project", "")
            lid = obj.get("learning_id", "")
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
            new_entries.append(obj)
except FileNotFoundError:
    pass

if new_entries:
    # YAML-safe scalar escape — double-quote and backslash-escape embedded quotes/newlines
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
        out.append("  received_at: " + q(__import__("datetime").datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")))
    # Append under the 'received:' list. Replace "received: []" with "received:\n<entries>",
    # else just append at EOF.
    try:
        with open(received_path) as f:
            current = f.read()
    except FileNotFoundError:
        current = "received: []\n"
    block = "\n".join(out) + "\n"
    if "received: []" in current:
        current = current.replace("received: []", "received:\n" + block.rstrip() + "\n", 1)
    else:
        # Already has entries — append lines
        if not current.endswith("\n"):
            current += "\n"
        current += block
    with open(received_path, "w") as f:
        f.write(current)
    counts["appended"] = len(new_entries)

with open(log_path, "a") as lf:
    import datetime
    ts = datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")
    lf.write(f"{ts} poll received={counts['received']} appended={counts['appended']} skipped_self={counts['skipped_self']} skipped_dup={counts['skipped_dup']} skipped_malformed={counts['skipped_malformed']}\n")
PY

exit 0
