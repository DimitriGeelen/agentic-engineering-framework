"""T-1896 (T-1878 B): tests for detect_human_ac_mechanical_signal.

Three-gate detector:
  1. AC under `### Human` with `[REVIEW]` prefix
  2. AC body has no strategic markers (decide / approve / authorize / ...)
  3. Expected clause has at least one mechanical signal AND no taste signals

Positive cases: synthetic [REVIEW] ACs whose Expected reads as a shell check
(grep / curl / file-exists / HTTP status / appended log row).
Negative cases: real arc-grooming [REVIEW] ACs post-T-1894 cleanup, which
are either genuine taste or strategic decisions.
"""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(ROOT))

from lib.reviewer import static_scan as ss  # noqa: E402


# ───────────────────────── Positive cases ─────────────────────────

def test_fires_on_grep_expected():
    ac = """
### Human
- [ ] [REVIEW] Confirm log file shows the new line
  **Steps:**
  1. Tail the log
  **Expected:** `grep -q "new line" /var/log/app.log` returns 0
  **If not:** Inspect log rotation
"""
    findings = ss.detect_human_ac_mechanical_signal(ac)
    assert len(findings) == 1
    assert findings[0].pattern_id == "human-ac-mechanical-signal"
    assert findings[0].ac_index == 1
    assert findings[0].ac_subhead.lower().startswith("human")


def test_fires_on_curl_http_expected():
    ac = """
### Human
- [ ] [REVIEW] Endpoint responds
  **Steps:**
  1. Run curl
  **Expected:** `curl -sf http://localhost:5050/health` returns HTTP 200
  **If not:** Check systemd
"""
    findings = ss.detect_human_ac_mechanical_signal(ac)
    assert len(findings) == 1
    assert "human-ac-mechanical-signal" == findings[0].pattern_id


def test_fires_on_file_appended_expected():
    ac = """
### Human
- [ ] [REVIEW] Audit log row written
  **Steps:**
  1. Trigger event
  **Expected:** A new row appended to `.context/audits/foo.jsonl` with status: closed
  **If not:** Inspect hook
"""
    findings = ss.detect_human_ac_mechanical_signal(ac)
    assert len(findings) == 1


def test_fires_on_status_field_expected():
    ac = """
### Human
- [ ] [REVIEW] Workflow finishes
  **Steps:**
  1. Run it
  **Expected:** Task moves to status: work-completed and `test -f foo.txt` succeeds
  **If not:** Check gate logs
"""
    findings = ss.detect_human_ac_mechanical_signal(ac)
    assert len(findings) == 1


# ───────────────────────── Negative cases ─────────────────────────

def test_silent_on_taste_expected():
    """T-1851/T-1857 post-T-1894 cleanup: taste signals in Expected → suppress."""
    ac = """
### Human
- [ ] [REVIEW] Deprecation banner reads as an obvious supersedes note
  **Steps:**
  1. Open the file
  2. Read the banner
  **Expected:** The voice + framing tells a fresh reader "supersedes" without them needing to chase references.
  **If not:** Edit the banner prose and reopen.
"""
    findings = ss.detect_human_ac_mechanical_signal(ac)
    assert findings == [], f"unexpected findings: {findings}"


def test_silent_on_strategic_ac_body():
    """T-1893: 'Decide whether to close arc' is strategic — suppress even if Expected is mechanical."""
    ac = """
### Human
- [ ] [REVIEW] Decide whether to `fw arc close arc-grooming --demo docs/reports/arc-005-demo.md`
  **Steps:**
  1. Visit fw review-queue URL
  2. Tick remaining ACs
  **Expected:** Arc transitions to `status: closed`, audit log row appended to `.context/audits/arc-close.jsonl`
  **If not:** Use `--justification "..."` to record reservations.
"""
    findings = ss.detect_human_ac_mechanical_signal(ac)
    assert findings == [], f"strategic AC should suppress: {findings}"


def test_silent_on_reads_taste_marker():
    ac = """
### Human
- [ ] [REVIEW] 012-ArcSystem.md reads cleanly as canonical Arc System reference
  **Steps:**
  1. Open in Markdown viewer
  **Expected:** A new operator could orient using only these two surfaces without falling back to source.
  **If not:** Note which section reads thin
"""
    findings = ss.detect_human_ac_mechanical_signal(ac)
    assert findings == [], f"taste AC should suppress: {findings}"


def test_silent_on_review_not_under_human_subhead():
    """A `[REVIEW]` AC accidentally placed under ### Agent must not fire — that's
    a different anti-pattern (treat human prefix as agent AC)."""
    ac = """
### Agent
- [ ] [REVIEW] grep -q PATTERN file
"""
    findings = ss.detect_human_ac_mechanical_signal(ac)
    assert findings == [], f"non-human subhead should suppress: {findings}"


def test_silent_on_non_review_prefix():
    """A `[RUBBER-STAMP]` AC (not [REVIEW]) must not fire — different pattern class."""
    ac = """
### Human
- [ ] [RUBBER-STAMP] Run `grep -q FOO file` to confirm
  **Expected:** Exit code 0
"""
    findings = ss.detect_human_ac_mechanical_signal(ac)
    assert findings == [], f"non-REVIEW prefix should suppress: {findings}"


def test_silent_on_no_expected_clause():
    """An AC with no **Expected:** line cannot be assessed — suppress."""
    ac = """
### Human
- [ ] [REVIEW] Something
  **Steps:**
  1. Look at it
"""
    findings = ss.detect_human_ac_mechanical_signal(ac)
    assert findings == []


# ───────────────────────── Wired into scan_task ─────────────────────────

def test_detector_is_wired_into_scan_task(tmp_path):
    """Ensure run-time wiring: scan_task picks up the new detector."""
    task = tmp_path / "T-9999-mechanical.md"
    task.write_text("""---
id: T-9999
name: mechanical-review-test
status: started-work
workflow_type: build
owner: agent
---

# T-9999: synthetic

## Acceptance Criteria

### Agent
- [x] Did the work

### Human
- [ ] [REVIEW] Confirm endpoint responds
  **Steps:**
  1. curl it
  **Expected:** `curl -sf http://localhost:5050/health` returns 0
  **If not:** Restart service

## Verification

# nothing
""")
    catalogue = ss.load_catalogue(ROOT / "policy" / "anti-patterns.yaml")
    verdict = ss.scan_task(task, catalogue)
    ids = {f.pattern_id for f in verdict.findings}
    assert "human-ac-mechanical-signal" in ids, f"got {ids}"
