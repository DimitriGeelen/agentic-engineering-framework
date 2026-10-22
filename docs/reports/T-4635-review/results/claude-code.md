# Review: SEV-1 cross-project environment leak and slice teardown (T-4635 / G-116)

## Verdict

The RCA has the mechanisms right but treats this as a variable-naming problem. It is not. Project identity is taken from ambient, inheritable state, and that state sits in host objects shared by every project. Two things guaranteed a recurrence: the 10-16 fixes listed only the variable names already seen, and G-116 was never closed against a test. The teardown half is a separate root cause. Long-lived processes live in transient login cgroups. Linger is a mitigation, not the fix.

Two points in the bundle need checking before the RCA is final:

- **Kill time.** §1 cites the slice removal at 13:37:10. The parent and workers died at 13:38:48–58, about 100 s later. Either a second teardown did the kill, or the cited one is the wrong event. Correlate exactly.
- **PROJECT_ROOT in the global environment.** §1 says the new server took 1409's `PROJECT_ROOT` too, but only `TASKS_DIR`/`CONTEXT_DIR` were unset. Re-check `show-environment -g` for every server.

## Root cause (ranked)

1. **The framework trusts inherited paths for identity.** This includes the env-var location scheme itself; they are the same defect. The boundary hook reads `os.environ['PROJECT_ROOT']` (§5:222). With a foreign `PROJECT_ROOT`, the safety hook inverts: it permits writes to the other project and blocks the agent's own. The §3 guard only checks `TASKS_DIR`/`CONTEXT_DIR` *relative to* `PROJECT_ROOT`, so a foreign `PROJECT_ROOT` passes it.
2. **One mutable environment shared across projects.** This covers the default server, the `fw-agents` server ("shared by every wrapped project", §4), and the same Unix user.
3. **A name-based deny-list.** It fixed instances, not the class. Worse, T-3445 strips `_FW_PATHS_DERIVED_BY`, the T-2289 sentinel (§3). The fix deleted the detector and left the payload in place.
4. **Separately, long-lived processes run in login-session cgroups** of a non-lingering user. This was the trigger.

## Remediation (prioritised, concrete)

1. **Now.** Apply `loginctl enable-linger root`. Then scan `/proc/*/environ` for every project variable whose value names a different project than the process cwd. Relaunch those carriers. They survive the 14:55 cleanup, and if one is the first client after the next teardown, it re-seeds the server.
2. **One spawn function, clean on every call.** Since any client can be first, never rely on being first:
   ```
   env -i HOME="$HOME" PATH=/usr/local/bin:/usr/bin:/bin LANG=C.UTF-8 TERM="$TERM" SHELL=/bin/bash USER="$USER" \
     tmux -L <sock> -f /dev/null new-session -d -s … -e K=V… \; set -g update-environment ""
   ```
   - The global environment holds only those six variables.
   - Project variables go only via `-e`, built from an allow-list, after the launcher re-derives them itself.
   - After start, assert that `show-environment -g` matches a regex of project-ish variables (`*_ROOT|*_DIR|FW_*|CLAUDE*`). On a match, unset and alert.
   - TermLink must use the same function. The hub's own environment has the same shape: a hub started from a project shell seeds every spawn.
3. **Fix the claude-fw allow-list (§4).**
   - `CLAUDE*` and `FW_*` re-inject `CLAUDE_PROJECT_DIR`, `FW_ROUTED_FROM` and `FW_TASKS_DIR_OVERRIDE=1` into the session via `-e`. The `env -u` only cleans the tmux client.
   - `PROJECT_ROOT`/`FRAMEWORK_ROOT` are copied from the caller. Set them from `readlink -f "$0"` before building `_cfw_env`.
4. **Identity from location.**
   - `PROJECT_ROOT` comes from the vendored framework's own path or a `.framework.yaml` walk from cwd. In hooks, cross-check it against Claude Code's `CLAUDE_PROJECT_DIR`.
   - Environment values are overrides only, honoured only with an explicit flag.
   - **Refuse** (non-zero exit, no write) when the inherited `PROJECT_ROOT` disagrees with the derived one. Re-derive-plus-warn is acceptable for `*_DIR`, but log it to a host-wide audit file, not only to stderr. Nobody reads stderr.
