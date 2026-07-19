"""Unit tests for the Child-2 forward compiler (tools/bpmn_to_tasks.py, T-2531).

Verifies the first-slice invariants: aef:uid extraction from <extensionElements>
(IW-1), lane->owner mapping (IW-7), O-1 Lane-wins+warn for a serviceTask in a human
lane, and that every emitted skeleton is parseable YAML frontmatter (never a stub).
"""
import os
import sys

import yaml

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(REPO_ROOT, "tools"))

import bpmn_to_tasks  # noqa: E402

FIXTURE = os.path.join(REPO_ROOT, "tests", "fixtures", "bpmn", "two-lane-sample.bpmn")
FIXTURE_FLOW = os.path.join(REPO_ROOT, "tests", "fixtures", "bpmn", "flow-order-sample.bpmn")
FIXTURE_INCEPTION = os.path.join(
    REPO_ROOT, "tests", "fixtures", "bpmn", "inception-gonogo-sample.bpmn"
)
FIXTURE_PLAIN = os.path.join(
    REPO_ROOT, "tests", "fixtures", "bpmn", "plain-composite-sample.bpmn"
)
# T-2552: 832's T-204 typed-event encoding (<aef:eventDef> on a neutral
# intermediateCatchEvent) — compiler WARNs, does not consume (T-2551).
FIXTURE_TYPED_EVENT = os.path.join(
    REPO_ROOT, "tests", "fixtures", "bpmn", "typed-event-sample.bpmn"
)
# T-2537: inception marker in a NON-sovereignty lane -> malformed -> fail fast.
FIXTURE_MISLANED = os.path.join(
    REPO_ROOT, "tests", "fixtures", "bpmn", "inception-mislaned-sample.bpmn"
)
# T-2537: inception in a NAME-ONLY human lane (no laneMeta) -> accepted + WARN.
FIXTURE_NAMEONLY = os.path.join(
    REPO_ROOT, "tests", "fixtures", "bpmn", "inception-nameonly-lane-sample.bpmn"
)
# 832's byte-exact canonical inception fixture (delivered over the DM rail, T-193).
# Uses the REAL aef: namespace URI + the attribute uid form <aef:uid value="..."/>.
FIXTURE_CANONICAL = os.path.join(
    REPO_ROOT, "tests", "fixtures", "bpmn", "inception-gonogo-canonical.bpmn"
)
CANONICAL_SHA256 = "093858400716a0c5dd4e6676ad96b1564e47980527a15028fd08242df1c7041e"
# 832's byte-exact canonical NEGATIVE fixture (resume-status.bpmn, delivered over
# the DM rail at offset 45, T-2535). frw_7_gather is a <subProcess> WITH
# <aef:constituents> but NO workflowType="inception" -> plain composition, must
# NOT compile to workflow_type:inception. The positive/negative discriminator pair.
FIXTURE_RESUME_STATUS = os.path.join(
    REPO_ROOT, "tests", "fixtures", "bpmn", "resume-status-canonical.bpmn"
)
RESUME_STATUS_SHA256 = "7b15f3e0f78587c25d8b448f30dc6d57ffa8b283396f55caf875fa10e4b2c03f"


def _by_uid(skeletons):
    return {s["uid"]: s for s in skeletons}


def test_extracts_all_task_nodes_with_uid():
    """Each userTask/serviceTask/scriptTask is extracted with its aef:uid (IW-1)."""
    skeletons, _ = bpmn_to_tasks.parse_bpmn(FIXTURE)
    by_uid = _by_uid(skeletons)
    assert set(by_uid) == {"u-review-001", "u-compile-002", "u-escalate-003"}
    # start/end events are NOT tasks — must not appear
    assert len(skeletons) == 3


def test_lane_to_owner_mapping_both_lanes():
    """Human lane -> owner:human; Agent lane -> owner:agent (IW-7)."""
    skeletons, _ = bpmn_to_tasks.parse_bpmn(FIXTURE)
    by_uid = _by_uid(skeletons)
    assert by_uid["u-review-001"]["owner"] == "human"   # userTask, Human lane
    assert by_uid["u-compile-002"]["owner"] == "agent"   # serviceTask, Agent lane


def test_o1_lane_wins_with_warning():
    """A serviceTask in a human lane resolves owner=human (Lane wins) AND warns (O-1)."""
    skeletons, warnings = bpmn_to_tasks.parse_bpmn(FIXTURE)
    by_uid = _by_uid(skeletons)
    assert by_uid["u-escalate-003"]["owner"] == "human"  # Lane wins over serviceTask
    assert any("Task_escalate" in w and "Lane wins" in w for w in warnings)


