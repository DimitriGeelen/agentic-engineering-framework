#!/usr/bin/env python3
"""Fabric enrichment engine — auto-detect dependency edges from source analysis.

Reads component cards, analyzes their source files for import/source/render
patterns, resolves matches to component IDs, and writes both forward (depends_on)
and reverse (depended_by) edges back to cards.

Usage:
    python3 enrich.py [--dry-run] [--subsystem X] [--verbose] [CARD_PATH ...]
"""

import argparse
import glob
import os
import re
import sys
from collections import defaultdict
from datetime import date

import yaml


# ---------------------------------------------------------------------------
# YAML helpers
# ---------------------------------------------------------------------------

def load_card(path):
    with open(path) as f:
        return yaml.safe_load(f)


def save_card(path, data):
    """Write card YAML preserving readable formatting."""
    with open(path, "w") as f:
        yaml.dump(data, f, default_flow_style=False, sort_keys=False,
                  allow_unicode=True, width=120)


# ---------------------------------------------------------------------------
# Index builder
# ---------------------------------------------------------------------------

def build_index(components_dir):
    """Build lookup indexes from all component cards."""
    cards = {}       # card_path -> card_data
    loc_to_id = {}   # relative_location -> component_id
    loc_to_card = {} # relative_location -> card_path
    id_to_loc = {}   # component_id -> relative_location
    id_to_card = {}  # component_id -> card_path

    for card_path in sorted(glob.glob(os.path.join(components_dir, "*.yaml"))):
        data = load_card(card_path)
        if not data:
            continue
        cards[card_path] = data
        loc = data.get("location", "")
        cid = data.get("id", "")
        if loc:
            loc_to_id[loc] = cid
            loc_to_card[loc] = card_path
        if cid:
            id_to_loc[cid] = loc
            id_to_card[cid] = card_path

    return cards, loc_to_id, loc_to_card, id_to_loc, id_to_card


# ---------------------------------------------------------------------------
# Reverse edge type mapping
# ---------------------------------------------------------------------------

REVERSE_EDGE_TYPE = {
    "calls": "called_by",
    "renders": "rendered_by",
    "reads": "read_by",
    "extends": "extended_by",
    "includes": "included_by",
    "registers": "registered_by",
}


# ---------------------------------------------------------------------------
# Pattern detectors — each returns list of (target_location, edge_type)
# ---------------------------------------------------------------------------

