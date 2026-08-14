#!/usr/bin/env python3
"""
T-1706 — thin tool-execution loop for ollama-research workflow.

Bypasses claude -p (the bottleneck per T-1704). Calls litellm /v1/messages
directly with a curated 3-tool definition (Read, Bash, Grep), parses
tool_use blocks, executes them under a strict sandbox, posts tool_result,
loops until stop_reason=end_turn or hard cap.

Output contract (matches the dispatch wdir layout consumed by
fw outcome / dispatch_status / T-1700 harness scripts):

  prompt.md      (input — read from wdir)
  env.sh         (optional — sourced before run, e.g. ANTHROPIC_BASE_URL)
  meta.json      (existing — written by cmd_dispatch; we only read)
  result.jsonl   (one JSON object per line — assistant/user/result events
                  in the same shape claude -p stream-json emits, so the
                  T-1700 harness tool_use counter works unmodified)
  result.md      (final assistant text)
  exit_code      (0 = end_turn reached, 1 = error / iteration cap, 2 = http)

Usage:
  ollama-tool-loop.py --wdir /tmp/tl-dispatch/<name>

Environment:
  ANTHROPIC_BASE_URL   default http://localhost:4000
  ANTHROPIC_API_KEY    default sk-litellm-local-dev
  OLLAMA_LOOP_MODEL    default claude-3-5-sonnet-hermes3 (litellm alias)
  OLLAMA_LOOP_MAX_ITER default 10
"""

from __future__ import annotations

import argparse
import json
import os
import shlex
import subprocess
import sys
import time
import urllib.request
import urllib.error
from pathlib import Path

MAX_ITER_DEFAULT = 10
PER_CALL_TIMEOUT = 120
TOOL_BASH_TIMEOUT = 30
TOOL_OUTPUT_LIMIT = 8000

DEFAULT_MODEL = "claude-3-5-sonnet-hermes3"
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

PROJECT_ROOT = Path(os.environ.get("PROJECT_ROOT", os.getcwd())).resolve()


_ALLOWED_PREFIXES = (
    str(PROJECT_ROOT),
    "/etc",
    "/tmp",
    "/proc",
    "/sys",
    "/usr/lib",   # /etc/os-release symlinks here on some distros
    "/usr/share",
    "/var/log",
)


def _is_allowed(s: str) -> bool:
    return any(s == a or s.startswith(a + "/") for a in _ALLOWED_PREFIXES)


def _safe_path(p: str) -> Path:
    """Resolve a tool-supplied path. Allow if EITHER the requested path or
    the resolved target sits under an allow-listed prefix — this lets
    /etc/os-release work on distros where it symlinks to /usr/lib/os-release.
    """
    cand = Path(p).expanduser()
    cand_abs = cand if cand.is_absolute() else (PROJECT_ROOT / cand)
    try:
        resolved = cand.resolve()
    except OSError:
        raise ValueError(f"path resolve failed: {p}")
    if not (_is_allowed(str(cand_abs)) or _is_allowed(str(resolved))):
        raise ValueError(f"path outside sandbox: {resolved} (requested {p})")
    return resolved


def _trunc(s: str, limit: int = TOOL_OUTPUT_LIMIT) -> str:
    if len(s) <= limit:
        return s
    return s[:limit] + f"\n[... {len(s) - limit} bytes truncated]"


def tool_read(args: dict) -> str:
    path = _safe_path(args["path"])
    if not path.is_file():
        return f"ERROR: not a file: {path}"
    try:
        return _trunc(path.read_text(errors="replace"))
    except Exception as exc:
        return f"ERROR: read failed: {exc}"


_BASH_DENY = ("rm -rf", "sudo", "dd if=", "mkfs", ":(){", "shutdown", "reboot",
              "chmod -R 000", "> /dev/sda")


