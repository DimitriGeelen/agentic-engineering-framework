---
id: T-2442
name: "Remediate greenfield-onboarding bug-class (dogfood F4/F5/F9/F10)"
description: >
  Batched structural remediation of the four correctness defects found in the T-2441
  live onboarding dogfood: F4 invalid greenfield value-drivers.yaml, F5 session-init
  fails on happy path, F9 Watchtower false-positive health, F10 fw serve misidentifies
  the project. Inception scopes/sequences the fix; F4 is the cleanest first build slice.
status: started-work
workflow_type: inception
target_blast_radius: 4
voi_score: 0.7
owner: agent
horizon: now
tags: [onboarding, remediation, dogfood, high-prio]
related_tasks: [T-2441]
created: 2026-06-21T07:30:00Z
last_update: 2026-06-21T07:30:00Z
date_finished: null
---

# T-2442: Remediate greenfield-onboarding bug-class (dogfood F4/F5/F9/F10)

## Context

The T-2441 live dogfood (real AEF install into the empty `/opt/505-Ring20-Site`) surfaced four
**correctness defects** on the greenfield happy path. They are filed as proposal **P-048** and
evidenced in `docs/reports/T-2441-aef-onboarding-dogfooding.md`. This inception batches them into
one remediation and decides scope + sequencing before any core change (init template / shim routing
are real change sets — not ad-hoc edits).

**The question:** remediate the four as one batch (they share the greenfield-init + bare-fw-routing
region), F4 first as the contained quick win — or split F8/F10 (shim routing, higher blast) into a
separate design? **Recommended:** GO on the batch, F4 first; carve the routing legs out if they grow.

## Batched findings

- **F4 — invalid greenfield `value-drivers.yaml`** *(cleanest first slice)*: `fw init` scaffolds a
  `policy/value-drivers.yaml` missing the required `drivers` key → `yaml-2bv` fails on *every* fresh
  project (1 err / 42). Fix: correct the greenfield template + add a fresh-init bats assertion
  (sibling to `upgrade_fresh_machine_simulation.bats`).
- **F5 — session-init fails on happy path**: `fw init` prints `⚠ Session init failed — run
  'fw context init' manually`. Recovery works; the first-run shouldn't need it. Fix: make init's
  inline session activation succeed greenfield (or auto-run the recovery).
- **F9 — Watchtower false-positive health**: `fw serve` refuses a foreign-held default port (good) but
  starts nothing, while `fw watchtower url` + curl return 200 from the foreign server. Fix: auto-pick a
  free port (or exit non-zero) + verify a project-identity marker before reporting reachable.
- **F10 — `fw serve` misidentifies the project**: from a fresh consumer, `fw serve` logs
  `(project: /opt/999-…)` instead of the consumer. Root: bare-fw global-shim routing (T-1257) /
  shared Watchtower state. Higher blast — may split into its own design slice.

## Acceptance Criteria

### Agent
- [x] Research artifact exists with reproduced evidence + RCA per finding — `docs/reports/T-2441-aef-onboarding-dogfooding.md`
- [x] Findings batched with proposed fix + sequencing recommendation (this task body)

## Recommendation

**Recommendation:** GO — proceed with the batched remediation, F4 first.

**Rationale:** All four are *reproduced* defects with captured wire-level evidence from the dogfood
(not hypotheses), and three (F4/F5/F9) are tractable contained fixes. F4 in particular breaks every
fresh project's own init validation and has an obvious fix + a cheap regression test. They share the
greenfield-init / bare-fw-routing region, so batching the scope avoids four disconnected tasks. F10's
shim-routing root has higher blast radius and may warrant its own design slice — that split is the one
genuine open question, and it does not block starting F4. This is a GO, not a DEFER: the evidence is
complete; only the routing-leg sequencing is open.

**Evidence:**
- `docs/reports/T-2441-aef-onboarding-dogfooding.md` (F1–F10, RCA + remediation)
- Pickup proposals `P-048-bug-report` (F4/F5/F9/F10), `P-049-feature-proposal`
- Dogfood commits `79175f0aa` (artifact + pickups), `7a7165d1c` (hardened install prompt)

## Decision

**Decision**: GO

**Rationale**: All four are *reproduced* defects with captured wire-level evidence from the dogfood
(not hypotheses), and three (F4/F5/F9) are tractable contained fixes. F4 in particular breaks every
fresh project's own init validation and has an obvious fix + a cheap regression test. They share the
greenfield-init / bare-fw-routing region, so batching the scope avoids four disconnected tasks. F10's
shim-routing root has higher blast radius and may warrant its own design slice — that split is the one
genuine open question, and it does not block starting F4. This is a GO, not a DEFER: the evidence is
complete; only the routing-leg sequencing is open.

**Date**: 2026-06-21T07:44:17Z

## Verification

# Inception task — no build artifacts. Reachability of the cited evidence:
test -f docs/reports/T-2441-aef-onboarding-dogfooding.md
test -f .context/pickup/inbox/P-048-bug-report.yaml

## Updates

### 2026-06-21T07:44:17Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** All four are *reproduced* defects with captured wire-level evidence from the dogfood
(not hypotheses), and three (F4/F5/F9) are tractable contained fixes. F4 in particular breaks every
fresh project's own init validation and has an obvious fix + a cheap regression test. They share the
greenfield-init / bare-fw-routing region, so batching the scope avoids four disconnected tasks. F10's
shim-routing root has higher blast radius and may warrant its own design slice — that split is the one
genuine open question, and it does not block starting F4. This is a GO, not a DEFER: the evidence is
complete; only the routing-leg sequencing is open.
