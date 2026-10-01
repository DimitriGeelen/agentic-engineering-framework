1. CONCEPT
Sound. The failure mode it fixes is real: arcs are built to finish (headline mechanic, §ACD demo, 30-day stale WARN), so continuous work has no home — 381 pending inbox items, ignored audit WARNs, 114 baselined reds are symptoms of undrained flow. New failure mode: a sanctioned graveyard. The design parks items "with a reason" by definition, so the proposed age WARN ("past 30 days unless explicitly parked with a reason") is extinguishable by the very act the concept is made of — it will never fire. Drain is half-strong: weekly sweep and promote/won't-fix-only exits are right, but 60-day forced action is twice the delivery-arc stale threshold, and "bundle, promote or close" lets a cluster be re-bundled indefinitely while nominally satisfying forced action.

2. PER ANSWER
(1) Lifecycle: agree, except close the parked-reason loophole (age WARN must survive parking; only explicit won't-fix clears it), and define the create path — a flow statement is substrate-only phrasing §ACD rejects today.
(2) Intake: change. "7 consecutive days" assumes daily audits; use N consecutive audit runs. Dedup by check name and repeat-signals-only auto scope: agree, right-sized.
(3) Drain: change. 60d → 30d forced action (match the stale WARN); count bundles, not raw items, against the 25 cap; same cluster cannot satisfy forced action twice.
(4) Scoring: change. Median-of-current-scores is self-referential and ratchets down: parking retains low scores, median falls, more items park. Use the existing policy band (bvp_norm_min 0.85) and define precedence with auto-promote.
(5) Naming/set: change. Merge FW-003 into FW-001 as a tagged cluster; expiry is item-level drain mechanics, not an arc-level distinction. Arc-008 has a demo-able headline (two-click decide) — close it properly under §ACD rather than absorbing it; FW-002 takes only future escalations.

3. INTERACTIONS
- §ACD/close-ready: standing arcs must be excluded from approvals close-ready scans and completion-ratio badges; unspecified.
- Stale WARN / T-3637: "supports nothing AND stale" can't fire on arcs that map objectives, so the requested exemption is only needed by weakly-mapped FW-003 — evidence to merge it, not exempt it.
- T-1931 auto-promote: two BVP-driven promotion paths (per-arc threshold vs global 0.85) can race and double-count; one precedence rule required.
- Inbox / fw note triage: one finding can live as both OBS-xxx and a FW-001 task; promotion must mark the inbox item. Also nothing drains the existing 381.
- T-3621 baseline: entries already have owner tasks and 14-day expiry; parallel FW-003 tasks double-own and outlive the excuse. Admit only reds whose baseline entry expired unfixed.
- Weekly dispatched sweeps are recurring spend — O-6 requires cost logging and approval.

4. OBJECTIVE MAPPING
FW-001 → O-1+O-3: agree. FW-002 → O-3+O-2: agree; operator feedback surviving sessions is O-2's core. FW-003: no — its "weak mapping" is exactly the forced mapping O-3's measure warns against; belongs in FW-001.

5. MISSING
Create verb + schema; enumerated exemption list; "parked" status definition; promote target and executor; won't-fix reason taxonomy with operator visibility; backfill decision for inbox/L-670/114 reds; whether standing arcs get scoped drivers; sweep cost class; flow-ratio reporting on the arc page.

6. VERDICT: go-with-changes.
(1) Close the parked-reason loophole, tighten forced action to 30 days, count bundles against the cap.
(2) Fixed score band + auto-promote precedence instead of a per-arc median.
(3) Merge FW-003 into FW-001 and drop the T-3637 exemption instead of needing it.
