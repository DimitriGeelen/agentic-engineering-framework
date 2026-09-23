---
id: T-3446
name: "Geelen & Company design language for Streichliste struktur page"
description: >
  Geelen & Company design language for Streichliste struktur page

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
created: 2026-09-23T22:14:18Z
last_update: 2026-09-23T22:27:49Z
date_finished: 2026-09-23T22:27:49Z
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
  - ts: '2026-09-23T22:15:11Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 3
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=3 
      (workflow:design); effort=8 (lines=269,acs=4)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-09-23T22:15:28Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 3
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=3
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3446: Geelen & Company design language for Streichliste struktur page

## Context

Produce a design language for the **Streichliste** civic evidence register
(`http://127.0.0.1:8931/`) derived from the **Geelen & Company** brand language, and a
page-level redesign proposal for `struktur.html` (Die Verwaltungsstruktur, 169 entries).

Sources read (not approximated):
- Brand: `/opt/023-geelenandcompany.com/hub.css`, `brand-language.html`,
  `opsasto/assets/dragon.png`
- Application: `struktur.html`, `index.html`, `methode.html`, `glossar.html`,
  `belege.html`, `liste.html` on `127.0.0.1:8931`

Deliverable is a published Design System artifact (tokens, brand book, two guideline
sections, 9 component previews, the dragon as an uploaded asset), not a repo change.
Working tree: `/tmp/claude-1000/.../scratchpad/ds/project/`.

## Acceptance Criteria

### Agent
- [x] Tokens derived from the real Geelen sources at exact values (23 colours in 2 themes,
      4 families, 12 type styles, 8 spacing steps, 4 radii, 2 shadows); `tokens.json` parses
      and uses the list shape the renderer reads, not a DTCG map
- [x] Contrast checked per token against its stated ground in BOTH themes; the one failing
      brand pair (`ink-mute`, 3.5:1 on paper) is KEPT at its source value and flagged in its
      usage note rather than silently corrected
- [x] Brand book (`README.md`) states the adaptation rule, content fundamentals, visual
      foundations, iconography, the ornament rule, and 7 usage rules naming tokens
- [x] Page redesign proposal names the concrete defects in the live `struktur.html`, with a
      proposal and a shipping order for each
- [x] Evidence specification separates status (hue) from provenance (form) and says why the
      current single-scale encoding cannot represent `teilweise (zu prüfen)`
- [x] Dragon copied byte-for-byte from the brand repo and uploaded as an asset, never redrawn
- [x] 9 component previews written, each with its `@dsCard` marker; 8 carry guidelines
      (Cover folder kept bare as the type requires)
- [x] Published as a Design System artifact from the type, index written last


## Verification

python3 -c "import json,sys; d=json.load(open('/tmp/claude-1000/-opt-999-Agentic-Engineering-Framework/1ea22d2a-ed54-4309-a220-c325463f4119/scratchpad/ds/project/tokens.json')); assert isinstance(d['color']['tokens'],list) and len(d['color']['tokens'])==23; assert len(d['color']['themes'])==2; print('tokens ok')"
python3 -c "import json; d=json.load(open('/tmp/claude-1000/-opt-999-Agentic-Engineering-Framework/1ea22d2a-ed54-4309-a220-c325463f4119/scratchpad/ds/project/design-system.json')); assert d['createdOnFiles']['v']==1 and d['title']=='Streichliste Design Language'; print('index ok')"
test $(find /tmp/claude-1000/-opt-999-Agentic-Engineering-Framework/1ea22d2a-ed54-4309-a220-c325463f4119/scratchpad/ds/project/components -name preview.html | wc -l) -eq 9
for f in /tmp/claude-1000/-opt-999-Agentic-Engineering-Framework/1ea22d2a-ed54-4309-a220-c325463f4119/scratchpad/ds/project/components/*/preview.html; do head -1 "$f" | grep -q '@dsCard' || exit 1; done
test ! -f /tmp/claude-1000/-opt-999-Agentic-Engineering-Framework/1ea22d2a-ed54-4309-a220-c325463f4119/scratchpad/ds/project/components/Cover/README.md
cmp /opt/023-geelenandcompany.com/opsasto/assets/dragon.png /tmp/claude-1000/-opt-999-Agentic-Engineering-Framework/1ea22d2a-ed54-4309-a220-c325463f4119/scratchpad/ds/project/assets/Ornament/dragon.png

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

### 2026-09-23T22:14:18Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3446-geelen--company-design-language-for-stre.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-8db7f476
- **Timestamp:** 2026-09-23T22:27:50Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 4
     - evidence: `for f in /tmp/claude-1000/-opt-999-Agentic-Engineering-Framework/1ea22d2a-ed54-4309-a220-c325463f4119/scratchpad/ds/project/components/*/preview.html; do head -1 "$f" | grep -q '@dsCard' || exit 1; do`

### 2026-09-23T22:27:49Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
