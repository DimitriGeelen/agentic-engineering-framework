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
from playwright.sync_api import Page

# Test fixtures pinned to live tasks in .tasks/completed and .tasks/active —
# these IDs are used because their bodies are stable and known to have (or
# lack) the structural blocks.
TASK_WITH_BOTH_BLOCKS = "T-1582"   # has ## Recommendation (GO) + ## Reviewer Verdict
TASK_WITHOUT_REVIEWER = "T-967"    # no ## Reviewer Verdict block
INCEPTION_WITH_REVIEWER = "T-1346"  # inception task with ## Reviewer Verdict

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

    def test_reviewer_block_absent_when_body_has_no_block(self, page: Page, base_url):
        """Negative case — no `## Reviewer Verdict` body section ⇒ no card."""
        for surface in (f"/tasks/{TASK_WITHOUT_REVIEWER}", f"/review/{TASK_WITHOUT_REVIEWER}"):
            page.goto(_url(base_url, surface))
            page.wait_for_load_state("domcontentloaded")
            content = page.content()
            assert SEC_REVIEWER not in content, (
                f"{surface} renders structural reviewer section despite "
                f"{TASK_WITHOUT_REVIEWER} having no '## Reviewer Verdict' "
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
