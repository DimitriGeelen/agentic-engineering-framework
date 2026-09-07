"""T-3312 (arc-020 S6): tests for fleet repo-source + integrity verify.

Spec: docs/reports/T-3287-identity-taxonomy-circuit-model.md (D5 bound 3).
Covers: the known-peers-only property (query log matches the passed list
exactly, never anything else), first-peer-with-verified-repo wins, sha256
pass -> materialize called, sha256 fail -> abort BEFORE materialize (order
pinned), missing digest is a failure not a pass, trusted-manifest digest
precedence, all-peers-fail -> operator notice emitted + halt (naming the
project and every peer tried), the default stderr sink, and the
integration leg: aef_resolve.provision's missing-path S6 halt routes into
source_repo and provisioning resumes after successful sourcing.
"""

from __future__ import annotations

import hashlib
import sys
from dataclasses import replace
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from lib.aef_address import AEFAddress, parse, serialize  # noqa: E402
from lib.aef_repo_source import (  # noqa: E402
    DIGEST_MISMATCH,
    NO_DIGEST,
    NO_REPO,
    QUERY_ERROR,
    SOURCED,
    UNFINDABLE,
    VERIFIED,
    OperatorNotice,
    PeerOffer,
    RepoSourceError,
    default_notice_sink,
    provision_with_sourcing,
    source_repo,
    stub_query_peer,
)
from lib.aef_resolve import HALTED, HANDOFF_S6, PROVISIONED  # noqa: E402

ARTIFACT = b"repo-bundle-bytes-for-T-3312"
DIGEST = hashlib.sha256(ARTIFACT).hexdigest()

PEERS = ["host106.ring20.lan", "host107.ring20.lan", "host108.ring20.lan"]


def recording_query(offers: dict):
    """query_peer seam that answers from ``offers`` and logs every ask."""
    log: list[str] = []

    def query(peer: str, project: str) -> PeerOffer | None:
        log.append(peer)
        answer = offers.get(peer)
        if isinstance(answer, Exception):
            raise answer
        return answer

    query.log = log
    return query


def recording_materialize(events: list):
    def materialize(project: str, artifact: bytes) -> None:
        events.append(("materialize", project, artifact))

    return materialize


# ── known-peers-only (D5 bound 3: never arbitrary network) ───────────────


def test_queries_exactly_the_known_peers_and_nothing_else():
    """All peers say no: the query log is the passed list, verbatim."""
    query = recording_query({})
    events: list = []
    result = source_repo(
        "/opt/proj", PEERS, query, recording_materialize(events),
        notice_sink=lambda n: None,
    )
    assert query.log == PEERS  # exactly, in order — no invented peers
    assert result.outcome == UNFINDABLE
    assert [a.outcome for a in result.attempts] == [NO_REPO] * 3
    assert events == []


def test_peers_list_must_be_explicit_not_a_string():
    with pytest.raises(RepoSourceError):
        source_repo("/opt/proj", "host107", recording_query({}), lambda p, a: None)


def test_stub_query_peer_documents_the_protocol():
    """The transport stub answers no for every peer — wiring is later work."""
    assert stub_query_peer("host107.ring20.lan", "/opt/proj") is None


# ── first peer with a (verified) repo wins ───────────────────────────────


def test_first_peer_with_repo_wins_and_later_peers_are_never_asked():
    offers = {PEERS[1]: PeerOffer(PEERS[1], lambda: ARTIFACT, DIGEST)}
    query = recording_query(offers)
    events: list = []
    result = source_repo("/opt/proj", PEERS, query, recording_materialize(events))
    assert result.outcome == SOURCED
    assert result.peer == PEERS[1]
    assert result.sha256 == DIGEST
    assert query.log == PEERS[:2]  # peer 3 never consulted
    assert events == [("materialize", "/opt/proj", ARTIFACT)]


def test_verify_failure_moves_to_the_next_known_peer():
    """A bad artifact from peer 1 does not block a good one from peer 2."""
    offers = {
        PEERS[0]: PeerOffer(PEERS[0], lambda: b"tampered", DIGEST),
        PEERS[1]: PeerOffer(PEERS[1], lambda: ARTIFACT, DIGEST),
    }
    query = recording_query(offers)
    events: list = []
    result = source_repo("/opt/proj", PEERS, query, recording_materialize(events))
    assert result.outcome == SOURCED
    assert result.peer == PEERS[1]
    assert [a.outcome for a in result.attempts] == [DIGEST_MISMATCH, VERIFIED]
    # only the VERIFIED artifact ever reached materialize
    assert events == [("materialize", "/opt/proj", ARTIFACT)]


# ── integrity: sha256 gates materialization ──────────────────────────────


