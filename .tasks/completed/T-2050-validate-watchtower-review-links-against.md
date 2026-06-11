---
id: T-2050
name: "validate Watchtower review links against app.url_map at fw task review (T-2030
  GO)"
description: >
  T-2030 GO follow-on. At fw task review time, extract Watchtower URLs from the task's
  ## Recommendation Evidence and Human-AC Steps, validate each path against web.app.app.url_map
  (parameterless resolved directly; parameterised HTTP-probed). WARN on unresolvable
  path (e.g. /appearance 404 vs real /settings/appearance). Reuse T-2042 discover_get_routes().
  Keep curl-before-paste as advisory backstop. OUT: external URLs, screenshot-existence,
  prose quality. Unit test: bad path fails, good path passes.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [watchtower, review]
components: [lib/review.sh, lib/review_link_validator.py]
related_tasks: [T-2030, T-2042]
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-25T19:50:47Z
last_update: '2026-06-11T22:24:06Z'
date_finished: 2026-05-25T23:38:35+02:00
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
  - ts: '2026-05-25T20:00:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-29T09:45:04Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 2
      effort: 8
    rationale: blast_radius=3 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-05-25T20:00:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:24:06Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2050: validate Watchtower review links against app.url_map at fw task review (T-2030 GO)

## Context

T-2030 GO follow-on (candidate C: app.url_map validation). Agents have pasted
review links to non-existent routes (`/appearance` 404 vs the real
`/settings/appearance`), so the human gets a dead link at review time — the
recurring "useless for me i need concrete links" pain. Fix: at `fw task review`
time, extract Watchtower URLs from the task's `## Recommendation` and `### Human`
AC Steps, validate each path against `web.app.app.url_map`, and WARN on any path
that resolves to nothing. Advisory only (never blocks the review). Reuses T-2042's
`discover_get_routes()` for the parameterless set; HTTP-probes parameterised paths.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `lib/review_link_validator.py` extracts internal Watchtower paths from a task's `## Recommendation` + `### Human` AC Steps; external (non-base_url) URLs are ignored — unit test
- [x] A path in the parameterless route set (`discover_get_routes()`) validates OK; an unresolvable path (e.g. `/appearance`) emits WARN — unit test (bad fails, good passes) + live: `/appearance`→404 WARN, `/settings/appearance`→OK
- [x] Parameterised paths (e.g. `/review/T-XXX`) are HTTP-probed: 404 → WARN, non-404 → OK; server/Flask unavailable → non-blocking advisory (curl-before-paste backstop) — unit test with injected probe
- [x] `lib/review.sh emit_review()` invokes the validator and prints WARN lines before the review URL; validation never blocks `fw task review` (always exit 0) — verified live (`fw task review T-2050` clean, exit 0)
- [x] Out-of-scope honored: external URLs, screenshot existence, and prose quality are NOT checked — unit test asserts external URL skipped
- [x] `python3 -m py_compile lib/review_link_validator.py` passes, new pytest green (10 passed), `bash -n lib/review.sh` passes

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
python3 -m py_compile lib/review_link_validator.py
bash -n lib/review.sh
python3 -m pytest tests/unit/test_review_link_validator.py -q

## RCA

**Symptom:** Agents paste Watchtower review links to routes that don't exist
(`/appearance` → 404; the real page is `/settings/appearance`), so the human
clicks a dead link at review time ("useless for me i need concrete links").

**Root cause:** `fw task review` emits whatever URL the agent wrote in the task,
with no check that the path actually resolves against the app's route table. The
only guard was the agent's own discipline ("curl before paste"), which is exactly
the thing that fails under autonomy.

**Why structurally allowed:** the review-emission path (`lib/review.sh:emit_review`)
treated review URLs as opaque strings. The app already knows every valid route
(`app.url_map`), but that knowledge was never consulted at emission time.

**Prevention:** `lib/review_link_validator.py` consults `app.url_map` (via T-2042's
`discover_get_routes()` + an HTTP probe for parameterised routes) at `fw task review`
time and WARNs on unresolvable paths, so a wrong path is surfaced before the human
ever sees it. Pinned by `tests/unit/test_review_link_validator.py` (bad path WARNs,
good path passes).

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

### 2026-05-25T19:50:47Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2050-validate-watchtower-review-links-against.md
- **Context:** Initial task creation

### 2026-05-25T21:31:34Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-a4da2758
- **Timestamp:** 2026-06-02T15:00:53Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
