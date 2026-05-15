#!/usr/bin/env python3
"""
PiWorker — subprocess wrapper for pi (mariozechner/coding-agent) in RPC mode.

T-1692 design (`docs/reports/T-1692-pi-rpc-integration.md`); T-1701 v1 build.

Protocol contract (LF-delimited JSONL, one event per line):
  request:  {"id": "req-N", "type": "prompt", "message": "..."}
  events:   {"type": "response" | "tool_use" | ... , "id": "req-N", ...}
  done:     {"type": "agent.done"}
  error:    {"type": "error", "retryable": bool, ...}

Framing rules pinned in pi's `packages/coding-agent/docs/rpc.md`:
  - LF-delimited only. Node `readline` is non-compliant because it splits on
    U+2028/U+2029 which can appear inside JSON string literals.
  - Use `bufsize=1` (line-buffered) and explicit `\\n` splitting.
  - Strip trailing `\\r` defensively (some shells inject CR on Windows).

Invariants worth pinning (see tests/unit/test_pi_worker.py):
  - Module import does NOT spawn pi. Only PiWorker(...) construction does.
  - U+2028/U+2029 in tool-use payload strings does not split the event.
  - close() is idempotent and tolerates an already-exited child.

Spawn-side note: this class is the worker primitive. The dispatch driver that
reads a resolver envelope, instantiates PiWorker, streams events to
.context/dispatch-blobs/<id>/events.jsonl, and emits the final cost=0 row to
.context/dispatches.jsonl is a separate spawn-side module — out of scope for
T-1701, same as T-1700 deferred its claude-p spawn driver.
"""

from __future__ import annotations

import json
import subprocess
from typing import Iterator, Optional


class PiWorker:
    """Spawn pi in RPC mode and stream JSONL events for a single prompt.

    Args:
        provider: pi --provider value (e.g. "anthropic", "openai", "huggingface").
        model:    pi --model value (e.g. "claude-3-5-sonnet-latest").
        cwd:      working directory for the pi subprocess.
        binary:   override pi binary path (default "pi" from PATH).

    Usage:
        with closing(PiWorker("anthropic", "claude-3-5-sonnet-latest", "/tmp")) as w:
            for ev in w.prompt("summarise CLAUDE.md §Watchtower Port"):
                process(ev)
    """

    def __init__(
        self,
        provider: str,
        model: str,
        cwd: str,
        binary: str = "pi",
    ) -> None:
        self.provider = provider
        self.model = model
        self.cwd = cwd
        self.binary = binary
        self.req_id = 0
        self.proc: Optional[subprocess.Popen] = subprocess.Popen(
            [
                binary,
                "--mode", "rpc",
                "--provider", provider,
                "--model", model,
                "--no-session",
            ],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            cwd=cwd,
            text=True,
            bufsize=1,
        )

    def prompt(self, message: str) -> Iterator[dict]:
        """Send one prompt; yield events until agent.done or error.

        Yields each parsed JSON event. Stops yielding (and returns) on the first
        terminal event: {"type": "agent.done"} or {"type": "error", ...}.

        Malformed JSON lines are skipped silently — pi's RPC contract permits
        free-form lines on stderr but stdout is JSONL-only; if a non-JSON line
        appears on stdout we treat it as protocol noise rather than crashing
        the dispatch.
        """
        if self.proc is None or self.proc.stdin is None or self.proc.stdout is None:
            raise RuntimeError("PiWorker subprocess is not running")

        self.req_id += 1
        req = {"id": f"req-{self.req_id}", "type": "prompt", "message": message}
        self.proc.stdin.write(json.dumps(req) + "\n")
        self.proc.stdin.flush()

        for line in self.proc.stdout:
            stripped = line.rstrip("\r\n")
            if not stripped:
                continue
            try:
                event = json.loads(stripped)
            except json.JSONDecodeError:
                continue
            yield event
            etype = event.get("type")
            if etype in ("agent.done", "error"):
                return

    def close(self) -> int:
        """Close stdin and wait ≤5s for the child. Returns exit code (-1 if killed)."""
        if self.proc is None:
            return 0
        try:
            if self.proc.stdin and not self.proc.stdin.closed:
                self.proc.stdin.close()
        except Exception:
            pass
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

    def __enter__(self) -> "PiWorker":
        return self

    def __exit__(self, exc_type, exc, tb) -> None:
        self.close()