def test_sha256_pass_then_materialize_called():
    offers = {PEERS[0]: PeerOffer(PEERS[0], lambda: ARTIFACT, DIGEST)}
    events: list = []
    result = source_repo(
        "/opt/proj", PEERS[:1], recording_query(offers), recording_materialize(events)
    )
    assert result.outcome == SOURCED
    assert events == [("materialize", "/opt/proj", ARTIFACT)]
    assert result.attempts[-1].outcome == VERIFIED
    assert result.attempts[-1].actual_sha256 == DIGEST


def test_sha256_fail_aborts_before_materialize_order_pinned():
    """Verification failure aborts WITHOUT executing: fetch happened,
    materialize never did — and the attempt names peer + both digests."""
    events: list = []

    def fetch():
        events.append(("fetch", PEERS[0]))
        return b"not-the-artifact"

    offers = {PEERS[0]: PeerOffer(PEERS[0], fetch, DIGEST)}
    result = source_repo(
        "/opt/proj", PEERS[:1], recording_query(offers),
        recording_materialize(events), notice_sink=lambda n: None,
    )
    assert result.outcome == UNFINDABLE
    # order pinned: the fetch is the ONLY event — no materialize after it
    assert events == [("fetch", PEERS[0])]
    attempt = result.attempts[0]
    assert attempt.outcome == DIGEST_MISMATCH
    assert attempt.peer == PEERS[0]
    assert attempt.expected_sha256 == DIGEST
    assert attempt.actual_sha256 == hashlib.sha256(b"not-the-artifact").hexdigest()
    assert PEERS[0] in attempt.error and DIGEST in attempt.error


def test_missing_digest_is_a_verification_failure_not_a_pass():
    """No peer claim, no trusted manifest -> the artifact may not run."""
    offers = {PEERS[0]: PeerOffer(PEERS[0], lambda: ARTIFACT, sha256=None)}
    events: list = []
    result = source_repo(
        "/opt/proj", PEERS[:1], recording_query(offers),
        recording_materialize(events), notice_sink=lambda n: None,
    )
    assert result.outcome == UNFINDABLE
    assert result.attempts[0].outcome == NO_DIGEST
    assert events == []


def test_trusted_manifest_digest_takes_precedence_over_peer_claim():
    """A lying peer claim cannot override the trusted manifest, and a
    correct manifest verifies even when the peer claims nothing."""
    offers = {PEERS[0]: PeerOffer(PEERS[0], lambda: ARTIFACT, sha256="deadbeef")}
    events: list = []
    result = source_repo(
        "/opt/proj", PEERS[:1], recording_query(offers),
        recording_materialize(events), expected_sha256=DIGEST,
    )
    assert result.outcome == SOURCED  # manifest digest matched; claim ignored
    # and the inverse: manifest says otherwise -> abort despite matching claim
    offers2 = {PEERS[0]: PeerOffer(PEERS[0], lambda: ARTIFACT, sha256=DIGEST)}
    events2: list = []
    result2 = source_repo(
        "/opt/proj", PEERS[:1], recording_query(offers2),
        recording_materialize(events2), expected_sha256="0" * 64,
        notice_sink=lambda n: None,
    )
    assert result2.outcome == UNFINDABLE
    assert result2.attempts[0].outcome == DIGEST_MISMATCH
    assert events2 == []


# ── unfindable: halt + operator notice (surfaced, never silent) ──────────


def test_all_peers_fail_emits_operator_notice_and_halts():
    offers = {
        PEERS[0]: None,  # no repo
        PEERS[1]: ConnectionError("peer unreachable"),  # query raises
        PEERS[2]: PeerOffer(PEERS[2], lambda: b"tampered", DIGEST),  # bad digest
    }
    sunk: list[OperatorNotice] = []
    events: list = []
    result = source_repo(
        "/opt/proj", PEERS, recording_query(offers),
        recording_materialize(events), notice_sink=sunk.append,
    )
    assert result.outcome == UNFINDABLE
    assert events == []
    assert [a.outcome for a in result.attempts] == [
        NO_REPO, QUERY_ERROR, DIGEST_MISMATCH,
    ]
    assert len(sunk) == 1
    assert sunk[0] is result.notice  # the notice rides on the result too


def test_notice_names_the_project_and_every_peer_tried():
    sunk: list[OperatorNotice] = []
    result = source_repo(
        "/opt/the-missing-proj", PEERS, recording_query({}),
        lambda p, a: None, notice_sink=sunk.append,
    )
    notice = sunk[0]
    assert notice.project == "/opt/the-missing-proj"
    assert notice.peers_tried == tuple(PEERS)
    assert "/opt/the-missing-proj" in notice.message
    for peer in PEERS:
        assert peer in notice.message
    assert result.notice == notice


