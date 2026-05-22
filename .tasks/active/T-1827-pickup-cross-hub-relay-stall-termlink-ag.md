---
id: T-1827
name: "Pickup: Cross-hub relay stall: termlink-agents framework:pickup offsets 9+10
  never reached framework-agent (only seq 47 visible) (from 999-Agentic-Engineering-Framework)"
description: >
  Auto-created from pickup envelope. Source: 999-Agentic-Engineering-Framework, task
  T-1826. Type: bug-report.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [pickup, bug-report, fw-upgrade-incident-2026-05-14, termlink-relay]
components: [agents-termlink-termlink, lib-mirror]
related_tasks: [T-1826, T-1828, T-1829]
created: 2026-05-14T14:26:01Z
last_update: '2026-05-19T21:45:02Z'
date_finished:
source_task_id_in_origin: T-1826
source_project_in_origin: "999-Agentic-Engineering-Framework"
bvp_scores_proposed:
  - ts: '2026-05-19T18:27:45Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-05-19T21:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 2
      effort: 6
    rationale: blast_radius=3 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1827: Pickup: Cross-hub relay stall: termlink-agents framework:pickup offsets 9+10 never reached framework-agent (only seq 47 visible) (from 999-Agentic-Engineering-Framework)

## Context

OPS-1 from fw-upgrade-incident-2026-05-14. Sibling of T-1828 (OPS-2 outbound mirror lag). On 2026-05-14T14:25Z, framework-agent observed that termlink-agent's framework:pickup envelopes at offsets 9 and 10 (T-1634 status-check + B-1 cwd-trap detail) had not been visible from this side — only seq=47 visible. Resolution finding (2026-05-14T18:30Z): re-checked framework:pickup via `termlink channel subscribe --since 0 framework:pickup` and offsets 9 and 10 ARE now visible (plus offset 11 P-046 self-message and offset 12 OPS-2 mirror-lag report). The "stall" was a delivery-latency issue (eventual delivery, ~hours), not a permanent drop. The visibility-gap fix termlink-agent suggested (sender-side queue-status surface in fleet doctor) remains the right long-term ask.

## Acceptance Criteria

### Agent
- [x] Verify offsets 9 and 10 are now visible on framework:pickup (observed 2026-05-14T18:30Z)
- [x] Cross-link to T-1828 (sibling OPS-2) and T-1826 (origin)
- [x] Reply to termlink-agent on framework:pickup acknowledging late-but-eventual delivery (offset 13 reply-to:12)

### Human
- [ ] [REVIEW] Decide whether the eventual-delivery class warrants its own gap entry, OR whether the visibility-gap follow-up (sender-side queue-status in fleet doctor) is the correct downstream action
  **Steps:**
  1. Open the review page (link in `fw task review T-1827`)
  2. Read RCA section
  3. Decide: (a) file gap G-XXX for "no SLO on framework:pickup delivery latency" → file a TermLink-side ticket via pickup, OR (b) close T-1827 with note that the visibility-gap fix is the only useful action and the eventual-delivery is acceptable.

  **Expected:** Either a new G-entry filed or T-1827 closed with the decision recorded.

  **If not:** Defer to next session — does not block the OPS-2 / T-1828 mirror-fix flow.

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.
#
# Toolchain hint (L-291): if you edited *.vbproj/*.csproj/*.xaml add `dotnet build`;
# *.go → `go build ./...`; Cargo.toml → `cargo check`; tsconfig.json → `tsc --noEmit`;
# pom.xml → `mvn -q compile`. P-011 runs only what you write — broken builds slip
# past otherwise (origin: 003-NTB-ATC-Plugin T-077, broken WPF DLL on master 5 days).

## RCA

**Symptom:** framework-agent could not see termlink-agent's framework:pickup envelopes at offsets 9 and 10 for several hours (2026-05-13 → 2026-05-14T14:25Z). Only seq=47 (G-082 ring20-management) was visible on this side; local outbound queue empty, no obvious stall surface.

**Root cause:** Cross-hub delivery latency on the framework:pickup topic was hours, not seconds. Eventually-consistent delivery is working; instantaneous delivery is not guaranteed. There is no SLO and no visibility surface for "envelope sent, delivery pending".

**Why structurally allowed:** TermLink's `fleet doctor` reports hub-level health but does not surface per-topic per-envelope delivery state. Sender sees `Inbox: X pending transfer(s)` (limited info) but receiver has no way to know "your peer has N envelopes queued for you that haven't reached your hub yet". No metric, no log, no audit. Means the only signal a receiver gets is "did the message arrive yet?" — and "not yet" is indistinguishable from "never will".

**Prevention:**
- **Level C (TermLink-side):** sender-side queue-status surface in `fleet doctor`. When peer is on a remote hub, show envelopes in-flight per topic with timestamp. Filed via reply on framework:pickup as a TermLink follow-up ask.
- **Level B (framework-side):** documented in CLAUDE.md (already covered by §"TermLink inject for interactive, push for async" feedback memory) — pickup is async, don't expect synchronous delivery for cross-hub.
- **Level A:** see L-376 / L-377 (this and T-1828 share root family — "no visibility surface for outbound state crossing trust/hub boundaries").

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

### 2026-05-14T14:26:01Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1827-pickup-cross-hub-relay-stall-termlink-ag.md
- **Context:** Initial task creation

### 2026-05-14T18:30Z — resolution-finding [framework-agent]
- **Action:** Re-checked framework:pickup via `termlink channel subscribe --since 0 framework:pickup`
- **Output:** Offsets 9, 10, 11, 12 all visible. Offsets 9-10 (the originally-reported stall) ARE delivered, just hours-late.
- **Context:** Reclassifies T-1827 from "drop" to "latency". Sibling OPS-2 (T-1828) is now the higher-priority item — it's the OUTBOUND mirror lag (GitHub) preventing consumers from picking up the fix.

## Recommendation

**Recommendation:** DEFER closure pending TermLink-side queue-status surface (Level-C ask delivered to termlink-agent at framework:pickup offset 13).

**Rationale:** the reported "stall" turned out to be eventual-but-delayed delivery, not a drop. The structural visibility gap (no sender-side queue-status surface in fleet doctor) is the real problem and lives on the TermLink side, not the framework side. Closing T-1827 unilaterally on this side would lose the cross-link to the TermLink follow-up.

**Evidence:**
- `termlink channel subscribe --since 0 framework:pickup` shows offsets 9, 10, 11, 12 all present (2026-05-14T18:25Z)
- Offset 13 posted by framework-agent acknowledging the slow-delivery class and pointing to T-1828 as the higher-priority sibling
- Original symptom (offset 9 = T-1634 status-check, offset 10 = B-1 cwd-trap detail) — both received; B-1 is the SAME cwd-trap fixed by T-1822 (already shipped to origin, blocked from GitHub by T-1828)

### 2026-05-14T18:27:26Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)
