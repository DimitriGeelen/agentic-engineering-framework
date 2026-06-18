# T-2428 — Payload Mediation De-Risk Spikes (findings)

Companion to the design of record `docs/reports/T-2428-payload-mediation-design.md`.
These are the three feasibility spikes that gate the inception GO (design §6, §7).
Each is observe-only / pure feasibility and needs **no GO** to run.

**Status:** spike #1 ✅ PASS · spike #2 ⏳ pending · spike #3 ⏳ pending

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

## Spike #2 — payload visibility  ⏳ pending

Goal: the relay logs each `tool_use` block (name + input) and
`usage.{input,output}_tokens` from the live SSE stream — proving tool-call intent +
real budget are capturable at the wire.

Partial signal already from #1: the **request** body is plainly readable (model
name extracted), so outbound `tool_use` intent is visible. The **response**-side
`usage` extraction in the #1 relay did not surface a USAGE line — needs a proper
SSE event parser (`message_start` / `message_delta` carry `usage`). To run next.

## Spike #3 — coherent denial  ⏳ pending

Goal: demonstrate one rewritten response (drop a `tool_use`, substitute a text
turn, `stop_reason: end_turn`, no owed `tool_result`) that the harness accepts
without breaking the conversation (design §5).
