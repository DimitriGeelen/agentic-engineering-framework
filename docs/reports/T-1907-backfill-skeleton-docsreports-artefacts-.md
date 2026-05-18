# T-1907 — backfill skeleton docs/reports artefacts for 15 pre-T-1906 inceptions with C-001 WARN — clear historical audit noise

**Inception artefact (C-001).** Filed 2026-05-18T20:08:14Z by agent; awaiting human inception-decide.

## Origin

Filed immediately after T-1906 shipped (auto-skeleton at filing). This very artefact is the dogfood evidence — it was auto-created by the T-1906 mechanism, not written by hand. T-1906's prevention story closes future C-001 recurrence but leaves 15 historical inceptions with audit WARNs:

- T-1617, T-1444, T-1621, T-1710, T-1831, T-1376, T-1833, T-1616, T-1372, T-1506, T-1732, T-1626, T-1507, T-1829, T-1713 (per `.context/audits/2026-05-18.yaml`)

Each was filed when the C-001 rule was advisory text. Some are completed-and-archived inceptions whose original research is lost to the chat transcript. Some reached GO/NO-GO decisions captured in commit history but not in a docs/reports/ artefact.

## Research

Three options identified at filing:

1. **Mechanical skeleton write** — loop the T-1906 skeleton over the 15 task slugs. Pros: clears audit WARNs in ~5 min. Cons: empty skeletons add zero signal; they make future readers think research happened when it didn't.

2. **Hand-curated backfill** — for each task, read the body + commit history, write a retrospective artefact that captures what the inception found and decided. Pros: real signal. Cons: 15 × ~30 min = 7.5 hours of work for stale inceptions; risk of fabricating history.

3. **Audit-rule retirement / temporal cutoff** — change the C-001 audit detector to ignore inceptions filed before T-1906's commit timestamp. Pros: WARNs disappear with zero busywork. Cons: hides historical violations behind a temporal cutoff (sets precedent that filtering is acceptable).

Hybrid: option 3 + a one-line note in the audit detector explaining the cutoff date and pointing at this artefact for the reasoning.

## Dialogue Log

(none yet — to be populated when human reviews and decides between options)

## Recommendation

**DEFER** (filing-time recommendation).

T-1906 just shipped structural prevention; recurrence is closed. Historical 15 WARNs are low-priority noise — signal-to-noise ratio improves naturally as new inceptions accumulate artefacts and old ones complete and archive.

**Promotion criterion:** human decides the WARN list is distracting enough to warrant a 30-min cleanup batch, OR an audit policy decision (option 3) is made.

If promoted, recommended path: option 3 (temporal cutoff) — minimal risk, zero fabrication, and the audit detector's purpose (prevent future drift) is already served by T-1906.

## Cross-references

- T-1906 — the prevention this backfill complements
- T-1717 — origin grill that surfaced the C-001 advisory→structural gap
- T-1903 — sibling cleanup-vs-prevention task (archive-eligible sweep verb)
- T-194 / T-226 — historical C-001 / G-009 enforcement work (predecessor)
- `.context/audits/2026-05-18.yaml` — the audit cycle that surfaced the 15 WARNs
- CLAUDE.md §Inception Discipline rule 6 — the rule T-1906 made structural
- L-405 — advisory → detective → preventive ladder pattern