def detect_bash_sources(content, source_location, framework_root):
    """Detect bash source/dot-source, exec, and variable-path patterns."""
    edges = []
    source_dir = os.path.dirname(source_location)

    # Pattern: source "$LIB_DIR/file.sh" or . "$LIB_DIR/file.sh"
    for m in re.finditer(
        r'(?:source|\.)\s+"?\$(?:LIB_DIR|SCRIPT_DIR)/([^"$\s]+)"?', content
    ):
        target_file = m.group(1)
        candidates = [
            os.path.join(source_dir, "lib", target_file),
            os.path.join(source_dir, target_file),
        ]
        for c in candidates:
            c = os.path.normpath(c)
            if os.path.exists(os.path.join(framework_root, c)):
                edges.append((c, "calls"))
                break

    # Pattern: exec "$AGENTS_DIR/agent/script.sh" "$@"
    for m in re.finditer(r'exec\s+"?\$AGENTS_DIR/([^"$\s]+)"?', content):
        target = os.path.normpath(os.path.join("agents", m.group(1)))
        if os.path.exists(os.path.join(framework_root, target)):
            edges.append((target, "calls"))

    # Pattern: source/exec "$FW_LIB_DIR/file.sh"
    for m in re.finditer(
        r'(?:source|exec|\.)\s+"?\$FW_LIB_DIR/([^"$\s]+)"?', content
    ):
        target = os.path.normpath(os.path.join("lib", m.group(1)))
        if os.path.exists(os.path.join(framework_root, target)):
            edges.append((target, "calls"))

    # Pattern: exec python3 "$AGENTS_DIR/path"
    for m in re.finditer(r'exec\s+python3\s+"?\$AGENTS_DIR/([^"$\s]+)"?', content):
        target = os.path.normpath(os.path.join("agents", m.group(1)))
        if os.path.exists(os.path.join(framework_root, target)):
            edges.append((target, "calls"))

    # Pattern: exec python3 -m web.module
    for m in re.finditer(r'exec\s+python3\s+-m\s+(web\.\w+)', content):
        mod = m.group(1).replace(".", "/") + ".py"
        if os.path.exists(os.path.join(framework_root, mod)):
            edges.append((mod, "calls"))

    # Pattern: "$FRAMEWORK_ROOT/path.sh" or "$PROJECT_ROOT/path.sh" (called as command)
    for m in re.finditer(
        r'"?\$(?:FRAMEWORK_ROOT|PROJECT_ROOT)/([^"$\s]+\.sh)"?', content
    ):
        target = os.path.normpath(m.group(1))
        if os.path.exists(os.path.join(framework_root, target)):
            if target != source_location:
                edges.append((target, "calls"))

    # Pattern: "$FRAMEWORK_ROOT/agents/X/Y.sh" via variable like GIT_AGENT=
    for m in re.finditer(
        r'(?:FRAMEWORK_ROOT|PROJECT_ROOT)["/]+?(agents/[^"$\s]+\.sh)', content
    ):
        target = os.path.normpath(m.group(1))
        if os.path.exists(os.path.join(framework_root, target)):
            if target != source_location:
                edges.append((target, "calls"))

    # Pattern: "$FRAMEWORK_ROOT/metrics.sh" or standalone script paths
    for m in re.finditer(
        r'"?\$(?:FRAMEWORK_ROOT|PROJECT_ROOT)/([^"$\s]+\.(?:sh|py))"?', content
    ):
        target = os.path.normpath(m.group(1))
        if os.path.exists(os.path.join(framework_root, target)):
            if target != source_location:
                edges.append((target, "calls"))

    return edges


def detect_python_imports(content, source_location, framework_root):
    """Detect Python from/import and render_page patterns."""
    edges = []

    # Pattern: from web.X import Y
    for m in re.finditer(r'from\s+(web(?:\.\w+)+)\s+import', content):
        mod_path = m.group(1).replace(".", "/")
        target = mod_path + ".py"
        if os.path.exists(os.path.join(framework_root, target)):
            if target != source_location:
                edges.append((target, "calls"))
            continue
        target = os.path.join(mod_path, "__init__.py")
        if os.path.exists(os.path.join(framework_root, target)):
            if target != source_location:
                edges.append((target, "calls"))

    # Pattern: render_page("template.html", ...)
    for m in re.finditer(r'render_page\(\s*["\']([^"\']+)["\']', content):
        template = m.group(1)
        target = os.path.join("web/templates", template)
        if os.path.exists(os.path.join(framework_root, target)):
            edges.append((target, "renders"))

    # Pattern: yaml.safe_load(open(path)) with literal path
    for m in re.finditer(
        r'yaml\.safe_load\(.*?open\([^)]*["\']([^"\']+)["\']', content
    ):
        path = m.group(1)
        if os.path.exists(os.path.join(framework_root, path)):
            edges.append((path, "reads"))

    return edges


def detect_blueprint_registration(content, source_location, framework_root):
    """Detect Flask blueprint registration in __init__.py or app.py."""
    edges = []

    # Pattern: from web.blueprints.X import bp
    for m in re.finditer(r'from\s+web\.blueprints\.(\w+)\s+import', content):
        mod_name = m.group(1)
        target = f"web/blueprints/{mod_name}.py"
        if os.path.exists(os.path.join(framework_root, target)):
            if target != source_location:
                edges.append((target, "registers"))

    return edges


