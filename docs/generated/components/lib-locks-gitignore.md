# locks-gitignore

> T-5373 — keep flock anchors under .context/locks/ out of a consumer's git.

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/locks-gitignore.sh`

## What It Does

T-5373 — keep flock anchors under .context/locks/ out of a consumer's git.
lib/keylock.sh, lib/keylock.py and their callers (verdict ledger, dispatch
ledgers, inception decide) take flock(2) on .context/locks/<key>.lock. The
files persist by design — an flock anchor must not be unlinked while another
process may hold it — so they are never cleaned up. The framework repo ignores
.context/locks/ in its ROOT .gitignore (.gitignore:37), which no consumer
inherits; `fw init` and `fw upgrade` only wrote ignores for .context/working/,
.context/dispatch/ and .context/inbox/files/. Origin: skills-manager saw an
untracked .context/locks/T-486.lock after `fw inception decide`.
One list, two writers: init (fresh write) and upgrade (append-missing). The

---
*Auto-generated from Component Fabric. Card: `lib-locks-gitignore.yaml`*
*Last verified: 2026-11-23*
