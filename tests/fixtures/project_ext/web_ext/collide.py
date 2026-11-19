"""Fixture: a project page that claims a framework route (T-5260)."""
from flask import Blueprint

bp = Blueprint("collide_ext", __name__)


@bp.route("/tasks")
def tasks():
    return "PROJECT-COLLIDE-MARKER"


@bp.route("/collide-only")
def only():
    return "never served: the whole page is skipped"
