# T-3466 — Dispatch fix: F-15 (read-only allowlist gaps) and F-17 (git-commit task-file dirt)

Worker report for a dispatched, one-turn fix against two findings reported by a
consuming project (vendored at framework 1.6.768, `version_sha:
a6bea48819460a0f250f8983a48fca267e422483`). Both findings were re-derived
against this repo's current source before any edit, per the dispatch contract's
"gatherer/judge were not separated" confidence penalty.

Branch: `t-dispatch-f15-f17-safe-commands-fix`. **Not pushed.**

## F-15 — read-only allowlist refuses two everyday read-only shapes

**Reproduced: partially — one shape confirmed and fixed, one shape confirmed
and deliberately left unfixed (see below).**

### Shape 1: `VAR=$(readonly-cmd)` — reproduced, fixed

Confirmed pre-fix at `agents/context/lib/safe-commands.sh` (the file's own
T-2834 header comment, lines 51-57, states command substitution is
"Deliberately NOT handled" and files the gap as OBS-185):

```
$ source agents/context/lib/safe-commands.sh
$ is_bash_safe_command 'X=$(git status)'; echo $?
1          # pre-fix: refused, although `git status` alone is allowlisted
```

**Fix:** added a narrow recognizer in `_fw_single_command_is_safe`
(`agents/context/lib/safe-commands.sh:266-298`, inserted right after the
existing T-2834 whitespace trim) that matches ONLY a terminal, whole-segment
assignment — `^[A-Za-z_][A-Za-z0-9_]*=\$\(.*\)[[:space:]]*$` — and delegates
the captured inner command back through the top-level chain-aware entry point
`is_bash_safe_command` (not a second call into the single-command function),
so a substitution containing `&&`-joined clauses requires every clause to be
independently safe. This is deliberately narrower than the general "$(...)
anywhere on the line" case the T-2834 comment excludes: a *terminal* assignment
has no outer command for an inner one's safety verdict to bleed into, which is
exactly the risk that comment's exclusion was protecting against for the
general case (e.g. `curl "$(fw watchtower url)/page"`).

### Shape 2: `python3 -m pytest` — reproduced, deliberately NOT fixed

Confirmed pre-fix and post-fix (unchanged):

```
$ is_bash_safe_command 'python3 -m pytest tests/foo.py -q'; echo $?
1
```

**Not fixed, and this is the most valuable finding in this report.** The same
file already states, for the adjacent filter category a few lines below the
`python3|python` arm, that `bats`, `make`, `python3 <file>` and `./script.sh`
are **deliberately excluded** because "a file's contents are not visible to a
command-string scan, so executing one is never provably read-only"
(`safe-commands.sh:568-570`, citing CLAUDE.md §Enforcement Tiers, T-2742, the
Tier 0 scope boundary). `python3 -m pytest <path>` imports and executes every
test module (and `conftest.py`) under `<path>` — the identical class of
"execute unseen file content" the codebase already refuses for its siblings.
Implementing the dispatch's suggested widening as specified would have
silently reopened a hole this same function closes on purpose two case arms
away. There is no narrower safe form either — `--collect-only` still imports
and executes module-level code during collection.

This directly **contradicts** the dispatch's framing of shape 2 as a simple
allowlist gap parallel to shape 1. It is not: shape 1 is an unmeasured gap in
an otherwise-sound category (command substitution wrapping an already-safe
read); shape 2 is a measured, intentional exclusion the dispatch is asking to
override. Declined; documented in the task's Decisions section with full
rationale.

### Checks (negative controls included, per the dispatch's F-15 requirement)

```
$ bash -c 'source agents/context/lib/safe-commands.sh; is_bash_safe_command "X=\$(git status)"; echo rc=$?'
rc=0                                                          # PASS — was rc=1
$ bash -c 'source agents/context/lib/safe-commands.sh; is_bash_safe_command "X=\$(rm -rf /tmp/x)"; echo rc=$?'
rc=1                                                          # PASS — negative control: substitution wrapping a genuine write still gates
$ bash -c 'source agents/context/lib/safe-commands.sh; is_bash_safe_command "python3 -m pytest tests/foo.py -q"; echo rc=$?'
rc=1                                                          # PASS — deliberately still refused (see above)
$ timeout 300 bats tests/unit/safe_commands*.bats
1..122
... (all 122 "ok", 0 "not ok")
exit=0
```

Also verified, beyond the two AC-pinned cases:

```
X=$(echo $(hostname))          -> 0   (nested substitution, correctly extracted)
X=$(git status && rm -rf /tmp) -> 1   (unsafe clause inside substitution still gates)
```

**Known limitation, not fixed (documented in Decisions):** `_fw_chain_split`
(the top-level splitter) does not track parentheses, only quotes. A chain
operator *inside* a substitution on an otherwise-terminal assignment, e.g.
`X=$(git status && echo ok)`, gets split at the top level before reaching the
new recognizer, so the resulting fragments match nothing and the whole line
stays gated (verified this is pre-existing, not a regression, via `git stash`
against the unmodified source — same `1` result). Fixing it would mean
teaching `_fw_chain_split` itself about parens, a materially larger change to
the file's most load-bearing function, and neither dispatch reproduction case
needs it.

## F-17 — `fw git commit` dirties the task file it just committed

**Reproduced, live, against the real repo (not a sandbox) — confirmed and
fixed for the common flow, with a scoped, documented exception.**

