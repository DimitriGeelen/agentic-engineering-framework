# SEV-1 incident bundle (AEF T-4635): agent sessions killed by host slice teardown + cross-project environment leak

Host names, addresses and user names are removed. Paths are kept because they are the subject.

## 1. RCA as written by the AEF agent

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

## 2. Registered gap G-116 (same leak class, 2026-10-16) and its fix tasks

```yaml
- id: G-116
  type: gap
  title: A shared tmux server carries one project's PROJECT_ROOT/FRAMEWORK_ROOT into every agent session started on it, and fw obeys the inherited paths
  description: 'On 2026-10-16 01:40 a 055 review dispatch started the host''s default tmux server through fw termlink
    dispatch with 055''s environment, which became the server''s global env. The claude-fw master sessions of AEF, 050,
    1023, 832 and termlink, started 01:41-01:49, inherited 055''s paths; their fw commands and PreToolUse hooks acted on
    055''s project (1023 created two tasks there). AEF noticed only because a verb was missing and reply paths pointed at
    055; AEF stopped writing and recovered by restarting from a clean server.'
  severity: high
  status: open
  detected_in: T-4217
  observed: '2026-10-16'
  reported_by: agent (AEF) and 055-agentic-fleet-cockpit (their T-536)
  blast_radius: every project whose agent session starts on a shared tmux server after another project's dispatch
  detection_gap: fw and the hooks trust PROJECT_ROOT/FRAMEWORK_ROOT from the environment; nothing compares them with
    the launcher's own project or CLAUDE_PROJECT_DIR, so a session operating on another project looks normal
  what_remains: T-4217 strips the paths from the dispatch spawn; T-4218 makes claude-fw set them explicitly and fw refuse
    a foreign inherited PROJECT_ROOT. Close when both land and a polluted-server test shows a clean session.
```

### T-4217: "fw termlink dispatch leaks PROJECT_ROOT/FRAMEWORK_ROOT into the host's default
## Context


## Acceptance Criteria

### T-4218: "fw and its hooks accept an inherited PROJECT_ROOT/FRAMEWORK_ROOT of another
## Context


## Acceptance Criteria

### T-4222: "Env leak, second source: an inherited TASKS_DIR/CONTEXT_DIR still steers fw
## Context


## Acceptance Criteria

## 3. lib/paths.sh: the path guard (T-2289, T-4222)

```bash
    if [[ "$(basename "$FRAMEWORK_ROOT")" = ".agentic-framework" ]] \
       && [[ -f "$(dirname "$FRAMEWORK_ROOT")/.framework.yaml" ]]; then
        PROJECT_ROOT="$(dirname "$FRAMEWORK_ROOT")"
    else
        PROJECT_ROOT="$(git -C "$FRAMEWORK_ROOT" rev-parse --show-toplevel 2>/dev/null || echo "$FRAMEWORK_ROOT")"
    fi
fi

# T-2289 (OBS-053 3-incident class): re-derive TASKS_DIR/CONTEXT_DIR when
# they were inherited from a different PROJECT_ROOT. Symptom: shell A exports
# TASKS_DIR=/project-A/.tasks via `fw context init`; a subprocess in project B
# with `PROJECT_ROOT=/project-B fw …` inherits the stale /project-A/.tasks and
# writes go to the wrong project. The `:-` default below silently keeps the
# inherited value when non-empty.
#
# Fix: the `_FW_PATHS_DERIVED_BY` sentinel records the PROJECT_ROOT that
# originally derived the path vars. When it's present AND differs from the
# current PROJECT_ROOT, the inherited paths are stale — unset them so the
# `:-` defaults below re-derive from PROJECT_ROOT.
#
# Test-fixture invariant: when `TASKS_DIR` is set in the SAME shell as
# `PROJECT_ROOT` with no prior derivation, `_FW_PATHS_DERIVED_BY` is empty,
# the unset block is skipped, and the explicit `TASKS_DIR` survives intact
# (this is what tests/unit/create_task.bats:18 relies on).
if [[ -n "${_FW_PATHS_DERIVED_BY:-}" ]] && [[ "$_FW_PATHS_DERIVED_BY" != "$PROJECT_ROOT" ]]; then
    unset TASKS_DIR CONTEXT_DIR
fi

# T-4222 (G-116, second source): with the sentinel absent (unset by a polluted session, or never
# set) an inherited TASKS_DIR/CONTEXT_DIR still survived the `:-` below and steered writes into
# another project. Rule: an inherited value is re-derived (with a stderr warning) when it lies
# outside PROJECT_ROOT AND is itself a project's own dir — basename .tasks/.context whose parent
# carries .framework.yaml. Plain test fixtures (tmp dirs without .framework.yaml) and
# FW_TASKS_DIR_OVERRIDE=1 are honoured unchanged.
if [[ "${FW_TASKS_DIR_OVERRIDE:-0}" != "1" ]]; then
    for _fw_dv in TASKS_DIR:.tasks CONTEXT_DIR:.context; do
        _fw_dn="${_fw_dv%%:*}"; _fw_db="${_fw_dv##*:}"; _fw_dval="${!_fw_dn:-}"
        if [[ -n "$_fw_dval" && "$(basename "$_fw_dval")" == "$_fw_db" \
              && "$(dirname "$_fw_dval")" != "$PROJECT_ROOT" \
              && -f "$(dirname "$_fw_dval")/.framework.yaml" ]]; then
            echo "fw: inherited $_fw_dn=$_fw_dval is outside project $PROJECT_ROOT; using $PROJECT_ROOT/$_fw_db (set FW_TASKS_DIR_OVERRIDE=1 to keep it)" >&2
            unset "$_fw_dn"
        fi
    done
    unset _fw_dv _fw_dn _fw_db _fw_dval
fi

# Common directories
TASKS_DIR="${TASKS_DIR:-$PROJECT_ROOT/.tasks}"
CONTEXT_DIR="${CONTEXT_DIR:-$PROJECT_ROOT/.context}"

# T-2289: record which PROJECT_ROOT derived the path vars, so subprocess
# invocations under a different PROJECT_ROOT can detect the env-leak above.
_FW_PATHS_DERIVED_BY="$PROJECT_ROOT"
export _FW_PATHS_DERIVED_BY

# fw_reanchor_from_cwd <cwd> — re-anchor PROJECT_ROOT + path vars to the project
# root that <cwd> resolves to (walking up for .framework.yaml / .tasks), when it
# differs from the current PROJECT_ROOT. Always returns 0 (no-op cases included).
#
# T-2465 (generalizes T-2463 / OBS-080): a framework hook can execute a `bin/fw`
```

