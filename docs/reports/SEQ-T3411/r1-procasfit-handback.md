# SEQ-T3411 Round 1 — procAsFit handback

- **Worker:** TermLink worker `seq-t3411-r1-procasfit`, round 1 of 5.
- **Input:** `docs/reports/SEQ-T3411/r1-review.md` + `r1-review-evidence.md` (the
  Round 1 Review — a re-verification of T-3370's 2026-09-16 whole-repo value
  review, not a from-scratch review). Used per the Mandate's instruction: its
  ADD/REPAIR items were candidates for my own selection, not a worklist.
- **Sidecar:** checked at start, at both yield points before Write/Edit, and
  immediately before this file — empty every time
  (`no pending consults on sidecar:seq-t3411-r1-procasfit`).

## Selections made (stated before execution, per Mandate)

### Selection 1 — T-3302 (parked, not executed)

**Objective → Arc → Task → Quadrant:** D2 Reliability (constitutional
directive; no in-flight arc owns "unit-suite audit reliability" — checked all
18 in-progress + 2 draft arc YAMLs, none match) → no arc → T-3302 → **Q1**
(all 6 Agent ACs already ticked, RCA/Recommendation:GO already written by a
prior session; the *remaining* activity — verify and close — is near-zero
cost against real, evidenced Reliability value: it is one of the two
still-open items the round-1 review's evidence explicitly names as unresolved
6 days on).

**Why this one first:** it looked closeable on inspection (all Agent ACs
ticked, Recommendation: GO already on file) rather than needing new work —
the cheapest kind of Q1.

**Executed:** re-ran the task's own `## Verification` block independently
(did not trust the checkmarks — Producer-not-judge): `tests/unit/t3302_unit_suite_schedule.bats`
20/20 green, 0 skips; `fw doctor` shows "Cron registry in sync", no "edited
but not generated" WARN. All three verification lines pass.

