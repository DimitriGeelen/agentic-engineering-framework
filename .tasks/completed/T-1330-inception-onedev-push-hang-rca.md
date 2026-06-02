---
id: T-1330
name: "Onedev push hang RCA — every git push onedev exceeds 15s timeout, cause unaddressed (T-1277 fixed damage only)"
description: >
  Inception. Every git push to onedev hangs past T-1277's 15s timeout. T-1277 bounded the damage (handover.sh no longer stalls the session) but did not address why the push hangs. Direct evidence from session 2026-04-19: 4+ reproductions across different commit batches; github push of the same commits succeeds in 30-60s. Onedev-specific.

status: work-completed
workflow_type: inception
owner: agent
horizon: null
tags: [rca, infrastructure, onedev, push-hang]
components: []
related_tasks: [T-1277]
created: 2026-04-19T12:01:00Z
last_update: 2026-04-19T13:28:29Z
date_finished: 2026-04-19T13:28:29Z
---

# T-1330: Onedev push hang RCA

## Problem Statement

`git push onedev HEAD` consistently hangs past 15s. T-1277 wraps the call in `timeout` so the session continues, but:
- The push never completes within budget
- Onedev tag pushes succeed (shown by `fw release` of v1.5.744 today)
- github push of identical commits completes in 30-60s
- 4+ direct reproductions in session 2026-04-19

So: onedev-specific, branch-push-specific, not a general network/auth/repo issue.

## Assumptions

1. The hang is real (not a timeout-flag misconfig) — TESTED TRUE (`fw release` tag push to onedev succeeded; only branch push of HEAD hangs)
2. T-1277's bound is correct (15s is the right timeout for "this isn't going to finish") — UNTESTED (could be too short; need trace)
3. Cause is server-side, not client-side — UNTESTED (would need to run with GIT_TRACE / GIT_CURL_VERBOSE on client + observe onedev container during push)
4. Cause is consistent (same root every time) — LIKELY TRUE based on uniform symptom but UNTESTED

## Exploration Plan

Single-spike sequence (run one, decide next from evidence):

- **Spike A** (~10s, local-only): `GIT_TRACE=1 GIT_TRACE_PACKET=1 git push -v --progress onedev HEAD 2>&1 | head -200` — observe where the trace stalls (counting / compressing / writing / waiting on remote / TLS handshake / pre-receive). Definitive on client-vs-server.
- **Spike B** (5min, requires .122 access): if Spike A points to remote, ask ring20-management on .122 to inspect onedev container during a push: process state, lock files, pre-receive hook log, GC state, recent disk pressure. Out-of-band contact may be needed (G-045 .122 hub auth still rotating).
- **Spike C** (5min, local): if Spike A points to TLS/HTTP layer, retry with `GIT_CURL_VERBOSE=1` to isolate whether stall is in the HTTPS handshake vs git protocol.
- **Spike D** (decision-only): given Spike A/B/C results, decide between (1) fix server-side, (2) bump T-1277 timeout, (3) drop onedev as a remote, (4) move to ssh transport.

## Technical Constraints

- LXC 170 hosts onedev under Proxmox; ring20-management on .122 has admin
- .122 TermLink hub is in G-045 rotation state — direct TermLink remote-exec may fail, need SSH or Watchtower-of-theirs as fallback
- Pushes happen in pre-push hook + handover.sh — both call sites are bounded already, so this is a quality-of-life issue not a blocking one (which is why it can be properly investigated rather than panic-fixed)

## Scope Fence

**IN:** identify why `git push onedev HEAD` hangs, decide on a bounded fix path.
**OUT:** rebuilding onedev's auth model, switching git server vendors, removing onedev as a mirror entirely (those are downstream choices once RCA points there).

## Acceptance Criteria

