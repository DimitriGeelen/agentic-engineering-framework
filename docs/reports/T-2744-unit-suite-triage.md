# T-2744 — Triage of the standing-red `tests/unit/` pytest failures

**Date:** 2026-08-03
**Origin:** OBS-136, filed under T-2741 after a token guard sat red for 28 days.
**Scope:** classify. This task changed no test and no source file.

---

## 1. The headline finding: the suite is not standing-red, it is *unrun*

OBS-136 framed the problem as *"the red is drowned out by background red — one more
red is indistinguishable"*. That framing is **wrong**, and the correction matters more
than the individual failures.

`tests/unit/` holds **383 `.bats` files and 153 pytest files**. Every runner that
touches the directory runs **bats only**:

| Surface | What it runs on `tests/unit/` | pytest on `tests/unit/*.py`? |
|---|---|---|
| `fw test unit` (`bin/fw:7551`) | `bats tests/unit/` | **no** |
| `fw test all` (`bin/fw:7663`) | `bats tests/unit/` | **no** — its pytest leg is `web/test_app.py tests/web/` only (`bin/fw:7701`) |
| GitHub Actions (`.github/workflows/test.yml:46`) | `bats tests/integration/ tests/unit/` | **no** — its only pytest leg is `tests/playwright/` (`:124`) |
| cron (`.context/cron-registry.yaml`) | nothing | no |
| pre-push hook | nothing | no |

There is no `pytest.ini`, `pyproject.toml`, `setup.cfg` or `conftest.py` anywhere in the
repo, so there is no `testpaths` default that would pick them up either.

**No runner, gate, hook, or CI job has ever executed these 2035 tests as a suite.** The
only way any of them runs is when a task author names their own file in a `## Verification`
line — which is exactly what the git history shows: every `pytest tests/unit/...` reference
in episodic memory names a single file, never the directory.

That reframes every failure below. These tests did not "go red and get ignored". They
went red and **nothing anywhere was capable of noticing**. A test that breaks because of
someone *else's* change has no path to being observed at all.

This is the same class as T-2696/T-2697 (`tests/lint/`, globbed by no runner, 7 red, one
51 days old). That fix added `tests/lint/` to `fw test all` as leg 2c. The same session
did not ask whether any *other* directory had the same problem — and this one is 22×
larger and better camouflaged, because `fw test unit` exists, names this exact directory,
and passes.

**Routed to:** T-2745 (see §4). Not fixed here.

### 1a. Why this was invisible even to a careful reader

`fw test unit` prints `=== Bats Unit Tests ===` and a bats count. Nothing in that output
states what it *did not* run. The directory name matches, the command name matches, the
exit code is honest about what it ran. The gap is only visible if you already suspect it.

---

## 2. Census

Command, from `PROJECT_ROOT`, 2026-08-03:

```
python3 -m pytest tests/unit/ -q --tb=no -p no:cacheprovider
→ 24 failed, 2011 passed, 3 skipped in 327.64s
```

Re-run twice; identical counts both times (327.64s / 321.10s). **24, not the 25 in
OBS-136** — T-2741 fixed `test_arcs_pages_tokens`; no other delta.

Re-running **exactly those 24 nodeids in isolation**:

```
python3 -m pytest <the 24 nodeids> -q --tb=short
→ 18 failed, 6 passed in 94.22s
```

**Six failures do not reproduce in isolation.** That split is not visible from a failure
count and is the reason this triage runs the suite two ways. Nodeid list:
`docs/reports/T-2744-census.txt`.

---

## 3. Classification

Taxonomy note: `env-dependent` covers *any* dependency on state outside the test's own
setup — including **process state left behind by an earlier test in the same run**. The
six order-dependent failures are filed under it with the sub-class named explicitly, so
the report is not silently widening a bucket. See §5.

### Cluster A — `fw orchestrator status --json` returns non-JSON (13 tests) — `stale-test`

