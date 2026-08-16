---
id: T-1830
name: "fw-upgrade-incident-2026-05-14 meta-RCA umbrella — boundary-crossing invisibility
  class"
description: >
  Meta-RCA for both T-1827 (cross-hub envelope delivery latency) and T-1828 (mirror-sync
  push failure invisible). Both share root class: invisibility of failures crossing
  async boundaries. Inception for structural remediation pattern.

status: work-completed
workflow_type: inception
owner: human
horizon:
tags: [fw-upgrade-incident-2026-05-14, meta-rca, observability, 
      structural-remediation, umbrella]
components: [bin-fw, lib-mirror, agents-termlink-termlink, agents-audit, 
      web-blueprints]
related_tasks: [T-1827, T-1828, T-1829, T-1594, T-1603]
created: 2026-05-14T19:10:00Z
last_update: '2026-08-16T22:24:45Z'
date_finished: 2026-05-14T20:29:38Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:00Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-ORCH=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:45Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-AUTONOMY=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1830: fw-upgrade-incident-2026-05-14 meta-RCA umbrella — boundary-crossing invisibility class

## Context

Two incidents fired on 2026-05-14 in the fw-upgrade-incident cluster. Surface-level they look distinct (one is TermLink hub-relay, one is git mirror sync). The meta-RCA in this task shows they share **one** structural class: **invisibility of failures at async boundaries**. The framework has gates (T-1603 monotonicity, T-1594 mirror cron, framework:pickup cross-hub topology) — but lacks corresponding observability surfaces for when those gates fire, time out, or stall.

This is an inception because the remediation is not a single fix but a pattern-level investment (what observability surfaces become canonical? Where does the framework draw the line between "this is gated" and "this gate emits when it fires"?). Decision needs human framing before any build slice.

## Meta-RCA — Two Incidents, One Class

### Incident A: T-1827 — Cross-hub envelope delivery latency invisible

**Symptom:** framework-agent could not see termlink-agent's framework:pickup envelopes at offsets 9 and 10 for ~hours. Receiver perspective: "did anything send?" Sender perspective: "I sent it; the local outbound queue is empty (0 pending in ~/.termlink/outbound.sqlite)".

**Discovery channel:** termlink-agent had to send a SEPARATE pickup envelope describing the stall, hours after the actual stall began. Self-reported by the affected party, not by infrastructure.

**Async boundary:** local hub → remote hub federation. The envelope crosses hub boundary; the cross-boundary state (queued-in-flight, accepted-at-remote, delivered-to-receiver) has no surface.

**Failure mode:** eventual delivery (envelopes ARE delivered after hours), but no visibility into "in-flight for N hours" state.

### Incident B: T-1828 — GitHub mirror sync failure invisible

**Symptom:** Auto-recover mirror cron (T-1594, every 15min) push-failed every cycle for ~5h. GitHub HEAD stuck at `9d52cee27` (T-1725, 2026-05-04, 10 days stale). Consumer at /opt/termlink unable to `fw upgrade` to pick up the cwd-trap fix (T-1822 in the 294 stuck commits).

**Discovery channel:** termlink-agent (consumer-side) reported "GitHub mirror is 10 days behind" via framework:pickup offset 12. Self-reported by the affected party, not by infrastructure.

**Async boundary:** origin (OneDev) → mirror (GitHub) via background cron. The cross-boundary state (pushed, push-failed, lagging-by-N-commits) is logged tersely but not surfaced in `fw audit`, `fw doctor`, or Watchtower.

**Failure mode:** silent stall — cron writes `push-failed` to `.context/working/.mirror-sync.log` but does not capture stderr, does not surface in audit, does not alert anything.

### Shared root class — *boundary-crossing-state invisibility*

| Attribute | T-1827 | T-1828 |
|-----------|--------|--------|
| Async boundary | hub → remote-hub | origin → mirror-remote |
| Cross-boundary state | "envelope in-flight" | "push pending / push-failed" |
| Local visibility | outbound queue (limited) | mirror-sync.log "push-failed" (terse) |
| Remote visibility | none | none |
| Cross-boundary visibility | NONE | NONE |
| Discovery channel | consumer self-report | consumer self-report |
| Discovery latency | hours | ~5h |

