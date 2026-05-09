#!/usr/bin/env python3
"""
OllamaLoopWorker — subprocess wrapper for `claude -p` with redirected env vars.

T-1700 shipped the litellm proxy on localhost:4000; the workflow-side env block
(ANTHROPIC_BASE_URL=http://localhost:4000, ANTHROPIC_API_KEY=sk-litellm-local-dev)
diverts claude -p's API calls to the local proxy, which fronts ollama / hermes3.
This is the "ollama-loop" worker_kind.

T-1775 ships the Python primitive analogous to lib/pi_worker.PiWorker so
lib/spawn._DISPATCHERS can route worker_kind=ollama-loop without falling back
to the agents/termlink/termlink.sh shell pattern (which exists but is a
fire-and-forget dispatcher, not a synchronous primitive).

Protocol contract (claude -p --output-format stream-json --verbose):
  Each stdout line is a JSON event:
    {"type":"system", ...}      boot
    {"type":"assistant", ...}   text + tool_use blocks
    {"type":"user", ...}        tool_result blocks
    {"type":"result", ...}      terminal — has `is_error: bool`, `result: str`

The same anti-readline rule applies (LF-delimited only, U+2028/U+2029 must not
split events). Use bufsize=1 + iterate `for line in proc.stdout`.
"""

from __future__ import annotations

import json
import os
import subprocess
from typing import Iterator, List, Optional


class OllamaLoopWorker:
    """Spawn `claude -p` with stream-json output and yield parsed events.

    Args:
        model:         claude --model value (e.g. "claude-3-5-sonnet-hermes3").
                       This must match a litellm proxy alias when env redirects
                       to localhost:4000.
        cwd:           working directory for the claude subprocess.
        env:           extra env vars to overlay on os.environ. The expected
                       shape for ollama-loop dispatch is:
                         ANTHROPIC_BASE_URL=http://localhost:4000
                         ANTHROPIC_API_KEY=sk-litellm-local-dev
        allowed_tools: list of tool names for the --tools flag. Empty list →
                       flag is omitted, claude -p uses its default catalogue.
        binary:        override claude binary path (default "claude" from PATH).

    Usage:
        with OllamaLoopWorker("claude-3-5-sonnet-hermes3", "/tmp",
                              env={"ANTHROPIC_BASE_URL":"http://localhost:4000",
                                   "ANTHROPIC_API_KEY":"sk-litellm-local-dev"},
                              allowed_tools=["Read","Bash","Grep"]) as w:
            for ev in w.prompt("summarise CLAUDE.md §Watchtower Port"):
                process(ev)
    """

    def __init__(
        self,
        model: str,
        cwd: str,
        env: Optional[dict] = None,
        allowed_tools: Optional[List[str]] = None,
        binary: str = "claude",
    ) -> None:
        self.model = model
        self.cwd = cwd
        self.allowed_tools = allowed_tools or []
        self.binary = binary
        self._env_overlay = env or {}
        self.proc: Optional[subprocess.Popen] = None
        self._launched = False

    def _build_argv(self, message: str) -> List[str]:
        argv = [
            self.binary,
            "-p", message,
            "--model", self.model,
            "--output-format", "stream-json",
            "--verbose",
        ]
        if self.allowed_tools:
            argv.extend(["--tools", ",".join(self.allowed_tools)])
        return argv

    def _build_env(self) -> dict:
        merged = dict(os.environ)
        merged.update(self._env_overlay)
        return merged

    def prompt(self, message: str) -> Iterator[dict]:
        """Spawn claude -p with the prompt; yield parsed events until terminal.

        claude -p reads the prompt as a positional argv argument (NOT stdin),
        so each call to prompt() spawns a fresh process. Terminal event is
        ``{"type": "result", "is_error": bool, ...}``.

        Malformed JSON lines are skipped silently — claude -p's stream-json
        contract permits diagnostic noise on stderr but stdout is JSONL-only.
        """
        if self._launched:
            raise RuntimeError(
                "OllamaLoopWorker.prompt() is single-shot; create a new "
                "instance for a follow-up prompt"
            )
        self._launched = True

        self.proc = subprocess.Popen(
            self._build_argv(message),
            stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            cwd=self.cwd,
            env=self._build_env(),
            text=True,
            bufsize=1,
        )

        if self.proc.stdout is None:
            raise RuntimeError("OllamaLoopWorker subprocess has no stdout")

        for line in self.proc.stdout:
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
        """Wait ≤5s for child to exit; kill + wait ≤2s if needed.

        Returns exit code, or -1 if killed without clean exit.
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

    def __enter__(self) -> "OllamaLoopWorker":
        return self

    def __exit__(self, exc_type, exc, tb) -> None:
        self.close()
