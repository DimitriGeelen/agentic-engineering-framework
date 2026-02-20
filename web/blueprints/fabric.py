"""Watchtower – Component Fabric browser."""

import glob
import os

import yaml
from flask import Blueprint, request

from web.shared import PROJECT_ROOT, render_page

bp = Blueprint("fabric", __name__)

FABRIC_DIR = os.path.join(PROJECT_ROOT, ".fabric")
COMP_DIR = os.path.join(FABRIC_DIR, "components")


def _load_components():
    """Load all component cards."""
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
    return components


def _load_subsystems():
    """Load subsystem registry."""
    path = os.path.join(FABRIC_DIR, "subsystems.yaml")
    if not os.path.exists(path):
        return []
    with open(path) as f:
        data = yaml.safe_load(f)
    return data.get("subsystems", [])


def _build_graph(components):
    """Build nodes and edges for visualization."""
    nodes = []
    edges = []
    id_to_name = {}

    for c in components:
        cid = c.get("id", c.get("name", ""))
        name = c.get("name", cid)
        ctype = c.get("type", "unknown")
        subsystem = c.get("subsystem", "unknown")
        id_to_name[cid] = name
        id_to_name[name] = name
        loc = c.get("location", "")
        if loc:
            id_to_name[loc] = name
        nodes.append({
            "id": name,
            "label": name,
            "type": ctype,
            "subsystem": subsystem,
            "location": loc,
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

    # Add placeholder nodes for edge targets/sources not in the node set
    node_ids = {n["id"] for n in nodes}
    for e in edges:
        for endpoint in (e["source"], e["target"]):
            if endpoint and endpoint not in node_ids:
                node_ids.add(endpoint)
                nodes.append({
                    "id": endpoint,
                    "label": endpoint,
                    "type": "unknown",
                    "subsystem": "unknown",
                    "location": "",
                })

    # Filter out edges with empty endpoints
    edges = [e for e in edges if e["source"] and e["target"]]

    return nodes, edges


@bp.route("/fabric")
def fabric_overview():
    """Main fabric page — subsystem overview + component list."""
    components = _load_components()
    subsystems = _load_subsystems()

    # Stats
    type_counts = {}
    subsystem_counts = {}
    for c in components:
        t = c.get("type", "unknown")
        s = c.get("subsystem", "unknown")
        type_counts[t] = type_counts.get(t, 0) + 1
        subsystem_counts[s] = subsystem_counts.get(s, 0) + 1

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

    return render_page(
        "fabric_detail.html",
        page_title=f"Component: {component.get('name', '?')}",
        component=component,
        reverse_deps=reverse_deps,
    )


@bp.route("/fabric/graph")
def fabric_graph():
    """Dependency graph visualization."""
    components = _load_components()
    subsystem_filter = request.args.get("subsystem", "")

    if subsystem_filter:
        components = [c for c in components if c.get("subsystem") == subsystem_filter]

    # Only include components that have edges (enriched cards)
    enriched = [c for c in components if c.get("depends_on") or c.get("writers") or c.get("readers")]

    nodes, edges = _build_graph(enriched)
    subsystems = _load_subsystems()

    return render_page(
        "fabric_graph.html",
        page_title="Dependency Graph",
        nodes=nodes,
        edges=edges,
        subsystems=subsystems,
        subsystem_filter=subsystem_filter,
        total_nodes=len(nodes),
        total_edges=len(edges),
    )
