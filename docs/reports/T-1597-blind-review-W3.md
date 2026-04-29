# Blind Review — Group W3
**Tasks:** 3 reviewed
**Summary:** 2 confirm-GO, 1 flag-concern, 0 inconclusive
**Reviewer:** TermLink blind worker W3 under T-1597
**Date:** 2026-04-29

Group scope: cross-surface parity for Recommendation + Reviewer Verdict cards on `/tasks/T-XXX` and `/inception/T-XXX`, plus the Playwright invariant test that pins all four review surfaces.

---

## T-1584: Surface Recommendation + Reviewer Verdict cards on /tasks/T-XXX page
**Watchtower:** http://192.168.10.107:3000/tasks/T-1584
**Status:** work-completed (owner: human)
**Recommendation:** GO

### Human ACs evaluated

- AC text: "[REVIEW] Recommendation + Reviewer cards on /tasks/T-XXX read cleanly alongside metadata"
  - **Type:** [REVIEW]
  - **Evidence:** `curl -sf http://192.168.10.107:3000/tasks/T-1582 | grep -nE 'recommendation-block|reviewer-verdict-block|Research Artifacts'` — line 913: `<section class="recommendation-block" data-verdict="GO">`, line 936: `<section class="reviewer-verdict-block" data-reviewer-overall="PASS">`, line 944: `<!-- Research Artifacts -->`. Cards render in the exact slot the AC describes — between metadata and Research Artifacts, in the order Recommendation → Reviewer. Both carry the data-attribute palette hooks (`data-verdict="GO"` → green, `data-reviewer-overall="PASS"` → green) and CSS rules at lines 730–795 mirror the `review.html` palette (`#ecfdf5`/`#10b981`/`#065f46` for GO/PASS, parallel triple for DEFER/WARN, NO-GO/FAIL). The Jinja guard works for tasks without these blocks (verified live below).
  - **Blind verdict:** confirm-GO

### Overall
Implementation is correct and matches every Agent AC verbatim. Cards render in the right slot with the right palette and the right data attributes. The Recommendation card and the Reviewer card visually parallel `/review/T-1582`, which is exactly the cross-surface parity the task set out to deliver. **One forward-fragility note worth flagging to the human:** the negative-case command in the task's `## Verification` section (`! curl -sf .../tasks/T-967 | grep -q '<section class="reviewer-verdict-block"'`) would FAIL today — T-967 acquired its own `## Reviewer Verdict (v1.4)` section on 2026-04-28T20:18:03Z (about 5 hours after T-1584 completed at 15:30Z). This is fixture decay, not an implementation regression — the rendering itself still correctly shows/hides the section based on body content. Strongest evidence: T-1265 (inception with no reviewer block) returns 0 occurrences of the section element today, proving the guard still works. **Stamp recommended.**

---

## T-1585: Surface Reviewer Verdict on /inception/T-XXX page
**Watchtower:** http://192.168.10.107:3000/inception/T-1585
**Status:** work-completed (owner: human)
**Recommendation:** GO

### Human ACs evaluated

