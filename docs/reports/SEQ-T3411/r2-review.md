# VALUE REVIEW — Round 2 (T-3411, seq:T-3411) — whole repo, prediction re-check

- **Worker:** TermLink worker `seq-t3411-r2-review`, round 2 of 5 (Review →
  procAsFit sequence).
- **Role setup:** **self-judged — GATHERER and JUDGE NOT separated**, same as
  round 1. Confidence capped one level below what corroboration alone would
  justify, applied throughout §6.
- **Human present:** no. All `[ASK]` gates below are answered on stated
  defaults and the run proceeds, per driver instruction. Phase 6 is **not**
  executed — this round stops at the end of Phase 5.
- **Scope of this round, per the driver's mandate:** NOT a from-scratch
  review. This round re-runs the check named by every "Expected effect"
  prediction in round 1's findings table (`r1-review.md` §6, Δ1–Δ6), records
  HELD / FAILED / UNTESTABLE for each, checks whether round 1's procAsFit
  selections (T-3302, T-3412) landed and produced the predicted effect, and
  tries to close round 1's two INVESTIGATE items (Δ4, Δ5) with the data round
  1 said would decide them. Nothing round 1 or its procAsFit round rejected
  is re-proposed here without new evidence.

---

## 1. Yardstick

**PROPOSED-UNCONFIRMED**, unchanged from round 1 — no evidence this round
that `policy/value-drivers.yaml` changed in substance, or that any of
round 1's three stated questions (purpose still right? F3/F1=D2 weighting
deliberate or stale? is BVP still a live product bet?) were answered. Reused
verbatim from round 1 / T-3370:

> Make an AI agent's work traceable, reversible and human-sovereign by
> structural enforcement rather than agent discipline. It captures the
> record of what happened (Context Fabric), the map of what the work touches
> (Component Fabric), and forces a human decision at exactly the moments
> that need one. It *coordinates; it does not execute*.

**What I would have asked the human, had one been present:** the same three
questions round 1 posed, unanswered — plus a fourth this round's own
evidence surfaces: is the ~2-hour cadence between rounds (round 1 finished
07:00:56Z, round 2 started immediately) intended, or should rounds be spaced
to let daily/nightly data sources (the 01:03Z unit-suite cron, in particular)
actually produce a new data point between checks? At the current cadence,
Δ2's "within 14 days" prediction cannot be meaningfully re-tested until far
later rounds, or a round explicitly deferred to cross a cron boundary.

## 2. Data availability map — deltas only

Unchanged from round 1 except:

| Source | Round 1 status | Round 2 status | Evidence |
|---|---|---|---|
| Gate-bypass audit log | PARTIAL (does not parse, byte-835 UTF-8 error) | **EXISTS now — parses, 1211 entries** | E6 |
| Hook-invocation counter (write-only class) | EXISTS (T-3371 fix confirmed) | **EXISTS, unchanged, still healthy** | E2 |
| TermLink topic `seq:T-3411` | asserted in task ACs, not observed from inside round 1 | **EXISTS, observed directly — 5 posts, exact schema match** | E11, E12 |
| Per-worker focus isolation | not examined | **PARTIAL — falls back to shared `focus.yaml` when no session-local file exists yet**, observed live this round | E17, E18 |
| Vendored-path sync gate coverage of autonomous procAsFit workers | not examined | **GAP, observed live**: T-3412 (round 1) closed without the CLAUDE.md-mandated `bin/fw vendor self --check` Verification line; pre-push caught it, P-011 could not | E14–E16 |

## 3. Role setup

Not separated (stated above), same cap as round 1.

## 4. Baseline

- `fw --version`: `1.6.746`, HEAD `0ca99bcdb` on `bleeding-edge` (was
  `1.6.744`/`8bd9b13ec` at round 1 — E0).
- **Local is 4 commits ahead of `origin/bleeding-edge`** (E1) — round 1's
  T-3412 fix and the round-1 artifact commit are not yet pushed.
