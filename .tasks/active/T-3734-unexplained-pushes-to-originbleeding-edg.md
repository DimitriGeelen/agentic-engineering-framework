---
id: T-3734
name: "Unexplained pushes to origin/bleeding-edge at 16:11 and 16:17 (2026-10-02)
  while the pre-push unit ratchet refused every agent push: find the pusher and whether
  the ratchet was skipped"
description: >
  origin/bleeding-edge reflog: update by push at 16:11 (23540f871) and 16:17 (ca2c1c7d9).
  The session's own pushes were refused before (26 new reds) and after (47 new reds).
  No handover then; no bypass-log entry. Hypothesis to test first: a push ran while
  agents/audit/unit-suite.sh was rewriting .context/audits/unit-suite/LATEST.yaml,
  so the ratchet read an in-progress or undetermined report and graded WARN. Check
  pre-push audit logs, unit-suite runs.log timing, process accounting, and every caller
  of git push or fw push (handover, mirror, close paths, workers).

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [bug, gates, push, security]
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
created: 2026-10-02T16:37:13Z
last_update: 2026-10-21T07:11:54Z
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
  - ts: '2026-10-02T16:45:25Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=269,acs=4)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-10-02T16:45:44Z'
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

# T-3734: Unexplained pushes to origin/bleeding-edge at 16:11 and 16:17 (2026-10-02) while the pre-push unit ratchet refused every agent push: find the pusher and whether the ratchet was skipped

## Context

