"""Generated documentation blueprint — serves auto-generated component reference docs
and a general-purpose file viewer for project markdown files (T-632)."""

import logging
import os
import re as re_mod
from pathlib import Path

import markdown2
import yaml
from flask import Blueprint, abort, request

logger = logging.getLogger(__name__)

from web.shared import FRAMEWORK_ROOT, PROJECT_ROOT, render_page

# Safe directories for file viewer (relative to PROJECT_ROOT)
_VIEWABLE_DIRS = ("docs/", ".tasks/", ".context/handovers/", ".context/episodic/")

# Regex for file references that should become clickable links (T-633)
_FILE_REF_RE = re_mod.compile(
    r'(?<!href=")'           # Not already inside an href
    r'(?<!/file/)'           # Not already a /file/ link
    r'(`?)'                  # Optional opening backtick
    r'((?:docs/reports/|\.tasks/(?:active|completed)/|\.context/(?:handovers|episodic)/)'
    r'[A-Za-z0-9_/.-]+\.(?:md|yaml))'  # File path
    r'(`?)'                  # Optional closing backtick
)


def _auto_link_files(html):
    """Convert file path references in rendered HTML to clickable /file/ links (T-633)."""
    def _replace(m):
        tick1, path, tick2 = m.group(1), m.group(2), m.group(3)
        # Verify file exists before linking
        if (PROJECT_ROOT / path).exists():
            return f'<a href="/file/{path}">{tick1}{path}{tick2}</a>'
        return m.group(0)
    return _FILE_REF_RE.sub(_replace, html)

bp = Blueprint("docs", __name__)

GENERATED_DIR = FRAMEWORK_ROOT / "docs" / "generated" / "components"
COMPONENTS_DIR = FRAMEWORK_ROOT / ".fabric" / "components"


def _load_docs():
    """Load all generated component docs, grouped by subsystem."""
    if not GENERATED_DIR.exists():
        return {}, []

    # Load card data for subsystem grouping
    card_data = {}
    if COMPONENTS_DIR.exists():
        for card_file in COMPONENTS_DIR.glob("*.yaml"):
            try:
                with open(card_file) as f:
                    data = yaml.safe_load(f)
                if data:
                    card_name = card_file.stem
                    card_data[card_name] = data
            except Exception as e:
                logger.warning("Failed to parse component card %s: %s", card_file, e)
                continue

    subsystems = {}
    all_docs = []

    for doc_file in sorted(GENERATED_DIR.glob("*.md")):
        card_name = doc_file.stem
        card = card_data.get(card_name, {})
        subsystem = card.get("subsystem", "other")
        name = card.get("name", card_name)
        purpose = card.get("purpose", "")
        ctype = card.get("type", "unknown")

        entry = {
            "card_name": card_name,
            "name": name,
            "subsystem": subsystem,
            "purpose": purpose[:100] + ("..." if len(purpose) > 100 else ""),
            "type": ctype,
        }

        if subsystem not in subsystems:
            subsystems[subsystem] = []
        subsystems[subsystem].append(entry)
        all_docs.append(entry)

    return subsystems, all_docs


@bp.route("/docs/generated")
def docs_index():
    """Index of all generated component docs, grouped by subsystem."""
    subsystems, all_docs = _load_docs()

    return render_page(
        "docs_index.html",
        page_title="Component Reference Docs",
        subsystems=subsystems,
        total=len(all_docs),
    )


@bp.route("/docs/generated/<card_name>")
def docs_detail(card_name):
    """Render a single generated component doc."""
    if not card_name.replace("-", "").replace("_", "").isalnum():
        abort(404)

    doc_path = GENERATED_DIR / f"{card_name}.md"
    if not doc_path.exists():
        abort(404)

    content_md = doc_path.read_text()
    html_content = markdown2.markdown(
        content_md, extras=["tables", "fenced-code-blocks", "code-friendly"]
    )

    # Extract title from first line
    first_line = content_md.split("\n")[0].lstrip("# ").strip()

    return render_page(
        "docs_detail.html",
        page_title=first_line,
        card_name=card_name,
        html_content=html_content,
    )


@bp.route("/file/<path:filepath>")
def file_viewer(filepath):
    """Render any project markdown file from safe directories (T-632).

    Only serves files under _VIEWABLE_DIRS to prevent path traversal.
    """
    # Block path traversal
    if ".." in filepath:
        abort(404)

    # Must be under a safe directory
    if not any(filepath.startswith(d) for d in _VIEWABLE_DIRS):
        abort(404)

    # Must be markdown
    if not filepath.endswith(".md"):
        abort(404)

    file_path = PROJECT_ROOT / filepath
    if not file_path.exists() or not file_path.is_file():
        abort(404)

    # Resolve and verify still under PROJECT_ROOT (symlink protection)
    resolved = file_path.resolve()
    if not str(resolved).startswith(str(PROJECT_ROOT.resolve())):
        abort(404)

    content_md = file_path.read_text()
    html_content = markdown2.markdown(
        content_md, extras=["tables", "fenced-code-blocks", "code-friendly"]
    )
    html_content = _auto_link_files(html_content)

    # Title from first heading or filename
    first_line = ""
    for line in content_md.split("\n"):
        if line.startswith("#"):
            first_line = line.lstrip("# ").strip()
            break
    if not first_line:
        first_line = file_path.name

    return render_page(
        "docs_detail.html",
        page_title=first_line,
        card_name=file_path.stem,
        html_content=html_content,
    )
