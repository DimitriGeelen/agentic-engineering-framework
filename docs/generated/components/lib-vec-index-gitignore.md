# vec-index-gitignore

> T-3861 — keep the vector index out of a consumer's git history.

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/vec-index-gitignore.sh`

## What It Does

T-3861 — keep the vector index out of a consumer's git history.
`fw index reindex` builds .context/working/fw-vec-index.db (1.5-3.5 GiB) plus
scratch beside it: `<db>.reindex.<pid>.tmp[-journal]`, `<db>.<pid>.building`,
`<db>.manifest.json`, `<db>.reindex.lock`, sqlite `-wal/-shm/-journal`. The
framework repo ignores all of these in its ROOT .gitignore (.gitignore:108-130),
which no consumer inherits. `fw init` only writes .context/working/.gitignore,
and it named none of them; `fw upgrade` never touched that file. Origin:
ring20-dashboard T-2462 finding 9 — a 1.2 GB unreferenced blob in .git after a
handover's `git add -A .context`.
One list, three readers: init (fresh write), upgrade (append-missing), audit

---
*Auto-generated from Component Fabric. Card: `lib-vec-index-gitignore.yaml`*
*Last verified: 2026-10-21*
