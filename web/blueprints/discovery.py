"""Discovery blueprint — decisions, learnings, gaps, search, graduation."""

import json
import logging
import os
import re as re_mod
import subprocess
from datetime import datetime
from pathlib import Path

from flask import Blueprint, Response, request

from web.context_loader import load_concerns, load_decisions, load_learnings, load_patterns, load_practices
from web.shared import PROJECT_ROOT, render_page

log = logging.getLogger(__name__)
bp = Blueprint("discovery", __name__)


_index_build_thread = None


def _trigger_async_index_build():
    """Start background thread to build embedding index for next request."""
    import threading
    global _index_build_thread
    if _index_build_thread and _index_build_thread.is_alive():
        return  # Already building
    def _build():
        try:
            from web.embeddings import build_index
            log.info("Background index build started")
            build_index()
            log.info("Background index build completed")
        except Exception as e:
            log.warning("Background index build failed: %s", e)
    _index_build_thread = threading.Thread(target=_build, daemon=True)
    _index_build_thread.start()


@bp.route("/decisions")
def decisions():
    all_decisions = []

    design_file = PROJECT_ROOT / "005-DesignDirectives.md"
    if design_file.exists():
        content = design_file.read_text()
        for line in content.split("\n"):
            if line.startswith("|") and line.strip().startswith("| AD-"):
                cols = [c.strip() for c in line.split("|")[1:-1]]
                if len(cols) >= 4:
                    all_decisions.append(
                        {
                            "id": cols[0],
                            "type": "architectural",
                            "date": cols[1],
                            "decision": cols[2][:120],
                            "directives_served": cols[3],
                            "rationale": cols[4] if len(cols) > 4 else "",
                            "task": "",
                            "alternatives": [],
                        }
                    )

    for d in load_decisions():
        all_decisions.append(
            {
                "id": d.get("id", ""),
                "type": "operational",
                "date": str(d.get("date", "")),
                "decision": d.get("decision", "")[:120],
                "directives_served": ", ".join(d.get("directives_served", [])),
                "rationale": d.get("rationale", ""),
                "task": d.get("task", ""),
                "alternatives": d.get("alternatives_rejected", []),
            }
        )

    has_rationale = any(d.get("rationale") for d in all_decisions)
    return render_page(
        "decisions.html",
        page_title="Decisions",
        decisions=all_decisions,
        rationale_map=has_rationale,
    )


@bp.route("/learnings")
def learnings():
    learnings_list = load_learnings()

    pdata = load_patterns()
    patterns_grouped = {
        "failure": pdata.get("failure_patterns", []),
        "success": pdata.get("success_patterns", []),
        "workflow": pdata.get("workflow_patterns", []),
    }

    practices_list = load_practices()

    return render_page(
        "learnings.html",
        page_title="Learnings",
        learnings=learnings_list,
        patterns=patterns_grouped,
        practices=practices_list,
    )


@bp.route("/gaps")
def gaps():
    gaps_list = load_concerns()

    return render_page("gaps.html", page_title="Gaps", gaps=gaps_list)


