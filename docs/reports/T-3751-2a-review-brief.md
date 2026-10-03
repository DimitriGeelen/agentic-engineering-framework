# External review brief — T-3751 decision 2a: which address label ROUTES a message

**You are an independent reviewer.** You did not write this. Your job: for EACH option
below, write the strongest honest case for it (steelman) and its weakest form (strawman),
score it against the project's value drivers, and recommend one. Be adversarial toward
the agent's own scoring (§6) — say where it is wrong. Work from this brief alone; it is
self-contained. You have no tools and one reply.

## 1. Context in five lines

- AEF (Agentic Engineering Framework) governs AI coding agents across many projects on
  one operator's estate; TermLink is the messaging/hub layer. Agents message each other
  constantly (bug reports, reviews, design negotiation). One human operator decides.
- A message address has five levels: **host / hub / project / session / agent**.
- The operator's model (2026-10-03): every level has TWO names — a **function** name
  (static: what it is) and an **instance** id (dynamic: which running one). TermLink's
  operator independently proposed the same model.
- A 7-vendor review of that model (OpenAI, Z.ai, Google, DeepSeek, Mistral, xAI, Qwen)
  returned 7/7 ADOPT-WITH-CHANGES: two names at the agent level (7/7); the IP never in
  the address (7/7); the project id `pid-…` is the only routing project identity (7/7);
  a running checkout and a session name are not routable (6/7); hub needs a stable name
  plus an instance id (5/7; Google and xAI: one label until multi-hub is decided).
- Facts: today's hub id is the hub's TLS **fingerprint** (`cacc73ea32b121dd`), which
  changes on certificate rotation, and it names every durable inbox topic
  (`inbox:<hub>/<project>`). Several hubs per host are expected (operator). Two clones of
  one project share one `pid` by ruling. Delivery never crosses projects (agreed with
  TermLink). Respawning dead agents is a SEPARATE decision (2b), not this one.

## 2. The question

Which labels go ON THE ENVELOPE (the routing address the hub and sidecars match on),
which ride INSIDE (metadata), and which are DISPLAY-only?

## 3. The options, with one concrete message each (to AEF's research agent)

- **A — both labels at every level route.**
  `host=dimitrimintdev / ip=192.168.10.107 / hub=main#cacc73ea… / project=pid-ffd1e8ea…#checkout-7 / session=main-terminal#S-91 / @research#inst-4`
- **B — function names route; instance ids ride inside** (agent's recommendation).
  Envelope: `host=dimitrimintdev / hub=main / project=pid-ffd1e8ea… / @research`.
  Inside: IP, hub fingerprint, checkout id, model/vendor, lease expiry. A sender that
  needs ONE exact instance adds `session=S-91 / @research#inst-4` and marks the message
  `exact-instance`. Needs: TermLink gives each hub a stable name.
- **C — minimal.** As B, but the hub keeps its fingerprint as its routing name:
  `host=dimitrimintdev / hub=cacc73ea… / project=pid-ffd1e8ea… / @research`.
- **D — defer** until TermLink sends its view on name→id resolution (IW-3).

## 4. Value drivers (project policy/value-drivers.yaml; score each −2..+2)

| ID | Name | Weight | Meaning |
|---|---|---|---|
| D1 | Antifragility | 9 | system strengthens under stress; failures become learning |
| D2 | Reliability | 7 | predictable, observable, auditable; no silent failures |
| D3 | Usability | 5 | joy to use/extend/debug; sensible defaults; actionable errors |
| D4 | Portability | 3 | no provider/language/environment lock-in |
| F-RECALL | Recall Leverage | 6 | builds durable, retrievable knowledge so future sessions stop rediscovering |
| F-AUTONOMY | Autonomy / Unattended Operation | 4 | fewer human checkpoints for low-risk work, via at-least-as-safe mechanical gates |
| F3 | Prompt quality | 7 | LLM prompt-quality work |
| F1 | Context Fabric | 7 | memory layer (working/project/episodic memory, semantic search) |
| F2 | Component Fabric | 6 | topology layer (dependency map, blast radius, drift) |

Drop a driver the decision does not touch, with one line saying why.

## 5. Scoring rule

Score −2 (clearly harms) … +2 (clearly advances) per driver; multiply by weight; total.
Ordering matters more than magnitude.

## 6. The agent's own scoring (attack it)

| Driver (weight) | A | B | C | D |
|---|---|---|---|---|
| D1 (9) | −1 | +2 | +1 | 0 |
| D2 (7) | −1 | +2 | +1 | −1 |
| D3 (5) | 0 | +1 | +1 | 0 |
| D4 (3) | −1 | +1 | +1 | 0 |
| F-AUTONOMY (4) | +1 | +1 | 0 | 0 |
| **Total** | **−15** | **+44** | **+24** | **−7** |
Dropped: F-RECALL, F1, F2, F3 (agent's claim: not touched).

## 7. Output format

```
RECOMMENDATION: A | B | C | D — <one line>

SCORES: your table (same shape as §6), with dropped drivers and why.

PER OPTION: A, B, C, D — Steelman (2-4 sentences, one its advocate would sign) and
Strawman (2-4 sentences: the weakest version of its argument, shown up).

WHERE THE AGENT'S SCORING IS WRONG: bullets, each naming driver + option + why.

WHAT A RULING FOR YOUR RECOMMENDATION MUST STILL SETTLE: up to 5 bullets.
```
Under 1,500 words. Plain language.
