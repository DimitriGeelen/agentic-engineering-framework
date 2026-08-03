---
id: T-2771
name: "triage the remaining red verification blocks in the human review queue (T-2765
  census)"
description: >
  The first fw verify-queue census (T-2765) reached 60 of 221 queue tasks and found
  13 red. One (T-1805) was classified and repaired under T-2766, which also surfaced
  a live product defect (T-2769) that the red was masking. The remaining reds are
  unfiled. Each needs its own wrong-vs-correctly-failing call — a red block is either
  (a) WRONG (the contract moved, the path never existed, the assertion is superseded)
  and repairable, or (b) CORRECTLY FAILING (the thing it asserts is genuinely broken),
  in which case the line must NOT be edited and the underlying defect must be fixed
  or filed. Deliverable: every remaining red classified with evidence, repairs applied
  where (a), defects filed where (b). Do not repair blind — T-2766 showed the thirty-second
  green is exactly where the classification gets skipped, and it would have buried
  a real rc=0 JSON contamination bug.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [tests/unit/test_pre_push_monotonic_ancestor.bats]
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
created: 2026-08-03T17:05:02Z
last_update: 2026-08-03T17:36:58Z
date_finished: 2026-08-03T17:36:58Z
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
  - ts: '2026-08-03T17:15:06Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-03T17:15:10Z'
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

# T-2771: triage the remaining red verification blocks in the human review queue (T-2765 census)

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Every red block from the census carries an explicit classification — **(a) WRONG,
      repairable** or **(b) CORRECTLY FAILING** — recorded with the evidence that decides
      it, in this task's `## Findings`. No red is left unclassified or silently skipped
- [x] Every (a) is repaired and its full block re-run green via
      `bin/fw verify-queue --task T-XXX`, with the repair carrying a provenance comment
      naming what it replaced and why
      <!-- 6/8 green (T-1811, T-1928, T-1947, T-1968, T-1951, T-1843-bats). T-1960/T-1961
           repaired correctly — they now resolve to our own Watchtower — but remain red on
           a distinct environmental defect underneath (T-2774, loopback unreachable). They
           are NOT re-pointed to make them green; see the post-repair correction below. -->
- [x] The environmental defect exposed by the repair is filed rather than papered over
      (T-2774), and the two affected lines are left red rather than re-pointed at a server
      that would answer
- [x] Every (b) has its underlying defect filed as its own task, and its verification line
      left **byte-identical** — a correctly-failing line is the framework working, and
      editing it to green is the failure mode this whole exercise exists to prevent
- [x] The counts reconcile: reds classified = reds found, stated as a number, so a partial
      sweep cannot read as a complete one
- [x] The gate coverage gap the sweep exposed is filed rather than quietly patched here
      (T-2772 — the T-2732 port predicate cannot see `FW_TEST_PORT=3000`)
- [x] A fresh `bin/fw verify-queue` pass over the tasks touched here shows the (a) repairs
      green and the (b) lines still red — verified by running it, not by assuming

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

## Findings

### Count reconciliation (do this first, because the number was wrong)

The census was recorded as **13 red**. It is **11**. `grep -c FAIL` over the log counts
two `=================== FAILURES ===================` separator lines from embedded pytest
output as verdicts. The real verdict lines are 11, one of which (T-1805) was classified and
repaired under T-2766. **10 remained for this task, and all 10 are classified below.**
Correcting the earlier figure rather than leaving it standing — an inflated red count is
not harmless, it makes the queue look worse than it is and the sweep look less complete
than it was.

### Classification table

| Task | Class | Cause |
|------|-------|-------|
| T-1811 | (a) WRONG | `pipefail` surfaces the *producer's* exit code |
| T-1928 | (a) WRONG | SIGPIPE — `/bvp` is 5,366,599 bytes |
| T-1947 | (a) WRONG | superseded: T-1948 rewrote the pinned prose per human review |
| T-1968 | (a) WRONG | SIGPIPE (375,353 bytes) **and** asserts the v1 value its own v2 replaced |
| T-1843 | (a) WRONG | G-015 always-moving value: pins `VERSION=1.4`, hook is at 1.5 |
| T-1951 | (a) WRONG | `set -e` kills on a command whose non-zero exit *is* the expected result |
| T-1960 | (a) WRONG | `FW_TEST_PORT=3000` — drove a **different project's** server |
| T-1961 | (a) WRONG | same as T-1960 |
| T-1910 | neither | passes now (10 passed / 81.6s); the red was environment-dependent |
| T-1971 | **(b) CORRECTLY FAILING** | the stale text it existed to remove is still rendered |

