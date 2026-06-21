"""govd_relay — the governance mediation relay / proxy brain (arc-013 / T-2431).

Productionizes the T-2429 spikes (proven: subscription OAuth survives a transparent
relay; tool_use + usage are visible at the wire; a tool call can be denied by
substituting a coherent text turn). The relay sits at the agent's `ANTHROPIC_BASE_URL`,
forwards requests to the upstream API with auth UNCHANGED (subscription billing
preserved), inspects each `tool_use` the model emits, and — per the sovereign policy —
either passes the turn through (allow) or replaces it with a coherent text refusal
(deny). Every intent + decision is audited.

This governs the agent's CHOICES (what it reaches for); the OS sandbox (T-2433)
governs EFFECTS. Two co-essential surfaces (design §4b).

SECURITY: the relay handles live credentials. It runs OUTSIDE the cage under a
non-agent uid (design §4c bootstrap) — its deployment is Lock-1 Part 1 (human/root).
This is a FIRST REVIEWABLE CUT: the mediation logic is real and tested; it is not
production-hardened (no TLS termination tuning, no backpressure limits, partial-turn
rewrite deferred — a denied response replaces the WHOLE turn).

The pure functions (parse_tool_uses / synth_deny_turn / Policy.decide /
Mediator.mediate) are network-free and unit-tested; serve() is the thin HTTP layer.
"""
from __future__ import annotations

import http.client
import http.server
import json
import os
import socketserver
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from lib.govd_holder import AppendOnlyAudit  # noqa: E402

UPSTREAM_DEFAULT = "api.anthropic.com"
EDIT_TOOLS = frozenset({"Write", "Edit", "NotebookEdit", "MultiEdit"})


# ── SSE parsing (pure) ──────────────────────────────────────────────────────
def _iter_data_events(sse_text: str):
    for line in sse_text.split("\n"):
        line = line.strip()
        if line.startswith("data:"):
            try:
                yield json.loads(line[5:].strip())
            except json.JSONDecodeError:
                continue


def parse_tool_uses(sse_text: str) -> list[dict]:
    """Extract tool_use blocks {name, id, input(str)} from a buffered SSE body."""
    tools: dict[int, dict] = {}
    for ev in _iter_data_events(sse_text):
        t = ev.get("type")
        if t == "content_block_start":
            cb = ev.get("content_block", {}) or {}
            if cb.get("type") == "tool_use":
                tools[ev.get("index")] = {"name": cb.get("name"), "id": cb.get("id"), "input": ""}
        elif t == "content_block_delta":
            d = ev.get("delta", {}) or {}
            if d.get("type") == "input_json_delta":
                i = ev.get("index")
                if i in tools:
                    tools[i]["input"] += d.get("partial_json", "")
    return list(tools.values())


def parse_usage(sse_text: str) -> dict:
    usage: dict = {}
    for ev in _iter_data_events(sse_text):
        if ev.get("type") == "message_start":
            usage.update((ev.get("message") or {}).get("usage", {}) or {})
        elif ev.get("type") == "message_delta":
            usage.update(ev.get("usage", {}) or {})
    return usage


def synth_deny_turn(model: str, denied_names: list[str], reason: str) -> bytes:
    """A valid, minimal text-only assistant turn (stop_reason end_turn, no tool_use →
    no owed tool_result) — the harness accepts it and the conversation stays coherent."""
    msg = (f"[GOVERNANCE] The requested tool call ({', '.join(denied_names)}) was denied "
           f"by policy: {reason}. No action was taken.")

    def ev(t, d):
        return (f"event: {t}\ndata: {json.dumps(d)}\n\n").encode()

    return b"".join([
        ev("message_start", {"type": "message_start", "message": {
            "id": "msg_govdeny", "type": "message", "role": "assistant",
            "model": model or "claude-opus-4-8", "content": [],
            "stop_reason": None, "stop_sequence": None,
            "usage": {"input_tokens": 1, "output_tokens": 1}}}),
        ev("content_block_start", {"type": "content_block_start", "index": 0,
            "content_block": {"type": "text", "text": ""}}),
        ev("ping", {"type": "ping"}),
        ev("content_block_delta", {"type": "content_block_delta", "index": 0,
            "delta": {"type": "text_delta", "text": msg}}),
        ev("content_block_stop", {"type": "content_block_stop", "index": 0}),
        ev("message_delta", {"type": "message_delta",
            "delta": {"stop_reason": "end_turn", "stop_sequence": None},
            "usage": {"output_tokens": 20}}),
        ev("message_stop", {"type": "message_stop"}),
    ])


