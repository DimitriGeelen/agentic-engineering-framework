# arc-012 (continuous-run) — ultrareview scoping + prompt

**Why this file exists.** `/ultrareview` on `bleeding-edge` refuses: the diff vs
`master` is 314 files / 69,006 lines, against limits of 500 files / 8,000 lines.
The blowup is **not** the arc — it is machine-generated churn that rides the same
branch: `.context/project/metrics-history.yaml` alone is 14,902 lines, plus
`watchtower.log`, `watchtower-rss.jsonl`, audit snapshots and `.tasks/` frontmatter.

The prompt does not narrow the diff. **The target does.** So the slice is a branch.

## The slice

Branch `arc012-ultrareview` — synthetic, built off `master`, not for merge.

- **43 files, 5,495 insertions, 153 deletions** — inside both gate limits.
- Derived from the **43 commits** on `master..bleeding-edge` whose subject
  references one of the arc's 36 member tasks or the 7 in-flight tasks below.
- **Excluded on purpose:** `.context/` (machine state), `.tasks/` (frontmatter
  churn), all of `docs/` (generated fabric cards plus 3 prose research
  artifacts — context, not code under review), and `.agentic-framework/` (the
  vendored self-mirror — byte-duplicate of the same code; reviewing it twice
  spends reviewer attention on nothing. Its drift is called out as a directed
  question instead, below).

Rebuild it any time:

```
git branch -D arc012-ultrareview 2>/dev/null; D=$(mktemp -d); export GIT_INDEX_FILE=$D/idx; git read-tree master; git log --format=%H master..bleeding-edge --grep='^(T-2362|T-2363|T-2364|T-2365|T-2366|T-2367|T-2368|T-2369|T-2372|T-2373|T-2379|T-2387|T-2389|T-2390|T-3159|T-3163|T-3164|T-3165|T-3166|T-3167|T-3168|T-3169|T-3170|T-3181|T-3182|T-3202|T-3204|T-3206|T-3209|T-3210|T-3212|T-3213|T-3217|T-3218|T-3219|T-3220|T-3226|T-3225|T-3224|T-3222|T-3215|T-3221|T-3223):' -E | while read c; do git show --pretty=format: --name-only $c; done | grep -vE '^$|^\.context/|^\.tasks/|^docs/|^\.agentic-framework/' | sort -u | while read f; do git cat-file -e "bleeding-edge:$f" 2>/dev/null && git update-index --add --cacheinfo "$(git ls-tree bleeding-edge -- $f | awk '{print $1}'),$(git rev-parse bleeding-edge:$f),$f" || git update-index --force-remove "$f"; done; git branch -f arc012-ultrareview $(git commit-tree $(git write-tree) -p master -m 'arc-012 review slice'); unset GIT_INDEX_FILE; git diff --shortstat master..arc012-ultrareview
```

## How to run it

```
cd /opt/999-Agentic-Engineering-Framework && git switch arc012-ultrareview
```

then `/ultrareview` (no arg — reviews the branch against `master`), pasting the
prompt below. Return with `git switch bleeding-edge` when the review lands; the
slice branch is disposable (`git branch -D arc012-ultrareview`).

If `/code-review ultra <branch>` accepts a *target* branch on this build, that
works from `bleeding-edge` without switching — try it first and fall back.

---

## The prompt

Review arc-012 ("continuous-run") of the Agentic Engineering Framework: the
mechanism that lets a long-running Claude Code agent cross a context-budget
boundary unattended and keep working, bounded by explicit ceilings.

**The headline mechanic the code must deliver:** the agent crosses the
context-budget threshold with no operator relay → `checkpoint.sh` fires a
self-trigger → handover is written and the session resumes via `claude-fw` → the
operator observes a multi-cycle continuous session whose iteration counter,
directive and bounded tier-ceiling are all visible in `fw resume status`.

This is governance-critical shell and Python. The loop runs unattended, so a
defect does not surface as a crash — it surfaces as a run that quietly does the
wrong thing for hours, or a gate that reports success without checking anything.

### Where the risk actually is

This arc's own history is dominated by **one failure class: the false green** —
an instrument that reports OK because it never looked. Confirmed instances
already fixed inside this very diff:

- **T-3219** — the P-011 verification gate ran 2 of 4 commands and reported pass.
  A command consuming stdin swallowed the remaining lines from the loop's input.
- **T-3217** — a skipped `bats` test reports `ok`; the P-011 idiom cannot
  distinguish "passed" from "never ran".
- **T-3218** — an HTTP 200 was being treated as evidence the page was read.
- **T-3209** — `fw doctor` inferred a *cause* from the mere absence of a file,
  and blamed the operator for a loop it had not diagnosed.
- **T-3220** — a code comment stated a false reason for an exit path; the
  measured behaviour differed.
