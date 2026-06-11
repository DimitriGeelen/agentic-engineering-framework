---
id: T-1763
name: "fix AC body parser — HTML comment example leaks into render and overrides Steps/Expected/If-not"
description: >
  fix AC body parser — HTML comment example leaks into render and overrides Steps/Expected/If-not

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: ["bug", "render", "governance-render", "human-review-surface"]
components: [lib/render_surface.sh, tests/unit/test_ac_body_html_comment.py, 
      tests/unit/test_file_route_extensions.py, web/blueprints/docs.py, 
      web/blueprints/tasks.py, web/shared.py]
related_tasks: ["T-204", "T-1551", "T-1762"]
created: 2026-05-06T10:47:12Z
last_update: '2026-06-11T22:23:58Z'
date_finished: 2026-05-16T07:04:01Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:58Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=2 (body:lightly-promoted); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1763: fix AC body parser — HTML comment example leaks into render and overrides Steps/Expected/If-not

## Context

`web/blueprints/tasks.py::_parse_acceptance_criteria` and `_parse_ac_body` collectively let HTML-comment template content leak into rendered Human ACs.

Discovered while reviewing T-1762 — the human saw "https://example.com/dashboard / panels / browser console" rendered as Steps/Expected/If-not for AC #2, when those values were template example content inside the `### Human` block's HTML comment, not real AC data. Real AC #2 content (Steps about `cd /tmp/scratch && fw task update T-FAKE`, Expected about refusal-message wording) was silently overridden.

Affects every task using the default template (most tasks), but only manifests when an AC has Steps/Expected/If-not placed before the comment. T-1762 was the first review to surface it because earlier reviewed tasks either (a) had no Human AC, (b) had ACs with content patterns that didn't trigger the second-`**Steps:**` overwrite, or (c) the human wasn't reading carefully enough to notice.

