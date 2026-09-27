# section-extract

> lib/section-extract.sh — anchored section extraction for the task-file sections that gate build/inception completion, other than ## Verification

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/section-extract.sh`

## What It Does

lib/section-extract.sh — anchored section extraction for the task-file
sections that gate build/inception completion, other than ## Verification
(T-3148).
lib/verification-port.sh:extract_verification_block (T-3134) fixed three
defects in the old `sed -n '/^## X/,/^## /p' | sed '$d'` shape for the
Verification section only:
D1 — `sed '$d'` discards sed's re-printed terminator line. When the
section is the FILE'S LAST section there is no terminator to
discard, so it deletes real content instead (832's report).
D2 — the start pattern is an unanchored PREFIX match, so a heading that

## Used By (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [check-active-task](/docs/generated/agents-context-check-active-task) | called_by | Task-First Enforcement Hook — PreToolUse gate for Write/Edit tools |
| [update-task](/docs/generated/agents-task-create-update-task) | called_by | Task Update Agent - Status transitions with auto-triggers |
| [inception](/docs/generated/lib-inception) | called_by | fw inception - Inception phase workflow |

---
*Auto-generated from Component Fabric. Card: `lib-section-extract.yaml`*
*Last verified: 2026-09-05*
