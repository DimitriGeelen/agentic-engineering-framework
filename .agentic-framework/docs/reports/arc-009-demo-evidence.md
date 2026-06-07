# arc-009 horizon-axis-hardening — Wire-Level Demo Evidence

**Arc:** `.context/arcs/horizon-axis-hardening.yaml` (id: arc-009)
**Captured:** 2026-06-01
**Captured by:** S-2026-0601-1249 successor session
**Slices shipped:** T-2160 (Slice 1 — partial-complete, awaiting human), T-2161 (Slice 2 — done), T-2162 (Slice 3 — done), T-2163 (Slice 4 — done; write-side prevention nulls horizon at close-time in `update-task.sh:1660`; 4 bats green)

## Headline mechanic

> An agent reads the handover 'Work in Progress' section and sees zero work-completed tasks in the now/next buckets — partial-complete tasks (awaiting human ACs) appear in an explicit 'Partial-Complete — awaiting human' footer, completed/ tasks render horizon=past on Watchtower without any stored horizon field, and re-running the migration reports 0 changes.

Five conditions decomposed; each is captured by a wire-level artefact below.

---

## Condition 1 — Handover WIP has zero work-completed entries

**Source:** `.context/handovers/LATEST.md` (S-2026-0601-1249, committed at `390eb258`).

**Method:** Python regex over the `## Work in Progress` section, counting actual `**Status:** work-completed` lines (not substring matches inside task names).

```
$ python3 -c "..."
Actual work-completed STATUS lines in WIP: 0
```

Pre-T-2160, three sub-headings inside `## Work in Progress` ("horizon: now — Awaiting Human Review", "horizon: next — Awaiting Human Review", "horizon: later — Awaiting Human Review") flushed work-completed entries inline with in-flight ones. T-2160 collapsed this into a single bottom footer (see Condition 2).

---

## Condition 2 — "Partial-Complete — awaiting human" footer is present and explicit

**Source:** `.context/handovers/LATEST.md` line 320-ish (varies by session).

```
$ awk '/^### Partial-Complete/{print; exit}' .context/handovers/LATEST.md
### Partial-Complete — awaiting human (137 tasks)
```

Sub-grouped by horizon underneath:

```
**horizon: now** (136)
**horizon: next** (1)
```

Origin: `agents/handover/handover.sh` line ~584-680 — T-2160's single-footer refactor.

---

## Condition 3 — completed/ files render horizon=past on Watchtower without stored value

**Source:** live `/tasks?horizon=past&view=list` endpoint.

```
$ curl -sf "$(bin/fw watchtower url)/tasks?horizon=past&view=list" | grep -oE 'T-21[0-9]+' | sort -u | head -5
T-210
T-2100
T-2101
T-2102
T-2104
```

HTTP 200; page size 7.4 MB; contains completed-task IDs that render with **derived** past rendering even though their stored `horizon:` field is `null` (see Condition 4).

Origin:
- Filter logic: `web/blueprints/tasks.py:~684` — `if horizon_filter == "past": filter on _location == "completed"`
- Template var: `web/blueprints/tasks.py:~755` — `enum_render_horizons=enums["horizons"] + ["past"]`
- Dropdown: `web/templates/tasks.html:437-443` — iterates `enum_render_horizons`

---

## Condition 4 — Zero stored horizon values in completed/ corpus

**Source:** structural scan of `.tasks/completed/T-*.md` frontmatter.

```
$ python3 -c "..."
{'null/absent': 1947, 'non_null': 0}
```

1828 files were migrated by `bin/migrate-horizon-null-completed.sh` (per T-2161 report); 117 were already absent-field (pre-frontmatter-template era); 2 newly closed in this session (T-2161, T-2162) were swept by re-running the migration after each close.

---

## Condition 5 — Re-running migration reports 0 changes (idempotent)

**Source:** `bin/migrate-horizon-null-completed.sh` exit output.

```
$ bin/migrate-horizon-null-completed.sh | grep -E "^[0-9]+ changes|total files"
0 changes
  total files scanned:                  1947
```

Plus `fw audit` CTL-030 rail confirms no drift slipped in since the last migration:

```
$ bin/fw audit --section compliance | grep CTL-030
[PASS] CTL-030: All completed/ tasks have null/absent stored horizon (arc-009)
```

---

## Slice-level summary

| Slice | Task | Status | Wire-level proof |
|-------|------|--------|------------------|
| 1 | T-2160 | partial-complete, owner=human | conditions 1, 2, 3 |
| 2 | T-2161 | completed | conditions 4, 5 (migration) |
| 3 | T-2162 | completed | condition 5 (audit) + 10/10 bats green |
| 4 | T-2163 | completed | write-side prevention at `agents/task-create/update-task.sh:1660` (null horizon at full-close move); 4/4 bats green (`tests/unit/update_task_horizon_null_on_close.bats`); closes the recurrence loop so the migration is one-shot, not perpetually-needed |

## arc-009 close readiness

- **`anchor_task:`** unset in the arc YAML — T-2159 inception was the anchor; closure may need this set to T-2159 (in completed/).
- **`demo_evidence:`** captured here (`docs/reports/arc-009-demo-evidence.md`).
- **`headline_mechanic:`** present and verified across all 5 conditions.
- **Sovereignty:** `fw arc close` is human-only under `$CLAUDECODE=1` (T-1671). The human runs `fw task review <anchor>` → Watchtower `/arcs/horizon-axis-hardening/close`.

## Recurrence loop closed — both surfaces

The arc closes the missing edge at **both** prevention surfaces:

- **Write-side (T-2163):** `agents/task-create/update-task.sh:1660` nulls the stored `horizon:` field atomically at the full-close move, so no completed/ file is ever written with `horizon: now|next|later`. The 4-bats fixture pins both branches in isolation (full-close nulls; partial-complete preserves — the file stays in active/ where horizon is still functional).
- **Read-side (T-2162):** `fw audit --section compliance` runs CTL-030 daily via cron. Any drift that slips past the write-side (legacy file, manual edit, future regression of T-2163) FAILs the audit with the exact offender list and points at the migration script as the recovery.

The migration (`bin/migrate-horizon-null-completed.sh`, T-2161) remains as a one-shot for cross-machine corpora that ingest the audit rail before they ingest the write-side fix. On a corpus where T-2163 has always been in effect, re-running the migration reports **0 changes** — that is Condition 5.

Read-only mitigation alone (CTL-030 + migration on demand) would have left the recurrence loop open: every new task close would have generated fresh drift for the audit to catch. T-2163 closes the loop atomically; CTL-030 is now a backstop, not the primary mechanism.
