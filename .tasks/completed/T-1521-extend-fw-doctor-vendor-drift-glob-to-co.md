---
id: T-1521
name: "Extend fw doctor vendor-drift glob to cover all fw vendor paths (handover, audit, git, web, reviewer)"
description: >
  Extend fw doctor vendor-drift glob to cover all fw vendor paths (handover, audit, git, web, reviewer)

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [bin/fw]
related_tasks: []
created: 2026-04-26T21:40:49Z
last_update: 2026-04-26T21:45:35Z
date_finished: 2026-04-26T21:45:35Z
---

# T-1521: Extend fw doctor vendor-drift glob to cover all fw vendor paths (handover, audit, git, web, reviewer)

## Context

T-1434's vendor-drift check in `fw doctor` (bin/fw:711-738) globs only `bin/fw`, `lib/*.sh`, `agents/context/*.sh`, `agents/task-create/*.sh`. T-1520 RCA showed it missed `agents/handover/*.sh`, `agents/audit/*.sh`, `agents/git/lib/*.sh`, `lib/reviewer/*.py`, `web/blueprints/*.py`, `web/templates/*.html` — all synced by `fw vendor` but uncovered by the audit.

Fix: walk the vendored tree (`.agentic-framework/`) itself instead of a curated source glob — guarantees we catch whatever `fw vendor` put there.

## Acceptance Criteria

### Agent
- [x] `fw doctor` after dirtying `agents/handover/handover.sh` reports vendor-drift WARN with that file listed
- [x] `fw doctor` reports OK when source and vendor match
- [x] No false positives on `docs/generated/` or `__pycache__/` paths

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.
     Optionally prefix with [RUBBER-STAMP] or [REVIEW] for prioritization.
     Example:
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error
-->

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.
#
# Toolchain hint (L-291): if you edited *.vbproj/*.csproj/*.xaml add `dotnet build`;
# *.go → `go build ./...`; Cargo.toml → `cargo check`; tsconfig.json → `tsc --noEmit`;
# pom.xml → `mvn -q compile`. P-011 runs only what you write — broken builds slip
# past otherwise (origin: 003-NTB-ATC-Plugin T-077, broken WPF DLL on master 5 days).

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Updates

### 2026-04-26T21:40:49Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1521-extend-fw-doctor-vendor-drift-glob-to-co.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.4)

- **Scan ID:** R-01eb16eb
- **Timestamp:** 2026-04-26T21:45:35Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#1 (ACs)** — `fw doctor` after dirtying `agents/handover/handover.sh` reports vendor-drift WARN with that file listed
  - **AC-verify-mismatch** (narrow, heuristic) — `path=agents/handover/handover.sh in: `fw doctor` after dirtying `agents/handover/handover.sh` reports vendor-drift WARN with that file listed`

### 2026-04-26T21:45:35Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
