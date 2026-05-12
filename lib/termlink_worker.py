#!/usr/bin/env python3
"""
TermLinkWorker — subprocess wrapper for `fw termlink dispatch`.

Mirrors :class:`lib.ollama_loop.OllamaLoopWorker` so :mod:`lib.spawn` can route
``worker_kind=TermLink`` end-to-end. T-1776 surfaced the fallback-workflow
contract gap (default.yaml declares ``worker_kind: TermLink`` but the spawn
driver had no handler); the human picked Option A — build a Python primitive
that wraps the existing TermLink dispatch shell command.

Why a wrapper (and not direct `claude -p` like ollama-loop):

  `OllamaLoopWorker` spawns claude in-process and streams stdout directly.
  `TermLinkWorker` invokes ``fw termlink dispatch`` which spawns claude inside
  a separate TermLink/PTY session (independent OS process, observable from
  outside, survives parent context compaction). That isolation is the whole
  point of the TermLink dispatch surface; the trade-off is post-hoc event
  replay instead of live stream — TermLink writes the full event trail to
  ``/tmp/tl-dispatch/<name>/result.jsonl`` and we read it after ``fw termlink
  wait`` confirms the worker has exited.

Protocol contract (claude -p --output-format stream-json --verbose, written
to ``result.jsonl`` by TermLink's run.sh):

  Each line is a JSON event:
    {"type": "system", ...}     boot
    {"type": "assistant", ...}  text + tool_use blocks
    {"type": "user", ...}       tool_result blocks
    {"type": "result", ...}     terminal — has ``is_error: bool``, ``result: str``

Single-shot semantics: each ``prompt()`` call dispatches a fresh TermLink
worker (TermLink's run.sh writes exit_code once and exits). Reuse requires
a new instance with a fresh ``name``.
"""

from __future__ import annotations

import json
import os
import subprocess
import uuid
from pathlib import Path
from typing import Iterator, List, Optional


DISPATCH_DIR = Path("/tmp/tl-dispatch")