def test_skeleton_is_real_frontmatter_not_placeholder():
    """Every emitted block round-trips through yaml.safe_load with real fields."""
    out, _ = bpmn_to_tasks.compile_to_tasks(FIXTURE)
    blocks = [b for b in out.split("---") if b.strip()]
    assert len(blocks) == 3
    for b in blocks:
        doc = yaml.safe_load(b)
        assert doc["id"].startswith("u-")
        assert doc["name"]
        assert doc["owner"] in ("human", "agent")
        assert doc["workflow_type"] == "build"
        assert doc["tier"] == 1
        # skeleton, not a template stub
        assert "[First criterion]" not in b


def test_cli_main_emits_stdout(capsys):
    """The CLI entrypoint prints skeletons to stdout and returns 0."""
    rc = bpmn_to_tasks.main(["bpmn_to_tasks.py", FIXTURE])
    assert rc == 0
    captured = capsys.readouterr()
    assert "id: u-review-001" in captured.out
    assert "owner: human" in captured.out


# ── Slice 2 (T-2532): flow-order -> horizon + related_tasks ──────────────────

def test_horizon_from_flow_order():
    """Flow-order tier maps to AEF horizon: tier1->now, tier2->next, tier3->later."""
    skeletons, _ = bpmn_to_tasks.parse_bpmn(FIXTURE_FLOW)
    by_uid = _by_uid(skeletons)
    assert by_uid["u-spec-1"]["horizon"] == "now"     # first task after start
    assert by_uid["u-impl-2"]["horizon"] == "next"    # second tier (transits GW_1)
    assert by_uid["u-verify-3"]["horizon"] == "later"  # third tier


def test_related_tasks_transit_gateway():
    """related_tasks = nearest task predecessor(s), transiting gateways/events."""
    skeletons, _ = bpmn_to_tasks.parse_bpmn(FIXTURE_FLOW)
    by_uid = _by_uid(skeletons)
    assert by_uid["u-spec-1"]["related_tasks"] == []            # predecessor is a start event
    assert by_uid["u-impl-2"]["related_tasks"] == ["u-spec-1"]  # through exclusiveGateway GW_1
    assert by_uid["u-verify-3"]["related_tasks"] == ["u-impl-2"]


def test_flow_output_carries_new_fields():
    """Emitted YAML frontmatter carries horizon + related_tasks and still round-trips."""
    out, _ = bpmn_to_tasks.compile_to_tasks(FIXTURE_FLOW)
    docs = [yaml.safe_load(b) for b in out.split("---") if b.strip()]
    assert len(docs) == 3
    for d in docs:
        assert d["horizon"] in ("now", "next", "later")
        assert isinstance(d["related_tasks"], list)


def test_no_flow_defaults_horizon_now():
    """A fixture with no sequenceFlows leaves every task at horizon=now (slice-1 fixture)."""
    skeletons, _ = bpmn_to_tasks.parse_bpmn(FIXTURE)
    assert all(s["horizon"] == "now" for s in skeletons)
    assert all(s["related_tasks"] == [] for s in skeletons)


# ── Slice 3 (T-2534): inception subProcess -> workflow_type:inception + owner:human ──

def test_inception_subprocess_emits_inception_type():
    """A subProcess with <aef:meta workflowType="inception"> compiles to workflow_type:inception."""
    skeletons, _ = bpmn_to_tasks.parse_bpmn(FIXTURE_INCEPTION)
    by_uid = _by_uid(skeletons)
    # Only the inception subProcess is a task; start/end events are not.
    assert set(by_uid) == {"u-inception-2"}
    assert by_uid["u-inception-2"]["workflow_type"] == "inception"


def test_inception_owner_is_human_from_sovereignty_lane():
    """Owner is derived from the sovereignty lane (IW-7/IW-9) -> human; go/no-go is sovereign (G-3)."""
    skeletons, _ = bpmn_to_tasks.parse_bpmn(FIXTURE_INCEPTION)
    by_uid = _by_uid(skeletons)
    assert by_uid["u-inception-2"]["owner"] == "human"


def test_inception_constituents_surface_in_output():
    """The <aef:constituents> steps surface as an AC-seed comment in the emitted skeleton."""
    out, _ = bpmn_to_tasks.compile_to_tasks(FIXTURE_INCEPTION)
    assert "# constituents:" in out
    for step in ("Gather evidence", "Assess criteria", "Record decision"):
        assert step in out
    # Still valid frontmatter: the YAML body round-trips (comment lines are ignored).
    docs = [yaml.safe_load(b) for b in out.split("---") if b.strip()]
    assert len(docs) == 1
    assert docs[0]["workflow_type"] == "inception"
    assert docs[0]["owner"] == "human"


def test_inception_counts_in_flow_order():
    """The inception subProcess is a task for flow-order: first after start -> horizon now."""
    skeletons, _ = bpmn_to_tasks.parse_bpmn(FIXTURE_INCEPTION)
    by_uid = _by_uid(skeletons)
    assert by_uid["u-inception-2"]["horizon"] == "now"
    assert by_uid["u-inception-2"]["related_tasks"] == []  # only a start event precedes it


