"""T-3551: the cost sweep must see partial-complete tasks.

`components:` is resolved at the `work-completed` transition. `cmd_cost_sweep`'s
status scope was `["started-work", "captured"]`. So the input `blast_radius` is
derived from arrived at exactly the moment the sweep stopped asking for it — two
mechanisms each correct alone, with an unmeasured seam between them.

Measured before the fix: 50 active tasks carried `components:` AND a proposal whose
`blast_radius` was null, and **all 50 were `work-completed`**. The sweep had been
running every 15 minutes throughout. It was never idle; it was looking at a
population that excluded the data.

THE CONTROL IS LOAD-BEARING. `test_archived_completed_task_is_still_skipped` is what
separates this fix from "sweep everything": the boundary is partial-complete
(`work-completed` in `active/`), not `work-completed` generally. Without it, a build
that swept all 3,040 archived tasks every 15 minutes would satisfy every other
assertion here.
"""

import importlib.util
import sys

from pathlib import Path

FW_ROOT = Path(__file__).resolve().parents[2]
_EST = FW_ROOT / "agents" / "termlink" / "bvp-estimator" / "estimator.py"

_spec = importlib.util.spec_from_file_location("_bvp_estimator_t3551", _EST)
est = importlib.util.module_from_spec(_spec)
sys.modules["_bvp_estimator_t3551"] = est
_spec.loader.exec_module(est)

DEFAULT_STATUSES = ["started-work", "captured"]


def _scope(status, subdir, statuses=None):
    """Run the scope predicate against a synthetic (status, directory) pair."""
    p = Path("/tmp/.tasks") / subdir / "T-0001-x.md"
    return est._cost_sweep_in_scope({"status": status}, p,
                                    statuses if statuses is not None else DEFAULT_STATUSES)


# ───────────────────────────── the scope predicate ──────────────────────────────


def test_partial_complete_is_in_scope():
    """work-completed + still in active/ = open work the sweep must score."""
    assert _scope("work-completed", "active") is True


def test_archived_completed_task_is_still_skipped():
    """CONTROL. The boundary IS the fix.

    Without this, 'sweep everything' passes every other test in this file while
    re-scoring 3,040 archived tasks every 15 minutes — churn for a decision nobody
    is making. The directory is what distinguishes finished work from work awaiting
    a human.
    """
    assert _scope("work-completed", "completed") is False


def test_original_statuses_unchanged():
    assert _scope("captured", "active") is True
    assert _scope("started-work", "active") is True


def test_an_unrelated_status_is_still_out():
    assert _scope("issues", "active") is False


def test_explicit_status_list_still_honoured():
    """A caller passing --statuses keeps control of leg (1)..."""
    assert _scope("issues", "active", statuses=["issues"]) is True
    assert _scope("captured", "active", statuses=["issues"]) is False


def test_partial_complete_leg_is_not_defeated_by_a_narrow_status_list():
    """...but leg (2) is about WHERE the file is, so a status list cannot hide it.

    Pinned deliberately: the partial-complete population is the whole point of the
    task, and making it silently suppressible by an unrelated flag would reintroduce
    the defect through a side door.
    """
    assert _scope("work-completed", "active", statuses=["captured"]) is True


# ──────────────────────── end-to-end over a real tree ───────────────────────────


