---
id: T-1765
name: "fix code element inline-block dropping long paths to next line — visual cutoff in prose contexts"
description: >
  fix code element inline-block dropping long paths to next line — visual cutoff in prose contexts

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: ["bug", "render", "css", "human-review-surface", "ui-visual"]
components: [lib/render_surface.sh, tests/playwright/test_review_code_inline.py, web/templates/base.html, web/templates/review.html]
related_tasks: ["T-1575", "T-1722", "T-1762", "T-1763", "T-1764"]
created: 2026-05-06T11:20:05Z
last_update: 2026-05-16T07:07:48Z
date_finished: 2026-05-16T07:07:48Z
---

# T-1765: fix code element inline-block dropping long paths to next line — visual cutoff in prose contexts

## Context

User reported on `/review/T-1762`: the Evidence list item "shellcheck clean on `lib/task_pair_acd.sh`" renders with the path on its own line, visually disconnected from the surrounding prose. User called this "still cutoff" — the path appears to be broken away from its sentence context.

Investigation via Playwright at 360px and 320px mobile viewports:
- Path is FULLY visible (not truncated character-wise)
- Path does NOT overflow the body
- Path renders on a separate line from "shellcheck clean on"
- `<code>` element computed `display: inline-block` — sourced from Pico CSS rule `code, kbd { display: inline-block }`

**Why inline-block causes the visual cutoff:**

Inline-block elements participate in line layout but as ATOMIC units — they don't break internally. When the remaining space on a line is less than the inline-block's width, the browser drops the WHOLE element to the next line (instead of breaking it within itself like inline text would). With `<code>lib/task_pair_acd.sh</code>` at ~169px and remaining line width often < 169px on mobile, the path gets pushed to its own line.

Combined with the grey `<code>` background, the visual effect is:
```
shellcheck clean on
[lib/task_pair_acd.sh]   <-- atomic block dropped to new line, framed in grey
```
…which reads as "broken away" / "cutoff" rather than as continuous prose.

**Why review.html's existing `a > code` override doesn't catch this:**

review.html has CSS (lines 181-187) that styles `a > code` (when a link wraps a code element — the T-1575 backticked-URL case). But the auto-linker for *paths* emits `<code><a>...</a></code>` (code wrapping link) — the OPPOSITE direction. The override doesn't apply.

## Acceptance Criteria

### Agent
- [x] **Pico inline-block override applied to prose contexts** — `code` inside `.rec-rationale`, `.rec-evidence`, `.ac-detail`, and other prose contexts on `/review/<task>` is `display: inline` (not inline-block). Long paths break with surrounding text instead of dropping atomically.
- [x] **Override propagated to base.html surfaces** — same fix applied to `web/templates/base.html` so `/tasks/<id>`, `/inception/<id>`, `/approvals`, `/cockpit` and any other base-extending surface inherit the fix.
- [x] **Long path graceful break** — for paths longer than the line, `overflow-wrap: anywhere` (or `word-break: break-word`) lets the path break gracefully at any character. No horizontal scroll, no off-screen text.
- [x] **Playwright regression test pinned** — `tests/playwright/test_review_code_inline.py` opens `/review/T-1762` at 360px viewport, finds the `lib/task_pair_acd.sh` link, asserts (a) `getComputedStyle(...).display !== 'inline-block'`, (b) the `<a>` and the preceding text "shellcheck clean on " are on the same line OR the `<code>` is breakable inline. Documents the visual contract.
- [x] **No regression on file viewer source rendering** — `/file/lib/task_pair_acd.sh` page still renders with its `<pre><code>` syntax-highlighted block intact (the Pygments output uses `<pre>` not bare `<code>`, so the override should not affect it). Verified via Playwright: page loads, source content visible.
- [x] **No regression on T-1575 backticked-URL contract** — `<a><code>http://...</code></a>` (link wrapping code) continues to render with link colour/underline visible across the code box. Existing `a > code` override unchanged.

### Human

<!-- Retroactively added 2026-05-16 after T-1766 ship — documentary only,
     not blocking the already-shipped close. -->

- [ ] [REVIEW] Inline `<code>` elements render as inline (not block) across review pages
  **Steps:**
  1. Open any `$(bin/fw watchtower url)/review/T-XXXX` page that includes inline backtick-wrapped tokens in AC text (e.g. T-1762).
  2. Look at sentences containing `\`backticked\`` words.
  **Expected:** The code-styled token sits on the same line as the surrounding prose with monospace font + subtle background — no orphan line break, no "stray punctuation" at start of next line.
  **If not:** Screenshot, note offending element, reopen.

