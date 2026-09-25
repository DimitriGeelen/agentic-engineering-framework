# F-25 — sibling-worktree blindness in `check-project-boundary` (T-3480)

## 1. Did F-25 reproduce here?

Yes, in both gates, before any change:

- **Write/Edit gate** — `agents/context/check-project-boundary.sh:68-78` (the
  `case "$RESOLVED" in ... esac` allowlist). Reproduced by feeding the hook a
  `Write` call targeting `/opt/aef-f21-f24/scratch-test.txt` (a real sibling
  worktree already present on the host from a prior F21-F24 dispatch, and
  later also `/opt/aef-f25`, this dispatch's own worktree): exit 2, "PROJECT
  BOUNDARY BLOCK — Write Outside Project Root".
- **Bash gate, Pattern 4 (read-side outside-path argument)** —
  `agents/context/check-project-boundary.sh:490-517`. Reproduced with
  `cat /opt/aef-f21-f24/README.md`: exit 2, "Outside-path argument
  ... (not in read-side allowlist)".

Both gates check only `$PROJECT_ROOT` (plus `/tmp`, `/root/.claude`, a few
read-only system prefixes) and have no notion of "another worktree of this
same repository." Confirmed with the genuinely-original, unmodified hook —
this was not a fixture artifact.

## 2. What I changed, and why

Both gates now additionally admit any absolute path that falls under a
worktree `git worktree list --porcelain` reports **when run against
`PROJECT_ROOT`**. `git worktree list` on a given root only ever enumerates
worktrees that share that root's own `.git` — a genuinely unrelated repository
at another path never appears in that list, by construction, so this cannot
be used to admit anything outside the current repository. This is a variant
of the suggestion in the dispatch brief (`git rev-parse --git-common-dir` per
candidate path) chosen because it does not require the candidate path to
already exist on disk — `Write` frequently targets a file that doesn't exist
yet, and `git rev-parse --git-common-dir <not-yet-existing-path>` has nothing
to resolve. Enumerating `PROJECT_ROOT`'s own worktree list sidesteps that.

**Write/Edit gate** (bash): after the existing `case` allowlist, a loop reads
`git -C "$PROJECT_ROOT" worktree list --porcelain | sed -n 's/^worktree //p'`
and exits 0 if `$RESOLVED` is under any listed root. Silent no-op (empty
output, no exit) when `PROJECT_ROOT` is not a git repo — pre-existing
non-git-install / test-fixture behaviour is unchanged.

**Bash gate** (the embedded Python block): added `_worktree_roots(root)` (one
`git worktree list --porcelain` subprocess call, fails closed to `[]` on any
error — not a repo, git missing, timeout) and `_in_sibling_worktree(path)`.
Wired into all four existing patterns that block on an absolute path:
Pattern 1 (`cd`), Pattern 2 (direct `.agentic-framework/bin/fw` invocation),
Pattern 3 (write-redirect `>`/`tee`), Pattern 4 (read-side outside-path
token). Same class of defect, same file, same root cause (`PROJECT_ROOT`-only
comparison) — not a second finding.

Scope held to F-25: nothing here touches how the hook reads text (F-26,
explicitly out of scope) or any other gate.

## 3. Negative control — both halves, real output

**Fixture note:** both fixtures were deliberately built under `/opt`, not
`/tmp`. `/tmp/**` is already unconditionally allowlisted by both gates
regardless of worktree status — a `/tmp`-rooted fixture would pass identically
with or without this fix and would prove nothing. `/opt` is the exact zone the
finding was measured against.

**Half 1 — admitted.** `/opt/aef-f25` (this dispatch's own worktree, created
via `git worktree add ../aef-f25 -b dispatch-f25` from this same repo) and the
pre-existing `/opt/aef-f21-f24` (a sibling worktree from a prior dispatch):

```
$ echo '{"tool_name":"Write","tool_input":{"file_path":"/opt/aef-f25/scratch-test.txt"}}' \
    | PROJECT_ROOT=/opt/999-Agentic-Engineering-Framework bash <fixed hook>
exit=0

$ echo '{"tool_name":"Bash","tool_input":{"command":"cat /opt/aef-f21-f24/README.md"}}' \
    | PROJECT_ROOT=/opt/999-Agentic-Engineering-Framework bash <fixed hook>
exit=0

$ echo '{"tool_name":"Bash","tool_input":{"command":"cd /opt/aef-f25 && ls"}}' \
    | PROJECT_ROOT=/opt/999-Agentic-Engineering-Framework bash <fixed hook>
exit=0
```

**Half 2 — still refused.** A freshly `git init`'d, wholly unrelated repo at
`/opt/f25-foreign-project` (own history, no relation to this repo):

```
$ echo '{"tool_name":"Write","tool_input":{"file_path":"/opt/f25-foreign-project/scratch.txt"}}' \
    | PROJECT_ROOT=/opt/999-Agentic-Engineering-Framework bash <fixed hook>
PROJECT BOUNDARY BLOCK — Write Outside Project Root
exit=2

$ echo '{"tool_name":"Bash","tool_input":{"command":"cat /opt/f25-foreign-project/README.md"}}' \
    | PROJECT_ROOT=/opt/999-Agentic-Engineering-Framework bash <fixed hook>
PROJECT BOUNDARY BLOCK — Command Targets Another Project
  Reason: Outside-path argument /opt/f25-foreign-project/README.md (not in read-side allowlist)
exit=2

$ echo '{"tool_name":"Bash","tool_input":{"command":"cd /opt/f25-foreign-project && ls"}}' \
    | PROJECT_ROOT=/opt/999-Agentic-Engineering-Framework bash <fixed hook>
PROJECT BOUNDARY BLOCK — Command Targets Another Project
  Reason: cd to /opt/f25-foreign-project (outside project root ...)
exit=2
```

Both halves are also pinned as bats tests (not just demonstrated once) —
see §5.

## 4. Property pinned in the test suite

Added to `tests/integration/check_project_boundary.bats`:

- `Write into sibling git worktree of PROJECT_ROOT: allowed`
- `Bash cat inside sibling git worktree of PROJECT_ROOT: allowed`
- `Bash cd into sibling git worktree of PROJECT_ROOT: allowed`
- `F-25 negative control: write into a genuinely foreign repo still blocked`
- `F-25 negative control: bash cat of a genuinely foreign repo still blocked`
- `F-25: PROJECT_ROOT not a git repo still behaves as before (no crash, still blocks)`

Ran the full file (34 tests: 28 pre-existing + 6 new) against the fixed hook:
**33 passed.** The one failure — `Bash redirect to /etc: blocked` (test 16,
pre-existing, unrelated to F-25) — **also fails against the original,
unmodified hook**, confirmed by running the untouched
`tests/integration/check_project_boundary.bats` against the original script
before making any change. It is a pre-existing gap (Pattern 3 explicitly
allow-lists `/etc/cron.d/` as a write target, and Pattern 4 allow-lists all of
`/etc/`, so nothing currently blocks `echo x > /etc/cron.d/y`) — not something
this fix touched, caused, or fixed. Flagging it here rather than silently
leaving a red bat in the suite; out of scope for F-25 to repair.

No pre-existing test that passed before this change regressed.

## 5. Main checkout HEAD — did it move?

Before I touched anything: `git rev-parse HEAD` = `115fc7ea72aa0a2e71be2020434298b32fc4a413`
on `bleeding-edge`.

After finishing the work: `git rev-parse HEAD` = `32f1ca21b05b0965c99da0cd1b0f4d86723b7110`
on `bleeding-edge`. **HEAD did move** — but not because of anything I did. I
made zero `git commit` calls against the main checkout for the entire session.
The move is `T-3479: convergence slice A — dual-read V9, and the fork
dissolved`, authored by the operator's own live persistent session attached to
this same shared checkout (the one the dispatch brief names: `claude -c`, PID
3692337, pts/318) — concurrent, unrelated work landing in the ordinary course
of that session's own use of the checkout. Verified this is a clean
fast-forward, not a divergence I need to reconcile:

```
$ git merge-base --is-ancestor 115fc7ea72aa0a2e71be2020434298b32fc4a413 HEAD && echo ancestor
ancestor
$ git log --oneline 115fc7ea7..HEAD
32f1ca21b T-3479: convergence slice A — dual-read V9, and the fork dissolved
```

`dispatch-f25`'s branch point (`115fc7ea7`) is unaffected and remains exactly
where `git worktree add` left it; I built this commit on top of that same
point via plumbing, not on top of the new tip, so nothing here needed to be
rebased.

## 6. Branch, and confirmation nothing was pushed

Branch: **`dispatch-f25`** (created via `git worktree add ../aef-f25 -b
dispatch-f25`, worktree at `/opt/aef-f25`). The fix + tests were committed
onto it via plumbing from the main checkout
(`hash-object` → `update-index --cacheinfo` against a scratch `GIT_INDEX_FILE`
seeded with `git read-tree dispatch-f25^{tree}` → `write-tree` →
`commit-tree -p dispatch-f25` → `update-ref refs/heads/dispatch-f25`), per the
dispatch brief's prescribed route, since Edit into `/opt/aef-f25` itself is
exactly what F-25 blocks pre-fix and the hook loaded by this session is the
pre-fix one until a fresh session checks this branch out.

**Not pushed.** No `git push` was run against any remote for this branch or
any other.

## 7. Worktree staleness

`/opt/aef-f25`'s **working tree is stale** relative to `dispatch-f25`'s tip:
the plumbing commands moved the branch ref and wrote new blobs/trees into the
object store, but never ran `git checkout` or touched the worktree's files.
`git -C /opt/aef-f25 status` will show the worktree still checked out at the
commit it was created from (`115fc7ea7`), not the new fix commit. A reviewer
should read the diff via `git show dispatch-f25` / `git diff
115fc7ea7..dispatch-f25` from the main checkout, or run `git -C /opt/aef-f25
checkout dispatch-f25 --` (or re-add the worktree) to materialise the files,
rather than opening `/opt/aef-f25` directly and assuming it reflects the
branch.

## 8. Anything that contradicts the finding

Nothing contradicts F-25 itself — it reproduced cleanly and exactly as
described, in both gates. Two adjacent observations, neither of which changes
the finding:

- The pre-existing `/etc/cron.d` write-redirect gap (§4) is unrelated but
  worth a human glance — it means Pattern 3's own allowlist is currently wider
  than Pattern 4's for that one prefix in a way that produces a bats red,
  independent of anything F-25 touches.
- HEAD's movement (§5) could look at first glance like this dispatch broke the
  "main checkout HEAD must not move" constraint. It didn't — it was concurrent
  operator-session activity, confirmed by the ancestor check. Worth naming
  explicitly rather than leaving a reviewer to wonder why HEAD differs from
  what an earlier message in this same thread quoted.

## Scope note

F-25 only, per the dispatch. F-26 (the hook is textual, defeated by hiding a
path inside an invoked script) is untouched and still open in the consuming
project's register.
