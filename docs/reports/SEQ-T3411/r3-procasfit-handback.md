# SEQ-T3411 Round 3 — procAsFit handback

- **Worker:** TermLink worker `seq-t3411-r3-procasfit`, round 3 of 5.
- **Input:** `docs/reports/SEQ-T3411/r3-review.md` + `r3-review-evidence.md`
  (round 3's prediction re-check of rounds 1-2, plus Δ9/Δ10 new findings).
  Used per the Mandate: its ADD items and Sovereign questions were candidates
  for my own selection, not a worklist.
- **Sidecar:** checked at every yield point (session start, before every
  Write/Edit, before/after closing every task, before this report) — empty
  every time, `no pending consults on sidecar:seq-t3411-r3-procasfit`.

## Selections made (stated before execution, per Mandate)

### Selection 1 — Δ7: push the 1 remaining unpushed commit (attempted, blocked, root cause advanced)

**Objective → Arc → Task → Quadrant:** D2 Reliability (constitutional
directive; no owning arc, same reasoning as rounds 1-2) → no arc → `git push
origin bleeding-edge` → **Q1** (near-zero cost, real value — round 2's own
review named this the fastest-look item; round 3's review reconfirmed it as
the standing recommendation).

**Why first:** cheapest, most time-sensitive item on the board, same
reasoning as round 2.

**Executed, not closed:** 6 push attempts across the round (immediate ×2,
45s wait, a bounded `until`-loop poll (~100s), an immediate retry, and one
`FW_PREPUSH_LOCK_WAIT=320` extended wait — a sanctioned, documented patience
knob per T-3297/OBS-305, not a bypass; it still requires a real audit
verdict). All six failed identically: `Another audit is already running —
exiting (no verdict produced)`. Never used `--no-verify`.

**New evidence this round, not available to round 2:** a concurrent session
on this same host independently filed and is actively working **T-3421**
("pre-push audit lock wait (90s) is shorter than the structure audit it
waits for (~292s): every contended push fails and re-runs the audit"),
observed live via `ps aux` mid-round. I verified the claim's premise
directly rather than taking it on faith: `agents/git/lib/hooks.sh:1137`
confirms `FW_PREPUSH_LOCK_WAIT` defaults to 90s. Round 2's own handback
independently measured one `audit.sh --section structure` invocation at
185s wall-clock against a near-empty scratch root. My own 320s wait *still*
failed, which sharpens T-3421's framing further: the blocker isn't one long
audit outrunning a 90s timer, it's **sustained multi-worker contention** —
`ps aux` during this round showed 3-5 concurrent `audit.sh --section
structure` processes at once, spawned by at least three other concurrent
TermLink sessions active on this host (an unrelated T-2122 4-round sequence
on a different project, and others). A longer wait doesn't help when the
lock is being continuously re-acquired by new entrants, not held by one slow
process.

**Did not duplicate T-3421.** Per "one lock at a time" / no converging
writes, I left that task to the session already working it rather than
opening a second structural change on the same root cause.

**Not closed this round** — same as round 2's own outcome on this item, now
with a materially better root-cause trace to hand to round 4/5 or the
driver.

### Selection 2 — Δ9: close T-3414 (executed and closed)

**Objective → Arc → Task → Quadrant:** D2 Reliability → no arc → T-3414 →
**Q1** (trivial — round 3's review found all 4 Agent ACs already ticked
with evidence in the task body; only the status transition was missing).

**Executed:** re-ran all three of T-3414's own verification lines directly
(`bin/fw vendor self --check`, the `errors="ignore"` grep, the
`git diff --quiet` unchanged-fix check) — all passed. Closed via
`fw task update T-3414 --status work-completed` (reviewer verdict PASS, 0
findings). Committed separately (`14b076e7d`).

**Note on why this was safe now, unlike when T-3414 itself deferred its own
close:** T-3414's own text explained the earlier hold — closing nulls
`focus.yaml`'s slot, and round 2's procAsFit worker was mid-flight sharing
that slot. This round confirmed (directly, via `ls .context/working/
focus.*.yaml`) that every SEQ-T3411 worker since round 1 has run under a
session-local focus file (`focus.seq-t3411-*.yaml`), so the shared-slot risk
T-3414 was guarding against does not apply to this sequence's own workers.

### Selection 3 — Δ4 (via T-3417): close arc-011 sidecar slice 6 (executed and closed)

**Objective → Arc → Task → Quadrant:** arc-011 (`parallel-execution-aef`,
`in-progress`) — Δ4's sidecar-observability ADD is a `D-DISJOINT`/
`D-WIRE-EVIDENCE`-adjacent slice of this arc → T-3417 → **Q1** (round 3's
review found all 5 Agent ACs already ticked, no Human ACs present, only the
status transition and a vendor-sync check remaining).

**Why this one next:** cheapest closeable item after Δ9, same
already-done-just-not-closed shape, and it directly closes out Δ4 — the
oldest open item in this sequence's own findings table (open since round 1).

**Executed:** ran all four of T-3417's verification lines directly —
`pytest tests/unit/test_sidecar_status.py test_sidecar_inbox.py
test_sidecar_termlink_transport.py test_sidecar_delivery.py
test_sidecar_outbox.py` (33 passed), `fw sidecar status --json` (both
`expired_unswept` and `ledger` keys present), `fw sidecar status --probe
--json` (`hub_probe` key present), `fw vendor self --check` (clean). Closed
via `fw task update T-3417 --status work-completed` (reviewer verdict PASS,
0 findings). Committed separately (`9d121ed8f`).

**Effect on Δ4:** the review's own D-reading ("unmeasured, trending toward
resolution") advances — the instrumentation itself is now `work-completed`,
not merely built. The underlying gap Δ4 named (no independent hub-side
send/receive/drop counter, only local ledger self-reporting) is unchanged;
T-3417 was always scoped as a reader over existing durable state, not that
counter, and its own body says so explicitly.

### Not selected — T-3420 (left alone, correctly)

**Objective → Arc → Task → Quadrant:** arc-011 → T-3420 ("fw audit rail —
WARN on stuck or UNKNOWN sidecar deliveries") → would have scored Q1 if
picked up cold.

**Why not:** at session start this worker's *inherited* `focus.yaml` (before
`fw context focus` was run) pointed at T-3420 — the same Δ8 fallback hazard
this sequence has now reproduced three rounds running, this round pointing
at a task another concurrent session was actively building (created
`2026-09-22T08:01:51Z`, inside this round's own window). Per "one lock at a
time" and the converging-writes discipline, I did not touch it. It was
independently completed and pushed by that other session mid-round
(`0943bfef0`, observed via `git log origin/bleeding-edge..HEAD` moving from
this worker's perspective — that commit is not mine and I made no edits
toward it). Correct outcome: avoided a second worker opening a structural
change on a task already claimed.

## Objectives advanced, and by how much (against state at round 3 start)

- **D2 Reliability:** two tasks fully closed (T-3414, T-3417), both were
  agent-ACs-complete-but-unclosed process-hygiene gaps the review's own Δ9
  and Δ4 named. `.tasks/active/` count for this sequence's own
  procAsFit-eligible backlog reduced by 2.
- **arc-011 (`parallel-execution-aef`):** advanced by one closed constituent
  task (T-3417). Δ4's sidecar-observability line of work is now shippable,
  not merely built.
- **Δ7 (data-loss risk):** NOT advanced this round in the literal sense (0
  of 1 remaining commits pushed) — but the root cause is now understood and
  independently corroborated (T-3421, source-verified 90s-vs-~292s+
  mismatch, sustained multi-worker contention confirmed even at 320s wait),
  which is real progress on the *diagnosis* even though the *symptom*
  (1 commit still local-only) is unchanged.
- **Not advanced this round:** Δ2 (Sovereign, gated on timeout-resize
  decision, unchanged); Δ8 (Sovereign, dispatch-mechanics decision,
  reproduced a 3rd time by round 3's review, not by this round — this round
  did observe the same fallback live at session start, a 4th data point,
  recorded above under "Not selected"); Δ10 (Sovereign, vendor-sync
  gate-scope decision, unchanged); T-3302 (still blocked on human
  sovereignty gate).

## Arc state

**No arc** claims Δ7/Δ9 (same D2-constitutional-directive reasoning rounds
1-2 applied — no arc owns "push a commit" or "close a stale-but-done task").

**arc-011 (`parallel-execution-aef`, in-progress):** this round closed one
constituent (T-3417, slice 6). T-3420 (slice 8) closed independently by a
concurrent session during this round, not by me. Both are now in
`.tasks/completed/`.

## What remains in Q1/Q2, per task, with the reason it was not done

| Item | Quadrant (estimate) | Why not done this round |
|---|---|---|
| **Δ7 — push the 1 remaining commit** | Q1 (near-zero cost) | Blocked on sustained pre-push audit-lock contention, now root-caused (T-3421, a concurrent session's diagnosis, independently verified against source: 90s default wait vs. ~185-292s+ actual audit duration, worsened by multiple concurrent TermLink sessions on this host queuing for the same lock). 6 bounded attempts, no `--no-verify`. **Top remaining item for round 4/5 or the driver — retry after T-3421 lands, or once this host's concurrent-session load drops.** |
| Δ2's actual fix — raise `FW_UNIT_SUITE_TIMEOUT`/`PY_RESERVE` | Q2 (high value, cost partly known) | Unchanged — Sovereign question, scheduling-policy call, not decided unilaterally. Now 3 consecutive nightly cycles confirm the same failure signature (round 3's review, Δ2). |
| Δ8 — pre-seed session-local focus for TermLink-spawned workers | Unscored, Sovereign | Unchanged — dispatch-mechanics decision. This round observed the hazard a 4th time (inherited focus pointed at T-3420 at session start), reinforcing but not changing the finding. |
| Δ10 — vendor-sync gate scope vs. `docs/generated/` | Unscored, Sovereign | New this round (round 3's review) — two structurally valid options named, neither an agent's call. Not investigated further; no new data needed, only an operator choice. |
| T-3302 close | Q1 (near-zero remaining cost) | Unchanged across all 3 rounds — blocked on the human sovereignty gate (`owner: human`). |
| Corpus-wide `docs/generated/components/*.md` refresh | Unscored, likely Q1 but touches ~185 files | Unchanged from round 2 — deliberately out of scope, flagged not executed. |

## Sovereign questions raised, unresolved, in priority order

Carried forward from round 3's review §12 (all 15 items — the 10 from round
1, round 2's Δ7/Δ8 additions, round 3's Δ10/Δ2-restated additions),
unchanged by this round except where noted:

1. **`FW_UNIT_SUITE_TIMEOUT`/`PY_RESERVE` re-sizing** (Δ2) — now 3
   consecutive nightly cycles confirming the same failure signature.
   Urgency rising; the question itself unchanged.
2. **Δ10's choice** (new, round 3's review) — extend the vendor-sync gate's
   declared scope to cover `docs/generated/`, or stop vendoring
   `docs/generated/` into `.agentic-framework/` at all. Either closes the
   drift; neither is an agent's call.
3. **Δ8's proposal** (pre-seed session-local focus at TermLink dispatch
   time) — corroborated a 4th time this round, live, at this worker's own
   session start. Still a dispatch-mechanics decision (`run-sequence.sh`/
   `fw termlink dispatch`), not mine to make.
4. **All remaining questions from rounds 1-3** (11 further items) — carried
   forward unchanged, not re-derived this round for budget reasons; see
   `r3-review.md` §12 for the full list.

**My recommendation, stated rather than left blank:** Δ7 remains the
single highest-leverage remaining item, and it is now better understood
than at any prior round — round 4 or 5 should retry the push after
checking `ps aux | grep 'audit.sh --section structure'` is quiet, or after
T-3421 lands (whichever comes first), rather than repeating my six-attempt
pattern from a cold start. Δ2 and Δ10 are next in priority, both
Sovereign, both ready for an operator decision with no further
investigation needed on my end.

## Gates that refused me, and what I did instead

| Gate | Where | What I did |
|---|---|---|
| Pre-push audit-lock contention | `git push origin bleeding-edge` (6 attempts, including one `FW_PREPUSH_LOCK_WAIT=320` sanctioned extended wait) | Waited, bounded, each time. Independently verified the T-3421 root-cause claim against source (`agents/git/lib/hooks.sh:1137`) rather than trusting it blindly. Did not force `--no-verify`. Named as the top remaining item rather than routed around. |
| Task gate (`check-active-task.sh`) fired once, mid-round | A chained `fw sidecar inbox && git add ...` command, right after T-3414 closed — my session-local focus still pointed at the just-closed T-3414 | This is Δ8 reproducing live, on myself, mid-round: the gate correctly refused a write under a stale focus pointer. Fixed the actual cause (`fw context focus T-3411`) rather than working around the gate; did not retry the exact same blocked command unmodified. |

No `--force` and no `--no-verify` used anywhere this round. Zero Tier-2
bypasses logged this round (none of this round's work required one).

## Cost-vs-estimate deltas worth feeding back into calibration

- **T-3414 and T-3417 both scored `tier: 2, effort: 8` by the estimator**
  (same heuristic pattern round 2 flagged for T-3416/T-3419) **despite
  having zero remaining implementation work at the point this round picked
  them up** — both were 100% agent-ACs-complete, needing only a status
  transition plus re-running already-passing verification lines. This is a
  third and fourth independent data point (after round 2's two) for the
  same estimator-blindness class: body length inflates the effort read
  regardless of how much of that body is finished work vs. remaining work.
  Worth a structural fix (e.g., weight remaining-unchecked-AC-count over raw
  body length) rather than a fifth anecdote next round.
- **Pre-push lock contention is now a measured, not estimated, cost**: 6
  attempts, ~20+ minutes of this round's wall-clock spent on a single
  near-zero-value-add git operation. If Δ7 keeps recurring round over
  round, the *true* cost of "push a commit" under current host load is not
  Q1 (near-zero) — it may be Q2 by wall-clock, even though the operation
  itself remains trivially reversible and low-risk. Worth flagging to
  whoever calibrates cost estimates for git operations under contention.

---

**Stop marker:** stopping at the end of Selection 3 (T-3417), having
advanced through every Q1 item this round's evidence surfaced that was safe
to touch (T-3420 correctly left to its concurrent owner). Not stopping
mid-task — T-3414 and T-3417 are each fully closed (agent ACs ticked,
verification green, reviewer PASS, 0 findings); Δ7's push is an ungated,
explicitly-named-open item, not an abandoned one. No BVP calibration
parameters were touched; no self-scored work was rescored upward. Sidecar
inbox checked at every yield point this round — empty throughout,
`no pending consults on sidecar:seq-t3411-r3-procasfit`.
