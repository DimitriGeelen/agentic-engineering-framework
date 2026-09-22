# VALUE REVIEW — Round 3 (T-3411, seq:T-3411) — whole repo, prediction re-check

- **Worker:** TermLink worker `seq-t3411-r3-review`, round 3 of 5 (Review →
  procAsFit sequence).
- **Role setup:** **self-judged — GATHERER and JUDGE NOT separated**, same as
  rounds 1-2. Confidence capped one level below what corroboration alone
  would justify, applied throughout §6.
- **Human present:** no. All `[ASK]` gates below are answered on stated
  defaults and the run proceeds, per driver instruction. Phase 6 is **not**
  executed — this round stops at the end of Phase 5.
- **Read first, per the driver's mandate:** `r2-review.md` and
  `r2-procasfit-handback.md`, both in full, before any data-gathering.
- **Scope of this round:** re-run the check named by every "Expected effect"
  prediction in round 2's findings table (Δ1-Δ8), check whether round 2's
  procAsFit selections (T-3415, T-3416, T-3419, the push) landed and
  produced the predicted effect, and try to close anything round 2 left
  open. Nothing round 2 or its procAsFit round rejected is re-proposed here
  without new evidence.

---

## 1. Yardstick

**PROPOSED-UNCONFIRMED**, unchanged from rounds 1-2 — no evidence this round
that `policy/value-drivers.yaml` changed in substance, or that any of round
1's three stated questions were answered. Reused verbatim:

> Make an AI agent's work traceable, reversible and human-sovereign by
> structural enforcement rather than agent discipline. It captures the
> record of what happened (Context Fabric), the map of what the work touches
> (Component Fabric), and forces a human decision at exactly the moments
> that need one. It *coordinates; it does not execute*.

**What I would have asked the human, had one been present:** rounds 1-2's
questions, unanswered — plus one this round's own evidence surfaces: round
2 miscounted the next nightly-cron boundary (predicted `2026-09-23T03:03Z`;
the actual next cycle ran a day earlier, `2026-09-22T03:03Z`, because the
cron is daily and round 2 undercounted from the same-day cadence between
rounds). Should the driver's round-to-round cadence be made cron-aware, so
"next cycle" predictions are computed from the cron schedule rather than
estimated per round?

## 2. Data availability map — deltas only

Unchanged from round 2 except:

| Source | Round 2 status | Round 3 status | Evidence |
|---|---|---|---|
| Nightly unit-suite cron | Same run cited both rounds 1 and 2 (no new cycle in window) | **New cycle observed** (`2026-09-22T01:03-03:03Z`) — same failure signature (`bats_rc=124 pytest_rc=124`) | E8 |
| Sidecar out-of-band observer | GAP, none existed | **PARTIAL — now exists** (`fw sidecar status`, T-3417), but self-reads local ledger only, not hub-side; task still `started-work` | E15, E16 |
| Vendored `.agentic-framework/` copy of `docs/generated/components/*.md` | not examined | **GAP, observed live**: 3 files still carry the exact stale reference T-3419 set out to remove, 5+ weeks unregenerated, outside the vendor-sync gate's declared scope | E17-E21 |
| T-3414 (round 1's own vendor-fix task) | Δ7 flagged its 4th AC as unticked | **All 4 ACs now ticked**, but task status still `started-work` — never formally closed | E12 |

## 3. Role setup

Not separated (stated above), same cap as rounds 1-2.

## 4. Baseline

- Session start: `2026-09-22T07:58:40Z` (E0).
- `git status -sb`: `bleeding-edge...origin/bleeding-edge [ahead 1]` — down
  from round 2's end-state of 2 unpushed commits to 1 (E1, E2). The single
  remaining unpushed commit is round 2's own review-report commit.
- `fw sidecar inbox`: empty, checked 3× this round (session start, before
  each Write) — third consecutive round with zero inbound consults (E14).

## 5. Summary

**Prediction-recheck counts:** 4 HELD (Δ1, Δ3, Δ5, Δ6-close-condition-met),
1 PARTIALLY HELD / advanced-not-closed (Δ7), 1 tested-with-a-negative-result
(Δ2 — new data point arrived, shows no improvement, which is the *expected*
outcome since the fix was correctly deferred pending a Sovereign decision),
1 STILL D / partially addressed (Δ4), 1 REPRODUCED A THIRD TIME (Δ8 — not a
re-check of a prediction, but the hazard recurred live, unprompted, again).
**2 NEW** findings this round (Δ9, Δ10), neither predicted by round 2.

**Top 3 by axis, this round:**

- **DELETE:** none. Unchanged from rounds 1-2 (T-3370's D-566 ruling
  stands).
- **REFACTOR:** (1) **Δ8, now a 3-for-3 pattern** — every one of this
  sequence's 3 rounds-with-a-fresh-worker observed the shared-`focus.yaml`
  fallback pointing at a different, unrelated, real active task
  (`T-3414` in round 2, `T-3418` in round 3) before the worker explicitly
  called `fw context focus`. Three independent occurrences, three different
  foreign tasks, is no longer a single-instance friction cost — it is the
  reliable behaviour of every TermLink-spawned worker in this sequence that
  has not yet been given a pre-seeded session-local focus file; (2) **Δ10,
  NEW** — the vendor-sync gate's declared scope (`bin/fw`, `lib/`, `agents/`,
  `policy/`, `web/`, `.tasks/templates/`) does not include `docs/generated/`,
  so a doc-drift fix that explicitly targeted `docs/generated/components/`
  (T-3419) landed in the live copy but left the vendored dogfood copy
  exactly as stale as before — silently, because nothing checks it.
