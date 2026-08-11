#!/usr/bin/env python3
"""OllamaThinLoopWorker — direct /v1/messages tool loop for small local models.

T-2592 root finding: worker_kind=ollama-loop wraps `claude -p`, whose multi-K
injected system prompt drowns 8B models — hermes3 scored 0/9 real tool_use on
that path (T-1704), while the thin direct-API loop (tools/ollama-tool-loop.py)
scored 100% (T-1706). The GO evidence and the production worker were different
primitives. This module ports the validated thin loop into the spawn substrate
as worker_kind=ollama-thin-loop.

No subprocess, no claude binary, no MCP surface: POST {base}/v1/messages with
a curated tool catalogue (Read, Bash, Grep), execute tool_use blocks under a
strict path/command sandbox, post tool_result, loop until stop_reason=end_turn
or the iteration cap.

Event contract (same stream-json shapes claude -p emits, so lib/spawn's
event-file writer, `_classify_status`, and the T-1700 harness tool_use counter
all work unmodified):

    {"type": "system", "subtype": "init", "tools": [...], "model": ...}
    {"type": "assistant", "message": {role, model, content, stop_reason, usage}}
    {"type": "user", "message": {role, content: [tool_result...]}}
    {"type": "result", "is_error": bool, "result": str, ...}     terminal

HTTP/transport failures yield a terminal result event with is_error=True
rather than raising, so the dispatch row still records a classified outcome.
"""

from __future__ import annotations

import json
import os
import subprocess
import urllib.error
import urllib.request
from pathlib import Path
from typing import Iterator, List, Optional

MAX_ITER_DEFAULT = 10
PER_CALL_TIMEOUT = 120
TOOL_BASH_TIMEOUT = 30
TOOL_OUTPUT_LIMIT = 8000
MAX_TOKENS = 1024

DEFAULT_BASE = "http://localhost:4000"
DEFAULT_KEY = "sk-litellm-local-dev"

TOOL_DEFINITIONS = [
    {
        "name": "Read",
        "description": "Read a text file from disk and return its contents. "
                       "Argument: path (absolute or relative to project root).",
        "input_schema": {
            "type": "object",
            "properties": {
                "path": {"type": "string", "description": "Path to read."}
            },
            "required": ["path"],
        },
    },
    {
        "name": "Bash",
        "description": "Run a single shell command and return stdout (truncated). "
                       "No persistent state across calls. 30s timeout.",
        "input_schema": {
            "type": "object",
            "properties": {
                "command": {"type": "string", "description": "The shell command."}
            },
            "required": ["command"],
        },
    },
    {
        "name": "Grep",
        "description": "Search for a pattern in a file or directory. "
                       "Returns matching lines (truncated).",
        "input_schema": {
            "type": "object",
            "properties": {
                "pattern": {"type": "string"},
                "path": {"type": "string"},
            },
            "required": ["pattern", "path"],
        },
    },
]

_SANDBOX_EXTRA_PREFIXES = (
    "/etc",
    "/tmp",
    "/proc",
    "/sys",
    "/usr/lib",   # /etc/os-release symlinks here on some distros
    "/usr/share",
    "/var/log",
)

_BASH_DENY = ("rm -rf", "sudo", "dd if=", "mkfs", ":(){", "shutdown", "reboot",
              "chmod -R 000", "> /dev/sda")


def _trunc(s: str, limit: int = TOOL_OUTPUT_LIMIT) -> str:
    if len(s) <= limit:
        return s
    return s[:limit] + f"\n[... {len(s) - limit} bytes truncated]"


