#!/usr/bin/env python3
"""T-2468 — unit tests for lib/hook_paths.py:reanchor_project_root.

Python-side parity with tests/unit/t2465_reanchor_from_cwd.bats (the bash resolver).
Run directly: python3 tests/unit/test_hook_paths.py
"""
import os
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent))
from lib.hook_paths import reanchor_project_root  # noqa: E402


class ReanchorProjectRoot(unittest.TestCase):
    def setUp(self):
        self.main = tempfile.mkdtemp()           # the env-resolved (wrong) fallback
        self.wt = tempfile.mkdtemp()             # the worktree the tool ran in
        os.makedirs(os.path.join(self.wt, ".tasks"))
        Path(self.wt, ".framework.yaml").write_text("version: test\n")
        self.outside = tempfile.mkdtemp()        # no project markers above it

    def _real(self, p):
        return str(Path(p).resolve())

    def test_reanchors_to_cwd_project_root(self):
        got = reanchor_project_root({"cwd": self.wt}, self.main)
        self.assertEqual(str(got), self._real(self.wt))

    def test_walks_up_from_subdir(self):
        sub = os.path.join(self.wt, "lib", "sub")
        os.makedirs(sub)
        got = reanchor_project_root({"cwd": sub}, self.main)
        self.assertEqual(str(got), self._real(self.wt))

    def test_resolves_via_tasks_dir_when_no_framework_yaml(self):
        only_tasks = tempfile.mkdtemp()
        os.makedirs(os.path.join(only_tasks, ".tasks"))
        got = reanchor_project_root({"cwd": only_tasks}, self.main)
        self.assertEqual(str(got), self._real(only_tasks))

    def test_noop_when_no_cwd_key(self):
        self.assertEqual(str(reanchor_project_root({"tool_name": "Write"}, self.main)), self.main)

    def test_noop_when_payload_none(self):
        self.assertEqual(str(reanchor_project_root(None, self.main)), self.main)

    def test_noop_when_cwd_not_a_dir(self):
        self.assertEqual(str(reanchor_project_root({"cwd": self.wt + "/nope"}, self.main)), self.main)

    def test_noop_when_cwd_outside_any_project(self):
        self.assertEqual(str(reanchor_project_root({"cwd": self.outside}, self.main)), self.main)

    def test_noop_when_cwd_empty_string(self):
        self.assertEqual(str(reanchor_project_root({"cwd": ""}, self.main)), self.main)


class WalkUpFloor(unittest.TestCase):
    """T-2793 — the walk-up must stop BEFORE the filesystem root.

    The shell twin has always had this floor (`while … [ "$d" != "/" ]`, never
    testing "/" itself); the python side walked `d.parents` all the way up and
    tested "/" like any other directory. On a host carrying a stray `/.tasks`
    (real — T-2787), "/" satisfied the marker check and every python hook
    re-anchored PROJECT_ROOT to the entire filesystem.

    Vacuity note, stated rather than hidden: `test_root_cwd_*` below only
    *catches* a regression while a marker exists at "/". Once T-2787 clears the
    pollution it asserts a contract that cannot currently fail. The parity test
    is the one that stays sharp — it compares the two implementations against
    each other, so it fails whenever they disagree, marker or no marker.
    """

    def setUp(self):
        self.fb = tempfile.mkdtemp()

    def test_root_cwd_returns_fallback(self):
        self.assertEqual(str(reanchor_project_root({"cwd": "/"}, self.fb)), self.fb)

    def test_never_returns_a_filesystem_root(self):
        for cwd in ("/", "/tmp", tempfile.mkdtemp()):
            got = Path(reanchor_project_root({"cwd": cwd}, self.fb))
            self.assertNotEqual(got.parent, got, f"walk-up reached a filesystem root from {cwd}")

    def test_shell_and_python_twins_agree(self):
        """Both resolvers, same inputs, same answers — including the "/" case.

        This is the assertion the two implementations lacked: each was tested
        alone, so a disagreement on their single most consequential input was
        invisible to both suites.
        """
        import subprocess

        marked = tempfile.mkdtemp()
        os.makedirs(os.path.join(marked, ".tasks"))
        nested = os.path.join(marked, "a", "b")
        os.makedirs(nested)
        repo = Path(__file__).resolve().parent.parent.parent

        for cwd in ("/", "/tmp", marked, nested, tempfile.mkdtemp()):
            py = str(reanchor_project_root({"cwd": cwd}, self.fb))
            sh = subprocess.run(
                ["bash", "-c",
                 f'PROJECT_ROOT={self.fb!r}; source {str(repo / "lib" / "paths.sh")!r} >/dev/null 2>&1; '
                 f'fw_reanchor_from_cwd {cwd!r} >/dev/null 2>&1; printf %s "$PROJECT_ROOT"'],
                capture_output=True, text=True, timeout=30,
            ).stdout.strip()
            self.assertEqual(py, sh, f"twins disagree for cwd={cwd}: python={py} shell={sh}")


if __name__ == "__main__":
    unittest.main(verbosity=2)
