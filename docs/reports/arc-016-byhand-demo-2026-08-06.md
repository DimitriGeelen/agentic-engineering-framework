# arc-016 demo capture — the by-hand five-minute path, end to end

**Task:** T-2819 · **Date:** 2026-08-06 · **Arc:** arc-016 (`readme-first-run`)
**Full transcript:** [`arc-016-byhand-transcript-2026-08-06.log`](arc-016-byhand-transcript-2026-08-06.log) (2662 lines)

## What this is

§ACD (G-062) requires a captured artefact showing an arc's **headline mechanic
firing** before closure — not a green test suite, which is substrate. arc-016's
mechanic:

> A person with no agent assisting follows the README's five-minute walkthrough end
> to end and reaches a working first task without hitting a block they cannot clear,
> and a persona test that runs the by-hand path separately from the agent-assisted
> one fails loudly if that ever stops being true.

This is the first half. The second half — the persona test — shipped as
`tests/integration/readme_five_minute_by_hand.bats` (T-2719).

**Closure is not mine to make.** `fw arc close` refuses under `$CLAUDECODE=1`
(T-1671); this document is the evidence the operator decides on.

## Conditions

| | |
|---|---|
| Bytes under test | **Published** — GitHub mirror, confirmed in sync at `e492f4116` |
| Environment | `env -i`, `HOME=/tmp/arc016-demo2/home`, `PATH=$HOME/.local/bin:/usr/bin:/bin` |
| Git identity | **none** — `GIT_CONFIG_GLOBAL` points at a nonexistent file |
| Agent involvement | none during the run; commands issued exactly as the README lists them |

Running against published bytes matters: a demo of the working tree proves nothing
about what a consumer actually receives.

## The run

| Step | Command | RC | Outcome |
|---|---|---|---|
| 1 | `curl … install.sh \| bash -s -- my-project --provider claude` | **0** | Installed + initialised. Init's closing block flagged the identity blocker. |
| 2 | `git commit -m "no task yet"` | **128** | `Author identity unknown` — died *before any framework hook ran*. |
| — | operator runs the command init printed | **0** | Identity set. |
| 2′ | `git commit -m "no task yet"` (retry) | **1** | **The gate refuses** — `No task reference found in commit message`. Documented outcome reached. |
| 3 | `fw work-on "Add authentication" --type build` | **0** | Created and focused **T-006**, the operator's own first real task. |
| 3b | `git commit -m "T-006: first governed commit"` | **0** | **First governed commit lands.** |
| 4 | `fw audit` | 1 | Ran; exit 1 = warnings on a day-zero project (known class, T-2740). |
| 4b | `fw serve` | 1 | Refused — `:3000` held by a foreign service. Names the remedy (`--port N`). |

## Verdict: the mechanic fired

The operator reached **a working first task** (T-006, focused, committed) without
assistance, and **every block they hit was clearable from what the framework told
them**:

- **RC=128 identity** — cleared using the copy-pasteable command in init's closing
  block. This is exactly what T-2818 shipped; before that fix the same three
  warnings existed but were contradicted by `Validation passed: 43/44`, `Done!
  Governance is active.` and `Next step: start your AI agent`. The operator was
  warned and then told everything was fine.
- **Commit refused, no task** — this is the *documented* step 2 outcome, and the
  remedy line printed `fw work-on "your task name" --type build`. That is T-2816
  working in a real consumer: it previously printed
  `./agents/task-create/create-task.sh`, a path no consumer has.

Both of this session's onboarding fixes are visible firing in the transcript, on
published bytes, in the persona that could not see them before.

## Caveats — stated, not papered over

**1. `fw` PATH resolution could not be honestly measured on this host.**
This machine carries `fw` in **both** `/usr/local/bin` and `/usr/bin` from earlier
global installs. A by-hand test of "does bare `fw` resolve on a fresh machine"
therefore resolves the *host's* binary, not the newly installed router — the same
wrong-object contamination as T-2796. What *is* verifiable: `install.sh` writes its
router to `~/.local/bin/fw`, detects that the directory is not on `PATH`, and prints
the `export PATH=...` remedy (transcript lines 47–54). The run used that `PATH`.
A clean answer needs a container or a machine with no prior install.

**2. Step 4 assumes port 3000 is free.** On this host `:3000` belongs to
`/opt/832-Workflow-designer`, so `fw serve` refuses and `fw watchtower url` reports
it cannot identify a Watchtower for this project. **Both refusals are correct** —
this is the T-1376/T-2732 false-green fix working exactly as designed, declining to
claim another project's server rather than returning a 200 that asserts nothing. But
the README's step 4 lists a bare `fw serve` with no mention of `--port`, so a by-hand
operator on any port-contended host follows the walkthrough into an error. Filed
separately (see below) rather than folded into this capture.

**3. `fw audit` exits 1 on a day-zero project.** Warnings, not failures — the known
T-2740 greenfield-seed-drift class. The README presents `fw audit` without noting
that non-zero is expected on a fresh project.

Neither caveat blocks the mechanic: both occur *after* the operator has reached a
working first task, and both name their own remedy.

## What this does not prove

That the *agent-assisted* path works — that is a different persona and, per arc-016's
whole thesis, fails differently. And that a genuinely clean machine resolves `fw` as
intended (caveat 1).
