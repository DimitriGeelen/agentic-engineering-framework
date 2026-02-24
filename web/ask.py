"""LLM-assisted Q&A for Watchtower search.

Retrieves context via rag_retrieve() (T-255), formats as numbered Markdown,
streams answers via ollama with SSE. Includes model fallback logic (T-258).

T-256: Ask endpoint — /search/ask with ollama SSE streaming.
T-258: Model management — pre-load and fallback logic.
"""

import json
import logging

import ollama

log = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Model management (T-258)
# ---------------------------------------------------------------------------

PRIMARY_MODEL = "krith/qwen2.5-coder-32b-instruct:IQ2_M"
FALLBACK_MODEL = "dolphin-llama3:8b"

_available_models = None


def _list_models() -> list[str]:
    """Get list of locally available ollama model names."""
    try:
        resp = ollama.list()
        return [m.model for m in resp.models]
    except Exception as e:
        log.warning("Failed to list ollama models: %s", e)
        return []


def get_model() -> str:
    """Select the best available model with fallback.

    Returns model name string, or raises RuntimeError if no models available.
    """
    global _available_models
    if _available_models is None:
        _available_models = _list_models()

    if PRIMARY_MODEL in _available_models:
        return PRIMARY_MODEL
    if FALLBACK_MODEL in _available_models:
        log.info("Primary model unavailable, using fallback: %s", FALLBACK_MODEL)
        return FALLBACK_MODEL

    # Refresh cache and try once more
    _available_models = _list_models()
    if PRIMARY_MODEL in _available_models:
        return PRIMARY_MODEL
    if FALLBACK_MODEL in _available_models:
        return FALLBACK_MODEL

    raise RuntimeError("No suitable LLM model available in ollama")


# ---------------------------------------------------------------------------
# RAG context formatting
# ---------------------------------------------------------------------------

SYSTEM_PROMPT = """\
You are a knowledgeable assistant for the Agentic Engineering Framework project.

## Rules
1. Answer using ONLY the provided source documents. Never invent task IDs, file paths, \
command flags, or configuration options that do not appear in the sources.
2. Cite every claim with numbered references like [1], [2]. For multi-source claims use [1][3].
3. Distinguish between:
   - **Direct information**: explicitly stated in sources (cite directly)
   - **Inference**: logically follows from sources (say "Based on [N], ...")
   - **Gap**: not covered by sources (say "The sources don't cover this")
4. If the sources don't contain enough information, say "I don't have enough information to \
answer this fully" and suggest which topics or files might help.
5. Keep answers concise and actionable. Use markdown formatting with code blocks for commands.
6. For how-to questions, provide step-by-step instructions.
7. For why questions, explain the rationale and link to decisions if available."""


def format_rag_context(chunks: list[dict]) -> str:
    """Format retrieved chunks as numbered Markdown context for LLM."""
    parts = []
    for i, chunk in enumerate(chunks, 1):
        title = chunk.get("title", "Untitled")
        category = chunk.get("category", "")
        path = chunk.get("path", "")
        text = chunk.get("chunk_text", "")

        parts.append(
            f"--- SOURCE [{i}] ---\n"
            f"Title: {title}\n"
            f"Type: {category}\n"
            f"Path: {path}\n"
            f"\n{text}\n"
        )
    return "\n".join(parts)


# ---------------------------------------------------------------------------
# Streaming Q&A
# ---------------------------------------------------------------------------

def stream_answer(query: str, chunks: list[dict]):
    """Generator yielding SSE events for a RAG-assisted answer.

    Yields:
        SSE-formatted strings: "data: {...}\\n\\n"
        Events: {type: "token", content: "..."} for each token
                {type: "sources", sources: [...]} at the end
                {type: "done"} when complete
                {type: "error", message: "..."} on failure
    """
    try:
        model = get_model()
    except RuntimeError as e:
        yield f"data: {json.dumps({'type': 'error', 'message': str(e)})}\n\n"
        return

    context = format_rag_context(chunks)
    user_message = f"{context}\n\n## Question\n\n{query}"

    # Send model info
    yield f"data: {json.dumps({'type': 'model', 'model': model})}\n\n"

    try:
        response = ollama.chat(
            model=model,
            messages=[
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user", "content": user_message},
            ],
            stream=True,
        )

        for chunk in response:
            token = chunk.get("message", {}).get("content", "")
            if token:
                yield f"data: {json.dumps({'type': 'token', 'content': token})}\n\n"
            if chunk.get("done"):
                break

    except Exception as e:
        log.error("Ollama streaming error: %s", e)
        yield f"data: {json.dumps({'type': 'error', 'message': f'LLM error: {e}' })}\n\n"
        return

    # Send source metadata for the citation panel
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
    yield f"data: {json.dumps({'type': 'sources', 'sources': sources})}\n\n"
    yield f"data: {json.dumps({'type': 'done'})}\n\n"