### The ones worth reading in full

**T-1971 — the only (b), and the whole reason not to sweep.** Its single line asserts that
`/bvp` contains "Drag a slider below to preview re-ranking" **and not** "Read-only — live
weight sliders ship in T-1929". Both strings are on the page right now: the first once, the
second **twice**. The line is red because the removal T-1971 shipped is incomplete. It is
the framework working. **The line must not be edited.** Repairing it would have taken about
fifteen seconds and would have destroyed the only evidence that the stale copy survived.

**T-1960 / T-1961 — the T-2732 origin scenario, live on this host.** Both pin
`FW_TEST_PORT=3000`. Port 3000 here is a *different* python3 (pid 1341537) from our
Watchtower (pid 390238, port 3001), and it answers 200. These Playwright suites have been
driving another project's Watchtower. **The T-2732 gate does not see this shape:**
`find_port_literals` matches `https?://host:3000` URL literals only, so a port supplied as
an env-var assignment — exactly how a test harness is pointed at a server — passes the gate
clean. Verified directly against the predicate. That is a coverage gap in the gate built
for this exact failure, and it gets its own task rather than a quiet fix here.

**T-1968 — two independent defects in one line.** It pipes a 375KB page through
`awk | grep -q` (SIGPIPE) *and* asserts `color: var(--pico-color);` — the **v1** fix. The
CSS at that selector now carries a comment, written by T-1968 itself, explaining that v1
resolved to the Pico link colour inside an `<a>` and was replaced by
`--pico-secondary-inverse`. The verification line pins the value its own task superseded.

**T-1811 — the mirror image of the T-2738 lesson.** `fw verify-acs … | grep -q "Reviewer"`
fails with rc=1 while the output *does* contain "Reviewer". Cause: `verify-acs` exits 1 by
design when REVIEW ACs are pending, and `pipefail` returns the last non-zero status in the
pipeline — the producer's. T-2738 warns against `out=$(cmd)` *discarding* a producer's exit
code; here `pipefail` *preserves* one that means "there is human work pending", not
"failure". Both directions of the same confusion between *did it succeed* and *does the
output say X*.

### Post-repair correction: T-1960 / T-1961 are still red, and the reason matters

The port repair worked — both suites now resolve to `http://localhost:3001`, our own
Watchtower, instead of port 3000. They still fail, with `Page.goto: Timeout 15000ms` on
`about:blank`. That is not a regression introduced by the repair; it is what was underneath.

Measured: Watchtower listens on `0.0.0.0:3001` and answers on the **LAN** address
`http://192.168.10.107:3001` immediately, while **`localhost:3001` and `127.0.0.1:3001`
both time out** (rc=000 after the full 5s curl budget). Loopback traffic to the port is
being dropped though the socket is bound to all interfaces. Playwright builds its base_url
as `http://localhost:$FW_TEST_PORT`, so every Playwright suite on this host is affected.
Filed as **T-2774**.

**This reframes the hard-coded port.** Port 3000 is another project's Watchtower, and it
*does* answer on loopback. So `FW_TEST_PORT=3000` was most likely not carelessness but a
workaround for the loopback defect — one that traded "our tests cannot reach our server"
for "another project's server passes our assertions". The second is the worse failure, and
it is invisible: it produces green.

So the honest classification for T-1960/T-1961 is **two stacked defects**: the stored line
was (a) WRONG *and* the environment underneath it is (b) genuinely broken. The repair fixed
the half this task owns. The lines stay red until T-2774 lands, and they should — a green
there would mean they had been re-pointed at the wrong server again.

### Filed rather than fixed here

