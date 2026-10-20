"""T-3715: fw upgrade pre-approves the framework's MCP servers so a restarted
Claude Code does not stop on the "New MCP server found" prompt."""
import json
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
HELPER = os.path.join(ROOT, "lib", "mcp_approve.py")
sys.path.insert(0, os.path.join(ROOT, "lib"))
import mcp_approve  # noqa: E402


def _project(tmp_path, servers, local=None):
    (tmp_path / ".mcp.json").write_text(json.dumps({"mcpServers": {s: {"command": "x"} for s in servers}}))
    if local is not None:
        (tmp_path / ".claude").mkdir()
        (tmp_path / ".claude" / "settings.local.json").write_text(json.dumps(local))
    return tmp_path


def _local(p):
    return json.loads((p / ".claude" / "settings.local.json").read_text())


def test_approves_framework_servers_without_local_settings(tmp_path):
    p = _project(tmp_path, ["fw", "termlink", "mine"])
    assert mcp_approve.approve(str(p)) == "APPROVED termlink,fw"
    assert _local(p)["enabledMcpjsonServers"] == ["termlink", "fw"]


def test_never_approves_non_framework_server(tmp_path):
    p = _project(tmp_path, ["mine"])
    assert mcp_approve.approve(str(p)) == "NONE"
    assert not (p / ".claude" / "settings.local.json").exists()


def test_preserves_other_keys_and_existing_entries(tmp_path):
    p = _project(tmp_path, ["fw", "context7"], {"permissions": {"allow": ["Bash(ls)"]}, "enabledMcpjsonServers": ["mine", "context7"]})
    assert mcp_approve.approve(str(p)) == "APPROVED fw"
    s = _local(p)
    assert s["permissions"] == {"allow": ["Bash(ls)"]}
    assert s["enabledMcpjsonServers"] == ["mine", "context7", "fw"]


def test_respects_disabled(tmp_path):
    p = _project(tmp_path, ["fw", "playwright"], {"disabledMcpjsonServers": ["playwright"]})
    assert mcp_approve.approve(str(p)) == "APPROVED fw; DISABLED playwright"
    s = _local(p)
    assert "playwright" not in s["enabledMcpjsonServers"]
    assert s["disabledMcpjsonServers"] == ["playwright"]


def test_enable_all_is_noop(tmp_path):
    local = {"enableAllProjectMcpServers": True}
    p = _project(tmp_path, ["fw"], local)
    assert mcp_approve.approve(str(p)) == "ALL"
    assert _local(p) == local


def test_idempotent(tmp_path):
    p = _project(tmp_path, ["fw"])
    mcp_approve.approve(str(p))
    assert mcp_approve.approve(str(p)) == "NONE"


def test_dry_run_writes_nothing(tmp_path):
    p = _project(tmp_path, ["fw"])
    assert mcp_approve.approve(str(p), dry_run=True) == "APPROVED fw"
    assert not (p / ".claude" / "settings.local.json").exists()


def test_flat_legacy_schema(tmp_path):
    (tmp_path / ".mcp.json").write_text(json.dumps({"fw": {"command": "x"}}))
    assert mcp_approve.approve(str(tmp_path)) == "APPROVED fw"


def test_unparseable_local_settings_untouched(tmp_path):
    p = _project(tmp_path, ["fw"])
    (p / ".claude").mkdir()
    (p / ".claude" / "settings.local.json").write_text("{not json")
    assert mcp_approve.approve(str(p)).startswith("ERROR")
    assert (p / ".claude" / "settings.local.json").read_text() == "{not json"


def test_cli(tmp_path):
    p = _project(tmp_path, ["fw"])
    out = subprocess.run([sys.executable, HELPER, str(p), "--dry-run"], capture_output=True, text=True)
    assert out.returncode == 0 and out.stdout.strip() == "APPROVED fw"


def test_upgrade_calls_helper():
    src = open(os.path.join(ROOT, "lib", "upgrade.sh")).read()
    assert 'lib/mcp_approve.py" "$target_dir"' in src