def test_plain_composite_not_emitted_as_inception():
    """A collapsed subProcess WITHOUT the marker is ordinary composition, not a task."""
    skeletons, _ = bpmn_to_tasks.parse_bpmn(FIXTURE_PLAIN)
    by_uid = _by_uid(skeletons)
    # sub_gather (u-gather-9) is a plain composite -> skipped; only the userTask is emitted.
    assert "u-gather-9" not in by_uid
    assert set(by_uid) == {"u-review-9"}
    assert by_uid["u-review-9"]["workflow_type"] == "build"


# ── T-2536: uid attribute serialization (832 canonical corpus) ───────────────

def test_canonical_fixture_byte_guard():
    """The vendored canonical fixture is byte-exact with 832's delivery (sha256 guard)."""
    import hashlib

    with open(FIXTURE_CANONICAL, "rb") as fh:
        digest = hashlib.sha256(fh.read()).hexdigest()
    assert digest == CANONICAL_SHA256, "canonical fixture mutated — re-fetch from 832 rail"


def test_uid_read_from_value_attribute():
    """832 serializes uid as <aef:uid value="X"/> (attribute), not text — must resolve X.

    Regression for T-2536: the attribute form was silently missed, so every node in
    832's real corpus fell back to its node id (hum_1_inception instead of n_inception).
    """
    skeletons, warnings = bpmn_to_tasks.parse_bpmn(FIXTURE_CANONICAL)
    by_uid = _by_uid(skeletons)
    assert "n_inception" in by_uid, "uid attribute form not read"
    assert "hum_1_inception" not in by_uid, "fell back to node id — attribute form missed"
    assert not any("no aef:uid" in w for w in warnings)


def test_canonical_full_parity():
    """832's canonical inception fixture compiles to the same shape as the AEF twin."""
    skeletons, _ = bpmn_to_tasks.parse_bpmn(FIXTURE_CANONICAL)
    by_uid = _by_uid(skeletons)
    node = by_uid["n_inception"]
    assert node["workflow_type"] == "inception"
    assert node["owner"] == "human"  # from <aef:laneMeta authority="sovereignty">


def test_text_form_uid_still_resolves():
    """Regression: the text-content uid form (AEF twin fixtures) still works."""
    skeletons, _ = bpmn_to_tasks.parse_bpmn(FIXTURE)  # two-lane uses <aef:uid>text</aef:uid>
    by_uid = _by_uid(skeletons)
    assert "u-review-001" in by_uid


# ── T-2539: write-out staging slice (uid-keyed proposals, NOT tasks) ─────────

def test_write_stages_proposals_not_tasks(tmp_path):
    """--write stages one proposal file per skeleton under <stage>/<stem>/ — NOT .tasks/ (C1)."""
    skeletons, _ = bpmn_to_tasks.parse_bpmn(FIXTURE)
    out_dir = bpmn_to_tasks.write_proposals(skeletons, FIXTURE, stage_dir=str(tmp_path))
    md = sorted(p.name for p in tmp_path.joinpath("two-lane-sample").glob("*.md"))
    assert md == ["u-compile-002.md", "u-escalate-003.md", "u-review-001.md"]
    # C1: the staging dir is entirely under tmp_path — nothing escapes to a real .tasks path.
    assert str(tmp_path) in out_dir
    assert ".tasks" not in out_dir


def test_proposal_marked_not_a_task(tmp_path):
    """Each proposal carries status: proposal + the promote marker (never a task status)."""
    skeletons, _ = bpmn_to_tasks.parse_bpmn(FIXTURE)
    bpmn_to_tasks.write_proposals(skeletons, FIXTURE, stage_dir=str(tmp_path))
    text = tmp_path.joinpath("two-lane-sample", "u-review-001.md").read_text()
    assert "status: proposal" in text
    assert "status: captured" not in text
    assert "PROPOSAL" in text
    # Still valid frontmatter (comment line ignored by yaml.safe_load).
    doc = yaml.safe_load([b for b in text.split("---") if b.strip()][0])
    assert doc["owner"] == "human"


def test_manifest_keyed_by_uid(tmp_path):
    """manifest.yaml is keyed by aef:uid with name/owner/workflow_type/horizon/sha."""
    skeletons, _ = bpmn_to_tasks.parse_bpmn(FIXTURE)
    bpmn_to_tasks.write_proposals(skeletons, FIXTURE, stage_dir=str(tmp_path))
    manifest = yaml.safe_load(
        tmp_path.joinpath("two-lane-sample", "manifest.yaml").read_text()
    )
    assert manifest["diagram"] == "two-lane-sample.bpmn"
    assert set(manifest["proposals"]) == {"u-review-001", "u-compile-002", "u-escalate-003"}
    entry = manifest["proposals"]["u-review-001"]
    assert entry["owner"] == "human"
    assert entry["workflow_type"] == "build"
    assert len(entry["sha"]) == 16


