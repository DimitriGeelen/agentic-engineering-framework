"""T-4391: `fw ux shots T-X state=@steps.yaml` — interaction states (after a click, a fill, a
hover) are captured by ux_shots itself from a declarative step list, the steps file is hashed
into a per-state capture manifest, and the judge carries that hash into the signed review run.

Parser, manifest and judge/ledger legs run everywhere. The browser leg (a file:// page whose
button reveals an element) needs Playwright + Chromium; it skips with the reason named when
either is missing, so a host without a browser shows SKIPPED, never a silent pass.
"""
from __future__ import annotations

import hashlib
import importlib.util
import json
import sys
from pathlib import Path

import pytest

_HERE = Path(__file__).resolve().parent
REPO = _HERE.parents[1]
sys.path.insert(0, str(_HERE))
sys.path.insert(0, str(REPO / "agents" / "ux-review"))

import ux_shots as us  # noqa: E402
from lib import verdict_ledger as vl  # noqa: E402
from lib.reviewer import judge_cli  # noqa: E402
from _review_runtime import hermetic_review_env  # noqa: E402,F401  (T-4205: autouse)
from _review_runtime import register_run as _reg  # noqa: E402
from _visual_evidence import WIDTHS, add_checklist  # noqa: E402
from t3580_judge_cli_test import TID, FakeWorker, _judge, repo  # noqa: E402,F401
from t4214_visual_evidence_test import _page_capture, _render_task  # noqa: E402

GOOD = """\
- goto: http://127.0.0.1:1/map
- click: "#check"
- fill: {selector: "#q", text: "hello world"}
- press: Enter
- hover: ".row"
- wait-for: "#result"
  timeout: 5000
- wait-for: {text: "Done"}
"""


def _steps(tmp_path: Path, body: str, name: str = "checked.yaml") -> Path:
    f = tmp_path / name
    f.write_text(body, encoding="utf-8")
    return f


# ── parser: a closed allowlist, no code ───────────────────────────────────

def test_good_steps_parse_into_the_six_ops(tmp_path):
    steps = us.load_steps(_steps(tmp_path, GOOD))
    assert [s["op"] for s in steps] == ["goto", "click", "fill", "press", "hover", "wait-for", "wait-for"]
    assert steps[2] == {"op": "fill", "selector": "#q", "text": "hello world"}
    assert steps[5]["timeout"] == 5000 and steps[6]["text"] == "Done"


def test_steps_target_names_the_state_and_keeps_the_hash(tmp_path):
    f = _steps(tmp_path, GOOD)
    shots = us.plan([f"checked=@{f}"], [1024, 1440, 1920], tmp_path, "T-9")
    assert [s.state for s in shots] == ["checked"] * 3
    assert all(s.steps_sha256 == hashlib.sha256(f.read_bytes()).hexdigest() for s in shots)
    assert shots[0].url == "http://127.0.0.1:1/map"
    bare = us.plan([f"@{f}"], [1024, 1440, 1920], tmp_path, "T-9")
    assert bare[0].state == "checked"                        # from the file stem


@pytest.mark.parametrize("body,match", [
    ("- eval: alert(1)\n", "not an allowed step"),
    ("- goto: http://h/\n- evaluate: 'x'\n", "not an allowed step"),
    ("- click: '#a'\n", "must start with goto"),
    ("- goto: javascript:alert(1)\n", "http, https or file"),
    ("- goto: http://h/\n- fill: '#q'\n", "fill"),
    ("- goto: http://h/\n- click: '#a'\n  force: true\n", "unknown key"),
    ("- goto: http://h/\n- click: '#a'\n  timeout: -5\n", "timeout"),
    ("- goto: http://h/\n- click: ''\n", "click"),
    ("- goto: http://h/\n  click: '#a'\n", "exactly one"),
    ("[]\n", "no steps"),
    ("goto: http://h/\n", "list"),
    ("- goto: http://h/\n- wait-for: {selector: '#a', text: 'b'}\n", "wait-for"),
])
def test_bad_steps_are_refused(tmp_path, body, match):
    with pytest.raises(us.PlanError, match=match):
        us.load_steps(_steps(tmp_path, body))


