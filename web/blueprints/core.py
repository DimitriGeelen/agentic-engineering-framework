"""Core blueprint — dashboard, project docs, directives."""

import re as re_mod

import markdown2
import yaml
from flask import Blueprint, abort

from web.shared import PROJECT_ROOT, render_page

bp = Blueprint("core", __name__)


@bp.route("/")
def index():
    active_dir = PROJECT_ROOT / ".tasks" / "active"
    completed_dir = PROJECT_ROOT / ".tasks" / "completed"
    active_count = len(list(active_dir.glob("T-*.md"))) if active_dir.exists() else 0
    completed_count = len(list(completed_dir.glob("T-*.md"))) if completed_dir.exists() else 0

    gaps_file = PROJECT_ROOT / ".context" / "project" / "gaps.yaml"
    gap_count = 0
    if gaps_file.exists():
        with open(gaps_file) as f:
            data = yaml.safe_load(f)
        if data:
            gap_count = len([g for g in data.get("gaps", []) if g.get("status") == "watching"])

    handovers_dir = PROJECT_ROOT / ".context" / "handovers"
    last_session = "Unknown"
    if handovers_dir.exists():
        sessions = sorted(handovers_dir.glob("S-*.md"), reverse=True)
        if sessions:
            last_session = sessions[0].stem

    return render_page(
        "index.html",
        page_title="Dashboard",
        active_count=active_count,
        completed_count=completed_count,
        gap_count=gap_count,
        last_session=last_session,
    )


@bp.route("/project")
def project():
    docs = []
    for f in sorted(PROJECT_ROOT.glob("0*.md")):
        docs.append({"name": f.stem, "filename": f.name})
    fw_md = PROJECT_ROOT / "FRAMEWORK.md"
    if fw_md.exists():
        docs.append({"name": "FRAMEWORK", "filename": "FRAMEWORK.md"})
    return render_page("project.html", page_title="Project Documentation", docs=docs)


@bp.route("/project/<doc>")
def project_doc(doc):
    if not re_mod.match(r"^[A-Za-z0-9_-]+$", doc):
        abort(404)

    candidates = [PROJECT_ROOT / f"{doc}.md", PROJECT_ROOT / f"{doc}"]
    doc_path = None
    for c in candidates:
        if c.exists() and c.suffix == ".md":
            doc_path = c
            break
    if not doc_path:
        abort(404)

    content_md = doc_path.read_text()
    html_content = markdown2.markdown(
        content_md, extras=["tables", "fenced-code-blocks", "code-friendly"]
    )

    return render_page(
        "project_doc.html", page_title=doc, doc_name=doc_path.stem, html_content=html_content
    )


@bp.route("/directives")
def directives():
    directives_file = PROJECT_ROOT / ".context" / "project" / "directives.yaml"
    directives_data = []
    if directives_file.exists():
        with open(directives_file) as f:
            data = yaml.safe_load(f)
        if data:
            directives_data = data.get("directives", [])

    practices_file = PROJECT_ROOT / ".context" / "project" / "practices.yaml"
    practices = []
    if practices_file.exists():
        with open(practices_file) as f:
            data = yaml.safe_load(f)
        if data:
            practices = data.get("practices", [])

    decisions_file = PROJECT_ROOT / ".context" / "project" / "decisions.yaml"
    decisions_list = []
    if decisions_file.exists():
        with open(decisions_file) as f:
            data = yaml.safe_load(f)
        if data:
            decisions_list = data.get("decisions", [])

    gaps_file = PROJECT_ROOT / ".context" / "project" / "gaps.yaml"
    gaps_list = []
    if gaps_file.exists():
        with open(gaps_file) as f:
            data = yaml.safe_load(f)
        if data:
            gaps_list = data.get("gaps", [])

    for d in directives_data:
        did = d["id"]
        d["practices"] = [
            p
            for p in practices
            if did
            in (
                p.get("derived_from", [])
                if isinstance(p.get("derived_from"), list)
                else [p.get("derived_from", "")]
            )
        ]
        d["decisions"] = [dec for dec in decisions_list if did in dec.get("directives_served", [])]
        d["gaps"] = [g for g in gaps_list if did in g.get("related_directives", [])]

    return render_page(
        "directives.html", page_title="Constitutional Directives", directives=directives_data
    )
