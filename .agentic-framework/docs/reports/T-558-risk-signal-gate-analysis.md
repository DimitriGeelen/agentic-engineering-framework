# T-558: Build Task Risk Signal Detection — Analysis

## Question

Should we add a PreToolUse gate that detects "risk signals" at build time and warns/blocks high-impact builds that should have gone through inception?

## Existing Guards (check-active-task.sh)

| Guard | What it catches |
|-------|----------------|
| B-005 | Agent modifying settings.json |
| Task gate | No active task |
| Status validation | Task not started-work |
| Onboarding gate | Incomplete onboarding |
| Inception awareness | Active inception task (advisory) |
| Build readiness G-020 | Placeholder ACs on build task |
| Fabric advisory | File has N dependents (advisory) |

## Proposed Signals

1. File in `deploy/` or `infrastructure/` — no such directories exist (speculative)
2. File has >3 fabric dependents — already covered by fabric advisory
3. New subsystem directory — hard to detect at write-time
4. Cross-subsystem edits (3+ subsystems) — requires session state tracking, many false positives

## Recommendation

**DEFER** — Existing guards cover the most impactful cases. No incident in project history was caused by the specific failure mode this would prevent.
