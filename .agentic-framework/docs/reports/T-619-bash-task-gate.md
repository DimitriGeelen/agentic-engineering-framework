# T-619: Bash Task Gate with Bootstrap Allowlist

## Status: Superseded by T-630

T-630 ("Universal task gate — close Bash, Agent, and TermLink bypass paths") already completed comprehensive inception research covering this exact topic:

- 5 spikes completed with findings
- 7,920 Bash invocations analyzed from real session data
- Safe-command allowlist defined (27 patterns in 6 categories)
- <0.5% false-positive rate demonstrated
- FW_SAFE_MODE escape hatch designed
- GO recommendation with 3 build tasks

See: `docs/reports/T-630-universal-task-gate.md`

## Key Finding

T-630's research is strictly more comprehensive than T-619's scope. T-619 focused only on Bash; T-630 covers Bash + Agent/TaskCreate + TermLink governance propagation.

## Build Tasks Needed (from T-630 GO)

T-630 recommended 3 build tasks (T-631, T-632, T-633) but those IDs were reused for unrelated work. The build tasks still need to be created:

1. **Bash task gate** — Add Bash to check-active-task.sh matcher. Safe-command allowlist + write-pattern detection + FW_SAFE_MODE.
2. **Agent/Task tool gate** — Add Agent|TaskCreate|TaskUpdate to matcher. Zero code changes to check-active-task.sh.
3. **TermLink governance propagation** — Make `--task` mandatory in `fw termlink dispatch`.

## Recommendation: Close T-619 as duplicate. Create the 3 build tasks referenced by T-630.
