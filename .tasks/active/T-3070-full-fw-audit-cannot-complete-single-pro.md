---
id: T-3070
name: "Full fw audit cannot complete: single process-wide lock contends with cron
  section runs"
description: >
  A full (all-section) 'fw audit' run takes long enough that it never wins the shared
  .context/locks/audit.lock against structural-30m/traceability-hourly/observations-6h/oe-*
  cron jobs, which each acquire the SAME internal audit.sh lock regardless of --section
  (cron's own /var/lock/agentic-cron-*.lock files are per-section-group and don't
  prevent this). Confirmed independently twice on T-1719 (2026-08-17): first attempt
  exit 75 'another audit already running' (cron holding lock), second attempt (lock
  free at start) ran 590s under timeout and was killed mid-run (exit 124) before reaching
  the SUMMARY section — output stopped after EPISODIC MEMORY CHECKS with no verdict.
  This makes 'fw audit clean' unusable as a task Acceptance Criterion anywhere, and
  makes the pre-push audit gate (OBS-221/T-2930 area, agents/git/lib/hooks.sh:915)
  contend against cron with no Tier-2 escape, only Tier-0 --no-verify. Candidate fixes
  noted by prior investigation: (a) full-audit mode takes a distinct lock from per-section
  cron runs, (b) full-audit retries/waits across cron gaps instead of failing immediately,
  (c) full-audit runs sections that don't overlap with in-flight cron sections first.
  Root-caused in T-1719 Evolution log (2026-08-17 entries) and .context/inbox.yaml
  (OBS-221-adjacent entry, 'PRE-PUSH AUDIT GATE CAN DEADLOCK AGAINST CRON AUDIT PILEUP').

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [audit, lock-contention, cron, verification-gate]
components: []
related_tasks: [T-1719, T-2930, T-860, T-862]
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
created: 2026-08-17T13:20:32Z
last_update: '2026-08-23T19:30:18Z'
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
  - ts: '2026-08-17T13:30:05Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=202,acs=4)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-17T13:30:15Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 3
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=3
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-18T13:30:18Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 3
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=3
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=1 
      (body/components:context-fabric-incidental); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-23T19:30:18Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 3
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=3
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=1 (body/components:context-fabric-incidental); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3070: Full fw audit cannot complete: single process-wide lock contends with cron section runs

## Context

Two candidate root causes, not yet disentangled by T-1719's three prior attempts:
1. **Lock-acquisition contention** against cron section jobs sharing the same
   `.context/locks/audit.lock`, sharpened by an actual **schedule collision**:
   `full-daily` fires `0 8 * * *`, the same minute as `structural-30m`
   (`*/30 * * * *`) and `traceability-hourly` (`0 * * * *`) — three cron jobs
   racing for the same lock in the same minute is not bad luck, it's the
   registry (`.context/cron-registry.yaml`).
2. **Raw runtime**, independent of contention: `AUDIT_TIMEOUT` (`agents/audit/audit.sh:340`,
   default 600s) may be too short for a full run regardless of who holds the
   lock. T-1719's third attempt (uncontended lock, `timeout 590`) was still
   inside `EPISODIC MEMORY CHECKS` — section 10 of 27 (`grep -n 'echo "=== '
   agents/audit/audit.sh`) — when killed, with `WHOLE-TREE SCANS` alone
   already measured at ~283s per the T-3062 comment at `audit.sh:2327-2341`.

**Scope correction from filing:** the pre-push audit gate
(`agents/git/lib/hooks.sh:910`, T-862) runs a **fast section subset**, not a
full audit — production pushes are not blocked by full-run *runtime*, only by
occasional brief lock contention that self-resolves on retry. The severity is
lower than the original description implied; the primary blocked consumer is
`fw audit clean` as a task AC (T-1719 A6/A6b), not the push path.

**Root cause disentangled (2026-08-23):** BOTH candidates were real,
independently. (1) `AUDIT_TIMEOUT` was too short for a full run regardless of
contention — fixed by giving full runs (SECTIONS empty) their own larger
default (`FW_AUDIT_FULL_TIMEOUT`, 3000s vs the section-scoped 600s;
`agents/audit/audit.sh:341-355`, pinned by
`tests/unit/t3070_audit_full_run_timeout.bats`). (2) The schedule collision
was real AND wider than filed: `full-daily` (`0 8 * * *`) exactly collided
with `traceability-hourly` (`0 * * * *`) at 8:00 daily, and three MORE
undetected collisions existed on the same shared flock —
`observations-6h`/`oe-daily`/`oe-weekly` each also fired at `:00`, colliding
with `traceability-hourly`'s every-hour `:00` trigger. `structural-30m` had
already been offset to `5,35` for the same class before this task started.
Fixed by offsetting all four remaining `:00`-aligned jobs
(`.context/cron-registry.yaml`); pinned generically (not just the four known
pairs) by `tests/lint/audit-lock-cron-schedule-collision.bats`, which expands
every active `fw audit`-invoking job's 5 cron fields and fails on ANY pair
that can fire the same absolute minute.

