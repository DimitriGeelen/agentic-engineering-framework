---
id: T-1522
name: "Self-lock in handover.sh to prevent concurrent-write duplicate sections (defense-in-depth for T-1520)"
description: >
  Self-lock in handover.sh to prevent concurrent-write duplicate sections (defense-in-depth for T-1520)

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [agents/handover/handover.sh]
related_tasks: []
created: 2026-04-26T21:46:38Z
last_update: 2026-04-26T21:48:39Z
date_finished: 2026-04-26T21:48:39Z
---

# T-1522: Self-lock in handover.sh to prevent concurrent-write duplicate sections (defense-in-depth for T-1520)

## Context

T-1520's RCA fixed the upstream PreCompact dedup, but `handover.sh` itself has no concurrency guard. SESSION_ID is minute-precision (`S-YYYY-MMDD-HHMM`), so two callers in the same minute write to the same `$HANDOVER_FILE`. Three real callers exist: `pre-compact.sh` (has its own dedup), `checkpoint.sh` (auto-handover at budget critical, no dedup), and `audit.sh` (warning surface, no dedup). If two fire in the same minute the `cat > $FILE` then six `>> $FILE` appends will interleave and produce duplicate sections — same artefact corruption as T-1520, just from a different trigger.

Fix: flock at the top of handover.sh's normal-mode path. Concurrent invocation exits silently with a warning instead of racing.

## Acceptance Criteria

### Agent
- [x] handover.sh acquires flock before normal-mode work; second concurrent invocation exits 0 silently
- [x] Sequential calls (one finishes before next starts) work normally
- [x] Checkpoint mode (--checkpoint) is exempt — it writes to a different file and is safe to run while a normal handover holds the lock

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

### 2026-04-26T21:46:38Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1522-self-lock-in-handoversh-to-prevent-concu.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.4)

- **Scan ID:** R-66588962
- **Timestamp:** 2026-04-26T21:48:39Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-04-26T21:48:39Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
