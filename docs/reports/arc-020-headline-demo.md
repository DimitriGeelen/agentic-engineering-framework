# arc-020 headline mechanic — combined demo evidence (G1 + G3)

**Arc:** arc-020 — *Cross-agent identity & self-healing circuits*
**Anchor:** T-3287 · **Charter:** `docs/reports/T-3287-identity-taxonomy-circuit-model.md`
**Status when written:** in-progress · **This document:** a candidate single
`--demo` artifact for `fw arc close`, consolidating both clauses of the headline
mechanic.

> **Note on authority (§ACD).** This report is an *advisory* consolidation an
> agent assembled from two live, green demos. It is **not** an arc close and does
> not set `demo_evidence:`. The close decision — whether these demos show the
> headline mechanic firing — remains the operator's, via
> `{watchtower}/arcs/arc-020/close` (§ACD-gated). The value here is that the
> operator can pass one path (`docs/reports/arc-020-headline-demo.md`) as
> `--demo` and have it cover the whole headline sentence, not half of it.

## The headline mechanic (verbatim, from arc-020.yaml)

> A worker addresses a peer agent by its durable name; **distinct co-resident
> agents stay distinct correspondents** on the operator's TermLink thread instead
> of collapsing into one fingerprint, **and a dropped circuit self-heals** — the
> peer's message still lands after the framework re-provisions an equivalent
> instance under the same durable name.

It bundles **two** clauses, and an arc whose headline bundles mechanics does not
close until each is demonstrated (the continuous-run precedent: that arc stayed
OPEN because "the headline sentence bundles M1+M2 and only M2 ships"). The two
clauses map to two legs, each demonstrated below against a **live termlink hub**.

| Clause | Leg | Task | Demo | Wire evidence |
|--------|-----|------|------|---------------|
| distinct correspondents (kills the collapse) | G1 | T-3340 | `tests/manual/arc020_g1_demo.py` | `docs/reports/T-3340-g1-demo-evidence.md` |
| dropped circuit self-heals | G3 | T-3341 | `tests/manual/arc020_g3_demo.py` | `docs/reports/T-3341-g3-demo-evidence.md` |

## The bug this arc kills (G-105 / T-3286)

termlink has no `agent_id`, so the identity reader falls back to a shared crypto
`identity_fingerprint`. On the origin host that fingerprint is shared across
co-resident sessions, so "who is this" has **one** answer for **many** agents —
distinct agents collapse into one correspondent. The G1 demo reads this collapse
live: on the hub at capture time, **177 of 179** fingerprint-carrying sessions
shared the single fingerprint `d1993c2c3ec44c94` — corroborated independently by
the G3 run, whose spawned sessions carried the *same* fingerprint. The AEF fix is
the **durable name**: a V9 address without a `session=` token is the
correspondent, and two distinct names stay distinct regardless of the fingerprint
collision.

## Leg G1 — distinct co-resident correspondents (T-3340)

`tests/manual/arc020_g1_demo.py`, live hub, `RESULT: PASS ✓`:

1. Reads the live fingerprint collapse (177/179 → one correspondent).
2. Builds two co-resident durable names — `@alpha` and `@beta`, same
   `host+hub+project`, which therefore share the crypto fingerprint — and shows
   `serialize()` distinguishes them where the fingerprint cannot.
3. On the **live** claim substrate (T-3335 `TermlinkChannelClaimBackend` +
   `elect`), each name derives a **distinct** sha256 election topic and elects its
   **own** coordinate — two distinct correspondents on the live hub while their
   crypto fingerprint is identical.

Full wire trace: `docs/reports/T-3340-g1-demo-evidence.md`.

## Leg G3 — a dropped circuit self-heals (T-3341)

`tests/manual/arc020_g3_demo.py`, live hub, `RESULT: PASS ✓` (twice
consecutively, re-runnable, zero leftover sessions):

1. **Bind** — spawn circuit-1 (a real session), bind the durable name `@healer`
   to it; a test message lands on circuit-1.
2. **Drop** — kill circuit-1's listener and evict its registration; the live
   T-3338 probe (`termlink_probe`) reports it **definitively absent** — the hub
   answered "not found", not "unreachable" (the D4-A distinction: a `False` means
   *heal*, a raise would mean *retry*).
3. **Elect** — two candidates race the durable name via the T-3335 live claim;
   **exactly one** wins (healer-A WON, healer-B LOST), the loser backs off.
4. **Heal** — the winner drives `aef_resolve.provision()` over the durable name;
   resolve locates the deepest live ancestor (the project — the agent rung has no
   live circuit), and the session provisioner materializes **circuit-2** with a
   **fresh** id (`tl-rbsylu45` → `tl-ydi5rzcm`, distinct — D1: a recovered
   endpoint is a NEW instance, never a resurrection).
5. **Land** — a message addressed to the durable name, now bound to circuit-2,
   **lands** on the healed circuit.

Full wire trace: `docs/reports/T-3341-g3-demo-evidence.md`.

The whole flow runs on shipped substrate — `aef_address` (S1),
`aef_resolve.provision` + `termlink_probe` (S3/S8/T-3338), `aef_election` live
claim backend (S8/T-3335) — plus `termlink spawn/interact/signal` for the real
circuits. No new stub, no `NotImplementedError`.

## Reproduce (both legs)

```
cd /opt/999-Agentic-Engineering-Framework && termlink hub status --json   # else: termlink hub start
cd /opt/999-Agentic-Engineering-Framework && python3 tests/manual/arc020_g1_demo.py
cd /opt/999-Agentic-Engineering-Framework && python3 tests/manual/arc020_g3_demo.py
```

Each prints its sections and rewrites its evidence file; both exit 0 on success.
Deterministic (hub-free) backstop for the underlying substrate:
`python3 -m pytest tests/unit/test_aef_resolve_termlink.py -q` (16/16).

## What remains (not blocking these two legs)

- **Operator review** of both demo tasks: `{watchtower}/review/T-3340`,
  `{watchtower}/review/T-3341` (each re-runs a green live demo).
- **Cross-host self-heal** (project *path* absent → fleet-source `aef_repo_source`)
  is a separate, shelved leg (T-3339) — not part of the same-host headline
  demonstrated here.
- **Arc close** is the operator's §ACD decision at `{watchtower}/arcs/arc-020/close`.
