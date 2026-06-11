---
id: T-1938
name: "BVP T-1937 sibling — fw bvp / fw bvp T-XXX cost include proposed fallback"
description: >
  BVP T-1937 sibling — fw bvp / fw bvp T-XXX cost include proposed fallback

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [arc:value-prioritisation, parity]
components: [lib/bvp.sh, tests/playwright/test_arc_detail_bvp.py, 
      tests/unit/test_bvp_scatter_arc_mode.py, web/blueprints/bvp.py, 
      web/templates/bvp.html]
related_tasks: [T-1937, T-1936, T-1934, T-1935, T-1919]
arc_id: value-prioritisation
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-19T19:59:47Z
last_update: '2026-06-11T22:24:03Z'
date_finished: 2026-05-20T18:22:40Z
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
  - ts: '2026-05-19T20:00:01Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:24:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); 
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-05-19T20:00:01Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1938: BVP T-1937 sibling — fw bvp / fw bvp T-XXX cost include proposed fallback

## Context

T-1937 closed CLI/web parity for `fw bvp arcs` (arc-level rollup). Two
sibling drifts remain on task-level surfaces in `lib/bvp.sh`:

1. **`cmd_rank`** (the bare `fw bvp` verb) reads only direct `bvp_scores:`
   and skips all 57+ tasks carrying `bvp_scores_proposed:`. Result:
   "No tasks have bvp_scores: set yet" — same root cause as T-1937
   (silent-corpus-migration, L-329/T-1850 cluster).
2. **`cmd_detail`** cost block reads only `cost_estimate:` and prints
   "cost_estimate: absent" for tasks carrying `cost_estimate_proposed:`
   (the BVP score block already handles proposed fallback correctly —
   only the cost section drifted).

Sovereignty boundary calibration: web `/bvp` shows proposed by default
because the visual context makes provenance obvious (T-1934 `cost_source`
suffix). CLI lacks that affordance. So `cmd_rank` should:
- Default to confirmed-only (sovereignty-conservative)
- Add `--include-proposed` flag for explicit opt-in
- Stamp source column so the user sees provenance

`cmd_detail` cost section is different — single-task detail-view context
already signals "advisory" via the existing `PROPOSED (advisory)` label
on the score block. Cost section can mirror that: show proposed cost
when confirmed is absent, labelled `PROPOSED (estimator)` like the score
block already does.

## Acceptance Criteria

### Agent
- [x] `cmd_rank` accepts `--include-proposed` flag; without it, only confirmed-score tasks rank (sovereignty-conservative default)
- [x] When `--include-proposed` is set, `cmd_rank` falls back to `bvp_scores_proposed:` for tasks lacking confirmed scores
- [x] `cmd_rank` row output includes a `SOURCE` column (`confirmed` / `proposed`) when proposed are included
- [x] `cmd_detail` cost section falls back to `cost_estimate_proposed:` when `cost_estimate:` is absent, labelled `PROPOSED (estimator)` parallel to the score block convention
- [x] `bin/fw bvp --include-proposed 2>&1 | grep -E "^T-1937"` returns at least one row (T-1937 has proposed scores set by the v1 cron sweep)
- [x] `bin/fw bvp T-1937 2>&1 | grep -q "PROPOSED.*estimator"` shows the cost section now reads proposed
- [x] Unit tests in `tests/unit/test_bvp_cli_rank_proposed.py` cover: confirmed-only default, --include-proposed opt-in, source column distinction, cost detail proposed fallback
- [x] All new tests PASS; existing CLI BVP tests still PASS (`unit/test_bvp_cli_arcs_rollup.py`, `unit/test_bvp_estimator.py`, `unit/test_bvp_blueprint_cost.py`)

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
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