- **ADD:** Δ4 (sidecar delivery observability) is now genuinely in progress
  (T-3417 exists, partial) rather than purely open; Δ9 (NEW) — T-3414's
  task-closure step itself was skipped despite all 4 Agent ACs being done,
  a small process-hygiene gap worth naming since it is the exact kind of
  loose end CLAUDE.md's Session End Protocol warns about.

## 6. Findings table — round 2 predictions re-checked, plus new items

| ID | Item | Class | Prediction (round 2) | Re-check result | Evidence | Confidence | Proposal | Size | Reversible? | Risk if wrong | Expected effect (next check) |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Δ1 | Hook-write-blindness | **HELD, 3rd round running** | "Next `fw audit` run should still show zero hook-write-blindness citations" | A fresher audit than round 2's citation exists (`.context/audits/2026-09-22.yaml`, mtime session-concurrent) — zero mentions | E9 | MEDIUM (self-judged; fresh independent snapshot, same result 3 rounds straight) | No action — close stays closed | N/A | N/A | Reopens only if a future audit re-adds the WARN | Same check next round |
| Δ2 | Nightly pytest leg | **Tested this round — result NEGATIVE (unimproved), as expected** | "Re-check after `2026-09-23T03:03Z` (next cron cycle)" | Round 2 miscounted the boundary — the actual next cycle ran a day earlier (`2026-09-22T01:03-03:03Z`). Checked it directly: **same failure signature** (`bats_rc=124 pytest_rc=124`) as the two prior cycles. This is the expected result, not a surprise — T-3416 (round 2) diagnosed the root cause and correctly deferred the fix pending a Sovereign timeout-resize decision (§12), so an unchanged nightly result is consistent with "diagnosed, not yet authorized to fix," not with "diagnosis was wrong" | E8, E10 | MEDIUM (self-judged; three independent nightly runs now agree on the failure signature) | No new action — the fix remains gated on the Sovereign question T-3416/round 2 raised. Re-affirm it as the single highest-leverage open item once authorized | M (unchanged) | Revert | Same as round 2 | Re-check after the timeout/reserve values are actually changed — a nightly run showing `pytest_rc≠124` or `bats_rc≠124` for the first time is the close condition |
| Δ3 | Gate-bypass-log parse | **HELD** | "Next audit run parsing this file cleanly is the ongoing confirmation" | Re-parsed independently this round: `yaml.safe_load` succeeds, 1212 entries (round 2: 1211 — +1, consistent with one new Tier-2 bypass logged since, matching T-3419's `--skip-render-review`) | E7 | MEDIUM (self-judged; fresh independent parse, monotonic entry growth consistent with expected activity) | Close stays closed | N/A | N/A | A parse failure on a future round would reverse this | Next round's independent re-parse |
| Δ4 | Sidecar delivery observability | **STILL D, but now partially addressed** | "Round 3, 4, or 5 of this same sequence receiving a consult remains the strongest available signal" | **Still did not happen this round** (E14) — third consecutive empty inbox across 3 different worker addresses. **New:** `fw sidecar status` (T-3417) now exists and confirms, from the channel's own bookkeeping, that all 5 sequence-worker addresses sit at inbox cursor `@0` — never delivered anything. This is the instrumentation round 1/2 called for, arriving in progress, not a false all-clear: its own help text says "never asks the hub," so it still cannot see a hub-side silent drop, only local non-delivery | E14, E15, E16 | LOW-MEDIUM (self-judged; the new tool corroborates but does not close the out-of-band gap Ground Rules require) | Unchanged core ask: an independent (non-sidecar) hub-side send/receive/drop counter. Upgrade: T-3417 is real, tracked, in-progress work toward it — worth closing rather than re-deriving from scratch | S-M (T-3417 already exists; closing it is the remaining unit) | Revert (additive) | Same as rounds 1-2 | Round 4 or 5 receiving an organic consult remains the strongest signal; T-3417 reaching `work-completed` is a secondary, weaker but real signal |
| Δ5 | T-3411 driver mechanism correctness | **HELD, further de-risked** | "Recommend round 3 or 4 do one more spot-check of `seq:T-3411` rather than waiting for round 5 exclusively" | Did exactly that: `termlink channel snapshot seq:T-3411 --as-of <now>` shows row **[8]**, this worker's own dispatch, schema-correct (round/step/worker/result-path/status), matching rows [0]-[7] from rounds 1-2 exactly. Direct, first-hand proof of the feed-forward mechanism working through 3 of 5 rounds, from inside round 3 itself | E13 | MEDIUM (self-judged; direct hub read, 3rd consecutive round agreeing, would be HIGH with role separation) | No action — mechanism confirmed working through round 3. Round 5's own report remains the final, most complete check (it alone can confirm receipt of rounds 1-4 together) | S | N/A (observation) | If round 4 or 5 finds a broken link, that reverses this finding | Round 5's own report explicitly confirming it received rounds 1-4 |
| Δ6 | CLAUDE.md:459 → `zzz-default.md` | **CLOSED — close condition met** | "A follow-up `grep -n \"zzz-default\" CLAUDE.md` returning nothing (doc fixed to say `default.md`) is the close condition" | Ran exactly that grep: no match | E6 | MEDIUM (self-judged; direct, exact re-run of the stated close condition) | Close — T-3415's fix confirmed landed and correct | N/A (done) | N/A | None — closed | None further needed on this narrow item; see Δ10 for the broader propagation this fix did not fully complete |
| Δ7 | Unpushed commits (data-loss risk) | **PARTIALLY HELD — advanced, not closed** | "`git status -sb` on bleeding-edge showing 'up to date' with origin, or a fresh push commit, closes this" | Not fully closed: `git status -sb` shows `ahead 1`, down from round 2's `ahead 2` — the two commits round 2 flagged as lock-blocked (T-3419's close + vendor sync) are now confirmed on origin (T-3414's own AC4 evidence cites the successful push hash, and the recent-commits banner shows both `T-3419` commits present). One commit remains local-only: round 2's own review-report commit (`38326625e`), created after round 2's last push attempt | E1, E2, E3, E12 | MEDIUM (self-judged; git state directly observed, corroborated by T-3414's independent AC text) | This round does not push (Phase 6 is out of scope for a review-only round) — name it as the standing, still-live, still-time-sensitive item for round 4's procAsFit or the driver, same reasoning CLAUDE.md's Session End Protocol gives for unpushed commits generally | N/A (observation) | N/A | If left uncorrected across another round, this sequence's own artifacts accumulate further unpushed | `git status -sb` showing "up to date" is still the close condition; not yet met |
| Δ8 | Focus-state fallback hazard | **REPRODUCED, 3rd occurrence, pattern now clearer** | "A driver-spawned worker's first gate-checked command succeeding without a prior explicit `fw context focus` call would confirm the fix" | The fix (pre-seeding) was not built (Sovereign question, correctly not decided unilaterally) — so the fallback fired again, exactly as before: this worker's `focus.yaml`, read before calling `fw context focus`, pointed at `T-3418` (round 2 saw `T-3414`; both real, unrelated, concurrently-active tasks). Three rounds, three different foreign tasks, zero rounds where a session-local focus file pre-existed at spawn. This raises the finding from "one observed instance" (round 2, LOW confidence) to "the reliable behaviour of every worker spawned so far" | E4, E5 | MEDIUM (self-judged; 3 independent occurrences now agree, though still n=3 not n=5) | Unchanged proposal from round 2: TermLink dispatch pre-seeds a session-local `focus.<key>.yaml` at spawn time. Confidence in the *cost* of not fixing it (misdirected block messages, wasted diagnosis time) is now higher; the fix itself remains a dispatch-mechanics decision for the operator | S-M (if built) | Revert (additive) | Low if left unfixed (each worker self-corrects, as observed 3/3 times) — cost is friction, not correctness | Round 4 or 5 either reproducing this a 4th/5th time (further confirms) or NOT reproducing it (would mean something changed — worth checking what) |
| Δ9 | NEW: T-3414 all Agent ACs ticked, task never closed | **ADD (process hygiene) / minor** | not predicted by round 2 | `.tasks/active/T-3414-...md` has all 4 Agent ACs marked `[x]`, including direct evidence the push it was tracking succeeded — but `status: started-work`, never transitioned to `work-completed`. Not a Human-AC partial-complete (no `owner: human`, no unchecked Human ACs found) — simply an open task whose agent-side work is done and was never formally closed | E12 | MEDIUM (self-judged; direct read of the task file's AC and status lines, internally consistent) | Someone (round 4's procAsFit, or the human) should run `fw task update T-3414 --status work-completed` — trivial, no new investigation needed, the evidence is already in the task body | S | Revert (status change only) | Low — a stale-but-otherwise-correct task sitting in `active/` costs review-list clutter, not correctness | `status: work-completed` on next read closes this |
| Δ10 | NEW: vendored `.agentic-framework/docs/generated/components/*.md` still stale | **REFACTOR (extend vendor-sync scope) or ADD (targeted regen) — Sovereign-adjacent** | not predicted by round 2 | T-3419 fixed the live, authoritative `docs/generated/components/{lib-tasks,web-blueprints-tasks,web-templates-tasks}.md` (confirmed clean, E18) and regenerated them this morning (E19). The **vendored** `.agentic-framework/` copies of the same 3 files still contain the exact stale `zzz-default.md` reference (E17), last touched 2026-08-14 — over 5 weeks before this incident's own remediation work. `fw vendor self --check` reports clean regardless (E20), because CLAUDE.md's own Vendored-path-touching gate scope explicitly excludes `docs/generated/` (E21) — this is not a gate bug, it is an acknowledged scope boundary the gate was never meant to cover. Net effect: the R18 propagation problem (T-3370's original citation, the whole reason T-3419 exists) is now fixed everywhere the gate can see, and still live in the one vendored location the gate cannot see | E17-E21 | MEDIUM (self-judged; direct content + mtime comparison of both copies, plus direct source-read of the gate's declared scope, three independent facts agree) | Two honest options, not mine to pick: (a) extend the vendor-sync gate's declared scope to include `docs/generated/`, accepting the extra sync cost on every generated-doc change; or (b) exclude `docs/generated/` from what gets vendored into `.agentic-framework/` at all, on the reasoning that generated docs describe a project's own components and a vendored copy of the *framework's own* generated docs inside its own self-vendored tree is dogfood cruft, not a real consumer-facing surface. Surfaced as a Sovereign question (§12) rather than decided here | S (either option) | Revert | Low — the vendored copy is not consumer-facing (it is this repo's own internal self-vendored dogfood tree), so the drift's real-world blast radius is small, but it is the same class of silent doc-reference rot the whole R18 line of work exists to catch | Whichever option is chosen, a follow-up `grep -rn "zzz-default" .agentic-framework/docs/generated/` returning nothing closes this |

