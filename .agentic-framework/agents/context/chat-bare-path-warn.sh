#!/bin/bash
# UserPromptSubmit hook — chat bare-path warner (T-2183, Slice 2 of T-2181)
#
# Companion to chat-bare-path-scan.sh. On each UserPromptSubmit, reads any
# outstanding bare-path violations recorded by the scanner, emits one agent-visible
# <system-reminder> block per violation to stdout (UserPromptSubmit stdout becomes
# additional context on the agent's next turn), then TRUNCATES the violations file
# (consume-on-show — each violation is surfaced exactly once).
#
# The reminder points the agent at the correct mechanism: `fw task review[-batch]`
# emits class-correct full URLs (T-2182 helper); bare /review/T-XXX paths in chat
# are the regression this backstop guards (T-2125 / T-2129 / T-2181).
#
# SAFETY: non-destructive (reads + truncates one YAML file), always exits 0.
#
# Part of: Agentic Engineering Framework — T-2183 (T-2181 GO Candidate D, Slice 2)

set -uo pipefail

PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
WORKING_DIR="${PROJECT_ROOT}/.context/working"
VIOLATIONS="${WORKING_DIR}/.bare-path-violations.yaml"

# Drain stdin (hook convention); UserPromptSubmit payload not needed here.
cat > /dev/null 2>&1 || true

[ -f "$VIOLATIONS" ] || exit 0

python3 - "$VIOLATIONS" <<'PYEOF'
import sys, os, re

path = sys.argv[1]
try:
    with open(path, "r") as f:
        body = f.read()
except Exception:
    sys.exit(0)

# Parse the simple `- path: "..."` entries the scanner writes.
paths = re.findall(r'^- path:\s*"?([^"\n]+)"?\s*$', body, flags=re.MULTILINE)
# Strip any trailing quote artefact from json.dumps round-trip.
paths = [p.rstrip('"').strip() for p in paths if p.strip()]

if not paths:
    # Nothing actionable — still truncate so a malformed file doesn't wedge.
    try:
        open(path, "w").close()
    except Exception:
        pass
    sys.exit(0)

# De-dupe, preserve order.
seen, uniq = set(), []
for p in paths:
    if p not in seen:
        seen.add(p)
        uniq.append(p)

count = len(uniq)
plural = "path" if count == 1 else "paths"
joined = ", ".join(uniq[:10])
if count > 10:
    joined += f", … (+{count - 10} more)"

print("<system-reminder>")
print(f"BARE WATCHTOWER PATH IN CHAT OUTPUT ({count} {plural} in your last turn): {joined}")
print("These were written as bare paths, not clickable URLs. Watchtower handoffs MUST")
print("be full URLs (http://<host>/review/T-XXX), not bare /review/T-XXX. Regenerate them")
print("with `fw task review T-XXX` (single) or `fw task review-batch T-A T-B …` (multi) and")
print("paste the emitted URL(s) verbatim — the helper routes inception→/inception/<id>,")
print("build→/review/<id> automatically. Origin: T-2125 / T-2181 (bare-path regression class).")
print("</system-reminder>")

# Consume-on-show: truncate so each violation surfaces exactly once.
try:
    open(path, "w").close()
except Exception:
    pass

sys.exit(0)
PYEOF

exit 0
