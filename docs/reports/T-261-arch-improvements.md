# Q&A System Architectural Improvements Research

**Date:** 2026-02-24
**Current Stack:** Flask + Vanilla JS EventSource + Ollama SSE + sqlite-vec + Tantivy BM25

---

## 1. Multi-Turn Conversation

### Current State
- Single-shot Q&A: each `/search/ask?q=...` is stateless
- `stream_answer()` sends system prompt + single user message to Ollama
- No chat history, no session tracking

### Architecture Design

**Option A: Client-Side History (Recommended)**
- Store conversation history in JS array on the frontend
- Send full history with each request: `POST /search/ask` with `{query, history: [{role, content}, ...]}`
- Pro: Zero server state, survives server restarts, no session management
- Con: History grows with each turn; need to truncate for context window limits

**Option B: Server-Side Sessions**
- Use Flask sessions (cookie-based) or server-side store (Redis/SQLite)
- Session ID in cookie, history stored server-side
- Pro: Smaller request payloads
- Con: Server state management, cleanup of stale sessions, more complex

**Recommended Implementation (Client-Side):**

```python
# ask.py — modify stream_answer to accept history
def stream_answer(query: str, chunks: list[dict], history: list[dict] = None):
    messages = [{"role": "system", "content": SYSTEM_PROMPT}]

    # Add conversation history (last N turns, truncated to fit context)
    if history:
        # Keep last 6 turns (3 exchanges) to stay within context window
        MAX_HISTORY_TURNS = 6
        for msg in history[-MAX_HISTORY_TURNS:]:
            messages.append({"role": msg["role"], "content": msg["content"]})

    # Current query with RAG context
    context = format_rag_context(chunks)
    messages.append({"role": "user", "content": f"{context}\n\n## Question\n\n{query}"})

    response = ollama.chat(model=model, messages=messages, stream=True)
    ...
```

```javascript
// Frontend — maintain conversation array
var conversationHistory = [];

function askQuestion() {
    var query = input.value.trim();

    // POST instead of GET to send history
    fetch('/search/ask', {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({
            query: query,
            history: conversationHistory
        })
    }).then(response => {
        // Read SSE from response body stream using ReadableStream
        const reader = response.body.getReader();
        const decoder = new TextDecoder();
        // ... process SSE tokens from stream
    });

    // After answer completes:
    conversationHistory.push({role: 'user', content: query});
    conversationHistory.push({role: 'assistant', content: fullAnswer});
}
```

**SSE with POST Challenge:**
- `EventSource` only supports GET. For POST with history, use `fetch()` with `ReadableStream`
- Alternative: Send history as a session token (hash of history array), with server-side cache

**Context Window Management:**
- qwen2.5-coder-32b has ~128K context window (IQ2_M quantization may limit effective use)
- dolphin-llama3:8b has 8K context
- Strategy: Keep last 3 Q&A exchanges + current RAG context
- Estimate: System prompt (~200 tokens) + RAG context (~3000 tokens) + 3 exchanges (~2000 tokens) = ~5200 tokens — fits comfortably in both models

**Assessment:**
- User Impact: **HIGH** — Transforms Q&A from isolated queries to natural conversation
- Implementation Effort: **3 days** (POST endpoint, fetch-based SSE reader, history management, context truncation)
- Dependencies: None (standalone improvement)
- Risk: POST+SSE requires replacing EventSource with fetch ReadableStream, more complex JS

---

## 2. Answer Caching

### Architecture Design

**Two-Layer Cache:**

1. **Exact Match Cache** — Hash of normalized query -> cached response
2. **Semantic Cache** — Embed query, find nearest cached query within threshold

