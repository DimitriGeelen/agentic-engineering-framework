# Incident review brief (SEV-1): cross-project environment leak through a shared tmux server

(Same brief as TermLink's T-3549 reviewers; the attached bundle adds the AEF side: the full RCA, the earlier
gap G-116 and its three fix tasks, the framework's path guard, the claude-fw tmux wrapper, and the host facts.
The bundle also covers the second half of the incident: the host slice teardown that killed every session.)

You are one of seven independent reviewers. Investigate deeply, think adversarially, and propose remediation.
Disagreeing with our current thinking is useful. Answer in English, at most ~900 words, markdown, with the sections
listed at the end. Answer from the bundle; cite its section numbers.

## System

- **AEF (agent framework).** Each software project on a Linux host has its own directory with a task store
  (`.tasks/`), a context store (`.context/`) and a vendored copy of the framework. Framework tools locate a project
  through environment variables, notably `PROJECT_ROOT`, `FRAMEWORK_ROOT`, `TASKS_DIR` and `CONTEXT_DIR`. AI coding
  agents (Claude Code) run one per project, usually inside a tmux session.
- **TermLink** is a Rust substrate on the same host. It runs a hub, registers terminal sessions, and has `termlink
  spawn` / dispatch commands that start new terminal sessions, usually with `tmux new-session` on the host's
  **default** tmux server. That one server is shared by every project and every user agent on the host, because all
  run as the same Unix user.
- **tmux behaviour that matters:** the first client to start a server passes its own environment, and the server
  keeps it as its **global environment**. Every session started on that server later inherits the global environment,
  unless the variable is overridden per session (`new-session -e K=V`) or listed in `update-environment`.

## What happened (2026-10-22)

1. **13:38.** Under host load, systemd force-tore down the root user's slice (root does not linger; cron churns root
   login sessions every minute). The default tmux server died, and every session inside it was killed: agent
   sessions of several projects and AEF's six running worker agents (no exit code, uncommitted work lost).
2. **The next `termlink spawn`** came from project **1409-sprind**. It started a new default server, and that
   server's global environment received 1409's `TASKS_DIR` and `CONTEXT_DIR`.
3. **13:39–14:55.** Every session started or restarted on the host inherited those two variables, including
   relaunched agents of other projects and TermLink's own agent session.
4. **14:55.** AEF cleared the server's global environment. Sessions started after that are clean.
5. **Containment that held:** framework versions ≥ 1.8.13 detect "inherited `TASKS_DIR` outside project" and
   re-derive the path, with a warning only. Older vendored copies (e.g. 1.8.10, project 055) followed the inherited
   paths: 055's hooks read 1409's focus. No foreign write has been reported; damage is not yet measured.

## This is a recurrence

- **2026-10-16:** a dispatch from one project started the default server, and five agents ran with that project's
  `PROJECT_ROOT` / `FRAMEWORK_ROOT`; one project created two tasks inside another. Registered as AEF gap G-116
  (still open). Fixes: TermLink T-3445 (deny-list of variables stripped from the tmux client: PROJECT_ROOT,
  FRAMEWORK_ROOT, _FW_PATHS_DERIVED_BY, FW_ROUTED_FROM, CLAUDE_PROJECT_DIR), AEF T-4217/T-4218 (dispatch strips paths;
  claude-fw sets PROJECT_ROOT/FRAMEWORK_ROOT itself), AEF T-4222 (re-derive a foreign TASKS_DIR/CONTEXT_DIR, warn).
- **The gap:** `TASKS_DIR` and `CONTEXT_DIR` were on no deny-list, and claude-fw does not set them. G-116's own close
  condition ("a polluted-server test shows a clean session") was never met.
- **Second failure class in the same incident:** the framework never checks whether its long-lived processes can be
  killed from outside (cgroup placement, user linger); 50 force-killed slice teardowns in three days went unseen, and
  earlier session deaths were misattributed.

## Questions for you

1. **Root cause.** What is the real defect class? Name-based deny-list, sharing one tmux server across projects,
   environment-variable project location, or the framework trusting inherited paths? Rank them.
2. **Source-side guard.** Deny-list vs allow-list vs `env -i` (clean environment plus an explicit minimal set) for the
   tmux client. What should the server's global environment contain, and how do you start a server with a clean
   environment when any client may be the first? Consider per-project or per-hub sockets, `-f /dev/null`,
   `set-environment -g -u`, `update-environment`, and starting a dedicated server deliberately before use.
3. **Isolation boundary.** One tmux socket per project? Per hub? Per Unix user? The cost: attach habits, cockpits that
   list sessions, existing sessions, restarts of the shared server under load.
4. **Detection.** A detector for a polluted server environment, or for a session whose project variables disagree with
   its working directory or registration. Where should it run, and how fast must it fire?
5. **Damage assessment.** How to find out, after the fact, whether any process wrote into another project's
   `.tasks`/`.context` in the window: git status, mtimes, task ids out of sequence, episodic files, audit logs.
6. **Framework side.** Should the framework refuse rather than warn when inherited paths point outside the project?
   What about old vendored copies? Should project identity come from the environment at all?
7. **Process survival.** How should long-lived agent processes be placed so a login-session or slice teardown cannot
   kill them (linger, dedicated systemd scope/slice, a service), and how should a vanished worker be detected?
8. **Why the 2026-10-16 fixes did not prevent this,** and what closing discipline would have caught it.
9. **Anything we have not thought of,** including other shared host state with the same shape.

Sections: **Verdict** · **Root cause (ranked)** · **Remediation (prioritised, concrete)** · **Detection** ·
**Damage assessment** · **What we missed**.
