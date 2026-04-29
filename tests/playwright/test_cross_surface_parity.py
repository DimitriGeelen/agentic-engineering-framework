"""T-1586: Cross-surface parity invariant for Recommendation + Reviewer Verdict.

The arc T-1531/T-1569 → T-1575/T-1583 → T-1584 → T-1585 shipped structural
Recommendation + Reviewer Verdict cards across all four review surfaces:

- /approvals          (verdict pills on cards — T-1531, reviewer in T-1569)
- /review/T-XXX       (per-task standalone — T-1575/T-1583)
- /tasks/T-XXX        (per-task cockpit-extending — T-1584)
- /inception/T-XXX    (inception decision page — T-1585)

This module pins the contract: for a known task with both blocks, every
surface that renders the body ALSO renders the structured cards. If a future
refactor blinds one of the four, these tests fail — fail-fast, not human-fast.

Drift class: L-316 (cross-surface inheritance — fix-once-per-surface failures
where no invariant pins parity). Origin sweep: T-1582/T-1583/T-1584/T-1585
each plugged one surface; this test prevents the next sweep from starting.

Assertion shape (T-1583 lesson): match `<section class="..."` (the opening
tag, not bare `class="..."`) — the inline `<style>` block defines the same
class names ~10 times, so bare-class greps fire false positives. The opening
`<section` tag occurs 0 or 1 times per surface — that's the real signal.

Fixtures: `page`, `watchtower_server` from conftest.py — Watchtower runs on
FW_TEST_PORT (default 3099) for the test session.
"""
import os
import re
from pathlib import Path

import pytest
from playwright.sync_api import Page

# Test fixtures pinned to live tasks in .tasks/completed and .tasks/active —
# these IDs are used because their bodies are stable and known to have (or
# lack) the structural blocks.
TASK_WITH_BOTH_BLOCKS = "T-1582"   # has ## Recommendation (GO) + ## Reviewer Verdict
INCEPTION_WITH_REVIEWER = "T-1346"  # inception task with ## Reviewer Verdict
TASK_WITH_NO_REC = "T-449"         # build task without ## Recommendation block (NO-REC)


# T-1598: the negative-case fixture (no `## Reviewer Verdict` block) is
# resolved at runtime, not pinned. The daily reviewer scan rewrites completed
# and active task bodies, so any static ID decays. Scanning `.tasks/` each
# session picks a fresh task that still lacks the block.
_REVIEWER_HEADING = re.compile(r"^##\s+Reviewer Verdict\b", re.MULTILINE)
_TASK_ID = re.compile(r"^(T-\d+)-")


@pytest.fixture(scope="session")
def task_without_reviewer() -> str:
    """Return a task ID whose body has no `## Reviewer Verdict` heading.

    Preference order: completed (stable lineage), then active. Skips the test
    if every reachable task has acquired a verdict block — which would itself
    be a useful signal (the negative-case invariant has nothing to assert).
    """
    project_root = Path(
        os.environ.get(
            "PROJECT_ROOT",
            Path(__file__).resolve().parents[2],
        )
    )
    for subdir in ("completed", "active"):
        d = project_root / ".tasks" / subdir
        if not d.is_dir():
            continue
        for path in sorted(d.glob("T-*.md")):
            try:
                body = path.read_text(encoding="utf-8")
            except OSError:
                continue
            if _REVIEWER_HEADING.search(body):
                continue
            m = _TASK_ID.match(path.name)
            if m:
                return m.group(1)
    pytest.skip(
        "No task without `## Reviewer Verdict` heading found under "
        ".tasks/{completed,active} — negative-case fixture cannot resolve."
    )

# Match opening tag, not bare class — CSS rules in inline <style> share names.
SEC_RECOMMENDATION = '<section class="recommendation-block"'
SEC_REVIEWER = '<section class="reviewer-verdict-block"'


def _url(base_url: str, path: str) -> str:
    return f"{base_url}{path}"


class TestCrossSurfaceReviewerParity:
    """Reviewer Verdict structural rendering — all four surfaces.

    A task with `## Reviewer Verdict (vX.Y)` MUST render the structured
    `.reviewer-verdict-block` section on every surface that renders the body.
    A task without that section MUST NOT render the block (Jinja guard).
    """

    def test_reviewer_block_renders_on_tasks_surface(self, page: Page, base_url):
        """`/tasks/T-XXX` (cockpit-extending per-task viewer, T-1584)."""
        page.goto(_url(base_url, f"/tasks/{TASK_WITH_BOTH_BLOCKS}"))
        page.wait_for_load_state("domcontentloaded")
        content = page.content()
        assert SEC_REVIEWER in content, (
            f"/tasks/{TASK_WITH_BOTH_BLOCKS} should render structural reviewer "
            f"section (T-1584 cross-surface parity). Body has '## Reviewer "
            f"Verdict' block but the surface renders no <section> for it."
        )

    def test_reviewer_block_renders_on_review_surface(self, page: Page, base_url):
        """`/review/T-XXX` (mobile-first standalone per-task, T-1583)."""
        page.goto(_url(base_url, f"/review/{TASK_WITH_BOTH_BLOCKS}"))
        page.wait_for_load_state("domcontentloaded")
        content = page.content()
        assert SEC_REVIEWER in content, (
            f"/review/{TASK_WITH_BOTH_BLOCKS} should render structural reviewer "
            f"section (T-1583 cross-surface parity)."
        )

    def test_reviewer_block_renders_on_inception_surface(self, page: Page, base_url):
        """`/inception/T-XXX` (inception decision page, T-1585)."""
        page.goto(_url(base_url, f"/inception/{INCEPTION_WITH_REVIEWER}"))
        page.wait_for_load_state("domcontentloaded")
        content = page.content()
        assert SEC_REVIEWER in content, (
            f"/inception/{INCEPTION_WITH_REVIEWER} should render structural "
            f"reviewer section (T-1585 cross-surface parity)."
        )

    def test_reviewer_block_absent_when_body_has_no_block(self, page: Page, base_url, task_without_reviewer):
        """Negative case — no `## Reviewer Verdict` body section ⇒ no card."""
        task_id = task_without_reviewer
        for surface in (f"/tasks/{task_id}", f"/review/{task_id}"):
            page.goto(_url(base_url, surface))
            page.wait_for_load_state("domcontentloaded")
            content = page.content()
            assert SEC_REVIEWER not in content, (
                f"{surface} renders structural reviewer section despite "
                f"{task_id} having no '## Reviewer Verdict' "
                f"block — Jinja guard regression."
            )