@bp.route("/search")
def search_view():
    from web.search import search as bm25_search, index_stats

    query = request.args.get("q", "").strip()
    mode = request.args.get("mode", "hybrid")
    results = {}
    stats = None
    vec_stats = None

    if query and len(query) >= 2:
        vec_ready = False
        if mode in ("semantic", "hybrid"):
            # T-395: check if vector index is ready before attempting (avoids multi-minute hang)
            try:
                from web.embeddings import is_index_ready
                vec_ready = is_index_ready()
            except Exception:
                pass

        if mode in ("semantic", "hybrid") and vec_ready:
            try:
                if mode == "semantic":
                    from web.embeddings import search as vec_search, index_stats as vec_index_stats
                    search_results = vec_search(query)
                else:
                    from web.embeddings import hybrid_search, index_stats as vec_index_stats
                    search_results = hybrid_search(query)
                for item in search_results.get("results", []):
                    cat = item.get("category", "Other")
                    if cat not in results:
                        results[cat] = []
                    results[cat].append(item)
                vec_stats = vec_index_stats()
            except Exception as e:
                import logging
                logging.getLogger(__name__).warning("Vector search failed, falling back to keyword: %s", e)
                search_results = bm25_search(query)
                results = search_results.get("categories", {})
        else:
            search_results = bm25_search(query)
            results = search_results.get("categories", {})
        stats = index_stats()

    # Load saved Q&A answers for the sidebar (T-385)
    saved_answers = []
    qa_dir = PROJECT_ROOT / ".context" / "qa"
    if qa_dir.exists():
        for f in sorted(qa_dir.glob("*.md"), reverse=True)[:8]:
            try:
                content = f.read_text()
                title = content.split("\n")[0].lstrip("# ").strip()
                saved_answers.append({"title": title[:80], "file": f.name})
            except Exception:
                continue

    # Tag cloud for empty state (T-392)
    tag_cloud = []
    if not query:
        from web.search_utils import aggregate_tags
        tag_cloud = aggregate_tags(limit=24)

    is_chat = request.args.get("mode") == "ask"
    return render_page(
        "search.html",
        page_title="Search",
        query=query,
        mode=mode,
        is_chat=is_chat,
        results=results,
        stats=stats,
        vec_stats=vec_stats,
        saved_answers=saved_answers,
        tag_cloud=tag_cloud,
    )


@bp.route("/search/ask", methods=["GET", "POST"])
def search_ask():
    """SSE streaming endpoint for LLM-assisted Q&A (T-256, T-268, T-409).

    GET:  /search/ask?q=... (single-shot, backward compatible)
    POST: /search/ask with JSON {query, history, scope, model}

    T-409: Added scope (filter RAG context) and model (override default) params.
    """
    from web.ask import stream_answer
    from web.embeddings import rag_retrieve

    history = []
    scope = "all"
    model_override = None
    if request.method == "POST":
        data = request.get_json(silent=True) or {}
        query = (data.get("query") or data.get("q") or "").strip()
        history = data.get("history") or []
        scope = data.get("scope", "all")
        model_override = data.get("model") or None
    else:
        query = request.args.get("q", "").strip()

    if not query or len(query) < 2:
        def error_stream():
            yield 'data: {"type": "error", "message": "Query too short"}\n\n'
        return Response(error_stream(), mimetype="text/event-stream")

    # T-409: Stream progress events during RAG retrieval + LLM generation.
    # RAG retrieval is done INSIDE the generator so we can send SSE status
    # events while the user waits (not before Response creation).
    def _chat_stream():
        from web.ask import stream_answer
        from web.embeddings import rag_retrieve, _db, _db_built_at, DB_PATH, STALE_SECONDS
        import sqlite3
        import time

        # Phase 1: Check embedding index readiness
        # The index is ready if: in-memory DB has docs, OR on-disk DB has docs
        index_ready = False
        if _db is not None and (time.time() - _db_built_at) < STALE_SECONDS:
            index_ready = True
        elif DB_PATH.exists() and DB_PATH.stat().st_size > 4096:
            try:
                tmp = sqlite3.connect(str(DB_PATH))
                count = tmp.execute("SELECT COUNT(*) FROM documents").fetchone()[0]
                tmp.close()
                index_ready = count > 0
            except Exception:
                pass

        if not index_ready:
            yield f'data: {json.dumps({"type": "status", "phase": "index", "message": "Knowledge index is not built yet. Starting background build — please try again in ~60 seconds."})}\n\n'
            _trigger_async_index_build()
            yield f'data: {json.dumps({"type": "error", "message": "The embedding index is empty. A background build has been started — please try again in about 60 seconds."})}\n\n'
            return

        # Phase 2: RAG retrieval
        yield f'data: {json.dumps({"type": "status", "phase": "retrieval", "message": "Searching knowledge base..."})}\n\n'

        try:
            chunks = rag_retrieve(query, limit=10)
        except Exception as e:
            log.warning("RAG retrieve failed: %s", e)
            yield f'data: {json.dumps({"type": "error", "message": "Failed to retrieve context: " + str(e)[:100] + ". Try again in a moment."})}\n\n'
            return

        # Phase 3: Filter by scope
        if scope and scope != "all":
            scope_filters = {
                "tasks": ["Active Tasks", "Completed Tasks"],
                "docs": ["Research Reports", "Specifications", "Agent Docs"],
                "episodic": ["Episodic Memory"],
            }
            allowed = scope_filters.get(scope, [])
            if allowed:
                chunks = [c for c in chunks if c.get("category") in allowed]

        if not chunks:
            yield f'data: {json.dumps({"type": "error", "message": "No relevant context found for your question. Try broadening the scope or rephrasing."})}\n\n'
            return

        yield f'data: {json.dumps({"type": "status", "phase": "generating", "message": "Found " + str(len(chunks)) + " relevant sources — generating answer..."})}\n\n'

        # Phase 4: Stream LLM answer
        yield from stream_answer(query, chunks, history=history, model_override=model_override)

    return Response(
        _chat_stream(),
        mimetype="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "X-Accel-Buffering": "no",
        },
    )


