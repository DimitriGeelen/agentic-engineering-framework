---
id: T-2025
name: "arc-007 S3c — approvals page style block to semantic tokens"
description: >
  arc-007 S3c — approvals page style block to semantic tokens

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [arc:watchtower-redesign, ui, watchtower, approvals]
components: [tests/playwright/test_approvals_content_tokens.py, 
      tests/playwright/test_approvals_style_tokens.py, 
      tests/unit/test_approvals_content_tokens.py, 
      tests/unit/test_approvals_style_tokens.py, 
      web/templates/_approvals_content.html, web/templates/approvals.html]
related_tasks: [T-1990, T-1987, T-2023, T-2024]
arc_id: watchtower-redesign
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-24T11:19:51Z
last_update: '2026-05-28T22:54:11Z'
date_finished: 2026-05-25T22:42:56Z
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
  - ts: '2026-05-24T11:30:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-05-24T11:30:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-28T22:54:11Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F1=0 (no-signal); 
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2025: arc-007 S3c — approvals page style block to semantic tokens

## Context

arc-007 S3 covers Cockpit **+ Approvals** (T-1990). S3a/S3a2 tokenised the cockpit;
this slice tokenises the **`approvals.html` `<style>` block** (29 hardcoded hexes) so
the approvals page honours the live `/settings/appearance` palette (the human's
2026-05-24 "honour the selected preset" decision). Restyle ONLY — no markup, no
buttons, no decision logic; the approvals page is a sovereignty surface and this slice
must not add bulk-decision UX. Worked precedent: T-2023 (queue-pill tint pattern),
T-2024. One deliverable: the `approvals.html` page stylesheet.

Scope fence: the inline-styled verdict pills / filter buttons / severity spans in
`_approvals_content.html` (39 sites) are a separate slice (S3c2), NOT this task.

Hex→token map: card accents (pending/approved/rejected/go-decision/human-ac-group),
approve/reject buttons + hovers, status badges (pending/approved/rejected/expired) and
confidence badges (review/rubber-stamp/startedwork/workcompleted) via the tint+token
queue-pill pattern, stat-value colours (tier0/go/ac/decisions), decision text
(go/nogo/defer). Alpha-hex suffixes (`08/22/44/55`) become `color-mix` percentages.

## Acceptance Criteria

### Agent
- [x] Approval-card accent borders/tints (pending/approved/rejected/go-decision/human-ac-group) use `var(--wt-*)` / `color-mix(var(--wt-*) …)`; no `#f59e0b/#10b981/#ef4444/#1565c0/#7c3aed` literals in those rules
- [x] `.btn-approve`/`.btn-reject` (+ `:hover`) use semantic tokens; no `#10b981/#059669/#ef4444` literals
- [x] Status badges + confidence badges use the tint+token pattern (`color-mix` bg/border + `var(--wt-*)` text); no `#…22/#…55` ink/tint literals
- [x] Stat-value colours (tier0/go/ac/decisions) and decision text (go/nogo/defer) use tokens; no `#f59e0b/#1565c0/#7c3aed/#10b981/#ef4444/#6b7280` literals in those rules
- [x] No hardcoded theme hex remains in the `approvals.html` `<style>` block (grep clean — only `#000` color-mix darken anchor)
- [x] Unit test asserts token rules present + old hexes gone + `approvals.html` compiles
- [x] Playwright test proves an approvals element re-themes when `[data-wt-palette]` switches, with an eyes-on review screenshot captured

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
- [ ] [REVIEW] Approvals page reads cleanly under the selected palette; badges/buttons keep adequate contrast and the sovereignty affordances stay unambiguous
  **Steps:**
  1. Ensure the dev Watchtower serves current templates (restart if needed): `cd /opt/999-Agentic-Engineering-Framework && bin/fw serve` (templates are cached)
  2. Open `$(bin/fw watchtower url)/approvals` and switch palettes at `/settings/appearance` across `linen / stone / paper / bone / console`
  3. Check: pending/approved/rejected card accents, Approve (green) / Reject (red) buttons, the status + confidence badges, the stat-value counts, and GO/NO-GO/DEFER decision text
  **Expected:** Every coloured element shifts with the palette; Approve still reads clearly green / Reject clearly red (the approve/reject distinction must never be ambiguous on a sovereignty surface); badge tint backgrounds keep their text legible in all five palettes
  **If not:** Note the palette + element; a badge text token may need a darker/lighter variant, or a button may need a non-token safety colour for the approve/reject distinction

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
python3 -m pytest tests/unit/test_approvals_style_tokens.py -q
python3 -c "from web.app import app; app.jinja_env.get_template('approvals.html')"

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

