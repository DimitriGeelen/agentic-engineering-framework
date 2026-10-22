## Verdict

This is a recurrence of **ambient project authority crossing a shared process boundary**, coupled with a separate lifecycle failure that killed multiple projects together. Environment sanitation alone cannot close either class.

The cross-project read is established; absence of foreign writes is not. The teardown explanation is plausible, but the cited teardown at 13:37:10 precedes final agent output at 13:38:58. Correlate process identities and cgroups before treating that specific teardown as proven causation (§§1, 6).

## Root cause (ranked)

1. **Trusting inherited paths as authority.** Framework operations and the boundary hook accept project identity from potentially contaminated state. A hook enforcing the wrong `PROJECT_ROOT` can authorize the very crossing it should prevent (§§3, 5).
2. **Sharing a project-bearing tmux server.** The first starter establishes defaults for unrelated projects; server death makes this race recur (§§1–2).
3. **Incomplete name-based sanitation.** The fixes removed observed names without enforcing a clean-environment invariant. New names, credentials and override flags remain candidates (§§2, 4).
4. **Environment-based location itself.** Environment variables are acceptable transport for validated configuration, but cannot establish identity independently.

The availability defect is different: long-lived work lacks an explicit, verified lifecycle owner independent of transient logins (§§1, 6).

## Remediation (prioritised, concrete)

**P0 — Contain and preserve evidence.** Inventory affected sessions and descendants, preserve their environment metadata with secrets redacted, then relaunch through a corrected launcher. Clearing server globals does not repair existing sessions or processes. Restrict unpatched framework copies from dispatch/write operations until upgraded or protected at launch (§§1, 6).

**P1 — Establish identity before executing hooks.** Have the launcher resolve an explicit project selection against a canonical project registry/configuration. Derive all four paths together; pass the result to tools and validate it at reads and writes. Working directory is corroborating evidence, not sole authority: agents can change directories.

Refuse conflicting identity or unapproved storage paths before accessing either store. Automatic re-derivation is defensible only when identity is independently established. Replace the §3 heuristic: it misses foreign directories without `.framework.yaml`, alternate basenames and symlink destinations. Canonicalize paths and validate approved worktrees/storage mappings. An inherited `FW_TASKS_DIR_OVERRIDE=1` must not grant an exception.

**P1 — Own server creation.** Use an explicit socket per project, selected by stable identity, and a common launcher for every create/recreate path. Start servers deliberately under supervision with `env -i` plus an exact allow-list of necessary host settings: controlled `PATH`, `HOME`, locale and required runtime settings. Globals should contain no project identity, project credentials, routing state or override flags. Supply validated project/session values explicitly.

An allow-list implemented by constructing a fresh environment is preferable to incremental unsetting. `-f /dev/null` controls configuration loading, not environment inheritance; `set-environment -g -u` is containment, not prevention; constrain `update-environment` so attach cannot reintroduce authority. Handle first-start races and server recreation through the same controlled path (§§1, 4).

A per-hub socket still mixes projects in that hub. A per-user socket changes nothing here. Per-project sockets reduce accidental coupling; separate non-root Unix accounts or stronger isolation are needed for hostile-project containment.

Provide socket-aware attach commands and cockpit aggregation. Migrate sessions by controlled replacement; do not kill the shared server to migrate everyone simultaneously.

**P1 — Own process lifetime.** Run project tmux servers and the hub as supervised system services under dedicated accounts, with explicit resource limits and shutdown policy. A lingering user service is an alternative. Root linger is immediate mitigation, not proof that every existing session-scoped process survives. A differently named scope/slice is insufficient unless its actual ancestry and lifetime escape the disappearing owner. Verify placement after launch and exercise logout/cron teardown (§§1, 6).

## Detection

Block mismatches synchronously before session registration, hooks and store access. Check selected socket, canonical project identity, session environment and resolved paths against registration.

Audit server globals at startup/recreation and periodically; alert without recording secret values. The §4 wrapper forwards broad `FW_*` families, potentially preserving override flags.

Use an external supervisor outside the workers’ failure domain. Heartbeats plus process/unit identity should report a vanished worker within a defined deadline, for example 30 seconds. Silence alone is not death; missing `exit_code` means unknown/interrupted, never success (§1).

## Damage assessment

Preserve repositories, dispatch logs, transcripts and available audit records before cleanup. Examine **all projects**, not just 1409, from 13:39 until the last contaminated descendant exits—not merely 14:55 (§1).

Compare git status/diffs/history, untracked and ignored files, task metadata, focus changes, episodic context, deletions and backups. Correlate timestamps and task IDs with transcripts and worker identities; these are clues, not attribution. Git misses untracked/deleted data; mtimes do not identify writers. Without prior filesystem auditing or equivalent evidence, report uncertainty explicitly. Also investigate foreign reads influencing later decisions.

## What we missed

The fixes lacked end-to-end closure evidence; the supplied task records have empty acceptance criteria (§2). Require polluted-server, absent-server, concurrent-first-client, restart, attach, override and mixed-version tests across every launcher, with evidence attached to G-116 before closure.

The “private” `fw-agents` server is actually shared across wrapped projects (§4). Other analogous state includes shared credentials, SSH agents, runtime sockets, caches, registries and global configuration.

Finally, process death does not itself prove loss of on-disk uncommitted edits. Separate interrupted execution, volatile output and demonstrated filesystem loss.