def test_write_idempotent_upsert(tmp_path):
    """Re-running --write on the same diagram does NOT duplicate — count is stable (C3)."""
    skeletons, _ = bpmn_to_tasks.parse_bpmn(FIXTURE)
    bpmn_to_tasks.write_proposals(skeletons, FIXTURE, stage_dir=str(tmp_path))
    first = sorted(p.name for p in tmp_path.joinpath("two-lane-sample").glob("*.md"))
    bpmn_to_tasks.write_proposals(skeletons, FIXTURE, stage_dir=str(tmp_path))
    second = sorted(p.name for p in tmp_path.joinpath("two-lane-sample").glob("*.md"))
    assert first == second  # upsert by uid, no duplicates


def test_stale_proposal_pruned(tmp_path):
    """A proposal whose uid is no longer emitted is pruned on the next --write."""
    skeletons, _ = bpmn_to_tasks.parse_bpmn(FIXTURE)
    bpmn_to_tasks.write_proposals(skeletons, FIXTURE, stage_dir=str(tmp_path))
    # Drop one node and re-stage: its proposal must disappear.
    bpmn_to_tasks.write_proposals(skeletons[:-1], FIXTURE, stage_dir=str(tmp_path))
    remaining = sorted(p.name for p in tmp_path.joinpath("two-lane-sample").glob("*.md"))
    assert "u-escalate-003.md" not in remaining
    assert len(remaining) == 2


def test_main_write_flag_stages_and_stdouts(tmp_path, capsys, monkeypatch):
    """`--write` stages proposals AND preserves stdout emission (additive)."""
    monkeypatch.setenv("FW_BPMN_STAGE_DIR", str(tmp_path))
    rc = bpmn_to_tasks.main(["bpmn_to_tasks.py", "--write", FIXTURE])
    assert rc == 0
    captured = capsys.readouterr()
    assert "id: u-review-001" in captured.out          # stdout preserved
    assert "staged 3 proposal(s)" in captured.err       # staging reported
    assert tmp_path.joinpath("two-lane-sample", "manifest.yaml").exists()


# ── T-2535 AC3: negative case against 832's REAL canonical bytes ─────────────

def test_resume_status_negative_byte_guard():
    """The vendored canonical negative fixture is byte-exact with 832's delivery."""
    import hashlib

    with open(FIXTURE_RESUME_STATUS, "rb") as fh:
        digest = hashlib.sha256(fh.read()).hexdigest()
    assert digest == RESUME_STATUS_SHA256, "negative fixture mutated — re-fetch from 832 rail"


# ── T-2537: O-3 graduated — fail fast on a mis-laned inception ───────────────

def test_mislaned_inception_fails_fast():
    """An inception subProcess in an initiative/agent lane raises (O-3 v1.1, G-3).

    Supersedes the pre-graduation force-human+WARN: a sovereign go/no-go in a
    non-sovereign lane is a structural defect, not a presentational one (contrast O-1).
    """
    import pytest

    with pytest.raises(bpmn_to_tasks.MalformedInceptionError) as exc:
        bpmn_to_tasks.parse_bpmn(FIXTURE_MISLANED)
    # The error is actionable: names the node and points at the fix.
    assert "sub_incept" in str(exc.value)
    assert "sovereignty" in str(exc.value)


def test_mislaned_inception_cli_exits_nonzero(capsys):
    """The CLI refuses a malformed inception with a non-zero exit + stderr ERROR."""
    rc = bpmn_to_tasks.main(["bpmn_to_tasks.py", FIXTURE_MISLANED])
    assert rc != 0
    err = capsys.readouterr().err
    assert "ERROR" in err
    assert "sub_incept" in err


def test_valid_sovereignty_inception_still_compiles():
    """Regression: a sovereignty-laned inception is unchanged — no raise, owner human."""
    skeletons, _ = bpmn_to_tasks.parse_bpmn(FIXTURE_CANONICAL)
    by_uid = _by_uid(skeletons)
    assert by_uid["n_inception"]["owner"] == "human"
    assert by_uid["n_inception"]["workflow_type"] == "inception"


def test_nameonly_human_lane_now_raises():
    """A name-only 'Human' lane (no laneMeta authority) MUST raise (832 VETO, rail offset 49).

    mapping-v1 §3 (IW-9, v1.1): <aef:laneMeta authority> is the SOLE authority-of-record.
    A lane NAME is not an authority carrier, so a name-only 'Human' lane is not
    sovereignty-laned and fails O-3 identically to no-lane. Supersedes T-2537's
    accept+WARN ramp (which forked conformance against 832's reference validator).
    """
    import pytest

    with pytest.raises(bpmn_to_tasks.MalformedInceptionError) as exc:
        bpmn_to_tasks.parse_bpmn(FIXTURE_NAMEONLY)
    # Actionable: names the offending lane and points at the authority-of-record fix.
    assert "sovereignty" in str(exc.value)