- **T-2772** — the T-2732 port gate's predicate is blind to `FW_TEST_PORT=3000`. Patching
  `find_port_literals` inside a triage task would have widened a shared gate with no
  regression corpus and no sweep for other instances of the shape; the sweep is the
  larger half of that work.
- **T-2773** — the stale `/bvp` copy behind T-1971's (b). Its brief says explicitly not to
  touch T-1971's verification line: that line goes green when the page is right, or it
  stays red.

### What this sweep says about the rails

Eight of ten reds were defects in the *checks*, not in the code they check. That ratio is
worth stating plainly rather than filing away: a verification corpus decays on its own,
because pages grow past pipe buffers, ports move, prose gets rewritten by later tasks, and
versions increment. None of those are regressions in the product. The value of
`fw verify-queue` is not that it finds broken features — here it found exactly one — but
that it distinguishes a rotting check from a real failure, which is precisely the judgment
a green-or-red count cannot make on its own.

**T-1843 — G-015, in a test file, which is why the sweep missed it.** Pins
`^# VERSION=1.4` on the pre-push hook, now at 1.5. Behavioural cases 3-7 all pass, so the
hook works; only the version-equality assertion fails. T-2763's G-015 sweep ran over stored
`## Verification` blocks — this instance lives in a bats file, outside that population.
*A sweep is only as wide as the pattern that generated it* (T-2764), and also only as wide
as the corpus it was pointed at.

## Verification

# The six repairs that are green on their own merits.
timeout 400 bin/fw verify-queue --task T-1811 > /tmp/.t2771-1811.out 2>&1 && grep -q "0 red" /tmp/.t2771-1811.out
timeout 400 bin/fw verify-queue --task T-1928 > /tmp/.t2771-1928.out 2>&1 && grep -q "0 red" /tmp/.t2771-1928.out
timeout 400 bin/fw verify-queue --task T-1947 > /tmp/.t2771-1947.out 2>&1 && grep -q "0 red" /tmp/.t2771-1947.out
timeout 400 bin/fw verify-queue --task T-1968 > /tmp/.t2771-1968.out 2>&1 && grep -q "0 red" /tmp/.t2771-1968.out
timeout 400 bin/fw verify-queue --task T-1951 > /tmp/.t2771-1951.out 2>&1 && grep -q "0 red" /tmp/.t2771-1951.out
timeout 400 bats tests/unit/test_pre_push_monotonic_ancestor.bats

# T-1971's line is untouched. Asserting the bytes rather than trusting the intent, because
# "I left it alone" is exactly the claim a sweep is tempted to make falsely.
grep -q 'Drag a slider below to preview re-ranking' .tasks/active/T-1971-remove-stale-read-only--live-weight-slid.md

