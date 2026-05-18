# T-1902 — Watchtower `/arcs/<slug>/close` review surface for human arc closure

**Inception artifact (C-001).** Filed 2026-05-18 by agent; awaiting human inception-decide.

## Problem framing

T-1671 §ACD gate correctly refuses agent-side `fw arc close` under `$CLAUDECODE=1` — closure is strategic judgment, not substrate verification. The gate exists because of four shipped incidents (T-1626 / T-1633 / T-1641 / T-1667 / T-1670) where the agent attempted to participate in closure. Structurally sound.

But the human-side workflow today is raw CLI:

```bash
cd /opt/999-Agentic-Engineering-Framework && bin/fw arc close arc-grooming \
  --demo docs/reports/arc-005-headline-mechanic-demo.md \
  --decision "..."
```

— context-switch to terminal, recall slug + demo path + flag names, type decision string with no preview. `fw task review T-XXX` solved the equivalent friction for task approvals (T-679). The arc-level twin is missing.

Evidence: arc-grooming has 32/32 constituent tasks `work-completed`, demo artefact captured at `docs/reports/arc-005-headline-mechanic-demo.md`, but `closed_at: null` across multiple sessions because the friction is real.

## Assumptions to validate

1. `lib/arc.sh:779` `--from-watchtower` flag bypasses `$CLAUDECODE=1` refusal — pre-existing exemption.
2. `web/blueprints/tasks.py` task-review surface is the right structural template for the arc-level twin.
3. Prerequisite checks (all-tasks-completed, demo-present, headline-mechanic-non-empty, anchor-completed) can be cleanly factored into a reusable function in `lib/arc.sh` callable from both CLI and web backend.

## Exploration plan (three spikes, time-boxed)

| Spike | Goal | Time-box |
|-------|------|----------|
| 1 | Confirm `--from-watchtower` reaches close path end-to-end (trace `lib/arc.sh:779` → `do_arc_close`) | 30 min |
| 2 | Read `web/blueprints/tasks.py` + `web/templates/task_review*.html` for template pattern; identify minimal delta for arc | 45 min |
| 3 | Design `do_arc_close_preconditions` function signature returning structured status | 30 min |

After spikes, file a small build slice (likely T-1903+) for the implementation.

## Scope fence

**IN:** new `fw arc review <slug>` CLI verb, new `/arcs/<slug>/close` Watchtower page (arc metadata + headline_mechanic + task table + demo preview + recommendation + decision editor + prereq checklist + Approve/Reject), backend POST handler that subprocess-invokes `fw arc close --from-watchtower`, prerequisite checks.

**OUT:** changing §ACD axiom, auto-closing arcs, bulk arc ops, editing `--from-watchtower` exemption mechanism.

## Recommendation: **GO**

Friction is real (arc-grooming parked on closure for days). Exemption mechanism already exists and is tested. No gate weakening — Watchtower IS the human surface, just like `/tasks/T-XXX/review`.

## Origin dialogue

This inception emerged from arc-grooming closure work. The arc-grooming arc has been structurally closure-ready since T-1893 (demo captured) + T-1894 (mis-class re-classed) but the human CLI workflow has parked it. Agent observed during T-1717/T-1729/T-1890 cycle that every "human action" presented at session end was raw CLI; user has corrected this pattern multiple times (see `feedback_human_review_links.md`, `feedback_use_fw_task_review.md`). The structural fix is the Watchtower surface, not better CLI ergonomics.

## Cross-references

- T-1671 — §ACD closure gate ($CLAUDECODE=1 refusal + --from-watchtower exemption)
- T-679 — `fw task review T-XXX` pattern (the precedent this clones)
- T-1626 / T-1633 / T-1641 / T-1667 / T-1670 — the five closure incidents that produced T-1671
- `docs/reports/arc-005-headline-mechanic-demo.md` — demo artefact already captured for arc-grooming closure
- CLAUDE.md §Arc Completion Discipline — the axiom that stays intact under this proposal
