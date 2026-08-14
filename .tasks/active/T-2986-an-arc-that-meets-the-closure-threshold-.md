---
id: T-2986
name: "an arc that meets the closure threshold but lacks an anchor Recommendation is silently excluded"
description: >
  an arc that meets the closure threshold but lacks an anchor Recommendation is silently excluded

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [ui, arcs]
components: []
related_tasks: [T-1961, T-2347, T-2910, T-2718, T-2985]
arc_id: arc-grooming
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
created: 2026-08-14T12:30:57Z
last_update: 2026-08-14T12:35:47Z
date_finished: 2026-08-14T12:35:47Z
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

# T-2986: an arc that meets the closure threshold but lacks an anchor Recommendation is silently excluded

## Context

`/approvals` surfaces close-ready arcs via `_load_close_ready_arcs`
(`web/blueprints/approvals.py:413`, T-1961). Three conditions must all hold:
`status == in-progress`, `completion_ratio >= 0.80`, and an anchor-task
`## Recommendation` block. The third failing produces a bare `continue` — the arc
vanishes from the queue with nothing said anywhere.

**arc-015 (`onboarding-shape-detection`) is the live instance.** Measured today:

| arc | status | ratio | anchor Recommendation | surfaces? |
|---|---|---|---|---|
| `readme-first-run` | in-progress | 1.00 | present (GO) | yes |
| `onboarding-shape-detection` | in-progress | **1.00** | **absent** | **no** |
| `onboarding-curriculum` | in-progress | 0.70 | absent | no (below threshold) |
| `designer-corpus` | in-progress | 0.51 | present (GO) | no (below threshold) |

arc-015 is 2/2 complete *and* its demo evidence was captured and verified under T-2910
(`docs/reports/arc-015-demo-evidence.md`, covering all five ecosystems the headline
mechanic names). Everything G-062 asks for exists. It cannot reach the operator because
its anchor T-2718 closed without a `## Recommendation` section, and no gate asked for one.

The failure mode is the one this session has hit repeatedly: **a silent exclusion is
indistinguishable from a considered judgement.** An arc missing from the closure queue
reads as "not ready yet". There is no view anywhere that says "ready, but blocked, and
here is the one thing missing" — so arc-015 has been finished and invisible.

**Scope fence — surfacing only.** This task does NOT write the missing Recommendation on
T-2718, and does not close any arc. Both are judgement calls that belong to the operator
(`fw arc close` is agent-refused under T-1671, and §ACD's mandatory question — does the
demo show the headline mechanic firing — is exactly what a Recommendation records). The
deliverable is that the operator can *see* the blocked arc and what unblocks it. Writing
the recommendation itself is a separate decision with its own evidence review.

## Acceptance Criteria

### Agent
- [x] `_load_close_ready_arcs` returns threshold-meeting arcs whose anchor has no
      `## Recommendation`, carrying a `blocked_reason` naming the missing piece — instead
      of dropping them with a bare `continue`
- [x] Genuinely close-ready arcs are unchanged: same fields, same order, `blocked_reason`
      empty — the existing rows must not regress in shape or content
- [x] A blocked arc renders visibly distinct from an actionable one — it must not show a
      GO/CLOSE verdict badge it does not have, which would invite a close on unread evidence
- [x] The blocked row states what unblocks it, naming the anchor task, so the operator can
      act without reading `approvals.py` to work out why the arc is listed
- [x] arc-015 (`onboarding-shape-detection`) specifically appears on `/approvals` after the
      change and did not before — the motivating instance is verified end to end, not assumed
- [x] Tests cover both directions against the real arc store: a threshold-meeting arc with a
      Recommendation still surfaces as actionable, one without surfaces as blocked. Fixtures
      alone would pass while the real store's shape drifts (the T-2980/T-2985 lesson)
- [x] Below-threshold arcs stay excluded regardless of Recommendation — this widens the
      queue by one condition only, and an unbounded closure queue is the T-2038 list class

### Human