def test_missing_steps_file_is_a_usage_error(tmp_path, capsys):
    rc = us.main(["T-9", f"x=@{tmp_path}/nope.yaml", "--root", str(tmp_path), "--plan-only"])
    assert rc == us.EXIT_USAGE
    assert "steps file" in capsys.readouterr().err


def test_url_targets_are_unchanged(tmp_path):
    shots = us.plan(["a=http://h/a"], [1024, 1440, 1920], tmp_path, "T-9")
    assert shots[0].url == "http://h/a" and shots[0].steps is None and shots[0].steps_sha256 == ""
    assert shots[0].path == tmp_path / ".context/visual/T-9/a@1024.png"


# ── manifest: what produced each image ────────────────────────────────────

def _fake_capture(shots):
    """A browser stand-in: writes each planned PNG so the manifest can be checked."""
    for s in shots:
        s.path.parent.mkdir(parents=True, exist_ok=True)
        s.path.write_bytes(b"png-" + s.state.encode() + str(s.width).encode())
    return [s.path for s in shots]


def test_manifest_records_steps_hash_and_each_shot(tmp_path, monkeypatch):
    f = _steps(tmp_path, GOOD)
    monkeypatch.setattr(us, "capture", _fake_capture)
    rc = us.main(["T-9", f"checked=@{f}", "u=http://h/u", "--root", str(tmp_path)])
    assert rc == us.EXIT_OK
    m = json.loads((tmp_path / ".context/visual/T-9/checked.capture.json").read_text())
    assert m["source"] == "steps" and m["steps_sha256"] == hashlib.sha256(f.read_bytes()).hexdigest()
    assert [x["width"] for x in m["shots"]] == [1024, 1440, 1920]
    assert m["shots"][0]["path"] == ".context/visual/T-9/checked@1024.png"
    assert m["shots"][0]["sha256"] == hashlib.sha256(b"png-checked1024").hexdigest()
    u = json.loads((tmp_path / ".context/visual/T-9/u.capture.json").read_text())
    assert u["source"] == "url" and u["url"] == "http://h/u" and not u.get("steps_sha256")


# ── judge + ledger: the hash rides in the signed run ──────────────────────

def _steps_state(repo_path: Path, tf: Path, monkeypatch) -> Path:
    add_checklist(tf, repo_path, TID)                       # state "page", shots at every width
    f = _steps(repo_path, GOOD.replace("http://127.0.0.1:1/map", "http://h/"), "page.yaml")
    monkeypatch.setattr(us, "capture", _fake_capture)
    assert us.main([TID, f"page=@{f}", "--root", str(repo_path)]) == us.EXIT_OK
    return f


def test_judge_carries_steps_hash_into_the_signed_run(repo, monkeypatch):
    tf = _render_task(repo)
    f = _steps_state(repo, tf, monkeypatch)
    ev = judge_cli._gather_visual(repo, TID, judge_cli._load_task(TID, repo))
    assert ev["problems"] == []
    want = hashlib.sha256(f.read_bytes()).hexdigest()
    assert [s["steps_sha256"] for s in ev["shots"]] == [want] * 3
    res = _judge(repo, dispatcher=FakeWorker("green"), capture=_page_capture)
    run = next(r for r in vl._read(vl.RUNS, repo) if r.get("kind") == "run")
    assert [s["steps_sha256"] for s in run["visual"]["shots"]] == [want] * 3
    assert run.get("sig")
    assert res["outcomes"] == {1: "green"}                    # eligible exactly as a URL state


def test_steps_file_edited_after_capture_is_a_problem(repo, monkeypatch):
    tf = _render_task(repo)
    f = _steps_state(repo, tf, monkeypatch)
    f.write_text(f.read_text() + "- click: '#other'\n")
    ev = judge_cli._gather_visual(repo, TID, judge_cli._load_task(TID, repo))
    assert any("steps file" in p and "changed" in p for p in ev["problems"])


def test_shot_replaced_after_capture_is_a_problem(repo, monkeypatch):
    tf = _render_task(repo)
    _steps_state(repo, tf, monkeypatch)
    (repo / ".context/visual" / TID / "page@1440.png").write_bytes(b"hand-made")
    ev = judge_cli._gather_visual(repo, TID, judge_cli._load_task(TID, repo))
    assert any("1440" in p and "not the one" in p for p in ev["problems"])


