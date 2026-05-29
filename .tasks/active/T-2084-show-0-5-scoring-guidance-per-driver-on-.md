---
id: T-2084
name: "show 0-5 scoring guidance per driver on /bvp (hover tooltip / expand)"
description: >
  show 0-5 scoring guidance per driver on /bvp (hover tooltip / expand)

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
created: 2026-05-29T07:38:45Z
last_update: '2026-05-29T07:45:03Z'
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
bvp_scores_proposed:
  - ts: '2026-05-29T07:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F1: 1
      F2: 1
      F3: 0
    rationale: "D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 (body:component-discoverability);
      D4=2 (body:env-class-handled); F1=1 (body/tag hits for 'F1': 1); F2=1 (body/tag
      hits for 'F2': 1); F3=0 (no-signal)"
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-05-29T07:45:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2084: show 0-5 scoring guidance per driver on /bvp (hover tooltip / expand)

## Context

User asked: "can we show the scoring guidance (0-5) for the BVP drivers (e.g. on hover popup?) http://192.168.10.107:3000/bvp". `policy/bvp-scoring-rubric.md` already contains per-driver 0-5 score tables (D1–D4 + free drivers F1+). The /bvp slider rows currently show only driver id + name (T-2080), with no inline guidance on what each score means. Surface the rubric on hover/click so the human can score without context-switching to the rubric file.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `web/blueprints/bvp.py` adds `_driver_rubrics(policy)` returning `{driver_id: [str_for_score_0, ..., str_for_score_5]}` parsed from `policy/bvp-scoring-rubric.md` (regex on `## Dn — …` / `## Fn — …` headings + `### Score criteria` table; matches existing `_driver_names()` shape). Free drivers F1+ additionally parsed from their `value-drivers.yaml` `rationale` field's inline 0-5 enumeration.
- [x] Rubrics passed to `bvp.html` template as `driver_rubrics={...}` alongside `driver_names`. Driver IDs in the policy but missing from the rubric file degrade gracefully (no popup, no template crash).
- [x] `web/templates/bvp.html` renders the rubric on each slider row — chose `<details><summary>(?)</summary><ol>…</ol></details>` over Pico `data-tooltip` because the 6-line content would not fit in a single-line tooltip. Each rendered expand block contains all 6 score levels (0..5) verbatim from the rubric. 6/6 driver rows (D1-D4, F1, F2) now render the expand block.
- [x] `bvp_driver_remove` + `bvp_driver_add` paths still work — Playwright `tests/playwright/test_bvp_form_htmx.py` 5/5 green post-change.
- [x] Unit test `tests/unit/test_driver_rubrics.py` — 6 tests covering D1-D4 six-level coverage, D1 score-5 substring pin, unknown driver returns empty, free-driver inline rationale parse, empty-policy no-crash. All green in 0.18s.

### Human
- [ ] [REVIEW] The 0-5 scoring guidance is accessible without leaving /bvp and reads cleanly per driver.
  **Steps:**
  1. Open http://192.168.10.107:3000/bvp
  2. On each driver row in the sliders table, hover (or click — whichever pattern shipped) the rubric trigger element (`(?)` icon, "rubric" link, or `<summary>`).
  3. Confirm all 6 score levels (0 through 5) are visible verbatim — none truncated or hidden behind scroll.
  4. Spot-check D1 (Antifragility) — score 5 should read like "Changes the *class* of behavior the driver protects against (new structural mechanism)".
  5. Open the free-driver F1 entry the same way — confirm its rubric also surfaces.

  **Expected:** Hover/click reveals the 6 rubric levels per driver, readable inline, no page reflow that breaks the slider layout. Free drivers F1+ behave identically to D1-D4.

  **If not:** Note which driver's tooltip/expand failed and whether the issue was content (missing levels) or layout (tooltip clipped, slider misaligned, etc.).

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
python3 -c "import ast; ast.parse(open('web/blueprints/bvp.py').read())"
out=$(python3 -m pytest tests/unit/test_driver_rubrics.py -q 2>&1); echo "$out" | tail -3 | grep -q "passed"
curl -sf "$(bin/fw watchtower url)/bvp" > /tmp/.t2084-bvp; grep -qE 'data-tooltip|<details' /tmp/.t2084-bvp
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

**Recommendation:** GO (complete)

**Rationale:** Minimal, additive change: one helper in `bvp.py` (~50 LOC, two parse paths covering protected + free drivers), one expand block in `bvp.html` (~9 LOC, gated on `{% if driver_rubrics[d_id] %}`). The 6-line content rules out a single-line tooltip — `<details>` was the right shape (no JS, accessible, no Pico dependency). All 6 drivers (D1–D4, F1, F2) now surface their rubric inline; the slider mutation flow (add/remove/commit) is untouched and the existing Playwright suite (5/5) still passes. One `[REVIEW]` Human AC pending for visual rhythm — render-surface gate (T-1766).

**Evidence:**
- `web/blueprints/bvp.py`: `_driver_rubrics(policy)` + `RUBRIC_PATH = policy/bvp-scoring-rubric.md`. Parses D1-D4 from rubric tables, F1+ from `value-drivers.yaml` rationale (handles "0 — desc", "1–2 — desc" en-dash range, ascii hyphen range).
- `web/templates/bvp.html`: `<details class="driver-rubric"><summary>(?)</summary><ol start="0">…</ol></details>` next to each driver's name span. Native `<details>` = keyboard-accessible, no JS dependency.
- `tests/unit/test_driver_rubrics.py`: 6 tests, all green in 0.18s.
- `tests/playwright/test_bvp_form_htmx.py`: 5/5 green (regression: add/remove/commit forms unaffected).
- Live `curl /bvp`: 279,536 bytes, contains 6× `class="driver-rubric"` block (one per driver), D1's score 5 row reads "Changes the *class* of failure…", F1 score 0 reads "produces no durable artifact…".
- All 3 Verification commands pass.

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

### 2026-05-29T07:38:45Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2084-show-0-5-scoring-guidance-per-driver-on-.md
- **Context:** Initial task creation
