# T-4635 — RCA: agent sessions and workers killed when root's user slice is torn down

Date: 2026-10-22. Operator: "ok thats bad, rca structural remediation?"

## Symptom

At about 13:38:58 CEST the parent session (claude-fw, conversation 087d333f) stopped mid
tool call, together with all six running TermLink workers (w4632, w4626, w4616, w4617,
w4634, w4551). The workers wrote no `exit_code`; their last output is 13:38:48–13:38:57.
Every background monitor of the parent was lost. The operator resumed the session at
13:55:47 (`claude --resume 087d333f…`). Two other projects' claude sessions on the host were
also resumed at 13:41 and 13:43.

## Evidence

- Parent transcript: last entry 2026-10-22T11:38:58Z, next entry 11:55:53Z ("Tool call
  interrupted: the session ended").
- The tmux server that hosts the relaunched session was started at 13:39:08 by
  1409-sprind's TermLink spawn (`tmux new-session -d -s tl-t2482-r1 -e
  PROJECT_ROOT=/opt/1409-sprind …`): the previous shared default server was gone.
- `journalctl`: `user-runtime-dir@0.service: State 'stop-sigterm' timed out. Killing.` at
  13:37:00, `Processes still around after SIGKILL`, `Stopped user-runtime-dir@0.service`,
  `Removed slice user-0.slice - User Slice of UID 0` at 13:37:10.
- Root has no linger (`loginctl list-users` lists only uid 1000; no root entry under
  `/var/lib/systemd/linger`). Cron opens and closes root logind sessions every minute, so
  `user@0.service` and `user-0.slice` are started and torn down roughly once a minute
  (`Stopped user-runtime-dir@0.service` every 1–2 minutes today).
- That teardown timed out and was force-killed 50 times between 2026-10-20 00:00 and
  2026-10-22 14:01, clustered in high-load periods (2026-10-21 10:57–12:28, 2026-10-22
  00:12–01:05, 11:32–13:37). The 2026-10-21 session restarts at 09:08 and 11:47 (blamed
  then on claude-fw ping death, T-4541) fall in the same high-load windows.
- The relaunched tmux server now lives in `/user.slice/user-1000.slice/session-c1.scope`.

### Correction after review (2026-10-22, codex and claude-code seats)

Two reviewers noted that the 13:37:10 force-kill precedes the deaths (13:38:48–58) by about
100 s. The journal shows the actual trigger: a root ssh login at 13:38:32 created a new root
session; when it closed, systemd stopped `user@0.service` and **removed `user-0.slice` at
13:38:43.889 in an ordinary, non-timeout teardown**. The deaths follow within 5–15 s. So the
kill does not need a stop timeout: any teardown of root's slice while a long-lived process
lives in a root login-session scope is enough. The cause and the linger remediation stand;
the "only under load" qualifier below is too narrow.

## Root cause

Long-lived agent processes (the shared tmux server, claude-fw sessions, TermLink workers)
are started from transient root login sessions (cron, ssh, a terminal), so they live
inside `user-0.slice`. Root does not linger, so systemd tears that slice down whenever
root's last login session closes, which cron makes happen every minute. Normally the
teardown leaves the abandoned processes alone; under host load the stop times out,
systemd escalates to SIGKILL and removes the slice, and every process still in it dies:
the tmux server and everything running inside it, at once.

## Second finding: cross-project environment contamination

A tmux server keeps the environment of the process that started it. 1409-sprind's
TermLink spawn started the new default server with `PROJECT_ROOT`, `CONTEXT_DIR` and
`TASKS_DIR` of `/opt/1409-sprind`, so the relaunched AEF session inherited
`CONTEXT_DIR=/opt/1409-sprind/.context` and `TASKS_DIR=/opt/1409-sprind/.tasks`. `fw`
caught it (`inherited TASKS_DIR … is outside project …; using …`) and fell back to its
own directories, so no data crossed, but every hook now prints the warning and any
tool that reads those variables without that guard would write into another project.

## Containment (2026-10-22 14:55)

055 reported the same leak as an isolation breach: its vendored 1.8.10 predates T-4222
(lib/paths.sh re-derives a foreign TASKS_DIR/CONTEXT_DIR), so its hooks read 1409's focus
and any fw write would have landed in /opt/1409-sprind (055 reports nothing was written).
The leak sat in the DEFAULT tmux server's global environment (`tmux show-environment -g`),
which hosts every project's `tl-claude-master-*` session; the claude-fw `fw-agents` server
was clean (up since 2026-10-11). Both variables were removed with `tmux set-environment
-g -u CONTEXT_DIR` / `-u TASKS_DIR` (verified: 0 left), and every peer was told to check
`env` in sessions started or restarted between 13:39 and 14:55 and relaunch once if
affected. Running processes keep their old copy until relaunched.

## Why nothing caught it

- Nothing checks where long-lived framework processes live (which cgroup, and whether
  the owning user lingers). `fw doctor` reports claude-fw and TermLink health, not
  survivability.
- The kill looks like an ordinary exit from inside: claude-fw saw its child die and the
  earlier incidents were attributed to the closest visible mechanism (T-4541).
- Workers die without `exit_code`, so the parent's monitor simply never fires; there is no
  "worker vanished" signal.
- A shared tmux default socket means one project's spawn decides every project's server
  environment; nothing scrubs foreign project variables at session launch.

## Structural remediation

1. **Host, immediate (operator):** `loginctl enable-linger root`. The root user manager and
   `user-0.slice` then stay up, so the per-minute teardown and its SIGKILL path stop.
2. **Framework, durable:** claude-fw and `fw termlink dispatch` start their long-lived
   processes in a dedicated unit outside any login session (`systemd-run --scope
   --slice=…`, falling back cleanly where systemd is absent), so a session teardown can
   never reach them, linger or not.
3. **Detection:** `fw doctor` / `fw audit` WARN when claude-fw, Watchtower, the TermLink hub
   or a tmux server serving workers lives in a `session-*.scope` of a user without linger,
   naming the fix; a dispatch-dir sweep reports workers that stopped producing output
   without writing `exit_code` ("worker vanished"), so the parent learns instead of waiting.
4. **Environment hygiene:** claude-fw drops inherited `PROJECT_ROOT`/`CONTEXT_DIR`/`TASKS_DIR`
   that point at another project before launching; TermLink should spawn on its own tmux
   socket (or with a clean server environment) so one project's spawn cannot seed another's
   sessions. The TermLink half is homed with TermLink per Gap Homing.

## Damage update (2026-10-22 21:00)

- **050-email-archive (vendored 1.8.10): confirmed cross-project WRITE.** Its 17:21 PreCompact hook ran
  with the leaked `CONTEXT_DIR` and wrote handover `S-2026-1022-1721.md`, `LATEST.md`,
  `audits/2026-10-22.yaml` and `.session-metrics.yaml` into `/opt/1409-sprind/.context`; its
  auto-commit step may have committed in the 1409 repo. 1409-sprind was asked to inspect and revert on
  its side (project boundary: not touched from here). 050 relaunched clean at 20:50.
- **1023 (1.8.12): clean**, writes in its own tree, env clean.
- **0506: still unknown.**
- The host rebooted at ~20:46, so every process now runs with a fresh environment; the leak itself
  is gone. Pre-T-4222 consumers (050, 055, 1023) stay exposed to a recurrence until they upgrade.
- **1409-sprind inspection (21:20):** 050's leaked hook left two untracked files in 1409's
  `.context/handovers/` (`S-2026-1022-1721.md`, `.discard-manifest.yaml`), computed from 1409's own task
  tree. No commit was made in 1409 and nothing was pushed; 1409 quarantined both files, and its
  LATEST.md had already been re-pointed by its own 17:36 handover. Damage is closed for 050→1409.
- **055 (21:30):** its own tmux wrappers (fleet launcher, rehome, cockpit) had the same deny-list hole
  (055 T-538); now an allow-list (055 commit 34e78fe1) with an A-after-B polluted private-server test
  that was red on the old code — the model for the G-116/G-124 close test. 055's post-reboot host scan:
  256 agent processes, 0 foreign TASKS_DIR/CONTEXT_DIR, tmux global environment clean.