| Nodeid | Class | Follow-up |
|---|---|---|
| `tests/unit/test_orchestrator_status_outcomes.py::test_default_json_does_not_have_outcomes_key` | stale-test | T-2747 |
| `tests/unit/test_orchestrator_status_outcomes.py::test_outcomes_json_exposes_aggregation` | stale-test | T-2747 |
| `tests/unit/test_orchestrator_status_terminal_events.py::test_json_by_model_empty_when_no_model_field` | stale-test | T-2747 |
| `tests/unit/test_orchestrator_status_terminal_events.py::test_json_exposes_by_model_key` | stale-test | T-2747 |
| `tests/unit/test_orchestrator_status_terminal_events.py::test_json_exposes_terminal_event_keys` | stale-test | T-2747 |
| `tests/unit/test_orchestrator_status_terminal_events.py::test_json_recent_carries_terminal_event` | stale-test | T-2747 |
| `tests/unit/test_orchestrator_status_terminal_events.py::test_json_terminal_keys_empty_when_no_rows_have_terminal_event` | stale-test | T-2747 |
| `tests/unit/test_orchestrator_status_terminal_events.py::test_model_filter_with_json` | stale-test | T-2747 |
| `tests/unit/test_orchestrator_status_terminal_events.py::test_recent_composes_with_json` | stale-test | T-2747 |
| `tests/unit/test_orchestrator_status_terminal_events.py::test_resolved_via_filter_with_json` | stale-test | T-2747 |
| `tests/unit/test_orchestrator_status_terminal_events.py::test_task_filter_composes_with_json` | stale-test | T-2747 |
| `tests/unit/test_orchestrator_status_terminal_events.py::test_task_filter_with_json_returns_empty_stats` | stale-test | T-2747 |
| `tests/unit/test_orchestrator_status_terminal_events.py::test_worker_kind_filter_composes_with_json` | stale-test | T-2747 |

**Symptom:** all 13 die on `json.loads(result.stdout)` → `JSONDecodeError: Expecting value: line 1 column 1`.

**Mechanism, traced end to end.** The fixture (`_seed_jsonl`, `test_orchestrator_status_terminal_events.py:44`)
creates `.context/dispatches.jsonl` and `.context/dispatch-outcomes.jsonl` in `tmp_path`,
then runs `bin/fw` with `env["PROJECT_ROOT"]=tmp_path`. But `bin/fw:189` re-validates the
inherited value through `_project_root_is_stale()`, and that predicate (`bin/fw:185`)
accepts a directory as a project **only** if it holds `.framework.yaml` or `.tasks/`.
A directory with `.context/` alone is judged *stale*, the explicit env var is **discarded**,
`find_project_root()` walks up from the tmp cwd, finds nothing, and `PROJECT_ROOT` ends
up empty. That reaches the auto-init dialogue at `bin/fw:526`, whose non-TTY branch
(`bin/fw:533`) runs `do_init "$PWD"` and re-execs. The init banner lands on **stdout**,
ahead of the JSON.

Reproduced by hand:

```
$ T=$(mktemp -d); mkdir -p "$T/.context"; echo '{...}' > "$T/.context/dispatches.jsonl"
$ cd "$T" && PROJECT_ROOT="$T" /opt/999-Agentic-Engineering-Framework/bin/fw orchestrator status --json
Setting up agentic governance for tmp.ktpgWNGtJu...
  ⚠  Git identity not configured (commits will fail)
  ✓  Task system (.tasks/)
  ...
```

**What changed and when:** the marker-based staleness guard is the T-2390 / T-2391 /
T-2446 daemon-poison family, added *after* these fixtures were written. The fixtures
encode the older contract "exported `PROJECT_ROOT` is authoritative".

**Why `stale-test` and not `genuine-bug`:** the tests are wrong about the current
contract, and the fix that makes them pass is a fixture change (seed `.tasks/`). But
the mechanism exposed a **separate, genuine defect** which is filed on its own — see
Cluster A′.

**★ Why only the `--json` tests fail, and why that is the most important line in this report.**
The text-mode tests in the same files pass, on the same polluted stdout. They assert with
`in`:

```python
assert "By terminal event:" in result.stdout      # passes — banner just precedes it
data = json.loads(result.stdout)                  # fails — strict parse
```