- **T-3202** — a timing record could not distinguish *which* ceiling killed a run.
- **T-3226** — doctor reported the Stop hook missing while it was running.

**Weight your attention accordingly.** For every assertion, check, gate and
health line in this diff, ask the question that class demands: *can this report
success without having tested its subject?* Prefer a finding that names a
specific input under which a check passes vacuously over a stylistic note.

### Directed questions

1. **Two ceilings, two units (`lib/continuous-mode.sh`).** The state file carries
   `current_iteration/max_iterations` counted in **sessions** (advanced by
   SessionStart) and `tasks_completed/max_tasks` counted in **tasks** (advanced
   on the work-completed transition). Before T-3164 these were accidentally the
   same number. Can they now desync in a way that lets a run exceed a ceiling the
   operator believes is binding, or terminate on a ceiling they did not set?

2. **Arm/disarm writes two files (`fw_continuous_cli`, T-3225).** Arming sets
   `enabled`, `current_iteration`, `last_terminated_reason` in
   `.continuous-mode.yaml` **and** `filed_at`/`expires_at` in
   `.next-directive.yaml`, because `stop-driver.sh` reads expiry from the
   *directive* first. What happens on a partial write, a crash between the two,
   or concurrent arm from two sessions? Can the loop end up `enabled: true` while
   stopping instantly on a stale expiry — the exact bug this verb was built to
   remove?

3. **Stored vs. computed state.** `status` is documented as re-evaluating the
   predicate chain live, printing `last_terminated_reason` only as an explicitly
   labelled *stored* string — because the log once recited a frozen `now` for 74
   days, reading as current while being a replay. Audit every place this diff
   prints state: is anything recited that the reader will take as computed?

4. **Human-gate stop (`fw_continuous_note_human_gate`, T-3212).** The rule is
   STOP AND NOTIFY, not park-and-take-the-next-task. Can any path route past a
   human gate, or record a stop whose reason does not name the gate that caused
   it?

5. **Never fail a close.** `fw_continuous_note_task_completed` runs on the
   completion path of *every* task in the project and must be a silent no-op when
   disabled, when the state file is missing/unreadable, or when python3/pyyaml
   are absent. Is that total? It is also required to be idempotent per task id
   (partial-complete tasks re-enter the same transition after a human ticks their
   ACs) — verify double-counting is impossible.

6. **Command-safety surface** (`agents/context/lib/safe-commands.sh`, T-3222,
   T-3221). Two admission holes were just closed: `curl -o` / `wget -O` were
   safe-listed unconditionally despite writing files, and a `git commit`
   exemption matched a *mention* of the string rather than a command in command
   position. Both are parser-shaped bugs on a security gate. Look for siblings:
   other flags that write, other exemptions matched by substring rather than
   position, quoting/escaping, and argument-order assumptions.

7. **Budget gauge (`lib/context_tokens.py`, `agents/context/budget-gate.sh`,
   T-3204).** The gauge divided by a constant window. Is the cap now correct
   across models with different context windows, and does it *say* which model it
   applies to?

8. **Test quality.** ~15 new `.bats` suites and `tests/lint/bats-silent-skip.bats`
   + `tools/bats-silent-skip-lint.py` ship here — the lint exists precisely
   because skips were invisible. Do the new tests actually exercise the
   mechanism, or do they assert on strings/mocks that would stay green if the
   implementation were deleted? Flag any test with a control leg missing (one
   that cannot distinguish "fires correctly" from "never fires").

9. **Vendor parity — already measured, confirm the structural fix.** The repo
   vendors a self-copy at `.agentic-framework/`. At time of writing it is
   **behind**: `.agentic-framework/lib/continuous-mode.sh` is missing the entire
   198-line `fw_continuous_cli` function T-3225 just shipped, and
   `.agentic-framework/bin/fw` is behind on T-3158. The mirror is excluded from
   this diff, so do not review its contents — instead judge whether anything in
   the diff makes this sync structural, or whether it stays a manual step that
   will drift again. A capability that exists in `lib/` but not in the copy
   consumers actually run is a capability that does not exist.

### Out of scope

Do not report on: `.context/` state files, `.tasks/` frontmatter, generated
fabric cards, CLAUDE.md prose, or the vendored `.agentic-framework/` mirror's
contents (see Q9 — the *policy* is in scope, the duplicated bytes are not).

---

## Loose end worth fixing regardless of the review

Five of the seven in-flight tasks that produced this code — **T-3215, T-3222,
T-3224, T-3225, T-3226** — carry an empty `arc_id:` and empty `tags:`, despite
T-3225 being literally `fw continuous arm/disarm/status`. `fw arc show
continuous-run` therefore cannot see them, and the arc's completion ratio and
stale-arc audit are both computed over an undercount. The arc's 36 members split
awkwardly across two schemes as it is: 19 by `arc_id:`, 19 by legacy
`tags: [arc:continuous-run]`, overlapping in 2.