def detect_template_deps(content, source_location, framework_root):
    """Detect Jinja2 template dependencies."""
    edges = []
    tmpl_dir = "web/templates"

    # Pattern: {% extends "base.html" %}
    for m in re.finditer(r'\{%[-\s]*extends\s+["\']([^"\']+)["\']', content):
        target = os.path.join(tmpl_dir, m.group(1))
        if os.path.exists(os.path.join(framework_root, target)):
            edges.append((target, "extends"))

    # Pattern: {% include "_fragment.html" %}
    for m in re.finditer(r'\{%[-\s]*include\s+["\']([^"\']+)["\']', content):
        target = os.path.join(tmpl_dir, m.group(1))
        if os.path.exists(os.path.join(framework_root, target)):
            edges.append((target, "includes"))

    return edges


def detect_generic_python_imports(content, source_location, project_root):
    """
    Detect standard Python imports: from X import Y

    Attempts to resolve module names to actual files in the project,
    inferring paths based on source file location and common patterns.

    This is a prototype for consumer project support (L-CONSUMER-001).
    """
    edges = []

    # Get directory containing source file
    source_dir = os.path.dirname(source_location)

    # Skip standard library and common third-party modules
    SKIP_MODULES = {
        'typing', 'os', 'sys', 'datetime', 'argparse', 'subprocess',
        'yaml', 're', 'json', 'pathlib', 'collections', 'functools',
        'itertools', 'logging', 'time', 'random', 'math', 'copy',
        'enum', 'dataclasses', 'abc', 'urllib', 'http', 'email',
        'sqlite3', 'csv', 'xml', 'html', 'unittest', 'pytest',
        'flask', 'jinja2', 'werkzeug', 'requests', 'numpy', 'pandas'
    }

    # Pattern: from module import something
    for m in re.finditer(r'from\s+(\w+)\s+import', content):
        module_name = m.group(1)

        # Skip standard library and common third-party modules
        if module_name in SKIP_MODULES:
            continue

        # Try to resolve module to file
        # Strategy 1: Same directory as source
        target = os.path.join(source_dir, module_name + '.py')
        if os.path.exists(os.path.join(project_root, target)):
            if target != source_location:
                edges.append((target, "uses"))
            continue

        # Strategy 2: Package init file
        target = os.path.join(source_dir, module_name, '__init__.py')
        if os.path.exists(os.path.join(project_root, target)):
            if target != source_location:
                edges.append((target, "uses"))
            continue

        # Strategy 3: Check parent directory (for shared modules)
        parent_dir = os.path.dirname(source_dir)
        if parent_dir:
            target = os.path.join(parent_dir, module_name + '.py')
            if os.path.exists(os.path.join(project_root, target)):
                if target != source_location:
                    edges.append((target, "uses"))
                continue

    return edges


RUST_SKIP_CRATES = {
    # Language built-ins and intra-crate aliases
    "std", "core", "alloc", "crate", "self", "super",
    # Async runtime + futures
    "tokio", "tokio_util", "tokio_stream", "futures", "futures_util",
    "async_trait",
    # Serde + encoding
    "serde", "serde_json", "serde_yaml", "serde_with", "bincode",
    "base64", "hex", "byteorder",
    # Errors + logging
    "anyhow", "thiserror", "tracing", "tracing_subscriber", "log",
    "env_logger",
    # Crypto / hashing / rand
    "sha2", "sha1", "md5", "blake3",
    "ed25519", "ed25519_dalek", "x25519_dalek", "rsa", "ring",
    "rand", "rand_core", "rand_chacha", "getrandom",
    # Data structures + time
    "chrono", "time", "uuid", "once_cell", "lazy_static",
    "parking_lot", "dashmap", "smallvec", "indexmap", "ahash",
    # CLI + HTTP + RPC
    "clap", "structopt",
    "reqwest", "hyper", "axum", "warp", "tower", "http", "url",
    "jsonrpsee", "jsonrpc_core",
    # Storage
    "rusqlite", "r2d2", "sled",
    # Testing / utilities
    "tempfile", "assert_cmd", "predicates", "insta", "mockall",
    "pretty_assertions",
    # Misc third-party seen in this workspace
    "libc", "nix", "bytes", "regex", "dirs", "home",
    "toml", "toml_edit", "shellwords",
}


