"""Regression: load_latest_audit must skip non-date YAML (T-1307)."""

import sys
from pathlib import Path

import pytest

FRAMEWORK_ROOT = Path(__file__).resolve().parents[2]
if str(FRAMEWORK_ROOT) not in sys.path:
    sys.path.insert(0, str(FRAMEWORK_ROOT))


def _prepare(tmp_path: Path):
    (tmp_path / ".context" / "audits").mkdir(parents=True)
    return tmp_path


def test_non_date_yaml_is_ignored(tmp_path, monkeypatch):
    """upgrades.yaml sorts after 2026-*.yaml; glob must not include it."""
    project = _prepare(tmp_path)
    audits = project / ".context" / "audits"
    (audits / "2026-04-18.yaml").write_text(
        "timestamp: '2026-04-18T10:00:00Z'\nsummary: {pass: 10, warn: 1, fail: 0}\nfindings: []\n"
    )
    # Non-date YAML with no 'summary' key — this used to win the sort.
    (audits / "upgrades.yaml").write_text("version: 1.0.0\nentries: []\n")

    monkeypatch.setenv("PROJECT_ROOT", str(project))
    for mod in ("web.shared", "web.config"):
        sys.modules.pop(mod, None)
    from web.shared import load_latest_audit  # noqa: E402

    ts, summary, _ = load_latest_audit()
    assert ts == "2026-04-18T10:00:00Z"
    assert summary.get("pass") == 10


def test_returns_empty_when_only_non_date_yaml(tmp_path, monkeypatch):
    project = _prepare(tmp_path)
    (project / ".context" / "audits" / "upgrades.yaml").write_text("version: 1\n")
    monkeypatch.setenv("PROJECT_ROOT", str(project))
    for mod in ("web.shared", "web.config"):
        sys.modules.pop(mod, None)
    from web.shared import load_latest_audit  # noqa: E402

    ts, summary, findings = load_latest_audit()
    assert ts is None
    assert summary == {}
    assert findings == []
