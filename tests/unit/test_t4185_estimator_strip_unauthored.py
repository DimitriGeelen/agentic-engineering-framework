"""T-4185 (832 OBS-409, their T-1150) — the heuristic scorers read only text
the task's author wrote.

Origin: a stub task (template body, nothing filled in) scored D1=4 D2=4 D3=3
D4=2 F-RECALL=2, every stub identically, because the template's HTML comments
and `#` guidance lines say "completion gate", "fw doctor", ... and the
estimator's own earlier rationale could reach the body too. Pinned here against
the live default template, so a template edit that reintroduces trigger words
cannot slip past.
"""

from __future__ import annotations

import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "agents" / "termlink" / "bvp-estimator"))
os.environ.setdefault("PROJECT_ROOT", str(ROOT))
os.environ.setdefault("FRAMEWORK_ROOT", str(ROOT))

import estimator  # noqa: E402

CORE = {"D1": 10, "D2": 8, "D3": 6, "D4": 4, "F-RECALL": 5}

_FM = """---
id: T-9999
name: "stub"
description: >
  stub
status: captured
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
created: 2026-10-22T00:00:00Z
last_update: 2026-10-22T00:00:00Z
---
"""


def _template_body() -> str:
    text = (ROOT / ".tasks" / "templates" / "default.md").read_text()
    m = estimator._FM_RE.match(text)
    return m.group(2) if m else text


def _write(tmp_path: Path, text: str) -> Path:
    p = tmp_path / "T-9999-stub.md"
    p.write_text(text)
    return p


def test_template_only_stub_scores_zero_on_core_drivers(tmp_path):
    r = estimator.estimate_task(_write(tmp_path, _FM + _template_body()), CORE)
    assert r["scores"] == {d: 0 for d in CORE}, r["evidence"]


def test_html_comment_text_is_not_scored(tmp_path):
    body = "\n## Context\n\n<!-- the completion gate and fw doctor check -->\nRename a label.\n"
    r = estimator.estimate_task(_write(tmp_path, _FM + body), CORE)
    assert r["scores"]["D1"] == 0, r["evidence"]["D1"]
    assert r["scores"]["D2"] == 0, r["evidence"]["D2"]


def test_prior_rationale_below_frontmatter_is_not_scored(tmp_path):
    # Frontmatter never closes, so parse_task hands back the whole file as body.
    text = (
        "---\nid: T-9999\nworkflow_type: build\n"
        "bvp_scores_proposed:\n"
        "  - estimator: bvp-estimator-v1-heuristic\n"
        "    rationale: D1=4 (body:structural-gate via completion gate); D2=4\n"
        "      (body:fw-audit-or-doctor via fw doctor check)\n"
        "\n## Context\n\nRename a label.\n"
    )
    r = estimator.estimate_task(_write(tmp_path, text), CORE)
    assert r["scores"]["D1"] == 0, r["evidence"]["D1"]
    assert r["scores"]["D2"] == 0, r["evidence"]["D2"]


def test_authored_text_still_scores(tmp_path):
    body = _template_body().replace(
        "## Context\n",
        "## Context\n\nAdd a completion gate that refuses the close.\n", 1)
    r = estimator.estimate_task(_write(tmp_path, _FM + body), CORE)
    assert r["scores"]["D1"] == 4, r["evidence"]["D1"]
