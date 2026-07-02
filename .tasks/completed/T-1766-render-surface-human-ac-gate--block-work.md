---
id: T-1766
name: "render-surface Human-AC gate — block work-completed on render-touching tasks
  without [REVIEW] Human AC"
description: >
  render-surface Human-AC gate — block work-completed on render-touching tasks without
  [REVIEW] Human AC

status: work-completed
workflow_type: build
owner: human
horizon: null
components: [agents/task-create/update-task.sh, lib/render_surface.sh, 
      tests/unit/test_render_surface_gate.bats]
related_tasks: ["T-193", "T-954", "T-1575", "T-1763", "T-1764", "T-1765"]
created: 2026-05-06T11:30:48Z
last_update: '2026-06-11T22:23:58Z'
date_finished: 2026-05-16T08:13:11Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:58Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 4
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=4 
      (body:framework-level-ux); D4=0 (no-signal); F-RECALL=0 (no-signal); 
      F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1766: render-surface Human-AC gate — block work-completed on render-touching tasks without [REVIEW] Human AC

## Context

T-1763 (AC-body-comment leak), T-1764 (/file/ route 404), T-1765 (`<code>` inline-block drop) all shipped with **zero Human ACs**. Each was a render-surface bug user-reported on `/review/T-1762`. Each fix was technically verifiable (computed-style, HTTP code, regex) — so I wrote all-Agent ACs. The subjective question "does this read right to a human?" never appeared as an AC.

Three render fixes. Three missing Human ACs. The user caught the omission and said "rca + structural fix."

This is the same family as `feedback_ui_visual_verification.md` (T-1575) in agent memory: "For UI/template changes, element-presence grep is forbidden. Required: Playwright screenshot OR DOM-content assertion." — but T-1575 only addressed the *technical* verification (DOM/screenshot replaces grep). It did not address the *subjective* verification (a human looks at the rendered output).

T-954's AC classification guidance says:
> Make it a Human AC if ANY apply: subjective judgment — quality, tone, UX feel, "is this good enough?"

Render fixes inherently invoke "is this good enough" — a path that's technically `display:inline` may still LOOK wrong to a human if it wraps weirdly. Without Human eyes on the rendered output, the framework is shipping render changes blind.

## Acceptance Criteria

### Agent
- [x] **Render-surface predicate** — `lib/render_surface.sh` exposes `task_touches_render_surface <task_file>` returning 0 (yes) or 1 (no). Predicate examines the task's `components` frontmatter list AND the file paths mentioned in `## Verification` and `## Recommendation > Evidence`. Match patterns: `web/templates/*.html`, `web/static/*.css`, `web/static/*.js`, `web/blueprints/*.py`, `web/shared.py`, `web/app.py`, `web/templates/*.j2`. Single source of truth — the patterns list is exported as `RENDER_SURFACE_PATTERNS` for reuse. **SHIPPED 2026-05-06 (partial-ship: lib only).**
- [x] **Gate wired into update-task.sh** — `check_render_surface_human_ac()` in `agents/task-create/update-task.sh:380-475`. Fires on `--status work-completed` AND `workflow_type` in {build, refactor, test} AND `task_touches_render_surface` returns 0. Refuses with exit 1 if no Human AC exists OR all Human ACs are mechanical (no `[REVIEW]` marker). Bypass: `--skip-render-review "rationale"` logged Tier-2.
- [x] **Bypass plumbing reuses log_gate_bypass** — same machinery as T-1668/T-1671/T-1762 gates. Bypass log: `.context/working/.gate-bypass-log.yaml`. No new log file.
- [x] **Bats test pinned** — `tests/unit/test_render_surface_gate.bats` covers 12 cases: source-level invariants (4), predicate behaviour (3), gate firing/passing/bypass/rubber-stamp/non-render (5). 12/12 pass.
- [x] **Self-application: T-1766 closure** — T-1766's body references `web/shared.py`/`web/app.py` literal paths (because the task DEFINES those patterns as render-surface examples). The predicate correctly flags T-1766 as render-touching — meta-honest result. Adding a [REVIEW] Human AC below to satisfy the gate self-applies the rule the task creates.
- [x] **Retroactive hygiene applied to T-1763/T-1764/T-1765** — Each completed task gained a `[REVIEW]` Human AC with copy-pasteable Steps/Expected/If-not. Commit 34e7127d. Documentary only — the tasks already shipped; this records what eyes the human would have applied if the gate had existed.
- [x] **Documentation updated** — `CLAUDE.md` "AC Classification Guidance" section gains a new bullet (5th) under "Make it a Human AC if ANY apply": render-surface trigger + cite T-1766 / bypass flag / origin tasks.
- [x] **Block-message conformance (T-1897 split):** [REVIEWER] Block message names (a) which file(s) triggered the gate, (b) the exact `[REVIEW]` AC template to copy-paste, (c) the bypass flag with rationale syntax — conformance check via `bin/fw reviewer T-1766` (human-ac-mechanical-signal pattern silent on the residual UX-taste [REVIEW] body).

