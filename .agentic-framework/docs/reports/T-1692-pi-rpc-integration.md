# T-1692 Research Artifact — pi RPC integration

**Status:** in-progress (2026-05-03) — paper inception; install + smoke test deferred to v1 build
**Workflow type:** inception
**Arc:** orchestrator-rethink

## A-1 — RPC stability (paper-validated)

Source: `https://raw.githubusercontent.com/badlogic/pi-mono/main/packages/coding-agent/docs/rpc.md`

Findings:
- Stable invocation: `pi --mode rpc [--provider X --model Y --no-session --session-dir P]`
- **Strict JSONL framing** with LF (`\n`) only — no Unicode-separator splits. Their docs explicitly call out Node's `readline` as non-compliant. Implication for our wrapper: use a low-level line-buffered reader, not stream-aware libraries.
- Commands: `prompt`, `steer`, plus extension commands. Optional `id` field for request/response correlation.
- Each command returns `{type: "response", command: ..., success: bool}` after acceptance; events stream asynchronously after.
- Streaming-mid-prompt requires explicit `streamingBehavior: "steer"|"followUp"`.

Active project (npm `@mariozechner/pi-coding-agent`, MIT, CI green per badge). RPC docs are extensive and explicit about edge cases. **A-1 paper-validated.**

## A-3 — Built-in tool coverage

pi default tools per docs: `read`, `write`, `edit`, `bash`.

Comparison to dispatchable workflow patterns:

| Workflow shape | Built-in pi tools sufficient? |
|----------------|-------------------------------|
| Code edit (read → modify → run tests) | Yes |
| Research / write report | Yes (read + write) |
| Bash-driven verification | Yes (bash) |
| MCP-tool-required (database query, browser, etc.) | **No** — pi has no MCP |
| Multi-file refactor with grep | bash only (grep via shell) |
| Cross-repo coordination | No (no MCP for TermLink) |

**A-3 paper-validated** for the ≥80% claim — the four built-in tools cover most code-edit workflows. MCP-required workflows route to TermLink (`worker_kind: TermLink`). T-1694's lint warns when an MCP field appears on a `worker_kind: pi` workflow.

## A-4 — Auth-token conflict

pi stores credentials at `~/.pi/agent/` (per docs). Framework credentials live in `.context/secrets/` (gitignored), `.framework.yaml`, or env vars. **No path collision.** Operator's `/login` flow inside pi is independent of framework auth state.

## A-2 — Quota error parsing

Cannot validate without an actual subscription-quota dispatch. Strategy for v1 build:
1. Use a dummy provider with rate-limited free tier (Hugging Face inference)
2. Fire enough dispatches to trigger 429
3. Verify the RPC error frame parses (matches `{type: "error", ...}` shape per docs)
4. Wrapper exposes `retryable: True/False` flag based on error class

## Wrapper design (sketch for v1 build)

```python
# lib/pi_worker.py — sketch
import json, subprocess, threading, queue
from typing import Iterator

class PiWorker:
    def __init__(self, provider: str, model: str, cwd: str):
        self.proc = subprocess.Popen(
            ["pi", "--mode", "rpc",
             "--provider", provider,
             "--model", model,
             "--no-session"],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            cwd=cwd,
            text=True,
            bufsize=1,  # line-buffered
        )
        self.req_id = 0

    def prompt(self, message: str) -> Iterator[dict]:
        """Send a prompt; yield events until completion/error."""
        self.req_id += 1
        req = {"id": f"req-{self.req_id}", "type": "prompt", "message": message}
        self.proc.stdin.write(json.dumps(req) + "\n")
        self.proc.stdin.flush()
        # Stream events until {"type": "response", "id": req_id} (acceptance)
        # then {"type": "agent.done"} (completion) or {"type": "error"}
        for line in self.proc.stdout:
            event = json.loads(line.rstrip("\r\n"))
            yield event
            if event.get("type") == "agent.done":
                return
            if event.get("type") == "error":
                return

    def close(self):
        self.proc.stdin.close()
        self.proc.wait(timeout=5)
```

Telemetry parity: every event with cost/token info gets summarized into the
`dispatches.jsonl` row at end-of-dispatch. The same dispatch_id, blob_dir,
workflow_sha, template_sha fields apply. The `worker_kind: pi` row omits
`mcp_config` (always absent for pi) and adds `pi_session_id`.

## fw doctor integration

Already wired in T-1694 (Q13). The check fires WARN when at least one workflow
declares `worker_kind: pi` AND pi is not on PATH. Install command:
`npm install -g @mariozechner/pi-coding-agent`.

## What's deferred to v1 build

1. Install pi on a representative host (`npm install -g @mariozechner/pi-coding-agent`)
2. `/login` to Anthropic Pro and verify subscription auth works headless after initial setup
3. Spike: dispatch a research task via wrapper; measure latency + cost ($0 expected)
4. Quota-error case (induce 429, verify retryable detection)
5. Extension/skills compatibility (the built-in toolset matches TermLink defaults — but `/skill:foo` style commands are pi-specific; wrapper passes them through verbatim)

## Recommendation

(in task file)