The defect hits **every** test in both files identically. Thirteen fail because they parse
strictly; the rest **pass while asserting against a stdout stream that begins with an
onboarding banner**. Those greens are false. They are the T-2738/T-2739 family — an
assertion that cannot fail for the reason it was written — and they would have stayed
invisible if the file contained no strict parser at all. The strict tests are not the
broken ones; they are the only ones telling the truth.

### Cluster A′ — the genuine defect that Cluster A uncovered — `genuine-bug` → T-2746

Not a test failure; recorded here because Cluster A is how it surfaced.

`bin/fw:533`: when `PROJECT_ROOT` resolves empty **and stdin is not a TTY**, `fw`
silently runs `do_init "$PWD"` — `git init`, seed `.tasks/`, `.context/`, `.claude/`,
vendor `.agentic-framework/` — then re-execs the original command. No prompt, no
confirmation, no `--yes`.

Consequences, in severity order:

1. **A read-only-sounding command mutates the filesystem.** `fw orchestrator status`
   is a status query. Run non-interactively from the wrong cwd, it creates a git repo
   and a vendored framework tree there.
2. **Any non-interactive caller is exposed** — cron, CI, scripts, `subprocess.run`,
   TermLink workers. All are non-TTY by construction. The interactive path correctly
   *asks* (`bin/fw:545`); only the automated path acts unilaterally.
3. **It breaks `--json` machine-readability**, which is what Cluster A is.
4. **It plausibly explains the stray `/.tasks` in Cluster C** — any non-TTY `fw` call
   with `cwd=/` would create exactly that.

The T-519 comment says "Non-TTY: silently use defaults". That was written when init was
small. It now includes `git init` and a full vendor.

There is a second, narrower defect in the same path: an **explicitly exported**
`PROJECT_ROOT` is discarded when the directory lacks a marker. The daemon-poison guards
it was built for concern *inherited* values; an explicit export by a caller who knows
what it wants is a different case and currently indistinguishable from poison.

### Cluster B — order-dependent (6 tests) — `env-dependent` (sub-class: order-dependent) → T-2748

| Nodeid | Class | Follow-up |
|---|---|---|
| `tests/unit/test_auto_link_root_and_articles.py::test_existing_root_file_gets_linkified` | env-dependent | T-2748 |
| `tests/unit/test_cockpit_activity.py::test_cockpit_page_has_polling_activity_card` | env-dependent | T-2748 |
| `tests/unit/test_task_panel.py::test_board_links_open_panel_not_full_page` | env-dependent | T-2748 |
| `tests/unit/test_task_panel.py::test_panel_fragment_is_lean_read_view` | env-dependent | T-2748 |
| `tests/unit/test_task_panel_edit.py::test_active_task_panel_has_editable_selects` | env-dependent | T-2748 |
| `tests/unit/test_task_panel_edit.py::test_completed_task_panel_is_read_only` | env-dependent | T-2748 |

**Evidence for the classification:** all six fail in the full-suite run and all six pass
when the 24 census nodeids are run alone (§2). The dependency is on **process state left
by an earlier test in the same pytest process** — nothing about the host.

**Shared signature.** Four of the six get a **full page** where a lean fragment is
expected (`assert 'data-task-panel=' in '<!DOCTYPE html>\n<html lang="en"...'`), and the
`auto_link` one gets `<p>README.md</p>` where `<a href="/file/README.md">` is expected —
i.e. `_auto_link_files`' `(PROJECT_ROOT/path).exists()` guard failed for a repo-root file.
Both are consistent with a shared Flask app or a `web.shared` module global (`PROJECT_ROOT`,
the jinja loader) being mutated and not restored.

**Ruled out (measured, not assumed):** `test_render_page_guard.py` was the obvious
suspect — it assigns `_shared.PROJECT_ROOT` (`:23`, `:36`) and `app.jinja_env.loader`
(`:57`). Running `test_render_page_guard.py` immediately followed by `test_task_panel.py`
in one process gives **1 failed, 11 passed** — all six task_panel tests pass. It is not
the polluter, or not the only one.

Identifying the polluter needs a bisection over ~150 files and is the fix task's job, not
triage's. Method recorded on T-2748.

### Cluster C — host-environment (1 test) — `env-dependent` → T-2749, T-2750

