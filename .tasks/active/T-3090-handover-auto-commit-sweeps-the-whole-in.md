---
id: T-3090
name: "handover auto-commit sweeps the whole index, absorbing another session's staged
  work"
description: >
  handover auto-commit sweeps the whole index, absorbing another session's staged
  work

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [bug, git, handover, concurrency]
components: [agents/git/lib/commit.sh, agents/handover/handover.sh, tests/unit/handover_commit_scope.bats]
related_tasks: [T-3089, T-3028]
created: 2026-08-19T21:41:28Z
last_update: 2026-08-23T18:31:31Z
date_finished: 2026-08-19T21:52:38Z
cost_estimate_proposed:
  - ts: '2026-08-19T21:45:07Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=139,acs=7)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-19T21:45:13Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 1
      F-AUTONOMY: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=3 (body:test-or-audit-check); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=1 (body:episodic-only); 
      F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=1 
      (body/components:context-fabric-incidental); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3090: handover auto-commit sweeps the whole index, absorbing another session's staged work

## Context

`fw handover --commit` stages exactly two files and then commits the **entire
index**. Any file another session had already `git add`-ed — but not yet
committed — is swept into the handover commit and attributed to the handover's
task, not the author's.

Measured, not inferred. `agents/handover/handover.sh:1421` stages narrowly:

```bash
git -C "$PROJECT_ROOT" add "$HANDOVER_FILE" "$HANDOVER_DIR/LATEST.md"
```

There is no `git add -A` anywhere in the handover path. The sweep is at the
commit: `agents/git/lib/commit.sh:70` and `:113` both run

```bash
git -C "$PROJECT_ROOT" commit -m "$message" "${git_args[@]}"
```

with **no pathspec**, so git commits whatever the index holds.

Live instance, 2026-08-19: commit `d3d3e49db` "T-3028: Session handover
S-2026-0819-2334" contains 4 files — the 2 handover files it staged, plus
`tests/lint/no-backticks-in-quoted-strings.bats` and
`.tasks/active/T-3089-lint-forbid-backticks-in-quoted-bash-str.md`, which
belonged to a concurrent session working T-3089. That session had staged them
and was composing its commit message; between its `git add` and its `fw git
commit`, the index came back empty because the handover had already committed
them. The T-3089 rationale is therefore absent from the commit that carries the
code (it survives in the file header and the task file, both committed).

This is the same class as the `focus.yaml` singleton: a single-writer assumption
in a system that now demonstrably has concurrent writers. The framework's own
answer to concurrency is worktree isolation, but nothing *requires* it, and the
staging area is shared per-checkout regardless.

**Scope fence:** this task fixes the commit-side pathspec leak only. Whether two
agent sessions should share one checkout at all is an operator decision, tracked
separately.

## Acceptance Criteria

### Agent
- [x] `do_commit` in `agents/git/lib/commit.sh` commits only what the caller
      intends: either a pathspec is threaded through, or the pre-existing index
      is preserved and restored, so a concurrently-staged file cannot be absorbed.
- [x] `agents/handover/handover.sh` passes its two handover files as an explicit
      pathspec to the git agent, so the handover commit is scoped by construction
      rather than by the index happening to be clean.
- [x] A regression test asserts the leak is closed: with an unrelated file staged
      by a simulated second writer, a handover-shaped commit contains ONLY the
      handover files and the unrelated file remains staged and uncommitted.
- [x] The same test carries a **positive control** (L-616): the handover files
      themselves ARE in the commit. Without it, a `do_commit` that commits
      nothing at all passes the leak assertion.
- [x] Every existing caller of `agents/git/git.sh commit` still commits what it
      used to — the ordinary single-session `git add` then `fw git commit` flow
      is unchanged, verified by test, not by inspection.
- [x] Test runs in a sandbox git repo under `$BATS_TEST_TMPDIR`, never against
      this working tree (T-3077 isolation-by-construction).

### Human
- [ ] [REVIEW] The two-sessions-per-checkout question is an operator call, not a
      code fix — confirm the scope fence above is where you want it.
  **Steps:**
  1. Read the Scope fence paragraph in `## Context` above.
  2. Decide whether concurrent sessions on one checkout should be *prevented*
     (worktree isolation enforced) or merely *survivable* (this fix).

  **Expected:** Either "the fix is enough, sessions may share a checkout" or a
  follow-up task to enforce isolation.

  **If not:** Say which, and a follow-up task gets filed.

## Verification

