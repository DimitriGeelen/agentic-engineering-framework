# post-write-index

> TODO: describe what this component does

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/post-write-index.sh`

## What It Does

Post-write vector-index hook — T-1719 A1.
Makes a just-written document retrievable NOW instead of at the next hourly
cron. That framing matters: `index-reindex-hourly` (T-3014) already covers
every write site, so this is LATENCY REDUCTION, not coverage. Nothing here is
load-bearing for correctness, which is exactly why it is built to fail silent.
WHAT THIS IS FOR, AND WHAT IT IS NOT
Wire this only where a write produces ONE SMALL DOCUMENT AT ONE PATH — an
episodic YAML, a pattern entry. Do NOT wire it into appends against the large
aggregates (.context/project/learnings.yaml is ~386 chunks, decisions.yaml
~112). index_one() re-chunks and re-embeds the WHOLE file, so hooking an

---
*Auto-generated from Component Fabric. Card: `lib-post-write-index.yaml`*
*Last verified: 2026-08-16*
