"""T-5428: the retry sweep stops chasing a stored own-hub address nobody reads.

AEF-ontology-agent RCA, defect 2: three consults stored as
`cacc73ea32b121dd/proxmox-ring20-management` (a nickname on the sender's own hub,
reached through the T-4529 route T-5427 removed) counted as delivered when the hub
took them, and the ladder then re-posted and nudged them 18 more times. Rows stored
before T-5428 carry no `addressed_how`; the sweep re-resolves their bare name and
dead-letters the row when the resolver refuses it or points elsewhere. The resolver
is injected; nothing reaches a hub.
"""

import importlib
from datetime import datetime, timedelta, timezone

import pytest

T0 = datetime(2026, 11, 22, 12, 0, 0, tzinfo=timezone.utc)
OWN = "cacc73ea32b121dd"


@pytest.fixture()
def sc(tmp_path, monkeypatch):
    monkeypatch.setenv("FRAMEWORK_ROOT", str(tmp_path))
    monkeypatch.setenv("PROJECT_ROOT", str(tmp_path))
    monkeypatch.setenv("FW_SIDECAR_AGENT_ID", "sweeper-test")
    monkeypatch.setenv("FW_SIDECAR_HUB_ID", OWN)
    monkeypatch.setenv("FW_SIDECAR_HOST", "host107.ring20.lan")
    import lib.sidecar.outbox as outbox
    import lib.sidecar.delivery as delivery
    import lib.sidecar.addressing as addressing
    import lib.sidecar.retry as retry
    for m in (outbox, delivery, addressing, retry):
        importlib.reload(m)
    monkeypatch.setattr(addressing, "own_hub_id", lambda: OWN)
    return outbox, delivery, addressing, retry


def _ok_probe(_hub):
    import lib.sidecar.delivery as delivery
    return delivery.ProbeResult(True)


def _empty_reader(_topic, _cursor, _limit=None):
    return []


def _delivered(outbox, delivery, to, **kw):
    cmid = outbox.write_message(from_id="sweeper-test", to=to, body="the question",
                                conversation_id="conv-1", **kw)
    delivery.deliver(cmid, lambda _m: None, _ok_probe, now=T0)
    return cmid


def _sweep(retry, monkeypatch, addressing, resolver):
    monkeypatch.setattr(addressing, "resolve", resolver)
    posted = []
    report = retry.sweep(now=T0 + timedelta(seconds=60), transport=posted.append,
                         probe=_ok_probe, reader=_empty_reader)
    return report, posted


def _refuse(name, **_kw):
    import lib.sidecar.addressing as a
    raise a.AddressError(f"recipient {name!r} is not resolvable: not a project id")


def test_witness_nickname_now_resolving_elsewhere_is_dead_lettered(sc, monkeypatch):
    outbox, delivery, addressing, retry = sc
    cmid = _delivered(outbox, delivery, f"{OWN}/proxmox-ring20-management")
    report, posted = _sweep(retry, monkeypatch, addressing, lambda name, **kw: {
        "circuit": f"22c19fedafd73da2/{name}", "hub": "ring20", "how": "peer directory"})
    assert posted == []
    assert report["deadlettered"] == 1 and report["reposted"] == 0
    row = outbox.latest_ack_state(cmid)
    assert row["state"] == outbox.UNKNOWN
    assert row["error"].startswith(retry.UNRETRYABLE)
    assert "fw sidecar send --to proxmox-ring20-management --hub ring20" in row["error"]


def test_a_name_the_resolver_now_refuses_is_dead_lettered(sc, monkeypatch):
    outbox, delivery, addressing, retry = sc
    cmid = _delivered(outbox, delivery, f"{OWN}/some-nickname")
    report, posted = _sweep(retry, monkeypatch, addressing, _refuse)
    assert posted == [] and report["deadlettered"] == 1
    assert "no longer resolves" in outbox.latest_ack_state(cmid)["error"]


def test_a_numbered_project_on_our_hub_is_still_reposted(sc, monkeypatch):
    outbox, delivery, addressing, retry = sc
    _delivered(outbox, delivery, f"{OWN}/055-agentic-fleet-cockpit")
    report, posted = _sweep(retry, monkeypatch, addressing, lambda name, **kw: {
        "circuit": f"{OWN}/{name}", "hub": None, "how": "project address on this hub"})
    assert report["deadlettered"] == 0 and report["reposted"] == 1 and len(posted) == 1


def test_a_row_addressed_under_current_rules_is_never_judged(sc, monkeypatch):
    outbox, delivery, addressing, retry = sc
    _delivered(outbox, delivery, f"{OWN}/claude-shared",
               addressed_how="project address on this hub")
    report, posted = _sweep(retry, monkeypatch, addressing, _refuse)
    assert report["deadlettered"] == 0 and len(posted) == 1


def test_remote_hub_and_subagent_rows_are_left_to_the_ladder(sc, monkeypatch):
    outbox, delivery, addressing, retry = sc
    _delivered(outbox, delivery, "22c19fedafd73da2/ring20-dashboard", hub="ring20")
    _delivered(outbox, delivery, f"{OWN}/999-Agentic-Engineering-Framework/w-probe")
    report, posted = _sweep(retry, monkeypatch, addressing, _refuse)
    assert report["deadlettered"] == 0 and len(posted) == 2


def test_an_undecidable_resolve_leaves_the_row_to_the_ladder(sc, monkeypatch):
    outbox, delivery, addressing, retry = sc
    _delivered(outbox, delivery, f"{OWN}/some-nickname")

    def hub_down(name, **_kw):
        raise RuntimeError("termlink hub unreachable")

    report, posted = _sweep(retry, monkeypatch, addressing, hub_down)
    assert report["deadlettered"] == 0 and len(posted) == 1


def test_send_records_how_the_address_was_resolved(sc):
    outbox, delivery, _addressing, _retry = sc
    cmid = outbox.write_message(from_id="x", to=f"{OWN}/055-a", body="b",
                                conversation_id="c", addressed_how="project address on this hub")
    assert delivery.read_message(cmid)["addressed_how"] == "project address on this hub"
    cmid2 = outbox.write_message(from_id="x", to=f"{OWN}/055-a", body="b", conversation_id="c")
    assert "addressed_how" not in delivery.read_message(cmid2)