@bp.route("/search/save", methods=["POST"])
def search_save():
    """Save a Q&A answer to .context/qa/ for the retrieval flywheel (T-265)."""
    data = request.get_json(silent=True) or {}
    question = (data.get("question") or "").strip()
    answer = (data.get("answer") or "").strip()
    sources = data.get("sources") or []
    inferred_title = (data.get("inferred_title") or "").strip()  # T-389

    if not question or not answer:
        return json.dumps({"error": "Question and answer are required"}), 400

    qa_dir = PROJECT_ROOT / ".context" / "qa"
    qa_dir.mkdir(parents=True, exist_ok=True)

    # Use inferred title for slug/heading if available, fall back to raw question (T-389)
    display_title = inferred_title if inferred_title else question
    slug = re_mod.sub(r"[^a-z0-9]+", "-", display_title.lower())[:60].strip("-")
    date_str = datetime.now().strftime("%Y-%m-%d")
    filename = f"{date_str}-{slug}.md"
    filepath = qa_dir / filename

    # Avoid overwriting — append counter if needed
    counter = 1
    while filepath.exists():
        counter += 1
        filename = f"{date_str}-{slug}-{counter}.md"
        filepath = qa_dir / filename

    # Format sources
    source_lines = []
    for s in sources:
        num = s.get("num", "")
        title = s.get("title", "")
        path = s.get("path", "")
        source_lines.append(f"- [{num}] {title} (`{path}`)")

    # T-389: Use clean inferred title as heading, preserve raw question as metadata
    content = (
        f"# {display_title}\n\n"
        f"**Date:** {date_str}\n"
        + (f"**Original query:** {question}\n\n" if inferred_title and inferred_title != question else "\n")
        + f"## Answer\n\n"
        f"{answer}\n\n"
        f"## Sources\n\n"
        + ("\n".join(source_lines) if source_lines else "No sources recorded.")
        + "\n"
    )

    filepath.write_text(content)
    rel_path = str(filepath.relative_to(PROJECT_ROOT))
    return json.dumps({"saved": True, "path": rel_path}), 200


