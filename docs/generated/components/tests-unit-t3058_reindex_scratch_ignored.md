# t3058_reindex_scratch_ignored

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/t3058_reindex_scratch_ignored.bats`

## What It Does

T-3058 — the vector reindex scratch copy must be gitignored.
It is not a leak. `web/embeddings.py` parks partial work in it so an hourly
cron can finish a 29-58h bootstrap across many firings (OBS-258), so the file
sits in .context/working/ for DAYS, at index size, inside the directory every
handover commits from. `.reindex.resume` was already ignored and the scratch is
`shutil.move`d into exactly that path — same file, two moments of one run, only
one of them covered.
Checks run against a scratch repo holding a COPY of the real .gitignore, so the
mutation (deleting the rule) is possible without touching the working tree.

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [embeddings](/docs/generated/web-embeddings) | tests | sqlite-vec semantic search — embeds framework knowledge files (874 docs) using all-MiniLM-L6-v2, provides semantic + hybrid (RRF) search |

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3058_reindex_scratch_ignored.yaml`*
*Last verified: 2026-08-16*
