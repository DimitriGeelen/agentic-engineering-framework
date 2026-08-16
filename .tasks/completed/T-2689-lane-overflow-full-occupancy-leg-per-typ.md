---
id: T-2689
name: "lane-overflow full-occupancy leg: per-type botOf from 832 rail-340 NODE_DEFAULTS"
description: >
  lane-overflow full-occupancy leg: per-type botOf from 832 rail-340 NODE_DEFAULTS

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [tests/unit/test_corpus_lint_lane_overflow.py, tools/corpus_lint.py]
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
created: 2026-07-30T20:16:57Z
last_update: '2026-08-16T22:25:14Z'
date_finished: 2026-07-30T20:27:23Z
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
bvp_scores_proposed:
  - ts: '2026-08-16T22:25:14Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal);
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2689: lane-overflow full-occupancy leg: per-type botOf from 832 rail-340 NODE_DEFAULTS

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] AC-1 `NODE_OCCUPANCY` table in `tools/corpus_lint.py` encodes 832's rail-340
      `botOf` — per-type height + the 18px below-shape label allowance — keyed by OUR
      spec type, with the vocabulary bridge (our `catch`/`throw` vs their
      `linkEventCatch`/`event*` family) stated in the comment, not assumed.
- [x] AC-2 All 9 types in `corpus_spec.TYPE_TO_TAG` have an occupancy entry (no silent
      gap): pinned by a test that reads TYPE_TO_TAG and asserts full coverage, so a
      future palette type fails loudly instead of being skipped forever.
- [x] AC-3 Threshold is `extent > height` where `extent = max(botOf) - min(y)`, and the
      docstring records WHY the basis changed from the shipped top-y `span >= height`
      (membership question -> render-containment question), not just that it changed.
- [x] AC-4 The new predicate is a provable strict superset of the shipped one, pinned by
      a test — `span >= height` implies `extent > height` since occupancy > 0. This is
      the claim T-2687 forced me to retract on the ordering rule; here it is arithmetic,
      not survey, and the test is the proof rather than the assertion.
- [x] AC-5 Unknown node type in a lane -> that lane SKIPS (skip-not-pass, per-lane), and
      a known-good sibling lane in the same map still reports. Pinned both ways.
- [x] AC-6 Finding message names: declared height, content extent, spill px, the lowest
      node WITH its type and occupancy (because the lowest node is not always the
      largest-y one), and the Clean fixpoint height (`extent + 24`). Both fixes named,
      neither prescribed.
- [x] AC-7 The 15 existing `test_corpus_lint_lane_overflow.py` tests are re-based, and
      the one that legitimately flips (`span == height - 1` was silent under top-y,
      spills under occupancy) carries the reason inline — a changed expectation must
      read as a decision, not as a test edited to match new output.
- [x] AC-8 Live sweep recorded: 3 lanes spill across 2 maps (`draft-knowledge-leveling`
      agent + framework, `aef-session-lifecycle` agent). Default lint baseline moves
      3 -> 4 because `aef-session-lifecycle` is canonical, not a draft — recorded as a
      real defect surfaced, with the number stated, never silently absorbed.
- [x] AC-9 The two lanes that fail 832's Clean fixpoint while still CONTAINING their
      content (`aef-task-lifecycle` agent 6px slack, `aef-inception-flow` agent 16px)
      are recorded as a separate observation, not folded into this rule — that is the
      margin-advisory class and it is a different decision.
- [x] AC-10 832 told at the rail with our recomputed per-lane numbers and the explicit
      reason our count (3) differs from their estimate (4-5): they counted fixpoint
      failures, we gate on spill. They asked us to recompute rather than take their
      count; answering with a bare number would waste that.

### Human

<!-- INTENTIONALLY EMPTY (T-2143 audience axis). Everything this task produces is
     lint output read by agents and a rail post read by 832's agent — the subject of
     every quality judgement here is AGENT experience, so it routes to Agent
     self-eval, not to a Human prefix. Same call as T-2688.

     The operator-facing consequence of this work is NOT an AC of this task: the
     v8 promotion round now carries a third finding, and aef-session-lifecycle has
     a real 6px spill. Those belong to the promotion decision (T-2667) and to their
     own follow-up, not to the rule that discovered them.

     Original template retained below for the next author.
-->
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
# stdin on. `echo "$out"` is small and immediate; grep scans the whole captured
# string anyway, so the tail-3 was cosmetic. Drop it: `echo "$out" | grep -q PAT`.
#
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

python3 -m pytest tests/unit/test_corpus_lint_lane_overflow.py -q >/dev/null 2>&1
python3 -m pytest tests/unit/test_corpus_lint_lane_overflow.py tests/unit/test_corpus_lint.py -q >/dev/null 2>&1
out=$(python3 tools/corpus_lint.py 2>&1); echo "$out" | grep -qc "lane-overflow"
out=$(python3 tools/corpus_lint.py draft-knowledge-leveling 2>&1); echo "$out" | grep -q "spilling"
# 5 rails, all PASS, and no FAIL line — the tool prints one line per rail with no
# summary, so assert the count rather than a summary string that does not exist.
out=$(python3 tools/corpus_conformance.py --all 2>&1); [ "$(echo "$out" | grep -c 'conformance: PASS')" = 5 ] && ! echo "$out" | grep -q "FAIL"

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

### 2026-07-30T20:16:57Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2689-lane-overflow-full-occupancy-leg-per-typ.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-542a6ecc
- **Timestamp:** 2026-07-30T20:27:32Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 3

**Verification-level findings:**

  1. **empty-output-success** (partial, heuristic) @ Verification:line 32
     - evidence: `python3 -m pytest tests/unit/test_corpus_lint_lane_overflow.py -q >/dev/null 2>&1`
  2. **empty-output-success** (partial, heuristic) @ Verification:line 33
     - evidence: `python3 -m pytest tests/unit/test_corpus_lint_lane_overflow.py tests/unit/test_corpus_lint.py -q >/dev/null 2>&1`
  3. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 38
     - evidence: `out=$(python3 tools/corpus_conformance.py --all 2>&1); [ "$(echo "$out" | grep -c 'conformance: PASS')" = 5 ] && ! echo "$out" | grep -q "FAIL"`

### 2026-07-30T20:27:23Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
