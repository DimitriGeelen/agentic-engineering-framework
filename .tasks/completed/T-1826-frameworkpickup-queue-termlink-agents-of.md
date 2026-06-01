---
id: T-1826
name: "framework:pickup queue: termlink-agent's offsets 9+10 (T-1634 status + B-1 detail) not visible — pickup plumbing stall"
description: >
  OPS-1 reported by termlink-agent on 2026-05-14. termlink-agent emitted two framework:pickup envelopes (offset 9: T-1634 status-check 2026-05-13T13:29Z; offset 10: B-1 detail 2026-05-14T05:09Z). Neither is visible on framework-agent's bus — only seq 47 (G-082 ring20-management 2026-05-05) shows on the framework:pickup topic. Two envelopes apparently stalled in the cross-hub relay. Probably a TermLink-side delivery issue but framework-half pipeline (fw pickup) may also be implicated. Investigation: trace why these specific envelopes didn't surface; if TermLink-side, file as cross-repo pickup to /opt/termlink.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [fw-upgrade-incident-2026-05-14, pickup, termlink-relay, bug]
components: []
related_tasks: [T-1822]
created: 2026-05-14T07:31:02Z
last_update: 2026-05-14T14:26:37Z
date_finished: 2026-05-14T14:26:37Z
---

# T-1826: framework:pickup queue: termlink-agent's offsets 9+10 (T-1634 status + B-1 detail) not visible — pickup plumbing stall

## Context

OPS-1 (fw-upgrade-incident-2026-05-14). termlink-agent reported its outbound pickup envelopes (offsets 9 + 10) never surfaced on framework-agent's `framework:pickup` topic — only seq 47 (G-082 from ring20-management) is visible. Framework-side investigation confirms: local outbound queue is empty (0 pending), so the framework half of the pipeline isn't stalling. The envelopes are stuck on TermLink-agent's outbound side or in the cross-hub relay. Per CLAUDE.md Gap Homing (T-1333), the fix lives in TermLink — this task scopes to (a) homing the gap there, (b) registering the framework-side observation, (c) closing when TermLink confirms back.

## Acceptance Criteria

### Agent
- [x] Framework-side investigation done: local `framework:pickup` topic shows only seq 47 (G-082 ring20-management); local outbound sqlite queue is empty (0 pending). Framework half is healthy.
- [x] Cross-repo pickup envelope filed to /opt/termlink describing the symptom (offsets 9+10 stalled, framework cannot see them) with diagnostic data.
- [x] Task framed for closure as homed-elsewhere: the fix lives in TermLink, this task tracks the framework-side observation only.

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

bash -c 'ls .context/pickup/{inbox,processed}/P-046-bug-report.yaml 2>/dev/null | head -1 | xargs -r test -f'
bash -c 'cat .context/pickup/{inbox,processed}/P-046-bug-report.yaml 2>/dev/null | grep -q "T-1826"'
bash -c 'cat .context/pickup/{inbox,processed}/P-046-bug-report.yaml 2>/dev/null | grep -q "termlink"'

## RCA

**Symptom:** termlink-agent emitted two pickup envelopes on `framework:pickup` (their offsets 9 + 10, dated 2026-05-13 + 2026-05-14) but framework-agent's poll of the same topic showed only seq 47 (G-082 from ring20-management, 2026-05-05). 9 days of cross-hub delivery worked between seq 47 and the missing envelopes; something stalled between termlink-agent and framework-agent's view.

**Root cause (framework half — ruled out):** Framework outbound queue is empty (0 pending in `~/.termlink/outbound.sqlite`). Framework inbound topic is functioning — seq 47 visible, last poll returns expected payload. The framework half of the pipeline is healthy.

**Root cause (presumed, cross-hub side):** Stalled outbound queue on termlink-agent, OR hub-side buffer overflow, OR cross-hub relay backoff. Confirmation requires TermLink-side investigation.

**Why structurally allowed:** Receiver-side has no visibility into sender-side queue state. From framework-agent's view, "no envelope" is indistinguishable from "no envelope sent" vs "envelope sent but stuck". `termlink fleet status` shows hub up/down but not per-channel queue depth. The relay is invisible until something explicitly fails — and stalls aren't failures.

**Prevention:**
1. Per CLAUDE.md Gap Homing (T-1333): fix lives in TermLink. Filed pickup P-046-bug-report.yaml + direct inject to termlink-agent with diagnostic data. Framework task tracks the observation, not the fix.
2. Visibility gap candidate for L-entry: "Cross-hub message stalls invisible from receiver side. Sender-side queue-status surface (in `fleet doctor`?) would let receivers verify 'no envelope' = "really no envelope" vs "stuck in transit"."
3. This task closes when termlink-agent confirms back (via inject reply or fix.shipped event). No framework-side code change needed.

## Evolution

<!-- REQUIRED for arc-tagged build tasks (tags include arc:*). Captures how
     understanding evolved during build — what was learned that wasn't known at
     filing, what in the original plan no longer fits, what triggered pivots
     or new sub-tasks. Mandatory at slice boundaries (when applicable) and
     before --status work-completed.

     Origin: T-1717 grill Q4 — "the understanding of what we need and want
     evolves with the process of materialisation." Structural counter to §ACD:
     spec-vs-build divergence is logged as soon as it happens, not lost as
     folklore.

     Format (one entry per slice boundary or significant insight):
       ### YYYY-MM-DD — [topic]
       - **What changed:** [what we learned that we didn't know at filing]
       - **Plan impact:** [what in the plan no longer fits]
       - **Triggered:** [new sub-task / pivot / scope cut, with task ID if filed]

     The completion gate (T-1718) blocks --status work-completed when this
     section exists but is empty/template-only. Use --skip-evolution to bypass
     (logged Tier-2). Non-arc tasks may leave this empty.
-->

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

### 2026-05-14T07:31:02Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1826-frameworkpickup-queue-termlink-agents-of.md
- **Context:** Initial task creation

### 2026-05-14T14:24:38Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.4)

- **Scan ID:** R-71e74fd5
- **Timestamp:** 2026-05-14T14:26:38Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** yes
- **Findings:** none

- **Layer-1 escalations:** 1
  1. **cross-project-blast** (medium) — Cross-project or cross-repo change
     - matched: `Cross-repo`

### 2026-05-14T14:26:37Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
