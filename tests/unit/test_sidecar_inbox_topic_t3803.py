"""T-3803 — the owner's own inbox topic is created by the receiving side, and
a missing topic is reported as FAIL by name instead of a silent 0.

Origin: ring20-dashboard / ring20-manager (.121/.122). Nothing on the receiving
side ever created `inbox:<circuit>`; only a sender's `--ensure-topic` post did.
`default_reader` turns the hub's "unknown topic" refusal into an empty list,
so `fw sidecar status` printed `inbound unread: 0` for an inbox that did not
exist. All termlink calls here go through a fake runner — no live hub.
"""

import importlib
import json
import subprocess


import pytest

HUB = "cacc73ea32b121dd"
PROJECT = "999-Agentic-Engineering-Framework"
TOPIC = f"inbox:{HUB}/{PROJECT}"


@pytest.fixture()
def inbox(tmp_path, monkeypatch):
    project = tmp_path / PROJECT
    project.mkdir()
    monkeypatch.setenv("FRAMEWORK_ROOT", str(project))
    monkeypatch.setenv("PROJECT_ROOT", str(project))
    monkeypatch.setenv("FW_SIDECAR_HUB_ID", HUB)
    monkeypatch.setenv("FW_SIDECAR_AGENT_ID", PROJECT)
    for var in ("TERMLINK_SESSION", "FW_FOCUS_SESSION_KEY"):
        monkeypatch.delenv(var, raising=False)   # a dispatched worker's session id would extend the circuit
    import lib.sidecar.outbox as outbox
    import lib.sidecar.inbox as inbox_mod
    importlib.reload(outbox)
    importlib.reload(inbox_mod)
    return inbox_mod


class FakeHub:
    """Answers `channel list` and `channel create` like termlink does."""

    def __init__(self, topics=(), list_rc=0, create_err=None):
        self.topics = set(topics)
        self.list_rc = list_rc
        self.create_err = create_err
        self.calls = []

    def __call__(self, argv, **kw):
        self.calls.append(argv[1:])
        verb = argv[2]
        if verb == "list":
            if self.list_rc:
                return subprocess.CompletedProcess(argv, self.list_rc, "", "hub down")
            prefix = argv[argv.index("--prefix") + 1]
            names = [{"name": t} for t in sorted(self.topics) if t.startswith(prefix)]
            return subprocess.CompletedProcess(argv, 0, json.dumps({"topics": names}), "")
        if verb == "create":
            if self.create_err:
                return subprocess.CompletedProcess(argv, 1, "", self.create_err)
            self.topics.add(argv[3])
            return subprocess.CompletedProcess(argv, 0, json.dumps({"created": True}), "")
        raise AssertionError(f"unexpected termlink call {argv}")


def test_ensure_creates_missing_owner_topic(inbox):
    hub = FakeHub()
    row = inbox.ensure_topic(runner=hub)
    assert row == {"topic": TOPIC, "ok": True, "action": "created", "reason": "created"}
    assert TOPIC in hub.topics
    # Default retention: no --retention flag, so the hub's inbox:* default applies.
    create = [c for c in hub.calls if c[1] == "create"][0]
    assert "--retention" not in create


def test_ensure_is_idempotent_and_leaves_existing_topic_alone(inbox):
    hub = FakeHub(topics=[TOPIC])
    row = inbox.ensure_topic(runner=hub)
    assert row["action"] == "exists" and row["ok"]
    assert not [c for c in hub.calls if c[1] == "create"], "must not re-create (retention clash)"


def test_prefix_sibling_is_not_mistaken_for_the_topic(inbox):
    # `channel list --prefix` also returns longer names; only an exact match counts.
    hub = FakeHub(topics=[TOPIC + "/agentB"])
    assert inbox.topic_present(TOPIC, runner=hub)[0] is False
    assert inbox.ensure_topic(runner=hub)["action"] == "created"


def test_create_race_already_exists_counts_as_present(inbox):
    hub = FakeHub(create_err=f'channel.create: topic "{TOPIC}" already exists with a different retention policy')
    row = inbox.ensure_topic(runner=hub)
    assert row["ok"] and row["action"] == "exists"


def test_create_failure_is_reported_not_swallowed(inbox):
    hub = FakeHub(create_err="permission denied")
    row = inbox.ensure_topic(runner=hub)
    assert row["ok"] is False and row["action"] == "failed"
    assert "permission denied" in row["reason"]


def test_topic_present_unknown_when_hub_cannot_be_asked(inbox):
    present, reason = inbox.topic_present(TOPIC, runner=FakeHub(list_rc=1))
    assert present is None and "hub down" in reason


@pytest.fixture()
def cli(inbox, monkeypatch):
    import lib.sidecar_cli as cli_mod
    importlib.reload(cli_mod)
    monkeypatch.setattr(cli_mod.inbox, "topic_present", inbox.topic_present)
    monkeypatch.setattr("shutil.which", lambda name: "/usr/bin/termlink")
    return cli_mod


def test_status_check_names_missing_topic_as_fail(cli, monkeypatch):
    hub = FakeHub()
    real = cli.inbox.topic_present
    monkeypatch.setattr(cli.inbox, "topic_present", lambda t, **kw: real(t, runner=hub))
    check = cli._inbox_topic_check()
    assert check["verdict"] == "FAIL"
    assert TOPIC in check["reason"] and "fw sidecar ensure" in check["reason"]


def test_status_check_ok_when_topic_exists(cli, monkeypatch):
    hub = FakeHub(topics=[TOPIC])
    real = cli.inbox.topic_present
    monkeypatch.setattr(cli.inbox, "topic_present", lambda t, **kw: real(t, runner=hub))
    assert cli._inbox_topic_check()["verdict"] == "OK"


def test_status_check_unknown_never_ok_when_hub_unreachable(cli, monkeypatch):
    hub = FakeHub(list_rc=1)
    real = cli.inbox.topic_present
    monkeypatch.setattr(cli.inbox, "topic_present", lambda t, **kw: real(t, runner=hub))
    assert cli._inbox_topic_check()["verdict"] == "UNKNOWN"


def test_cli_ensure_helper_creates_topic(cli, monkeypatch, capsys):
    hub = FakeHub()
    real = cli.inbox.ensure_topic
    monkeypatch.setattr(cli.inbox, "ensure_topic", lambda agent=None, **kw: real(agent, runner=hub))
    row = cli._ensure_inbox_topic(PROJECT, quiet=False)
    assert row["action"] == "created" and TOPIC in hub.topics
    assert f"inbox topic: created {TOPIC}" in capsys.readouterr().out


def test_cli_ensure_helper_failure_goes_to_stderr(cli, monkeypatch, capsys):
    hub = FakeHub(create_err="permission denied")
    real = cli.inbox.ensure_topic
    monkeypatch.setattr(cli.inbox, "ensure_topic", lambda agent=None, **kw: real(agent, runner=hub))
    row = cli._ensure_inbox_topic(PROJECT, quiet=True)
    assert not row["ok"]
    assert "FAIL" in capsys.readouterr().err
