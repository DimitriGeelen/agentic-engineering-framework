"""T-2432 — pin proxy-policy emit/install/drift (arc-013, design §4c).

Covers the emitted-but-not-installed drift class (the sibling of cron registry→generated
and tool-set→manifest): drift is by CONTENT (sha256), absent-deployed is SKIP not FAIL,
and the emit spec is text-only (the agent never installs).
"""
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(PROJECT_ROOT))

from lib import govd_policy as P  # noqa: E402


def test_drift_not_installed_when_deployed_absent(tmp_path):
    src = tmp_path / "proxy-policy.yaml"
    src.write_text("invariants: {}\n")
    d = P.drift_status(src, tmp_path / "nope" / "deployed.yaml")
    assert d["state"] == "not_installed"          # SKIP, never a failure (install is human-gated)
    assert d["deployed_sha"] is None


def test_drift_ok_when_deployed_matches(tmp_path):
    src = tmp_path / "src.yaml"
    dep = tmp_path / "dep.yaml"
    src.write_text("invariants:\n  deny_tools: []\n")
    dep.write_text("invariants:\n  deny_tools: []\n")
    d = P.drift_status(src, dep)
    assert d["state"] == "ok"
    assert d["source_sha"] == d["deployed_sha"]


def test_drift_detected_when_source_edited(tmp_path):
    src = tmp_path / "src.yaml"
    dep = tmp_path / "dep.yaml"
    dep.write_text("invariants:\n  deny_tools: []\n")          # deployed (old)
    src.write_text("invariants:\n  deny_tools: [DangerousTool]\n")  # source edited
    d = P.drift_status(src, dep)
    assert d["state"] == "drift"
    assert d["source_sha"] != d["deployed_sha"]


def test_drift_absent_source(tmp_path):
    d = P.drift_status(tmp_path / "missing.yaml", tmp_path / "also-missing.yaml")
    assert d["state"] == "absent_source"


def test_sha256_is_content_not_mtime(tmp_path):
    a = tmp_path / "a.yaml"
    a.write_text("x: 1\n")
    first = P.sha256_file(a)
    a.touch()                                      # mtime changes, content does not
    assert P.sha256_file(a) == first               # T-2290 lesson: content, never mtime


def test_emit_spec_is_text_and_names_boundary(tmp_path):
    spec = P.emit_install_spec(tmp_path / "src.yaml", tmp_path / "dep.yaml", 4000)
    assert "EMIT ONLY" in spec and "the agent must NOT" in spec
    assert "sudo fw policy install" in spec        # the human/root verb
    assert "fw policy status" in spec              # the drift confirm verb


def test_install_copies_and_hashes(tmp_path):
    src = tmp_path / "src.yaml"
    dep = tmp_path / "deep" / "dep.yaml"           # parent dir created by install
    src.write_text("invariants: {}\n")
    r = P.install_policy(src, dep)
    assert Path(r["installed"]).read_text() == "invariants: {}\n"
    assert r["sha256"] == P.sha256_file(src)
    # after install, drift is ok
    assert P.drift_status(src, dep)["state"] == "ok"


def test_install_missing_source_raises(tmp_path):
    import pytest
    with pytest.raises(FileNotFoundError):
        P.install_policy(tmp_path / "nope.yaml", tmp_path / "dep.yaml")
