"""LLM-assisted Q&A for Watchtower search.

Retrieves context via rag_retrieve() (T-255), formats as numbered Markdown,
streams answers via ollama with SSE. Includes model fallback logic (T-258).

T-256: Ask endpoint — /search/ask with ollama SSE streaming.
T-258: Model management — pre-load and fallback logic.
T-262: Replaced model with Qwen3-14B + thinking mode toggle.
"""

import json
import logging
import re

import ollama

from web.config import Config

log = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Model management (T-258, T-262, T-273: config-driven)
# ---------------------------------------------------------------------------

PRIMARY_MODEL = Config.PRIMARY_MODEL
FALLBACK_MODEL = Config.FALLBACK_MODEL

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
# Query complexity classifier (T-262)
# ---------------------------------------------------------------------------

# Patterns that signal complex queries needing deep thinking
_COMPLEX_PATTERNS = [
    r"\bwhy\b",          # Reasoning questions
    r"\bhow (?:can|should|do|would)\b",  # Design/approach questions
    r"\bcompare\b",      # Comparison questions
    r"\bdesign\b",       # Architecture questions
    r"\bexplain\b",      # Explanation requests
    r"\bdifference\b",   # Contrast questions
    r"\btrade.?off\b",   # Analysis questions
    r"\bbest\b",         # Evaluation questions
    r"\brecommend\b",    # Advice questions
    r"\banalyz\b",       # Analysis requests
]
_COMPLEX_RE = re.compile("|".join(_COMPLEX_PATTERNS), re.IGNORECASE)


def should_think(query: str) -> bool:
    """Classify whether a query benefits from thinking mode.

    Simple lookups (what is X?, list Y, show Z) use fast mode.
    Complex reasoning (why, how should, compare, design) use thinking.
    """
    # Short queries are almost always simple lookups
    if len(query.split()) <= 4:
        return False
    return bool(_COMPLEX_RE.search(query))


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

def stream_answer(query: str, chunks: list[dict], history: list[dict] | None = None):
    """Generator yielding SSE events for a RAG-assisted answer.

    Args:
        query: The user's question.
        chunks: RAG-retrieved context chunks.
        history: Optional conversation history as list of {role, content} dicts.
                 Last 6 turns (3 exchanges) are used to stay within context window.

    Yields:
        SSE-formatted strings: "data: {...}\\n\\n"
        Events: {type: "model", model: "...", thinking: bool} model info
                {type: "thinking", content: "..."} thinking tokens (T-262)
                {type: "token", content: "..."} for each answer token
                {type: "sources", sources: [...]} at the end
                {type: "done"} when complete
                {type: "error", message: "..."} on failure
    """
    try:
        model = get_model()
    except RuntimeError as e:
        yield f"data: {json.dumps({'type': 'error', 'message': str(e)})}\n\n"
        return

    use_thinking = should_think(query) if model == PRIMARY_MODEL else False
    context = format_rag_context(chunks)
    user_message = f"{context}\n\n## Question\n\n{query}"

    # Build message list: system + history + current query (T-268)
    messages = [{"role": "system", "content": SYSTEM_PROMPT}]

    # Add conversation history (last 6 turns = 3 exchanges)
    MAX_HISTORY_TURNS = 6
    if history:
        for msg in history[-MAX_HISTORY_TURNS:]:
            role = msg.get("role", "")
            content = msg.get("content", "")
            if role in ("user", "assistant") and content:
                messages.append({"role": role, "content": content})

    messages.append({"role": "user", "content": user_message})

    # Send model info with thinking status
    yield f"data: {json.dumps({'type': 'model', 'model': model, 'thinking': use_thinking})}\n\n"

    try:
        response = ollama.chat(
            model=model,
            messages=messages,
            stream=True,
            think=use_thinking,
        )

        in_thinking = use_thinking
        for chunk in response:
            msg = chunk.get("message", {})
            # Thinking tokens come via the 'thinking' field (Qwen3/Ollama)
            thinking_token = msg.get("thinking", "")
            if thinking_token:
                yield f"data: {json.dumps({'type': 'thinking', 'content': thinking_token})}\n\n"
                continue

            # Answer tokens
            token = msg.get("content", "")
            if token:
                if in_thinking:
                    # First answer token after thinking phase
                    in_thinking = False
                    yield f"data: {json.dumps({'type': 'thinking_done'})}\n\n"
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
