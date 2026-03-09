# Template & JS Architecture Restructuring Plan

## 1. Current State

### File Structure (relevant files)

```
web/
  static/
    pico.min.css
    htmx.min.js
    htmx-ext-sse.js
    highlight.min.js / highlight-github-dark.min.css
    marked.min.js
    purify.min.js
    cytoscape.min.js / dagre.min.js / cytoscape-dagre.js
    logo.png
    (NO application JS files)
  templates/
    base.html          (354 lines — shell: nav, footer, htmx glue, toast helper)
    _wrapper.html      (5 lines — extends base, includes content fragment)
    search.html        (567 lines — HTML + 14-line <style> + 416-line <script>)
    fabric_graph.html  (has inline <script> — Cytoscape graph rendering)
    task_detail.html   (has inline <script>)
    tasks.html         (has inline <script>)
    _session_strip.html(has inline <script>)
    ... 30+ other content templates (pure HTML/Jinja2 fragments)
  search.py            (268 lines — BM25 index: _categorize, _extract_title, _extract_task_id, _collect_files)
  embeddings.py        (643 lines — vector index: DUPLICATES _categorize, _extract_title, _extract_task_id, _collect_files)
  ask.py               (234 lines — LLM Q&A streaming, model management)
  shared.py            (145 lines — PROJECT_ROOT, NAV, build_ambient, render_page)
  config.py            (config from env vars)
  app.py               (268 lines — Flask factory, CSRF, blueprints, error handlers)
  blueprints/
    discovery.py       (search routes: search_view, search_ask, search_save, search_feedback)
    ...
```

### Duplication Inventory

| Code | File A | File B | Notes |
|------|--------|--------|-------|
| `_categorize()` | `search.py:29-49` | `embeddings.py:77-95` | Identical except embeddings is missing "Saved Answers" category |
| `_extract_title()` | `search.py:52-65` | `embeddings.py:98-106` | Identical |
| `_extract_task_id()` | `search.py:109-121` | `embeddings.py:109-117` | Identical |
| `_collect_files()` | `search.py:68-95` | `embeddings.py:120-143` | Identical |
| path-to-link mapping | `search.html:87-102` (Jinja2) | `search.html:540-558` (JS `pathToLink()`) | Same logic, two languages |

### search.html Breakdown

```
Lines   1-62:   HTML — Q&A section (ask form, conversation thread, actions)
Lines  64-132:  HTML — Search results (Jinja2 loops, path-to-link mapping)
Lines 134-148:  <style> — 14 lines for Q&A rendering
Lines 150-566:  <script> — 416 lines:
  152-158:  Global state vars (_askAbort, _lastQuestion, etc.)
  159-162:  _getCsrfToken() — CSRF helper
  164-195:  saveAnswer() — POST to /search/save
  197-232:  sendFeedback() — POST to /search/feedback
  235-246:  newConversation() — reset UI
  249-271:  _addTurnToThread(), _updateConvHeader() — conversation thread
  273-470:  askQuestion() — 198 lines, fetch+ReadableStream SSE streaming
  472-478:  Enter key handler (DOMContentLoaded)
  481-519:  Markdown rendering (marked.js init, renderAnswer, renderAnswerDebounced)
  521-537:  addCopyButtons() — code block copy buttons
  539-558:  pathToLink() — DUPLICATE of Jinja2 logic
  561-565:  escHtml() — utility
```

---

## 2. Proposed File Structure

```
web/
  static/
    (existing vendor libs unchanged)
    js/
      search-qa.js      # Q&A streaming, conversation, save/feedback (~280 lines)
      markdown-render.js # marked.js init, renderAnswer, addCopyButtons (~60 lines)
      path-links.js      # pathToLink() — single source of truth (~25 lines)
      utils.js            # escHtml, getCsrfToken (~15 lines)
  templates/
    base.html            (unchanged)
    _wrapper.html        (unchanged)
    search.html          (reduced to ~140 lines: HTML + Jinja2 only)
    _partials/
      _search_form.html       # Search form (lines 1-16)
      _ask_section.html       # Q&A section (lines 18-62)
      _search_results.html    # Results display (lines 64-132) — path-to-link stays server-side
  search_utils.py        # NEW: _categorize, _extract_title, _extract_task_id, _collect_files
  search.py              # imports from search_utils.py instead of defining locally
  embeddings.py          # imports from search_utils.py instead of defining locally
  shared.py              # unchanged (already has render_page, PROJECT_ROOT, etc.)
```

