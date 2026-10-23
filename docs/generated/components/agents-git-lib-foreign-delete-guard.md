# foreign-delete-guard

> Foreign-delete guard (T-4528) — refuse a commit that deletes another task's files.

**Type:** script | **Subsystem:** git-traceability | **Location:** `agents/git/lib/foreign-delete-guard.py`

## What It Does

T-4563: `fw upgrade` re-vendors the framework into this dir and removes files the
new version dropped; their last commit is the PREVIOUS upgrade's task, so every
such re-vendor commit was refused. A commit that stages nothing outside this dir
is a re-vendor, not a stale index: its deletions under the dir are exempt.

---
*Auto-generated from Component Fabric. Card: `agents-git-lib-foreign-delete-guard.yaml`*
*Last verified: 2026-10-21*
