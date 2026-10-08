"""T-4000 — the arc page shows each driver's name beside its code (D1, F3), from the same
policy names /bvp uses; a driver with no name falls back to its code alone."""

import importlib
import re
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]


@pytest.fixture
def client(tmp_path, monkeypatch):
    for d in (".context/arcs", ".context/working", ".tasks/active", ".tasks/completed", "policy"):
        (tmp_path / d).mkdir(parents=True)
    (tmp_path / ".framework.yaml").write_text(f"framework_path: {REPO_ROOT}\n")
    (tmp_path / "policy" / "value-drivers.yaml").write_text(
        "protected_drivers:\n"
        "  - {id: D1, name: Antifragility, weight: 5}\n"
        "  - {id: D2, weight: 3}\n"
        "free_drivers:\n"
        "  - {id: F3, name: V_PROMPT_QUALITY, weight: 2}\n")
    (tmp_path / ".context" / "arcs" / "alpha.yaml").write_text(
        "id: arc-901\nslug: alpha\nname: Alpha\nstatus: in-progress\nheadline_mechanic: x\n"
        "bvp_scores: {D1: 4, D2: 2}\ncost_estimate: {blast_radius: 2, tier: 2, effort: 4}\n")
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
    with app.test_client() as c:
        yield c


def test_named_driver_shows_its_name_beside_the_code(client):
    r = client.get("/arcs/alpha")
    html = r.get_data(as_text=True)
    assert r.status_code == 200
    # the inline "Drivers:" list and the breakdown table
    assert "<code>D1</code> Antifragility = 5" in html
    assert re.search(r"<td><code>D1</code> Antifragility</td>", html)


def test_unnamed_driver_falls_back_to_its_code(client):
    html = client.get("/arcs/alpha").get_data(as_text=True)
    assert "<code>D2</code> = 3" in html
    assert re.search(r"<td><code>D2</code></td>", html)


def test_handler_key_names_are_humanised_for_display(client):
    html = client.get("/arcs/alpha").get_data(as_text=True)
    assert "<code>F3</code> Prompt Quality = 2" in html and "V_PROMPT_QUALITY" not in html
