I've read the proposal and the related machinery (CLAUDE.md §ACD, arc-008, objectives, the T-3621 baseline, BVP auto-promote and T-3637). Here is the review.

1. IS THE CONCEPT SOUND?
Yes. It fixes a real problem. The arc model only has finishing-shaped containers, so continuous work (audit WARNs, escalated inceptions) has no home and builds up as unowned noise. The new risk is laundering, not just a graveyard. The drain counts "bundle" as an exit, so a sweep can merge 25 parked items into one parked task and every health rail goes green while nothing gets fixed. The drain is not strong enough until health measures resolved items (fixed, or won't-fix with a reason), not open-item count.

2. PER ANSWER
1. Lifecycle: change. Keep the §ACD create gate: a standing arc still needs a headline mechanic, for example "operator sees FW-001 flow and age and every exit has a reason". Exempt it only from the close gate and the stale WARN. Add a human-only retire path. There are two age clocks (a 30-day WARN and a 60-day forced action), and "parked with a reason" will become boilerplate when parked is the normal state. Use one 60-day clock. "Grows 4 weeks running" resets after one flat week. Use net growth over a rolling 4 weeks instead.
2. Intake: change. "7 consecutive days" misses flapping WARNs. Use "seen on 5 of the last 7 audits", deduplicated by check name plus scope. A won't-fix needs a suppression record so the same WARN doesn't come back in. Don't turn the 373 observations into tasks; link them by tag and only create a task at triage. As far as I can find, `fw note triage` doesn't exist (`fw triage route` handles hub messages), so the build must name the real verb.
3. Drain: change. Bundling should not reduce the count used by the health rails. Make the weekly worker's cost visible under O-6, with a budget per sweep. A won't-fix needs an independent reviewer verdict, not the sweeping agent's own word. 25 items is fine as a starting point, but measure today's FW-001 intake first.
4. Scoring: reject the median threshold. By definition about half of all intake would be promoted at once, which defeats parking. A relative median also drifts, and T-3485 already records the median equality defect. Use the existing auto_promote band (bvp_norm ≥0.85, cost ≤1, max_concurrent 1) as the intake promote rule, and park everything else.
5. Naming and first set: change. Drop FW-003 (point 4). Don't absorb arc-008. Its headline (two-click decide plus feedback) is a deliverable: close it through §ACD with a demo, then let FW-002 hold the ongoing queue.

3. INTERACTION WITH EXISTING MACHINERY
- §ACD: `fw arc close` already refuses under an agent. Standing arcs need an explicit branch in close readiness and must be excluded from the /approvals close-ready list.
- Stale-arc WARN: it is keyed on commits to member tasks, so parked arcs would trip it. The exemption is right.
- T-1931: two promote paths would double-count. Use one.
- T-3621 baseline: it already has a 14-day expiry, owner tasks and a regenerate step. FW-003 would run a second clock over the same items.
- T-3637: standing arcs declare `supports:`, so they only need the stale half exempted. Exempting the whole rail lets a standing arc go without any objective.
- The `arc_id` validation hook must accept FW-NNN ids.

4. OBJECTIVE MAPPING
FW-001 → O-1 and O-3 is right, with O-3 as the main one: declinable low value. FW-002 → O-3 and O-2 is right. FW-003 doesn't get its own arc. Expired baseline entries should flow into FW-001 intake, with the baseline file staying the source of truth.

5. WHAT IS MISSING
- The task state of parked items: their status and horizon, whether they count toward WIP, focus, handover or `fw work-on`.
- How FW-NNN ids live alongside arc-NNN ids and slugs.
- A health metric based on resolved-per-week.
- What happens when the sweep worker fails, or its cost hits the ceiling.
- Migration of the current WARN backlog.
- Watchtower surfaces: the flow/age chart and the won't-fix review.
- A human retire verb.

6. VERDICT: GO-WITH-CHANGES. The top three changes:
1. Measure drain as resolved items. Bundling doesn't count as an exit, and a won't-fix needs a reviewer verdict.
2. Replace the median intake threshold with the existing auto_promote band, so there is one promote path and parking is the default.
3. Drop FW-003 and feed baseline expiries into FW-001. Close arc-008 on its own demo instead of absorbing it into FW-002.
