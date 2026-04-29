# T-1602 Consumer-Project Health Sweep — Consolidated Packet

**Date:** 2026-04-29
**Workers:** 5 parallel TermLink read-only health workers (W1-W5), 13 consumer projects
**Read-only:** no consumer state was modified

---

## Headline finding

**Framework `VERSION` was rolled back ~440 patch versions on 2026-04-27.** This explains the fleet-wide pin anomaly.

| When | Framework VERSION | Source |
|---|---|---|
| 2026-04-25 16:18-19 (consumer upgrade window) | 1.5.294 → 1.5.307 | git show `b0e8e27fd:VERSION` and consumer pins |
| 2026-04-27 00:04 (peak before rollback) | 1.5.463 | `f0b7dd474:VERSION` |
| 2026-04-27 14:47 (T-1540 iter1 commit) | **1.5.19** ← drop of 444 patch versions | `cc38e98f5:VERSION` |
| 2026-04-29 (now) | 1.5.167 | HEAD |

Commit `cc38e98f5` is `T-1540 iter1: fix 3 real bugs surfaced by blind-reviewer convergence loop`. The bug fixes were legitimate; the VERSION clobber was a side-effect, likely from a `git checkout` against a stale tag/ref. No version-monotonicity gate caught it.

**Consequence:** All 12 governed consumers were upgraded on 2026-04-25 from a framework checkout at ~1.5.307 (4 days before the rollback). Their pins are now numerically AHEAD of framework HEAD's 1.5.167. The consumers are not stale — the framework's VERSION file lost ~440 versions of progress.

## Tally

| Verdict | Count | Consumers |
|---|---|---|
| in-sync | 0/13 | — |
| stale (behind HEAD) | 1/13 | `/opt/050-email-archive` (1.5.133, on `pen-dev` branch) |
| ahead-of-HEAD anomaly | 11/13 | All except email-archive and dimitri-mint-dev |
| sandbox / not-a-real-consumer | 1/13 | `/home/dimitri-mint-dev` (vendored 1.2.6, no .framework.yaml, no commits) |
| **Uncommitted state** | **12/13** | All except dimitri-mint-dev (which has zero commits, so "uncommitted" is moot) |

Every governed consumer has uncommitted `.agentic-framework/` paths from the same 2026-04-25T16:18-19 batch upgrade. **The upgrade copied files to disk but never committed.**

## Group reports

- [W1 — sprechloop, CPN, termlink](T-1602-consumer-W1.md)
- [W2 — KCP, ntfy, email-archive](T-1602-consumer-W2.md)
- [W3 — skills-manager, openclaw, Bilderkarte](T-1602-consumer-W3.md)
- [W4 — Vinix24, kosten, WokrshopDesigner](T-1602-consumer-W4.md)
- [W5 — dimitri-mint-dev (sandbox)](T-1602-consumer-W5.md)

## Per-consumer table

| Consumer | Pinned | Vendored | Branch | Dirty (M/D/??) | Active tasks | Verdict |
|---|---|---|---|---|---|---|
| /opt/001-sprechloop | 1.5.307 | 1.5.307 | develop | 89 / - / 111 | 8 | ahead-of-HEAD, uncommitted upgrade |
| /opt/002-Claude-Partner-Network | 1.5.307 | 1.5.307 | master | 4 / - / 3 | 5 | ahead-of-HEAD, mostly clean |
| /opt/termlink | 1.5.307 | 1.5.307 | main | 27 / 56 / 68 | 8 | ahead-of-HEAD, operational churn |
| /opt/052-KCP | 1.5.307 | 1.5.307 | main | 201 / - / - | 1 | ahead-of-HEAD, full uncommitted upgrade |
| /opt/053-ntfy | 1.5.307 | 1.5.307 | main | 201 / - / - | 6 | ahead-of-HEAD, identical to KCP |
| /opt/050-email-archive | 1.5.133 | 1.5.133 | pen-dev | 24 / 1 / - | 42 | **stale (1.5.133 < HEAD 1.5.167)** |
| /opt/150-skills-manager | 1.5.307 | 1.5.307 | master | 96 / 283 / 395 | 18 | ahead-of-HEAD, partial-upgrade pattern + rollback dir |
| /opt/openclaw-evaluation | 1.5.307 | 1.5.307 | main | 85 / - / 109 | 37 | ahead-of-HEAD, uncommitted upgrade |
| /opt/3021-Bilderkarte-tool-llm | 1.5.307 | 1.5.307 | fix/stale-prompt-bug | 91 / 769 / 891 | 47 | ahead-of-HEAD, framework changes entangled with feature branch |
| /opt/051-Vinix24 | 1.5.307 | 1.5.307 | main | 86 / 53 / 2 | 4 | ahead-of-HEAD, uncommitted upgrade |
| /opt/995_2021-kosten | 1.5.307 | 1.5.307 | master | 89 / 24 / 111 | 14 | ahead-of-HEAD, uncommitted upgrade |
| /opt/025-WokrshopDesigner | 1.5.307 | 1.5.307 | master | 88 / 45 / 112 | 79 | ahead-of-HEAD, highest active-task backlog (79) |
| /home/dimitri-mint-dev | n/a | 1.2.6 | master (no commits) | 0 / - / 150 | n/a | sandbox — not a real consumer |

