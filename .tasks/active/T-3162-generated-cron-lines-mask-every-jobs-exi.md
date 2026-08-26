---
id: T-3162
name: "generated cron lines mask every job's exit status behind the logger pipeline"
description: >
  Inbound field report from 001-CashWeb (their G-052). Both generators (bin/fw cron generate and lib/cron_dry_run.py:79-83) append '2>&1 | logger -t agentic-cron' to each command, replacing any existing 2>/dev/null. A pipeline's exit status is the last component's, so cron always sees 0. Reproduced: 'false 2>&1 | logger' -> status 0; with '; exit ${PIPESTATUS[0]}' -> status 1. No MAILTO is set, so a crashed nightly audit is indistinguishable from a successful one; the only remaining trace is unmonitored syslog text. Reporter's preferred fix (per-line '; exit ${PIPESTATUS[0]}') is the correct one — 'SHELL=/bin/bash -o pipefail' does not work in cron.d, where SHELL must be a bare executable path. The stderr-capture gain of T-1720 is real and should be kept.

status: captured
workflow_type: build
owner: agent
horizon: now
tags: [cron, exit-status, inbound-report, 001-cashweb, silent-failure]
components: []
related_tasks: [T-3160, T-3161, T-3149]
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
created: 2026-08-26T12:09:12Z
last_update: 2026-08-26T12:09:12Z
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

# T-3162: generated cron lines mask every job's exit status behind the logger pipeline

## Context

Inbound field report from consumer project **001-CashWeb-Lightspeed-Ecwid-integration**
(their T-151, registered there as G-052), vendored AEF v1.6.29. Registered here as
**G-089**. This project does not modify 001-CashWeb.

Both generators — `bin/fw` `cron generate` (`bin/fw:5265-5270`) and
`lib/cron_dry_run.py:79-83` — rewrite each command to
`<cmd> 2>&1 | logger -t agentic-cron`, replacing any existing `2>/dev/null`. A pipeline
exits with the status of its **last** component, and `logger` always succeeds.

**Reproduced, not inferred:**

```
$ bash -c 'false 2>&1 | logger -t probe; echo $?'                    -> 0
$ bash -c 'set -o pipefail; false 2>&1 | logger -t p2; echo $?'      -> 1
$ bash -c 'false 2>&1 | logger -t p3; exit ${PIPESTATUS[0]}'; echo $? -> 1
```

Consequence: cron still emits `CRON ... exited with status N` for a failing job in the
un-piped form, but under the generated form it always sees 0. No `MAILTO` is set, so no
mail either. The only surviving trace is syslog text under tag `agentic-cron`, which
nothing reads on a schedule. **A crashed nightly audit is indistinguishable from a
successful one at every automated surface.**

This is the framework's own L-365 blind spot made worse: the registry → generated →
deployed chain is gated at three transitions, but the fourth — deployed → executable,
which L-365 already names as ungated — is exactly the one this masking hides. Every
exec-time failure class L-365 lists (cwd, env, missing module) now reaches cron as exit 0.

**What must be preserved.** The T-1720 change this stems from is a real gain: before it,
generated lines ended in `2>/dev/null` and stderr was discarded outright. Piping to
`logger` puts it in `journalctl -t agentic-cron`. The reporter states this explicitly and
does not ask for a revert — their objection is that the gain is currently paid for with
the only machine-readable signal.

**Form.** Use the reporter's preferred per-line `; exit ${PIPESTATUS[0]}`. Do **not** put
`SHELL=/bin/bash -o pipefail` in the generated header: cron.d treats `SHELL` as a bare
executable path and does not word-split arguments.

**Parity requirement.** `bin/fw cron generate` and `lib/cron_dry_run.py` are
content-compared by both drift checks. They must change together or registry→generated
drift reports permanent false drift.

## Acceptance Criteria

### Agent
- [ ] `bin/fw` `cron generate` appends `; exit ${PIPESTATUS[0]}` to every generated active job line, after the logger pipe
- [ ] `lib/cron_dry_run.py` emits byte-identical output to `fw cron generate` for the same registry, including the new suffix
- [ ] Paused lines (`# PAUSED: ...`) and non-`fw` commands get the same treatment, so resuming a job does not change its failure semantics
- [ ] A job that exits non-zero produces a non-zero status from the fully generated line — verified by executing the generated line, not by reading it
- [ ] `.context/cron/agentic-audit.crontab` regenerated and deployed, so both drift checks stay green after the generator change
- [ ] Regression test `tests/unit/t3162_cron_job_exit_status_survives_logger_pipe.bats` pins: generated line propagates non-zero status, stderr still reaches logger, both generators byte-identical

## Verification

python3 lib/cron_dry_run.py "$PROJECT_ROOT" "$PROJECT_ROOT/.context/cron-registry.yaml" "$PWD/bin/fw" > /tmp/.t3162-dry 2>&1 && diff -q /tmp/.t3162-dry "$PROJECT_ROOT/.context/cron/agentic-audit.crontab"
bash -c 'set -eo pipefail; ! bash -c "false 2>&1 | logger -t t3162-probe; exit \${PIPESTATUS[0]}"'
out=$(bin/fw doctor 2>&1); echo "$out" | grep -q "Cron registry in sync" && ! echo "$out" | grep -q "Cron registry edited but not generated"
bats tests/unit/t3162_cron_job_exit_status_survives_logger_pipe.bats > /tmp/.t3162-bats 2>&1 && grep -q "^ok 1 " /tmp/.t3162-bats && ! grep -q "^not ok" /tmp/.t3162-bats

## RCA

**Symptom:** every framework cron job reports exit 0 to cron regardless of outcome, so a
failing scheduled audit produces no cron log entry, no mail, and no automated signal.

**Root cause:** `2>&1 | logger` makes `logger` the status-bearing component of the
pipeline. The rewrite was introduced (T-1720) to stop discarding stderr and correctly
solved that; it did not consider that it was also replacing the exit-status channel.

**Why structurally allowed:** the framework gates the three transitions it can observe
from inside the repo (registry → generated → deployed) and explicitly documents the
fourth (deployed → executable, L-365) as having no automated gate. Exit-status masking
lives entirely in that fourth transition, so no existing check could see it — and the
failure it hides is silent by construction, which is why it took an external reporter
walking the generator line by line to find it rather than an incident.

**Prevention:** (to be written with the fix) — a test that *executes* a generated line
with a failing command and asserts non-zero, rather than asserting on the generated text,
so the property is pinned at the transition L-365 says nothing else watches.

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

### 2026-08-26T12:09:12Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3162-generated-cron-lines-mask-every-jobs-exi.md
- **Context:** Initial task creation
