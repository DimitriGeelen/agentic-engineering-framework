# T-2184 — OBS-048 → G-064 closure-readiness operator handoff

**Date:** 2026-06-02
**Predecessor:** OBS-048 (captured 2026-06-01T22:34:22Z, context_task T-2158)
**Decision class:** gap closure (sovereignty-bearing, operator-only)
**Class-correct URL:** http://192.168.10.107:3000/gaps

## What changed since OBS-048 was captured

OBS-048 reported **11 cron-firing dates ≥3 threshold**. A fresh run of `tools/g064-readiness.py` (this task, 2026-06-02) reports **12 cron-firing dates** — today's 05:33 LOCAL cron firing added 2026-06-02 to the set. The mechanical gauge VERDICT is still **READY**; the threshold gap has only widened.

```
$ python3 tools/g064-readiness.py
G-064 closure-readiness gauge
================================
Workflow:           escalation-triage
Cron schedule:      05:33 LOCAL +/- 5 min
Closure threshold:  >= 3 distinct cron-firing dates

Total dispatches:   461
  Cron firings:     270 across 12 date(s)
  Manual runs:      191 across 1 date(s)

v0.5 LATEST:        2026-06-02T03:33:11.517048+00:00
  dispatched=1 skipped_idempotent=22

Cron-firing dates: 2026-05-14, 2026-05-15, 2026-05-18, 2026-05-21, 2026-05-22,
                   2026-05-23, 2026-05-25, 2026-05-26, 2026-05-29, 2026-05-31,
                   2026-06-01, 2026-06-02
Manual-run dates:  2026-05-05

VERDICT: READY -- 12 cron-firing dates meets threshold (3).
Action: human can close G-064 via Watchtower
        (gap is satisfied; autonomous workload is exercising the substrate).
```

## G-064 in one line

The orchestrator-rethink arc (T-1641 anchor) shipped substrate but the `headline_mechanic` was only ever proven by **synthetic verification dispatches**. G-064 was opened to watch for a non-synthetic consumer.

## Why the gauge fires now

Non-synthetic consumer **exists and is autonomous**:
- 461 total dispatches captured in `.context/dispatches.jsonl`
- 270 of them are `cron`-driven (not manual verification)
- 12 distinct calendar dates covered (well past the 3-date threshold)
- Workflow: `escalation-triage` running daily at 05:33 LOCAL
- Worker kind: `ollama-loop` (463 dispatches), model `claude-3-5-sonnet-hermes3` — the litellm proxy substrate that T-1700 shipped IS in autonomous production use, just not under the T-1700 task_id

## Cascade — what closure unlocks

Per [[project_value_drivers_v3_landed]] and `policy/value-drivers.yaml` v3:

- **T-2169** (retire_when advisory) — its F-ORCH retirement heuristic explicitly keys on `G-064 closed`. When G-064 flips to closed, the audit/doctor advisory will WARN the operator that F-ORCH free-driver in `policy/value-drivers.yaml` may be retired (it was added when the substrate was unproven; the substrate is now demonstrably autonomous).
- **OBS-048** can be `fw note dismiss`'d once G-064 closes — the recommendation has been actioned.

## Evidence checklist (mechanical, pre-verified)

- [x] Gauge VERDICT=READY (rerun above, 12 firings ≥3)
- [x] Status_notes on G-064 already specify the gauge as the closure mechanism (mechanical threshold, not human-judgment)
- [x] Cron registry confirms `escalation-triage` is registered and `Cron registry in sync` (audit PASS)
- [x] Orchestrator substrate `fw orchestrator status` shows 466 dispatches, 100% outcome-enriched, recent activity through 2026-06-02

## Recommended operator action

**One click — Watchtower /gaps:**

```
http://192.168.10.107:3000/gaps
```

Locate G-064 → "Close" (or whatever the page surface offers); set rationale "gauge VERDICT=READY 12 cron-firing dates ≥3 threshold; autonomous workload exercising substrate per `fw orchestrator status`".

Cascade automatic: T-2169 retire_when audit advisory will surface F-ORCH retirement recommendation on the next `fw audit` run; agent can then propose the `policy/value-drivers.yaml` edit via a separate task (sovereignty-respecting).

## What is NOT being requested

- Agent does NOT mechanically close G-064 — closure of `concerns.yaml` entries is sovereignty-adjacent (gap register lives on the human side of the rail).
- Agent does NOT edit `policy/value-drivers.yaml` to retire F-ORCH preemptively — that follows the T-2169 audit advisory, not this handoff.

This document is **surface evidence only**. It exists so the operator does not have to re-derive the gauge state, re-walk the cascade, or hunt for the URL.

---

_Generated 2026-06-02 by T-2184 (post-T-1820/T-1700 §ACD-pause pivot, fabric-enrich opportunistic cleanup co-sibling)._
