# issues

> Issue tracker for known problems and their resolution status.

**Type:** data | **Subsystem:** context-fabric | **Location:** `.context/project/issues.yaml`

**Tags:** `context`, `project-memory`

## What It Does

Issue Register — Past incidents and materialized risks (T-194)
An issue = a risk that materialized. Links back to risks.yaml via related_risk.
Schema:
id: I-XXX
title: Short description of what happened
date: When it occurred (YYYY-MM-DD)
related_risk: R-XXX (from risks.yaml)
related_tasks: [T-XXX] (tasks where it was observed/fixed)
description: What happened
impact: What was the consequence

## Related

### Tasks
- T-194: ISO 27001-aligned assurance model — control register, OE testing, risk-driven cron redesign

---
*Auto-generated from Component Fabric. Card: `context-project-issues.yaml`*
*Last verified: 2026-03-04*
