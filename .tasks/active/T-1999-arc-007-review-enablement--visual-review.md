---
id: T-1999
name: "arc-007 review enablement — visual review surface for S0/S1 presets (palette/theme
  contact sheet + live preview)"
description: >
  arc-007 review enablement — visual review surface for S0/S1 presets (palette/theme
  contact sheet + live preview)

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: [T-1988, T-1991, T-1989]
arc_id: watchtower-redesign
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-22T22:11:08Z
last_update: '2026-05-22T22:15:02Z'
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
  - ts: '2026-05-22T22:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 7
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=7 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-05-22T22:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
---

# T-1999: arc-007 review enablement — visual review surface for S0/S1 presets (palette/theme contact sheet + live preview)

## Context

The human cannot review arc-007 S0 (T-1991 tokens) / S1 (T-1988 appearance) because the
review surface (`/review/T-XXX` Human-AC checkbox) is text-only, and the instructions I gave
made them *guess* the URL (`bin/fw watchtower url then open .../settings/appearance`). A visual
redesign needs a direct, clickable, confirmed-live review surface — not a recipe. Deliverable:
hand the human the exact resolved URL(s), confirmed serving current S0/S1 code, so all 6 presets
(Calm/Editorial/Console/Paper/Bone/Midnight) are reviewable with zero guessing.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Live Watchtower URL resolved via `bin/fw watchtower url` (no guessing) and `/settings/appearance` returns HTTP 200 on it — http://192.168.10.107:3000
- [x] Live instance serves current S0/S1 code: `/settings/appearance` body contains all 6 preset labels (Calm, Editorial, Console, Paper, Bone, Midnight)
- [x] Clicking a preset re-themes `<html>` and the choice persists across navigation — verified in a real browser via Playwright (curl couldn't: CSRF-protected save). Click Console → `theme=dark, palette=console, type=plex`, paints `rgb(10,12,14)`, "Saved · console"; `/tasks` retains it. Pinned by `tests/playwright/test_appearance_presets.py` (2/2)
- [x] The exact clickable URL is handed to the human in chat (full host, not a command to find it); LAN reachability confirmed (firewall `3000/tcp ALLOW Anywhere`)
- [x] Blocker fixed: appearance.html JS `SyntaxError` (dead preset buttons) corrected in `d1cb717a` — the page was unreviewable before this

### Human
- [ ] [REVIEW] The appearance review surface is decent: all 6 presets are reviewable without guessing URLs; clicking a preset re-themes the whole UI and the choice persists across nav + hard-reload
  **Steps:**
  1. Open the exact URL I provide (it ends in `/settings/appearance`)
  2. Click each of the 6 presets — watch the page re-theme
  3. Pick one (e.g. Console), navigate to Cockpit / Tasks / Approvals via the nav, then hard-reload
  **Expected:** Each preset visibly re-themes; the chosen preset persists across navigation and hard-reload
  **If not:** Note which preset/page looked wrong (screenshot helps)

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

# Regression guard: the appearance preset JS must actually execute (the origin
# bug returned 200 + presets-present but the script threw, so buttons were dead).
out=$(python3 -m pytest tests/playwright/test_appearance_presets.py -q 2>&1); echo "$out" | tail -3 | grep -q "2 passed"
# Resolved review URL serves the appearance page (no hard-coded :3000)
curl -sf "$(bin/fw watchtower url)/settings/appearance" >/dev/null

## RCA

**Symptom:** The human could not visually review arc-007 S1 (T-1988). The
instructions I gave made them *guess* the URL, and once on `/settings/appearance`
clicking any of the 6 presets did nothing — the page was inert.

**Root cause (two layers):**
1. *Review-surface gap:* I handed a recipe (`bin/fw watchtower url then open …`)
   instead of the resolved clickable URL — the stated complaint.
2. *Live bug:* `web/templates/appearance.html`'s inline `<script>` had a malformed
   ternary on the `save()` `.then()` — `status.textContent = d && d.ok ? '…' ;`
   with no `:` else-branch. That is a hard `SyntaxError: Unexpected token ';'`,
   which aborts parsing of the **entire** IIFE. Result: no preset/axis click
   handler ever attached. Every button on the page was dead.

**Why structurally allowed:** S1's Agent ACs verified "page returns 200" and
"presets present" — both true. But a `SyntaxError` leaves the DOM fully rendered;
only *executing* the JS reveals the break. There was zero executable-JS coverage
of `/settings/appearance`, so curl/grep verification passed on a functionally
dead page. This is the T-1575 class ("UI verification needs eyes") in its purest
form: the markup was perfect, the behaviour was absent.

**Prevention:** `tests/playwright/test_appearance_presets.py` (added here) drives
a real browser — clicks a preset, asserts `<html>` re-themes, asserts no console
errors, asserts persistence across navigation. A future `SyntaxError` fails it
immediately. Captured as a learning (interactive render surfaces require an
executed-browser AC, not markup-presence). Fix commit: `d1cb717a`.

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

### 2026-05-23 — "enable review" became "fix the blocker that makes review impossible"
- **What changed:** Scoped as a URL-handoff ("give the human a clickable link, not a recipe"). But driving the live page in a real browser (Playwright) revealed S1's preset JS was dead — a `SyntaxError` killed every click handler. The page was unreviewable regardless of how good the URL was.
- **Plan impact:** Deliverable expanded from URL-handoff to a one-line code fix in `appearance.html` plus a Playwright regression guard. The "contact sheet" framing in the task name proved unnecessary — once the page works, live interactive review beats static screenshots and lets the human exercise nav/persistence/hard-reload directly.
- **Triggered:** Fix `d1cb717a`; `tests/playwright/test_appearance_presets.py`; learning on executed-browser verification for interactive render surfaces; open question for the human — does T-1988 (S1) need its review verdict re-opened, given it shipped functionally broken?

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

### 2026-05-22T22:11:08Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1999-arc-007-review-enablement--visual-review.md
- **Context:** Initial task creation