### Agent
- [x] Spike A executed; client-vs-server determined from trace — **onedev negotiation was 182ms; hang is local to pre-push hook**
- [x] Spike B or C executed (chosen by Spike A's evidence) — **skipped, Spike A definitive; follow-on ps/cron discovery revealed 139 orphan `fw audit` processes as real root cause**
- [x] Recommendation written: which fix path is bounded and reversible — **GO, flock wrapper shipped under T-1331**
- [x] Research artifact `docs/reports/T-1330-onedev-push-hang.md` created and updated incrementally during exploration (C-001)

### Human
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `cd /opt/999-Agentic-Engineering-Framework && bin/fw task review T-1330`
  2. Review the Recommendation section + chosen fix path
  3. Record decision via Watchtower
  **Expected:** Decision recorded, task moves to completed/
  **If not:** Ask agent for additional spike or clarification

## Go/No-Go Criteria

**GO if:**
- Root cause identified with bounded, reversible fix path
- Fix can be shipped under one task in a single session

**NO-GO if:**
- RCA points at a fundamental onedev limitation requiring vendor swap (then escalate to separate strategic decision, do not bundle here)
- Fix would require destabilizing pre-push or handover paths that have been working fine under T-1277's bound

## Verification

# For inception tasks, verification is the recommendation content itself.

## Recommendation

**Recommendation:** GO

**Rationale:** The "onedev push hang" is NOT onedev. Spike A trace shows onedev completes ref negotiation in 182ms; the hang is in the pre-push hook's `fw audit` call, contending with **139 orphaned `fw audit --cron` processes** (some running >24h in D-state, consuming 6+ CPU-hours each). Root cause: no `flock` wrapper on audit cron entries, so overlapping fires stacked instead of skipped.

**Fix path (bounded, reversible):**
1. Kill the 139 orphans (done inline under T-1330; count 139 → 1)
2. Wrap audit cron entries with `flock -n /var/lock/fw-audit-999-<section>.lock` (done under T-1331; 9 entries flock-wrapped; empirically verified skip behaviour)

**Evidence:**
- Research artifact: `docs/reports/T-1330-onedev-push-hang.md` (full trace + findings)
- T-1331 build task (now completed): `.tasks/completed/T-1331-add-flock-wrapper-to-audit-cron-entries-.md`
- Updated cron source: `.context/cron/agentic-audit.crontab` (9 flock-wrapped entries)
- Installed: `/etc/cron.d/agentic-audit-999-agentic-engineering-framework` (9 flock-wrapped entries)
- Empirical flock-skip test: `flock -n LOCK` exit 1 without payload when lock held (2026-04-19)
- Post-fix audit process count: 3 (down from 139; 3 are current cron-cycle fires, flock prevents further stacking)

**NOT addressed here (tracked separately):**
- Why individual audits sometimes took 6+ CPU-hours (D-state NFS wait suspected) — separate RCA if it recurs
- Other projects' audit cron files not yet flock-wrapped — generator-level sweep is separate
- T-1277's `timeout 15 git push` bound retained as belt-and-suspenders

## Decisions

<!-- Recorded inline if multiple alternative fix paths emerge. -->

## Decision

**Decision**: GO

**Rationale**: Recommendation: GO

Rationale: The "onedev push hang" is NOT onedev. Spike A trace shows onedev completes ref negotiation in 182ms; the hang is in the pre-push hook's `fw audit` call, contending with 139 orphaned `fw audit --cron` processes (some running >24h in D-state, consuming 6+ CPU-hours each). Root cause: no `flock` wrapper on audit cron entries, so overlapping fires stacked instead of skipped.

Fix path (bounded, reversible):
1. Kill the 139 orphans (done inline under T-1330; count 139 → 1)
2. Wrap audit cron entries with `flock -n /var/lock/fw-audit-999-<section>.lock` (done under T-1331; 9 entries flock-wrapped; empirically verified skip behaviour)

Evidence:
- Research artifact: `docs/reports/T-1330-onedev-push-hang.md` (full trace + findings)
- T-1331 build task (now completed): `.tasks/completed/T-1331-add-flock-wrapper-to-audit-cron-entries-.md`
- Updated cron source: `.context/cron/agentic-audit.crontab` (9 flock-wrapped entries)
- Installed: `/etc/cron.d/agentic-audit-999-agentic-engineering-framework` (9 flock-wrapped entries)
- Empirical flock-skip test: `flock -n LOCK` exit 1 without payload when lock held (2026-04-19)
- Post-fix audit process count: 3 (down from 139; 3 are current cron-cycle fires, flock prevents further stacking)

NOT addressed here (tracked separately):
- Why individual audits sometimes took 6+ CPU-hours (D-state NFS wait suspected) — separate RCA if it recurs
- Other projects' audit cron files not yet flock-wrapped — generator-level sweep is separate
- T-1277's `timeout 15 git push` bound retained as belt-and-suspenders

**Date**: 2026-04-19T13:28:28Z

## Updates

### 2026-04-19T12:01:00Z — created
- **Action:** Inception framed at session wrap-up (budget critical, 97%)
- **Next:** Run Spike A first thing next session
- **Authorized assist:** ring20-management on .122 (per user, this session) — out-of-band channel may be needed due to G-045 .122 hub rotation

### 2026-04-19T13:28:28Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO

Rationale: The "onedev push hang" is NOT onedev. Spike A trace shows onedev completes ref negotiation in 182ms; the hang is in the pre-push hook's `fw audit` call, contending with 139 orphaned `fw audit --cron` processes (some running >24h in D-state, consuming 6+ CPU-hours each). Root cause: no `flock` wrapper on audit cron entries, so overlapping fires stacked instead of skipped.

Fix path (bounded, reversible):
1. Kill the 139 orphans (done inline under T-1330; count 139 → 1)
2. Wrap audit cron entries with `flock -n /var/lock/fw-audit-999-<section>.lock` (done under T-1331; 9 entries flock-wrapped; empirically verified skip behaviour)

Evidence:
- Research artifact: `docs/reports/T-1330-onedev-push-hang.md` (full trace + findings)
- T-1331 build task (now completed): `.tasks/completed/T-1331-add-flock-wrapper-to-audit-cron-entries-.md`
- Updated cron source: `.context/cron/agentic-audit.crontab` (9 flock-wrapped entries)
- Installed: `/etc/cron.d/agentic-audit-999-agentic-engineering-framework` (9 flock-wrapped entries)
- Empirical flock-skip test: `flock -n LOCK` exit 1 without payload when lock held (2026-04-19)
- Post-fix audit process count: 3 (down from 139; 3 are current cron-cycle fires, flock prevents further stacking)

NOT addressed here (tracked separately):
- Why individual audits sometimes took 6+ CPU-hours (D-state NFS wait suspected) — separate RCA if it recurs
- Other projects' audit cron files not yet flock-wrapped — generator-level sweep is separate
- T-1277's `timeout 15 git push` bound retained as belt-and-suspenders

### 2026-04-19T13:28:29Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO

## Reviewer Verdict (v1.5)

- **Scan ID:** R-5df7bb7f
- **Timestamp:** 2026-06-02T14:56:45Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
