# Orphaned cron entries — backup before removal (T-3281, G-103)

Copies of the six `/etc/cron.d/agentic-audit-proj-schedule-install*` entries as
they stood on **2026-09-05**, taken before handing the operator a removal command.
They are here so removal is reversible without reconstructing anything by hand.

## What these are

Left behind by temp-dir test-fixture installs. Each declares a `PROJECT_ROOT`
under `/tmp` that no longer exists:

| File | Declared PROJECT_ROOT | State |
|------|----------------------|-------|
| `agentic-audit-proj-schedule-install` | `/tmp/tmp.wVw10F3uGw/proj-schedule-install` | gone |
| `agentic-audit-proj-schedule-install-4afedaec` | `/tmp/tmp.4xy62tWgm4/proj-schedule-install` | gone |
| `agentic-audit-proj-schedule-install-76854ad3` | `/tmp/tmp.ZKbeeoD163/proj-schedule-install` | gone |
| `agentic-audit-proj-schedule-install-baa83268` | `/tmp/tmp.dGq1JyvsnQ/proj-schedule-install` | gone |
| `agentic-audit-proj-schedule-install-cce5bb73` | `/tmp/tmp.B4nYVo1Mz9/proj-schedule-install` | gone |
| `agentic-audit-proj-schedule-install-ef7ae545` | `/tmp/tmp.knKrmxrmbs/proj-schedule-install` | gone |

Each contains two lines — a `*/30` structural audit and a `0 * * * *` traceability
audit — both invoking `/opt/999-Agentic-Engineering-Framework/bin/fw`.

## Why they are not harmless

`bin/fw` classifies the vanished root as stale, re-resolves, finds no usable cwd
(cron supplies none) and falls back to `FRAMEWORK_ROOT`. So all six audit **this**
repo. Unlike registry-generated entries they carry no per-job `/var/lock` flock
(T-1331/T-1558), so they do not deduplicate each other: twelve extra audit
invocations per hour queue on `.context/locks/audit.lock` and hold it for minutes
at a time. Every pre-push audit gate then fails with *"Another audit is already
running — exiting (no verdict produced)"*.

## Removal

```
cd /opt/999-Agentic-Engineering-Framework && sudo rm -f /etc/cron.d/agentic-audit-proj-schedule-install /etc/cron.d/agentic-audit-proj-schedule-install-4afedaec /etc/cron.d/agentic-audit-proj-schedule-install-76854ad3 /etc/cron.d/agentic-audit-proj-schedule-install-baa83268 /etc/cron.d/agentic-audit-proj-schedule-install-cce5bb73 /etc/cron.d/agentic-audit-proj-schedule-install-ef7ae545
```

Nothing in this repo depends on them. They are not in `.context/cron-registry.yaml`
and never were — that is the whole reason they went unnoticed.

## Restore

```
cd /opt/999-Agentic-Engineering-Framework && sudo cp -p docs/reports/T-3281-orphan-cron-backup/agentic-audit-proj-schedule-install* /etc/cron.d/
```

## Verify afterwards

```
cd /opt/999-Agentic-Engineering-Framework && bash -c 'source lib/cron-orphans.sh; cron_orphan_scan /etc/cron.d "$PWD/bin/fw"'
```

Prints one `file<TAB>dead-root` line per remaining orphan; silence means clean.

## What this does NOT fix

The reason an orphan is created at all — `bin/fw` silently re-targeting a vanished
`PROJECT_ROOT` onto `FRAMEWORK_ROOT` instead of refusing — is untouched. That is
**G-103 defect A**, still open. Removing these six clears the current lock
starvation; it does not stop the next torn-down worktree or temp-dir install from
producing another.
