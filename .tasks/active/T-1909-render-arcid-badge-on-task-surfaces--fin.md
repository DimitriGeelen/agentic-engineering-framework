---
id: T-1909
name: "Render arc_id badge on task surfaces — finish the T-1849 visibility job (kanban
  + list + arc-detail constituents)"
description: >
  Complete the visible surface for the arc_id design principle agreed 2026-05-15 (HANDOFF-arc-grooming
  Q1 → T-1848 / T-1849 / T-1850). Tasks now carry arc_id: in frontmatter, 162 were
  migrated, six reader surfaces sweep arc_id, but the /tasks kanban card and list
  view do NOT display the arc_id badge — arc membership is invisible except via filter
  chip. Also the /arcs/<slug> constituent-tasks table has no arc_id column. This is
  the symmetric-to-T-XXXX visibility the user explicitly wanted: 'tasks can be assigned
  to arcs, simply by filling in an ARc-id field value in the tasks arc-id value field
  ... that all wraps into the corresponding arc'. Render the badge on three surfaces.

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [watchtower, ui, arc]
components: [lib/arc_membership.sh, lib/arc.sh, 
      tests/playwright/test_arc_badge.py, 
      tests/playwright/test_arc_page_parity.py, 
      tests/unit/arc_membership_dual_id.bats, web/blueprints/arcs.py, 
      web/templates/arc_detail.html, web/templates/arcs_index.html, 
      web/templates/base.html, web/templates/_partials/arc_badge.html, 
      web/templates/tasks.html]
related_tasks: [T-1848, T-1849, T-1850, T-1874, T-1876, T-1879, T-1880, T-1904, 
      T-1905]
arc_id: arc-005
created: 2026-05-18T21:02:27Z
last_update: '2026-06-11T22:23:26Z'
date_finished: 2026-05-20T14:29:10Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
bvp_scores_proposed:
  - ts: '2026-05-19T18:27:46Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-28T22:54:10Z'
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
  - ts: '2026-06-11T22:23:26Z'
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
cost_estimate_proposed:
  - ts: '2026-05-19T21:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1909: Render arc_id badge on task surfaces — finish the T-1849 visibility job (kanban + list + arc-detail constituents)

## Context

Design lineage: 2026-05-15 dialogue (HANDOFF-arc-grooming Q1) — user agreed `arc-id` is a first-class sequential identifier symmetric to `T-XXXX`, and tasks belong to arcs via the `arc_id:` frontmatter field. T-1848 shipped arc-NNN ids, T-1849 shipped the field on tasks, T-1850 migrated 162 tasks, T-1874/1876/1879/1880 swept reader surfaces. But the visible surfaces never finished: `/tasks` kanban card and list view do not render the arc membership; `/arcs/<slug>` constituent-task table has no arc column. User pushback 2026-05-18 ("its actually as we discussed and agreed and decided") confirms this is the unfinished half of the agreed design.

Scope: render the arc as a clickable badge (linking to `/arcs/<arc_id>`) on three surfaces:

1. `/tasks` kanban card — small pill under the name or in the meta row
2. `/tasks?view=list` list view — column or inline pill
3. `/arcs/<slug>` constituent-task table — new column

Read `task.arc_id` from frontmatter (already loaded via `get_all_task_metadata`). Fall back to scanning `_tags` for `arc:<slug>` for any unmigrated rows (defensive — migration was 162/162 per T-1850 but cheap to include).

## Acceptance Criteria

### Agent
- [x] `/tasks` kanban card renders the arc badge when `task.arc_id` is set — linking to `/arcs/<arc_id>`. Confirmed by Playwright DOM-content assertion (T-1575 rule).
- [x] `/tasks?view=list` list view renders the arc badge in a visible column or inline near the task name. Confirmed by Playwright DOM-content assertion.
- [x] `/arcs/<slug>` constituent-task table has an "Arc" column with the arc badge on each row. Confirmed by Playwright DOM-content assertion.
- [x] A Playwright test exists in `tests/playwright/` that loads `/tasks` and asserts at least one arc badge with `arc-005` (or current arc-grooming id) is present and links to `/arcs/arc-005`.
- [x] No regression: `/tasks` page returns HTTP 200, `/arcs/arc-grooming` returns HTTP 200, both render with new badge present.

### Human
- [ ] [REVIEW] Arc badge placement and styling read well visually — pill shape sized to match existing meta-row tokens, color distinguishable from status/type/horizon selects, link affordance clear.
  **Steps:**
  1. Open `http://192.168.10.107:3000/tasks` and scan a kanban column for arc badges.
  2. Open `http://192.168.10.107:3000/arcs/arc-grooming` and scan the constituent-task table.
  3. Hover the badge — confirm `/arcs/<id>` link works.
  **Expected:** Badge is visually subordinate to task name/status but legible; clicking navigates to arc detail page.
  **If not:** Note the surface and what looks off (size/colour/placement); agent will adjust.

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

