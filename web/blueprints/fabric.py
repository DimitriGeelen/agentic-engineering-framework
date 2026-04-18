"""Watchtower – Component Fabric browser."""

import glob
import logging
import os

import yaml
from flask import Blueprint, request

from web.shared import PROJECT_ROOT, render_page

logger = logging.getLogger(__name__)

bp = Blueprint("fabric", __name__)

# In consumer projects, PROJECT_ROOT is .agentic-framework/ — fabric data lives at the parent.
# In the framework repo itself, PROJECT_ROOT is the actual root.
if os.path.basename(os.path.normpath(PROJECT_ROOT)) == ".agentic-framework":
    ACTUAL_PROJECT_ROOT = os.path.dirname(os.path.normpath(PROJECT_ROOT))
else:
    ACTUAL_PROJECT_ROOT = PROJECT_ROOT

FABRIC_DIR = os.path.join(ACTUAL_PROJECT_ROOT, ".fabric")
COMP_DIR = os.path.join(FABRIC_DIR, "components")

# mtime-based cache for component loading
_comp_cache = {"mtime": 0, "data": []}


def _load_components():
    """Load all component cards (cached by directory mtime)."""
    try:
        dir_mtime = os.stat(COMP_DIR).st_mtime
    except OSError:
        return []
    if dir_mtime == _comp_cache["mtime"] and _comp_cache["data"]:
        return _comp_cache["data"]
    components = []
    for path in sorted(glob.glob(os.path.join(COMP_DIR, "*.yaml"))):
        try:
            with open(path) as f:
                data = yaml.safe_load(f)
            if data:
                data["_card_file"] = os.path.basename(path)
                components.append(data)
        except Exception:
            pass
    _comp_cache["mtime"] = dir_mtime
    _comp_cache["data"] = components
    return components


def _load_subsystems():
    """Load subsystem registry.

    Supports both list-of-dicts ([{id, name, ...}]) and dict-of-dicts
    ({id: {name, ...}}) formats in subsystems.yaml.
    """
    path = os.path.join(FABRIC_DIR, "subsystems.yaml")
    if not os.path.exists(path):
        return []
    try:
        with open(path) as f:
            data = yaml.safe_load(f)
    except Exception as e:
        logger.warning("Failed to parse %s: %s", path, e)
        return []
    if not isinstance(data, dict):
        return []
    raw = data.get("subsystems", [])
    if isinstance(raw, dict):
        return [{"id": k, **v} for k, v in raw.items() if isinstance(v, dict)]
    if isinstance(raw, list):
        # Normalize: fill `id` from `name` when missing so downstream callers
        # can rely on the docstring's promised shape `[{id, name, ...}]`.
        return [
            {**s, "id": s.get("id") or s.get("name")}
            for s in raw
            if isinstance(s, dict) and (s.get("id") or s.get("name"))
        ]
    return []



@bp.route("/fabric")
def fabric_overview():
    """Main fabric page — subsystem overview + component list."""
    components = _load_components()
    subsystems = _load_subsystems()

    # Stats — derive counts from actual component cards
    type_counts = {}
    subsystem_counts = {}
    for c in components:
        t = c.get("type", "unknown")
        s = c.get("subsystem", "unknown")
        type_counts[t] = type_counts.get(t, 0) + 1
        subsystem_counts[s] = subsystem_counts.get(s, 0) + 1

    # Ensure every subsystem in component cards has a tile
    registered_ids = {s["id"] for s in subsystems}
    for sid in sorted(subsystem_counts):
        if sid not in registered_ids:
            subsystems.append({
                "id": sid,
                "name": sid.replace("-", " ").title(),
                "purpose": f"Auto-discovered subsystem ({subsystem_counts[sid]} components)",
                "summary": "",
            })

    edge_count = sum(
        len(c.get("depends_on", []))
        for c in components
    )

    # Filter by subsystem if requested
    filter_subsystem = request.args.get("subsystem", "")
    filter_type = request.args.get("type", "")
    search = request.args.get("q", "")

    filtered = components
    if filter_subsystem:
        filtered = [c for c in filtered if c.get("subsystem") == filter_subsystem]
    if filter_type:
        filtered = [c for c in filtered if c.get("type") == filter_type]
    if search:
        q = search.lower()
        filtered = [
            c for c in filtered
            if q in c.get("name", "").lower()
            or q in c.get("purpose", "").lower()
            or q in str(c.get("tags", [])).lower()
            or q in c.get("location", "").lower()
        ]

    return render_page(
        "fabric.html",
        page_title="Component Fabric",
        components=filtered,
        all_components=components,
        subsystems=subsystems,
        type_counts=type_counts,
        subsystem_counts=subsystem_counts,
        total_components=len(components),
        total_edges=edge_count,
        filter_subsystem=filter_subsystem,
        filter_type=filter_type,
        search=search,
    )