# The port repairs resolve the port instead of pinning it. These two suites stay RED until
# T-2774 (loopback) lands — that is correct, so this asserts the repair shape, not a green.
grep -q 'FW_TEST_PORT="$(bin/fw watchtower port)"' .tasks/active/T-1960-arc-recommendation-schema--auto-render-o.md
grep -q 'FW_TEST_PORT="$(bin/fw watchtower port)"' .tasks/active/T-1961-approvals-ingestion-of-close-ready-arcs-.md
# Absence is checked over the EXECUTABLE lines only — the provenance comments deliberately
# quote the old `FW_TEST_PORT=3000` they replaced, and a naive file-wide grep would fail on
# the very comment that documents the fix.
bash -c 'source lib/verification-port.sh; extract_verification_block .tasks/active/T-1960-arc-recommendation-schema--auto-render-o.md' > /tmp/.t2771-b1960.out
bash -c 'source lib/verification-port.sh; extract_verification_block .tasks/active/T-1961-approvals-ingestion-of-close-ready-arcs-.md' > /tmp/.t2771-b1961.out
! grep -q 'FW_TEST_PORT=3000' /tmp/.t2771-b1960.out
! grep -q 'FW_TEST_PORT=3000' /tmp/.t2771-b1961.out

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.
#
# Toolchain hint (L-291): if you edited *.vbproj/*.csproj/*.xaml add `dotnet build`;
# *.go → `go build ./...`; Cargo.toml → `cargo check`; tsconfig.json → `tsc --noEmit`;
# pom.xml → `mvn -q compile`. P-011 runs only what you write — broken builds slip
# past otherwise (origin: 003-NTB-ATC-Plugin T-077, broken WPF DLL on master 5 days).
#
# Pipefail/SIGPIPE hint (L-387): P-011 runs each command under `set -eo pipefail`.
# `cmd | grep -q PATTERN` exits 141 (SIGPIPE) when grep matches and closes stdin
# while the upstream is still writing — verification then "fails" even though
# the pattern was present. Safe pattern: capture first, grep the capture:
#     out=$(cmd 2>&1); echo "$out" | grep -q "PATTERN"
# Or:
#     cmd > /tmp/.out 2>&1 && grep -q "PATTERN" /tmp/.out
# Origin: L-387, captured 4× (T-1716, T-1838, T-1862, T-1863) before this hint.
#
# Single pipe only — no intermediate tail/awk/sed stages between capture and grep
# (T-2090): `echo "$out" | tail -3 | grep -q PAT` re-introduces the SIGPIPE risk
# the capture step closed off — the middle stage is what `grep -q` slams its
# stdin on. grep scans the whole captured string anyway, so the tail-3 was
# cosmetic. Drop it: `echo "$out" | grep -q PAT`.
#
# AND ONLY WHILE THE CAPTURE IS SMALL (T-2743). The two hints above are correct
# for the captures they were written about, and both invert above the pipe
# buffer. `echo "$out" | grep -q PAT` is NOT SIGPIPE-free — it is SIGPIPE-free
# only while "$out" fits in the 65536-byte pipe buffer. Above that, with an
# early match: echo blocks on the full pipe, grep -q exits, echo takes SIGPIPE,
# pipeline exits 141 under pipefail — the exact failure L-387 exists to prevent.
# Measured: a Watchtower page is 146,366 bytes, rc=141 on 3/3 runs, deterministic
# not racy. Any line that curls a rendered page is exposed (routes run 50-200KB).
# For anything that might be large, redirect to a file:
#     cmd -o /tmp/.out && grep -q "PATTERN" /tmp/.out
#     curl -sf "$(bin/fw watchtower url)/page" -o /tmp/.out && grep -q "PAT" /tmp/.out
# This is the better default even when size is not a concern: `&&` keeps the
# PRODUCING command's exit code in the verdict, where `out=$(cmd)` discards it —
# the T-2738 problem one layer down. A 404 from curl fails the line instead of
# silently producing an empty capture for grep to not-match.
#
# REHEARSING A LINE BY HAND DOES NOT REHEARSE THE GATE (T-2743). Your interactive
# shell has no `set -eo pipefail`. The line above returned 0 when run by hand and
# 141 under P-011, from the same directory, the same second. To rehearse for real:
#     bash -c 'set -eo pipefail; <your verification line>'
#
# BUT NOT for a test runner (T-2738): the capture above discards the command's
# exit code, and `set -e` is suppressed inside the `if` condition the gate runs
# each line in — so in `cmd1; cmd2` only cmd2 is the verdict. For pytest/bats
# that exit code WAS the verdict, and the pass marker you grep instead survives
# a partial failure: a suite printing "3 failed, 9 passed" satisfies
# `grep -q "9 passed"`. Generalising to `grep -qE "[0-9]+ passed"` matches the
# same output. Either keep the exit code:
#     python3 -m pytest <file> -q > /tmp/.out 2>&1 && grep -q passed /tmp/.out
# or add the guard the exit code used to supply:
#     out=$(python3 -m pytest <file> -q 2>&1); echo "$out" | grep -q passed && ! echo "$out" | grep -q failed
#     out=$(bats <file> 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
# The close gate refuses the unguarded form. Bypass: FW_ALLOW_UNJUDGED_TEST_RUN=1.
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

### 2026-08-03T17:05:02Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2771-triage-the-remaining-red-verification-bl.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-2b553f87
- **Timestamp:** 2026-08-03T17:44:48Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-03T17:36:58Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