**The structural class is not "we forgot to add logging to one specific cron."** It's: every async boundary in the framework has the same shape — terse local log, no cross-boundary surface, no audit surface, no Watchtower surface, no alert. When ANY of them stalls, the framework is BLIND for as long as it takes a consumer to manually trigger a check.

This class is broader than mirror or pickup:
- TermLink pickup-bridge cron (consumes from .context/pickup/inbox/)
- TermLink peer-subscribe cron (cross-repo learning)
- watchtower-rss monitor
- liveness monitor
- escalation-drift monitor
- audit cron itself
- mirror sync cron

Each is a "thing that crosses a boundary periodically". Each has terse-local-log + no-cross-boundary-surface. Each is silent when it stalls.

## Acceptance Criteria

### Agent
- [x] Document the meta-RCA in this task body (above) and cross-link to T-1827, T-1828, T-1829
- [x] Inventory the framework's async boundaries (cron jobs, monitors, cross-hub relays, mirror pushes) and characterise each one's current observability surface — at least 5 named (see boundary list under "Shared root class")
- [x] Identify at least 3 candidate remediation patterns — 4 documented (cron-stderr / heartbeat / Watchtower panel / audit-time detector)
- [x] File Recommendation block before inception decision — Recommendation = bundled (Cand-2 + Cand-4)

### Human
- [x] [REVIEW] Decide GO/NO-GO/DEFER on the umbrella remediation pattern, AND which candidate pattern to pursue first
  **Steps:**
  1. Open the review page (link in `fw task review T-1830`)
  2. Read meta-RCA + Candidates + Recommendation
  3. Run: `cd /opt/999-Agentic-Engineering-Framework && bin/fw inception decide T-1830 <decision> --rationale "..."`
  **Expected:** decision recorded; agent files build tasks for chosen pattern. T-1829 stays as a child specifically for the VERSION-stamping piece (independent of which T-1830 pattern is chosen).
  **If not:** DEFER and revisit when the next boundary-crossing stall fires.

## Candidates

### Candidate 1: Universal cron-stderr-capture

Wrap every framework cron job in a thin shim that captures stderr to a per-cron log file. `fw doctor` and `fw audit` then check those files for non-empty stderr (or specific failure patterns) and surface them.

- **Pro:** small, mechanical, applies to every cron at once. Catches the "push-failed silently" class T-1828 hit.
- **Con:** purely reactive (need to check the logs); doesn't catch "stalled but not erroring" classes like T-1827 (envelope in-flight without failure).
- **Migration:** zero consumer impact (all internal infrastructure).

### Candidate 2: Per-boundary heartbeat + last-success timestamp