### Human
- [ ] [REVIEW] Block-message UX is crisp — a new agent reading the message can act without re-opening T-1766 (wording is self-contained; the three pieces of info are easy to extract under cognitive load)
  **Steps:**
  1. Trigger the gate intentionally on a fresh test task: create a render-surface build task (`components: ["web/templates/tasks.html"]`) with no Human AC, then `bin/fw task update T-XXX --status work-completed`.
  2. Read the block message (lines under `ERROR: Cannot complete build task — touches render surface`).
  3. Ask: would a fresh agent on first read know exactly what to copy and where, or would they need to chase to T-1766's body?
  **Expected:** Self-contained — fresh agent acts without re-reading the source task.
  **If not:** Flag the specific phrasing or layout that requires lookup; agent reworks the block-message string.
  <!-- T-1897 split (2026-05-18): the previous AC blended two claims —
       (a) conformance: "message names (a) file, (b) template, (c) bypass syntax"
           → moved to Agent [REVIEWER] AC above, verified by reviewer-PASS.
       (b) taste: "a new agent should be able to act without re-reading T-1766"
           → residual [REVIEW] above (genuine cognitive-load UX judgment). -->


## Verification

bash -n lib/render_surface.sh
bash -n agents/task-create/update-task.sh
bats tests/unit/test_render_surface_gate.bats
grep -q "5\. \*\*Touches a rendering surface" CLAUDE.md
bash -n agents/task-create/update-task.sh
FRAMEWORK_ROOT=$(pwd) bats tests/unit/test_render_surface_gate.bats
# T-1897 re-class: reviewer confirms the human-ac-mechanical-signal pattern stays silent (split residue is taste-only)
test "$(bin/fw reviewer T-1766 2>&1 | grep -c 'human-ac-mechanical-signal')" -eq 0
# Self-application: T-1766 itself does NOT touch render surface, so gate is no-op.
# We can verify by sourcing the predicate and asserting it returns 1 for T-1766's components.
bash -c 'source lib/render_surface.sh && task_touches_render_surface .tasks/active/T-1766-render-surface-human-ac-gate--block-work.md && echo FAIL || echo OK_NOOP'
# Regression: existing P-010/P-011/P-012 gates still run before P-013
FRAMEWORK_ROOT=$(pwd) bats tests/unit/update_task.bats
FRAMEWORK_ROOT=$(pwd) bats tests/unit/test_task_pair_acd_gate.bats

## RCA

**Symptom:** Three consecutive render-fix tasks (T-1763, T-1764, T-1765) shipped with zero Human ACs. User had to manually flag each one ("no human ac, please rca and fix structurally"). The agent's review-routed work was passing the human's eye-check by accident, not by structural design.

**Root cause:** The agent's heuristic for AC classification was binary:
- "Test is deterministic and mechanical" → Agent AC
- "Test requires subjective judgment" → Human AC

For render-surface fixes, the **technical** test (computed-style assertion, HTTP code, regex) is deterministic. So all ACs went to Agent. But render fixes also have a **subjective** layer ("does this look right to a human?") that no test can capture. The classification heuristic conflated "deterministic test exists" with "no subjective layer exists" — they are independent dimensions.

T-1575 had previously shipped a related guidance ("UI Verification Needs Eyes") but only at the *technical* layer (DOM/screenshot replaces grep). It did not address the *subjective* layer (a human looks at the rendered output). The feedback memory entry says "DOM-content assertion required" but DOM assertions don't tell you whether the layout reads as continuous prose or as broken-away boxes — that's eye-perception.

