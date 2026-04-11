# T-1112 — Cron Registry vs /etc/cron.d/ Divergence: RCA + Consumer Remediation

**Status:** Captured 2026-04-11 after the user asked "why are cron jobs still not running". Investigation revealed not a failure but a divergence: cron jobs ARE running, but only 10 of the 11 registry-listed jobs are actually installed.

---

## Symptom

User observed pickup-process not firing despite `fw cron status` showing it as active.

## Investigation

1. `bin/fw cron status` reports 11 jobs active from `.context/cron-registry.yaml`.
2. `/etc/cron.d/agentic-audit-999-agentic-engineering-framework` has 10 schedules installed and firing correctly (audit files written at `.context/audits/cron/*.yaml` every 15–30 min; latest `2026-04-11-2330.yaml` at 23:30:09).
3. Missing from /etc/cron.d/: `pickup-process` (*/15 * * * *).
4. `.context/pickup/inbox/` directory does not exist — confirming pickup-process has never fired.
5. `bin/fw cron generate --dry-run` writes `.context/cron/agentic-audit.crontab` with all 11 entries and then says "Install with: fw audit schedule install" — a manual second step.
6. Stray `/etc/cron.d/agentic-audit` (no project suffix) points at `/opt/3021-Bilderkarte-tool-llm` — leftover from a prior install, not interfering but polluting `/etc/cron.d/` namespace.

## Root cause

**Two parallel cron management systems with no structural binding — L-006 enumeration-divergence at the system layer:**

1. **Legacy system (T-184/T-196):** `fw audit schedule install` writes directly to `/etc/cron.d/agentic-audit-<project>`. Source of truth for what's actually installed.
2. **New registry system (T-604):** `fw cron status` / `fw cron generate` operates on `.context/cron-registry.yaml` and writes a git-tracked `.context/cron/agentic-audit.crontab`. Source of truth for what *should* be installed.

The two systems are joined only by the human convention "run `fw audit schedule install` after `fw cron generate`". When `pickup-process` was added to the registry, the install step was never re-run. Registry and runtime diverged silently.

**Class:** L-006 enumeration-divergence (same as G-024/G-037/G-038/G-039/G-040/G-041/G-042/G-043). Two parallel lists of the same logical thing (installed cron jobs), no structural invariant binding them.

## Consumer impact

The same divergence affects **every consumer project** that has ever run `fw audit schedule install`. `/etc/cron.d/` currently has:

- `agentic-audit` — stale, points at /opt/3021-Bilderkarte-tool-llm (no project suffix; predates T-604)
- `agentic-audit-150-skills-manager`
- `agentic-audit-999-agentic-engineering-framework`
- `agentic-audit-termlink`

Any registry updates in any of these consumers have silently diverged from their installed crontab. The problem is systemic across the 11-consumer-project fleet on this host.

## Hypotheses ruled out

| H | Description | Status |
|---|---|---|
| H1 | Cron daemon not running | RULED OUT — `systemctl is-active cron` = active |
| H2 | Registry YAML malformed | RULED OUT — parses cleanly, `fw cron status` renders 11 jobs |
| H3 | `fw cron generate` broken | RULED OUT — dry-run produces correct 11-entry output |
| H4 | Permission issue writing /etc/cron.d/ | PARTIALLY — new registry system would need sudo if it tried to install (it doesn't try) |
| H5 | Registry and runtime diverged (TWO SYSTEMS) | **CONFIRMED** — root cause |

## Proposed fix (two-layer chokepoint)

### Immediate (unblock pickup-process)
Run `fw audit schedule install` to push the 11-job crontab to `/etc/cron.d/agentic-audit-999-*`. Single command, root privilege required.

### Structural (T-1113a..e build tasks after GO)
**C1 — Collapse `fw cron generate` + `fw audit schedule install` into single command** (`fw cron install`) that:
1. Generates the crontab from registry YAML
2. Computes diff against `/etc/cron.d/agentic-audit-<project>`
3. Writes atomically (via `sudo install` or equivalent) if diff is non-empty
4. Emits pass/fail status with diff summary
5. No more "two-step human convention" — one command does both.

**C2 — `fw doctor` invariant check** comparing registry to installed crontab and warning on drift. This is the "invariant test" paired with the C1 chokepoint per T-1105 discipline.

**C3 — Stray cron file sweep** — detect and warn on `/etc/cron.d/agentic-audit` without a project suffix (stale T-3021 install). `fw doctor` suggests removal.

**C4 — Consumer remediation** — document a `fw consumers audit` or `fw consumers sync-cron` command that iterates across all registered consumer projects (via `fw doctor` consumer list) and reinstalls their cron files. Required once C1 lands.

### Invariant tests

1. `tests/integration/cron-install-syncs-registry.bats` — modify registry, run `fw cron install`, assert `/etc/cron.d/agentic-audit-<project>` matches exactly.
2. `tests/integration/fw-doctor-flags-cron-drift.bats` — add a job to registry without install, run `fw doctor`, assert non-zero exit + drift message.
3. `tests/lint/no-stray-cron-files.bats` — assert no `/etc/cron.d/agentic-audit` without project suffix.

## Relationship to other L-006 work

This is the **ninth confirmed L-006 instance** in 24 hours:
- G-024 (do_upgrade vs do_vendor)
- G-024-NEW-07 (agent_dirs string)
- G-037 (excludes lists)
- G-038 (tasks.py enums)
- G-039 (config registry triple-mirror)
- G-040 (owner enum)
- G-041 (active-status 7+ mirrors)
- G-042 (hook usage list)
- G-043 (fw subcommand list)
- **T-1112 (cron registry vs /etc/cron.d/)** ← this task

Pattern density now crosses a threshold: **the L-006 bug class is not a handful of local bugs — it's the framework's default failure mode for any concept that needs to exist in two places.** T-1110 (framework enum sweep) handles the in-process cases. T-1112 handles the cross-process (cron) case. Both descend from T-1105 (chokepoint+invariant-test discipline).

## Recommendation (preview)

**GO** — fix immediately for this project (1-command), create build tasks T-1113a..e for structural fix + consumer remediation, register as new gap G-044.

## Scope fence

**IN:** RCA; immediate unblock; structural fix sketch; consumer remediation plan; relationship to L-006 pattern family.

**OUT:** Actual code edits (T-1113a..e after GO); rewriting the stale T-3021 cron file (out of our boundary per cross-repo rules); scheduling changes to existing jobs.