Findings so far (parent session, 2026-10-02 ~17:50Z), times UTC:
- origin/bleeding-edge reflog "update by push": 14:11Z (to 23540f871), 14:17Z (to ca2c1c7d9).
- The parent session's own pushes, from its transcript: 11:43Z, 11:49Z, 13:25Z, all refused by the unit ratchet. None at 14:1x.
- No dispatch worker (w-t-36*, w-t-37*) issued a git push or handover tool call.
- DISPROVED: "the ratchet read a half-written report". unit-suite.sh writes LATEST.yaml atomically at the end (tmp + rename), so at 14:11Z the gate read the 01:03Z nightly report (26 new reds), which should refuse.
- Mirror sync (cron, 15 min) only syncs the github remote (.mirror-sync.log).
- No entry in .gate-bypass-log.yaml at 14:0x-14:2x.
STRONG LEAD (21:50 local): later "update by push" reflog entries are at 18:36:52, 19:50:35 and 21:47:09 (+02:00). Each is a minute or a few after a quarter-hour mark, matching the 15-min `fw mirror sync` cron (/etc/cron.d/agentic-audit-999-*, "Mirror cascade auto-recovery"). The 21:47 push carried 1caf5450a minutes after the session committed it and while the session's own pushes were being refused. Check whether mirror sync pushes local bleeding-edge to origin, and with which pre-push verdict (cron environment, no CLAUDE_CODE_SESSION_ID, possibly a different audit scope).
Remaining candidates to check: the continuous-run Stop hook (agents/context/stop-driver.sh; audit warned it is "cycling on a stale terminate reason") triggering a handover push; another Claude session working in this repo; the pre-push audit scope used by handover pushes; /var/log or shell history for git push at 14:11Z.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [ ] Pusher of the 2026-10-02 14:11Z/14:17Z origin/bleeding-edge updates identified from evidence on disk (reflog, cron logs, push audit logs), recorded under ## RCA with file:line — NOT MET: every in-repo pusher and every agent transcript was eliminated, and no retained record names the actor (see ## RCA). Needs an operator decision (## Recommendation).
- [x] Whether the pre-push unit ratchet ran for those pushes (and what it graded) is established and recorded — timing shows a full pre-push run (~6-10 min between HEAD-at-push-start and the reflog entry) for all five 2026-10-02 pushes; the verdict itself is not retained anywhere (## RCA)
- [x] Defect checked at HEAD: the ratchet refuses new/expired reds, incomplete runs and contention at HEAD (t3621 17/17, t3794 12/12, t3297 11/11, 0 skips); not-reproducible evidence recorded

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
# ── Mutable-corpus anchor (T-3326) ────────────────────────────────────────────
# Do NOT anchor a verification line (or a unit test it runs) to MUTABLE corpus
# state — an exact live count, or a grep of live `fw audit`/`fw doctor` output
# for a specific corpus entity (a named arc, a task count, a census number).
# The corpus moves under the check, and the line rots: it goes red (or vanishes
# its pattern) for reasons unrelated to the code under test, blocking closes.
# Pin the INVARIANT (categories sum, count > 0, property holds) or run the code
# against a COMMITTED FIXTURE — never the live count or a live-audit line.
# Origin: T-2969 line grepping live audit for one arc's status; T-2871's census
# test pinning exact live counts (56→74 files) — both blocked closes (OBS-377).
#
# ── Pipefail/SIGPIPE: grepping a command's output (L-387, T-2090, T-2743, T-2738) ──
#
# THE DEFAULT — redirect to a file, then grep the file:
#     cmd > /tmp/.out 2>&1 && grep -q "PATTERN" /tmp/.out
#     curl -sf "$(bin/fw watchtower url)/page" -o /tmp/.out && grep -q "PAT" /tmp/.out
# Correct at any output size, and `&&` keeps the PRODUCING command's exit code in
# the verdict. Reach for this first; the alternative below is the special case.
#
# Why not `cmd | grep -q PAT` (L-387): P-011 runs each line with PIPEFAIL LIVE
# (errexit is not — see below). When grep matches it exits and closes stdin while cmd is still
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
# ── A SKIPPED BATS TEST REPORTS `ok` (T-3217) ─────────────────────────────────
#
# `! grep -q "^not ok"` does NOT mean the suite ran. Bats emits a skip as
#     ok 6 <name> # skip <reason>
# which is not a `not ok`, so the gate passes and the report says ok while the
# thing the test covers was measured NOWHERE. Origin: T-3213 guarded a test with
# `[ "$(id -u)" -eq 0 ] && skip` — the suite runs as root here and in CI, so it
# skipped on every run that mattered, for as long as it existed.
#
# Add a skip clause to any bats verification line. `# skip` is the marker bats
# writes; counting it is the whole check:
#     timeout 300 bats <file> > /tmp/.out 2>&1 && ! grep -q "^not ok" /tmp/.out
#     test "$(grep -c '# skip' /tmp/.out)" -eq 0
# Two lines, because they answer different questions — "did anything fail" and
# "did everything run". If some skips are legitimate on your host (an optional
# dependency is genuinely absent), assert the COUNT you expect rather than zero,
# and say in the task why that number is right.
#
# Corpus-wide, the same check runs from `bin/fw test lint`
# (tools/bats-silent-skip-lint.py): static mode flags guards that are fixed for
# a deployment rather than probing an optional dependency, and `--tap FILE`
# reports the skips a real run actually fired.
#
# REHEARSING A LINE BY HAND DOES NOT REHEARSE THE GATE (T-2743). Your interactive
# shell has no pipefail. A line has returned 0 by hand and 141 under P-011, from
# the same directory, the same second. To rehearse for real:
#     bash -c 'set -o pipefail; <your verification line>'
#
# NOTE THE MISSING `-e` — it is not a typo (T-3203). This file used to prescribe
# `set -eo pipefail` here, which is NOT the gate: it adds errexit the gate does
# not have, so it FAILS lines the gate PASSES. Measured, 10 lines, 3 diverged:
#     line                            gate    set -eo (old)   set -o (this)
#     false; true                     PASS    FAIL  wrong     PASS  ok
#     cd /nonexistent; echo ok        PASS    FAIL  wrong     PASS  ok
#     grep -q MISS file; true         PASS    FAIL  wrong     PASS  ok
# The divergence is one-directional and that is the trap: the old rehearsal only
# ever fails lines the gate accepts, so it produces false REDS, and an author
# who "fixes" a line to satisfy it is fixing something that was never broken —
# while the line that actually is broken (`cmd1; cmd2` where cmd1 fails) passes
# both. Re-derive rather than trust this table — it is pinned, not asserted:
#     bats tests/unit/t3203_p011_gate_semantics.bats
#
# ── `cmd1; cmd2` IS JUDGED ONLY ON cmd2 (T-3203) ──────────────────────────────
#
# The gate runs each line as the CONDITION of an `if` (update-task.sh:1215), and
# POSIX suppresses errexit for a compound command in an `if` condition — through
# the subshell. So pipefail applies and `set -e` does not, and in a sequence only
# the LAST command's status reaches the verdict. `cd /nonexistent; echo ok` passes.
# 2,644 of 10,997 verification lines in this corpus contain `;` (re-derive with
# the query in docs/reports/T-3203-p011-gate-semantics.md).
#
# SAFE SHAPES — both verified biting, each against a passing control:
#   A. one command whose own status is the verdict (prefer this):
#        out=$(cmd 2>&1); echo "$out" | grep -q PAT && ! echo "$out" | grep -q BAD
#      the leading assignments are setup; the trailing `&&` chain is the verdict.
#   B. an explicit sub-shell, whose errexit the outer `if` cannot reach into:
#        bash -c 'set -eo pipefail; cmd1; cmd2'
#      use when you genuinely need every command in the sequence to count.
#
# The rule of thumb: put the assertion LAST, and make sure it is an assertion.
#
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

# T-3734: the pre-push ratchet refuses at HEAD (new/expired reds, incomplete run, lock contention)
timeout 900 bats tests/unit/t3621_unit_suite_ratchet.bats > /tmp/.t3734a 2>&1 && ! grep -q "^not ok" /tmp/.t3734a
test "$(grep -c '# skip' /tmp/.t3734a)" -eq 0
timeout 900 bats tests/unit/t3794_unit_suite_incomplete_prepush.bats > /tmp/.t3734b 2>&1 && ! grep -q "^not ok" /tmp/.t3734b
test "$(grep -c '# skip' /tmp/.t3734b)" -eq 0
timeout 900 bats tests/unit/t3297_prepush_lock_wait.bats > /tmp/.t3734c 2>&1 && ! grep -q "^not ok" /tmp/.t3734c
test "$(grep -c '# skip' /tmp/.t3734c)" -eq 0
# mirror sync never pushes to origin (it iterates every remote except origin)
grep -q "grep -vx 'origin'" lib/mirror.sh

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

**Symptom:** origin/bleeding-edge advanced "by push" from this checkout at 2026-10-02 14:11:27Z (23540f871) and 14:17:55Z (ca2c1c7d9), and later at 16:36:52Z, 17:50:35Z and 19:47:09Z. Over the same period every push the parent session made was refused by the pre-push unit ratchet (T-3621).

**Investigation (worker w3734, 2026-10-21), every lead and its result:**
- *Pushed SHA lags HEAD by one pre-push run.* 23540f871 was HEAD 13:41:59Z–14:05:38Z and reached origin at 14:11:27Z. ca2c1c7d9 was HEAD 14:10:19Z–14:12:19Z and reached origin at 14:17:55Z. 08c61ee19 was HEAD 17:39:58Z–17:50:02Z and reached origin at 17:50:35Z. Each push is therefore a plain push of the current branch that spent ~6–10 min in the pre-push hook, which is the structure audit's duration (the session's own refused pushes took 6–7 min, e.g. 11:43→11:49Z). Pushes 1 and 2 ran back to back. The hook ran its audit, so this was not `--no-verify`, and that audit let the push through.
- *Mirror sync (cron, 15 min):* ruled out. `lib/mirror.sh` iterates `git remote | grep -vx 'origin'` and pushes only to github (the `.mirror-sync.log` 14:15:03Z row reads github in-sync).
- *Agent pushes:* ruled out. A scan of every Claude transcript on the host with activity 13:55Z–14:18Z found no push into this repo. The parent session made no tool call 13:42Z–14:03Z, and its pushes at 11:43, 11:49, 13:25 and 14:26 were all refused. The only other push in the window (055-cockpit, 14:15:01Z) went to its own repo.
- *Close path / episodic / BVP / learning bus:* ruled out. `update-task.sh` backgrounds only the BVP estimator (`:2297`), `episodic-gen/T-3725.log` shows no git activity, and the learning bus posts to TermLink only.
- *Watchtower inception decide:* ruled out. The T-3723 GO was recorded at 17:28:41Z, and `web/` contains no push.
- *Release cron:* ruled out. No tag was cut 2026-10-01..03, and the job is paused (T-4364).
- *Checkpoint detached push retry* (`agents/context/checkpoint.sh:306`, T-4004): postdates 2026-10-02 and has no log.
- *Handover --commit, fw sync, fw push, integrate:* no invocation in any transcript in the window. `fw integrate` would also leave a worktree branch, and the 2026-10-02 reflogs show none.
- *Unit-suite runs on the live checkout:* not supported. Pushes 1–4 do fall inside full-suite runs (13:32–14:26Z, 16:27–17:17Z, 17:41–18:35Z), but over 2026-09-25..10-21, 26 of 285 pushes fall inside one of 68 runs. That is exactly the share expected by chance, since runs cover ~9% of the time. No test was found that pushes from the live checkout or writes the live LATEST.yaml/baseline.yaml (the ratchet tests pass fixtures via `FW_UNIT_SUITE_REPORT`/`FW_UNIT_SUITE_BASELINE`).
- *Half-written report:* stays disproved. `agents/audit/unit-suite.sh:556-568` writes LATEST.yaml only at the end of a run.

