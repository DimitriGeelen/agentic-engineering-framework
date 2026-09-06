# T-3289 — Observation Triage, Worker 3

Scope: OBS-305 OBS-306 OBS-307 OBS-308 OBS-315 OBS-317 OBS-353 OBS-355 OBS-356 OBS-358.
Method: each entry read in full from `.context/inbox.yaml`, then verified against current
code, `.tasks/completed/`, git history since capture, and live host state. Read-only run;
no inbox/concerns/tasks mutation.

**Tally: 3 PROMOTE / 7 DISMISS / 0 DEFER**

---

## OBS-305 — pre-push exit-75 gate: stale advice + Tier-0-only escape

**Verdict: PROMOTE** — task: *"pre-push exit-75 branch: truthful wait guidance + Tier-2
contention-only bypass"*, workflow_type: build. AC: the exit-75 block message states
realistic lock-hold durations (drawn from the T-3127 timing record, not the "minute or
two" folklore) and a logged Tier-2 env bypass exists for contention-only exit 75, distinct
from Tier-0 `git push --no-verify`.

- Most of the observation is already addressed: T-3062 fixed the 60s push window
  (completed 2026-08-17), T-3070 fixed the cron schedule collision and delegated
  `audit schedule install` to the registry (completed 2026-08-24, commit d4787e61b),
  every cron audit job now runs under a per-job `flock -n /var/lock/agentic-cron-*.lock`
  wrapper (`.context/cron-registry.yaml:37,54,64,87,97,106`) — the "cron overlap guard"
  the OBS asked for. T-3126 partitioned ref- vs worktree-scoped FAILs; T-3127 records
  per-run timing.
- What did NOT ship, verified live: `agents/git/lib/hooks.sh:1152` still says
  *"Usually the daily cron audit — it finishes within a minute or two"*, while T-3127 AC1
  measured the full audit at **1729s** (OE-DAILY alone 824s) — during that daily window
  the advice is wrong by an order of magnitude. And the only documented escape is still
  Tier-0 `git push --no-verify` (`hooks.sh:1157`), exactly the "pushes agents toward
  Tier 0 for a routine push" defect the OBS names. Same gate-credibility class the repo
  already codified at T-3096/G-084 (a gate stating a false cause teaches agents to route
  around it).

## OBS-306 — correction: "the audit is blocked, not slow"

**Verdict: DISMISS** — overtaken by T-3070's measurement; its valid asks shipped.

- T-3070 (completed 2026-08-24) disentangled exactly the two candidate causes this OBS
  conflated, and partially refuted it: raw runtime IS real for the full audit (1729s
  measured, `.tasks/active/T-3127-*.md` AC1), while pre-push contention was found "brief
  and self-resolving" (T-3070 scope correction in `.tasks/completed/T-3070-*.md`).
- The overlap-guard ask shipped: per-job `flock -n /var/lock/agentic-cron-*.lock -c`
  wrappers in `.context/cron-registry.yaml` mean a colliding cron run skips instead of
  queueing; `audit.sh:458` `flock -n` + exit 75 means an audit never waits on the shared
  lock either.
- The "audit.sh re-invoking itself as a child with identical args" mystery is the
  watchdog: `agents/audit/audit.sh:475-480` forks a subshell (which inherits the parent's
  cmdline in ps) whose only job is `sleep && kill -TERM $$`. Not a self-deadlock shape.

## OBS-307 — "each blocked push leaves a hung audit holding the lock"

**Verdict: DISMISS** — the self-poisoning model does not survive a read of the code, and
the real underlying class was fixed by T-3062/T-3063.

- `audit.sh:456-465` acquires with `flock -n` and exits 75 immediately on contention — an
  audit spawned by pre-push structurally cannot queue or "block waiting" on the lock. The
  T-1772 fd-close fix (commit fdde765af, **2026-05-06** — three months before this
  capture) already prevented the watchdog's sleep child from carrying FD 200.
- The observed evidence fits a lock-WINNING audit mid-run: a shell parent legitimately
  shows ~0 CPU / state S while its grep/subprocess children do the work (the structure
  section took 300s+ at capture time per T-3062), and the "child audit.sh with same args"
  is the watchdog subshell (see OBS-306 above). fuser listing it on the lock is the
  parent's fd 200.
- The class that actually recurred — pushes killed by session teardown mid-audit, unnoticed
  — was root-caused and fixed as T-3062 (window) + T-3063 (killed-vs-blocked distinction),
  both completed 2026-08-17, the day after capture. Remaining true root cause (lock-path
  unlink) is promoted via OBS-308.

## OBS-308 — audit.sh unlinks the flock'd lock path in its EXIT trap

**Verdict: PROMOTE** — task: *"audit.sh: stop unlinking the flock'd lock path — migrate
to lib/keylock.sh exclusive()"*, workflow_type: build. AC: two concurrent `audit.sh` runs
can never both hold the lock across the unlink/recreate race (pinned by a bats test), and
no EXIT trap `rm -f`'s the lock path.

- Verified still present, three sites: `agents/audit/audit.sh:482` (flock-arm EXIT trap
  `rm -f '$AUDIT_LOCK_FILE'` while the lock is held via fd 200), `:451` (stale-lock
  cleanup rm), `:507` (fallback-arm trap). Unlinking a flock'd path lets the next process
  create a fresh inode at the same path and flock it — two audits "holding the lock" at
  once, exactly as the OBS describes.
- The migration target exists and was never adopted: `lib/keylock.sh` (exclusive-lock
  acquisition at `:85`) and `lib/keylock.py` (whose docstring documents the
  inode-not-path invariant). No commit since capture touches the audit lock block
  (git log on `audit.sh` since 2026-08-16 shows T-3062/3070/3126/3127/3202 — none touch
  the trap).
- Second defect also still present: the trap kills only `$AUDIT_TIMEOUT_PID` (the
  subshell); the `sleep` child reparents and lives up to `AUDIT_TIMEOUT` (600s). Defanged
  since T-1772 (fds closed, so it no longer holds the lock) but still an orphan — fold
  the process-group kill into the same task.

## OBS-315 — B-005 covers Write/Edit only; block message overclaimed

**Verdict: DISMISS** — already fixed by T-3050 (completed 2026-08-17, same day as capture).

- The OBS itself says the message fix was underway "under T-3050"; that landed. The block
  message no longer claims "requires human review" — it now names the sanctioned route
  and carries an explicit scope note: *"B-005 covers Write/Edit on this path only. It does
  not read the file's..."* (`agents/context/check-active-task.sh:449,467-469`).
- T-3050's ACs (A2 "the message stops overclaiming", ticked) recorded the scope decision
  in the task file. The reach boundary the OBS wanted "registered" is now self-documenting
  at the exact surface an agent reads when blocked, mirroring the CLAUDE.md Tier-0
  scope-boundary precedent it cites. No residual action.

## OBS-317 — 17 satisfied-but-unclosed active tasks; rail needed

**Verdict: DISMISS** — the rail it argued for shipped as T-3061 (completed 2026-08-17)
plus T-3074 (its tests committed, 2026-08-18).

- `fw audit` now generates `.context/audits/unclosed-satisfied/LATEST.md` (commit
  e0e58030c "the satisfied-but-unclosed rail, with one definition of the rule"). The file
  is live and currently lists 14 qualifying tasks — the measurement is continuous, so the
  inbox no longer needs to carry the snapshot.
- The exact caveat the OBS demanded is in the rail's output verbatim: *"A ticked box is a
  claim, not evidence... Each row below is a candidate for close, never a closure"*
  (`unclosed-satisfied/LATEST.md`), including the empty-Verification scrutiny note.
- T-3060 (the sweep this OBS reports) closed 2026-08-17 with commit 43651098d noting
  "OBS-317 carries the measurement" — carried, and now superseded by the recurring rail.

## OBS-353 — G-020 gate blocks both of its own prescribed escapes

**Verdict: PROMOTE** — task: *"allowlist G-020's own prescribed remedies in
safe-commands.sh"*, workflow_type: build. AC: with the G-020 gate firing (focused
build task with placeholder ACs), `bin/fw task update <id> --type inception` executes
from the blocked state — verified by running the remedy WHILE the gate fires, per the
observation's own lesson.

