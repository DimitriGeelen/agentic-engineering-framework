---
id: T-2056
name: "Fix stale preset-nav unit tests + T-2011 verification after T-2033 human-decided
  decouple"
description: >
  T-2033 decoupled nav from presets (human AskUserQuestion decision: presets set palette/type/density/mode
  only, nav is an independent axis). It changed web/blueprints/settings.py line 79
  to drop 'nav' from preset-applied keys, but left 3 unit tests in tests/unit/test_nav_layouts.py
  (test_every_preset_carries_a_valid_nav, test_console_is_sidebar_midnight_is_rail,
  test_sanitise_preset_sets_its_nav) + the docstring guarantee #2 + T-2011's Verification
  block asserting the dead coupling. Suite is RED; T-2011 cannot complete. Fix: align
  the tests/docstring/verification to the decoupled contract. Found while closing
  shipped-but-unclosed arc-007 slices (L-434).

status: work-completed
workflow_type: build
owner: agent
horizon: now
tags: [watchtower, redesign, ui, nav, test-drift]
components: [C-004, lib/render_surface.sh, tests/unit/test_audit_completable_not_completed.bats, tests/unit/test_nav_layouts.py, tests/unit/test_render_surface_gate.bats]
related_tasks: [T-2011, T-2033]
arc_id: watchtower-redesign
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-25T22:50:42Z
last_update: 2026-05-28T11:47:03Z
date_finished: 2026-05-28T11:47:03Z
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
  - ts: '2026-05-25T22:50:53Z'
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
  - ts: '2026-05-25T23:00:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2056: Fix stale preset-nav unit tests + T-2011 verification after T-2033 human-decided decouple

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `tests/unit/test_nav_layouts.py` is green — the 3 stale preset↔nav tests are replaced with decoupled-contract assertions (presets do NOT carry `nav`; preset selection leaves nav at its default/explicit value). (11 passed)
- [x] The test-module docstring guarantee #2 describes the T-2033 decoupled contract, not the dead "presets bind nav" coupling.
- [x] T-2011's `## Verification` block no longer asserts `all('nav' in preset)` or `preset→nav` binding — it matches the decoupled contract so T-2011 can complete.
- [x] No production behaviour change — `web/blueprints/settings.py` is untouched (this is a test/contract-doc drift fix only); the decouple itself shipped in T-2033. (`git diff --quiet` confirms)

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

python3 -m pytest tests/unit/test_nav_layouts.py -q
# presets must NOT carry nav (decoupled contract)
python3 -c "from web.blueprints import settings as s; assert all('nav' not in p for p in s.PRESETS.values()), 'a preset still carries nav'; print('decoupled OK')"
# preset selection leaves nav at default; explicit nav still honoured
python3 -c "from web.blueprints.settings import _sanitise_appearance as f; assert f({'preset':'console'})['nav']=='topbar'; assert f({'preset':'calm','nav':'rail'})['nav']=='rail'; print('nav-independent OK')"
# production settings.py unchanged by this task
git diff --quiet HEAD -- web/blueprints/settings.py && echo "settings.py untouched"

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

**Symptom:** `tests/unit/test_nav_layouts.py` is RED (3 failures: `test_every_preset_carries_a_valid_nav`, `test_console_is_sidebar_midnight_is_rail`, `test_sanitise_preset_sets_its_nav`), and T-2011's `--status work-completed` is blocked because its `## Verification` asserts the same dead contract. Discovered while completing the shipped-but-unclosed T-2011 nav-layout slice (L-434 sweep).

**Root cause:** T-2033 (commit `d71a59cd`) implemented a human-decided decouple (AskUserQuestion: "presets set palette/type/density/mode only; nav is an independent axis") by removing `nav` from the preset-applied key tuple in `settings.py:79`. The contract change was correct and complete in production code, but the **sibling slice's tests + verification + docstring were not updated** in the same change. The old assertions (every preset carries `nav`; console→sidebar, midnight→rail; preset selection sets nav) now contradict the shipped behaviour.

**Why structurally allowed:** Two gaps. (1) T-2033 shipped a contract change without a same-commit sweep of the contract's existing tests/docs — the §ACD spec-vs-build divergence wasn't propagated to the test surface. (2) T-2033 itself was never run through `--status work-completed` (it sat in started-work — the L-434 shipped-but-unclosed class), so its own verification gate never re-ran the now-stale `test_nav_layouts.py` to surface the red. The red suite stayed invisible until this completion sweep tried T-2011.

**Prevention:** L-434's detector (T-2055) catches the unclosed-slice half — had T-2033 been completed, its gate would have re-run the suite and caught the red immediately. The contract-change-without-test-sweep half is the same class as L-417 (stale-slice-reference): when a later task changes a contract, grep the contract's test/doc surface in the same change. Captured as a learning here.

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

### 2026-05-26 — stale tests surfaced by the L-434 unclosed-slice sweep
- **What changed:** This task was not planned — it emerged from completing the 35 shipped-but-unclosed arc-007 slices (L-434). T-2011's verification gate failed, revealing that T-2033's human-decided preset↔nav decouple had left a red `test_nav_layouts.py` invisible for ~2 days (T-2033 never completed, so its gate never re-ran the suite).
- **Plan impact:** confirms the two-part nature of L-434 — unclosed slices aren't just an admin gap, they suppress the verification gates that would surface regressions in sibling code. The cost of leaving slices in started-work is hidden red suites.
- **Triggered:** this task (T-2056); reinforces T-2055 (the unclosed-slice detector) as the structural prevention.

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

### 2026-05-25T22:50:42Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2056-fix-stale-preset-nav-unit-tests--t-2011-.md
- **Context:** Initial task creation

### 2026-05-25T22:50:53Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-adba2336
- **Timestamp:** 2026-05-28T11:47:05Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-05-28T11:47:03Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
