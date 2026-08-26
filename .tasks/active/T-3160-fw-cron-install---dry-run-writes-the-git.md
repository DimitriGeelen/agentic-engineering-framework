---
id: T-3160
name: "fw cron install --dry-run writes the git-tracked crontab source before printing 'no changes made'"
description: >
  Inbound field report from 001-CashWeb-Lightspeed-Ecwid-integration (their G-050). 'fw cron install --dry-run' runs 'fw cron generate' as step 1 to compute its diff, which WRITES $PROJECT_ROOT/.context/cron/agentic-audit.crontab, then prints '(dry-run — no changes made)'. Reproduced at HEAD v1.6.78 in a sandbox project root: 135 bytes -> 389 bytes, md5 changed, message still claimed no changes. In their project it truncated a 3875-byte file carrying ten running jobs to 450 bytes; recovered only because the file was git-tracked. Fix: dry-run must not call the writing generator — route through lib/cron_dry_run.py (stdout-only) for the diff comparand.

status: captured
workflow_type: build
owner: agent
horizon: now
tags: [cron, dry-run, inbound-report, 001-cashweb]
components: []
related_tasks: [T-3161, T-3162, T-3149]
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
created: 2026-08-26T12:08:35Z
last_update: 2026-08-26T12:08:35Z
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

# T-3160: fw cron install --dry-run writes the git-tracked crontab source before printing 'no changes made'

## Context

Inbound field report from consumer project **001-CashWeb-Lightspeed-Ecwid-integration**
(their T-151, registered there as G-050), vendored AEF v1.6.29. Registered here as
**G-087**. This project does not modify 001-CashWeb; the report is self-contained.

`fw cron install --dry-run` computes its diff by calling `"$0" cron generate` as step 1
(`bin/fw:5487`) — the same writing code path the non-dry-run form uses. Only step 3
(the `/etc/cron.d` install) is guarded by `$_install_dry_run`. The command then prints
`(dry-run — no changes made)` over a file it has just rewritten.

**Reproduced at HEAD (v1.6.78), not version-specific.** Sandbox project root with a
hand-written source file and a one-job registry:

```
BEFORE: 135 bytes  md5 69313a83cf63413969317ce5d47066ea
  $ PROJECT_ROOT=/tmp/cronprobe FW_CRON_INSTALL_DIR=/tmp/cronprobe/etc bin/fw cron install --dry-run
  ... (dry-run — no changes made)
AFTER:  389 bytes  md5 4d9e0f04704840073eed33403663b688
```

In the reporting project the same call truncated a git-tracked 3875-byte crontab source
carrying ten running jobs to 450 bytes (39 lines deleted). They recovered with
`git checkout HEAD --` and verified the result byte-identical to `/etc/cron.d/`; no job
missed a cycle. Recovery depended entirely on the file being tracked.

Their framing is the part worth keeping: `--dry-run` is the flag an operator reaches for
*because* they do not yet know what the command will do, so a writing `--dry-run`
punishes the cautious choice specifically. Outside git it is silent, unrecoverable loss
with a success message on top.

A non-writing generator already exists and is already the comparand for both drift
checks: `lib/cron_dry_run.py` emits the same text to stdout and never writes.

## Acceptance Criteria

### Agent
- [ ] `fw cron install --dry-run` leaves `$PROJECT_ROOT/.context/cron/agentic-audit.crontab` untouched — same md5 AND same mtime — when the on-disk source differs from what the registry would generate
- [ ] The diff `--dry-run` prints is unchanged in content: registry-derived text compared against the deployed target, sourced from `lib/cron_dry_run.py` rather than from the written file
- [ ] `fw cron install` without `--dry-run` still generates, diffs and installs exactly as before (in-sync short-circuit, new-install preview, sudo degradation all preserved)
- [ ] Regression test `tests/unit/t3160_cron_dry_run_does_not_write.bats` pins: mtime+md5 unchanged after `--dry-run`, diff still printed, non-dry-run still writes
- [ ] Every other `fw` subcommand advertising `--dry-run` is surveyed for the same shape (write reached before the flag is honoured) and the result recorded in `## Decisions` — `fw vendor`, `fw upgrade`, `fw harvest`, `fw triage route`, `fw integrate run`, `fw task archive-eligible`, `fw mcp reap`

## Verification

bash -c 'set -eo pipefail; rm -rf /tmp/t3160 && mkdir -p /tmp/t3160/.context/cron /tmp/t3160/etc && printf "framework_version: probe\n" > /tmp/t3160/.framework.yaml && printf "jobs:\n  - id: p\n    name: P\n    schedule: \"*/5 * * * *\"\n    command: \"echo hi\"\n    status: active\n" > /tmp/t3160/.context/cron-registry.yaml && printf "# legacy\n" > /tmp/t3160/.context/cron/agentic-audit.crontab && before=$(md5sum /tmp/t3160/.context/cron/agentic-audit.crontab | cut -d" " -f1) && PROJECT_ROOT=/tmp/t3160 FW_CRON_INSTALL_DIR=/tmp/t3160/etc bin/fw cron install --dry-run >/dev/null 2>&1 && after=$(md5sum /tmp/t3160/.context/cron/agentic-audit.crontab | cut -d" " -f1) && [ "$before" = "$after" ]'
bats tests/unit/t3160_cron_dry_run_does_not_write.bats > /tmp/.t3160-bats 2>&1 && grep -q "^ok 1 " /tmp/.t3160-bats && ! grep -q "^not ok" /tmp/.t3160-bats

## RCA

**Symptom:** `fw cron install --dry-run` rewrites the git-tracked crontab source and
prints `(dry-run — no changes made)` in the same output. Reported by 001-CashWeb after
it truncated a 3875-byte file holding ten live jobs to 450 bytes.

**Root cause:** the dry-run branch was added to the *install* step only. `bin/fw:5487`
generates unconditionally because generation is how the diff comparand is produced; the
flag was applied at the last mutation rather than at the first.

**Why structurally allowed:** the write is idempotent whenever registry and generated
form are already in sync — which is the state every framework-repo session is in, so
the mutation is invisible here and only surfaces on a project that never migrated. The
one surface that would have caught it, a test asserting `--dry-run` writes nothing, was
never written because the flag *reads* as a guarantee rather than as a claim to verify.
Same signature as the port-3000 false-green class: the output asserts a property it
never checked.

**Prevention:** (to be written with the fix) — regression test pinning no-write, plus
the cross-command `--dry-run` survey so the class is closed rather than the instance.

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

### 2026-08-26T12:08:35Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3160-fw-cron-install---dry-run-writes-the-git.md
- **Context:** Initial task creation