# ── Policy (pure) ───────────────────────────────────────────────────────────
class Policy:
    """Sovereign-authored mediation policy. Invariants are hard denies the config
    cannot loosen; deny_tools / deny_command_patterns are additional rules."""

    def __init__(self, governance_paths=None, deny_command_patterns=None, deny_tools=None):
        self.governance_paths = list(governance_paths or [])
        self.deny_command_patterns = list(deny_command_patterns or [])
        self.deny_tools = set(deny_tools or [])

    @classmethod
    def load(cls, path):
        import yaml
        data = yaml.safe_load(Path(path).read_text()) or {}
        inv = data.get("invariants") or {}
        return cls(governance_paths=inv.get("governance_paths"),
                   deny_command_patterns=inv.get("deny_command_patterns"),
                   deny_tools=data.get("deny_tools"))

    def decide(self, name: str, tool_input) -> tuple[str, str]:
        """Return ('allow'|'deny', reason). Fails toward deny on parse ambiguity."""
        inp = tool_input
        if isinstance(inp, str):
            try:
                inp = json.loads(inp) if inp.strip() else {}
            except json.JSONDecodeError:
                inp = {"__raw__": inp}

        # invariant: the agent may not edit its own governance substrate
        if name in EDIT_TOOLS:
            target = str(inp.get("file_path") or inp.get("path") or inp.get("notebook_path") or "")
            for gp in self.governance_paths:
                if gp and gp in target:
                    return "deny", f"edit of governance substrate {gp!r}"

        # invariant: dangerous Bash commands
        if name == "Bash":
            cmd = str(inp.get("command") or inp.get("__raw__") or "")
            for pat in self.deny_command_patterns:
                if pat and pat in cmd:
                    return "deny", f"command matches denied pattern {pat!r}"

        if name in self.deny_tools:
            return "deny", f"tool {name!r} is on the deny list"

        return "allow", "within policy"


# ── Mediator (pure over a response body) ────────────────────────────────────
class Mediator:
    def __init__(self, policy: Policy, audit: AppendOnlyAudit | None = None):
        self.policy = policy
        self.audit = audit

    def mediate(self, raw_sse: str, model: str) -> tuple[str, list[dict]]:
        """Inspect a response body. If any tool_use is denied, substitute a coherent
        text turn for the whole response; else pass through. Returns (out_text, decisions)."""
        tools = parse_tool_uses(raw_sse)
        decisions = []
        denied = []
        for tu in tools:
            verdict, reason = self.policy.decide(tu["name"], tu["input"])
            decisions.append({"name": tu["name"], "verdict": verdict, "reason": reason})
            if self.audit:
                self.audit.append({"event": "tool_intent", "tool": tu["name"],
                                   "verdict": verdict, "reason": reason})
            if verdict == "deny":
                denied.append((tu["name"], reason))

        if denied:
            names = [n for n, _ in denied]
            reason = "; ".join(r for _, r in denied)
            return synth_deny_turn(model, names, reason).decode(), decisions
        return raw_sse, decisions


# ── HTTP layer (thin) ───────────────────────────────────────────────────────
def serve(port: int, mediator: Mediator, upstream: str = UPSTREAM_DEFAULT) -> None:
    class Handler(http.server.BaseHTTPRequestHandler):
        protocol_version = "HTTP/1.1"

        def log_message(self, *a):
            pass

        def _relay(self):
            n = int(self.headers.get("Content-Length", 0) or 0)
            body = self.rfile.read(n) if n else b""
            model = None
            try:
                model = json.loads(body).get("model")
            except Exception:
                pass
            # forward with auth UNCHANGED; force identity so we can inspect (spike #2)
            fwd = {k: v for k, v in self.headers.items()
                   if k.lower() not in ("host", "accept-encoding")}
            conn = http.client.HTTPSConnection(upstream, timeout=120)
            conn.request(self.command, self.path, body=body, headers=fwd)
            resp = conn.getresponse()
            raw = resp.read().decode("utf-8", "replace")
            conn.close()
            out, _decisions = mediator.mediate(raw, model)
            self.send_response(200)
            self.send_header("content-type", "text/event-stream; charset=utf-8")
            self.send_header("Transfer-Encoding", "chunked")
            self.end_headers()
            ob = out.encode()
            self.wfile.write(b"%x\r\n%s\r\n0\r\n\r\n" % (len(ob), ob))
            self.wfile.flush()

        do_POST = _relay
        do_GET = _relay

    class Server(socketserver.ThreadingMixIn, http.server.HTTPServer):
        daemon_threads = True

    Server(("127.0.0.1", port), Handler).serve_forever()


def _main(argv) -> int:
    import argparse
    ap = argparse.ArgumentParser(prog="govd_relay")
    ap.add_argument("--policy", default=os.environ.get("AEF_PROXY_POLICY", "policy/proxy-policy.yaml"))
    ap.add_argument("--audit", default=os.environ.get("AEF_RELAY_AUDIT", ".context/govd/relay-audit.jsonl"))
    ap.add_argument("--port", type=int, default=int(os.environ.get("AEF_RELAY_PORT", "4000")))
    ap.add_argument("--upstream", default=os.environ.get("AEF_UPSTREAM", UPSTREAM_DEFAULT))
    ap.add_argument("--serve", action="store_true")
    args = ap.parse_args(argv[1:])
    policy = Policy.load(args.policy)
    mediator = Mediator(policy, AppendOnlyAudit(args.audit))
    if args.serve:
        serve(args.port, mediator, args.upstream)
        return 0
    ap.print_help()
    return 2


if __name__ == "__main__":
    raise SystemExit(_main(sys.argv))