def test_no_laneset_inception_raises(tmp_path):
    """PL-035 existence-rule lock: an inception subProcess in a diagram with NO laneSet
    at all (no lanes, no authority, no human signal) MUST raise — the existence rule
    fires HARDEST on absent input, never no-ops (contrast O-1). 832 offset 50 flagged
    their own validator skipping O-3 on this exact shape via an early return; this test
    proves AEF's inline check does not have that hole.
    """
    import pytest

    bpmn = tmp_path / "no-laneset-inception.bpmn"
    bpmn.write_text(
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<definitions xmlns="http://www.omg.org/spec/BPMN/20100524/MODEL"\n'
        '             xmlns:aef="http://aef/ns">\n'
        '  <process id="p1">\n'
        '    <startEvent id="s1"/>\n'
        '    <subProcess id="sub_bare" name="Explore?">\n'
        '      <extensionElements>\n'
        '        <aef:uid value="u-bare"/>\n'
        '        <aef:meta workflowType="inception"/>\n'
        '      </extensionElements>\n'
        '    </subProcess>\n'
        '  </process>\n'
        '</definitions>\n'
    )
    with pytest.raises(bpmn_to_tasks.MalformedInceptionError) as exc:
        bpmn_to_tasks.parse_bpmn(str(bpmn))
    assert "sub_bare" in str(exc.value)
    assert "sovereignty" in str(exc.value)


def test_canonical_negative_frw_gather_not_inception():
    """frw_7_gather (subProcess WITH constituents, NO workflowType) must NOT compile
    to an inception — validated against 832's REAL resume-status.bpmn bytes (T-2535 AC3).

    This is the negative half of the inception discriminator: presence/absence of
    workflowType="inception" on the subProcess, nothing else. The positive half is
    inception-gonogo-canonical.bpmn (test_canonical_full_parity).
    """
    skeletons, warnings = bpmn_to_tasks.parse_bpmn(FIXTURE_RESUME_STATUS)
    by_uid = _by_uid(skeletons)
    # frw_7_gather is a plain composite -> skipped entirely (not a task).
    assert "frw_7_gather" not in by_uid
    # No node in the whole diagram compiles to inception.
    assert all(s["workflow_type"] != "inception" for s in skeletons)
    # The real userTask/serviceTask nodes ARE emitted (positive control) as build.
    assert len(skeletons) >= 1
    assert all(s["workflow_type"] == "build" for s in skeletons)


# ── T-2552: typed-event surfacing (WARN, no consumption) ─────────────────────

def test_typed_event_annotation_warns_per_kind():
    """Each <aef:eventDef> on a neutral intermediateCatchEvent (832 T-204 Slice 1)
    produces a WARN naming the node, kind, and that AEF does not consume it (T-2551).

    Reliability leg: the flow-walk transits these events but never reads eventDef, so
    without this WARN the kind/binding would be dropped SILENTLY — indistinguishable
    from the parse's intended forward-compat tolerance of unknown tags (T-2552 RCA)."""
    skeletons, warnings = bpmn_to_tasks.parse_bpmn(FIXTURE_TYPED_EVENT)
    typed = [w for w in warnings if "typed-event annotation" in w]
    assert len(typed) == 3, f"expected 3 typed-event WARNs, got {len(typed)}: {typed}"
    joined = "\n".join(typed)
    # one per kind, each naming its node and carrying its binding scalar
    assert "Evt_timer" in joined and "kind=timer" in joined and "timerSpec=PT1H" in joined
    assert "Evt_error" in joined and "kind=error" in joined and "errorStatus=failed" in joined
    assert (
        "Evt_message" in joined
        and "kind=message" in joined
        and "busTopic=inbox.queued" in joined
    )
    # WARN-only: it explicitly points at the scoping inception, does not consume.
    assert all("T-2551" in w for w in typed)


def test_typed_event_diagram_still_compiles_clean():
    """A typed-event diagram compiles WITHOUT crash — the two task nodes emit as build
    skeletons; the events are transited (contribute to related_tasks), never emitted."""
    skeletons, _ = bpmn_to_tasks.parse_bpmn(FIXTURE_TYPED_EVENT)
    by_uid = _by_uid(skeletons)
    assert set(by_uid) == {"u-watch-001", "u-handle-002"}
    assert all(s["workflow_type"] == "build" for s in skeletons)
    # Task_handle sits downstream of the three events → nearest task predecessor is
    # Task_watch, reached by transiting the events (T-2532 flow-walk, unregressed).
    assert "u-watch-001" in by_uid["u-handle-002"]["related_tasks"]