```python
# cache.py
import hashlib
import json
import sqlite3
import time

CACHE_DB = Path("/tmp/fw-qa-cache.db")
SIMILARITY_THRESHOLD = 0.92  # cosine similarity for semantic cache hit
CACHE_TTL = 3600  # 1 hour default

class QACache:
    def __init__(self):
        self.db = self._init_db()

    def _init_db(self):
        db = sqlite3.connect(str(CACHE_DB), check_same_thread=False)
        db.execute("""
            CREATE TABLE IF NOT EXISTS qa_cache (
                id INTEGER PRIMARY KEY,
                query_hash TEXT UNIQUE,
                query_text TEXT,
                query_embedding BLOB,
                answer TEXT,
                sources TEXT,  -- JSON
                model TEXT,
                created_at REAL,
                hit_count INTEGER DEFAULT 0
            )
        """)
        # sqlite-vec for semantic matching
        sqlite_vec.load(db)
        db.execute("""
            CREATE VIRTUAL TABLE IF NOT EXISTS cache_vec USING vec0(
                id INTEGER PRIMARY KEY,
                embedding FLOAT[384]
            )
        """)
        return db

    def get(self, query: str) -> dict | None:
        """Check exact match first, then semantic."""
        normalized = query.strip().lower()
        qhash = hashlib.sha256(normalized.encode()).hexdigest()

        # Exact match
        row = self.db.execute(
            "SELECT answer, sources, model FROM qa_cache WHERE query_hash = ? AND created_at > ?",
            (qhash, time.time() - CACHE_TTL)
        ).fetchone()
        if row:
            return {"answer": row[0], "sources": json.loads(row[1]), "model": row[2]}

        # Semantic match
        query_emb = _embed_single(query)
        rows = self.db.execute("""
            SELECT c.answer, c.sources, c.model, v.distance
            FROM cache_vec v JOIN qa_cache c ON c.id = v.id
            WHERE v.embedding MATCH ? AND k = 3
            AND c.created_at > ?
        """, (query_emb, time.time() - CACHE_TTL)).fetchall()

        for answer, sources, model, distance in rows:
            similarity = 1.0 - distance
            if similarity >= SIMILARITY_THRESHOLD:
                return {"answer": answer, "sources": json.loads(sources), "model": model}

        return None

    def put(self, query: str, answer: str, sources: list, model: str):
        """Store a Q&A pair in cache."""
        normalized = query.strip().lower()
        qhash = hashlib.sha256(normalized.encode()).hexdigest()
        emb = _embed_single(query)
        row_id = self.db.execute(
            "INSERT OR REPLACE INTO qa_cache (query_hash, query_text, query_embedding, answer, sources, model, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)",
            (qhash, query, emb, answer, json.dumps(sources), model, time.time())
        ).lastrowid
        self.db.execute("INSERT OR REPLACE INTO cache_vec (id, embedding) VALUES (?, ?)", (row_id, emb))
        self.db.commit()
```

**Cache Invalidation:**
- The BM25 index rebuilds every 60s, vector index every 120s
- Add a content hash based on indexed file mtimes
- On cache lookup, compare current content hash with cached one
- If knowledge base changed -> invalidate all cache entries
- Simple approach: `_index_built_at` timestamp comparison

**Streaming with Cache:**
- Cached answers: Send all tokens at once (instant response) or simulate streaming with small delays
- Non-cached: Stream normally, accumulate answer, cache on completion

**Assessment:**
- User Impact: **MEDIUM** — Most queries in this system are exploratory/unique; repeat queries less common for a project knowledge base
- Implementation Effort: **2 days** (cache table, semantic matching, invalidation, streaming integration)
- Dependencies: Uses existing sqlite-vec and embedding infrastructure
- Risk: Cache staleness if invalidation misses knowledge base changes; 0.92 threshold needs tuning

---

## 3. User Feedback Loop

### Architecture Design

```python
# feedback.py
FEEDBACK_DB = Path("/tmp/fw-qa-feedback.db")

def init_feedback_db():
    db = sqlite3.connect(str(FEEDBACK_DB), check_same_thread=False)
    db.execute("""
        CREATE TABLE IF NOT EXISTS qa_feedback (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            query TEXT NOT NULL,
            answer TEXT NOT NULL,
            model TEXT,
            sources TEXT,  -- JSON array of source paths
            rating INTEGER CHECK(rating IN (-1, 0, 1)),  -- -1=bad, 0=neutral, 1=good
            comment TEXT DEFAULT '',
            created_at REAL DEFAULT (unixepoch())
        )
    """)
    db.execute("CREATE INDEX IF NOT EXISTS idx_feedback_rating ON qa_feedback(rating)")
    db.execute("CREATE INDEX IF NOT EXISTS idx_feedback_created ON qa_feedback(created_at)")
    return db
```

**Frontend Integration:**
- After answer completes, show subtle thumbs up/down buttons
- On click, POST to `/search/feedback` with query, answer, model, sources, rating
- Optional: expandable comment field for "What went wrong?"

**Using Feedback to Improve Quality:**