def test_default_sink_writes_stderr_and_the_ledger(capsys):
    from lib import aef_repo_source

    before = len(aef_repo_source.OPERATOR_NOTICES)
    result = source_repo("/opt/proj", PEERS[:1], recording_query({}), lambda p, a: None)
    err = capsys.readouterr().err
    assert "OPERATOR NOTICE" in err and "/opt/proj" in err
    assert aef_repo_source.OPERATOR_NOTICES[before:] == [result.notice]
    aef_repo_source.OPERATOR_NOTICES.pop()  # leave the ledger as found


def test_no_known_peers_is_unfindable_with_notice_not_an_error():
    sunk: list[OperatorNotice] = []
    result = source_repo(
        "/opt/proj", [], recording_query({}), lambda p, a: None,
        notice_sink=sunk.append,
    )
    assert result.outcome == UNFINDABLE
    assert result.attempts == ()
    assert len(sunk) == 1


# ── integration: the S3 ladder's S6 halt routes here and resumes ─────────

CIRCUIT = (
    "aef::host=host107.ring20.lan::hub=H-1"
    "::project={project}::session=S-8f3c::@reviewer::"
)


def circuit(project: str) -> AEFAddress:
    return parse(CIRCUIT.format(project=project))


def probe_knowing(*existing: AEFAddress):
    known = {serialize(a) for a in existing}

    def probe(addr: AEFAddress) -> bool:
        return serialize(addr) in known

    return probe


def make_provisioners():
    calls: list[str] = []

    def make(level):
        def prov(intended):
            calls.append(level)
            if level == "session" and intended.session is None:
                return replace(intended, session="S-fresh")
            return None

        return prov

    provs = {lvl: make(lvl) for lvl in ("hub", "project", "session", "agent")}
    return provs, calls


def fleet_materialize(project: str, artifact: bytes) -> None:
    path = Path(project)
    path.mkdir(parents=True)
    (path / "payload").write_bytes(artifact)


def test_provision_missing_path_halt_routes_into_source_and_resumes(tmp_path):
    """End to end: halt (path absent) -> fleet-source -> verify ->
    materialize -> the SAME provision walk resumes and completes."""
    proj = tmp_path / "sourced-proj"  # not on disk
    target = circuit(str(proj))
    host_hub = AEFAddress(host=target.host, hub=target.hub)
    provs, calls = make_provisioners()
    offers = {PEERS[2]: PeerOffer(PEERS[2], lambda: ARTIFACT, DIGEST)}
    query = recording_query(offers)

    out = provision_with_sourcing(
        target, probe_knowing(host_hub), provs,
        fleet_peers=PEERS, query_peer=query, materialize=fleet_materialize,
    )
    assert out.sourcing is not None
    assert out.sourcing.outcome == SOURCED
    assert out.sourcing.peer == PEERS[2]
    assert query.log == PEERS  # known peers only, in order
    assert (proj / "payload").read_bytes() == ARTIFACT
    # the ladder resumed: the missing suffix materialized top-down
    assert out.provision.outcome == PROVISIONED
    assert calls == ["project", "session", "agent"]
    assert out.provision.materialized[-1] == serialize(target)


def test_provision_unfindable_stays_halted_and_operator_is_informed(tmp_path):
    proj = tmp_path / "never-found"
    target = circuit(str(proj))
    host_hub = AEFAddress(host=target.host, hub=target.hub)
    provs, calls = make_provisioners()
    sunk: list[OperatorNotice] = []

    out = provision_with_sourcing(
        target, probe_knowing(host_hub), provs,
        fleet_peers=PEERS, query_peer=recording_query({}),
        materialize=fleet_materialize, notice_sink=sunk.append,
    )
    assert out.sourcing.outcome == UNFINDABLE
    assert out.provision.outcome == HALTED  # the original halt, unchanged
    assert out.provision.handoff == HANDOFF_S6
    assert calls == []  # nothing materialized anywhere
    assert not proj.exists()
    assert len(sunk) == 1 and str(proj) in sunk[0].message


def test_non_halt_outcomes_pass_through_without_sourcing(tmp_path):
    """Sourcing is ONLY the S6 halt's handoff — a found endpoint (or any
    other outcome) never touches the fleet."""
    proj = tmp_path / "proj"
    proj.mkdir()
    target = circuit(str(proj))
    provs, _ = make_provisioners()
    query = recording_query({})

    out = provision_with_sourcing(
        target, probe_knowing(target), provs,
        fleet_peers=PEERS, query_peer=query, materialize=fleet_materialize,
    )
    assert out.provision.outcome == "already-exists"
    assert out.sourcing is None
    assert query.log == []  # no peer was ever asked