---

## 3. Python Deduplication Strategy

### 3a. Create `web/search_utils.py`

Extract these 4 functions into a new shared module:

```python
# web/search_utils.py
"""Shared utilities for BM25 and vector search indexing."""

from pathlib import Path
import re
from web.shared import PROJECT_ROOT

def categorize(path_str: str) -> str: ...
def extract_title(path: Path, content: str) -> str: ...
def extract_task_id(path: Path, content: str) -> str: ...
def collect_files() -> list[Path]: ...
```

**Why `search_utils.py` not `shared.py`:**
- `shared.py` imports Flask (`render_template`, `request`) — it's web-framework-coupled
- `search_utils.py` is pure data logic, no Flask dependency
- Both `search.py` and `embeddings.py` import from `web.shared` already for `PROJECT_ROOT`
- Keeping the module focused makes it testable without Flask context

**Migration:**
1. Create `web/search_utils.py` with canonical versions of the 4 functions
2. Fix the `_categorize` discrepancy: embeddings.py is missing the "Saved Answers" category (`".context/qa/"`) — the canonical version should include it
3. Update `web/search.py`: `from web.search_utils import categorize, extract_title, extract_task_id, collect_files`
4. Update `web/embeddings.py`: same import
5. Remove the local `_categorize`, `_extract_title`, `_extract_task_id`, `_collect_files` from both files
6. Drop the `_` prefix since they're now part of a public module API

---

## 4. Path-to-Link Deduplication Strategy

### Recommendation: Server-side resolution (Option A)

**Current state:**
- Jinja2 template (lines 87-102): builds link from `item.path` during server render for search results
- JS `pathToLink()` (lines 540-558): builds link from `src.path` during client-side SSE source rendering

**Proposed approach — Server-side only:**

1. Create a Python function `path_to_watchtower_link(path: str) -> str` in `web/search_utils.py`
2. For search results: already server-rendered — replace inline Jinja2 logic with a Jinja2 filter or template function that calls the Python function
3. For Q&A sources: change the SSE `sources` event to include pre-computed `link` field

**Server-side implementation:**

```python
# In web/search_utils.py
def path_to_link(path: str) -> str:
    """Map a framework file path to a Watchtower URL."""
    if not path:
        return ""
    if path.startswith(".tasks/") and "/T-" in path:
        m = re.search(r"/T-(\d+)", path)
        return f"/tasks/T-{m.group(1)}" if m else ""
    if path.startswith(".fabric/components/"):
        return f"/fabric/component/{path.split('/')[-1].replace('.yaml', '')}"
    if path.startswith(".context/episodic/") and path.endswith(".yaml"):
        return f"/tasks/{path.split('/')[-1].replace('.yaml', '')}"
    if path in (".context/project/learnings.yaml", "learnings.yaml"):
        return "/learnings"
    if path in (".context/project/patterns.yaml", "patterns.yaml"):
        return "/patterns"
    if path in (".context/project/decisions.yaml", "decisions.yaml"):
        return "/decisions"
    if path.endswith(".md") and not path.startswith("."):
        return "/project/" + path.replace(".md", "").replace("/", "--")
    return ""
```

**Wire into SSE sources event** (in `web/ask.py` or `web/blueprints/discovery.py`):

```python
# In the stream_answer sources section or in discovery.py before yielding
for i, c in enumerate(chunks, 1):
    sources.append({
        "num": i,
        "title": c.get("title", ""),
        "path": c.get("path", ""),
        "link": path_to_link(c.get("path", "")),  # NEW
        "category": c.get("category", ""),
    })
```

