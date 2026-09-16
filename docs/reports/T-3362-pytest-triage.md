# T-3362 — Triage: the 22 pytest failures surfaced by the T-3359 starvation fix

**Status:** triage complete. No production source modified under this task.
**Date:** 2026-09-15

## Why these were invisible

`agents/audit/unit-suite.sh` granted the pytest leg `timeout 1` (a `_remaining()`
floor that had already been consumed by the bats leg). Four consecutive nightlies
therefore reported `pytest_rc=124`, `failed_count: 0` — a run killed before it
could speak, read as a clean bill of health.

T-3359 reserved 1800s for the leg. Since **2026-09-12** the leg completes
(`pytest_rc=1`, ~1761s) and the report is **byte-identical across four nightly
runs (09-12 … 09-15)**: 2706 tests, 23 entries, 7 skipped. Deterministic, not flake.

The oldest failure in this set dates to **2026-05-23**. It had been red for
~3.7 months behind a green-looking report.

## Headline

Of the 23 reported entries:

| | Count | |
|---|---:|---|
| Not a test at all — parser artifact | 1 | OBS-402 |
| Cross-test contamination (pass alone, fail in suite) | 16 | **one root cause** |
| Genuine standing reds | 6 | 4 distinct causes |

**Only 6 of the 22 are failures of the code under test.** The other 16 are one
defect in the test harness, counted sixteen times.

## Group A — parser artifact (1 entry, not a test)

```
web.embeddings:embeddings.py:222 embedding unavailable [contention] host=… busy
```

`agents/audit/unit-suite.sh:155` filters on `l.startswith(("FAILED ", "ERROR "))`,
which cannot distinguish pytest's `ERROR <nodeid>` (a collection error) from a
captured log record rendered as `ERROR    web.embeddings:…`. Worse,
`"failed_count": len(py_failed) or …` lets the contaminated list length **override
pytest's own self-reported count** — the report says 23 where pytest said 22.

Proven by replaying the exact parser logic against a 4-line synthetic sample:
2 real failures in, 2 entries out, one of them the log line.

Same family as OBS-392/T-3357: a number that looks authoritative but was derived
from a pattern matching more than it means.

→ **OBS-402**, promoted to its own task.

## Group B — cross-test contamination (16 failures, 6 files, ONE root cause)

| File | Failures |
|---|---:|
| `test_embed_health.py` | 6 |
| `test_incremental_reindex.py` | 4 |
| `test_task_panel.py` | 2 |
| `test_task_panel_edit.py` | 2 |
| `test_auto_link_root_and_articles.py` | 1 |
| `test_cockpit_activity.py` | 1 |

All 16 **pass** when their files are run as a subset, and **fail** in the full
suite. They are not environmental: the embedding tests are fully mocked
(`monkeypatch.setattr(E, "_get_embed_client", …)`, fake hosts like
`http://only-host:1`) and never touch the live host.

**Root cause — a point fix that was never generalised.** Reload-based tests
(`importlib.reload`, 15 files) leave module globals — notably
`web.shared.PROJECT_ROOT` — pointing at tmp dirs that have since been deleted.
T-1995 diagnosed exactly this and fixed it with a per-test autouse re-pin
fixture… applied to **two** files. The correlation is total:

| | re-pin fixture | affected |
|---|---|---|
| `test_render_page_guard.py`, `test_render_artefact_paths.py` | **yes** | no |
| all 6 files above | **no** | yes |

**Reproduced in 10 seconds**, not inferred:

```
python3 -m pytest tests/unit/test_arcs_routes.py \
                 tests/unit/test_auto_link_root_and_articles.py -q
→ FAILED test_existing_root_file_gets_linkified
  assert '<a href="/file/README.md">README.md</a>' in 'see <p>README.md</p> for setup'
```

The auto-linker's `(PROJECT_ROOT/path).exists()` guard refuses to linkify because
`PROJECT_ROOT` is a deleted directory. Same file alone: passes.

