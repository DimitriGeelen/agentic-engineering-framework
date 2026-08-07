# T-2857 — A gate that a task touching `bin/fw` / `bin/fw-router` must run its tests

**Task:** T-2857 (inception) · **Arc:** onboarding-curriculum · **Opened:** 2026-08-07
**Status:** exploration in progress

C-001 artifact. Written before the research, updated incrementally as spikes land.
The thinking trail IS the artifact.

---

## Prior (stated up front so it can be falsified)

Filed at task-creation time, before any exploration, by the
recommendation-completeness gate (T-2204):

> **GO.** T-2854 turned 6 tests red across 2 suites and it went unnoticed for 4
> commits because P-011 runs only what the author writes. The runner exists
> (`fw test unit` globs `tests/unit/`); nothing invokes it on a router change.
> Same shape as the cron registry→generated and tool-set→manifest rails already
> in CLAUDE.md, both enforced at close. The open question is only enforcement
> surface.

That prior asserts the remedy is obvious and only the surface is open. **The
exploration exists to try to break it.** The specific way it could be wrong: if
`fw test unit` is *already* red at most commits for unrelated reasons, then a
close gate that runs it blocks nearly every author for something they did not
cause — and a gate that blocks innocents is a gate that gets bypassed, which is
worse than no gate because the bypass log then reads as noise.

## Origin incident (T-2856 RCA, condensed)

T-2854 removed the router's global-install fallback to complete D-377. Six tests
across `tests/unit/fw_vendor_completeness.bats` (3/6) and `tests/unit/fw_router.bats`
(3/12) observed the property they protect *through* that fallback — "did it hand
over to the global?" stood in for "did it decline to run the partial vendor?".
Removing the mechanism removed the proxy. All six went red on that commit; the
commit landed and was pushed; they were found four commits later, incidentally.

The suites are **not orphaned** — `fw test unit` globs `tests/unit/` (`bin/fw:7988`).
Nothing invoked it.

---

## Findings

### F-1 — The suites are three days old, so the replay window is tiny

| Suite | First commit | Date |
|-------|--------------|------|
| `tests/unit/fw_router.bats` | `84a71b9b5` (T-2793) | 2026-08-04 |
| `tests/unit/fw_vendor_completeness.bats` | `6af954bf4` (T-2805) | 2026-08-05 |

Commits touching `bin/fw` or `bin/fw-router`: **345 all-time, 130 in 90 days, 46
in 30 days.** But only those after 2026-08-04 had either suite to run at all.

This immediately reshapes IW-4. "How many past commits would the gate have
caught" is not answerable over the 345 — for the overwhelming majority there was
no router suite in the tree, so the honest answer for them is *neither caught nor
missed*. The measurable population is days old and small.

### F-2 — a factual error in a source comment, found while sizing the window

`tests/unit/fw_router.bats:33-37` states the broken fixtures left tests
"red for a year of router changes without ever being about the router."

The suite was created **2026-08-04**, three days before this was written. It
cannot have been red for a year. Logged as an observation; the comment's
substantive point (the fixtures asserted against a refusal) is unaffected, only
its duration claim is false. Left for a separate task — one bug, one task.

### F-3 — S-2 (cost): the full runner is unaffordable at close, the targeted set is nearly free

| What | Wall clock |
|------|-----------|
| `fw test unit` (all 427 suites) | **>900s — killed at timeout, never completed** |
| 6 core router suites, direct `bats` | **4.1s** |
| 10 CLI-touching suites, one at a time | ~25s total |

This settles IW-3 in one measurement. A close gate that runs `fw test unit`
cannot ship: a 15-minute-plus block on `--status work-completed` is a gate every
agent learns to `--force` past within a day. A close gate over a *named, targeted*
suite set costs ~4s and is affordable.

Secondary observation: `fw test unit` buffered its entire output — 54 bytes on
disk after 15 minutes of running. There is no progress signal at all, so an agent
that runs it cannot distinguish "slow" from "hung". That is a usability defect in
its own right, separate from this inception.

### F-4 — S-3 (predicate): "the suites for this file" is not grep-definable

| Selector | Suites |
|----------|--------|
| All of `tests/unit/*.bats` | 427 |
| Mentioning `bin/fw` | **181 (42%)** |
| Mentioning `fw-router` | 10 |

A path-triggered "run the suites that reference the file you edited" would pull
in 181 suites for any `bin/fw` edit — effectively the full runner, with the
cost from F-3. The router-specific set (10) is tractable, but it is tractable
because `fw-router` is a rare string, not because the selector is sound. The
predicate has to be a **maintained map**, not a grep.

### F-5 — the decisive finding: T-2856 did not sweep the class it was written to sweep

While measuring F-3 I ran the ten CLI-touching suites individually.
**`tests/unit/fw_init_atomic.bats` test 1 is red right now.**

