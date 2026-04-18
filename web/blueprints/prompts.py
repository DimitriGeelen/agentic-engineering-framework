"""Prompts blueprint — reusable agent-prompt register UI (T-1283 B3).

Reads the prompt files written by `fw prompt create` (lib/prompt.sh).
Read-only in B3; create/edit composer is deferred to B4.
"""

from pathlib import Path

import yaml
from flask import Blueprint, abort

from web.shared import PROJECT_ROOT, render_page

bp = Blueprint("prompts", __name__)

_PROMPTS_DIR = PROJECT_ROOT / "prompts"


def _parse_prompt(path: Path):
    text = path.read_text()
    if not text.startswith("---"):
        return None
    _, frontmatter, *body = text.split("---", 2)
    try:
        meta = yaml.safe_load(frontmatter) or {}
    except yaml.YAMLError:
        return None
    body_text = "".join(body).lstrip("\n")
    meta["_body"] = body_text
    meta["_slug"] = path.stem
    return meta


def _load_all():
    if not _PROMPTS_DIR.is_dir():
        return []
    out = []
    for f in sorted(_PROMPTS_DIR.glob("*.md")):
        if f.name == "README.md":
            continue
        parsed = _parse_prompt(f)
        if parsed is not None:
            out.append(parsed)
    return out


def _find_by_ref(ref: str):
    """Resolve a slug or FQID to a parsed prompt."""
    for p in _load_all():
        if p.get("_slug") == ref or p.get("qid") == ref or p.get("id") == ref:
            return p
    return None


@bp.route("/prompts")
def prompts_list():
    prompts = _load_all()
    return render_page("prompts_list.html", prompts=prompts)


@bp.route("/prompts/<path:ref>")
def prompt_detail(ref):
    prompt = _find_by_ref(ref)
    if prompt is None:
        abort(404)
    return render_page("prompt_detail.html", prompt=prompt)
