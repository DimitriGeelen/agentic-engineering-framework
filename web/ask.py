"""LLM-assisted Q&A for Watchtower search.

Retrieves context via rag_retrieve() (T-255), formats as numbered Markdown,
streams answers via LLM provider with SSE. Includes model fallback logic (T-258).

T-256: Ask endpoint — /search/ask with ollama SSE streaming.
T-258: Model management — pre-load and fallback logic.
T-262: Replaced model with Qwen3-14B + thinking mode toggle.
T-377: Refactored to use LLM provider abstraction (Ollama + OpenRouter).
"""
from __future__ import annotations


import logging
import re

from web.config import Config
from web.llm import get_manager
from web.shared import sse_event

log = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Model management (T-258, T-262, T-273: config-driven, T-377: provider-aware)
# ---------------------------------------------------------------------------

PRIMARY_MODEL = Config.PRIMARY_MODEL
FALLBACK_MODEL = Config.FALLBACK_MODEL


def get_model() -> str:
    """Select the best available model with fallback.

    Returns model name string, or raises RuntimeError if no models available.
    """
    manager = get_manager()
    provider = manager.active
    models = provider.list_models()
    model_ids = [m.id for m in models]

    if PRIMARY_MODEL in model_ids:
        return PRIMARY_MODEL
    if FALLBACK_MODEL in model_ids:
        log.info("Primary model unavailable, using fallback: %s", FALLBACK_MODEL)
        return FALLBACK_MODEL

    # For OpenRouter, model names are like "anthropic/claude-3-haiku" — accept primary as-is
    if manager.active_name == "openrouter":
        return PRIMARY_MODEL

    raise RuntimeError(f"No suitable LLM model available ({manager.active_name})")


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
7. For why questions, explain the rationale and link to decisions if available.
8. End your response with a hidden HTML comment that cleanly rephrases the user's question \
in one sentence: <!-- Q: Clean rephrased question here -->. This is used for saving. \
Fix any typos, grammar issues, or voice-transcription errors in the original question."""


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

def stream_answer(query: str, chunks: list[dict], history: list[dict] | None = None,
                   model_override: str | None = None):
    """Generator yielding SSE events for a RAG-assisted answer.

    Args:
        query: The user's question.
        chunks: RAG-retrieved context chunks.
        history: Optional conversation history as list of {role, content} dicts.
                 Last 6 turns (3 exchanges) are used to stay within context window.
        model_override: Optional model name to use instead of the default (T-409).

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
        model = model_override if model_override else get_model()
    except RuntimeError as e:
        log.warning("Model selection failed: %s", e)
        yield sse_event("error", message="No AI model available. Check that your LLM provider is running.")
        return

    manager = get_manager()
    provider = manager.active
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

    # Send model info with thinking status and provider
    yield sse_event("model", model=model, thinking=use_thinking, provider=manager.active_name)

    # Stream via the active provider (T-377)
    for chunk in provider.chat_stream(model, messages, thinking=use_thinking):
        if chunk.type == "token":
            yield sse_event("token", content=chunk.content)
        elif chunk.type == "thinking":
            yield sse_event("thinking", content=chunk.content)
        elif chunk.type == "thinking_done":
            yield sse_event("thinking_done")
        elif chunk.type == "error":
            yield sse_event("error", message=chunk.content)
            return
        elif chunk.type == "done":
            break

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
    yield sse_event("sources", sources=sources)
    yield sse_event("done")