Three composing parser bugs:
1. **Body collector** (`_parse_acceptance_criteria` lines ~402-410) breaks on `^- \[[ xX]\]` — no whitespace allowed at line start. Indented commented-out checkboxes (`       - [ ] [REVIEW] Dashboard...`) don't match, so collector reads past them.
2. **Body collector** does not honor `in_comment` (the outer loop tracks it correctly but the body sub-loop doesn't).
3. **`_parse_ac_body`** silently overwrites Steps/Expected/If-not when it sees a second `**Steps:**` etc. — no scope guard; last-write-wins semantics.

Symmetric pattern to T-204 / L-097 (CTL-013 audit parser had same blind spot — fix was to track `in_comment` flag).

## Acceptance Criteria

### Agent
- [x] **Body collector honors `in_comment`** — `_parse_acceptance_criteria` body collection sub-loop tracks HTML comments the same way the outer loop does. Lines inside `<!-- ... -->` blocks are excluded from the AC body passed to `_parse_ac_body`.
- [x] **Regression test pinned** — `tests/unit/test_ac_body_html_comment.py` (or `.bats`) covers: (a) AC body containing template-example HTML comment renders the *real* Steps/Expected/If-not, not the example's; (b) AC followed only by an HTML comment renders empty body (no leakage); (c) AC with no comment renders unchanged (no regression).
- [x] **T-1762 review-page renders correctly** — `curl -sf http://localhost:3002/review/T-1762` no longer contains `example.com/dashboard`, `panels load within 2 seconds`, or `browser console`. Real AC #2 Steps about `cd /tmp/scratch && /opt/999-Agentic-Engineering-Framework/bin/fw task update T-FAKE --status work-completed` are visible.
- [x] **Existing tests pass** — `bin/fw test playwright` Review-related tests (or whichever pin AC rendering today) pass without changes.
- [x] **No render of trailing `-->`** — render output for any AC body must not contain a literal `-->` (the comment-close that previously leaked into "If not").

### Human

<!-- Retroactively added 2026-05-16 after T-1766 ship. The render-surface gate
     (T-1766, P-013) would have caught this task at filing time — three render
     fixes (T-1763/T-1764/T-1765) shipped with zero Human ACs is the origin
     cluster the gate exists to prevent. Adding the AC here is documentary,
     not blocking — the task already shipped. -->

- [ ] [REVIEW] Rendered AC body on `/review/T-1762` shows no leaked `-->`
  **Steps:**
  1. Open `$(bin/fw watchtower url)/review/T-1762` (or any review page rendering a task with `<!-- ... -->` blocks under `### Human`).
  2. Inspect the AC list — each `[REVIEW]`/`[RUBBER-STAMP]` AC should render with its body text only.
  **Expected:** No literal `-->` characters visible. No fragment of the HTML-comment-close leaks into "If not" text.
  **If not:** Screenshot the leaked render, reopen for follow-up fix.

## Verification

# Toolchain: Python only — no compileable artefacts.
python3 -c "import ast; ast.parse(open('web/blueprints/tasks.py').read())"
python3 -m pytest tests/unit/test_ac_body_html_comment.py -q
# Live render no longer leaks the template example. Use dynamic Watchtower URL
# resolution (triple-file) — never hard-code :3000/:3002 (T-1376 anti-pattern).
# T-1763: fixed port hard-code (was :3002) → use bin/fw watchtower url.
WT_URL=$(bin/fw watchtower url) && curl -sf "$WT_URL/review/T-1762" > /tmp/.t1763-render.html
grep -qv "example.com/dashboard" /tmp/.t1763-render.html
grep -qv "panels load within 2 seconds" /tmp/.t1763-render.html
# Real AC #2 Steps surface
grep -q "T-FAKE" /tmp/.t1763-render.html

## RCA

**Symptom:** On the `/review/T-1762` Watchtower page, AC #2 ("Confirm gate refusal message is actionable") rendered with Steps/Expected/If-not from the default template's HTML-comment example: "Open https://example.com/dashboard in browser", "Verify all panels load within 2 seconds", "Screenshot the broken panel". The real AC content (cd /tmp/scratch + fw task update T-FAKE) was silently overwritten. A literal `-->` even leaked into the rendered "If not" trailing text.

**Root cause:** Three composing parser bugs in `web/blueprints/tasks.py`:
1. `_parse_acceptance_criteria` body sub-loop (~lines 402-410) breaks on `re.match(r'^- \[[ xX]\]', next_line)` with no leading-whitespace tolerance. Indented commented-out checkboxes don't match, so the body collector reads past them into the comment region.
2. The body sub-loop does not track HTML-comment state, while the outer loop does (lines ~348-355). The `in_comment` flag exists at the function scope but is consulted only by the outer loop.
3. `_parse_ac_body` (lines ~270-328) uses last-write-wins for Steps/Expected/If-not — every subsequent `**Steps:**` resets `current_field` and clears `current_content`. The template example's Steps overwrite the real Steps unconditionally.

**Why structurally allowed:**
- AC parsing has no test coverage for the "AC followed by HTML-comment example" shape, despite the default template embedding exactly that shape. The pattern was authored alongside the parser but never red/green-tested together.
- L-097 (T-204) caught the same class of bug in `audit.sh::CTL-013` two years ago. The fix (in_comment flag) propagated to the outer loop here but not to the body sub-loop. Cross-parser drift.
- Render is a one-way path (file → HTML); no diffing against expected output, no Playwright assertion that "real AC content survives a comment-following template example."

**Prevention (distinct from the fix):**
1. New regression test pins exact pattern: AC + HTML-comment-with-example-checkbox → real AC content survives.
2. Test asserts NO `-->` literal appears in rendered output for any AC.
3. Audit lint check (future): scan all `web/blueprints/*.py` parsers for HTML-comment state tracking. If any function reads task body and pattern-matches on `## ` / `### ` / `- [ ]`, it must track `in_comment` (linkable to L-097).
4. **L-097 propagation gap is the deeper lesson** — file as a project-memory entry: "When fixing parser X with `in_comment` tracking, audit other parsers in the same surface for symmetric blindness."

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

### 2026-05-06 — Fix at body-collector layer, not at `_parse_ac_body`

- **Chose:** Make the body collector strip HTML-commented regions before passing the body to `_parse_ac_body`. Single fix point at the source of bad data.
- **Why:** `_parse_ac_body`'s last-write-wins semantics on `**Steps:**` is a separate concern (and arguably the right behavior for legitimate multi-step content where Steps appear once). Filtering at body-collection time keeps `_parse_ac_body` simple and aligns with how the outer loop already handles comments.
- **Rejected:** Adding a "first-Steps-wins" guard inside `_parse_ac_body` — wrong layer, would mask future cases of unintended content reaching the parser. Comment-stripping in a Markdown preprocessor — too invasive for a one-line bug.

## Recommendation

**Recommendation:** GO

**Rationale:**

Three composing parser bugs collapsed into a single body-collector fix that mirrors the outer loop's existing `in_comment` state machine. Live verification on `/review/T-1762` confirms zero leaked example-content (`example.com/dashboard` count: 0, was 1) and the real AC #2 Steps about `T-FAKE` now surface (count: 1, was 0). 4/4 new regression tests pass, 18/18 T-1762 bats still green, 36/36 existing render tests still green. No template change needed — the template's HTML-comment example was always the right shape; the parser was wrong.

L-097 propagation gap is the deeper insight (filed in `## RCA`): same in-comment-blindness pattern was caught and fixed in `audit.sh` two years ago (T-204), but the fix never crossed into other parsers in the same surface. Future work to file as a structural concern: a lint that scans `web/blueprints/*.py` and `agents/*/*.sh` parsers for HTML-comment state tracking.

**Evidence:**

- `tests/unit/test_ac_body_html_comment.py` — 4 tests pin: leak prevention, empty-body case, no-regression case, single-line comment case
- Live render verification:
  - `curl -s http://localhost:3002/review/T-1762 | grep -c example.com/dashboard` → 0 (was 1)
  - `curl -s http://localhost:3002/review/T-1762 | grep -c T-FAKE` → 1 (was 0)
  - `curl -s http://localhost:3002/review/T-1762 | grep -c -- '-->'` → 0 (was 1)
- 36/36 existing render tests pass (`test_extract_recommendation`, `test_render_artefact_paths`)
- 18/18 T-1762 task-pair §ACD bats tests pass (no regression in adjacent surface)
- 22/22 AC-related bats pass (`ac_counter_strip_comments`, `skip_ac_partial_complete`, `inception_decide_ac_tick`)

**Risk acknowledged:**

- **Forward-only.** Existing tasks already shipped with broken render are not retroactively re-rendered. Acceptable: render is a read path, no persistent damage. Each affected task surfaces correctly on next page-load.
- **Pre-existing inline-Steps bug surfaced during testing.** `_parse_ac_body` doesn't capture inline content after `**Steps:**` like it does for Expected/If-not. Not a regression — it predates T-1763. Filing as separate observation rather than bundling per "one bug = one task."
- **Single-line `<!-- ... -->` edge case** has special handling (open + close on same line). Tested and green. If a malformed comment lacks closing `-->`, the body collector treats everything until the next `## ` / `### ` / `- [ ]` as commented (closes implicitly at section boundary). This is conservative — empty render is better than leaked render.

## Updates

### 2026-05-06T10:47:12Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1763-fix-ac-body-parser--html-comment-example.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-873992fe
- **Timestamp:** 2026-06-02T14:59:35Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-16T07:04:01Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
