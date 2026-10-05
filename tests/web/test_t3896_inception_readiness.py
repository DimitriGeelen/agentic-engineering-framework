"""T-3896 (G-108) — a page that offers a GO must ask the decide gate's question first.

Operator 2026-10-05 clicked GO on T-3659 in Watchtower and was refused: "Cannot
record GO — 4 Open Question(s) not yet disposed". 6 queued inceptions were in
that state. /approvals and /inception/<id> now call the ONE shared predicate
(lib/inception-readiness.sh inception_handoff_blockers, T-3279) and show what
the agent still owes instead of a GO they cannot pass.
"""
from __future__ import annotations

import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

HEAD = """---
id: {tid}
name: "probe {tid}"
status: started-work
workflow_type: inception
owner: human
---

# {tid}

## Problem Statement

A probe.

## Open Questions

- **IW-1: Does it work?** Recommendation: yes.
  confidence: 2
  disposition: {disp}
  rationale: {rat}

## Recommendation

**Recommendation:** GO

**Rationale:** The probe shows it works, measured on a scratch project.

**Evidence:**
- a probe

## Decision

<!-- Filled at completion via: fw inception decide T-XXX go|no-go --rationale "..." -->
"""


def _write(root: Path, tid: str, disp: str, rat: str) -> Path:
    d = root / ".tasks" / "active"
    d.mkdir(parents=True, exist_ok=True)
    p = d / f"{tid}-probe.md"
    p.write_text(HEAD.format(tid=tid, disp=disp, rat=rat), encoding="utf-8")
    return p


@pytest.fixture()
def proj(tmp_path, monkeypatch):
    from web.blueprints import inception
    monkeypatch.setattr(inception, "PROJECT_ROOT", tmp_path)
    ready = _write(tmp_path, "T-9901", "answered", "measured on the probe")
    blocked = _write(tmp_path, "T-9902", "", "")
    return {"root": tmp_path, "ready": ready, "blocked": blocked}


def test_shared_predicate_reports_the_undisposed_question(proj):
    from web.shared import inception_handoff_blockers
    assert inception_handoff_blockers(proj["ready"]) == []
    b = inception_handoff_blockers(proj["blocked"])
    assert [x["kind"] for x in b] == ["undisposed-question"]
    assert b[0]["detail"].startswith("IW-1 disposition=false")


def test_a_broken_predicate_fails_closed(proj, monkeypatch):
    import web.shared as shared
    monkeypatch.setattr(shared, "FRAMEWORK_ROOT", proj["root"] / "nowhere")
    shared._HANDOFF_BLOCKERS_CACHE.clear()
    b = shared.inception_handoff_blockers(proj["ready"])
    assert b and b[0]["kind"] == "check-failed", "a check that cannot run must never read as ready"
    shared._HANDOFF_BLOCKERS_CACHE.clear()


@pytest.fixture()
def client(proj):
    from web.app import app
    app.config["TESTING"] = True
    app.config["WTF_CSRF_ENABLED"] = False
    return app.test_client()


def test_inception_page_offers_no_decision_form_when_not_ready(client):
    page = client.get("/inception/T-9902").get_data(as_text=True)
    assert 'data-testid="inception-not-ready"' in page
    assert "IW-1 disposition=false" in page
    assert 'class="decision-form"' not in page


def test_inception_page_keeps_the_form_when_ready(client):
    page = client.get("/inception/T-9901").get_data(as_text=True)
    assert 'data-testid="inception-not-ready"' not in page
    assert 'class="decision-form"' in page


def test_approvals_card_template_hides_decision_controls_when_blocked():
    src = (ROOT / "web/templates/_approvals_content.html").read_text(encoding="utf-8")
    i_ready = src.index("{% if t.blockers %}")
    i_form = src.index('hx-post="/inception/{{ t.task_id }}/decide"')
    assert i_ready < i_form, "the readiness branch must come before the decide form"
    assert 'data-testid="inception-not-ready"' in src


def test_approvals_loader_attaches_the_gate_answer():
    src = (ROOT / "web/blueprints/approvals.py").read_text(encoding="utf-8")
    assert '"blockers": inception_handoff_blockers(path)' in src
