---
id: T-2023
name: "arc-007 S3a — cockpit theme-respecting status pills (token-ize hardcoded status
  hexes)"
description: >
  arc-007 S3a — cockpit theme-respecting status pills (token-ize hardcoded status
  hexes)

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [arc:watchtower-redesign, ui, watchtower, cockpit]
components: [tests/playwright/test_cockpit_status_pills.py, 
      tests/unit/test_cockpit_status_pills.py, web/templates/cockpit.html]
related_tasks: [T-1990, T-1987, T-2021, T-2022]
arc_id: watchtower-redesign
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-24T10:53:17Z
last_update: '2026-05-28T22:54:11Z'
date_finished: 2026-05-25T22:40:55Z
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
  - ts: '2026-05-24T11:00:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-05-24T11:00:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-28T22:54:11Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2023: arc-007 S3a — cockpit theme-respecting status pills (token-ize hardcoded status hexes)

## Context

First slice of arc-007 S3 (T-1990 Cockpit + Approvals redesign). Per the human's
2026-05-24 decision, the redesigns **honour the selected preset** — use `--wt-*`
tokens only, nothing hardcoded, so every page follows the live
`/settings/appearance` palette.

The cockpit's status indicators violate that: they use hardcoded hexes
(`cockpit.html` inline CSS) that do NOT re-theme —
`.wt-badge-pass #2e7d32`, `.wt-badge-warn #f9a825`, `.wt-badge-fail #c62828`,
`.wt-queue-status.issues #c62828`, `.wt-queue-status.started-work #1565c0`.
The foundation tokens already define per-palette semantic colors
(`--wt-success/--wt-warn/--wt-danger/--wt-info`, tuned for each of the 6 palettes,
`foundations.css §palettes`). This slice maps the cockpit's status colours onto
those tokens so the audit badge and work-queue statuses re-theme per palette, and
upgrades the plain coloured queue-status text into proper pills (the redesign's
"theme-respecting status pills").

Scope fence: cockpit status colours only. No layout/density changes (later S3
slices); approvals page untouched (sovereignty surface — separate handling).

## Acceptance Criteria

### Agent
- [x] The cockpit audit badge (`.wt-badge-pass/warn/fail`) uses `var(--wt-success/--wt-warn/--wt-danger)` instead of hardcoded hexes — re-themes per palette. (unit: cockpit inline CSS contains `var(--wt-success)` etc. and no `#2e7d32`/`#f9a825`/`#c62828` in the badge rules)
- [x] The work-queue status (`.wt-queue-status`) renders as a token-based pill — `.issues`→`--wt-danger`, `.started-work`→`--wt-info`, plus `.captured`→`--wt-muted` and `.work-completed`→`--wt-success` — no hardcoded status hexes remain **in the `.wt-queue-status` rules**. (unit: the queue-status rules use `var(--wt-*)`; old `color:#c62828`/`#1565c0` rules gone). Scope fence: the cockpit's many *inline-style* hexes (verdict pills, concerns counts, card borders) are a separate follow-up slice — see Evolution.
- [x] Per-palette re-theming proven in a browser — switching `[data-wt-palette]` changes the computed pill colour. (Playwright: audit badge / queue pill colour differs between two palettes)
- [x] Reviewer static scan passes. (Verification: `bin/fw reviewer T-2023` → Overall PASS)

### Human
- [ ] [REVIEW] Status pills read well and re-theme cleanly across palettes
  **Steps:**
  1. Open the cockpit: `cd /opt/999-Agentic-Engineering-Framework && bin/fw watchtower url` → open that URL
  2. At `/settings/appearance`, switch between a few palettes (e.g. Bone, Paper, Console, Midnight)
  3. Watch the audit badge and the work-queue status pills — confirm their colours shift with the palette and stay legible (good contrast) in both light and dark
  **Expected:** Pills follow the palette accent/semantic colours, read clearly, and don't clash with the surrounding cards
  **If not:** Note the palette + which pill looks off (low contrast / wrong hue) and screenshot

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

