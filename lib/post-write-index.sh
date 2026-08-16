#!/usr/bin/env bash
# Post-write vector-index hook — T-1719 A1.
#
# Makes a just-written document retrievable NOW instead of at the next hourly
# cron. That framing matters: `index-reindex-hourly` (T-3014) already covers
# every write site, so this is LATENCY REDUCTION, not coverage. Nothing here is
# load-bearing for correctness, which is exactly why it is built to fail silent.
#
# WHAT THIS IS FOR, AND WHAT IT IS NOT
#
# Wire this only where a write produces ONE SMALL DOCUMENT AT ONE PATH — an
# episodic YAML, a pattern entry. Do NOT wire it into appends against the large
# aggregates (.context/project/learnings.yaml is ~386 chunks, decisions.yaml
# ~112). index_one() re-chunks and re-embeds the WHOLE file, so hooking an
# aggregate spends six embed batches to add one entry, and `add-decision` is
# called in a per-decision loop at task close (update-task.sh:2251) — N decisions
# would mean N full re-embeds of the same file in one command. For those, the
# hourly cron is the proportionate answer: the marginal entry is ~1/400th of the
# document and a ≤1h delay to retrievability costs nothing anyone can perceive.
# Analysis: docs/reports/OBS-292-learning-write-paths.md.
#
# FAILING SILENT IS THE CONTRACT, NOT LAZINESS
#
# This runs on the path of `fw task update --status work-completed`. A task close
# must never fail because the embedder is down, the venv is missing, sqlite-vec
# is not installed, or a reindex holds the lock. index_one() already returns
# {"skipped": reason} rather than raising for all of those; this wrapper adds the
# outer belt — timeout, stderr swallow, unconditional exit 0 — so that even an
# import-time explosion cannot take a close down with it. The cost of a missed
# index is one hour of staleness. The cost of a failed close is a blocked human.
#
# Usage:  fw_post_write_index <path> [<stale_path_to_purge_first>]
#
# The optional second argument handles the rename case: when a task file moves
# active/ -> completed/, the rows under the OLD path keep surfacing in retrieval
# with pre-close content. Purge them, then index the new path.

# Seconds before we give up. index_one() measured 1.6s on a 42-chunk document;
# 30s is generous enough to absorb a cold model load and still bounded enough
# that a hung embedder cannot stall a task close.
FW_POST_WRITE_INDEX_TIMEOUT="${FW_POST_WRITE_INDEX_TIMEOUT:-30}"

fw_post_write_index() {
    local target="$1"
    local stale_path="${2:-}"

    # Opt-out. Set FW_POST_WRITE_INDEX=0 to fall back to cron-only indexing.
    [ "${FW_POST_WRITE_INDEX:-1}" = "1" ] || return 0
    [ -n "$target" ] || return 0

    local root="${PROJECT_ROOT:-$PWD}"
    [ -f "$root/web/embeddings.py" ] || return 0

    # Everything below is best-effort by construction — see the header.
    (
        cd "$root" 2>/dev/null || exit 0
        timeout "$FW_POST_WRITE_INDEX_TIMEOUT" python3 - "$target" "$stale_path" <<'PY' 2>/dev/null
import sys, os
sys.path.insert(0, "web")
target, stale = sys.argv[1], (sys.argv[2] if len(sys.argv) > 2 else "")
try:
    import embeddings as e
except Exception:
    raise SystemExit(0)

# Purge rows under a path the document no longer lives at (the rename case).
# Skipped when a reindex owns the lock — index_one reports that itself, and a
# delete without the matching insert would leave a hole until the cron catches up.
if stale:
    try:
        rel = os.path.relpath(os.path.abspath(stale), e.PROJECT_ROOT)
        db = e._get_db()
        e._delete_path_rows(db, rel)
        db.commit()
    except Exception:
        pass

try:
    e.index_one(target)
except Exception:
    pass
PY
        exit 0
    ) || true

    return 0
}
