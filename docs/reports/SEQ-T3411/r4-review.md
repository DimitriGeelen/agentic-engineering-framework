# VALUE REVIEW — Round 4 (T-3411, seq:T-3411) — whole repo, prediction re-check

- **Worker:** TermLink worker `seq-t3411-r4-review`, round 4 of 5 (Review →
  procAsFit sequence).
- **Role setup:** **self-judged — GATHERER and JUDGE NOT separated**, same as
  rounds 1-3. Confidence capped one level below what corroboration alone
  would justify, applied throughout §6.
- **Human present:** no. All `[ASK]` gates below are answered on stated
  defaults and the run proceeds, per driver instruction. Phase 6 is **not**
  executed — this round stops at the end of Phase 5.
- **Read first, per the driver's mandate:** `r3-review.md` and
  `r3-procasfit-handback.md`, both in full, before any data-gathering.
- **Scope of this round:** re-run the check named by every "Expected effect"
  prediction in round 3's findings table (Δ1-Δ10), check whether round 3's
  procAsFit selections (T-3414 close, T-3417 close, the push attempts, the
  not-selected T-3420) landed and produced the predicted effect, and try to
  close anything round 3 left open. Nothing round 3 or its procAsFit round
  rejected is re-proposed here without new evidence.

---

## 1. Yardstick

**PROPOSED-UNCONFIRMED**, unchanged from rounds 1-3 — no evidence this round
that `policy/value-drivers.yaml` changed in substance, or that any of round
1's three stated questions (or round 3's cron-cadence question) were
answered. Reused verbatim:

> Make an AI agent's work traceable, reversible and human-sovereign by
> structural enforcement rather than agent discipline. It captures the
> record of what happened (Context Fabric), the map of what the work touches
> (Component Fabric), and forces a human decision at exactly the moments
> that need one. It *coordinates; it does not execute*.

**What I would have asked the human, had one been present:** rounds 1-3's
questions, unanswered, plus one this round's own evidence surfaces: three
independent tasks this sequence has now found (T-3414, T-3417, T-3420) sat
with every Agent AC ticked and verification evidence already written into
the body, yet none self-transitioned to `work-completed` — should there be a
structural nudge (a doctor WARN, an audit line) for "100% Agent ACs ticked,
no unticked Human ACs, status still `started-work`" the way there already is
for cron drift and vendor staleness?

## 2. Data availability map — deltas only

Unchanged from round 3 except:

