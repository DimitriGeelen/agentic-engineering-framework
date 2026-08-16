---
id: T-2690
name: "832 rail 342 pair-round: respond to occupancy-leg reply, land any resulting
  corpus fix"
description: >
  832 rail 342 pair-round: respond to occupancy-leg reply, land any resulting corpus
  fix

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
created: 2026-07-30T20:32:49Z
last_update: '2026-08-16T22:25:14Z'
date_finished: 2026-07-30T20:41:11Z
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
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=2 (body:default-change); D4=2 
      (body:env-class-handled); F-RECALL=0 (no-signal); F-AUTONOMY=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2690: 832 rail 342 pair-round: respond to occupancy-leg reply, land any resulting corpus fix

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] AC-1 832's rail 342 read in full and its asks separated into three buckets:
      (a) claims about OUR corpus/rules that are checkable here, (b) claims about
      THEIR side that we take on report, (c) open questions addressed to us. Bucket (a)
      is verified against the code or the maps before any reply quotes it — the rail
      thread has twice now caught a confidently-stated claim that a five-minute check
      would have falsified (our rail 336, their T-312 scope).
- [x] AC-2 Every item in bucket (a) either confirmed with the command/number that
      confirms it, or contradicted with the same — no item answered from memory.
- [x] AC-3 Any corpus/lint/test change 342 turns out to require is landed with tests,
      or its absence is recorded with the reason. "Nothing to do" is a valid outcome
      and must be stated explicitly rather than left as silence.
- [x] AC-4 Reply posted to the rail as a reply-to-342, answering their open questions
      directly, and flagging anything we could NOT verify as unverified rather than
      letting it pass as agreed.
- [x] AC-5 Existing green state preserved: corpus lint default baseline stays 4 (or
      moves only deliberately, with the move recorded in the pinning test's comment),
      conformance stays 5/5, corpus test suite stays green.

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

python3 -m pytest tests/unit/test_corpus_lint_lane_overflow.py tests/unit/test_corpus_lint.py -q >/dev/null 2>&1
# AC-5: default baseline stays exactly 4 findings, and zero lanes go unjudged
out=$(python3 tools/corpus_lint.py 2>&1); echo "$out" | grep -q "^4 finding(s)$"
out=$(python3 tools/corpus_conformance.py --all 2>&1); [ "$(echo "$out" | grep -c 'conformance: PASS')" = 5 ] && ! echo "$out" | grep -q "FAIL"
# the skip channel exists and reports the live zero (pins 832's "0 skipped" half)
python3 -c "import sys;sys.path.insert(0,'tools');import corpus_lint;assert callable(corpus_lint.lane_overflow_skips)"

## RCA

**Symptom:** `lane_overflow` skipped any lane it could not evaluate and said nothing.
From outside, a run printing `CLEAN` or `4 finding(s)` was indistinguishable from a run
where lanes were never judged at all. 832 hit the same class on their side first and
named it at rail 342.

**Root cause:** the rule had exactly two observable outcomes — a finding, or no finding
— and used a bare `continue` for three structurally different conditions: out of scope
(no members / no declared height), unevaluable (unpositioned member, unknown node type),
and evaluated-and-clean. Absence of a finding collapsed all three into one signal.

**Why structurally allowed:** nothing asserted anything about skipped lanes, in either
direction, so the conflation was untestable by construction. The live corpus happens to
have zero unevaluable lanes, so the hole never produced a wrong answer — only the
standing capacity for one, which is invisible precisely because it looks like success.
The skip branches were also authored in the same commit as the rule (T-2688), so there
was never a moment where someone read the rule from outside and asked what a skip looks
like. This is the G-071 shape: a deterministic component whose silence is
indistinguishable from its success. Our own T-2689 note (OBS-104) had already observed
that findings carry no severity dimension, and stopped at observing it.

**Prevention:** `lane_overflow_skips()` emits the skip as an exit-code-neutral NOTE on
every run, unconditionally rather than behind a flag — the point is that a clean run
must not be readable as a complete one. 832's scope guard is kept so the note cannot
become permanent noise (two empty lanes in `t2584-scratch` would otherwise print
forever, and unresolvable notes train people to ignore the channel). Six tests pin both
directions, and `test_live_corpus_has_no_unjudged_lanes` pins the live ZERO, so the day
a map lands an unpositioned member the count stops being invisible. Recorded as L-520
for the wider class — the sibling defect, that the rule was conservative because it
answered the wrong question rather than because it lacked a constant.

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

### 2026-07-30T20:32:49Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2690-832-rail-342-pair-round-respond-to-occup.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-710fa47e
- **Timestamp:** 2026-07-30T20:41:17Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Verification-level findings:**

  1. **empty-output-success** (partial, heuristic) @ Verification:line 32
     - evidence: `python3 -m pytest tests/unit/test_corpus_lint_lane_overflow.py tests/unit/test_corpus_lint.py -q >/dev/null 2>&1`
  2. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 35
     - evidence: `out=$(python3 tools/corpus_conformance.py --all 2>&1); [ "$(echo "$out" | grep -c 'conformance: PASS')" = 5 ] && ! echo "$out" | grep -q "FAIL"`

### 2026-07-30T20:41:11Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
