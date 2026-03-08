# risks

> Risk register tracking identified risks with severity, mitigation plans, and current status.

**Type:** data | **Subsystem:** context-fabric | **Location:** `.context/project/risks.yaml`

**Tags:** `context`, `project-memory`

## What It Does

Risk Register — ISO 27001-aligned (T-194)
Likelihood (1-5) × Impact (1-5) = Score (1-25)
Ranking: Low (1-4), Medium (5-9), High (10-16), Urgent (17-25)
Schema:
id: R-XXX
title: Short description
category: governance|context|knowledge|quality|tooling|operational|session|architecture|oversight
description: What can go wrong
likelihood: 1-5 (Rare/Unlikely/Possible/Likely/Almost certain)
impact: 1-5 (Negligible/Minor/Moderate/Major/Severe)

## Related

### Tasks
- T-194: ISO 27001-aligned assurance model — control register, OE testing, risk-driven cron redesign

---
*Auto-generated from Component Fabric. Card: `context-project-risks.yaml`*
*Last verified: 2026-03-04*
