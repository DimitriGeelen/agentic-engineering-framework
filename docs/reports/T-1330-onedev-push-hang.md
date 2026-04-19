# T-1330 — Onedev push hang RCA

**Task:** T-1330
**Started:** 2026-04-19
**Status:** exploring

## Problem

Every `git push onedev HEAD` hangs past 15s. T-1277 bounded the damage (`timeout 15 git push`) but never addressed why. Evidence:

- 4+ reproductions session 2026-04-19
- Onedev tag pushes **succeed** (`fw release` of v1.5.744 pushed tag cleanly today)
- GitHub push of identical commits completes in 30–60s
- Only onedev branch-push of HEAD hangs

So: onedev-specific, branch-push-specific.

## Assumptions under test

| # | Assumption | Status |
|---|---|---|
| 1 | Hang is real, not timeout-flag misconfig | TRUE (tag push succeeds) |
| 2 | 15s is the correct bound | UNTESTED |
| 3 | Cause is server-side | UNTESTED — Spike A decides |
| 4 | Cause is consistent across attempts | LIKELY — symptom uniform |

## Spike plan

- **A** (~10s local): `GIT_TRACE=1 GIT_TRACE_PACKET=1` — see where trace stalls
- **B** (requires .122 admin): inspect onedev container if Spike A points remote
- **C** (local): `GIT_CURL_VERBOSE=1` if Spike A points at TLS/HTTP layer

## Spike A — trace

### Command

```
timeout 30 env GIT_TRACE=1 GIT_TRACE_PACKET=1 GIT_CURL_VERBOSE=1 \
  git push -v --progress onedev HEAD > /tmp/t1330-spike-a.log 2>&1
```

### Findings

**Trace timeline (onedev server is NOT the hang source):**

- `14:32:12.639` — `git push` starts
- `14:32:12.656` — DNS resolved (.52), TCP connect .52:443
- `14:32:12.758` — TLS 1.3 handshake complete, cert valid through 2026-06-17
- `14:32:12.761` — HTTP/2 `GET /info/refs?service=git-receive-pack` sent
- `14:32:12.765` — Response: `401 BASIC realm="OneDev"` (expected, basic auth round-trip)
- `14:32:12.821` — All refs enumerated (pkt-line `0000` terminator received). **Onedev negotiation: 182 ms total.**
- `14:32:12.821` — `run_command: .git/hooks/pre-push onedev ...` fires
- `14:32:12.825` — Pre-push hook starts `fw audit` (VERSION stamp + audit)
- **`30.000 s`** — wall-clock timeout hits, log ends mid-audit-trend-analysis (exit 124)

Onedev responded in 182ms. The hang is in the **pre-push hook's `fw audit` invocation**, not the push.

**Follow-up discovery (the real root cause):**

`ps aux | grep 'fw audit'` showed **139 orphaned `fw audit --cron` processes**, some in uninterruptible D-state running since Apr 18 consuming 358+ minutes of CPU each. Two cron files install audit schedules (framework's `.context/cron/agentic-audit.crontab` → `/etc/cron.d/agentic-audit-999-*`), and no lock mechanism existed — every cron fire that overlapped with a still-running audit stacked rather than skipped. Over time, 139 overlapping audits accumulated, contending for the same audit-history files and choking any new invocation (including the pre-push hook).

**So: the "onedev push hang" was our own pre-push audit hook serialising behind 139 orphaned cron audits, not onedev.** T-1277's `timeout 15 git push` bounded the damage but treated the wrong suspect.

## Spike B & C — not needed

Spike A was definitive. No server-side or TLS-level investigation required.

## Recommendation — GO

**Bounded, reversible fix path** — ship immediately:

1. **Kill 139 orphan `fw audit` processes** — done inline under T-1330 (pkill, 139 → 1 after successive SIGTERM rounds, last straggler killed by PID). Single-shot, reversible (cron respawns if needed).
2. **Wrap audit cron entries in `flock -n`** — done under separate build task **T-1331**. Per-section lock files (`/var/lock/fw-audit-999-<section>.lock`) so different audit sections still run in parallel but overlapping fires of the same section skip instead of stack. Source-of-truth `.context/cron/agentic-audit.crontab` edited; installed to `/etc/cron.d/agentic-audit-999-agentic-engineering-framework`. 9 flock-wrapped entries verified in both source and destination.
3. **Empirical flock-skip test** — `flock -n /tmp/test.lock` returns exit 1 without running payload when lock held. Confirmed.

T-1277's `timeout 15 git push` bound can stay — it's still a belt-and-suspenders safeguard if future audit regressions happen. Not removing.

**NOT addressed here (out of scope, separate concerns):**

- Why individual audits sometimes took 6+ CPU-hours (D-state NFS wait?) — separate RCA if it recurs post-flock
- Consumer projects' audit cron files (`/etc/cron.d/agentic-audit-*`) are unchanged — fix applies only to the framework's own audit cron. A cron-generator sweep is a separate task.
- `fw audit schedule install` for other projects still emits lock-free crontabs — generator-level fix is a separate concern.

## Dialogue Log

- **Human request:** "icept RCA investigation, incpeet resoloztaion exploration and discusstion + decision" + "if needed ask ring20-managemnrt on .122 for assitance"
- **Agent initial framing:** planned Spike A (local trace) → B (.122 server-side) → C (TLS). Assumption 3 (cause is server-side) was the working hypothesis.
- **Spike A result flipped the investigation:** trace showed onedev responded in 182ms, hang is local to pre-push hook. No need to escalate to .122.
- **Follow-on discovery:** `ps aux` revealed 139 orphaned audit processes — the hang is systemic, not just pre-push. The flock fix is the structural remediation.
- **Scope discipline:** human asked "do we need cross-project pickup for structural remediation?" — tracked separately as T-1332 (G-045 fleet-rotation-UX remediation inception) and T-1333 (meta-rule "gap lives where fix lives" codification inception). Not bundled here.

## Decision

**Decision:** GO
**Rationale:** Root cause identified (139 orphan audits + no flock); fix bounded, reversible, scoped to framework project; implementation landed under T-1331 with empirical verification. Separate concerns tracked as follow-ups.
**Date:** 2026-04-19
