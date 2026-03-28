# Watchtower /search UX Redesign Analysis

## Current State Assessment

The existing search page (`web/templates/search.html`) has these issues:
1. **Q&A buried**: The "Ask a Question" LLM feature is in a collapsed `<details>` tag — most users will never find it
2. **Technical mode selector**: "Keyword (BM25) / Semantic / Hybrid" exposed raw to users
3. **Raw relevance scores**: Numbers like `0.432` shown next to results — meaningless to users
4. **No empty state**: Landing on /search with no query shows nothing — no guidance, no suggestions
5. **Accordion grouping**: Results in `<details open>` by category — forces vertical scanning across collapsed sections
6. **Mobile cramping**: The `<fieldset role="group">` puts input + select + button on one line — breaks on narrow screens
7. **No search history**: No recent queries, no popular searches, no "try these" suggestions

---

## Research Summary

### Key Patterns from Modern Tools

| Tool | Pattern | Takeaway |
|------|---------|----------|
| **Perplexity** | Q&A-first, sources secondary, progressive disclosure | AI answer is the PRIMARY output, not an afterthought |
| **Linear** | Unified search, minimal UI, monochrome, keyboard-first | Single input that searches everything; mode is invisible |
| **Vercel** | Command palette overlay, instant results | Fast, focused, no mode selection |
| **Notion** | Unified search with type filters as pills | Filter by type AFTER searching, not before |
| **NN/g research** | Lists > cards for search; cards > lists for browsing | List format is more scannable for search results |
| **htmx patterns** | Active Search (hx-trigger="input changed delay:500ms") | Server-driven tabs via HATEOAS; no client JS for state |

### Key UX Principles (2025-2026)

1. **AI answers should be first-class, not hidden** — Perplexity proved users want answers, not just links
2. **Don't expose implementation details** — "BM25" means nothing to users; auto-select the best mode
3. **Empty states are onboarding opportunities** — Show suggestions, recent queries, example questions
4. **Relevance should be visual, not numeric** — Bars, dots, or color intensity; never raw floats
5. **Lists beat cards for search** — Fixed positioning aids scanning; cards waste space
6. **Progressive disclosure** — Show snippet first, expand for full context
7. **Unified input** — One box that handles both search and Q&A; detect intent

---

## Layout Options Analysis

### Option A: "Perplexity-Style" — Q&A First, Search Results as Sources

```
+----------------------------------------------------------+
|  Search Watchtower                                    [?] |
|  +----------------------------------------------------+  |
|  | Ask anything or search...                          |  |
|  +----------------------------------------------------+  |
|                                                          |
|  Suggested: "What patterns have failed?" | "Show recent  |
|  decisions" | "How does the healing loop work?"          |
|                                                          |
|  ---- After query: ----                                  |
|                                                          |
|  [AI Answer]                                             |
|  The healing loop has three phases: classify, lookup,    |
|  and suggest. When a task hits "issues" status...        |
|  [1][2][3]                                               |
|                                                          |
|  Sources (3)         | Filter: [All] [Tasks] [Patterns]  |
|  +-----------------+                                     |
|  | T-015: API...   | score ████░░ | .tasks/active/...   |
|  +-----------------+                                     |
|  | L-007: Retry... | score █████░ | learnings.yaml      |
|  +-----------------+                                     |
|  | P-003: Timeout  | score ███░░░ | patterns.yaml       |
|  +-----------------+                                     |
+----------------------------------------------------------+
```

**Pros:**
- Surfaces the highest-value feature (AI Q&A) prominently
- Unified input — one box for everything
- Sources/results naturally follow the answer
- Progressive: answer first, drill-down second
- Matches user mental model: "I want an answer, not a list"

**Cons:**
- Requires LLM to be available for the best experience
- Pure keyword search becomes secondary
- Latency for AI answer may frustrate users wanting quick results
- May confuse users who just want file search

### Option B: "Tabs" — Search & Ask as Equal Peers

