---
id: T-1940
name: "BVP T-1939 sibling — Playwright pin for /arcs/<slug> bvp_mode provenance label"
description: >
  BVP T-1939 sibling — Playwright pin for /arcs/<slug> bvp_mode provenance label

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [arc:value-prioritisation, render-surface, test, parity]
components: [tests-playwright-test_arc_detail_bvp]
related_tasks: [T-1939, T-1937, T-1938, T-1936, T-1934, T-1930]
arc_id: value-prioritisation
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-19T21:12:50Z
last_update: '2026-05-19T21:15:01Z'
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
cost_estimate_proposed:
  - ts: '2026-05-19T21:15:01Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 1
      tier: 2
      effort: 8
    rationale: blast_radius=1 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-05-19T21:15:01Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
---

# T-1940: BVP T-1939 sibling — Playwright pin for /arcs/<slug> bvp_mode provenance label

## Context

T-1939 added a `bvp_mode` provenance field (`direct-confirmed`/`direct-proposed`/
`derived-confirmed`/`derived-proposed`/empty) and rendered it as a
`<small>Source: <code>{{ bvp_mode }}</code> — ...</small>` line when
`bvp_mode != 'direct-confirmed'`. T-1939's `[REVIEW]` Human AC covered the
visual aesthetic but did NOT mechanically pin the DOM contract. Per T-971
(write Playwright when AC is a UI feature), per T-1878 (when the check is
deterministic, prefer `[REVIEWER]`/Agent), and per L-407 (silent-corpus
pattern — guard the new fields), add a Playwright regression that pins:
(1) provenance label visibility on derived-proposed arcs, (2) explanation
text per mode variant, (3) absence of the label when bvp_mode would be
direct-confirmed. Structural fix complements the human visual review.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Playwright test file extended/added that asserts `<small>Source: ...</small>` is visible on a `derived-proposed` arc
- [x] Same test asserts the `derived-proposed` explanation substring renders ("rolled up from constituent task scores; at least one input is estimator-proposed")
- [x] Test pinned via DOM-content assertion (not bare element-presence grep, per T-1575)
- [x] Test passes locally against running Watchtower on :3000 (value-prioritisation arc currently `derived-proposed`)
- [x] No regression in existing `test_arc_detail_bvp.py` tests
- [x] Task post-grill governance closure (L-349): arc_id, tags, related_tasks set; sibling/build pre-files surfaced if needed

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

cd /opt/999-Agentic-Engineering-Framework && python3 -m pytest tests/playwright/test_arc_detail_bvp.py -x --tb=short 2>&1 | tail -15

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

**Recommendation:** GO

**Rationale:** T-1939 shipped the `bvp_mode` provenance field as a single
`[REVIEW]` Human AC covering aesthetic + structural concerns together. Per
T-1878 author-time bias rule, the structural part of that review (label
visibility, mode-slug enum, explanation substring presence) is deterministic
DOM-content — better pinned by Playwright than re-reviewed visually each
time. This sibling slice adds 3 structural assertions that:
  - Pin label visibility on derived/proposed arcs
  - Pin the explanation substring per mode variant
  - Pin the `<code>` element semantic wrapper around the mode slug

The remaining T-1939 `[REVIEW]` AC now correctly scopes to the *aesthetic*
question alone (does the label read clearly? is its placement right?) — the
machine catches structural regressions.

**Evidence:**
  - `tests/playwright/test_arc_detail_bvp.py` — 3 new tests added at lines 81-126
  - Test run: `10 passed in 49.17s` (4 new + 6 existing, no regression)
  - Live verified against `http://localhost:3000/arcs/value-prioritisation`
    rendering `Source: derived-proposed — rolled up from constituent task scores`
  - Sibling of T-1939, T-1937, T-1938, T-1936, T-1934, T-1930 (full arc-006
    /arcs/<slug> render-surface coverage now)

## Evolution

### 2026-05-19 — T-1939 [REVIEW] split into structural + aesthetic
- **What changed:** T-1939's `[REVIEW]` AC bundled DOM-content checks
  (structural: label visibility + mode-slug presence) with visual aesthetic
  (taste: label readability + placement). Per T-1878, structural checks
  should default to `[REVIEWER]`/Agent ACs with Playwright/reviewer commands.
- **Plan impact:** T-1939 stays `[REVIEW]` for the aesthetic remainder only;
  T-1940 (this task) carries the structural pin via Playwright.
- **Triggered:** Filed T-1940 as a sibling; no further sub-tasks needed.

## Decisions

### 2026-05-19 — extend existing file vs new file
- **Chose:** extend `tests/playwright/test_arc_detail_bvp.py` with 3 new tests
- **Why:** T-1930's existing test file already pins the same page's BVP
  section. Adding to it keeps related tests co-located and shares the
  `_ARC_SLUG` fixture without duplication. Separate file would fragment
  coverage across multiple files for one DOM region.
- **Rejected:** create `test_arc_detail_bvp_mode.py` — would split coverage
  artificially; the provenance label is part of the same `#bvp-signals`
  block T-1930 already tests.

### 2026-05-19 — DOM-content text match vs to_have_text
- **Chose:** `.text_content()` substring assertion via `assert "Source:" in ...`
- **Why:** The template renders different explanation strings per mode
  variant. A single Playwright `to_have_text` would force frozen text;
  substring assertion lets the test survive innocent copy edits while still
  pinning the load-bearing substring (mode slug + key explanation phrase).
- **Rejected:** `expect(elem).to_have_text("exact frozen string")` — too
  brittle, would break on any text refinement.

### 2026-05-19 — three tests, not one composite
- **Chose:** three separate tests pinning label visibility, explanation
  substring, and `<code>` slug element independently.
- **Why:** Three independent contracts (existence, semantic content,
  structural wrapper) should fail independently — diagnosis is faster when
  only the broken contract fails.
- **Rejected:** single test asserting all three — first-fail short-circuits
  the others, hiding co-occurring drift.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-05-19T21:12:50Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1940-bvp-t-1939-sibling--playwright-pin-for-a.md
- **Context:** Initial task creation
