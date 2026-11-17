"""T-5200 (T-5190 S1): operator-owned subscription registry — neutral ids, never account data."""
from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

import pytest
import yaml

FW = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(FW / "lib"))
sys.path.insert(0, str(FW))
import subscriptions as subs  # noqa: E402

HEADER = "# test registry\n"


def _env(proj: Path, agent: bool = False, ai_agent: bool = False) -> dict:
    env = {k: v for k, v in os.environ.items() if k not in ("CLAUDECODE", "AI_AGENT")}
    env.update(PROJECT_ROOT=str(proj), FRAMEWORK_ROOT=str(FW))
    if agent:
        env["CLAUDECODE"] = "1"
    if ai_agent:
        env["AI_AGENT"] = "codex"
    return env


@pytest.fixture
def proj(tmp_path, monkeypatch):
    (tmp_path / "policy").mkdir()
    (tmp_path / "policy" / "subscriptions.yaml").write_text(HEADER + "subscriptions: []\nassignments: []\n")
    monkeypatch.setenv("PROJECT_ROOT", str(tmp_path))
    monkeypatch.setenv("FRAMEWORK_ROOT", str(FW))
    monkeypatch.delenv("CLAUDECODE", raising=False)
    monkeypatch.delenv("AI_AGENT", raising=False)
    return tmp_path


def _write(proj: Path, data: dict, extra: str = "") -> Path:
    p = proj / "policy" / "subscriptions.yaml"
    p.write_text(HEADER + extra + yaml.safe_dump(data, sort_keys=False))
    return p


def _cli(proj: Path, *args, agent=False, ai_agent=False):
    return subprocess.run([sys.executable, str(FW / "lib" / "subscriptions.py"), *args],
                          capture_output=True, text=True, env=_env(proj, agent, ai_agent), cwd=str(proj))


GOOD = {"subscriptions": [{"id": "claude-a", "harness": "claude", "description": "pool sub A"},
                          {"id": "glm", "harness": "glm", "description": "coding plan"}],
        "assignments": [{"kind": "claude", "subscription": "claude-a"},
                        {"kind": "claude", "host": "ring20-dev", "subscription": "glm"},
                        {"kind": "opencode", "subscription": "glm"}]}


# ── the shipped file ─────────────────────────────────────────────────────────

def test_shipped_registry_has_schema_and_is_valid():
    # The operator fills this file (T-5200 S1); check its shape and validity, never its
    # contents, so the test holds for any registry the operator writes (T-5208).
    p = FW / "policy" / "subscriptions.yaml"
    text = p.read_text()
    data = yaml.safe_load(text)
    assert set(data) == {"subscriptions", "assignments"}
    assert isinstance(data["subscriptions"], list) and isinstance(data["assignments"], list)
    assert "NEVER ACCOUNT IDENTITY" in text and "harness:" in text and "subscription:" in text
    assert subs.validate(data, text) == []


# ── resolve ──────────────────────────────────────────────────────────────────

def test_resolve_kind_host_and_unassigned(proj):
    _write(proj, GOOD)
    assert subs.resolve("claude") == "claude-a"
    assert subs.resolve("claude", host="other-host") == "claude-a"
    assert subs.resolve("claude", host="ring20-dev") == "glm"  # host-specific wins
    assert subs.resolve("opencode", host="ring20-dev") == "glm"
    assert subs.resolve("codex") == subs.UNASSIGNED


def test_host_specific_wins_regardless_of_order(proj):
    data = {"subscriptions": GOOD["subscriptions"],
            "assignments": [{"kind": "claude", "host": "h1", "subscription": "glm"},
                            {"kind": "claude", "subscription": "claude-a"}]}
    _write(proj, data)
    assert subs.resolve("claude", "h1") == "glm"
    assert subs.resolve("claude", "h2") == "claude-a"


def test_resolve_absent_file_is_unassigned(proj, tmp_path_factory, monkeypatch):
    # Both locations absent: the project's and the framework fallback's (T-5208).
    (proj / "policy" / "subscriptions.yaml").unlink()
    monkeypatch.setenv("FRAMEWORK_ROOT", str(tmp_path_factory.mktemp("fw-empty")))
    assert subs.resolve("claude") == subs.UNASSIGNED


def test_resolve_invalid_registry_raises(proj):
    _write(proj, {"subscriptions": [{"id": "a", "harness": "nope", "description": "d"}], "assignments": []})
    with pytest.raises(subs.SubscriptionError):
        subs.resolve("claude")


# ── validation ───────────────────────────────────────────────────────────────