def _task(path: Path, tid: str, status: str, components: list[str] | None = None,
          confirmed: dict | None = None):
    # Built by concatenation, NOT textwrap.dedent: the injected blocks below start
    # at column 0, which makes dedent's common prefix empty so the surrounding
    # template keeps its source indentation and the frontmatter stops being YAML.
    # (Cost me one red run — left as a note rather than a silent fix.)
    if components is not None:
        comp = "components:\n" + "".join(f"  - {c}\n" for c in components)
    else:
        comp = "components: []\n"
    conf = ""
    if confirmed:
        conf = ("cost_estimate:\n" +
                "".join(f"  {k}: {v}\n" for k, v in confirmed.items()))
    path.write_text(
        "---\n"
        f"id: {tid}\n"
        f'name: "fixture {tid}"\n'
        f"status: {status}\n"
        "workflow_type: build\n"
        "owner: agent\n"
        "horizon: now\n"
        "created: 2026-01-01T00:00:00Z\n"
        "last_update: 2026-01-01T00:00:00Z\n"
        f"{comp}{conf}"
        "---\n"
        "\n"
        f"# {tid}\n"
        "\n"
        "## Acceptance Criteria\n"
        "\n"
        "### Agent\n"
        "- [x] done\n"
    )


def _tree(tmp_path, monkeypatch):
    (tmp_path / ".tasks" / "active").mkdir(parents=True)
    (tmp_path / ".tasks" / "completed").mkdir(parents=True)
    monkeypatch.setattr(est, "PROJECT_ROOT", tmp_path)
    return tmp_path


def _proposed_br(path: Path):
    import yaml
    text = path.read_text()
    fm = yaml.safe_load(text.split("---")[1])
    prop = fm.get("cost_estimate_proposed") or []
    if not prop:
        return "NO-PROPOSAL"
    return (prop[-1].get("cost_estimate") or {}).get("blast_radius")


def test_partial_complete_task_gains_a_real_blast_radius(tmp_path, monkeypatch):
    """The originating symptom, end to end."""
    root = _tree(tmp_path, monkeypatch)
    t = root / ".tasks" / "active" / "T-9001-partial.md"
    _task(t, "T-9001", "work-completed",
          components=["lib/a.sh", "lib/b.sh", "web/c.py"])

    est.cmd_cost_sweep(stale_hours=0)

    br = _proposed_br(t)
    assert br not in (None, "NO-PROPOSAL"), f"expected a real blast_radius, got {br!r}"
    assert isinstance(br, int) and br > 0


def test_archived_task_is_not_written_at_all(tmp_path, monkeypatch):
    """CONTROL, end to end: the archived file must come back untouched."""
    root = _tree(tmp_path, monkeypatch)
    t = root / ".tasks" / "completed" / "T-9002-archived.md"
    _task(t, "T-9002", "work-completed", components=["lib/a.sh", "lib/b.sh"])
    before = t.read_text()

    est.cmd_cost_sweep(stale_hours=0)

    assert t.read_text() == before, "archived task was rewritten"
    assert _proposed_br(t) == "NO-PROPOSAL"


def test_confirmed_cost_is_never_overwritten(tmp_path, monkeypatch):
    """Sovereignty. A confirmed cost_estimate: is the operator's, not the sweep's."""
    root = _tree(tmp_path, monkeypatch)
    t = root / ".tasks" / "active" / "T-9003-confirmed.md"
    _task(t, "T-9003", "work-completed", components=["lib/a.sh"],
          confirmed={"blast_radius": 1, "tier": 2, "effort": 3})
    before = t.read_text()

    est.cmd_cost_sweep(stale_hours=0)

    assert t.read_text() == before, "confirmed cost_estimate was touched"


def test_a_second_sweep_writes_nothing(tmp_path, monkeypatch):
    """No unbounded proposal growth over the 290-task population.

    `write_proposed_cost` returns `no-change-since-last` when the computed estimate
    equals the stored one. Widening the scope multiplies how often that guard is
    exercised, so it is pinned here rather than assumed.
    """
    root = _tree(tmp_path, monkeypatch)
    t = root / ".tasks" / "active" / "T-9004-stable.md"
    _task(t, "T-9004", "work-completed", components=["lib/a.sh", "lib/b.sh"])

    est.cmd_cost_sweep(stale_hours=0)
    after_first = t.read_text()
    est.cmd_cost_sweep(stale_hours=0)

    assert t.read_text() == after_first, "a second sweep rewrote an unchanged task"
