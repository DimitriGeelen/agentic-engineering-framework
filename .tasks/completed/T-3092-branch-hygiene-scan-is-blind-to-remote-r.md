---
id: T-3092
name: "branch-hygiene scan is blind to remote refs carrying unlanded commits (OBS-331)"
description: >
  branch-hygiene scan is blind to remote refs carrying unlanded commits (OBS-331)

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [bin/fw, lib/branch-hygiene.sh]
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
created: 2026-08-19T23:16:57Z
last_update: 2026-08-19T23:46:37Z
date_finished: 2026-08-19T23:46:37Z
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
  - ts: '2026-08-19T23:30:08Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=226,acs=8)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-19T23:30:15Z'
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

# T-3092: branch-hygiene scan is blind to remote refs carrying unlanded commits (OBS-331)

## Context

`fw_branch_hygiene` (`lib/branch-hygiene.sh`) walks remote refs and emits exactly one
class for them: `remote-contained` — ahead=0, fully landed, safe to delete. A remote ref
carrying **unlanded** commits matches no branch of that logic and is emitted as nothing.
It is not reported as risky; it is not reported at all.

Live instance, found during the T-3091 stranded-branch triage:

| Ref | State | What the scan says |
|---|---|---|
| `origin/t2416-fw-safe-mode-hook-timing` | **202 unlanded commits**, 6 SALVAGE + 15 NEW-FILE rows | *nothing* |
| `t2416-fw-safe-mode-hook-timing` (local) | ancestor of origin/master, fully landed | `merged-undeleted` |

Same name, remote 204 ahead of local. An operator reading the scan concludes t2416 is
landed and deletable. The local half is; the remote half holds `tests/unit/liveness_watchdog.bats`,
`tests/unit/test_task_cache_t100140.py`, five research artifacts and six unprocessed
`.pickup/` messages that exist nowhere else.

The local-branch arm already has the right shape — `merged-undeleted` / `behind-threshold` /
`diverged-fork`. The remote arm was written for the narrow question "which remote refs can I
delete?" and never grew the complement.

Filed as OBS-331 (urgent). Evidence: `docs/reports/T-3091-branch-manifest.md`.

## Acceptance Criteria

### Agent
- [x] `fw_branch_hygiene` emits a class for a remote ref that is NOT contained in the target — carrying the ref name and its unlanded-commit count
- [x] Running the scan on this repo names `origin/t2416-fw-safe-mode-hook-timing` with a non-zero unlanded count
- [x] A remote ref whose local namesake is landed is still reported on its own merits — the local `merged-undeleted` verdict must not suppress the remote finding (this is the exact t2416 confusion)
- [x] `remote-contained` still fires for genuinely-contained remote refs — regression guard, since the new arm shares the same loop
- [x] Bats coverage in `tests/unit/` builds a sandbox repo with three remote refs (contained / unlanded / unlanded-with-landed-local-namesake) and asserts the emitted class for each
- [x] Mutation check recorded in Decisions: with the new arm disabled the new tests go red, and with it enabled the pre-existing branch-hygiene tests stay green
- [x] The finding is actually reachable in `fw doctor` output — a positional 12-line cap was hiding every remote class behind the 12 local findings on this repo (0 of 4 shown); truncation is now class-representative via `fw_branch_hygiene_head`

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

bats tests/unit/t100143_branch_hygiene.bats > /tmp/.t3092-bats 2>&1 && grep -q '^ok 15' /tmp/.t3092-bats && ! grep -q '^not ok' /tmp/.t3092-bats
bash -n lib/branch-hygiene.sh
bash -n bin/fw
# the live miss this task exists for: the 204-commit remote strand must now be named
bash -c 'source lib/branch-hygiene.sh; fw_branch_hygiene .' > /tmp/.t3092-scan 2>/dev/null && grep -qE '^remote-unlanded origin/t2416-fw-safe-mode-hook-timing ahead=[0-9]+$' /tmp/.t3092-scan
# ...and its landed local namesake must still report independently
grep -q '^merged-undeleted t2416-fw-safe-mode-hook-timing$' /tmp/.t3092-scan
# the contained class must not have been swallowed by the new arm
grep -q '^remote-contained ' /tmp/.t3092-scan
# doctor must actually SHOW a remote finding, not truncate it away
timeout 300 bin/fw doctor > /tmp/.t3092-doc 2>&1; grep -q 'remote-unlanded' /tmp/.t3092-doc
# the command doctor prints for the operator must be the one that actually works:
# extract it from bin/fw verbatim, run it, and require it to reproduce the full scan
grep -o "bash -c 'source lib/branch-hygiene.sh; fw_branch_hygiene .'" bin/fw > /tmp/.t3092-cmd
test -s /tmp/.t3092-cmd
bash -c 'source lib/branch-hygiene.sh; fw_branch_hygiene .' > /tmp/.t3092-hint 2>/dev/null && test "$(grep -c . /tmp/.t3092-hint)" -eq "$(grep -c . /tmp/.t3092-scan)" && test "$(grep -c . /tmp/.t3092-hint)" -gt 12
# structural invariants stay green
bats tests/lint/ > /tmp/.t3092-lint 2>&1 && ! grep -q '^not ok' /tmp/.t3092-lint

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

**Symptom:** `origin/t2416-fw-safe-mode-hook-timing` held 204 commits absent from master — including `tests/unit/liveness_watchdog.bats`, `tests/unit/test_task_cache_t100140.py`, five research artifacts and six unread `.pickup/` messages — and `fw doctor`'s branch-hygiene section said nothing about it. Meanwhile the *local* branch of the same name, an ancestor of `origin/master`, was reported `merged-undeleted`, i.e. landed and safe to delete.

