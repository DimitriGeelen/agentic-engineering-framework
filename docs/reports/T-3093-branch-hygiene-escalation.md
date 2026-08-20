# T-3093 — How should unread branch-hygiene findings escalate?

**Status:** inception (exploration) — Recommendation: pending
**Opened:** 2026-08-20
**Trigger:** operator, on being shown 15 stranded branches — *"this seems to be a mess. pollution."*
The rail had been reporting that mess the whole time.

## Problem

Detection works. Nothing consumes it. See the task's Problem Statement for the
measured shape; this artifact carries the exploration.

## Findings

### F1 (IW-1) — Nobody sees them. The finding has never been on an automatic surface.

Measured, not inferred:

| Surface | Runs when | Consumes `fw_branch_hygiene`? |
|---|---|---|
| `fw doctor` | only when a human types it — **0 cron lines** | **yes — the sole consumer** (`bin/fw:3221`) |
| `fw audit` | cron: every 30m, hourly, 6h, daily, weekly | **no** — all 5 textual matches in `audit.sh` are comments that *mirror doctor's logic for other checks* |
| `fw handover` | every session end | **no** — uses `fw_branch_divergence`, which reports only the **current** branch |

So the one rail that can see a strand runs only on demand, and the two rails that
run automatically cannot see one. This is not "the WARN was ignored" — it is
"the WARN was never delivered".

Dates make it sharper. The rail shipped **2026-07-04**. The oldest strand forked
**2026-03-01**. The strands predate the detector by four months, and in the six
weeks the detector has existed it has had no automatic surface at all.

**IW-1 is answered, and it reframes IW-2.** The question is not "how do we make
people act on a WARN they are ignoring" — it is "put the finding somewhere that
runs without being asked". Those need very different mechanisms, and the second is
much cheaper.

### F2 (IW-2) — There is already a precedent for exactly this promotion.

`agents/audit/audit.sh:1827` and `:1858` carry the comments *"Mirrors `bin/fw
doctor` cron-drift logic"* — the cron registry→generated→deployed drift check was
first a doctor check, then duplicated into audit so the cron rail would catch it
(T-1771, T-1942, T-1943). That is the same shape as this problem, already solved
once in this codebase, with the reasoning recorded in CLAUDE.md.

The precedent also carries a warning: it was solved by **duplicating** the logic
into audit rather than sharing it, and CLAUDE.md now documents three separate
drift classes that each needed their own gate. A promotion here should call
`fw_branch_hygiene` directly rather than reimplement it.

## Dialogue Log

<!-- questions posed, course corrections, why the reasoning moved -->
