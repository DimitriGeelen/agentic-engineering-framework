"""Core blueprint — dashboard, project docs, directives."""

import os
import re as re_mod
import subprocess

import markdown2
import yaml
from flask import Blueprint, abort

from web.shared import FRAMEWORK_ROOT, PROJECT_ROOT, render_page, load_yaml as _load_yaml
from web.blueprints.cockpit import load_scan, get_cockpit_context

bp = Blueprint("core", __name__)


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

    # Concerns near trigger (T-398: migrated from gaps.yaml to concerns.yaml)
    concerns_path = PROJECT_ROOT / ".context" / "project" / "concerns.yaml"
    if not concerns_path.exists():
        concerns_path = PROJECT_ROOT / ".context" / "project" / "gaps.yaml"
    concerns_data = _load_yaml(concerns_path)
    for c in concerns_data.get("concerns", concerns_data.get("gaps", [])):
        if c.get("status") == "watching" and c.get("severity") in ("high", "medium"):
            items.append({
                "type": "gap",
                "id": c.get("id", ""),
                "message": c.get("title", "")[:50],
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


def _get_concerns_summary():
    """Summarize concerns register for dashboard (T-398)."""
    concerns_path = PROJECT_ROOT / ".context" / "project" / "concerns.yaml"
    if not concerns_path.exists():
        concerns_path = PROJECT_ROOT / ".context" / "project" / "gaps.yaml"
    data = _load_yaml(concerns_path)
    all_concerns = data.get("concerns", data.get("gaps", []))
    watching = [c for c in all_concerns if c.get("status") == "watching"]
    gaps = [c for c in watching if c.get("type", "gap") == "gap"]
    risks = [c for c in watching if c.get("type") == "risk"]
    high = [c for c in watching if c.get("severity") in ("high",) or c.get("ranking") in ("high", "urgent")]
    return {
        "total_watching": len(watching),
        "gaps": len(gaps),
        "risks": len(risks),
        "high": len(high),
    }


def _get_focus_task():
    """Get current focus task for dashboard (T-398)."""
    focus_path = PROJECT_ROOT / ".context" / "working" / "focus.yaml"
    if not focus_path.exists():
        return None
    data = _load_yaml(focus_path)
    task_id = data.get("current_task")
    if not task_id:
        return None
    # Find task file for name
    active_dir = PROJECT_ROOT / ".tasks" / "active"
    if active_dir.exists():
        for f in active_dir.glob(f"{task_id}-*.md"):
            content = f.read_text(errors="replace")
            fm_match = re_mod.match(r"^---\n(.*?)\n---", content, re_mod.DOTALL)
            if fm_match:
                try:
                    fm = yaml.safe_load(fm_match.group(1))
                    return {"id": task_id, "name": fm.get("name", "")[:50]}
                except yaml.YAMLError:
                    pass
    return {"id": task_id, "name": ""}


def _get_stale_tasks():
    """Count stale tasks: active with issues or >7d without update (T-398)."""
    import datetime
    stale = []
    active_dir = PROJECT_ROOT / ".tasks" / "active"
    if not active_dir.exists():
        return stale
    now = datetime.datetime.now(datetime.timezone.utc)
    for f in active_dir.glob("T-*.md"):
        content = f.read_text(errors="replace")
        fm_match = re_mod.match(r"^---\n(.*?)\n---", content, re_mod.DOTALL)
        if not fm_match:
            continue
        try:
            fm = yaml.safe_load(fm_match.group(1))
        except yaml.YAMLError:
            continue
        if not isinstance(fm, dict):
            continue
        status = fm.get("status", "")
        if status == "issues":
            stale.append({"id": fm.get("id", ""), "reason": "has issues"})
        elif status in ("started-work", "captured"):
            last = fm.get("last_update") or fm.get("created")
            if last:
                if isinstance(last, str):
                    try:
                        last = datetime.datetime.fromisoformat(last.replace("Z", "+00:00"))
                    except ValueError:
                        continue
                if hasattr(last, "tzinfo") and last.tzinfo is None:
                    last = last.replace(tzinfo=datetime.timezone.utc)
                if (now - last).days > 7:
                    stale.append({"id": fm.get("id", ""), "reason": f"no update in {(now - last).days}d"})
    return stale


def _get_pattern_summary():
    """Count patterns by type for the dashboard."""
    pf = _load_yaml(PROJECT_ROOT / ".context" / "project" / "patterns.yaml")
    return {
        "failure": len(pf.get("failure_patterns", [])),
        "success": len(pf.get("success_patterns", [])),
        "antifragile": len(pf.get("antifragile_patterns", [])),
        "workflow": len(pf.get("workflow_patterns", [])),
    }


@bp.route("/")
def index():
    active_dir = PROJECT_ROOT / ".tasks" / "active"
    completed_dir = PROJECT_ROOT / ".tasks" / "completed"
    active_count = len(list(active_dir.glob("T-*.md"))) if active_dir.exists() else 0
    completed_count = len(list(completed_dir.glob("T-*.md"))) if completed_dir.exists() else 0

    # Inception detection: no tasks at all
    is_inception = (active_count == 0 and completed_count == 0)

    if is_inception:
        return render_page(
            "index.html",
            page_title="Watchtower",
            is_inception=True,
            inception_checklist=_get_inception_checklist(),
        )

    # Try cockpit view (Phase 4 — scan-driven dashboard)
    scan_data = load_scan()
    if scan_data:
        ctx = get_cockpit_context(scan_data)
        ctx["recent_activity"] = _get_recent_activity()
        ctx["concerns_summary"] = _get_concerns_summary()
        ctx["focus_task"] = _get_focus_task()
        ctx["stale_tasks"] = _get_stale_tasks()
        return render_page("cockpit.html", page_title="Watchtower", **ctx)

    # Fallback: existing dashboard (no scan data)
    concerns_summary = _get_concerns_summary()

    handovers_dir = PROJECT_ROOT / ".context" / "handovers"
    last_session = "None"
    if handovers_dir.exists():
        sessions = sorted(handovers_dir.glob("S-*.md"), reverse=True)
        if sessions:
            last_session = sessions[0].stem

    audit_status, audit_pass, audit_warn, audit_fail = _get_audit_status()

    return render_page(
        "index.html",
        page_title="Watchtower",
        active_count=active_count,
        completed_count=completed_count,
        gap_count=concerns_summary["total_watching"],
        concerns_summary=concerns_summary,
        focus_task=_get_focus_task(),
        stale_tasks=_get_stale_tasks(),
        last_session=last_session,
        is_inception=False,
        audit_status=audit_status,
        audit_pass=audit_pass,
        audit_warn=audit_warn,
        audit_fail=audit_fail,
        attention_items=_get_attention_items(),
        recent_activity=_get_recent_activity(),
        knowledge_counts=_get_knowledge_counts(),
        traceability=_get_traceability(),
        inception_checklist=_get_inception_checklist(),
        pattern_summary=_get_pattern_summary(),
    )


@bp.route("/project")
def project():
    categories = {}
    skip = {".git", ".tasks", ".context", "node_modules", ".pytest_cache", ".playwright-mcp", "__pycache__"}

    def _add(cat, path, display_name=None):
        rel = path.relative_to(PROJECT_ROOT)
        doc_id = str(rel).replace("/", "--")
        for suffix in (".md", ".yaml", ".yml"):
            doc_id = doc_id.removesuffix(suffix)
        categories.setdefault(cat, []).append({
            "name": display_name or path.stem,
            "path": str(rel),
            "doc_id": doc_id,
        })

    # Governance: CLAUDE.md, FRAMEWORK.md, numbered specs (0*.md)
    for name in ("CLAUDE.md", "FRAMEWORK.md"):
        p = PROJECT_ROOT / name
        if p.exists():
            _add("Governance", p)
    for f in sorted(PROJECT_ROOT.glob("0*.md")):
        _add("Governance", f)

    # Design docs: docs/ and docs/plans/
    docs_dir = PROJECT_ROOT / "docs"
    if docs_dir.is_dir():
        for f in sorted(docs_dir.rglob("*.md")):
            if not any(part in skip for part in f.parts):
                _add("Design", f)

    # Agent docs: agents/*/AGENT.md
    agents_dir = PROJECT_ROOT / "agents"
    if agents_dir.is_dir():
        for f in sorted(agents_dir.glob("*/AGENT.md")):
            _add("Agents", f)

    # Project docs: remaining root .md files
    seen = {d["path"] for cat_docs in categories.values() for d in cat_docs}
    for f in sorted(PROJECT_ROOT.glob("*.md")):
        rel = str(f.relative_to(PROJECT_ROOT))
        if rel not in seen and f.stem != "zzz-default":
            _add("Project", f)

    # Commands: .claude/commands/*.md
    commands_dir = PROJECT_ROOT / ".claude" / "commands"
    if commands_dir.is_dir():
        for f in sorted(commands_dir.glob("*.md")):
            _add("Commands", f)

    # Research: recent episodic summaries (.context/episodic/T-*.yaml)
    episodic_dir = PROJECT_ROOT / ".context" / "episodic"
    if episodic_dir.is_dir():
        def _task_num(f):
            m = re_mod.search(r"T-(\d+)", f.stem)
            return int(m.group(1)) if m else 0
        episodics = sorted(episodic_dir.glob("T-*.yaml"), key=_task_num, reverse=True)
        for f in episodics[:25]:
            name = f.stem
            try:
                header = f.read_text(encoding="utf-8")[:800]
                m = re_mod.search(r'task_name:\s*"(.+?)"', header)
                if m:
                    name = f"{f.stem}: {m.group(1)[:60]}"
            except Exception:
                pass
            _add("Research", f, display_name=name)

    return render_page("project.html", page_title="Project Documentation", categories=categories)


@bp.route("/project/<doc>")
def project_doc(doc):
    if not re_mod.match(r"^[A-Za-z0-9_.-]+$", doc):
        abort(404)

    # Support -- as path separator for subdirectory docs
    rel_base = doc.replace("--", "/")
    doc_path = None
    for ext in (".md", ".yaml", ".yml"):
        candidate = PROJECT_ROOT / (rel_base + ext)
        if candidate.exists():
            doc_path = candidate
            break
    if doc_path is None:
        # Fallback: try direct .md match without -- expansion
        doc_path = PROJECT_ROOT / f"{doc}.md"
    if not doc_path.exists():
        abort(404)
    # Ensure path is within PROJECT_ROOT
    try:
        doc_path.resolve().relative_to(PROJECT_ROOT.resolve())
    except ValueError:
        abort(404)

    content_md = doc_path.read_text()
    if doc_path.suffix in (".yaml", ".yml"):
        content_md = f"```yaml\n{content_md}\n```"
    html_content = markdown2.markdown(
        content_md, extras=["tables", "fenced-code-blocks", "code-friendly"]
    )

    return render_page(
        "project_doc.html", page_title=doc_path.stem, doc_name=doc_path.stem, html_content=html_content
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