cd /opt/999-Agentic-Engineering-Framework/tests && python3 -m pytest unit/test_bvp_cli_rank_proposed.py unit/test_bvp_cli_arcs_rollup.py unit/test_bvp_estimator.py unit/test_bvp_blueprint_cost.py -q
out=$(cd /opt/999-Agentic-Engineering-Framework && bin/fw bvp --include-proposed 2>&1); echo "$out" | grep -q "^T-1937"
out=$(cd /opt/999-Agentic-Engineering-Framework && bin/fw bvp T-1937 2>&1); echo "$out" | grep -q "PROPOSED.*estimator"

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

## Recommendation

**Recommendation:** GO

**Rationale:** Two task-level CLI drift sites closed. `fw bvp`
(rank) gains `--include-proposed` opt-in; default remains
confirmed-only (sovereignty-conservative). `fw bvp T-XXX` (detail)
cost section falls back to `cost_estimate_proposed:` parallel to
the score block which already did so — closing the last drift in
this file. Help text now nudges users toward the flag when no
confirmed scores exist yet. 8/8 new tests + 75 sibling tests PASS.

**Evidence:**
- `bin/fw bvp --include-proposed` ranks 71 tasks with SOURCE column (proposed/confirmed)
- `bin/fw bvp T-1937` shows `Cost components (PROPOSED (estimator))` with composite 2.00
- 83/83 BVP tests PASS — full file suite green
- Sovereignty preserved: bare `fw bvp` (no flag) still says "No tasks have bvp_scores: set yet" with help-text nudge

## Evolution

### 2026-05-19 — scope-root pattern applied successfully

- **What changed:** After shipping T-1937 (arc rollup parity), grep-swept `lib/bvp.sh` for sibling drifts before declaring done. Found two: cmd_rank ignored proposed entirely; cmd_detail cost ignored proposed even though detail's score block already handled it.
- **Plan impact:** No need for a future "T-1939 sibling-of-sibling" — full file parity reached.
- **Triggered:** This task (T-1938). Applied "scope root, not symptom" (memory rule from T-1871 → T-1873 origin) — same file, same anti-pattern, fixed together.

## Decisions

### 2026-05-19 — --include-proposed flag vs always-on

- **Chose:** Opt-in flag.
- **Why:** CLI lacks the visual affordance the web `/bvp` scatter has for distinguishing proposed (color/opacity). Always-on would silently mix advisory + confirmed in a flat table — bad sovereignty signal. Opt-in keeps the bare `fw bvp` output sovereignty-clean.
- **Rejected:** Always-on (mirrors web) — would create the very confusion the sovereignty boundary exists to prevent.

### 2026-05-19 — SOURCE column only when --include-proposed

- **Chose:** Conditional column.
- **Why:** Bare `fw bvp` already implies confirmed-only; an unused SOURCE column would just take screen width and confuse the table. Conditional rendering preserves the slim default output.
- **Rejected:** Always render — taxes the common case for no benefit.

### 2026-05-19 — cmd_detail cost label `PROPOSED (estimator)` matches score block

- **Chose:** Same label shape as the existing `PROPOSED (advisory)` score block label.
- **Why:** Reader's mental model is already calibrated — `PROPOSED (...)` means estimator/advisory at this file. Keeps reader from having to learn a second convention.
- **Rejected:** Inventing a new label like `[ADVISORY]` — would fragment the convention within a single command's output.

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

### 2026-05-19T19:59:47Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1938-bvp-t-1937-sibling--fw-bvp--fw-bvp-t-xxx.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-c8132b52
- **Timestamp:** 2026-06-02T15:00:33Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#7 (Agent)** — Unit tests in `tests/unit/test_bvp_cli_rank_proposed.py` cover: confirmed-only default, --include-proposed opt-in, source column distinction, cost detail proposed fallback
  - **AC-verify-mismatch** (narrow, heuristic) — `path=tests/unit/test_bvp_cli_rank_proposed.py in: Unit tests in `tests/unit/test_bvp_cli_rank_proposed.py` cover: confirmed-only default, --include-proposed opt-in, source column distinction, cost det`
### 2026-05-20T18:22:40Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
