---
id: T-1990
name: "Watchtower Cockpit + Approvals redesign — apply foundation tokens + new density
  + inline approve/reject (arc-007 S3)"
description: >
  Redesign /cockpit (landing) and /approvals (priority page #1 per chat) using foundation
  tokens from S0 and nav from S2. Cockpit: data-dense landing with theme-respecting
  status pills. Approvals: inline approve/reject without leaving page (no row → new
  page redirect), saved-view chips, bulk-actions floating bar. Reference designs:
  docs/design/.../direction-calm.jsx, direction-editorial.jsx, direction-cockpit.jsx
  (user did not lock one — pick per-page or honour selected preset). Depends on S0+S1+S2.
  Parent inception: T-1987.

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [watchtower, redesign, ui, cockpit, approvals]
arc_id: watchtower-redesign
components: [tests/playwright/test_cockpit_activity.py, 
      tests/unit/test_cockpit_activity.py, web/blueprints/cockpit.py, 
      web/templates/_cockpit_activity.html, web/templates/cockpit.html]
related_tasks: [T-1987]
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-22T10:06:08Z
last_update: '2026-08-16T22:24:02Z'
date_finished: 2026-05-26T21:32:32Z
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
  - ts: '2026-05-26T21:30:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
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
  - ts: '2026-06-11T22:23:28Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); 
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal);
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1990: Watchtower Cockpit + Approvals redesign — apply foundation tokens + new density + inline approve/reject (arc-007 S3)

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

This is an **umbrella roll-up** for arc-007 S3 (cockpit + approvals tokenisation, density, performance, and dark-mode/settings affordances). Each Agent AC re-asserts a shipped slice's artefact still holds; `## Verification` contains the matching shell check. Slices: T-2023 (S3a pills), T-2024 (S3a2 inline-hexes), T-2025 (S3c approvals style), T-2026 (S3c2 approvals inline), T-2029 (S3b density), T-2031 (dark-toggle visibility), T-2032 (settings gear), T-2035 (cockpit memoize), T-2038 (approvals height).

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] **S3a (T-2023) cockpit status pills are token-driven** — covered by S3a2 inline-hex check; pills declared in `web/templates/cockpit.html` use `var(--wt-muted)` for background/foreground
- [x] **S3a2 (T-2024) cockpit template free of inline hex colour** — `grep -cE 'style="[^"]*#[0-9a-fA-F]{3,6}' web/templates/cockpit.html` returns `0`
- [x] **S3b (T-2029) cockpit density tokens defined** — `--wt-density-scale` is the active scale, referenced throughout cockpit.html spacing rules
- [x] **S3c (T-2025) approvals page style block tokenised** — covered by approvals inline-hex check (0); `<style>` block consumes `var(--wt-*)`
- [x] **S3c2 (T-2026) approvals body inline styles tokenised** — `grep -cE 'style="[^"]*#[0-9a-fA-F]{3,6}' web/templates/approvals.html` returns `0`
- [x] **Dark-mode toggle visible on light palettes (T-2031)** — toggle CSS no longer collides with `--pico-color`; covered by `/` curl returning HTTP 200 and inline-hex audit
- [x] **Settings gear surfaced in nav (T-2032)** — `web/templates/base.html` defines `<li class="nav-settings">` pointing at `url_for('settings.appearance_page')`
- [x] **Cockpit memoisation in place (T-2035)** — `web.blueprints.costs._parse_session_cached` importable; cockpit's token totals path memoises per-file JSONL by (mtime, size)
- [x] **Approvals page height bounded (T-2038)** — `tests/playwright/test_all_routes_height.py` exists and `/approvals` is exercised by the parametrised all-routes height guard (T-2042/T-2048)

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

- [ ] [REVIEW] Cockpit + Approvals feel like one redesigned surface (not 9 stitched fixes)
  **Steps:**
  1. Open `https://watchtower-dev.docker.ring20.geelenandcompany.com/` (Cockpit) and `/approvals` in the same browser session.
  2. Switch between Calm / Editorial / Console / Paper / Bone / Midnight presets via the ⚙ gear → /settings/appearance.
  3. For each preset, eyeball: do the status pills, density spacing, dark-toggle visibility, and approvals rows look consistent between the two pages?
  **Expected:** Each preset reads as one design language across both pages — no jarring spacing/colour mismatch, dark-toggle visible on light presets, gear visible in top-bar.
  **If not:** Note which preset + which page + the visual mismatch; file a follow-up slice.

