---
id: T-100131
name: "Rewrite README opening with Garbage-In narrative + onboarding prompts"
description: >
  Rewrite README opening with Garbage-In narrative + onboarding prompts

status: work-completed
workflow_type: build
owner: human
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
created: 2026-07-04T08:47:10Z
last_update: '2026-08-16T22:23:57Z'
date_finished: 2026-07-06T12:44:04Z
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
  - ts: '2026-07-04T09:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-07-04T09:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 4
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F-AUTONOMY: 0
      audit_severity: 0
      F3: 1
      F1: 1
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=4 
      (body:framework-level-ux); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-ORCH=0 (no-signal); F-AUTONOMY=0 (no-signal); 
      audit_severity=0 (no-signal); F3=1 (body/components:prompt-incidental); 
      F1=1 (body/components:context-fabric-incidental); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:23:57Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 4
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 1
      F1: 1
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=4 
      (body:framework-level-ux); D4=0 (no-signal); F-RECALL=0 (no-signal); 
      F-AUTONOMY=0 (no-signal); F3=1 (body/components:prompt-incidental); F1=1 
      (body/components:context-fabric-incidental); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-100131: Rewrite README opening with Garbage-In narrative + onboarding prompts

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] README opens with the "Garbage in, garbage out?" narrative and the "One principle, two mechanisms" (Context Fabric + Component Fabric) framing
- [x] Onboarding-prompts section present with both entry paths (A greenfield, B existing codebase), each in a copy-pasteable fenced code block
- [x] Later "Hand it to your agent" install block reconciled (points to the new onboarding section, no duplicate prompt)
- [x] Markdown is well-formed: `python3 -m markdown README.md > /dev/null` (or fenced-block balance check) passes

### Human
- [ ] [REVIEW] The Garbage-In opening and onboarding prompts read in your voice and land for a first-time reader
  **Steps:**
  1. Open https://github.com/DimitriGeelen/agentic-engineering-framework#readme (or `cd /opt/999-Agentic-Engineering-Framework && head -140 README.md`)
  2. Read the "Garbage in, garbage out?" opening and the "Get started — hand a prompt to your coding agent" section (both entry-path prompts)
  **Expected:** opening reads as your narrative (not product pitch); a newcomer could copy either prompt block and onboard without prior framework knowledge
  **If not:** note the paragraphs that miss the tone or confuse; agent revises

## Verification

# Origin-based checks (MAIN's branch lags origin/master where this lands).
git show origin/master:README.md > /tmp/.t100131-readme.md && grep -q "Garbage in, garbage out?" /tmp/.t100131-readme.md
grep -q "One principle, two mechanisms" /tmp/.t100131-readme.md
grep -q "Get started" /tmp/.t100131-readme.md
python3 -c "import re;s=open('/tmp/.t100131-readme.md').read();f=len(re.findall(r'^'+chr(96)*3, s, re.M));exit(0 if f%2==0 else 1)"

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

## Recommendation

**Recommendation:** GO — approve the README opening.

**Rationale:** The rewrite leads with your Garbage-In narrative and the one-principle-two-mechanisms framing, then hands the reader two copy-pasteable onboarding prompts (greenfield + existing codebase). Structure verified mechanically (headings present, 48 fenced blocks balanced); what remains is whether the voice is yours — that is the [REVIEW].

**Evidence:**
- `## Garbage in, garbage out?` opens the README (line 6); `## One principle, two mechanisms` at line 26
- Both entry-path prompts under `## Get started — hand a prompt to your coding agent` (line 51), fenced and self-contained
- `### Hand it to your agent (lead)` install section points to the top prompts — no duplicate
- Fence balance check passes (48 fences, even)

## Updates

### 2026-07-04T08:47:10Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-100131-rewrite-readme-opening-with-garbage-in-n.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-e3e553b3
- **Timestamp:** 2026-07-06T12:44:06Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-07-06T12:44:04Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