- Not fixed. Commit defcaa55d ("T-3181: register OBS-353") only added the observation to
  `.context/inbox.yaml` — nothing landed in `concerns.yaml` (grep of all 24 entries: no
  OBS-353 / G-020 remedy entry) and no fix task exists.
- The gate still prints the refused remedy verbatim: `check-active-task.sh:1092-1094`
  ("Or change to inception: `fw task update $CURRENT_TASK --type inception`"), while
  `agents/context/lib/safe-commands.sh` has no `task update` arm — only
  `work-on|inception` bootstrap (`:644`) and read-only fw sub-verbs. Post-capture commits
  to both files (T-3174, T-3245, T-3231, T-3222/3223/3221) touch other gates.
- The secondary finding (an automated process created T-3215 in started-work with template
  ACs and took focus twice) has no dedicated fix either — the parent should consider
  splitting it into its own observation rather than losing it inside this promote
  (one bug = one task).

## OBS-355 — class observation: character-level scan treats a MENTION as the thing

**Verdict: DISMISS** — class already codified as L-547; all three cited instances have
shipped fixes or filed tasks; no residual action distinct from the learning.

- The class is L-547 (`.context/project/learnings.yaml:4192`, T-2834) with at least two
  follow-on learnings elaborating it (`:4513` remedy-reachability, `:4519` positional
  token readers), and the principle is embedded at the code sites that matter:
  `_fw_strip_quoted` state machine (`safe-commands.sh:945` region), T-3245's
  quote-stripped commit predicate, T-3223's splitter fix.