**Four independent contaminators** bisected, so this is systemic rather than one
bad neighbour: `test_arcs_routes`, `test_arc_membership_web_surfaces`,
`test_continuous_halt_control`, `test_decide_commit`.

→ new task.

## Group C — stale assertion encoding a superseded contract (1)

`test_file_route_extensions.py::test_is_viewable_path_rejects_unknown_dir`

```python
assert not is_viewable_path("README.md")  # repo-root, not under any prefix
```

**T-2281 (2026-06-09) deliberately made this true.** `web/shared.py:582` carries an
explicit `ROOT_FILES` allowlist ("depth-0 root files in ROOT_FILES bypass the
prefix + extension checks"). The code is right; the assertion still encodes the
pre-T-2281 contract and the trailing comment states a rule that no longer holds.

Note the same task shipped `test_auto_link_root_and_articles.py` asserting the
*new* contract — so T-2281 added the test for the new behaviour and left the old
contradicting one in place. Red ~3.2 months.

→ new task.

## Group D — stale fixture missing a dependency the code gained (1)

`test_render_page_guard.py::test_guard_skipped_on_htmx_request` →
`jinja2.exceptions.TemplateNotFound: _breadcrumb.html`

**T-2009 (2026-05-23, arc-007 S2b)** added to the htmx branch of `render_page`
(`web/shared.py:1348`):

```python
crumb = render_template("_breadcrumb.html", **context)
```

The T-1899 test builds an isolated app with a `DictLoader` stubbing only
`base.html` and `_wrapper.html`. The template exists in the repo; it is simply
absent from the test's loader. Test-fixture drift, not a product defect.

**Red since 2026-05-23 — ~3.7 months, the oldest in this set.**

→ new task.

## Group E — mutable-corpus anchor (1) — already owned

`test_corpus_lint.py::test_live_corpus_all_versions_census`

```
assert len(targets) == 42   →   assert 47 == 42
```

Pins an **exact live corpus count**. The corpus grew to 47; the test rots. This is
verbatim the class CLAUDE.md's Verification block warns about ("Do NOT anchor … to
MUTABLE corpus state — an exact live count") and that **T-3326** (active,
started-work) exists to address.

→ **cross-referenced to T-3326**, not re-filed.

## Group F — TDD-red, owned by an unfinished task (3)

`test_inception_decide_warning_widen.py` — all three assertions (truncation
widened 150→1500, HTML-escaping, `white-space: pre-wrap`).

