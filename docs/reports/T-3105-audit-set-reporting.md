# T-3105 — audit checks must report the set they evaluated

**Slice 3 of 3.** Status: code + tests on disk. No commit, no task-state write.

## The rule

> A check may only PASS over the set it actually evaluated, and must report that
> set's size. An empty or unenumerable candidate set is a WARN, not a PASS.

`no duplicate task IDs among 3124 task file(s)` is falsifiable — a reader who
believes the corpus is larger now has something to disagree with. `No duplicate
task IDs` is not. The count is not decoration; it is the claim's scope, and a
claim without a scope cannot be wrong, which is exactly why it cannot be trusted.

## Helper API — and why this shape

Added in `agents/audit/audit.sh` immediately after `info()`, alongside the
existing `pass` / `warn` / `fail` / `info` emitters:

```
pass_over <count> "<set-description>" "<message>" [<evidence>] [<mitigation>]
  count > 0         -> pass "<message> — examined <count> <set-description>"
  count == 0        -> warn "<message> — NOT EVALUATED: candidate set empty (0 <set>)"
  empty/non-numeric -> routed to warn_unenumerable

warn_unenumerable "<source>" "<message>" [<evidence>] [<mitigation>]
  -> warn "<message> — NOT EVALUATED: could not read <source>"
```

Four design calls, each with a reason:

1. **Two verbs, not one.** The two failures are known at different moments.
   "The set was empty" is known *after* enumeration returns a number. "Could not
   enumerate" is known *before* any number exists — a missing store, an
   unreadable path, an absent dependency, a `$(python3 … 2>/dev/null)` that
   collapsed to `""`. Folding both into one verb forces every caller to invent a
   sentinel for "I never got a count", and the obvious sentinel — `0` — is
   precisely the value that must not be conflated with it. T-3099's hand
   implementation already had this two-part shape; the helper is its
   generalisation, not a new idea.

2. **The helper renders the count, the caller does not.** `pass_over` appends
   `— examined N <set>` itself. Leaving interpolation to the caller means the
   count can be dropped by a future edit with nothing to notice — that is how
   the class arose in the first place. Mutation M2 below pins this.

3. **A non-numeric count routes to `warn_unenumerable`, it is not trusted.**
   A caller whose command substitution collapsed to the empty string has not
   measured a set of size 0; it has measured nothing. Whitespace is stripped
   first, so a padded `wc -l` still reads as a real count.

4. **Both paths WARN, never FAIL.** Audit's exit 2 means a real failure. A check
   that did not evaluate is an unknown. Same reasoning as this file's own
   lock-contention exit 75 (T-2930): *did not run* is its own verdict, distinct
   from both pass and fail — and an unknown that exits 2 would train readers to
   ignore it.

`<evidence>` and `<mitigation>` are optional and follow `warn()`'s existing
argument order, so a converted call site reads like the emitter it replaced.
Both default to text naming the set / source.

## Full check inventory

`agents/audit/audit.sh` has **315 emitter call sites** (142 `pass`, 111 `warn`,
40 `fail`, 17 `info`, 5 grace variants). Only the `pass` sites can express the
defect, so those 142 are the population inventoried below.

### Converted — 29 `pass_over` sites + 8 `warn_unenumerable` sites

| # | Check | Set now reported |
|---|-------|------------------|
| 1 | Duplicate task IDs | task file(s) in the main checkout's `.tasks/{active,completed}/` |
| 2 | Project YAML parse | project YAML file(s) |
| 3 | Arc `anchor_task` refs resolve | arc anchor_task reference(s) |
| 4 | Onboarding-seed corpus refs resolve | onboarding-seed corpus reference(s) |
| 5 | Corpus maps lint clean | corpus map(s) |
| 6 | Stale-arc assessment | in-progress arc(s) with constituents |
| 7 | Inline `arc:<slug>` tag-only scans (T-1881) | source file(s) under `lib/ web/ agents/ bin/ tools/` |
| 8 | PROJECT_ROOT split-root scan (T-2648/OBS-097) | Python file(s) under `web/ + lib/` |
| 9 | Stale-slice references (L-417) | file(s) under `web/templates web/blueprints lib` |
| 10 | **GO-scope-not-propagated (T-3099)** | GO-recorded completed inception(s), of N completed inceptions |
| 11 | Fabric drift | watched file(s) |
| 12 | Invariant suite (tests/lint/) | structural invariant(s) |
| 13 | Active tasks valid | active task(s) |
| 14 | Active task quality thresholds | active task(s) |
| 15 | Satisfied-but-unclosed active tasks | active task(s) |
| 16 | Commit task refs resolve | task-referencing commit(s) in the traceability range |
| 17 | Practices have traceable origins | documented practice(s) |
| 18 | Practice origins resolve to tasks | practice `Origin:` line(s) |
| 19 | Completed tasks have episodic summaries | completed task(s) |
| 20 | Episodic summaries have quality content | episodic summary file(s) |
| 21 | No orphaned episodic files | episodic file(s) |
| 22 | C-001 completed inceptions have research artifacts | completed inception(s) |
| 23 | C-006 active inceptions have Recommendation | active inception(s) |
| 24 | CTL-013b review-queue verification re-run | review-queue task(s) re-run |
| 25 | CTL-031 archive-eligible stuck partial-completes | active task(s) |
| 26 | CTL-028 completed/ frontmatter status | completed task(s) |
| 27 | CTL-030 completed/ stored horizon | completed task(s) |
| 28 | CTL-029 completable-but-not-completed | active task(s) |
| 29 | CTL-012 completed tasks have checked ACs | completed task(s) |

