---
id: T-3545
name: "OBS-467 residue: branch-hygiene and worktree headers still assert master as the integration target that T-3188 replaced with the dev branch"
description: >
  OBS-467 residue: branch-hygiene and worktree headers still assert master as the integration target that T-3188 replaced with the dev branch

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [lib/branch-hygiene.sh, lib/worktree.sh, tests/unit/t3545_branch_hygiene_header_parity.bats]
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
created: 2026-09-28T22:48:30Z
last_update: 2026-09-28T22:54:00Z
date_finished: 2026-09-28T22:54:00Z
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

# T-3545: OBS-467 residue: branch-hygiene and worktree headers still assert master as the integration target that T-3188 replaced with the dev branch

## Context

OBS-467 (found by 832) reported four sites still treating master as the branch this repo
integrates onto, after T-3185 made `bleeding-edge` the sanctioned development branch and
master the consumer install surface. Its sharpest claim was that the handover nudge would
tell a strand cut from bleeding-edge to merge into master — the exact injection the release
train exists to prevent.

**Measured at HEAD before filing, and the premise has mostly dissolved.** T-3188 already
fixed the behaviour:

| Site | Claimed state | Actual state at HEAD |
|---|---|---|
| `agents/handover/handover.sh:477` merge-back nudge | says `master` | **already fixed** — emits `fw integrate run ${_bd_devname} --push` |
| `lib/branch-hygiene.sh:604` remediation string | says `master` | **already fixed** — uses `$_gl_dev` |
| `fw_branch_hygiene` target resolution | judges against master | **already fixed** — `origin/$FW_DEV_BRANCH` first, master only as the master-only-consumer fallback |
| `fw_branch_divergence` comparand | judges against master | **already fixed** — same order, and silent on the dev branch |
| `lib/worktree.sh:246` `on_master` | wrong under release train | **not a defect** — a factual field ("is the checkout on master/main"), decides nothing, one test consumer |

What genuinely survives is **headers that assert the opposite of what their own code does**.
`lib/branch-hygiene.sh:9` reads *"Judged against TARGET = origin/master when present, else
master"* — flatly false since T-3188, at the top of the rail whose findings decide whether
branches get deleted. Four more comment sites in the same file and one in `lib/worktree.sh`
say the same thing.

That is not cosmetic. An agent reading that header reasons that landings are measured
against the consumer install surface, and under the release train that conclusion licenses
exactly the wrong remediation. A comment is the only interface a reader has before they
trust the function.

Scope fence: comments and their parity test. No behaviour changes — the behaviour is already
right and is pinned by T-3188's own tests, which must stay green. 832's second point (their
vendored tree has no integrate agent while handover.sh references it) is theirs to fix and
stays homed there per §Gap Homing.

## Acceptance Criteria

### Agent
- [x] `lib/branch-hygiene.sh`'s module header states the real resolution order — dev branch
      first, master as the master-only-consumer fallback — and names why master cannot be the
      comparand under the release train
- [x] The three other stale master references in that file's comments (the divergence header,
      its silence conditions, the exit-code line) are corrected to match the code
- [x] `lib/worktree.sh`'s trunk-resolution header no longer implies a worktree lands on master
- [x] A test pins header-vs-code parity: it fails if the resolution chain prefers the dev
      branch while the header claims master is the primary target, and it carries a control
      leg proving it can fail
- [x] No behaviour change — T-3188's and T-3194's existing suites stay green, verified by
      running them rather than by inspection
- [x] OBS-467 is updated in the register to record which legs were already closed by T-3188,
      so the next reader does not re-derive the four fixed sites

<!-- No Human criteria: every criterion here is a deterministic shell check, and
     nothing this task touches is a render surface. The template's Human block was
     removed as the template itself instructs when all criteria are agent-verifiable. -->

## Verification

<!-- ⚠ THIS SECTION WAS MALFORMED AT CLOSE AND THE P-011 GATE THEREFORE DID NOT RUN.
     Recorded here rather than quietly repaired, because the failure is the finding.

     The heading was spliced mid-sentence into the Human template comment above
     (which contains the literal phrase "added to ## Verification"), so no
     `## Verification` existed at line start. update-task.sh treats a missing
     section as the supported backward-compatible case and passes the task
     through — it cannot distinguish "no verification intended" from "verification
     present but unparseable". The close printed `Acceptance criteria: 6/6 ✓` and
     `Moved to completed/` with no gate section at all, and the absence of a line
     is not something a reader notices. Filed as OBS-565.

     work-completed → started-work is not a valid transition, so the gate cannot
     be re-run on this task. The commands below were instead executed by hand
     under the gate's real semantics (`bash -c 'set -o pipefail; <line>'`, each
     line judged on its own exit code); the results are recorded in ## Updates. -->

