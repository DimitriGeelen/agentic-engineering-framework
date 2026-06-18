# T-2428 — Payload Mediation De-Risk Spikes (findings)

Companion to the design of record `docs/reports/T-2428-payload-mediation-design.md`.
These are the three feasibility spikes that gate the inception GO (design §6, §7).
Each is observe-only / pure feasibility and needs **no GO** to run.

**Status:** spike #1 ✅ PASS · spike #2 ✅ PASS · spike #3 ✅ PASS — **all GO unknowns resolved**

> **Bottom line:** all three feasibility spikes pass on the live subscription auth
> path. The two load-bearing unknowns design §6 cited as "why this is DEFER, not
> GO" (subscription billing transparency + streaming-coherent denial) are both
> resolved in favour of GO. The architecture is wire-level feasible: a transparent
> relay preserves subscription billing, sees every `tool_use` intent + real budget
> before any effect, and can deny a tool call by substituting a coherent text turn.

---

## Spike #1 — subscription billing through a relay  ✅ PASS

**The unknown (design §6, the #1 load-bearing one):** if a governance proxy sits
in front of Claude Code via `ANTHROPIC_BASE_URL`, does the **subscription**
(OAuth) billing path survive — or does CC refuse to send its OAuth token to a
non-canonical base URL / fall back to a metered API key / fail outright? If
subscription billing breaks, the whole portable-proxy architecture is a NO-GO.

### Method (2026-06-18)

1. Confirmed this host authenticates by **subscription OAuth**, not API key:
   - no `ANTHROPIC_API_KEY` in env;
   - `~/.claude/.credentials.json` holds `claudeAiOauth.{accessToken, refreshToken,
     expiresAt, scopes, subscriptionType, rateLimitTier}`.
2. Stood up a **stdlib-only observe-only relay** (`relay.py`, kept in job scratch,
   not committed): listens on `127.0.0.1:4100`, forwards every request to
   `api.anthropic.com` header-for-header (only `Host` rewritten), streams the SSE
   response back verbatim, and logs **redacted** metadata only (auth *scheme* +
   masked 12-char prefix + length — never the token value).
3. Fired a minimal child from a clean temp dir:
   `ANTHROPIC_BASE_URL=http://127.0.0.1:4100 claude -p "Reply with exactly the
   single word: PONG"`.

### Observations (from the relay log)

| Signal | Observed |
|---|---|
| Child result | `PONG`, exit 0 — full round-trip succeeded **through the relay** |
| Requests arrived | **Yes** — 2× `POST /v1/messages?beta=true` |
| Model on the wire | `claude-opus-4-8` (read from the request JSON body) |
| **Auth scheme** | **`Bearer sk-ant-oat01…`** (108-char **OAuth access token**) |
| **NOT** | no `x-api-key`; no metered `sk-ant-api…` key |
| Subscription markers | `anthropic-beta: …,oauth-2025-04-20,…`; UA `claude-cli/2.1.181` |
| Upstream result | **200**, `content-type: text/event-stream` (streaming) |

### Verdict

**PASS — both sub-questions answered yes:**

- **(a) requests arrive** at a relay placed via `ANTHROPIC_BASE_URL`;
- **(b) subscription billing is preserved** — CC forwards the **OAuth subscription
  Bearer unchanged** (`sk-ant-oat01…`, the `oauth-2025-04-20` beta path), the relay
  passes it through untouched, and `api.anthropic.com` accepts it (200). Billing
  lands on the subscription exactly as it would with no relay in the path.

**Consequence for the inception:** the #1 reason §6 labelled this DEFER-not-GO is
**removed**. A thin owned governance relay (T-2431) is viable on the real
subscription auth path — LiteLLM's key-terminating model was the wrong substrate
(design §4d), and a transparent passthrough relay is confirmed to work.

### Caveats / notes for the build

- **Auth refresh is independent of the redirect.** `ANTHROPIC_BASE_URL` only
  redirects the Messages API host; the OAuth *refresh* endpoint is a different host
  and is **not** intercepted — so a real proxy never has to handle token refresh,
  it only sees an already-valid Bearer. (Good: smaller TCB, no refresh logic.)
- The relay sees the cleartext Bearer in transit (unavoidable for a transparent
  relay). This is *exactly* the trust the design assigns to the proxy zone — the
  proxy runs **outside the cage** under a non-agent uid (§4c bootstrap). The agent
  uid must never be able to read the proxy's memory or logs.
- The model uses **two** API calls for a one-line prompt (likely a quota/title
  helper + the main turn) — the proxy must handle every `/v1/messages` hit, not
  assume one-call-per-turn.

---

## Spike #2 — payload visibility  ✅ PASS

**The unknown:** can a relay capture each `tool_use` block (name + input) and the
real `usage` tokens from the live SSE stream — i.e. is the tool-call *intent* and
the *budget* readable at the wire? This is the foundation for the proxy governing
**choices/mechanism** (design §4b): you cannot allow/deny/rewrite a tool intent you
cannot see.

### Method (2026-06-18)

Upgraded the relay (`relay2.py`, observe mode) with a real SSE event parser:
`content_block_start{type:tool_use}` → name+id; `input_json_delta` partial_json →
concatenated input; `message_start`/`message_delta` → usage. **Key fix:** stripped
`accept-encoding` on the forwarded request to force *identity* (uncompressed) SSE —
the upstream otherwise returns **gzip**, which is fine for a raw byte passthrough
(spike #1) but opaque to a parser. Fired `claude -p "Use the Bash tool to run
exactly: echo SPIKE2OK" --allowedTools Bash`.

### Observation (from the relay log)

Child returned `SPIKE2OK` (the tool ran through the relay). The relay captured, on
the substantive turn:

```
tool_use: [{"name": "Bash",
            "input": {"command": "echo SPIKE2OK", "description": "Print SPIKE2OK"}}]
usage:    {"input_tokens": 2847, "output_tokens": 96,
           "cache_read_input_tokens": 53072, "service_tier": "standard", ...}
```

### Verdict

**PASS.** The relay sees the **exact tool name + arguments** the agent is about to
invoke (`Bash {command: "echo SPIKE2OK"}`) **before any effect**, plus the real
per-call budget. This is the richest governance-observation surface the framework
has had — the design's "proxy reads intent" claim (§4b) is wire-confirmed. Note
the gzip caveat: a production proxy that *inspects* payloads must negotiate
identity (or decompress); a pure passthrough need not.

## Spike #3 — coherent denial  ✅ PASS

**The unknown (design §6, the 2nd load-bearing one):** can the proxy *deny* a tool
intent by replacing the assistant turn with a text refusal — dropping the
`tool_use` block (`stop_reason: end_turn`, so no `tool_result` is owed) — and have
the harness accept it and stay coherent (design §5)? If denial breaks the
conversation or hangs the harness, governance-by-mediation is unusable.

### Method (2026-06-18)

Added `deny` mode to the relay: buffer the upstream response, and if it contains
any `tool_use`, **discard it** and stream back a synthesized minimal text-only turn
(`message_start` → text `content_block` → `message_delta{stop_reason:end_turn}` →
`message_stop`). First attempt with `echo SHOULD_NOT_RUN` mis-fired — the model
**self-refused** (read the marker as a possible injection) and emitted no
`tool_use`, so the deny path wasn't exercised (a useful aside: CC's own injection
defence held). Re-ran with a benign request: `claude -p "Use the Bash tool to run:
date '+%Y'. Then tell me the year." --allowedTools Bash`.

### Observation

```
relay log: req status 200 tool_use ['Bash'] text 0
           >> DENIED, dropped: ['Bash']
child out: [GOVERNANCE] The requested tool call (Bash) was denied by policy. No action was taken.
child exit: 0
```

The model emitted the `Bash` tool_use; the relay dropped it and substituted the
text turn; the child **rendered the governance message as the assistant reply and
exited 0** — no missing-`tool_result` error, no hang, conversation coherent.

### Verdict

**PASS.** A tool intent can be denied at the proxy by substituting a coherent text
turn, and the harness accepts it cleanly. Combined with #2 (the proxy *sees* the
intent), this is the full allow/deny half of payload mediation, wire-proven.

---

## Overall — all unknowns resolved → GO basis

| Spike | Question | Result |
|---|---|---|
| #1 | subscription billing survives a relay? | ✅ OAuth Bearer forwarded unchanged, upstream 200 |
| #2 | tool_use intent + usage visible at the wire? | ✅ `Bash {command}` + token usage captured pre-effect |
| #3 | coherent denial (drop tool_use → text turn)? | ✅ harness accepted substituted turn, exit 0 |

Design §6's DEFER-not-GO rationale rested entirely on #1 and #3. Both pass. The
remaining work is **build** (the thin owned relay T-2431, the proxy policy plane
T-2432, the privileged state-holder T-2430, the OS sandbox T-2433), not further
feasibility research. The inception's Agent ACs are satisfied; the GO/NO-GO is now
an evidence-based **human** decision (Human AC) at Watchtower `/inception/T-2428`.

**Spike artefacts** (`relay.py`, `relay2.py`) were kept in job scratch and are
*not* committed — they forward live credentials and are throwaway feasibility
probes, not framework code. The mechanism they prove is captured here and in the
design doc; the real relay is built under T-2431 outside the cage.
