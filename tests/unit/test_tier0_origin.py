"""T-3078 — the pure provenance logic behind Tier 0 approval cards.

Companion to ``tests/unit/tier0_card_provenance.bats``. The split is not
stylistic: every hook run from a bats body classifies as ``test``, so the
``agent`` and ``human`` branches are unreachable from there. A harness that
biases its own result cannot test the branches it biases away.

That is not a hypothetical cost. While this logic lived in a shell heredoc, the
``bats`` marker was matched against ``ps -o comm=`` — which reports ``bash`` for
every hop of a bats run — so it had never once fired. ``kind=test`` was being
carried entirely by the sandbox check, and nothing was red. Extracting the
function is what made the miss visible; these tests are what keep it visible.
"""

import os
import sys

import pytest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "..", "lib"))

import tier0_origin  # noqa: E402


# ── classify: the three arms, each reachable and each distinct ──────────────

def test_test_harness_in_the_chain_classifies_as_test():
    signals = ["bash /usr/local/libexec/bats-core/bats-exec-file --dummy-flag 1 x.bats"]
    assert tier0_origin.classify(signals, sandbox=False, env={}) == "test"


def test_pytest_in_the_chain_classifies_as_test():
    assert tier0_origin.classify(
        ["python3 -m pytest tests/unit"], sandbox=False, env={}
    ) == "test"


def test_agent_env_classifies_as_agent():
    assert tier0_origin.classify(
        ["bash", "fw"], sandbox=False, env={"CLAUDECODE": "1"}
    ) == "agent"


def test_agent_in_the_chain_classifies_as_agent_without_the_env():
    assert tier0_origin.classify(["claude -c"], sandbox=False, env={}) == "agent"


def test_plain_shell_classifies_as_human():
    assert tier0_origin.classify(["bash", "sshd"], sandbox=False, env={}) == "human"


def test_the_three_arms_are_actually_distinct():
    """L-616 guard: a classify() that returned a constant would satisfy each of
    the assertions above only if they were read in isolation. Assert the set."""
    got = {
        tier0_origin.classify(["bats x"], False, {}),
        tier0_origin.classify(["claude"], False, {}),
        tier0_origin.classify(["bash"], False, {}),
    }
    assert got == {"test", "agent", "human"}


# ── precedence: a test run by an agent is still a test run ─────────────────

def test_sandbox_outranks_the_agent_signal():
    """This exact combination is T-3077: a real agent session ran a suite, and
    the suite filed real cards on the operator's live queue. Those cards are
    test artefacts, not agent requests, and must not be labelled as requests."""
    assert tier0_origin.classify(
        ["claude -c"], sandbox=True, env={"CLAUDECODE": "1"}
    ) == "test"


def test_harness_marker_outranks_the_agent_signal():
    assert tier0_origin.classify(
        ["bash /usr/local/libexec/bats-core/bats x", "claude -c"],
        sandbox=False, env={"CLAUDECODE": "1"},
    ) == "test"


# ── the comm-vs-args trap, pinned so it cannot silently return ─────────────

def test_comm_names_alone_do_not_reveal_a_bats_run():
    """The original bug, as a characterization test.

    These are the real ``ps -o comm=`` values from a bats run of this very
    suite's sibling. Matching markers against them yields ``human`` — which is
    why :func:`classify` documents that callers must pass full command lines.
    If someone "simplifies" process_ancestry() back to comm-only, this stays
    green while the real detector dies, so the next test is the one that bites.
    """
    comms = ["bash", "bash", "bash", "bash", "claude", "claude-fw"]
    assert not any(m in " ".join(comms).lower() for m in tier0_origin.TEST_MARKERS)


