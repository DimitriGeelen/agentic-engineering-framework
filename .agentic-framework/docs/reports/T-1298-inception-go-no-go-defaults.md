# T-1298 — Inception template GO/NO-GO defaults propagate to auto-created tasks

**Source:** termlink pickup (P-???, agent owner)
**Status:** Triaged 2026-04-18 — DEFER
**Related:** T-1322 (RUBBER-STAMP AC auto-tick), T-1111 (placeholder-sections RCA)

## Problem statement

Pickup reports: the inception template ships with generic GO/NO-GO default criteria:

```
**GO if:**
- Root cause identified with bounded fix path
- Fix is scoped, testable, and reversible

**NO-GO if:**
- Problem requires fundamental redesign or unbounded scope
- Fix cost exceeds benefit given current evidence
```

These propagate into every pickup-derived inception. The pickup's framing is that
the problem is "detected only at decide time" — implying a quality issue only
surfaces late in the lifecycle.

## Investigation

### Where do the defaults live?

Only in `.tasks/templates/inception.md` (lines 64–69). Verified with grep — no
other file in the repo contains these literal strings.

### What gates check them?

`lib/task-audit.sh:audit_task_placeholders()` runs at review/decide time and
catches the following literal patterns:

- `[Criterion N]`
- `[TODO]`
- `[PLACEHOLDER]`
- `[Your recommendation here]`
- `[REQUIRED before`

**The generic GO/NO-GO defaults are NOT in this list.** The literal prose
"Root cause identified with bounded fix path" never trips any current detector.

`lib/inception.sh:do_inception_decide` only enforces:
1. Placeholder audit (above — doesn't hit these defaults)
2. Review marker present (`.context/working/.reviewed-T-XXX`)
3. `## Recommendation` section has content beyond comments

No gate currently checks whether Go/No-Go is task-specific.

### Conclusion about the premise

The pickup's premise ("detected only at decide time") is **inaccurate** — the
generic defaults are not detected anywhere. They pass through silently.

## The real concern beneath the inaccurate premise

Whether or not the framework flags them, generic Go/No-Go criteria erode
inception quality:

- If GO means "bounded fix path" for every inception, the criterion is
  non-discriminating (every inception that's actually ready for GO has a
  bounded fix path by definition).
- Humans making decide-calls see identical criteria every time, so the text
  becomes visual noise rather than an actual decision aid.

## Options

| Option | Cost | Benefit |
|--------|------|---------|
| A. Add literal defaults to the detector (block at decide) | 1-line edit + bats test | Forces customization — but every triage pays the cost |
| B. Warn (non-blocking) when defaults unchanged | Small | Nudge, preserves velocity; low signal/noise ratio |
| C. Remove defaults entirely — leave section empty | Medium (template edit + guidance doc) | Clean slate forces thought; but empty section invites skipping |
| D. Change template wording to explicit-prompt style (e.g. "GO if: [specific outcome of exploration]") | Small | Makes it obvious the prose needs editing without adding detection |
| E. Defer — no change; revisit if concrete miss surfaces | 0 | Preserves velocity on triage batch processing; but the quality smell remains |

## Recommendation: DEFER (E)

**Rationale:**

- The pickup's premise — that the framework catches these at decide time — is
  wrong. Nothing catches them. Adding detection would be a new gate, not a fix.
- Generic defaults are acceptable as starting points; T-1322/T-1324's context
  (fast triage of many pickups) argues *against* adding friction to each.
- Real failures caused by this pattern are hypothetical right now. No
  `fw inception decide` has produced a regret the framework could have
  prevented by rejecting generic Go/No-Go.
- If a concrete miss emerges (a task ships with generic Go/No-Go and *should*
  have been NO-GO, but was GO'd because the criteria were too loose), revisit
  with evidence and pick Option B or D at that point.

**Conditions to reconsider (GO later if any materialize):**

- Three or more inception decisions are later regretted and the post-mortem
  traces to generic Go/No-Go criteria that didn't discriminate.
- Human requests a quality gate here explicitly.

## Decision trail

- Source pickup: (agent-owner, termlink)
- Artifact: this file
- Recommendation: DEFER (no change; wait for concrete evidence of miss)