# T-1909 verification — three surfaces + Playwright test
WT_URL=$(bin/fw watchtower url 2>/dev/null || echo "http://localhost:3000"); curl -sf -o /dev/null "$WT_URL/tasks"
WT_URL=$(bin/fw watchtower url 2>/dev/null || echo "http://localhost:3000"); curl -sf -o /dev/null "$WT_URL/arcs/arc-grooming"
WT_URL=$(bin/fw watchtower url 2>/dev/null || echo "http://localhost:3000"); out=$(curl -sf "$WT_URL/tasks?view=board" 2>&1); grep -q 'class="arc-badge"' <<<"$out"
WT_URL=$(bin/fw watchtower url 2>/dev/null || echo "http://localhost:3000"); out=$(curl -sf "$WT_URL/tasks?view=list" 2>&1); grep -q '<th>Arc</th>' <<<"$out"
WT_URL=$(bin/fw watchtower url 2>/dev/null || echo "http://localhost:3000"); out=$(curl -sf "$WT_URL/arcs/arc-grooming" 2>&1); grep -q '<th>Arc</th>' <<<"$out"
out=$(bin/fw test playwright tests/playwright/test_arc_badge.py 2>&1); grep -qE '[0-9]+ passed' <<<"$out" && ! grep -qE '[0-9]+ failed' <<<"$out"

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

### 2026-05-19 — three surfaces, one macro

- **What changed:** Initial filing assumed badges would need bespoke styling per surface (kanban card vs list table vs arc-detail). During build it became obvious all three want the *same* badge token — the surface only varies in placement (meta row vs column cell). Extracted to a shared Jinja macro (`web/templates/_partials/arc_badge.html`, 24 lines) with one CSS class.
- **Plan impact:** Reduced from three surface-specific implementations to one macro + three include points. Cut LOC roughly in half versus the naïve plan.
- **Triggered:** L-AC reuse pattern reinforced for `_partials/` directory; no follow-up task needed.

### 2026-05-19 — defensive fallback to legacy tag

- **What changed:** T-1850 migrated 162 tasks from `tags: [arc:<slug>]` to canonical `arc_id:`, but the migration is one-shot — newly-filed tasks could still arrive with the legacy tag if a stale template or copy-paste leaks. Rendering against `arc_id:` alone would silently miss those.
- **Plan impact:** Macro reads `arc_id` first, falls back to scanning `tags` for `arc:<slug>` prefix. Defensive against drift without re-introducing dual-source-of-truth — `arc_id` always wins when present.
- **Triggered:** No follow-up; the fallback is bounded — once the audit catches a stale `arc:` tag it gets migrated by T-1850 logic.

## Recommendation

**Recommendation:** GO

**Rationale:**
The arc_id visibility job (T-1848 + T-1849 + T-1850) shipped the storage layer (arc-NNN ids, frontmatter field, 162-task migration) and the reader sweep (T-1874/1876/1879/1880) but never finished the user-visible render. User pushback 2026-05-18 made the omission explicit: arc membership is invisible on the three task-rendering surfaces. This patch adds the badge wherever a task is shown — kanban card, list table, arc-detail constituent table — using a shared Jinja macro that reads the canonical `arc_id` field with a defensive fallback to the legacy `arc:<slug>` tag. The implementation is small, the design lineage is settled, no axiom changes.

**Evidence:**
- `web/templates/_partials/arc_badge.html` — new shared macro (24 lines)
- `web/templates/base.html` — shared `.arc-badge` CSS (pico-themed, 18 lines)
- `web/templates/tasks.html` — macro inserted in kanban card meta row + list-view "Arc" column
- `web/templates/arc_detail.html` — macro inserted in constituent-task "Arc" column
- `web/blueprints/arcs.py` — `_read_task_meta` now passes through `arc_id` and `tags` to the template
- `tests/playwright/test_arc_badge.py` — 4 DOM-content assertions, all pass (T-1575 rule)
- Live curl: 18 badges on `/tasks?view=board`, 182 on `/tasks?view=list`, 29 on `/arcs/arc-grooming`
- Commit: `ff52e79a` — T-1909: render arc_id badge on task surfaces — finish the T-1849 visibility job

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

### 2026-05-18T21:02:27Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1909-render-arcid-badge-on-task-surfaces--fin.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.4)

- **Scan ID:** R-e9ac2c1e
- **Timestamp:** 2026-05-20T14:29:52Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-05-20T14:29:10Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