**Root cause:** not determinable from retained evidence. Two facts survive. First, whatever pushed ran `git push` of the current branch through a full pre-push audit that passed. Second, nothing on this host records *who* pushed or *what the hook decided*. The pre-push hook (`agents/git/lib/hooks.sh` → `.git/hooks/pre-push`) logs bypasses to `.gate-bypass-log.yaml` but writes no row for an ordinary allow or refuse. `full-audit-timing.yaml` keeps only the latest run per section. The local reflog carries no actor. The remaining unexamined actor is a human terminal (shell history is outside this project's boundary) or an OneDev-side record (server logs).

**Why structurally allowed:** a push is an outward-facing act, and the gate that governs it leaves no attribution ledger. A refused push is visible only in the pusher's own terminal, and an allowed push only as an anonymous reflog line. So "the ratchet refused every agent push, yet origin moved" cannot be reconciled after the fact. That gap is the reason this task stayed open for 19 days.

**At HEAD:** the gate itself is sound. The ratchet FAILs on new or expired reds and on incomplete runs, and BLOCKs on lock contention (t3621 17/17, t3794 12/12, t3297 11/11, 0 skips). No code defect was reproduced, so no fix or regression test was written.

**Prevention:** proposed, not built. It needs an operator decision; see ## Recommendation.

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

**Recommendation:** GO on option 1: close this investigation as unattributable and file a build task for a pre-push attribution ledger.
**Rationale:** No retained record names the 2026-10-02 pusher, and the investigation eliminated every in-repo push path (## RCA). The ratchet refuses correctly at HEAD (40/40 tests, 0 skips). What can still be fixed is the reason this question was unanswerable: the push gate keeps no record of who pushed or what it decided. The ledger would be a new behaviour in a hook every consumer receives via `fw upgrade`, so the decision is the operator's and not this worker's.
**Options:**
1. **Pre-push attribution ledger (recommended).** The hook appends one JSONL row per run to `.context/working/push-ledger.jsonl`: ts, remote, refs (local sha → remote sha), audit exit and verdict (allow / refuse / contention / bypass), `CLAUDE_CODE_SESSION_ID`, `$PPID` and the parent command line, TTY yes/no, and `FW_UNATTENDED`. A bats test would pin one row per allow and per refuse. The next "who pushed" becomes a single grep.
2. **Close as not reproducible and do nothing else.** Cheapest option, but the same question stays unanswerable next time.
3. **Ask OneDev.** The operator checks the OneDev audit log or access log for 2026-10-02 14:04–14:18Z to see which credential pushed. Only the operator can do this, and it may settle the original question. It combines with option 1.
**Evidence:**
- reflog lag analysis: each pushed SHA was HEAD ~6–10 min before its push landed, which matches a full pre-push audit
- 0 pushes into this repo in any Claude transcript on the host 13:55–14:18Z; mirror sync is github-only (`lib/mirror.sh`, `grep -vx 'origin'`)
- in-run share 26/285 matches chance (~9% time coverage), so the unit-suite correlation is not causal
- t3621 17/17, t3794 12/12, t3297 11/11 at HEAD

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

### 2026-10-02T16:37:13Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3734-unexplained-pushes-to-originbleeding-edg.md
- **Context:** Initial task creation

### 2026-10-21T07:11:54Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