def test_malformed_steps_hash_in_a_run_cannot_back_a_green(repo):
    _render_task(repo)
    shot = repo / "s.png"
    shot.write_bytes(b"x")
    sha = vl._hash_path(shot)
    _reg(f"run-{TID}-bad", TID, acs=[1], rung="rung-1-same-vendor-independent",
         seats=[{"seat": "claude", "vendor": "claude"}], required_vendors=1,
         pages={"1": ["/review"]}, captures=[{"page": "/review", "ok": True, "sha256": sha, "error": ""}],
         visual={"widths": list(WIDTHS), "problems": [],
                 "shots": [{"state": "page", "width": w, "path": "s.png", "sha256": sha,
                            "steps_sha256": "not-a-hash"} for w in WIDTHS]}, root=repo)
    run = next(r for r in vl._read(vl.RUNS, repo) if r.get("run_id") == f"run-{TID}-bad")
    assert run["visual"]["shots"][0]["steps_sha256"] == "not-a-hash"   # kept, signed, then judged
    fault = vl._visual_fault(run["visual"], {sha})
    assert fault and fault[0] == "visual-missing" and "steps" in fault[1]
    good = dict(run["visual"], shots=[dict(s, steps_sha256="a" * 64) for s in run["visual"]["shots"]])
    assert vl._visual_fault(good, {sha}) is None              # a well-formed hash: same as a URL shot


# ── a real browser: a click reveals an element ────────────────────────────

def _browser_unavailable_reason() -> str | None:
    if importlib.util.find_spec("playwright") is None:
        return "Playwright is not installed in this interpreter"
    try:
        from playwright.sync_api import sync_playwright
        with sync_playwright() as p:
            p.chromium.launch().close()
    except Exception as exc:  # noqa: BLE001
        return f"Chromium cannot launch: {str(exc).splitlines()[0][:160]}"
    return None


_REASON = _browser_unavailable_reason()

PAGE = ("<!doctype html><title>t</title><body style='margin:0;background:#fff'>"
        "<button id='check' onclick=\"document.getElementById('r').style.display='block'\">Check</button>"
        "<div id='r' style='display:none;width:600px;height:400px;background:#c00'>Result</div></body>")


@pytest.mark.skipif(_REASON is not None, reason=f"browser capture not exercised: {_REASON}")
def test_click_reveals_the_element_in_the_capture(tmp_path):
    site = tmp_path / "site"
    site.mkdir()
    (site / "map.html").write_text(PAGE, encoding="utf-8")
    url = (site / "map.html").as_uri()
    f = _steps(tmp_path, f"- goto: {url}\n- click: '#check'\n- wait-for: '#r'\n  timeout: 3000\n")
    root = tmp_path / "project"
    root.mkdir()
    assert us.main(["T-9", f"before={url}", f"after=@{f}", "--root", str(root)]) == us.EXIT_OK
    d = root / ".context/visual/T-9"
    for w in (1024, 1440, 1920):
        assert (d / f"after@{w}.png").read_bytes()[:8] == b"\x89PNG\r\n\x1a\n"
        assert (d / f"after@{w}.png").read_bytes() != (d / f"before@{w}.png").read_bytes()
    m = json.loads((d / "after.capture.json").read_text())
    assert m["steps_sha256"] == hashlib.sha256(f.read_bytes()).hexdigest()


@pytest.mark.skipif(_REASON is not None, reason=f"browser capture not exercised: {_REASON}")
def test_a_failing_step_is_not_checked_and_names_the_step(tmp_path, capsys):
    site = tmp_path / "site"
    site.mkdir()
    (site / "map.html").write_text(PAGE, encoding="utf-8")
    f = _steps(tmp_path, f"- goto: {(site / 'map.html').as_uri()}\n- click: '#absent'\n  timeout: 500\n")
    rc = us.main(["T-9", f"x=@{f}", "--root", str(tmp_path / "p")])
    assert rc == us.EXIT_NOT_CHECKED
    assert "step 2 (click" in capsys.readouterr().err
    assert not list((tmp_path / "p").rglob("*.png"))
