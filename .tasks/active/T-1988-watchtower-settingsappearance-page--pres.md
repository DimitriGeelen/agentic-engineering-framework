---
id: T-1988
name: "Watchtower /settings/appearance page — preset picker + foundation axes + sticky
  live preview + per-user YAML persistence (arc-007 S1)"
description: >
  Build the appearance settings page from docs/design/watchtower-redesign-2026-05-13/project/appearance-settings.jsx.
  Top: 6 preset cards (Calm/Editorial/Console/Paper/Bone/Midnight) one-click application.
  Body: theme mode (light/dark/auto), typography (6 cards), palette (6 cards), accent
  override, nav layout (3 cards with mini previews), density toggle, other UX toggles.
  Sticky live cockpit preview at top that re-themes instantly. Persistence: write
  to .context/user-preferences/<who>.yaml keyed by root (or session cookie fallback).
  Read on every page render via web/shared.py helper. Depends on S0 (foundation tokens).
  Parent inception: T-1987.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [watchtower, redesign, ui, settings]
arc_id: watchtower-redesign
components: []
related_tasks: [T-1987]
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-22T10:06:08Z
last_update: 2026-05-22T18:48:59Z
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
  - ts: '2026-05-22T10:15:01Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-05-22T10:15:02Z'
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

# T-1988: Watchtower /settings/appearance page — preset picker + foundation axes + sticky live preview + per-user YAML persistence (arc-007 S1)

## Context

Slice S1 of arc-007 (watchtower-redesign). Builds the `/settings/appearance` page —
the picker that *fires the headline mechanic* on top of the S0 token layer (T-1991).

**Scope (corrected per inception synthesis / review-A4, A5):**
- 6 **preset** cards (Calm/Editorial/Console/Paper/Bone/Midnight), one click applies a
  curated combo over the foundation axes.
- Per-axis controls: mode (light/dark), typography (6 pairings), palette (6), density
  (compact/cozy/comfortable). **NO nav-layout cards** — nav restructure is S2 (T-1989).
  **NO accent override** — deferred (adds combinatorial surface; not load-bearing for the mechanic).
- Live preview: choosing a preset/axis sets `data-wt-*` / `data-theme` on `<html>`
  *instantly* (client-side), then persists.
- Persistence: per-user YAML at `.context/user-preferences/<uid>.yaml`, where `<uid>`
  is a **signed-cookie UID** (Flask `session`, tamper-proof via `secret_key`) — A2's
  correction (there is no auth/`$USER`; per-browser, not cross-device).
- Read on every page via an `@app_context_processor` that injects `wt_appearance` into
  `base.html`'s `<html>` attributes — server-side, no FOUC. Coexists with the existing
  `data-theme` localStorage toggle (no parallel mechanism introduced for palette).