def tool_bash(args: dict) -> str:
    cmd = args["command"]
    if not isinstance(cmd, str):
        return "ERROR: command must be a string"
    low = cmd.lower()
    for d in _BASH_DENY:
        if d in low:
            return f"ERROR: command blocked by sandbox (matched '{d}')"
    try:
        proc = subprocess.run(
            cmd,
            shell=True,
            capture_output=True,
            text=True,
            timeout=TOOL_BASH_TIMEOUT,
            cwd=str(PROJECT_ROOT),
        )
    except subprocess.TimeoutExpired:
        return f"ERROR: command timed out after {TOOL_BASH_TIMEOUT}s"
    except Exception as exc:
        return f"ERROR: subprocess failed: {exc}"
    out = proc.stdout
    if proc.returncode != 0:
        out = (out or "") + f"\n[exit={proc.returncode}] stderr: {proc.stderr[:1000]}"
    return _trunc(out or "[no output]")


def tool_grep(args: dict) -> str:
    pattern = args["pattern"]
    path = _safe_path(args["path"])
    if not path.exists():
        return f"ERROR: path missing: {path}"
    cmd = ["grep", "-rIn", "--", pattern, str(path)] if path.is_dir() else \
          ["grep", "-In", "--", pattern, str(path)]
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=15)
    except subprocess.TimeoutExpired:
        return "ERROR: grep timed out after 15s"
    out = proc.stdout or ""
    if proc.returncode == 1 and not out:
        return "[no matches]"
    return _trunc(out)


TOOL_FUNCS = {
    "Read": tool_read,
    "Bash": tool_bash,
    "Grep": tool_grep,
}


def post_messages(base: str, key: str, body: dict) -> dict:
    url = base.rstrip("/") + "/v1/messages"
    data = json.dumps(body).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=data,
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {key}",
            "anthropic-version": "2023-06-01",
            "x-api-key": key,
        },
    )
    with urllib.request.urlopen(req, timeout=PER_CALL_TIMEOUT) as resp:
        return json.loads(resp.read().decode("utf-8"))


def write_event(fp, event: dict) -> None:
    fp.write(json.dumps(event) + "\n")
    fp.flush()


