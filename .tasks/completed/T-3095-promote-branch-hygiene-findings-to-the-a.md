---
id: T-3095
name: "Promote branch-hygiene findings to the audit cron (T-3093 slice 2)"
description: >
  Promote branch-hygiene findings to the audit cron (T-3093 slice 2)

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [C-004]
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
created: 2026-08-20T00:56:39Z
last_update: 2026-08-20T07:01:49Z
date_finished: 2026-08-20T07:01:49Z
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
  - ts: '2026-08-20T01:00:08Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=202,acs=4)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-20T01:00:15Z'
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

# T-3095: Promote branch-hygiene findings to the audit cron (T-3093 slice 2)

## Context

Slice 2 of the T-3093 GO. **Slice 1 (T-3094) had to land first** — that ordering was the
substance of the decision, not a preference: promoting a rail that fired on every branch
within ~1.2 days would have flooded the daily audit and burned the signal permanently.
With T-3094 in, the trigger is days-since-last-commit-on-the-branch and the live count is
seven findings, all 43–170 days untouched, all true.

The rail itself has never had an automatic surface. `fw_branch_hygiene` has exactly one
caller (`bin/fw:3221`, i.e. `fw doctor`), audit and handover do not call it, and doctor
appears on **zero** cron lines. It shipped 2026-07-04; the oldest strand forked
2026-03-01. So the strands predate the detector, and nothing has ever put its output in
front of anyone on a schedule — which is the whole reason four real strands sat unlanded
for 43–55 days.

Precedent to follow, not invent: `agents/audit/audit.sh:1826` promotes `bin/fw doctor`'s
cron-drift logic into audit (T-1771, T-1942, T-1943). Same surface, same cron, no new
alert channel. The one thing that precedent got wrong and this slice must not repeat is
that it **mirrored** doctor's logic rather than calling it; branch-hygiene has a single
library entry point (`lib/branch-hygiene.sh::fw_branch_hygiene`) and audit must call it.

Analysis: `docs/reports/T-3093-branch-hygiene-escalation.md` (Recommendation, slice 2).

## Acceptance Criteria

### Agent
- [x] `agents/audit/audit.sh` sources `lib/branch-hygiene.sh` and **calls**
      `fw_branch_hygiene` — no re-implementation, no copied classification logic. A second
      copy of a predicate is the L-399 defect this task's own precedent committed
- [x] Findings surface at **WARN**, never FAIL and never blocking. T-3093 explicitly ruled
      out a blocking gate and per-strand auto-filing: both act on a signal whose
      false-positive rate has only just been fixed, and both are much harder to walk back
      than a WARN
- [x] Output is bounded and **class-representative** — reuse `fw_branch_hygiene_head`
      (T-3092), which guarantees at least one line per finding class before filling the
      remaining budget. A flat `head -N` is what made T-3092's remote classes invisible in
      doctor (0 of 4 shown), and audit emits more sections than doctor does
- [x] Linked worktrees are skipped with INFO, not WARN — branch hygiene is a
      whole-repository concern evaluated from the canonical checkout, and a worktree
      derives a different branch set. Same guard and same reasoning as the cron-drift
      block directly above it (`fw_is_linked_worktree`, T-2435 / OBS-077)
- [x] A repository with no findings emits a positive OK line, not silence — an absent
      section is indistinguishable from a section that did not run (the false-green class
      this framework has hit repeatedly: T-2732, OBS-185)
- [x] The audit's own exit code is unchanged by branch-hygiene findings alone: a repo
      whose only issue is stale branches must still exit 1 (warnings), not 2 (failures)
- [x] Bats coverage in `tests/unit/` for: findings present → WARN emitted with counts,
      findings absent → OK line emitted, linked worktree → INFO and no WARN, and
      exit-code neutrality
- [x] Mutation check recorded in Decisions: removing the audit call turns the
      findings-present test red, and downgrading `fw_branch_hygiene_head` to a flat
      `head -N` turns the class-representation test red
- [x] The live audit is run and its branch-hygiene section reproduced verbatim in
      Decisions, with the finding count reconciled against
      `bash -c 'source lib/branch-hygiene.sh; fw_branch_hygiene .'` — the two must agree,
      and any difference is a defect in this slice, not a rounding artefact
- [x] A repo with **no master lineage** is INFO-skipped, not reported clean. Added during
      build, not at filing: `fw_branch_hygiene` returns silently both when a repo is tidy
      and when there is nothing to judge against, and the two are indistinguishable at the
      call site. Reporting the second as "clean" is the same false-green the OK-line AC
      above exists to prevent, one level deeper

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