def test_derive_classifies_this_very_pytest_run_as_test():
    """End-to-end on the live process tree, with the sandbox signal DISABLED.

    The project_root is the real framework checkout — it has a `.git` and is not
    under a temp dir, so `is_sandbox()` is False and the ancestry is the only
    thing left that can produce `test`. That is the whole point: an earlier
    version of this test passed `/nonexistent`, which made `sandbox` True and
    masked the ancestry entirely. It stayed green under a mutation that reverted
    matching to comm-only — i.e. it asserted nothing about the thing it named.

    If `process_ancestry()` ever stops collecting full command lines, this goes
    red and nothing else will.

    The walk is pointed at *this* process rather than its parent. `derive()`
    defaults to `os.getppid()`, which is right for the hook — there the harness
    really is an ancestor — but wrong here: under pytest the harness is the
    process running this function, so the default walk sees only the shell and
    agent above it and correctly answers `agent`.
    """
    root = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
    assert tier0_origin.is_sandbox(root, env={}) is False, "fixture precondition"
    origin = tier0_origin.derive(project_root=root, env={}, pid=os.getpid())
    assert origin["kind"] == "test"


# ── is_sandbox: both clauses, and why neither is redundant ─────────────────

def test_missing_git_dir_is_a_sandbox(tmp_path):
    assert tier0_origin.is_sandbox(str(tmp_path), env={}) is True


def test_git_dir_under_a_temp_path_is_still_a_sandbox(tmp_path):
    """The second clause. A fixture that runs `git init` on its scratch tree
    would otherwise read as a genuine project."""
    (tmp_path / ".git").mkdir()
    assert tier0_origin.is_sandbox(str(tmp_path), env={}) is True


def test_a_real_project_is_not_a_sandbox():
    """Positive control (L-616). Without it, an is_sandbox() hardwired to True
    would pass both assertions above and label every card a test artefact —
    the precise failure that would hide a genuine agent request."""
    root = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
    assert os.path.isdir(os.path.join(root, ".git")), "fixture assumes a git checkout"
    assert tier0_origin.is_sandbox(root, env={}) is False


def test_empty_project_root_is_not_a_sandbox():
    assert tier0_origin.is_sandbox("", env={}) is False


# ── derive never raises; the card must be written even if origin fails ─────

@pytest.mark.parametrize("root", ["", "/nonexistent/path/xyz", "/"])
def test_derive_never_raises(root):
    """Provenance explains the block; the card IS the block. A failure to
    explain must never prevent the destructive command from being recorded."""
    origin = tier0_origin.derive(project_root=root, env={})
    assert origin["kind"] in {"test", "agent", "human", "unknown"}


def test_derive_survives_a_broken_ancestry_walk(monkeypatch):
    monkeypatch.setattr(
        tier0_origin, "process_ancestry",
        lambda *a, **k: (_ for _ in ()).throw(RuntimeError("boom")),
    )
    assert tier0_origin.derive(project_root="/tmp", env={})["kind"] == "unknown"


def test_ancestry_walk_is_bounded(monkeypatch):
    """A cycle must not hang the hook that is holding a destructive command."""
    calls = {"n": 0}

    class _R:
        stdout = "999 bash bash -c loop"

    def _fake_run(*a, **k):
        calls["n"] += 1
        return _R()

    monkeypatch.setattr(tier0_origin.subprocess, "run", _fake_run)
    tier0_origin.process_ancestry(pid=999)
    # pid repeats immediately, so the `seen` guard stops it on the first hop;
    # the depth cap is the backstop if that guard is ever removed.
    assert calls["n"] <= tier0_origin.MAX_ANCESTRY_DEPTH


# ── what the card stores vs what it matches on ────────────────────────────

def test_derive_stores_comm_names_not_full_command_lines():
    """Command lines can carry tokens, paths and secrets, and a card is a
    surface an operator reads. Matching uses argv; storage must not."""
    origin = tier0_origin.derive(project_root="/tmp", env={})
    for entry in origin.get("ancestry", []):
        assert " " not in entry, f"stored a full command line on the card: {entry!r}"