**Wire into Jinja2** (register as filter in `app.py`):

```python
from web.search_utils import path_to_link
app.jinja_env.filters["path_to_link"] = path_to_link
```

Then in `search.html`:
```jinja2
{% set link = item.path | path_to_link %}
```

This replaces 15 lines of inline Jinja2 logic with a 1-line filter call, AND eliminates the JS `pathToLink()` function entirely. The JS source rendering just uses `src.link` from the SSE payload.

**Why not JS-only (Option C):** The search results are already server-rendered. Moving them to client-side would mean changing the htmx pattern (currently the search form does `hx-get` and receives an HTML fragment). Keeping server-side is simpler and consistent.

**Why not a shared data structure (Option B):** Over-engineering. The mapping is <20 lines. A single Python function with a Jinja2 filter covers both use cases.

---

## 5. JS Extraction Plan

### 5a. Script Loading Strategy: Classic `<script>` tags (NOT ES modules)

**Reasoning:**
- htmx uses `hx-boost="true"` on `<body>` — this means page navigations swap `#content` innerHTML
- Scripts in `base.html` load once (page shell). Scripts in content templates load per-swap
- ES modules (`type="module"`) are deferred and have strict CORS — adds complexity for zero benefit in this app
- Classic scripts with global functions are simpler and match the htmx pattern
- The existing vendor libs (htmx, marked, hljs) are all classic scripts with globals

**Critical htmx consideration:**
- `search.html` is a content fragment loaded INTO `#content` via htmx swap
- Scripts in swapped content are executed by htmx
- BUT: re-executing script setup on every swap is wasteful and can cause issues (double event listeners)
- Solution: Load `search-qa.js` from `base.html` (always available), but make functions idempotent
- Functions reference DOM elements by ID — they naturally work only when those elements exist

**Recommendation:** Load application JS files in `base.html`, not in individual templates.

### 5b. Proposed JS Files

**`web/static/js/utils.js`** (~15 lines)
```javascript
// CSRF token helper + HTML escaping
function getCsrfToken() { ... }
function escHtml(s) { ... }
```

**`web/static/js/path-links.js`** (~25 lines)
- Only needed IF we keep client-side path resolution
- With the server-side approach (Section 4), this file is ELIMINATED entirely
- The `pathToLink()` function is removed from the JS codebase

**`web/static/js/markdown-render.js`** (~60 lines)
```javascript
// marked.js initialization, renderAnswer(), renderAnswerDebounced(), addCopyButtons()
// Self-initializing: calls initMarked() on load
```

**`web/static/js/search-qa.js`** (~280 lines)
```javascript
// Global state vars
// askQuestion() — SSE streaming via fetch+ReadableStream
// saveAnswer(), sendFeedback() — POST helpers
// newConversation(), _addTurnToThread(), _updateConvHeader() — conversation management
// Enter key handler (DOMContentLoaded)
```

**Load order in `base.html`:**
```html
<!-- Application JS (after vendor libs) -->
<script src="{{ url_for('static', filename='js/utils.js') }}"></script>
<script src="{{ url_for('static', filename='js/markdown-render.js') }}"></script>
<script src="{{ url_for('static', filename='js/search-qa.js') }}"></script>
```

**Note:** `markdown-render.js` depends on `marked`, `hljs`, `DOMPurify` being loaded first (they are — loaded in `<head>`). `search-qa.js` depends on `utils.js` and `markdown-render.js`.

### 5c. htmx Interaction Notes