## Verification

# Toolchain: HTML/CSS templates only — no compileable artefacts.
# CSS validation: jinja2 template parses (no syntax errors)
python3 -c "from jinja2 import Environment, FileSystemLoader; e = Environment(loader=FileSystemLoader('web/templates')); e.get_template('review.html'); e.get_template('base.html')"
# Playwright regression
FW_TEST_PORT=3002 python3 -m pytest tests/playwright/test_review_code_inline.py -q

## RCA

**Symptom:** On `/review/T-1762` (and any review/inception/task page rendering markdown evidence) the Evidence list item `shellcheck clean on \`lib/task_pair_acd.sh\`` rendered with the path on its own line, visually disconnected from the prose. User reported as "still cutoff" — the path appears broken away from its sentence. Reproducible at any viewport ≤ ~600px wide.

**Root cause:** Pico CSS (the framework's chosen base stylesheet) sets `code, kbd { display: inline-block }` globally. Inline-block elements participate in line layout but as ATOMIC units — when remaining horizontal space is less than the block's intrinsic width, the browser drops the WHOLE block to the next line, instead of breaking inside it (which is what plain inline elements do).

For long backticked paths in prose (e.g. `lib/task_pair_acd.sh` at ~169px on mobile), this triggers whenever the surrounding sentence already consumed enough line width — which is most of the time on phones. Combined with the grey `<code>` background and inline-block padding, the visual reads as "broken away" / "cutoff" rather than continuous prose.

**Why structurally allowed:**
- No template overrode Pico's `code` display rule for prose contexts. The override existed for `a > code` (link-wrapping-code, T-1575) — a related but different shape — leaving the bare-`<code>` case unprotected.
- T-1722 promoted `_auto_link_files` to a global helper that emits `<a>` inside or outside `<code>` depending on input shape. It did not include CSS guidance for either resulting shape.
- No visual regression test asserted that prose paths flow inline (only T-1575 styling tests existed, scoped to `a > code`).
- Same family as L-361 (cross-parser drift) and L-362 (helper-vs-consumer drift): a global stylesheet rule has multiple consumer surfaces; one consumer (review.html) added a partial fix; others (task_detail, inception, approvals) inherited the bug silently.

**Prevention:**
1. Override `display: inline; overflow-wrap: anywhere` for `<code>` in prose contexts in `base.html` — covers all base-extending surfaces in one place.
2. Same override duplicated in `review.html` (the only standalone Watchtower template that doesn't extend base.html).
3. Re-assert `display: inline-block` on `pre > code` and `.codehilite code` so the source-file viewer (`/file/lib/...`) is unaffected — Pygments token spans need block layout.
4. Playwright regression `tests/playwright/test_review_code_inline.py` pins the contract: prose `<code>` is `display: inline` at mobile, link doesn't overflow body, source-file viewer unaffected, T-1575 backticked-URL coexistence preserved.
5. L-363 (filed): "Visual regression tests must cover mobile viewport for any markdown-rendering surface." Element-presence grep is not enough (T-1575 visual feedback memory) — DOM computed-style assertion catches CSS regressions that grep cannot.

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

### 2026-05-06 — Override Pico per-prose-context, not globally

- **Chose:** Targeted CSS overrides on `.rec-rationale code, .rec-evidence code, .ac-detail code, article code, td code, li code` etc., plus `pre > code` re-assertion of inline-block. Apply in `base.html` (covers most surfaces) and `review.html` (standalone).
- **Why:** A bare `code { display: inline }` global override would risk breaking any consumer that legitimately wants inline-block (badges, kbd-key indicators, fixed-width labels). Targeting prose contexts limits blast radius. The `pre > code` re-assertion ensures Pygments output is unaffected.
- **Rejected:** Replacing Pico CSS — too disruptive. Stripping `<code>` tags at the linker layer — would lose semantic and visual styling. Setting `word-break: break-all` everywhere — too aggressive (mid-character breaks in non-path text are ugly).

### 2026-05-06 — `overflow-wrap: anywhere` over `word-break: break-all`

- **Chose:** `overflow-wrap: anywhere; word-break: normal` on prose `<code>`.
- **Why:** `overflow-wrap: anywhere` is the modern standard, only triggers when the line CAN'T fit the token (preserves natural breaks). `word-break: break-all` triggers preemptively, producing ugly mid-character breaks in regular text.
- **Rejected:** `word-break: break-word` — non-standard alias, behaves differently across engines.

## Recommendation

**Recommendation:** GO

**Rationale:**

Single structural fix (CSS override targeted at prose contexts) closes the user-reported cutoff. Verified live via Playwright at 320px and 360px viewports: prose `<code>` is now `display: inline` with `overflow-wrap: anywhere`, no horizontal scroll, no overflow past body, source-file viewer unaffected. 4/4 new Playwright regression tests pin the contract.

Same root-cause class as T-1763/T-1764 (parser/route/style contract drift between producer surface and consumer surface). Three siblings now: L-361 cross-parser, L-362 helper-vs-consumer, L-363 visual-regression-needs-DOM-measurement-not-HTML-grep. If a fourth incident lands, this should become a structural concern with a lint check.

**Evidence:**

- 4/4 `tests/playwright/test_review_code_inline.py` pass at FW_TEST_PORT=3002:
  - `test_prose_code_is_not_inline_block_at_mobile_width` (asserts `getComputedStyle(code).display === 'inline'`)
  - `test_path_link_does_not_overflow_body_at_mobile_width` (no horizontal scroll at 320px)
  - `test_source_file_viewer_still_renders_syntax_highlighted` (`/file/lib/task_pair_acd.sh` source content intact)
  - `test_no_regression_on_t1575_backticked_url_styling` (a > code link colour visible across box)
- Live verification via Playwright DOM measurement on `/review/T-1762`:
  - Pre-fix: `<code> display: inline-block`, atomic drop-to-next-line
  - Post-fix: `<code> display: inline`, `overflow-wrap: anywhere`, flows with prose
- Source rendering preserved: `pre > code` re-asserts inline-block at the source-viewer surface
- L-363 captured (visual regression needs computed-style assertion, not HTML grep)

**Risk acknowledged:**

- **Pico CSS upgrades may re-introduce the inline-block.** If we ever upgrade `pico.min.css`, the override stays in our template — Pico's rule is overridden by our higher-specificity selectors. Playwright test catches any regression.
- **Selectors enumerate prose contexts by class name.** If a new template introduces a markdown-rendering area without using one of the listed selectors (`article`, `.rec-evidence`, `.ac-detail`, `li`, `td`, `.markdown-content`), the new context inherits Pico's inline-block default. Mitigation: future templates should use one of the existing prose classes; if a new class is needed, add it to the override selector list. Documented in L-363.
- **`overflow-wrap: anywhere` semantics differ per browser.** Modern Chrome/Firefox/Safari: tested behavior matches. Older browsers: graceful fallback to standard text-wrap.

## Updates

### 2026-05-06T11:20:05Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1765-fix-code-element-inline-block-dropping-l.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-d64edf00
- **Timestamp:** 2026-06-02T14:59:36Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 3

**Per-AC findings:**

- **AC#2 (Agent)** — **Override propagated to base.html surfaces** — same fix applied to `web/templates/base.html` so `/tasks/<id>`, `/inception/<id>`, `/approvals`, `/cockpit` and any other base-extending surface inherit
  - **AC-verify-mismatch** (narrow, heuristic) — `path=web/templates/base.html in: **Override propagated to base.html surfaces** — same fix applied to `web/templates/base.html` so `/tasks/<id>`, `/inception/<id>`, `/approvals`, `/coc`
- **AC#4 (Agent)** — **Playwright regression test pinned** — `tests/playwright/test_review_code_inline.py` opens `/review/T-1762` at 360px viewport, finds the `lib/task_pair_acd.sh` link, asserts (a) `getComputedStyle(...
  - **AC-verify-mismatch** (narrow, heuristic) — `path=lib/task_pair_acd.sh in: **Playwright regression test pinned** — `tests/playwright/test_review_code_inline.py` opens `/review/T-1762` at 360px viewport, finds the `lib/task_pa`
- **AC#5 (Agent)** — **No regression on file viewer source rendering** — `/file/lib/task_pair_acd.sh` page still renders with its `<pre><code>` syntax-highlighted block intact (the Pygments output uses `<pre>` not bare `<
  - **AC-verify-mismatch** (narrow, heuristic) — `path=file/lib/task_pair_acd.sh in: **No regression on file viewer source rendering** — `/file/lib/task_pair_acd.sh` page still renders with its `<pre><code>` syntax-highlighted block in`
### 2026-05-16T07:07:48Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