| Nodeid | Class | Follow-up |
|---|---|---|
| `tests/unit/test_hook_paths.py::ReanchorProjectRoot::test_noop_when_cwd_outside_any_project` | env-dependent | T-2749 (doctor gap), T-2750 (leak source) |

**Symptom:** `AssertionError: '/' != '/tmp/tmpzdc87ld9'` — `reanchor_project_root` returned
the filesystem root instead of the fallback.

**Dependency, and what makes it present here:** there is a stray **`/.tasks/`** directory
on this host:

```
$ ls -la /.tasks/active/
-rw-r--r-- 1 root root 99 Jun 27 19:28 T-9999-test.md
```

`lib/hook_paths.py:reanchor_project_root` walks up from cwd accepting `.framework.yaml`
**or `.tasks/`** as a project marker. From `/tmp/tmpXXXX` the walk reaches `/`, finds
`/.tasks`, and returns `/`. The test is correct; the host is polluted.

Two distinct defects fall out, filed separately:

- **T-2749 (`genuine-bug`)** — `fw doctor` has a stray-root-marker check (`bin/fw:954`,
  T-1747 / G-069) that warns on `/.framework.yaml` and tells you to remove it. It does
  **not** check `/.tasks`, even though every resolver in the codebase treats `.tasks/`
  as an equally valid marker (`bin/fw:find_project_root`, `lib/hook_paths.py`,
  `lib/paths.sh`). G-069 fixed one half of a two-element marker set. This host has been
  in the un-checked half since **2026-06-27 — 37 days** — with doctor green.
- **T-2750 (`genuine-bug`)** — the content is a test fixture (`T-9999-test.md`, the ID
  used by ~10 suites) that escaped to the filesystem root. Some test writes to `/`
  instead of a tmp dir. Sibling of the T-2294 pre-push gate, which exists because
  `T-2293` leaked a bats artefact into a tracked manifest.

**Note:** `/.tasks` is outside this repo and owned by root. Removing it is a host-level
change and is left to the operator — see §6.

### Cluster D — assertions pinned to superseded contracts (4 tests) — `stale-test`

Each has a *different* production change behind it, so each gets its own task.

| Nodeid | Class | Follow-up |
|---|---|---|
| `tests/unit/test_file_route_extensions.py::test_is_viewable_path_rejects_unknown_dir` | stale-test | T-2751 |
| `tests/unit/test_render_page_guard.py::test_guard_skipped_on_htmx_request` | stale-test | T-2752 |
| `tests/unit/test_arc_system.py::test_arc_tag_idempotent` | stale-test | T-2753 |
| `tests/unit/test_corpus_lint.py::test_live_corpus_all_versions_census` | stale-test | T-2754 |

**T-2751 — `is_viewable_path("README.md")`.** Test asserts `not is_viewable_path("README.md")`
with the comment *"repo-root, not under any prefix"*. **T-2281** deliberately added a
`ROOT_FILES` allowlist (`web/shared.py:555`) containing `README.md`, `CLAUDE.md`,
`FRAMEWORK.md`, `VERSION`, `LICENSE`, `CHANGELOG`, with a comment explaining exactly why.
The assertion encodes the pre-T-2281 contract.
**Not a security regression** — checked: the traversal guards (`".." in filepath`) are
untouched and `test_is_viewable_path_rejects_traversal` passes; the two sibling assertions
in the same test (`etc/passwd`, `/etc/passwd`) still hold. Only the `README.md` line is stale.

**T-2752 — `TemplateNotFound: _breadcrumb.html`.** The test builds an isolated app with a
`DictLoader` stubbing `base.html` (`tests/unit/test_render_page_guard.py:54`). It was added
by **T-1899**. **T-2009** ("breadcrumbs on every page header") later made `render_page`
call `render_template("_breadcrumb.html")` (`web/shared.py:1170`). The stub set was never
extended. Only the htmx test fails because only the HX path reaches that call.

**T-2753 — arc tag idempotency proxy.** Test tags twice, then asserts
`task_text.count("arc:alpha") == 1` over the whole file. Actual file:

```
tags: [seed, arc:alpha]                          ← 1
- **Change:** tags: +arc:alpha                   ← 1  (audit log)
```

