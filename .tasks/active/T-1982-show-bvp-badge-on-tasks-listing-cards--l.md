---
id: T-1982
name: "show BVP badge on /tasks listing cards + list view — T-1980 sibling"
description: >
  show BVP badge on /tasks listing cards + list view — T-1980 sibling

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: []
components: [tests/playwright/test_tasks_listing_bvp.py, web/blueprints/tasks.py, web/templates/base.html, web/templates/_partials/bvp_badge.html, web/templates/task_detail.html, web/templates/tasks.html]
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-21T15:52:30Z
last_update: 2026-05-21T16:04:44Z
date_finished: 2026-05-21T16:04:44Z
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
  - ts: '2026-05-21T16:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-05-21T16:00:03Z'
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

# T-1982: show BVP badge on /tasks listing cards + list view — T-1980 sibling

## Context

User's recurring feedback "still not seeing BVP calculation / scores on tasks frontmatter / cards" — T-1980 fixed the detail page but `/tasks` listing (kanban + list) has zero BVP visibility. Surface a compact `BVP_norm` chip on every card. Italic + `*` for proposed-mode; plain for confirmed; nothing for none-mode (keeps cards lean).

## Acceptance Criteria

### Agent
- [x] `_attach_bvp_to_tasks(tasks)` batch helper in `web/blueprints/tasks.py` — loads policy ONCE, loops the task list, attaches `t["_bvp"] = {mode, norm}` (or omits when mode=none)
- [x] `/tasks` route calls the batch helper after filtering, before render
- [x] `web/templates/_partials/bvp_badge.html` macro renders a small chip: confirmed → `BVP 0.58`, proposed → italic `BVP 0.58*` with `title=` tooltip
- [x] Kanban card meta row shows the chip after `arc_badge(task)`
- [x] List view adds a "BVP" column (between "Arc" and "Tags") rendering the chip
- [x] Playwright test pins DOM: at least one `.bvp-badge` element exists on `/tasks?view=list` (any task with bvp_scores or bvp_scores_proposed)
- [x] Playwright test pins DOM: kanban view on `/tasks` also surfaces `.bvp-badge` elements

### Human
- [ ] [REVIEW] BVP chip rhythm — does the badge read as informative without crowding the card?
  **Steps:**
  1. Open http://192.168.10.107:3000/tasks (kanban view)
  2. Scan 5-10 cards in any column
  3. Switch to list view via the toggle
  4. Confirm a proposed-mode badge (italic + `*`) reads distinctly from a confirmed badge
  **Expected:** Chip is visible but not dominant; you can identify high-BVP tasks at a glance; italic+asterisk provenance signal is legible
  **If not:** Note which cards feel crowded; consider hiding chip in compact view

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

python3 -c "import ast; ast.parse(open('web/blueprints/tasks.py').read())"
out=$(curl -sf "$(bin/fw watchtower url)/tasks?view=list" 2>&1); [[ "$out" == *'bvp-badge'* ]]
out=$(curl -sf "$(bin/fw watchtower url)/tasks" 2>&1); [[ "$out" == *'bvp-badge'* ]]

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

**Recommendation:** GO — close after a 1-minute scan of /tasks.

**Rationale:** Addresses user's recurring "still not seeing BVP on tasks frontmatter / cards" feedback at the listing surface (T-1980 fixed the detail page; this fixes the at-a-glance view). Batch helper loads policy once for all 1200+ tasks — no perf concern. Italic + `*` provenance signal matches the /bvp + /arcs convention. Confirmed-mode + proposed-mode both render with distinct CSS class hooks so styling can diverge later if needed.

**Evidence:**
- `web/blueprints/tasks.py:_attach_bvp_to_tasks` — batch helper, policy loaded once
- `web/templates/_partials/bvp_badge.html` — macro with italic+asterisk for proposed-mode
- `web/templates/tasks.html` — kanban card meta row + list view "BVP" column wired
- `web/templates/base.html` — `.bvp-badge` CSS rule + `.bvp-badge-proposed em` italic
- `tests/playwright/test_tasks_listing_bvp.py` — 4/4 PASS (list + kanban + href contract + proposed-mode signal)
- Live curl: `/tasks?view=list` returns `<a class="bvp-badge bvp-badge-proposed" href="/tasks/T-332#bvp-block">…BVP 0.XX*…</a>` markup; T-1915 shows `BVP 0.58*`

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

### 2026-05-21T15:52:30Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1982-show-bvp-badge-on-tasks-listing-cards--l.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.4)

- **Scan ID:** R-fb6a5b80
- **Timestamp:** 2026-05-21T16:04:47Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#3 (Agent)** — `web/templates/_partials/bvp_badge.html` macro renders a small chip: confirmed → `BVP 0.58`, proposed → italic `BVP 0.58*` with `title=` tooltip
  - **AC-verify-mismatch** (narrow, heuristic) — `path=web/templates/_partials/bvp_badge.html in: `web/templates/_partials/bvp_badge.html` macro renders a small chip: confirmed → `BVP 0.58`, proposed → italic `BVP 0.58*` with `title=` tooltip`

### 2026-05-21T16:04:44Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
