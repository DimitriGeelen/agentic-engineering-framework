---
id: T-1261
name: "Consumer cron-registry seeds empty — fw cron install wipes audit schedule on vendored installs"
description: >
  Inception: Consumer cron-registry seeds empty — fw cron install wipes audit schedule on vendored installs

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-04-15T09:56:07Z
last_update: 2026-04-15T09:57:21Z
date_finished: null
---

# T-1261: Consumer cron-registry seeds empty — fw cron install wipes audit schedule on vendored installs

## Problem Statement

Field report (2026-04-15, `/003-NTB-ATC-Plugin`): on a **fresh vendored install**,
running `fw cron install` proposes to DELETE the entire legacy 7-job audit crontab
and replace it with a nearly-empty file (just `SHELL` + `PATH`). `fw cron generate`
confirms: "0 active, 0 paused (0 total)". The user then ran `fw audit schedule install`
(legacy path) which re-installed the 10-job audit+docs+retention crontab from a
hardcoded template — bypassing the registry entirely.

**Root cause (confirmed, two lines of code):**
- `lib/init.sh:157-162` — on `fw init`, seeds `.context/cron-registry.yaml` with literal `jobs: []`
- `lib/upgrade.sh:305-314` — on `fw upgrade`, same seed when file absent

So every consumer project on this host ships with an **empty cron registry**. The
`fw cron` system and the `fw audit schedule` system agree on file paths and slug
naming (T-1112/T-1113) but **disagree at the seed level**: the registry starts
empty, the legacy template has 10 jobs.

**Compounding:** `fw cron install` has no safety check when the generated crontab
would remove >N existing jobs from a populated `/etc/cron.d/` target — it happily
proposes a destructive diff and applies on confirm. A single `fw cron install` on
any existing consumer wipes the audit schedule that was silently keeping the
project healthy.

**For whom:** every consumer project that has ever run `fw audit schedule install`
(which installs 10 jobs from a hardcoded template) and later receives an upgrade
or re-init (which seeds `jobs: []`). After that, `fw cron install` is a trap.

**Why now:** user hit the trap live; audit cron is the primary mechanism by which
the framework maintains project health, discovery trends, and operational
effectiveness checks. A silent wipe means the consumer stops self-auditing.

**Class relationship:** same L-006 enumeration-divergence class as T-1112/T-1113,
but at a different layer — T-1112 was "two populated systems drift", this is
"two systems seeded differently so they were never in sync from day 1."

## Assumptions

- A1: **The 10 legacy audit jobs are the consumer-safe default.** Framework repo's
  `.context/cron-registry.yaml` has 12 jobs; `release-weekly` and possibly
  `pickup-process` may be framework-dev-specific and should NOT be seeded for
  consumers. Needs confirmation.
- A2: **Every consumer on this host is affected.** T-1112 RCA named 4 consumers;
  the seed-empty bug means all of them risk a destructive `fw cron install`.
- A3: **A safety guard in `fw cron install` is orthogonal to the seed fix.** Even
  after seeding defaults, some consumer may legitimately have an empty registry
  (e.g., non-audit project) — the guard prevents accidental wipe regardless of
  cause.
- A4: **Template-file seed is cleaner than inline heredoc.** A new
  `templates/cron-registry-default.yaml` (or `.agentic-framework/templates/...`)
  gives one place to edit the consumer defaults instead of maintaining two
  heredocs (init.sh + upgrade.sh).
- A5: **The legacy `fw audit schedule install` command should be deprecated, not
  removed.** Existing crons still reference it; removing it would break upgrade
  ordering.

## Exploration Plan

- **Spike A (5 min) — Confirm consumer defaults:** Diff the framework's 12-job
  `.context/cron-registry.yaml` against what `fw audit schedule install`
  hardcoded template used to install (read T-1112 research artifact). Identify
  which jobs are consumer-safe vs framework-dev-only. Output: list of N jobs to
  seed.
- **Spike B (5 min) — Audit the blast radius:** Enumerate `/etc/cron.d/agentic-audit-*`
  on this host. For each, compare the populated crontab against the consumer's
  `.context/cron-registry.yaml` job count. Report consumers whose next `fw cron install`
  would wipe jobs.
- **Spike C (5 min) — Safety guard design:** Sketch the logic for `fw cron install`
  refusing/prompting when install-diff would remove >50% of existing jobs.
  Decide: hard block (require `--force`) or prompt for confirmation with a clear
  warning.
- **Spike D (10 min) — Template vs heredoc:** Test whether init.sh/upgrade.sh
  can read a template file from `$FRAMEWORK_ROOT/templates/` and copy it into
  `$PROJECT_ROOT/.context/cron-registry.yaml`. Confirm no chicken-and-egg
  problem (e.g., consumer has no `$FRAMEWORK_ROOT` yet during init).
- **Spike E (5 min) — Idempotency:** Confirm that seeding defaults on a consumer
  that already has a populated registry is a no-op (`[ ! -f ... ]` guard
  already present in both init.sh and upgrade.sh — verify).

## Technical Constraints

- `fw init` runs before framework is vendored in some flows — template must live
  in framework repo at a stable path (`$FRAMEWORK_ROOT/templates/` or
  `.agentic-framework/templates/` in consumer)
- Cross-repo edit rule (durable user instruction): any consumer-side change must
  be initiated from the consumer's own `fw` invocation, not from the framework repo
- `/etc/cron.d/` writes require root/sudo — existing pattern in `fw cron install`
  already degrades gracefully
- `fw cron install` must remain idempotent — running twice with no registry
  change is a no-op
- Consumer `cron-registry.yaml` is git-tracked — seeding defaults must produce a
  diff the user can review+commit, not an auto-applied silent change

## Scope Fence

**IN:**
- Confirm the bug class and root cause at both surfaces (seed + safety)
- Identify consumer-safe default job list
- Propose fix with bounded LOC and test coverage
- Enumerate affected consumers on this host
- Recommendation with GO/NO-GO/DEFER + build decomposition

**OUT:**
- Actually fixing init.sh/upgrade.sh (that's the follow-up build task after GO)
- Rewriting the legacy `fw audit schedule install` (kept as deprecated alias
  per T-1113)
- Redesigning the cron-registry schema (out of scope — registry format is fine)
- Cross-machine remediation (one host at a time)

## Acceptance Criteria

### Agent
- [ ] Problem statement validated
- [ ] Assumptions tested
- [ ] Recommendation written with rationale

### Human
- [ ] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `fw task review T-XXX` (opens Watchtower with recommendation, assumptions, research artifacts)
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

<!-- Fill these BEFORE writing the recommendation. The placeholder detector will block review/decide if left empty. -->
**GO if:**
- Root cause identified with bounded fix path
- Fix is scoped, testable, and reversible

**NO-GO if:**
- Problem requires fundamental redesign or unbounded scope
- Fix cost exceeds benefit given current evidence

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).

## Recommendation

<!-- REQUIRED before fw inception decide. Write your recommendation here (T-974).
     Watchtower reads this section — if it's empty, the human sees nothing.
     Format:
     **Recommendation:** GO / NO-GO / DEFER
     **Rationale:** Why (cite evidence from exploration)
     **Evidence:**
     - Finding 1
     - Finding 2
-->

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Decision

<!-- Filled at completion via: fw inception decide T-XXX go|no-go --rationale "..." -->

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-15T09:57:21Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
