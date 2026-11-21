"""T-5336 (1023 field report): stored Verification lines that change the repo are refused
when re-run unattended; read-only git and lines that merely mention a git verb still run."""
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "lib"))
from unattended_verification import unattended_refusal  # noqa: E402


@pytest.mark.parametrize("line", [
    "git add -A .context",                                  # 1023's exact line
    "git commit -m x",
    "cd /tmp/x && git add . && git commit -qm y",
    "git -C /tmp/repo commit -qm y",                        # a write, even in a temp repo
    "git -c user.name=a commit -qm y",
    "git --git-dir=/tmp/r/.git checkout main",
    "git stash",
    "git clean -fdx",
    "git checkout -- file.txt",
    "git switch other",
    "git restore file.txt",
    "git rm file.txt",
    "git mv a b",
    "git reset HEAD~1",
    "git tag v1",
    "git branch -D old",
    "git branch --delete old",
    "out=$(git add x)",
    "sudo git commit -m x",
    "echo x >> .tasks/active/T-1.md",
    "echo x > .context/project/concerns.yaml",
    "echo x > ./.context/foo",
    'echo x > "$PROJECT_ROOT/.context/foo"',
])
def test_repo_mutating_lines_are_refused(line):
    assert unattended_refusal(line) is not None, line


@pytest.mark.parametrize("line", [
    "git log --oneline -5",
    "git status --short",
    "git diff --stat HEAD~1",
    "git show HEAD:lib/x.py | grep -q foo",
    "git rev-parse HEAD",
    "git -C /tmp/repo log -1",
    "git ls-files -ci --exclude-standard",
    "git branch --show-current",
    "git merge-base --is-ancestor abc123 origin/master",   # read-only despite 'merge'
    "git tag --contains 27368fc3d | grep -q v1",           # tag listing is a read
    "test -z \"$(git tag -l '*-be.*')\"",
    "git tag --list",
    'git stash list | grep -q "stash@{0}"',                # stash list/show are reads
    "git stash show abc --name-only | wc -l",
    "bats x.bats > .context/scratch/t1.out 2>&1",          # gitignored scratch
    "bats tests/unit/x.bats > .context/working/.x.out 2>&1 && ! grep -q '^not ok' .context/working/.x.out",
    'grep -q "git add" docs/guide.md',
    "grep -c 'git commit' CHANGELOG.md",
    "python3 lib/x.py > /tmp/.out 2>&1 && grep -q ok /tmp/.out",
    "test -f .context/working/foo.yaml",
    "cat .tasks/active/T-1.md | grep -q x",
])
def test_read_only_lines_still_run(line):
    assert unattended_refusal(line) is None, (line, unattended_refusal(line))


@pytest.mark.parametrize("line", ["git tag v1", "git tag -d old", "git tag -a v1 -m x",
                                  "git tag --delete old", "git tag -f v1"])
def test_git_tag_writes_are_refused(line):
    assert unattended_refusal(line) == "repo-mutating git command", line
