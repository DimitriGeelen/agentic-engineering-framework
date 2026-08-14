# T-2704 — Cross-host hook path portability (RCA + proposal)

**Task:** T-2704 (inception)
**Date:** 2026-07-31
**Status:** RCA complete, guard written and proven RED. Awaiting human GO before generator fix.

---

## 0. Headline

The absolute hook paths in `.claude/settings.json` are **not an oversight — they are a
deliberate, incident-driven remediation** (T-1364, T-1504) that solved a real problem
(relative paths break under CWD drift; 680 silent failures downstream) by picking the
wrong one of two options in a **false dichotomy**.

The framing was *relative vs absolute*. The third option — `${CLAUDE_PROJECT_DIR}/bin/fw`,
which is **absolute after expansion** and therefore satisfies T-1364's constraint **while
staying host-portable** — has never appeared in this repo's history.

The remediation then **pinned its own framing as a test invariant**
(`tests/unit/hook_absolute_paths.bats`), so from 2026-04-20 onward portability was not
merely unimplemented — it was *actively enforced against*. Meanwhile `fw doctor` prints
the words **"all portable"** for the current 25/25 non-portable state.

---

## 1. Evidence — who writes the hook `command` string

Current state, verified 2026-07-31:

```
grep -cE '"command": "/' .claude/settings.json    -> 25   (raw lines)
grep -c  'CLAUDE_PROJECT_DIR' .claude/settings.json -> 0
python: unique (event,type,command) tuples          -> 23
python: non-`bin/fw hook` command entries           -> 0
top-level keys in settings.json                     -> ['hooks']
```

All 25 read `/opt/999-Agentic-Engineering-Framework/bin/fw hook <name>`.

### Two generators, one shape

| # | Site | file:line | Emits | Rationale comment |
|---|------|-----------|-------|-------------------|
| 1 | `generate_claude_code_config()` | `lib/init.sh:617-620` | `$dir/.agentic-framework/bin/fw`, or `$dir/bin/fw` when `$dir/bin/fw` is executable **and** `$dir/FRAMEWORK.md` exists | `lib/init.sh:613-616` — T-1364 (G-053-A) |
| 2 | `fw hook-enable` | `bin/hook-enable.sh:116-119` | identical two-shape logic on `$project_dir` | `bin/hook-enable.sh:107-114` — T-1504 |

`$dir` / `$project_dir` are canonicalised absolute paths (`cd … && pwd`), so the emitted
string is the **generating host's checkout path**, baked in permanently.

`lib/upgrade.sh` does **not** contain a third copy of the string-building logic — it
*delegates* to generator #1 (`lib/upgrade.sh:1390` and `:1465`, both
`( force=true; generate_claude_code_config "$target_dir" )`). It does, however, own the
**decision of whether to regenerate at all** (`lib/upgrade.sh:1298-1391`), which is where
the migration problem lives (§5).

**The duplication is real but shallow:** two sites build the string, and both are the
*same two-branch shape*. That is the important detail for the fix — the framework/consumer
split is duplicated, so a fix applied to one site silently leaves the other emitting the
old form. `bin/hook-enable.sh:112` literally says *"Mirrors init.sh:584"* — the duplication
was known and accepted at the time.

### The framework-vs-consumer split is real

- **Framework repo** (this one): has `bin/fw` + `FRAMEWORK.md` at root → `<root>/bin/fw`.
- **Consumer project**: no root `bin/` → `<root>/.agentic-framework/bin/fw`.

A generator emitting one form for both is wrong in one of the two cases. Any fix must
preserve this branch and only replace the *absolute prefix* with the placeholder:

- framework → `${CLAUDE_PROJECT_DIR}/bin/fw hook <name>`
- consumer  → `${CLAUDE_PROJECT_DIR}/.agentic-framework/bin/fw hook <name>`

---

## 2. Five Whys

**Symptom:** clone this repo to any host with a different checkout path and all 25 hooks
fail to resolve; governance is silently off.

1. **Why do hooks break on a foreign host?**
   `.claude/settings.json` hardcodes `/opt/999-Agentic-Engineering-Framework/bin/fw`,
   which does not exist there.