def detect_rust_deps(content, source_location, project_root):
    """Detect Rust `mod` declarations and cross-crate `use` statements.

    Two edge patterns, both mapped to edge type "calls" (same convention as
    bash source and python imports):

    1. `mod <name>;` — resolves to a sibling file `<dir>/<name>.rs` or a
       subdir module `<dir>/<name>/mod.rs`. This captures intra-crate
       structural composition (lib.rs → submodule files).

    2. `use <crate>::...;` / `pub use <crate>::...;` — when `<crate>` maps
       to a workspace crate via the `crate_name → kebab-case → crates/<kebab>/src/lib.rs`
       convention, emit an edge to that crate's lib.rs. Third-party and std
       crates in `RUST_SKIP_CRATES` are ignored.

    Intra-crate `use crate::foo::Bar` is deliberately NOT detected here —
    the owning `lib.rs` / `mod.rs` already has `mod foo;` which captures
    the sibling edge, so adding a second edge would be noise.
    """
    edges = []
    source_dir = os.path.dirname(source_location)

    # Pattern: mod foo;  (optionally with pub or pub(crate)/pub(super))
    # Skip `mod foo { ... }` inline modules — only resolve file/dir modules.
    # Skip `#[cfg(test)] mod tests { ... }` via the `;` anchor; inline blocks
    # end in `{` not `;`.
    for m in re.finditer(
        r'^\s*(?:pub(?:\([^)]+\))?\s+)?mod\s+([A-Za-z_][A-Za-z0-9_]*)\s*;',
        content,
        re.MULTILINE,
    ):
        mod_name = m.group(1)
        # Try sibling file first: <source_dir>/<mod>.rs
        sibling = os.path.normpath(os.path.join(source_dir, f"{mod_name}.rs"))
        if os.path.exists(os.path.join(project_root, sibling)):
            if sibling != source_location:
                edges.append((sibling, "calls"))
            continue
        # Fall back to subdir module: <source_dir>/<mod>/mod.rs
        subdir = os.path.normpath(os.path.join(source_dir, mod_name, "mod.rs"))
        if os.path.exists(os.path.join(project_root, subdir)):
            if subdir != source_location:
                edges.append((subdir, "calls"))

    # Pattern: use <crate>::...;  or  pub use <crate>::...;
    # Grab the leading path segment; the resolver decides if it's a crate.
    # Also handles `use <crate>;` (no `::`) and `use <crate> as Alias;`.
    seen_crates = set()
    for m in re.finditer(
        r'^\s*(?:pub(?:\([^)]+\))?\s+)?use\s+([A-Za-z_][A-Za-z0-9_]*)\b',
        content,
        re.MULTILINE,
    ):
        crate_name = m.group(1)
        if crate_name in RUST_SKIP_CRATES:
            continue
        if crate_name in seen_crates:
            continue
        seen_crates.add(crate_name)
        # Rust `_` → Cargo `-` (underscore ↔ hyphen convention)
        kebab = crate_name.replace("_", "-")
        target = os.path.normpath(f"crates/{kebab}/src/lib.rs")
        if os.path.exists(os.path.join(project_root, target)):
            if target != source_location:
                edges.append((target, "calls"))

    return edges