- `askQuestion()` currently calls `htmx.process(sourceList)` after inserting source links with `hx-target`/`hx-swap` attributes. This must be preserved in `search-qa.js`.
- The `htmx.process()` call tells htmx to scan the newly inserted DOM for htmx attributes. This is the standard pattern for dynamically inserted content.
- All functions use `document.getElementById()` — no htmx-specific element references
- The `DOMContentLoaded` listener for the Enter key handler should be changed to run on `htmx:afterSwap` as well, since the search page can be loaded via htmx navigation (the input element won't exist at DOMContentLoaded of the initial page load if the user navigates to /search via htmx)

**Fix for Enter key binding:**
```javascript
// Instead of:
document.addEventListener('DOMContentLoaded', function() {
    var el = document.getElementById('ask-input');
    if (el) el.addEventListener('keydown', ...);
});

// Use:
document.body.addEventListener('keydown', function(e) {
    if (e.target.id === 'ask-input' && e.key === 'Enter') {
        e.preventDefault();
        askQuestion();
    }
});
```
This event delegation pattern works regardless of when the element is added to the DOM.

---

## 6. Template Componentization

### 6a. Recommended Partials

Split `search.html` into logical includes:

**`web/templates/_partials/_search_form.html`** (~16 lines)
- The search form with mode selector
- No JS dependencies

**`web/templates/_partials/_ask_section.html`** (~44 lines)
- The collapsible Q&A section (details/summary)
- Conversation thread, input, buttons, error display
- References JS functions via `onclick` attributes (unchanged)

**`web/templates/_partials/_search_results.html`** (~50 lines)
- Results loop with `path_to_link` filter
- Stats display

**Resulting `search.html`** (~15 lines):
```jinja2
<div class="page-header">
    <h1>{{ page_title }}</h1>
    <p>Full-text search across tasks, decisions, learnings, patterns, and documentation.</p>
</div>

{% include '_partials/_search_form.html' %}
{% include '_partials/_ask_section.html' %}
{% include '_partials/_search_results.html' %}

<style>
{# Q&A rendering styles — 14 lines, kept inline since they're specific to this page #}
...
</style>
```

### 6b. htmx Fragments — NOT recommended at this time

Could the search results be a separate htmx endpoint returning HTML fragments? Yes, but:
- The current `search_view()` already returns the full search.html as a fragment for htmx requests
- Splitting results into a separate endpoint adds a route, a template, and complexity
- The current pattern (full page fragment swap) is idiomatic htmx
- Consider this only if search results need independent refresh (e.g., polling for index updates)

### 6c. Style Extraction

The 14-line `<style>` block in search.html is small and specific to the Q&A rendering. Options:
- **Keep inline** (recommended) — it's only 14 lines, specific to this page
- Move to `web/static/css/search.css` — adds an HTTP request for 14 lines
- Move to base.html — pollutes global styles for one page's needs

---

## 7. Migration Strategy

### Phase 1: Python Deduplication (LOW RISK, do first)

1. Create `web/search_utils.py` with canonical functions
2. Update `web/search.py` imports, remove local functions
3. Update `web/embeddings.py` imports, remove local functions
4. Add `path_to_link()` to `search_utils.py`
5. Register `path_to_link` as Jinja2 filter in `app.py`
6. Test: restart server, verify search works in all 3 modes (keyword, semantic, hybrid)

**Risk:** Low — pure refactor, no behavior change. The `_categorize` discrepancy (missing "Saved Answers" in embeddings) is a bug fix.

### Phase 2: JS Extraction (MEDIUM RISK, do second)

1. Create `web/static/js/` directory
2. Create `utils.js` with `getCsrfToken()` and `escHtml()`
3. Create `markdown-render.js` with marked init, `renderAnswer()`, `renderAnswerDebounced()`, `addCopyButtons()`
4. Create `search-qa.js` with all Q&A functions
5. Add `<script>` tags to `base.html`
6. Remove inline `<script>` block from `search.html`
7. Fix Enter key handler to use event delegation
8. Test: full Q&A flow (ask, stream, save, feedback, multi-turn)

**Risk:** Medium — scripts loaded in base.html run on every page, but functions are no-ops without the search page DOM elements. Verify no naming conflicts with existing global functions in base.html (current: `showToast`).

### Phase 3: Path-to-Link Server-Side (LOW RISK, do third)

1. Add `link` field to SSE `sources` event payload in `ask.py`
2. Update search.html Jinja2 to use `| path_to_link` filter
3. Update `search-qa.js` source rendering to use `src.link` instead of `pathToLink(src.path)`
4. Remove `pathToLink()` from JS
5. Test: search results links, Q&A source links

**Risk:** Low — additive change to SSE payload, then removal of JS function.

### Phase 4: Template Partials (LOW RISK, do last)

1. Create `web/templates/_partials/` directory
2. Extract `_search_form.html`
3. Extract `_ask_section.html`
4. Extract `_search_results.html`
5. Replace `search.html` body with includes
6. Test: full-page load and htmx navigation to search

**Risk:** Low — Jinja2 `{% include %}` is well-understood. No logic changes.

### Dependency Order

```
Phase 1 (Python dedup) ← independent, no JS changes
    ↓
Phase 2 (JS extraction) ← depends on nothing, but test thoroughly
    ↓
Phase 3 (path-to-link) ← depends on Phase 1 (path_to_link function) + Phase 2 (JS file exists to edit)
    ↓
Phase 4 (template partials) ← depends on Phase 2 (inline script already removed)
```

Phases 1 and 2 are independent and could be done in parallel.
Phase 3 depends on both Phase 1 and Phase 2.
Phase 4 depends on Phase 2 (easier to split the template after JS is extracted).

---

## 8. Line Count Impact

| File | Before | After |
|------|--------|-------|
| `search.html` | 567 | ~15 (+ partials: ~110 total) |
| `search.py` | 268 | ~200 (removed 4 functions) |
| `embeddings.py` | 643 | ~575 (removed 4 functions) |
| `search_utils.py` | 0 (new) | ~90 |
| `static/js/search-qa.js` | 0 (new) | ~280 |
| `static/js/markdown-render.js` | 0 (new) | ~60 |
| `static/js/utils.js` | 0 (new) | ~15 |
| `base.html` | 354 | ~360 (added 3 script tags) |
| `_partials/_search_form.html` | 0 (new) | ~16 |
| `_partials/_ask_section.html` | 0 (new) | ~44 |
| `_partials/_search_results.html` | 0 (new) | ~50 |

**Net effect:**
- `search.html`: 567 → 15 lines (97% reduction in the main file)
- Total JS: 416 inline → 355 in 3 files (slight reduction from removing pathToLink and deduplicating getCsrfToken with base.html's existing CSRF logic)
- Python duplication: 4 functions x 2 files → 1 canonical copy
- Path-to-link: 2 implementations (Jinja2 + JS) → 1 Python function

---

## 9. Risks and Mitigations

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| JS loaded on every page has naming conflicts | Low | Audit base.html globals (only `showToast`). Use underscore prefix for internal state vars. |
| Scripts execute before DOM on htmx swap | Low | All functions reference elements by ID on call, not on load. Event delegation for Enter key. |
| Flask template caching stale after partial extraction | Medium | Restart server after template changes (known issue from MEMORY.md) |
| `_categorize` behavior change in embeddings.py when using canonical version | Low | The canonical version ADDS "Saved Answers" — strictly additive, improves coverage |
| `base.html` loads Q&A JS on non-search pages | Low | Functions are no-ops without DOM elements. Total added JS is ~355 lines (~10KB unminified). Negligible compared to htmx.min.js (50KB) and marked.min.js (39KB). |

---

## 10. Questions for Decision

1. **JS in base.html vs search.html?** Recommendation: base.html. But if page-load performance is a concern, we could add them only in search.html (with the caveat that htmx swaps re-execute them on every navigation to /search).

2. **getCsrfToken in utils.js or reuse base.html's htmx CSRF handler?** The htmx `configRequest` event in base.html already handles CSRF for htmx requests. The manual `_getCsrfToken()` is only needed for raw `fetch()` calls in the Q&A code. Keep both — they serve different code paths.

3. **Phase 2 can be done incrementally:** Extract `utils.js` first, then `markdown-render.js`, then `search-qa.js`, testing after each step. Or do all at once since the functions are well-isolated.