Each async boundary writes a heartbeat file (`.context/working/.boundary-${name}.heartbeat`) on every successful operation. `fw doctor` and `fw audit` warn when ANY heartbeat is older than the expected cadence (e.g., mirror cron's 15min → warn if heartbeat > 30min stale).

- **Pro:** catches BOTH failure classes — explicit fail (no heartbeat updated) AND stall (heartbeat ages out). Universal pattern.
- **Con:** every async boundary needs to be retrofitted to write the heartbeat. Per-boundary cadence config needed.
- **Migration:** zero consumer impact.

### Candidate 3: Watchtower /boundaries panel

Build a new Watchtower page that lists every async boundary, its current state (in-flight / ok / failed / stale), last-success ts, last-error stderr. Driven by the heartbeat + stderr data from Candidates 1+2.

- **Pro:** human-readable surface; operator opens one URL to see "what's stalled". Complements audit-time check with always-on dashboard.
- **Con:** UI work + retrofit of every boundary to expose state.
- **Migration:** zero consumer impact for the framework repo; consumer's Watchtower also gets the panel after re-vendor.

### Candidate 4: Audit-time stall detector

Extend `fw audit` to walk every known cron in `.context/cron-registry.yaml`, parse its expected cadence, check its last-run state, surface stalls as `FAIL` (not WARN — escalating to FAIL ensures the next handover surfaces it).

- **Pro:** uses existing audit surface (already gated at handover/pre-push). Zero new infrastructure.
- **Con:** audit is at most every 15min on cron — still has discovery latency. Requires reliable last-run state per cron (some don't write one today).
- **Migration:** zero consumer impact.

## Recommendation

**Recommendation:** GO with **bundled (Candidate 2 + Candidate 4)** as the V1 slice, defer Candidate 3 (Watchtower panel) to a V2 follow-up.

**Rationale:** Candidate 2 (heartbeat + last-success) is the smallest universal mechanism that detects BOTH failure classes (explicit fail + silent stall). Candidate 4 (audit-time detector) is the lowest-friction surface — it uses the existing fw audit cadence and handover gates, so the alert path is already wired. Together they catch the T-1827/T-1828 class in <15min via audit, with a clear migration path: retrofit one boundary at a time (start with mirror sync as proof, then pickup-bridge, then peer-subscribe, then watchtower-rss/liveness/escalation-drift). Candidate 1 (stderr capture) is a useful auxiliary but doesn't cover stalls without errors. Candidate 3 (Watchtower panel) is high-value but high-cost — defer until heartbeat data exists to populate it.

**Evidence:**
- T-1827 + T-1828 are 2 incidents of the same class within 24h
- Existing cron infrastructure (.context/cron-registry.yaml, .context/monitors/*) provides a known list of boundaries to retrofit
- `fw doctor` already surfaces some cron-state info (Cron registry in sync check) — the heartbeat addition is incremental
- T-1771 already wired cron-registry sync check into `fw audit` — heartbeat addition extends the same audit surface

## Decision

**Decision**: GO

**Rationale**: Recommendation: GO with bundled (Candidate 2 + Candidate 4) as the V1 slice, defer Candidate 3 (Watchtower panel) to a V2 follow-up.

Rationale: Candidate 2 (heartbeat + last-success) is the smallest universal mechanism that detects BOTH failure classes (explicit fail + silent stall). Candidate 4 (audit-time detector) is the lowest-friction surface — it uses the existing fw audit cadence and handover gates, so the alert path is already wired. Together they catch the T-1827/T-1828 class in <15min via audit, with a clear migration path: retrofit one boundary at a time (start with mirror sync as proof, then pickup-bridge, then peer-subscribe, then watchtower-rss/liveness/escalation-drift). Candidate 1 (stderr capture) is a useful auxiliary but doesn't cover stalls without errors. Candidate 3 (Watchtower panel) is high-value but high-cost — defer until heartbeat data exists to populate it.

Evidence:
- T-1827 + T-1828 are 2 incidents of the same class within 24h
- Existing cron infrastructure (.context/cron-registry.yaml, .context/monitors/) provides a known list of boundaries to retrofit
- `fw doctor` already surfaces some cron-state info (Cron registry in sync check) — the heartbeat addition is incremental
- T-1771 already wired cron-registry sync check into `fw audit` — heartbeat addition extends the same audit surface

**Date**: 2026-05-14T20:29:38Z

## Updates

### 2026-05-14T19:10Z — task-created [framework-agent]
- **Action:** Created umbrella inception covering T-1827 + T-1828 + T-1829 meta-RCA
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1830-fw-upgrade-incident-2026-05-14-meta-rca-.md
- **Context:** Human asked for meta-RCA covering both incidents and an inception for structural remediation

### 2026-05-14T19:24:11Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO with bundled (Candidate 2 + Candidate 4) as the V1 slice, defer Candidate 3 (Watchtower panel) to a V2 follow-up.

Rationale: Candidate 2 (heartbeat + last-success) is the smallest universal mechanism that detects BOTH failure classes (explicit fail + silent stall). Candidate 4 (audit-time detector) is the lowest-friction surface — it uses the existing fw audit cadence and handover gates, so the alert path is already wired. Together they catch the T-1827/T-1828 class in <15min via audit, with a clear migration path: retrofit one boundary at a time (start with mirror sync as proof, then pickup-bridge, then peer-subscribe, then watchtower-rss/liveness/escalation-drift). Candidate 1 (stderr capture) is a useful auxiliary but doesn't cover stalls without errors. Candidate 3 (Watchtower panel) is high-value but high-cost — defer until heartbeat data exists to populate it.

Evidence:
- T-1827 + T-1828 are 2 incidents of the same class within 24h
- Existing cron infrastructure (.context/cron-registry.yaml, .context/monitors/) provides a known list of boundaries to retrofit
- `fw doctor` already surfaces some cron-state info (Cron registry in sync check) — the heartbeat addition is incremental
- T-1771 already wired cron-registry sync check into `fw audit` — heartbeat addition extends the same audit surface

### 2026-05-14T19:24:32Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO with bundled (Candidate 2 + Candidate 4) as the V1 slice, defer Candidate 3 (Watchtower panel) to a V2 follow-up.

Rationale: Candidate 2 (heartbeat + last-success) is the smallest universal mechanism that detects BOTH failure classes (explicit fail + silent stall). Candidate 4 (audit-time detector) is the lowest-friction surface — it uses the existing fw audit cadence and handover gates, so the alert path is already wired. Together they catch the T-1827/T-1828 class in <15min via audit, with a clear migration path: retrofit one boundary at a time (start with mirror sync as proof, then pickup-bridge, then peer-subscribe, then watchtower-rss/liveness/escalation-drift). Candidate 1 (stderr capture) is a useful auxiliary but doesn't cover stalls without errors. Candidate 3 (Watchtower panel) is high-value but high-cost — defer until heartbeat data exists to populate it.

Evidence:
- T-1827 + T-1828 are 2 incidents of the same class within 24h
- Existing cron infrastructure (.context/cron-registry.yaml, .context/monitors/) provides a known list of boundaries to retrofit
- `fw doctor` already surfaces some cron-state info (Cron registry in sync check) — the heartbeat addition is incremental
- T-1771 already wired cron-registry sync check into `fw audit` — heartbeat addition extends the same audit surface

### 2026-05-14T19:27:26Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO with bundled (Candidate 2 + Candidate 4) as the V1 slice, defer Candidate 3 (Watchtower panel) to a V2 follow-up.

Rationale: Candidate 2 (heartbeat + last-success) is the smallest universal mechanism that detects BOTH failure classes (explicit fail + silent stall). Candidate 4 (audit-time detector) is the lowest-friction surface — it uses the existing fw audit cadence and handover gates, so the alert path is already wired. Together they catch the T-1827/T-1828 class in <15min via audit, with a clear migration path: retrofit one boundary at a time (start with mirror sync as proof, then pickup-bridge, then peer-subscribe, then watchtower-rss/liveness/escalation-drift). Candidate 1 (stderr capture) is a useful auxiliary but doesn't cover stalls without errors. Candidate 3 (Watchtower panel) is high-value but high-cost — defer until heartbeat data exists to populate it.

Evidence:
- T-1827 + T-1828 are 2 incidents of the same class within 24h
- Existing cron infrastructure (.context/cron-registry.yaml, .context/monitors/) provides a known list of boundaries to retrofit
- `fw doctor` already surfaces some cron-state info (Cron registry in sync check) — the heartbeat addition is incremental
- T-1771 already wired cron-registry sync check into `fw audit` — heartbeat addition extends the same audit surface

### 2026-05-14T20:09:16Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO with bundled (Candidate 2 + Candidate 4) as the V1 slice, defer Candidate 3 (Watchtower panel) to a V2 follow-up.

Rationale: Candidate 2 (heartbeat + last-success) is the smallest universal mechanism that detects BOTH failure classes (explicit fail + silent stall). Candidate 4 (audit-time detector) is the lowest-friction surface — it uses the existing fw audit cadence and handover gates, so the alert path is already wired. Together they catch the T-1827/T-1828 class in <15min via audit, with a clear migration path: retrofit one boundary at a time (start with mirror sync as proof, then pickup-bridge, then peer-subscribe, then watchtower-rss/liveness/escalation-drift). Candidate 1 (stderr capture) is a useful auxiliary but doesn't cover stalls without errors. Candidate 3 (Watchtower panel) is high-value but high-cost — defer until heartbeat data exists to populate it.

Evidence:
- T-1827 + T-1828 are 2 incidents of the same class within 24h
- Existing cron infrastructure (.context/cron-registry.yaml, .context/monitors/) provides a known list of boundaries to retrofit
- `fw doctor` already surfaces some cron-state info (Cron registry in sync check) — the heartbeat addition is incremental
- T-1771 already wired cron-registry sync check into `fw audit` — heartbeat addition extends the same audit surface

### 2026-05-14T20:09:25Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO with bundled (Candidate 2 + Candidate 4) as the V1 slice, defer Candidate 3 (Watchtower panel) to a V2 follow-up.

Rationale: Candidate 2 (heartbeat + last-success) is the smallest universal mechanism that detects BOTH failure classes (explicit fail + silent stall). Candidate 4 (audit-time detector) is the lowest-friction surface — it uses the existing fw audit cadence and handover gates, so the alert path is already wired. Together they catch the T-1827/T-1828 class in <15min via audit, with a clear migration path: retrofit one boundary at a time (start with mirror sync as proof, then pickup-bridge, then peer-subscribe, then watchtower-rss/liveness/escalation-drift). Candidate 1 (stderr capture) is a useful auxiliary but doesn't cover stalls without errors. Candidate 3 (Watchtower panel) is high-value but high-cost — defer until heartbeat data exists to populate it.

Evidence:
- T-1827 + T-1828 are 2 incidents of the same class within 24h
- Existing cron infrastructure (.context/cron-registry.yaml, .context/monitors/) provides a known list of boundaries to retrofit
- `fw doctor` already surfaces some cron-state info (Cron registry in sync check) — the heartbeat addition is incremental
- T-1771 already wired cron-registry sync check into `fw audit` — heartbeat addition extends the same audit surface

### 2026-05-14T20:09:31Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO with bundled (Candidate 2 + Candidate 4) as the V1 slice, defer Candidate 3 (Watchtower panel) to a V2 follow-up.

Rationale: Candidate 2 (heartbeat + last-success) is the smallest universal mechanism that detects BOTH failure classes (explicit fail + silent stall). Candidate 4 (audit-time detector) is the lowest-friction surface — it uses the existing fw audit cadence and handover gates, so the alert path is already wired. Together they catch the T-1827/T-1828 class in <15min via audit, with a clear migration path: retrofit one boundary at a time (start with mirror sync as proof, then pickup-bridge, then peer-subscribe, then watchtower-rss/liveness/escalation-drift). Candidate 1 (stderr capture) is a useful auxiliary but doesn't cover stalls without errors. Candidate 3 (Watchtower panel) is high-value but high-cost — defer until heartbeat data exists to populate it.

Evidence:
- T-1827 + T-1828 are 2 incidents of the same class within 24h
- Existing cron infrastructure (.context/cron-registry.yaml, .context/monitors/) provides a known list of boundaries to retrofit
- `fw doctor` already surfaces some cron-state info (Cron registry in sync check) — the heartbeat addition is incremental
- T-1771 already wired cron-registry sync check into `fw audit` — heartbeat addition extends the same audit surface

### 2026-05-14T20:29:38Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO with bundled (Candidate 2 + Candidate 4) as the V1 slice, defer Candidate 3 (Watchtower panel) to a V2 follow-up.

Rationale: Candidate 2 (heartbeat + last-success) is the smallest universal mechanism that detects BOTH failure classes (explicit fail + silent stall). Candidate 4 (audit-time detector) is the lowest-friction surface — it uses the existing fw audit cadence and handover gates, so the alert path is already wired. Together they catch the T-1827/T-1828 class in <15min via audit, with a clear migration path: retrofit one boundary at a time (start with mirror sync as proof, then pickup-bridge, then peer-subscribe, then watchtower-rss/liveness/escalation-drift). Candidate 1 (stderr capture) is a useful auxiliary but doesn't cover stalls without errors. Candidate 3 (Watchtower panel) is high-value but high-cost — defer until heartbeat data exists to populate it.

Evidence:
- T-1827 + T-1828 are 2 incidents of the same class within 24h
- Existing cron infrastructure (.context/cron-registry.yaml, .context/monitors/) provides a known list of boundaries to retrofit
- `fw doctor` already surfaces some cron-state info (Cron registry in sync check) — the heartbeat addition is incremental
- T-1771 already wired cron-registry sync check into `fw audit` — heartbeat addition extends the same audit surface

## Reviewer Verdict (v1.5)

- **Scan ID:** R-4a701c55
- **Timestamp:** 2026-06-02T14:59:54Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-14T20:29:38Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
