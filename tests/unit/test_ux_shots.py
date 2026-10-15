"""fw ux shots (T-4212) — planning without a browser, and capture when Playwright is here.

The planning half (widths, names, paths, refusals) runs everywhere. The capture
half needs Playwright and a Chromium binary; it skips with the reason named when
either is missing, so a host without a browser shows SKIPPED, never a silent pass.
"""
from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "agents" / "ux-review"))

import ux_shots as us  # noqa: E402


# ── widths ────────────────────────────────────────────────────────────────

def test_default_widths_are_the_t4202_trio():
    assert us.parse_widths(None) == [1024, 1440, 1920]
    assert us.parse_widths("") == [1024, 1440, 1920]


def test_custom_widths_keep_their_order():
    assert us.parse_widths("800, 1280 ,1600,1920") == [800, 1280, 1600, 1920]


@pytest.mark.parametrize("raw", ["1024,1440", "1024", "1024,1440,1440"])
def test_fewer_than_three_or_duplicate_widths_refused(raw):
    with pytest.raises(us.PlanError):
        us.parse_widths(raw)


def test_duplicate_width_message_names_the_width():
    with pytest.raises(us.PlanError, match="repeats width 1024"):
        us.parse_widths("1024,1024,1920")


@pytest.mark.parametrize("raw", ["1024,abc,1920", "1024,-1,1920", "1024,1.5,1920"])
def test_non_integer_widths_refused(raw):
    with pytest.raises(us.PlanError, match="not an integer"):
        us.parse_widths(raw)


@pytest.mark.parametrize("raw", ["100,1024,1920", "1024,1440,9000"])
def test_out_of_range_widths_refused(raw):
    with pytest.raises(us.PlanError, match="outside"):
        us.parse_widths(raw)


# ── names and paths ───────────────────────────────────────────────────────

def test_shot_path_follows_the_convention(tmp_path):
    p = us.shot_path(tmp_path, "T-4212", "toolbar", 1440)
    assert p == tmp_path / ".context" / "visual" / "T-4212" / "toolbar@1440.png"


@pytest.mark.parametrize("task", ["4212", "T-", "../T-1", "T-1/x", ""])
def test_bad_task_ids_refused(task):
    with pytest.raises(us.PlanError, match="T-NNNN"):
        us.validate_task(task)


@pytest.mark.parametrize("state", ["Toolbar", "a b", "../x", "", "-lead"])
def test_bad_state_names_refused(state):
    with pytest.raises(us.PlanError):
        us.validate_state(state)


def test_explicit_state_name_wins_over_url():
    assert us.parse_target("toolbar=http://127.0.0.1:9/tasks/T-1") == ("toolbar", "http://127.0.0.1:9/tasks/T-1")


def test_state_derived_from_file_stem():
    assert us.parse_target("file:///tmp/pages/Designer_View.html") == ("designer_view", "file:///tmp/pages/Designer_View.html")


def test_state_derived_from_last_path_segment():
    assert us.parse_target("http://h:3000/designer/Load")[0] == "load"


def test_query_string_with_equals_is_not_a_state_split():
    state, url = us.parse_target("http://h:3000/x?a=b")
    assert url == "http://h:3000/x?a=b"
    assert state == "x"


def test_unsupported_scheme_refused():
    with pytest.raises(us.PlanError, match="must be http"):
        us.parse_target("ftp://h/x")


# ── plan ──────────────────────────────────────────────────────────────────

def test_plan_is_states_times_widths(tmp_path):
    shots = us.plan(["a=http://h/a", "b=http://h/b"], [1024, 1440, 1920], tmp_path, "T-9")
    assert len(shots) == 6
    assert {(s.state, s.width) for s in shots} == {(st, w) for st in ("a", "b") for w in (1024, 1440, 1920)}
    assert all(s.path.parent == tmp_path / ".context" / "visual" / "T-9" for s in shots)


def test_plan_refuses_duplicate_state(tmp_path):
    with pytest.raises(us.PlanError, match="given twice"):
        us.plan(["a=http://h/1", "a=http://h/2"], [1024, 1440, 1920], tmp_path, "T-9")


def test_plan_refuses_no_targets(tmp_path):
    with pytest.raises(us.PlanError, match="no targets"):
        us.plan([], [1024, 1440, 1920], tmp_path, "T-9")


# ── CLI, no browser ───────────────────────────────────────────────────────

def test_plan_only_prints_paths_and_writes_nothing(tmp_path, capsys):
    rc = us.main(["T-9", "a=http://h/a", "--widths", "1024,1440,1920", "--root", str(tmp_path), "--plan-only"])
    out = capsys.readouterr().out.strip().splitlines()
    assert rc == us.EXIT_OK
    assert len(out) == 3
    assert not (tmp_path / ".context").exists()


def test_usage_error_exit_code(tmp_path, capsys):
    rc = us.main(["T-9", "a=http://h/a", "--widths", "1024,1440", "--root", str(tmp_path)])
    assert rc == us.EXIT_USAGE
    assert "requires at least 3" in capsys.readouterr().err


def test_missing_playwright_is_not_checked_not_pass(tmp_path, monkeypatch, capsys):
    def boom():
        raise us.NotChecked("Playwright is not installed in this interpreter (simulated)")

    monkeypatch.setattr(us, "_require_playwright", boom)
    rc = us.main(["T-9", "a=file:///tmp/a.html", "--root", str(tmp_path)])
    err = capsys.readouterr().err
    assert rc == us.EXIT_NOT_CHECKED
    assert "NOT CHECKED" in err
    assert "no screenshot was written" in err
    assert list((tmp_path / ".context").rglob("*.png")) == []


def test_import_error_on_playwright_maps_to_not_checked(monkeypatch):
    # A None entry in sys.modules makes `import` raise ImportError — Playwright "absent".
    monkeypatch.setitem(sys.modules, "playwright", None)
    monkeypatch.setitem(sys.modules, "playwright.sync_api", None)
    with pytest.raises(us.NotChecked, match="not installed"):
        us._require_playwright()


# ── capture with a real browser (skips with the reason named) ─────────────

def _browser_unavailable_reason() -> str | None:
    if importlib.util.find_spec("playwright") is None:
        return "Playwright is not installed in this interpreter"
    try:
        from playwright.sync_api import sync_playwright
        with sync_playwright() as p:
            b = p.chromium.launch()
            b.close()
    except Exception as exc:  # noqa: BLE001 — any launch failure means no browser here
        return f"Chromium cannot launch: {str(exc).splitlines()[0][:160]}"
    return None


_REASON = _browser_unavailable_reason()


@pytest.mark.skipif(_REASON is not None, reason=f"browser capture not exercised: {_REASON}")
def test_capture_writes_one_png_per_state_and_width(tmp_path, capsys):
    page_dir = tmp_path / "site"
    page_dir.mkdir()
    (page_dir / "toolbar.html").write_text(
        "<!doctype html><title>t</title><body><button>Load</button>"
        "<button>Check</button><button>Save</button></body>",
        encoding="utf-8",
    )
    root = tmp_path / "project"
    root.mkdir()
    url = (page_dir / "toolbar.html").as_uri()

    rc = us.main(["T-4212", f"toolbar={url}", "--widths", "1024,1440,1920", "--root", str(root)])

    assert rc == us.EXIT_OK
    for w in (1024, 1440, 1920):
        png = root / ".context" / "visual" / "T-4212" / f"toolbar@{w}.png"
        assert png.exists() and png.stat().st_size > 0
        assert png.read_bytes()[:8] == b"\x89PNG\r\n\x1a\n"
    assert "3 shot(s)" in capsys.readouterr().out
