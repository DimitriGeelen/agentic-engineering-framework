"""T-2140 (T-2138 V2): tests for detect_review_link_homework.

Detector fires when a `### Human` AC's Steps/body contain the review-handoff
homework pattern — text that asks the reviewer to construct the Watchtower
URL themselves instead of emitting a full clickable URL.

Three gates (all must hold):
  1. AC sits under `### Human` subhead
  2. Body or Steps/Expected lines contain a named homework pattern
  3. NO author opt-out marker

Class lineage: T-2030 (origin) → T-2050 (advisory) → T-2138 (RCA) →
T-2139 (V1 keystone gate) → T-2140 (THIS detector, V2 backstop).

Mirrors T-2147 (audience-mismatch) and T-2145 (defer-as-hedge) shapes —
the arc-008 detector triplet.
"""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(ROOT))

from lib.reviewer import static_scan as ss  # noqa: E402


# ───────────────────────── Positive cases ─────────────────────────


def test_fires_on_url_from_bin_fw_watchtower_url():
    """Canonical positive — T-2109's homework Steps."""
    ac = """### Human
- [ ] [REVIEW] Open each Watchtower page and confirm it loads cleanly
  **Steps:**
  1. Open each of these in browser (Watchtower URL from `bin/fw watchtower url`):
     - `/`
     - `/bvp`
     - `/approvals`
  **Expected:** Each page renders in <2s
  **If not:** Screenshot the broken page
"""
    findings = ss.detect_review_link_homework(ac)
    assert len(findings) == 1
    assert findings[0].pattern_id == "review-link-homework"
    assert findings[0].ac_index == 1
    assert "Human" in findings[0].ac_subhead


def test_fires_on_base_from_bin_fw():
    """Second canonical pattern — `base from bin/fw watchtower url`."""
    ac = """### Human
- [ ] [REVIEW] Verify partial-complete review surfaces
  **Steps:**
  1. Resolve base from `bin/fw watchtower url`
  2. Navigate to `<base>/review/T-XXXX`
  **Expected:** Page shows AC table
"""
    findings = ss.detect_review_link_homework(ac)
    assert len(findings) == 1
    assert findings[0].pattern_id == "review-link-homework"


def test_fires_on_watchtower_url_from_parenthetical():
    """Third canonical pattern — `(Watchtower URL from`."""
    ac = """### Human
- [ ] [REVIEW] Confirm review queue renders sorted
  **Steps:**
  1. Open this (Watchtower URL from `bin/fw watchtower url`): /review-queue
  **Expected:** GO recommendations sort first
"""
    findings = ss.detect_review_link_homework(ac)
    assert len(findings) == 1


def test_fires_per_ac_granularity():
    """Two Human ACs both with homework → two findings."""
    ac = """### Human
- [ ] [REVIEW] First check
  **Steps:**
  1. URL from `bin/fw watchtower url`/foo
- [ ] [REVIEW] Second check
  **Steps:**
  1. base from `bin/fw watchtower url`/bar
"""
    findings = ss.detect_review_link_homework(ac)
    assert len(findings) == 2
    assert {f.ac_index for f in findings} == {1, 2}


# ───────────────────────── Negative cases ─────────────────────────


def test_silent_when_pattern_under_agent_subhead():
    """Same homework text under `### Agent` → must be silent."""
    ac = """### Agent
- [x] Run curl on `URL from bin/fw watchtower url`/path (legitimate shell ref)
### Human
- [ ] [REVIEW] Visit http://192.168.10.107:3000/bvp
  **Expected:** Loads cleanly
"""
    findings = ss.detect_review_link_homework(ac)
    assert len(findings) == 0


def test_silent_on_full_url_in_steps():
    """Full clickable URL in Steps → no homework pattern → silent."""
    ac = """### Human
- [ ] [REVIEW] Open the BVP page
  **Steps:**
  1. Open http://192.168.10.107:3000/bvp
  2. Open http://192.168.10.107:3000/approvals
  **Expected:** Each loads <2s
"""
    findings = ss.detect_review_link_homework(ac)
    assert len(findings) == 0


def test_silent_on_opt_out_marker():
    """Author opt-out marker present → silent (documentation-meta class)."""
    ac = """### Human
- [ ] [REVIEW] Confirm the catalogue entry text reads cleanly
  <!-- review-link-homework-ok: this AC quotes the literal homework pattern -->
  **Steps:**
  1. Read the description of "URL from `bin/fw watchtower url`" in the catalogue
  **Expected:** Phrasing is accurate quote
"""
    findings = ss.detect_review_link_homework(ac)
    assert len(findings) == 0


def test_silent_on_alt_opt_out_text():
    """Alt opt-out phrase 'documents the homework pattern' → silent."""
    ac = """### Human
- [ ] [REVIEW] This task documents the homework pattern; verify wording
  **Steps:**
  1. Read T-2138 RCA where the literal "URL from `bin/fw watchtower url`" appears
  **Expected:** Wording matches operator quote
"""
    findings = ss.detect_review_link_homework(ac)
    assert len(findings) == 0


def test_silent_on_empty_ac_section():
    findings = ss.detect_review_link_homework("")
    assert len(findings) == 0


def test_silent_when_no_human_subhead():
    """ACs exist but no Human subhead → silent."""
    ac = """### Agent
- [x] AC body mentions URL from `bin/fw watchtower url` (legitimate shell ref)
"""
    findings = ss.detect_review_link_homework(ac)
    assert len(findings) == 0


def test_silent_on_partial_string_match():
    """Word `URL` appearing but not as part of the homework pattern → silent."""
    ac = """### Human
- [ ] [REVIEW] Verify URL handling
  **Steps:**
  1. Open http://192.168.10.107:3000/bvp
  **Expected:** The URL renders correctly with no 404
"""
    findings = ss.detect_review_link_homework(ac)
    assert len(findings) == 0


# ───────────────────────── Integration into scan_task ─────────────────────────


def test_integrated_in_scan_task(tmp_path):
    """Detector is wired into scan_task pipeline."""
    (tmp_path / "policy").mkdir()
    (tmp_path / "policy" / "anti-patterns.yaml").write_text("# stub\n")
    (tmp_path / ".tasks" / "completed").mkdir(parents=True)
    task_path = tmp_path / ".tasks" / "completed" / "T-9999-test.md"
    task_path.write_text("""---
id: T-9999
name: review-link-homework-fixture
status: work-completed
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-05-31T00:00:00Z
last_update: 2026-05-31T00:00:00Z
date_finished: null
---

# T-9999

## Acceptance Criteria

### Agent
- [x] Built the feature

### Human
- [ ] [REVIEW] Open the new pages and verify
  **Steps:**
  1. Open each (Watchtower URL from `bin/fw watchtower url`):
     - /foo
     - /bar
  **Expected:** Both render

## Verification

# no commands
""")
    catalogue = {
        "verdict_thresholds": {
            "fail_on_severities": ["complete", "severe"],
            "concern_on_severities": ["partial", "narrow", "staleness"],
        },
        "catalogue_version": "test",
    }
    verdict = ss.scan_task(task_path, catalogue)
    ids = [f.pattern_id for f in verdict.findings]
    assert "review-link-homework" in ids
