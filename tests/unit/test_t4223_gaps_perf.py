"""T-4223: /gaps parses the register once, uses CSafeLoader, runs gauges concurrently."""
import sys
import time
from pathlib import Path

import pytest
import yaml

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO))

from lib import gaps as G  # noqa: E402


def _make_register(root: Path, n=20, watching=6, sleep=0.4):
    (root / ".context" / "project").mkdir(parents=True)
    (root / "tools").mkdir()
    (root / "tools" / "gauge.py").write_text(
        f"import time,json\ntime.sleep({sleep})\nprint(json.dumps({{'verdict':'READY'}}))\n"
    )
    lines = ["concerns:"]
    for i in range(n):
        lines += [
            f"- id: G-{i+1:03d}",
            f"  title: 'gap {i}'",
            f"  status: {'watching' if i < watching else 'closed'}",
        ]
        if i < watching:
            lines.append("  closure_check_command: python3 tools/gauge.py")
        lines += ["  evidence:"] + [f"  - 'item {k}: x'" for k in range(40)]
    (root / ".context" / "project" / "concerns.yaml").write_text("\n".join(lines) + "\n")


def test_csafeloader_parity_fixture_and_repo(tmp_path):
    _make_register(tmp_path)
    for path in (tmp_path / ".context/project/concerns.yaml",
                 REPO / ".context/project/concerns.yaml"):
        text = path.read_text()
        assert yaml.load(text, Loader=getattr(yaml, "CSafeLoader", yaml.SafeLoader)) == yaml.safe_load(text)
    assert G.load_concerns_yaml(tmp_path) == yaml.safe_load(
        (tmp_path / ".context/project/concerns.yaml").read_text())


def test_gauge_state_with_data_does_not_reparse(tmp_path, monkeypatch):
    _make_register(tmp_path, watching=1, sleep=0)
    data = G.load_concerns_yaml(tmp_path)
    monkeypatch.setattr(G, "load_concerns_yaml",
                        lambda *a, **k: pytest.fail("re-parsed"))
    st = G.gauge_state("G-001", project_root=tmp_path, data=data)
    assert st["verdict"] == "READY"
    # legacy call shape still parses on its own
    monkeypatch.undo()
    assert G.gauge_state("G-001", project_root=tmp_path)["verdict"] == "READY"


def test_gauge_states_concurrent_and_equal_to_sequential(tmp_path):
    _make_register(tmp_path, watching=6, sleep=0.5)
    data = G.load_concerns_yaml(tmp_path)
    ids = [f"G-{i:03d}" for i in range(1, 7)]
    t = time.time()
    par = G.gauge_states(ids, project_root=tmp_path, data=data)
    par_t = time.time() - t
    seq = {i: G.gauge_state(i, project_root=tmp_path, data=data) for i in ids}
    assert par == seq
    assert list(par) == ids
    assert par_t < 6 * 0.5 * 0.7  # well under the sequential 3 s


def test_gauge_states_drops_failures(tmp_path, monkeypatch):
    _make_register(tmp_path, watching=2, sleep=0)
    real = G.gauge_state

    def boom(gid, **k):
        if gid == "G-001":
            raise RuntimeError("x")
        return real(gid, **k)

    monkeypatch.setattr(G, "gauge_state", boom)
    out = G.gauge_states(["G-001", "G-002"], project_root=tmp_path)
    assert list(out) == ["G-002"]
    assert G.gauge_states([], project_root=tmp_path) == {}


def test_gaps_route_parses_once_and_is_fast(tmp_path, monkeypatch):
    _make_register(tmp_path, n=20, watching=6, sleep=0.5)
    monkeypatch.setenv("PROJECT_ROOT", str(tmp_path))
    for m in [m for m in sys.modules if m == "web" or m.startswith("web.")]:
        del sys.modules[m]
    sys.path.insert(0, str(REPO))
    from web.app import app
    import web.blueprints.discovery as D

    loads = []
    orig = yaml.load
    monkeypatch.setattr(yaml, "load", lambda *a, **k: (loads.append(1), orig(*a, **k))[1])
    import lib.gaps as lg
    monkeypatch.setattr(lg, "load_concerns_yaml",
                        lambda *a, **k: pytest.fail("per-gauge re-parse"))
    t = time.time()
    r = app.test_client().get("/gaps")
    el = time.time() - t
    assert r.status_code == 200
    concerns_loads = len(loads)
    assert concerns_loads == 1, concerns_loads
    assert el < 6 * 0.5 * 0.8 + 1.5
    assert b"G-001" in r.data
