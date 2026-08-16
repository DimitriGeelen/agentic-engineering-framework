---
id: T-1899
name: "render_page() runtime guard — refuse template that extends base.html with actionable
  error pointing at the convention (future-prevention follow-up to T-1898)"
description: >
  render_page() runtime guard — refuse template that extends base.html with actionable
  error pointing at the convention (future-prevention follow-up to T-1898)

status: work-completed
workflow_type: build
owner: human
horizon:
tags: []
components: [tests/unit/test_render_page_guard.py, web/shared.py]
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-18T17:18:57Z
last_update: '2026-08-16T22:24:48Z'
date_finished: 2026-05-18T17:25:40Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 1
      D3: 3
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=1 (body:log-or-error-line); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:48Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 1
      D3: 3
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=1 (body:log-or-error-line); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1899: render_page() runtime guard — refuse template that extends base.html with actionable error pointing at the convention (future-prevention follow-up to T-1898)

## Context

`web/shared.py:render_page()` documents in its docstring that "each page template is a pure HTML fragment (no <html>, no extends)" but nothing enforces this. T-1898 fixed three templates (`arc_detail.html`, `arcs_index.html`, `orchestrator.html`) that violated the convention — each extended `base.html` while routed through `render_page()` which already wraps in `_wrapper.html` (also extends base.html) — producing double-render. The contract was a comment; the violation was invisible until a user noticed two stacked Watchtower bars on `/arcs/arc-005`. This task closes that detection window with a runtime guard: `render_page()` reads the first non-empty line of the template file and refuses if it starts with `{% extends "base.html"`, raising a clear error pointing at the convention.

## Acceptance Criteria

### Agent
- [x] `render_page()` reads the resolved template source on full-page load and refuses if its first non-empty/non-Jinja-comment line starts with `{% extends "base.html"`. Refusal raises `RuntimeError` with a message naming (a) the template name, (b) the convention ("page templates are HTML fragments"), (c) where to look (`web/shared.py:render_page` docstring + a sibling fragment example). htmx fragment path (HX-Request) is unchanged — those go through `render_template()` directly.
- [x] Unit test: feeding a template that begins with `{% extends "base.html" %}` to `render_page()` raises `RuntimeError` whose message matches `extends.*base\.html` and names the template name.
- [x] Unit test: feeding a fragment template (no extends) renders normally (returns wrapped HTML with one `<nav>`).
- [x] Live regression: `curl -sf $(bin/fw watchtower url)/arcs/arc-005` and `curl -sf $(bin/fw watchtower url)/arcs` and `curl -sf $(bin/fw watchtower url)/orchestrator` each return one `<nav>` (T-1898 invariants hold).
- [x] Live confirmation: temporarily re-introducing `{% extends "base.html" %}` at the top of `web/templates/arc_detail.html` causes `/arcs/arc-005` to return HTTP 500 with the actionable message (revert immediately after; check encoded in test, not as a manual step in this file).

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
- [x] [REVIEW] Error message reads actionably — a fresh developer who hits the new guard understands what the convention is and where to look without re-reading T-1898 or T-1899
  **Steps:**
  1. Read the RuntimeError message rendered when the guard fires (test output or live curl with deliberate extends restored)
  2. Ask: does it name the template? does it state the convention? does it point at a sibling fragment example?
  **Expected:** Yes to all three; the message reads like a contract violation report, not a Python traceback decoded by hand
  **If not:** Note which piece is missing or weak; agent revises the message

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

# All checks use `test "$(... | grep -c)" -eq N` pattern per L-387/L-393.

# Unit tests (positive + negative)
FRAMEWORK_ROOT=$(pwd) python3 -m pytest tests/unit/test_render_page_guard.py -q