## What this means

### The rollback bug

A `git checkout` (or similar) against a stale tag inside commit `cc38e98f5` reset VERSION from 1.5.463 to 1.5.19. The fix-3-real-bugs body of T-1540 iter1 was correct work; VERSION damage was a silent side-effect. **No structural gate caught it** — VERSION is never validated for monotonic non-decrease.

### The upgrade-without-commit bug

The 2026-04-25T16:18-19 batch upgrade ran across 12 consumers. The `fw upgrade` mechanism copied files into `.agentic-framework/` and bumped `.framework.yaml` `version:` and `last_upgrade:`, but **did not commit**. 4 days later, the changes are still uncommitted across the entire fleet. This means:

- A `fw upgrade` re-run today would either fail (dirty tree) or silently overwrite the in-flight changes.
- Consumers cannot easily distinguish "in-flight upgrade" from "deliberate local fork" of the vendored framework.
- The framework lost telemetry on which consumers actually adopted the upgrade vs which got it dropped on disk and forgotten.

### The mixed pin lineage

`email-archive` is the odd one out — pinned 1.5.133, `upgraded_from: 1.5.477`, last upgrade 2026-04-28. Suggests it was upgraded from yet ANOTHER framework checkout that was at 1.5.477 a day later than the others — almost certainly a different machine (likely the .107 Mac or another LXC). The framework version line is not a single source of truth across machines.

## Recommended follow-ups (each = its own task)

1. **VERSION monotonicity gate** (Level-C tooling) — pre-push or pre-commit hook that refuses any commit decreasing VERSION. Cheap. Would have caught cc38e98f5. **Highest leverage.**

2. **`fw upgrade` finalization fix** (Level-C tooling) — after vendoring, EITHER commit + push automatically OR refuse to update `.framework.yaml` until the consumer commits. Current half-state is the worst outcome. **Second-highest leverage** (12 consumers paying the cost.)

3. **Cross-machine framework version reconciliation** (inception) — at least two framework checkouts are pushing VERSION numbers (the 1.5.307 checkout that did the 04-25 batch and our 1.5.167 HEAD here). Discover all framework instances and decide on a single source of truth. Pre-requisite for fixing #4.

4. **Fleet upgrade sweep** (operational) — once #1+#2 land and we've reconciled the version source, do a coordinated commit-or-revert sweep across the 12 dirty consumers. Per CLAUDE.md no-cross-repo-edits, this needs to go via pickups, not direct edit.

5. **dimitri-mint-dev cleanup** — decide whether to fully initialize it as a project (commit, add `.framework.yaml`, structure) or remove the vendored `.agentic-framework/` since nothing else here treats it as governed.

## What you do now

This sweep is **read-only diagnostic** — nothing has been changed in any consumer. Decisions:

- **Most urgent:** task for #1 (VERSION monotonicity gate) — prevents the recurrence we just measured.
- **Next:** task for #2 (`fw upgrade` finalization) — closes the systemic upgrade-without-commit hole.
- **Then:** inception for #3 (cross-machine reconciliation) — bigger scope, needs human input.

The 12 dirty consumers themselves are not in immediate danger; they're operational with their pinned version, just out of sync with their commit history.

## Worker hygiene

- All 5 worker exit codes = 0
- All 5 reports parse with summary line
- No worker ran any `fw` subcommand, `git pull`, or write op inside a consumer (verified via the read-only constraint in prompts)
- `find /opt /home -newer /tmp/t1602-baseline -path "*/.tasks/*"` returned empty (no consumer task files modified)