2. **Why is it hardcoded?**
   Both generators interpolate the *generating host's* canonicalised root (`$dir`,
   `$project_dir`) into the command string at generation time
   (`lib/init.sh:617`, `bin/hook-enable.sh:116`).

3. **Why do the generators emit absolute rather than portable paths?**
   Because **T-1364 (`fb3e51764`, 2026-04-20) deliberately changed them from relative to
   absolute.** The diff is literally
   `- "command": "bin/fw hook pre-compact"` → `+ "command": "/opt/999-…/bin/fw hook pre-compact"`.
   Reason given: *"Claude Code resolves hook commands against session CWD. When CWD drifts
   (test fixtures, subdir navigation), relative paths cascade into hook-cannot-find-fw
   tool-blocks."* T-1504 then extended the same change to the second code path
   (`hook-enable.sh`), citing **680 silent failures in one session** at downstream consumer
   `003-NTB-ATC-Plugin`. **These were real bugs and the diagnosis was correct.**

4. **Why did the fix stop at "absolute" instead of "absolute *and* portable"?**
   Because the problem was framed as a **binary**: relative (portable, broken) vs absolute
   (works, non-portable). `$CLAUDE_PROJECT_DIR` — which is *absolute after expansion*, and
   so satisfies T-1364's CWD-drift constraint at zero cost to portability — dissolves the
   dichotomy. It was never considered:
   `git log -S'CLAUDE_PROJECT_DIR' -- .claude/settings.json` returns **empty for the entire
   history of the file**. The third option was not rejected; it was invisible, because the
   framing admitted only two.

