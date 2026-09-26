"""T-3499 — the usage axis (slice 6 of T-3484).

Two properties carry this suite, and both exist because something was measured
wrong first:

1. **The three classes must stay distinguishable.** `used`,
   `discoverable-but-unused` and `undiscoverable-and-unused` demand opposite
   responses — leave alone, document, consider retiring. A classifier that
   collapsed the last two would recommend deleting features nobody had ever been
   told about. `test_a_discoverable_but_unused_verb_is_NOT_retirable` is the
   control leg that gives the rest meaning.

2. **An absent counter is not a corpus of zeros.** Same rule S1 applies to cost
   and S4 to quality: a source that cannot be read must not read as a clean
   record.

Plus a regression test for a bug this task shipped and then caught in the live
counter — see `test_a_key_with_a_shell_metacharacter_is_rejected`.

No live corpus counts are pinned (T-3326): every counter and every bin/fw here is
a fixture.
"""

import subprocess
import sys
from pathlib import Path

import pytest

FRAMEWORK_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(FRAMEWORK_ROOT))
from lib import bvp_usage as U  # noqa: E402


FAKE_FW = """#!/usr/bin/env bash
# --- Main Command Routing ---
case "$cmd" in
    alpha)
        :
        ;;
    beta|bee)
        :
        ;;
    gamma)
        :
        ;;
    hook)
        :
        ;;
esac
"""


@pytest.fixture()
def repo(tmp_path):
    (tmp_path / ".context" / "working").mkdir(parents=True)
    (tmp_path / "bin").mkdir()
    (tmp_path / "bin" / "fw").write_text(FAKE_FW, encoding="utf-8")
    # alpha and beta are advertised; gamma deliberately is not.
    (tmp_path / "CLAUDE.md").write_text(
        "Run `fw alpha` to do the thing. See also fw beta.\n", encoding="utf-8")
    return tmp_path


def counter(repo, text):
    (repo / ".context" / "working" / ".verb-counter").write_text(text, encoding="utf-8")


# ── unmeasured is not zero ──────────────────────────────────────────────────

def test_an_absent_counter_is_unavailable_not_a_corpus_of_zeros(repo):
    report = U.classify(root=repo)
    assert report["available"] is False
    assert report["verbs"] == {}
    assert "reason" in report


def test_an_absent_counter_recommends_retiring_nothing(repo):
    """The dangerous shape: no data read as 'nothing is used, delete it all'."""
    assert U.retirable(root=repo) == []


def test_a_present_counter_with_no_rows_is_a_REAL_zero(repo):
    """Control leg for the above — available:True must stay distinguishable."""
    counter(repo, "")
    report = U.classify(root=repo)
    assert report["available"] is True
    assert report["observed_invocations"] == 0
    assert report["verbs"]["alpha"]["count"] == 0


# ── the three classes ───────────────────────────────────────────────────────

def test_an_invoked_verb_is_used(repo):
    counter(repo, "alpha=7\n")
    report = U.classify(root=repo)
    assert report["verbs"]["alpha"]["class"] == U.USED
    assert report["verbs"]["alpha"]["count"] == 7


def test_a_discoverable_but_unused_verb_is_NOT_retirable(repo):
    """THE CONTROL LEG.

    `beta` is advertised in CLAUDE.md and has never been called. That is a
    documentation/adoption finding, not a dead feature. Folding it in with
    never-advertised verbs would recommend deleting things nobody was told about
    — the arc-020 failure inverted.
    """
    counter(repo, "alpha=3\n")
    report = U.classify(root=repo)
    assert report["verbs"]["beta"]["class"] == U.DISCOVERABLE_UNUSED
    assert report["verbs"]["beta"]["discoverable"] is True
    assert "beta" not in U.retirable(root=repo)


def test_an_undiscoverable_unused_verb_IS_retirable(repo):
    """`gamma` exists in the dispatcher and is advertised nowhere.

    Asserted by membership, not by an exact list: the fixture's `beta|bee` branch
    means `bee` is ALSO undiscoverable-and-unused, because CLAUDE.md advertises
    `fw beta` and never `fw bee`. The first version of this test asserted
    `== ["gamma"]` and failed — correctly. An alias that is dispatched but never
    documented is a real instance of this class, not fixture noise.
    """
    counter(repo, "alpha=3\n")
    report = U.classify(root=repo)
    assert report["verbs"]["gamma"]["class"] == U.UNDISCOVERABLE_UNUSED
    assert report["verbs"]["gamma"]["discoverable"] is False
    assert "gamma" in U.retirable(root=repo)
    assert "beta" not in U.retirable(root=repo)


def test_the_two_unused_classes_are_not_collapsed(repo):
    """Stated as its own assertion because collapsing them is the whole risk."""
    counter(repo, "alpha=1\n")
    report = U.classify(root=repo)
    assert report["verbs"]["beta"]["class"] != report["verbs"]["gamma"]["class"]
    assert report["totals"][U.DISCOVERABLE_UNUSED] >= 1
    assert report["totals"][U.UNDISCOVERABLE_UNUSED] >= 1


def test_hook_is_reported_as_not_instrumented_not_as_unused(repo):
    """`hook` is excluded at the writer, so a zero here means 'not measured
    here', not 'never called'. Reporting it as unused would be a false finding
    about the single hottest path in the system."""
    counter(repo, "alpha=1\n")
    report = U.classify(root=repo)
    assert report["verbs"]["hook"]["class"] == U.NOT_INSTRUMENTED_CLASS
    assert "hook" not in U.retirable(root=repo)


