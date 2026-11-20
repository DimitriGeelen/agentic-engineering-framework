"""T-5305 (T-5302 slice 3): Watchtower prints copy-paste fw commands through the
one builder (lib/fw_command.py, Jinja global ``fw_cmd`` from T-5303).

Each changed template is rendered with the real app's Jinja environment for two
fixture roots — a framework repo (FRAMEWORK.md + bin/fw) and a vendored project
(.agentic-framework/bin/fw, no FRAMEWORK.md) — and must show the builder's text,
never a hand-written ``bin/fw``. The blueprint/runner strings are checked the
same way.
"""
from __future__ import annotations

import html
import re
import sys
from pathlib import Path

import jinja2
import pytest

FRAMEWORK_ROOT = Path(__file__).resolve().parents[2]
if str(FRAMEWORK_ROOT) not in sys.path:
    sys.path.insert(0, str(FRAMEWORK_ROOT))

from lib.fw_command import user_command  # noqa: E402

# template -> (minimal page context, the fw args each printed command carries)
PAGES = {
    "arcs_index.html": (
        dict(arcs=[], all_arcs_count=0),
        ['arc create <id> --name "Description" --anchor T-XXXX'],
    ),
    "arc_detail.html": (
        dict(arc={"status": "in-progress", "id": "arc-x"}, arc_id="arc-x", arc_slug="arc-x",
             stats={"completed": 0, "total": 1, "ratio": 0.0},
             bvp_info={"proposed_drivers": [{"name": "drv", "reviewer_state": "fail"}]}),
        ["arc review-driver arc-x --all",
         'arc approve-driver arc-x "drv" --i-am-human',
         "arc close arc-x"],
    ),
    "designer_ghosts.html": (
        dict(ghosts=[{"uuid": "u-1", "first_seen_h": "now"}]),
        ["bpmn claim u-1 <project>"],
    ),
    "embeddings.html": (
        dict(index={"chunks": 0}, happiness={"count": 0, "recent": [], "mean": 0.0}),
        ['task update T-XXX --happiness +3 --happiness-reason "..."'],
    ),
    "orchestrator.html": (
        dict(),
        ["audit --section orchestrator"],
    ),
}


def _framework_fixture(tmp_path: Path) -> Path:
    root = tmp_path / "fwrepo"
    (root / "bin").mkdir(parents=True)
    (root / "bin" / "fw").write_text("#!/bin/sh\n")
    (root / "FRAMEWORK.md").write_text("# fw\n")
    return root


def _vendored_fixture(tmp_path: Path) -> Path:
    root = tmp_path / "consumer"
    (root / ".agentic-framework" / "bin").mkdir(parents=True)
    (root / ".agentic-framework" / "bin" / "fw").write_text("#!/bin/sh\n")
    return root


@pytest.fixture(scope="module")
def app():
    from web.app import create_app
    a = create_app()
    a.config["TESTING"] = True
    # Pages get far more context from their routes than these fixtures supply;
    # chainable undefined lets the template render around the parts under test.
    a.jinja_env.undefined = jinja2.ChainableUndefined
    return a


@pytest.fixture(params=["framework", "vendored"])
def root(request, tmp_path):
    return (_framework_fixture if request.param == "framework" else _vendored_fixture)(tmp_path)


def _hand_written_fw(text: str, root: Path) -> list[str]:
    """Every `bin/fw ` in text that the builder did not produce."""
    bad = []
    expected_prefix = user_command("", root) + " "
    for m in re.finditer(r"bin/fw ", text):
        start = m.end() - len(expected_prefix)
        if start < 0 or text[start:m.end()] != expected_prefix:
            bad.append(text[max(0, m.start() - 60):m.end() + 40])
    return bad


def test_app_global_is_the_builder(app):
    from web.shared import PROJECT_ROOT
    assert app.jinja_env.globals["fw_cmd"]("doctor") == user_command("doctor", str(PROJECT_ROOT))


@pytest.mark.parametrize("template", sorted(PAGES))
def test_page_prints_builder_commands(app, root, template):
    from flask import render_template
    ctx, commands = PAGES[template]
    saved = app.jinja_env.globals["fw_cmd"]
    app.jinja_env.globals["fw_cmd"] = lambda args="": user_command(args, str(root))
    try:
        with app.test_request_context("/"):
            text = html.unescape(render_template(template, project_root=str(root), **ctx))
    finally:
        app.jinja_env.globals["fw_cmd"] = saved
    for args in commands:
        assert user_command(args, str(root)) in text, (template, args)
    assert _hand_written_fw(text, root) == [], template
    if (root / ".agentic-framework").is_dir():
        assert ".agentic-framework/bin/fw " in text
        assert not re.search(r"(?<![\w./-])bin/fw ", text), template


def test_no_literal_bin_fw_in_templates():
    hits = [f"{p.name}:{i}" for p in (FRAMEWORK_ROOT / "web" / "templates").rglob("*.html")
            for i, line in enumerate(p.read_text(errors="replace").splitlines(), 1)
            if "bin/fw " in line]
    assert hits == []


def test_inception_refusal_texts_use_builder(root, monkeypatch):
    import web.blueprints.inception as inc
    monkeypatch.setattr(inc, "PROJECT_ROOT", root)
    want = user_command("task review T-9305", str(root))
    for text in (inc._silent_refusal("T-9305"), inc._filtered_refusal("T-9305")):
        assert want in text
        assert _hand_written_fw(text, root) == []


def test_decide_runner_recovery_text_uses_builder(root):
    from web.decide_runner import _printed_fw
    assert _printed_fw(root, "context generate-episodic T-9305") == \
        user_command("context generate-episodic T-9305", str(root))