5. **Old vendored copies.** Set a minimum-version floor in `fw doctor` and the TermLink spawn: refuse to dispatch into projects older than 1.8.13. The source-side clean environment (item 2) is the only protection 1.8.10 gets.
6. **Isolation boundary.**
   - Short term: one socket per project (`-L aef-<project>`), shared by that project's master and workers. Add `fw attach` and a cockpit that enumerates `/tmp/tmux-$UID/aef-*`. Cost: `tmux attach` habits and a one-time migration of live sessions.
   - Per-hub sockets still mix projects.
   - Durable: one Unix user per project. That is the only boundary that fails closed, because 055 then simply cannot write to `/opt/1409-sprind`. It also separates `~/.claude`.
7. **Survival.** Start each project's tmux server as a unit, for example `systemd-run --unit=aef-tmux-<project> --slice=aef.slice -p Type=forking -p KillMode=process tmux -L … new-session -d`, where `aef.slice` is a system slice. Do not use a login scope. The relaunched server currently sits in `user-1000.slice/session-c1.scope` (§1), which is equally fragile.

## Detection

- **At creation, synchronously.** The spawn function asserts a clean global environment. A tmux `session-created` hook (`set-hook -g` on each server) runs the check immediately.
- **In-process, before the first write.** Run the identity check from item 4 in `paths.sh` and the hooks, and record every trip in a central log.
- **Every minute (Watchtower / `fw audit`).** For every socket in the tmux socket dir, and for every pane PID's `/proc/environ`:
  - compare project variables against the pane's cwd project and its TermLink registration;
  - check the cgroup of claude-fw, the hub and the tmux servers (a `session-*.scope` of a user without linger means WARN);
  - check for workers that stopped producing output without writing `exit_code`.
- **Journal watch.** Alert on `Killing`/`SIGKILL` from `user-runtime-dir@*`. Fifty silent events were the real miss.

## Damage assessment

The window is 10-16 01:40 through relaunch of the last carrier, plus 13:39 → carrier relaunch on 10-22. It does not end at 14:55.

- **Claude transcripts.** Grep `~/.claude/projects/*/*.jsonl` for tool calls whose paths hit `/opt/<other>/.tasks|.context`. All agents share one user, so this is the most complete record.
- **Per project.** Run `git status` and `git log --since` on `.tasks`/`.context`. Use `find -newermt` across all projects for the window. Check commit or session metadata that names another project.
- **Reads that write.** 055's hooks "read 1409's focus". Check whether they also updated counters, timestamps or the session file in 1409.
- **Task ids.** Look for ids out of sequence, or tasks whose creator or session id belongs to a foreign agent. 10-16 already showed this pattern (1023 created tasks in 055).
- **Episodic and handover files** that mention foreign task ids.
- **Exposure proxy.** Count the warning lines in hook stderr captures. Check for an auditd trail if one exists.

## What we missed

- **Closing discipline.** T-4217/18/22 have empty Context and Acceptance Criteria (§2). The fix was split across two repos: T-4222 added `*_DIR` to claude-fw's `env -u` (on a server that was already clean), not to TermLink's T-3445 list.
  - Rule: a gap closes only on an executable reproduction.
  - Pollute a shell with a fake project A's *whole* environment, plus a variable name that is on no list (e.g. `ZZZ_DIR=/opt/A/.tasks`).
  - Spawn through every path (termlink spawn, fw dispatch, claude-fw).
  - Assert that the session environment holds no A values and that writes land in B.
  - Run it in both repos' CI.
- **`fw-agents` was clean by luck.** It has been up since 10-11, predating T-4217.
- **Same-shape shared state:**
  - the TermLink hub's environment;
  - the `systemctl --user` manager environment;
  - shared `~/.claude` settings, memory and `CLAUDE.md`, plus `~/.gitconfig` and shell rc exports;
  - fixed-name files in `/tmp`;
  - anything under `/run/user/0`, which is deleted on every teardown (check whether hub sockets live there).
- **Agents run as root.** If so, the project boundary is advisory everywhere, and stop-timeout behaviour under load 25–75 deserves its own look (`DefaultTimeoutStopSec`, D-state processes).
- **Misattribution.** The T-4541 "ping death" diagnosis should be reopened against the journal.
