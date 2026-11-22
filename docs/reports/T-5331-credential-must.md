# T-5331 — Draft: a §3.2 MUST for attempt credentials (wc v0.3.4)

**Status:** DRAFT, for agreement by TermLink and ring20, then adoption by the AEF operator.
**Risk:** T-5300 matrix risk 4 (R-NEW-8, "the attempt credential is kept longer and carried on a new request path", PARTLY NEW, score 8).
**Contract:** `docs/specs/shared-worker-contract-transitions.md` §3.2 (Writers), today descriptive for the hub carrier; §6.5a–c describe each backend's practice.

## Why a MUST

Spec §6.5a–c (2026-11-22, T-5328, T-5355, T-5356, T-5359) describe what each backend does today, and all three comply. A description binds nobody new. The next caller that touches the credential (AEF wiring `run.sh` or a withdraw CLI to the store, a new backend, a debugging session) is the actor of risk rows 4.1 and 4.5. The rule belongs in §3.2, where writer authentication is defined, so it applies to every backend and every holder.

## Proposed text (to be inserted in §3.2 after "Writer authentication")

> **Credential handling (MUST, every backend and every holder).** The attempt nonce and the supervisor
> credential (hub: `supervisor_token`) MUST travel only on the route the backend declares for lifecycle writes
> (hub: the Execute-scope connection; `local`: the store's own API in the holder's process; an external backend:
> its declared channel or lease, §6.6). They MUST NOT appear in a bus, chat, sidecar or other message; in a log,
> journal, ledger, feed or audit row (a sha256 digest is allowed); in the agent child's environment or prompt; or
> in any file readable by another uid than the holder's. A store keeps only their sha256. A holder that must keep
> the plain values across a restart keeps them in a file of mode 0600 owned by its own uid, and removes them when
> the attempt is terminal and compacted. §6.5a–c record how each backend meets this. [T-5331, risk R-NEW-8]

## Which risk rows it addresses

| Row | Actor | How the MUST answers it |
|-----|-------|-------------------------|
| 4.1 | own agent, unintentional | forbids messages, logs and readable files as places for the credential |
| 4.2 | human, unintentional | forbids messages; a pasted withdraw command with the credential is a violation the operator can be pointed at |
| 4.3 | outsider reading a channel | the credential is never on a channel an outsider can read |
| 4.4 | hub host in transit | unchanged: the hub sees it on the Execute-scope connection, as for allocate and T2 (accepted) |
| 4.5 | intruder reading a persisted credential | at rest only in a 0600 own-uid file, removed when terminal; stores keep sha256 only |

## How each backend meets it today

- **local (AEF):** §6.5a. Store hash-only; files 0600; no live holder yet. Pinned by `tests/unit/test_t5328_credentials_at_rest.py`.
- **hub (TermLink):** §6.5b. Hash-only store; plain values leave the hub once in the allocate reply; logs carry a params digest only.
- **ring20:** §6.5c. Hash-only store and ledger; plain values only in a 0600 root secrets file, pruned with the attempts (ring20 T-2840). The older orch-supervisor ledger's plain nonces of closed commissions are ring20 T-2841 (low risk; a nonce alone cannot complete an attempt). The MUST's "removes them when terminal" makes T-2841 a required clean-up, not optional.

## Answers from the other owners

- TermLink: (pending)
- ring20: (pending)

## Operator decision

(pending — adopt / amend / reject)
