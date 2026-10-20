"""T-4354 (GH #97): the Watchtower smoke test must probe the URL doctor resolved.

web/smoke_test.py hard-coded http://localhost:{port}, so on a host where
Watchtower binds one specific address (FW_HOST) every endpoint "failed" while
doctor's own /health check, which uses _watchtower_url, passed.
"""

import io
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class _Resp(io.BytesIO):
    status = 200

    def __enter__(self):
        return self

    def __exit__(self, *a):
        return False


def _stub(monkeypatch, smoke):
    calls = []

    def fake_urlopen(req, timeout=None):
        url = req if isinstance(req, str) else req.full_url
        calls.append(url)
        return _Resp(b"{}")

    monkeypatch.setattr(smoke.urllib.request, "urlopen", fake_urlopen)
    monkeypatch.setattr(smoke, "_discover_routes_from_app", lambda: (["/", "/tasks"], None))
    monkeypatch.setattr(smoke, "CRITICAL_ROUTES", {})
    monkeypatch.setattr(smoke, "wait_for_warmup", lambda base, **kw: {"state": "unknown"})
    return calls


def test_base_url_is_where_the_probes_go(monkeypatch):
    import web.smoke_test as smoke

    calls = _stub(monkeypatch, smoke)
    report = smoke.run_smoke_tests(port=3000, base_url="http://192.0.2.7:4567/")
    assert calls == ["http://192.0.2.7:4567/", "http://192.0.2.7:4567/tasks"]
    assert report["passed"] == 2 and report["failed"] == 0


def test_without_base_url_localhost_port_is_kept(monkeypatch):
    import web.smoke_test as smoke

    calls = _stub(monkeypatch, smoke)
    smoke.run_smoke_tests(port=3123)
    assert calls == ["http://localhost:3123/", "http://localhost:3123/tasks"]


def test_cli_accepts_url():
    src = (ROOT / "web" / "smoke_test.py").read_text()
    assert re.search(r'add_argument\(\s*"--url"', src)
    assert "base_url=args.url" in src


def test_doctor_passes_its_resolved_url_to_the_smoke_test():
    fw = (ROOT / "bin" / "fw").read_text()
    calls = [l for l in fw.splitlines() if "web/smoke_test.py" in l and "python3" in l]
    assert calls, "doctor smoke-test call not found"
    assert all('--url "$_doctor_wt_url"' in l for l in calls), calls