**Gate that refused me:** `fw task update T-3302 --status work-completed
--switch-focus` → **sovereignty gate (R-033)**: `owner: human`, refuses agent
closure even with 0/0 Human ACs. Per the Mandate ("a gate that refuses you is
a finding to be recorded, not an obstacle to route around") I did not force
it. The gate emitted `http://192.168.10.107:3002/review/T-3302` and created
`.context/working/.reviewed-T-3302`. **Parked — this is a genuine one-click
human action, not new work**: the evidence is already written, verified twice
independently (prior session + this round), and the review URL is live.

### Selection 2 — T-3412 (executed and closed)

**Objective → Arc → Task → Quadrant:** D2 Reliability (same directive, same
"no owning arc" reasoning) → no arc → new task T-3412 → **Q1** (root cause
investigation was cheap — under an hour of tracing — and the fix at each call
site was a 1–5 line change; value is high: this defect blocked two
independent whole-repo reviews 6 days apart from ever explaining *why* the
audit's own bypass log was unreadable).

**Why this one:** the round-1 review's Δ3 finding ("gate-bypass-log does not
parse") was evidenced but *uninvestigated* — both T-3370 and the round-1
review cited the same symptom without finding a cause. Root-causing it turned
"repair the file" (a one-time patch that would recur) into "fix the writer"
(a structural fix), which is the higher-value version of the same ADD item.

**Scored:** `fw bvp estimate T-3412` → D1=4 D2=4 D3=3 D4=2 F-RECALL=2
(proposed, estimator-run — not hand-waved). `fw bvp confirm` is
sovereignty-gated (`--i-am-human`/`--from-watchtower` only) and not available
to me; proceeded on the proposed score, which is the only "scored" an agent
can produce. Noted as a gate boundary, not routed around.

**Executed:**
1. Traced the root cause: `agents/context/check-active-task.sh` truncates
   the logged `BASH_CMD` with `head -c 200` (raw byte offset, no UTF-8
   boundary awareness) at 2 call sites — confirmed by locating the exact
   corrupted byte (absolute file offset 279363 = 68×4096 + 835, i.e. PyYAML's
   reported "position 835" is its internal read-chunk offset, not a second
   distinct bug — same byte, same cause, both citations correct).
2. Fixed both call sites: decode with `errors="ignore"` after the byte
   truncation, so an incomplete trailing UTF-8 sequence is dropped rather
   than kept.
3. While verifying the fix against the live file, found a **second,
   independent** corruption: `create-task.sh` and
   `lib/inception.sh:do_inception_start` interpolate a free-text inception
   title into a single-quoted YAML scalar with no escaping (same file, same
   defect class — L-370 — different writer, different specific bug: an
   embedded apostrophe, not a byte-truncation). Fixed both with the
   quote-doubling idiom T-1861 already established elsewhere in this
   codebase (`agents/task-create/update-task.sh:log_gate_bypass`). Also
   audited the remaining ~9 writers of this file (grep on `} >> "$log"`-style
   append blocks) — all already escape correctly (T-1861/L-392 precedent) or
   only interpolate structurally-safe values (T-NNNN ids, fixed strings).
4. Repaired the two existing corrupted entries in the live file in place
   (surgical byte/string replacement, each confirmed to occur exactly once
   before touching it; pre-edit backup taken at
   `/tmp/.gate-bypass-log.yaml.pre-t3412-backup`).
5. Wrote `tests/unit/t3412_bypass_log_utf8_truncation.bats` — 4 tests (the
   UTF-8-boundary fix + an ASCII control for check-active-task.sh, plus one
   apostrophe-title case each for create-task.sh and do_inception_start).
   20/20 T-3302 tests + 100/100 across 10 sibling suites touching the same
   files re-run clean (no regressions).
6. Closed via `fw task update T-3412 --status work-completed` — no sovereignty
   block (`owner: agent`, no Human ACs); verification gate ran all 3 lines,
   passed; reviewer static-scan PASS, 0 findings.
7. Committed (`0ec223c1e`, 7 files, +774/-6) under focus T-3411 (T-3412's own
   focus was cleared by its own close, per the documented close-then-commit
   sequencing in CLAUDE.md §Vendored-path-touching tasks — same shape applied
   here to the focus gate rather than the vendor sync it names).

**Check that closed each AC:** all 5 Agent ACs verified by re-running the
task's own `## Verification` block post-fix (`yaml.safe_load` exit 0; bats
4/4, 0 skips) — not self-certified from memory.

## Objectives advanced, and by how much

- **D2 Reliability:** the audit substrate got measurably more trustworthy.
  `.context/working/.gate-bypass-log.yaml` — the Tier-2 bypass audit trail —
  now parses (it did not, for at least 6 weeks: oldest corrupted entry dated
  2026-08-09). Two structural writer bugs fixed at 4 call sites, not just the
  symptom patched once. T-3302 (nightly unit-suite visibility, the *other*
  half of the same directive) is verified-complete and one click from closing
  — state advanced from "silently stuck" to "ready for a human decision."
- **Not advanced this round:** Δ4 (sidecar delivery observability) and Δ2
  (pytest leg `failed_count:0` on 0 collected tests) — see below.

## Arc state

No arc claimed either unit of this round's work (checked all 20 arc YAMLs;
none own "unit-suite/audit reliability" or "gate-bypass-log integrity").
Both were constitutional-directive-level (D2) work with no owning arc, which
is itself worth naming: this class of cross-cutting reliability repair has no
arc home in the current 18-arc portfolio.

## What remains in Q1/Q2, per task, with the reason it was not done