```
+----------------------------------------------------------+
|  Search Watchtower                                        |
|                                                           |
|  [ Search ]  [ Ask AI ]                    (tab bar)      |
|  =========                                                |
|                                                           |
|  +----------------------------------------------------+  |
|  | Search framework content...                        |  |
|  +----------------------------------------------------+  |
|  Mode: (Keyword) (Semantic) (Hybrid)    <- pill toggles   |
|                                                           |
|  Suggested searches:                                      |
|  "healing loop" | "portability" | "recent failures"       |
|                                                           |
|  ---- After search: ----                                  |
|                                                           |
|  12 results for "healing"    [Tasks 5] [Patterns 3] ...   |
|                                                           |
|  T-015: API Timeout Healing          ████░░               |
|  .tasks/active/T-015-api-timeout.md                       |
|  ...implements retry logic with exponential backoff...    |
|                                                           |
|  L-007: Always Add Retry Logic       ███░░░               |
|  .context/project/learnings.yaml                          |
|  ...discovered during T-012 that bare HTTP calls...       |
+----------------------------------------------------------+
```

**Pros:**
- Clear separation of concerns — users know what they're getting
- Search works without LLM dependency
- Mode selector available but not dominant (pills instead of dropdown)
- Tab state manageable with htmx (server-driven)
- Category filters as pills instead of accordions = better scanning

**Cons:**
- Two-tab paradigm splits attention
- Users may not discover the "Ask AI" tab
- More complex navigation
- Doesn't leverage the AI as a differentiator

### Option C: "Unified Smart Input" — Auto-Detect Intent (RECOMMENDED)

```
+----------------------------------------------------------+
|  Search Watchtower                                        |
|                                                           |
|  +----------------------------------------------------+  |
|  | Search or ask a question...                  [->]  |  |
|  +----------------------------------------------------+  |
|  Tip: Try "What causes task failures?" or "healing loop"  |
|                                                           |
|  Recent:  healing loop | T-015 | portability patterns     |
|                                                           |
|  ---- After search query "healing loop": ----             |
|                                                           |
|  8 results for "healing loop"                             |
|  [All 8] [Tasks 3] [Patterns 2] [Learnings 2] [Docs 1]   |
|                                                           |
|  T-015: API Timeout Healing              ████░░           |
|  .tasks/active/T-015-api-timeout.md                       |
|  ...implements retry logic with exponential backoff...    |
|  [View task ->]                                           |
|                                                           |
|  ---- After question "What causes task failures?": ----   |
|                                                           |
|  +-- AI Answer ------------------------------------------+|
|  | Task failures typically stem from three categories:   ||
|  | 1. External dependencies (API timeouts) [1]           ||
|  | 2. Design gaps (missing validation) [2]               ||
|  | 3. Environment issues (port conflicts) [3]            ||
|  +-------------------------------------------------------+|
|                                                           |
|  Sources & Related Results                                |
|  [All 5] [Tasks 2] [Patterns 2] [Learnings 1]            |
|                                                           |
|  [1] P-003: External API Timeout        █████░            |
|  patterns.yaml                                            |
|  ...classified as external dependency failure...          |
+----------------------------------------------------------+
```

**Pros:**
- Single input — lowest cognitive load
- Auto-detects: questions (contains ?) get AI answer + sources; keywords get search results
- AI answer appears inline ABOVE results when triggered — not hidden, not forced
- Graceful degradation: if LLM unavailable, falls back to search-only
- Category pills for filtering (replaces accordions)
- Empty state with suggestions and recent queries
- Relevance bars instead of raw scores

**Cons:**
- Intent detection might misclassify (mitigated by "?" heuristic)
- Slightly more complex backend logic
- Users might not realize AI is available (mitigated by placeholder text and tips)

### Option D: "Split Pane" — Results + Preview

```
+----------------------------------------------------------+
|  Search Watchtower                                        |
|  +----------------------------------------------------+  |
|  | Search or ask...                             [->]  |  |
|  +----------------------------------------------------+  |
|                                                           |
|  +------------------------+  +------------------------+  |
|  | Results (8)            |  | Preview                |  |
|  |                        |  |                        |  |
|  | > T-015: API Timeout   |  | # T-015: API Timeout  |  |
|  |   ████░░               |  |                        |  |
|  |   T-012: Retry Logic   |  | Status: completed      |  |
|  |   ███░░░               |  | Owner: agent           |  |
|  |   P-003: Timeout       |  |                        |  |
|  |   █████░               |  | ## Context             |  |
|  |                        |  | API calls to external  |  |
|  |                        |  | service timing out...  |  |
|  +------------------------+  +------------------------+  |
+----------------------------------------------------------+
```

