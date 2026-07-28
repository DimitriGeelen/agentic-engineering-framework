"""T-2654 (T-2652 GO slice 1): registry-driven conformance checker mechanics.

Pins: registry parse/validation, per-primitive dispatch, behavior parity of
the migrated aef-task-lifecycle leg, unknown-primitive and missing-source
error paths, --all iteration, unregistered-map refusal.

CLI-level assertions run the tool as a subprocess against a synthetic root
(registry + map store + source built in tmp_path) so the registry loader,
dispatch, and exit-code contract are exercised end-to-end, not via internals.
"""

import json
import subprocess
import sys
from pathlib import Path

import pytest

FRAMEWORK_ROOT = Path(__file__).resolve().parents[2]
TOOL = FRAMEWORK_ROOT / "tools" / "corpus_conformance.py"

sys.path.insert(0, str(FRAMEWORK_ROOT / "tools"))
import corpus_conformance as cc  # noqa: E402


_MINIMAL_BPMN = """<?xml version="1.0" encoding="UTF-8"?>
<bpmn:definitions xmlns:bpmn="http://www.omg.org/spec/BPMN/20100524/MODEL"
                  xmlns:aef="https://aef.dev/schema/bpmn/1.0"
                  id="defs_test" targetNamespace="https://aef.dev/test">
  <bpmn:process id="proc_test" isExecutable="false">
    <bpmn:startEvent id="n_start" name="start">
      <bpmn:extensionElements><aef:meta state="captured"/></bpmn:extensionElements>
    </bpmn:startEvent>
    <bpmn:serviceTask id="n_work" name="work">
      <bpmn:extensionElements><aef:meta state="started-work"/></bpmn:extensionElements>
    </bpmn:serviceTask>
    <bpmn:sequenceFlow id="f1" sourceRef="n_start" targetRef="n_work"/>
  </bpmn:process>
</bpmn:definitions>
"""


# T-2658: gateway map for vocabulary-set — one gateway "verdict?" with two
# outgoing branches whose labels jointly cover {alpha, beta, gamma}.
_GATEWAY_BPMN = """<?xml version="1.0" encoding="UTF-8"?>
<bpmn:definitions xmlns:bpmn="http://www.omg.org/spec/BPMN/20100524/MODEL"
                  xmlns:aef="https://aef.dev/schema/bpmn/1.0"
                  id="defs_gw" targetNamespace="https://aef.dev/test">
  <bpmn:process id="proc_gw" isExecutable="false">
    <bpmn:startEvent id="g_start" name="start"/>
    <bpmn:exclusiveGateway id="g_gw" name="verdict?"/>
    <bpmn:serviceTask id="g_a" name="path a"/>
    <bpmn:serviceTask id="g_b" name="path b"/>
    <bpmn:sequenceFlow id="gf0" sourceRef="g_start" targetRef="g_gw"/>
    <bpmn:sequenceFlow id="gf1" name="ALPHA" sourceRef="g_gw" targetRef="g_a"/>
    <bpmn:sequenceFlow id="gf2" name="BETA / GAMMA" sourceRef="g_gw" targetRef="g_b"/>
  </bpmn:process>
</bpmn:definitions>
"""

_VOCAB_REGISTRY = """\
test-map:
  primitive: vocabulary-set
  source: machine.sh
  gateway: "verdict?"
  branch_vocab:
    regex: "[A-Za-z][A-Za-z-]*"
  source_vocab:
    anchor: 'case "\\$verdict" in'
    regex: '([a-z|-]+)\\)'
    first_only: true
    split: "|"
"""

_VOCAB_SOURCE = 'case "$verdict" in\n    alpha|beta|gamma) ;;\n    *) exit 1 ;;\nesac\n'


def _make_root(tmp_path, registry_text, with_map=True, source_text=None,
               map_xml=_MINIMAL_BPMN, source_name="machine.yaml"):
    root = tmp_path
    (root / "tools").mkdir(exist_ok=True)
    (root / "tools" / "conformance-registry.yaml").write_text(registry_text)
    if with_map:
        d = root / ".context/designer/projects/test-map"
        d.mkdir(parents=True)
        (d / "meta.json").write_text(json.dumps({"latest": 1}))
        (d / "v1.bpmn").write_text(map_xml)
    if source_text is not None:
        (root / source_name).write_text(source_text)
    return root


def _run(root, *args):
    return subprocess.run(
        [sys.executable, str(TOOL), "--root", str(root), *args],
        capture_output=True, text=True, timeout=60,
    )


# ── registry loading / validation ───────────────────────────────────────────

