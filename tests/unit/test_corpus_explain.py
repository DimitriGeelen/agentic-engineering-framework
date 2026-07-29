"""T-2622: corpus explain — walkthrough rendering + authority-stage derivation.

Stage derivation is the load-bearing piece: the cascading-detail model (T-2619)
routes precedence on it, so both directions are pinned against synthetic stores.
"""

import sys
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT / "tools"))

import corpus_conformance as conformance  # noqa: E402
import corpus_explain as ce  # noqa: E402

HEAD = (
    '<?xml version="1.0" encoding="UTF-8"?>'
    '<bpmn:definitions xmlns:bpmn="http://www.omg.org/spec/BPMN/20100524/MODEL" '
    'xmlns:aef="http://anchorpoint.framework/aef/extensions" id="Definitions_x" '
    'targetNamespace="https://aef.anchorpoint.dev/workflows">'
    '<bpmn:process id="Process_x" isExecutable="true">'
    '<bpmn:extensionElements><aef:workflowMeta id="m" version="1" '
    'schemaVersion="2" title="lifecycle test" tier_default="1"/>'
    "</bpmn:extensionElements>"
)
TAIL = "</bpmn:process></bpmn:definitions>"


def _node(tag, nid, name, state=None):
    ext = ""
    if state:
        ext = (f"<bpmn:extensionElements><aef:meta state=\"{state}\"/>"
               "</bpmn:extensionElements>")
    return f'<bpmn:{tag} id="{nid}" name="{name}">{ext}</bpmn:{tag}>'


def _flow(fid, a, b, name=""):
    nm = f' name="{name}"' if name else ""
    return f'<bpmn:sequenceFlow id="{fid}" sourceRef="{a}" targetRef="{b}"{nm}/>'


# Full non-legacy state machine expressed as a map.
GREEN_XML = HEAD + "".join([
    _node("startEvent", "s0", "work identified"),
    _node("serviceTask", "create", "create", "captured"),
    _node("serviceTask", "start", "start", "started-work"),
    _node("serviceTask", "heal", "heal", "issues"),
    _node("serviceTask", "shelve", "shelve", "captured"),
    _node("serviceTask", "archive", "archive", "work-completed"),
    _flow("f0", "s0", "create"),
    _flow("f1", "create", "start"),
    _flow("f2", "start", "heal"),
    _flow("f3", "heal", "start"),
    _flow("f4", "heal", "archive"),
    _flow("f5", "start", "archive"),
    _flow("f6", "start", "shelve"),
]) + TAIL

# Same map minus two edges -> divergent.
THIN_XML = HEAD + "".join([
    _node("serviceTask", "create", "create", "captured"),
    _node("serviceTask", "start", "start", "started-work"),
    _node("serviceTask", "heal", "heal", "issues"),
    _node("serviceTask", "archive", "archive", "work-completed"),
    _flow("f1", "create", "start"),
    _flow("f2", "start", "heal"),
    _flow("f3", "heal", "start"),
    _flow("f5", "start", "archive"),
]) + TAIL

TRANSITIONS = (
    "transitions:\n"
    "  - {from: captured, to: started-work}\n"
    "  - {from: started-work, to: captured}\n"
    "  - {from: started-work, to: issues}\n"
    "  - {from: started-work, to: work-completed}\n"
    "  - {from: issues, to: started-work}\n"
    "  - {from: issues, to: work-completed}\n"
)


def _store(tmp_path, xml, registry=None):
    d = tmp_path / ".context/designer/projects/aef-task-lifecycle"
    d.mkdir(parents=True)
    (d / "meta.json").write_text('{"latest": 1, "uuid": "u-1"}')
    (d / "v1.bpmn").write_text(xml)
    (tmp_path / "status-transitions.yaml").write_text(TRANSITIONS)
    # T-2685: authority_stage reads the conformance registry rather than naming a
    # map, so the fixture carries one. The registry is the real rail opt-in surface
    # (T-2654) — a fixture without it was modelling a world that cannot exist.
    reg = tmp_path / "tools"
    reg.mkdir(exist_ok=True)
    (reg / "conformance-registry.yaml").write_text(registry or (
        "aef-task-lifecycle:\n"
        "  primitive: transition-table\n"
        "  source: status-transitions.yaml\n"
    ))
    return tmp_path


def test_green_rail_grants_detail_authority(tmp_path):
    root = _store(tmp_path, GREEN_XML)
    stage, rail = ce.authority_stage(root, "aef-task-lifecycle")
    assert stage == "detail-authority"
    assert "GREEN" in rail


def test_divergent_rail_stays_transitional_subordinate(tmp_path):
    root = _store(tmp_path, THIN_XML)
    stage, rail = ce.authority_stage(root, "aef-task-lifecycle")
    assert stage == "transitional-subordinate"
    assert "DIVERGENT" in rail
    assert "started-work->captured" in rail


def test_unrailed_map_is_transitional_subordinate(tmp_path):
    """A readable registry that simply has no entry for this map."""
    root = _store(tmp_path, GREEN_XML)
    stage, rail = ce.authority_stage(root, "some-other-map")
    assert stage == "transitional-subordinate"
    assert "no conformance rail" in rail


