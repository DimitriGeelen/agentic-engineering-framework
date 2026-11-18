"""T-5236 — a missing or broken hubs.toml profile reaches the operator once, with the fix.

Operator ruling 2026-11-18 (question 4, option 1 + remediation option 1). Every termlink
call goes through a stub runner; hubs.toml is a temp file; PROJECT_ROOT is a temp tree.
No hub is contacted and no real sidecar message is sent.
"""

from __future__ import annotations

import importlib
import json
import subprocess
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

import pytest

FW_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(FW_ROOT))

ADDR = "192.168.10.122:9100"


class _Proc:
    def __init__(self, returncode=0, stdout="", stderr=""):
        self.returncode, self.stdout, self.stderr = returncode, stdout, stderr


def _runner(*, probe_rc=1, probe_err="Error: failed to resolve address", doctor_rows=None):
    def run(argv, **kw):
        if argv[1:3] == ["hub", "probe"]:
            return _Proc(probe_rc, "" if probe_rc else json.dumps({"fingerprint": "x"}), probe_err)
        if argv[1:3] == ["fleet", "doctor"]:
            return _Proc(0, json.dumps({"hubs": doctor_rows or []}))
        raise AssertionError(f"unexpected termlink call {argv}")
    return run


@pytest.fixture()
def env(tmp_path, monkeypatch):
    home = tmp_path / "home"
    proj = tmp_path / "proj"
    (home / ".termlink").mkdir(parents=True)
    (proj / ".context" / "sidecar").mkdir(parents=True)
    (proj / ".framework.yaml").write_text("project: t5236\n")
    monkeypatch.setenv("HOME", str(home))
    monkeypatch.setenv("PROJECT_ROOT", str(proj))
    import lib.sidecar.outbox as outbox
    import lib.sidecar.profile_notices as pn
    import lib.sidecar.termlink_transport as tt
    import lib.sidecar.delivery as delivery
    for m in (pn, tt, delivery):
        importlib.reload(m)
    # A broken profile's fix is one command: a runme is prepared. Stub it here
    # (one test below exercises the real `fw runme new` into the temp project).
    runmes = []

    def fake_runme(user, hub, command):
        runmes.append((user, hub, command))
        return f"bash {proj}/.context/runme/hub-profile-{user}-{hub}/runme.sh"
    monkeypatch.setattr(pn, "_prepare_runme", fake_runme)
    real_record = pn.record
    monkeypatch.setattr(pn, "record", lambda g, cmid, **k: real_record(g, cmid, make_runme=fake_runme, **k))
    hubs = home / ".termlink" / "hubs.toml"
    return dict(home=home, proj=proj, hubs=hubs, pn=pn, tt=tt, delivery=delivery,
                outbox=outbox, runmes=runmes)


def _probe(env, runner):
    real = env["tt"].probe_hub   # bound now: a test may monkeypatch the module attribute
    return lambda hub: real(hub, runner=runner, hubs_file=env["hubs"])


def _send(env, hub, probe, transport=None, to=None):
    ob = env["outbox"]
    cmid = ob.write_message(from_id="t5236-test", to=to or f"{hub}/agent/x", body="consult",
                            conversation_id="c-t5236", hub=hub)
    posted = []
    tr = transport or (lambda msg: posted.append(msg))
    return env["delivery"].deliver(cmid, tr, probe), cmid, posted


# ── criterion 1: the NOT-delivered detail names hub, user and the exact fix ──

def test_missing_profile_detail_names_hub_user_and_hubs_toml_lines(env):
    env["hubs"].write_text('[hubs.local]\naddress = "127.0.0.1:9100"\nsecret_file = "/x"\n')
    pn = env["pn"]
    v = _probe(env, _runner())("ring20-management")
    assert v.ok is False and v.credential_refused is False   # still retried
    assert v.profile_gap["kind"] == pn.MISSING
    user, host = pn.current_user(), pn.current_host()
    assert f"user {user} on host {host} has no hubs.toml profile for hub ring20-management" in v.reason
    assert "[hubs.ring20-management]" in v.reason
    assert f'secret_file = "{env["home"]}/.termlink/secrets/ring20-management.hex"' in v.reason
    assert "termlink fleet reauth" not in v.reason


def test_missing_profile_for_an_address_puts_the_address_in_the_lines(env):
    env["hubs"].write_text('[hubs.other]\naddress = "10.0.0.9:9100"\nsecret_file = "/x"\n')
    v = _probe(env, _runner(probe_rc=0))(ADDR)
    assert v.profile_gap["kind"] == env["pn"].MISSING
    assert f'address = "{ADDR}"' in v.profile_gap["fix"]
    assert "[hubs.192-168-10-122-9100]" in v.profile_gap["fix"]


