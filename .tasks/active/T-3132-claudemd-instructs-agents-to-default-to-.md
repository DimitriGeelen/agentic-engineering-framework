---
id: T-3132
name: "CLAUDE.md instructs agents to default to worktrees — invert it to opt-in only"
description: >
  CLAUDE.md instructs agents to default to worktrees — invert it to opt-in only

status: started-work
workflow_type: build
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
created: 2026-08-25T07:28:38Z
last_update: '2026-08-25T07:30:19Z'
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
  - ts: '2026-08-25T07:30:09Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=202,acs=4)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-25T07:30:19Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3132: CLAUDE.md instructs agents to default to worktrees — invert it to opt-in only

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent

**Operator directive (2026-08-25, verbatim intent):** default = NO worktree.
Worktrees are used ONLY on explicit instruction. The agent MAY *suggest* one for a
major piece of work; a suggestion the operator does not accept means main checkout.
Applies to vendored/consumer projects too, which is where much of the pain
originates. (An earlier reading of this directive as "build an enforced switch"
was wrong — see the scope correction below.)

**SCOPE CORRECTION (operator, same session).** A first draft of this task specced
a `FW_ALLOW_WORKTREE` config key, a refusing gate on `fw worktree create`, and MCP
exposure of the switch. That was over-built and is **rejected**. Operator: *"Not
gateway fuses. Just by default, you're not creating work trees... we're not gonna
take out the option and the mechanism. We just want it to be an explicit request."*

So: **the mechanism is untouched. No new config key, no gate, no fuse, nothing to
bypass.** The only change is the default behaviour and the guidance that produces
it. Do not reintroduce a gate under this task.

- [x] AC1 — CLAUDE.md contains a §Worktree Policy section stating: default is the main checkout; worktrees only on explicit operator instruction; the agent may suggest once for a major piece of work; same rule applies to consumer/vendored projects.
- [x] AC2 — No line in CLAUDE.md instructs worktree-by-default. Specifically §Execution Model item 4 and §Trunk-Based Session Flow no longer read "use a worktree for parallel work" / "real code goes through a worktree". Verified by grep.
- [x] AC3 — The policy section states explicitly that the mechanism is NOT removed and NOT gated, so a future agent does not read the policy as a reason to build one. (This AC exists because the first draft did exactly that.)
- [x] AC4 — `fw worktree create`, `fw worktree gc` and `fw integrate` are behaviourally unchanged — confirm no code change was made to them under this task. This is an anti-AC: the deliverable is that the tooling was NOT touched.
- [x] AC5 — Change propagates to consumers: vendored via `fw vendor self` so `fw upgrade` carries it. The directive explicitly covers vendored projects, where much of the pain originates.

### Human

- [ ] [REVIEW] The default is genuinely off and the refusal reads right. **Steps:** run `cd /opt/999-Agentic-Engineering-Framework && bin/fw worktree create scratch-test`. **Expected:** it refuses, and the message tells you how to allow it in one line you can paste. **If not:** say which part read wrong.

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.

     ── Prefix routing (T-1811, T-1878): default to [REVIEWER] if Expected is grep-able ──
     If your Expected clause is grep-able / file-exists / structural (a deterministic
     shell check), prefer [REVIEWER] — that AC should be an Agent AC with the reviewer
     command in `## Verification` instead of a Human AC here. Only keep [REVIEW] if
     verification genuinely needs human taste (tone, feel, layout rhythm).
     See CLAUDE.md §AC Classification Guidance for the conversion rule.

     [REVIEW] example (genuine human judgment):
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error

     [REVIEWER] example (static-scan-verifiable — convert to Agent AC + Verification):
       - [ ] [REVIEWER] Block message names both bypass mechanisms
         **Steps:**
         1. Run `bin/fw reviewer T-XXX`
         **Expected:** Verdict: PASS; no findings on `block-message-completeness`
         **If not:** Inspect hook block-message string and add missing mechanism
       Conversion: this AC should be moved to ### Agent and
       `bin/fw reviewer T-XXX 2>&1 | grep -q "Overall:.*PASS"` added to ## Verification.
