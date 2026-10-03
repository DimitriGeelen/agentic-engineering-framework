# T-3751 — external review synthesis: function + instance labels, respawn-by-function fallback

Brief: `docs/reports/T-3751-review-brief.md`. Seven independent reviewers from seven
vendors, none of them the brief's author (Anthropic):

| # | Seat | Vendor / model | Class | Report |
|---|---|---|---|---|
| 1 | codex | OpenAI | internal | `T-3751-review-openai.md` |
| 2 | opencode | Z.ai GLM-5.2 | internal | `T-3751-review-zai.md` |
| 3 | antigravity | Google | internal | `T-3751-review-google.md` |
| 4 | OpenRouter | DeepSeek v4-pro | paid | `T-3751-review-deepseek.md` |
| 5 | OpenRouter | Mistral medium-3.5 | paid | `T-3751-review-mistralai.md` |
| 6 | OpenRouter | xAI grok-4.7 (re-run) | paid | `T-3751-review-x-ai.md` |
| 7 | OpenRouter | Qwen 3.8-max (re-run) | paid | `T-3751-review-qwen.md` |

Paid spend: 0.35 USD over six calls (two first calls were unusable — an agentic
preamble and a reasoning-only reply — and were re-run on new approvals).

**Verdict: 7/7 ADOPT-WITH-CHANGES.** Nobody rejects the model; nobody adopts it as
proposed.

## 1. Per level — where they agree

| Level | Consensus | Count | Dissent |
|---|---|---|---|
| Host | FQDN is the identity; the **IP is never in the address** (resolution state, DNS/TTL) | 7/7 | DeepSeek keeps IP as an instance label in metadata |
| Hub | needs a stable name **and** an instance id; the instance id must not be the routing key | 5/7 | Google, xAI: merge to one label until multi-hub is a real decision (D6) |
| Project | `pid-…` is the **only routing identity** | 7/7 | — |
| Project | a "project instance" is a **workspace/checkout disambiguator in metadata / claims**, not a routable, respawnable actor; the project stays passive (D2) | 6/7 | Mistral keeps both labels routable |
| Session | **no function label for routing**; keep the session instance id; a readable name is display/metadata | 6/7 | Mistral: a routable session name (`worker-<n>`) |
| Agent | **both labels**: function (`@research`) + instance id | 7/7 | — |
| Agent | vendor/model/capability is **metadata, never in the address** (Portability) | 6/7 | DeepSeek: metadata, but required for respawn authorization |

New facts the reviewers and 010 added:
- **Hub id is an instance id today.** Our durable inbox topic `inbox:<hub>/<project>`
  uses the hub's TLS fingerprint (`cacc73ea32b121dd`), which changes on certificate
  rotation (010 PL-021, Z.ai Q1). Every durable topic name would change with it.
- **Two checkouts share one pid** (operator ruling: instances share the id). The
  disambiguator is needed for claims and exactly-once, not for addressing (OpenAI,
  Z.ai, Google, xAI, Qwen).

## 2. Respawn — where they agree

Unanimous (7/7): **an inbound message must not start an agent by default.**
- T-3287 **D5 does not cover it.** D5 pre-authorizes a project healing itself; a peer's
  message causing the recipient operator's spend is a new grant of authority and needs
  an explicit operator ruling (Z.ai, Google, OpenAI, xAI — called out as the agent's
  error in the brief).
- Guardrails named by most: per-project policy, default off; budget; Erlang/OTP-style
  restart intensity (N per T, then stop and page); respawn only on the project's home
  host; only from an authenticated sender (blocked today by the shared TermLink
  signing identity, §3.5 — a hard dependency); one recovery claim per logical
  recipient with a fencing token so a half-dead old instance cannot keep writing.
- **A new session is not a working equivalent** without a verified recovery checkpoint
  (task, repo revision, uncommitted changes, pending external effects). The
  conversation thread alone is not enough (DeepSeek: blocks adoption of respawn until
  solved; Google: "respawned context-blindness"; OpenAI: "replacement started reported
  as recipient recovered").

## 3. Fallback and receipts — where they agree

- The message **waits in one durable place, the project inbox**, and never "delivers"
  at a lower rung; "where it waits" is separate from "who is started to read it" (Z.ai,
  Google, OpenAI). `climb()` was built for ladder repair (D1), not delivery.
- **Never cross the project boundary** (7/7; 010 agrees).
- Every message states its policy: `exact-instance` vs `allow-replacement` (OpenAI,
  DeepSeek — "identity is not delivery policy").
- Receipts name the message, the instance that took it, the evidence and the
  uncertainty; `HUB_ACCEPTED` must be renamed so it cannot read as "delivered"
  (Z.ai, Google). Ack matching keys on (function, client_msg_id), never the instance
  id — otherwise a respawned instance's reply never lands as REPLIED (Z.ai).
- Leases with TTL on instances/claims, the hub as single arbiter (Z.ai, OpenAI):
  fixes the 22-hour orphan class (§3.8).

## 4. What the reviewers say the model does NOT fix

All seven: the §3 incidents were mostly **receipt semantics and stale liveness, not
missing labels.** Those were fixed separately on 2026-10-03 (T-3684/T-3685/T-3745,
independent PASS; idle pickup 1.43 s, hub-path RECEIVED at the sender 14.90 s).
Still open from §3: shared signing identity (TermLink's fix), cross-version receipts
(T-3769), migration dual-read (IW-2).

## 5. Prior art (most cited)

Erlang/OTP registered name vs pid + supervision restart intensity (copy); Orleans
virtual actors — stable identity, runtime activation (copy the split, not the
automatic activation: an LLM session costs dollars, not microseconds); SIP
address-of-record vs contact (copy the grammar shape); XMPP `node@domain/resource`;
DNS/SRV with TTL (copy leases, avoid stale caches); email backup MX (avoid
"accepted ≠ delivered" — §3.1 verbatim).

## 6. Where the reviewers disagree with each other

1. Hub: two labels now (5) vs one label until multi-hub is decided (2). 010's operator
   says several hubs per host are expected, and the current hub id rotates — both
   favour two labels now.
2. Project instance: metadata/claim token (Z.ai, xAI, Qwen) vs workspace id that must
   survive restart and differ per clone (OpenAI) vs discriminator at hub registration
   (Google). Compatible: one workspace id, minted per checkout, used in claims.
3. Vendor/model: metadata only (6) vs required for respawn authorization (DeepSeek).
   Compatible if respawn reads it from an approved role specification.

## 7. Implications for decision 2a (agent's reading, for the operator)

The operator's two-label model survives review at the agent level (unanimous) and as a
**naming principle** everywhere; what changes is which label ROUTES:
- routes: host FQDN, hub NAME (new — the fingerprint becomes the hub instance id),
  `pid`, `@agent` function, plus session instance id and agent instance id only when a
  message pins an exact instance;
- metadata: IP, hub fingerprint, workspace/checkout id, vendor/model, lease expiry;
- display: readable project name, session name, folder name.
Respawn (decision 2b) is a separate grant the operator must make explicitly, with the
guardrails in §2.