### 2026-05-24 — approvals colour palette is wider than the cockpit's
- **What changed:** The approvals page uses a *different* hex vocabulary than the cockpit
  (Tailwind-style `#10b981/#ef4444/#f59e0b/#3b82f6` vs the cockpit's Material `#2e7d32`
  etc.). Both collapse onto the same six foundation tokens, so tokenising also *unifies*
  the two pages' colour language — a latent benefit beyond re-theming.
- **Plan impact:** Confirmed the S3c/S3c2 split (page stylesheet vs `_content` inline
  styles) — 68 sites across two surfaces was too big for one slice.
- **Triggered:** S3c2 filed mentally (NOT yet a task): `_approvals_content.html` inline
  verdict pills / filter buttons / severity spans / submit buttons.

## Decisions

### 2026-05-24 — badges use tint+token, not separate ink hexes
- **Chose:** Render status/confidence badges as `color-mix(in srgb, var(--wt-X) 13%,
  transparent)` background + `var(--wt-X)` text + `color-mix(… 33%, transparent)` border,
  dropping the hardcoded ink hexes (`#b45309/#047857/#dc2626/#1d4ed8`).
- **Why:** Matches the T-2023 queue-pill precedent; one token per semantic state re-themes
  the whole badge. Per-state ink hexes would not re-theme and would re-introduce drift.
- **Rejected:** Keeping the dark ink hexes (don't re-theme); a new `--wt-*-ink` token set
  (scope creep — the foundation tokens already give acceptable contrast on a 13% tint).

### 2026-05-24 — approve/reject must stay unambiguous (sovereignty)
- **Chose:** Map approve→`--wt-success`, reject→`--wt-danger`, but flag the green/red
  legibility across all palettes as the load-bearing Human [REVIEW].
- **Why:** Approvals is a sovereignty surface; if a palette ever made approve/reject hard
  to tell apart, that is a safety regression, not a cosmetic one. The human signs off.
- **Rejected:** Hardcoding approve/reject to fixed green/red (defeats the honour-selected
  decision) — deferred to the [REVIEW]; if a palette fails, that's the documented fallback.

## Recommendation

- **Recommendation:** GO
- **Rationale:** All 7 Agent ACs pass. The `approvals.html` `<style>` block (29 hardcoded
  hexes) now references foundation semantic tokens — card accents, approve/reject buttons,
  status + confidence badges (tint+token queue-pill pattern), stat-value colours, and
  decision text all re-theme with the live palette. Only `#000` remains (the darken anchor
  inside the `btn-approve:hover` color-mix). Re-theming is pinned by a unit test (token
  rules present, old hexes gone, no residual theme hex, template compiles — 6 green) and a
  Playwright test (a `.badge-approved` probe changes computed colour across
  `paper`→`console`). Eyes-on under `bone` confirmed the page renders cleanly with no
  breakage. Restyle only — no markup, no buttons, no decision logic touched (sovereignty).
- **Evidence:**
  - `web/templates/approvals.html` `<style>` — grep shows only `#000` remains
  - `tests/unit/test_approvals_style_tokens.py` — 6 passed in 0.52s
  - `tests/playwright/test_approvals_style_tokens.py` — 2 passed (probe re-theme + screenshot)
  - `web/static/ux-review/T-2025-approvals-style-tokens.png` — eyes-on artefact (bone palette)
  - Reviewer: see `## Reviewer Verdict` below
- **Human [REVIEW] remaining:** approve/reject legibility + badge contrast across all 5
  palettes (the sovereignty-load-bearing Human AC).
- **Scope note for the reviewer:** the arc-closure "Approve / Override" buttons and the
  inline verdict pills / filter buttons / severity spans live in `_approvals_content.html`
  (pico-primary or hardcoded inline) and are S3c2, NOT this slice — they will still look
  pre-redesign until S3c2 ships.

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

### 2026-05-24T11:19:51Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2025-arc-007-s3c--approvals-page-style-block-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-3fa707ba
- **Timestamp:** 2026-05-25T22:42:58Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-05-25T22:42:56Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
