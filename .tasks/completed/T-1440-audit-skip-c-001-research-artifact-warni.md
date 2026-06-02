---
id: T-1440
name: "audit: skip C-001 research-artifact warning for pickup-auto-created tasks"
description: >
  audit: skip C-001 research-artifact warning for pickup-auto-created tasks

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-25T05:52:37Z
last_update: 2026-04-25T05:55:42Z
date_finished: 2026-04-25T05:55:42Z
---

# T-1440: audit: skip C-001 research-artifact warning for pickup-auto-created tasks

## Context

12 of 14 "Inception task X has no research artifact" audit warnings are pickup-auto-created tasks (description starts "Auto-created from pickup envelope"). The pickup importer hard-codes `workflow_type: inception` regardless of envelope type — bug-report and feature-proposal envelopes get classified as inception but never need a research artifact (the fix lands via commits). Audit then nags about every closed pickup. Surgical fix: skip the missing-research check when the task description contains the pickup envelope marker. Structural fix (out of scope here): change pickup importer to set workflow_type by envelope type — captured as observation for human triage.

## Acceptance Criteria

### Agent
- [x] `agents/audit/completed-task-scan.py` skips the research-artifact check for tasks containing "Auto-created from pickup envelope"
- [x] After fix, audit shows no warnings for T-1305/T-1358/T-1350/T-1352/T-1353/T-1348/T-1345/T-1357/T-1351/T-1349/T-1304/T-1123
- [x] Real inception tasks T-1332 (G-045) and T-1333 (meta-rule) still warn (they genuinely lack artifacts)
- [x] Observation captured (OBS-015): pickup importer should set workflow_type per envelope type (not hard-code inception)

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

OUT=$(bin/fw audit 2>&1); ! echo "$OUT" | grep -qE "Inception task T-(1305|1358|1350|1352|1353|1348|1345|1357|1351|1349|1304|1123) has no research artifact"
OUT=$(bin/fw audit 2>&1); echo "$OUT" | grep -qE "Inception task T-(1332|1333) has no research artifact"

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

### 2026-04-25T05:52:37Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1440-audit-skip-c-001-research-artifact-warni.md
- **Context:** Initial task creation

### 2026-04-25T05:55:42Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-bb1f5816
- **Timestamp:** 2026-06-02T14:57:29Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 1
     - evidence: `OUT=$(bin/fw audit 2>&1); ! echo "$OUT" | grep -qE "Inception task T-(1305|1358|1350|1352|1353|1348|1345|1357|1351|1349|1304|1123) has no research artifact"`
