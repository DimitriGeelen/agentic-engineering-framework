---
id: T-3075
name: "AEF-grounded architecture review of 0503's Executable Workflow Contract Runtime
  dossier (T-027)"
description: >
  Peer 0503-codex-cli-playground broadcast a T-027 review request on agent-chat-arc
  @97: an independent, AEF-grounded architecture review of a 554-line dossier proposing
  a workflow-contract runtime built on AEF primitives. Advisory only. We are the authoritative
  source on which AEF primitives actually exist, which are gaps, and where the governance
  model would be violated.

status: started-work
workflow_type: design
owner: agent
horizon: now
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
created: 2026-08-18T11:17:44Z
last_update: 2026-08-18T11:32:34Z
date_finished:
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
cost_estimate_proposed:
  - ts: '2026-08-18T11:30:06Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 3
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=3 
      (workflow:design); effort=8 (lines=162,acs=5)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-18T11:30:16Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 1
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal); F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 
      (no-signal); F3=0 (no-signal); F1=1 
      (body/components:context-fabric-incidental); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-3075: AEF-grounded architecture review of 0503's Executable Workflow Contract Runtime dossier (T-027)

## Context

Peer project `0503-codex-cli-playground` broadcast a review request on `agent-chat-arc`
offset **@97** (2026-08-18, `msg_type=note`, `thread=T-027`, no explicit mentions —
addressed to whoever can answer). Full text saved verbatim to
`.context/working/T-027-dossier-from-0503.md` (554 lines, 34 KB, dossier SHA-256
`7b51ba56329bebe50ac92295d32c71c66906afbae259f8010e33f39ed27efdd5`).

The dossier proposes an **Executable Workflow Contract Runtime**: workflows as
versioned, governed, executable contracts, with a runtime acting as an independent
policy-enforcement point over agent actions. It builds explicitly on AEF primitives
(task/inception lifecycle, Context Fabric, Component Fabric, TermLink, worktree
isolation, Watchtower) plus the Workflow Designer's BPMN-plus-AEF mapping.

**Why this repo answers it.** The request asks specifically for review grounded in
*observed AEF fact* versus *proposed design*. This project is the AEF. We hold the
measured knowledge of which primitives exist, which are stubs, and — more usefully —
where our own enforcement is thinner than its documentation reads. A reviewer who
only read the dossier would grade its internal consistency; we can grade it against
what the substrate actually does.

**Authority boundary.** The request is explicitly advisory ("You are advisory only;
do not approve, modify, or dispatch work"). We produce a review. We do not approve
their architecture, create tasks in their project, or dispatch anything on their
behalf. No permission escalation is involved and none is being granted.

## Acceptance Criteria

### Agent

- [x] A1 — Review written to `docs/reports/T-3075-aef-review-of-0503-t027.md`, ≤1000
      words in the response body, in the structure the requester specified: Verdict;
      numbered findings each carrying severity + dossier section + evidence/reason +
      concrete change; missing primitives; first pilot; human decisions.
- [x] A2 — Every claim about AEF is labelled as **observed** (with a file:line or
      command-output citation from this repo) or as **inference**. A structural proxy
      plus an inference is not a measurement (L-589); the review must not present one
      as the other.
- [x] A3 — The review checks the dossier's enforcement claims against how AEF gates
      actually behave, not against how CLAUDE.md describes them. At minimum it must
      reach a position on the dossier's central safety claim — that a runtime can
      independently enforce a contract and "not trust an agent to self-authorise" —
      given what our own PreToolUse hooks can and cannot see.
- [x] A4 — Findings distinguish *the dossier is factually wrong about AEF today* from
      *the dossier is right about AEF today and that is the problem*. The second class
      is the one worth their time.
- [ ] A5 — Response posted to `agent-chat-arc` on thread `T-027` with the report path
      and the verdict, so the requester can act on it without our repo access.

## Verification

test -f docs/reports/T-3075-aef-review-of-0503-t027.md
# Structure the requester asked for — all five blocks present.
for h in Verdict Findings "Missing primitives" "First pilot" "Human decisions"; do grep -qi "$h" docs/reports/T-3075-aef-review-of-0503-t027.md || { echo "missing section: $h"; exit 1; }; done
# A2: claims are cited, not asserted. At least 8 file:line or command citations.
test "$(grep -oE '(lib|bin|agents|web|tests|policy)/[A-Za-z0-9_./-]+(:[0-9]+)?' docs/reports/T-3075-aef-review-of-0503-t027.md | sort -u | wc -l)" -ge 8
# Positive control (L-616): the citation pattern must actually match a known-good
# string, otherwise "8 unique citations" could be satisfied by a broken regex
# matching noise, and an empty match set is indistinguishable from a blind check.
printf 'see lib/task-audit.sh:117 for the predicate\n' | grep -qE '(lib|bin|agents)/[A-Za-z0-9_./-]+:[0-9]+'
# A3: the review took a position on the enforcement claim rather than skipping it.
grep -qiE 'PreToolUse|Tier 0|self-authoris|policy-enforcement' docs/reports/T-3075-aef-review-of-0503-t027.md

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

### 2026-08-18T11:17:44Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3075-aef-grounded-architecture-review-of-0503.md
- **Context:** Initial task creation

### 2026-08-18T11:32:34Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
