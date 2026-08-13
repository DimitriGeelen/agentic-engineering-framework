# t2948_review_human_ac_comment_aware

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/t2948_review_human_ac_comment_aware.bats`

## What It Does

T-2948 — lib/review.sh's Human-AC counter was comment-immune BY ACCIDENT.
Its globs are `"- [ ]"*` — whitespace-intolerant — and default.md's commented
example ACs happen to sit indented seven spaces. Nothing in the file recorded
that the indentation was load-bearing. De-indenting those examples (pure
formatting, the kind no reviewer stops) would have made the counter see two
phantom Human ACs on EVERY task created from the template: each fresh build
task reads as partial-complete 0/2 and trips T-2421's rec-gate on work nobody
has started.
Reported by 832 at rail 570 §3, as the negative control of their own census —
the finding came out of explaining why their count was RIGHT.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t2948_review_human_ac_comment_aware.yaml`*
*Last verified: 2026-08-12*