# ── the verb universe ───────────────────────────────────────────────────────

def test_the_universe_is_parsed_from_the_dispatcher_including_alternatives(repo):
    verbs = U.known_verbs(root=repo)
    assert {"alpha", "beta", "bee", "gamma", "hook"} <= verbs


def test_a_counted_verb_absent_from_the_dispatcher_still_appears(repo):
    """A verb removed from bin/fw but still in the counter is real history and
    must not silently vanish from the report."""
    counter(repo, "retired-verb=12\n")
    report = U.classify(root=repo)
    assert report["verbs"]["retired-verb"]["count"] == 12


def test_a_corrupt_count_is_skipped_not_read_as_zero(repo):
    counter(repo, "alpha=notanumber\nbeta=4\n")
    counts = U.read_counter(root=repo)
    assert "alpha" not in counts
    assert counts["beta"] == 4


# ── the writer, end to end against the REAL bin/fw ──────────────────────────

def _run_fw(args, env_extra=None, cwd=None):
    """Invoke the SHIPPED bin/fw against an isolated PROJECT_ROOT.

    `CLAUDE_PROJECT_DIR` must be stripped, and cwd must be the throwaway root.
    The first version of this helper kept both and the increments landed in the
    LIVE `.context/working/.verb-counter` instead of the fixture's — bin/fw
    prefers an inherited `CLAUDE_PROJECT_DIR` over an explicit `PROJECT_ROOT`
    (the T-2390 hook/$HOME-poison branch), and a cwd inside the real repo lets
    `find_project_root` re-anchor. Measured: it pushed the live `decisions` count
    from 2 to 14 before this was fixed. Same family as T-3250, whose close-gate
    harness wrote 34 junk tasks into the live repo.
    """
    import os
    env = dict(os.environ)
    for leaky in ("FW_VERB_TELEMETRY", "CLAUDE_PROJECT_DIR",
                  "TASKS_DIR", "CONTEXT_DIR", "_FW_PATHS_DERIVED_BY"):
        env.pop(leaky, None)
    if env_extra:
        env.update(env_extra)
    return subprocess.run([str(FRAMEWORK_ROOT / "bin" / "fw")] + args,
                          capture_output=True, text=True, env=env,
                          cwd=str(cwd or FRAMEWORK_ROOT), timeout=120)


def test_a_key_with_a_shell_metacharacter_is_rejected(repo):
    """Regression for a bug this task shipped and the live counter caught.

    The first guard was `[a-z][a-z0-9-]*`, which looks like a regex and is not:
    in a shell `case` glob, `*` matches ANY characters rather than repeating the
    preceding bracket class. So `evil=injected` matched, the `*` absorbed
    `=injected`, and a corrupt line went into the real `.verb-counter` — the flat
    `key=count` format means an unguarded key rewrites the file's grammar.

    Asserted on the shipped bin/fw source, because the defect was in the pattern,
    not in any Python.
    """
    src = (FRAMEWORK_ROOT / "bin" / "fw").read_text(encoding="utf-8")
    assert "*[!a-z0-9-]*" in src, "the negated-class guard is gone"
    assert "[a-z][a-z0-9-]*)" not in src, (
        "the glob-as-regex guard is back; it matches keys containing '='")


def test_the_real_dispatcher_counts_a_verb_and_honours_the_opt_out(tmp_path):
    """End-to-end through the shipped bin/fw, in a throwaway PROJECT_ROOT so the
    live counter is never touched by the suite."""
    (tmp_path / ".context" / "working").mkdir(parents=True)
    target = tmp_path / ".context" / "working" / ".verb-counter"

    _run_fw(["decisions"], {"PROJECT_ROOT": str(tmp_path)}, cwd=tmp_path)
    assert target.is_file(), "the dispatcher did not create a counter"
    assert "decisions=" in target.read_text(encoding="utf-8")

    before = target.read_text(encoding="utf-8")
    _run_fw(["decisions"], {"PROJECT_ROOT": str(tmp_path), "FW_VERB_TELEMETRY": "0"}, cwd=tmp_path)
    assert target.read_text(encoding="utf-8") == before, (
        "FW_VERB_TELEMETRY=0 did not disable the increment")


def test_instrumentation_is_fail_open_when_the_counter_cannot_be_written(tmp_path):
    """Telemetry must never change fw's exit code. A read-only working dir is the
    cheapest way to break the write without breaking anything else."""
    import os
    working = tmp_path / ".context" / "working"
    working.mkdir(parents=True)
    os.chmod(working, 0o500)
    try:
        ok = _run_fw(["decisions"], {"PROJECT_ROOT": str(tmp_path)}, cwd=tmp_path)
        blocked = _run_fw(["decisions"], {"PROJECT_ROOT": str(tmp_path),
                                          "FW_VERB_TELEMETRY": "0"}, cwd=tmp_path)
        assert ok.returncode == blocked.returncode, (
            f"telemetry changed the exit code: {ok.returncode} vs {blocked.returncode}")
        assert "verb-counter" not in ok.stderr, "telemetry leaked an error to stderr"
    finally:
        os.chmod(working, 0o700)