## 7. KEEP list (names only)

Unchanged from rounds 1-2, plus: `fw sidecar status` (T-3417, Δ4) — real,
working, in-progress instrumentation, even though not yet closed.

## 8. INVESTIGATE list + data needed

Carrying forward rounds 1-2's list unchanged, with updates:

- **Δ4** (sidecar delivery observability) — still open, now partially
  instrumented (T-3417). Data needed: an out-of-band hub-side counter,
  unchanged.
- **Δ2** (pytest leg) — diagnosis closed (T-3416), fix still gated on a
  Sovereign timeout-resize decision. Not re-derived; the decision itself is
  the remaining blocker, not more investigation.
- **Δ10** (NEW) — needs an operator choice between the two options named
  above, not further data.

## 9. Data gaps that capped confidence (ADD candidates in their own right)

Unchanged from rounds 1-2 (G1-G13), all still open. Δ9 and Δ10 are process
findings, not measurement gaps, same distinction round 2 drew for its own
Δ7/Δ8.

## 10. Contradictions (docs vs code, purpose vs reality, source vs source)

Carrying forward rounds 1-2's 14 rows unchanged. New:

- **15.** T-3419's own procAsFit handback claimed the 3
  `docs/generated/components/*.md` stale references "self-heal on regen...
  confirmed" — true for the live copy, not verified (and, this round finds,
  not true) for the vendored copy of the same 3 files (Δ10).