`count == 2`. **The behaviour under test is correct** — the tag appears once in
frontmatter, and there is only *one* update-log entry despite two `arc tag` calls, so the
second was properly a no-op. What broke is the *proxy*: `update-task.sh:1823` appends a
`- **Change:** …` audit line that mentions the tag, and a whole-file substring count
cannot tell an audit mention from a duplicate tag. Same family as T-1828 (a gate measuring
a proxy that drifted from the thing it stood for).

**T-2754 — corpus census 28 → 32.** `assert len(targets) == 28`. The test's own docstring
says *"Update deliberately when the store grows or a rule changes."* The store grew to 32
stored versions (draft maps added during arc-014 work). This is a **deliberate pin working
exactly as designed** — and it is the cleanest illustration of §1: the author wrote the
maintenance instruction, and the trigger for reading it never fired, because nothing runs
the test. Same family as the T-2735/T-2737 denominator trio.

---

## 4. Follow-up tasks

| Task | Class | What it fixes | Covers |
|---|---|---|---|
| T-2745 | keystone | Wire pytest `tests/unit/` into `fw test all` / `fw test unit` and CI | §1 — the reason all of the below went unseen |
| T-2746 | genuine-bug | Non-TTY auto-init mutates the filesystem from any command | Cluster A′ |
| T-2747 | stale-test | Orchestrator status fixtures seed only `.context/` | Cluster A (13) |
| T-2748 | env-dependent | Find the cross-test polluter | Cluster B (6) |
| T-2749 | genuine-bug | `fw doctor` stray-root check misses `/.tasks` | Cluster C |
| T-2750 | genuine-bug | Find the test leaking `T-9999-test.md` to `/` | Cluster C |
| T-2751 | stale-test | `is_viewable_path` README assertion (pre-T-2281) | Cluster D |
| T-2752 | stale-test | `render_page_guard` stub set (pre-T-2009) | Cluster D |
| T-2753 | stale-test | arc-tag idempotency proxy vs audit log | Cluster D |
| T-2754 | stale-test | corpus census 28 → 32 | Cluster D |

Every one of the 24 census nodeids maps to exactly one task. No "no action" entries.

**Ordering.** T-2745 is the keystone and should land **first** — until a runner produces
the verdict, every fix below is unverifiable by anything except a hand-run, which is the
condition that created this backlog. But note the ordering trap: landing T-2745 while 24
tests are red makes `fw test all` red, which is its own kind of noise. T-2745's own body
must decide between (a) land the wiring red and fix forward under a short freeze, or
(b) fix the 24 first and land the wiring green. **Recommend (a)** — a red suite that is
*wired* degrades toward green with every fix, while an unwired suite silently re-accumulates,
which is the failure this whole task documents. That decision is T-2745's to record, not
this task's to pre-empt.

---

## 5. A note on the taxonomy

The three buckets in the ACs (`genuine-bug` / `stale-test` / `env-dependent`) did not
cleanly hold two of the cases, and stretching a bucket quietly is how a classification
stops meaning anything:

- **Order-dependence** (Cluster B) is not a property of the host. It is filed under
  `env-dependent` with the sub-class stated, because the test depends on state it did not
  set up — which is what the bucket is *for* — but the sub-class is load-bearing and must
  survive into T-2748.
- **Cluster A** is `stale-test` by the letter (the fixture asserts a superseded contract),
  yet investigating it produced the session's most serious *genuine* defect. Had it been
  filed as `stale-test` and closed there, Cluster A′ would never have been written down.
  A classification is a routing decision, not a verdict on whether something is worth
  looking at.

---

## 6. For the operator

One item needs a decision that is not the agent's to make:

**Remove `/.tasks/` from the filesystem root of this host.** It is a leaked test fixture
(`/.tasks/active/T-9999-test.md`, 2026-06-27, root-owned), it sits outside this repo, and
while present it makes every project-root resolver on this host resolve `/` for any cwd
outside a project. It has been there 37 days.

    sudo rm -rf /.tasks

Not done here: it is a destructive operation at the filesystem root, outside the repo,
and Tier 0 territory. T-2749 adds the doctor check that would have surfaced it; T-2750
hunts the test that created it. Neither removes the existing directory.