def detect_ts_js_imports(content, source_location, project_root):
    """Detect TypeScript/JavaScript import/require patterns.

    Handles: import X from './path', import {X} from './path',
             export {X} from './path', require('./path'),
             dynamic import('./path').

    Resolves relative paths (./ and ../) against source directory.
    Skips bare package imports (no ./ prefix) as they're node_modules.
    T-552: Origin — OpenClaw eval showed 0 edges on TS project.
    """
    edges = []
    source_dir = os.path.dirname(source_location)

    import_paths = set()

    # ES module: import X from 'path' / import {X} from 'path' / export {X} from 'path'
    for m in re.finditer(
        r'''(?:import|export)\s+.*?\s+from\s+['"]([^'"]+)['"]''', content
    ):
        import_paths.add(m.group(1))

    # Side-effect import: import 'path'
    for m in re.finditer(r'''import\s+['"]([^'"]+)['"]''', content):
        import_paths.add(m.group(1))

    # CommonJS: require('path')
    for m in re.finditer(r'''require\s*\(\s*['"]([^'"]+)['"]\s*\)''', content):
        import_paths.add(m.group(1))

    # Dynamic import: import('path')
    for m in re.finditer(r'''import\s*\(\s*['"]([^'"]+)['"]\s*\)''', content):
        import_paths.add(m.group(1))

    for imp in import_paths:
        # Skip bare package imports (node_modules)
        if not imp.startswith('.'):
            continue

        resolved = os.path.normpath(os.path.join(source_dir, imp))

        # Try exact path, then common extensions and index files
        extensions = ['', '.ts', '.tsx', '.js', '.jsx',
                      '/index.ts', '/index.tsx', '/index.js', '/index.jsx']
        for ext in extensions:
            candidate = resolved + ext
            if os.path.exists(os.path.join(project_root, candidate)):
                if candidate != source_location:
                    edges.append((candidate, "uses"))
                break

    return edges


# ---------------------------------------------------------------------------
# Edge resolver
# ---------------------------------------------------------------------------

def resolve_edges(raw_edges, loc_to_id, source_id):
    """Convert (location, type) pairs to edge dicts. Deduplicates."""
    seen = set()
    resolved = []

    for loc, edge_type in raw_edges:
        loc = os.path.normpath(loc)
        target_id = loc_to_id.get(loc)
        if not target_id:
            continue
        if target_id == source_id:
            continue
        key = (target_id, edge_type)
        if key in seen:
            continue
        seen.add(key)
        resolved.append({"target": target_id, "type": edge_type})

    return resolved


# ---------------------------------------------------------------------------
# Forward pass — detect depends_on for each card
# ---------------------------------------------------------------------------

def compute_forward_edges(cards, loc_to_id, framework_root):
    """Analyze all cards and return new forward edges per card_path.

    Returns: dict of card_path -> list of edge dicts to ADD to depends_on
    """
    forward = {}  # card_path -> [edge_dicts]

    for card_path, card_data in sorted(cards.items()):
        location = card_data.get("location", "")
        card_id = card_data.get("id", "")

        if not location:
            continue

        source_path = os.path.join(framework_root, location)
        if not os.path.exists(source_path):
            continue

        try:
            with open(source_path, "r", errors="replace") as f:
                content = f.read(100_000)
        except (OSError, UnicodeDecodeError):
            continue

        # Determine file type — check extension, fall back to shebang
        raw_edges = []
        is_bash = location.endswith(".sh")
        is_python = location.endswith(".py")
        is_html = location.endswith(".html")
        is_ts_js = any(location.endswith(ext) for ext in ('.ts', '.tsx', '.js', '.jsx'))
        is_rust = location.endswith(".rs")
        if not (is_bash or is_python or is_html or is_ts_js or is_rust):
            first_line = content.split("\n", 1)[0] if content else ""
            if "bash" in first_line or "sh" in first_line:
                is_bash = True
            elif "python" in first_line:
                is_python = True

        if is_bash:
            raw_edges.extend(detect_bash_sources(content, location, framework_root))
        elif is_python:
            raw_edges.extend(detect_python_imports(content, location, framework_root))
            raw_edges.extend(detect_blueprint_registration(content, location, framework_root))
            raw_edges.extend(detect_generic_python_imports(content, location, framework_root))  # L-CONSUMER-001 prototype
        elif is_html:
            raw_edges.extend(detect_template_deps(content, location, framework_root))
        elif is_ts_js:
            raw_edges.extend(detect_ts_js_imports(content, location, framework_root))
        elif is_rust:
            raw_edges.extend(detect_rust_deps(content, location, framework_root))

        if not raw_edges:
            continue

        new_edges = resolve_edges(raw_edges, loc_to_id, card_id)
        if not new_edges:
            continue

        # Filter out edges already present
        existing = card_data.get("depends_on", []) or []
        existing_keys = set()
        if isinstance(existing, list):
            for e in existing:
                if isinstance(e, dict):
                    existing_keys.add((e.get("target", ""), e.get("type", "")))

        to_add = []
        for edge in new_edges:
            key = (edge["target"], edge["type"])
            if key not in existing_keys:
                to_add.append(edge)

        if to_add:
            forward[card_path] = to_add

    return forward