1. **Prompt Engineering:** Analyze low-rated answers to identify patterns:
   - Which source categories correlate with good/bad ratings?
   - Are certain query types (how-to vs factual) consistently underperforming?

2. **Retrieval Tuning:**
   - For poorly-rated answers, check if relevant sources were retrieved
   - If sources were present but answer was bad -> prompt issue
   - If sources were missing -> retrieval issue (adjust BM25 boost, chunk size, etc.)

3. **Golden Set:** Use feedback to build query-answer pairs for regression testing

**Analytics Dashboard Endpoint:**
```python
@bp.route("/search/feedback/analytics")
def feedback_analytics():
    db = get_feedback_db()
    stats = {
        "total": db.execute("SELECT COUNT(*) FROM qa_feedback").fetchone()[0],
        "positive": db.execute("SELECT COUNT(*) FROM qa_feedback WHERE rating = 1").fetchone()[0],
        "negative": db.execute("SELECT COUNT(*) FROM qa_feedback WHERE rating = -1").fetchone()[0],
        "recent": db.execute(
            "SELECT query, rating, created_at FROM qa_feedback ORDER BY created_at DESC LIMIT 20"
        ).fetchall(),
    }
    return render_page("feedback_analytics.html", **stats)
```

**Assessment:**
- User Impact: **HIGH** — Direct signal for improvement; shows users their input matters
- Implementation Effort: **1.5 days** (SQLite table, POST endpoint, frontend buttons, basic analytics page)
- Dependencies: None (standalone)
- Risk: Low adoption if buttons are intrusive; make them subtle and optional

---

## 4. Streaming UX Improvements

### Current State
- `renderAnswer()` does basic text->HTML: bold, inline code, citation refs, line breaks
- No code block handling, no syntax highlighting, no copy buttons
- "Thinking..." shown until first token, then hidden

### Improvement Plan

**A. Progressive Markdown Rendering**

Replace custom `renderAnswer()` with **marked.js** (~40KB gzipped) — Full CommonMark, handles partial input well.

```javascript
// Include: <script src="/static/marked.min.js"></script>
// Include: <script src="/static/purify.min.js"></script>

var fullText = '';

function updateAnswer(newToken) {
    fullText += newToken;
    // marked handles incomplete markdown gracefully
    var html = marked.parse(fullText);
    // Sanitize to prevent XSS
    textDiv.innerHTML = DOMPurify.sanitize(html);
    // Post-process: add copy buttons to code blocks
    addCopyButtons(textDiv);
    // Post-process: citation styling
    textDiv.querySelectorAll('p, li').forEach(el => {
        el.innerHTML = el.innerHTML.replace(
            /\[(\d+)\]/g,
            '<sup style="color:var(--pico-primary);font-weight:600">[$1]</sup>'
        );
    });
}
```

**B. Syntax Highlighting** — **highlight.js** (~30KB core + languages), auto-detects language.

```javascript
// After each markdown render:
function highlightCode(container) {
    container.querySelectorAll('pre code').forEach(block => {
        hljs.highlightElement(block);
    });
}
```

**C. Copy Button for Code Blocks:**
```javascript
function addCopyButtons(container) {
    container.querySelectorAll('pre').forEach(pre => {
        if (pre.querySelector('.copy-btn')) return; // already has one
        var btn = document.createElement('button');
        btn.className = 'copy-btn outline';
        btn.textContent = 'Copy';
        btn.style.cssText = 'position:absolute;top:0.25rem;right:0.25rem;padding:0.15rem 0.4rem;font-size:0.7rem;';
        btn.onclick = function() {
            var code = pre.querySelector('code');
            navigator.clipboard.writeText(code.textContent).then(function() {
                btn.textContent = 'Copied!';
                setTimeout(function() { btn.textContent = 'Copy'; }, 1500);
            });
        };
        pre.style.position = 'relative';
        pre.appendChild(btn);
    });
}
```

**D. Enhanced "Thinking" Phase:**
```javascript
// Show phases with timing
var thinkingStart = Date.now();
var phases = [
    "Retrieving relevant sources...",
    "Analyzing context...",
    "Generating answer..."
];
var phaseIndex = 0;
var phaseInterval = setInterval(function() {
    if (phaseIndex < phases.length - 1) {
        phaseIndex++;
        statusDiv.innerHTML = '<span aria-busy="true">' + phases[phaseIndex] + '</span>';
    }
}, 1500);

// On first token:
clearInterval(phaseInterval);
var elapsed = ((Date.now() - thinkingStart) / 1000).toFixed(1);
statusDiv.textContent = 'Answer generated in ' + elapsed + 's';
```

