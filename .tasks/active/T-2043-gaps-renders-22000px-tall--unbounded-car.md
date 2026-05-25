---
id: T-2043
name: "/gaps renders 22000px tall — unbounded card list (T-2038 class)"
description: >
  /gaps renders 22,278px (card-list: {% for g in gaps %}<article> with nested details).
  6th instance of the unbounded-page class found by the T-2042 exhaustive height probe.
  Fix: cap inline + collapse overflow <details>, like T-2040 /inception.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [arc-007, perf, watchtower, gaps, ui, render-surface]
components: []
related_tasks: [T-2040, T-2042, T-2041]
arc_id: watchtower-redesign
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-25T14:52:39Z
last_update: 2026-05-25T14:55:01Z
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
  - ts: '2026-05-25T14:55:01Z'
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

# T-2043: /gaps renders 22000px tall — unbounded card list (T-2038 class)

## Context

6th instance of the unbounded-page class (T-2038/T-2039/T-2040/T-2041), surfaced by the
T-2042 exhaustive height probe. `/gaps` loops `{% for g in gaps %}<article>` over every gap
in `gaps.yaml` (watching + closed/decided) with no height bound → 22,278px. Pure card-list
→ same fix as T-2040 /inception: render the first N inline, wrap the older/closed overflow
in a collapsed `<details class="gaps-overflow">` (display:none → excluded from scrollHeight
and full_page screenshots, every gap still in the DOM one click away — nothing dropped).
See [[project_unbounded_watchtower_pages]].

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] /gaps rendered scrollHeight drops below the 8000px `_safe_shot` cap (from 22,278px), verified by a live playwright probe — measured **22,278px → 5,615px**
- [x] Every gap `<article>` stays in the DOM: opening `.gaps-overflow` leaves the article count unchanged (collapsed, never truncated) — **74 → 74** after expand
- [x] `tests/playwright/test_gaps_height.py` added (height-bounded + items-reachable), both pass — **2 passed**
- [x] New test registered in the component fabric (`fw fabric register`) — `.fabric/components/tests-playwright-test_gaps_height.yaml`

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
- [ ] [REVIEW] /gaps reads cleanly after the height fix
  **Steps:**
  1. Open http://192.168.10.107:3000/gaps
  2. Confirm the actively-watched gaps render inline and the page no longer endless-scrolls
  3. Find the "Show N more" affordance; click it and confirm the remaining gaps expand in place
  **Expected:** The watched/active gaps are visible at a glance; the collapse affordance is discoverable and labelled; clicking it restores the full gap list without a reload
  **If not:** Note which gaps should be inline vs collapsed and whether the affordance label reads clearly

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

curl -sf "$(bin/fw watchtower url)/gaps" >/dev/null
python3 -m pytest tests/playwright/test_gaps_height.py -q 2>&1 | tail -3
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

**Symptom:** `/gaps` rendered 22,278px tall (74 gap `<article>` cards).

**Root cause:** The template looped over every concern in `gaps.yaml` (8 watching + 66
closed/decided) with no height bound — the closed gaps are never pruned, so the page grows
monotonically. Same data-growth class as T-2038..T-2042.

**Why structurally allowed:** /gaps was never in the ux-review sweep's hard-coded 5-page
list, so the height regression was invisible to tooling — found only once T-2042 made the
detector exhaustive (this is the 6th of 9 instances that fix surfaced).

**Prevention:** (1) `tests/playwright/test_gaps_height.py` pins scrollHeight < 8000 and
no-card-dropped — guards this page forever. (2) The systemic prevention (exhaustive
detector) already shipped in T-2042 — /gaps is now in scope, so a future regression
surfaces in the `--all-routes` Capture column automatically.

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

### 2026-05-25 — active-first ordering makes the cap meaningful

- **What changed:** The blueprint (`load_concerns()`) returns gaps unsorted, so a plain
  file-order cap risked hiding the 8 *watching* gaps behind 66 closed ones. Realised the cap
  is only useful if the inline slots show the gaps an operator actually acts on.
- **Plan impact:** Added a one-line Jinja partition (active = non-closed first, then closed)
  before the cap, so the ~8 active gaps are always inline and the overflow is "mostly closed".
- **Triggered:** None — this is one of the 5 instances T-2042 surfaced (T-2043..T-2047);
  the others are filed separately.

## Decisions

### 2026-05-25 — partition + cap vs. plain file-order cap

- **Chose:** Partition active-first (`rejectattr('status','equalto','closed')` ++
  `selectattr(...,'closed')`) then cap at 20 + collapse overflow.
- **Why:** Guarantees the actionable (watching/decided) gaps render inline regardless of
  `gaps.yaml` order; the overflow is dominated by closed/resolved gaps that are reference-only.
- **Rejected:** Plain cap in file order — would non-deterministically bury watching gaps in
  the collapsed section. Filtering closed gaps out entirely — rejected: they must stay
  reachable for audit/history (the collapse keeps them one click away).

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Recommendation

**Recommendation:** GO

**Rationale:** 6th instance of the unbounded-page class fixed with the established T-2040
pattern plus active-first ordering. /gaps drops from 22,278px to 5,615px while keeping all
74 gap cards in the DOM (verified count unchanged after expand). The 8 watching/decided gaps
render inline; the 66 closed/resolved collapse into "Show 54 more". A playwright regression
test pins both invariants and is registered in the fabric. Only the visual-rhythm judgment
remains for human taste.

**Evidence:**
- scrollHeight: **22,278px → 5,615px** (live playwright probe, `< 8000px` cap)
- DOM cards: **74 → 74** after opening `.gaps-overflow` (nothing dropped)
- `tests/playwright/test_gaps_height.py`: **2 passed**
- Eyes-on screenshot: http://192.168.10.107:3000/static/ux-review/T-2043-gaps-bounded.png
- Template: `web/templates/gaps.html` — active-first partition + `_gaps_cap = 20` + nested `<details class="gaps-overflow">`

## Updates

### 2026-05-25T14:52:39Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2043-gaps-renders-22000px-tall--unbounded-car.md
- **Context:** Initial task creation

### 2026-05-25T14:55:01Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