def test_no_typed_event_warn_on_plain_fixtures():
    """The typed-event WARN must NOT fire on diagrams without <aef:eventDef> —
    no false positives on the existing two-lane / inception fixtures."""
    for fx in (FIXTURE, FIXTURE_INCEPTION):
        _, warnings = bpmn_to_tasks.parse_bpmn(fx)
        assert not [w for w in warnings if "typed-event annotation" in w]


# ---------------------------------------------------------------- gateway WARNs (T-2557)

FIXTURE_LIFECYCLE = os.path.join(
    REPO_ROOT, "tests", "fixtures", "bpmn", "task-lifecycle-corpus.bpmn"
)


def test_gateway_warn_per_gateway_with_branch_labels():
    """Each gateway produces one WARN naming node id, gateway name, and every outgoing
    branch label with its target (T-2557, arc-014 D1 finding). Same silent-loss class
    as the typed-event WARN: the flow-walk transits gateways but the DECISION has no
    representation in the emitted skeletons."""
    _, warnings = bpmn_to_tasks.parse_bpmn(FIXTURE_LIFECYCLE)
    gw = [w for w in warnings if "T-2557" in w]
    assert len(gw) == 2, f"expected 2 gateway WARNs, got {len(gw)}: {gw}"
    joined = "\n".join(gw)
    assert "agt_gw_issues" in joined and "issues encountered?" in joined
    assert "agt_gw_human" in joined and "unchecked Human ACs?" in joined
    # branch labels + targets surfaced verbatim
    assert "yes — status: issues → agt_4_heal" in joined
    assert "no — all ACs agent-verifiable → agt_7_archive" in joined
    # WARN-only contract: surfaced, never applied
    assert all("surfaced here, not applied" in w for w in gw)


def test_gateway_warn_no_false_positives_on_plain_fixtures():
    """No gateway WARNs on gateway-free diagrams (two-lane, inception, typed-event)."""
    for fx in (FIXTURE, FIXTURE_INCEPTION, FIXTURE_TYPED_EVENT):
        _, warnings = bpmn_to_tasks.parse_bpmn(fx)
        assert not [w for w in warnings if "T-2557" in w]


def test_lifecycle_corpus_diagram_compiles_clean_with_loop():
    """The D1 corpus diagram (issues↔work back-edge) compiles: 7 skeletons, correct
    owner split, loop predecessors intact — pins the arc-014 D1 result."""
    skeletons, _ = bpmn_to_tasks.parse_bpmn(FIXTURE_LIFECYCLE)
    assert len(skeletons) == 7
    by_uid = {s["uid"]: s for s in skeletons}
    assert by_uid["tl_human_review"]["owner"] == "human"
    assert all(
        s["owner"] == "agent" for s in skeletons if s["uid"] != "tl_human_review"
    )
    assert set(by_uid["tl_work"]["related_tasks"]) == {"tl_start", "tl_heal"}


# ------------------------------------------- 832 real-fixture cross-validation (T-2559)
# Spike-2 of arc-014: 832 delivered their T-204 round-trip fixtures byte-exact over the
# DM rail (offsets 88/89, pinned at 832 master 2bff553). These tests cross-validate the
# T-2552 Pass-3 detector against the PEER's real encoding (L-501), including the
# boundary-event form that directly tests the "detector iterates ALL nodes" claim.

FIXTURE_832_TYPED = os.path.join(
    REPO_ROOT, "tests", "fixtures", "aef-bpmn", "typed-events.bpmn"
)
FIXTURE_832_BOUNDARY = os.path.join(
    REPO_ROOT, "tests", "fixtures", "aef-bpmn", "boundary-events.bpmn"
)
SHA_832_TYPED = "5467071b3a3909629b224ed6357abb5fc8a57c12e18e402106307dd91d2ca5ff"
SHA_832_BOUNDARY = "37eec1b0f10ad02aa5622e28e0e9977ae8bfa9308f59fd36d91048da6d106f1a"


def test_832_fixtures_byte_exact():
    """Both vendored 832 fixtures match their rail-pinned sha256 — the byte-exact
    contract. If this fails the fixture was mutated locally: re-fetch from the rail."""
    import hashlib

    for path, pin in ((FIXTURE_832_TYPED, SHA_832_TYPED), (FIXTURE_832_BOUNDARY, SHA_832_BOUNDARY)):
        with open(path, "rb") as fh:
            assert hashlib.sha256(fh.read()).hexdigest() == pin, f"mutated: {path}"


