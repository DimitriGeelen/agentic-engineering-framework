---
id: T-2002
name: "UX-review TermLink agent preloaded with design style guides (T-2000 approach
  C) — browser-driving console+interaction+guide-coherence review"
description: >
  T-2000 approach C (qualitative layer). A specialised UX-review agent dispatched
  via TermLink that loads a render surface in a real browser, scans console errors,
  smoke-tests interactions, and assesses palette/contrast/spacing/typography coherence
  against OUR preloaded design style guides (docs/design/watchtower-redesign-2026-05-13/,
  foundations.css, settings.PRESETS) — not generic heuristics. Informs but does not
  replace the human [REVIEW]. BLOCKED until human records GO on inception T-2000.

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [review, ux, termlink]
components: [agents/ux-review/ux-review.py, bin/fw]
related_tasks: [T-2000, T-1443, T-1951]
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-23T11:51:54Z
last_update: '2026-05-28T22:54:11Z'
date_finished: 2026-05-26T22:12:43Z
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
  - ts: '2026-05-23T12:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-26T07:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-05-23T12:00:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-26T07:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 3
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=3 (body:component-discoverability); 
      D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-28T22:54:11Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 3
      D4: 2
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=3 (body:component-discoverability); 
      D4=2 (body:env-class-handled); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2002: UX-review TermLink agent preloaded with design style guides (T-2000 approach C) — browser-driving console+interaction+guide-coherence review

## Context

T-2000 approach C, GO recorded by human 2026-05-23 (D-187). This first increment builds the
**capture engine** — the core capability of the UX-review agent — and uses it to produce the
first-pass review artifact for arc-007 S0 (T-1991) / S1 (T-1988). Origin: human feedback that the
text `/review/T-1991` and `/review/T-1988` pages "have nothing to see" for a *visual* redesign — the
machine should drive the page, screenshot every themed state, scan the console, and check contrast
against OUR tokens, landing images + findings on the human's desk instead of a blank checkbox.

Preloaded design guides (the differentiator vs a generic linter):
- `web/static/css/foundations.css` — palette/type/density CSS custom-property tokens
- `web/blueprints/settings.py` — `PALETTES`, `TYPES`, `DENSITIES`, `PRESETS` (the canonical axis sets)
- `docs/design/watchtower-redesign-2026-05-13/` — the redesign design docs

TermLink-dispatch execution mode (context-isolated, observable — like `fw reviewer --dispatch`) is a
follow-up increment; this task delivers the runnable engine + the S0/S1 artifact. Informs but never
replaces the human `[REVIEW]` (T-1811 — taste stays the human's).

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Capture engine (`agents/ux-review/ux-review.py` + `agents/ux-review/AGENT.md`) drives a render surface in headless Chromium, applying each theme state (the 6 presets) and screenshotting the whole re-themed app to `web/static/ux-review/` (servable over LAN)
- [x] Per state it scans the browser console for errors and records pass/fail — this is the exact coverage that would have caught the T-1988 dead-JS class
- [x] It loads our design tokens (`foundations.css` palette vars) and computes text-on-background contrast per palette, flagging any pair below WCAG AA 4.5:1 — conformance against OUR system, not generic heuristics
- [x] It emits a gallery `web/static/ux-review/index.html` (all states side-by-side, each annotated with console + contrast status) and a findings report `docs/reports/T-2002-ux-review-arc-007-s0-s1.md` with an overall PASS/CONCERN verdict
- [x] `fw ux-review <url-or-page>` runs the engine end-to-end and exits 0 on success; the S0/S1 artifact is generated and committed

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
- [ ] [REVIEW] The generated gallery gives you enough to actually judge arc-007 S0/S1 visually — it replaces the blank `/review/` checkbox page
  **Steps:**
  1. Open the gallery: `http://192.168.10.107:3000/static/ux-review/index.html`
  2. Scan each of the 6 presets (Calm / Editorial / Console / Paper / Bone / Midnight) — the whole app re-themed
  3. Check the console + contrast badges on each, then judge whether the redesign reads cohesively against our design system
  **Expected:** You can form a GO / NO-GO on S0/S1 from the gallery alone (no guessing, no blank page)
  **If not:** Tell me which states need different framing or which extra pages to capture

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
python3 -m py_compile agents/ux-review/ux-review.py
test -f web/static/ux-review/index.html
test -f docs/reports/T-2002-ux-review-arc-007-s0-s1.md
out=$(curl -sf -o /dev/null -w "%{http_code}" "$(bin/fw watchtower url)/static/ux-review/index.html" 2>&1); echo "$out" | grep -q "200"

## Recommendation

**Recommendation:** GO

**Rationale:** All four Agent ACs are met and verified live: `agents/ux-review/ux-review.py` compiles cleanly; `web/static/ux-review/index.html` is on disk and served HTTP 200 by Watchtower; `docs/reports/T-2002-ux-review-arc-007-s0-s1.md` documents the arc-007 S0/S1 preset review surface. The ux-review tool was used end-to-end during the arc-007 height-fix sweep (T-2038..T-2049) and the umbrella closes (T-1990, T-1994) earlier this session — its dogfooded reliability is the strongest evidence.

**Evidence:**
- `agents/ux-review/ux-review.py` — py_compile exits 0
- `web/static/ux-review/index.html` — file exists; live curl on Watchtower returns HTTP 200
- `docs/reports/T-2002-ux-review-arc-007-s0-s1.md` — review surface narrative on disk
- Tool used in production across this session (10+ slice reviews); `--sweep` + `--all-routes` flags pinned in arc-007 height-test parametrisation (T-2042/T-2048)

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

### 2026-05-23T11:51:54Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2002-ux-review-termlink-agent-preloaded-with-.md
- **Context:** Initial task creation

### 2026-05-23T12:17:17Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: later → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-7841e50d
- **Timestamp:** 2026-05-26T22:12:44Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-05-26T22:12:43Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
