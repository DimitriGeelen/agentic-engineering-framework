"""Generated documentation blueprint — serves auto-generated component reference docs."""

import os
from pathlib import Path

import markdown2
import yaml
from flask import Blueprint, abort

from web.shared import FRAMEWORK_ROOT, render_page

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
            except Exception:
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