## 4. bin/claude-fw: the tmux re-exec wrapper

```bash
    done
fi
unset FW_CFW_SCOPED_PID

# T-4003 (operator 2026-10-09: "we wanted reliable to work for every project"): peer mail can
# only reach an agent through a terminal something can type into — a TermLink session or a
# tmux pane (lib/sidecar/inject.py c1/c2). A bare terminal window cannot be typed into from
# outside, so its mail waited until someone happened to type there (34 messages, up to 80 h).
# When this session would land on a bare terminal, re-launch it inside a private tmux session
# that behaves like the terminal it replaces: no status bar, and closing the window ends the
# session (destroy-unattached) instead of leaving Claude running hidden. Nothing changes for
# the operator; `claude-fw -c` stays the command. Skipped for --termlink, inside tmux already
# (fleet panes), headless or non-terminal runs, dispatched workers, and when tmux is missing.
# Opt out: FW_CLAUDE_FW_NO_TMUX=1.
_cfw_should_wrap_tmux() {
    [ "$_CFW_RESUMED" = 1 ] && return 1   # T-4118: a re-exec stays where the session already is
    [ "${FW_CLAUDE_FW_NO_TMUX:-0}" = 1 ] && return 1
    [ "${FW_CLAUDE_FW_IN_TMUX:-0}" = 1 ] && return 1
    [ "$TERMLINK_ENABLED" = 1 ] && return 1
    [ "$HEADLESS" = 1 ] && return 1
    [ -n "${TMUX:-}" ] && return 1
    [ -n "${FW_DISPATCHED_WORKER:-}" ] && return 1
    [ -t 0 ] && [ -t 1 ] || return 1
    command -v tmux >/dev/null 2>&1 || return 1
    return 0
}
if _cfw_should_wrap_tmux; then
    _cfw_self="$(readlink -f "$0")"   # this script itself (not a lib/ lookup, T-3954)
    _cfw_name="fw-$(printf '%s' "$(basename "$PWD")" | tr -c 'A-Za-z0-9_-' '_' | cut -c1-40)-$$"
    _cfw_sock=fw-agents   # the tmux server this wrap runs on (-L); the redraw hooks below reuse it
    # tmux does not hand the caller's environment to a new session: pass what matters.
    _cfw_env=(-e FW_CLAUDE_FW_IN_TMUX=1)
    while IFS='=' read -r _k _; do
        case "$_k" in
            FW_*|TL_*|CLAUDE*|ANTHROPIC*|PROJECT_ROOT|FRAMEWORK_ROOT|PATH|HOME|LANG|LC_*|NVM_*|PYTHONPATH|EDITOR|VISUAL)
                _cfw_env+=(-e "$_k=${!_k}") ;;
        esac
    done < <(env | grep -E '^[A-Za-z_][A-Za-z0-9_]*=' | cut -d= -f1 | sort -u | sed 's/$/=/')
    # Its OWN tmux server (-L fw-agents) with no user config (-f /dev/null): never the fleet's
    # server, never the operator's tmux habits. On it tmux must be invisible to Claude Code:
    #   prefix None   — Ctrl-B (Claude Code: background a running command) reaches Claude;
    #   escape-time 0 — Esc interrupts at once (tmux default waits 500 ms for a sequence);
    #   RGB override  — true colour passes through;  status off — no bar.
    # The 055 cockpit's display faults came from its browser bridge (polled relay, competing
    # viewer sizes, 055 T-474); none of that is here: one client, the operator's own terminal.
    # lib/sidecar/inject.py looks for panes on this server as well as the default one.
    # destroy-unattached is set on THIS session only (T-4049, 055 G-014): the server is shared
    # by every wrapped project, and a session inside it inherits $TMUX, so a global setting
    # destroyed every detached session a wrapped agent created (fw termlink dispatch workers).
    # T-4217 (G-116): a tmux server takes its GLOBAL env from the process that starts it. The
    # session's own paths travel via -e below, so the server itself must not inherit the
    # caller's PROJECT_ROOT/FRAMEWORK_ROOT (another project's, if the server is shared).  T-4222: also TASKS_DIR/CONTEXT_DIR.
    # T-4426: after a mouse-wheel scroll into copy mode, on attach and on resize, Claude Code's
    # screen stays cluttered until Ctrl+L. Three hooks send C-l to this session's pane. Each is
    # set on "$_cfw_name" (or its window), never -g: the shared server also carries dispatch
    # workers, and they must not get Ctrl+L. pane-mode-changed is a window hook in tmux 3.4, so
    # it targets "$_cfw_name:"; it fires on every mode change, so it sends C-l only when the
    # pane is back out of its mode (#{pane_in_mode} = 0). run-shell -b expands the formats; a
    # set-hook command that uses if-shell -F silently did nothing (T-4426 measurement).
    exec env -u PROJECT_ROOT -u FRAMEWORK_ROOT -u _FW_PATHS_DERIVED_BY -u FW_ROUTED_FROM -u TASKS_DIR -u CONTEXT_DIR \
        tmux -L "$_cfw_sock" -f /dev/null new-session -s "$_cfw_name" -c "$PWD" "${_cfw_env[@]}" -- "$_cfw_self" "$@" \; \
        set-option -s escape-time 0 \; \
        set-option -g prefix None \; \
        set-option -g prefix2 None \; \
        set-option -g default-terminal tmux-256color \; \
        set-option -as terminal-overrides ',*:RGB' \; \
        set-option -g status off \; \
        set-option -t "$_cfw_name" destroy-unattached on \; \
        set-option -g history-limit 50000 \; \
        set-option -g mouse on \; \
        set-hook -w -t "$_cfw_name:" pane-mode-changed "run-shell -b '[ #{pane_in_mode} = 0 ] && tmux -L $_cfw_sock send-keys -t #{pane_id} C-l'" \; \
        set-hook -t "$_cfw_name" client-attached "run-shell -b 'tmux -L $_cfw_sock send-keys -t #{pane_id} C-l'" \; \
        set-hook -t "$_cfw_name" client-resized "run-shell -b 'tmux -L $_cfw_sock send-keys -t #{pane_id} C-l'"
fi

# TermLink session management
```