- [ ] [REVIEW] The blocked-arc row reads as "finished, needs one thing from you" — not as
      noise, and not as a second thing to approve

  **Steps:**
  1. `cd /opt/999-Agentic-Engineering-Framework && bin/fw watchtower url` — then open
     `<that url>/approvals` and scroll to the **Arc Closure** section
  2. Compare the two rows: `readme-first-run` (GO badge, Review + Approve/Override) and
     `onboarding-shape-detection` (BLOCKED badge, Review only, amber callout)
  3. Read the amber callout on the blocked row

  **Expected:** the blocked row reads as an arc that is *done* and waiting on a specific,
  named piece of writing — not as a warning, an error, or a second approval competing with
  the actionable row above it. The absence of the Approve/Override button should feel
  obviously correct rather than like something failed to load.

  **If not:** say which reading it produced (noise / error / competing approval). The
  levers are the badge colour and word (currently amber `BLOCKED`), the callout's amber
  left stripe, and the opening phrase "Not yet reviewable." Any of the three can change
  without touching the loader logic.

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

python3 -m pytest tests/web/test_approvals_blocked_arcs.py -q > /tmp/.t2986-a 2>&1 && grep -q passed /tmp/.t2986-a
python3 -m pytest tests/web/test_approvals_bvp_proposals.py tests/web/test_approvals_cache.py -q > /tmp/.t2986-b 2>&1 && grep -q passed /tmp/.t2986-b
python3 -c "import sys; sys.path.insert(0,'.'); from web.blueprints.approvals import _load_close_ready_arcs; rows=_load_close_ready_arcs(); assert all('blocked_reason' in r for r in rows); assert all(r['completion_ratio'] >= 0.80 for r in rows)"

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

### 2026-08-14 — the bug was in the data, not the branch

- **What changed:** Went looking for why none of the four onboarding arcs appeared on
  `/approvals` and first concluded the Arc Closure section did not exist — a broken HTML
  parse (`split('</style>')[-1]`) returned zero headings and I read that as absence. A raw
  grep showed the section, and `readme-first-run` in it, four times. Corrected before acting.
  The lesson is cheap but real: when a page-scrape says "nothing is there", suspect the
  scrape before the page.
- **Plan impact:** Once the loader was run directly against the live store the actual
  distribution was immediate — arc-015 at ratio 1.00 with `rec_present=False`. That reframed
  the task from "the closure surface is missing" to "the closure surface silently excludes",
  which is a much smaller change and a much more interesting bug.
- **Triggered:** Scope fence added mid-task — writing T-2718's `## Recommendation` would
  unblock arc-015 immediately and was tempting, but it is a §ACD evidence judgement (does
  the demo show the headline mechanic firing?) rather than a UI fix. Left to the operator
  with the evidence surfaced in `## Recommendation` above.

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

**Recommendation:** GO

**Rationale:** The surfacing change is done and verified end to end against the live arc
store — arc-015 now appears on `/approvals` with a BLOCKED badge and a callout naming
T-2718, and the pre-existing close-ready rows are byte-for-byte unaffected (13 sibling
tests still green). What remains is a taste call on how the new row *reads*, which is
operator-audience by construction and cannot be settled by curl or grep.

Worth flagging beyond this task: the change reveals that **arc-015 has been finished and
invisible.** It is 2/2 complete, its demo evidence was captured and verified under T-2910
(`docs/reports/arc-015-demo-evidence.md`, all five ecosystems), and the only thing between
it and a closure decision is an unwritten `## Recommendation` on T-2718. That advisory is
deliberately not written here — §ACD's mandatory question (does the demo show the headline
mechanic firing?) deserves its own evidence review rather than being appended to a UI fix.

**Evidence:**
- Before: `onboarding-shape-detection` appeared 0 times in the rendered `/approvals` HTML
- After: BLOCKED badge present, `/arcs/onboarding-shape-detection/close` correctly absent
  from the card, anchor `T-2718` named in the callout
- `readme-first-run` (the actionable comparator) keeps its GO badge and close action
- 7 new tests + 13 sibling approvals/onboarding tests green
- Queue stayed bounded: exactly one row added, all rows still ≥0.80 completion

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

### 2026-08-14T12:30:57Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2986-an-arc-that-meets-the-closure-threshold-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-8588dcf2
- **Timestamp:** 2026-08-14T12:36:08Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-14T12:35:47Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
