"""REST API blueprint — JSON endpoints for search and Q&A (T-382, T-384).

Endpoints:
    GET  /api/v1          — API index with endpoint documentation
    POST /api/v1/ask      — RAG-assisted Q&A (non-streaming JSON)
    POST /api/v1/ask/stream — RAG-assisted Q&A (SSE streaming)
    POST /api/v1/search   — Search results as JSON (query in the body)
    GET  /api/v1/search   — same, query in ?q= (compatibility; URL is logged)
    GET  /api/v1/health   — API health check
"""

import json
import time

from flask import Blueprint, Response, jsonify, request

from web.shared import sse_event

bp = Blueprint("api", __name__, url_prefix="/api/v1")


# T-4657: the LLM, embeddings and keyword-search stacks are optional installs
# (ollama, sqlite_vec, tantivy). Each component names the modules that must
# import for it to work; a missing one degrades the endpoint, never a 500.
_COMPONENTS = {
    "llm": ("web.llm",),
    "ask": ("web.ask",),
    "embeddings": ("web.embeddings",),
    "search": ("web.search",),
}


def _missing(*components):
    """Names of the given components that cannot be imported (T-4657).

    The llm component also needs a provider manager: get_manager() imports
    the ollama package lazily, so it is called here rather than at first use.
    """
    import importlib
    missing = []
    for name in components:
        try:
            for mod in _COMPONENTS[name]:
                importlib.import_module(mod)
            if name == "llm":
                from web.llm import get_manager
                get_manager()
        except ImportError:
            missing.append(name)
    return missing


def _unavailable(missing):
    """503 JSON for an endpoint whose optional stack is not installed."""
    return jsonify({"error": "optional component not installed: " + ", ".join(missing),
                    "missing": missing}), 503


@bp.errorhandler(Exception)
def _index_unavailable(exc):
    """T-3786: readers never build the vector index; an unusable index is a 503
    with the remedy, not a 500 and not a silent multi-hour rebuild."""
    if isinstance(exc, ImportError):
        # T-4657: an optional package missing below the import probes.
        return _unavailable([getattr(exc, "name", None) or str(exc)])
    try:
        from web.embeddings import IndexUnavailable
    except ImportError:
        raise exc
    if isinstance(exc, IndexUnavailable):
        return jsonify({"error": "vector index unavailable", "detail": str(exc),
                        "remedy": "fw index reindex"}), 503
    raise exc


@bp.route("/")
def index():
    """Self-documenting API index."""
    base = request.host_url.rstrip("/") + "/api/v1"
    return jsonify({
        "name": "Watchtower API",
        "version": "v1",
        "endpoints": {
            "ask": {
                "url": f"{base}/ask",
                "methods": ["GET", "POST"],
                "description": "RAG-assisted Q&A (complete JSON response)",
                "params": {
                    "q": "Query string (GET) or 'query' in JSON body (POST)",
                    "history": "Conversation history as [{role, content}] (POST only)",
                    "limit": "Max RAG chunks to retrieve (default: 10, max: 20)",
                },
                "example": f"curl '{base}/ask?q=What+are+the+four+directives?'",
            },
            "ask_stream": {
                "url": f"{base}/ask/stream",
                "methods": ["GET", "POST"],
                "description": "RAG-assisted Q&A (Server-Sent Events stream)",
                "params": {
                    "q": "Query string (GET) or 'query' in JSON body (POST)",
                    "history": "Conversation history (POST only)",
                },
                "events": ["model", "thinking", "thinking_done", "token", "sources", "done", "error"],
                "example": f"curl -N '{base}/ask/stream?q=How+does+healing+work?'",
            },
            "search": {
                "url": f"{base}/search",
                "methods": ["GET"],
                "description": "Search project knowledge base",
                "params": {
                    "q": "Search query (min 2 chars)",
                    "mode": "Search mode: keyword, semantic, hybrid (default: hybrid)",
                    "limit": "Max results (default: 20, max: 50)",
                },
                "example": f"curl '{base}/search?q=healing+loop&mode=keyword&limit=5'",
            },
            "health": {
                "url": f"{base}/health",
                "methods": ["GET"],
                "description": "API and provider health status",
            },
        },
    })


def _request_query():
    """T-4061: the query from a POST body (JSON, else form) or GET ?q=.

    POST is the path that keeps the query out of request logs and browser
    history; GET remains for compatibility.
    """
    if request.method == "POST":
        data = request.get_json(silent=True) or request.form
        return (data.get("query") or data.get("q") or "").strip()
    return request.args.get("q", "").strip()


