"""T-5281 — the inbox-bound alarm.

AEF's inbox reads are unsigned (`termlink channel subscribe`, no read proof).
Once the hub binds an inbox to its agent's key it refuses those reads with
JSON-RPC error -32049 (INBOX_BOUND, 010-termlink). That must never read as an
empty inbox or a generic error, and a bind must be noticed before anyone wonders
why mail stopped: `fw sidecar alerts` and `fw doctor` WARN on a non-null `bound`
from `termlink hub inbox consumers <own topic> --json`, say nothing when it is
null, and say "not checked" (never OK) when the hub cannot be asked.

A fake `termlink` first on PATH stands in for the hub; FAKE_MODE picks its answer.
"""

from __future__ import annotations

import io
import json
import os
import re
import stat
import subprocess
import sys
from contextlib import redirect_stdout
from pathlib import Path
from types import SimpleNamespace

import pytest

FW_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(FW_ROOT))

from lib.sidecar import adapter, alerts, inbox  # noqa: E402
import lib.sidecar_cli as cli  # noqa: E402

BOUND_OBJ = {"agent": "999-Agentic-Engineering-Framework", "key": "ab12cd34ef56ab78cd90"}

FAKE = r"""#!/usr/bin/env bash
echo "$*" >> "$FAKE_LOG"
mode="$(cat "$FAKE_MODE_FILE")"
if [ "$1 $2 $3" = "hub inbox consumers" ]; then
    case "$mode" in
        bound) printf '%s\n' '{"bound":BOUND,"consumers":[],"topic":"'"$4"'","window_s":86400}' ;;
        unbound|locked-read) printf '%s\n' '{"bound":null,"consumers":[],"topic":"'"$4"'","window_s":86400}' ;;
        consumers-fail) echo "Error: unrecognized subcommand 'inbox'" >&2; exit 2 ;;
    esac
    exit 0
fi
if [ "$1 $2" = "channel subscribe" ]; then
    case "$mode" in
        locked-read|bound)
            echo "Error: Hub returned error for channel.subscribe: JSON-RPC error -32049: inbox is bound" >&2
            exit 1 ;;
        *) exit 0 ;;
    esac
fi
exit 0
""".replace("BOUND", json.dumps(BOUND_OBJ))


@pytest.fixture
def fake(tmp_path, monkeypatch):
    root = tmp_path / "t5281"
    (root / ".context").mkdir(parents=True)
    (root / ".framework.yaml").write_text("project_name: t5281\n")
    monkeypatch.setenv("PROJECT_ROOT", str(root))
    monkeypatch.setenv("FW_SIDECAR_REGISTRY_DIR", str(tmp_path / "registry"))
    monkeypatch.delenv("FW_SIDECAR_AGENT_ID", raising=False)
    monkeypatch.setenv("FW_SIDECAR_HUB_ID", "cacc73ea32b121dd")
    monkeypatch.delenv("FW_REVIEW_WORKER", raising=False)
    monkeypatch.setattr(adapter, "_claude_ancestor_pid", lambda *a, **k: None)
    bindir = tmp_path / "fakebin"
    bindir.mkdir()
    tl = bindir / "termlink"
    tl.write_text(FAKE)
    tl.chmod(tl.stat().st_mode | stat.S_IEXEC)
    mode_file = tmp_path / "mode"
    log = tmp_path / "fake.log"
    monkeypatch.setenv("FAKE_MODE_FILE", str(mode_file))
    monkeypatch.setenv("FAKE_LOG", str(log))
    monkeypatch.setenv("PATH", f"{bindir}{os.pathsep}{os.environ['PATH']}")
    # Hermetic cmd_alerts: other routes have their own tests.
    monkeypatch.setattr(cli.addressing, "orphan_inboxes", lambda **_: [])
    monkeypatch.setattr(cli, "_issue_reply_lines", lambda: [])
    monkeypatch.setattr(cli, "_host_shared_lines", lambda: [])

    def set_mode(m: str) -> None:
        mode_file.write_text(m)
    set_mode("unbound")
    return SimpleNamespace(set=set_mode, log=log, bindir=bindir, root=root)


def _alerts(json_out: bool = False) -> tuple[int, str]:
    buf = io.StringIO()
    with redirect_stdout(buf):
        rc = cli.cmd_alerts(SimpleNamespace(limit=10, json=json_out, mark_seen=False))
    return rc, buf.getvalue()


def _no_mail(monkeypatch):
    monkeypatch.setattr(alerts, "collect", lambda **_: [])


# --- 1. a -32049 read is a locked inbox, never empty, never generic ---------

def test_refused_read_is_locked_not_empty(fake):
    fake.set("locked-read")
    got = inbox.default_reader("inbox:cacc73ea32b121dd/x", 0)
    assert isinstance(got, inbox.ReadFailed)
    assert got == []  # still falsy for lenient callers, but...
    assert "inbox locked (bound" in got.reason
    assert "unsigned" in got.reason and "T-5281" in got.reason