- AC text: "[REVIEW] Reviewer card on /inception reads cleanly alongside the Agent Recommendation"
  - **Type:** [REVIEW]
  - **Evidence:** `curl -sf http://192.168.10.107:3000/inception/T-1346 | grep -nE 'Agent Recommendation|reviewer-verdict-block|<header>Reviewer'` — line 839 `<!-- Agent Recommendation -->`, line 845 `Agent Recommendation: <strong>GO</strong> — adopted by human`, line 879 `<section class="reviewer-verdict-block" data-reviewer-overall="PASS">`. The two cards are adjacent (40 lines apart in rendered HTML, with the decision banner between them — that's the natural place). No `<header>Reviewer Verdict` heading appears anywhere on the page outside the structured block (the heading-prefix filter in `extra_sections` is doing its job). T-1265 (inception without a reviewer block) returns 0 occurrences of the section — Jinja guard works.
  - **Blind verdict:** confirm-GO

### Overall
Implementation matches all Agent ACs and the Human AC's expected outcome ("green Reviewer card showing PASS, no duplicate Reviewer Verdict rendering further down"). The forward-compat heading-prefix filter (`startswith("Reviewer Verdict")`) is the right call — handles v1.5/v1.6 without code changes. The card placement (immediately after Agent Recommendation, before extra_sections) is the same shape as `/tasks` and `/review`. The decision (inline CSS instead of extracted shared file) is well-reasoned in the `## Decisions` section: three-call-site threshold weighed against three different chrome-scaffold contexts. **Stamp recommended.**

---

## T-1586: Cross-surface parity invariant — pin Recommendation + Reviewer Verdict on all 4 review surfaces (L-316 closure)
**Watchtower:** http://192.168.10.107:3000/tasks/T-1586
**Status:** work-completed (owner: human)
**Recommendation:** GO

### Human ACs evaluated

- AC text: "[REVIEW] Test name + assertions read as a clear contract that future agents will recognize as cross-surface parity protection"
  - **Type:** [REVIEW]
  - **Evidence:** Read `tests/playwright/test_cross_surface_parity.py` (180 lines). Module docstring (lines 1–26) explicitly names L-316, cites the originating arc (T-1531/T-1569 → T-1575/T-1583 → T-1584 → T-1585), and explains the assertion-shape lesson from T-1583 (match `<section class="..."` not bare `class="..."` because CSS rules in inline `<style>` define the same names ~10 times). Three test classes: `TestCrossSurfaceReviewerParity`, `TestCrossSurfaceRecommendationParity`, `TestCrossSurfaceNoRecBanner` — each with a class docstring that names which surfaces it covers and which originating task wired each surface. Per-method docstrings name the surface and the task that introduced it (e.g. line 55: `/tasks/T-XXX (cockpit-extending per-task viewer, T-1584)`). Assertion failure messages name the parity contract (e.g. line 60: "should render structural reviewer section (T-1584 cross-surface parity)"). A future agent who breaks any of these would see the failure message and immediately understand which task introduced the surface and what contract failed. **Docstrings telegraph intent excellently.**
  - **BUT — fixture-decay flag:** `python3 -m pytest tests/playwright/test_cross_surface_parity.py -q --no-header` → **1 failed, 7 passed**. The failure is `test_reviewer_block_absent_when_body_has_no_block` (line 85) — the negative case fixture `TASK_WITHOUT_REVIEWER = "T-967"` (line 33). T-967 acquired its own `## Reviewer Verdict (v1.4)` section on 2026-04-28T20:18:03Z (16 minutes AFTER T-1586 was marked work-completed at 16:16Z). The reviewer scan that runs across all tasks now writes a Reviewer Verdict block back into every task it scans, including T-967, which means **the chosen "negative" fixture is no longer a negative case**. The implementation is fine — the fixture is decayed.
  - **Blind verdict:** flag-concern: invariant test ships fragile fixture choice. The test that was claimed to pass at completion (`6 passed in 16.76s` per Recommendation Evidence) cannot pass today because the reviewer scan systematically eliminates negative cases. A robust fixture would be either (a) a synthetic in-memory task without the block, or (b) a fixture that explicitly creates a task body without `## Reviewer Verdict` for the test session, or (c) periodically re-pick a task that genuinely has no reviewer block. As written, the test will degrade further over time as more tasks acquire reviewer blocks.

### Overall
The contract design and docstring quality are excellent — this is exactly the cross-surface invariant that L-316 needed and a future refactor of any one surface will see this fail loudly. **However**, the negative-case fixture (T-967) was already scheduled to be invalidated by the reviewer scan that the rest of this arc relies on, and that invalidation actually happened 16 minutes after task completion. Strongest evidence both ways: (a) docstrings + assertion messages are the clearest contract-pinning I've seen in this codebase, but (b) the test currently FAILS in the negative-case branch and will not stop failing without a fixture refactor. I would not stamp this as-is — I'd ask for a 5-line fixture fix (either pick a synthetic body or generate a no-reviewer task on the fly) before closing. The 7 passing positive assertions are solid; the 1 failing negative case is a real issue that the human should see before they click GO.