**Pros:**
- Familiar pattern (email clients, VS Code, Finder)
- Quick preview without navigating away
- Good for power users who browse many results

**Cons:**
- Requires significant horizontal space — BAD on mobile
- Complex to implement with Pico CSS (no native split pane)
- Overkill for a framework search — users typically want to navigate TO a result, not preview it
- htmx can do it but requires careful panel management

---

## RECOMMENDATION: Option C (Unified Smart Input)

### Why Option C Wins

1. **Lowest friction**: One input, no mode selection, no tabs to discover
2. **Surfaces AI naturally**: Questions get AI answers; searches get results — no hidden features
3. **Pico CSS compatible**: Uses semantic HTML (input, article, nav with pills)
4. **htmx native**: Category filtering via `hx-get` with query params; AI streaming already works
5. **Mobile-friendly**: Single column, stacked layout, no split panes
6. **Progressive enhancement**: Works without JS (form submit), better with htmx, best with AI

### Detailed Mockup: Option C — Desktop

```
+================================================================+
|                                                                 |
|  SEARCH WATCHTOWER                                              |
|  Explore tasks, decisions, learnings, patterns, and docs.       |
|                                                                 |
|  +----------------------------------------------------------+  |
|  |  Search or ask a question...                        [ -> ]|  |
|  +----------------------------------------------------------+  |
|                                                                 |
|  Try: "What patterns have failed most?"                         |
|       "healing loop"  |  "portability"  |  "recent decisions"   |
|                                                                 |
+================================================================+

--- After typing "healing loop" (keyword detected): ---

+================================================================+
|                                                                 |
|  +----------------------------------------------------------+  |
|  |  healing loop                                       [ -> ]|  |
|  +----------------------------------------------------------+  |
|                                                                 |
|  8 results  |  0.3s                                             |
|  [All (8)] [Tasks (3)] [Patterns (2)] [Learnings (2)] [Docs 1] |
|                                                                 |
|  +----------------------------------------------------------+  |
|  | T-015: API Timeout Healing                  Relevance     |  |
|  | .tasks/active/T-015-api-timeout.md          ████░░ High   |  |
|  |                                                           |  |
|  | ...implements retry logic with exponential backoff.       |  |
|  | The healing loop diagnosed this as an external            |  |
|  | dependency failure and suggested...                       |  |
|  +----------------------------------------------------------+  |
|                                                                 |
|  +----------------------------------------------------------+  |
|  | P-003: External API Timeout Pattern         Relevance     |  |
|  | .context/project/patterns.yaml              █████░ V.High |  |
|  |                                                           |  |
|  | Type: failure | Mitigation: Add retry with backoff.       |  |
|  | First seen in T-012, recurred in T-015, T-023...          |  |
|  +----------------------------------------------------------+  |
|                                                                 |
+================================================================+

--- After typing "What causes task failures?" (question detected): ---

+================================================================+
|                                                                 |
|  +----------------------------------------------------------+  |
|  |  What causes task failures?                         [ -> ]|  |
|  +----------------------------------------------------------+  |
|                                                                 |
|  +-- Answer (qwen2.5:14b) ---------------------------------+|  |
|  |                                                          ||  |
|  |  Task failures in the framework typically stem from      ||  |
|  |  three categories:                                       ||  |
|  |                                                          ||  |
|  |  1. **External dependencies** — API timeouts, service    ||  |
|  |     outages [1]                                          ||  |
|  |  2. **Design gaps** — Missing input validation,          ||  |
|  |     incomplete specs [2]                                 ||  |
|  |  3. **Environment issues** — Port conflicts, missing     ||  |
|  |     dependencies [3]                                     ||  |
|  |                                                          ||  |
|  |  The healing loop (agents/healing/) classifies these     ||  |
|  |  and suggests mitigations based on past patterns.        ||  |
|  |                                                          ||  |
|  |  [Save] [Thumbs up] [Thumbs down]   Model: qwen2.5:14b  ||  |
|  +----------------------------------------------------------+|  |
|                                                                 |
|  Follow up: [Ask another question...]                           |
|                                                                 |
|  Sources & Related (5)                                          |
|  [All (5)] [Patterns (2)] [Tasks (2)] [Learnings (1)]          |
|                                                                 |
|  +----------------------------------------------------------+  |
|  | [1] P-003: External API Timeout             █████░ V.High |  |
|  | patterns.yaml                                             |  |
|  | Type: failure | 3 occurrences                             |  |
|  +----------------------------------------------------------+  |
|                                                                 |
+================================================================+
```

