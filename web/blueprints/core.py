"""Core blueprint — dashboard, project docs, directives."""

import os
import re as re_mod
import subprocess

import markdown2
import yaml
from flask import Blueprint, abort

from web.shared import FRAMEWORK_ROOT, PROJECT_ROOT, render_page

bp = Blueprint("core", __name__)


def _load_yaml(path):
    """Safely load a YAML file, return empty dict on failure."""
    if not path.exists():
        return {}
    try:
        with open(path) as f:
            data = yaml.safe_load(f)
        return data if isinstance(data, dict) else {}
    except Exception:
        return {}


def _get_attention_items():
    """Build the 'needs attention' list for the dashboard."""
    items = []

    # Active tasks with no recent update
    active_dir = PROJECT_ROOT / ".tasks" / "active"
    if active_dir.exists():
        for f in active_dir.glob("T-*.md"):
            content = f.read_text(errors="replace")
            fm_match = re_mod.match(r"^---\n(.*?)\n---", content, re_mod.DOTALL)
            if fm_match:
                try:
                    fm = yaml.safe_load(fm_match.group(1))
                except yaml.YAMLError:
                    continue
                if isinstance(fm, dict):
                    tid = fm.get("id", f.stem[:5])
                    status = fm.get("status", "")
                    name = fm.get("name", "")[:40]
                    if status == "issues":
                        items.append({"type": "task", "id": tid, "message": f"{name} — has issues"})
                    else:
                        items.append({"type": "task", "id": tid, "message": f"{name} — {status}"})

    # Gaps near trigger
    gaps_data = _load_yaml(PROJECT_ROOT / ".context" / "project" / "gaps.yaml")
    for g in gaps_data.get("gaps", []):
        if g.get("status") == "watching" and g.get("severity") in ("high", "medium"):
            items.append({
                "type": "gap",
                "id": g.get("id", ""),
                "message": g.get("title", "")[:50],
            })

    return items


def _get_recent_activity():
    """Build recent activity from handovers."""
    activity = []
    handovers_dir = PROJECT_ROOT / ".context" / "handovers"
    if handovers_dir.exists():
        for f in sorted(handovers_dir.glob("S-*.md"), reverse=True)[:3]:
            content = f.read_text(errors="replace")
            fm_match = re_mod.match(r"^---\n(.*?)\n---", content, re_mod.DOTALL)
            if fm_match:
                try:
                    fm = yaml.safe_load(fm_match.group(1))
                except yaml.YAMLError:
                    continue
                if isinstance(fm, dict):
                    sid = fm.get("session_id", f.stem)
                    touched = fm.get("tasks_touched", [])
                    completed = fm.get("tasks_completed", [])
                    parts = []
                    if completed:
                        parts.append(f"{len(completed)} completed")
                    if touched:
                        parts.append(f"{len(touched)} touched")
                    detail = ", ".join(parts) if parts else "session recorded"
                    activity.append({"label": sid, "detail": detail})
    return activity


def _get_knowledge_counts():
    """Count learnings, practices, and decisions."""
    counts = {"learnings": 0, "practices": 0, "decisions": 0}

    lf = _load_yaml(PROJECT_ROOT / ".context" / "project" / "learnings.yaml")
    counts["learnings"] = len(lf.get("learnings", []))

    pf = _load_yaml(PROJECT_ROOT / ".context" / "project" / "practices.yaml")
    counts["practices"] = len(pf.get("practices", []))

    df = _load_yaml(PROJECT_ROOT / ".context" / "project" / "decisions.yaml")
    counts["decisions"] = len(df.get("decisions", []))

    return counts


def _get_traceability():
    """Get git traceability percentage."""
    try:
        result = subprocess.run(
            ["git", "-C", str(PROJECT_ROOT), "log", "--oneline", "--all"],
            capture_output=True, text=True, timeout=10,
        )
        if result.returncode == 0 and result.stdout.strip():
            lines = result.stdout.strip().split("\n")
            total = len(lines)
            traced = sum(1 for l in lines if re_mod.search(r"T-\d{3}", l))
            return int(traced * 100 / total) if total > 0 else 0
    except Exception:
        pass
    return 0


def _get_audit_status():
    """Get latest audit status."""
    audits_dir = PROJECT_ROOT / ".context" / "audits"
    if not audits_dir.exists():
        return "UNKNOWN", 0, 0, 0
    audit_files = sorted(audits_dir.glob("*.yaml"), reverse=True)
    if not audit_files:
        return "UNKNOWN", 0, 0, 0
    data = _load_yaml(audit_files[0])
    s = data.get("summary", {})
    p, w, f = s.get("pass", 0), s.get("warn", 0), s.get("fail", 0)
    if f > 0:
        return "FAIL", p, w, f
    elif w > 0:
        return "WARN", p, w, f
    return "PASS", p, w, f


def _get_inception_checklist():
    """Build inception checklist for new projects."""
    checklist = []

    # Framework config
    has_config = (PROJECT_ROOT / ".framework.yaml").exists()
    checklist.append({"label": "Framework config", "done": has_config, "action_url": None, "action_label": None})

    # Git hooks
    has_hooks = (PROJECT_ROOT / ".git" / "hooks" / "commit-msg").exists()
    checklist.append({"label": "Git hooks installed", "done": has_hooks, "action_url": None, "action_label": None})

    # First task
    active_dir = PROJECT_ROOT / ".tasks" / "active"
    completed_dir = PROJECT_ROOT / ".tasks" / "completed"
    has_tasks = False
    if active_dir.exists():
        has_tasks = len(list(active_dir.glob("T-*.md"))) > 0
    if not has_tasks and completed_dir.exists():
        has_tasks = len(list(completed_dir.glob("T-*.md"))) > 0
    checklist.append({"label": "First task created", "done": has_tasks, "action_url": "/tasks/new", "action_label": "Create Task"})

    # Session initialized
    working_dir = PROJECT_ROOT / ".context" / "working"
    has_session = working_dir.exists() and any(working_dir.glob("*.yaml"))
    checklist.append({"label": "Session initialized", "done": has_session, "action_url": None, "action_label": None})

    # First handover
    handovers_dir = PROJECT_ROOT / ".context" / "handovers"
    has_handover = handovers_dir.exists() and len(list(handovers_dir.glob("S-*.md"))) > 0
    checklist.append({"label": "First handover", "done": has_handover, "action_url": None, "action_label": None})

    return checklist


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
    last_session = "None"
    if handovers_dir.exists():
        sessions = sorted(handovers_dir.glob("S-*.md"), reverse=True)
        if sessions:
            last_session = sessions[0].stem

    # Inception detection: no tasks at all
    is_inception = (active_count == 0 and completed_count == 0)

    # Audit status
    audit_status, audit_pass, audit_warn, audit_fail = _get_audit_status()

    return render_page(
        "index.html",
        page_title="Watchtower",
        active_count=active_count,
        completed_count=completed_count,
        gap_count=gap_count,
        last_session=last_session,
        is_inception=is_inception,
        audit_status=audit_status,
        audit_pass=audit_pass,
        audit_warn=audit_warn,
        audit_fail=audit_fail,
        attention_items=_get_attention_items(),
        recent_activity=_get_recent_activity(),
        knowledge_counts=_get_knowledge_counts(),
        traceability=_get_traceability(),
        inception_checklist=_get_inception_checklist(),
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