def test_832_typed_events_fixture_three_warns_no_skeletons():
    """832's real typed-events.bpmn: exactly 3 typed-event WARNs (error/timer/message,
    each naming node id + binding), zero task skeletons (no TASK_TAGS nodes), no drop."""
    skeletons, warnings = bpmn_to_tasks.parse_bpmn(FIXTURE_832_TYPED)
    assert skeletons == []
    typed = [w for w in warnings if "typed-event annotation" in w]
    assert len(typed) == 3, f"expected 3, got {len(typed)}: {typed}"
    joined = "\n".join(typed)
    assert "ev_err" in joined and "kind=error" in joined and "status:issues" in joined
    assert "ev_tmr" in joined and "kind=timer" in joined and "0 9 * * *" in joined
    assert "ev_msg" in joined and "kind=message" in joined and "bus:designer-events" in joined


def test_832_boundary_events_detector_fires_on_boundary_nodes():
    """The offset-85 claim, proven against 832's counter-example fixture: the Pass-3
    detector iterates ALL nodes, so both <bpmn:boundaryEvent> variants (interrupting
    error, non-interrupting timer) fire a typed-event WARN. The host serviceTask still
    emits one agent/build skeleton. KNOWN LIMIT (recorded, T-2560): the WARN carries
    kind+binding only — attachedToRef / cancelActivity / boundaryPos are not mentioned."""
    skeletons, warnings = bpmn_to_tasks.parse_bpmn(FIXTURE_832_BOUNDARY)
    assert len(skeletons) == 1
    assert skeletons[0]["uid"] == "n_host"
    assert skeletons[0]["owner"] == "agent"
    assert skeletons[0]["workflow_type"] == "build"
    typed = [w for w in warnings if "typed-event annotation" in w]
    assert len(typed) == 2, f"expected 2, got {len(typed)}: {typed}"
    joined = "\n".join(typed)
    assert "bnd_err" in joined and "kind=error" in joined
    assert "bnd_tmr" in joined and "kind=timer" in joined and "0 0 * * *" in joined


# ------------------------------- 832 pair-draft #1: session-handover (T-2566)
# 832's T-214 pair-draft, delivered rail offset 92 as a deliberate live T-2557 probe
# (one exclusiveGateway + named branches + back-edge) and the first diagram with a
# THIRD lane authority value (authority="authority", Framework lane).

FIXTURE_832_HANDOVER = os.path.join(
    REPO_ROOT, "tests", "fixtures", "aef-bpmn", "session-handover.bpmn"
)
SHA_832_HANDOVER = "d971a2fccbac6cf93bebcb8ed7de63e6dfc3c6445626e286f18fc282c87f5855"


def test_832_handover_fixture_byte_exact():
    import hashlib

    with open(FIXTURE_832_HANDOVER, "rb") as fh:
        assert hashlib.sha256(fh.read()).hexdigest() == SHA_832_HANDOVER


def test_832_handover_gateway_probe_warns_with_labels():
    """832's deliberate T-2557 probe: the frw_budget gateway + BOTH branch labels
    surface in the WARN — confirms the Pass-4 fix against a peer-authored diagram."""
    _, warnings = bpmn_to_tasks.parse_bpmn(FIXTURE_832_HANDOVER)
    gw = [w for w in warnings if "T-2557" in w]
    assert len(gw) == 1, gw
    assert "frw_budget" in gw[0]
    assert "budget ok → next unit → agt_work" in gw[0]
    assert "critical → wrap up → agt_capture" in gw[0]


def test_832_handover_authority_lane_warns_not_silent():
    """T-2567 (moves the T-2566 current-behavior pin): laneMeta authority="authority"
    (Framework lane) is not in AUTHORITY_OWNER. Nodes still fall back to name/type
    derivation (owner: agent — 832-ratified, rail offset 95: executor is the agent,
    what's lost is authority PROVENANCE), but the fold now surfaces ONE aggregated
    WARN naming the lane, the unrecognized value, and each affected uid→owner."""
    skeletons, warnings = bpmn_to_tasks.parse_bpmn(FIXTURE_832_HANDOVER)
    assert len(skeletons) == 9
    by_uid = {s["uid"]: s for s in skeletons}
    assert by_uid["n_pickup"]["owner"] == "human"
    for uid in ("n_resume", "n_gate", "n_persist"):
        assert by_uid[uid]["owner"] == "agent"
    auth_warns = [w for w in warnings if "unrecognized aef:laneMeta authority" in w]
    assert len(auth_warns) == 1, warnings
    w = auth_warns[0]
    assert "authority='authority'" in w
    assert "Framework" in w  # names the lane
    for pair in ("n_resume→agent", "n_gate→agent", "n_persist→agent"):
        assert pair in w
    assert "T-2567" in w
    # sovereignty/initiative lanes stay silent — additive-only
    assert "Sovereignty" not in w and "Initiative" not in w
    # back-edge through the gateway resolves to the DISTINCT gate node — no self-ref
    assert set(by_uid["n_work"]["related_tasks"]) == {"n_focus", "n_gate"}