# Header-vs-code parity, with a control leg that restores the pre-T-3188 header
# over the current code and proves the check goes red on the contradiction.
timeout 300 bats tests/unit/t3545_branch_hygiene_header_parity.bats > /tmp/.t3545.out 2>&1 && ! grep -q "^not ok" /tmp/.t3545.out
test "$(grep -c '# skip' /tmp/.t3545.out)" -eq 0

# No behaviour changed — the suites that pin the release-train resolution order.
timeout 300 bats tests/unit/t3188_hygiene_release_train.bats > /tmp/.t3545-3188.out 2>&1 && ! grep -q "^not ok" /tmp/.t3545-3188.out
timeout 300 bats tests/unit/t3194_remediation_target.bats > /tmp/.t3545-3194.out 2>&1 && ! grep -q "^not ok" /tmp/.t3545-3194.out
timeout 300 bats tests/unit/t3187_branch_identity_guard.bats > /tmp/.t3545-3187.out 2>&1 && ! grep -q "^not ok" /tmp/.t3545-3187.out
timeout 300 bats tests/unit/t100143_branch_hygiene.bats > /tmp/.t3545-100143.out 2>&1 && ! grep -q "^not ok" /tmp/.t3545-100143.out

# The false sentence is gone from the file entirely, not merely from the header.
! grep -q "Judged against TARGET = origin/master when present" lib/branch-hygiene.sh

# The register records which legs T-3188 had already closed, so the next reader
# does not re-derive the four fixed sites.
python3 -c "import yaml;d=yaml.safe_load(open('.context/inbox.yaml'));o=[x for x in d['observations'] if x.get('id')=='OBS-467'][0];assert 'resolution' in o and 'T-3188' in o['resolution']"

# Vendored paths touched (lib/) — sync BEFORE close, per OBS-250.
bin/fw vendor self --check

## RCA

**Symptom:** `lib/branch-hygiene.sh`'s module header stated *"Judged against TARGET =
origin/master when present, else master"* while the function underneath resolved
`origin/$FW_DEV_BRANCH` first and fell back to master only for a consumer with no dev
branch. Four further comment sites in the same file, and one in `lib/worktree.sh`, carried
the same stale claim.

**Root cause:** T-3188 changed the comparand and its tests, and did not revisit the header
the change invalidated. Nothing connects the two: a test asserts what the code does, and
no test in this repo had ever asserted what a comment says about it.

**Why structurally allowed:** comments are outside every gate we run. `fw test lint`
shellchecks syntax, the invariant suite checks structural facts, the reviewer scans task
files — none reads a module header and compares it to the code beneath. So a header can
invert its own function's meaning and every surface stays green, indefinitely. The drift
survived from T-3188 (2026-09-07) until a peer read the file and reported it.

**Prevention:** `tests/unit/t3545_branch_hygiene_header_parity.bats` pins the relationship
rather than either side alone — the first ref the resolution chain tries, against what the
header claims is primary — and its control leg reconstructs the old header over the current
code to prove the check fires on exactly that contradiction. Two of its assertions are about
the header's *reasoning*, not its wording: it must say why master cannot be the comparand
(the release train) and must still document the master-only-consumer fallback. A header that
merely swapped one branch name for another would teach the next reader nothing, and they
would change it back.

**Not prevented — the class.** This pins one header on one file. Nothing stops the next
module's header from inverting, and a general "does this comment still describe this code"
check is not something a grep can do. The honest scope here is: the rail whose findings
delete branches now has a pinned header, because that is the one where being wrong costs
something.

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

### 2026-09-28T23:05Z — P-011 did not run at close; commands executed by hand [agent]
- **Action:** Discovered after close that no `## Verification` heading existed at line
  start (spliced mid-sentence into the Human template comment), so the gate ran zero
  commands and reported nothing. `fw task update T-3545 --status started-work` is refused
  — `work-completed → started-work` is not a valid transition — so the gate cannot be
  re-run on this task. Executed all nine verification commands by hand instead, each under
  the gate's real semantics (`bash -c 'set -o pipefail; <line>'`, judged on its own rc).
- **Output:** 9 of 9 passed.
  - `t3545_branch_hygiene_header_parity.bats` — green, 0 skips
  - `t3188_hygiene_release_train.bats` — green
  - `t3194_remediation_target.bats` — green
  - `t3187_branch_identity_guard.bats` — green
  - `t100143_branch_hygiene.bats` — green
  - the false sentence is absent from `lib/branch-hygiene.sh`
  - OBS-467 carries a `resolution:` naming T-3188
  - `bin/fw vendor self --check` clean
- **Context:** The gate's silence is the finding, not this task's result. Filed as OBS-565.
  The task's work stands on the evidence above; what it does NOT have is a gate-produced
  verdict, and that distinction is recorded here rather than papered over.

### 2026-09-28T22:48:30Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3545-obs-467-residue-branch-hygiene-and-workt.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-6be0d71c
- **Timestamp:** 2026-09-28T22:54:02Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-09-28T22:54:00Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