@bp.route("/ask", methods=["GET", "POST"])
def ask():
    """RAG-assisted Q&A returning complete JSON answer.

    POST: /api/v1/ask with JSON {"query": "...", "history": [...]} (preferred)
    GET:  /api/v1/ask?q=How does the audit system work? (compatibility; the
          query is written to the request log)

    Returns:
        {
            "query": "...",
            "answer": "...",
            "model": "...",
            "provider": "...",
            "sources": [...],
            "thinking_time_ms": 0,
            "total_time_ms": 0
        }
    """
    missing = _missing("llm", "ask", "embeddings")
    if missing:
        return _unavailable(missing)
    from web.ask import (
        SYSTEM_PROMPT,
        format_rag_context,
        get_model,
        should_think,
    )
    from web.embeddings import rag_retrieve
    from web.llm import get_manager

    start = time.time()
    history = []

    query = _request_query()
    if request.method == "POST":
        history = (request.get_json(silent=True) or {}).get("history") or []

    if not query or len(query) < 2:
        return jsonify({"error": "Query too short (min 2 characters)"}), 400

    # RAG retrieval
    limit = request.args.get("limit", 10, type=int)
    chunks = rag_retrieve(query, limit=min(limit, 20))

    # Model selection
    try:
        model = get_model()
    except RuntimeError:
        return jsonify({"error": "No AI model available. Check that your LLM provider is running."}), 503

    manager = get_manager()
    provider = manager.active
    use_thinking = should_think(query)
    context = format_rag_context(chunks)
    user_message = f"{context}\n\n## Question\n\n{query}"

    # Build messages
    messages = [{"role": "system", "content": SYSTEM_PROMPT}]
    MAX_HISTORY_TURNS = 6
    if history:
        for msg in history[-MAX_HISTORY_TURNS:]:
            role = msg.get("role", "")
            content = msg.get("content", "")
            if role in ("user", "assistant") and content:
                messages.append({"role": role, "content": content})
    messages.append({"role": "user", "content": user_message})

    # Collect full answer from streaming provider
    answer_parts = []
    thinking_start = None
    thinking_ms = 0

    for chunk in provider.chat_stream(model, messages, thinking=use_thinking):
        if chunk.type == "token":
            answer_parts.append(chunk.content)
        elif chunk.type == "thinking":
            if thinking_start is None:
                thinking_start = time.time()
        elif chunk.type == "thinking_done":
            if thinking_start is not None:
                thinking_ms = int((time.time() - thinking_start) * 1000)
                thinking_start = None
        elif chunk.type == "error":
            return jsonify({"error": "AI service unavailable. Please try again."}), 500
        elif chunk.type == "done":
            break

    answer = "".join(answer_parts)
    total_ms = int((time.time() - start) * 1000)

    # Build sources
    sources = []
    for i, c in enumerate(chunks, 1):
        sources.append({
            "num": i,
            "title": c.get("title", ""),
            "path": c.get("path", ""),
            "category": c.get("category", ""),
            "score": c.get("score", 0),
            "task_id": c.get("task_id", ""),
        })

    return jsonify({
        "query": query,
        "answer": answer,
        "model": model,
        "provider": manager.active_name,
        "sources": sources,
        "thinking_time_ms": thinking_ms,
        "total_time_ms": total_ms,
    })


@bp.route("/ask/stream", methods=["GET", "POST"])
def ask_stream():
    """RAG-assisted Q&A with Server-Sent Events streaming.

    Same parameters as /ask but returns SSE stream instead of JSON.
    Events: model, thinking, thinking_done, token, sources, done, error.
    """
    missing = _missing("llm", "ask", "embeddings")
    if missing:
        return _unavailable(missing)
    from web.ask import stream_answer
    from web.embeddings import rag_retrieve

    history = []
    query = _request_query()
    if request.method == "POST":
        history = (request.get_json(silent=True) or {}).get("history") or []

    if not query or len(query) < 2:
        def error_stream():
            yield sse_event("error", message="Query too short (min 2 characters)")
        return Response(error_stream(), mimetype="text/event-stream")

    chunks = rag_retrieve(query, limit=10)

    return Response(
        stream_answer(query, chunks, history=history),
        mimetype="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "X-Accel-Buffering": "no",
        },
    )


@bp.route("/search", methods=["GET", "POST"])
def search():
    """Search results as JSON.

    POST /api/v1/search with JSON {"query": "healing loop", "mode": "hybrid"} (preferred)
    GET  /api/v1/search?q=healing+loop&mode=hybrid&limit=20 (compatibility)

    Returns:
        {
            "query": "...",
            "mode": "...",
            "results": [...],
            "total": N,
            "stats": {...}
        }
    """
    missing = _missing("search")
    if missing:
        return _unavailable(missing)
    from web.search import search as bm25_search, index_stats

    query = _request_query()
    if request.method == "POST":
        params = request.get_json(silent=True) or request.form
    else:
        params = request.args
    mode = params.get("mode", "hybrid")
    try:
        limit = int(params.get("limit", 20))
    except (TypeError, ValueError):
        limit = 20

    if not query or len(query) < 2:
        return jsonify({"error": "Query too short (min 2 characters)"}), 400

    results = []
    degraded = {}
    if mode in ("semantic", "hybrid"):
        missing = _missing("embeddings")
        if missing:
            # T-4657: no vector stack — answer from the keyword index instead.
            degraded = {"degraded": True, "missing": missing, "requested_mode": mode}
            mode = "keyword"

    stats = index_stats()

    if mode == "semantic":
        from web.embeddings import search as vec_search, index_stats as vec_index_stats
        search_results = vec_search(query, limit=min(limit, 50))
        results = search_results.get("results", [])
        stats.update(vec_index_stats())
    elif mode == "hybrid":
        from web.embeddings import hybrid_search, index_stats as vec_index_stats
        search_results = hybrid_search(query, limit=min(limit, 50))
        results = search_results.get("results", [])
        stats.update(vec_index_stats())
    else:
        search_results = bm25_search(query)
        # Flatten categorized results
        for category, items in search_results.get("categories", {}).items():
            for item in items:
                item["category"] = category
                results.append(item)

    return jsonify({
        "query": query,
        "mode": mode,
        "results": results[:limit],
        "total": len(results),
        "stats": stats,
        **degraded,
    })


@bp.route("/health")
def health():
    """API health check. T-4657: 200 "degraded" naming what is not installed."""
    missing = _missing("llm", "embeddings", "search")
    if "llm" in missing:
        return jsonify({
            "status": "degraded",
            "missing": missing,
            "active_provider": None,
            "providers": [],
        })

    from web.llm import get_manager

    manager = get_manager()
    providers = manager.list_providers()

    body = {
        "status": "degraded" if missing else "ok",
        "active_provider": manager.active_name,
        "providers": providers,
    }
    if missing:
        body["missing"] = missing
    return jsonify(body)