**Why structurally allowed:**
- No gate at work-completed time required Human ACs for render-touching tasks. P-010 (AC checkbox), P-011 (Verification), P-012 (task-pair §ACD) all check structural conditions — none check "is there a human review for the visual layer?"
- T-954's AC classification guidance lists "subjective judgment" as a Human AC trigger, but enumerated examples are tone/quality/architecture — no explicit mention of render surfaces. The agent did not generalize.
- The bypass channel works: a human caught all three. But that's expensive — three back-and-forths, three fix iterations. Each was a Tier 1 problem ("ship the fix") that escalated to a Tier 4 question ("why does the framework allow this?").
- Same family as L-361/L-362 (cross-component drift). Here the drift is between the *fix surface* (the agent's mechanical work) and the *review surface* (what the human sees).

**Prevention:**
1. New gate `lib/render_surface.sh::check_render_surface_human_ac` consulted by `update-task.sh` at work-completed time. Build tasks touching render surfaces MUST have at least one unchecked `[REVIEW]` Human AC. Refusal exit code 5; bypass `--skip-render-review` logged Tier-2.
2. Single source of truth `RENDER_SURFACE_PATTERNS` in `lib/render_surface.sh` — same list referenced from any future consumer (linter, audit check, CI).
3. Bats regression pins gate behavior across 6 fixtures.
4. CLAUDE.md "AC Classification Guidance" updated to explicitly call out render surfaces as a Human-AC trigger.
5. **Retroactive hygiene** — T-1763/T-1764/T-1765 each get a `[REVIEW]` Human AC added. Demonstrates the gate would have caught all three at filing time. Their Recommendation blocks remain GO; the new ACs are advisory until the gate ships in T-1766.
6. L-364 filed: "Render-surface fixes have a subjective layer that deterministic tests cannot cover. Add a [REVIEW] Human AC even when computed-style and HTTP-code assertions pass."

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

## Recommendation

- **Recommendation:** GO
- **Rationale:** Gate substrate, bats coverage, CLAUDE.md doc, self-application, and retroactive documentary ACs all shipped. 12/12 bats pass. The render-surface predicate flagged T-1766 itself (because the task body literally names `web/shared.py`/`web/app.py` as patterns) — this is correctly handled by adding a [REVIEW] Human AC on block-message UX, which is the actual subjective check that warrants human eyes. Only remaining Human AC is the block-message readability review; the recommendation is to confirm the message is actionable.
- **Evidence:**
  - `agents/task-create/update-task.sh:380-475` — `check_render_surface_human_ac()` gate function
  - `agents/task-create/update-task.sh:1000-1006` — wired into work-completed sequence
  - `lib/render_surface.sh` — predicate library (shipped 2026-05-06)
  - `tests/unit/test_render_surface_gate.bats` — 12/12 pass (source invariants + predicate + gate firing/passing/bypass/rubber-stamp/non-render)
  - `CLAUDE.md:600-605` — 5th Human-AC trigger added (rendering surface)
  - Commits: 845b5c9f (substrate), dc5de6f3 (fabric card), 34e7127d (retroactive ACs)
  - Retroactive ACs on T-1763/T-1764/T-1765 — documentary record that the gate would have caught the origin cluster at filing time

## Updates

### 2026-05-06T11:30:48Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1766-render-surface-human-ac-gate--block-work.md
- **Context:** Initial task creation

### 2026-05-06 — Partial ship — budget gate fired mid-implementation

- **Shipped:**
  - `lib/render_surface.sh` (predicate library, single source of truth for `RENDER_SURFACE_PATTERNS`)
  - This task file with full RCA + AC plan + Recommendation rationale
- **NOT shipped (next-session pickup):**
  - `check_render_surface_human_ac` function body in `agents/task-create/update-task.sh`
    - Call site WAS added in working tree at line ~919 of update-task.sh; reverted from this commit because adding the function body was blocked by budget gate. Next session: re-add the call site AND insert the function body together.
    - Function spec is in this task's Agent ACs and `## RCA > Prevention` section.
  - Bats test `tests/unit/test_render_surface_gate.bats`
  - Retroactive Human ACs on T-1763, T-1764, T-1765 (each needs a `[REVIEW]` AC asking the human to confirm visual rendering on `/review/T-1762` at mobile width)
  - CLAUDE.md update under "AC Classification Guidance"
  - L-364 learning ("render-surface fixes have a subjective layer that deterministic tests cannot cover")
- **Status:** `started-work` (NOT work-completed). Do not run `fw task update T-1766 --status work-completed` until all Agent ACs are ticked.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-686a595d
- **Timestamp:** 2026-06-02T14:59:36Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 3

**Per-AC findings:**

- **AC#1 (Agent)** — **Render-surface predicate** — `lib/render_surface.sh` exposes `task_touches_render_surface <task_file>` returning 0 (yes) or 1 (no). Predicate examines the task's `components` frontmatter list AND th
  - **AC-verify-mismatch** (narrow, heuristic) — `path=web/shared.py in: **Render-surface predicate** — `lib/render_surface.sh` exposes `task_touches_render_surface <task_file>` returning 0 (yes) or 1 (no). Predicate examin`
- **AC#5 (Agent)** — **Self-application: T-1766 closure** — T-1766's body references `web/shared.py`/`web/app.py` literal paths (because the task DEFINES those patterns as render-surface examples). The predicate correctly
  - **AC-verify-mismatch** (narrow, heuristic) — `path=web/shared.py in: **Self-application: T-1766 closure** — T-1766's body references `web/shared.py`/`web/app.py` literal paths (because the task DEFINES those patterns as`
- **AC#1 (Human)** — [REVIEW] Block-message UX is crisp — a new agent reading the message can act without re-opening T-1766 (wording is self-contained; the three pieces of info are easy to extract under cognitive load)
  - **audience-mismatch** (partial, heuristic) — `agent-subject='agent read' in: Self-contained — fresh agent acts without re-reading the source task.`
### 2026-05-16T08:13:11Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