class OllamaThinLoopWorker:
    """Direct-API tool loop against a litellm/anthropic-compatible endpoint.

    Interface mirrors lib/ollama_loop.OllamaLoopWorker (prompt() → event
    iterator, single-shot, close(), context manager) so lib/spawn dispatchers
    stay symmetric.

    Args:
        model:         litellm alias (e.g. "claude-3-5-sonnet-hermes3").
        cwd:           sandbox root for tool execution (Read/Bash/Grep are
                       confined to cwd plus a small read-only system allowlist).
        env:           overlay consulted for ANTHROPIC_BASE_URL /
                       ANTHROPIC_API_KEY before os.environ (matches the
                       envelope["env"] redirection contract).
        allowed_tools: subset of {Read, Bash, Grep} to expose. Empty/None →
                       all three.
        max_iter:      hard cap on request/tool-execute iterations
                       (default: OLLAMA_LOOP_MAX_ITER env or 10).
    """

    def __init__(
        self,
        model: str,
        cwd: str,
        env: Optional[dict] = None,
        allowed_tools: Optional[List[str]] = None,
        max_iter: Optional[int] = None,
    ) -> None:
        self.model = model
        self.cwd = str(Path(cwd).resolve())
        self._env_overlay = env or {}
        names = allowed_tools or [t["name"] for t in TOOL_DEFINITIONS]
        self.tools = [t for t in TOOL_DEFINITIONS if t["name"] in names]
        self.max_iter = max_iter or int(
            self._env("OLLAMA_LOOP_MAX_ITER", str(MAX_ITER_DEFAULT)))
        self._launched = False

    # -- env / transport ----------------------------------------------------
    def _env(self, key: str, default: str) -> str:
        return self._env_overlay.get(key) or os.environ.get(key) or default

    def _post_messages(self, body: dict) -> dict:
        base = self._env("ANTHROPIC_BASE_URL", DEFAULT_BASE)
        key = self._env("ANTHROPIC_API_KEY", DEFAULT_KEY)
        url = base.rstrip("/") + "/v1/messages"
        req = urllib.request.Request(
            url,
            data=json.dumps(body).encode("utf-8"),
            headers={
                "Content-Type": "application/json",
                "Authorization": f"Bearer {key}",
                "anthropic-version": "2023-06-01",
                "x-api-key": key,
            },
        )
        with urllib.request.urlopen(req, timeout=PER_CALL_TIMEOUT) as resp:
            return json.loads(resp.read().decode("utf-8"))

    # -- sandboxed tools ----------------------------------------------------
    def _is_allowed(self, s: str) -> bool:
        prefixes = (self.cwd,) + _SANDBOX_EXTRA_PREFIXES
        return any(s == a or s.startswith(a + "/") for a in prefixes)

    def _safe_path(self, p: str) -> Path:
        """Allow if EITHER the requested path or the resolved target sits under
        an allow-listed prefix — lets /etc/os-release work where it symlinks
        into /usr/lib."""
        cand = Path(p).expanduser()
        cand_abs = cand if cand.is_absolute() else (Path(self.cwd) / cand)
        try:
            resolved = cand_abs.resolve()
        except OSError as exc:
            raise ValueError(f"path resolve failed: {p}") from exc
        if not (self._is_allowed(str(cand_abs)) or self._is_allowed(str(resolved))):
            raise ValueError(f"path outside sandbox: {resolved} (requested {p})")
        return resolved

    def _tool_read(self, args: dict) -> str:
        try:
            path = self._safe_path(args["path"])
        except (KeyError, ValueError) as exc:
            return f"ERROR: {exc}"
        if not path.is_file():
            return f"ERROR: not a file: {path}"
        try:
            return _trunc(path.read_text(errors="replace"))
        except Exception as exc:  # noqa: BLE001 — tool errors go to the model
            return f"ERROR: read failed: {exc}"

    def _tool_bash(self, args: dict) -> str:
        cmd = args.get("command")
        if not isinstance(cmd, str):
            return "ERROR: command must be a string"
        low = cmd.lower()
        for d in _BASH_DENY:
            if d in low:
                return f"ERROR: command blocked by sandbox (matched '{d}')"
        try:
            # T-2917: merge the envelope env overlay (worker-identity
            # GIT_AUTHOR_*/GIT_COMMITTER_* among others) so a `git commit` run
            # through this tool picks up the dispatch identity instead of
            # falling through to this process's ambient env. Every other
            # dispatcher (_build_env in ollama_loop, PiWorker.__init__) merges
            # the same way; this was the one Bash-executing path that didn't.
            proc = subprocess.run(
                cmd, shell=True, capture_output=True, text=True,
                timeout=TOOL_BASH_TIMEOUT, cwd=self.cwd,
                env={**os.environ, **self._env_overlay},
            )
        except subprocess.TimeoutExpired:
            return f"ERROR: command timed out after {TOOL_BASH_TIMEOUT}s"
        except Exception as exc:  # noqa: BLE001
            return f"ERROR: subprocess failed: {exc}"
        out = proc.stdout
        if proc.returncode != 0:
            out = (out or "") + f"\n[exit={proc.returncode}] stderr: {proc.stderr[:1000]}"
        return _trunc(out or "[no output]")

    def _tool_grep(self, args: dict) -> str:
        pattern = args.get("pattern")
        if not isinstance(pattern, str):
            return "ERROR: pattern must be a string"
        try:
            path = self._safe_path(args["path"])
        except (KeyError, ValueError) as exc:
            return f"ERROR: {exc}"
        if not path.exists():
            return f"ERROR: path missing: {path}"
        argv = ["grep", "-rIn", "--", pattern, str(path)] if path.is_dir() else \
               ["grep", "-In", "--", pattern, str(path)]
        try:
            proc = subprocess.run(argv, capture_output=True, text=True, timeout=15)
        except subprocess.TimeoutExpired:
            return "ERROR: grep timed out after 15s"
        out = proc.stdout or ""
        if proc.returncode == 1 and not out:
            return "[no matches]"
        return _trunc(out)

    def _run_tool(self, name: str, args: dict) -> str:
        func = {
            "Read": self._tool_read,
            "Bash": self._tool_bash,
            "Grep": self._tool_grep,
        }.get(name)
        if func is None:
            return f"ERROR: unknown tool '{name}'"
        try:
            return func(args)
        except Exception as exc:  # noqa: BLE001 — never let a tool kill the loop
            return f"ERROR: {name} raised: {exc}"

    # -- main loop ----------------------------------------------------------
    def prompt(self, message: str) -> Iterator[dict]:
        """Run the tool loop; yield claude-p-shaped events until terminal.

        Single-shot: create a new instance for a follow-up prompt.
        """
        if self._launched:
            raise RuntimeError(
                "OllamaThinLoopWorker.prompt() is single-shot; create a new "
                "instance for a follow-up prompt"
            )
        self._launched = True

        yield {
            "type": "system",
            "subtype": "init",
            "model": self.model,
            "tools": [t["name"] for t in self.tools],
            "worker_kind": "ollama-thin-loop",
        }

        messages: list = [{"role": "user", "content": message}]
        yield {
            "type": "user",
            "message": {"role": "user",
                        "content": [{"type": "text", "text": message}]},
        }

        iteration = 0
        final_text = ""
        total_in = 0
        total_out = 0
        ended_clean = False

        while iteration < self.max_iter:
            iteration += 1
            body = {
                "model": self.model,
                "max_tokens": MAX_TOKENS,
                "tools": self.tools,
                "messages": messages,
            }
            try:
                resp = self._post_messages(body)
            except urllib.error.HTTPError as exc:
                detail = exc.read().decode("utf-8", errors="replace")[:500]
                yield {"type": "result", "is_error": True,
                       "result": f"HTTPError {exc.code}: {detail}",
                       "iterations": iteration}
                return
            except Exception as exc:  # noqa: BLE001 — transport class varies
                yield {"type": "result", "is_error": True,
                       "result": f"Request failed: {exc}",
                       "iterations": iteration}
                return

            usage = resp.get("usage", {}) or {}
            total_in += usage.get("input_tokens", 0) or 0
            total_out += usage.get("output_tokens", 0) or 0
            content = resp.get("content", []) or []
            stop_reason = resp.get("stop_reason")

            yield {
                "type": "assistant",
                "message": {
                    "role": "assistant",
                    "model": self.model,
                    "content": content,
                    "stop_reason": stop_reason,
                    "usage": usage,
                },
            }
            messages.append({"role": "assistant", "content": content})

            if stop_reason != "tool_use":
                for block in content:
                    if block.get("type") == "text":
                        final_text += block.get("text", "")
                ended_clean = True
                break

            tool_results = []
            for block in content:
                if block.get("type") != "tool_use":
                    if block.get("type") == "text":
                        final_text += block.get("text", "") + "\n"
                    continue
                tool_results.append({
                    "type": "tool_result",
                    "tool_use_id": block.get("id"),
                    "content": self._run_tool(block.get("name"),
                                              block.get("input") or {}),
                })

            if not tool_results:
                # stop_reason=tool_use with no tool_use blocks — protocol error
                break

            user_msg = {"role": "user", "content": tool_results}
            messages.append(user_msg)
            yield {"type": "user", "message": user_msg}

        yield {
            "type": "result",
            "is_error": not ended_clean,
            "result": final_text.strip() if ended_clean
            else f"loop ended without end_turn after {iteration} iteration(s)",
            "iterations": iteration,
            "input_tokens": total_in,
            "output_tokens": total_out,
        }

    # -- lifecycle (interface parity with OllamaLoopWorker) -----------------
    def close(self) -> int:
        return 0

    def __enter__(self) -> "OllamaThinLoopWorker":
        return self

    def __exit__(self, exc_type, exc, tb) -> None:
        self.close()
