#!/usr/bin/env bash
# Recall-usage verdict — T-3019 (T-3005 slice 6a, the "Used" signal).
#
# Sibling to lib/index-health.sh, and extracted for the same reason: a verdict
# that can only be exercised by running the whole of `fw doctor` is a verdict
# nobody tests twice.
#
# Emits one line: VERDICT|MESSAGE|HINT
#   OK   — recall was used at least once inside the window
#   WARN — zero rows in the window (the G-064 zero-consumer signal)
#   SKIP — web.recall_telemetry not importable (consumer without the extras)
#
# What this checks is deliberately NOT whether recall works. Freshness, liveness
# and correctness each have their own control already. This one answers the
# question none of those can: is anybody actually asking? A substrate can pass
# all three other signals while being queried by nothing but its own tests —
# which is the shape of every dead control this framework has shipped.
#
# Embed-free by construction, like its sibling: it reads a JSONL file. A usage
# check that needed the embedder would go quiet exactly when usage stopped,
# reporting the absence of a signal it had itself prevented from existing.

# recall_usage_verdict [WINDOW_DAYS]
# Window defaults to FW_RECALL_USAGE_DAYS / .framework.yaml / the registry.
recall_usage_verdict() {
    local window="${1:-}"
    if [ -z "$window" ]; then
        window=$(fw_config RECALL_USAGE_DAYS 2>/dev/null || echo 7)
    fi
    [ -z "$window" ] && window=7

    local root="${PROJECT_ROOT:-$PWD}"
    local out
    out=$(cd "$root" && WINDOW="$window" python3 -c '
import os, sys

window = float(os.environ.get("WINDOW") or 7)

try:
    from web.recall_telemetry import usage_summary
except Exception as exc:  # consumer without the embedding extras, most likely
    print(f"SKIP|recall usage: web.recall_telemetry not importable here ({type(exc).__name__})|")
    sys.exit(0)

try:
    s = usage_summary(window_days=window)
except Exception as exc:
    print(f"WARN|recall usage: check errored ({str(exc)[:80]})|Run: fw doctor")
    sys.exit(0)

rows = s.get("rows", 0)

# Zero is reported as zero, with the remedy naming the two things it could
# mean. A silent OK here is precisely how a subsystem stays plausibly alive
# for months while nothing calls it.
if not rows:
    print(f"WARN|recall usage: 0 queries in {window:g}d — semantic recall may have no consumers"
          f"|Either nobody is searching (try: fw recall \"something\"), or callers are failing "
          f"before they reach it (check: fw doctor for the embed path)")
    sys.exit(0)

misses = s.get("misses", 0)
unavailable = s.get("unavailable", 0)
noun = "query" if rows == 1 else "queries"
detail = f"{rows} {noun} in {window:g}d"
if unavailable:
    print(f"WARN|recall usage: {detail}, {unavailable} could not run"
          f"|The embed path failed mid-query. Check: fw doctor")
    sys.exit(0)

extra = f", {misses} miss" if misses else ""
print(f"OK|recall usage: {detail}{extra}|")
' 2>/dev/null)

    if [ -z "$out" ]; then
        echo "SKIP|recall usage: not determinable here|"
    else
        echo "$out"
    fi
}
