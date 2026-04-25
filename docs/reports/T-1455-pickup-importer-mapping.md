# T-1455 — Pickup Importer Type Mapping (Inception)

**Status:** awaiting human GO/NO-GO at `/inception/T-1455`
**Origin:** OBS-015 (12 closed bug-fix tasks classified as inception → C-001 audit warning)
**Tension:** T-469 (deliberate force-inception to prevent governance bypass)

## Findings

- `lib/pickup.sh:246-275` (`pickup_create_inception`) reads `pickup_type` from the envelope (line 250) but unconditionally creates the resulting task with `--type inception` (line 262).
- The hard-code is a deliberate guard from T-469: an envelope mislabelled "bug-report" once caused an agent to ship 4 framework-source files without scoping; force-inception was the structural backstop.
- T-1440 surgically silenced the C-001/missing-research audit warning (skip pickups in audit). The misclassification itself was not addressed.
- OBS-015's 12 cases were all `bug-report` envelopes. No mention of misclassified `feature-proposal`, `learning`, or `pattern` envelopes.

## Design space

| Option | Sketch | Cost | T-469 risk |
|---|---|---|---|
| B (status quo) | leave as-is, accept misclass | 0 LoC | safe |
| A (full mapping) | bug-report→build, feature-proposal→inception | ~5 LoC | reopens for feature-proposal mislabels |
| **A-constrained** | bug-report→build only; rest stays inception | ~3 LoC | bounded by bug-fix scope |
| C (hybrid type+size) | type default + heuristic size override | ~50 LoC | depends on heuristic |
| D (envelope flag) | sender opts in via `scope_validated: true` | sender migration | safest, most work |

## Decision (recommended)

**Constrained A.** Bug-fix is scope-constrained by definition (one bug, one fix), and bug-reports are the most type-faithful envelope kind. For all other envelope types — including the high-risk `feature-proposal` — keep the inception default. Net result: OBS-015 friction goes away; T-469's structural protection stays where it matters.

## Implementation sketch (post-GO)

```bash
# lib/pickup.sh, replace line 262
local task_type
case "$pickup_type" in
    bug-report) task_type="build" ;;
    *)          task_type="inception" ;;
esac
```

Plus a unit test in `tests/unit/lib_pickup.bats` asserting:
1. `bug-report` envelope → `workflow_type: build`
2. `feature-proposal` envelope → `workflow_type: inception` (regression for T-469)
3. Unknown type → `workflow_type: inception` (default safe)

## Dialogue Log

- **2026-04-25T14:01Z** — User reported `/inception/T-1455 gives 404`. Root cause: workflow_type=build (not inception) due to missed `--type` flip in OBS-015 promotion. Fixed in T-1458 with both data fix and structural fix (added `--type` flag to `fw note promote`). Scaffolding for T-1455 was carried over from prior session — completed Recommendation block here on user's second flag ("no recommendation, no rationale").

## Out-of-scope follow-up

- Watch the first ~10 `bug-report → build` tasks for any that turned out to need inception. That's the canary for revisiting Option C/D.
- If a feature-proposal-class incident recurs, escalate to Option D (envelope `scope_validated` flag).