**Performance Note:** Debounce markdown rendering to ~100ms intervals to prevent flicker during rapid token streaming.

**Assessment:**
- User Impact: **HIGH** — Dramatically improves perceived quality and usability of answers
- Implementation Effort: **2 days** (marked.js integration, highlight.js, copy buttons, thinking phases)
- Dependencies: None (standalone frontend work)
- Risk: Incremental markdown parsing can flicker; debounce renders to ~100ms intervals

---

## 5. Query Understanding

### Architecture Design

**A. Intent Classification (Rule-Based)**

```python
# query_understanding.py
INTENT_KEYWORDS = {
    "factual": ["what is", "who", "when", "where", "how many", "which", "define"],
    "how_to": ["how to", "how do i", "how can i", "steps to", "guide", "tutorial"],
    "exploratory": ["why", "explain", "compare", "difference", "pros and cons", "should i"],
    "troubleshooting": ["error", "fail", "broken", "not working", "issue", "bug", "fix"],
    "code": ["code", "example", "snippet", "function", "implement", "write"],
}

def classify_intent(query: str) -> str:
    """Rule-based intent classification. Returns intent type."""
    q = query.lower().strip()
    scores = {}
    for intent, keywords in INTENT_KEYWORDS.items():
        scores[intent] = sum(1 for kw in keywords if kw in q)
    best = max(scores, key=scores.get)
    return best if scores[best] > 0 else "general"
```

**Why rule-based, not ML:** For a project knowledge base with predictable query patterns, rule-based is:
- Zero additional dependencies
- Instant (no model inference)
- Easy to maintain and extend
- Good enough for 5-7 intent categories

**B. Query Rewriting for Better Retrieval**

```python
def rewrite_query(query: str, intent: str) -> str:
    """Expand or rewrite query for better retrieval."""
    # Expand abbreviations common in the framework
    expansions = {
        "AC": "acceptance criteria",
        "RAG": "retrieval augmented generation",
        "SSE": "server-sent events",
        "BM25": "keyword search",
        "RRF": "reciprocal rank fusion",
    }
    rewritten = query
    for abbr, expansion in expansions.items():
        if abbr in query and expansion not in query.lower():
            rewritten += f" ({expansion})"

    # For troubleshooting, add resolution keywords
    if intent == "troubleshooting" and "fix" not in query.lower():
        rewritten += " resolution fix"

    return rewritten
```

**C. Suggested Follow-Up Questions**

After the answer is complete, generate 2-3 follow-up suggestions via a second (non-streaming) LLM call:

```python
def generate_followups(query: str, answer: str, model: str) -> list[str]:
    """Generate suggested follow-up questions (non-streaming)."""
    try:
        response = ollama.chat(
            model=model,
            messages=[
                {"role": "system", "content": "You suggest follow-up questions. Return JSON array only."},
                {"role": "user", "content": f"Question: {query}\nAnswer: {answer[:500]}\n\nSuggest 3 follow-ups:"},
            ],
            stream=False,
        )
        return json.loads(response["message"]["content"])
    except Exception:
        return []
```

Frontend: Render as clickable chips that populate the input and trigger askQuestion().

**Assessment:**
- User Impact: **MEDIUM-HIGH** — Better retrieval for all queries; follow-ups guide exploration
- Implementation Effort: **3 days** (intent classification, query rewriting, follow-up generation, frontend chips)
- Dependencies: Follow-up generation uses LLM (same Ollama), adds ~2-3s per query
- Risk: Follow-up generation doubles LLM calls; make it optional/async. Rule-based intent may misclassify edge cases.

---

## 6. Answer Quality Metrics

### Architecture Design

**A. Automated Scoring**

