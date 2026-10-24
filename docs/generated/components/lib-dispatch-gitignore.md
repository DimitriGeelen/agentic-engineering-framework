# dispatch-gitignore

> T-4684 — keep dispatch worker dirs out of a consumer's git.

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/dispatch-gitignore.sh`

## What It Does

T-4684 — keep dispatch worker dirs out of a consumer's git.
T-4675 moved TermLink worker dirs under the dispatching project:
<project>/.context/dispatch/<worker>/ holds prompt.md, env.sh (can carry
environment values), result.jsonl, stderr.log, meta.json. The framework repo
ignores .context/dispatch/ in its ROOT .gitignore (.gitignore:35), which no
consumer inherits, so a handover's `git add -A .context` could commit them.
Origin: 832 be.5 report (sidecar 81cb0bca).
One list, two writers: init (fresh write) and upgrade (append-missing). The
rules live in a nested .context/.gitignore, so they are relative to .context/
and apply before the directory exists. Same shape as lib/working-gitignore.sh

---
*Auto-generated from Component Fabric. Card: `lib-dispatch-gitignore.yaml`*
*Last verified: 2026-10-23*
