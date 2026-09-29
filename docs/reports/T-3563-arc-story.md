# T-3563 — An arc should carry its story

Research artefact (C-001). Opened 2026-09-29.

## Dialogue Log

### Segment 1 — operator, verbatim

> Ok, additional thought and I really want you to reflect this and I want you to get
> external consultation, 3 agents. Headline mechanics for our ARC. Describe what our ARC
> is, describe what AEF is, describe how it's used for vendor projects, how we use ARC
> drivers, how we use it to container a feature or an initiative and also do the scoring
> scoping. We derive back on project objectives and goals from the ARC drivers and
> evaluation of ARC is complete and task are complete. So I really think there should be
> way more emphasis on headline of an ARC that describes what it is, what's the
> background, research decisions made, back and forth. All the context fabric that we've
> created in our, often in our inception.

## Findings

### F-1 — The story exists; the arc does not show it

Measured 2026-09-29 across all 20 arcs in `.context/arcs/`:

| | count |
|---|---|
| arcs with an `anchor_task` | 19 |
| … whose anchor is an inception | 14 |
| … whose anchor has a research report in `docs/reports/` | 14 |
| arcs with `design_doc` set | **1** |
| arcs with `decision` set | **1** |

`headline_mechanic`: median 46 words, maximum 165. `description`: median 34 words.

Example headline (continuous-run), which is typical: *"agent crosses the
context-budget threshold without operator relay -> checkpoint.sh fires self-trigger ->
handover + resume via claude-fw -> operator observes multi-cycle continuous session
whose iteration counter, directive, and bounded tier-ceiling are visible in fw resume
status"*. That is a precise demo check, and it tells a newcomer nothing about why the
arc exists or what was decided along the way.

### F-2 — Why the headline is shaped this way

G-062 (T-1667, T-1671) made `headline_mechanic` mandatory and rejects substrate-only
phrasing. Its job is to force a *user-visible, demo-able* claim, so an arc cannot close
on "the substrate is in place". It succeeded at that job. It was never designed to
explain the arc, and nothing else on the arc was either.

External review brief: `T-3563-external-review-brief.md`.
