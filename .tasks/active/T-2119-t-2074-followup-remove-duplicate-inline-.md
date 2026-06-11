---
id: T-2119
name: "T-2074 followup: remove duplicate inline htmx error listeners in review.html"
description: >
  T-2074 followup: remove duplicate inline htmx error listeners in review.html

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: []
components: [web/templates/review.html]
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-30T20:01:43Z
last_update: '2026-06-11T22:23:32Z'
date_finished: 2026-06-06T06:18:37Z
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
  - ts: '2026-06-05T18:00:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-06-05T18:00:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 2
      F-ORCH: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=2 (body:lightly-promoted); F-ORCH=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:23:32Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=2 (body:lightly-promoted); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2119: T-2074 followup: remove duplicate inline htmx error listeners in review.html

## Context

T-2074 extracted htmx error listeners to `web/static/htmx-toast.js` and added the
script to `review.html` — but missed that `review.html:629-636` ALREADY had inline
listeners for the same events. Net effect: every htmx 4xx/5xx on /review fires the
toast TWICE. This task removes the inline listeners (lines ~629-636), leaving the
inline `showToast()` + `#toast-container` div untouched so `htmx-toast.js`'s
`getShowToast()` still defers to the page-styled implementation.

## Acceptance Criteria

### Agent
- [x] `review.html` no longer contains `addEventListener('htmx:responseError'` or `addEventListener('htmx:sendError'` (grep returns zero).
- [x] `review.html` still contains the inline `function showToast(` + `id="toast-container"` (htmx-toast.js delegates to them).
- [x] `/review/T-2119` HTTP smoke (200) and `/static/htmx-toast.js` (200).
- [x] `web/static/htmx-toast.js` unchanged (extraction owns wiring).

### Human
- [ ] [REVIEW] On `/review/<any-task-with-checkable-AC>`, click a checkbox/Complete action and force/observe a 4xx (DevTools Network → block the POST, or just click against an already-completed task). Confirm exactly **one** red toast appears bottom-right — not two stacked. Before T-2119 a duplicate-listener bug caused two simultaneous toasts.
  **Steps:**
  1. Open http://192.168.10.107:3000/review/T-2119 (or any open task with Human ACs).
  2. Open Chrome DevTools → Network tab.
  3. Click an action that mutates state (Complete button, AC checkbox).
  4. If the request succeeds (no toast), use the Network tab's "Block request URL" to force a 4xx, then click again.
  **Expected:** Exactly one `.wt-toast.error` element appears in `#toast-container` (CSS-styled, bottom-right) — not two.
  **If not:** Inspect Elements → search for `addEventListener('htmx:` — should be present in `htmx-toast.js` only, not inline in review.html.

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

curl -sf "$(bin/fw watchtower url)/review/T-2119" > /tmp/.t2119.out
test -s /tmp/.t2119.out
test "$(grep -c "addEventListener('htmx:responseError'" /tmp/.t2119.out)" = "0"
test "$(grep -c "addEventListener('htmx:sendError'" /tmp/.t2119.out)" = "0"
grep -q "function showToast" /tmp/.t2119.out
grep -q "id=\"toast-container\"" /tmp/.t2119.out
grep -q "static/htmx-toast.js" /tmp/.t2119.out
curl -sf "$(bin/fw watchtower url)/static/htmx-toast.js" -o /tmp/.t2119-js.out
test -s /tmp/.t2119-js.out

## RCA

**Symptom:** T-2074 introduced htmx-toast.js + a `<script src=…>` in review.html
without first auditing whether the template already wired the same listeners.
review.html:629-636 already had inline `htmx:responseError` + `htmx:sendError`
listeners (from T-1582/T-1574 follow-up), so after T-2074 every htmx error fired
two toasts (inline + module).

**Root cause:** T-2074's AC #3 ("review.html loads htmx-toast.js after csrf-htmx.js")
said WHAT to add but not "and remove any pre-existing inline listeners that would
duplicate". The originating inception (T-2063) body even noted the inline handler
existed at lines 611-634 — but the scope correction in T-2074 Context didn't
translate that observation into an AC.

**Why structurally allowed:** No detector pins "exactly one set of listeners per
DOM event per page". The check is shape-equivalence (single registration), not
something a curl/grep test naturally exercises. The render-surface gate fires
[REVIEW] for visual confirmation — which a human eyeballing might catch as "two
toasts blink", but it's not what the [REVIEW] Steps directed them to look at.

**Prevention:** L-448 candidate — when extracting an inline handler to a shared
script file, the extraction task must include an AC of the form "no remaining
inline `addEventListener('<event>'`, …) call sites in any consumer template
(grep-zero)". The same gap closed for `csrf-htmx.js` (T-1453) by coincidence
because the extracting agent did do the grep — codify that as part of
the extraction protocol next time. Filing as a candidate learning rather than
a detector for now (sample size = 1; the more general "no duplicate listener"
property is harder to detect mechanically).

## Recommendation

**Recommendation:** GO (close on [REVIEW] tick)

**Rationale:** T-2074 regression cleanly closed. Inline listeners removed,
inline `showToast` + container kept so htmx-toast.js's `getShowToast()` still
delegates to the page-styled implementation. Behaviour now matches T-2074's
original intent: one set of listeners (in htmx-toast.js), one styled
`showToast` per page context (inline on review, inline on base, fallback for
any other standalone).

**Evidence:**
- `web/templates/review.html` — inline listeners gone (`grep -c addEventListener` returns 0 for both events)
- Inline `function showToast` + `id="toast-container"` retained for delegation
- HTTP smoke: `/review/T-2119` → 200; `/static/htmx-toast.js` → 200
- L-448 candidate captured in RCA — extraction tasks need explicit "grep zero remaining inline" AC

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

### 2026-05-30T20:01:43Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2119-t-2074-followup-remove-duplicate-inline-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-40285306
- **Timestamp:** 2026-06-11T12:13:00Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#4 (Agent)** — `web/static/htmx-toast.js` unchanged (extraction owns wiring).
  - **AC-verify-mismatch** (narrow, heuristic) — `path=web/static/htmx-toast.js in: `web/static/htmx-toast.js` unchanged (extraction owns wiring).`
### 2026-06-06T06:18:37Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