@pytest.mark.parametrize("value,label", [
    ("owner is someone@example.com", "e-mail"),
    ("key 0123456789abcdef0123456789abcdef", "hex"),
    ("blob QWxhZGRpbjpvcGVuIHNlc2FtZTEyMzQ1Njc4OTA", "base64"),
    ("sk-ant-api03-abcdefgh", "sk-"),
    ("ghp_abcdefghij12", "ghp_"),
    ("gho_abcdefghij12", "gho_"),
    ("xox" + "b-1234567-abcdef", "xoxb-"),  # built at runtime: the commit secret-scan
    ("AKI" + "AIOSFODNN7EXAMPLE", "AKIA"),
    ("glpat-abcdefghij", "glpat-"),
])
def test_account_values_refused_in_description(proj, value, label):  # noqa: ARG001
    data = {"subscriptions": [{"id": "a", "harness": "claude", "description": value}], "assignments": []}
    _write(proj, data)
    with pytest.raises(subs.SubscriptionError) as e:
        subs.load()
    assert "account-looking" in str(e.value)
    assert value not in str(e.value)  # never echo the secret


def test_account_value_refused_in_comment(proj):
    _write(proj, {"subscriptions": [], "assignments": []}, extra="# login: someone@example.org\n")
    with pytest.raises(subs.SubscriptionError, match="e-mail"):
        subs.load()


@pytest.mark.parametrize("value", [
    "docs/reports/T-5190-subscription-quota-overview.md",
    "a-very-long-kebab-case-description-without-secrets",
    "Claude Max pool subscription shared by the ring hosts",
])
def test_ordinary_text_is_not_an_account_value(value):
    assert subs.account_values(value) == []


def test_duplicate_id_refused():
    data = {"subscriptions": [{"id": "a", "harness": "claude", "description": "x"},
                              {"id": "a", "harness": "glm", "description": "y"}], "assignments": []}
    assert any("duplicate id" in e for e in subs.validate(data))


def test_unknown_harness_refused():
    data = {"subscriptions": [{"id": "a", "harness": "gemini-free", "description": "x"}], "assignments": []}
    assert any("unknown harness" in e for e in subs.validate(data))


def test_assignment_to_undefined_id_refused():
    data = {"subscriptions": [], "assignments": [{"kind": "claude", "subscription": "ghost"}]}
    assert any("not defined" in e for e in subs.validate(data))


def test_duplicate_assignment_and_unknown_fields_refused():
    data = {"subscriptions": [{"id": "a", "harness": "claude", "description": "x", "account": "y"}],
            "assignments": [{"kind": "claude", "subscription": "a"}, {"kind": "claude", "subscription": "a"}]}
    errs = subs.validate(data)
    assert any("duplicate assignment" in e for e in errs)
    assert any("unknown field" in e for e in errs)


def test_valid_registry_has_no_errors():
    assert subs.validate(GOOD, yaml.safe_dump(GOOD)) == []


# ── CLI: reads for anyone, changes refused under agent control ───────────────

def test_list_and_show_work_under_agent_control(proj):
    _write(proj, GOOD)
    r = _cli(proj, "subscription", "list", agent=True)
    assert r.returncode == 0 and "claude-a" in r.stdout and "glm" in r.stdout
    r = _cli(proj, "subscription", "show", "glm", ai_agent=True)
    assert r.returncode == 0 and "harness: glm" in r.stdout and "opencode" in r.stdout
    r = _cli(proj, "resolve", "claude", "--host", "ring20-dev", agent=True)
    assert r.returncode == 0 and r.stdout.strip() == "glm"


@pytest.mark.parametrize("args", [
    ("subscription", "add", "x", "--harness", "claude", "--description", "d"),
    ("subscription", "add", "x", "--harness", "claude", "--description", "d", "--i-am-human"),
    ("subscription", "assign", "claude-a", "--kind", "codex", "--i-am-human"),
    ("subscription", "remove", "glm", "--i-am-human"),
])
@pytest.mark.parametrize("who", ["claudecode", "ai_agent"])
def test_changes_refused_under_agent_control(proj, args, who):
    p = _write(proj, GOOD)
    before = p.read_text()
    r = _cli(proj, *args, agent=(who == "claudecode"), ai_agent=(who == "ai_agent"))
    assert r.returncode == 2 and "REFUSED" in r.stderr
    assert p.read_text() == before
    assert not (proj / ".context" / "costs" / subs.CHANGE_LOG).exists()


def test_operator_add_assign_remove_and_log(proj):
    p = proj / "policy" / "subscriptions.yaml"
    assert _cli(proj, "subscription", "add", "claude-a", "--harness", "claude", "--description", "pool A").returncode == 0
    assert _cli(proj, "subscription", "add", "glm", "--harness", "glm", "--description", "plan").returncode == 0
    assert _cli(proj, "subscription", "assign", "claude-a", "--kind", "claude").returncode == 0
    assert _cli(proj, "subscription", "assign", "glm", "--kind", "claude", "--host", "h1").returncode == 0
    assert p.read_text().startswith(HEADER)  # schema comment survives a rewrite
    assert _cli(proj, "resolve", "claude", "--host", "h1").stdout.strip() == "glm"
    # re-assigning the same (kind, host) replaces, not duplicates
    assert _cli(proj, "subscription", "assign", "claude-a", "--kind", "claude", "--host", "h1").returncode == 0
    assert _cli(proj, "resolve", "claude", "--host", "h1").stdout.strip() == "claude-a"
    r = _cli(proj, "subscription", "remove", "claude-a")
    assert r.returncode == 0 and "2 assignment(s)" in r.stdout
    assert _cli(proj, "resolve", "claude").stdout.strip() == "unassigned"
    rows = [json.loads(l) for l in (proj / ".context" / "costs" / subs.CHANGE_LOG).read_text().splitlines()]
    assert [r["action"] for r in rows] == ["add", "add", "assign", "assign", "assign", "remove"]
    assert all(r["by"] == "human" for r in rows)
    assert rows[4]["before"] == "glm"