5. **Why did nothing surface the false dichotomy for the next ~3 months?**
   Because **T-1364 shipped `tests/unit/hook_absolute_paths.bats` alongside the change,
   which encodes the framing as a permanent invariant.** It asserts every hook command
   starts with `/` (`:20-40`, `:44` against *this repo's own* settings.json) and explicitly
   asserts the portable forms are **absent** (`:95-96`,
   `! grep -qE '"command": *"bin/fw hook'`). A correct portable fix
   (`${CLAUDE_PROJECT_DIR}/bin/fw`) does not start with `/` and therefore **fails the
   existing test suite**. The remediation converted its own assumption into a guard, and
   the guard now defends the defect.

**Root cause:** a correct fix to a real bug (CWD-drift) was applied under a
two-option framing, and the remediation's own regression test froze that framing into an
invariant — so the missing third option became structurally unreachable rather than merely
unchosen.

### Was it ever portable, or never? — *Both, precisely.*

This matters and the answer is not "it never landed":

| Date | Commit | Form | Portable? |
|------|--------|------|-----------|
| 2026-02 | `4d91a343f` T-496 | `fw hook <name>` (bare, PATH-resolved) | yes (weakly — depends on PATH) |
| — | `2de3bba9d` T-663 | `bin/fw hook <name>` (relative) | yes (weakly — depends on CWD) |
| **2026-04-20** | **`fb3e51764` T-1364** | **`/opt/999-…/bin/fw hook <name>`** | **no — regression** |
| — | T-1504 | same, second code path | no |
| never | — | `${CLAUDE_PROJECT_DIR}/bin/fw` (strong form) | — |

So: **portability in the weak sense existed and was deliberately regressed on
2026-04-20.** Portability in the *strong* sense (placeholder — CWD-independent *and*
host-independent) has never existed.

### Why the doc disagrees with the artifact

`docs/claude-code-settings.md:108` claims *"All hooks use portable paths
(`.agentic-framework/bin/fw hook <name>`) — no hardcoded absolute paths (T-496/T-498)."*

The doc header says **"Last updated: 2026-03-15"**. T-1364 landed **2026-04-20**.

**The doc was true when written** and was invalidated ~5 weeks later by T-1364, which
changed the artifact and its test but not the prose. This is doc-drift caused by a
deliberate reversal, not a doc that was ever aspirational. The doc is therefore *evidence
of the regression*, not evidence of a fix that never landed.

---

## 3. Why no gate caught it

Four independent surfaces could have caught this. Each fails for a different reason, and
one of them **reports the opposite of the truth**.

### 3a. `fw doctor` Check 6 — predicate is shaped for the *previous* generation of the bug

`bin/fw:1123-1181`. Two counters:

- `broken` — *does the executable exist and is it `+x`?* On the host that generated the
  file, `/opt/999-…/bin/fw` always exists → `broken = 0`, **by construction, forever.**
- `stale_paths` — the isolation check. Predicate (`bin/fw:1160`):
  `if '/agents/context/' in cmd or 'PROJECT_ROOT=' in cmd`.
  That is the **pre-T-496 defect shape** (direct paths to hook scripts). The current shape
  — an absolute path to `bin/fw` — matches neither clause → `stale = 0`.

So the check that exists to detect "works here, breaks on clone" is looking for a defect
signature that was retired two fixes ago.

### 3b. `fw doctor` states the false conclusion out loud

`bin/fw:1177-1178`:

```
elif [ "${hook_total:-0}" -ge 10 ]; then
    echo "  OK  Hook path validation: $hook_total hooks, all portable"
```

`broken == 0 && stale == 0 && total >= 10` prints **"all portable"** — a property it never
tested. On this host, today, with 25/25 hardcoded absolute paths, `fw doctor` affirms
portability. This is worse than silence: an operator checking for exactly this problem is
told it is fine. (Same class as L-525 — the narration layer asserting more than the
measurement underneath it supports.)

### 3c. Hook exercise from `/tmp` (T-1629) tests the wrong axis

`bin/fw:1230-1253` runs hooks from a foreign **CWD** — which absolute paths pass
*trivially and by design*. It proves CWD-independence (T-1364's axis). It cannot prove
**host**-independence, because it never leaves the host.

### 3d. The unit test pins the defect

`tests/unit/hook_absolute_paths.bats` — see Why #5. This is the decisive one: the other
three are blind, but this one is **hostile to the fix**. Any correct patch turns the suite
red until the test is rewritten in the same commit.

### The general shape

> A check that can only fail on a machine that never runs it is not a check.

The brief's phrasing is right but *generous* here. On a foreign host `broken` would fire —
but only as `FAIL: 25/25 broken paths`, i.e. reporting the **symptom** (file missing) on a
fresh clone where governance is already off and nobody is running `fw doctor`. The
**class** (non-portable path) is detectable *on the generating host, right now, cheaply* —
and no surface looks for it. That is the gap the guard in §6 closes.

---

## 4. Does `${CLAUDE_PROJECT_DIR}` actually work? (verify, don't assume)

**Confirmed** via Claude Code documentation (Hooks reference,
`https://docs.claude.com/en/docs/claude-code/hooks`), retrieved 2026-07-31:

- `$CLAUDE_PROJECT_DIR` **is** usable inside a hook `command` in `settings.json`; the docs
  give a worked example of exactly this shape:
  `"$CLAUDE_PROJECT_DIR"/.claude/hooks/protect-files.sh`.
- **Both shell form and exec form support the same path placeholders**, and both **export
  `CLAUDE_PROJECT_DIR`, `CLAUDE_PLUGIN_ROOT`, `CLAUDE_PLUGIN_DATA` as environment
  variables on the spawned process.**

**Therefore, answering the brief's two open questions:**

1. **Expansion in `command`: yes, supported and documented.**
2. **Exec form (`command` + `args`) is *not required*.** The docs state both forms support
   the same placeholders. Exec form is an available alternative, not a prerequisite. Our
   fix can stay in shell form, which is a much smaller diff.

**Confidence caveat, stated plainly:** this was obtained via documentation *search*
(WebFetch of the docs page was not permitted in this session, so I could not pull the
verbatim page text). The two claims above are consistent across the shell/exec description
and the worked example, and the mechanism is independently corroborated in-repo — `bin/fw:191`
already documents *"Claude Code exports it"* about `CLAUDE_PROJECT_DIR` in the hook
environment, and T-2390 depends on that being true in production. **Recommend one empirical
confirmation** (§8 AC) before merging the generator change: register one hook with the
placeholder and confirm it fires.

Note a subtlety that does not change the conclusion: in **shell form** the expansion may be
performed by the spawned shell (the var is exported) rather than by literal substitution in
Claude Code. Either path yields the same resolved absolute argv. The guard in §6 accepts
both `$CLAUDE_PROJECT_DIR` and `${CLAUDE_PROJECT_DIR}` spellings.

---

## 5. Candidate fixes

### Candidate A — `${CLAUDE_PROJECT_DIR}` placeholder in both generators *(recommended)*

Change the prefix only; keep the two-branch framework/consumer split intact.

```sh
# lib/init.sh:617-620 and bin/hook-enable.sh:116-119
local fw_prefix='${CLAUDE_PROJECT_DIR}/.agentic-framework/bin/fw'
if [ -x "$dir/bin/fw" ] && [ -f "$dir/FRAMEWORK.md" ]; then
    fw_prefix='${CLAUDE_PROJECT_DIR}/bin/fw'
fi
```

Note the **detection** still uses `$dir` (correct — we must inspect the real filesystem to
decide which shape applies); only the **emitted string** becomes a placeholder. In
`lib/init.sh` the heredoc is intentionally unquoted (`<< SJSON`, `:624`) so `$fw_prefix`
expands — the literal `${CLAUDE_PROJECT_DIR}` inside `fw_prefix` must therefore be
single-quoted at assignment as above, or it will be eaten by the generating shell. **This
is the single most likely way to get this patch wrong.**

- **Pro:** absolute after expansion → fully preserves T-1364/T-1504's CWD-drift fix. Portable
  across hosts and clones. Smallest diff. No new runtime machinery. Fixes both generators
  identically.
- **Con:** requires rewriting `tests/unit/hook_absolute_paths.bats` in the same commit
  (it asserts `startswith('/')`). Requires the empirical confirmation in §4. Depends on a
  Claude-Code-specific feature (acceptable — the file is already Claude-Code-specific).
- **Con:** does not by itself migrate existing consumers — see §5.1.

### Candidate B — runtime self-heal at `SessionStart`

A hook that checks whether its own `fw` path resolves and rewrites `settings.json` if not.

- **Pro:** repairs existing broken consumers with no operator action.
- **Con:** **circular** — the repair hook is itself registered by an absolute path, so on
  the very host where everything is broken, the repairer cannot start either. Fatal as a
  primary fix. Also self-mutating governance config trips the T-1888/L-398 enforcement
  baseline on every session.
- **Verdict:** reject as primary. A *degenerate* variant (a `fw doctor --fix` operator
  verb) is viable as a migration aid.

### Candidate C — relative path + a wrapper that chdirs

- **Verdict:** **reject outright.** This is precisely the state T-1364 and T-1504 reverted,
  at a documented cost of 680 silent failures. Re-proposing it would be a re-regression.

### Candidate D — exec form (`command` + `args` array)

- **Pro:** no shell re-parse; unambiguous argv; robust to spaces in paths.
- **Con:** larger diff across both generators, both doctor parsers (`bin/fw:1123`,
  `lib/upgrade.sh:1300`), the upgrade hook-extractor, and the enforcement baseline. Per §4
  it buys **no additional placeholder support** — both forms expand identically.
- **Verdict:** not now. Reasonable follow-up; orthogonal to portability.

### Candidate E — bare `fw` on `PATH`

- **Verdict:** reject. This is the T-496 form that T-663 replaced; it resolves to whichever
  global shim happens to be installed, which CLAUDE.md §Copy-Pasteable Commands explicitly
  warns against ("may resolve to a stale global install").

### 5.1 What happens to existing consumers — *this is the trap*

`fw upgrade` **does** regenerate settings.json (`lib/upgrade.sh:1390`, `:1465`, both calling
`generate_claude_code_config` with `force=true`) — **but only when a "reason" fires.** The
reason is computed by `check_stale_paths()` / missing-hook diff at `lib/upgrade.sh:1300-1356`,
and that predicate has the **same blind spot as doctor's**:

- absolute `/other-host/…/bin/fw hook X` contains `'fw hook'` → not `stale`, not `non_framework`
- hook *names* extracted match the framework's → `missing = 0`

→ **`reason` never fires → no regeneration → the consumer stays broken even after
`fw upgrade`.**

So Candidate A alone ships a fixed generator that **no existing consumer ever invokes**.
The fix must therefore be **two-part**:

- **A1** — generators emit the placeholder (§5 Candidate A).
- **A2** — extend the stale predicate in *both* `lib/upgrade.sh:1329` and `bin/fw:1160` to
  flag "hook command contains an absolute filesystem path instead of the placeholder", so
  `fw upgrade` recognises the old shape and regenerates, and `fw doctor` stops printing
  "all portable" at consumers that are not.

A2 is the same predicate as the guard in §6 — write it once, use it in three places.

---

## 6. Prevention guard

**File:** `tests/lint/hook-paths-portable.bats` (run by `bin/fw test invariants`, which
globs `tests/lint/*.bats` — `bin/fw:7538`).

**Rule:** every hook `command` in a tracked `settings.json` must reference `fw` via the
`${CLAUDE_PROJECT_DIR}` placeholder, never via a literal absolute filesystem path.

### Proven RED against the current state — mutate-then-check

Per the brief: *a guard you have not watched fail is not a guard.* Both directions were
exercised.

```
$ bats tests/lint/hook-paths-portable.bats
   (against live .claude/settings.json, 25/25 absolute)
   -> RED, 1 of 3 tests failing, output names the offending commands
```

Full transcript and the GREEN-on-fixed-fixture run are recorded in §7.

### False-positive surface — checked, currently empty

```
python: non-`bin/fw hook` command entries in .claude/settings.json -> 0
top-level keys                                                     -> ['hooks']
```

There are **no** legitimately-absolute non-hook entries today, so the guard has no live FP
surface. But one *can* exist: `fw hook-enable --script <abs-path>`
(`bin/hook-enable.sh:29,121`) registers a project-local script by absolute path, and
`lib/upgrade.sh:1345` already contemplates non-framework hooks. The guard therefore scopes
its assertion to **framework `fw hook` commands** and reports foreign-script entries as a
separate informational count rather than failing on them — so a project registering its own
hook is not blocked by a framework invariant. A dedicated test pins this non-FP behaviour.

---

## 7. Guard implementation + verification transcript

**Shipped:** `tests/lint/hook-paths-portable.bats` (3 tests). Confirmed picked up by
`bin/fw test invariants` (which globs `tests/lint/*.bats`, `bin/fw:7538`).

### 7.1 RED against the current 25/25 state — as required, watched failing

```
$ bats tests/lint/hook-paths-portable.bats
1..3
not ok 1 hook paths: every framework hook command uses ${CLAUDE_PROJECT_DIR}, not a hardcoded absolute path
# FAIL: 25 of 25 framework hook command(s) hardcode an absolute path.
#
# Hook commands must resolve on ANY host. Use the placeholder, which expands
# to an absolute path (so CWD-drift protection from T-1364/T-1504 is kept):
#   framework repo:  ${CLAUDE_PROJECT_DIR}/bin/fw hook <name>
#   consumer:        ${CLAUDE_PROJECT_DIR}/.agentic-framework/bin/fw hook <name>
#
# Do NOT hand-edit settings.json — fix the generators (lib/init.sh:617,
# bin/hook-enable.sh:116) and regenerate, then refresh the enforcement
# baseline (bin/fw enforcement baseline). See T-2704.
#
# Offending entries:
#   - PreCompact: /opt/999-…/bin/fw hook pre-compact
#   - PreToolUse: /opt/999-…/bin/fw hook check-active-task
#   … (25 total, every entry named)
ok 2 hook paths: settings.json declares a plausible number of framework hooks
ok 3 hook paths: project-local --script registrations are not flagged (no false positive)
```

Test 2 passing matters: it proves the RED in test 1 is a **real** detection over 25 live
commands, not a vacuous pass over an empty/unparsed file.

### 7.2 GREEN on a placeholder-fixed fixture — the other direction

A copy of the live settings.json with `/opt/999-Agentic-Engineering-Framework` →
`${CLAUDE_PROJECT_DIR}` (25 substitutions), scanned via `FRAMEWORK_ROOT=<fixture>`:

```
$ grep -c 'CLAUDE_PROJECT_DIR' $tmp/.claude/settings.json
25
$ FRAMEWORK_ROOT=$tmp bats tests/lint/hook-paths-portable.bats
1..3
ok 1 hook paths: every framework hook command uses ${CLAUDE_PROJECT_DIR}, not a hardcoded absolute path
ok 2 hook paths: settings.json declares a plausible number of framework hooks
ok 3 hook paths: project-local --script registrations are not flagged (no false positive)
```

So the guard flips RED→GREEN on exactly the change Candidate A makes, and on nothing else.

### 7.3 No false positive on project-local absolute registrations

Test 3 is a fixture pinning the FP boundary directly (not prose): a settings.json holding
one placeholder framework hook **and** one legitimately-absolute project script
(`/opt/some-project/.claude/hooks/my-own-hook.sh`). Asserted: `fw_total == 1`,
`offenders == 0`, `foreign == 1`. Passes in every run above.

### 7.4 Verifying the §3d claim — first attempt was invalid, corrected

I claimed in §3d/Why-5 that `tests/unit/hook_absolute_paths.bats` **rejects** the portable
fix. First attempt to prove it ran that suite against a placeholder fixture via
`FRAMEWORK_ROOT=<fixture>` and returned **4/4 ok** — apparently refuting my own claim.

That run was **invalid**, not exculpatory: `tests/test_helper.bash:15` does
`export FRAMEWORK_ROOT="$(_find_framework_root)"` **unconditionally**, clobbering the
override, so test 1 re-read the real (absolute) settings.json and tests 2-4 build their
fixtures from the *current* generator — which still emits absolute. The experiment could
not have observed the placeholder form at all.

Re-verified by evaluating that suite's own predicate (`hook_absolute_paths.bats:20-40`)
directly on the portable form:

```
$ python3 …  # bin_path = cmd.split()[0]; fail if not bin_path.startswith('/')
VERDICT: existing test would FAIL (rejects the fix)
  flagged: PreToolUse: ${CLAUDE_PROJECT_DIR}/bin/fw hook check-active-task
```

`${CLAUDE_PROJECT_DIR}/bin/fw` does not start with `/`, so it lands in `bad` → exit 1.
**Claim confirmed:** the existing suite is hostile to the fix and must be rewritten in the
same commit (build slice A1). Recording the bad experiment because a passing test that
silently tested nothing is the same failure class as §3b — a green signal that measured
something other than what it claimed.

---

## 8. T-2446 / T-2390 interaction — checked explicitly

**Question:** does Claude Code's placeholder expansion interact with `bin/fw`'s
`CLAUDE_PROJECT_DIR` trust-narrowing (T-2390 introduced trust; T-2446 narrowed it against
the daemon-poison class)?

**Answer: no. There is no interaction, and it does not outrank the rest.** Reasoning, with
the mechanism named at each step:

1. `CLAUDE_PROJECT_DIR` is **already exported into every hook process today**, regardless of
   what the command string says — confirmed by the Claude Code docs (§4, "both forms export
   them as environment variables on the spawned process") and relied upon in-repo at
   `bin/fw:191-230`, which is live in production.
2. Therefore using the placeholder in the command string **introduces no new environment
   exposure and no new trust surface**. The variable the trust-narrowing guards is present
   either way.
3. Expansion resolves the string to an absolute path **at/just-before `exec`**. By the time
   `bin/fw` runs its `PROJECT_ROOT` resolution (`bin/fw:203-230`), it sees ordinary argv and
   an ordinary environment — byte-identical in shape to today.
4. The two mechanisms are **orthogonal**: the command string decides *which `fw` binary is
   executed*; the T-2446 logic decides *what `PROJECT_ROOT` that binary trusts*. Changing
   the former does not alter the latter's inputs.
5. T-2446's daemon-poison class specifically concerns `CLAUDE_PROJECT_DIR` **inherited by
   non-hook descendants** (cron jobs, long-lived subshells started from a poisoned env).
   That inheritance path is untouched by this change.

### One genuine, secondary consequence — worth flagging, not a blocker

`lib/paths.sh:82` and `lib/hook_paths.py:4` both state as a load-bearing premise:

> *"every framework hook is wired into Claude Code settings.json by **MAIN's absolute
> path** (`<main>/bin/fw hook …`)"*

Candidate A **falsifies that sentence.** In a git-worktree session `CLAUDE_PROJECT_DIR`
resolves to the *worktree* root, so the **worktree's own `bin/fw`** would execute rather
than main's.

Assessment: this is **directionally an improvement** — the reanchor machinery
(`fw_reanchor_from_cwd`, `reanchor_project_root`) exists precisely to undo main-anchoring,
and it degrades to a correct no-op when the binary is already correctly anchored (it
compares against the resolved root and returns unchanged on a match). But two things follow
and must be in the build task:

- the premise comments at `lib/paths.sh:82-89` and `lib/hook_paths.py:3-13` become false and
  must be rewritten;
- a worktree may carry a **different framework version** than main, so the executing `fw`
  could differ in behaviour. T-2465/T-2468 tests should be re-run under the placeholder form
  before merge.

**This is a follow-on scope item, not a reason to keep hardcoded paths.**

---

## 9. Recommendation

**GO — Candidate A + A2 (placeholder in both generators, plus the shared stale predicate),
implemented as a separate build task after human approval.**

Rationale:

- The defect is **confirmed and severe**: it fails toward *no enforcement*, silently, on
  every host but this one. Every constitutional directive points the same way — this is a
  Reliability failure (silent, unobservable) and a Portability failure (§Four Directives 2
  and 4) in one artifact.
- The fix is **known-safe with respect to the incident that caused it**: `${CLAUDE_PROJECT_DIR}`
  expands to an absolute path, so T-1364/T-1504's CWD-drift protection is fully retained.
  This is not a revert; it is the option the original framing excluded.
- The mechanism is **documented and independently corroborated in-repo** (§4), with one
  cheap empirical confirmation outstanding.
- **A2 is not optional.** Without it the fixed generator is never invoked on any existing
  consumer (§5.1), and the fix ships to nobody.

Not DEFER: the evidence is complete — generators located with file:line, the regression
commit identified with its diff, the doc-drift window established to the day, the blind
predicate read line-by-line, and the guard written and proven RED. There is no outstanding
question whose answer would change the recommendation. (Per CLAUDE.md §Presenting Work for
Human Review — DEFER is for evidence gaps, not confidence gaps.)

### Scope explicitly NOT shipped in this inception

Per the task constraints, this inception delivers RCA + proposal + guard only:

- **not** shipped: the generator change (`lib/init.sh`, `bin/hook-enable.sh`)
- **not** shipped: the A2 predicate change (`bin/fw`, `lib/upgrade.sh`)
- **not** shipped: the rewrite of `tests/unit/hook_absolute_paths.bats`
- **not** shipped: the correction to `docs/claude-code-settings.md:108`
- **not** run: `.claude/settings.json` regeneration

### Operator note — enforcement baseline (L-398 / T-1886)

When the build task regenerates `.claude/settings.json`, `fw doctor` will report
**"Enforcement baseline CHANGED"** (`bin/fw:1889`, baseline at
`.context/project/enforcement-baseline.sha256`) until the baseline is refreshed with
`bin/fw enforcement baseline`. **This has deliberately not been run here** — nothing was
regenerated, and refreshing a baseline is an operator action. It is called out so it is not
mistaken for a new failure later.

### Suggested build slices

1. **A1** — placeholder in both generators + rewrite `hook_absolute_paths.bats` to assert
   *post-expansion* absoluteness (placeholder present) rather than `startswith('/')`.
2. **A2** — shared non-portable-path predicate wired into `bin/fw:1160` (doctor) and
   `lib/upgrade.sh:1329` (upgrade trigger); fix doctor's "all portable" wording to reflect
   what it actually measured.
3. **A3** — correct `docs/claude-code-settings.md:108`; update the false premise comments at
   `lib/paths.sh:82` and `lib/hook_paths.py:4` (§8).
4. **A4** — empirical confirmation that the placeholder fires (§4), then regenerate this
   repo's settings.json from the fixed generator and refresh the enforcement baseline.
