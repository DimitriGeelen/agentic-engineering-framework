# t3861_vec_index_gitignore

> T-3861 — the vector index (.context/working/fw-vec-index.db, GiB-sized) and its build/reindex scratch must be gitignored in consumers.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t3861_vec_index_gitignore.bats`

## What It Does

T-3861 — the vector index (.context/working/fw-vec-index.db, GiB-sized) and its
build/reindex scratch must be gitignored in consumers. The framework repo ignored
them in its ROOT .gitignore, which consumers never inherit; `fw init` wrote a
.context/working/.gitignore that named none of them and `fw upgrade` never
touched it (ring20-dashboard T-2462 finding 9: 1.2 GB blob in .git).

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3861_vec_index_gitignore.yaml`*
*Last verified: 2026-10-21*
