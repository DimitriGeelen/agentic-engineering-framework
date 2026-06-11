"""T-2343 — BVP estimator dispatch name-alias fallback.

Pins the dispatch path so dedicated V_* handlers fire under policy ids that
differ from their canonical names. Sibling to test_bvp_estimator_v_dedicated.py.

The fix: dispatch consults both `id` (existing) and `name` (new alias map)
when finding a handler — so a policy entry `{id: F3, name: V_PROMPT_QUALITY}`
dispatches to `score_v_prompt_quality`, not the generic `score_free_driver`
fallback.
"""

from __future__ import annotations

import importlib
import sys
from pathlib import Path

import pytest


@pytest.fixture
def estimator(tmp_path, monkeypatch):
    """Reload the estimator with a fresh POLICY_PATH so tests can swap it."""
    # Ensure the estimator module path is importable
    repo = Path(__file__).resolve().parents[2]
    sys.path.insert(0, str(repo / "agents" / "termlink" / "bvp-estimator"))
    if "estimator" in sys.modules:
        del sys.modules["estimator"]
    import estimator as est  # type: ignore
    importlib.reload(est)
    monkeypatch.setattr(est, "POLICY_PATH", tmp_path / "value-drivers.yaml")
    return est


def _seed_policy(path: Path, free_drivers: list[dict]) -> None:
    """Write a minimal policy with directives + given free drivers."""
    lines = [
        "protected_drivers:",
        "  - id: D1",
        "    name: Antifragility",
        "    weight: 9",
        "  - id: D2",
        "    name: Reliability",
        "    weight: 7",
        "  - id: D3",
        "    name: Usability",
        "    weight: 5",
        "  - id: D4",
        "    name: Portability",
        "    weight: 3",
        "free_drivers:",
    ]
    for d in free_drivers:
        lines.append(f"  - id: {d['id']}")
        if d.get("name"):
            lines.append(f"    name: {d['name']}")
        lines.append(f"    weight: {d['weight']}")
    path.write_text("\n".join(lines) + "\n")


# ─── _load_driver_aliases ───────────────────────────────────────────────────


def test_aliases_empty_when_no_policy(estimator, tmp_path):
    """No policy file → empty aliases (degrades cleanly)."""
    # POLICY_PATH points at a non-existent file
    assert estimator._load_driver_aliases() == {}


def test_aliases_returns_id_to_name(estimator, tmp_path):
    """Free drivers with `name: ...` produce `{id: name}` entries."""
    _seed_policy(tmp_path / "value-drivers.yaml", [
        {"id": "F3", "name": "V_PROMPT_QUALITY", "weight": 7},
        {"id": "F1", "name": "V_CONTEXT_FABRIC", "weight": 7},
        {"id": "F2", "name": "V_COMPONENT_FABRIC", "weight": 6},
    ])
    out = estimator._load_driver_aliases()
    assert out == {
        "F3": "V_PROMPT_QUALITY",
        "F1": "V_CONTEXT_FABRIC",
        "F2": "V_COMPONENT_FABRIC",
    }


def test_aliases_omits_when_name_equals_id(estimator, tmp_path):
    """A driver whose `name` matches its `id` needs no alias entry."""
    _seed_policy(tmp_path / "value-drivers.yaml", [
        {"id": "F-RECALL", "name": "F-RECALL", "weight": 6},
        {"id": "F3", "name": "V_PROMPT_QUALITY", "weight": 7},
    ])
    out = estimator._load_driver_aliases()
    assert out == {"F3": "V_PROMPT_QUALITY"}


def test_aliases_omits_when_name_missing(estimator, tmp_path):
    """A driver without a `name:` field has no alias."""
    _seed_policy(tmp_path / "value-drivers.yaml", [
        {"id": "F-CUSTOM", "weight": 4},  # no name
    ])
    out = estimator._load_driver_aliases()
    assert out == {}


# ─── Dispatch via alias map ──────────────────────────────────────────────────


def _seed_task(tmp_path: Path, name: str = "T-X", body: str = "") -> Path:
    """Write a minimal task fixture under .tasks/active/."""
    tdir = tmp_path / ".tasks" / "active"
    tdir.mkdir(parents=True, exist_ok=True)
    path = tdir / f"{name}.md"
    path.write_text(
        f"---\nid: {name}\nname: \"{name}\"\nstatus: started-work\n"
        f"workflow_type: build\nowner: agent\nhorizon: now\n---\n\n"
        f"# {name}\n\n{body}\n"
    )
    return path


