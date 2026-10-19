"""T-4432 — Watchtower cron pause/resume must write the same crontab as `fw cron generate`.

The web path used to carry its own generator that ignored lib/cron_schedule.py
(T-4351), so a pause reverted the staggered reindex minute to :20. Temp project
only: /etc/cron.d is never written and `fw cron install` is never run.
"""
import os
import subprocess
import sys
from pathlib import Path

import pytest
import yaml

FW_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(FW_ROOT))

REGISTRY = {
    "jobs": [
        {"id": "index-reindex-hourly", "name": "Reindex", "schedule": "20 * * * *",
         "command": "fw index reindex", "status": "active"},
        {"id": "audit-daily", "name": "Audit", "schedule": "0 8 * * *",
         "command": "fw audit --cron 2>/dev/null", "status": "active"},
        {"id": "retention", "name": "Retention", "schedule": "0 9 * * *",
         "command": "find .context/audits/cron -name '*.yaml' -mtime +7 -delete",
         "status": "paused"},
    ]
}


@pytest.fixture
def project(tmp_path):
    root = tmp_path / "proj-t4432"
    (root / ".context").mkdir(parents=True)
    (root / ".framework.yaml").write_text(f"project_name: proj-t4432\nframework_path: {FW_ROOT}\n")
    (root / ".context" / "cron-registry.yaml").write_text(yaml.dump(REGISTRY, sort_keys=False))
    return root


def _generate(root: Path) -> str:
    env = {k: v for k, v in os.environ.items() if not k.startswith("FW_") and k != "PROJECT_ROOT"}
    env["PROJECT_ROOT"] = str(root)
    r = subprocess.run([str(FW_ROOT / "bin" / "fw"), "cron", "generate"],
                       cwd=root, env=env, capture_output=True, text=True, timeout=120)
    assert r.returncode == 0, r.stdout + r.stderr
    return (root / ".context" / "cron" / "agentic-audit.crontab").read_text()


def test_pause_resume_matches_fw_cron_generate(project, monkeypatch):
    from flask import Flask
    import web.blueprints.cron as cron_bp

    monkeypatch.setattr(cron_bp, "PROJECT_ROOT", project)
    monkeypatch.setattr(cron_bp, "REGISTRY_PATH", project / ".context" / "cron-registry.yaml")
    monkeypatch.setattr(cron_bp, "_install_cron", lambda src: None)  # never touch /etc/cron.d

    expected = _generate(project)
    crontab = project / ".context" / "cron" / "agentic-audit.crontab"
    crontab.unlink()

    app = Flask(__name__)
    app.register_blueprint(cron_bp.bp)
    client = app.test_client()
    assert client.post("/api/v1/cron/jobs/audit-daily/pause").status_code == 200
    assert client.post("/api/v1/cron/jobs/audit-daily/resume").status_code == 200

    got = crontab.read_text()
    assert got == expected
    # The T-4351 stagger survived: reindex minute is derived, not the seeded :20.
    reindex = [l for l in got.splitlines() if "index reindex" in l and not l.startswith("#")][0]
    assert not reindex.startswith("20 ")
