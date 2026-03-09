"""REST API blueprint — JSON endpoints for search and Q&A (T-382, T-384).

Endpoints:
    GET  /api/v1          — API index with endpoint documentation
    POST /api/v1/ask      — RAG-assisted Q&A (non-streaming JSON)
    POST /api/v1/ask/stream — RAG-assisted Q&A (SSE streaming)
    GET  /api/v1/search   — Search results as JSON
    GET  /api/v1/health   — API health check
"""

import json
import time

from flask import Blueprint, Response, jsonify, request

bp = Blueprint("api", __name__, url_prefix="/api/v1")


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


@bp.route("/ask", methods=["GET", "POST"])
def ask():
    """RAG-assisted Q&A returning complete JSON answer.

    GET:  /api/v1/ask?q=How does the audit system work?
    POST: /api/v1/ask with JSON {"query": "...", "history": [...]}

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

    if request.method == "POST":
        data = request.get_json(silent=True) or {}
        query = (data.get("query") or data.get("q") or "").strip()
        history = data.get("history") or []
    else:
        query = request.args.get("q", "").strip()

    if not query or len(query) < 2:
        return jsonify({"error": "Query too short (min 2 characters)"}), 400

    # RAG retrieval
    limit = request.args.get("limit", 10, type=int)
    chunks = rag_retrieve(query, limit=min(limit, 20))

    # Model selection
    try:
        model = get_model()
    except RuntimeError as e:
        return jsonify({"error": str(e)}), 503

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
            return jsonify({"error": chunk.content}), 500
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
    from web.ask import stream_answer
    from web.embeddings import rag_retrieve

    history = []
    if request.method == "POST":
        data = request.get_json(silent=True) or {}
        query = (data.get("query") or data.get("q") or "").strip()
        history = data.get("history") or []
    else:
        query = request.args.get("q", "").strip()

    if not query or len(query) < 2:
        def error_stream():
            yield 'data: {"type": "error", "message": "Query too short"}\n\n'
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


@bp.route("/search")
def search():
    """Search results as JSON.

    GET /api/v1/search?q=healing+loop&mode=hybrid&limit=20

    Returns:
        {
            "query": "...",
            "mode": "...",
            "results": [...],
            "total": N,
            "stats": {...}
        }
    """
    from web.search import search as bm25_search, index_stats

    query = request.args.get("q", "").strip()
    mode = request.args.get("mode", "hybrid")
    limit = request.args.get("limit", 20, type=int)

    if not query or len(query) < 2:
        return jsonify({"error": "Query too short (min 2 characters)"}), 400

    results = []
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
    })


@bp.route("/health")
def health():
    """API health check."""
    from web.llm import get_manager

    manager = get_manager()
    providers = manager.list_providers()

    return jsonify({
        "status": "ok",
        "active_provider": manager.active_name,
        "providers": providers,
    })