def test_broken_secret_file_names_reauth(env):
    env["hubs"].write_text(f'[hubs.dash]\naddress = "{ADDR}"\nsecret_file = "/nonexistent/dash.hex"\n')
    v = _probe(env, _runner(probe_rc=0))("dash")
    assert v.ok is False
    assert v.profile_gap == {"kind": env["pn"].BROKEN, "hub": "dash", "profile": "dash",
                             "fix": "termlink fleet reauth dash", "command": "termlink fleet reauth dash"}
    assert f"user {env['pn'].current_user()} on host" in v.reason
    assert "fix: `termlink fleet reauth dash`" in v.reason


def test_rejected_secret_names_reauth(env, tmp_path):
    sec = tmp_path / "s.hex"
    sec.write_text("ab" * 32)
    env["hubs"].write_text(f'[hubs.dash]\naddress = "{ADDR}"\nsecret_file = "{sec}"\n')
    v = _probe(env, _runner(probe_rc=0, doctor_rows=[{
        "hub": "dash", "status": "error",
        "error": "Authentication failed: -32010 Token validation failed: invalid signature"}]))("dash")
    assert v.credential_refused is True
    assert v.profile_gap["kind"] == env["pn"].BROKEN
    assert "termlink fleet reauth dash" in v.reason


def test_cli_not_delivered_detail_carries_the_fix(env, capsys, monkeypatch):
    env["hubs"].write_text('[hubs.local]\naddress = "127.0.0.1:9100"\nsecret_file = "/x"\n')
    monkeypatch.setenv("FW_SIDECAR_HUB_ID", "cacc73ea32b121dd")
    monkeypatch.setenv("FW_SIDECAR_AGENT_ID", "sender-t5236")
    monkeypatch.setenv("FW_SIDECAR_REGISTRY_DIR", str(env["home"] / "registry"))
    import lib.sidecar_cli as cli
    importlib.reload(cli)
    monkeypatch.setattr(cli.addressing, "resolve", lambda to, **k: {
        "circuit": f"d1993c2c3ec44c94/{to}", "hub": k.get("hub"), "how": f"--hub {k.get('hub')}"})
    monkeypatch.setattr(cli.transport, "probe_hub", _probe(env, _runner()))
    monkeypatch.setattr(cli.transport, "termlink_transport", lambda m, **k: None)
    rc = cli.cmd_send(cli.build_parser().parse_args(
        ["send", "--to", "ring20-manager", "--hub", "ring20-management", "--body", "c"]))
    out = capsys.readouterr().out
    assert rc == 1
    assert out.splitlines()[0].startswith("NOT delivered: STORED")
    reason = [ln for ln in out.splitlines() if ln.startswith("reason:")][0]
    assert "has no hubs.toml profile for hub ring20-management" in reason
    assert "[hubs.ring20-management]" in reason


# ── criterion 2: one notice per (user, hub), in pending and on the page ──────

def test_one_notice_per_user_and_hub_across_retries_and_senders(env):
    env["hubs"].write_text("")
    probe = _probe(env, _runner())
    r1, c1, _ = _send(env, "ring20-management", probe)
    r2, c2, _ = _send(env, "ring20-management", probe, to="ring20-management/agent/other")
    for _ in range(3):   # the watcher's retries of the first message
        env["delivery"].deliver(c1, lambda m: None, probe, attempts=2)
    assert r1.state == env["outbox"].STORED and r2.state == env["outbox"].STORED
    rows = env["pn"].pending()
    assert len(rows) == 1
    row = rows[0]
    assert (row["user"], row["hub"]) == (env["pn"].current_user(), "ring20-management")
    assert row["messages_waiting"] == 2 and sorted(row["waiting_ids"]) == sorted([c1, c2])
    assert row["kind"] == env["pn"].MISSING and row["runme"] is None
    assert row["first_seen"] <= row["last_seen"] and row["resolved_at"] is None
    s = env["pn"].summary(row)
    assert s.startswith(f"user {row['user']} on host {row['host']} has no hubs.toml profile "
                        "for hub ring20-management; 2 messages waiting; fix: add to")
    # a different hub is a different notice
    _send(env, "ring20-dashboard", probe)
    assert {r["hub"] for r in env["pn"].pending()} == {"ring20-management", "ring20-dashboard"}


def test_broken_profile_notice_comes_with_a_prepared_runme(env):
    env["hubs"].write_text(f'[hubs.dash]\naddress = "{ADDR}"\nsecret_file = "/nonexistent"\n')
    probe = _probe(env, _runner(probe_rc=0))
    _send(env, "dash", probe)
    _send(env, "dash", probe)
    rows = env["pn"].pending()
    assert len(rows) == 1 and rows[0]["kind"] == env["pn"].BROKEN
    assert rows[0]["runme"].startswith("bash ") and rows[0]["runme"].endswith("runme.sh")
    assert env["runmes"] == [(rows[0]["user"], "dash", "termlink fleet reauth dash")]   # once
    assert rows[0]["messages_final"] == 2   # credential refusals stay final (unchanged)
    assert "run bash " in env["pn"].summary(rows[0])


