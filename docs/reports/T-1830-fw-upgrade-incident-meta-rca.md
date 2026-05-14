# T-1830 — fw-upgrade-incident-2026-05-14 Meta-RCA

**Task:** [T-1830](http://192.168.10.107:3000/inception/T-1830)
**Scope:** Two incidents (T-1827, T-1828) → one root class
**Status:** Inception, awaiting decision
**Generated:** 2026-05-14

## Executive Summary

On 2026-05-14, two distinct incidents fired in the fw-upgrade-incident-2026-05-14 cluster. Both look unrelated on the surface — one is a TermLink hub-relay latency, one is a GitHub mirror sync failure. **They share one structural root class:** the framework operates across async boundaries, and when boundary-crossing operations fail or stall, **the failure is invisible**.

The fix isn't "add logging to one cron". It's a pattern: every async boundary in the framework needs (a) a heartbeat file that aging out signals "stalled" and (b) an audit-time stall detector that surfaces it within the cadence already gated at handover/pre-push.

**Recommendation:** GO on T-1830 with bundled Candidate 2 + Candidate 4. Defer Watchtower panel (Candidate 3) to V2. Keep T-1829 (VERSION-stamping algorithm) as an independent child — the algorithm class is narrower and doesn't depend on the boundary-observability pattern.

## The Two Incidents

### Incident A — T-1827 (OPS-1): Cross-hub envelope delivery latency

- **Discovery (2026-05-14T14:25Z):** termlink-agent emitted a SEPARATE pickup envelope describing the original stall, hours after the original stall began. The fact that envelopes at offsets 9-10 were stalled became visible only because the affected party sent a META-message about it.
- **Symptom:** framework-agent could not see termlink-agent's framework:pickup envelopes at offsets 9 and 10. Local outbound queue empty (0 pending). Receiver had no surface to know "your peer has N envelopes queued for you that haven't reached your hub yet".
- **Resolution (2026-05-14T18:30Z):** offsets 9 and 10 ARE visible on re-check — eventual-but-late delivery (~hours). Class reclassified from "drop" to "latency without visibility".
- **Async boundary:** local hub → remote hub federation.

### Incident B — T-1828 (OPS-2): GitHub mirror sync failure

- **Discovery (2026-05-14T18:05Z):** termlink-agent reported via framework:pickup offset 12 that the GitHub mirror was 10 days stale. Mirror cron HAD been auto-retrying every 15 minutes for ~5h, logging `push-failed` to `.context/working/.mirror-sync.log` — but stderr was discarded by `2>/dev/null`, no audit surface fired, no Watchtower visibility, no alert.
- **Symptom:** GitHub HEAD stuck at `9d52cee27` (T-1725, 2026-05-04). 294 commits ahead on origin. Consumer at /opt/termlink unable to `fw upgrade` to pick up T-1822 (cwd-trap fix).
- **Root sub-cause:** VERSION-stamping `git describe` patch-counter resets at each new tag. `v1.6.2` created after last GitHub push, dropped stamped VERSION from `1.6.260` → `1.6.148`. T-1603 monotonicity hook correctly flagged this as rollback per its `sort -V` check. The hook IS doing its job; the stamping algorithm is the substrate flaw (covered by T-1829).
- **Status:** awaiting Tier-2 bypass push approval.
- **Async boundary:** origin (OneDev) → mirror (GitHub) via cron.

## Shared Root Class

| Attribute | T-1827 | T-1828 |
|---|---|---|
| Async boundary | hub → remote-hub | origin → mirror-remote |
| Cross-boundary state | "envelope in-flight" | "push pending / push-failed" |
| Local visibility | outbound queue (limited) | mirror-sync.log "push-failed" (terse) |
| Remote visibility | NONE | NONE |
| Cross-boundary visibility | NONE | NONE |
| Discovery channel | consumer self-report | consumer self-report |
| Discovery latency | hours | ~5h |
| Failure-mode coverage | latency (no error) | error (silently discarded) |

The framework has multiple async boundaries with the same shape. Each is silent when it stalls or fails:

| Boundary | Cadence | Direction | Current observability |
|---|---|---|---|
| mirror sync (T-1594) | 15min cron | origin → mirror | mirror-sync.log (terse) |
| pickup-bridge | cron | local outbound → remote inbox | .pickup-bridge.log |
| peer-subscribe | cron | cross-repo learnings | none |
| framework:pickup | continuous | hub federation | none (the T-1827 class) |
| watchtower-rss | continuous monitor | external → local cache | watchtower-rss.jsonl |
| liveness | continuous monitor | local → state | liveness.jsonl |
| escalation-drift | continuous monitor | session → ladder check | escalation-drift-LATEST.yaml |
| audit cron | daily | local → audit log | .context/audits/YYYY-MM-DD.yaml |

Every one of these has the same vulnerability: silent stall is undetectable without manual probing. The framework BLINDLY trusts that each cron continues running on schedule.

## Antifragility framing

CLAUDE.md Directive 1: **Antifragility — System strengthens under stress; failures are learning events.**

T-1827 and T-1828 are stress signals. The system did NOT strengthen — both incidents were resolved by manual intervention from a consumer (termlink-agent self-reporting). The system stayed exactly as fragile as before. T-1830 is the antifragile response: convert the failure events into a structural change that catches the next instance automatically.

## Candidates (4 evaluated, see task file for full text)

| # | Approach | Catches | Cost | Consumer impact |
|---|---|---|---|---|
| 1 | Per-cron stderr capture | Errors (T-1828 class) | Low | None |
| 2 | Per-boundary heartbeat + age check | Errors + stalls (T-1827 + T-1828) | Medium (retrofit each boundary) | None |
| 3 | Watchtower /boundaries panel | All (visible dashboard) | High | Re-vendor after release |
| 4 | Audit-time stall detector | All (via existing audit gate) | Low (extend fw audit) | None |

## Recommendation

**GO on T-1830 with bundled Candidate 2 + Candidate 4 as V1 slice.**

Rationale: smallest universal mechanism that detects both failure classes (explicit fail + silent stall). Reuses the existing `fw audit` cadence and handover gates — the alert path is already wired. Clear migration: retrofit one boundary at a time (start with mirror sync as proof, then pickup-bridge, then peer-subscribe, then watchtower-rss/liveness/escalation-drift). Watchtower panel (C-3) is deferred to V2 once heartbeat data exists to populate it.

Expected V1 outcome: a future T-1828-class stall surfaces in `fw audit` within 30min of the cron's expected cadence, surfaces in `fw handover` immediately after, and a Tier-0 alert pattern fires before any consumer notices.

## Relationship to T-1829

T-1829 covers the VERSION-stamping algorithm specifically. That's a narrower class (one cron's algorithm) and is INDEPENDENT of T-1830's boundary-observability pattern. T-1829 should be decided on its own merits; whichever direction is chosen there does not affect T-1830's V1 scope.

