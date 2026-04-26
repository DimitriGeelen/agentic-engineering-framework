"""Unit tests for /reviewer/audit Watchtower route (T-1486).

Exercises the blueprint's _latest_yaml helper and the route's behaviour
when YAML files are missing, malformed, or present.
"""

from __future__ import annotations

import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(ROOT))


def _make_yaml(directory: Path, name: str, payload: dict) -> Path:
    directory.mkdir(parents=True, exist_ok=True)
    p = directory / name
    p.write_text(yaml.safe_dump(payload))
    return p


def test_latest_yaml_picks_lexicographically_newest(tmp_path):
    from web.blueprints.reviewer import _latest_yaml

    audit_dir = tmp_path / "audits"
    _make_yaml(audit_dir, "2026-04-24-pass-a.yaml", {"day": "old"})
    _make_yaml(audit_dir, "2026-04-26-pass-a.yaml", {"day": "new"})
    _make_yaml(audit_dir, "2026-04-25-pass-a.yaml", {"day": "mid"})

    p, parsed = _latest_yaml(audit_dir, "pass-a")
    assert p.name == "2026-04-26-pass-a.yaml"
    assert parsed["day"] == "new"


def test_latest_yaml_returns_none_when_missing(tmp_path):
    from web.blueprints.reviewer import _latest_yaml

    p, parsed = _latest_yaml(tmp_path / "does-not-exist", "pass-a")
    assert p is None
    assert parsed is None


def test_latest_yaml_returns_none_when_no_match(tmp_path):
    from web.blueprints.reviewer import _latest_yaml

    audit_dir = tmp_path / "audits"
    _make_yaml(audit_dir, "2026-04-26-pass-b.yaml", {"x": 1})

    p, parsed = _latest_yaml(audit_dir, "pass-a")
    assert p is None
    assert parsed is None


def test_latest_yaml_does_not_confuse_pass_a_with_pass_a_baseline(tmp_path):
    from web.blueprints.reviewer import _latest_yaml

    audit_dir = tmp_path / "audits"
    _make_yaml(audit_dir, "2026-04-26-pass-a-baseline.yaml", {"mode": "baseline"})
    _make_yaml(audit_dir, "2026-04-25-pass-a.yaml", {"mode": "drift"})

    p, parsed = _latest_yaml(audit_dir, "pass-a")
    # `*-pass-a.yaml` matches BOTH (-baseline ends with -baseline.yaml not -pass-a.yaml)
    # so this should pick only the drift file.
    assert p.name == "2026-04-25-pass-a.yaml"
    assert parsed["mode"] == "drift"


def test_latest_yaml_handles_malformed_yaml(tmp_path):
    from web.blueprints.reviewer import _latest_yaml

    audit_dir = tmp_path / "audits"
    audit_dir.mkdir()
    (audit_dir / "2026-04-26-pass-a.yaml").write_text("{not: valid: yaml: at all")

    p, parsed = _latest_yaml(audit_dir, "pass-a")
    assert p is not None  # path returned
    assert parsed is None  # parse failed cleanly


# ───────────────── Flask route smoke ─────────────────


def _make_client(project_root: Path, monkeypatch):
    """Use the real Watchtower app, monkeypatched to point at a test dir."""
    import web.shared
    import web.blueprints.reviewer as reviewer_bp

    (project_root / ".tasks" / "active").mkdir(parents=True, exist_ok=True)
    (project_root / ".tasks" / "completed").mkdir(parents=True, exist_ok=True)
    (project_root / ".context" / "working").mkdir(parents=True, exist_ok=True)

    monkeypatch.setattr(web.shared, "PROJECT_ROOT", project_root)
    monkeypatch.setattr(reviewer_bp, "PROJECT_ROOT", project_root)
    monkeypatch.setenv("PROJECT_ROOT", str(project_root))

    from web.app import app
    app.config["TESTING"] = True
    return app.test_client()


def test_route_renders_when_no_audit_files(tmp_path, monkeypatch):
    client = _make_client(tmp_path, monkeypatch)
    resp = client.get("/reviewer/audit")
    assert resp.status_code == 200
    body = resp.get_data(as_text=True)
    assert "Reviewer Audit" in body
    assert "No Pass A audit YAML yet" in body
    assert "No Pass B audit YAML yet" in body


def test_route_renders_with_pass_a_drifted(tmp_path, monkeypatch):
    audit_dir = tmp_path / ".context" / "audits" / "reviewer"
    _make_yaml(audit_dir, "2026-04-26-pass-a.yaml", {
        "scan_date": "2026-04-26",
        "scan_timestamp": "2026-04-26T07:00:00Z",
        "tasks_scanned": 2,
        "limit": None,
        "totals": {"STABLE": 1, "DRIFTED": 1, "NO-BASELINE": 0, "NO-VERIFICATION": 0},
        "per_task": [
            {"task_id": "T-9001", "verdict": "STABLE", "has_drift": False,
             "n_unchanged": 1, "n_changed": 0, "n_missing": 0, "n_no_baseline": 0,
             "changed_files": [], "missing_files": []},
            {"task_id": "T-9002", "verdict": "DRIFTED", "has_drift": True,
             "n_unchanged": 0, "n_changed": 1, "n_missing": 0, "n_no_baseline": 0,
             "changed_files": ["a.txt"], "missing_files": []},
        ],
    })

    client = _make_client(tmp_path, monkeypatch)
    resp = client.get("/reviewer/audit")
    assert resp.status_code == 200
    body = resp.get_data(as_text=True)
    assert "T-9002" in body
    assert "/review/T-9002" in body  # link present
    assert "a.txt" in body


def test_route_renders_with_pass_b_failure(tmp_path, monkeypatch):
    audit_dir = tmp_path / ".context" / "audits" / "reviewer"
    _make_yaml(audit_dir, "2026-04-26-pass-b.yaml", {
        "scan_date": "2026-04-26",
        "scan_timestamp": "2026-04-26T07:05:00Z",
        "tasks_scanned": 1,
        "limit": None,
        "totals": {"PASS": 0, "FAIL": 1, "NO-VERIFICATION": 0, "ERROR": 0},
        "per_task": [
            {"task_id": "T-9010", "sha": "abc12345", "overall": "FAIL",
             "n_pass": 1, "n_fail": 1, "n_skipped": 0, "n_error": 0, "error": None},
        ],
        "errors": [],
    })

    client = _make_client(tmp_path, monkeypatch)
    resp = client.get("/reviewer/audit")
    assert resp.status_code == 200
    body = resp.get_data(as_text=True)
    assert "T-9010" in body
    assert "FAIL" in body
    assert "abc12345" in body


def test_overrides_route_still_works_no_regression(tmp_path, monkeypatch):
    """Adding /reviewer/audit must not break /reviewer/overrides."""
    client = _make_client(tmp_path, monkeypatch)
    resp = client.get("/reviewer/overrides")
    assert resp.status_code == 200
