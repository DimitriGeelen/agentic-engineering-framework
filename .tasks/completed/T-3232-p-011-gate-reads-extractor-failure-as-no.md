---
id: T-3232
name: "P-011 gate reads extractor failure as no-Verification-section and passes 0
  of N"
description: >
  arc-012 review C3. lib/verification-port.sh:202 extract_verification_block is awk
  | comment_strip.py 2>/dev/null | grep ... || true. EVERY failure mode of that pipeline
  yields the empty string with exit 0, and update-task.sh:1182 reads empty as 'this
  task has no Verification section' -> return 0 -> completion allowed with zero commands
  run and NO OUTPUT. Reproduced: a clean block extracts 'true'; the same block with
  one 0xff byte extracts empty (comment_strip.py exits 1 on UnicodeDecodeError, stderr
  swallowed by 2>/dev/null, status by || true). This is T-3219 one level up: T-3219
  fixed the gate running 2 of 4 commands, this is the gate running 0 of 4 and reporting
  the same pass. Design sketch, validated by reading both sides: capture the python
  stage exit status explicitly instead of collapsing it, and have the function RETURN
  2 on extraction failure while still returning 0 for a genuinely absent or empty
  section. Caller then distinguishes the two and refuses on 2. Backward compatible
  for consumers that ignore the exit code (fw verify-queue) since stdout is unchanged.
  Do NOT fix by having the caller independently re-detect whether a Verification section
  exists - that is a guard reimplementing the code it guards, the class peer 577-CashWeb
  raised as G-072.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [arc:continuous-run]
components: [agents/task-create/update-task.sh, lib/verification-port.sh, tests/unit/t3232_verification_extractor_failure.bats]
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
created: 2026-08-31T13:12:11Z
last_update: 2026-08-31T15:39:03Z
date_finished: 2026-08-31T15:39:03Z
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
  - ts: '2026-08-31T13:15:10Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=261,acs=4)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-31T13:15:18Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3232: P-011 gate reads extractor failure as no-Verification-section and passes 0 of N

## Context

Finding C3 of the arc-012 review (`docs/reports/arc-012-review/SYNTHESIS.md`).

`extract_verification_block` (`lib/verification-port.sh:202`) is a three-stage
pipeline ending in `|| true`. Every failure mode of every stage collapses to the
same value the function returns for a task that simply has no Verification
section: the empty string, exit 0. `update-task.sh:1182` reads that as "nothing
to verify" and returns 0 — completion allowed, **zero commands run, no output**.

The two states are not the same and the function cannot tell you which one it is
in. That is the defect: not that extraction can fail, but that failure is
indistinguishable from success-with-nothing-to-do.

This is T-3219 one level up. T-3219 fixed the gate running 2 of 4 commands; this
is the gate running 0 of 4. Measured during the fix, the review's wording needs
one correction: the gate does not *print* a pass on this input, it prints nothing
at all and returns early. A silent skip is worse than a printed `0/0 passed`,
which would at least have left a line in the log for someone to notice.

## Acceptance Criteria

### Agent
- [x] `extract_verification_block` returns **2** when a pipeline stage fails, and its
      stdout is unchanged from today's behaviour (empty), so consumers that ignore the
      exit code keep working
- [x] It still returns **0** for a genuinely absent Verification section, and **0**
      for a present block that yields commands — the three states are distinguishable
      by exit code alone
- [x] The `grep -vE` stage exiting 1 on "block present but every line is a comment"
      is classified as *empty*, not as *failure* — that is a normal outcome, not a fault
- [x] `update-task.sh` refuses `--status work-completed` on rc=2 with a message naming
      the file and the bypass, instead of silently returning 0
- [x] The refusal is bypassable via `FW_ALLOW_UNEXTRACTABLE_VERIFICATION=1`, logged
      Tier-2 to `.gate-bypass-log.yaml` (parity with the sibling
      `FW_ALLOW_UNPARSEABLE_VERIFICATION` gate two lines below it)
- [x] The caller does **not** independently re-detect whether a Verification
      section exists — a guard reimplementing the code it guards is the G-072 class
      peer 577-CashWeb raised; the exit code is the whole contract
- [x] A bats suite drives the **real** function and the **real** close gate (not a
      re-implementation), with control legs proving the harness can both pass and fail,
      and zero skips (T-3217: a skipped test reports `ok`)
- [x] Mutation testing: reverting each leg of the fix independently reddens at least
      one test, recorded as a matrix in the RCA

## Verification