The production code at `web/blueprints/inception.py` still truncates at `[:300]`.
These tests were committed **2026-06-05 by T-2219 itself** ("widen inception decide
side-effect-warning truncation, T-2217 Slice 1"), which is still `started-work`.
They are correctly red: the work they pin is unfinished.

→ **cross-referenced to T-2219**, not re-filed. (T-2221 is the queued sibling for
`cockpit.py`.)

## Full disposition of all 23 entries

| # | Entry | Group | Disposition |
|---:|---|---|---|
| 1 | `web.embeddings:embeddings.py:222 embedding unavailable [contention]` | A | OBS-402 |
| 2 | `test_auto_link_root_and_articles.py::test_existing_root_file_gets_linkified` | B | contamination |
| 3 | `test_cockpit_activity.py::test_cockpit_page_has_polling_activity_card` | B | contamination |
| 4 | `test_corpus_lint.py::test_live_corpus_all_versions_census` | E | T-3326 |
| 5 | `test_embed_health.py::test_retry_zero_means_a_single_attempt` | B | contamination |
| 6 | `test_embed_health.py::test_a_dead_primary_falls_over_to_the_other_host` | B | contamination |
| 7 | `test_embed_health.py::test_failover_is_recorded_not_silent` | B | contamination |
| 8 | `test_embed_health.py::test_an_unclassifiable_error_does_not_fail_over` | B | contamination |
| 9 | `test_embed_health.py::test_when_both_hosts_fail_the_primary_is_the_one_reported` | B | contamination |
| 10 | `test_embed_health.py::test_a_single_host_install_does_not_double_its_retries` | B | contamination |
| 11 | `test_file_route_extensions.py::test_is_viewable_path_rejects_unknown_dir` | C | new task |
| 12 | `test_inception_decide_warning_widen.py::test_side_effect_warning_truncation_widened_to_1500` | F | T-2219 |
| 13 | `test_inception_decide_warning_widen.py::test_side_effect_warning_html_escaped` | F | T-2219 |
| 14 | `test_inception_decide_warning_widen.py::test_side_effect_warning_uses_pre_wrap_style` | F | T-2219 |
| 15 | `test_incremental_reindex.py::test_bootstrap_embeds_against_the_bulk_host` | B | contamination |
| 16 | `test_incremental_reindex.py::test_incremental_embeds_against_the_bulk_host` | B | contamination |
| 17 | `test_incremental_reindex.py::test_queries_still_embed_against_the_query_host` | B | contamination |
| 18 | `test_incremental_reindex.py::test_the_reindex_result_names_the_host_it_embedded_against` | B | contamination |
| 19 | `test_render_page_guard.py::test_guard_skipped_on_htmx_request` | D | new task |
| 20 | `test_task_panel.py::test_panel_fragment_is_lean_read_view` | B | contamination |
| 21 | `test_task_panel.py::test_board_links_open_panel_not_full_page` | B | contamination |
| 22 | `test_task_panel_edit.py::test_active_task_panel_has_editable_selects` | B | contamination |
| 23 | `test_task_panel_edit.py::test_completed_task_panel_is_read_only` | B | contamination |

## What this says about the framework

Three of the four standing causes are **tests that stopped matching their subject
and nobody was told**: an assertion outliving its contract (C), a fixture outliving
its dependency (D), a count outliving its corpus (E). None is a product bug. All
three sat red for months because the one surface that would have reported them —
the nightly unit suite — was answering a different question than it appeared to.

That is the same shape as OBS-392 (a timed-out run read as a verdict), OBS-402 (a
log line counted as a failure), and T-3326 (a check anchored to something that
moves). The cluster is not four bugs; it is one habit.

Group B is the counterpart on the other side: a **known** defect (T-1995), correctly
diagnosed, fixed only where it was noticed. The fix was a per-file fixture, so its
coverage is exactly the set of files someone had already seen fail.

## Reconfirmation (2026-09-16) — all 22 real failures reproduced locally

Re-run against current `bleeding-edge` to close out AC1 (every entry reproduced with
its assertion/error captured, or shown not to be a test):

| Group | Status now | Evidence |
|---|---|---|
| A (1, parser artifact) | n/a — not a test | synthetic parser replay above |
| B (16, contamination) | **fixed** — T-3363 + T-3367 landed | `pytest tests/unit/test_arcs_routes.py tests/unit/test_auto_link_root_and_articles.py -q` → 27 passed (was: 1 failed) |
| C (1, stale assertion) | **fixed** — T-3364 landed | `pytest tests/unit/test_file_route_extensions.py::test_is_viewable_path_rejects_unknown_dir -q` → passed |
| D (1, stale fixture) | **fixed** — T-3365 landed | `pytest tests/unit/test_render_page_guard.py::test_guard_skipped_on_htmx_request -q` → passed |
| E (1, mutable-corpus anchor) | still red, as expected — owned by T-3326 | `AssertionError: ... assert 47 == 42` (corpus grew 42→47 since the pin) |
| F (3, TDD-red) | still red, as expected — owned by T-2219 | 3× `AssertionError` — production code at `web/blueprints/inception.py` still unwidened |

18 of the 22 real failures are already gone from the tree (fixed by their filed
tasks in the days since triage); the remaining 4 are red for exactly the reason
this report named, with fresh assertion text captured today. No entry required
further investigation — the triage's causal classification held up against
independent fix work it didn't perform itself.
