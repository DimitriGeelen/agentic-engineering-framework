"""T-3999 — /arcs embeds an arcs-only value/cost matrix (the arc points of /bvp, server-side SVG).

Isolated PROJECT_ROOT with two arcs carrying direct-confirmed bvp_scores + cost_estimate, so the
matrix has known points without depending on the live corpus.
"""

import importlib
import re
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]

ARC = """id: {id}
slug: {slug}
name: {name}
status: {status}
headline_mechanic: x
bvp_scores: {{D1: {d1}, D2: 3, D3: 2, D4: 1}}
cost_estimate: {{blast_radius: {br}, tier: 2, effort: 4}}
"""


@pytest.fixture
def app_mod(tmp_path, monkeypatch):
    (tmp_path / ".context" / "arcs").mkdir(parents=True)
    (tmp_path / ".context" / "working").mkdir(parents=True)
    (tmp_path / ".tasks" / "active").mkdir(parents=True)
    (tmp_path / ".tasks" / "completed").mkdir(parents=True)
    (tmp_path / ".framework.yaml").write_text(f"framework_path: {REPO_ROOT}\n")
    (tmp_path / "policy").mkdir()
    (tmp_path / "policy" / "value-drivers.yaml").write_text(
        "protected_drivers:\n" + "".join(f"  - {{id: D{i}, weight: 3}}\n" for i in range(1, 5)))
    for i, (slug, d1, br, status) in enumerate([("alpha", 5, 2, "in-progress"),
                                                ("beta", 1, 8, "closed")], start=1):
        (tmp_path / ".context" / "arcs" / f"{slug}.yaml").write_text(
            ARC.format(id=f"arc-90{i}", slug=slug, name=slug.title(), status=status, d1=d1, br=br))
    monkeypatch.setenv("PROJECT_ROOT", str(tmp_path))
    import web.shared
    import web.blueprints.bvp
    import web.blueprints.arcs
    importlib.reload(web.shared)
    importlib.reload(web.blueprints.bvp)
    importlib.reload(web.blueprints.arcs)
    import web.app
    importlib.reload(web.app)
    app = web.app.create_app()
    app.config["TESTING"] = True
    return app, web.blueprints.arcs


def _get(app, path="/arcs"):
    with app.test_client() as c:
        r = c.get(path)
    return r.status_code, r.get_data(as_text=True)


def test_arcs_page_has_one_dot_per_scored_arc_linking_to_the_arc(app_mod):
    app, _ = app_mod
    code, html = _get(app)
    assert code == 200
    assert 'id="arc-value-matrix"' in html
    dots = re.findall(r'<circle[^>]*data-arc="([^"]+)"', html)
    assert sorted(dots) == ["alpha", "beta"]
    assert 'href="/arcs/alpha"' in html and 'href="/arcs/beta"' in html
    assert 'href="/bvp"' in html


def test_same_numbers_as_bvp(app_mod):
    app, arcs = app_mod
    from web.blueprints import bvp
    want = {p["slug"]: (p["bvp_norm"], p["cost"])
            for p in bvp._collect_arc_points(bvp._driver_weights(bvp._load_policy()))}
    got = {d["slug"]: (d["norm"], d["cost"]) for d in arcs._arc_matrix()["dots"]}
    assert got == want


def test_high_value_low_cost_arc_sits_top_left_of_the_other(app_mod):
    _, arcs = app_mod
    m = arcs._arc_matrix()
    d = {x["slug"]: x for x in m["dots"]}
    assert d["alpha"]["x"] < d["beta"]["x"] and d["alpha"]["y"] < d["beta"]["y"]


def test_list_view_shows_the_matrix_too(app_mod):
    app, _ = app_mod
    code, html = _get(app, "/arcs?view=list")
    assert code == 200 and 'id="arc-value-matrix"' in html


def test_a_failing_computation_never_breaks_the_page(app_mod, monkeypatch):
    app, arcs = app_mod
    from web.blueprints import bvp

    def boom(_w):
        raise RuntimeError("policy unreadable")
    monkeypatch.setattr(bvp, "_collect_arc_points", boom)
    arcs._matrix_cache.update(at=0.0, val=None)
    code, html = _get(app)
    assert code == 200
    assert "value matrix unavailable: policy unreadable" in html
    assert "data-arc=" not in html


def test_the_matrix_styles_use_theme_tokens_only():
    tpl = (REPO_ROOT / "web" / "templates" / "arcs_index.html").read_text()
    block = tpl[tpl.index("T-3999"):tpl.index("{% if kanban_mode %}")]
    assert not re.search(r"#[0-9a-fA-F]{3,8}\b", block), "hex colour literal in the matrix block"


# ── T-4009: reviewer findings (coincident dots, leaders, colour source) ──────────────────────

def test_t4009_coincident_arcs_get_their_own_click_target(app_mod, tmp_path):
    app, arcs = app_mod
    import os
    root = Path(os.environ["PROJECT_ROOT"])
    # a third arc at exactly alpha's value and cost
    (root / ".context" / "arcs" / "gamma.yaml").write_text(
        ARC.format(id="arc-903", slug="gamma", name="Gamma", status="in-progress", d1=5, br=2))
    arcs._matrix_cache.update(at=0.0, val=None)
    d = {x["slug"]: x for x in arcs._arc_matrix()["dots"]}
    assert (d["alpha"]["x"], d["alpha"]["y"]) != (d["gamma"]["x"], d["gamma"]["y"])
    assert abs(d["alpha"]["x"] - d["gamma"]["x"]) >= 6
    assert d["alpha"]["leader"] or d["gamma"]["leader"]       # the second label moved: leader


def test_t4009_matrix_colours_are_fixed_on_the_section_not_inside_the_link():
    tpl = (REPO_ROOT / "web" / "templates" / "arcs_index.html").read_text()
    block = tpl[tpl.index("T-3999"):tpl.index("{% if kanban_mode %}")]
    assert "--am-ink: var(--wt-text" in block
    for cls in (".am-dot {", ".am-name {", ".am-label {"):
        rule = block[block.index(cls):block.index("}", block.index(cls))]
        assert "var(--am-ink)" in rule and "--pico-color" not in rule and "--pico-primary" not in rule


def test_t4009_reviewer_badges_are_tinted_not_white_on_token():
    tpl = (REPO_ROOT / "web" / "templates" / "arc_detail.html").read_text()
    seg = tpl[tpl.index("Reviewer: PASS") - 600:tpl.index("Reviewer: FAIL") + 50]
    assert seg.count("color-mix(in srgb, var(--wt-") == 2
    assert "color: #fff" not in seg
