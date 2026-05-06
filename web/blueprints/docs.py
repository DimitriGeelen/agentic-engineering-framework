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

from web.shared import (
    FRAMEWORK_ROOT,
    PROJECT_ROOT,
    _ARTEFACT_PATH_RE as _FILE_REF_RE,  # back-compat alias
    _auto_link_files,
    is_viewable_path,
    render_page,
)

# T-1764: _VIEWABLE_DIRS and the .md-only restriction were the cause of
# linker/route drift. Replaced by `is_viewable_path` (web/shared.py) which
# both the linker and this route consult. Kept here as a deprecated alias
# for any out-of-tree imports — but contains the FULL list now, not the old
# 4-prefix subset.
_VIEWABLE_DIRS = ("docs/", ".tasks/", ".context/", ".fabric/", "web/", "lib/",
                  "bin/", "agents/", "tests/", "tools/", "prompts/", "policy/",
                  "deploy/")

# Map extensions to fenced-code-block language hints for syntax highlighting
_EXT_TO_LANG = {
    "py": "python",
    "sh": "bash",
    "bats": "bash",
    "yaml": "yaml",
    "yml": "yaml",
    "json": "json",
    "toml": "toml",
}

# T-633 / T-1722: file-path linkifier promoted to web/shared.py so every
# Markdown surface (review, tasks, approvals, inception) gets one-click
# artefact navigation. Re-exported here as `_FILE_REF_RE` / `_auto_link_files`
# for back-compat with the existing call site below.

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
    """Render a project file from a whitelisted directory (T-632, T-1764).

    Whitelist enforcement (path traversal block, dir prefix check, extension
    check) lives in `web.shared.is_viewable_path` so this route and the
    auto-linker (`_auto_link_files`) cannot drift apart again — that drift
    was the T-1764 root cause.

    Markdown files render as Markdown. Source files (.py, .sh, .yaml, etc.)
    render as syntax-highlighted code blocks.
    """
    if not is_viewable_path(filepath):
        abort(404)

    file_path = PROJECT_ROOT / filepath
    if not file_path.exists() or not file_path.is_file():
        abort(404)

    # Resolve and verify still under PROJECT_ROOT (symlink protection)
    resolved = file_path.resolve()
    if not str(resolved).startswith(str(PROJECT_ROOT.resolve())):
        abort(404)

    content = file_path.read_text()
    ext = filepath.rsplit(".", 1)[-1] if "." in filepath else ""

    if ext == "md":
        html_content = markdown2.markdown(
            content, extras=["tables", "fenced-code-blocks", "code-friendly"]
        )
        html_content = _auto_link_files(html_content)
        # Title from first heading or filename
        first_line = ""
        for line in content.split("\n"):
            if line.startswith("#"):
                first_line = line.lstrip("# ").strip()
                break
        if not first_line:
            first_line = file_path.name
    else:
        # Source file — render as fenced code block with language hint
        lang = _EXT_TO_LANG.get(ext, "")
        fenced = f"```{lang}\n{content}\n```"
        html_content = markdown2.markdown(
            fenced, extras=["fenced-code-blocks", "code-friendly"]
        )
        first_line = filepath  # show repo-relative path as title

    return render_page(
        "docs_detail.html",
        page_title=first_line,
        card_name=file_path.stem,
        html_content=html_content,
    )
