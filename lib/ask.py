#!/usr/bin/env python3
"""fw ask — synchronous RAG+LLM wrapper for framework agents.

T-264: Keystone CLI integration. Enables programmatic Q&A access for
agents (healing, briefing, precedent mining) without requiring the
web server's streaming endpoint.

Usage:
    python3 lib/ask.py "How do I create a task?"
    python3 lib/ask.py --json "What is the healing loop?"
    python3 lib/ask.py --concise "List enforcement tiers"
"""
from __future__ import annotations

import argparse
import json
import os
import sys

# Add project root to path so web modules are importable
PROJECT_ROOT = os.environ.get("PROJECT_ROOT", os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, PROJECT_ROOT)

from web.embeddings import rag_retrieve, build_index
from web.ask import get_model, should_think, SYSTEM_PROMPT, format_rag_context

import ollama


CONCISE_ADDENDUM = "\n\nBe extremely concise — answer in 2-3 sentences maximum."

# ---------------------------------------------------------------------------
# litellm proxy routing (T-2417)
# ---------------------------------------------------------------------------
# Route the chat call through the local litellm proxy so `fw ask` inherits the
# proxy's ollama-primary + openrouter-fallback routing (.context/litellm-config.yaml).
# Falls back to a direct ollama.chat call when the proxy is unreachable, so
# `fw ask` never hard-depends on litellm being up. Disable entirely with
# FW_ASK_NO_PROXY=1 (restores the exact legacy direct-ollama behaviour).

DEFAULT_PROXY_URL = "http://localhost:4000/v1"
DEFAULT_MASTER_KEY = "sk-litellm-local-dev"
_LITELLM_CONFIG = os.path.join(PROJECT_ROOT, ".context", "litellm-config.yaml")


def _resolve_proxy() -> tuple[str, str] | None:
    """Return (base_url, api_key) for the litellm proxy, or None if disabled.

    Resolution: FW_ASK_NO_PROXY=1 → disabled. Base URL from FW_ASK_PROXY_URL
    else default. Key from LITELLM_MASTER_KEY env, else general_settings.master_key
    in the config file, else the default dev key.
    """
    if os.environ.get("FW_ASK_NO_PROXY") == "1":
        return None
    base = os.environ.get("FW_ASK_PROXY_URL", DEFAULT_PROXY_URL)
    key = os.environ.get("LITELLM_MASTER_KEY", "")
    if not key:
        try:
            import yaml
            with open(_LITELLM_CONFIG) as fh:
                cfg = yaml.safe_load(fh) or {}
            key = (cfg.get("general_settings") or {}).get("master_key") or ""
        except Exception:
            key = ""
    return base, (key or DEFAULT_MASTER_KEY)


def _chat_via_proxy(model: str, messages: list[dict], use_thinking: bool) -> tuple[str, str]:
    """Call the litellm proxy (OpenAI-compatible). Returns (content, thinking).

    Raises on any failure so the caller can fall back to direct ollama.
    """
    target = _resolve_proxy()
    if target is None:
        raise RuntimeError("proxy disabled (FW_ASK_NO_PROXY=1)")
    base, key = target
    from openai import OpenAI
    client = OpenAI(base_url=base, api_key=key)
    # `think` is ollama-specific; pass via extra_body (litellm drop_params drops it
    # cleanly if the backend doesn't support it — answer content is unaffected).
    resp = client.chat.completions.create(
        model=model,
        messages=messages,
        extra_body={"think": use_thinking},
    )
    msg = resp.choices[0].message
    content = msg.content or ""
    thinking = getattr(msg, "reasoning_content", None) or ""
    return content, thinking


def _chat_via_ollama(model: str, messages: list[dict], use_thinking: bool) -> tuple[str, str]:
    """Direct ollama.chat call (legacy path / proxy-down fallback)."""
    response = ollama.chat(model=model, messages=messages, think=use_thinking)
    content = response.message.content or ""
    thinking = getattr(response.message, "thinking", None) or ""
    return content, thinking


def ask(query: str, limit: int = 10, concise: bool = False, think: bool | None = None) -> dict:
    """Synchronous RAG+LLM query.

    Args:
        query: The question to answer.
        limit: Max chunks to retrieve.
        concise: If True, request brief answers.
        think: Override thinking mode. None = auto-detect.

    Returns:
        dict with keys: answer, model, sources, thinking_used
    """
    # Retrieve context
    chunks = rag_retrieve(query, limit=limit)

    # Format context
    context = format_rag_context(chunks)
    prompt = SYSTEM_PROMPT
    if concise:
        prompt += CONCISE_ADDENDUM

    user_message = f"{context}\n\n## Question\n\n{query}"

    # Determine thinking mode
    model = get_model()
    use_thinking = think if think is not None else should_think(query)

    messages = [
        {"role": "system", "content": prompt},
        {"role": "user", "content": user_message},
    ]

    # Proxy-primary (ollama→openrouter fallback via litellm), direct-ollama as
    # safety net when the proxy is down (T-2417). Fallback is non-silent.
    try:
        answer, thinking = _chat_via_proxy(model, messages, use_thinking)
    except Exception as exc:  # proxy unreachable / errored — degrade, don't break
        print(f"fw ask: litellm proxy unavailable ({type(exc).__name__}), "
              f"falling back to direct ollama", file=sys.stderr)
        answer, thinking = _chat_via_ollama(model, messages, use_thinking)

    # Build source list
    sources = []
    for i, c in enumerate(chunks, 1):
        sources.append({
            "num": i,
            "title": c.get("title", ""),
            "path": c.get("path", ""),
            "category": c.get("category", ""),
            "score": c.get("score", 0),
        })

    return {
        "answer": answer,
        "model": model,
        "thinking_used": use_thinking,
        "thinking": thinking,
        "sources": sources,
    }


def main():
    parser = argparse.ArgumentParser(description="Ask the framework knowledge base")
    parser.add_argument("query", help="Question to ask")
    parser.add_argument("--json", action="store_true", dest="json_output", help="Output as JSON")
    parser.add_argument("--concise", action="store_true", help="Request brief answers")
    parser.add_argument("--think", action="store_true", default=None, help="Force thinking mode")
    parser.add_argument("--no-think", action="store_true", help="Disable thinking mode")
    parser.add_argument("--limit", type=int, default=10, help="Max chunks to retrieve")
    args = parser.parse_args()

    think = None
    if args.think:
        think = True
    elif args.no_think:
        think = False

    result = ask(args.query, limit=args.limit, concise=args.concise, think=think)

    if args.json_output:
        print(json.dumps(result, indent=2))
    else:
        print(result["answer"])
        if result["sources"]:
            print(f"\n--- Sources ({len(result['sources'])} chunks) ---")
            for s in result["sources"][:5]:
                print(f"  [{s['num']}] {s['title']} ({s['path']})")


if __name__ == "__main__":
    main()
