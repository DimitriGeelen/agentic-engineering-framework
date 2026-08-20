# T-3093 — How should unread branch-hygiene findings escalate?

**Status:** inception (exploration) — Recommendation: pending
**Opened:** 2026-08-20
**Trigger:** operator, on being shown 15 stranded branches — *"this seems to be a mess. pollution."*
The rail had been reporting that mess the whole time.

## Problem

Detection works. Nothing consumes it. See the task's Problem Statement for the
measured shape; this artifact carries the exploration.

## Findings

### F1 (IW-1) — Nobody sees them. The finding has never been on an automatic surface.

Measured, not inferred:

| Surface | Runs when | Consumes `fw_branch_hygiene`? |
|---|---|---|
| `fw doctor` | only when a human types it — **0 cron lines** | **yes — the sole consumer** (`bin/fw:3221`) |
| `fw audit` | cron: every 30m, hourly, 6h, daily, weekly | **no** — all 5 textual matches in `audit.sh` are comments that *mirror doctor's logic for other checks* |
| `fw handover` | every session end | **no** — uses `fw_branch_divergence`, which reports only the **current** branch |

So the one rail that can see a strand runs only on demand, and the two rails that
run automatically cannot see one. This is not "the WARN was ignored" — it is
"the WARN was never delivered".

Dates make it sharper. The rail shipped **2026-07-04**. The oldest strand forked
**2026-03-01**. The strands predate the detector by four months, and in the six
weeks the detector has existed it has had no automatic surface at all.

**IW-1 is answered, and it reframes IW-2.** The question is not "how do we make
people act on a WARN they are ignoring" — it is "put the finding somewhere that
runs without being asked". Those need very different mechanisms, and the second is
much cheaper.

### F2 (IW-2) — There is already a precedent for exactly this promotion.

`agents/audit/audit.sh:1827` and `:1858` carry the comments *"Mirrors `bin/fw
doctor` cron-drift logic"* — the cron registry→generated→deployed drift check was
first a doctor check, then duplicated into audit so the cron rail would catch it
(T-1771, T-1942, T-1943). That is the same shape as this problem, already solved
once in this codebase, with the reasoning recorded in CLAUDE.md.

The precedent also carries a warning: it was solved by **duplicating** the logic
into audit rather than sharing it, and CLAUDE.md now documents three separate
drift classes that each needed their own gate. A promotion here should call
`fw_branch_hygiene` directly rather than reimplement it.

## Dialogue Log

<!-- questions posed, course corrections, why the reasoning moved -->

### F3 (IW-3) — The threshold is not too high. It is in the wrong unit, and it fires in 29 hours.

`FW_BRANCH_BEHIND_WARN` counts **commits**. On this repo `origin/master` moves at
**~41 commits/day** (2577 commits over 63 active days). At a threshold of 50, a
branch created this morning is a "finding" by tomorrow lunchtime — **~1.2 days**.

And 88% of that movement is governance churn: **2266 of 2577** commits since
2026-06-01 touch nothing outside `.context/` and `.tasks/`. So the counter that
decides whether your branch is stale is driven almost entirely by handovers and
task-file writes — activity that has no bearing on whether your branch still merges.

This is the real reason the section is unread, and it is worse than "nobody looked":
**the rail is mostly false positives by construction.** Every healthy in-progress
branch trips it within a day. Escalating that signal — putting it on cron, blocking
on it, filing tasks from it — would multiply noise, not surface strands. It would
make the framework less trustworthy, not more.

The framework already has the right unit elsewhere: `FW_STALE_ARC_DAYS` (default 30)
WARNs an in-progress arc with no constituent-task commit in N **days**
(`lib/config.sh:245`, T-1855). Branch staleness wants the same treatment — *how long
since anyone touched this branch*, not *how much unrelated churn happened elsewhere*.

Retro-check on the four real strands: all four sat unpushed and untouched for **weeks
to months**, so a days-since-last-commit rule catches every one of them, while a
branch you committed to this morning stays silent no matter how fast master moves.

### F4 (IW-4) — Escalation must be dismissible, or it becomes the next ignored rail.

`worktree-inception-gov-payload-mediation` is a deliberately-parked inception artifact,
not a strand to be cleaned up. Any escalation that cannot express "parked on purpose"
will either be overridden constantly (and learned as noise) or will pressure real work
into being deleted. The framework already has the vocabulary — `horizon: later` for
tasks, `--justification` logging for arc-close bypasses — and an escalation rail should
reuse it rather than invent a new dismissal channel.

This is why the recommendation below stops short of a **gate**. A gate on a signal
that is currently ~88%-noise-driven, before recalibration, is how you teach people to
set `FW_...=1` reflexively.

## Recommendation

**GO — but on F3 first, and the order is the whole point.**

The obvious build ("put branch-hygiene on the audit cron") is the wrong first slice.
Promoting a rail that fires on every branch within 1.2 days would flood the daily
audit and burn the signal permanently.

Proposed slices, in order:

1. **Recalibrate to time** — add days-since-last-commit-on-branch alongside the commit
   counts, modelled on `FW_STALE_ARC_DAYS` (T-1855). Findings become "untouched for N
   days", which is what actually distinguishes a strand from work in progress. Cheap,
   self-contained, testable.
2. **Then promote to the audit cron** — call `fw_branch_hygiene` from `audit.sh`,
   following the documented `bin/fw doctor` → audit precedent (`audit.sh:1827`,
   T-1771/T-1942/T-1943), but calling it rather than duplicating it.
3. **Then, and only with a clean signal, consider a handover nudge** — the handover
   already carries `fw_branch_divergence` for the current branch; extend it to remote
   strands once step 1 makes the finding count small and true.

**Not recommended:** a blocking gate, and auto-filing tasks per strand. Both act on a
signal whose false-positive rate has not been fixed yet, and both are much harder to
walk back than a WARN.

**Evidence:**
- `fw_branch_hygiene` has exactly one caller (`bin/fw:3221`); audit and handover do not call it; doctor appears on **0** cron lines
- Rail shipped 2026-07-04; oldest strand forked 2026-03-01 — the strands predate the detector, and it has never had an automatic surface
- master moves ~41 commits/day → the 50-commit threshold is crossed in ~1.2 days
- 2266 of 2577 commits (88%) since 2026-06-01 are governance-only, so the staleness counter is driven by unrelated churn
- Time-based precedent exists and is documented: `FW_STALE_ARC_DAYS` (`lib/config.sh:245`, T-1855)
- doctor→audit promotion precedent exists and is documented: `agents/audit/audit.sh:1827` (T-1771, T-1942, T-1943)
