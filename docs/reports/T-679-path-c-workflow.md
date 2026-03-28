# T-679: Path C Workflow — External Codebase Ingestion via TermLink

## Status: Complete (GO decision 2026-03-28)

## What is Path C?

Path C is the framework's workflow for analyzing an external codebase. Unlike Path A (new project) or Path B (adopt framework into your own project), Path C treats the external repo as an analysis target.

**L-117 Exception:** Path C requires writing to the target project (fw init, seed tasks, fabric). This is an explicit exception to "never edit outside PROJECT_ROOT" — but requires **explicit human approval** before any writes to the external project.

## Correct Workflow (from T-678 corrections, 6 exchanges, 5 corrections)

### Phase 1: Setup (FROM framework project, human approval required)

1. Create inception task for the deep-dive
2. Clone the target repo to `/opt/NNN-ProjectName`
3. Use TermLink to initialize framework governance in the target:
   - Spawn TermLink session
   - cd into target project inside that session
   - Run `fw init --force`
   - Run `fw doctor` to verify
   - Verify framework hooks (not original project hooks) are in settings.json
   - Original hooks preserved as `settings.json.pre-fw` (investigation artifact)
4. Seed tasks auto-created by `fw init` (T-001 through T-006)

### Phase 2: Execute (INSIDE target project via TermLink)

- Dispatch Claude Code worker OR interactive TermLink session
- Worker cd's into target project
- Executes seed tasks (T-001 orientation, T-002 first commit, T-003 register components, etc.)
- Runs `fw doctor` and `fw audit` after each task
- Every friction point logged

### Phase 3: Harvest (BACK in framework project)

- Results come back via bus (`fw bus manifest T-XXX`)
- Or read via TermLink from target project files
- Consolidate findings into framework research artifact
- Create improvement tasks for friction points

## Key Rules

1. **Never cd into the target from framework session** — boundary hook blocks it (correctly)
2. **Never analyze target code from framework session** — pollutes context
3. **Always use TermLink for cross-project commands** — isolation by design
4. **TermLink session cd's INTO the consumer project** — that's the whole point
5. **Keep original project hooks** as `.pre-fw` — they're analysis artifacts
6. **Framework hooks must be applied** — governance even for analysis
7. **Human must approve** before any writes to external project (L-117 exception)
8. **Friction points become framework tasks** — the onboarding IS the test

## Friction Points Discovered (T-678 + T-679 sessions)

| # | Issue | Category | Severity | Fix |
|---|-------|----------|----------|-----|
| F-1 | Boundary hook blocks TermLink commands (R-037) | Framework | **HIGH** | Add TermLink exception to boundary hook |
| F-2 | `fw upgrade` doesn't validate hook content | Framework | HIGH | Check hooks are framework hooks, not project hooks |
| F-3 | `fw init` re-vendors from self | Framework | Medium | Detect source==target, pull from upstream |
| F-4 | Version display confusing | Framework | Low | Fix pinned vs installed comparison |
| F-5 | TermLink MCP not in default MCP config | Framework | Medium | Add to fw init MCP seeding |
| F-6 | No `termlink spawn --working-dir` flag | TermLink | Medium | Feature request |
| F-7 | TermLink interact also blocked by boundary hook | Framework | HIGH | Same root cause as F-1 |
| F-8 | Seed task T-001 verification too strict (`fw audit` exits non-zero on fresh project) | Framework | Medium | T-683: Use `fw doctor` instead |
| F-9 | `fw init` doesn't check git user identity | Framework | Medium | T-685: Add git identity check |
| F-10 | Seed T-002 gitignores `.context/`, T-005 can't commit handover there | Framework | Medium | T-684: Exclude `.context/handovers/` from gitignore |

### Fix Status

| Friction | Status | Task |
|----------|--------|------|
| F-1/F-7 | **FIXED** | `check-project-boundary.sh` — TermLink exception |
| F-2 | **FIXED** | `lib/upgrade.sh` — non-framework hook detection |
| F-3 | **FIXED** | T-680 — vendor self-ref detection + `--source` flag |
| F-4 | Open | Low priority |
| F-5 | **FIXED** | T-681 — TermLink MCP in init/upgrade defaults |
| F-6 | Open | T-682 (TermLink product) |
| F-8 | **FIXED** | T-683 — `fw audit; test $? -le 1` |
| F-9 | **FIXED** | T-685 — git identity check in `fw doctor` |
| F-10 | **FIXED** | T-684 — gitignore warning in seed T-002 |

### Seed Task Execution Results

All 6 seed tasks completed successfully in `/opt/051-Vinix24`:
- **T-001**: Orientation + doctor/audit — PASS (needed `--force` for audit, friction F-8)
- **T-002**: First governed commit — PASS (needed git identity config, friction F-9)
- **T-003**: Register 6 key components — PASS (clean)
- **T-004**: Complete task lifecycle — PASS (clean, satisfied by T-001-T-003)
- **T-005**: Generate handover — PASS (handover created, commit failed due to gitignore, friction F-10)
- **T-006**: Add project learning — PASS (clean)

## TermLink Product Feedback

For the TermLink creator (Vincent):

1. **`--working-dir` on spawn** — Avoid separate cd step after spawning
2. **MCP server should be default** — Cross-project tools bypass bash hooks entirely
3. **TermLink 0.9.33 works well** — spawn/interact/inject/signal/clean all functional
4. **MCP serve exists** — Just needs to be configured by default in consumer projects

## Prior Art

- T-549: OpenClaw deep-dive (first Path C attempt, partial success)
- T-678: vnx-orchestration deep-dive (second attempt, 5 course corrections — dialogue log in `.context/episodic/T-678-dialogue.yaml`)
- T-124: New-project onboarding tutorial (Path A/B, not Path C)
- T-559: Project boundary enforcement (the hook causing F-1/F-7)
- T-677: Fix fw init for pre-existing settings.json
