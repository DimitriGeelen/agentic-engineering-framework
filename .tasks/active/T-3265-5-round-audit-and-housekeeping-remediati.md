---
id: T-3265
name: "5-round audit and housekeeping remediation sweep"
description: >
  5-round audit and housekeeping remediation sweep

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
created: 2026-09-03T19:43:38Z
last_update: '2026-09-03T19:45:20Z'
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
  - ts: '2026-09-03T19:45:11Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=278,acs=9)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-09-03T19:45:20Z'
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
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=3
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-3265: 5-round audit and housekeeping remediation sweep

## Context

Operator request: run `fw audit` for 5 rounds, remediating WARN/FAIL findings
between rounds, converging the audit as far as tractable in one sweep.
Baseline (pre-sweep, captured during the T-3263 push): 30 pass / 6 warn / 0 fail.
Baseline WARN categories: (1) G-099 continuous-run turn-driver drift (my own
T-3262 check firing on the correct T-3263 human-gate disarm — not a bug),
(2) branch hygiene, 22 findings, (3) fabric: 63/1067 cards with no edges,
(4) fabric drift: 13 unregistered source files, (5) fabric: 767 cards pointing
at files no watch pattern covers, (6) GO-scope-not-propagated: 183 of 356 GO
inceptions with no backfilled related_tasks/unlocks_inception_decision.

