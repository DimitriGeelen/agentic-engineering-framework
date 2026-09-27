# rules

> Watchtower detection rules — challenge, opportunity and strength rule functions over scanner inputs

**Type:** script | **Subsystem:** watchtower | **Location:** `web/watchtower/rules.py`

## What It Does

web/watchtower/rules.py

### Framework Reference

- **One task = one deliverable.** If a task has multiple independent spikes or deliverables, decompose it.
- **One bug = one task.** Never compound multiple independent bugs into a single ticket. Each bug has its own root cause, fix, and regression test. Compounding destroys causality traceability and dilutes episodic memory.
- **One inception = one question.** An inception task should explore one problem and produce one go/no-go decision. "Umbrella inceptions" that bundle independent explorations create all-or-nothing decisions and coarse progress tracking.
- **Target: fits in one session.**

*(truncated — see CLAUDE.md for full section)*

## Used By (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [test_scan](/docs/generated/web-watchtower-test_scan) | called_by | Test suite for the Watchtower scan engine (scanner/rules/prioritizer/feedback), colocated in web/watchtower/ |
| [test_scan](/docs/generated/web-watchtower-test_scan) | uses_by | Test suite for the Watchtower scan engine (scanner/rules/prioritizer/feedback), colocated in web/watchtower/ |

---
*Auto-generated from Component Fabric. Card: `web-watchtower-rules.yaml`*
*Last verified: 2026-09-08*