@bp.route("/search/save-conversation", methods=["POST"])
def save_conversation():
    """Save a chat conversation as a curated artifact (T-409).

    Saves the final answer as the primary content, with full conversation
    thread as collapsible context. Stored in .context/qa/conversations/.
    """
    data = request.get_json(silent=True) or {}
    history = data.get("history") or []
    final_answer = (data.get("final_answer") or "").strip()
    final_question = (data.get("final_question") or "").strip()
    loaded_from = data.get("loaded_from")  # ID if continuing a saved conversation

    if not final_answer or not history:
        return json.dumps({"error": "No conversation to save"}), 400

    conv_dir = PROJECT_ROOT / ".context" / "qa" / "conversations"
    conv_dir.mkdir(parents=True, exist_ok=True)

    # Generate title from first question or final question
    first_question = ""
    for msg in history:
        if msg.get("role") == "user":
            first_question = msg["content"]
            break
    title = final_question or first_question or "Untitled conversation"
    slug = re_mod.sub(r"[^a-z0-9]+", "-", title.lower())[:60].strip("-")
    date_str = datetime.now().strftime("%Y-%m-%d")
    conv_id = f"{date_str}-{slug}"
    filepath = conv_dir / f"{conv_id}.json"

    # Avoid overwriting
    counter = 1
    while filepath.exists() and not loaded_from:
        counter += 1
        conv_id = f"{date_str}-{slug}-{counter}"
        filepath = conv_dir / f"{conv_id}.json"

    # If continuing a saved conversation, overwrite the original
    if loaded_from:
        orig = conv_dir / f"{loaded_from}.json"
        if orig.exists():
            filepath = orig
            conv_id = loaded_from

    # Save as JSON (structured for reload)
    conv_data = {
        "id": conv_id,
        "title": title[:120],
        "date": date_str,
        "turns": len(history) // 2,
        "final_question": final_question,
        "final_answer": final_answer,
        "history": history,
    }
    filepath.write_text(json.dumps(conv_data, indent=2))

    # Also save a human-readable Markdown version
    md_path = conv_dir / f"{conv_id}.md"
    md_lines = [
        f"# {title}\n",
        f"**Date:** {date_str}  ",
        f"**Turns:** {len(history) // 2}\n",
        "## Final Answer\n",
        f"{final_answer}\n",
        "## Conversation Thread\n",
    ]
    for msg in history:
        role = msg.get("role", "unknown")
        content = msg.get("content", "")
        if role == "user":
            md_lines.append(f"**You:** {content}\n")
        else:
            md_lines.append(f"**AI:** {content}\n")
    md_path.write_text("\n".join(md_lines))

    rel_path = str(filepath.relative_to(PROJECT_ROOT))
    return json.dumps({"saved": True, "path": rel_path, "id": conv_id}), 200


@bp.route("/search/conversations")
def list_conversations():
    """List saved conversations for the chat sidebar (T-409)."""
    conv_dir = PROJECT_ROOT / ".context" / "qa" / "conversations"
    conversations = []
    if conv_dir.exists():
        for f in sorted(conv_dir.glob("*.json"), reverse=True)[:20]:
            try:
                data = json.loads(f.read_text())
                conversations.append({
                    "id": data.get("id", f.stem),
                    "title": data.get("title", f.stem),
                    "date": data.get("date", ""),
                    "turns": data.get("turns", 0),
                })
            except Exception:
                continue
    return json.dumps({"conversations": conversations}), 200


@bp.route("/search/load-conversation")
def load_conversation():
    """Load a saved conversation for continuation (T-409)."""
    conv_id = request.args.get("id", "").strip()
    if not conv_id:
        return json.dumps({"error": "No conversation ID"}), 400

    conv_dir = PROJECT_ROOT / ".context" / "qa" / "conversations"
    filepath = conv_dir / f"{conv_id}.json"
    if not filepath.exists():
        return json.dumps({"error": "Conversation not found"}), 404

    try:
        data = json.loads(filepath.read_text())
        return json.dumps(data), 200
    except Exception as e:
        return json.dumps({"error": str(e)}), 500


@bp.route("/search/feedback", methods=["POST"])
def search_feedback():
    """Record thumbs up/down feedback on a Q&A answer (T-267)."""
    from web.qa_feedback import save_feedback

    data = request.get_json(silent=True) or {}
    query = (data.get("query") or "").strip()
    rating = data.get("rating")
    if not query or rating not in (-1, 1):
        return json.dumps({"error": "query and rating (-1 or 1) required"}), 400

    row_id = save_feedback(
        query=query,
        answer_preview=data.get("answer_preview", ""),
        model=data.get("model", ""),
        rating=rating,
        comment=data.get("comment", ""),
    )
    return json.dumps({"saved": True, "id": row_id}), 200


@bp.route("/search/feedback/analytics")
def feedback_analytics():
    """Simple analytics dashboard for Q&A feedback (T-267)."""
    from web.qa_feedback import get_analytics

    analytics = get_analytics()
    return render_page(
        "feedback_analytics.html",
        page_title="Q&A Feedback",
        analytics=analytics,
    )