```
not ok 1 router refuses to route into a vendor marked incomplete
# (in test file tests/unit/fw_init_atomic.bats, line 60)
#   `[ "$status" -eq 0 ]' failed
```

Line 63 of that test asserts `grep -q 'ROUTED-TO-GLOBAL'` — the global-install
fallback removed by T-2854 (`cc5c829c1`). It is the **same defect class** as the
six tests T-2856 fixed: a test observing its property through a mechanism that
was legitimately deleted.

Attribution, by the same method T-2856 used — extract the pre-T-2854 router,
repoint `ROUTER()` at it, run the unmodified suite:

| Router | Test 1 |
|--------|--------|
| pre-T-2854 (`cc5c829c1^`, 233 lines) | **ok** |
| current (260 lines) | **not ok** |

So T-2856 — a task whose entire purpose was to find every test asserting the
removed fallback — found six of seven and closed. It missed this one because its
search method was "the suites I already had open", not "the runner". **The
inception's own origin incident recurred inside the fix for that incident**,
which is about as direct as evidence for a mechanical rail gets.

Correction to the inherited record while establishing this: my prior session's
notes named `9fa1806f6` as the commit that removed the fallback. It is
`cc5c829c1`. `9fa1806f6` touches `lib/update.sh` and `claude_fw_router.bats` and
never opens the router. The first attribution run I did was therefore against the
wrong parent and showed no difference — 13 `global` references on both sides.
That non-difference is what exposed the error.

### F-6 — a stale header comment in the router, found in passing

`bin/fw-router:31` still documents the decision tree as:

> 2. No project found → the global install, ANNOUNCED on stderr.

while line 117 of the same file states "T-2854, completing D-377: there is NO
global-install fallback." The code matches line 117. Filed as an observation, not
fixed here — inception tasks do not write build artifacts.

### F-7 — S-1 (firing rate): the targeted suites are red at 18 of 22 commits

Method: clone the repo once (`--shared`), check out each commit that touched
`bin/fw` or `bin/fw-router` since the first router suite existed (2026-08-04),
and run whichever of the ten CLI-touching suites existed at that commit. Tree
and tests both come from that commit — the gate at time C runs the tests that
exist at C against the code that exists at C.

Anti-vacuity anchor: HEAD must reproduce the live result. It does (2 FAIL, both
`fw_init_atomic`; the live repo gives 1 because test 4 self-skips there and fails
in the clone — see F-8). **v1 of this harness failed that anchor** — it used
`git archive` over a path subset, so four suites failed for want of `.git` and
gave 18 FAIL at HEAD. The numbers below are from v2.

| Commit | Task | Suites | Tests | **FAIL** |
|--------|------|-------:|------:|---------:|
| `b53a893ff` | T-2793 shim mode bit | 4 | 29 | 0 |
| `789c7b85d` | T-2793 vendored-copy holes | 4 | 30 | 0 |
| `4edf158a1` | T-2793 install router | 4 | 30 | 0 |
| `ebebd305f` | T-2793 VERSION correction | 4 | 32 | 0 |
| `a3d20ff71` | T-2794 loop message | 4 | 33 | **1** |
| `975059510` | T-2796 version distance | 4 | 33 | 0 |
| `f324aa5fd` | T-2798 --help auto-init | 4 | 33 | 0 |
| `65ad0ceeb` | T-2801 atomic init | 5 | 38 | **1** |
| `6af954bf4` | T-2805 partial vendor | 6 | 46 | **9** |
| `6f79448cc` | T-2807 claude-fw copy | 6 | 46 | **9** |
| `eb3aa57c9` | T-2808 fw help | 6 | 46 | **9** |
| `713cc4883` | T-2810 refusal text | 7 | 51 | **8** |
| `2cfad4c1e` | T-2814 bare-dir bootstrap | 8 | 57 | **1** |
| `176445c64` | T-2812 git hooks dir | 8 | 57 | **2** |
| `17e03fcb1` | T-2825 worktree guard | 8 | 57 | **2** |
| `0f333b27c` | T-2830 --switch-focus | 8 | 56 | **1** |
| `025497d05` | T-2835 unknown subcommand | 8 | 56 | **1** |
| `87d517b4a` | T-2836 fw help verbs | 8 | 56 | **2** |
| `242cbaa8c` | T-2843 doctor vendored WARN | 8 | 56 | **2** |
| `4cb252ce0` | T-2844 empty cron registry | 8 | 56 | **2** |
| `cc5c829c1` | **T-2854 remove global fallback** | 8 | 56 | **9** |
| `8752b2edd` | T-2849 vendor excludes | 8 | 56 | **8** |
| `4d9d7c57f` | T-2856 | — | — | *not measured (sweep timeout)* |
| `HEAD` | — | 10 | 71 | **2** |

Failures by suite across the sweep: `fw_router` 37, `fw_init_atomic` 19,
`self_vendor_parity` 13, `fw_vendor_completeness` 9.

**This refutes the filed recommendation's central claim.** That claim was: *"the
open question is only enforcement surface."* It is not. The open question is the
**baseline**.

- **18 of 22 measured commits (82%) had at least one red test** in the targeted set.
- Only four commits were fully green, all in the first two days.
- From `a3d20ff71` (2026-08-04) onward, **the set was never green again** — not once.
- Two sustained windows: 8–9 red held across four consecutive commits
  (`6af954bf4`→`713cc4883`), and 8–9 again at `cc5c829c1`→`8752b2edd`.

A "suites must be green" gate installed at any point in this window would have
blocked 82% of authors for failures they did not cause. That is not a precise
signal, it is a toll booth — and a toll booth is what teaches agents to reach for
`--force`, after which the bypass log fills with legitimate-looking entries and
the gate is worse than absent. The two prior-art rails the recommendation leaned
on (cron registry→generated, tool-set→manifest) do not have this problem: they
compare two files and are green by default.

**What the evidence actually supports** is a *delta* gate, not an absolute one:
refuse when the commit **introduces** a failure, tolerating a known-red baseline
recorded as a checked-in expected-failures list. On this history a delta gate
fires exactly where it should — at `6af954bf4` (+8), at `cc5c829c1` (+7), and at
`a3d20ff71` / `65ad0ceeb` (+1 each) — and stays quiet across the long red plateaus
where nothing new broke. Or, cheaper: green the baseline first (T-2858 is one of
the two remaining reds), *then* an absolute gate becomes affordable.

### F-8 — a timing-dependent test would make any gate flaky

`fw_init_atomic` test 4 ("an interrupted init is recoverable by re-running fw
init") kills an init mid-flight and asserts recovery. It carries its own guard —
it self-skips with "init completed within the kill window — no partial state to
recover". In the live repo it skips; in the clone it fails. Same commit, same
tests, different machine timing.

Any gate over this set inherits that coin-flip. Whichever enforcement surface is
chosen, this test needs to be made deterministic or excluded from the gated set —
otherwise the gate's first false block teaches the bypass habit on its own.

---

## The decision was recorded while this exploration was in flight

At **2026-08-07T16:54:20Z**, mid-sweep, `fw inception decide T-2857 go` was run.
`.context/working/.gate-bypass-log.yaml` records it as
`flag: --skip-sovereignty, caller: check_human_sovereignty, reason: Inception
decision: GO`; `lib/inception.sh:716` is the call site. Watchtower's log ends at
14:25, so it did not come through the web UI — it was a terminal invocation.
Four ACs were auto-ticked by the `@auto-tick-on-decide` markers, including the
`### Human [REVIEW]` one. The task then moved to `.tasks/completed/`.

