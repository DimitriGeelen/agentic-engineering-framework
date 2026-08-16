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

sys.path.insert(0, os.path.join(PROJECT_ROOT, "lib"))


CONCISE_ADDENDUM = "\n\nBe extremely concise — answer in 2-3 sentences maximum."

ASK_TASK_TYPE = "ask"
FALLBACK_TIMEOUT_S = 120


def _is_connection_error(exc: BaseException) -> bool:
    """True only when the local provider was UNREACHABLE.

    Deliberately narrow (see routing.fallback.trigger in ask.yaml). A model
    error or a mid-generation failure means Ollama IS running and something
    else is wrong — falling through to a paid cloud model there would convert a
    visible local fault into an invisible bill.

    Matched three ways because the ollama client has re-wrapped its transport
    errors across versions, and a fallback that silently stops triggering is
    indistinguishable from one that never needed to.
    """
    if isinstance(exc, (ConnectionError, TimeoutError)):
        return True
    for cls in type(exc).__mro__:
        name = cls.__name__
        if name in ("ConnectError", "ConnectTimeout", "ConnectionError"):
            return True
    text = str(exc).lower()
    return any(
        s in text
        for s in ("connection refused", "failed to connect", "connection error",
                  "max retries exceeded", "cannot connect")
    )


def _route() -> tuple:
    """Return (workflow, dispatch_id, task_id) — all None-safe.

    Telemetry is best-effort by contract: if the Resolver is unavailable or
    the capture fails, `fw ask` still answers. The alternative — an ask that
    dies because its logging died — trades a working feature for a metric.
    """
    try:
        import resolver  # lib/resolver.py
    except Exception:
        return None, None, None
    try:
        wf = resolver.load_workflow(ASK_TASK_TYPE)
    except Exception:
        return None, None, None
    return wf, None, (resolver._focused_task_id() or "ask-adhoc")


def _capture(wf: dict, task_id: str, prompt: str, model: str) -> str | None:
    try:
        import resolver
        envelope, row = resolver.capture_dispatch(
            task_id=task_id,
            workflow=dict(wf, model=model),
            rendered_prompt=prompt,
        )
        return row.get("dispatch_id")
    except Exception:
        return None


def _record(dispatch_id: str | None, task_id: str, outcome: dict) -> None:
    if not dispatch_id:
        return
    try:
        import outcome as outcome_mod
        outcome_mod.append_outcomes([dispatch_id], task_id, outcome)
    except Exception:
        pass


def select_route(wf: dict, fallback: bool = False) -> tuple:
    """Return (route_name, route_config) for this call.

    Named by ask.yaml. The routing key is hardcoded per the locked AC —
    default_route always, fallback_route only after a connection error. This is
    intentionally not a scored decision; scoring is Slice 2+ territory, and
    building it now would mean shipping an unmeasured heuristic under a gate
    that says "hardcoded".
    """
    wf = wf or {}
    key = "fallback_route" if fallback else "default_route"
    name = wf.get(key) or ("claude-via-litellm" if fallback else "ollama-local")
    return name, (wf.get("routes") or {}).get(name) or {}


def _cloud_fallback(wf: dict, prompt: str, user_message: str) -> tuple:
    """Ask claude-via-litellm over the OpenAI-compatible surface.

    Returns (answer, model, route_name). Raises on failure — the caller reports
    the ORIGINAL connection error alongside, because "local was down AND cloud
    failed" is a different operational story from either alone.
    """
    import httpx

    route_name, fb = select_route(wf, fallback=True)
    base_url = fb.get("base_url", "http://localhost:4000")
    model = fb.get("model", "claude-3-5-sonnet-hermes3")
    resp = httpx.post(
        f"{base_url.rstrip('/')}/v1/chat/completions",
        json={
            "model": model,
            "messages": [
                {"role": "system", "content": prompt},
                {"role": "user", "content": user_message},
            ],
        },
        timeout=FALLBACK_TIMEOUT_S,
    )
    resp.raise_for_status()
    data = resp.json()
    return data["choices"][0]["message"]["content"] or "", model, route_name


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
    use_thinking = think if think is not None else should_think(query)

    # T-1719 A3: route through the Resolver. The workflow decides the provider
    # pair; this function executes it and reports which one actually answered.
    wf, _, task_id = _route()

    try:
        model = get_model()
    except Exception as e:
        # get_model() probes Ollama for its loaded models, so it fails the same
        # way chat() would. Treat it as the same branch or the fallback is dead
        # code on exactly the host that needs it most.
        if not _is_connection_error(e):
            raise
        model = "unavailable"

    dispatch_id = _capture(wf, task_id, user_message, model) if wf else None

    route_name, _route_cfg = select_route(wf)
    provider = "ollama"
    thinking = ""
    try:
        if model == "unavailable":
            raise ConnectionError("ollama unreachable during model probe")
        response = ollama.chat(
            model=model,
            messages=[
                {"role": "system", "content": prompt},
                {"role": "user", "content": user_message},
            ],
            think=use_thinking,
        )
        answer = response.message.content or ""
        thinking = getattr(response.message, "thinking", None) or ""
        _record(dispatch_id, task_id, {
            "status": "ok", "provider": "ollama", "route": route_name,
            "model": model, "chunks": len(chunks), "fallback_used": False,
        })
    except Exception as primary_exc:
        if not _is_connection_error(primary_exc):
            _record(dispatch_id, task_id, {
                "status": "error", "provider": "ollama", "route": route_name,
                "model": model, "error": str(primary_exc)[:400],
                "fallback_used": False,
            })
            raise
        try:
            answer, model, route_name = _cloud_fallback(wf or {}, prompt, user_message)
            provider = "litellm"
            use_thinking = False
            _record(dispatch_id, task_id, {
                "status": "ok", "provider": "litellm", "route": route_name,
                "model": model, "chunks": len(chunks), "fallback_used": True,
                "primary_error": str(primary_exc)[:400],
            })
        except Exception as fallback_exc:
            _record(dispatch_id, task_id, {
                "status": "error", "provider": "litellm", "route": route_name,
                "model": model, "error": str(fallback_exc)[:400],
                "fallback_used": True, "primary_error": str(primary_exc)[:400],
            })
            raise RuntimeError(
                f"ask failed on both providers — ollama: {primary_exc}; "
                f"litellm fallback: {fallback_exc}"
            ) from fallback_exc

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
        "provider": provider,
        "route": route_name,
        "dispatch_id": dispatch_id,
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