bash -c 'set -eo pipefail; bash -n agents/git/lib/commit.sh'
bash -c 'set -eo pipefail; bash -n agents/handover/handover.sh'
out=$(bats tests/unit/handover_commit_scope.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
out=$(bats tests/governance/test_pretooluse_gates.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'

## RCA

**Symptom:** Commit `d3d3e49db`, titled "T-3028: Session handover
S-2026-0819-2334", contains two files belonging to a different session's task
(T-3089). The authoring session's staged index was emptied out from under it
mid-compose.

**Root cause:** `agents/git/lib/commit.sh` runs `git commit -m "$message"` with
no pathspec. `git commit` without a pathspec commits the whole index. The
handover's narrow `git add` of two files therefore scopes *staging*, not
*committing* — and staging is only half the operation.

**Why structurally allowed:** three things compose.

1. **The index is per-checkout, not per-session.** Nothing in the framework
   models it as shared state, so no gate guards it. `focus.yaml` has the same
   shape and was found the same day.
2. **The narrow `git add` reads as scoping.** Anyone auditing
   `handover.sh:1421` sees two explicit paths and concludes the commit is
   bounded. It is bounded only when the index was already empty — which is the
   single-session case, i.e. every case anyone tested.
3. **The failure is invisible in the success path.** A swept commit succeeds,
   pushes, and looks correct. Nothing reports "this commit contains files you
   did not stage". It surfaced only because a human-attended second session
   noticed its own `git add` had evaporated.

**Prevention:** the regression test in the ACs is the rail — it stages an
unrelated file as a simulated second writer and asserts it survives. The
pathspec fix alone would silently regress the moment someone adds a `git add`
to the handover path for convenience; the test pins the invariant rather than
the implementation.

## Decisions

### 2026-08-19 — mechanism was misdiagnosed as `git add -A`; corrected before fixing

- **Chose:** Fix the missing pathspec at `git commit`, after grepping the whole
  handover path for `git add -A` and finding none.
- **Why:** The reporting session diagnosed a "blanket `git add -A`" in
  `fw handover --commit`. `grep -rn "git add" agents/handover/ lib/ bin/fw`
  returns no such call; the only `add -A` occurrences are two `echo`'d
  suggestion strings in `lib/init.sh`. Had the reported mechanism been taken at
  face value, the fix would have been to remove a line that does not exist, the
  test would have passed for the wrong reason, and the real leak would have
  survived.
- **Rejected:** Acting on the peer report as written. Effect reported by another
  agent is evidence; mechanism reported by another agent is a hypothesis.

### 2026-08-19 — the first draft of the regression suite was itself inert

- **Chose:** Route every refutation through a `_refute_in_head` helper that uses
  an explicit `if … then return 1`, and never through a bare `! cmd`.
- **Why:** Mutation testing caught the suite lying. With pathspec forwarding
  disabled, test 1 — the headline leak assertion — stayed **green**. Cause:
  `! cmd` in non-final position inside a bats body is inert, because `set -e`
  is specified to ignore the status of a command inverted with `!`. Only the
  final line of a body is checked, since bats uses the body's own return value
  there. Pinned by direct measurement:

      @test "non-final" { ! grep -qx peer f; true; }   -> ok      (WRONG)
      @test "final"     { ! grep -qx peer f; }         -> not ok  (right)

  The leak assertion was decorative and the positive control was carrying the
  whole test. This is a sibling of L-387 (pipefail/SIGPIPE) and L-616 (two empty
  sets are equal): assertions that look like they check something and do not.
- **Rejected:** Shipping the suite on the strength of 9/9 green. A green suite is
  evidence of nothing until a mutation shows which tests it discriminates.

### 2026-08-19 — `git commit -- <path>` needs the path TRACKED; the caller's add stays

- **Chose:** Keep the `git add` in both handover legs, and pin the requirement
  with a test.
- **Why:** The first version of the code comment asserted that a pathspec commit
  "does not need the paths to have been `git add`-ed first". Measured false:
  an untracked path fails the whole commit with `pathspec '<p>' did not match
  any file(s) known to git`. Since a handover file is new every session, deleting
  the add as now-redundant would turn every handover commit into a hard failure.
- **Rejected:** Simplifying the callers to pathspec-only.

### 2026-08-19 — regression fixture avoids `--no-verify`

- **Chose:** `--cleanup=verbatim` as the flag-passthrough fixture.
- **Why:** The Tier 0 hook classifies `--no-verify` as a hook bypass and blocks
  on the command string, so a test using it files a real approval card on the
  operator's live queue on every run — the T-3077 class this repo just spent a
  task cleaning up. Confirmed the hard way: the exploratory sandbox command that
  established this behaviour filed one.
- **Rejected:** `--no-verify`. Any flag exercises the same argv path, so there is
  no coverage cost.

## Recommendation

**Recommendation:** GO

**Rationale:** The leak is closed at both legs and the fix is mutation-proven,
not merely green. The single open question is scope, not correctness: whether two
sessions sharing one checkout should be prevented outright rather than made
survivable. That is an operator call, which is why it is the one Human AC.

**Evidence:**
- Root cause measured, not inferred: `git commit` with no pathspec commits the
  whole index; `agents/handover/handover.sh` was staging narrowly and committing
  broadly. Live instance `d3d3e49db` carried 4 files, 2 of them foreign.
- Fix: `--` pathspec threaded through `do_commit` into a single assembled argv
  shared by both call sites; both handover legs now pass their own files.
- 9/9 green, and mutation-discriminating in both directions: disabling pathspec
  forwarding turns tests 1-4 red; removing the pathspec from the callers turns
  test 9 red. Controls 5-8 stay green under both, so the suite is not failing
  wholesale.
- Backward compatibility pinned: with no pathspec the whole index is still
  committed, so every existing `git add` + `fw git commit` caller is unchanged.
- Both source files verified byte-identical to their pre-mutation state.
- Two of my own errors were caught by that mutation pass and are recorded above
  rather than quietly fixed: an inert test assertion, and a false claim about
  tracked-ness in a code comment.

## Updates

### 2026-08-19T21:41:28Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3090-handover-auto-commit-sweeps-the-whole-in.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-fd76e3d9
- **Timestamp:** 2026-08-19T21:52:45Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-19T21:52:38Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
