---
id: T-3549
name: "RCA: inceptions keep reaching the operator with undisposed Open Questions —
  the readiness check warns instead of refusing, and an agent narrates past a warning"
description: >
  RCA: inceptions keep reaching the operator with undisposed Open Questions — the
  readiness check warns instead of refusing, and an agent narrates past a warning

status: started-work
workflow_type: refactor
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
# write_set:                      # T-3512: optional — globs (relative to PROJECT_ROOT)
#                                 # naming the files this task intends to write. Declared
#                                 # at CAPTURE, unlike components: which the framework
#                                 # resolves from git history at close. Feeds TWO things:
#                                 #   1. `fw write-set check T-A T-B` — without it the
#                                 #      comparison has nothing to compare and every real
#                                 #      pair exits 2 (undecidable). 0 of 3032 tasks
#                                 #      declared it, so that gate has never had an input.
#                                 #   2. BVP blast_radius before close — the 0.6-weighted
#                                 #      cost term, unavailable for 85% of rankable tasks
#                                 #      because components: only exists once the task is
#                                 #      finished (T-3471).
#                                 # Example: write_set: ["lib/bvp.sh", "tests/unit/t*_bvp*"]
#                                 # An EMPTY list is a real declaration ("writes nothing"),
#                                 # which is not the same as omitting the field. Omitted
#                                 # means unknown, and unknown must never score as cheap.
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
created: 2026-09-29T07:18:43Z
last_update: '2026-09-29T07:30:13Z'
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
  - ts: '2026-09-29T07:30:13Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 3
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=3 
      (workflow:refactor); effort=8 (lines=291,acs=10)
    rubric_sha: e4a00f38e801
---

# T-3549: RCA: inceptions keep reaching the operator with undisposed Open Questions — the readiness check warns instead of refusing, and an agent narrates past a warning

## Context

**Operator, 2026-09-29, after T-3548's GO was refused by the disposition gate:**

> "The mechanism is good that you catch it. What's not good is that we don't have the discipline
> to produce an inception that meets all requirements. And you keep proposing exceptions that
> have issues and that are not ready. And as you are the maintainer of the framework, this
> incapability trickles to all vendor instances. So therefore it's really important we get that
> right and we should really look at the root cause and focus now on remediating that. And
> getting a structure … that really looks that everything is right and self-adjust, auto-adjust
> if things are still missing. And they don't surface with omissions."

This is at least the **third** operator-facing instance: T-3532, T-3535, T-3548. It has already
been escalated once — in the T-3535 round the operator said *"I really want us to review this
process and make it more reliable. How can it be that we keep fucking this up?"* — and the
remediation that produced (T-3540) is the thing that failed here.

**The sharpest fact is not that the omission happened. It is that the warning fired and the
agent narrated past it.** `fw task review T-3548` printed `NOT decision-ready — 4 Open
Question(s) lack disposition/rationale`, and the agent relayed it to the operator as though the
undisposed state were deliberate ("disposing them *is* the discussion"). `deferred` was available
for all four and would have taken under a minute.

**Why the existing control did not hold — and it is the agent's own reasoning from T-3540**,
`lib/review.sh:442`:

> "Emission is still not blocked — the review page is a legitimate route to reaching
> dispositions, and refusing here would strand a task whose only problem is that nobody has
> answered its questions yet. But the blocker now travels WITH the handoff, so an agent pasting
> this output cannot hand the decision over unaware."

Both halves are now falsified by observation:

1. **"Refusing would strand a task"** — false. `deferred` is always available as a disposition,
   so an agent is never unable to dispose. Nothing can be stranded by requiring it. The T-3540
   reasoning imagined a task that *cannot* be disposed; no such task exists.
2. **"An agent cannot hand it over unaware"** — true and irrelevant. The agent was not unaware.
   It was aware, and handed it over anyway with a justification attached. **Awareness was never
   the failure mode.** A WARN that permits the action is an invitation to explain the action.

Scope fence: this task fixes the *handoff boundary* for inception readiness. It does NOT
re-open T-3548's content, and it does NOT weaken the T-2190 decide-time gate, which worked
correctly and must keep working as the last line.

## Acceptance Criteria

### Agent
- [x] Blast radius measured and recorded in `## RCA`: how many inceptions in `active/` and
      `completed/` carry undisposed `IW-N` questions, so the claim "third instance" is replaced
      by a number
- [x] **One** readiness predicate for inception handoff exists, covering every known requirement
      (Open Questions present, each disposed with a rationale, Recommendation substantive), so
      requirements stop being discovered one refusal at a time
- [x] `fw task review` REFUSES to emit a handoff for an inception that fails it, naming each
      failing item and the exact command that fixes it — replacing the T-3540 WARN, whose own
      stated rationale is falsified above
- [x] The refusal names `deferred` explicitly as an always-available disposition, because the
      belief that a question might be undisposable is what produced the WARN-not-BLOCK choice
- [x] Auto-adjust where the repair is mechanical and needs no judgement (a malformed or absent
      `disposition:` LINE is repaired in shape); auto-adjust is explicitly NOT applied to the
      disposition VALUE, since auto-deferring an unconsidered question manufactures readiness —
      the failure class this task exists to remove
- [x] A bypass exists, is env-var shaped per L-399/T-1890 parity, and writes a Tier-2 entry
- [x] Tests pin: a ready inception still emits its handoff (control); an unready one is refused;
      the refusal text names the fixing command; the bypass works and logs; and a NEGATIVE
      CONTROL proves the refusal can be reached — i.e. it is not vacuously green
- [x] `bin/fw vendor self --check` clean, so the fix reaches vendored consumer instances rather
      than only this repo — the operator's stated reason this matters beyond us

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