def test_refused_read_names_the_holder_when_the_hub_says(fake):
    fake.set("bound")
    got = inbox.default_reader("inbox:cacc73ea32b121dd/x", 0)
    assert isinstance(got, inbox.ReadFailed)
    assert "bound to 999-Agentic-Engineering-Framework (key ab12cd34ef56ab78)" in got.reason


def test_strict_reader_raises_locked(fake):
    fake.set("locked-read")
    with pytest.raises(inbox.Unreadable, match="inbox locked"):
        inbox.strict_reader("inbox:cacc73ea32b121dd/x", 0)


def test_code_not_text_decides(fake, monkeypatch):
    """Another code whose message mentions binding is not INBOX_BOUND, and
    -320490 is not -32049."""
    for err in ("JSON-RPC error -32013: inbox bound? unknown topic",
                "JSON-RPC error -320490: something"):
        monkeypatch.setattr(subprocess, "run", lambda *a, _e=err, **k:
                            subprocess.CompletedProcess(a, 1, "", _e))
        got = inbox.default_reader("inbox:x", 0)
        assert not (isinstance(got, inbox.ReadFailed) and "locked" in got.reason)


# --- 2. bound non-null -> WARN in alerts (and doctor, below) ----------------

def test_alerts_warns_when_bound(fake, monkeypatch):
    fake.set("bound")
    _no_mail(monkeypatch)
    rc, out = _alerts()
    assert rc == 0
    assert re.search(r"^WARN: our inbox is locked \(bound to 999-Agentic", out, re.M)
    rc, out = _alerts(json_out=True)
    assert json.loads(out)["inbox_lock"]["state"] == "bound"


def test_alerts_warns_when_bound_even_if_mail_unreadable(fake, monkeypatch):
    """The usual shape after a bind: the read is refused AND the lock is shown."""
    fake.set("bound")
    rc, out = _alerts()
    assert rc == 3
    assert out.startswith("NOT CHECKED:") and "inbox locked" in out
    assert "WARN: our inbox is locked" in out


# --- 3. bound null -> no warning --------------------------------------------

def test_alerts_silent_when_unbound(fake, monkeypatch):
    fake.set("unbound")
    _no_mail(monkeypatch)
    rc, out = _alerts()
    assert rc == 0
    assert "locked" not in out and "inbox lock" not in out
    assert out.strip() == "peer mail: nothing unseen"
    # exactly one extra hub call for the lock check
    calls = fake.log.read_text().splitlines()
    assert [c for c in calls if c.startswith("hub inbox consumers")] == [
        f"hub inbox consumers {inbox.inbox_topic()} --json"]


# --- 4. command missing / failing -> not checked, never OK -------------------

def test_alerts_not_checked_when_consumers_fails(fake, monkeypatch):
    fake.set("consumers-fail")
    _no_mail(monkeypatch)
    rc, out = _alerts()
    assert "inbox lock: not checked (" in out
    assert "WARN" not in out


def test_own_inbox_bound_unknown_when_binary_missing(fake, monkeypatch):
    monkeypatch.setattr(inbox, "_binary", lambda: "termlink-does-not-exist")
    state, detail = inbox.own_inbox_bound()
    assert state == "unknown" and "not found" in detail


def test_own_inbox_bound_unknown_without_bound_field(fake, monkeypatch):
    monkeypatch.setattr(subprocess, "run", lambda *a, **k: subprocess.CompletedProcess(
        a, 0, '{"consumers":[]}', ""))
    assert inbox.own_inbox_bound()[0] == "unknown"


# --- doctor: the same three states, through the real bin/fw block -----------

def _doctor_block() -> str:
    src = (FW_ROOT / "bin" / "fw").read_text()
    start = src.index("# T-5281: our inbox reads are unsigned")
    end = src.index("esac", start) + len("esac")
    return src[start:end]


def _run_doctor_block(fake) -> str:
    script = ("set -euo pipefail\nYELLOW= CYAN= NC=\nwarnings=0\n"
              "check() {\n" + _doctor_block() + "\n}\ncheck\necho \"warnings=$warnings\"\n")
    env = dict(os.environ, FRAMEWORK_ROOT=str(FW_ROOT), PROJECT_ROOT=str(fake.root))
    p = subprocess.run(["bash", "-c", script], capture_output=True, text=True, env=env,
                       timeout=30)
    assert p.returncode == 0, p.stderr
    return p.stdout


def test_doctor_warns_when_bound(fake):
    fake.set("bound")
    out = _run_doctor_block(fake)
    assert "WARN  Our inbox is locked (bound to 999-Agentic-Engineering-Framework" in out
    assert "warnings=1" in out


def test_doctor_silent_when_unbound(fake):
    fake.set("unbound")
    out = _run_doctor_block(fake)
    assert out.strip() == "warnings=0"


def test_doctor_not_checked_when_consumers_fails(fake):
    fake.set("consumers-fail")
    out = _run_doctor_block(fake)
    assert "SKIP  Inbox lock: not checked (" in out
    assert "OK" not in out and "warnings=0" in out