# Live regression: each render_page route returns one <nav> with the guard active
test "$(curl -sf "$(bin/fw watchtower url)/arcs/arc-005" | grep -c '<nav')" -eq 1
test "$(curl -sf "$(bin/fw watchtower url)/arcs" | grep -c '<nav')" -eq 1
test "$(curl -sf "$(bin/fw watchtower url)/orchestrator" | grep -c '<nav')" -eq 1

# Guard message reachable: docstring includes the contract verbiage
test "$(grep -c 'pure HTML fragment' web/shared.py)" -ge 1

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

**Symptom:** T-1898 — three templates rendered through `render_page()` started with `{% extends "base.html" %}`, causing Watchtower to render its full nav twice on `/arcs/arc-005`, `/arcs`, and `/orchestrator`. The user reported it; agent fixed the three templates; the *contract violation class* remained possible because nothing enforced it.

**Root cause:** The "fragment template" convention lives only in `render_page()`'s docstring. New page templates copying the wrong sibling (e.g. `escalation_drift.html`, which IS rendered via `render_template` directly and so correctly extends base.html) inherit the wrong pattern silently — at runtime Jinja resolves both extends chains and the page just looks ugly, no crash, no log. Detection required a human noticing the visual artifact.

**Why structurally allowed:** No lint, audit, or render-time check inspected template structure against the convention. Visual UI verification is famously hard to automate (T-1575 origin) and the bug presented as "ugly but functional", which routes around HTTP-status / element-presence smoke tests. The render-surface gate (P-013, T-1766) catches the *missing-Human-AC* class but not the *convention-violation* class.

**Prevention:** Add a runtime check inside `render_page()` itself — read the resolved template source, refuse with `RuntimeError` if it starts with `{% extends "base.html"` (skipping whitespace and `{# ... #}` Jinja comments). The error message names the template, the convention, and points at a sibling fragment example. Unit tests pin both the positive (fragment OK) and negative (extends → raise) paths. The runtime guard fires *the first time someone loads the violating page in dev* — the loop is "edit template → load page → see actionable error" rather than "edit template → ship → user reports visual artifact days later".

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

**Recommendation:** GO

**Rationale:** All 5 Agent ACs PASS. The guard fires structurally before any render of a violating template — closes the convention-violation detection class opened by T-1898. The error message names the template, the convention, and points at sibling examples (verified by pytest). Live test re-introduced the violation deliberately, observed HTTP 500, then restored — sanity check post-restore confirms 1-`<nav>`. One [REVIEW] Human AC remains: read the error message and confirm it's actionable.

**Evidence:**
- pytest: 6/6 PASS (`tests/unit/test_render_page_guard.py`)
- Live regression: `/arcs/arc-005`, `/arcs`, `/orchestrator` all return 1 `<nav>`
- Live htmx path: HX-Request fragment returns 0 `<nav>` (unchanged)
- Live regression on `render_template` routes: `/escalation-drift`, `/reviewer/audit`, `/reviewer/overrides` all return 1 `<nav>`
- Deliberate violation test: re-introduced `{% extends "base.html" %}` → HTTP 500; restored → 1 `<nav>` recovered
- Code change: `web/shared.py` adds `_check_render_page_fragment_convention()` (≈50 LOC) called from the non-htmx branch of `render_page()`
- T-1898 follow-up: this task is the "structural prevention" line item RCA'd in T-1898

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

### 2026-05-18T17:18:57Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1899-renderpage-runtime-guard--refuse-templat.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-24babad5
- **Timestamp:** 2026-06-02T15:00:21Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#5 (Agent)** — Live confirmation: temporarily re-introducing `{% extends "base.html" %}` at the top of `web/templates/arc_detail.html` causes `/arcs/arc-005` to return HTTP 500 with the actionable message (revert im
  - **AC-verify-mismatch** (narrow, heuristic) — `path=web/templates/arc_detail.html in: Live confirmation: temporarily re-introducing `{% extends "base.html" %}` at the top of `web/templates/arc_detail.html` causes `/arcs/arc-005` to retu`
### 2026-05-18T17:25:40Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