timeout 600 bats tests/unit/t3232_verification_extractor_failure.bats > /tmp/.t3232a.out 2>&1 && ! grep -q "^not ok" /tmp/.t3232a.out
test "$(grep -c '# skip' /tmp/.t3232a.out)" -eq 0
timeout 900 bats tests/unit/verification_extractor_anchoring.bats > /tmp/.t3232b.out 2>&1 && ! grep -q "^not ok" /tmp/.t3232b.out
test "$(grep -c '# skip' /tmp/.t3232b.out)" -eq 0
timeout 900 bats tests/unit/t2921_verification_comment_strip.bats > /tmp/.t3232c.out 2>&1 && ! grep -q "^not ok" /tmp/.t3232c.out
test "$(grep -c '# skip' /tmp/.t3232c.out)" -eq 0
timeout 900 bats tests/unit/t2765_verify_queue.bats > /tmp/.t3232d.out 2>&1 && ! grep -q "^not ok" /tmp/.t3232d.out
test "$(grep -c '# skip' /tmp/.t3232d.out)" -eq 0
grep -q 'FW_ALLOW_UNEXTRACTABLE_VERIFICATION' agents/task-create/update-task.sh
grep -q 'PIPESTATUS' lib/verification-port.sh
# `;` not `&&` here, deliberately, and this is the rare case where T-3203's
# "cmd1; cmd2 is judged only on cmd2" is the BEHAVIOUR WANTED rather than a trap.
# fw verify-queue exits non-zero when any task in its rotation is red — and the
# rotation is least-recently-checked-first, so which five tasks it samples differs
# between runs. Making its exit code the verdict would make THIS task's close gate
# depend on other tasks' health: it passed in rehearsal and failed at the gate
# minutes later purely because the sample moved (it hit T-2038, red for an
# unrelated playwright reason). What this line must assert is that the rail still
# RUNS after the extractor's contract changed, which is exactly what the report
# line proves — a crash or an import error prints no such line.
timeout 300 bin/fw verify-queue > /tmp/.t3232e.out 2>&1; grep -q "task(s) checked" /tmp/.t3232e.out

## RCA

**Symptom:** a task whose `## Verification` block cannot be decoded reaches
`work-completed` with zero verification commands run. Not one command failed and
not one was reported — the gate returns before it prints anything.

**Root cause:** `extract_verification_block` ended in `|| true`, so all three
pipeline stages had their exit status discarded and every failure produced the
same value as the "no Verification section" case: empty stdout, exit 0. The
caller had exactly one bit of information (`-z "$verify_cmds"`) to distinguish
two states that need different answers.

**Why structurally allowed:** the `|| true` is *correct* for the case it was
written for — a task with no Verification block must not make the gate fail — and
it silently generalised to every other reason the pipeline can produce nothing.
Nothing ever compared the two states because, until this task, they were not
representable as different values. The gate could not have detected this about
itself: an instrument whose failure mode is indistinguishable from its
success-with-nothing-to-do mode is reporting on a cached assumption, not on its
subject. Same family as C1 and C2 of the same review, and as T-3219 one level
down.

**Prevention:** three-way exit contract (0 = read it, 0 = nothing there, 2 =
could not read), pinned by `tests/unit/t3232_verification_extractor_failure.bats`
at both the function and gate levels, with control legs at both. The load-bearing
test is *"a FAILED extraction is distinguishable from an ABSENT section"* — it
compares the gate's whole output on the two inputs and fails when they match,
which is the defect stated as an assertion rather than as prose.

**Mutation matrix.** Each leg reverted independently against the finished suite;
restore verified byte-identical after every run:

| # | mutation | reddened |
|---|---|---|
| M1 | `return 2` → `return 0` (equivalent to the old `\|\| true`) | 5 |
| M2 | stop classifying a python-stage failure | 4 |
| M3 | treat grep's "filtered everything out" (rc=1) as failure | 4 |
| M4 | caller ignores the new exit code | 3 |
| M5 | bypass env no longer recognised | 1 |

M4 is the one that matters: it restores the original bug exactly, and it reddens
the distinguishability test on the *comparison* — `[ "$dirty_out" != "$absent_out" ]`
fails because under the bug the two outputs are byte-identical. The defect is
therefore demonstrated, not asserted.

**Two of my own tests were inert before the matrix caught them**, which is the
reason the matrix is not optional. The first version of the distinguishability
test asserted the absence of a green line — true both before and after the fix,
so M4 reddened nothing. The corrected version then reddened for the *wrong*
reason: bats runs bodies under errexit, so it failed on the capture assignment
rather than on the comparison. A test that reddens for the wrong reason is not
evidence (L-302).

## Evolution

### 2026-08-31 — the finding's own wording was slightly wrong, in a way that matters

- **What changed:** C3 says the gate "reports the same pass". It does not report
  anything: `[ -z "$verify_cmds" ] && return 0` fires before the gate prints its
  header, so a task with an undecodable block produces output byte-identical to a
  task with no block at all. The consequence the review named (completion allowed
  over zero commands) is right; the mechanism is a silent skip, not a printed
  green. That distinction became the suite's load-bearing test.
- **Plan impact:** none to the design — the three-way exit contract in the filing
  survived contact unchanged. It changed what the test asserts: comparing the two
  outputs is strictly stronger than looking for a marker in one of them.
- **Triggered:** correction filed into `docs/reports/arc-012-review/SYNTHESIS.md`
  alongside the C2 correction from T-3231.

### 2026-08-31 — reproducing the finding took two attempts, and the first one "disproved" it

- **What changed:** the first repro appended the `0xff` byte after the closing
  `## RCA` heading. awk stops at the next `## `, so the bad byte never reached
  `comment_strip.py` and extraction succeeded — which reads exactly like the
  finding being wrong. The byte has to be *inside* the block.
- **Plan impact:** none, but it is now written into the suite's fixture comment,
  because the next person to touch this will make the same mistake.
- **Triggered:** nothing filed; captured as a fixture comment and here.

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

### 2026-08-31T13:12:11Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3232-p-011-gate-reads-extractor-failure-as-no.md
- **Context:** Initial task creation

### 2026-08-31T13:12:30Z — status-update [task-update-agent]
- **Change:** tags: +arc:continuous-run

### 2026-08-31T15:17:15Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-0f3d1a8c
- **Timestamp:** 2026-08-31T15:39:43Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-31T15:39:03Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
