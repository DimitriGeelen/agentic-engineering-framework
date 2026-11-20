# inbox-files-gitignore

> T-5271 — keep operator-dropped files out of a project's git.

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/inbox-files-gitignore.sh`

## What It Does

T-5271 — keep operator-dropped files out of a project's git.
The fleet cockpit's /drop page (055-agentic-fleet-cockpit, their T-703, msg
1ed082c3) delivers files the operator drops, possibly sensitive, into
<project>/.context/inbox/files/. No project ignored that path — not even the
framework repo — so `git add -A`, a handover's `git add -A .context`, or an
explicit add could put a dropped file into history and onto every remote.
Where the rule lives: the nested .context/.gitignore, anchored as
`/inbox/files/`. That is the file lib/dispatch-gitignore.sh (T-4684) already
writes, so one file holds the .context/-level runtime rules; the rule applies
before .context/inbox/ exists (a nested .context/inbox/.gitignore would need

---
*Auto-generated from Component Fabric. Card: `lib-inbox-files-gitignore.yaml`*
*Last verified: 2026-11-19*