# ---------------------------------------------------------------------------
# Reverse pass — compute depended_by from forward edges
# ---------------------------------------------------------------------------

def compute_reverse_edges(forward_edges, cards, id_to_card):
    """From forward edges, compute reverse depended_by edges per card_path.

    Returns: dict of card_path -> list of edge dicts to ADD to depended_by
    """
    reverse = defaultdict(list)  # card_path -> [edge_dicts]

    for source_path, edges in forward_edges.items():
        source_data = cards[source_path]
        source_id = source_data.get("id", "")

        for edge in edges:
            target_id = edge["target"]
            edge_type = edge["type"]
            rev_type = REVERSE_EDGE_TYPE.get(edge_type, f"{edge_type}_by")
            target_card_path = id_to_card.get(target_id)
            if not target_card_path:
                continue
            reverse[target_card_path].append({
                "target": source_id,
                "type": rev_type,
            })

    # Also compute reverse edges from EXISTING depends_on that were already
    # in the cards (so targets of pre-existing edges also get depended_by)
    for card_path, card_data in cards.items():
        source_id = card_data.get("id", "")
        existing_deps = card_data.get("depends_on", []) or []
        if not isinstance(existing_deps, list):
            continue
        for edge in existing_deps:
            if not isinstance(edge, dict):
                continue
            target_id = edge.get("target", "")
            edge_type = edge.get("type", "")
            rev_type = REVERSE_EDGE_TYPE.get(edge_type, f"{edge_type}_by")
            target_card_path = id_to_card.get(target_id)
            if not target_card_path:
                continue
            reverse[target_card_path].append({
                "target": source_id,
                "type": rev_type,
            })

    # Deduplicate and filter already-present reverse edges
    filtered = {}
    for card_path, rev_edges in reverse.items():
        card_data = cards.get(card_path)
        if not card_data:
            continue

        existing_depby = card_data.get("depended_by", []) or []
        existing_keys = set()
        if isinstance(existing_depby, list):
            for e in existing_depby:
                if isinstance(e, dict):
                    existing_keys.add((e.get("target", ""), e.get("type", "")))

        seen = set()
        to_add = []
        for edge in rev_edges:
            key = (edge["target"], edge["type"])
            if key not in existing_keys and key not in seen:
                to_add.append(edge)
                seen.add(key)

        if to_add:
            filtered[card_path] = to_add

    return filtered


# ---------------------------------------------------------------------------
# Write pass — apply edges to cards
# ---------------------------------------------------------------------------

