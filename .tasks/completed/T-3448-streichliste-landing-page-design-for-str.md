---
id: T-3448
name: "Streichliste landing page design for streichliste.de"
description: >
  Streichliste landing page design for streichliste.de

status: work-completed
workflow_type: design
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
# demo_target: true               # T-2286: optional — marks task as reserved for an orchestrated demo
#                                 # worker (e.g. arc-010 HM-A dispatches via mcp__fw__work_on). When set,
#                                 # `fw work-on T-XXX` refuses unless --i-am-demo-orchestrator (CLI) or
#                                 # FW_I_AM_DEMO_ORCHESTRATOR=1 (env) is passed. Prevents the parent
#                                 # session from consuming the captured→started-work transition the demo
#                                 # worker expects to drive. Origin OBS-057.
created: 2026-09-24T07:53:24Z
last_update: 2026-09-24T07:53:58Z
date_finished: 2026-09-24T07:53:58Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── BVP scoring fields (T-1918, arc-006). See docs/reports/T-1915-bvp-inception.md for semantics. ──
# bvp_scores:                     # confirmed per-driver scores 0-5, set by `fw bvp confirm` (T-1924).
#                                 # Sovereignty boundary — only set after human or agent confirmation.
#                                 # Shape: {D1: <int 0-5>, D2: <int 0-5>, D3: <int 0-5>, D4: <int 0-5>, [<free-driver-id>: <int>]...}
# bvp_scores_proposed:            # estimator-proposed scores (T-1922 worker). Persists when ≥2 delta
#                                 # from bvp_scores: on any driver (M3 v2-delta). Shape: list of timestamped entries.
# cost_estimate:                  # F8 composite: 0.6×blast_radius + 0.3×tier + 0.1×effort.
#                                 # Q2 fallback: T-shirt S/M/L/XL mapped to 2/4/6/8 when blast_radius is not yet computable.
---

# T-3448: Streichliste landing page design for streichliste.de

## Context

Redesign `index.html` of Streichliste (`/opt/1409-sprind`) as a landing page for
the domain streichliste.de. Brief from the operator: strong opening, name made
unmistakable, and written for somebody landing on the page cold.

Two decisions taken by the operator before design:
- **Opening move:** name + plain-German sentence first, counts as a band beneath.
- **Audience:** a cold general visitor; no legal vocabulary assumed.

Measured defects on the live page (1280x900): the word "Streichliste" first
appears 340px down mid-sentence and nowhere as a name; the findings start at
1654px of a 2725px page, behind a five-rung methodology diagram; no call to
action; 8px horizontal overflow from `.leitsatz`.

Deliverable: `Startseite` component + `guidelines/30-startseite.md` in the
published Design System artifact (KHsqdBoUerfTPVC8Ds74ZE). No repo change.

## Acceptance Criteria

### Agent
- [x] Live page measured, not assumed: name position, section offsets, overflow
- [x] Landing sequence answers a stranger's questions in their own order, name first
- [x] The zero is explained in the same breath it is shown, never left hanging
- [x] One concrete example (Fuehrungszeugnis) carries the method in place of a methodology section
- [x] "Was Streichliste nicht tut" promoted onto the landing page
- [x] Three weighted doors, each saying what is behind it
- [x] Full German copy deck recorded so the implementing agent writes no new copy
- [x] Published to the design system with the index read immediately before the write


## Verification

test -f /tmp/claude-1000/-opt-999-Agentic-Engineering-Framework/1ea22d2a-ed54-4309-a220-c325463f4119/scratchpad/ds/project/components/Startseite/preview.html
head -1 /tmp/claude-1000/-opt-999-Agentic-Engineering-Framework/1ea22d2a-ed54-4309-a220-c325463f4119/scratchpad/ds/project/components/Startseite/preview.html | grep -q '@dsCard'
test -f /tmp/claude-1000/-opt-999-Agentic-Engineering-Framework/1ea22d2a-ed54-4309-a220-c325463f4119/scratchpad/ds/project/components/Startseite/README.md
grep -q 'Null ist kein fehlendes Ergebnis' /tmp/claude-1000/-opt-999-Agentic-Engineering-Framework/1ea22d2a-ed54-4309-a220-c325463f4119/scratchpad/ds/project/guidelines/30-startseite.md
grep -q 'Was Streichliste nicht tut' /tmp/claude-1000/-opt-999-Agentic-Engineering-Framework/1ea22d2a-ed54-4309-a220-c325463f4119/scratchpad/ds/project/components/Startseite/preview.html
grep -q '30-startseite' /tmp/claude-1000/-opt-999-Agentic-Engineering-Framework/1ea22d2a-ed54-4309-a220-c325463f4119/scratchpad/ds/project/README.md
python3 -c "import json;d=json.load(open('/tmp/claude-1000/-opt-999-Agentic-Engineering-Framework/1ea22d2a-ed54-4309-a220-c325463f4119/scratchpad/ds/project/design-system.json'));assert d['lastChange']['note'].startswith('Added the Startseite');print('index ok')"

## RCA

<!-- REQUIRED for bug-class tasks (workflow_type=build with bug-tag, OR title matches
     fix/bug/rca/broken/crash/error/regression/fail/hotfix).
     Non-bug-class tasks may leave this section empty or remove it.

     For bug-class, fill in:
       **Symptom:** what was observed (the user-facing manifestation).
       **Root cause:** the specific structural/logical gap — not "the code was wrong".
       **Why structurally allowed:** what in the framework/code/tooling let this go undetected.
       **Prevention:** what catches the next instance (test/lint/gate/doc/learning) — distinct from the fix itself.

     The completion gate (T-1550, G-019) blocks --status work-completed when
     bug-class AND this section is empty/template-only. Use --skip-rca to bypass (logged).
-->

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

## Recommendation

<!-- T-2945: same shape as inception.md's block — the gate that reads it
     (audit_inception_recommendation, lib/task-audit.sh:117) is shared, so the
     shape is copied rather than reinvented.

     REQUIRED once this task reaches partial-complete: Agent ACs done, at least
     one `### Human` AC still unticked. `lib/review.sh:205-211` (T-2421) BLOCKS
     `fw task review` emission for build/refactor/test/decommission tasks in that
     state with no substantive block here — the operator would otherwise open
     /review/<id> to a blank Recommendation card and be asked to approve a form.

     Not required while every Human AC is ticked or the task has none: the gate
     only fires on the partial-complete transition. It is here from the start so
     you write it while you still have the evidence, not when the gate refuses.

     Format (the parser wants the `**Recommendation:**` line at the start of a
     line; a leading `-` or `*` bullet is also accepted):
     **Recommendation:** GO / NO-GO / DEFER
     **Rationale:** Why (cite evidence — what shipped, what was proven, what remains)
     **Evidence:**
     - Finding 1
     - Finding 2

     DEFER is for evidence gaps, not confidence gaps (CLAUDE.md §Presenting Work
     for Human Review). If the artefact is complete and you still don't want to
     commit, that is a calibration failure — recommend GO or NO-GO.
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

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-09-24T07:53:24Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3448-streichliste-landing-page-design-for-str.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-233823a3
- **Timestamp:** 2026-09-24T07:53:59Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 2
     - evidence: `head -1 /tmp/claude-1000/-opt-999-Agentic-Engineering-Framework/1ea22d2a-ed54-4309-a220-c325463f4119/scratchpad/ds/project/components/Startseite/preview.html | grep -q '@dsCard'`

### 2026-09-24T07:53:58Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