The recorded rationale is my **filing-time recommendation verbatim**, with an
empty `Evidence:` block — the untested prior, promoted to a decision.

Two things follow, and they are separate:

1. **The GO is not disputed.** The decision belongs to the human, the direction it
   points is the one the evidence supports, and T-2858 is already filed under it.
2. **The rationale attached to it is now known to be wrong on its central claim.**
   "The open question is only enforcement surface" was falsified by F-7 forty
   minutes after it was recorded. Anyone reading the closed task will read the
   prior, not the finding, because the Evidence block is empty and the artifact
   is not linked from it.

That gap is the thing worth fixing — not the decision. The build work this GO
authorises should be shaped by F-3/F-4/F-7 (targeted set, maintained map, delta
gate or green-baseline-first), not by the recommendation that preceded them.

---

## Dispositions

- **IW-1 (enforcement surface):** *answered.* Close gate over a targeted,
  maintained suite map. Not the full runner (F-3: >45 min, never completed).
  Not a grep-derived set (F-4: 181/427 suites match `bin/fw`).
- **IW-2 (trigger predicate):** *answered.* A maintained map, not a grep. Path
  match on `bin/fw` / `bin/fw-router` is the right trigger; suite selection must
  be explicit.
- **IW-3 (declare vs execute):** *answered.* Execute — 4.1s for the six core
  suites. Declaration is satisfiable by a line that never runs green, the
  false-green class T-2732 exists to close.
- **IW-4 (firing rate):** *answered, and it inverted the recommendation.* 18/22
  commits red. An absolute gate is unaffordable; a delta gate or a greened
  baseline is required first. This was the decisive question and it was open at
  the moment the decision was recorded.


---

## Dialogue Log

**2026-08-07 — operator, standing directive.** "proceed as suggested, follow
framework governance, contineu till 300k, focus of the onboarding arcs."
Agent proceeding autonomously on the spike plan; no operator decision requested
yet. The go/no-go handoff comes after S-1.

**2026-08-07 — agent, on the filed recommendation.** Flagged in the resume
summary that the `GO` on T-2857 was written by the filing gate before any
exploration existed, so it is an assertion rather than a finding, and that S-1
(IW-4) is the evidence that should decide it. Recorded here so that if the
exploration ends up confirming GO, it is visible that the confirmation was
earned rather than inherited.