def test_valid_registry_parses():
    reg = cc.load_registry(FRAMEWORK_ROOT)
    assert "aef-task-lifecycle" in reg
    assert reg["aef-task-lifecycle"]["primitive"] == "transition-table"
    assert reg["aef-task-lifecycle"]["source"] == "status-transitions.yaml"


def test_unknown_primitive_is_load_error(tmp_path):
    root = _make_root(
        tmp_path,
        "test-map:\n  primitive: vibes\n  source: machine.yaml\n",
        source_text="transitions: []\n",
    )
    proc = _run(root, "--map", "test-map")
    assert proc.returncode == 2
    assert "unknown primitive" in proc.stderr
    assert "Traceback" not in proc.stderr


def test_missing_source_is_load_error(tmp_path):
    root = _make_root(
        tmp_path,
        "test-map:\n  primitive: transition-table\n  source: nope.yaml\n",
    )
    proc = _run(root, "--map", "test-map")
    assert proc.returncode == 2
    assert "source missing" in proc.stderr


def test_malformed_entry_is_load_error(tmp_path):
    root = _make_root(tmp_path, "test-map:\n  primitive: transition-table\n")
    proc = _run(root, "--map", "test-map")
    assert proc.returncode == 2
    assert "malformed" in proc.stderr


def test_unregistered_map_is_load_error(tmp_path):
    root = _make_root(
        tmp_path,
        "other-map:\n  primitive: transition-table\n  source: machine.yaml\n",
        source_text="transitions: []\n",
    )
    proc = _run(root, "--map", "test-map")
    assert proc.returncode == 2
    assert "no registry entry" in proc.stderr


# ── dispatch + verdicts through the registry ────────────────────────────────

def test_registered_map_pass(tmp_path):
    root = _make_root(
        tmp_path,
        "test-map:\n  primitive: transition-table\n  source: machine.yaml\n",
        source_text="transitions:\n  - {from: captured, to: started-work}\n",
    )
    proc = _run(root, "--map", "test-map")
    assert proc.returncode == 0, proc.stderr
    assert "PASS" in proc.stdout


def test_registered_map_divergent(tmp_path):
    root = _make_root(
        tmp_path,
        "test-map:\n  primitive: transition-table\n  source: machine.yaml\n",
        source_text=(
            "transitions:\n"
            "  - {from: captured, to: started-work}\n"
            "  - {from: started-work, to: work-completed}\n"
        ),
    )
    proc = _run(root, "--map", "test-map")
    assert proc.returncode == 1
    assert "code-allows/map-lacks" in proc.stdout


def test_all_iterates_entries_and_reports_worst(tmp_path):
    root = _make_root(
        tmp_path,
        (
            "test-map:\n  primitive: transition-table\n  source: machine.yaml\n"
            "ghost-map:\n  primitive: transition-table\n  source: machine.yaml\n"
        ),
        source_text="transitions:\n  - {from: captured, to: started-work}\n",
    )
    proc = _run(root, "--all")
    # test-map passes; ghost-map has no store dir -> load error dominates.
    assert proc.returncode == 2
    assert "PASS" in proc.stdout
    assert "ghost-map" in proc.stderr


def test_all_empty_registry_is_ok(tmp_path):
    root = _make_root(tmp_path, "{}\n", with_map=False)
    proc = _run(root, "--all")
    assert proc.returncode == 0
    assert "registry empty" in proc.stdout


# ── vocabulary-set primitive (T-2658, T-2652 slice 2) ───────────────────────

def _vocab_root(tmp_path, registry_text=_VOCAB_REGISTRY, source_text=_VOCAB_SOURCE,
                map_xml=_GATEWAY_BPMN):
    return _make_root(tmp_path, registry_text, source_text=source_text,
                      map_xml=map_xml, source_name="machine.sh")


def test_vocab_set_pass(tmp_path):
    root = _vocab_root(tmp_path)
    proc = _run(root, "--map", "test-map")
    assert proc.returncode == 0, proc.stderr
    assert "PASS" in proc.stdout
    assert "alpha, beta, gamma" in proc.stdout


def test_vocab_set_divergent_both_directions(tmp_path):
    # Source enforces {alpha, beta, delta}: map's gamma is map-only,
    # source's delta is code-only.
    src = 'case "$verdict" in\n    alpha|beta|delta) ;;\nesac\n'
    root = _vocab_root(tmp_path, source_text=src)
    proc = _run(root, "--map", "test-map")
    assert proc.returncode == 1
    assert "map-asserts/code-refuses: gamma" in proc.stdout
    assert "code-allows/map-lacks:    delta" in proc.stdout


