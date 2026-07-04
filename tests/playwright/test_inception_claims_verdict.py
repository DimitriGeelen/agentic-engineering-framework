"""T-100188 (T-100186 GO slice B): /inception/<id> renders the Recommendation
Verdict block written by the claims validator (T-100187).

Contract under test (T-971 rule — the AC verifies once, this test guards forever):

  1. An inception task with a `## Recommendation Verdict (v1.0)` block renders
     the claims-verdict-block section (data-claims-overall attribute, per-claim
     table rows) on /inception/<id>.
  2. An inception task WITHOUT the block returns 200 and renders no
     claims-verdict-block — conditional rendering works both ways.

Uses temporary fixture tasks dropped into `.tasks/completed/` (the blueprint
reads from disk at request time, no app restart needed) — same mechanics as
tests/playwright/test_inception_detail_sections.py (T-2077).
"""
import pathlib

import pytest


PROJECT_ROOT = pathlib.Path(__file__).resolve().parents[2]
COMPLETED = PROJECT_ROOT / ".tasks" / "completed"

POSITIVE_TID = "T-99975"
NEGATIVE_TID = "T-99976"

_FRONTMATTER = """---
id: {tid}
name: "T-100188 {kind} fixture — claims verdict render"
description: synthetic fixture
status: work-completed
workflow_type: inception
horizon: now
owner: agent
created: 2026-07-05T00:00:00Z
last_update: 2026-07-05T00:00:00Z
date_finished: 2026-07-05T00:00:00Z
tags: []
---
"""

POSITIVE_FIXTURE = _FRONTMATTER.format(tid=POSITIVE_TID, kind="positive") + """
# Positive fixture

## Problem Statement

Sentinel problem statement.

## Recommendation

**Recommendation:** GO — ships in `lib/reviewer/recommendation_claims.py`.

## Recommendation Verdict (v1.0)

- **Scan ID:** RC-fixture01
- **Timestamp:** 2026-07-05T00:00:00Z
- **Overall:** CONFIRMED
- **Claims:** 2

| Claim | Type | Status |
|-------|------|--------|
| `lib/reviewer/recommendation_claims.py` | file | ✓ pass |
| `T-100187` | task_ref | ✓ pass |

## Updates
"""

NEGATIVE_FIXTURE = _FRONTMATTER.format(tid=NEGATIVE_TID, kind="negative") + """
# Negative fixture

## Problem Statement

Only a problem statement and a recommendation — no verdict block.

## Recommendation

**Recommendation:** GO — no reviewer scan has run on this task.
"""


@pytest.fixture
def positive_inception():
    p = COMPLETED / f"{POSITIVE_TID}-t100188-claims-positive-fixture.md"
    p.write_text(POSITIVE_FIXTURE)
    yield POSITIVE_TID
    try:
        p.unlink()
    except FileNotFoundError:
        pass


@pytest.fixture
def negative_inception():
    p = COMPLETED / f"{NEGATIVE_TID}-t100188-claims-negative-fixture.md"
    p.write_text(NEGATIVE_FIXTURE)
    yield NEGATIVE_TID
    try:
        p.unlink()
    except FileNotFoundError:
        pass


def test_claims_verdict_table_renders_when_block_present(page, positive_inception):
    from tests.playwright.conftest import TEST_URL

    page.goto(f"{TEST_URL}/inception/{positive_inception}", wait_until="domcontentloaded")
    block = page.locator(".claims-verdict-block")
    assert block.count() == 1, "claims-verdict-block missing on inception with verdict"
    assert block.get_attribute("data-claims-overall") == "CONFIRMED"

    heading = block.locator("h4").inner_text()
    assert "Evidence Claims" in heading and "CONFIRMED" in heading
    assert "2/2 confirmed" in heading

    rows = block.locator("tbody tr")
    assert rows.count() == 2
    body_html = page.content()
    assert "lib/reviewer/recommendation_claims.py" in body_html
    assert "task_ref" in body_html


def test_page_renders_cleanly_without_verdict_block(page, negative_inception):
    from tests.playwright.conftest import TEST_URL

    resp = page.goto(f"{TEST_URL}/inception/{negative_inception}", wait_until="domcontentloaded")
    assert resp.status == 200
    assert page.locator(".claims-verdict-block").count() == 0, (
        "claims-verdict-block rendered on an inception with no verdict block"
    )
    # The recommendation itself still renders.
    assert "no reviewer scan has run" in page.content()