def test_dispatch_f3_calls_v_prompt_quality_handler(estimator, tmp_path):
    """Policy id F3 with name V_PROMPT_QUALITY must dispatch to
    score_v_prompt_quality, not the generic score_free_driver fallback."""
    _seed_policy(tmp_path / "value-drivers.yaml", [
        {"id": "F3", "name": "V_PROMPT_QUALITY", "weight": 7},
    ])
    # Body must trigger ONE of the prompt-quality handler's specific signals
    # (handler emits "→N (...)" arrows with phrasing distinct from the
    # generic fallback's "→N (...)" — we assert the handler ran by checking
    # the evidence arrow text is NOT the generic fallback shape).
    path = _seed_task(
        tmp_path, "T-V3",
        body="Adds a reusable prompt template covering AGENT.md preambles.",
    )
    drivers = estimator._load_drivers()
    result = estimator.estimate_task(path, drivers)
    assert "F3" in result["scores"]
    # The V_PROMPT_QUALITY handler emits arrows like "→3 (reusable prompt...)" —
    # check the arrow exists and is from the dedicated handler. The generic
    # score_free_driver fallback emits "→N (body:...keyword-only...)" shape.
    f3_ev = result["evidence"]["F3"]
    arrows = [e for e in f3_ev if e.startswith("→")]
    assert arrows, f"no arrow evidence for F3 — got: {f3_ev}"
    # Dedicated handler arrows include phrases the generic fallback doesn't
    # (e.g. "prompt", "template"). The generic fallback's arrow is generic.
    assert any(("prompt" in a.lower() or "template" in a.lower() or "rubric" in a.lower())
               for a in arrows), f"F3 arrows look generic: {arrows}"


def test_dispatch_f1_calls_v_context_fabric_handler(estimator, tmp_path):
    """Policy id F1 with name V_CONTEXT_FABRIC must dispatch to
    score_v_context_fabric."""
    _seed_policy(tmp_path / "value-drivers.yaml", [
        {"id": "F1", "name": "V_CONTEXT_FABRIC", "weight": 7},
    ])
    path = _seed_task(
        tmp_path, "T-V1",
        body="Touches Context Fabric working memory and episodic episodics.",
    )
    drivers = estimator._load_drivers()
    result = estimator.estimate_task(path, drivers)
    arrows = [e for e in result["evidence"]["F1"] if e.startswith("→")]
    assert arrows
    assert any(("context fabric" in a.lower() or "memory" in a.lower() or "episodic" in a.lower())
               for a in arrows), f"F1 arrows look generic: {arrows}"


def test_dispatch_f2_calls_v_component_fabric_handler(estimator, tmp_path):
    """Policy id F2 with name V_COMPONENT_FABRIC must dispatch to
    score_v_component_fabric."""
    _seed_policy(tmp_path / "value-drivers.yaml", [
        {"id": "F2", "name": "V_COMPONENT_FABRIC", "weight": 6},
    ])
    path = _seed_task(
        tmp_path, "T-V2",
        body="Updates the Component Fabric topology with blast-radius edges.",
    )
    drivers = estimator._load_drivers()
    result = estimator.estimate_task(path, drivers)
    arrows = [e for e in result["evidence"]["F2"] if e.startswith("→")]
    assert arrows
    assert any(("component fabric" in a.lower() or "topology" in a.lower() or "blast" in a.lower())
               for a in arrows), f"F2 arrows look generic: {arrows}"


def test_dispatch_unknown_driver_falls_back_to_score_free_driver(estimator, tmp_path):
    """A custom free driver with no name matching any handler must fall through
    to the generic score_free_driver — not crash or skip."""
    _seed_policy(tmp_path / "value-drivers.yaml", [
        {"id": "F-CUSTOM", "name": "Custom Driver", "weight": 4},
    ])
    path = _seed_task(tmp_path, "T-CUSTOM")
    drivers = estimator._load_drivers()
    result = estimator.estimate_task(path, drivers)
    # Score exists; evidence comes from the generic fallback
    assert "F-CUSTOM" in result["scores"]
    assert "F-CUSTOM" in result["evidence"]


def test_dispatch_explicit_v_prompt_quality_id_still_works(estimator, tmp_path):
    """Backward-compat: if a future Sovereign --add re-canonicalises the
    policy to use `id: V_PROMPT_QUALITY` directly, dispatch still works."""
    _seed_policy(tmp_path / "value-drivers.yaml", [
        {"id": "V_PROMPT_QUALITY", "name": "V_PROMPT_QUALITY", "weight": 7},
    ])
    path = _seed_task(
        tmp_path, "T-VPQ",
        body="Adds a reusable prompt rubric for evaluator handoffs.",
    )
    drivers = estimator._load_drivers()
    result = estimator.estimate_task(path, drivers)
    assert "V_PROMPT_QUALITY" in result["scores"]
    arrows = [e for e in result["evidence"]["V_PROMPT_QUALITY"] if e.startswith("→")]
    assert any(("prompt" in a.lower() or "rubric" in a.lower())
               for a in arrows)


def test_dispatch_dedicated_handlers_for_f_recall_unchanged(estimator, tmp_path):
    """Regression: F-RECALL must still dispatch to score_f_recall (T-2168)."""
    _seed_policy(tmp_path / "value-drivers.yaml", [
        {"id": "F-RECALL", "name": "Recall Leverage", "weight": 6},
    ])
    path = _seed_task(tmp_path, "T-FR", body="No memory-layer signal here.")
    drivers = estimator._load_drivers()
    result = estimator.estimate_task(path, drivers)
    assert "F-RECALL" in result["scores"]
    # F-RECALL handler emits "→0 (...)" or higher; existence proves dispatch
    arrows = [e for e in result["evidence"]["F-RECALL"] if e.startswith("→")]
    assert arrows