@bp.route("/fabric/component/<name>")
def component_detail(name):
    """Component detail view."""
    components = _load_components()
    component = None
    for c in components:
        if c.get("name") == name or c.get("_card_file", "").replace(".yaml", "") == name:
            component = c
            break

    if not component:
        return render_page("fabric_detail.html", page_title="Not Found", component=None)

    # Find reverse dependencies (what depends on this component)
    cid = component.get("id", "")
    cname = component.get("name", "")
    cloc = component.get("location", "")
    reverse_deps = []
    for c in components:
        if c.get("name") == cname:
            continue
        for dep in c.get("depends_on", []):
            if not isinstance(dep, dict):
                continue
            target = dep.get("target", "")
            if target in (cid, cname, cloc):
                reverse_deps.append({
                    "name": c.get("name", "?"),
                    "type": dep.get("type", "uses"),
                    "location": dep.get("location", ""),
                })

    # Read source file for inline display
    source_code = None
    source_lang = "plaintext"
    source_lines = 0
    source_size = ""
    location = component.get("location", "")
    if location:
        source_path = os.path.join(ACTUAL_PROJECT_ROOT, location)
        real_source = os.path.realpath(source_path)
        real_root = os.path.realpath(ACTUAL_PROJECT_ROOT)
        if real_source.startswith(real_root + os.sep) and os.path.isfile(real_source):
            ext_map = {
                ".py": "python", ".sh": "bash", ".bash": "bash",
                ".html": "html", ".jinja": "html", ".jinja2": "html",
                ".yaml": "yaml", ".yml": "yaml",
                ".js": "javascript", ".ts": "typescript",
                ".md": "markdown", ".json": "json",
                ".css": "css", ".toml": "toml",
            }
            _, ext = os.path.splitext(real_source)
            source_lang = ext_map.get(ext.lower(), "")
            if not source_lang:
                # Detect from shebang for extensionless files
                try:
                    with open(real_source) as f:
                        first_line = f.readline()
                    if first_line.startswith("#!") and ("bash" in first_line or "sh" in first_line):
                        source_lang = "bash"
                    elif first_line.startswith("#!") and "python" in first_line:
                        source_lang = "python"
                    else:
                        source_lang = "plaintext"
                except Exception:
                    source_lang = "plaintext"
            try:
                size_bytes = os.path.getsize(real_source)
                if size_bytes < 1024:
                    source_size = f"{size_bytes} B"
                else:
                    source_size = f"{size_bytes / 1024:.1f} KB"
                with open(real_source) as f:
                    lines = f.readlines()
                source_lines = len(lines)
                if source_lines > 2000:
                    lines = lines[:2000]
                    lines.append(f"\n# ... truncated at 2000 lines (file has {source_lines} lines) ...\n")
                source_code = "".join(lines)
            except Exception:
                pass

    # Build ID-to-name mapping for resolving C-XXX and path references in deps
    id_to_name = {}
    for c in components:
        ci = c.get("id", c.get("name", ""))
        cn = c.get("name", ci)
        cl = c.get("location", "")
        id_to_name[ci] = cn
        id_to_name[cn] = cn
        if cl:
            id_to_name[cl] = cn

    return render_page(
        "fabric_detail.html",
        page_title=f"Component: {component.get('name', '?')}",
        component=component,
        reverse_deps=reverse_deps,
        id_to_name=id_to_name,
        source_code=source_code,
        source_lang=source_lang,
        source_lines=source_lines,
        source_size=source_size,
    )