| Item | Quadrant (estimate) | Why not done this round |
|---|---|---|
| T-3302 close | Q1 (near-zero remaining cost) | **Blocked on human sovereignty gate**, not cost or value. Review link live: `http://192.168.10.107:3002/review/T-3302`. This is the single highest-priority remaining item — it is a decision, not work. |
| Δ2 — pytest leg reports `failed_count:0` on 0 collected tests (T-3370 A1, this round's E7) | Likely Q1–Q2, unscored | Root cause not yet traced (unlike Δ3, which I did trace this round). Distinct from T-3366's already-filed bug (T-3366 is about ERROR-log-line miscounting on a leg that DID collect; E7 is about 0 tests collected under `exit 124` timeout still reporting `failed_count:0`). Needs its own root-cause pass before it can be honestly scored — did not want to file an unscored, unlocalised task under time/context discipline for this round. **Candidate for round 3.** |
| Δ4 — sidecar delivery observability (no send/receive counter distinct from unit tests) | Unscored, likely Q2 (real but not urgent — the sidecar's read path works; only the send/cross-agent path is unmeasured) | This is instrumentation-*design* work (what should the observer measure, where does it live — hub-side vs TermLink-repo-owned), closer to the Mandate's "Discovery is read-only… Sovereign questions are surfaced, not resolved" boundary than to a scoped fix. Recommend this go through an inception, not a direct build task. |
| Δ6 — CLAUDE.md:459 / `zzz-default.md` drift check | Trivial (S), unscored | Genuinely 2 minutes of work (one `grep`) that I did not reach — deprioritised below the two Reliability items above. Flagging so round 3 picks it up cheaply. |

## Sovereign questions raised, unresolved, in priority order

Carried forward from the round-1 review (§12, all 10 still open — none
answered by this round's work, which was scoped to structural repair, not
policy decisions). Restating only the one this round's work bears on most
directly:

1. **T-3302's Human AC review** (`http://192.168.10.107:3002/review/T-3302`)
   — 0/0 Human ACs, all Agent ACs verified twice independently. This is not
   a judgment call, it is a one-click confirmation that the gate correctly
   requires anyway.
2. All 10 from the round-1 review §12 remain open (yardstick confirmation,
   BVP product-fate, `--skip-sovereignty` authorisation count, `.claude/settings.json`
   wiring approvals, Designer direction, arc closure count, review backlog
   count, govd/arc-013/Antigravity retire-or-complete, `fw gpu`/`fw deploy`
   re-homing, instrumentation-cost principle). Not re-derived this round —
   no new evidence bears on them.

## Gates that refused me, and what I did instead

| Gate | Where | What I did |
|---|---|---|
| Sovereignty gate (R-033), `owner: human` | `fw task update T-3302 --status work-completed` | Did not force. Parked the task, recorded the review URL, surfaced it above as the top-priority remaining item. |
| Focus-drift gate (T-1730) | `fw task update T-3302 ...` (focus was T-3411) | Used the documented `--switch-focus` bypass mechanism (logged Tier-2) — this is the sanctioned path for exactly this cross-task orchestration shape, not a workaround. |
| `fw bvp confirm` sovereignty gate | Attempting to move T-3412's proposed BVP score to confirmed | Cannot pass `--i-am-human`/`--from-watchtower` as an agent. Proceeded on the estimator's proposed score (the only "scored" available to me) rather than hand-waving a confirmed score myself. |
| G-020 scope-aware task gate | `fw bvp estimate T-3412` before ACs were real | Not a refusal of the unit of work — wrote real ACs first (the gate's intended remedy), then proceeded. |
| Focus-drift gate again | `git commit` after T-3412 closed (its own close clears focus) | Ran `fw context focus T-3411` (my actual driver task, still active) before committing — the correct state to commit under, not a bypass. |

No `--force`, no `--skip-*` flag, no env-var gate bypass was used anywhere
this round except the two logged Tier-2 mechanisms named above
(`--switch-focus` ×2), both of which are the gates' own documented escape
hatches for legitimate cross-task work, not routes around them.

## Cost-vs-estimate deltas worth feeding back into calibration

- **T-3412 actual cost vs. the estimator's implicit `effort` reading:** the
  estimator scored T-3412 with the same shape as T-3302 (D1=4 D2=4 D3=3 D4=2)
  before any code was written, i.e. purely off the task-body text. Actual
  work: root-cause trace (~30 min equivalent), fix at 4 call sites (not the 2
  originally scoped — scope grew by exactly 1 sibling bug, found by testing
  the first fix against live data rather than a synthetic case), 1 new test
  file (4 tests), repair of 2 live corrupted entries, 100+10 regression tests
  re-run clean. The estimator has no `cost_estimate:`/`blast_radius:` signal
  at all for this task (absent, not zero, per T-3068) — this is a second data
  point (after T-3366/T-3302 above) that cost estimation is structurally
  blind pre-close, which is a known, named gap (Sovereign Q10 in the round-1
  review), not a new finding.
- **"Verify, don't reconstruct" paid off concretely:** re-running T-3302's
  own pinned verification instead of trusting its checkmarks cost ~3 minutes
  (bats + doctor) and produced independent confirmation rather than a second
  layer of unverified trust on top of a prior session's self-report —
  directly the Mandate's Producer-not-judge principle, and cheap enough that
  there is no reason not to do it on every "looks done" task before handing
  it to a human.
