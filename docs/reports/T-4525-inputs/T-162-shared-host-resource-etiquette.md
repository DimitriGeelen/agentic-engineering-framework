# Proposal to AEF: shared-host resource awareness and guardrails for agents

From dimitri-mint-dev (.107 workstation host project), T-162, on operator request (2026-10-21): "analyze this further
and send an improvement suggestion to [AEF] to incorporate for agents to be aware of this". A proposal, not a build
instruction (G-020); AEF decides scope.

## 1. The incident (2026-10-21)

| Time | Event |
|---|---|
| ~10:00 | 832-Workflow-designer starts a load test for a flaky browser check (their T-1246): `/tmp/t1246/load.sh start` = **24 busy-loop burners** (`while [ ! -e stop ]; do :; done`) + 3 looping headless-Chrome CDP harnesses. The host has 24 cores. |
| 10:00-10:37 | Load 43-50, cpu PSI `some` ~45%. The operator's desktop is sluggish; the operator reports "system is busy". |
| 10:37 | We find it by `ps --sort=-pcpu` and the process **cwd** (/opt/832-Workflow-designer); the processes have PPID 1 (detached), user root, no task or project label. |
| 10:38 | Sidecar question to 832 (asked, not killed). |
| 10:39 | 832 stops it (27 PIDs), apologises, caps future load tests at ≤ 6 niced burners. cpu PSI 45% → 0.2% within a minute. |

The agent's intent was legitimate (reproduce a timing-sensitive failure under load). The harm came from **nothing
telling it** that the host is shared with ~30 agent projects and a human using the desktop, and **nothing limiting**
the blast radius.

## 2. It is a recurring class on this host

| Task | What saturated the shared host | Found by |
|---|---|---|
| T-082 (Sep 30) | stuck pytest at 100% CPU for 5 days (1409); Ollama model loop at 7-11 cores | operator noticed load 27-34 |
| T-085 | memory dips → Claude Code reaped other agents' background shells | 1409 reported lost work |
| T-086 | leaked `proj-schedule-install` cron files → 08:15 CPU storm | operator |
| T-115 / T-023 | test runs and Chromium automation leaked ~12,900 /tmp folders in 2 days; Thunar unusable; later 31 GB in /tmp (1409 worktrees, AEF installer fetch clones, AEF T-4438) | operator |
| T-135 | hourly full-copy reindex in 8 projects, 6 at the same minute: ~282 GiB/day writes, I/O-bound host (fixed by AEF T-4350/T-4351) | ring20 + us |
| T-162 (today) | 24 burners on 24 cores | operator |

Common pattern: **(a)** each agent sees only its own project; **(b)** no default limits on CPU/IO/memory/time for
agent-started work; **(c)** processes are not attributable (root, PPID 1, cwd is the only clue); **(d)** detection is the
human feeling the desktop lag; **(e)** cleanup depends on the happy path (no EXIT traps, detached loops with a stop file).

## 3. Proposals (priority order)

### P1 — Guidance in CLAUDE.md (cheap, immediate)

A short "Shared host" section in the governance template, e.g.:

- **You are not alone on this host.** Other agent projects and a human desktop share CPU, disk, RAM and /tmp.
- **Cap parallel load** at ≤ 25% of cores (`nproc`/4) unless the operator approves more; never a busy-loop burner per core.
- **Run heavy work niced and time-boxed:** `nice -n 10 ionice -c3 timeout <N>` (or the P2 wrapper).
- **Every background loop needs an owner, a deadline and a cleanup trap** (`trap … EXIT INT TERM`); never leave detached
  loops whose only stop is a file.
- **Scratch goes under the project** (e.g. `.context/scratch/`, gitignored), not /tmp; if /tmp, clean it in the trap.
- **Announce** a deliberate stress test (> 15 min or > 25% of the host) to the operator before starting, with its stop command.
- **When you find another project's process hurting the host: ask its owner first** (sidecar), don't kill it.

### P2 — A wrapper that makes the safe way the easy way: `fw run-heavy`

`fw run-heavy --task T-XXX [--cpu 25%] [--mem 8G] [--io low] [--max 30m] -- <cmd>` → `systemd-run --scope` (or
`--unit`) with `CPUQuota`, `MemoryMax`, `IOWeight`/`IOSchedulingClass=idle`, `Nice`, `RuntimeMaxSec`, unit name
`fw-<project>-<task>-<slug>`. Effects:

- the whole process tree is capped and **killed at the deadline** (no orphaned loops);
- the unit name **is the attribution** (`systemctl list-units 'fw-*'` shows who runs what);
- cgroup accounting gives per-task CPU/IO numbers for free (useful evidence, cf. T-135).

The project boundary hook could nudge: a Bash command that starts N background loops or a known load tool without
`fw run-heavy` gets a WARN (not a block).

### P3 — Attribution for everything an agent starts

Export `FW_PROJECT` and `FW_TASK` (and the session id) into the environment of agent-run commands, so `ps e`/`/proc/<pid>/environ`
answers "whose is this?" without cwd sleuthing. Cheap, and it helps every investigation in the table above.

### P4 — Detection before the human notices

A host-level canary (one per host, e.g. owned by the host project or Watchtower): when cpu PSI `some` avg60 > 30% or
io PSI > 20% for > 5 min, attribute the top consumers by cgroup/unit (`fw-*` scopes, then cwd → project) and post a
sidecar notice **to the owning project** plus an operator summary. Today's incident would have been caught by minute 5
instead of minute 37, and routed to 832 automatically.

### P5 — Cleanup on every path

Generalise AEF T-4438 (installer EXIT trap): framework scripts that create temp dirs, worktrees or background
processes clean them on EXIT/INT/TERM; `fw doctor` reports /tmp entries owned by this project older than 24 h.

## 4. Suggested scope

P1 + P3 are small and close most of the awareness gap; P2 gives enforcement; P4 gives detection. dimitri-mint-dev can
field-test any of them on .107 (we have the incident history and the host role), as with T-148/T-155/T-158.
