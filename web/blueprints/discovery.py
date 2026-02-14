"""Discovery blueprint — decisions, learnings, gaps, search."""

import re as re_mod
import subprocess

import yaml
from flask import Blueprint, request

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
        with open(dec_file) as f:
            data = yaml.safe_load(f)
        if data:
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
        with open(lf) as f:
            data = yaml.safe_load(f)
        if data:
            learnings_list = data.get("learnings", [])

    patterns_grouped = {"failure": [], "success": [], "workflow": []}
    pf = PROJECT_ROOT / ".context" / "project" / "patterns.yaml"
    if pf.exists():
        with open(pf) as f:
            data = yaml.safe_load(f)
        if data:
            patterns_grouped["failure"] = data.get("failure_patterns", [])
            patterns_grouped["success"] = data.get("success_patterns", [])
            patterns_grouped["workflow"] = data.get("workflow_patterns", [])

    practices_list = []
    prf = PROJECT_ROOT / ".context" / "project" / "practices.yaml"
    if prf.exists():
        with open(prf) as f:
            data = yaml.safe_load(f)
        if data:
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
        with open(gf) as f:
            data = yaml.safe_load(f)
        if data:
            gaps_list = data.get("gaps", [])

    return render_page("gaps.html", page_title="Gaps", gaps=gaps_list)


@bp.route("/search")
def search():
    query = request.args.get("q", "").strip()
    results = {}

    if query and len(query) >= 2:
        safe_query = re_mod.sub(r"[^\w\s\-]", "", query)
        if safe_query:
            try:
                search_paths = [
                    str(PROJECT_ROOT / ".tasks"),
                    str(PROJECT_ROOT / ".context"),
                ]
                for spec in PROJECT_ROOT.glob("0*.md"):
                    search_paths.append(str(spec))

                result = subprocess.run(
                    ["grep", "-rn", "--include=*.yaml", "--include=*.md", "-i", "-l", safe_query]
                    + search_paths,
                    capture_output=True,
                    text=True,
                    timeout=10,
                )
                files = result.stdout.strip().split("\n") if result.stdout.strip() else []

                for fpath in files[:50]:
                    if ".tasks/" in fpath:
                        category = "Tasks"
                    elif ".context/episodic/" in fpath:
                        category = "Episodic Memory"
                    elif ".context/project/" in fpath:
                        category = "Project Memory"
                    elif ".context/handovers/" in fpath:
                        category = "Handovers"
                    else:
                        category = "Specifications"

                    if category not in results:
                        results[category] = []

                    matches = []
                    try:
                        line_result = subprocess.run(
                            ["grep", "-n", "-i", "-m", "3", safe_query, fpath],
                            capture_output=True,
                            text=True,
                            timeout=5,
                        )
                        if line_result.stdout.strip():
                            matches = line_result.stdout.strip().split("\n")[:3]
                    except Exception:
                        pass

                    results[category].append(
                        {
                            "path": fpath.replace(str(PROJECT_ROOT) + "/", ""),
                            "matches": matches,
                        }
                    )
            except Exception:
                pass

    return render_page("search.html", page_title="Search", query=query, results=results)
