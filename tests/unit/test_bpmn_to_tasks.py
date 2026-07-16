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


def test_nameonly_human_lane_accepted_with_warning():
    """A name-only 'Human' lane (no laneMeta authority) is accepted + warned, not failed."""
    skeletons, warnings = bpmn_to_tasks.parse_bpmn(FIXTURE_NAMEONLY)
    by_uid = _by_uid(skeletons)
    assert by_uid["u-incept-nameonly"]["owner"] == "human"
    assert by_uid["u-incept-nameonly"]["workflow_type"] == "inception"
    assert any("NAME only" in w for w in warnings)


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