def run(wdir: Path) -> int:
    prompt_file = wdir / "prompt.md"
    if not prompt_file.exists():
        sys.stderr.write(f"FATAL: missing {prompt_file}\n")
        return 1

    prompt = prompt_file.read_text().strip()

    base = os.environ.get("ANTHROPIC_BASE_URL", DEFAULT_BASE)
    key = os.environ.get("ANTHROPIC_API_KEY", DEFAULT_KEY)
    model = os.environ.get("OLLAMA_LOOP_MODEL", DEFAULT_MODEL)
    max_iter = int(os.environ.get("OLLAMA_LOOP_MAX_ITER", MAX_ITER_DEFAULT))

    result_jsonl = wdir / "result.jsonl"
    result_md = wdir / "result.md"
    exit_file = wdir / "exit_code"
    meta_file = wdir / "meta.json"

    fp = result_jsonl.open("w")

    # Initial user message
    messages: list = [{"role": "user", "content": prompt}]
    write_event(fp, {
        "type": "user",
        "message": {"role": "user", "content": [{"type": "text", "text": prompt}]},
    })

    iteration = 0
    final_text = ""
    total_input_tokens = 0
    total_output_tokens = 0
    started = time.time()

    while iteration < max_iter:
        iteration += 1
        body = {
            "model": model,
            "max_tokens": 1024,
            "tools": TOOL_DEFINITIONS,
            "messages": messages,
        }
        try:
            resp = post_messages(base, key, body)
        except urllib.error.HTTPError as exc:
            err = f"HTTPError {exc.code}: {exc.read().decode('utf-8', errors='replace')[:500]}"
            write_event(fp, {"type": "error", "error": err})
            fp.close()
            result_md.write_text("")
            exit_file.write_text("2")
            sys.stderr.write(err + "\n")
            return 2
        except Exception as exc:
            err = f"Request failed: {exc}"
            write_event(fp, {"type": "error", "error": err})
            fp.close()
            result_md.write_text("")
            exit_file.write_text("2")
            sys.stderr.write(err + "\n")
            return 2

        usage = resp.get("usage", {}) or {}
        total_input_tokens += usage.get("input_tokens", 0) or 0
        total_output_tokens += usage.get("output_tokens", 0) or 0

        content = resp.get("content", []) or []
        stop_reason = resp.get("stop_reason")

        # Stream-json shape compatible with claude -p output
        # so the T-1700 harness parser counts tool_use events identically.
        write_event(fp, {
            "type": "assistant",
            "message": {
                "role": "assistant",
                "model": model,
                "content": content,
                "stop_reason": stop_reason,
                "usage": usage,
            },
        })

        # Append assistant turn to history
        messages.append({"role": "assistant", "content": content})

        # If stop_reason isn't tool_use, we're done
        if stop_reason != "tool_use":
            for block in content:
                if block.get("type") == "text":
                    final_text += block.get("text", "")
            break

        # Execute each tool_use, build tool_result content
        tool_results = []
        for block in content:
            if block.get("type") != "tool_use":
                if block.get("type") == "text":
                    final_text += block.get("text", "") + "\n"
                continue
            tname = block.get("name")
            tinput = block.get("input") or {}
            tid = block.get("id")
            func = TOOL_FUNCS.get(tname)
            if func is None:
                tool_output = f"ERROR: unknown tool '{tname}'"
            else:
                try:
                    tool_output = func(tinput)
                except Exception as exc:
                    tool_output = f"ERROR: {tname} raised: {exc}"
            tool_results.append({
                "type": "tool_result",
                "tool_use_id": tid,
                "content": tool_output,
            })

        if not tool_results:
            # stop_reason was tool_use but no tool_use blocks — protocol error
            break

        user_msg = {"role": "user", "content": tool_results}
        messages.append(user_msg)
        write_event(fp, {"type": "user", "message": user_msg})

    elapsed = time.time() - started

    # Final result event (matches claude -p stream-json shape so termlink.sh
    # extraction `jq 'select(.type=="result") | .result'` works on us too).
    write_event(fp, {
        "type": "result",
        "result": final_text.strip(),
        "iterations": iteration,
        "elapsed": round(elapsed, 2),
        "input_tokens": total_input_tokens,
        "output_tokens": total_output_tokens,
    })
    fp.close()

    result_md.write_text(final_text.strip() + "\n")

    # Update meta.json with completion details (best-effort merge)
    try:
        if meta_file.exists():
            meta = json.loads(meta_file.read_text())
        else:
            meta = {}
    except Exception:
        meta = {}
    meta.update({
        "worker_kind": "ollama-loop",
        "model_used": model,
        "iterations": iteration,
        "input_tokens": total_input_tokens,
        "output_tokens": total_output_tokens,
        "elapsed_seconds": round(elapsed, 2),
        "completed": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "status": "completed",
    })
    meta_file.write_text(json.dumps(meta, indent=2) + "\n")

    # Exit code: 0 if ended cleanly via end_turn, 1 if iteration cap reached
    rc = 0 if iteration < max_iter or messages[-1]["role"] == "assistant" else 1
    # Stricter: reach end_turn → 0; iteration cap → 1
    final_assistant = messages[-1]["content"] if messages and messages[-1]["role"] == "assistant" else None
    if final_assistant is None:
        rc = 1
    exit_file.write_text(str(rc))
    return rc


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--wdir", required=True, type=Path,
                    help="Dispatch working directory (contains prompt.md, env.sh, meta.json)")
    args = ap.parse_args()

    wdir = args.wdir.resolve()
    if not wdir.is_dir():
        sys.stderr.write(f"FATAL: wdir does not exist: {wdir}\n")
        return 1

    return run(wdir)


if __name__ == "__main__":
    sys.exit(main())