# template compiles
python3 -c "from web.app import app; app.jinja_env.get_template('cockpit.html')"
# status colours are token-based (no hardcoded status hexes remain in the badge/queue rules)
python3 -m pytest tests/unit/test_cockpit_status_pills.py -q
# reviewer static scan passes
out=$(bin/fw reviewer T-2023 2>&1); echo "$out" | grep -q "Overall:.*PASS"

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

### 2026-05-24 — first S3 slice; cockpit status colours only (honour-selected-preset)
- **What changed:** Confirmed the cockpit already uses `wt-*` structural tokens heavily (cards/sections/pulse), so "apply foundation tokens" is largely done — the live gap is the *status colours*, which were hardcoded hexes that defeat the palette. The human's "honour selected preset" decision makes token-mapping the correct, unambiguous approach (no per-page palette to choose).
- **Plan impact:** S3 decomposes; this slice (S3a) is colour-token-only. Cockpit density/layout and the approvals page become later slices (approvals handled with sovereignty care — no autonomous bulk-decision UX).
- **Triggered:** Sibling slices to file as S3b+ (cockpit density, approvals token restyle). Not filed yet — re-propose per BVP.

### 2026-05-24 — scope discovered: cockpit has 15+ inline-style hexes beyond the status classes
- **What changed:** On survey, the cockpit isn't just the `.wt-badge`/`.wt-queue-status` classes — verdict pills (`#1b5e20`/`#e65100`/`#b71c1c`/`#0e7490`/`#616161`), action-summary counts (`#f59e0b`/`#1565c0`/`#7c3aed`), concerns counts (`#1565c0`/`#e65100`/`#c62828`), card borders (`.wt-card-*`), and the Strength line all use hardcoded inline hexes that also defeat the palette.
- **Plan impact:** S3a stays scoped to the named status classes (badge + queue pills) — the cleanest, lowest-risk first cut. Token-izing the inline-style hexes is more invasive (per-element style edits, higher eyes-on burden) and belongs in its own slice.
- **Triggered:** Follow-up slice "S3a2 — cockpit inline-style hexes → semantic tokens" (not filed yet; re-propose per BVP).

## Decisions

### 2026-05-24 — semantic tokens, not accent, for status colours
- **Chose:** Map status colours to `--wt-success/--wt-warn/--wt-danger/--wt-info` (per-palette semantic tokens), not to `--wt-accent`.
- **Why:** Status meaning (pass/warn/fail) must stay readable as green/amber/red-family; the foundation already tunes these per palette so they re-theme while preserving meaning. Using the single accent would collapse the semantic distinction.
- **Rejected:** `--wt-accent` for all (loses pass/warn/fail distinction); keeping hardcoded hexes (defeats the palette — the bug).

## Recommendation

**Recommendation:** GO (pending the one [REVIEW] Human AC)

**Rationale:** Smallest sensible first S3 slice — maps the cockpit's hardcoded
status colours onto the existing per-palette semantic tokens so the audit badge
and work-queue pills honour the selected preset. Zero new infrastructure, contained
to cockpit status colours. Agent ACs are unit + Playwright covered; the Human AC is
an eyes-on taste/contrast check across palettes.

**Evidence:**
- Unit `tests/unit/test_cockpit_status_pills.py` — badge/queue rules use `var(--wt-success/warn/danger/info)`; no hardcoded status hexes remain.
- Playwright `tests/playwright/test_cockpit_status_pills.py` — switching `[data-wt-palette]` changes the computed pill colour (re-theming proven); review screenshot.
- Eyes-on screenshot `web/static/ux-review/T-2023-cockpit-status-pills.png`.
- Reviewer `fw reviewer T-2023` — Overall PASS.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-05-24T10:53:17Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2023-arc-007-s3a--cockpit-theme-respecting-st.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-15a4d111
- **Timestamp:** 2026-05-25T22:40:57Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-05-25T22:40:55Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