| Source | Round 3 status | Round 4 status | Evidence |
|---|---|---|---|
| Nightly unit-suite cron | New cycle observed this round | **No new cycle** — round 4 reads the same `2026-09-22T01:03-03:03Z` entry round 3 already cited; next cycle not yet due | E18 |
| T-3421 (pre-push lock wait fix) | Did not exist (filed mid-round 3) | **EXISTS, in progress, uncommitted** — real code (`lib/prepush-lock-wait.sh`, `hooks.sh` diff, bats test) matching its own AC text against the live timing ledger; ACs unticked, status `started-work` | E6-E9 |
| Repo-root untracked debris | Not examined | **NEW, observed live**: 39 `discard-manifest.yaml` files + 3 unrelated 17-day-old stray root files, neither ever surfaced by rounds 1-3 despite each round reading `git status -sb` | E11, E12 |
| T-3420 (sidecar audit rail) | Did not exist (created mid-round 3, closed by a concurrent session per round 3's account) | **Commit landed (E15), but task status still `started-work`** despite all 5 Agent ACs ticked (E13, E14) — contradicts round 3 procasfit's own characterisation ("independently completed") at the status-field level | E13-E15 |

## 3. Role setup

Not separated (stated above), same cap as rounds 1-3.

## 4. Baseline

- Session start: `2026-09-22T08:18:05Z` (E0); this worker's driver-logged
  dispatch: `08:17:35Z` (E19).
- `git status -sb`: `bleeding-edge...origin/bleeding-edge [ahead 5]` — **up**
  from round 3's end-state of 1 unpushed commit to 5 (E3, E4). All 4 of
  round 3's procAsFit commits landed locally; none reached origin (6 push
  attempts, all blocked on audit-lock contention, per round 3's handback).
- `ps aux`: 3 concurrent `audit.sh --section structure` processes observed
  live at check time — direct, first-hand confirmation the contention T-3421
  diagnosed is still happening right now, not merely a historical artifact
  (E5).
- `fw sidecar inbox`: empty, checked 2× this round (session start, before
  write) — 4th consecutive round with zero inbound consults (E20).

## 5. Summary

**Prediction-recheck counts:** 3 HELD (Δ1, Δ5, Δ9-close-condition-met),
1 HELD-BUT-FLAT (Δ3 — same count as round 3, zero new entries), 1
UNTESTABLE (Δ2 — no new cron cycle since round 3's own check), 1 STILL D
but with its instrumentation leg now complete (Δ4), 1 WORSENED IN RAW COUNT
BUT MATERIALLY ADVANCED IN ROOT-CAUSE TERMS (Δ7 — 5 commits unpushed now vs.
1 at round 3, but the actual fix is now real, uncommitted code, not just a
diagnosis), 1 REPRODUCED A 4TH TIME (Δ8), 1 UNCHANGED (Δ10 — still open,
re-confirmed). **3 NEW** findings this round (Δ11, Δ12, Δ13), none
predicted by round 3.

**Top 3 by axis, this round:**

- **DELETE:** (1) **Δ13, NEW, trivial** — three dead, unreferenced,
  17-day-old debris files at repo root (`./6`, the `FABRIC:...` fragment,
  `Summary:`), shell-injection artifacts from an unrelated unquoted-command
  incident, never flagged by 3 prior rounds despite each reading the same
  `git status` output they sit in.
- **REFACTOR:** (1) **Δ11, NEW** — the "agent-ACs-done, status never
  transitioned" pattern this sequence first named at Δ9 (T-3414) and closed
  again at T-3417 has now recurred a third time (T-3420), independently of
  this sequence's own workers — this reads less like three unrelated
  one-offs and more like a systemic gap in whatever should prompt a
  task-closer once Agent ACs are complete; (2) **Δ12, NEW** — 39 untracked
  `discard-manifest.yaml` files (T-2366/arc-012 S4's compaction artifact)
  accumulating in `.context/handovers/`, never gitignored, never cleaned,
  invisible to 3 rounds' worth of `git status -sb` baselines because none of
  them enumerated the untracked-file list past the ahead/behind count.
- **ADD:** Δ7's underlying fix (derive `FW_PREPUSH_LOCK_WAIT` from the
  measured timing ledger rather than a fixed 90s) is now genuinely being
  built (T-3421, in progress) rather than purely diagnosed — the strongest
  forward movement on this sequence's single most time-sensitive open item
  since round 1.

## 6. Findings table — round 3 predictions re-checked, plus new items

| ID | Item | Class | Prediction (round 3) | Re-check result | Evidence | Confidence | Proposal | Size | Reversible? | Risk if wrong | Expected effect (next check) |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Δ1 | Hook-write-blindness | **HELD, 4th round running** | "Same check next round" | Fresher audit than round 3's citation (`.context/audits/2026-09-22.yaml`, mtime `10:19`, session-concurrent) — zero mentions | E17 | MEDIUM (self-judged; fresh independent snapshot, same result 4 rounds straight) | No action — close stays closed | N/A | N/A | Reopens only if a future audit re-adds the WARN | Same check next round (round 5) |
| Δ2 | Nightly pytest leg | **UNTESTABLE this round — no new data** | "Re-check after the timeout/reserve values are actually changed — a nightly run showing `pytest_rc≠124` or `bats_rc≠124` for the first time is the close condition" | No new cron cycle ran between round 3's check and this one — both rounds read the identical `2026-09-22T01:03-03:03Z` entry (E18). Not a re-derivation, the same data point re-cited. The next cycle (`~2026-09-23T03:03Z`) falls after this round's window | E18 | N/A (no new data to score) | Unchanged — still gated on the Sovereign `FW_UNIT_SUITE_TIMEOUT`/`PY_RESERVE` decision | M | Revert | Same as round 3 | Round 5 is the first round positioned to catch the next cycle, if it runs inside round 5's window |
| Δ3 | Gate-bypass-log parse | **HELD, but flat** | "Next audit run parsing this file cleanly is the ongoing confirmation" | Re-parsed independently: `yaml.safe_load` succeeds, 1212 entries — **identical** to round 3's count (round 2→3 was +1; round 3→4 is +0, consistent with zero new Tier-2 bypasses logged in the interval) | E16 | MEDIUM (self-judged; fresh independent parse) | Close stays closed | N/A | N/A | A parse failure on a future round would reverse this | Next round's independent re-parse |
| Δ4 | Sidecar delivery observability | **STILL D, instrumentation leg now complete** | "T-3417 reaching `work-completed` is a secondary, weaker but real signal" | **T-3417 confirmed `work-completed`** (E22) — the secondary signal round 3 predicted has fired. **Primary signal still absent**: 4th consecutive empty inbox (E20), `fw sidecar status` shows the same 6 messages total (no growth since round 3), every `seq-t3411-*` address — now including this worker's own — still at cursor `@0` (E21) | E20, E21, E22 | MEDIUM (self-judged; direct tool read, consistent across 4 rounds) | Unchanged core ask: an independent hub-side send/receive/drop counter. The local-instrumentation half of this ADD is now done; only the harder half (out-of-band, per Ground Rules) remains | S (remaining scope, if pursued) | Revert (additive) | Same as rounds 1-3 | Round 5's own report is this sequence's last chance to observe an organic consult directly |
| Δ5 | T-3411 driver mechanism correctness | **HELD, 4th round agreeing** | "Round 5's own report explicitly confirming it received rounds 1-4 together" | `termlink channel snapshot seq:T-3411` now shows 13 rows; row **[12]** is this worker's own dispatch, schema-identical to rows [0]-[11] | E19 | MEDIUM (self-judged; direct hub read, 4th consecutive round agreeing, would be HIGH with role separation) | No action — mechanism confirmed working through round 4. Round 5's own report remains the final, most complete check | S | N/A (observation) | If round 5 finds a broken link, that reverses this finding | Round 5's own report explicitly confirming it received rounds 1-4 |
| Δ7 | Unpushed commits (data-loss risk) | **Symptom WORSENED (1→5 commits), root cause MATERIALLY ADVANCED** | "`git status -sb` on bleeding-edge showing 'up to date' with origin, or a fresh push commit, closes this" | Not closed, and by raw count worse: `ahead 5` (E3, E4), because round 3's own 4 commits (2 closes + T-3420's landing + round 3's own review-report commit) accumulated on top of round 2's already-unpushed one, across 6 failed push attempts. **But**: this round found the actual fix in progress — T-3421's uncommitted `lib/prepush-lock-wait.sh` derives the wait window from the real measured `structure: 292` ledger entry (1.25×=365, matching the task's own stated AC), replacing the fixed-90s default round 3 traced as the root cause. Live `ps aux` confirms the contention this fix targets is happening at this exact moment (E5) | E3-E9 | MEDIUM (self-judged; git state + live process list + direct diff read all agree; would be HIGH with role separation) | This round does not push or execute (review-only). Name Δ7 as the standing item for round 4's own procAsFit: retry the push once T-3421 lands (or once `ps aux` shows the structure-audit queue clear), same recommendation round 3 gave, now with a concrete landing to watch for instead of an open-ended wait | N/A (observation) | N/A | If T-3421 lands mid-round-5 without this sequence noticing, a stale recommendation persists one round longer than necessary | `git status -sb` showing "up to date", OR T-3421 reaching `work-completed` (which would make a subsequent push attempt meaningfully more likely to succeed) |
| Δ8 | Focus-state fallback hazard | **REPRODUCED, 4th distinct occurrence** | "Round 4 or 5 either reproducing this a 4th/5th time (further confirms) or NOT reproducing it (would mean something changed — worth checking what)" | Reproduced: this worker's `focus.yaml`, read before calling `fw context focus`, pointed at `T-3421` — a fourth distinct real, unrelated, concurrently-active foreign task (round 2 review: `T-3414`; round 3 review: `T-3418`; round 3 procasfit's own session-start observation: `T-3420`). No pre-seeding fix was built (unchanged Sovereign question) | E1, E2 | MEDIUM (self-judged; 4 independent occurrences now agree) | Unchanged proposal: TermLink dispatch pre-seeds a session-local `focus.<key>.yaml` at spawn time. Every worker so far (4/4 review + at least 1 procasfit self-observation) has self-corrected via `fw context focus`, so correctness is not at risk — only the cost of a misdirected first read | S-M (if built) | Revert (additive) | Low (self-corrects every time observed) | Round 5 reproducing a 5th time closes the observation window this sequence can offer; not reproducing would be the first break in the pattern and worth investigating why |
| Δ9 | T-3414 all Agent ACs ticked, task never closed | **CLOSED — close condition met** | "`status: work-completed` on next read closes this" | Directly re-read: `status: work-completed` (E23) | E23 | MEDIUM (self-judged; direct file read) | Close confirmed — no further action | N/A | N/A | None — closed | None needed; see Δ11 for the broader pattern this instance was the first example of |
| Δ10 | Vendored `.agentic-framework/docs/generated/components/*.md` still stale | **UNCHANGED — still open, re-confirmed** | "Whichever option is chosen, a follow-up `grep -rn "zzz-default" .agentic-framework/docs/generated/` returning nothing closes this" | Re-ran the exact grep: still matches in all 3 files (E24) — neither of round 3's two named options has been chosen. Sovereign, not an agent's call | E24 | MEDIUM (self-judged; direct, exact re-run) | Unchanged — awaiting operator choice (extend gate scope vs. stop vendoring `docs/generated/`) | S (either option) | Revert | Low (self-vendored dogfood tree only, not consumer-facing) | Same grep, next round it is asked |
| Δ11 | NEW: agent-ACs-complete-but-status-never-transitioned recurs a 3rd time (T-3420) | **REFACTOR (process/tooling gap)** | not predicted by round 3 | T-3420: all 5 Agent ACs ticked with inline verification evidence (E14), commit landed (`0943bfef0`, E15) — but task file `status: started-work` (E13), contradicting round 3 procasfit's own account of it as "independently completed". This is the **third** instance this sequence has found of the same shape (T-3414 → Δ9, T-3417 → Δ4's secondary signal, now T-3420), across two different sets of workers (this sequence's own, and at least one concurrent unrelated session) | E13-E15 | MEDIUM (self-judged; direct file reads, cross-checked against a real commit) | Worth a structural nudge (doctor WARN or audit line) for "100% Agent ACs ticked, no unticked Human ACs, status still `started-work`" — the same shape as the existing cron-drift and vendor-staleness WARNs this repo already has for other silent-drift classes. Surfaced as a Sovereign question (§12) since it is a new gate/WARN, not mine to add unilaterally in a review-only round | S (if built as a WARN) | Revert (additive) | Low — a stale-but-correct task in `active/` costs review-list clutter, not correctness, same reasoning as Δ9 | If a WARN is added, `fw doctor` output growing a new line covering this class closes it; absent that, watching whether a 4th instance appears is the fallback signal |
| Δ12 | NEW: 39 untracked `discard-manifest.yaml` files, never surfaced in 3 prior baselines | **REFACTOR (hygiene) or ADD (gitignore entry)** | not predicted by round 3 | `git status --porcelain` shows 39 `.context/handovers/*.discard-manifest.yaml` files, dated `2026-09-16` through `2026-09-22` (E12), generated by `agents/handover/discard-manifest.sh` (T-2366, arc-012 S4) on compaction — not git-ignored, not committed, not cleaned, across every round of this sequence so far, because each round's baseline read `git status -sb`'s ahead/behind line without enumerating the untracked tail | E12 | LOW-MEDIUM (self-judged; direct count and content read, but no investigation yet into whether these are meant to be committed, gitignored, or periodically swept) | Two honest options, neither decided here: (a) gitignore the pattern if these are purely local scratch state; (b) if they carry audit/traceability value (they record what a compaction dropped), commit them or add a sweep/archive step. Surfaced as a Sovereign-adjacent question (§12) — the underlying design intent (commit vs. discard) is not visible from this round's evidence alone | S (either option) | Revert | Low — local disk clutter only, no correctness impact found | A follow-up count showing the file stops growing unbounded (either via `.gitignore` or a sweep) closes this |
| Δ13 | NEW: 3 dead, unreferenced debris files at repo root, ≥17 days old, unflagged by 3 prior rounds | **DELETE (trivial)** | not predicted by round 3 | `./6`, `./FABRIC: 2 component(s) modified: v1Send, outboundSendLog`, `./Summary:` — all `mtime 2026-09-05 20:57`, 0-153 bytes, clearly shell-word-splitting debris from an unrelated, unquoted multi-word string executed as a command elsewhere (the middle name is recognisable as an `fw fabric` auto-commit-message fragment). No reference anywhere in the repo; not cited by rounds 1-3 despite each reading the same `git status` output containing them (E11) | E11 | MEDIUM (self-judged; direct `ls`, direct grep of prior rounds' reports for absence) | `rm` the three files — no positive reason they're needed, no references, no external consumer, not referenced by any ratified workflow, trivially revertible (they're not tracked, so "revert" is simply "they were never there") | XS | Revert (N/A — untracked, re-creatable only by re-triggering the same shell mistake) | None — dead files with a well-understood, unrelated origin | A follow-up `git status -sb` no longer listing them closes this; procAsFit-eligible as a Q1 item if the operator agrees a review-only round's DELETE classification is enough justification, otherwise defer to explicit approval per Ground Rules ("nothing is deleted... until the human approves it item by item") |

## 7. KEEP list (names only)

Unchanged from rounds 1-3, plus: T-3421 (`lib/prepush-lock-wait.sh`,
in-flight, not this sequence's to touch) — real, substantive work-in-progress
directly addressing Δ7's root cause.

## 8. INVESTIGATE list + data needed

Carrying forward rounds 1-3's list unchanged, with updates:

- **Δ4** (sidecar delivery observability) — instrumentation leg now closed
  (T-3417). Remaining data needed: an out-of-band hub-side counter,
  unchanged; or, failing that, an organic consult in round 5.
- **Δ2** (pytest leg) — diagnosis closed (T-3416, prior rounds), fix still
  gated on a Sovereign timeout-resize decision. No new data this round.
- **Δ10** — needs an operator choice between the two named options, not
  further data. Unchanged.
- **Δ12** (NEW) — needs to know the intended lifecycle of
  `discard-manifest.yaml` files (commit? gitignore? sweep?) before a class
  can be assigned with confidence; currently a data gap, not a verdict.

## 9. Data gaps that capped confidence (ADD candidates in their own right)

Unchanged from rounds 1-3 (G1-G13), all still open. Δ11, Δ12, Δ13 are
process/hygiene findings discovered via direct evidence, not measurement
gaps — same distinction round 2 drew for its own Δ7/Δ8 and round 3 drew for
Δ9/Δ10.

## 10. Contradictions (docs vs code, purpose vs reality, source vs source)

Carrying forward rounds 1-3's 16 rows unchanged. New:

- **17.** Round 3 procAsFit's own handback narrative states T-3420 was
  "independently completed and pushed by that other session" — true for the
  *commit* (E15, landed, substantive), but the *task file's own status
  field* still reads `started-work` (E13) with all Agent ACs ticked (E14).
  "Completed" as used in that handback meant "the code shipped", not "the
  task was closed" — a distinction this round's evidence makes explicit
  where round 3's prose did not.
- **18.** Three rounds of this same sequence read `git status -sb` as part
  of their own stated baseline procedure and none surfaced the untracked
  tail (Δ12, Δ13) sitting in that same output — the baseline step names the
  command but each round's own summary compressed it to the ahead/behind
  count only.

## 11. Not reviewed

Same exclusions as rounds 1-3. Also not reviewed this round: T-3421's own
bats test results (deliberately not executed — see E10 and Ground Rules on
exercising unowned in-flight work); whether any `discard-manifest.yaml`
files predate 2026-09-16 (the file-listing command used only showed what
`git status` currently tracks as untracked, not a full historical count);
whether other repos/consumers accumulate the same debris class as Δ13.

## 12. Sovereign questions for the operator

All prior rounds' questions remain open (15 total after round 3's
additions), unchanged, not re-checked in full this round for budget reasons.
Adding:

16. **Δ11's question** — should `fw doctor` (or `fw audit`) gain a WARN for
    "task has 100% ticked Agent ACs, no unticked Human ACs, but status is
    still `started-work`"? This sequence alone has now found 3 instances
    (T-3414, T-3417, T-3420) of work that was functionally done sitting
    unclosed. Not an agent's call to add a new gate unilaterally.
17. **Δ12's question** — are `.context/handovers/*.discard-manifest.yaml`
    files meant to be committed (audit trail of what compaction drops),
    gitignored (pure local scratch), or periodically swept? 39 currently
    accumulate untracked. Whichever the intent, it should be made explicit
    rather than left as ambient `git status` noise.
18. **Δ13's disposal** — three dead debris files at repo root are an
    unambiguous DELETE by this round's evidence (no references, no
    consumer, understood unrelated origin, trivially reversible since
    they're untracked). Named here rather than executed, per Ground
    Rules' item-by-item human approval requirement even for low-risk
    deletes in a review-only round.

**My recommendation, stated rather than left blank:** **Δ9's closure
confirms the cheapest class of action in this sequence (ticking a status
field on already-done work) remains reliably successful once picked up** —
Δ11 generalises that into "watch for it happening again, and consider
automating the detection." **Δ7 is still the single highest-leverage open
item**, and unlike every prior round, there is now a concrete, nearly-built
artifact (T-3421) to watch for landing rather than an open-ended wait —
round 5 or the driver should check `git log` for a `T-3421` close commit
before attempting another push. **Δ13 (delete 3 dead files)** is the
cheapest item on the whole board this round — Q1-sized, zero ambiguity,
withheld only by the item-by-item approval rule, not by any evidentiary
doubt.

---

**Stop marker:** Phase 6 (execute approved items) is **not** run. No file
outside `docs/reports/SEQ-T3411/` was modified by this worker, except
`fw context focus T-3411` (a sanctioned state-set, logged by the framework,
writing only this worker's own session-local `focus.seq-t3411-r4-review.yaml`
— the shared `focus.yaml` was read but never written by this worker) and
read-only checks (git, grep, stat, ps, termlink, fw sidecar/task status
commands). T-3421's in-flight, uncommitted, unowned code was read
(`diff`/`cat`/`ls`) but never executed or modified, per the converging-writes
and exercising-unowned-work discipline in Ground Rules. No gate was
force-bypassed; no gate refused any command this round. Sidecar inbox
checked 3× this round (session start, before each Write, before this final
report) — empty every time,
`no pending consults on sidecar:seq-t3411-r4-review`.