**Security (review-A5 #security):** UID is whitelisted to `^[0-9a-f]{32}$` before any
path use (no traversal); every appearance value is whitelist-validated against the known
palettes/types/densities/modes before it is persisted or rendered into an HTML attribute
(prevents attribute injection / stored XSS); the save endpoint is CSRF-protected.

Depends on S0 (T-1991). Parent inception: T-1987 (GO).

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `GET /settings/appearance` returns HTTP 200 and renders 6 preset cards (Calm, Editorial, Console, Paper, Bone, Midnight) — each present in the page HTML
- [x] Page renders per-axis controls: palette (6), typography (6), density (3), mode (light/dark) — all 6 palette ids and 6 type ids present in HTML
- [x] `POST /settings/appearance/save` with a valid preset persists `.context/user-preferences/<uid>.yaml` (uid from the signed `session` cookie) and returns 200; a fresh client with no cookie falls back to the default appearance
- [x] **Whitelist validation:** POSTing an out-of-set value (e.g. `palette=../../etc`) is rejected/sanitised — it is NOT written to the YAML and NOT reflected into an HTML attribute (verified by unit test)
- [x] **UID safety:** the uid is constrained to `^[0-9a-f]{32}$` before being used in a path (verified by unit test — a forged session value outside that charset cannot escape `user-preferences/`)
- [x] `base.html` `<html>` tag emits `data-theme` / `data-wt-palette` / `data-wt-type` / `data-wt-density` from the injected `wt_appearance`, defaulting cleanly when no prefs exist
- [x] After a save round-trip, reloading **another** page (e.g. `/`) reflects the saved palette in its `<html data-wt-palette=...>` (server-side persistence proves the mechanic across pages)
- [x] New appearance tests pass (`tests/unit/test_appearance_validation.py` — 9/9) and S1 introduces **no new** suite failures; `.context/user-preferences/` is git-ignored (per-user state, not committed). NB: the suite is pre-existing-red — 9 failures in `test_arc_system` (stale `id: alpha` vs `id: arc-001` from T-1969) + `test_render_artefact_paths` (cross-file ordering pollution; passes 12/12 in isolation), both unrelated to S1, tracked in T-1995.

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

- [ ] [REVIEW] The headline mechanic fires: picking a preset re-themes Watchtower instantly and the choice survives navigation
  **Steps:**
  1. `cd /opt/999-Agentic-Engineering-Framework && bin/fw watchtower url` then open that URL `/settings/appearance`
  2. Click each of the 6 presets (Calm/Editorial/Console/Paper/Bone/Midnight) — watch the page re-theme as you click
  3. Pick one (e.g. Console), then navigate to Cockpit / Tasks / Approvals via the nav
  4. Hard-reload one of those pages
  **Expected:** Each preset visibly changes background, surfaces, text, accent, and (for Console/Midnight) light↔dark — instantly, no page reload needed. After navigating + reloading, the chosen theme is still applied (persistence works). The 6 presets feel distinct and each is legible.
  **If not:** Note which preset looked broken or which page didn't keep the theme; check the browser console for errors.

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

# Page renders with 6 presets + axes
url=$(bin/fw watchtower url 2>/dev/null); out=$(curl -sf "$url/settings/appearance"); echo "$out" | grep -qi "Calm" && echo "$out" | grep -qi "Midnight"
for p in slate linen stone paper bone console; do echo "$out" | grep -q "$p" || { echo "missing palette $p on page"; exit 1; }; done
# base.html emits the data attrs from wt_appearance
grep -q 'data-wt-palette=' web/templates/base.html
grep -q 'wt_appearance' web/templates/base.html
# user-preferences gitignored
git check-ignore -q .context/user-preferences/probe.yaml && echo "gitignored OK"
# new appearance security/validation tests (deterministic). Full suite is
# pre-existing-red (unrelated) — tracked in T-1995, not gated here.
python3 -m pytest tests/unit/test_appearance_validation.py -q
# affected render-path tests pass in isolation (proves S1 introduced no break)
python3 -m pytest tests/unit/test_render_artefact_paths.py -q

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

### 2026-05-22 — S1 scope + persistence design
- **What changed:** The original description carried nav-layout cards, accent override, and a sticky cockpit preview. Per the inception synthesis (review-A4/A5) nav is S2 and accent/preview are non-load-bearing for the mechanic — cut to keep S1 thin. Persistence uses Flask `session` (signed cookie) for `<uid>`, not `$USER`/root (A2: there is no auth). Server-side injection via `@app_context_processor` (no FOUC) was chosen over client-only localStorage so the choice survives navigation server-side.
- **Plan impact:** S1 now delivers exactly the headline mechanic (preset → instant re-theme → persist → survives navigation) with no extra surface. The 6 presets are defined as curated combos over S0 axes in `settings.PRESETS` (single source of truth, pinned by `test_appearance_validation.py`).
- **Triggered:** No new sub-task. Note for S2 (T-1989): the picker deliberately omits a nav-layout control — wire it there. Note for S3-S5: density `data-wt-density` is set but visual density application across pages is still pending (token defined in S0, applied later).

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

**Recommendation:** GO (agent ACs complete; one `[REVIEW]` headline-mechanic check pending)

**Rationale:** S1 makes the arc's headline mechanic real and reviewable. The full round-trip is proven server-side: pick a preset → POST persists to a signed-cookie-keyed YAML → any other page reflects the choice on reload. Security is closed at the unit level (whitelist validation rejects out-of-set values; UID constrained to 32-hex before path use; CSRF on save). The pending `[REVIEW]` is the visual confirmation that the 6 presets feel distinct and legible and that the live re-theme is smooth — genuine human taste, not automatable.

**Evidence:**
- `web/blueprints/settings.py` — presets, sanitiser, signed-cookie UID, `@app_context_processor`, `/settings/appearance` + `/save`
- `web/templates/appearance.html` — 6 preset cards + per-axis controls + live-apply JS
- `web/templates/base.html` — `<html>` emits `data-wt-*` from injected `wt_appearance`
- Round-trip verified: save Console → `/` renders `data-wt-palette="console"` + `data-theme="dark"`; prefs file `<32-hex>.yaml` written and git-ignored
- `tests/unit/test_appearance_validation.py` — 9 tests (whitelist + UID traversal) pass
- Scope-corrected per inception: nav-layout cards deferred to S2, accent override dropped

## Updates

### 2026-05-22T10:06:08Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1988-watchtower-settingsappearance-page--pres.md
- **Context:** Initial task creation

### 2026-05-22T18:48:59Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: later → now (auto-sync)