```python
# quality.py — Post-hoc answer quality scoring
import re

def score_answer(query: str, answer: str, chunks: list[dict]) -> dict:
    """Score answer quality on multiple dimensions."""
    scores = {}

    # 1. Groundedness — citations present?
    citations = re.findall(r'\[(\d+)\]', answer)
    cited_sources = set(int(c) for c in citations if int(c) <= len(chunks))
    scores["citation_count"] = len(citations)
    scores["unique_sources_cited"] = len(cited_sources)
    scores["source_coverage"] = len(cited_sources) / len(chunks) if chunks else 0

    # 2. Completeness — answer length relative to query complexity
    scores["answer_length"] = len(answer.split())
    scores["length_ratio"] = len(answer.split()) / max(len(query.split()), 1)

    # 3. Hallucination risk — citations reference valid sources
    invalid_citations = [int(c) for c in citations if int(c) > len(chunks)]
    scores["invalid_citations"] = len(invalid_citations)
    scores["hallucination_risk"] = "high" if invalid_citations else "low"

    # 4. Confidence — uncertainty expression detection
    uncertainty_phrases = ["i'm not sure", "i don't know", "unclear", "may not", "cannot determine"]
    scores["expressed_uncertainty"] = any(p in answer.lower() for p in uncertainty_phrases)

    # 5. Overall score (0-100)
    overall = 50  # base
    overall += min(20, scores["citation_count"] * 5)
    overall += min(15, int(scores["source_coverage"] * 15))
    overall -= scores["invalid_citations"] * 10
    if scores["answer_length"] < 20:
        overall -= 20
    scores["overall"] = max(0, min(100, overall))

    return scores
```

**B. Query Logging Table**

```sql
CREATE TABLE qa_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    query TEXT,
    intent TEXT,
    answer TEXT,
    model TEXT,
    sources_json TEXT,
    overall_score REAL,
    citation_count INTEGER,
    source_coverage REAL,
    latency_ms INTEGER,
    token_count INTEGER,
    created_at REAL DEFAULT (unixepoch())
);
```

**C. Analytics Dashboard** — Total queries, avg score, avg latency, breakdown by intent, list of low-scoring queries.

**Assessment:**
- User Impact: **MEDIUM** — Operational intelligence, not directly user-facing (except dashboard)
- Implementation Effort: **2.5 days** (scoring module, logging, analytics endpoint, dashboard template)
- Dependencies: Pairs well with #3 (User Feedback) — combine automated + human scoring
- Risk: Automated scoring is heuristic; the "overall score" formula needs calibration with real data

---

## 7. Concurrent Request Handling

### Current State
- Flask dev server is single-threaded by default
- Ollama serves requests in a queue (one at a time per model by default)
- `stream_answer()` holds the connection for the entire generation (~10-30s for complex answers)
- Multiple simultaneous `/search/ask` requests would queue in Ollama

### Architecture Options

**A. Application-Level Queue (Recommended for Current Scale)**

```python
# request_queue.py
import queue
import threading
import uuid

MAX_QUEUE_SIZE = 5
MAX_CONCURRENT_LLM = 1  # Ollama typically handles 1 at a time

class LLMRequestQueue:
    def __init__(self):
        self._queue = queue.Queue(maxsize=MAX_QUEUE_SIZE)
        self._semaphore = threading.Semaphore(MAX_CONCURRENT_LLM)
        self._positions = {}

    def enqueue(self, request_id: str) -> int:
        """Add request to queue. Returns position (0 = processing now)."""
        if self._queue.full():
            raise QueueFullError("Server busy, try again later")
        self._queue.put(request_id)
        return self._queue.qsize()

    def wait_for_turn(self, request_id: str, timeout: int = 120):
        """Block until it's this request's turn."""
        self._semaphore.acquire(timeout=timeout)

    def release(self, request_id: str):
        """Release the semaphore after request completes."""
        self._semaphore.release()
        self._positions.pop(request_id, None)
```

**B. Queue Position SSE Events**

When a user's request is queued, send position updates before generation starts:

```python
def stream_answer_queued(query, chunks, request_queue):
    request_id = str(uuid.uuid4())
    try:
        position = request_queue.enqueue(request_id)
    except QueueFullError:
        yield f"data: {json.dumps({'type': 'error', 'message': 'Server busy. Please try again.'})}\n\n"
        return

    if position > 0:
        yield f"data: {json.dumps({'type': 'queue', 'position': position})}\n\n"

    request_queue.wait_for_turn(request_id)
    yield f"data: {json.dumps({'type': 'queue', 'position': 0})}\n\n"

    try:
        for event in stream_answer(query, chunks):
            yield event
    finally:
        request_queue.release(request_id)
```

**C. Ollama Configuration**

```bash
OLLAMA_NUM_PARALLEL=2    # Number of parallel requests (default: 1)
OLLAMA_MAX_LOADED_MODELS=1  # Keep 1 model loaded (RAM constraint)
```

