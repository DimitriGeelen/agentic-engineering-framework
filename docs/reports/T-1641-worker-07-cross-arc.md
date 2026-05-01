# T-1641 Worker 07 — Cross-Arc Connections

## Summary

Three arcs share T-1061's root pattern: **framework-blindness + scoping-too-narrow + symptom-vs-systemic conflation** (L-329/G-019 family). T-1626 (hook-self-surface, completed, 7 children T-1627–T-1632) and T-1633 (fw upgrade no-local-path, completed, 2 children T-1634–T-1635) are mature siblings — both used the `from-T-XXXX` tag pattern + filed real child build tasks. T-1542 is a near-orphan inside the upgrade cluster (owner=human, no Human ACs, agent ACs all `[x]`); largely noise here. The **Component Fabric has zero coverage** of orchestrator code (483 cards, none for routing/fallback/governance-frame — code lives in /opt/termlink, external repo). **Watchtower has no `/orchestrator` page** — `sessions.html` + `fleet.html` surface session/fleet liveness but not routing rules, task-type tags in flight, fallback chain state, or governance-frame subscribers. Recommendation: keep three distinct arcs cross-linked via `related_tasks` + `from-T-1641` tag; do NOT merge.

## Connection map

| Candidate | Connection | Strength | Recommended linkage |
|---|---|---|---|
| **T-1626** (hook self-surface) | Same root pattern (framework-blindness + invisible non-blocking errors); different code surface | High pattern, low code | `related_tasks: [T-1626]`; mirror its telemetry + SessionStart-self-test design idea for orchestrator |
| **T-1633** (fw upgrade no-local-path) | Same session pattern: "shipped" before fresh-substrate verification, G-019 escalation | High pattern, low code | `related_tasks: [T-1633]`; adopt its "fresh-environment simulation guard" idea → orchestrator equivalent is W09 smoke under clean broker |
| **T-1542** (fw upgrade self-target guard) | Subsumed by T-1633; orphan owner=human with no Human ACs | Low | Not orchestrator-arc relevant. Side-flag: T-1542 should be re-owned to agent or closed |
| **T-1636 / T-1637 / T-1639** (orchestrator-tagged, horizon:later) | Native arc siblings | Native | Add `related_tasks: [T-1641]` so reconsideration surfaces on their pages |
| **T-1640** (arc integration assessment, completed) | Direct predecessor — "GO awaiting review" T-1641 reconsiders | Native | Add to `related_tasks` for traceability |
| **T-1062 / T-1064 / T-1065 / T-1066** (open, "GO awaiting human review") | Native siblings; Recommendations may need rewrite | Native | Add `related_tasks: [T-1641]` on each — reviewer sees reconsideration before approving |
| **T-1309** (watchtowerservice systemd, tagged termlink) | Tag collision only | None | No linkage |
| **Component Fabric** | 483 cards, zero for orchestrator/router/fallback/governance-frame | Gap | File `from-T-1641` follow-up: decide in-repo-only vs. extend to external-repo components |
| **Watchtower UI** | No orchestrator-state page; sessions/fleet pages don't surface routing | Gap | File `from-T-1641` follow-up: `/orchestrator` page (precedent: T-1626 `/hooks`) |

## Proposed arc structure (next pass)

**Three distinct arcs, one shared meta-pattern. Do NOT merge.**

1. **Orchestrator arc (T-1061 lineage)** — behavioural verification, routing-rule consultation, drift defenses. Parent: T-1641. Children tagged `from-T-1641`.
2. **Framework-blindness meta-pattern** (recognition aid, NOT a build arc) — a `decisions.yaml` entry or new `G-0XX` codifying the recurring signature ("agent says 'shipped' before behavioural verification on a fresh substrate"). Points at T-1626, T-1633, T-1641 as exemplars.
3. **Hook/upgrade arcs stay independent** — T-1626 and T-1633 are closed/closing; do not retroactively re-parent.

## Recommended follow-up tasks

Most are 1-line YAML updates, not new build work:

1. **Cross-link orchestrator siblings** — `fw task update` to add `related_tasks: [T-1641]` on T-1062, T-1064, T-1065, T-1066, T-1636, T-1637, T-1639, T-1640. Prevents reviewers approving GO without seeing reconsideration.
2. **Update T-1641** — `related_tasks: [T-1061, T-1626, T-1633, T-1640]` to surface pattern-siblings as "see also" in Watchtower.
3. **Knowledge capture (optional)** — `fw context add-decision "framework-blindness pattern: shipped-before-substrate-verified — signature in T-1626/T-1633/T-1641"`. No new task.
4. **Side cleanup** — flag T-1542 for owner-flip-or-close (out of strict scope but worth surfacing; the W07 brief asked).
5. **Fabric gap** — file `from-T-1641` task: "Component Fabric coverage decision for /opt/termlink — in-repo only or external-repo extension."
6. **UI gap** — file `from-T-1641` task: "Watchtower `/orchestrator` page — routing rules, task-type tags in flight, fallback chain, breaker status, governance-frame subscribers."

## Linkage mechanism

`related_tasks` is primary (bidirectional, surfaces in Watchtower, survives lifecycle moves). `from-T-1641` tag is complementary (queryable filter for descendants, mirrors T-1626/T-1633). Use both: tag descendants, list siblings/predecessors in `related_tasks`.