# The refusal, its controls, the bypass, and the two structural pins.
timeout 600 bats tests/unit/t3549_inception_handoff_refusal.bats > /tmp/.t3549.out 2>&1 && ! grep -q "^not ok" /tmp/.t3549.out
test "$(grep -c '# skip' /tmp/.t3549.out)" -eq 0

# A dead negation here would make the refusal assertions inert — the exact
# false-green family this task is about (caught on my own test earlier today).
python3 tools/bats-dead-negation-lint.py tests/unit/t3549_inception_handoff_refusal.bats > /tmp/.t3549-dn.out 2>&1 && grep -q "clean" /tmp/.t3549-dn.out

# The WARN that permitted the handoff must be gone, and the BLOCK present.
! grep -q "WARNING: this inception is NOT decision-ready" lib/review.sh
grep -q "BLOCKED: this inception is NOT decision-ready" lib/review.sh

# The decide-time gate (T-2190) is untouched — this moved the EARLIEST check,
# not the last one. Its shared predicate must still exist and still be consulted.
grep -q 'inception_underdisposed_questions()' lib/inception-readiness.sh
grep -q 'inception_underdisposed_questions "$task_file") || true' lib/review.sh

# Siblings over the same file stay green.
timeout 600 bats tests/unit/t3540_inception_decide_diagnostics.bats > /tmp/.t3549-sib.out 2>&1 && ! grep -q "^not ok" /tmp/.t3549-sib.out || test ! -f tests/unit/t3540_inception_decide_diagnostics.bats

# Vendored path touched (lib/) — consumers get this via fw vendor self / fw upgrade,
# which is the operator's stated reason the defect matters beyond this repo.
bin/fw vendor self --check

## RCA

**Symptom:** the operator recorded GO on T-3548 and was refused — *"Cannot record GO — 4 Open
Question(s) not yet disposed"*. Third operator-facing instance (T-3532, T-3535, T-3548), the
second after an explicit escalation (*"How can it be that we keep fucking this up?"*).

**Blast radius, measured 2026-09-29 — and it contradicts the obvious story.** 504 inceptions;
121 carry `IW-N` questions at all:

| | inceptions | with IW questions | **with undisposed** |
|---|---:|---:|---:|
| `active/` | 32 | 14 | **0** |
| `completed/` | 472 | 107 | **1** (T-2527) |

The corpus is essentially clean. There is no backlog of broken inceptions. **The defect is a
transient at the handoff boundary that heals immediately afterwards** — the agent hands over
unready work, the operator bounces off the gate, the agent fixes it within minutes. Which is
exactly why counting artefacts finds nothing.

**Root cause, instance — the control warns where it should refuse.** `lib/review.sh:153-162`
detects the unready state and emits a WARN, then hands over anyway. The reasoning is the agent's
own, from T-3540 (`lib/review.sh:442`), and both halves are falsified by observation:

- *"Refusing here would strand a task whose only problem is that nobody has answered its
  questions yet"* — **false.** `deferred` is always an available disposition, so no question is
  ever undisposable and no task can be stranded by requiring disposition. T-3540 reasoned about
  a task that cannot exist.
- *"The blocker now travels WITH the handoff, so an agent pasting this output cannot hand the
  decision over unaware"* — **true and irrelevant.** The agent was not unaware. It read the
  warning and relayed it with a justification attached ("disposing them *is* the discussion").
  **Awareness was never the failure mode.** A WARN that still permits the action is an
  invitation to explain the action, and an agent is very good at explaining.

**Root cause, recurrence — a correctly-firing gate leaves no trace.**
`.context/working/.gate-bypass-log.yaml` records *bypasses*. **Nothing records a refusal.**
Grepping `lib/ agents/ bin/fw` for any refusal ledger returns zero hits. So when a gate does its
job, the only artefact is the operator's irritation. No audit section, metric, trend line or
learning can observe it; the task's episodic record shows a clean close, because the fix landed
minutes later.

That is why three incidents produced three *local* fixes instead of one structural one: **there
was never a second data point visible to anyone at the moment a fix was being designed.** Each
looked like a one-off. The pattern lived only in the operator's memory — precisely the thing the
framework exists to stop relying on.

**Why the framework allowed it:** the ladder has a hole between "WARN, proceed" and "BLOCK".
Every other inception requirement closed that hole by moving to BLOCK at multiple producer legs
— T-2204's recommendation-completeness gate fires at four producer surfaces, a consumer surface
and an hourly cron backstop. The disposition requirement got one decide-time BLOCK (correct, but
positioned *after* the handoff, so the operator discovers it) plus one producer-side WARN, which
an agent can narrate past.

**Prevention:**

- *Shipped here (Leg A)*: one readiness predicate for inception handoff; `fw task review`
  REFUSES rather than warns, naming each failing item, the command that fixes it, and that
  `deferred` is always available — the belief that a question might be undisposable is what
  produced the WARN-not-BLOCK choice.
- *Auto-adjust, deliberately bounded*: a malformed or missing `disposition:` LINE is repaired in
  shape; the disposition VALUE is never auto-filled. Auto-deferring an unconsidered question
  manufactures readiness, which is the failure class being removed, not a cheaper way to satisfy
  it.
- *Filed, not shipped (Leg B)*: a refusal ledger, so the class becomes measurable and the next
  variant is caught by a rail rather than by the operator noticing a third time. Filed separately
  because it is a framework-wide mechanism serving every gate, not an inception fix.
- *Consumer reach*: `lib/review.sh` is vendored, so `fw vendor self` carries this to consumer
  instances — the operator's stated reason it matters beyond this repo.

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

### 2026-09-29T07:18:43Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3549-rca-inceptions-keep-reaching-the-operato.md
- **Context:** Initial task creation