def test_missing_registry_degrades_with_a_reason(tmp_path):
    """Genuine unreadable-rail conditions still degrade gracefully (LoadError path)."""
    stage, rail = ce.authority_stage(tmp_path, "aef-task-lifecycle")
    assert stage == "transitional-subordinate"
    assert "rail unreadable" in rail


def test_non_transition_primitive_says_rail_present_not_rail_absent(tmp_path):
    """T-2685: a vocabulary-set rail exists; the T-2619 authority model just does not
    stage it. Reporting 'no conformance rail exists' would be a false statement about
    the corpus, which is exactly the class of quiet wrongness this task fixed."""
    root = _store(tmp_path, GREEN_XML, registry=(
        "aef-task-lifecycle:\n"
        "  primitive: vocabulary-set\n"
        "  source: status-transitions.yaml\n"
        "  gateway: whatever\n"
        "  branch_vocab: {regex: 'x'}\n"
        "  source_vocab: {regex: 'y'}\n"
    ))
    stage, rail = ce.authority_stage(root, "aef-task-lifecycle")
    assert stage == "transitional-subordinate"
    assert "rail present (vocabulary-set)" in rail
    assert "no conformance rail" not in rail


def test_programming_errors_in_the_rail_path_are_not_swallowed(tmp_path, monkeypatch):
    """The T-2685 regression pin, and the point of the whole task.

    The original bug was not the wrong arity — it was that a bare `except Exception`
    turned our own TypeError into a legitimate-looking 'transitional-subordinate'
    verdict, so an arity drift introduced in T-2654 survived undetected until T-2685.
    A signature-shape assertion would only restate today's arity; this pins the
    property that actually protects us: if the rail path raises something that is not
    a LoadError, it must reach the caller instead of becoming a verdict."""
    def boom(*_a, **_k):
        raise TypeError("canonical_transitions() missing 1 required positional argument")

    monkeypatch.setattr(ce.conformance, "canonical_transitions", boom)
    root = _store(tmp_path, GREEN_XML)
    with pytest.raises(TypeError):
        ce.authority_stage(root, "aef-task-lifecycle")


def test_live_task_lifecycle_holds_detail_authority():
    """Against the REAL repo: explain's verdict must agree with what the conformance
    checker independently reports. This is the pair that silently disagreed for the
    whole T-2654..T-2685 window — explain said descriptive-only while the rail passed."""
    root = REPO_ROOT
    stage, rail = ce.authority_stage(root, "aef-task-lifecycle")
    assert stage == "detail-authority", rail
    assert "GREEN" in rail
    entry = conformance.load_registry(root)["aef-task-lifecycle"]
    assert conformance.check_entry(root, "aef-task-lifecycle", entry) == 0


def test_explain_renders_every_node_and_the_provenance_footer(tmp_path, capsys):
    root = _store(tmp_path, GREEN_XML)
    assert ce.explain(root, "aef-task-lifecycle") == 0
    out = capsys.readouterr().out
    for name in ("work identified", "create", "start", "heal", "shelve", "archive"):
        assert name in out
    assert "authority stage: detail-authority" in out
    assert "state: captured" in out


def test_search_matches_node_names_and_points_at_explain(tmp_path, capsys):
    root = _store(tmp_path, GREEN_XML)
    assert ce.search(root, "shelve") == 0
    out = capsys.readouterr().out
    assert "aef-task-lifecycle" in out and "fw corpus explain" in out


def test_search_silent_on_no_match(tmp_path, capsys):
    root = _store(tmp_path, GREEN_XML)
    assert ce.search(root, "zzz-no-such-term") == 0
    assert capsys.readouterr().out == ""


# ── T-2623 draft mode ────────────────────────────────────────────────────────

def _draft_store(tmp_path):
    for mid in ("draft-sketch", "real-map"):
        d = tmp_path / ".context/designer/projects" / mid
        d.mkdir(parents=True)
        (d / "meta.json").write_text('{"latest": 1, "uuid": "u"}')
        (d / "v1.bpmn").write_text(HEAD + _node("serviceTask", "n1", "shared-term-node") + TAIL)
    (tmp_path / "status-transitions.yaml").write_text(TRANSITIONS)
    return tmp_path


def test_search_excludes_drafts(tmp_path, capsys):
    root = _draft_store(tmp_path)
    assert ce.search(root, "shared-term") == 0
    out = capsys.readouterr().out
    assert "real-map" in out and "draft-sketch" not in out


def test_explain_renders_draft_provenance(tmp_path, capsys):
    root = _draft_store(tmp_path)
    assert ce.explain(root, "draft-sketch") == 0
    out = capsys.readouterr().out
    assert "DRAFT — not authority" in out
    assert "authority stage: transitional" not in out


def test_lint_collect_targets_skips_drafts(tmp_path):
    import corpus_lint
    root = _draft_store(tmp_path)
    store = root / ".context/designer/projects"
    names = [n for n, _ in corpus_lint.collect_targets([], store)]
    assert names == ["real-map@v1"]
    # explicit targeting still lints a draft
    explicit = [n for n, _ in corpus_lint.collect_targets(["draft-sketch"], store)]
    assert explicit == ["draft-sketch@v1"]