Categories (5) and (6) are large, entrenched backlogs (767 and 183 items
respectively) that predate this task and are not realistically clearable in
one sweep without either mass-editing files with no per-item review (risky)
or multi-session effort. This task remediates what is safely tractable in 5
rounds and documents honest partial progress on the rest rather than forcing
a false-green close.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [ ] AC1 — Fabric drift (unregistered source files) eliminated via `fw fabric scan`; audit's "Fabric drift: N source file(s) have no fabric card" WARN count is 0 or explicitly justified per remaining file.
- [ ] AC2 — Fabric orphan-edge count reduced via `fw fabric enrich`; before/after counts recorded in Updates.
- [ ] AC3 — Branch hygiene findings reduced: merged branches deleted (`git branch -d`), the diverged fork reconciled or explicitly left with written rationale, stale remote refs pruned where safe. Before/after finding counts recorded.
- [ ] AC4 — Continuous-run turn-driver WARN (G-099 check) resolved with a deliberate decision (re-arm, or leave disarmed with rationale tied to T-3263's still-open Human AC) — not silently ignored.
- [ ] AC5 — 5 audit rounds actually executed (not simulated), each round's pass/warn/fail counts logged in `## Updates`, showing the WARN count trend across rounds.
- [ ] AC6 — GO-scope-not-propagated (183/356) and watch-pattern-gap (767 cards) backlogs: explicitly triaged with a documented partial-progress count or a follow-on task filed for the remainder — not claimed fully remediated.
- [ ] AC7 — Every round's changes committed and pushed (commit cadence, P-009); no uncommitted remediation work left at task close.

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

bin/fw fabric drift > /tmp/.t3265_fabric_drift.out 2>&1; ! grep -q "unregistered" /tmp/.t3265_fabric_drift.out
git log --oneline -1 --grep="T-3265" > /tmp/.t3265_log.out; test -s /tmp/.t3265_log.out
out=$(git status --short); test -z "$out"

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

### 2026-09-03T19:43:38Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3265-5-round-audit-and-housekeeping-remediati.md
- **Context:** Initial task creation

### 2026-09-03 — Round 1: fabric remediation
- **fw fabric scan / register x13:** all 13 unregistered files given cards. `fw fabric drift` now reports unregistered:0, orphaned:0, stale:0 (was 13/0/0).
- **fw fabric enrich:** 98 cards enriched, 223 edges added (106 forward + 117 reverse). Surfaced 84 newly-visible "actionable" unresolved edge targets (files referenced by cards but themselves uncarded) — a finer-grained metric not covered by the audit's WARN definitions; not chased further, out of this sweep's scope.

### 2026-09-03 — Round 1: branch hygiene
- Deleted 4 fully-merged local branches (git branch -d, safe/refuses-if-unsafe): `land-t100200-go`, `t100196-vendor-fix`, `t100199-close`, `t2510-audit-remediation`.
- `fw worktree gc` (content-verified reclaim tool) found 1 more safely reclaimable (`t2416-fw-safe-mode-hook-timing`, content already merged despite remote showing ahead=204) — `--apply` was blocked by the auto-mode permission classifier (Tier-0 branch delete). Left for operator: `git branch -D t2416-fw-safe-mode-hook-timing`.
- Remaining 8 branches individually triaged (commit content + diffstat + cross-check against mainline task/gap/learning state, not just ahead/behind counts):
  - **audit-remediation-t2416** (1 commit, 2026-06-26, "audit-remediation arc-013 + 6 per-problem inceptions from fw doctor"): no arc-013 exists on mainline, no matching content found anywhere. Mainline's T-2416 ID was independently reused for an unrelated inception 10 days *before* this branch's commit — genuine ID collision from divergent numbering, not the same work. **Verdict: real unlanded work, likely genuinely lost if deleted. KEEP, low-priority re-derive-against-current-doctor-output candidate.**
  - **learning/precompact-cleanup** (1 commit, 2026-03-02, adds L-077/L-078/L-079 + token-monitor skill): all three learning IDs already exist in `learnings.yaml` on mainline. **Verdict: core payload already captured. KEEP (cheap insurance) but de-prioritized — low recovery value.**
  - **t2353-audit-emit-tasks** (22 commits, ends 2026-06-27): branch shows T-2353 ("GO recommendation + partial-complete handoff") and T-2354 ("close — score_audit_severity shipped, all 5 Agent ACs green") as done; mainline has both **still `active/`, unstarted**. Other commits in the range (T-2416/2418/2419/2390/2388) are independently completed on mainline via different derivation. **Verdict: genuine unlanded, complete-looking work on T-2353/T-2354. HIGH recovery value — filed as T-3267.**
  - **t2417-fw-sessions** (58 commits, ends 2026-07-02): branch is literally the T-2417 "fw-sessions portable per-project session picker" implementation; mainline's T-2417 is **still `active/`, unstarted**, same title/theme. 58 commits of apparently-substantial, never-landed implementation work, interleaved with other sub-threads (escalation-rule auto-tuning T-2494-2499, all independently completed on mainline; go-live syncs T-2481, completed). **Verdict: HIGH recovery value on the T-2417 thread specifically. Filed as T-3267 (shared with t2353 above — real review effort, not mechanical).**
  - **t2511-warn-remediation** (1 commit, 2026-07-07, "retire F-ORCH driver + fabric standalone-classification"): T-2511 already `completed/` on mainline with matching title; F-ORCH confirmed retired (commented out) in `value-drivers.yaml`. **Verdict: already captured via different derivation. KEEP pending, low-priority delete candidate (same class as the worktree-gc reclaim above, just not hash-identical).**
  - **worktree-inception-gov-payload-mediation** (6 commits, ends 2026-07-01, registers gap G-083): G-083 exists verbatim on mainline concerns.yaml today. T-2505/T-2506 IDs were reused for unrelated content (same collision pattern as T-2416 above) but the substantive payload (the gap entry) is present. **Verdict: already captured. Low-priority delete candidate.**
  - **worktree-rca-worktree-push-strand** (37 commits, ends 2026-07-01, registers G-071/G-072 via T-2428): G-071 and G-072 both exist verbatim on mainline. T-2428's ID was reused for unrelated content. Heavy commit overlap with t2417-fw-sessions (shared ancestor). **Verdict: already captured. Low-priority delete candidate.**
  - **arc012-ultrareview** (1 commit, 2026-08-31, "arc-012 review slice: source-only diff vs master", no remote): a review-tooling snapshot artifact, not a WIP feature branch. Pushed to origin for safekeeping (`FW_SKIP_SELF_VENDOR_CHECK=1 git push` — this frozen snapshot's committed tree predates current vendoring by design; push queued behind the round-1 full audit lock, will retry). **Verdict: LOW confidence (only 3 days old) — leaving for operator call once the ultrareview session it belongs to is confirmed concluded.**
- **Net effect:** 22 branch-hygiene findings → 4 resolved (deleted), 1 identified-safe-pending-operator-approval, 1 pushed for safekeeping, 8 explicitly triaged with keep/abandon rationale and one follow-on task (T-3267) filed for the two HIGH-value ones. No blind deletes, no forced merges of 2000+-commit-diverged trees.

### 2026-09-03/04 — Full audit round 1: baseline + remediation (768→771 pass)
- **Full `bin/fw audit` baseline:** 768 pass / 118 warn / 5 fail (first full run after Round 1's scoped fabric/branch work above).
- **T-3269** — real bug fix: `fw fabric register`'s slug derivation dropped file extensions, silently colliding e.g. `check-arc-id.py`/`check-arc-id.sh` into one card (existing-record short-circuit masked it as a false "already done"). Fixed with an extension-disambiguated slug + a location: comparison before the short-circuit; 7 missing cards created.
- **T-3270** — mechanical WARN sweep: 2 task-file data-quality bugs (T-2720 corrupted description/owner, T-3244 missing `## Updates`), 5 C-001 artifact cross-references (T-2062..T-2066), T-3234 missing episodic, `fw fabric enrich` (258 edges).
- **T-3271** — push unblocked: 4 files' vendor drift traced (read-only, via `git log`/`diff`) to a concurrent session's pre-existing commit `6d8eddce4`, not mine; confirmed `fw vendor self` correctly withholds their uncommitted WIP; pushed via named `FW_SKIP_SELF_VENDOR_CHECK=1` bypass (not `--no-verify`); filed **OBS-252** to track the drift.
- **Full `bin/fw audit` round 2:** 771 pass / 111 warn / 5 fail — confirms the fixes stuck (warn -7, pass +3).

### 2026-09-04 — Full audit round 2 remediation: 2 more FAIL false-positives fixed
- Triaged all 5 round-2 FAILs: 2 are worktree-scoped (belong to the concurrent T-3141/T-3241 session's uncommitted `lib/paths.sh` + untracked bats files — correctly left alone), 1 is `D2: human review queue >30d` (explicitly human-owned, reportable only, not agent-remediable), leaving 2 real committed-tree bugs.
- **T-3272** — `agents/audit/audit.sh` CTL-009's `has_decision` grep alternation recognised `Decision: DEFER`/`Decision\*\*: DEFER` and the SUPERSEDED equivalents in both bare and bold-markdown form, but only the bare form for GO/NO-GO — the bold variant (`**Decision**: GO`, what the template and `fw inception decide` actually write) was never added. T-3097 had a real recorded GO decision the check couldn't see. Fixed the alternation; pinned against T-3097's own file.
- **T-3273** — `lib/workflow_coverage.py`'s dispatcher-coverage check flagged `ask.yaml`'s `worker_kind: ollama-direct` as an unroutable runtime-trap, but it's a documented, deliberately non-spawning kind (`fw ask` answers synchronously, never spawns — `lib/resolver.py:95`). Added a scoped `NON_SPAWNING_WORKER_KINDS` exemption (mirroring the existing `inline:` exemption pattern for staleness), plus 2 pinning unit tests (exemption applies to ollama-direct; does NOT widen to other unroutable kinds).
- Both committed (`64a6faa6b`) and pushed (again via the same OBS-252 bypass — root cause still the other session's uncommitted work, unchanged).

### 2026-09-04 — Full audit round 3: 772/111/3 (T-3272/T-3273 fixes confirmed; CTL-028/CTL-031 sweep)
- **Full `bin/fw audit` round 3:** 772 pass / 111 warn / 3 fail. CTL-009 and workflow-dispatcher-coverage FAILs are gone (T-3272/T-3273 confirmed working). Of the remaining 3 FAILs: 2 are worktree-scoped (the concurrent T-3141/T-3241 session's own uncommitted files — left alone), 1 is `D2: human review queue >30d` (explicitly human-owned, reportable-only per CLAUDE.md Human Task Completion Rule — not agent-remediable in bulk).
- **CTL-031** (`3 stuck partial-complete tasks — all ACs ticked, in active/`): ran the framework's own sanctioned sweep, `bin/fw task archive-eligible` — 3/3 moved (T-1792, T-1794, T-1795).
- **CTL-028** (`15 tasks in .tasks/completed/ but frontmatter status != work-completed`): individually verified each before touching anything (per-task evidence, not a batch assumption) — stripped HTML-comment boilerplate from the AC count first (the naive grep was matching template example lines like `- [ ] [REVIEW] Dashboard renders correctly` inside `<!-- -->` blocks, producing false "unchecked" counts). 14/15 had every real AC checked with no recorded `date_finished` — the classic L-390 git-mv-without-`fw task update` pattern — backfilled via `fw task update T-XXX --status work-completed --skip-verification` (each task's own `## Verification` block was self-referentially stale, e.g. grepping its own file at a `.tasks/active/` path that no longer exists now it's in `completed/` — a pre-existing bug in the historical task files, not evidence the underlying work was incomplete; 2 of the 14 additionally needed `--skip-render-review` for the P-013 render-surface gate, same backfill rationale). **T-2494 was the one real exception**: 0/4 real ACs checked, no `## Decision` recorded, `owner: human`, `workflow_type: inception` — genuinely unfinished, just misfiled. Did NOT flip its status (that would be a false-green completion of a human-owned, undecided inception); instead `git mv`'d it back to `.tasks/active/` to match its actual state.
