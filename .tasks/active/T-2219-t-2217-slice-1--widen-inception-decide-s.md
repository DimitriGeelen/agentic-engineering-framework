---
id: T-2219
name: "T-2217 Slice 1 — widen inception decide side-effect-warning truncation (150
  → 1500 + pre-wrap)"
description: >
  T-2217 Slice 1 — widen inception decide side-effect-warning truncation (150 → 1500
  + pre-wrap)

status: started-work
workflow_type: build
owner: human
horizon: now
tags: []
components: []
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-06-05T20:27:00Z
last_update: '2026-06-06T20:30:03Z'
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
  - ts: '2026-06-05T20:30:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-ORCH=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-06T20:30:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 3
      F-RECALL: 0
      F-ORCH: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=3 (body:portability-abstraction); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-06-05T20:30:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2219: T-2217 Slice 1 — widen inception decide side-effect-warning truncation (150 → 1500 + pre-wrap)

## Context

T-2217 GO scope Slice 1 (Candidate A, F8 ≈ 0.5). When `fw inception decide` records a Decision but the side-effect chain (e.g. `--status work-completed` transition) emits a multi-line stderr that the operator needs to act on, Watchtower's htmx warning at `web/blueprints/inception.py:551` truncates the message to **150 chars** and renders it unescaped/inline — long stderr (e.g. the disposition-gate block message at ~700 chars with bullet list + bypass options) shows the first sentence only and the operator has no way to recover the rest from the page. This is the visible symptom that triggered T-2217.

**Asymmetry to fix.** The sibling error path (`inception.py:579-587`, the htmx pre-decision validation rejection) already handles wide stderr correctly: `_html.escape(... [:300])` + `white-space:pre-wrap` style. Lines 549-553 (side-effect warning) and 556-562 (commit-failure warning) do NOT. Slice 1 closes that gap with three coordinated changes: widen to 1500, HTML-escape, render with `pre-wrap` so newlines survive.

Out of scope (separate slices): the form-redirect path (`?warning=`, `?error=` at lines 596-605) — URL query strings have practical length constraints, separate UX class. Playwright contract test (Slice 2, M-cost). Disposition-gate regex anchor (Slice 3, T-2218, shipped).

## Acceptance Criteria

### Agent
- [x] `web/blueprints/inception.py:551` side-effect-warning htmx fragment truncates `stderr or stdout` at **1500 chars** (not 150) AND HTML-escapes the value AND wraps it in a `pre-wrap`-style block so newlines survive.
- [x] `web/blueprints/inception.py:560` commit-failure htmx fragment matches the same shape (1500 chars + already-escaped + `pre-wrap` style) for consistency with its sibling.
- [x] The non-htmx form-redirect paths (`web/blueprints/inception.py:596`, 598, 605) are NOT widened — they remain at `[:300]` / `[:200]` (URL query-string constraint, separate UX class noted in Context).
- [x] Unit test (`tests/unit/test_inception_decide_warning_widen.py`) pins all three properties on the htmx-warning paths: max-length raised to 1500, output is HTML-escaped, output contains a `pre-wrap` style fragment. Test PASSes against the fixed source.
- [x] Reviewer static-scan PASS on this task (`bin/fw reviewer T-2219 --no-write 2>&1 \| grep -q "Overall:.*PASS"`).

### Human