- `fw doctor`: **still did not complete, now timed out at 90s** (was <60s at
  round 1, E8) — same non-completion class, confirmed at a longer ceiling too
  (E22).
- `fw audit` (06:32:21Z run, pre-dates the T-3412 fix): 33 PASS / 12 WARN / 0
  FAIL (E3) — same counts as round 1's citation; no fresher full-audit run
  exists inside this round's window to check post-fix.
- Nightly unit suite: same run round 1 cited (`01:03–03:03Z`, before round 1
  even started) — no new cron cycle has occurred between rounds 1 and 2
  (E4, E5).
- Sidecar inbox (this worker's own address): empty, checked 3× (session
  start, pre-write, pre-write) — second consecutive round with zero inbound
  consults (E8).

## 5. Summary

**Prediction-recheck counts:** 3 HELD (Δ1, Δ3, Δ5), 2 CONFIRMED-STILL-OPEN /
too-early-to-judge (Δ2, Δ4), 1 REVERSED (Δ6 — round 1's own close was wrong;
T-3370's original finding stands). **2 NEW** findings this round (E14–E18,
neither predicted by round 1): a Verification-completeness gap in round 1's
own procAsFit execution, and a focus-state fallback hazard.

**Top 3 by axis, this round:**

- **DELETE:** none. Unchanged from round 1 (T-3370's D-566 ruling stands).
- **REFACTOR:** (1) **P-011 is author-controlled and cannot catch a Verification
  line the author never wrote** (E14–E16) — this round found a live instance
  inside the sequence's own round 1, not a hypothetical. T-3414 (filed by a
  concurrent session, not this sequence) already proposes the structural
  fix ("derive required verification lines from the task's git diff rather
  than trusting author memory") — that proposal is sound and is **not**
  re-derived here, only corroborated; (2) the focus-fallback hazard (E17,
  E18) — a shared-tree worker with no session-local focus file inherits
  whatever the last concurrent session set, and the gate's block message
  names that unrelated task, not the worker's own.
- **ADD:** unchanged priorities from round 1 — Δ2 (pytest leg) and Δ4
  (sidecar delivery observability) remain open; Δ3 (gate-bypass-log) is now
  CLOSED, drop it from the ADD list.

## 6. Findings table — round 1 predictions re-checked, plus new items

| ID | Item | Class | Prediction (round 1) | Re-check result | Evidence | Confidence | Proposal | Size | Reversible? | Risk if wrong | Expected effect (next check) |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Δ1 | Hook-write-blindness (was INVESTIGATE, round 1 CLOSED it) | **HELD** | "next audit run should stop citing hook-write-blindness as a live risk" | Latest full audit (06:32Z, pre-T-3412) has zero mentions; hook counters remain healthy and non-zero across all 19 named hooks | E2, E3 | MEDIUM (self-judged; single fresh audit snapshot + continuous counter both agree) | No action — close stays closed | N/A | N/A | If a future audit re-adds this WARN, that reopens it | Next `fw audit` run should still show zero hook-write-blindness citations |
| Δ2 | Nightly pytest leg reports `failed_count:0` on 0 collected tests | **UNTESTABLE this round (too early)** | "Within 14 days: `pytest tests > 0` on a nightly run, or a triaged red" | The cited run (`01:03–03:03Z`) is the **same run** round 1 cited — no new nightly cycle has occurred in the ~2.5h between rounds 1 and 2 | E4, E5 | MEDIUM (unchanged from round 1 — same evidence, re-observed) | Unchanged: give the pytest leg a budget it can finish in; treat 0-collected as a failure. Not re-derived, only re-confirmed still needed | M | Revert | Same as round 1 | Re-check after `2026-09-23T03:03Z` (next cron cycle) — the earliest round that can see a new data point is whichever round runs after that boundary |
| Δ3 | Gate-bypass-log does not parse | **HELD (resolved, verified independently)** | "`yaml.safe_load` succeeds; audit fails loud if it stops parsing again" | Re-ran the parse live this round (not trusting the procAsFit handback's self-report): `yaml.safe_load` succeeds, 1211 entries | E6, E7 | MEDIUM (self-judged; one independent fresh parse, corroborated by commit `0ec223c1e`'s existence and description) | Close — mark T-3370 A2 / round-1 Δ3 resolved. Second half of the prediction ("audit fails loud if it stops parsing again") is not yet exercised — no regression has occurred to test it | S (already done) | N/A | A future corruption would need its own check to confirm the audit actually fails loud | Next audit run parsing this file cleanly is the ongoing confirmation |
| Δ4 | Sidecar delivery observability | **STILL D — unmeasured on this channel's review-worker address; PARTIAL evidence found elsewhere** | "A future round of this same sequence that DOES receive a consult would be the first real signal — record whether it happens" | **Did not happen this round either** (E8) — second consecutive empty inbox. However, found real (non-test) hub-mediated sidecar traffic from **outside this sequence**: T-3407's own acceptance demo, 6 sends/acks, all before round 1 started (E9). That traffic has no terminal ACK/FAIL state recorded independently of the sidecar's own bookkeeping (E10) — Ground Rule "a channel cannot report its own failures" still applies | E8, E9, E10 | LOW (self-judged; n=0 for this sequence, n=6 for a different, self-referential demo) | Unchanged from round 1: instrument an out-of-band send/receive/drop counter before relying on this channel for governance-relevant consults. Upgrade slightly: the mechanism is proven reachable end-to-end at least once (T-3407's demo), which round 1 could not say with the same confidence — but production/organic cross-agent use is still unobserved | S–M | Revert (additive) | Same as round 1 | Round 3, 4, or 5 of this same sequence receiving a consult remains the strongest available signal; also worth checking after round 5 whether ANY of the 5 review workers ever got one |
| Δ5 | T-3411 driver mechanism correctness | **HELD, first real evidence** | "Round 5's Review prompt, if it correctly received rounds 1–4 context, is the check" (round 1 could not see this from inside itself) | This round **can** see it, one round early: `termlink channel snapshot seq:T-3411` shows 5 posts, exactly matching the AC's stated schema (round/step/worker/result-path/status), for round 1's both steps and round 2's dispatch. Driver log corroborates independently. This round's own prompt file was regenerated fresh (not the round-1 copy), and this report's own instructions correctly named round 1's two artifact paths to read first — direct proof the feed-forward mechanism worked at least once | E11, E12, E13 | MEDIUM (self-judged; two independent sources — topic snapshot and driver log — agree, would be HIGH with role separation) | No action — mechanism is working as designed through 2 of 5 rounds. Recommend a later round (3, 4, or 5) do one more spot-check rather than assuming it stays correct for all 5 | S | N/A (observation) | If round 3+ finds a broken link (e.g., a round dispatched without the prior round's paths), that reverses this finding | Round 5's own report explicitly confirming it received rounds 1–4 is still the strongest, final check |
| Δ6 | CLAUDE.md:459 → `zzz-default.md` — round 1 called this file-exists, unresolved | **REVERSED — round 1's close was a false lead; T-3370's original finding stands** | "A direct read of the cited line either confirms drift or shows it was already fixed" | Did the direct read round 1 didn't reach. `CLAUDE.md:459` names `zzz-default.md`. A file by that exact name exists **only at repo root** (unrelated legacy file, `mtime Feb 2026`) — **not** in `.tasks/templates/`, which is what T-3370's original citation actually named (`.tasks/templates/zzz-default.md`) and where `create-task.sh` actually looks (`default.md`, never `zzz-default.md`, at either path). Round 1's Δ6 found a same-named-but-wrong file and treated the reference as resolvable; it is not | E19, E20, E21 | MEDIUM (self-judged; direct source read of both the doc line and the resolving code, two independent files agree) | **Restore T-3370 R18 to open, unresolved** — CLAUDE.md:459's reference to `zzz-default.md` does not match any file `fw task create`/`create-task.sh` actually reads. Fix: either rename the doc reference to `default.md`, or rename `.tasks/templates/default.md` to match the doc (lower blast radius: fix the doc) | S | Revert | Leaving it uncorrected means every session reads a broken pointer at the top of its context (T-3370's own R18 rationale — CLAUDE.md loads every session) | A follow-up `grep -n "zzz-default" CLAUDE.md` returning nothing (doc fixed to say `default.md`) is the close condition |
| Δ7 | NEW: round 1's own procAsFit fix (T-3412) closed without the CLAUDE.md-mandated vendored-path Verification line | **ADD (REPAIR of process, not of T-3412 itself — already repaired by a concurrent task)** | not predicted by round 1 | T-3412 edited 3 vendored paths (`lib/inception.sh`, `agents/context/check-active-task.sh`, `agents/task-create/create-task.sh`) and closed with a `## Verification` block containing zero "vendor" references — violating CLAUDE.md §Vendored-path-touching tasks (OBS-250/T-3236). P-011 passed (it only runs what the author wrote); the pre-push self-vendor gate (T-2240/T-3125) caught it and named the fix. A **separate, concurrently-active task, T-3414**, already did the vendor sync and recorded the failure mode as an observation — but its 4th AC ("the push that was blocked now succeeds") is still **unticked**, and this round's own `git status` confirms the push has not happened yet | E14, E15, E16, E1 | MEDIUM (self-judged; direct read of T-3412's Verification block, T-3414's task body, and live git state, three independent sources agree) | Do not re-derive T-3414's proposed fix (deriving required Verification lines from the task's own git diff) — it is sound and already filed. This round's contribution: confirm the push AC is still open and name it as the most time-sensitive remaining item (unpushed commits are a standing data-loss risk per CLAUDE.md §Session End Protocol) | N/A (observation + status check) | N/A | If the push silently fails again, T-3412's real fix and this sequence's own round-1 artifacts stay stranded locally | `git status -sb` on bleeding-edge showing "up to date" with origin, or a fresh push commit, closes this |
| Δ8 | NEW: focus-state fallback hazard for shared-tree TermLink workers | **REFACTOR (harden — move from agent-judgement to deterministic framework code)** | not predicted by round 1 | `check-active-task.sh:50-51` falls back to the shared `focus.yaml` when a worker has no session-local `focus.<key>.yaml` yet. This round's own session started with no such file; the shared file pointed at `T-3414` (a real, unrelated, concurrently-active task); a read-only command was blocked citing **T-3414's** placeholder-AC state until this worker explicitly ran `fw context focus T-3411`. Adjacent to, but milder than, the G-083 "two autonomous writers" hazard the task file names — this is one worker inheriting stale/foreign routing state, not two workers colliding on writes | E17, E18 | LOW (self-judged, n=1 observed instance, no corroborating second source) | Consider: TermLink dispatch could pre-seed a session-local `focus.<key>.yaml` at worker spawn time (the driver already knows the task id), removing the fallback window entirely for sequence-driven workers. Sovereign question, not mine to decide — surfaced in §12 | S–M (if built) | Revert (additive) | None if not built — current behaviour is a friction/misdirection cost, not a correctness bug (the worker can and did self-correct) | A driver-spawned worker's first gate-checked command succeeding without a prior explicit `fw context focus` call would confirm the fix |

## 7. KEEP list (names only)

Unchanged from round 1, plus: the TermLink topic-posting mechanism in
`tools/prompt-sequence/run-sequence.sh` (Δ5 — now directly observed working,
not just asserted).

## 8. INVESTIGATE list + data needed

Carrying forward round 1's list unchanged, with two updates:

- **Δ4** (sidecar delivery observability) — still open. Data needed:
  unchanged from round 1 (out-of-band send/receive/drop counter). New
  partial data point recorded this round (E9, E10) does not close it.
- **Δ5** (driver correctness) — **substantially de-risked this round**, not
  fully closed. Recommend round 3 or 4 do one more spot-check of
  `seq:T-3411` rather than waiting for round 5 exclusively.
- **Δ6** — was wrongly marked resolvable by round 1; **reopened** this round
  with a direct, conclusive read (see Δ6 row above). Data needed: none
  further — the fix itself (a one-line doc correction) is what remains, and
  it is Q1-sized per the procAsFit round's own quadrant language.

## 9. Data gaps that capped confidence (ADD candidates in their own right)

Unchanged from round 1 (G1–G13), all still open. No new gap surfaced this
round rises to the level of a named G-number — Δ7 and Δ8 are process
findings, not measurement gaps.

## 10. Contradictions (docs vs code, purpose vs reality, source vs source)

Carrying forward round 1's 13 rows, with **row 13 (CLAUDE.md:459 /
`zzz-default.md`) status corrected**: round 1 left it "unresolved, flagged";
this round's direct read makes it **confirmed contradiction, unresolved** —
not a maybe. See Δ6.