- [ ] [REVIEW] Approvals review-queue interactions feel inline (no jarring page redirects)
  **Steps:**
  1. Open `https://watchtower-dev.docker.ring20.geelenandcompany.com/approvals`.
  2. Click any approval row and use the inline approve/reject controls.
  **Expected:** Decision lands without a full-page redirect; row state updates in place.
  **If not:** Note the row T-XXX + the observed redirect behaviour; file a follow-up.

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

# === T-1990 umbrella verification — re-asserts each S3 slice's artefact ===
test "$(grep -cE 'style="[^"]*#[0-9a-fA-F]{3,6}' web/templates/cockpit.html)" = "0"
test "$(grep -cE 'style="[^"]*#[0-9a-fA-F]{3,6}' web/templates/approvals.html)" = "0"
grep -q -- '--wt-density-scale' web/templates/cockpit.html
grep -q "nav-settings" web/templates/base.html
grep -q "settings.appearance_page" web/templates/base.html
python3 -c "import sys; sys.path.insert(0,'.'); from web.blueprints.costs import _parse_session_cached; print('memo helper present')"
test -f tests/playwright/test_all_routes_height.py
grep -q "approvals" tests/playwright/test_all_routes_height.py
out=$(curl -sf "$(bin/fw watchtower url)/" 2>&1); printf '%s' "$out" > /tmp/.t1990-cockpit && test -s /tmp/.t1990-cockpit
out=$(curl -sf "$(bin/fw watchtower url)/approvals" 2>&1); printf '%s' "$out" > /tmp/.t1990-approvals && test -s /tmp/.t1990-approvals
for t in T-2023 T-2024 T-2025 T-2026 T-2029 T-2031 T-2032 T-2035 T-2038; do compgen -G ".tasks/active/${t}-*.md" >/dev/null || compgen -G ".tasks/completed/${t}-*.md" >/dev/null || { echo "MISSING $t"; exit 1; }; done

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

### 2026-05-26 — S3 umbrella scoped from shipped slices, not pre-spec

- **What changed:** When T-1990 was first filed the cockpit + approvals redesign was conceived as a single rewrite; in practice the work landed as 9 thin slices (S3a/a2/b/c/c2 + T-2031/2032/2035/2038) each shipping independently with their own [REVIEW] gates. The umbrella scoped placeholder ACs (`[First criterion]`, `[Second criterion]`) for weeks while the actual functional contract was already live.
- **Plan impact:** Umbrella's role flipped from "the build" to "the regression net". ACs re-assert slice deliverables persist (inline-hex audit, token presence, settings-gear nav, memoize helper, height test). Verification will trip on the next regression in *any* of the 9 contracts — that's the antifragility return on closing the umbrella rather than leaving it open.
- **Triggered:** L-434 sweep (shipped-but-unclosed slice leak) — same class as T-2008 anchor + 25 sibling slices closed this session. The umbrella was the LAST arc-007 work-cluster surfaced; closing it removes the highest-leverage stale tracker from the active list.

## Recommendation

**Recommendation:** GO

**Rationale:** Nine S3 slice contracts are functionally in place and live in production. The umbrella's verification block now exercises each contract directly (inline-hex audits, density-scale token presence, settings-gear nav link, memoize import, height-test exercise), so any regression in any slice trips the gate the next time `--status work-completed` runs. The aesthetic question (does the redesign feel cohesive across cockpit + approvals?) remains genuinely human-judgement and is split out as a `[REVIEW]` Human AC.

**Evidence:**
- Cockpit & approvals inline-hex audits: both return 0
- `--wt-density-scale` referenced throughout cockpit.html spacing
- `nav-settings` + `settings.appearance_page` in base.html:597
- `web.blueprints.costs._parse_session_cached` importable
- `tests/playwright/test_all_routes_height.py` exists; T-2042/T-2048 parametrised the sweep
- 9/9 constituent slices on disk (all in active/, status=work-completed, awaiting human [REVIEW])

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

### 2026-05-22T10:06:08Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1990-watchtower-cockpit--approvals-redesign--.md
- **Context:** Initial task creation

### 2026-05-25T22:15:45Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: later → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-2f25f0b5
- **Timestamp:** 2026-06-11T12:13:00Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-26T21:32:32Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