- **16.** `fw vendor self --check` reports "in sync" for a tree that
  contains a byte-for-byte-verifiable stale doc reference the sync claims to
  cover in spirit (R18's whole point) but does not cover in its declared
  scope (Δ10) — a true statement about a narrower scope than a casual
  reading of "in sync" would suggest.

## 11. Not reviewed

Same exclusions as rounds 1-2. Also not reviewed this round: the full
contents of T-3417's own task body (only its status and the command's live
behaviour were checked); whether any other vendored-path file classes
besides `docs/generated/` share the same excluded-from-gate-scope property.

## 12. Sovereign questions for the operator

All prior rounds' questions remain open (13 total after round 2's
additions), unchanged, not re-checked in full this round for budget reasons.
Adding:

14. **Δ10's choice** — extend the vendor-sync gate to cover
    `docs/generated/`, or stop vendoring `docs/generated/` into
    `.agentic-framework/` at all? Either closes the drift; neither is an
    agent's call, since both are gate-scope/dogfood-tree design decisions.
15. **Δ2's Sovereign question, restated with one more data point**: the
    nightly unit-suite budget resize (round 2's Δ2/T-3416 question) now has
    a third consecutive confirming data point (same failure signature,
    3 nights running). This does not change the question, only its
    urgency — the diagnosis is not going to un-happen on its own.

**My recommendation, stated rather than left blank:** **Δ7 (push the last
remaining commit) is still the fastest, lowest-risk look** — it is a single
commit, no lock contention observed *by this round* (this round did not
attempt a push, being review-only, but nothing in this round's evidence
suggests the contention round 2 hit is still active). **Δ9 (close T-3414)**
is equally cheap and equally clear-cut — the evidence to close it is already
written in the task file. Both are Q1-sized per the procAsFit round's own
quadrant language and neither requires new investigation, only the
mechanical step. Δ10 and Δ2's Sovereign questions are next in priority,
unchanged in reasoning from round 2.

---

**Stop marker:** Phase 6 (execute approved items) is **not** run. No file
outside `docs/reports/SEQ-T3411/` was modified by this worker, except
`fw context focus T-3411` (a sanctioned state-set, logged by the framework,
not a file edit) and read-only checks (git, grep, stat, termlink, fw
sidecar/task/vendor status commands). No gate was force-bypassed; no gate
refused any command this round. Sidecar inbox checked 3× this round (session
start, before each Write) — empty every time
(`no pending consults on sidecar:seq-t3411-r3-review`).