New:

- **14.** T-3412's own Verification block vs. CLAUDE.md's own mandatory
  Vendored-path-touching rule for the exact files it touched (Δ7) — the task
  that fixed a governance-audit-log bug did not itself follow the governance
  rule that would have caught its own gap before push.

## 11. Not reviewed

Same exclusions as round 1 (unchanged this round — this round's scope was
prediction re-checking plus the two new items that surfaced incidentally
while re-checking, not a broader sweep). Also not reviewed: whether T-3414
(filed by a concurrent, non-sequence session) itself followed every
CLAUDE.md rule — out of this round's scope, noted only insofar as it bears
on Δ7.

## 12. Sovereign questions for the operator

All 10 of round 1's questions remain open (unchanged — no decision ledger
entry answers any of them, not re-checked in full this round for budget
reasons, no evidence contradicts round 1's read). Adding:

11. **Δ8's proposal** — should TermLink dispatch pre-seed a session-local
    `focus.<key>.yaml` for spawned workers, closing the shared-focus fallback
    window? This touches dispatch mechanics (`fw termlink dispatch` /
    `run-sequence.sh`), not gate authority itself, so it may be a normal
    build decision rather than a Sovereign one — flagged here because it
    touches shared session-state handling, which has an authority-adjacent
    flavor (a wrong pre-seed could mask real drift the same way the current
    fallback's *absence* of isolation does).
12. **Δ7's underlying question, restated**: should P-011 be able to derive
    required Verification lines from a task's own git diff (T-3414's
    proposal), rather than relying entirely on author memory? This is a
    structural-gate design change and belongs with the operator, not with
    this round's own selection.

**My recommendation, stated rather than left blank:** if forced to rank,
**Δ7 (the unpushed commits) deserves the fastest look** — not because it is
a judgment call, but because CLAUDE.md's own Session End Protocol names
unpushed commits as a standing data-loss risk, and this round's own `git
status` confirms 4 commits, including this sequence's round-1 work, are
still local-only. Everything else in this round's findings can wait; that
one is a clock running. Q7/Q6 from round 1 (review backlog, arc closures)
remain the second-priority items, unchanged in reasoning from round 1.

---

**Stop marker:** Phase 6 (execute approved items) is **not** run. No file
outside `docs/reports/SEQ-T3411/` was modified by this worker, except
`fw context focus T-3411` (a sanctioned state-set, logged by the framework,
not a file edit) and the sidecar-inbox checks (read-only). No gate was
force-bypassed; the one gate that refused a command (§Δ8/E17) was resolved
by the documented, sanctioned `fw context focus` call, not routed around.
Sidecar inbox checked 3× this round (session start, before writing the
evidence file, before writing this report) — empty every time
(`no pending consults on sidecar:seq-t3411-r2-review`).