- Instance (1): `tools/bats-silent-skip-lint.py` now has a quote-tracking `strip_quotes`
  state machine (`:68-87`) crediting the peer fix — the heredoc/quoted-string blindness
  is fixed. Instance (2): T-3217 is in `.tasks/completed/`. Instance (3): the read-refusal
  false-positive class is filed as T-2410 and the misleading block message was fixed by
  T-3096 (real-reason output, `check-active-task.sh:359` region).
- The "generalisable ask" is a review question, not a mechanism — as prose it duplicates
  L-547, which recall already serves.

## OBS-356 — has_bash_write_pattern refuses a commit whose MESSAGE mentions `rm -rf`

**Verdict: DISMISS** — the measured defect is fixed by T-3245 (commit e33e8e749
"quote-strip the commit-checkpoint write-pattern check", in `.tasks/completed/`).

- Reproduced the OBS's exact test live against current code:
  `is_commit_checkpoint_command 'git commit -m "note: we no longer rm -rf the output dir"'`
  now returns **ADMIT**. The predicate judges a quote-stripped view
  (`safe-commands.sh:1005-1007`) exactly as the OBS's "fix shape" prescribed.
- `has_bash_write_pattern` itself still scans the raw string (`:778-807`), but that is a
  documented, deliberate scope decision (`:996-1005`): keeping the general scanner
  quote-blind fails toward BLOCKING and confines the stripped view to the two commit
  call sites — a general rewrite is explicitly named as a separate, larger change. The
  class-level concern is covered by L-547 (see OBS-355).

## OBS-358 — `fw init` ran with cwd=/tmp; /tmp became a project; test premise unasserted

**Verdict: DISMISS** — the pollution is gone and the structural fix shipped as T-3234.

- Host state today: `/tmp/.framework.yaml`, `/tmp/.tasks`, `/tmp/.context`,
  `/tmp/.agentic-framework`, `/tmp/.claude`, `/tmp/.git` all absent (verified 2026-09-06).
- The test now asserts its own premise in prose, citing this OBS by ID:
  `tests/unit/check_active_task_cwd_resolution.bats:118-127` ("PREMISE: /tmp has no
  .framework.yaml/.tasks above it... it has been false on this host before... OBS-358,
  T-3234") and points a red run at the new guard.
- The guard exists: `tests/lint/no-project-markers-above-bats-tmpdir.bats` (commit
  cf399722a, "a corpus-level guard for the ancestry every hook suite silently depends
  on") — it names the offending directory and distinguishes host movement from code
  regression, which was the OBS's actionable ask. The root-level `/.framework.yaml` +
  `/.tasks` still exist but remain outside the walk by design (stops before `/`), as the
  test comment records.