Confirmed at `agents/git/lib/commit.sh`: pre-fix, `git commit` ran at (was)
line 172, and `update_task_timestamp` (a `sed -i` on the task file's
`last_update:` frontmatter field, `agents/git/lib/common.sh:45-54`) ran
**after**, at (was) line 177. Live reproduction, committing this very task's
own ACs:

```
$ git add .tasks/active/T-3466-....md
$ bin/fw git commit -m "T-3466: write real ACs for F-15/F-17 dispatch fix"
[t-dispatch-f15-f17-safe-commands-fix 629438236] T-3466: ...
 1 file changed, 325 insertions(+)
$ git status --short .tasks/active/T-3466-....md
 M .tasks/active/T-3466-....md          # dirty immediately after a successful commit
$ git diff .tasks/active/T-3466-....md
-last_update: 2026-09-25T11:24:53Z
+last_update: 2026-09-25T11:28:19Z
```

Note: the dispatch's description said the commit "appends its Updates entry"
after the commit; what this repo's `commit.sh` actually does is narrower —
it rewrites only the `last_update:` frontmatter field, not a body `## Updates`
entry — but the **symptom is identical**: a successful commit leaves the tree
dirty, always one commit behind.

**Fix:** in `agents/git/lib/commit.sh`, moved the timestamp write and its
`git add` to *before* `git commit` runs (new block at lines 105-136), for the
**non-bypass, no-pathspec** flow — the everyday `git add -A && git commit`
form CLAUDE.md documents as the standard post-completion pattern. The
post-commit block (previously lines 172-186) now only prints the informational
"Task updated" message, reusing the pre-computed `commit_task_file` rather
than re-deriving it.

**Deliberately scoped exception — pathspec-scoped commits (T-3090) keep the
OLD (post-commit) ordering.** First attempt auto-appended the task file to any
given `--` pathspec so its bump could ride the same commit. That **broke 2 of
`tests/unit/handover_commit_scope.bats`'s existing, pinned T-3090 tests** —
which assert a pathspec-scoped commit takes *exactly* the given paths, a
deliberate safety property protecting a concurrent writer's staged-but-
uncommitted work (origin: incident commit `d3d3e49db`, documented in that
test file's own header). Silently widening a caller's explicit path scope
would have been the same class of defect T-3090 was filed to close, just
against a different file. Reverted the auto-injection; pathspec-scoped
commits (handover-class callers) now fall back to the pre-fix post-commit
ordering, so F-17 is fixed for the finding's described symptom (the ordinary
flow) but not universally. Documented as a Decision in the task file.

### Checks

Live, against this repo (the commit above was real, on this branch, task
T-3466's own file):

```
$ git add .tasks/active/T-3466-....md
$ bin/fw git commit -m "T-3466: [message]"
[branch sha] T-3466: ...
$ git status --short .tasks/active/T-3466-....md
                                          # (empty — clean, post-fix)
```

Test suites, before vs after, all green (0 `not ok` in every run):

```
tests/integration/fw_git.bats
tests/unit/git_common.bats
tests/unit/t3179_partial_complete_commit.bats
tests/unit/t3221_commit_exemption_clause.bats
tests/unit/handover_commit_scope.bats        # includes all 9 T-3090 pathspec tests
tests/unit/inception_commit_counter.bats
tests/unit/git_log.bats
tests/unit/git_install_hooks_git_path.bats
tests/unit/git_identity_check.bats
tests/unit/git_worker_commits.bats
tests/unit/t2996_seed_commit_assertion.bats
tests/governance/test_git_hooks.bats
```

(First attempt at the fix, before the pathspec exception was added, failed
`handover_commit_scope.bats` tests 47 and 48 — see Decisions in the task
file for the exact failure and the fix that resolved it.)

## Gates that refused me, and what I did instead

- **G-020 (build-readiness gate)** refused my first Bash exploration command
  because T-3466 had placeholder ACs. I wrote real ACs (Steps/Expected-style,
  file:line-anchored) before touching any source file — no `--force`, no
  `--skip-*`.
- No other gate refusal encountered. All commits went through `bin/fw git
  commit` normally (task-referenced, no `--bypass`, no `--no-verify`).

## Branch and push state

- Branch: `t-dispatch-f15-f17-safe-commands-fix`, based on `bleeding-edge`.
- Commits so far: the ACs-write commit (`629438236`), plus this report and
  the two source fixes will follow in a further commit.
- **Not pushed.** `git log`/`git status` confirm no `git push` was run this
  session.

## Anomalies found — not mine, flagged for the operator

1. **Ambient working-tree drift at session start** was extensive (dozens of
   `docs/generated/components/*.md`, `.context/monitors/*`, `VERSION`, etc.) —
   pre-existing, not touched, not committed by this work.
2. **A background BVP-estimator process** rewrote `bvp_scores_proposed` /
   `cost_estimate_proposed` blocks into T-3466's own task file mid-session,
   and separately bumped `last_update:` on an unrelated, already-closed task
   (`T-3090-handover-auto-commit-sweeps-the-whole-in.md`, `date_finished:
   2026-08-19`) with no commit message from me referencing it. Not caused by
   this dispatch's commits (neither commit message mentions T-3090).
3. **A concurrent automated handover commit landed on this feature branch**
   mid-session (`bdf9d9b86 "T-3090: Session handover S-2026-0925-1326"`,
   author `Dimitri Geelen`, touching only `.context/handovers/*`) — evidence
   that some other process on this host is committing to whatever branch is
   currently checked out in this shared working tree, not scoped to a
   worktree of its own. Worth the operator's attention independent of this
   dispatch; not reverted or altered here.

None of the three affected the correctness of the two fixes above — verified
by re-running every check after each anomaly was observed.
