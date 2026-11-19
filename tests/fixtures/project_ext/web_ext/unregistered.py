"""Fixture: sits in the folder but is not in the register, so it is never loaded."""
from flask import Blueprint

bp = Blueprint("unregistered_ext", __name__)


@bp.route("/unregistered")
def unregistered():
    return "UNREGISTERED-MARKER"