def apply_edges(cards, forward, reverse, dry_run, verbose):
    """Write forward and reverse edges to cards. Returns stats."""
    today = str(date.today())
    cards_touched = set()
    total_fwd = 0
    total_rev = 0
    subsystem_stats = defaultdict(int)

    # Apply forward edges (depends_on)
    for card_path, edges in sorted(forward.items()):
        card_data = cards[card_path]
        name = card_data.get("name", "?")
        subsystem = card_data.get("subsystem", "unknown")

        if verbose:
            for e in edges:
                print(f"  {name}: depends_on +{e['type']:10s} -> {e['target']}")

        if not dry_run:
            existing = card_data.get("depends_on", []) or []
            if not isinstance(existing, list):
                existing = []
            card_data["depends_on"] = existing + edges
            card_data["last_enriched"] = today

        cards_touched.add(card_path)
        total_fwd += len(edges)
        subsystem_stats[subsystem] += len(edges)

    # Apply reverse edges (depended_by)
    for card_path, edges in sorted(reverse.items()):
        card_data = cards[card_path]
        name = card_data.get("name", "?")
        subsystem = card_data.get("subsystem", "unknown")

        if verbose:
            for e in edges:
                print(f"  {name}: depended_by +{e['type']:10s} <- {e['target']}")

        if not dry_run:
            existing = card_data.get("depended_by", []) or []
            if not isinstance(existing, list):
                existing = []
            card_data["depended_by"] = existing + edges
            card_data["last_enriched"] = today

        cards_touched.add(card_path)
        total_rev += len(edges)
        subsystem_stats[subsystem] += len(edges)

    # Save all touched cards
    if not dry_run:
        for card_path in cards_touched:
            save_card(card_path, cards[card_path])

    return len(cards_touched), total_fwd, total_rev, dict(subsystem_stats)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description="Enrich fabric component cards with dependency edges"
    )
    parser.add_argument("--dry-run", action="store_true",
                        help="Report changes without writing")
    parser.add_argument("--subsystem",
                        help="Only enrich cards in this subsystem")
    parser.add_argument("--verbose", "-v", action="store_true",
                        help="Show each detected edge")
    parser.add_argument("cards", nargs="*",
                        help="Specific card paths to enrich (default: all)")
    args = parser.parse_args()

    # Find project root (use PROJECT_ROOT env var if available, for embedded frameworks)
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.environ.get("PROJECT_ROOT") or os.path.normpath(os.path.join(script_dir, "..", "..", ".."))
    components_dir = os.path.join(project_root, ".fabric", "components")

    if not os.path.isdir(components_dir):
        print(f"ERROR: Components directory not found: {components_dir}",
              file=sys.stderr)
        sys.exit(1)

    # Build index
    cards, loc_to_id, loc_to_card, id_to_loc, id_to_card = build_index(
        components_dir
    )

    # Filter to target cards if specified
    if args.cards:
        targets = {}
        for p in args.cards:
            p = os.path.abspath(p)
            if p in cards:
                targets[p] = cards[p]
            else:
                print(f"WARN: Card not found: {p}", file=sys.stderr)
    elif args.subsystem:
        targets = {p: d for p, d in cards.items()
                   if d.get("subsystem") == args.subsystem}
        if not targets:
            print(f"No cards for subsystem: {args.subsystem}", file=sys.stderr)
            sys.exit(1)
    else:
        targets = cards

    mode = "DRY RUN" if args.dry_run else "ENRICHING"
    print(f"\n=== Fabric Enrichment ({mode}) ===")
    print(f"Processing {len(targets)} cards...\n")

    # Phase 1: Compute forward edges (depends_on)
    forward = compute_forward_edges(targets, loc_to_id, project_root)

    # Phase 2: Compute reverse edges (depended_by) — uses ALL cards as targets
    reverse = compute_reverse_edges(forward, cards, id_to_card)

    # If subsystem filter, also limit reverse edges to target subsystem's cards
    # But actually we want reverse edges on ANY card that is a target — even
    # outside the subsystem. So we use all cards for reverse computation.

    # Phase 3: Apply
    n_cards, n_fwd, n_rev, sub_stats = apply_edges(
        cards, forward, reverse, args.dry_run, args.verbose
    )

    # Summary
    print(f"\n=== Summary ===")
    print(f"Cards processed:   {len(targets)}")
    print(f"Cards enriched:    {n_cards}")
    print(f"Forward edges:     {n_fwd}  (depends_on)")
    print(f"Reverse edges:     {n_rev}  (depended_by)")
    print(f"Total edges added: {n_fwd + n_rev}")

    if sub_stats:
        print(f"\nEdges by subsystem:")
        for sub, count in sorted(sub_stats.items(), key=lambda x: -x[1]):
            print(f"  {sub:30s}  +{count}")

    if args.dry_run:
        print(f"\n(Dry run — no files were modified)")

    return 0


if __name__ == "__main__":
    sys.exit(main())
