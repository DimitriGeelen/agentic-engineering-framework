# T-1700 — ollama-research harness results (v2, resolver-run substrate)

**Batch:** `20260721-205623` &nbsp; **N:** 10 &nbsp; **Task:** `T-2592` &nbsp; **Model (workflow):** `claude-3-5-sonnet-hermes3`

| Metric | Value | Threshold | Status |
|--------|-------|-----------|--------|
| **Real tool-use rate** | 9/10 (90%) | ≥90% | ✅ MET |
| Completed status | 10/10 (100%) | (informational) | — |
| Median latency | 2s | — | — |
| p95 latency | 27s | — | — |
| Outcome rows backpropped | 18 | ≥10 | ✅ |

**Critical:** clean completion is NOT a tool-use signal. The worker completes
cleanly when the model hallucinates an answer instead of calling tools. T-1700 GO
requires real tool_use events in the events stream, not just clean completion.

**v2 (T-2408):** dispatches route through `fw resolver run T-2592 ollama-research`;
envelope rows land in `.context/dispatches.jsonl`; `fw outcome backprop` appends
matching rows to `.context/dispatch-outcomes.jsonl`.

## Per-dispatch results

| # | Status | Tools called | Latency | Prompt (head) | Result (head) |
|---|--------|--------------|---------|---------------|---------------|
| 1 | success | 4 | 27s | Use Read to read /etc/hostname, then state the hos | - |
| 2 | success | 0 | 1s | Use Bash to run 'date -u +%Y-%m-%d', then report t | - |
| 3 | success | 1 | 2s | Use Read to read VERSION, then state the version n | It seems like the file you're trying to access is located outside of our allowed |
| 4 | success | 1 | 1s | Use Bash to run 'uname -m', then state the archite | The architecture is x86_64, based on the output of the 'uname -m' command. |
| 5 | success | 1 | 2s | Use Read to read /proc/version, then state the ker | The kernel version is 6.8.0-134-generic, compiled by buildd@lcy02-amd64-007 usin |
| 6 | success | 1 | 2s | Use Bash to count files in /etc with 'ls /etc \| wc | The command provided was unable to be executed due to a syntax error. The correc |
| 7 | success | 2 | 9s | Use Read to read /etc/os-release, then identify th | The OS family identified from the /etc/os-release file is Linux Mint, which is d |
| 8 | success | 1 | 15s | Use Bash to run 'whoami' and state the user. /no_t | The user is root, as determined by running the 'whoami' command using Bash. |
| 9 | success | 1 | 1s | Use Grep to find lines containing 'task_type' in l | The grep command found 16 lines containing 'task_type' in the specified file. |
| 10 | success | 2 | 1s | Use Bash to run 'echo $PWD' and report the working | The current working directory is /opt/999-Agentic-Engineering-Framework. |

## Dispatches (this batch, from .context/dispatches.jsonl)

- `6ef8ca87-4833-4f7c-b1aa-8dd6e8b33543` — forensics: `fw resolver explain 6ef8ca87-4833-4f7c-b1aa-8dd6e8b33543` / merged view: `fw outcome read 6ef8ca87-4833-4f7c-b1aa-8dd6e8b33543`
- `aa7cd91e-a8a8-455a-bdda-37563eb30637` — forensics: `fw resolver explain aa7cd91e-a8a8-455a-bdda-37563eb30637` / merged view: `fw outcome read aa7cd91e-a8a8-455a-bdda-37563eb30637`
- `a5ff5a02-fbdc-4191-82d0-5b055da5766f` — forensics: `fw resolver explain a5ff5a02-fbdc-4191-82d0-5b055da5766f` / merged view: `fw outcome read a5ff5a02-fbdc-4191-82d0-5b055da5766f`
- `298741ee-b6c6-456f-8c1b-e72f00aa58aa` — forensics: `fw resolver explain 298741ee-b6c6-456f-8c1b-e72f00aa58aa` / merged view: `fw outcome read 298741ee-b6c6-456f-8c1b-e72f00aa58aa`
- `5bdcd6f5-0cb2-468c-af2c-21772d15efa1` — forensics: `fw resolver explain 5bdcd6f5-0cb2-468c-af2c-21772d15efa1` / merged view: `fw outcome read 5bdcd6f5-0cb2-468c-af2c-21772d15efa1`
- `c9a7c414-b4ac-4f78-a53c-06259a5d561d` — forensics: `fw resolver explain c9a7c414-b4ac-4f78-a53c-06259a5d561d` / merged view: `fw outcome read c9a7c414-b4ac-4f78-a53c-06259a5d561d`
- `ce993d69-a5e5-4235-862e-4790e3c8e84a` — forensics: `fw resolver explain ce993d69-a5e5-4235-862e-4790e3c8e84a` / merged view: `fw outcome read ce993d69-a5e5-4235-862e-4790e3c8e84a`
- `ffd9ded3-d65c-4e89-8584-a0af5436bbad` — forensics: `fw resolver explain ffd9ded3-d65c-4e89-8584-a0af5436bbad` / merged view: `fw outcome read ffd9ded3-d65c-4e89-8584-a0af5436bbad`
- `9db6ec2d-7f20-4bd0-9d27-2cd418a67d1c` — forensics: `fw resolver explain 9db6ec2d-7f20-4bd0-9d27-2cd418a67d1c` / merged view: `fw outcome read 9db6ec2d-7f20-4bd0-9d27-2cd418a67d1c`
- `eff09e57-ad44-4902-87a6-0c13d81dba9c` — forensics: `fw resolver explain eff09e57-ad44-4902-87a6-0c13d81dba9c` / merged view: `fw outcome read eff09e57-ad44-4902-87a6-0c13d81dba9c`

## Events streams

- `/opt/999-Agentic-Engineering-Framework/.context/dispatch-blobs/2026-07/6ef8ca87-4833-4f7c-b1aa-8dd6e8b33543/events.jsonl`
- `/opt/999-Agentic-Engineering-Framework/.context/dispatch-blobs/2026-07/aa7cd91e-a8a8-455a-bdda-37563eb30637/events.jsonl`
- `/opt/999-Agentic-Engineering-Framework/.context/dispatch-blobs/2026-07/a5ff5a02-fbdc-4191-82d0-5b055da5766f/events.jsonl`
- `/opt/999-Agentic-Engineering-Framework/.context/dispatch-blobs/2026-07/298741ee-b6c6-456f-8c1b-e72f00aa58aa/events.jsonl`
- `/opt/999-Agentic-Engineering-Framework/.context/dispatch-blobs/2026-07/5bdcd6f5-0cb2-468c-af2c-21772d15efa1/events.jsonl`
- `/opt/999-Agentic-Engineering-Framework/.context/dispatch-blobs/2026-07/c9a7c414-b4ac-4f78-a53c-06259a5d561d/events.jsonl`
- `/opt/999-Agentic-Engineering-Framework/.context/dispatch-blobs/2026-07/ce993d69-a5e5-4235-862e-4790e3c8e84a/events.jsonl`
- `/opt/999-Agentic-Engineering-Framework/.context/dispatch-blobs/2026-07/ffd9ded3-d65c-4e89-8584-a0af5436bbad/events.jsonl`
- `/opt/999-Agentic-Engineering-Framework/.context/dispatch-blobs/2026-07/9db6ec2d-7f20-4bd0-9d27-2cd418a67d1c/events.jsonl`
- `/opt/999-Agentic-Engineering-Framework/.context/dispatch-blobs/2026-07/eff09e57-ad44-4902-87a6-0c13d81dba9c/events.jsonl`

_Generated: 2026-07-21T20:57:29Z_