class TestCrossSurfaceRecommendationParity:
    """Recommendation structural rendering — per-task surfaces.

    `/tasks` and `/review` both render the body and MUST surface the
    Recommendation as a `.recommendation-block` with `data-verdict`.
    `/approvals` renders verdict pills on cards (different shape, covered by
    test_verdict_ui.py); `/inception` does not surface Recommendation
    structurally (uses its own pending/adopted/overridden framing).
    """

    def test_recommendation_block_renders_on_tasks_surface(self, page: Page, base_url):
        """`/tasks/T-XXX` shows GO recommendation card with data-verdict (T-1584)."""
        page.goto(_url(base_url, f"/tasks/{TASK_WITH_BOTH_BLOCKS}"))
        page.wait_for_load_state("domcontentloaded")
        content = page.content()
        assert SEC_RECOMMENDATION in content, (
            f"/tasks/{TASK_WITH_BOTH_BLOCKS} should render structural "
            f"recommendation section (T-1584 cross-surface parity)."
        )
        assert 'data-verdict="GO"' in content, (
            f"/tasks/{TASK_WITH_BOTH_BLOCKS} recommendation should carry "
            f"data-verdict=\"GO\" (the body's verdict is GO)."
        )

    def test_recommendation_block_renders_on_review_surface(self, page: Page, base_url):
        """`/review/T-XXX` shows GO recommendation card with data-verdict (T-1575)."""
        page.goto(_url(base_url, f"/review/{TASK_WITH_BOTH_BLOCKS}"))
        page.wait_for_load_state("domcontentloaded")
        content = page.content()
        assert SEC_RECOMMENDATION in content, (
            f"/review/{TASK_WITH_BOTH_BLOCKS} should render structural "
            f"recommendation section (T-1575 cross-surface parity)."
        )
        assert 'data-verdict="GO"' in content, (
            f"/review/{TASK_WITH_BOTH_BLOCKS} recommendation should carry "
            f"data-verdict=\"GO\"."
        )


class TestCrossSurfaceNoRecBanner:
    """NO-REC banner structural rendering — per-task surfaces.

    A task without a `## Recommendation` block (the NO-REC state, T-1576)
    MUST render `<section class="recommendation-block" data-verdict="NO-REC"`
    on every per-task surface — telling the human "the agent has not yet
    written a verdict, this task is not ready for review yet". T-1576/T-1577/
    T-1578 shipped this banner across queue + landing + /review surfaces;
    `task_detail.html` carries the parallel `rec_state == 'NO-REC'` branch.
    No invariant pins it, so a future refactor that drops `rec_state`
    plumbing could silently regress the banner.
    """

    def test_no_rec_banner_renders_on_tasks_surface(self, page: Page, base_url):
        """`/tasks/T-XXX` for a task without `## Recommendation` shows NO-REC banner."""
        page.goto(_url(base_url, f"/tasks/{TASK_WITH_NO_REC}"))
        page.wait_for_load_state("domcontentloaded")
        content = page.content()
        # NO-REC banner uses compound class: `recommendation-block recommendation-norec`
        # Match on opening `<section class="recommendation-block` (prefix) — still
        # excludes CSS rules in <style> which use bare `.recommendation-block`.
        assert '<section class="recommendation-block' in content, (
            f"/tasks/{TASK_WITH_NO_REC} should render the recommendation "
            f"section even in NO-REC state (T-1584 + T-1576/T-1578 parity)."
        )
        assert 'data-verdict="NO-REC"' in content, (
            f"/tasks/{TASK_WITH_NO_REC} should carry data-verdict=\"NO-REC\" "
            f"on the recommendation section — the body has no '## Recommendation' "
            f"block, so rec_state should resolve to NO-REC."
        )

    def test_no_rec_banner_renders_on_review_surface(self, page: Page, base_url):
        """`/review/T-XXX` for a task without `## Recommendation` shows NO-REC banner (T-1578)."""
        page.goto(_url(base_url, f"/review/{TASK_WITH_NO_REC}"))
        page.wait_for_load_state("domcontentloaded")
        content = page.content()
        assert '<section class="recommendation-block' in content, (
            f"/review/{TASK_WITH_NO_REC} should render the recommendation "
            f"section even in NO-REC state (T-1578 banner)."
        )
        assert 'data-verdict="NO-REC"' in content, (
            f"/review/{TASK_WITH_NO_REC} should carry data-verdict=\"NO-REC\" "
            f"on the recommendation section."
        )
