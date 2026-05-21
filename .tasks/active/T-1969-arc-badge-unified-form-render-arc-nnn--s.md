---
id: T-1969
name: "Arc badge unified form: render 'arc-NNN · slug' resolving the missing form
  at render time"
description: >
  Arc badge unified form: render 'arc-NNN · slug' resolving the missing form at render
  time

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [ui, arc-badge, arc-display, arc:arc-grooming]
components: [web/blueprints/arcs.py, web/app.py, web/templates/_partials/arc_badge.html, tests/unit/test_arc_display_helper.py, tests/playwright/test_arc_badge.py]
related_tasks: [T-1849, T-1909, T-1968]
arc_id: arc-grooming
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-20T21:19:52Z
last_update: 2026-05-21T08:19:34Z
date_finished: 2026-05-21T08:19:34Z
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
  - ts: '2026-05-20T21:30:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-05-20T21:30:02Z'
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

# T-1969: Arc badge unified form: render 'arc-NNN · slug' resolving the missing form at render time

## Context

User pushback during arc-badge contrast review (T-1968 v2): "ok better still see arc names and arc numbers used mixed". The arc-badge currently displays whatever string `task.arc_id` holds — either the canonical id ("arc-006") or the slug ("value-prioritisation"), depending on how the task was authored. Both forms are accepted per T-1849 §D-Immutability + slug-equivalence rules. The mix is jarring visually.

User-selected display form (via AskUserQuestion preview): **"Both (id · slug)"** — e.g. `arc-006 · value-prioritisation`.

Resolution at render time:
- If `task.arc_id` is `arc-NNN` form → look up arc YAML, read `slug:` field
- If `task.arc_id` is slug form → look up arc YAML by slug, read `id:` (or compute from filename)
- Fall back to single form if the other doesn't resolve (orphan arc reference)

Existing helpers in `lib/arc.sh`: `_resolve_arc_slug` and `_resolve_arc_id` (per arc_badge.html comment).

**Affected files:**
- `web/templates/_partials/arc_badge.html` (the macro)
- `web/blueprints/*.py` — likely need a `arc_display(arc_id)` helper that returns the combined "id · slug" string, with caching for performance (28 badges on /arcs/arc-006 = 28 lookups otherwise)
- Possibly `web/shared.py` if there's already a Jinja context processor for arc data

## Acceptance Criteria

### Agent
- [x] Helper `arc_display(arc_id_or_slug)` in `web/blueprints/arcs.py` returns "arc-NNN · slug", with fallback to single form when YAML lacks `id:` or when id==slug
- [x] Helper memoized via `@lru_cache(maxsize=128)` — one YAML read per arc per process, not per badge
- [x] `arc_badge` macro updated to call `arc_display()` Jinja global and display combined form
- [x] All existing arc-badge instances render the new combined form — Playwright `test_arc_badge_shows_dual_form` passes
- [x] Click behavior unchanged — badge `href` still uses raw `_aid`; Playwright `test_arc_badge_link_navigates` still passes
- [x] Unit test `tests/unit/test_arc_display_helper.py` — 8/8 green: empty input, arc-NNN→dual, slug→dual, missing-id-fallback, degenerate-id==slug, unresolvable-verbatim, lru-cache-memoization, whitespace-stripped

### Human
- [ ] [REVIEW] Arc badges show consistent "arc-NNN · slug" form across all pages
  **Steps:**
  1. Hard-refresh http://192.168.10.107:3000/tasks
  2. Look at the arc-badge pills — should all read like "arc-003 · orchestrator-rethink" (no bare-slug, no bare-id)
  3. Click a badge — should navigate to /arcs/<that arc> as before
  **Expected:** Consistent dual-form display; no visual mix between badges; click navigation unchanged.
  **If not:** Note which task's badge shows only one form and check `task.arc_id` in its file.

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

python3 -m pytest tests/unit/test_arc_display_helper.py -q
python3 -m pytest tests/playwright/test_arc_badge.py -q
out=$(curl -s http://localhost:3000/tasks 2>&1); grep -qE '>arc-[0-9]{3} · [a-z]' <<<"$out"

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

### 2026-05-21 — implemented as single-helper + Jinja-global

- **What changed:** Initial spec considered both a Jinja filter and a context processor. Final choice: single Python helper `arc_display()` in `web/blueprints/arcs.py` (next to existing `_resolve_arc_slug` / `_read_arc`), exposed as `arc_display` Jinja global. Reason: keeps related arc-resolution logic colocated; one import in `web/app.py`; no per-request overhead because `lru_cache` is process-wide.
- **Plan impact:** "Possibly `web/shared.py`" line in Context section is moot — the natural home was `arcs.py` alongside other arc helpers.
- **Triggered:** No new task.

## Recommendation

**Recommendation:** GO

**Rationale:** User pushback during T-1968 v2 review explicitly named the dual-form ("Both (id · slug)") preference. Implementation is one helper + one Jinja-global registration + one macro change; YAML reads are memoized so the 28-badges-per-page render cost is one cold read per arc. Backend `_resolve_arc_slug` already accepts both forms, so navigation is unchanged. All 8 unit tests + 6 Playwright tests green; live `/tasks` confirms badges now render `arc-003 · orchestrator-rethink` etc.

**Evidence:**
- `web/blueprints/arcs.py` — new `arc_display()` helper with lru_cache memoization
- `web/app.py:140-142` — Jinja global registration
- `web/templates/_partials/arc_badge.html` — macro calls `arc_display(_aid)` for both `title=` and link text
- `tests/unit/test_arc_display_helper.py` — 8/8 PASS (empty, dual-form-from-id, dual-form-from-slug, missing-id-fallback, degenerate, unresolvable-verbatim, lru-cache, whitespace)
- `tests/playwright/test_arc_badge.py` — 6/6 PASS (kanban, list, arc-detail, link-nav, dual-form, title-dual-form)
- Live curl on `/tasks` confirms `arc-003 · orchestrator-rethink`, `arc-002 · embeddings-strategy` rendering

**Review on Watchtower:** http://192.168.10.107:3000/review/T-1969

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

### 2026-05-20T21:19:52Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1969-arc-badge-unified-form-render-arc-nnn--s.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.4)

- **Scan ID:** R-10659924
- **Timestamp:** 2026-05-21T08:20:34Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#1 (Agent)** — Helper `arc_display(arc_id_or_slug)` in `web/blueprints/arcs.py` returns "arc-NNN · slug", with fallback to single form when YAML lacks `id:` or when id==slug
  - **AC-verify-mismatch** (narrow, heuristic) — `path=web/blueprints/arcs.py in: Helper `arc_display(arc_id_or_slug)` in `web/blueprints/arcs.py` returns "arc-NNN · slug", with fallback to single form when YAML lacks `id:` or when `

### 2026-05-21T08:19:34Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