out=$(bats tests/unit/t3095_audit_branch_hygiene.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
out=$(bats tests/unit/t100143_branch_hygiene.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
bash -n agents/audit/audit.sh
# audit CALLS the library — no second copy of the predicate (AC #1)
grep -q 'fw_branch_hygiene "$PROJECT_ROOT"' agents/audit/audit.sh
grep -q 'fw_branch_hygiene_head' agents/audit/audit.sh
# the block never reaches fail() — audit's exit code is unchanged by branch findings (AC #6)
sed -n '/^_bh_lib="\$FRAMEWORK_ROOT\/lib\/branch-hygiene\.sh"$/,/^fi$/p' agents/audit/audit.sh > /tmp/.t3095blk && ! grep -qE '^[[:space:]]*fail ' /tmp/.t3095blk
# live audit emits the section, and its count reconciles with the library (AC #9)
# The block emits a section on this repo, and its count reconciles with the library (AC #9).
# NOT via `audit.sh --section structure`: audit takes a global lock and the close path runs
# its own audit, so that line fails with "Another audit is already running" exactly when the
# gate evaluates it. The helper evaluates the shipped block itself — same source, no lock.
tests/helpers/audit-branch-hygiene-block.sh . . > /tmp/.t3095blk2 2>&1 && grep -qE '^(WARN|PASS|INFO)\|Branch hygiene' /tmp/.t3095blk2
bash -c 'source lib/branch-hygiene.sh; fw_branch_hygiene .' > /tmp/.t3095lib 2>&1; test "$(grep -c . /tmp/.t3095lib)" = "$(sed -n 's/.*Branch hygiene: \([0-9]*\) finding(s).*/\1/p' /tmp/.t3095blk2)"
# vendored copy refreshed (consumer projects run the vendored audit)
diff -q agents/audit/audit.sh .agentic-framework/agents/audit/audit.sh

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

### 2026-08-20 — Call the library, do not mirror it

- **Chose:** `audit.sh` sources `lib/branch-hygiene.sh` and calls `fw_branch_hygiene` /
  `fw_branch_hygiene_head`. Zero classification logic in audit; the only place audit reads
  a class token is the `grep -q '^diverged-fork '` that routes the remedy.
- **Why:** the precedent this slice follows (`bin/fw doctor` → audit cron drift,
  T-1771/T-1942/T-1943) mirrored doctor's logic instead of calling it, and that second copy
  is the L-399 producer/consumer split — one side gets fixed, the other silently doesn't.
  Branch hygiene has a single library entry point, so there is no excuse for a copy.
- **Rejected:** re-implementing the scan inline for "audit independence". The independence
  is illusory: two copies of a predicate do not cross-check each other, they diverge.
- **Pinned:** test 10 fails if `fw_branch_hygiene` or `fw_branch_hygiene_head` disappears
  from audit.sh, and fails if any class token is ever *emitted* (rather than matched) there.

### 2026-08-20 — A check that could not run must not report as clean

- **Chose:** three distinct non-finding outcomes, not one. Linked worktree → INFO skip; no
  master lineage → INFO skip; genuinely tidy repo → PASS.
- **Why:** `fw_branch_hygiene` is silent in all three cases, so at the call site they are
  indistinguishable. `bin/fw doctor` collapses the last two and prints "Branch hygiene
  clean" on a repo it never judged. That is the false-green class this framework has hit
  repeatedly (T-2732's port-3000 verification lines, OBS-185, the fabric coverage expander
  at audit.sh:1791) — a silent instrument reporting as a silent result.
- **Rejected:** mirroring doctor's two-state form for parity. Parity with a defect is not
  parity worth having; the divergence is documented here instead, and doctor's own version
  is a candidate follow-up rather than a blocker for this slice.
- **Pinned:** mutation D (guard disabled) turns test 7 red and nothing else.

### 2026-08-20 — WARN, never FAIL; INFO for worktrees

- **Chose:** the block can reach `warn`, `pass` and `info`, and cannot reach `fail` on any
  input. Audit's exit code is therefore 1 (warnings) on a repo whose only issue is stale
  branches, never 2.
- **Why:** T-3093 explicitly ruled out a blocking gate and per-strand auto-filing. Both act
  on a signal whose false-positive rate was fixed only one slice ago (T-3094 moved the
  trigger from behind-count to recency), and both are far harder to walk back than a WARN.
  The linked-worktree INFO follows the content-vs-environment classification from L-486 /
  T-2437: a worktree derives a different branch set, so every finding there is a worktree
  artefact, not content drift.
- **Rejected:** FAIL on `diverged-fork` specifically, on the grounds that T-100194's fork
  cost 100+ conflicts. Tempting and wrong: the fork class is the newest and least-measured
  of the six, and a FAIL blocks pushes. It gets a distinct *remedy string* instead, which
  carries the same information at zero blast radius.
- **Pinned:** test 4 asserts `fail=0` on a findings-present fixture; test 5 asserts the
  shipped block contains no `fail` call at all, so the guarantee holds for inputs the
  fixture never produces. Mutation C (INFO→WARN on the worktree arm) turns test 3 red.

### 2026-08-20 — Mutation results (AC #8)

Each mutation applied to the shipped `audit.sh`, full suite run, source restored. Every one
was killed, and C and D were killed by exactly one test each — the tests discriminate, they
do not merely co-fire.

| # | Mutation | Tests turned red |
|---|----------|------------------|
| A | `_bh_out=$(fw_branch_hygiene …)` → `_bh_out=""` (audit stops calling the library) | 1, 4, 6, 9, 10 |
| B | `fw_branch_hygiene_head 12` → `head -12` (positional cap) | 6, 10 |
| C | linked-worktree arm `info` → `warn` | 3 |
| D | no-master-lineage guard → `elif false` | 7 |

Mutation B is the one worth stating plainly: with a flat `head -12` the fixture's
`remote-unlanded origin/strand` line vanishes entirely behind thirteen `merged-undeleted`
lines. That is not a hypothetical — it is what T-3092 measured in `fw doctor` on this repo,
where 0 of 4 remote findings survived the cap. Audit prints more sections than doctor, so a
class truncated here is even less likely to be noticed.

### 2026-08-20 — Live audit section, reproduced verbatim (AC #9)

`bash agents/audit/audit.sh --section structure`:

```
[WARN] Branch hygiene: 19 finding(s) — stale branches, worktrees or remote refs
       Evidence: behind-threshold audit-remediation-t2416 behind=1761 days=55 (threshold 50)
         merged-undeleted land-t100200-go
         behind-threshold learning/precompact-cleanup behind=7177 days=170 (threshold 50)
         merged-undeleted t100196-vendor-fix
         merged-undeleted t100199-close
         behind-threshold t2353-audit-emit-tasks behind=1761 days=53 (threshold 50)
         merged-undeleted t2416-fw-safe-mode-hook-timing
         diverged-fork t2417-fw-sessions ahead=58 behind=1728 days=48 (threshold 50)
         merged-undeleted t2510-audit-remediation
         worktree-merged /opt/999-Agentic-Engineering-Framework/.claude/worktrees/t100196-vendor-fix branch=t100196-vendor-fix
         remote-unlanded origin/learning/precompact-cleanup ahead=1
         remote-contained origin/t100199-rescue
         … 7 more (shown lines are one-per-class, not the worst)
       Mitigation: Cleanup: git branch -d <name> (merged); fw integrate run (overdue merge-back). Full list: bash -c 'source "/opt/999-Agentic-Engineering-Framework/lib/branch-hygiene.sh"; fw_branch_hygiene "/opt/999-Agentic-Engineering-Framework"' — FORK present: reconcile while small (merge origin/master INTO the branch, or reset if its commits already landed). Do NOT use fw integrate on a fork.
```

`bash -c 'source lib/branch-hygiene.sh; fw_branch_hygiene .' | grep -c .` → **19**. The two
agree exactly. All six finding classes fired and all six are represented in the twelve shown
lines; the seven suppressed are additional instances of classes already visible.

One correction to this task's own Context section, which said "the live count is seven
findings": seven is the count of *stale local* branches after T-3094's recency gate. The
full scan is 19 across six classes — the twelve non-local findings (worktrees, remote refs)
were never in that number. The reconciliation above is against the library, which is the
only figure that can be wrong in a way that matters here.

### 2026-08-20 — A verification line may not run `fw audit` (found by the gate, not by me)

- **Symptom:** two verification lines passed by hand, seconds apart, and both failed under
  the P-011 gate. Output: `Another audit is already running — exiting (no verdict produced)`.
- **Cause:** `audit.sh` takes a global lock, and the `--status work-completed` path runs its
  own audit. A verification line that shells out to `fw audit` therefore races the very
  command evaluating it — deterministically, not occasionally. It is unrunnable *only* at
  the moment it is required to run.
- **Chose:** extract the shipped block into `tests/helpers/audit-branch-hygiene-block.sh`
  and have both the bats suite and the verification line evaluate that. Same source text,
  no lock, and the duplicate runner the bats file had been writing into its own tmpdir is
  gone with it.
- **Worth generalising:** the audit correctly failed loud rather than emitting an empty
  verdict, which is the only reason this was visible at all — a lock that exited 0 with no
  output would have passed the gate while asserting nothing. That is the same false-green
  shape as T-2732's port-3000 lines. Captured as a learning.
- **Rejected:** `--skip-verification`. The lines were wrong; the gate was right.

### 2026-08-20 — Resolve the full-list command against FRAMEWORK_ROOT, not `lib/`

- **Chose:** the mitigation string embeds absolute paths — `source
  "/opt/…/lib/branch-hygiene.sh"; fw_branch_hygiene "/opt/…"`.
- **Why:** doctor emits the relative form `source lib/branch-hygiene.sh`, which only works
  from the framework repo root. In a consumer project the library is at
  `.agentic-framework/lib/`, and the audit that printed the line runs on cron from an
  unknown cwd. A copy-pasteable command that silently depends on cwd is the T-609/T-1257
  class this framework has corrected twice.
- **Rejected:** copying doctor's relative form for parity — same reasoning as the
  false-green decision above.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-08-20T00:56:39Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3095-promote-branch-hygiene-findings-to-the-a.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-80bfae97
- **Timestamp:** 2026-08-20T07:01:59Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-20T07:01:49Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
