"""T-5423 (050 item 5): each orchestrator-scan warning gets its own audit title.

050 saw "Orchestrator-arc tag-format drift" printed above evidence that led with
"NEW: 9 unclassified tool(s) … | REMOVED: 12 …". The scan writes `warnings:` as YAML
entries that wrap over several lines; the audit read a fragment with `awk | head -1`.
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "lib"))
import orchestrator_warnings as ow  # noqa: E402

NEW = ("NEW: 9 unclassified tool(s) (manual review needed — outside T-1761 convention scope): "
       "termlink_dialog_presence, termlink_fleet_governor_history, termlink_whoami")
REMOVED = "REMOVED: 12 tool(s) gone from /opt/termlink (likely renamed): termlink_agent_activity_rhythm"
TAG = ("TAG-FORMAT-DRIFT: 5 non-canonical tag prefix(es) in live sessions: "
       "fw-project=(20), respawn=(4), role=(2), fqdn=(1), stack=(1)")


def _latest(tmp_path, warnings):
    p = tmp_path / "orchestrator-LATEST.yaml"
    # width=80 makes yaml wrap long entries over several lines, as the real scan does
    p.write_text(yaml.safe_dump({"status": "warn", "warnings": warnings, "errors": []}, width=80))
    return p


def _run(path):
    out = subprocess.run([sys.executable, str(ROOT / "lib/orchestrator_warnings.py"), str(path)],
                         capture_output=True, text=True, check=True).stdout
    return [line.split("\t") for line in out.splitlines()]


def test_each_class_is_reported_under_its_own_title(tmp_path):
    p = _latest(tmp_path, [NEW, REMOVED, TAG])
    assert "\n  " in p.read_text(), "fixture must wrap entries, like the real scan"
    rows = _run(p)
    assert len(rows) == 3
    by_title = {r[0]: r[1] for r in rows}
    tag = by_title["Orchestrator-arc tag-format drift: live sessions carry non-canonical prefixes"]
    assert tag.startswith("TAG-FORMAT-DRIFT:") and "fw-project=(20)" in tag
    assert "unclassified" not in tag and "REMOVED" not in tag
    assert by_title["Orchestrator-arc MCP scan: unclassified TermLink tool(s)"].startswith("NEW:")
    assert by_title["Orchestrator-arc MCP scan: tool(s) gone from TermLink"].startswith("REMOVED:")


def test_wrapped_entries_come_back_whole(tmp_path):
    rows = _run(_latest(tmp_path, [NEW]))
    assert rows[0][1] == NEW


def test_unknown_class_and_unreadable_file_still_produce_a_line(tmp_path):
    rows = _run(_latest(tmp_path, ["SOMETHING-ELSE: x"]))
    assert rows[0][0] == ow.OTHER[0]
    rows = _run(tmp_path / "missing.yaml")
    assert len(rows) == 1 and "could not read" in rows[0][1]


def test_audit_no_longer_reads_warnings_with_head_1():
    src = (ROOT / "agents/audit/audit.sh").read_text()
    assert "lib/orchestrator_warnings.py" in src
    assert "awk '/^warnings:/{flag=1; next} /^errors:/{flag=0} flag' \"$ORCH_LATEST\"" not in src