`warn_unenumerable` sites (8): the GO-scope pre-scan (migrated from T-3099's
hand implementation), the satisfied-but-unclosed scan, and the five D-detector
catch-alls listed under *Findings* below, plus the routing branch inside
`pass_over` itself.

### Deliberately NOT converted — with reasons

**(a) Pure existence checks — no candidate set exists (16 sites).**
`Tasks directory exists`, `Tasks/{active,completed,templates} directory exists`,
`Task template exists`, `Bypass log exists`, `Commit-msg hook installed`,
`C-002: commit-msg hook has research artifact check`, `C-003: Research
checkpoint logic present`, `CTL-002 Tier 0 guard wired`, `CTL-005 error watchdog
wired`, `CTL-007 post-compact resume hook configured`, `CTL-011 pre-push hook
installed`, `CTL-019 claude-fw wrapper installed`, `CTL-026 human sovereignty
gate present`, `Practices file exists`, `Deploy gate: <file> exists`,
`Traceability baseline active`. A file either exists or it does not; there is
nothing to enumerate and nothing a count would add.

**(b) Already count-reporting state summaries, not universal claims (14 sites).**
`Fabric: N registered card(s)`, `Fabric edges: N/M cards enriched`,
`Git traceability: P% (N/M commits)`, `Gate-bypass log: N safety + M drift`,
`Practices documented: N practice(s)`, `Bugfix-learning coverage: P% (N/M)`,
`Observation inbox: N pending`, `Gaps register: N watching`, `Handover open
questions: N tracked`, `Graduation pipeline: N learnings`, `CTL-004 tool counter
at N`, `CTL-008 traceability P% (N/M)`, `CTL-020 N cron audit file(s)`,
`CTL-010 bypass log has N entries`. These already print their own denominator
and make no all-clear claim over a corpus; `pass_over` would duplicate the
number without adding scope.

**(c) Per-item PASS inside a loop — the item names itself (6 sites).**
`Map conformance: <map> matches its enforced machine`, `cron(<base>): USER-field
syntax installed`, `CTL-009: Inception <id> has decision`, `CTL-027: Inception
<id> has Recommendation + Decision`, `CTL-013: <id> verification re-run: N/M`,
`CTL-025: <id> partial-complete with owner:human`, `Arc '<id>': N/M below
threshold`. Each line already states which member it evaluated. **Residual gap:**
none of these loops emits a set-level summary, so a loop that iterates zero times
prints nothing at all — silence rather than a false PASS. Silence is a different
(and arguably worse) failure than the one this slice addresses; converting it
means adding new summary lines, which is a substance change. Reported, not fixed.

**(d) Session/environment state — the "set" is a single live file (9 sites).**
`CTL-001 focus file`, `CTL-003 budget status` (×3 branches), `CTL-018 budget
status JSON`, `CTL-006 handover coverage`, `D8 handover LATEST.md has no [TODO]`,
`Working directory clean` (×2), `Deploy gate: git clean / HEAD has task ref /
health endpoint responds`, `OneDev → GitHub mirror in sync`, `Cron registry in
sync`. These compare two states or read one named file; there is no population
whose size scopes the claim.

**(e) External scanner owns the population, and does not report it (2 sites).**
`Secret scan: tracked tree clean`, `Large-file gate: tracked tree clean`. Both
delegate to `$SECRET_SCANNER scan-tree` / `$LARGE_FILE_SCANNER scan-tree`, which
emit findings only — never a scanned-file count. **These are live residual
instances of the class:** if either scanner silently walked zero files, the audit
would print the same green line. Fixing it means widening the scanner's output
contract, which is a substance change and out of this slice.

