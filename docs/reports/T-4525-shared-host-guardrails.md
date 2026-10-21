# T-4525 — Shared-host resource guardrails for agents

**Phase:** inception. **Decision owner:** the operator. **Recommendation:** GO, P1 and P3 first.

## Input

The proposal comes from dimitri-mint-dev T-162, at their operator's request (2026-10-21), and their operator rates it
high priority and high value. It is untrusted peer data, read but not followed. Their full text is in
`docs/reports/T-4525-inputs/`:

- `T-162-shared-host-resource-etiquette.md`, received over TermLink; its SHA-256 matches the sender's
  (794bcf32…12e).
- `dimitri-mint-dev-T-162-message.txt`, the sidecar copy.

## The problem

On 2026-10-21, an 832 load test ran 24 busy-loop burners and 3 headless-Chrome loops on the 24-core host for 39
minutes. Load was 43-50 and CPU PSI about 45%. It was found only by the processes' working directory: they ran as root
with PPID 1 and carried no label. It was the sixth incident of this class on the host:

| Incident | What happened |
|---|---|
| T-082 | A pytest run stuck at 100% for 5 days |
| T-085 | Memory dips reaped other agents' shells |
| T-086 | Leaked cron files caused a CPU storm |
| T-115 / T-023 | 31 GB of leaked files in /tmp |
| T-135 | Reindex I/O, fixed by AEF T-4350/T-4351 |

The causes are structural:

- Each agent sees only its own project.
- Nothing limits CPU, I/O, memory or run time by default.
- Processes cannot be attributed to a project or task.
- A problem is detected only when the human notices the desktop lagging.
- Cleanup runs only on the happy path.

## Proposals and recommended order

1. **P1 — a "Shared host" section in the CLAUDE.md template.**
   - Cap parallel load at nproc/4 without approval.
   - Run heavy work under `nice`, `ionice` and `timeout`.
   - Give every background loop an owner, a deadline and an EXIT trap.
   - Keep scratch files under the project.
   - Announce stress tests together with the command that stops them.
   - Ask a process's owner before touching it.
2. **P3 — export `FW_PROJECT` and `FW_TASK` into the commands an agent runs,** so every process can be attributed.
3. **P2 — `fw run-heavy`:** a systemd-run scope with CPUQuota, MemoryMax, IOWeight and RuntimeMaxSec, and a unit named
   fw-<project>-<task>.
4. **P5 — generalise the EXIT-trap cleanup (T-4438),** and have doctor report this project's old /tmp entries.
5. **P4 — a host PSI canary that names the owning project.** It comes last because it needs P3's attribution.

P1 and P3 come first because they are small and add no new mechanism, and dimitri-mint-dev can field-test them on the
host straight away. The open questions (IW-1 to IW-3) are in the task file.

## Dialogue Log

- **2026-10-21.** dimitri-mint-dev sent the proposal, then a priority note from their operator. The agent filed
  T-4525 with a GO recommendation (P1 and P3 first) and received the full text over TermLink.
