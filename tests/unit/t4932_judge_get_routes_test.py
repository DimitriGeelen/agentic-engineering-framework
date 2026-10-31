"""T-4932: `fw reviewer judge` required a screenshot of `/api/task/create`, a POST-only
route (405 on GET), so both seats judging T-4904 returned not-evaluated. Only routes a
GET can render belong in the page plan."""
from __future__ import annotations

import sys
from pathlib import Path

_HERE = Path(__file__).resolve().parent
_ROOT = _HERE.parent.parent
sys.path.insert(0, str(_ROOT))

from lib.reviewer import judge_cli  # noqa: E402

BLUEPRINT = '''
from flask import Blueprint
bp = Blueprint("x", __name__)

@bp.route("/plain")
def plain(): ...

@bp.route("/both", methods=["GET", "POST"])
def both(): ...

@bp.route("/post-only", methods=["POST"])
def post_only(): ...

@bp.route(
    "/split-post",
    methods=["POST", "DELETE"],
)
def split_post(): ...

@bp.route("/tuple-get", methods=('get',))
def tuple_get(): ...

@bp.route("/item/<int:n>")
def item(n): ...
'''


def test_get_routes_keeps_get_and_default_drops_post_only():
    # A path with a <converter> has no URL to capture; the route pattern skips it as before.
    assert judge_cli._get_routes(BLUEPRINT) == ["/plain", "/both", "/tuple-get"]


def test_pages_for_changed_blueprint_skips_post_only(tmp_path):
    (tmp_path / ".context/working").mkdir(parents=True)
    (tmp_path / ".context/working/watchtower.url").write_text("http://127.0.0.1:3000\n")
    (tmp_path / "web/blueprints").mkdir(parents=True)
    (tmp_path / "web/blueprints/x.py").write_text(BLUEPRINT)
    pages = judge_cli._pages_for(tmp_path, "T-9999", "changed web/blueprints/x.py", [])
    assert pages == ["/plain", "/both", "/tuple-get"]


def test_this_repo_tasks_blueprint_plan_has_no_api_task_create():
    src = (_ROOT / "web/blueprints/tasks.py").read_text()
    routes = judge_cli._get_routes(src)
    assert "/api/task/create" not in routes
    assert routes, "tasks.py still has GET routes"
