---
id: T-1974
name: "Playwright test_bvp_page_shows_driver_weights_section stale — expects details/summary
  but T-1929 made sliders always-visible"
description: >
  Playwright test_bvp_page_shows_driver_weights_section stale — expects details/summary
  but T-1929 made sliders always-visible

status: work-completed
workflow_type: build
owner: agent
horizon: now
tags: []
components: [tests/playwright/test_bvp_scatter.py]
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-21T07:14:16Z
last_update: 2026-05-21T07:17:09Z
date_finished: 2026-05-21T07:17:09Z
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
  - ts: '2026-05-21T07:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-05-21T07:15:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
---

# T-1974: Playwright test_bvp_page_shows_driver_weights_section stale — expects details/summary but T-1929 made sliders always-visible

## Context

`tests/playwright/test_bvp_scatter.py::test_bvp_page_shows_driver_weights_section` (line 32-36) fails:

```
expect(page.locator("summary", has_text="Current driver weights")).to_be_visible()
```

The test was written for the T-1928 read-only design where weights were behind a `<details>/<summary>` collapse. T-1929 (live weight sliders, shipped) moved weights to a permanently-visible `<section id="bvp-sliders">` with `<h3>Live weight sliders</h3>` — strictly more visible than before, but the test selector breaks.

Test intent ("weights are load-bearing — surface them somewhere visible") is still right; the assertion just needs to match the T-1929 design.

## Acceptance Criteria

### Agent
- [x] Test selector updated to match T-1929 design (asserts `section#bvp-sliders`, `h3` "Live weight sliders", ≥4 range inputs)
- [x] Test intent preserved (still asserts driver weights are visible)
- [x] Updated test passes against live /bvp (verified: 7/7 in `test_bvp_scatter.py`)
- [x] Other 6 tests in the same module still pass (full module: 7 passed, 0 failed)

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

# Re-run the touched test module
python3 -m pytest tests/playwright/test_bvp_scatter.py -q 2>&1 | tail -3 > /tmp/.t1974-pytest.out
grep -q "7 passed" /tmp/.t1974-pytest.out

## RCA

**Symptom:** `test_bvp_page_shows_driver_weights_section` failed: `expect(page.locator("summary", has_text="Current driver weights")).to_be_visible()` timed out — element not found.

**Root cause:** Test was written for the T-1928 read-only `/bvp` design where weights lived inside a `<details>/<summary>` collapse. T-1929 (live sliders, shipped) moved weights to a permanently-visible `<section id="bvp-sliders">`. The implementation change improved visibility; the test selector wasn't updated.

**Why structurally allowed:** No coupling between template-change tasks (T-1929) and existing UI tests. The Playwright module exists, but T-1929 only added new tests for the sliders (e.g. `test_bvp_sliders.py`) — it didn't audit existing /bvp tests for stale selectors. Same anti-pattern class as T-1971/T-1972/T-1973: substrate evolved, satellite text/tests didn't follow.

**Prevention:** Run the affected Playwright module as part of any task that edits `web/templates/bvp.html` or `web/blueprints/bvp.py` — should be in `## Verification`. Stretching further: a periodic "Playwright drift" audit that flags tests whose selectors don't match any current DOM element would catch this class. Filed as a follow-up consideration if the pattern recurs (one instance now; threshold is 3+ for codification).

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

### 2026-05-21T07:14:16Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1974-playwright-testbvppageshowsdriverweights.md
- **Context:** Initial task creation

## Recommendation

**Recommendation:** GO

**Rationale:** Stale-test fix in the same anti-pattern family as T-1971/T-1972/T-1973 (substrate shipped, satellite text/test didn't follow). Test now asserts the post-T-1929 structure, intent preserved. Full module green.

**Evidence:**
- `tests/playwright/test_bvp_scatter.py:32-46` rewritten: asserts `section#bvp-sliders`, h3 text, ≥4 range inputs
- 7/7 tests pass in the module (was 1 failed / 6 passed)
- No template changes — pure test alignment

## Reviewer Verdict (v1.4)

- **Scan ID:** R-e41a0615
- **Timestamp:** 2026-05-21T07:17:38Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-05-21T07:17:09Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