@bp.route("/fabric/graph")
def fabric_graph():
    """Interactive D3 fabric explorer."""
    all_components = _load_components()

    # Build component list + subsystem lookup
    components = []
    comp_to_sub = {}
    for c in all_components:
        comp_id = c.get("id", c.get("name", ""))
        sub = c.get("subsystem", "unknown")
        comp_to_sub[comp_id] = sub
        components.append({
            "id": comp_id,
            "name": c.get("name", c.get("id", "")),
            "type": c.get("type", "unknown"),
            "subsystem": sub,
            "location": c.get("location", ""),
            "purpose": c.get("purpose", ""),
            "depends_on": c.get("depends_on", []),
            "depended_by": c.get("depended_by", []),
            "tags": c.get("tags", []),
        })

    # Build subsystem data from actual component cards (T-853)
    subsystem_data = {}
    subsystem_purposes = {}  # collect purposes for description
    for c in all_components:
        sub = c.get("subsystem", "unknown")
        if sub not in subsystem_data:
            subsystem_data[sub] = {
                "name": sub.replace("-", " ").title(),
                "count": 0,
                "desc": "",
            }
            subsystem_purposes[sub] = []
        subsystem_data[sub]["count"] += 1
        purpose = c.get("purpose", "")
        if purpose and len(purpose) > 10:
            subsystem_purposes[sub].append(purpose)
    # Generate descriptions from component purposes
    for sub_id, info in subsystem_data.items():
        purposes = subsystem_purposes.get(sub_id, [])
        if purposes:
            # Use the shortest distinct purpose as description, append count
            purposes.sort(key=len)
            desc = purposes[0]
            if len(desc) > 80:
                desc = desc[:77] + "..."
            info["desc"] = f"{desc} ({info['count']} components)"
        else:
            info["desc"] = f"{info['count']} components"

    # Inter-subsystem edges from component dependencies
    edge_set = set()
    for c in all_components:
        src_sub = c.get("subsystem", "unknown")
        for dep in c.get("depends_on", []):
            target_id = dep.get("target", "") if isinstance(dep, dict) else dep
            tgt_sub = comp_to_sub.get(target_id)
            if tgt_sub and src_sub != tgt_sub:
                edge_set.add((src_sub, tgt_sub))
    subsystem_edges = sorted(edge_set)

    # Assign layers — group subsystems by prefix, assign palette colors
    palette = [
        "#6366f1", "#06b6d4", "#8b5cf6", "#10b981",
        "#f59e0b", "#64748b", "#ec4899", "#f97316",
    ]
    groups = {}
    for sub_id in sorted(subsystem_data.keys()):
        prefix = sub_id.split("-")[0]
        groups.setdefault(prefix, []).append(sub_id)
    # Merge single-member groups into "Other" if >8 groups
    if len(groups) > 8:
        merged = {}
        other = []
        for prefix, subs in sorted(groups.items(), key=lambda x: -len(x[1])):
            if len(subs) > 1 or len(merged) < 6:
                merged[prefix.title()] = subs
            else:
                other.extend(subs)
        if other:
            merged["Other"] = other
        groups = merged
    else:
        groups = {k.title(): v for k, v in groups.items()}
    explorer_layers = {}
    for i, (layer_name, subs) in enumerate(sorted(groups.items())):
        explorer_layers[layer_name] = {
            "color": palette[i % len(palette)],
            "subsystems": subs,
        }

    # Match reports to subsystems
    subsystem_reports = {}
    reports_dir = os.path.join(ACTUAL_PROJECT_ROOT, "docs", "reports")
    if os.path.isdir(reports_dir):
        for rpt in sorted(os.listdir(reports_dir)):
            if not rpt.endswith(".md"):
                continue
            rpt_norm = rpt.lower().replace("-", "")
            for sub_id in subsystem_data:
                if sub_id.lower().replace("-", "") in rpt_norm:
                    subsystem_reports.setdefault(sub_id, []).append(rpt)

    # Stats
    total_dep_edges = sum(len(c.get("depends_on", [])) for c in all_components)
    report_count = 0
    if os.path.isdir(reports_dir):
        report_count = len([f for f in os.listdir(reports_dir) if f.endswith(".md")])

    return render_page(
        "fabric_explorer.html",
        page_title="Fabric Explorer",
        components=components,
        subsystem_data=subsystem_data,
        subsystem_edges=subsystem_edges,
        layers=explorer_layers,
        subsystem_reports=subsystem_reports,
        total_components=len(components),
        total_subsystems=len(subsystem_data),
        total_layers=len(explorer_layers),
        total_dep_edges=total_dep_edges,
        total_reports=report_count,
    )


@bp.route("/api/fabric/report/<path:filename>")
def fabric_report(filename):
    """Serve report markdown content for the inline viewer."""
    # Sanitize: only allow filenames within docs/reports/
    safe_name = os.path.basename(filename)
    if not safe_name.endswith(".md"):
        return "Not found", 404
    report_path = os.path.join(ACTUAL_PROJECT_ROOT, "docs", "reports", safe_name)
    if not os.path.isfile(report_path):
        return "Report not found", 404
    with open(report_path) as f:
        return f.read(), 200, {"Content-Type": "text/plain; charset=utf-8"}


@bp.route("/api/fabric/source/<path:filepath>")
def fabric_source(filepath):
    """Serve source file content for inline viewing."""
    # Resolve and verify the path stays within project root
    resolved = os.path.realpath(os.path.join(ACTUAL_PROJECT_ROOT, filepath))
    if not resolved.startswith(os.path.realpath(ACTUAL_PROJECT_ROOT) + os.sep):
        return "Forbidden", 403
    if not os.path.isfile(resolved):
        return "File not found", 404
    # Limit file size to 500KB
    if os.path.getsize(resolved) > 500_000:
        return "File too large", 413
    with open(resolved, errors="replace") as f:
        return f.read(), 200, {"Content-Type": "text/plain; charset=utf-8"}
