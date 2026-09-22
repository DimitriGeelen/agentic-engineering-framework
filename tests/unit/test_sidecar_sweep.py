"""T-3418 — arc-011 sidecar sweep: the cron cadence for resolve_expired (slice 7)."""

import importlib
import json
from datetime import datetime, timedelta, timezone

import pytest


@pytest.fixture()
def sc(tmp_path, monkeypatch):
    monkeypatch.setenv("FRAMEWORK_ROOT", str(tmp_path))
    monkeypatch.setenv("FW_SIDECAR_AGENT_ID", "sweeper-test")
    import lib.sidecar.outbox as outbox
    import lib.sidecar.delivery as delivery
    import lib.sidecar.inbox as inbox
    import lib.sidecar.status as status
    import lib.sidecar_cli as cli
    for m in (outbox, delivery, inbox, status, cli):
        importlib.reload(m)
    return cli, outbox, status


def test_sweep_flips_stuck_rows_and_leaves_fresh_ones(sc, capsys):
    cli, outbox, status = sc
    past = (datetime.now(timezone.utc) - timedelta(minutes=5)).isoformat()
    future = (datetime.now(timezone.utc) + timedelta(minutes=5)).isoformat()
    outbox.record_ack("stuck", "b", None, outbox.STORED, deadline=past)
    outbox.record_ack("fresh", "b", None, outbox.STORED, deadline=future)

    assert status.snapshot()["expired_unswept"] == 1

    rc = cli.main(["sweep", "--json"])
    out = json.loads(capsys.readouterr().out)

    assert rc == 0
    assert out["flipped"] == 1
    assert out["client_msg_ids"] == ["stuck"]
    assert outbox.latest_ack_state("stuck")["state"] == outbox.UNKNOWN
    assert outbox.latest_ack_state("fresh")["state"] == outbox.STORED

    # The two verbs agree on the same ledger.
    snap = status.snapshot()
    assert snap["expired_unswept"] == 0
    assert snap["ledger"][outbox.UNKNOWN] == 1
    assert snap["ledger"][outbox.STORED] == 1


def test_clean_sweep_is_not_an_error(sc, capsys):
    cli, _, _ = sc
    rc = cli.main(["sweep"])
    assert rc == 0
    assert "0 row(s)" in capsys.readouterr().out
