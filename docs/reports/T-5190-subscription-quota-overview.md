# T-5190 — Subscription quota overview across projects

**Task:** T-5190 (inception) · **Trigger:** 1409-sprind proposal (msg 97b0c79a, 2026-11-16) · **Status:** exploring

## Question

Several projects and the ring20 pool share the operator's subscriptions, and none of them sees the others' use. What,
if anything, should AEF record or provide so that a shared limit can be seen coming and planned around? It must never
handle account identifiers.

## Evidence received (1409 T-6158 report, commit d9c4512d7 in their repo, sent as text 2026-11-17, msg 2b9fb717)

Limit messages each harness actually emitted, last 14 days (neutral subscription names; host names omitted here):

| # | Subscription | When (UTC) | Count | Wording | Reset given |
|---|---|---|---|---|---|
| 1 | glm | 12.11 22:36 – 13.11 10:41 | 4 | "Insufficient balance or no resource package. Please recharge." | none (balance) |
| 2 | claude-pool | 14.11 01:37 – 01:49 | 12 | "You've hit your weekly limit · resets 5am (UTC)" | 14.11 05:00 |
| 3 | glm | 16.11 01:51 – 07:44 | 11 | "Rate limit reached for requests" (HTTP 429) | none (short) |
| 4 | glm | 16.11 02:56 – 06:00 | 32 | "Usage limit reached for 5 hour. Your limit will reset at 2026-11-16 14:12:01" | 16.11 06:12 UTC (read as UTC+8; the message carries no zone) |
| 5 | glm | 16.11 07:45 – 10:21 | 19 | "… will reset at 2026-11-16 20:32:37" | 16.11 12:32 UTC (same assumption) |
| 6 | claude-pool | 16.11 14:22 – 14:32 | 85 | "You've hit your weekly limit · resets Nov 21, 5am (UTC)" | 21.11 05:00 |
| 7 | OpenRouter (Mistral) | 11.10, 13.10 | 3 | "HTTP Error 429: Too Many Requests" | none |

codex, Antigravity and mistral-vibe emitted no limit message in 14 days.

Since 2026-11-17, ring20 records the account (2 or 3) per job and holds jobs at the limit instead of failing them.

### 1409's needs, as stated (needs, not solutions)

**Per job, in the project (their 3.1):**
- a neutral subscription id (`claude-a/b/c`, `glm`, `codex`, `antigravity`, `mistral-vibe`), never an e-mail, token or account id;
- place and node;
- the window state at completion, when the provider reports one;
- tokens for consultation seats too (today `null`), or at least a request count;
- the estimated tokens before a round and the actual afterwards;
- worker token rows kept for at least 14 days (today they vanish from /tmp after about 4).

**From ring20 (their 3.2):**
- a node → subscription map;
- per-subscription state from poold's quota lock (at limit, reset time, last message);
- who else uses the same subscription;
- an `abo` field in `ring20.pool.result/1`.

**From AEF (their 3.3), because subscriptions are shared across projects:**
1. A cross-project quota log per machine or per subscription: who put how much on which subscription, and when.
2. One shared signal any project can ask before a large round, in the same words: "free / tight / at limit until".
3. The same rule for TermLink workers: `fw termlink dispatch` writes the subscription id into `meta.json`.

## Findings

(filled in as explored)

## Dialogue Log

- 2026-11-17: the operator chose option (a): ask 1409 for the report sections as text, since this session cannot read other
  projects' files. 1409 sent them the same morning.