def test_real_runme_is_prepared_never_run(env, monkeypatch):
    importlib.reload(env["pn"])   # undo the stub
    line = env["pn"]._prepare_runme("alice", "dash", "termlink fleet reauth dash")
    script = env["proj"] / ".context" / "runme" / "hub-profile-alice-dash" / "runme.sh"
    assert line == f"bash {script}"
    assert "termlink fleet reauth dash" in script.read_text()
    assert not (script.parent / "run.log").exists()


def test_operator_pending_lists_the_notice(env, monkeypatch):
    env["hubs"].write_text("")
    _send(env, "ring20-management", _probe(env, _runner()))
    import lib.operator_pending as op
    importlib.reload(op)
    monkeypatch.setattr(op, "PROJECT", env["proj"])
    rows = op.hub_profile_notices()
    assert len(rows) == 1
    for name in ("partial_complete", "undecided_inceptions", "unrun_runmes", "pending_proposals",
                 "issue_replies", "outside_commit_alarms"):
        monkeypatch.setattr(op, name, (lambda: ([], [])) if name == "partial_complete" else (lambda: []))
    monkeypatch.setattr(op, "_base_url", lambda: "")
    text = op.render(op.collect())
    assert "## Hub profiles missing or broken" in text
    assert "has no hubs.toml profile for hub ring20-management; 1 message waiting" in text


def _approvals_client(monkeypatch, proj):
    from web.blueprints import approvals
    monkeypatch.setattr(approvals, "PROJECT_ROOT", proj)
    for name, val in (("_load_pending_approvals", lambda: []), ("_load_resolved_approvals", lambda: []),
                      ("_load_pending_go_decisions", lambda: []), ("_load_pending_human_acs", lambda: []),
                      ("_count_deferred_inceptions", lambda: 0), ("_load_paused_dispatches", lambda: []),
                      ("_load_close_ready_arcs", lambda _=0.80: []), ("_load_decided_unclosed", lambda: []),
                      ("_load_stale_keystones", lambda: []), ("_load_batch_ready_tasks", lambda: []),
                      ("_load_waiting_messages", lambda: {"items": [], "error": None, "warn_hours": None}),
                      ("_stale_ids", lambda: set())):
        monkeypatch.setattr(approvals, name, val)
    import web.blueprints.bvp as bvp
    monkeypatch.setattr(bvp, "_load_proposals", lambda: [])
    from web.app import app
    return app.test_client()


def test_approvals_page_shows_the_notice(env, monkeypatch):
    env["hubs"].write_text(f'[hubs.dash]\naddress = "{ADDR}"\nsecret_file = "/nonexistent"\n')
    _send(env, "dash", _probe(env, _runner(probe_rc=0)))
    client = _approvals_client(monkeypatch, env["proj"])
    html = client.get("/approvals/content").get_data(as_text=True)
    assert 'id="section-hub-profiles"' in html
    assert html.count('data-testid="hub-profile-notice"') == 1
    assert "has a broken profile <code>dash</code>" in html
    assert "hub-profile-" in html and "runme.sh" in html


# ── criterion 3: a later delivery resolves the notice ────────────────────────

def test_delivery_resolves_the_notice(env):
    env["hubs"].write_text("")
    pn = env["pn"]
    _, cmid, _ = _send(env, "ring20-management", _probe(env, _runner()))
    assert len(pn.pending()) == 1
    ok = lambda hub: env["delivery"].ProbeResult(True, "fixed")
    r = env["delivery"].deliver(cmid, lambda m: None, ok, fast_path=False, attempts=2)
    assert r.delivered
    assert pn.pending() == []
    rows = pn._read(pn.ledger_path())
    assert len(rows) == 1 and rows[0]["resolved_at"]


def _real_runme_row(env, user="alice", hub="dash"):
    """A notice row whose runme was really prepared (not the stub), for the withdraw tests."""
    importlib.reload(env["pn"])
    pn = env["pn"]
    line = pn._prepare_runme(user, hub, f"termlink fleet reauth {hub}")
    path = pn.ledger_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    pn._write(path, [{"user": user, "host": "h", "hub": hub, "kind": pn.BROKEN, "profile": hub,
                      "fix": "x", "first_seen": "2026-11-18T00:00:00Z", "last_seen": "2026-11-18T00:00:00Z",
                      "messages_waiting": 1, "messages_final": 0, "waiting_ids": [], "runme": line,
                      "resolved_at": None}])
    return pn, Path(line.split(" ", 1)[1]).parent


