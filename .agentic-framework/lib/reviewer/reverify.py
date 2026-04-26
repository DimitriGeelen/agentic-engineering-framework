"""Pass B re-verification (T-1483 v1.5).

Worktree-with-reuse re-execution of `## Verification` blocks. Single
shared worktree per audit run; checkout each task's `date_finished` SHA,
run verification commands inside the worktree subprocess with
`FW_REVIEWER_REVERIFY=1` so framework hooks short-circuit.

Skips network-dependent verifications (per Spike 1 classifier) — they
fail in offline environments without indicating real drift.

Public API:
    WorktreePool (context manager)
    ReverifyReport (dataclass)
    reverify_task(task_path, pool) -> ReverifyReport
"""

from __future__ import annotations

import os
import shutil
import subprocess
import tempfile
from dataclasses import dataclass, field
from pathlib import Path

from .classifier import Category, classify
from .static_scan import extract_section, parse_task_file


@dataclass
class LineResult:
    line: str
    category: str  # Category.value
    status: str  # PASS | FAIL | SKIPPED | ERROR
    exit_code: int | None = None
    stdout_tail: str = ""
    stderr_tail: str = ""

    def to_dict(self) -> dict:
        return {
            "line": self.line,
            "category": self.category,
            "status": self.status,
            "exit_code": self.exit_code,
            "stdout_tail": self.stdout_tail,
            "stderr_tail": self.stderr_tail,
        }


@dataclass
class ReverifyReport:
    task_id: str
    sha: str | None = None
    results: list[LineResult] = field(default_factory=list)
    overall: str = "PASS"  # PASS | FAIL | NO-VERIFICATION
    error: str | None = None  # set if pre-flight failed (no SHA, no worktree, etc.)

    def to_dict(self) -> dict:
        return {
            "task_id": self.task_id,
            "sha": self.sha,
            "overall": self.overall,
            "error": self.error,
            "results": [r.to_dict() for r in self.results],
        }

    def render(self) -> str:
        lines = [f"Reverify report — {self.task_id} (sha {self.sha or 'unknown'})"]
        if self.error:
            lines.append(f"  ERROR: {self.error}")
            return "\n".join(lines)
        n_pass = sum(1 for r in self.results if r.status == "PASS")
        n_fail = sum(1 for r in self.results if r.status == "FAIL")
        n_skip = sum(1 for r in self.results if r.status == "SKIPPED")
        lines.append(f"  Lines: {len(self.results)}  PASS: {n_pass}  FAIL: {n_fail}  SKIPPED: {n_skip}")
        if n_fail > 0:
            lines.append("\n  Failures:")
            for r in self.results:
                if r.status == "FAIL":
                    lines.append(f"    [{r.exit_code}] {r.line[:120]}")
                    if r.stderr_tail:
                        lines.append(f"        {r.stderr_tail[:200]}")
        lines.append(f"\n  Overall: {self.overall}")
        return "\n".join(lines)


class WorktreePool:
    """Single reusable worktree, checkout per task. ~78% faster than create-per-task.

    Usage:
        with WorktreePool(repo_root) as pool:
            for task in tasks:
                pool.checkout(sha)
                # use pool.path
    """

    def __init__(self, repo_root: Path, base_dir: Path | None = None):
        self.repo_root = Path(repo_root)
        self.base_dir = base_dir or Path(tempfile.gettempdir())
        self.path: Path | None = None
        self._current_sha: str | None = None

    def __enter__(self) -> "WorktreePool":
        if not (self.repo_root / ".git").exists():
            raise RuntimeError(f"{self.repo_root} is not a git repo")
        self.path = self.base_dir / f"fw-reviewer-wt-{os.getpid()}"
        if self.path.exists():
            shutil.rmtree(self.path, ignore_errors=True)
        # Use HEAD as initial; tasks will checkout their own SHAs.
        head = subprocess.check_output(
            ["git", "rev-parse", "HEAD"], cwd=self.repo_root, text=True
        ).strip()
        subprocess.run(
            ["git", "worktree", "add", "--detach", "-q", str(self.path), head],
            cwd=self.repo_root,
            check=True,
            capture_output=True,
        )
        self._current_sha = head
        return self

    def __exit__(self, *exc) -> None:
        if self.path and self.path.exists():
            subprocess.run(
                ["git", "worktree", "remove", "-f", str(self.path)],
                cwd=self.repo_root,
                capture_output=True,
            )
            # Defensive: if worktree remove failed, force-clean
            if self.path.exists():
                shutil.rmtree(self.path, ignore_errors=True)
            subprocess.run(
                ["git", "worktree", "prune"],
                cwd=self.repo_root,
                capture_output=True,
            )
        self.path = None

    def checkout(self, sha: str) -> bool:
        """Checkout the given SHA inside the pool worktree. No-op if already on it."""
        if self.path is None:
            raise RuntimeError("WorktreePool not entered (use with-statement)")
        if self._current_sha == sha:
            return True
        result = subprocess.run(
            ["git", "checkout", "-q", "--detach", sha],
            cwd=self.path,
            capture_output=True,
            text=True,
        )
        if result.returncode != 0:
            return False
        self._current_sha = sha
        return True


