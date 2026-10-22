## Verdict

Two coupled SEV-1s with one trigger. (1) **Survival:** all long-lived agents lived inside root's login slice, which cron tears down every minute and which systemd SIGKILLs under load (§1, §6). (2) **Isolation:** the default tmux server is a single cross-project trust domain — whoever starts it seeds the global environment every later session inherits (§1). Containment on 10-22 was luck plus version skew, not design (§6). The 10-16 fix failed because it enumerated names instead of closing the mechanism (§2, §3).

## Root cause (ranked)

1. **One shared tmux server across projects** — the architectural defect. It is both the leak amplifier (global env = broadcast) and the kill domain at 13:38: one server, one fate (§1, §6).
2. **Project identity carried in inheritable env vars.** Ambient, unauthenticated, copied by every wrapper; any boundary slip becomes a cross-project operation (§2 detection_gap).
3. **Framework trusts inherited paths.** Warn-and-derive only, and only in versions after 2026-10-17; old vendored copies obey silently (§3, §6).
4. **Name-based deny-list** (T-3445) — fail-open by construction; the proximate reason the fix didn't fix (§2).

## Remediation (prioritised, concrete)

- **P0** `loginctl enable-linger root` today — stops the per-minute teardown (§1).
- **P0** Move tmux server(s), hub and workers out of login scopes: `systemd-run --scope --unit=fw-… --slice=fw.slice` (system-level or a lingering user manager) with restart supervision (§1 rem. 2). Survival precedes isolation: a slice kill kills *every* socket's server.
- **P0** Supervised, deliberately pre-started, clean servers. TermLink owns its socket(s) (`-L termlink-hub`, or per project), started by that unit with `env -i` + minimal vars (`PATH HOME LANG TERM`), `-f /dev/null`, empty `update-environment`, a keeper session — so no project spawn is ever the first client. §4 already proves the pattern (`fw-agents`). Cockpits enumerate sessions via the hub registry; attach becomes `fw attach <proj>`. Post-hoc `set-environment -g -u` stays only as a racy remedial.
- **P1** Allow-list, not deny-list: every spawn wrapped in `env -i` + explicit set; the server's global environment must contain **no** project variables. Identity travels only per-session via `new-session -e` (§4).
- **P1** Framework: on env/cwd root disagreement, re-derive, tag the session, emit telemetry, and **refuse writes** until reconciled. Anchor identity to cwd + `.framework.yaml` (plus a per-session token), not ambient env (§3, §5).
- **P1** Version floor: the hub/launcher refuses projects vendoring pre-T-4222 framework; enforcement lives in the always-current launcher, since vendored copies lag by design (§6).
- **P2** `fw doctor`/`fw audit`: cgroup + linger checks; worker-vanished sweep (§1 rem. 3).

## Detection

- **Synchronous at spawn** (TermLink): after server-up, assert `show-environment -g` matches the allow-list; unset + alert otherwise. Must finish before the session's command runs — milliseconds.
- **At session start and in the PreToolUse hook:** compare `PROJECT_ROOT`/`TASKS_DIR`/`CONTEXT_DIR` against the cwd-derived root and TermLink registration (§5's hook exists but enforces whatever `PROJECT_ROOT` says). Fire in seconds, before any tool call.
- **Continuous:** dispatch-dir sweep for workers with recent output, no `exit_code`, no live pid (§1).

## Damage assessment

Window 13:39–14:55 (§1):

- Enumerate sessions started/restarted in it; `/proc/<pid>/environ` of still-running ones *proves* exposure (old copy kept until relaunch, §1).
- Per project: `git status` / `log --since` on `.tasks`/`.context` if tracked, else mtimes in the window; task-id sequence per store vs foreign ids (precedent: 1023 wrote two tasks into 055, §2); grep every store for other projects' roots (`/opt/1409-sprind` outside 1409).
- `.context` focus/episodic files referencing foreign projects (055 read 1409's focus, §1); journalctl + tmux server start at 13:39:08; hook stderr warnings as evidence.
- Separate class: six workers died without `exit_code` — audit for lost uncommitted work (§1).

## What we missed

- **Closing discipline:** G-116's close condition ("a polluted-server test shows a clean session") was never executed (§2). Rule: a gap closes only when its stated test is in CI and green — add a hostile-server fixture and one source-of-truth list of framework-consumed env vars so scrub lists cannot drift. The 10-16 fixes reproduced the bug's class: they patched variable *names* (T-3445/T-4217) while `TASKS_DIR`/`CONTEXT_DIR` sat in the same paths.sh (§3).
- **§3's guard is fail-open:** it re-derives only when the foreign dir's parent carries `.framework.yaml`, and honors `FW_TASKS_DIR_OVERRIDE`; with the sentinel stripped by T-3445, only shape-sniffing remains — foreign paths to non-marker dirs survive.
- **§5's boundary hook is only as strong as `PROJECT_ROOT`** — an inherited-wrong root makes it guard the wrong project.
- **Any first client reseeds globals**, including a human typing `tmux` from a project shell; only sessions launched with per-session `-e` are safe (§4).
- **Other tmux shared state with the same shape:** global options, hooks, and paste buffers — cross-project data channels.
- **Everything runs as one Unix user — root.** No MAC boundary; per-project users plus systemd units is the real isolation. Same-shape ambient state elsewhere: `~/.claude` history/config, `/tmp` sockets, ssh-agent, docker socket.