With `OLLAMA_NUM_PARALLEL=2`, Ollama can handle 2 concurrent requests for the same model, though throughput per request drops. For IQ2_M quantized 32B model on limited hardware, parallel=1 is likely optimal.

**D. Production WSGI Server**

```bash
# Gunicorn with gevent for async SSE
pip install gunicorn gevent
gunicorn -w 1 -k gevent --timeout 120 web.app:app

# Or with threading
gunicorn -w 1 --threads 4 --timeout 120 web.app:app
```

Note: SSE (streaming response) requires either:
- gevent workers (cooperative concurrency — ideal for I/O-bound SSE)
- threaded workers (1 thread per SSE connection)
- NOT multiple process workers with preforked model (would waste RAM)

**Assessment:**
- User Impact: **MEDIUM** — Only matters with multiple simultaneous users; for single-user/small team, less critical
- Implementation Effort: **2 days** (request queue, position SSE events, gunicorn config)
- Dependencies: None, but pairs with Gunicorn deployment
- Risk: Queue full rejection hurts UX; need graceful "try again" messaging

---

## Priority Matrix & Implementation Roadmap

### Priority Ranking (by User Impact / Effort ratio)

| # | Improvement | Impact | Effort | Priority | Dependencies |
|---|-------------|--------|--------|----------|--------------|
| 4 | Streaming UX (markdown, highlight, copy) | HIGH | 2d | **P1** | None |
| 3 | User Feedback Loop | HIGH | 1.5d | **P1** | None |
| 1 | Multi-Turn Conversation | HIGH | 3d | **P2** | None |
| 5 | Query Understanding | MED-HIGH | 3d | **P2** | Pairs with #1 |
| 6 | Answer Quality Metrics | MEDIUM | 2.5d | **P3** | Pairs with #3 |
| 2 | Answer Caching | MEDIUM | 2d | **P3** | None |
| 7 | Concurrent Requests | MEDIUM | 2d | **P4** | None |

### Recommended Implementation Phases

**Phase 1 (Week 1): Core UX — 3.5 days**
1. Streaming UX improvements (2d) — immediate visual quality improvement
2. User feedback buttons (1.5d) — start collecting signal immediately

**Phase 2 (Week 2): Intelligence — 3 days**
3. Multi-turn conversation (3d) — biggest functional leap

**Phase 3 (Week 3): Quality & Discovery — 5.5 days**
4. Query understanding (3d) — improves retrieval for all queries
5. Answer quality metrics (2.5d) — operational intelligence

**Phase 4 (Week 4): Performance — 4 days**
6. Answer caching (2d) — reduces LLM load
7. Concurrent requests (2d) — scales to multiple users

### Total Estimated Effort: ~16 days

### Key Architectural Decisions

1. **Client-side vs server-side conversation history:** Client-side recommended — simpler, no session management, survives restarts. Send via POST body.

2. **EventSource vs fetch for SSE:** Must switch to `fetch()` + `ReadableStream` for POST-based SSE (multi-turn). This is a one-way door — once changed, the SSE client code changes significantly. Do this in Phase 2 when implementing multi-turn.

3. **marked.js vs custom renderer:** Use marked.js — the custom `renderAnswer()` is already struggling with markdown edge cases. marked.js handles partial input well with debounced rendering.

4. **Separate DBs vs single DB:** Use one SQLite file for all Q&A state (cache, feedback, logs). Simplifies backup, cleanup, and cross-queries (e.g., "show feedback for cached answers").

5. **Rule-based vs ML intent classification:** Rule-based is correct for this scale. The query vocabulary is bounded by framework concepts. ML would add dependencies and training data requirements with minimal benefit.

### File Change Map

| File | Changes |
|------|---------|
| `web/ask.py` | Multi-turn history, quality scoring, follow-ups |
| `web/blueprints/discovery.py` | POST endpoint, feedback endpoints, analytics |
| `web/templates/search.html` | marked.js, highlight.js, copy buttons, feedback UI, follow-up chips |
| `web/qa_cache.py` | NEW — Answer caching module |
| `web/qa_feedback.py` | NEW — Feedback collection and analytics |
| `web/query_understanding.py` | NEW — Intent classification, query rewriting |
| `web/request_queue.py` | NEW — Concurrent request queue |
| `web/templates/qa_analytics.html` | NEW — Analytics dashboard |