def _find_task_completion_sha(task_id: str, repo_root: Path) -> str | None:
    """Find the SHA of the commit that closed the task (last commit referencing T-XXX)."""
    result = subprocess.run(
        ["git", "log", "--all", "--format=%H", "--grep", f"^{task_id}:"],
        cwd=repo_root,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        return None
    shas = [s for s in result.stdout.splitlines() if s.strip()]
    return shas[0] if shas else None  # Most recent (git log default order)


def reverify_task(
    task_path: Path,
    pool: WorktreePool,
    timeout_per_line: int = 30,
    skip_categories: tuple[Category, ...] = (Category.NETWORK_DEPENDENT,),
) -> ReverifyReport:
    """Re-execute a task's verification block in the worktree pool."""
    fm, body = parse_task_file(task_path)
    task_id = fm.get("id", task_path.stem.split("-")[0])
    rep = ReverifyReport(task_id=task_id)

    verification = extract_section(body, "Verification") or ""
    lines = [
        ln for ln in verification.splitlines()
        if ln.strip() and not ln.strip().startswith("#")
    ]
    if not lines:
        rep.overall = "NO-VERIFICATION"
        return rep

    sha = _find_task_completion_sha(task_id, pool.repo_root)
    if not sha:
        rep.error = f"could not locate completion commit for {task_id}"
        rep.overall = "FAIL"
        return rep
    rep.sha = sha

    if not pool.checkout(sha):
        rep.error = f"git checkout failed for {sha}"
        rep.overall = "FAIL"
        return rep

    env = {**os.environ, "FW_REVIEWER_REVERIFY": "1"}
    any_failed = False
    for raw in lines:
        cat = classify(raw)
        if cat in skip_categories:
            rep.results.append(
                LineResult(line=raw.strip(), category=cat.value, status="SKIPPED")
            )
            continue
        try:
            proc = subprocess.run(
                raw,
                shell=True,
                cwd=pool.path,
                env=env,
                capture_output=True,
                text=True,
                timeout=timeout_per_line,
            )
            status = "PASS" if proc.returncode == 0 else "FAIL"
            if proc.returncode != 0:
                any_failed = True
            rep.results.append(
                LineResult(
                    line=raw.strip(),
                    category=cat.value,
                    status=status,
                    exit_code=proc.returncode,
                    stdout_tail=proc.stdout[-200:],
                    stderr_tail=proc.stderr[-200:],
                )
            )
        except subprocess.TimeoutExpired:
            any_failed = True
            rep.results.append(
                LineResult(
                    line=raw.strip(),
                    category=cat.value,
                    status="ERROR",
                    exit_code=None,
                    stderr_tail=f"timeout after {timeout_per_line}s",
                )
            )
        except Exception as e:
            any_failed = True
            rep.results.append(
                LineResult(
                    line=raw.strip(),
                    category=cat.value,
                    status="ERROR",
                    stderr_tail=str(e)[:200],
                )
            )

    rep.overall = "FAIL" if any_failed else "PASS"
    return rep
