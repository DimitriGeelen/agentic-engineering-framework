---
id: T-2621
name: "Map-conformance audit leg — task-lifecycle map edges vs update-task.sh transitions"
description: >
  MAINTAIN goal: detect map-vs-reality divergence structurally. Derive the allowed
  status-transition set from the aef-task-lifecycle corpus map (fw corpus derive)
  and compare against the transition table enforced by agents/task-create/update-task.sh.
  Audit WARN on divergence in either direction (map documents a transition code refuses;
  code allows a transition the map lacks). First selective spec-conformance rail per
  T-2619 recommendation — task-lifecycle only, where transitions are already mechanically
  enforced.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [designer, corpus, t2619-slice]
components: []
related_tasks: [T-2619]
arc_id: designer-corpus
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
# demo_target: true               # T-2286: optional — marks task as reserved for an orchestrated demo
#                                 # worker (e.g. arc-010 HM-A dispatches via mcp__fw__work_on). When set,
#                                 # `fw work-on T-XXX` refuses unless --i-am-demo-orchestrator (CLI) or
#                                 # FW_I_AM_DEMO_ORCHESTRATOR=1 (env) is passed. Prevents the parent
#                                 # session from consuming the captured→started-work transition the demo
#                                 # worker expects to drive. Origin OBS-057.
created: 2026-07-25T16:43:07Z
last_update: 2026-07-26T20:30:42Z
date_finished: 2026-07-26T20:30:42Z
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
  - ts: '2026-07-25T16:45:05Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-07-26T20:30:05Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-07-25T16:45:08Z'
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
  - ts: '2026-07-26T20:30:08Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 2
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=2
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal);
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2621: Map-conformance audit leg — task-lifecycle map edges vs update-task.sh transitions

## Context

First selective spec-conformance rail per the T-2619 GO (mirror-first + selective conformance, task-lifecycle only). The keystone of the operator's cascading-detail authority model (T-2619 round 2): a map graduates from transitional-subordinate to detail-authority only when its conformance rail is green — this task builds that rail for aef-task-lifecycle. Extraction convention: map nodes carrying a machine-readable status annotation (`aef:meta state=<status>`) are state carriers; a flow (or flow path through non-state nodes) between two state carriers asserts a status transition. Canonical enforced set: `VALID_TRANSITIONS` (policy/enums.yaml via lib/enums.sh, enforced at agents/task-create/update-task.sh). Divergence in either direction is a WARN (map documents what code refuses / code allows what map lacks) — the rail's job is to surface divergence, not to hide it.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `fw audit` structure section gains a map-conformance check (`check_map_conformance` in agents/audit/audit.sh, thin wrapper over `tools/corpus_conformance.py`): PASS when aligned, WARN listing each divergent pair with direction, INFO when rail dormant (zero carriers), WARN on checker load failure
- [x] Extraction deterministic and documented in the checker docstring: state-carrier nodes (`aef:meta state=`) only; walks pass through non-carriers and terminate at the first carrier reached; same-state pairs ignored; only aef-task-lifecycle is scanned (rail scoped per T-2619 selective conformance)
- [x] Unit tests (tests/unit/test_corpus_conformance.py, 6 passed): aligned fixture asserts exactly the canonical set; refused-transition divergence; missing-transition divergence; zero-carrier skip; carrier-terminated walks; legacy exclusion
- [x] Live run recorded: aef-task-lifecycle v5 (state annotations added this task, uuid preserved, zero visual change) → DIVERGENT, 2 findings, both code-allows/map-lacks: `issues → work-completed` and `started-work → captured` (shelving demote, T-1068). Surfaced as audit WARN by design — map catch-up (2 new flows) proposed to operator as a pair-draft round rather than redrawing the T-2618-reviewed diagram unilaterally

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

out=$(python3 -m pytest tests/unit/test_corpus_conformance.py -q 2>&1); echo "$out" | grep -q "6 passed"
python3 tools/corpus_conformance.py > /dev/null 2>&1; rc=$?; test "$rc" -le 1
out=$(python3 tools/corpus_conformance.py 2>&1); echo "$out" | grep -qE "conformance: (PASS|DIVERGENT)"
out=$(bin/fw corpus derive aef-task-lifecycle 2>&1); test "$(echo "$out" | grep -c 'state:')" = "7"
out=$(python3 tools/corpus_lint.py 2>&1); echo "$out" | grep -q "^2 finding"

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

### 2026-07-26 — map had no machine-readable state at filing
- **What changed:** The task assumed the map's transitions were extractable; in fact v4 encoded statuses only in display names. The schema already supported `aef:meta state=`, so the task grew a first leg: annotate 7 carrier nodes as v5 (uuid preserved, canon diff = exactly the 7 additions, zero visual change).
- **Plan impact:** "Derive the allowed transition set from the map" became a two-step: define the carrier convention, then collapse. The convention (walks terminate at carriers, same-state ignored) is now the documented contract in the checker.
- **Triggered:** Map catch-up proposal to operator (2 missing flows: shelve-demote, issues→completed) — deliberately NOT drawn unilaterally while T-2618's review of this diagram is pending.

## Decisions

### 2026-07-26 — surface divergence vs redraw the map
- **Chose:** Ship the rail with the 2-pair divergence surfaced as audit WARN; propose the map edit to the operator.
- **Why:** The diagram is a joint pair-draft artifact currently under operator review (T-2618). The rail's job is to surface divergence; closing it by redrawing a reviewed diagram unilaterally would invert the sovereignty of the review. WARN is the honest steady-state until the next pair round.
- **Rejected:** (a) Save v6 with the 2 flows now — green rail but stale review; (b) exclude those transitions from the canonical set — hides real enforcement.

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

### 2026-07-25T16:43:07Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2621-map-conformance-audit-leg--task-lifecycl.md
- **Context:** Initial task creation

### 2026-07-26T20:22:45Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-d95a47f0
- **Timestamp:** 2026-07-26T20:30:46Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#1 (Agent)** — `fw audit` structure section gains a map-conformance check (`check_map_conformance` in agents/audit/audit.sh, thin wrapper over `tools/corpus_conformance.py`): PASS when aligned, WARN listing each div
  - **AC-verify-mismatch** (narrow, heuristic) — `path=agents/audit/audit.sh in: `fw audit` structure section gains a map-conformance check (`check_map_conformance` in agents/audit/audit.sh, thin wrapper over `tools/corpus_conforma`

### 2026-07-26T20:30:42Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
