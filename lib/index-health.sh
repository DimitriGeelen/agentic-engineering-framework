#!/usr/bin/env bash
# Vector-index freshness verdict — T-3013 (T-3005 slice 4).
#
# Extracted from bin/fw doctor so it can be tested without running doctor. The
# first version lived inline; pinning its three verdicts then cost five full
# doctor runs per suite, which is a test nobody would run twice — the same
# "instrument that never fires" problem this whole arc is about, one level up.
#
# Emits one line: VERDICT|MESSAGE|HINT
#   OK   — index is younger than the threshold
#   WARN — older than the threshold, or age not determinable
#   SKIP — web.embeddings not importable (consumer without the embedding extras)
#
# Embed-free by construction: it reads the corpus manifest, or stats the database
# file. A health check that needs the embedder to answer goes quiet exactly when
# the subsystem it watches is down, which is the failure being fixed rather than
# a new one to add. The canary — which does embed — runs in `fw audit --section
# corpus-health` instead, and never in pre-push (OBS-253).

# index_freshness_verdict [THRESHOLD_DAYS]
# Threshold defaults to FW_INDEX_STALE_DAYS / .framework.yaml / the registry.
index_freshness_verdict() {
    local threshold="${1:-}"
    if [ -z "$threshold" ]; then
        threshold=$(fw_config INDEX_STALE_DAYS 2>/dev/null || echo 7)
    fi
    [ -z "$threshold" ] && threshold=7

    local root="${PROJECT_ROOT:-$PWD}"
    local out
    out=$(cd "$root" && THRESHOLD="$threshold" python3 -c '
import json, os, sys

threshold = float(os.environ.get("THRESHOLD") or 7)

try:
    from web.embeddings import index_freshness
except Exception as exc:  # consumer without the embedding extras, most likely
    print(f"SKIP|vector index: web.embeddings not importable here ({type(exc).__name__})|")
    sys.exit(0)

try:
    f = index_freshness()
except Exception as exc:
    print(f"WARN|vector index: freshness check errored ({str(exc)[:80]})|Run: fw doctor")
    sys.exit(0)

age, src = f.get("age_seconds"), f.get("source")

# Absence is reported as absence. A 0.0 here would read as "built this instant",
# which is precisely how a five-month-dead index passed for healthy (T-3004).
if age is None or src == "unknown":
    print("WARN|vector index: age unknown (no manifest, no readable index)"
          "|Build one: fw serve, then visit /search")
    sys.exit(0)

days = age / 86400.0
if days > threshold:
    print(f"WARN|vector index: {days:.1f} days old (threshold {threshold:g}d, source: {src})"
          f"|Raise it: fw config set INDEX_STALE_DAYS <n>")
else:
    print(f"OK|vector index: {days:.1f} days old (source: {src})|")
' 2>/dev/null)

    if [ -z "$out" ]; then
        echo "SKIP|vector index: freshness not determinable here|"
    else
        echo "$out"
    fi
}
