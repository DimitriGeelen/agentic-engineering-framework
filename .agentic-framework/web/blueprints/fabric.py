"""Watchtower – Component Fabric browser."""

import glob
import os

import yaml
from flask import Blueprint, request

from web.shared import PROJECT_ROOT, render_page

bp = Blueprint("fabric", __name__)

FABRIC_DIR = os.path.join(PROJECT_ROOT, ".fabric")
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
    """Load subsystem registry."""
    path = os.path.join(FABRIC_DIR, "subsystems.yaml")
    if not os.path.exists(path):
        return []
    with open(path) as f:
        data = yaml.safe_load(f)
    return data.get("subsystems", [])


def _build_graph(components, all_components=None):
    """Build nodes and edges for visualization."""
    nodes = []
    edges = []
    id_to_name = {}
    comp_info = {}  # name → {type, subsystem, location}

    # Build lookup from ALL components so dependency targets resolve correctly
    for c in (all_components or components):
        cid = c.get("id", c.get("name", ""))
        name = c.get("name", cid)
        ctype = c.get("type", "unknown")
        subsystem = c.get("subsystem", "unknown")
        loc = c.get("location", "")
        id_to_name[cid] = name
        id_to_name[name] = name
        if loc:
            id_to_name[loc] = name
        comp_info[name] = {"type": ctype, "subsystem": subsystem, "location": loc}

    # Build nodes only from enriched components passed in
    for c in components:
        cid = c.get("id", c.get("name", ""))
        name = c.get("name", cid)
        info = comp_info.get(name, {})
        nodes.append({
            "id": name,
            "label": name,
            "type": info.get("type", "unknown"),
            "subsystem": info.get("subsystem", "unknown"),
            "location": info.get("location", ""),
        })

    seen_edges = set()
    for c in components:
        source_name = c.get("name", c.get("id", ""))
        for dep in c.get("depends_on", []):
            if not isinstance(dep, dict):
                continue
            target = dep.get("target", "")
            target_name = id_to_name.get(target, target)
            edge_type = dep.get("type", "uses")
            key = (source_name, target_name, edge_type)
            if key not in seen_edges:
                seen_edges.add(key)
                edges.append({
                    "source": source_name,
                    "target": target_name,
                    "type": edge_type,
                })

        # Also handle writers/readers on data files
        for w in c.get("writers", []):
            if isinstance(w, dict):
                wt = id_to_name.get(w.get("target", ""), w.get("target", ""))
                key = (wt, source_name, "writes")
                if key not in seen_edges:
                    seen_edges.add(key)
                    edges.append({"source": wt, "target": source_name, "type": "writes"})
        for r in c.get("readers", []):
            if isinstance(r, dict):
                rt = id_to_name.get(r.get("target", ""), r.get("target", ""))
                key = (rt, source_name, "reads")
                if key not in seen_edges:
                    seen_edges.add(key)
                    edges.append({"source": rt, "target": source_name, "type": "reads"})

    # Add nodes for edge endpoints not already in the node set
    node_ids = {n["id"] for n in nodes}
    for e in edges:
        for endpoint in (e["source"], e["target"]):
            if endpoint and endpoint not in node_ids:
                node_ids.add(endpoint)
                info = comp_info.get(endpoint, {})
                nodes.append({
                    "id": endpoint,
                    "label": endpoint,
                    "type": info.get("type", "unknown"),
                    "subsystem": info.get("subsystem", "unknown"),
                    "location": info.get("location", ""),
                })

    # Filter out edges with empty endpoints
    edges = [e for e in edges if e["source"] and e["target"]]

    return nodes, edges


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
        source_path = os.path.join(PROJECT_ROOT, location)
        real_source = os.path.realpath(source_path)
        real_root = os.path.realpath(PROJECT_ROOT)
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
    """Dependency graph visualization."""
    all_components = _load_components()
    subsystem_filter = request.args.get("subsystem", "")

    components = all_components
    if subsystem_filter:
        components = [c for c in components if c.get("subsystem") == subsystem_filter]

    # Only include components that have edges (enriched cards)
    enriched = [c for c in components if
                c.get("depends_on") or c.get("depended_by") or
                c.get("writers") or c.get("readers")]

    nodes, edges = _build_graph(enriched, all_components=all_components)
    subsystems = _load_subsystems()

    # Build subsystem color map for compound node backgrounds
    subsystem_colors = {
        "watchtower": "#2d4a7a",
        "context-fabric": "#2a5a4a",
        "framework-core": "#5a3a2a",
        "git-traceability": "#4a2a5a",
        "component-fabric": "#2a4a5a",
        "healing": "#5a2a3a",
        "learnings-pipeline": "#3a5a2a",
        "budget-management": "#5a4a2a",
        "task-management": "#2a3a5a",
        "audit": "#4a5a2a",
        "handover": "#3a2a5a",
        "enforcement": "#5a2a4a",
    }

    return render_page(
        "fabric_graph.html",
        page_title="Dependency Graph",
        nodes=nodes,
        edges=edges,
        subsystems=subsystems,
        subsystem_filter=subsystem_filter,
        subsystem_colors=subsystem_colors,
        total_nodes=len(nodes),
        total_edges=len(edges),
    )