def test_vocab_set_missing_gateway_is_load_error(tmp_path):
    reg = _VOCAB_REGISTRY.replace('"verdict?"', '"nonexistent?"')
    root = _vocab_root(tmp_path, registry_text=reg)
    proc = _run(root, "--map", "test-map")
    assert proc.returncode == 2
    assert "gateway 'nonexistent?' not found" in proc.stderr
    assert "verdict?" in proc.stderr  # lists what IS present
    assert "Traceback" not in proc.stderr


def test_vocab_set_stale_anchor_is_load_error(tmp_path):
    # Source refactored away the anchor -> extraction empty -> loud failure,
    # never a trivial pass.
    root = _vocab_root(tmp_path, source_text="echo nothing enforceable here\n")
    proc = _run(root, "--map", "test-map")
    assert proc.returncode == 2
    assert "extraction produced nothing" in proc.stderr


def test_vocab_set_unlabeled_branches_divergent_not_crash(tmp_path):
    # Gateway exists but branch labels carry no vocabulary -> every enforced
    # token is code-allows/map-lacks (divergent), not a traceback.
    xml = _GATEWAY_BPMN.replace(' name="ALPHA"', '').replace(' name="BETA / GAMMA"', '')
    root = _vocab_root(tmp_path, map_xml=xml)
    proc = _run(root, "--map", "test-map")
    assert proc.returncode == 1
    assert "code-allows/map-lacks:    alpha" in proc.stdout
    assert "Traceback" not in proc.stderr


def test_vocab_set_missing_spec_keys_is_load_error(tmp_path):
    reg = "test-map:\n  primitive: vocabulary-set\n  source: machine.sh\n  gateway: 'verdict?'\n"
    root = _vocab_root(tmp_path, registry_text=reg)
    proc = _run(root, "--map", "test-map")
    assert proc.returncode == 2
    assert "branch_vocab.regex" in proc.stderr


def test_vocab_set_invalid_regex_is_load_error(tmp_path):
    reg = _VOCAB_REGISTRY.replace('"[A-Za-z][A-Za-z-]*"', '"[unclosed"')
    root = _vocab_root(tmp_path, registry_text=reg)
    proc = _run(root, "--map", "test-map")
    assert proc.returncode == 2
    assert "regex invalid" in proc.stderr


# ── live rails (T-2658 registry entries against the real repo) ──────────────

def test_live_inception_flow_vocab():
    proc = _run(FRAMEWORK_ROOT, "--map", "aef-inception-flow")
    assert proc.returncode == 0, proc.stderr + proc.stdout
    assert "defer, go, no-go" in proc.stdout


def test_live_audit_cron_vocab():
    proc = _run(FRAMEWORK_ROOT, "--map", "aef-audit-cron")
    assert proc.returncode == 0, proc.stderr + proc.stdout
    assert "0, 1, 2" in proc.stdout


def test_live_tier0_escalation_vocab():
    """T-2664: promoted with the rail in the same round (operator GO
    2026-07-28). Disposition gateway branches {approved, rejected} vs the
    decide_approval enum guard (approvals.py) — green first-pass."""
    proc = _run(FRAMEWORK_ROOT, "--map", "aef-tier0-escalation")
    assert proc.returncode == 0, proc.stderr + proc.stdout
    assert "approved" in proc.stdout and "rejected" in proc.stdout


def test_live_dispatch_loop_vocab():
    """T-2659 shipped this knowingly DIVERGENT (event-type labels); the T-2660
    pair-draft relabeled the branches to the enforced ADR-0004 enum and T-2671
    promoted it (operator GO 2026-07-28, 832 pre-validated rail 294). This pin
    flipped from the divergence assertion to PASS per its own docstring."""
    proc = _run(FRAMEWORK_ROOT, "--map", "aef-dispatch-loop")
    assert proc.returncode == 0, proc.stderr + proc.stdout
    for tok in ("success", "error", "paused"):
        assert tok in proc.stdout


# ── behavior parity of the migrated leg (live repo) ─────────────────────────

def test_live_task_lifecycle_verdict_unchanged():
    """The migrated aef-task-lifecycle entry must keep the pre-refactor
    verdict: PASS asserting exactly the enforced transition count."""
    proc = _run(FRAMEWORK_ROOT, "--map", "aef-task-lifecycle")
    assert proc.returncode == 0, proc.stderr
    assert "PASS" in proc.stdout
    assert "aef-task-lifecycle" in proc.stdout


def test_default_map_arg_preserved():
    """Pre-T-2654 CLI contract: no --map defaults to aef-task-lifecycle
    (audit callers relied on this)."""
    proc = _run(FRAMEWORK_ROOT)
    assert proc.returncode == 0, proc.stderr
    assert "aef-task-lifecycle" in proc.stdout
