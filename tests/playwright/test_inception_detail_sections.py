"""T-2077 (T-2066 GO scope): /inception/<id> renders Context/AC/Verification/Decisions/RCA.

Symptom T-2066 reported: the inception detail page silently dropped 5 sections
that the body actually contained — Context, RCA, Acceptance Criteria, Verification,
and Decisions. Root cause: blueprint extracted those headings into `all_raw_sections`
and listed them in `KNOWN_SECTIONS` (excluding them from generic render), but never
threaded them into the `sections` dict passed to the template.

This test asserts the rendering contract end-to-end:

  1. An inception task with all 5 sections populated produces a page where all 5
     headers are visible AND each section's content surfaces.
  2. An inception task with NONE of the 5 sections produces a page where none of
     the 5 headers appear (conditional rendering works both ways).

Uses temporary fixture tasks dropped into `.tasks/completed/` (the blueprint reads
from disk at request time, no app restart needed; FileSystemLoader picks up the
template change at server start).
"""
import os
import pathlib
import re
import time

import pytest


PROJECT_ROOT = pathlib.Path(__file__).resolve().parents[2]
COMPLETED = PROJECT_ROOT / ".tasks" / "completed"

# Use a high T-ID that won't collide with real tasks.
POSITIVE_TID = "T-99977"
NEGATIVE_TID = "T-99978"

POSITIVE_FIXTURE = f"""---
id: {POSITIVE_TID}
name: "T-2077 positive fixture — all 5 sections populated"
description: synthetic fixture
status: work-completed
workflow_type: inception
horizon: now
owner: agent
created: 2026-05-28T00:00:00Z
last_update: 2026-05-28T00:00:00Z
date_finished: 2026-05-28T00:00:00Z
tags: []
---

# Positive fixture

## Problem Statement

Sentinel-problem-statement-text.

## Context

Sentinel-context-text — this section MUST render under T-2077.

## Acceptance Criteria

- [x] Sentinel-acceptance-text — this section MUST render under T-2077.

## Verification

Sentinel-verification-text — this section MUST render under T-2077.

## Decisions

Sentinel-decisions-text — this section MUST render under T-2077.

## RCA

Sentinel-rca-text — this section MUST render under T-2077.
"""

NEGATIVE_FIXTURE = f"""---
id: {NEGATIVE_TID}
name: "T-2077 negative fixture — none of the 5 sections present"
description: synthetic fixture
status: work-completed
workflow_type: inception
horizon: now
owner: agent
created: 2026-05-28T00:00:00Z
last_update: 2026-05-28T00:00:00Z
date_finished: 2026-05-28T00:00:00Z
tags: []
---

# Negative fixture

## Problem Statement

Only problem statement — no other sections.

## Exploration Plan

Just exploration.
"""

SECTIONS = ["Context", "Acceptance Criteria", "Verification", "Decisions", "RCA"]


@pytest.fixture
def positive_inception():
    p = COMPLETED / f"{POSITIVE_TID}-t-2077-positive-fixture.md"
    p.write_text(POSITIVE_FIXTURE)
    yield POSITIVE_TID
    try:
        p.unlink()
    except FileNotFoundError:
        pass


@pytest.fixture
def negative_inception():
    p = COMPLETED / f"{NEGATIVE_TID}-t-2077-negative-fixture.md"
    p.write_text(NEGATIVE_FIXTURE)
    yield NEGATIVE_TID
    try:
        p.unlink()
    except FileNotFoundError:
        pass


def test_inception_detail_renders_all_five_sections_when_present(page, positive_inception):
    """All 5 new section headers + their sentinel content surface on a populated body."""
    from tests.playwright.conftest import TEST_URL
    page.goto(f"{TEST_URL}/inception/{positive_inception}", wait_until="domcontentloaded")
    body_html = page.content()

    for sec in SECTIONS:
        # Header rendered (case-sensitive — matches template literal)
        assert f"<header>{sec}</header>" in body_html, (
            f"section '{sec}' header missing from /inception/{positive_inception} — "
            "blueprint or template change is incomplete"
        )

    # Content sentinels visible — guards against future regression where the
    # header renders but content is wired to the wrong key.
    sentinels = [
        "Sentinel-context-text",
        "Sentinel-acceptance-text",
        "Sentinel-verification-text",
        "Sentinel-decisions-text",
        "Sentinel-rca-text",
    ]
    for s in sentinels:
        assert s in body_html, f"content sentinel '{s}' missing — section is empty"


def test_inception_detail_omits_sections_when_absent(page, negative_inception):
    """None of the 5 headers appear when the body has no matching sections."""
    from tests.playwright.conftest import TEST_URL
    page.goto(f"{TEST_URL}/inception/{negative_inception}", wait_until="domcontentloaded")
    body_html = page.content()

    # Problem Statement WAS in the body — sanity check the page rendered something.
    assert "<header>Problem Statement</header>" in body_html, "page didn't render at all"

    for sec in SECTIONS:
        assert f"<header>{sec}</header>" not in body_html, (
            f"section '{sec}' rendered with an empty body — conditional gate broken"
        )