If T-1830 is GO and T-1829 is also GO: T-1830 retrofits mirror-sync to emit heartbeat; T-1829 fixes the stamping/hook semantics so the cron stops failing in the first place. The two layers compound: T-1829 reduces the rate of failures, T-1830 ensures any that still happen surface in <30min.

## Wire-evidence (artefacts traceable)

- T-1827 task file (RCA section): `.tasks/active/T-1827-pickup-cross-hub-relay-stall-termlink-ag.md`
- T-1828 task file (RCA section): `.tasks/active/T-1828-github-mirror-stalled--version-tag-reset.md`
- T-1829 task file (4 candidates for stamping fix): `.tasks/active/T-1829-version-stamping-algorithm-not-cross-tag.md`
- L-376 (VERSION tag-reset class): `.context/project/learnings.yaml`
- Mirror-sync log evidence: `.context/working/.mirror-sync.log` (16+ consecutive push-failed entries since 13:30Z)
- termlink-agent original report: `framework:pickup` offset 12 (also offset 10 with B-1 cwd-trap detail)
- framework-agent ack + W-issue triage: `framework:pickup` offset 13 + 14

## Suggested decision text (for fw inception decide T-1830 ...)

> GO with bundled V1 slice (Candidate 2 heartbeat + Candidate 4 audit-time stall detector). Defer Watchtower panel (Candidate 3) to V2 follow-up once heartbeat data is populated. Retrofit migration order: mirror-sync (proof) → pickup-bridge → peer-subscribe → watchtower-rss/liveness/escalation-drift. T-1829 stays independent.