### Detailed Mockup: Option C — Mobile

```
+================================+
|                                 |
|  SEARCH WATCHTOWER              |
|                                 |
|  +---------------------------+  |
|  | Search or ask...     [->] |  |
|  +---------------------------+  |
|                                 |
|  Try:                           |
|  [healing loop] [portability]   |
|  [recent decisions]             |
|                                 |
+================================+

--- After search: ---

+================================+
|  +---------------------------+  |
|  | healing loop         [->] |  |
|  +---------------------------+  |
|                                 |
|  8 results | 0.3s               |
|                                 |
|  [All] [Tasks] [Patterns] ...  |
|  (horizontally scrollable)      |
|                                 |
|  +---------------------------+  |
|  | T-015: API Timeout        |  |
|  | Healing                   |  |
|  | ████░░ High               |  |
|  | .tasks/active/T-015...    |  |
|  |                           |  |
|  | ...implements retry       |  |
|  | logic with exponential    |  |
|  | backoff...                |  |
|  +---------------------------+  |
|                                 |
|  +---------------------------+  |
|  | P-003: External API       |  |
|  | Timeout Pattern           |  |
|  | █████░ V.High             |  |
|  | patterns.yaml             |  |
|  |                           |  |
|  | Type: failure             |  |
|  | Mitigation: Add retry...  |  |
|  +---------------------------+  |
|                                 |
+================================+
```

---

## Specific Recommendations

### 1. Q&A Prominence

**Recommendation: Merge into unified input with auto-detection.**

- If query ends with `?` or starts with question words (what, why, how, when, where, who, which, can, does, is, are, should): route to AI Q&A
- Otherwise: route to search
- Add a small toggle link "Search instead" or "Ask AI instead" for override
- The AI answer appears ABOVE search results in a visually distinct `<article>` block
- Conversation history (multi-turn) stays available via "Follow up" input below the answer

**Implementation with htmx:**
```html
<form hx-post="/search/unified" hx-target="#results" hx-swap="innerHTML">
  <input type="search" name="q" placeholder="Search or ask a question...">
  <button type="submit">Go</button>
</form>
```
The server detects intent and returns either search results HTML or AI answer + sources HTML.

### 2. Mode Selector (Keyword/Semantic/Hybrid)

**Recommendation: Hide by default. Auto-select based on availability.**

- If embeddings are available: use hybrid mode by default
- If embeddings unavailable: fall back to keyword
- Add an "Advanced" toggle (small text link, not a dropdown) that reveals mode pills for power users
- The mode pills should use user-friendly labels: "Exact Match" / "Meaning" / "Best Match"

**Implementation:**
```html
<!-- Hidden by default, shown via JS toggle -->
<div id="search-advanced" style="display: none;">
  <small>Search mode:</small>
  <nav>
    <ul>
      <li><a href="#" class="active" data-mode="hybrid">Best Match</a></li>
      <li><a href="#" data-mode="keyword">Exact Match</a></li>
      <li><a href="#" data-mode="semantic">By Meaning</a></li>
    </ul>
  </nav>
</div>
<a href="#" onclick="toggle('search-advanced')"><small>Advanced options</small></a>
```

### 3. Relevance Display

**Recommendation: 5-segment bar with label. Never show raw scores.**

Map scores to 5 levels:
| Score Range | Bar | Label | Color |
|-------------|-----|-------|-------|
| >= 0.8 | `█████` | Exact | green (--pico-ins-color) |
| >= 0.6 | `████░` | High | green |
| >= 0.4 | `███░░` | Good | default text |
| >= 0.2 | `██░░░` | Fair | muted |
| < 0.2 | `█░░░░` | Low | muted |

**Implementation with pure CSS:**
```html
<div class="relevance-bar" data-score="4" title="High relevance">
  <span></span><span></span><span></span><span></span><span class="empty"></span>
  <small>High</small>
</div>

<style>
.relevance-bar {
  display: inline-flex;
  align-items: center;
  gap: 2px;
}
.relevance-bar span {
  display: inline-block;
  width: 6px;
  height: 14px;
  background: var(--pico-primary);
  border-radius: 1px;
}
.relevance-bar span.empty {
  background: var(--pico-muted-border-color);
}
.relevance-bar small {
  margin-left: 0.25rem;
  color: var(--pico-muted-color);
  font-size: 0.75rem;
}
</style>
```

