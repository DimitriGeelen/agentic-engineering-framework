You are an INDEPENDENT design reviewer. The repo /opt/999-Agentic-Engineering-Framework is read-only for you. Do not modify files and do not run anything that writes.

Review the proposal in docs/reports/T-3667-standing-arcs.md: "standing arcs", never-closing arcs where tasks flow in, get scored, park when low-value, and are bundled or mined for patterns. The first set is FW-001 audit findings, FW-002 inception review loop and FW-003 test health. The operator agreed with the framing; you are judging the agent's five proposed answers (lifecycle, intake, drain, scoring, naming and the first set) and the objective mapping.

Context you may read:
- CLAUDE.md, especially §Arc Completion Discipline, the arc-scoped driver workflow, and §Task Sizing;
- .context/project/objectives.yaml (the six project objectives);
- .context/arcs/*.yaml (existing arcs, including inception-review-loop = arc-008);
- docs/reports/T-3535-objectives-v2.md;
- lib/bvp.sh and policy/value-drivers.yaml (BVP scoring);
- docs/reports/T-3621* or .context/audits/unit-suite/baseline.yaml (the test-red baseline);
- `.context/inbox.yaml` (the observation inbox, ~373 pending).

Answer exactly:
1. **Is the concept sound?** What failure mode does it fix, and what new failure mode could it create? The graveyard risk in particular: is the proposed drain strong enough?
2. **Per answer (1-5): agree / change / reject,** with a one-line reason and a concrete alternative where you disagree. Check the thresholds especially (7 days, 25 items, 60 days, a 4-week growth WARN, a median-score threshold) and the auto-intake scope.
3. **Interaction with existing machinery:** the §ACD close gate, the stale-arc WARN, the BVP auto-promote (T-1931), the observation inbox and `fw note triage`, the T-3621 test baseline and its expiry, and T-3637's "supports nothing AND stale" rail. Anything that would conflict or double-count?
4. **Objective mapping:** is FW-001 → objectives 1+3, FW-002 → objectives 3+2 right? Does FW-003 deserve its own arc or belong in FW-001?
5. **What is missing** that the build must specify?
6. **VERDICT:** go / go-with-changes / no-go, with the top 3 changes.

Under 600 words. Plain text output only.