def test_operator_add_refuses_account_value_and_unknown_assign(proj):
    p = proj / "policy" / "subscriptions.yaml"
    before = p.read_text()
    r = _cli(proj, "subscription", "add", "a", "--harness", "claude", "--description", "me@example.com")
    assert r.returncode == 2 and "account-looking" in r.stderr and "me@example.com" not in r.stderr
    r = _cli(proj, "subscription", "assign", "ghost", "--kind", "claude")
    assert r.returncode == 2 and "not defined" in r.stderr
    assert p.read_text() == before


def test_add_rejects_unknown_harness_at_cli(proj):
    r = _cli(proj, "subscription", "add", "a", "--harness", "gemini", "--description", "d")
    assert r.returncode != 0


# ── audit / doctor ───────────────────────────────────────────────────────────

def test_audit_silent_when_absent_pass_when_valid_fail_when_invalid(proj):
    p = proj / "policy" / "subscriptions.yaml"
    p.unlink()
    # absent locally → falls back to the framework file, which ships valid
    r = _cli(proj, "audit")
    assert r.returncode == 0 and (r.stdout == "" or r.stdout.startswith("PASS\t"))
    _write(proj, GOOD)
    assert _cli(proj, "audit").stdout.startswith("PASS\tSubscription registry valid (2 id(s), 3 assignment(s))")
    _write(proj, {"subscriptions": [{"id": "a", "harness": "claude", "description": "x"}],
                  "assignments": [{"kind": "claude", "subscription": "nope"}]})
    out = _cli(proj, "audit").stdout
    assert out.startswith("FAIL\t") and "not defined" in out


def test_audit_lines_absent_everywhere_is_silent(tmp_path, monkeypatch):
    monkeypatch.setenv("PROJECT_ROOT", str(tmp_path))
    monkeypatch.setenv("FRAMEWORK_ROOT", str(tmp_path))
    assert subs.audit_lines() == []


def test_audit_and_doctor_are_wired():
    assert "lib/subscriptions.py\" audit" in (FW / "agents" / "audit" / "audit.sh").read_text()
    fw = (FW / "bin" / "fw").read_text()
    assert "lib/subscriptions.py\" audit" in fw and '"$FW_LIB_DIR/subscriptions.py"' in fw


def test_fw_quota_routes():
    # run in the framework repo itself: its shipped registry is empty, and add is refused
    env = {k: v for k, v in os.environ.items() if k not in ("PROJECT_ROOT", "AI_AGENT")}
    env["CLAUDECODE"] = "1"
    r = subprocess.run([str(FW / "bin" / "fw"), "quota", "subscription", "list"], capture_output=True,
                       text=True, env=env, cwd=str(FW))
    assert r.returncode == 0, r.stderr
    r = subprocess.run([str(FW / "bin" / "fw"), "quota", "subscription", "add", "x", "--harness", "claude",
                        "--description", "d", "--i-am-human"], capture_output=True, text=True,
                       env=env, cwd=str(FW))
    assert r.returncode == 2 and "REFUSED" in r.stderr


# ── Bash text gate ───────────────────────────────────────────────────────────

@pytest.mark.parametrize("cmd", [
    "bin/fw quota subscription add a --harness claude --description d",
    "fw quota subscription assign a --kind claude --host h",
    "bin/fw quota subscription remove a --i-am-human",
    "python3 lib/subscriptions.py subscription add a --harness claude --description d",
    "env -u CLAUDECODE -u AI_AGENT python3 lib/subscriptions.py subscription assign a --kind claude",
    "python3 .agentic-framework/lib/subscriptions.py subscription remove a",
])
def test_text_gate_refuses_operator_verbs(cmd):
    from lib import shell_write_scan as sws
    assert sws.scan(cmd, cwd=str(FW), project_root=str(FW)), cmd


@pytest.mark.parametrize("cmd", [
    "bin/fw quota subscription list",
    "bin/fw quota subscription show claude-a",
    "python3 lib/subscriptions.py resolve claude --host h",
    "python3 lib/subscriptions.py audit",
])
def test_text_gate_allows_reads(cmd):
    from lib import shell_write_scan as sws
    assert not sws.scan(cmd, cwd=str(FW), project_root=str(FW)), cmd
