# t3253_preflight_brake

> T-3253 AC3 — the breaching session is never launched.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t3253_preflight_brake.bats`

## What It Does

T-3253 AC3 — the breaching session is never launched.
E10 measured the hole these pin: the ceiling was evaluated in the SessionStart
hook of a session that had ALREADY relaunched carrying the armed directive as
its prompt, so the breach notice arrived as advisory additionalContext and lost
the argument with "do not stop until every task is closed". The over-ceiling
task was closed 4m26s after the brake fired.
These drive the real inject-next-directive.py against a scratch project root,
for the reason continuous_mode_disarm.bats records: a test written against a
transcription of the logic would miss the whole point.
EVERY BRAKE CASE HAS A CONTROL. A refusal that fires for the wrong reason is

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [inject-next-directive](/docs/generated/agents-context-inject-next-directive) | tests | T-2364/T-2365 (T-2158 S2+S3) — next-directive injector for post-compact resume. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3253_preflight_brake.yaml`*
*Last verified: 2026-09-03*
