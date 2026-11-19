"""Fixture project page (T-5260): template, static file and helper from the project."""
from flask import Blueprint, url_for

import hosts_helper  # a project helper module beside this file
from web.shared import render_page

bp = Blueprint("hosts_ext", __name__)


@bp.route("/hosts")
def hosts():
    return render_page("hosts_ext.html", hosts=hosts_helper.host_rows(),
                       css_url=url_for("hosts_ext.static", filename="hosts_ext.css"))


@bp.route("/hosts/shadow")
def shadow():
    # The project ships its own templates/cron.html; the framework's must win.
    return render_page("cron.html", total=0, active_count=0, paused_count=0, jobs=[])
