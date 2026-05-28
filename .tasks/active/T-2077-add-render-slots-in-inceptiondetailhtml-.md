---
id: T-2077
name: "add render slots in inception_detail.html for Context/RCA/AC/Verification/Decisions
  (T-2066 GO scope)"
description: >
  Implements T-2066 inception GO. Symptom: /inception/T-XXXX Watchtower page shows
  only Problem Statement / Exploration Plan / Recommendation — silently drops Context,
  RCA, Acceptance Criteria, Verification, and Decisions sections that the task body
  contains. Fix (option a): add render slots + matching Jinja blocks for the missing
  sections; mirror the shape of task_detail.html so the same section set surfaces
  on both inception and task pages. ACs: 5 new sections rendered when present in task
  body, gracefully skipped when absent, [REVIEW] Human AC required (render-surface
  gate T-1766 — touches web/templates/inception_detail.html), Playwright test covers
  presence/absence cases for each section.

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
created: 2026-05-28T18:04:21Z
last_update: 2026-05-28T18:40:02Z
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
  - ts: '2026-05-28T18:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-05-28T18:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2077: add render slots in inception_detail.html for Context/RCA/AC/Verification/Decisions (T-2066 GO scope)

## Context

Implements T-2066 GO scope: `/inception/<id>` was extracting Context, RCA, Acceptance Criteria, Verification, and Decisions into `all_raw_sections` and tagging them as `KNOWN_SECTIONS` (excluding them from generic render), but the `sections` dict passed to the template never received those keys — so they dropped on the floor. Five new section-card blocks in the template + five new dict keys in the blueprint close the gap. Conditional `{% if sections.<key> %}` rendering means empty sections produce zero DOM noise.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `web/blueprints/inception.py` `sections` dict (line ~351) extends with 5 new keys: `context`, `acceptance_criteria`, `verification`, `decisions`, `rca` — each populated from the matching `all_raw_sections` entry via `_md()`.
- [x] `web/templates/inception_detail.html` renders 5 new `<article class="section-card">` blocks gated by `{% if sections.<key> %}` — placement: Context after Problem Statement, Acceptance Criteria + Verification + Decisions after Go/No-Go Criteria, RCA after Structural Upgrade. Each section is conditional so empty sections produce zero DOM noise.
- [x] Playwright test `tests/playwright/test_inception_detail_sections.py` asserts: (a) all 5 sections + content sentinels visible on populated body, (b) none of the 5 headers render on empty body. Uses temp `.tasks/completed/T-99977.md` + `T-99978.md` fixtures.
- [x] `python3 -m pytest tests/playwright/test_inception_detail_sections.py` passes — 2/2 green in ~24s.

### Human
- [ ] [REVIEW] The 5 new sections (Context / Acceptance Criteria / Verification / Decisions / RCA) sit cleanly in the page rhythm — no jarring layout breaks, headers visually match the existing section-card headers (Problem Statement / Exploration Plan / etc.).
  **Steps:**
  1. Open http://192.168.10.107:3000/inception/T-2077 (this very task — note the body has all 5 sections populated)
  2. Scroll through the page. Confirm Context appears right after Problem Statement; Acceptance Criteria / Verification / Decisions appear after Go/No-Go Criteria; RCA appears after Structural Upgrade (or at end if no Structural Upgrade).
  3. For comparison, open http://192.168.10.107:3000/inception/T-2066 — sections that aren't filled (Context / RCA / Decisions on that task) should NOT render headers (empty sections are skipped, not displayed as blank).

  **Expected:** Section ordering reads naturally — early framing (Context) up top, gating/verification mid-page, post-mortem (RCA) near end. Header typography and spacing match existing section-cards.

  **If not:** Note which section's placement feels off and what visual element is broken (header size, spacing, indentation, or content typography).

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.
python3 -c "import ast; ast.parse(open('web/blueprints/inception.py').read())"
out=$(python3 -m pytest tests/playwright/test_inception_detail_sections.py -q 2>&1); echo "$out" | tail -3 | grep -q "passed"
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

## Recommendation

**Recommendation:** GO (complete)

**Rationale:** The fix is minimal and structurally symmetric — 5 lines added to the blueprint's `sections` dict + 5 conditional Jinja blocks in the template, mirroring the section set already on `task_detail.html`. Conditional rendering means existing inceptions (none of which use these sections) render identically to before; only inceptions that populate the new sections show them. Playwright coverage asserts both directions of the conditional (present + absent). One [REVIEW] AC remains for visual rhythm — a render-surface change requires eyes.

**Evidence:**
- `web/blueprints/inception.py` `sections` dict gains 5 keys (`context`, `acceptance_criteria`, `verification`, `decisions`, `rca`) backed by the matching `all_raw_sections` entry via `_md()`.
- `web/templates/inception_detail.html` gains 5 `<article class="section-card">` blocks gated by `{% if sections.<key> %}`. Placement: Context after Problem Statement; AC + Verification + Decisions after Go/No-Go Criteria; RCA after Structural Upgrade.
- `tests/playwright/test_inception_detail_sections.py`: 2 tests, both green in ~24s. Positive case asserts all 5 headers + 5 content sentinels; negative case asserts none of the 5 headers render on an empty body.
- Live smoke: `/inception/T-2066` (this very inception's parent) renders **Acceptance Criteria** + **Verification** headers (the only 2 of the 5 it has populated). Context / RCA / Decisions are absent because T-2066's body has no non-stub content for them — correct conditional behaviour.
- All 4 verification commands pass.

### 2026-05-28T18:04:21Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2077-add-render-slots-in-inceptiondetailhtml-.md
- **Context:** Initial task creation

### 2026-05-28T18:40:02Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