**Structural finding beyond the filed scope (OBS-249):** deploying the
schedule fix surfaced a second, more serious bug — `agents/audit/audit.sh
schedule install` was an independent, hardcoded-template generator for the
SAME git-tracked crontab source file that `fw cron generate`/`fw cron
install` (T-1112/T-1114) already own, and it silently reverted this task's
registry-driven fixes minutes after they were correctly generated (`fw cron
generate`'s own success message even recommends the broken command). Fixed
by making `audit.sh schedule install` delegate to `fw cron install` when a
registry exists (`agents/audit/audit.sh` install case); the hardcoded
template now only serves pre-T-448 consumer projects with no registry.
Pinned by `tests/unit/t3070_audit_schedule_install_delegates_to_registry.bats`.
See OBS-249 for the full RCA.

**Diagnostic run in progress (2026-08-17T14:09:15Z, superseded — see live
ground-truth run below):** launched a fully
detached `fw audit` (`nohup ... & disown`, no external timeout, lock
confirmed free at start) to get ground-truth timing before choosing a fix
shape — PID 4115033, output at
`.context/working/t1719-full-audit-diagnostic.log`. Before repeating this
experiment, check whether that log reached `=== SUMMARY ===` and how long it
took (`grep -c '^=== ' <log>` against the 27 section headers, or just diff
mtime vs the `AUDIT REPORT` header timestamp).

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [ ] Ground truth established: actual wall-clock time for an uncontended,
  un-killed full `fw audit` run to reach `=== SUMMARY ===` (or confirmation it
  never does within a generous bound, e.g. 2400s)
- [x] Root cause disentangled: confirm/refute whether `AUDIT_TIMEOUT=600s` alone
  (independent of lock contention) is insufficient for a full run on this corpus
- [x] Fix implemented for at least one of: (a) cron schedule collision at
  minute 0 in `.context/cron-registry.yaml` / `agents/audit/audit.sh` crontab
  block, (b) distinct lock or larger timeout budget for full vs section-scoped
  runs
- [ ] `fw audit` (full run, no `--section`) completes and reaches
  `=== SUMMARY ===` without external or internal timeout kill, verified live
- [ ] Regression coverage for the fix; `fw doctor` clean re: cron registry sync
  if `.context/cron-registry.yaml` is touched (CLAUDE.md cron-touching
  verification rule)

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

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.
#
# Toolchain hint (L-291): if you edited *.vbproj/*.csproj/*.xaml add `dotnet build`;
# *.go → `go build ./...`; Cargo.toml → `cargo check`; tsconfig.json → `tsc --noEmit`;
# pom.xml → `mvn -q compile`. P-011 runs only what you write — broken builds slip
# past otherwise (origin: 003-NTB-ATC-Plugin T-077, broken WPF DLL on master 5 days).
#
# ── Pipefail/SIGPIPE: grepping a command's output (L-387, T-2090, T-2743, T-2738) ──
#
# THE DEFAULT — redirect to a file, then grep the file:
#     cmd > /tmp/.out 2>&1 && grep -q "PATTERN" /tmp/.out
#     curl -sf "$(bin/fw watchtower url)/page" -o /tmp/.out && grep -q "PAT" /tmp/.out
# Correct at any output size, and `&&` keeps the PRODUCING command's exit code in
# the verdict. Reach for this first; the alternative below is the special case.
#
# Why not `cmd | grep -q PAT` (L-387): P-011 runs each line under `set -eo
# pipefail`. When grep matches it exits and closes stdin while cmd is still
# writing, cmd takes SIGPIPE, the pipeline exits 141 — verification "fails" with
# the pattern present. Captured 4× (T-1716, T-1838, T-1862, T-1863).
#
# THE EXCEPTION — capture first, grep the capture:
#     out=$(cmd 2>&1); echo "$out" | grep -q "PATTERN"
# Valid ONLY while "$out" fits the 65536-byte pipe buffer, and it is on you to
# know that it does. Above that the form inverts and becomes the very failure
# L-387 describes: echo blocks on the full pipe, grep -q exits, echo takes
# SIGPIPE, rc=141 (T-2743 — measured on a 146,366-byte Watchtower page, 3/3 runs,
# deterministic not racy; rendered routes run 50-200KB, so anything that curls a
# page is over the line). It also discards cmd's exit code, so a 404 yields an
# empty capture that grep merely fails to match rather than a failed line.
# If you do use it: single pipe only, no intermediate tail/awk/sed stage between
# capture and grep (T-2090) — the middle stage is what `grep -q` slams its stdin
# on, and grep scans the whole captured string anyway, so the `tail -3` was
# cosmetic. `echo "$out" | grep -q PAT`, nothing between.
#
# TEST RUNNERS need a guard either way (T-2738). `set -e` is suppressed inside the
# `if` condition the gate runs each line in, so in `cmd1; cmd2` only cmd2 is the
# verdict — and the pass marker you grep for survives a partial failure: a suite
# printing "3 failed, 9 passed" satisfies `grep -q "9 passed"`, and generalising
# to `grep -qE "[0-9]+ passed"` matches the same output. Keep the exit code:
#     python3 -m pytest <file> -q > /tmp/.out 2>&1 && grep -q passed /tmp/.out
# or add the guard the exit code used to supply:
#     out=$(python3 -m pytest <file> -q 2>&1); echo "$out" | grep -q passed && ! echo "$out" | grep -q failed
#     out=$(bats <file> 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
# The close gate refuses the unguarded form. Bypass: FW_ALLOW_UNJUDGED_TEST_RUN=1.
#
# REHEARSING A LINE BY HAND DOES NOT REHEARSE THE GATE (T-2743). Your interactive
# shell has no `set -eo pipefail`. A line has returned 0 by hand and 141 under
# P-011, from the same directory, the same second. To rehearse for real:
#     bash -c 'set -eo pipefail; <your verification line>'
#
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

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

**Symptom:** A full (unscoped) `fw audit` run either exits immediately with 75
("another audit already running") or, once it acquires the lock, gets killed
mid-run before reaching `=== SUMMARY ===`, making `fw audit clean` unusable
as a task Acceptance Criterion.

**Root cause (two independent, compounding causes):**
1. `AUDIT_TIMEOUT` defaulted to 600s for every run regardless of scope. A full
   run walks ~28 sections including whole-tree scans and was measured only
   43% through (12/28 sections) at the 590s mark — 600s was simply too short
   for the unscoped case, independent of contention.
2. Five cron jobs that all invoke `fw audit` (full or `--section`-scoped)
   share ONE internal flock (`.context/locks/audit.lock`,
   `agents/audit/audit.sh`) regardless of their own distinct per-job
   `/var/lock/agentic-cron-*.lock`. Five of those jobs were scheduled at
   minute `:00` (`full-daily`, `traceability-hourly`, `observations-6h`,
   `oe-daily`, `oe-weekly`) — an exact collision, not intermittent bad luck —
   so a full run frequently lost the race to acquire the lock at all.

**Why structurally allowed:** Nothing compared a job's declared cron schedule
against its lock-sharing peers — `.context/cron-registry.yaml` had no
collision check, only a per-field generator. The timeout was a single
constant with no scope-awareness. Deploying the schedule fix then surfaced a
THIRD, deeper structural gap (OBS-249): `agents/audit/audit.sh schedule
install` was a second, independent generator for the same git-tracked
crontab file that `fw cron generate`/`fw cron install` (T-1112/T-1114) were
built to own exclusively — T-1114's "collapse into one command" only added
the new correct command, it never redirected the old one, so the legacy path
kept silently reverting registry-driven fixes. This went undetected because
`fw cron generate`'s own success message recommended the broken command.

**Prevention:**
- `tests/unit/t3070_audit_full_run_timeout.bats` — pins the scope-aware
  timeout default (full > 600s, section-scoped stays 600s).
- `tests/lint/audit-lock-cron-schedule-collision.bats` — generic collision
  detector over the real registry: expands every active `fw audit`-invoking
  job's 5 cron fields and fails on ANY pair (not just the ones observed) that
  can fire in the same absolute minute.
- `tests/unit/t3070_audit_schedule_install_delegates_to_registry.bats` —
  pins that the legacy entry point now delegates to the registry-driven
  generator instead of maintaining a second copy.
- OBS-249 registered in `.context/concerns.yaml` for the dual-writer class.

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

### 2026-08-17T13:20:32Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3070-full-fw-audit-cannot-complete-single-pro.md
- **Context:** Initial task creation

### 2026-08-22T17:01:22Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