**(f) Trend / velocity detectors with no meaningful denominator (11 sites).**
`D3 commit velocity`, `D4 audit trend`, `D6 completion velocity`, `D7 commit
bunching`, `D9 control drift`, `D12 bypass log`, `D1 episodic quality`, `D2 human
review queue`, `D8b handover archive`, `D14 empty inception Recommendation`,
`CTL-016 failure-pattern mitigations`. These emit a computed *level*
(PASS/WARN/INFO/SKIP) over a time window rather than a universal claim over a
corpus, and several already have explicit `insufficient history` / `no data`
branches. **Residual gap:** each detector's population is real but is not on its
stdout contract (`print("PASS 0")` carries no scanned count), so converting them
requires editing 11 separate embedded Python blocks to widen their output — a
substance-adjacent change deferred out of this slice. What *was* fixable without
touching the detectors is the crash path; see Finding 4.

**(g) Already conformant by hand, left as-is (2 sites).**
`Branch hygiene` (T-3092) and `Designer ghost registry` both already carry an
explicit could-not-evaluate branch that emits INFO/WARN rather than PASS. Neither
exposes a population count through its library contract
(`fw_branch_hygiene` emits findings only), so the set-size half remains open.
`Invariant suite` was the third of these and *was* migrated (row 12) because its
count was already in hand.

## Findings — checks that were passing on an empty or unread set

Each of these is a finding in its own right.

**F1 — `C-001: No completed inception tasks to check` was a PASS.**
`agents/audit/audit.sh` printed the empty-set case *out loud* and then scored it
as a success. This is the class stated in its own words. Now `pass_over` over
`completed inception(s)`.

**F2 — the satisfied-but-unclosed scan scored a crashed scan as clean.**
The embedded Python printed its summary line only when `count > 0`, and its
stderr goes to `/dev/null`. So an empty `$_unclosed_summary` meant *either* "no
findings" *or* "the scan died" — and the shell scored both as
`PASS "No active tasks are satisfied-but-unclosed"`. The Python now prints
unconditionally; an absent summary routes to `warn_unenumerable`. This is the
same shape as the skills-manager errors store named in the task brief.

**F3 — six checks were silent, not green, on an empty set.**
`arc anchor_task refs`, `onboarding-seed corpus refs`, `corpus map lint`,
`stale-arc assessment`, `project YAML parse`, and `episodic summary quality` all
guarded their PASS with `[ "$N_checked" -gt 0 ]`. On an empty population they
emitted *no line at all*. That is not a false green, but it is the same
blindness: a reader scanning the report cannot distinguish "this rail is clean"
from "this rail did not appear". All six now WARN on zero.

**F4 — five D-detectors turned a dead detector into a PASS.**
`D5` (task lifecycle), `D10` (decision-without-dialogue), `D11` (gap-register
staleness), `D13` (inception limbo), `D15` (inception limbo state) each parsed a
level out of their Python's stdout and branched `case … *) pass …`. A Python that
dies produces `""` → level `""` → **the success arm**. The catch-all is now split
into an explicit `PASS)` arm and a `*)` arm that calls `warn_unenumerable` and
prints the unrecognised level. No detector logic was touched.

**F5 — the duplicate-task-ID check (task brief instance 3) now states its scope.**
Per the slice fence its scope was NOT widened. It still scans the main checkout
only — but the line now reads `No duplicate task IDs — examined N task file(s) in
the main checkout's .tasks/{active,completed}/`, with the main-checkout limit in
the evidence field. A reader who knows about the worktree replicas can now see
that the number is short. That visibility is what slice 2 will act on.

**F6 (residual, not fixed) — the two whole-tree scanners.**
See inventory group (e). `Secret scan: tracked tree clean` and `Large-file gate:
tracked tree clean` remain unfalsifiable claims.

**F7 (residual, not fixed) — the D-detector populations.**
See inventory group (f). Eleven detectors report a level but never their
denominator.

## Substantive bugs found while converting

None that change what any check looks for. F2 and F4 are reporting defects (a
crash rendering as a pass), not predicate defects — fixing them changed no
predicate. No check's search criteria, thresholds, allowlists or scope were
modified by this slice.

## Before/after audit diff

Two full `bin/fw audit` runs on the same corpus, same working tree: one with
`agents/audit/audit.sh` restored from `git show HEAD:` (pre-slice), one with the
shipped version. Neither run was wrapped in `timeout` — a truncated run is
indistinguishable from a regression, and the first attempt at this comparison
made exactly that mistake before it was caught.

**Verdict sequence: identical.** Emitting the ordered `PASS`/`WARN`/`FAIL`/`INFO`
sequence from each run and diffing them position-wise produces no output.

| | PASS | WARN | FAIL | INFO | total |
|---|---:|---:|---:|---:|---:|
| before | 37 | 9 | 2 | 5 | 53 |
| after | 37 | 9 | 2 | 5 | 53 |

Section headers are identical, and both runs end on the same check. **No check
changed verdict, appeared, or disappeared.** This is the intended result and it
confirms the claim made under *Substantive bugs found while converting*: every
conversion is a reporting change, not a predicate change.