@bp.route("/patterns")
def patterns():
    all_patterns = []
    pdata = load_patterns()
    for p in pdata.get("failure_patterns", []):
        p["_type"] = "failure"
        all_patterns.append(p)
    for p in pdata.get("success_patterns", []):
        p["_type"] = "success"
        all_patterns.append(p)
    for p in pdata.get("antifragile_patterns", []):
        p["_type"] = "antifragile"
        all_patterns.append(p)
    for p in pdata.get("workflow_patterns", []):
        p["_type"] = "workflow"
        all_patterns.append(p)

    type_filter = request.args.get("type", "").strip().lower()
    if type_filter and type_filter in ("failure", "success", "antifragile", "workflow"):
        filtered = [p for p in all_patterns if p["_type"] == type_filter]
    else:
        type_filter = ""
        filtered = all_patterns

    type_counts = {}
    for p in all_patterns:
        t = p["_type"]
        type_counts[t] = type_counts.get(t, 0) + 1

    return render_page(
        "patterns.html",
        page_title="Patterns",
        patterns=filtered,
        all_count=len(all_patterns),
        type_filter=type_filter,
        type_counts=type_counts,
    )


def _count_applications(learning_id):
    """Count how many distinct tasks/episodics reference this learning ID."""
    referenced = set()

    # Search episodics
    ep_dir = PROJECT_ROOT / ".context" / "episodic"
    if ep_dir.exists():
        for f in ep_dir.glob("T-*.yaml"):
            try:
                content = f.read_text()
                if learning_id in content:
                    referenced.add(f.stem)
            except Exception:
                continue

    # Search tasks
    for subdir in ["active", "completed"]:
        td = PROJECT_ROOT / ".tasks" / subdir
        if not td.exists():
            continue
        for f in td.glob("T-*.md"):
            try:
                content = f.read_text()
                if learning_id in content:
                    m = re_mod.match(r"(T-\d+)", f.name)
                    if m:
                        referenced.add(m.group(1))
            except Exception:
                continue

    # Search patterns
    pf = PROJECT_ROOT / ".context" / "project" / "patterns.yaml"
    extra = 0
    if pf.exists():
        try:
            if learning_id in pf.read_text():
                extra = 1
        except Exception:
            pass

    return len(referenced) + extra


@bp.route("/graduation")
def graduation():
    # Load learnings
    learnings_list = load_learnings()

    # Load practices
    practices_list = load_practices()

    # Build promoted set
    promoted_ids = set()
    for p in practices_list:
        origin = p.get("derived_from", "")
        if isinstance(origin, str) and origin.startswith("L-"):
            promoted_ids.add(origin)
        elif isinstance(origin, list):
            for o in origin:
                if str(o).startswith("L-"):
                    promoted_ids.add(str(o))
        if p.get("promoted_from"):
            promoted_ids.add(p["promoted_from"])

    # Compute application counts and status for each learning
    pipeline = []
    for l in learnings_list:
        lid = l.get("id", "")
        apps = _count_applications(lid)
        if lid in promoted_ids:
            status = "promoted"
        elif apps >= 3:
            status = "ready"
        elif apps >= 2:
            status = "almost"
        else:
            status = "building"
        pipeline.append({
            **l,
            "_apps": apps,
            "_status": status,
        })

    # Summary stats
    summary = {
        "total": len(learnings_list),
        "promoted": len([p for p in pipeline if p["_status"] == "promoted"]),
        "ready": len([p for p in pipeline if p["_status"] == "ready"]),
        "almost": len([p for p in pipeline if p["_status"] == "almost"]),
        "building": len([p for p in pipeline if p["_status"] == "building"]),
        "practices": len(practices_list),
    }

    status_filter = request.args.get("status", "").strip().lower()
    if status_filter and status_filter in ("promoted", "ready", "almost", "building"):
        pipeline = [p for p in pipeline if p["_status"] == status_filter]

    return render_page(
        "graduation.html",
        page_title="Graduation",
        pipeline=pipeline,
        practices=practices_list,
        summary=summary,
        status_filter=status_filter,
    )
