---
id: T-3161
name: "fw cron install wipes a live deployed crontab when the registry declares jobs: [], and both drift checks skip instead of warning"
description: >
  Inbound field report from 001-CashWeb (their G-051). Two lanes computed the same /etc/cron.d target; T-3070 (2026-08-24) redirected 'fw audit schedule install' to 'fw cron install' when a registry exists, but shipped no transition for projects whose jobs came from the legacy heredoc lane and whose registry is still 'jobs: []'. Reproduced at HEAD: with jobs: [] and a live target carrying two job lines, 'fw cron install' silently replaced source AND target with a header-only file — no refusal, no warning. Compounding: the T-2844 empty-registry guard in bin/fw do_doctor and agents/audit/audit.sh skips the drift checks unconditionally, so Watchtower /cron reports '0 jobs' and audit reports INFO while ten jobs are demonstrably running. The remedy the page suggests is the command that erases the schedule.

status: captured
workflow_type: build
owner: agent
horizon: now
tags: [cron, registry, inbound-report, 001-cashweb, false-green]
components: []
related_tasks: [T-3160, T-3162, T-3070, T-3149]
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
created: 2026-08-26T12:09:00Z
last_update: 2026-08-26T12:09:00Z
date_finished: null
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

# T-3161: fw cron install wipes a live deployed crontab when the registry declares jobs: [], and both drift checks skip instead of warning

## Context

Inbound field report from consumer project **001-CashWeb-Lightspeed-Ecwid-integration**
(their T-151, registered there as G-051), vendored AEF v1.6.29. Registered here as
**G-088**. This project does not modify 001-CashWeb.

This is the second-order residue of **OBS-249 / T-3070**. T-3070 (2026-08-24) stopped the
two cron lanes from both *writing*: `agents/audit/audit.sh schedule install` now `exec`s
`fw cron install` when a registry exists. It shipped no **transition** for projects whose
deployed jobs came from the legacy heredoc lane while `.context/cron-registry.yaml` is
still the `jobs: []` that `fw init` seeds. For those projects the delegation makes the
outcome worse: the legacy command now regenerates from an empty registry.

**Reproduced at HEAD (v1.6.78).** Registry `jobs: []`, deployed target carrying two live
job lines:

```
$ PROJECT_ROOT=/tmp/cronprobe2 FW_CRON_INSTALL_DIR=/tmp/cronprobe2/etc bin/fw cron install
Pending cron changes:
  -*/30 * * * * root echo legacy-audit-structural
  -0 * * * * root echo legacy-audit-traceability
Installed: /tmp/cronprobe2/etc/agentic-audit-cronprobe2
```

Both the git-tracked source and the deployed target became a six-line header-only file.
No refusal, no warning, exit 0.

**Compounding false-green.** The T-2844 empty-registry guard — `bin/fw:3134` (doctor) and
`agents/audit/audit.sh:2350` (audit) — skips the drift checks whenever job count is 0,
without testing whether the deployed target exists. So the reporting project, with ten
jobs demonstrably running and 622 output files in `.context/audits/cron/`, gets
`SKIP Cron drift checks skipped — registry declares no jobs (nothing to generate)`, and
Watchtower `/cron` renders `0 jobs — No jobs in cron registry`. The page does not hedge;
it asserts absence. That assertion is what produced the operator report ("our cron jobs
are not installed") that led to the whole investigation.

**The dangerous composition:** the obvious response to that page is `fw cron install` —
the command the page itself suggests — which is the command that erases the ten jobs.

T-2844 was right that a freshly initialised project has no generated form and should not
WARN. It is wrong that job count alone settles it: `jobs: []` **and** target exists is not
a fresh init, it is an unmigrated project, and the two are currently indistinguishable to
both surfaces.

Scope fence: legs (a) and (b) below. The reporter's leg (c) — rendering `/cron` from
deployed `/etc/cron.d` state rather than from the registry declaration — is a render
surface (P-013) and a separate deliverable; file it as a follow-up, do not fold it in.

## Acceptance Criteria

### Agent
- [ ] `fw cron install` refuses when the deployed target exists and does not carry the registry-generated header marker (`managed by cron-registry.yaml`), naming migration as the remedy and exiting non-zero without writing either the source or the target
- [ ] The refusal carries a bypass mechanism per L-399 producer/consumer parity (env-var form, since the gate must also survive the `audit.sh schedule install` → `fw cron install` exec), and the bypass writes a Tier-2 entry to `.context/working/.gate-bypass-log.yaml`
- [ ] `bin/fw` doctor WARNs instead of SKIPping when registry job count is 0 AND the deployed target exists; the fresh-init case (job count 0, no target) still SKIPs silently
- [ ] `agents/audit/audit.sh` emits the same distinction — WARN on `jobs: [] + target exists`, INFO/skip on fresh init — so both surfaces agree
- [ ] Regression test `tests/unit/t3161_empty_registry_does_not_wipe_live_cron.bats` pins: install refuses on unmigrated target, install still works on a marker-carrying target, doctor WARNs on `jobs: [] + target`, doctor SKIPs on fresh init
- [ ] Follow-up task filed for the reporter's leg (c) — `/cron` renders deployed host state alongside the registry declaration — and referenced in `related_tasks:`

## Verification

out=$(bin/fw doctor 2>&1); echo "$out" | grep -q "Cron registry in sync" && ! echo "$out" | grep -q "Cron registry edited but not generated"
bats tests/unit/t3161_empty_registry_does_not_wipe_live_cron.bats > /tmp/.t3161-bats 2>&1 && grep -q "^ok 1 " /tmp/.t3161-bats && ! grep -q "^not ok" /tmp/.t3161-bats

## RCA

**Symptom:** a project with ten cron jobs running reads `0 jobs — No jobs in cron
registry` on Watchtower `/cron` and `SKIP ... nothing to generate` from doctor and audit;
acting on the page's own suggestion (`fw cron install`) deletes the ten jobs.

**Root cause:** two independent defects composing. (1) `fw cron install` has no notion of
"the deployed target was not produced by me" — it treats any target as its own output and
overwrites unconditionally. (2) The T-2844 empty-registry guard uses job count as a proxy
for "fresh init", but job count 0 has two distinct meanings and the guard collapses them.

**Why structurally allowed:** T-3070 closed the dual-*writer* leg and its regression test
(`t3070_audit_schedule_install_delegates_to_registry.bats`) passes — so the class read as
closed. The migration state it left behind was never enumerated, because the fix was
framed as "make the old command resolve to the new logic" and the projects that had
already diverged under the old logic were out of frame. Meanwhile the drift checks that
would have surfaced the divergence were precisely the ones the empty registry silenced:
**a check that compared nothing rendered as a check that found nothing**, which is
indistinguishable from health at every surface.

**Prevention:** (to be written with the fix) — the header-marker refusal makes the
unmigrated state loud at the moment of damage, and the WARN split makes it loud
continuously before anyone reaches for the command.

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

### 2026-08-26T12:09:00Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3161-fw-cron-install-wipes-a-live-deployed-cr.md
- **Context:** Initial task creation