### 4. Result Presentation

**Recommendation: List-based with progressive disclosure. NOT cards, NOT accordions.**

Research (NN/g, Medium) confirms:
- **Lists > cards** for search results — more scannable, fixed element positioning
- **Progressive disclosure** — show title + path + 2-line snippet; click to navigate
- **Category filtering via pills** — horizontal pill bar replaces accordion grouping

Each result item:
```
+----------------------------------------------------------+
| [Category badge]  Title (linked)            Relevance bar |
| File path (monospace, muted)                              |
|                                                           |
| Two-line snippet with **highlighted** matching terms...   |
+----------------------------------------------------------+
```

**Implementation:**
```html
<article style="padding: 0.75rem 1rem; margin-bottom: 0.5rem;">
  <div style="display: flex; justify-content: space-between; align-items: baseline;">
    <div>
      <kbd style="font-size: 0.7rem;">Task</kbd>
      <a href="/tasks/T-015"><strong>T-015: API Timeout Healing</strong></a>
    </div>
    <div class="relevance-bar" data-score="4">...</div>
  </div>
  <code style="font-size: 0.75rem; color: var(--pico-muted-color);">
    .tasks/active/T-015-api-timeout.md
  </code>
  <p style="font-size: 0.85rem; margin-top: 0.25rem; line-height: 1.5;">
    ...implements retry logic with exponential backoff. The healing loop
    diagnosed this as an external dependency failure...
  </p>
</article>
```

### 5. Category Filtering

**Recommendation: Horizontal pill bar (replaces `<details>` accordions).**

```html
<nav id="result-filters" style="margin-bottom: 1rem;">
  <ul style="display: flex; gap: 0.5rem; flex-wrap: wrap; list-style: none; padding: 0;">
    <li><a href="#" class="active"
           hx-get="/search?q=healing&cat=all" hx-target="#results">All (8)</a></li>
    <li><a href="#"
           hx-get="/search?q=healing&cat=tasks" hx-target="#results">Tasks (3)</a></li>
    <li><a href="#"
           hx-get="/search?q=healing&cat=patterns" hx-target="#results">Patterns (2)</a></li>
    <li><a href="#"
           hx-get="/search?q=healing&cat=learnings" hx-target="#results">Learnings (2)</a></li>
    <li><a href="#"
           hx-get="/search?q=healing&cat=docs" hx-target="#results">Docs (1)</a></li>
  </ul>
</nav>
```

Style the active pill:
```css
#result-filters a {
  padding: 0.25rem 0.75rem;
  border-radius: 2rem;
  font-size: 0.8rem;
  text-decoration: none;
  border: 1px solid var(--pico-muted-border-color);
  color: var(--pico-muted-color);
}
#result-filters a.active {
  background: var(--pico-primary);
  color: var(--pico-primary-inverse);
  border-color: var(--pico-primary);
}
```

### 6. Empty State / Landing Page

**Recommendation: Welcoming landing with suggestions, recent queries, and stats.**

When no query is entered, show:
```
+----------------------------------------------------------+
|                                                           |
|  SEARCH WATCHTOWER                                        |
|  Explore tasks, decisions, learnings, patterns, and docs. |
|                                                           |
|  +----------------------------------------------------+  |
|  | Search or ask a question...                   [->] |  |
|  +----------------------------------------------------+  |
|                                                           |
|  EXAMPLE QUESTIONS                                        |
|  > What patterns have failed most?                        |
|  > How does the healing loop work?                        |
|  > What decisions were made this week?                    |
|                                                           |
|  POPULAR SEARCHES                                         |
|  [healing loop]  [portability]  [task lifecycle]          |
|  [context fabric]  [antifragility]                        |
|                                                           |
|  QUICK STATS                                              |
|  142 docs indexed  |  2,847 chunks embedded               |
|  Tasks: 45 completed, 12 active                           |
|                                                           |
+----------------------------------------------------------+
```

**Implementation:** Server passes `suggestions`, `popular_searches`, and `stats` to the template when `q` is empty.

### 7. Mobile Layout

**Recommendation: Stack everything vertically. Search input full-width. Pills horizontally scrollable.**

