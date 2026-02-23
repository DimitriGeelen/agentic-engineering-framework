"""Discovery blueprint — decisions, learnings, gaps, search, graduation."""

import os
import re as re_mod
import subprocess

import yaml
from flask import Blueprint, Response, request

from web.shared import PROJECT_ROOT, render_page

bp = Blueprint("discovery", __name__)


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

    dec_file = PROJECT_ROOT / ".context" / "project" / "decisions.yaml"
    if dec_file.exists():
        try:
            with open(dec_file) as f:
                data = yaml.safe_load(f)
        except yaml.YAMLError:
            data = None
        if isinstance(data, dict):
            for d in data.get("decisions", []):
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
    learnings_list = []
    lf = PROJECT_ROOT / ".context" / "project" / "learnings.yaml"
    if lf.exists():
        try:
            with open(lf) as f:
                data = yaml.safe_load(f)
        except yaml.YAMLError:
            data = None
        if isinstance(data, dict):
            learnings_list = data.get("learnings", [])

    patterns_grouped = {"failure": [], "success": [], "workflow": []}
    pf = PROJECT_ROOT / ".context" / "project" / "patterns.yaml"
    if pf.exists():
        try:
            with open(pf) as f:
                data = yaml.safe_load(f)
        except yaml.YAMLError:
            data = None
        if isinstance(data, dict):
            patterns_grouped["failure"] = data.get("failure_patterns", [])
            patterns_grouped["success"] = data.get("success_patterns", [])
            patterns_grouped["workflow"] = data.get("workflow_patterns", [])

    practices_list = []
    prf = PROJECT_ROOT / ".context" / "project" / "practices.yaml"
    if prf.exists():
        try:
            with open(prf) as f:
                data = yaml.safe_load(f)
        except yaml.YAMLError:
            data = None
        if isinstance(data, dict):
            practices_list = data.get("practices", [])

    return render_page(
        "learnings.html",
        page_title="Learnings",
        learnings=learnings_list,
        patterns=patterns_grouped,
        practices=practices_list,
    )


@bp.route("/gaps")
def gaps():
    gaps_list = []
    gf = PROJECT_ROOT / ".context" / "project" / "gaps.yaml"
    if gf.exists():
        try:
            with open(gf) as f:
                data = yaml.safe_load(f)
        except yaml.YAMLError:
            data = None
        if isinstance(data, dict):
            gaps_list = data.get("gaps", [])

    return render_page("gaps.html", page_title="Gaps", gaps=gaps_list)


@bp.route("/search")
def search_view():
    from web.search import search as bm25_search, index_stats

    query = request.args.get("q", "").strip()
    mode = request.args.get("mode", "keyword")
    results = {}
    stats = None
    vec_stats = None

    if query and len(query) >= 2:
        if mode == "semantic":
            from web.embeddings import search as vec_search, index_stats as vec_index_stats
            search_results = vec_search(query)
            # Convert flat results to categorized format for template
            for item in search_results.get("results", []):
                cat = item.get("category", "Other")
                if cat not in results:
                    results[cat] = []
                results[cat].append(item)
            vec_stats = vec_index_stats()
        elif mode == "hybrid":
            from web.embeddings import hybrid_search, index_stats as vec_index_stats
            search_results = hybrid_search(query)
            for item in search_results.get("results", []):
                cat = item.get("category", "Other")
                if cat not in results:
                    results[cat] = []
                results[cat].append(item)
            vec_stats = vec_index_stats()
        else:
            search_results = bm25_search(query)
            results = search_results.get("categories", {})
        stats = index_stats()

    return render_page(
        "search.html",
        page_title="Search",
        query=query,
        mode=mode,
        results=results,
        stats=stats,
        vec_stats=vec_stats,
    )


@bp.route("/search/ask")
def search_ask():
    """SSE streaming endpoint for LLM-assisted Q&A (T-256)."""
    from web.ask import stream_answer
    from web.embeddings import rag_retrieve

    query = request.args.get("q", "").strip()
    if not query or len(query) < 2:
        def error_stream():
            yield 'data: {"type": "error", "message": "Query too short"}\n\n'
        return Response(error_stream(), mimetype="text/event-stream")

    chunks = rag_retrieve(query, limit=10)

    return Response(
        stream_answer(query, chunks),
        mimetype="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "X-Accel-Buffering": "no",
        },
    )


@bp.route("/patterns")
def patterns():
    all_patterns = []
    pf = PROJECT_ROOT / ".context" / "project" / "patterns.yaml"
    if pf.exists():
        try:
            with open(pf) as f:
                data = yaml.safe_load(f)
        except yaml.YAMLError:
            data = None
        if isinstance(data, dict):
            for p in data.get("failure_patterns", []):
                p["_type"] = "failure"
                all_patterns.append(p)
            for p in data.get("success_patterns", []):
                p["_type"] = "success"
                all_patterns.append(p)
            for p in data.get("antifragile_patterns", []):
                p["_type"] = "antifragile"
                all_patterns.append(p)
            for p in data.get("workflow_patterns", []):
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
    learnings_list = []
    lf = PROJECT_ROOT / ".context" / "project" / "learnings.yaml"
    if lf.exists():
        try:
            with open(lf) as f:
                data = yaml.safe_load(f)
        except yaml.YAMLError:
            data = None
        if isinstance(data, dict):
            learnings_list = data.get("learnings", [])

    # Load practices
    practices_list = []
    prf = PROJECT_ROOT / ".context" / "project" / "practices.yaml"
    if prf.exists():
        try:
            with open(prf) as f:
                data = yaml.safe_load(f)
        except yaml.YAMLError:
            data = None
        if isinstance(data, dict):
            practices_list = data.get("practices", [])

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