def test_recognized_authority_lanes_emit_no_t2567_warn():
    """Additive-only guard: fixtures whose lanes all carry sovereignty/initiative
    must produce ZERO T-2567 WARNs (typed-events + boundary-events + D5 corpus)."""
    for fixture in (FIXTURE_832_TYPED, FIXTURE_832_BOUNDARY):
        _, warnings = bpmn_to_tasks.parse_bpmn(fixture)
        assert not [w for w in warnings if "unrecognized aef:laneMeta authority" in w]


# ------------------------------- 832 pair-draft #2: dispatch-loop (T-2568)
# 832's Sub-Agent Dispatch Protocol, delivered rail offsets 99+101 (chunked after
# two clipped single-shot attempts — the sha pin is what caught the silent 9445-byte
# prefix at offset 98). First diagram through the compiler with parallelGateway
# fork/join, multi-back-edge convergence, and an exclusive branch opening a
# parallel region.

FIXTURE_832_DISPATCH = os.path.join(
    REPO_ROOT, "tests", "fixtures", "aef-bpmn", "dispatch-loop.bpmn"
)
SHA_832_DISPATCH = "95bc24cdb0d27952a4f85da55368b74fc8c1e9586960d0dd839453595543594b"


def test_832_dispatch_fixture_byte_exact():
    import hashlib

    with open(FIXTURE_832_DISPATCH, "rb") as fh:
        assert hashlib.sha256(fh.read()).hexdigest() == SHA_832_DISPATCH


def test_832_dispatch_parallel_fork_join_structure():
    """Probe 1: the fork's 3 workers emit as structural siblings (identical
    related_tasks, no cross-ordering) and the join fans ALL branches back into
    collect's related_tasks — parallel structure round-trips via the task graph."""
    skeletons, warnings = bpmn_to_tasks.parse_bpmn(FIXTURE_832_DISPATCH)
    assert len(skeletons) == 10
    by_uid = {s["uid"]: s for s in skeletons}
    workers = ("n_6f708192", "n_70819203", "n_81920314")  # explore/analyze/review
    for uid in workers:
        assert by_uid[uid]["related_tasks"] == ["n_3c4d5e6f"]  # headroom, via mode→fan
    # seq worker (dependent branch) shares the same nearest-task predecessor
    assert by_uid["n_92031425"]["related_tasks"] == ["n_3c4d5e6f"]
    # join honored: collect fans in all 4 workers (3 parallel + 1 sequential merge)
    assert set(by_uid["n_14253647"]["related_tasks"]) == set(workers) | {"n_92031425"}


def test_832_dispatch_multi_backedge_convergence():
    """Probe 2: agt_2_scope has 3 incoming (start + re-dispatch loop + human-continue
    loop) — each back-edge resolves to a DISTINCT nearest-task predecessor, no
    self-reference, and the start path keeps horizon now."""
    skeletons, _ = bpmn_to_tasks.parse_bpmn(FIXTURE_832_DISPATCH)
    by_uid = {s["uid"]: s for s in skeletons}
    scope = by_uid["n_2b3c4d5e"]
    assert set(scope["related_tasks"]) == {"n_25364758", "n_58697081"}  # synth, check-in
    assert scope["uid"] not in scope["related_tasks"]
    assert scope["horizon"] == "now"
    # sovereignty userTask → human (owner derivation unchanged under new shapes)
    assert by_uid["n_58697081"]["owner"] == "human"


def test_832_dispatch_warn_set_pin():
    """Probes 3+4 + T-2567 live: 5 WARNs — 2 exclusive (labeled branches), 2 parallel
    (<unlabeled> fork edges), 1 aggregated authority-lane fold. NOTE: the parallel
    gateways currently reuse the exclusive decision-semantics wording — that text
    assertion MOVES when T-2569 lands (kind-split wording)."""
    _, warnings = bpmn_to_tasks.parse_bpmn(FIXTURE_832_DISPATCH)
    gw = [w for w in warnings if "Gateway" in w]
    assert len(gw) == 4, warnings
    mode = next(w for w in gw if "agt_4_mode" in w)
    assert "independent · parallel → agt_5_fan" in mode
    assert "dependent · sequential → agt_9_seq" in mode
    complete = next(w for w in gw if "agt_13_complete" in w)
    assert "more · re-dispatch → agt_2_scope" in complete
    fan = next(w for w in gw if "node 'agt_5_fan'" in w)
    assert "parallelGateway" in fan
    assert fan.count("<unlabeled>") == 3
    assert any("node 'agt_10_join'" in w for w in gw)
    auth = [w for w in warnings if "unrecognized aef:laneMeta authority" in w]
    assert len(auth) == 1
    assert "n_3c4d5e6f→agent" in auth[0] and "n_47586970→agent" in auth[0]
