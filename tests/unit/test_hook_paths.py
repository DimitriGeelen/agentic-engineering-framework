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


if __name__ == "__main__":
    unittest.main(verbosity=2)