**Root cause:** The remote-ref loop in `lib/branch-hygiene.sh` had exactly one arm — `if ahead == 0 → remote-contained`. There was no `else`. A remote ref carrying unlanded commits matched nothing and was emitted as nothing: not reported as low-priority, not reported as risky, *absent*.

**Why structurally allowed:** The loop was written to answer one question — "which remote refs can I delete?" — and that question only needs the contained case. The local-branch loop above it grew three classes over two tasks (`merged-undeleted`, then `behind-threshold`, then `diverged-fork` in T-100195) because each new failure mode was hit on a *local* branch. Nothing forced the remote arm to grow the complement, and its silence was indistinguishable from a clean result. The existing test even encoded the gap as intent: *"ahead remote silent"*.

A second, independent layer of the same class: `fw doctor` truncated findings positionally with `head -12`, and remote findings are emitted last. On this repo — 19 findings, 12 of them local — a correct `remote-unlanded` line would still have reached the operator's screen 0 times out of 4. The scan and its display had to be fixed together or the fix would have been invisible.

**Prevention:**
- `remote-unlanded origin/<branch> ahead=<n>` now fires for the complement, judged independently of any local branch of the same name (pinned by test 9, which goes red if a landed local verdict suppresses the remote one).
- `fw_branch_hygiene_head` makes truncation class-representative, so a finding class can no longer be hidden by volume in another class (pinned by test 13, plus test 14 which demonstrates the old positional cap dropping it).
- The stale test name asserting `ahead remote silent` is corrected, so the gap is no longer documented as intended behaviour.
- Mutation-tested in both directions: five mutations, four red as required; the fifth (B) stayed green and exposed an inert test of my own, which was rewritten to claim only what it verifies. Recorded in Decisions.

**Not prevented by this task:** nothing consumes these findings. `behind-threshold` has been firing at 1400–7100 commits over a threshold of 50 for months with no action taken, and this change adds four more WARN lines to that same unread section. Detection was never the missing piece — escalation is. That is a separate task, not a claim to have made here.

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

### 2026-08-20 — local and remote are judged independently, neither suppresses the other

- **Chose:** Report `remote-unlanded origin/X` on its own evidence even when local `X` is landed and reported `merged-undeleted`.
- **Why:** That combination IS the bug. `t2416-fw-safe-mode-hook-timing` was landed locally and 204 commits unlanded remotely; the scan showed only the local half, so the ref read as deletable while holding two test files, five research artifacts and six unread `.pickup/` messages that exist nowhere else. Suppressing one verdict with the other reproduces the failure with extra steps.
- **Rejected:** Deduplicating by branch name. It looks tidier and it is exactly what hid the strand.

### 2026-08-20 — the current branch's upstream is excluded

- **Chose:** Skip the remote ref that the current checkout tracks.
- **Why:** It is not a strand — it is where you are standing, and `fw_branch_divergence` already reports it in detail for the handover. On this repo it would emit a permanent finding for `origin/t2539-staging` (354 ahead) on every doctor run. A rail that always fires on your own working branch is the noise that trains people to skip the section — which is how `behind-threshold` reached 1761 unread.
- **Rejected:** Reporting everything. Honest but self-defeating; the value of this rail is that its lines are all actionable.

### 2026-08-20 — mutation results, including one that revealed my own inert test

| Mutation | Expected | Observed |
|---|---|---|
| A — delete the `remote-unlanded` arm | red | **2 red** (7, 9) |
| B — restore the old `\|\| echo 1` error fallback | red | **0 red** — see below |
| C — let a landed local namesake suppress the remote finding | red | **1 red** (9) |
| D — drop the upstream exclusion | red | **1 red** (10) |
| E — revert the head helper to a positional `head -n` | red | **1 red** (13) |
| control (pristine) | green | 15/15 green, file byte-identical after every restore |

- **B is the one worth reading.** It stayed green, which means the test claiming to cover the sentinel asserted nothing. Investigating: `git for-each-ref` *drops broken refs before the loop can see them* (`warning: ignoring broken ref`, row omitted), and a ref pointing at a non-commit counts as 0 rather than erroring. The rev-list-failure path is therefore unreachable through this loop, and my test passed because the ref never arrived — not because the guard worked.
- **Kept the sentinel anyway** (`|| echo ""` + skip, rather than `|| echo 1`): the old fallback meant "not contained", which was the *silent* case; now that case emits, so the same fallback would manufacture a finding out of an error. It is correct defensive code with no currently-reachable trigger, and the comment says so rather than implying coverage.
- **Rewrote the test** to pin the guarantee that IS real and reachable: a corrupt ref yields silence, not a phantom strand. Its claim now matches what it tests.

### 2026-08-20 — truncation had to change or the fix would not have shipped

- **Chose:** `fw_branch_hygiene_head` — one line per distinct class first, then fill to the cap.
- **Why:** `fw doctor` capped output with `head -12`, and emission order is local → worktree → remote. This repo has 19 findings of which 12 are local, so **0 of 4 `remote-unlanded` lines survived the cap**. Verified before and after. The scan would have been "fixed" while the operator's view was byte-identical.
- **Rejected:** Raising the cap. It defers the same failure to the next busy repo, and the cap exists because 19 lines of WARN is already at the edge of readable.
- **Known limit, stated rather than hidden:** the representative is the *first* line of its class, not the worst — `origin/t2416 ahead=204` is still behind `origin/learning/precompact-cleanup ahead=1` in the shown set. Coverage is guaranteed; ranking is not. The "… N more" hint therefore names a command that prints the full list, and that command was run to confirm it works before being written into the output.


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

### 2026-08-19T23:16:57Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3092-branch-hygiene-scan-is-blind-to-remote-r.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-054041ad
- **Timestamp:** 2026-08-19T23:50:56Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-19T23:46:37Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