**What did change: 14 lines now carry their evaluated-set size.**

```
No duplicate task IDs                     — examined 3093 task file(s) in the main
                                            checkout's .tasks/{active,completed}/
All project YAML files parse correctly    — examined 29 project YAML file(s)
All arc anchor_task references resolve    — examined 17 arc anchor_task reference(s)
All onboarding-seed corpus refs resolve   — examined 12 onboarding-seed corpus reference(s)
Corpus maps lint clean                    — examined 8 corpus map(s)
All assessed arcs had commits in 30 days  — examined 15 in-progress arc(s) with constituents
No inline arc:<slug> tag-only scans       — examined 386 source file(s) under lib/ web/ agents/ bin/ tools/
No PROJECT_ROOT resolution of fw assets   — examined 133 Python file(s) under web/ + lib/
No stale-slice-references (L-417)         — examined 260 file(s) under web/templates web/blueprints lib
All active tasks meet quality thresholds  — examined 382 active task(s)
All commit task refs resolve              — examined 8408 task-referencing commit(s) in full history
Practices have traceable origins          — examined 7 documented practice(s)
Practice origins resolve to actual tasks  — examined 7 practice Origin: line(s)
All completed tasks have episodic summaries — examined 2711 completed task(s)
```

29 call sites were converted; 14 rendered a count on this run. The remainder sit
in branches this corpus does not currently take — chiefly the `warn_unenumerable`
arms added to the five D-detectors (Finding 4), which fire only when a detector's
Python dies. That gap between *converted* and *observed* is the honest reading:
this run exercised roughly half the new code, and the untaken half is exactly the
half that only shows up on a bad day.

**No check flipped PASS → WARN on the live corpus.** Every converted set is
currently non-empty, so no empty-set WARN fired. The findings in the section above
are therefore *latent* instances, not currently-firing ones — with one exception,
F1, where the audit was printing `No completed inception tasks to check` out loud
and scoring it PASS; that text is gone because the set is non-empty here, but the
scoring bug it exposed was real and is now structurally impossible.

**One cosmetic defect found by reading the after-run output and fixed:** the
traceability line rendered `examined 8408 task-referencing commit(s) in ` with an
empty range, because `$trace_range` is empty when the range is full history. Now
`${trace_range:-full history}`. Small, but it is precisely a set descriptor that
failed to describe its set.

## Mutation testing

Three one-line mutations applied to the shipped helper in
`agents/audit/audit.sh`, each run against
`tests/unit/t3105_audit_set_reporting.bats` (18 tests), then reverted. Source
verified byte-identical to the pre-mutation copy afterwards.

| # | Mutation | Killed by | Failures |
|---|----------|-----------|---------:|
| M1 | `if [ "$_count" -gt 0 ]` → `-ge 0` (count==0 becomes PASS again) | #3 `count == 0 emits WARN, not PASS`; #4 WARN text says NOT EVALUATED; #5 caller evidence/mitigation; #6 default mitigation; #12 rendered count tracks set size; #14 tally warn=1 | 6 |
| M2 | `pass "$_msg — examined $_count $_set"` → drop `$_count` | #1 count appears in emitted text; #2 count 1 renders; #10 whitespace-padded count; #11 rendered count equals real set size; #12 tracks set size | 5 |
| M3 | `warn_unenumerable …` → `pass "$_msg"` (unenumerable falls through to PASS) | #8 empty count routes to unenumerable; #9 non-numeric count routes to unenumerable | 2 |

No equivalent mutants: every mutation was killed by at least two tests, so no
equivalence argument was needed.

## Test inventory

- `tests/unit/t3105_audit_set_reporting.bats` — **18 tests, all green.**
  Covers the five required areas: (1) count>0 → PASS with the count rendered
  (#1, #2), (2) count==0 → WARN saying it did not evaluate (#3–#6),
  (3) unenumerable → WARN naming the unread source (#7–#10), (4) the rendered
  count equals the real set size, asserted as an exact integer against a
  directory built in the test (#11, #12), (5) PASS/WARN/FAIL tallies per path
  (#13–#16). Plus two structural tests: the shipped file defines both verbs
  (#17), and the GO-scope check uses the shared helper rather than its own
  hand implementation (#18).
- `tests/helpers/audit-set-reporting-block.sh` — extracts the two functions from
  the shipped `agents/audit/audit.sh` with `sed` and evaluates them against stub
  emitters, the same technique as `tests/helpers/audit-branch-hygiene-block.sh`
  (T-3095). Extracting rather than copying keeps the assertions pinned to the
  file that ships; a copy would keep passing forever after audit.sh changed,
  which is the defect class the rail exists to catch.
- `tests/unit/t3095_audit_branch_hygiene.bats` — **10 tests, still green** (no
  regression; the branch-hygiene block was deliberately left unconverted).
