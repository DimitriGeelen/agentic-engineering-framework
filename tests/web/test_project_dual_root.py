"""T-2651 (OBS-097 final leg): /project docs surface under split roots.

Framework-owned docs (agents/*/AGENT.md) are listed from FRAMEWORK_ROOT with a
`fw--` doc_id prefix that project_doc routes back to FRAMEWORK_ROOT (own
containment check). The prefix is emitted ONLY when roots differ — coincident
installs (the framework repo) keep byte-identical doc_ids.

Split-root assertions reuse the T-2650 subprocess isolation (in-process
web.shared reload is the OBS-094 tarpit).
"""

import json
import os
import subprocess
import sys
from pathlib import Path

FRAMEWORK_ROOT = Path(__file__).resolve().parents[2]

_PROBE_SCRIPT = r"""
import json, warnings
warnings.filterwarnings("ignore")
from web.app import create_app

app = create_app()
app.config["TESTING"] = True
client = app.test_client()

listing = client.get("/project")
doc = client.get("/project/fw--agents--git--AGENT")
trav = client.get("/project/fw--..--..--etc--passwd")

print(json.dumps({
    "listing_status": listing.status_code,
    "listing_has_fw_agent_ids": "fw--agents--git--AGENT" in listing.get_data(as_text=True),
    "doc_status": doc.status_code,
    "doc_has_content": len(doc.get_data(as_text=True)) > 500,
    "traversal_status": trav.status_code,
}))
"""


def test_split_root_lists_and_serves_framework_agent_docs(tmp_path):
    consumer = tmp_path / "consumer"
    for d in (".tasks/active", ".tasks/completed", ".tasks/templates",
              ".context/working", ".context/handovers", "docs/reports"):
        (consumer / d).mkdir(parents=True)
    (consumer / ".framework.yaml").write_text(
        "project_name: dual-root-smoke\nversion: 1.0.0\nprovider: claude\n"
    )

    env = os.environ.copy()
    env["PROJECT_ROOT"] = str(consumer)
    env.pop("FRAMEWORK_ROOT", None)
    env["PYTHONPATH"] = str(FRAMEWORK_ROOT)
    proc = subprocess.run(
        [sys.executable, "-c", _PROBE_SCRIPT],
        capture_output=True, text=True, timeout=300,
        cwd=str(FRAMEWORK_ROOT), env=env,
    )
    assert proc.returncode == 0, f"split-root app boot failed:\n{proc.stderr[-3000:]}"
    result = json.loads(proc.stdout.strip().splitlines()[-1])

    assert result["listing_status"] == 200
    assert result["listing_has_fw_agent_ids"], (
        "split-root /project no longer lists framework AGENT.md docs under fw-- ids"
    )
    assert result["doc_status"] == 200, "fw-- doc failed to serve from FRAMEWORK_ROOT"
    assert result["doc_has_content"], "fw-- doc served but rendered (near-)empty"
    assert result["traversal_status"] == 404, (
        "traversal-shaped fw-- doc_id must 404 (containment against FRAMEWORK_ROOT)"
    )


def test_coincident_roots_keep_plain_doc_ids():
    # In the framework repo PROJECT_ROOT == FRAMEWORK_ROOT: no fw-- prefix,
    # doc_ids byte-identical to pre-T-2651 behavior.
    from web.app import create_app

    app = create_app()
    app.config["TESTING"] = True
    client = app.test_client()

    html = client.get("/project").get_data(as_text=True)
    assert "agents--git--AGENT" in html
    assert "fw--agents" not in html

    resp = client.get("/project/agents--git--AGENT")
    assert resp.status_code == 200