## 5. How the project boundary hook derives the project root

```bash
3:# Blocks file modifications and commands targeting paths outside PROJECT_ROOT.
9:# For Write/Edit: extracts file_path, blocks if outside PROJECT_ROOT.
17:#   PROJECT_ROOT/**        — Obviously allowed
96:        "$PROJECT_ROOT"/*)
114:    # another project. `git worktree list` (run against PROJECT_ROOT) only
115:    # enumerates worktrees that share PROJECT_ROOT's own .git — a genuinely
118:    # no-op (empty stdout) when PROJECT_ROOT is not a git repo, which keeps
127:    done < <(git -C "$PROJECT_ROOT" worktree list --porcelain 2>/dev/null | sed -n 's/^worktree //p')
136:    echo "  Project root: $PROJECT_ROOT" >&2
143:    echo "    - $PROJECT_ROOT/**  (project files)" >&2
222:project_root = os.environ.get('PROJECT_ROOT', '')
1029:    echo "  Project root: $PROJECT_ROOT" >&2
```

## 6. Host facts (redacted)

- root has no systemd linger; cron opens and closes root login sessions every minute, so the root user manager and its slice are started and torn down about once a minute
- 50 force-killed teardowns (stop timeout, then SIGKILL) of the root user runtime unit between 2026-10-20 and 2026-10-22, clustered in high-load windows (load 25-75 on 24 cores)
- one shared DEFAULT tmux server hosts every project's claude-fw master session and TermLink-spawned workers; claude-fw also keeps a private server (-L fw-agents)
- projects vendor the framework at different versions (1.8.10 .. 1.8.15-be.2); the guard in section 3 exists only in versions after 2026-10-17
- peers affected 2026-10-22: AEF and TermLink sessions inherited the foreign paths and re-derived (warning only); 055 on 1.8.10 had no guard, its hooks read the other project's focus; no foreign write reported