-->

## Verification

# AC1 — the policy section exists and states the rule.
grep -q '^## Worktree Policy — OPT-IN ONLY' CLAUDE.md
grep -q 'Do not create a git worktree unless the' CLAUDE.md

# AC2 — no line instructs the agent to default to a worktree.
! grep -qi 'Worktree isolation.*for any parallel work' CLAUDE.md
! grep -q 'Real code goes through a worktree' CLAUDE.md
grep -q 'Real code is built in the MAIN CHECKOUT by default' CLAUDE.md

# AC3 — the mechanism is stated as NOT gated (no fuse was invented).
grep -q 'The mechanism is NOT removed and is NOT gated' CLAUDE.md
! grep -q 'FW_ALLOW_WORKTREE' CLAUDE.md

# AC4 (anti-AC) — the rejected config key was never introduced.
# Word-boundary, NOT a prefix match: FW_ALLOW_WORKTREE_CORPUS_COMMIT and
# FW_ALLOW_WORKTREE_GOVERNANCE_WRITE are pre-existing bypasses from other tasks
# and must not satisfy this check either way.
! grep -rqE 'FW_ALLOW_WORKTREE([^A-Z_]|$)' lib/ bin/ agents/ CLAUDE.md 2>/dev/null
# And the worktree tooling itself carries no commit from this task.
! git log --oneline -1 --name-only -- lib/worktree.sh lib/integrate.sh | grep -q 'T-3132'

# AC5 — the vendored consumer guide carries no contradicting worktree default.
! grep -qi 'worktree' FRAMEWORK.md

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

### 2026-08-25T07:28:38Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3132-claudemd-instructs-agents-to-default-to-.md
- **Context:** Initial task creation

## Verification Provenance (T-3132)

The `## Verification` block shipped in the first draft was **template boilerplate
with zero executable lines** — P-011 would have passed it vacuously. That is the
same false-green family this session has been working (T-3125/T-3126/T-3128/
T-3129, L-575): a check that cannot see its subject reports the same thing as a
check that found nothing. Replaced with 10 real commands.

**Mutation check (measured, not asserted):** against the pre-change `CLAUDE.md`
at `6b9e2eeb4`, **6 of 10 fail** — those are the guards that actually bind:

- `^## Worktree Policy — OPT-IN ONLY` present
- `Do not create a git worktree unless the` present
- `Worktree isolation.*for any parallel work` absent
- `Real code goes through a worktree` absent
- `Real code is built in the MAIN CHECKOUT by default` present
- `The mechanism is NOT removed and is NOT gated` present

The remaining 4 pass against pre-change code **by construction**, and that is
correct: they are AC4's anti-AC (the rejected `FW_ALLOW_WORKTREE` key was never
introduced) plus the FRAMEWORK.md check. An anti-AC's job is to stay green; it
guards against a future regression, not against the past.

**AC4 predicate was corrected mid-verification.** The first version,
`! grep -rq 'FW_ALLOW_WORKTREE' lib/ bin/ agents/`, went red — but on
`FW_ALLOW_WORKTREE_CORPUS_COMMIT` and `FW_ALLOW_WORKTREE_GOVERNANCE_WRITE`,
two pre-existing bypasses from unrelated tasks. A prefix match answered a
different question than the one the AC asks. Tightened to a word boundary:
`FW_ALLOW_WORKTREE([^A-Z_]|$)`.

**FRAMEWORK.md needed no edit.** It is the provider-neutral guide that
`fw vendor self` ships to consumers, and it contains **zero** worktree
references — so there was no default to invert there. The operator's point that
the pain "also comes from vendor projects" is real, but its mechanism is agent
behaviour reading CLAUDE.md, not a contradicting sentence in the vendored guide.
The check is kept as a regression guard so nobody adds one later.