- [ ] [REVIEW] Side-effect-warning fragment renders cleanly on /inception/&lt;id&gt; when a wide multi-line stderr fires
  **Steps:**
  1. Open http://192.168.10.107:3000/inception/T-2209 (or any inception with a pending GO that will trip a gate).
  2. Click GO. Observe the warning fragment that appears below the decision button.
  3. Confirm: full gate message visible (not clipped at one sentence), newlines from stderr render as actual line breaks (not collapsed), the warning fits its card width without breaking the surrounding layout, no HTML escape glitches (`&amp;lt;` / `&amp;gt;` shouldn't appear in rendered text — only their actual symbol forms).
  4. If no live trigger handy, scroll to the bottom of an existing /inception/&lt;id&gt; page and inspect Element on the `.approval-card`'s warning `<div>` to confirm `white-space: pre-wrap` is applied.

  **Expected:** Multi-line gate stderr renders readably with bullet list intact and bypass options visible; operator can act on the warning without re-running the command in a terminal. Layout reads clean on dark + light palettes.

  **If not:** Note paragraph/line where rendering breaks; screenshot for follow-up.

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

python3 -m pytest tests/unit/test_inception_decide_warning_widen.py -x -q
grep -q '\[:1500\]' web/blueprints/inception.py
grep -q 'white-space:pre-wrap' web/blueprints/inception.py
grep -q '_html.escape((stderr or stdout)' web/blueprints/inception.py
out=$(bin/fw reviewer T-2219 --no-write 2>&1); echo "$out" | grep -q "Overall:.*PASS"

## RCA

**Symptom:** Operator clicked GO on `/inception/T-2209` and Watchtower rendered `⚠ Decision recorded; side-effect warning: === Task Update === Task: T-2209 ("Capability-overlay arc — MCP subsystem + CLI route for agent-callable framework) File: /opt/999-Agentic-Engin` — message clipped mid-word at exactly 150 chars. The full stderr (≈700 chars: gate name + missing-list bullets + three bypass options) was discarded. Operator had no surface-visible recovery path; they had to switch contexts to a terminal and re-run the command to see what the gate wanted.

**Root cause:** `web/blueprints/inception.py:551` truncated `(stderr or stdout)` at 150 chars and emitted the value into the HTML fragment without escaping and without `white-space:pre-wrap`. The 150-char limit was chosen at T-1470 (the original `--status work-completed → ?warning=` plumbing) for compatibility with URL query-strings, then copied into the htmx fragment path where no query-string constraint applies. The sibling htmx error path (the pre-decision validation rejection at lines 579-587) was independently authored with the wider 300-char + escape + pre-wrap pattern — but the discipline never back-propagated to the success-with-side-effect-warning path.

**Why structurally allowed:** No render-side unit test pinned the truncation shape (length + escape + pre-wrap) — the original T-1470 work didn't ship one because the path was reasonably understood as carrying short single-line warnings. The disposition gate (T-2190, shipped 2026-05-30) introduced the first multi-line stderr that this path had to render, and that's when the asymmetry surfaced as operator-blocking truncation. Adjacent class to G-068 META (Watchtower silent-failure on primary control surfaces).

**Prevention:** `tests/unit/test_inception_decide_warning_widen.py` pins all three properties on the htmx-warning paths. Future re-narrowing or escape-stripping fails the test before merge. The non-htmx form-redirect paths (lines 596/598/605) are intentionally excluded from the test's `[:1500]` requirement and have their own asserts at `[:300]` — making the URL-length constraint explicit so a later widener won't accidentally break URL handling.

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

**Rationale:** All 5 Agent ACs PASS; reviewer PASS; verification 5/5. The widening + escape + pre-wrap triad is the minimal class-closing fix for the G-068 META class as it manifested at this surface — sibling pattern was already in the same file (lines 579-587) for the validation-rejection path, so the asymmetry was the bug, not the design. The unit test (`tests/unit/test_inception_decide_warning_widen.py`) pins all three properties so future re-narrowing or escape-stripping fails before merge. Sibling Slice 3 (T-2218, shipped) closes RC5 (regex anchor) — the two slices together unblock T-2209 directly and prevent recurrence.

**Evidence:**
- `web/blueprints/inception.py:549-565` now uses `_html.escape((stderr or stdout)[:1500])` with `white-space:pre-wrap` style, matching the sibling pattern at lines 579-587.
- `tests/unit/test_inception_decide_warning_widen.py` — 5/5 PASS.
- Reviewer T-2219: PASS, 0 findings.
- Out-of-scope paths (URL-query-string at lines 596/598/605) preserved at `[:300]` / `[:200]`; explicit AC + test assertion prevents accidental widening.
- T-2218 (Slice 3, RC5 fix) committed `c68e5fe39` this session — together the two slices clear T-2209's stuck-state without operator Sovereign bypass.

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

### 2026-06-05T20:27:00Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2219-t-2217-slice-1--widen-inception-decide-s.md
- **Context:** Initial task creation