Key changes for mobile:
1. **Remove the inline fieldset group** — input goes full-width, button below or icon inside
2. **Category pills scroll horizontally** — `overflow-x: auto; white-space: nowrap;`
3. **AI answer uses full width** — no padding issues
4. **Relevance bar remains compact** — 5 dots work at any width
5. **Snippet text truncates** at 2 lines with CSS `line-clamp`

```css
@media (max-width: 768px) {
  /* Stack search input and button */
  form[role="search"] fieldset[role="group"] {
    flex-direction: column;
  }

  /* Horizontal scroll for category pills */
  #result-filters ul {
    flex-wrap: nowrap;
    overflow-x: auto;
    -webkit-overflow-scrolling: touch;
    padding-bottom: 0.5rem;
  }

  /* Truncate snippets */
  .result-snippet {
    display: -webkit-box;
    -webkit-line-clamp: 2;
    -webkit-box-orient: vertical;
    overflow: hidden;
  }
}
```

---

## Implementation Priority

### Phase 1: Quick Wins (1-2 hours)
1. Add empty state with suggestions (no backend changes)
2. Replace raw scores with relevance bars (CSS + Jinja filter)
3. Replace accordion grouping with pill filter bar
4. Fix mobile layout (CSS media queries)

### Phase 2: Q&A Promotion (2-3 hours)
5. Move Q&A input into the main search form (unified input)
6. Add intent detection (question vs. search) — server-side heuristic
7. Show AI answer above results when question detected
8. Keep multi-turn conversation for follow-ups

### Phase 3: Polish (1-2 hours)
9. Add recent/popular searches (requires server-side tracking)
10. Rename modes: BM25 -> "Exact Match", Semantic -> "By Meaning", Hybrid -> "Best Match"
11. Hide mode selector behind "Advanced" toggle
12. Add search tips / "Did you mean?" for zero results

---

## Technical Notes for Pico CSS + htmx

### Pico CSS Constraints
- **No utility classes** — Pico is classless/semantic; use `<article>`, `<nav>`, `<kbd>`, etc.
- **`role="group"` for input groups** — only works horizontally; stack with CSS for mobile
- **Dark/light theme** — use CSS variables (`--pico-primary`, `--pico-muted-color`) not hex values
- **Grid layout** — use `.grid` class for multi-column; auto-responsive

### htmx Patterns to Use
- **Active Search**: `hx-trigger="input changed delay:500ms"` for live search
- **HATEOAS Tabs**: Server returns HTML with active class on the selected pill
- **Swap targets**: `hx-target="#results"` to swap just the results section
- **Push URL**: `hx-push-url="true"` to keep search state in URL
- **SSE for AI**: Keep existing fetch+ReadableStream for AI streaming (htmx SSE extension is an alternative)

### Intent Detection Logic (Python)
```python
QUESTION_WORDS = {'what', 'why', 'how', 'when', 'where', 'who', 'which',
                  'can', 'does', 'is', 'are', 'should', 'would', 'could',
                  'will', 'do', 'explain', 'describe', 'tell'}

def detect_intent(query: str) -> str:
    """Detect if query is a question (-> AI) or search (-> results)."""
    q = query.strip().lower()
    if q.endswith('?'):
        return 'question'
    first_word = q.split()[0] if q else ''
    if first_word in QUESTION_WORDS:
        return 'question'
    return 'search'
```

---

## Sources

- [Command Palette Pattern](https://uxpatterns.dev/patterns/advanced/command-palette)
- [Perplexity UX Analysis (NN/g)](https://www.nngroup.com/articles/perplexity-henry-modisett/)
- [Search UX Best Practices 2026](https://www.designmonks.co/blog/search-ux-best-practices)
- [Cards vs Lists UX (NN/g)](https://www.nngroup.com/videos/card-view-vs-list-view/)
- [Empty State UX (NN/g)](https://www.nngroup.com/articles/empty-state-interface-design/)
- [htmx Active Search](https://htmx.org/examples/active-search/)
- [htmx Tabs (HATEOAS)](https://htmx.org/examples/tabs-hateoas/)
- [Pico CSS Forms](https://picocss.com/docs/forms)
- [Linear Search Changelog](https://linear.app/changelog/2025-04-10-new-search)
- [Perplexity Pro Search Architecture](https://www.langchain.com/breakoutagents/perplexity)