def test_resolve_withdraws_the_prepared_runme(env):
    pn, d = _real_runme_row(env)
    assert pn.resolve("dash", user="alice") == 1
    assert (d / "WITHDRAWN").is_file() and "no longer needed" in (d / "WITHDRAWN").read_text()
    assert not (d / "run.log").exists(), "withdrawing never fakes a run record"


def test_resolve_leaves_a_runme_that_already_ran(env):
    pn, d = _real_runme_row(env)
    (d / "run.log").write_text("RUNME START\nRUNME EXIT 0\n")
    pn.resolve("dash", user="alice")
    assert not (d / "WITHDRAWN").exists()


def test_withdrawn_runme_leaves_operator_pending(env, monkeypatch):
    pn, d = _real_runme_row(env)
    import lib.operator_pending as op
    monkeypatch.setattr(op, "PROJECT", env["proj"])
    assert any(r["name"] == d.name for r in op.unrun_runmes())
    pn.resolve("dash", user="alice")
    assert not any(r["name"] == d.name for r in op.unrun_runmes())


def test_resolve_leaves_other_hubs_alone(env):
    env["hubs"].write_text("")
    probe = _probe(env, _runner())
    _send(env, "ring20-management", probe)
    _send(env, "ring20-dashboard", probe)
    assert env["pn"].resolve("ring20-dashboard") == 1
    assert [r["hub"] for r in env["pn"].pending()] == ["ring20-management"]


# ── criterion 4: the daily check reports a notice older than 7 days ──────────

def _backdate(env, days):
    pn = env["pn"]
    rows = pn._read(pn.ledger_path())
    old = (datetime.now(timezone.utc) - timedelta(days=days)).isoformat(timespec="seconds")
    for r in rows:
        r["first_seen"] = old
    pn._write(pn.ledger_path(), rows)


def _run_audit_check(proj):
    audit = (FW_ROOT / "agents" / "audit" / "audit.sh").read_text()
    start = audit.index("check_hub_profile_notices() {")
    body = audit[start:audit.index("\n}\n", start) + 3]
    script = ('warn() { echo "WARN|$1|$2|$3"; }\n' + body +
              f'PROJECT_ROOT="{proj}"; FRAMEWORK_ROOT="{FW_ROOT}"; check_hub_profile_notices\n')
    return subprocess.run(["bash", "-c", script], capture_output=True, text=True, timeout=60)


def test_daily_check_reports_a_notice_older_than_seven_days(env):
    env["hubs"].write_text("")
    _send(env, "ring20-management", _probe(env, _runner()))
    assert _run_audit_check(env["proj"]).stdout == ""   # fresh: silent
    _backdate(env, 8)
    out = _run_audit_check(env["proj"]).stdout
    assert out.startswith("WARN|Hub profile unfixed for 7+ days: user ")
    assert "for hub ring20-management" in out
    assert len(env["pn"].stale(7)) == 1 and env["pn"].stale(9) == []


def test_daily_check_skips_resolved_notices(env):
    env["hubs"].write_text("")
    _send(env, "ring20-management", _probe(env, _runner()))
    _backdate(env, 8)
    env["pn"].resolve("ring20-management")
    assert _run_audit_check(env["proj"]).stdout == ""


# ── criterion 5: retries unchanged; no credential or hubs.toml writes ────────

def test_retry_semantics_unchanged_and_hubs_toml_untouched(env):
    body = '[hubs.local]\naddress = "127.0.0.1:9100"\nsecret_file = "/x"\n'
    env["hubs"].write_text(body)
    r, cmid, posted = _send(env, "ring20-management", _probe(env, _runner()))
    assert r.state == env["outbox"].STORED and not r.delivered and posted == []
    assert env["outbox"].list_pending() and cmid in env["outbox"].list_pending()
    assert env["hubs"].read_text() == body
    assert not (env["home"] / ".termlink" / "secrets").exists()


def test_a_broken_ledger_never_changes_a_delivery(env, monkeypatch):
    env["hubs"].write_text("")
    monkeypatch.setattr(env["pn"], "record", lambda *a, **k: (_ for _ in ()).throw(OSError("disk")))
    r, _, _ = _send(env, "ring20-management", _probe(env, _runner()))
    assert r.state == env["outbox"].STORED and "hub-refused:" in r.reason


def test_no_source_writes_hubs_toml_or_secrets():
    src = (FW_ROOT / "lib" / "sidecar" / "profile_notices.py").read_text()
    for forbidden in ("hubs.toml\").write", "write_text(secret", "open(hubs"):
        assert forbidden not in src
    assert "_write(path" in src   # the only writer is the notice ledger