class TermLinkWorker:
    """Spawn a TermLink worker via ``fw termlink dispatch`` and yield events.

    Args:
        model:         claude --model value, forwarded as ``--model`` flag.
                       Empty string is allowed (TermLink resolves a default).
        cwd:           working directory passed via ``--project``.
        task_id:       task reference for governance (required by
                       ``fw termlink dispatch``'s ``--task`` flag — T-630/T-652).
        env:           extra env vars forwarded as repeated ``--env KEY=VAL``.
                       Keys must match ``[A-Z_][A-Z0-9_]*`` (dispatch validates).
        allowed_tools: list forwarded as ``--tools`` (comma-joined). Empty list
                       → flag omitted, claude -p uses its default catalogue.
        task_type:     forwarded as ``--task-type``; lets route_cache learn.
        timeout:       per-worker timeout in seconds (forwarded as ``--timeout``).
        fw_bin:        path to the ``fw`` binary. Default: env ``FW_BIN`` or
                       resolved from PROJECT_ROOT.
        name:          dispatch worker name. Default: ``tl-<random>``.

    Usage::

        with TermLinkWorker("claude-sonnet-4-5", "/tmp", task_id="T-1797") as w:
            for ev in w.prompt("summarise CLAUDE.md §Watchtower Port"):
                process(ev)
    """

    def __init__(
        self,
        model: str,
        cwd: str,
        task_id: str,
        env: Optional[dict] = None,
        allowed_tools: Optional[List[str]] = None,
        task_type: Optional[str] = None,
        timeout: int = 1800,
        fw_bin: Optional[str] = None,
        name: Optional[str] = None,
    ) -> None:
        self.model = model
        self.cwd = cwd
        self.task_id = task_id
        self._env_overlay = env or {}
        self.allowed_tools = allowed_tools or []
        self.task_type = task_type
        self.timeout = timeout
        self.fw_bin = fw_bin or os.environ.get("FW_BIN") or self._default_fw_bin()
        self.name = name or f"tl-{uuid.uuid4().hex[:8]}"
        self.wdir = DISPATCH_DIR / self.name
        self.proc: Optional[subprocess.Popen] = None
        self._launched = False

    def _default_fw_bin(self) -> str:
        root = Path(os.environ.get("PROJECT_ROOT", os.getcwd()))
        cand_framework = root / "bin" / "fw"
        if cand_framework.exists():
            return str(cand_framework)
        cand_consumer = root / ".agentic-framework" / "bin" / "fw"
        if cand_consumer.exists():
            return str(cand_consumer)
        return "fw"

    def _build_dispatch_argv(self, message: str) -> List[str]:
        argv: List[str] = [
            self.fw_bin, "termlink", "dispatch",
            "--task", self.task_id,
            "--name", self.name,
            "--prompt", message,
            "--project", self.cwd,
            "--timeout", str(self.timeout),
        ]
        if self.model:
            argv.extend(["--model", self.model])
        if self.task_type:
            argv.extend(["--task-type", self.task_type])
        if self.allowed_tools:
            argv.extend(["--tools", ",".join(self.allowed_tools)])
        for k, v in self._env_overlay.items():
            argv.extend(["--env", f"{k}={v}"])
        return argv

    def _build_wait_argv(self) -> List[str]:
        return [
            self.fw_bin, "termlink", "wait",
            "--name", self.name,
            "--timeout", str(self.timeout),
        ]

    def prompt(self, message: str) -> Iterator[dict]:
        """Dispatch the prompt, wait for completion, replay events.

        Steps:
          1. ``fw termlink dispatch ... --prompt MSG`` — fire-and-forget; the
             worker dir is created at ``/tmp/tl-dispatch/<name>/``.
          2. ``fw termlink wait --name N --timeout T`` — block until
             ``exit_code`` file appears (or timeout).
          3. Read ``result.jsonl`` line-by-line; yield parsed events.

        Terminal event is ``{"type": "result", "is_error": bool, ...}``.
        Malformed JSON lines are skipped silently.
        """
        if self._launched:
            raise RuntimeError(
                "TermLinkWorker.prompt() is single-shot; create a new "
                "instance for a follow-up prompt"
            )
        self._launched = True

        # 1. Dispatch (the dispatch helper returns once the worker session
        #    has been spawned, not when claude finishes).
        self.proc = subprocess.Popen(
            self._build_dispatch_argv(message),
            stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        dispatch_rc = self.proc.wait()
        if dispatch_rc != 0:
            stderr = self.proc.stderr.read() if self.proc.stderr else ""
            raise RuntimeError(
                f"fw termlink dispatch failed (rc={dispatch_rc}): {stderr.strip()}"
            )

        # 2. Wait for worker completion. On timeout we still try to read
        #    whatever events landed.
        try:
            subprocess.run(
                self._build_wait_argv(),
                check=False,
                timeout=self.timeout + 30,
            )
        except subprocess.TimeoutExpired:
            pass

        # 3. Replay events from result.jsonl.
        result_path = self.wdir / "result.jsonl"
        if not result_path.exists():
            return
        with result_path.open() as f:
            for line in f:
                stripped = line.rstrip("\r\n")
                if not stripped:
                    continue
                try:
                    event = json.loads(stripped)
                except json.JSONDecodeError:
                    continue
                yield event
                if event.get("type") == "result":
                    return

    def close(self) -> int:
        """Best-effort: reap the dispatch helper subprocess.

        Worker dir cleanup (``termlink signal`` + ``termlink clean``) is owned
        by ``fw termlink cleanup`` and not run here — the worker directory
        holds the post-mortem forensic trail (meta.json, result.jsonl,
        exit_code) that downstream tooling (``fw outcome read``, route_cache)
        consumes. Premature cleanup would erase the trail.
        """
        if self.proc is None:
            return 0
        try:
            return self.proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            self.proc.kill()
            try:
                return self.proc.wait(timeout=2)
            except subprocess.TimeoutExpired:
                return -1
        finally:
            self.proc = None

    def __enter__(self) -> "TermLinkWorker":
        return self

    def __exit__(self, exc_type, exc, tb) -> None:
        self.close()
