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


def _make_root(tmp_path, registry_text, with_map=True, source_text=None):
    root = tmp_path
    (root / "tools").mkdir(exist_ok=True)
    (root / "tools" / "conformance-registry.yaml").write_text(registry_text)
    if with_map:
        d = root / ".context/designer/projects/test-map"
        d.mkdir(parents=True)
        (d / "meta.json").write_text(json.dumps({"latest": 1}))
        (d / "v1.bpmn").write_text(_MINIMAL_BPMN)
    if source_text is not None:
        (root / "machine.yaml").write_text(source_text)
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
