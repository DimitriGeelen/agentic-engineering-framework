# VALUE REVIEW — Round 1 (T-3411, seq:T-3411) — whole repo, verified delta

- **Worker:** TermLink worker `seq-t3411-r1-review`, round 1 of 5 (Review → procAsFit sequence). No prior round exists for this sequence.
- **Role setup:** **self-judged — GATHERER and JUDGE were NOT separated in this round.** One worker (this one) ran Phases 0–5 in a single pass. Per protocol this drops every confidence level below by one from what it would otherwise be. Stated once here rather than repeated per row.
- **Human present:** no. All `[ASK]` gates below were answered on stated defaults and proceeded, per driver instruction. Phase 6 was **not** executed — this run stops at the end of Phase 5.
- **Governing method note:** a full, independently role-separated whole-repo value review (T-3370, dated 2026-09-16 — 6 days before this snapshot) already exists at `docs/reports/VALUE-REVIEW-whole-repo-2026-09-16*.md`: 11 files, ~3,400 lines, 6 GATHERERs (A–F) + 2 JUDGE passes, 65 finding rows, an explicit yardstick, and 10 unanswered Sovereign questions. Re-deriving that from zero in one self-judged pass would be lower-quality *and* would violate the ground rule "verify, don't reconstruct." This round instead: (1) treats T-3370 as the base classification, (2) independently re-verifies a representative, load-bearing sample of its claims against live state, (3) reports what changed in the 6-day gap, and (4) inventories the one genuinely new subsystem built since. All evidence for (2)–(4) was gathered fresh this round (see `r1-review-evidence.md`, rows E0–E20) — nothing here is copy-pasted from T-3370's numbers.

---

## 1. Yardstick

**PROPOSED-UNCONFIRMED** (no human present to confirm). Reused verbatim from T-3370's derivation, because nothing in the 6-day gap touched `policy/value-drivers.yaml` in substance (evidence E19) or answered T-3370 Sovereign Q1, which asks the operator to confirm or amend it:

> Make an AI agent's work traceable, reversible and human-sovereign by structural enforcement rather than agent discipline. It captures the record of what happened (Context Fabric), the map of what the work touches (Component Fabric), and forces a human decision at exactly the moments that need one. It *coordinates; it does not execute*.

Drivers (weights, from `policy/value-drivers.yaml`, E19): D1 Antifragility (9, protected), D2 Reliability (7, protected), F3/F1 (7 each, free — **T-3370 flagged this as internally contradictory**: the file's own header reasoning puts the top free driver below D2, but F3/F1 are weighted equal to it), F-RECALL (6, free), F2 (6, free), D3 Usability (5, protected), F-AUTONOMY (4, free), D4 Portability (3, protected).

**What I would have asked the human, had one been present:** (1) is the derived purpose above still right; (2) does the F3/F1=D2 weighting reflect a deliberate re-weighting or a stale header; (3) is value-scoring (BVP) still a live product bet given T-3370's finding of zero independent predictive signal. Proceeding on the stated default: treat the yardstick as valid for ranking purposes, flag every ranking that depends on the contested F3/F1 line.

## 2. Data availability map (confirmed on defaults) + snapshot windows

**PROPOSED-UNCONFIRMED**, reused and re-verified from T-3370's Data Layer A/B tally where the 6-day gap left it unchanged, with deltas called out. Full 51-source tally is in T-3370's evidence files (`datamap-A/B/C`); this round re-checked the specific rows below live rather than re-running the whole map:

| Source | Status (T-3370, 09-16) | Status now (this round, re-verified) | Evidence |
|---|---|---|---|
| Gate-bypass audit log | PARTIAL (exists, does not parse) | **PARTIAL, unchanged — same byte-835 UTF-8 error** | E5 |
| Hook-invocation counter | PARTIAL (write-only hooks absent from snapshot) | **EXISTS now for the write-only class** — T-3371's race fix landed in the gap | E6 |
| Nightly unit-suite report | EXISTS but self-contradictory (0 tests, exit 124, `failed_count:0`) | **EXISTS, same defect, new run (2026-09-22), unresolved** | E7 |
| Gate-evaluation event log (G1) | ABSENT (T-3370's #1-ranked gap) | **ABSENT, confirmed by fresh grep** | E13 |
| Per-verb usage counter (G2) | ABSENT (T-3370's #2-ranked gap) | **ABSENT, confirmed by fresh grep** | E13 |
| Arc register (closure state) | EXISTS (17 in-progress, 0 closed) | **EXISTS — 18 in-progress, 2 draft, 0 closed** (net +1, zero closures in 6 days) | E10 |
| Partial-complete task backlog | EXISTS via `date_finished` grep (265) | **EXISTS — 278**, backlog grew | E11 |
| Decision ledger | EXISTS (D-1…D-566 at review time) | **EXISTS — D-567…D-583 added**, none answer T-3370's Sovereign questions | E12 |
| Sidecar/peer-consult subsystem | **not in scope — did not exist yet** | **EXISTS**, new this round: source, tests, CLI, fabric cards, docs | E14–E17 |
| T-3411 driver mechanism | **not in scope — did not exist** | **EXISTS, in flight** — self-referential, unmeasurable from inside round 1 | E18 |

Data I cannot see that may exist: any TermLink-hub-side (out-of-band) delivery-failure log for the sidecar transport (Ground Rule: "a channel cannot report its own failures" — this round only exercised the sidecar's own read path, E17, which cannot attest to silent drops).

## 3. Role setup

Not separated (stated above). This caps every confidence rating below at one level lower than the corroboration pattern alone would justify — applied throughout the findings table.

## 4. Baseline

- `fw --version`: `1.6.744`, HEAD `8bd9b13ec` on `bleeding-edge` (E0).
- `fw doctor`: **did not complete within 60s** this run (E8) — new data point, not previously characterized as a latency issue by T-3370.
- `fw audit` (latest cron-run snapshot, 2026-09-21T23:02:44Z): 33 PASS / 13 WARN / 0 FAIL (E9). Notable WARNs: 4 stale arcs, 185/367 GO-recorded inceptions with unpropagated scope, fabric drift (120 no-edge cards, 774 unwatched, 1 uncarded file), 18 branch-hygiene findings, unit suite undetermined, continuous-run loop stopped.
- Unit suite: `bats` 398 tests / 13 failed / 10 skipped, timed out (exit 124); `pytest` 208 files / **0 tests collected**, timed out, `failed_count: 0` (E7) — same defect class as T-3370 A1, unresolved 6 days later.
- Sidecar subsystem test suite (new, not part of the standard baseline yet): 28/28 passed (E15).

## 5. Summary

**Counts, this round's findings only** (T-3370's 65 rows are carried forward unmodified except where re-verification changed status — see §6 carry-forward table): 1 CLOSED (was INVESTIGATE, now resolved with fresh evidence), 2 CONFIRMED-STILL-OPEN (re-verified, unchanged), 3 NEW (ADD/INVESTIGATE on the sidecar and driver subsystems), 1 CONTRADICTION flagged for re-check (CLAUDE.md R18 citation).

**Top 3 by axis, this round:**

- **DELETE:** none proposed this round. T-3370's operator ruling (D-566) already emptied this axis to 3 narrow, non-capability-removing rows (a one-shot landing script, a deprecated wizard's dead alias, and run residue) — nothing in the 6-day gap changes that; carried forward unchanged.
- **REFACTOR:** none newly proposed this round (T-3370's 22 REFACTOR rows, R1–R22, stand unchanged — no evidence found that any landed in the gap).
- **ADD:** (1) **repair the pytest leg of the nightly unit suite** — still reports `failed_count: 0` on 0 collected tests, 6 days after T-3370 A1 flagged the identical shape (this round's E7 is fresh evidence, not a repeat of the old citation); (2) **repair the gate-bypass-log encoding** — identical UTF-8 failure at the same byte offset as 6 days ago (E5); (3) **instrument the sidecar send/delivery path** — 28/28 unit tests pass and the CLI is wired, but zero cross-agent exercise exists in any log this round could find (D-reading: unmeasured, E14–E17).

## 6. Findings table (delta only — see T-3370 for the base 65 rows, carried forward)

| ID | Item | Location | Class | Non-use reading | Evidence | Counter-evidence | Confidence | Proposal | Size | Reversible? | Risk if wrong | Expected effect |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Δ1 | I1 (T-3370): do write-only PreToolUse hooks fire? | `.context/working/.hook-counter` | **CLOSE (was INVESTIGATE)** | resolved: **A→fixed** | E6 — 10 named hooks now show sustained counts 141–536, vs. zero in both T-3370 snapshots. Corroborated independently by the T-3371/T-3372 commit trail (E3) that a lost-update race was root-caused and fixed. | Self-judged this round (no separate JUDGE); T-3371's own regression test (1600/1600 vs 17/1600 before, per commit message) is a second, independent corroboration | MEDIUM (self-judged caps it; would be HIGH with role separation — two independent measured sources agree) | Mark T-3370 I1 **resolved**, remove from the open INVESTIGATE list, retain the underlying repair (T-3371/T-3372) as the closure record | S (already done) | N/A — already landed | If wrong: the counter could still be lying in a new way; a repeat single-edit probe would catch it | Confirmed: next audit run should stop citing hook-write-blindness as a live risk |
| Δ2 | A1 (T-3370): nightly pytest leg reports `failed_count:0` on 0 tests | `.context/audits/unit-suite/LATEST.yaml` | **CONFIRM (still ADD, unresolved)** | A — broken, wanted | E7, fresh run dated 2026-09-22, same shape as the 09-16 citation | None found; no task references repairing this since T-3370 | MEDIUM (single fresh observation, self-judged) | Unchanged from T-3370 A1: give the pytest leg a budget it can finish in; treat 0-collected as a failure, not a pass-shaped non-event | M | Revert | A longer suite budget collides with other cron jobs | Within 14 days: `pytest tests > 0` on a nightly run, or a triaged red |
| Δ3 | A2 (T-3370): gate-bypass-log does not parse | `.context/working/.gate-bypass-log.yaml` | **CONFIRM (still ADD, unresolved)** | A — broken, wanted | E5, identical error at the identical byte offset (835), 6 days apart | None found | MEDIUM (one fresh read, same signature as T-3370's citation — corroborating, not independent) | Unchanged from T-3370 A2: fix the writer's encoding, repair the file, add a parse check to the audit | S | Revert | None — pure repair | `yaml.safe_load` succeeds; audit fails loud if it stops parsing again |
| Δ4 | NEW: sidecar/peer-consult subsystem (arc-011, T-3395–T-3409) | `lib/sidecar/*`, `lib/sidecar_cli.py`, `agents/context/sidecar-inbox.sh` | **ADD (instrumentation) / INVESTIGATE (delivery)** | **D — unmeasured** | E14 (built, fabric-registered, documented), E15 (28/28 tests pass), E16 (CLI wired, reachable), E17 (one live exercise this session — read path only, empty inbox) | Tests passing is evidence of correctness-in-isolation, not of production delivery; no send-side or cross-agent exercise found in any log | LOW (self-judged, n=1 live data point, D-reading explicitly caps confidence per protocol — "no data is not zero") | Add an out-of-band delivery observer or at minimum a send/receive counter distinct from the tests, before relying on this channel for governance-relevant consults (per Ground Rule: "a channel cannot report its own failures") | S–M | Revert (additive instrumentation) | None if not built; if never built, silent consult drops are indistinguishable from "nothing to say" | A future round of this same sequence that DOES receive a consult would be the first real signal — record whether it happens |
| Δ5 | NEW: T-3411 driver mechanism (this sequence itself) | `.tasks/active/T-3411-*.md`, `seq:T-3411` TermLink topic | **INVESTIGATE** | **D — unmeasured, self-referential** | E18 — task is `started-work`, round 1 is this very report; rounds 2–5, the `--dry-run` behaviour, and the "missing result file = failed step" refusal are asserted in the task's ACs but not observable from inside round 1 | None — round 1 completing and writing both required files (this file + evidence) is itself one data point that the "worker writes to repo path, driver reads it" half of the mechanism works | LOW (n=1, cannot see the driver's own behaviour from inside a dispatched worker) | No action — this is a note for round 2+ or for whoever inspects `seq:T-3411` after the sequence completes: check whether all 5 rounds ran, in order, each fed the prior result, per T-3411's own ACs | N/A | N/A | A driver bug (e.g., not actually feeding forward) would be invisible to any single round | Round 5's Review prompt, if it correctly received rounds 1–4 context, is the check |
| Δ6 | CONTRADICTION-CHECK: T-3370 R18 cited `CLAUDE.md:459 → nonexistent zzz-default.md` | `zzz-default.md` (repo root) | **INVESTIGATE (not resolved this round)** | n/a | E20 — `zzz-default.md` **exists** at repo root per this round's own directory listing | T-3370's evidence-D citation for this specific line was not independently re-read this round (out of budget); the file existing now doesn't prove the CLAUDE.md line was ever wrong, or that it's since been fixed | LOW (one-sided check, other side not verified) | Re-check CLAUDE.md's actual line 459 (or current line, since the file changes) against `zzz-default.md`'s existence before treating R18 as resolved or still-open | S | N/A (read-only check) | Treating this as resolved without checking the actual line could hide a real dead reference elsewhere in the same doc | A direct read of the cited line either confirms drift or shows it was already fixed |

## 7. KEEP list (names only)

Everything from T-3370's 65-row classification not listed as DELETE/REFACTOR/ADD/INVESTIGATE there (i.e., "judged KEEP by default, with no finding" per T-3370 §11) is unchanged and carried forward. New KEEP candidate this round: **sidecar CLI + core send/inbox/outbox/delivery modules** (tested 28/28, wired, fabric-registered) — KEEP the code; the *delivery-observability gap* is the open item (Δ4), not the code itself.

## 8. INVESTIGATE list + data needed

Carrying forward all of T-3370 §8's 15 open INVESTIGATE rows (I2, I3, I7–I10, I12–I19 in that numbering) unchanged — none were touched by the 6-day gap's git activity per this round's checks. New this round:

- **Δ4** — sidecar delivery observability. Data needed: an out-of-band (hub-side or TermLink-repo-owned) send/receive/drop counter, distinct from the sidecar's own unit tests.
- **Δ5** — T-3411 driver correctness across all 5 rounds. Data needed: the `seq:T-3411` TermLink topic history, read after round 5 completes (or by any agent with topic access mid-sequence).
- **Δ6** — CLAUDE.md:459 / `zzz-default.md` drift status. Data needed: one direct read of the current cited line.

## 9. Data gaps that capped confidence (ADD candidates in their own right)

Unchanged from T-3370 §9 (G1–G12) — all 12 remain open; G1 (gate-evaluation events) and G2 (per-verb usage counter) re-confirmed ABSENT this round (E13) and are still the two highest-unlock items per T-3370's own ranking. New gap surfaced this round:

- **G13 (new): sidecar delivery observer.** No hub-side or independent record of consult send/receive/drop exists (Δ4). Ranked here because it is the sidecar-subsystem instance of the same class G11 (TermLink bus drop/reject observer) already named for the older `fw bus`/`fw pickup` channels — this is evidence the class recurs in new code, not a one-off.

## 10. Contradictions (docs vs code, purpose vs reality, source vs source)

Carrying forward T-3370 §10's 12 rows unchanged (all still open except where §6 above marks a re-verification). Added:

- **13.** T-3370 R18 cited a dead CLAUDE.md reference to `zzz-default.md`; this round found the file exists at repo root (E20) but did not re-read the actual cited line to confirm whether the doc-side drift was fixed, never real, or has moved. **Status: unresolved, flagged (Δ6).**

## 11. Not reviewed

Same broad exclusions T-3370 §11 named (`tools/`, `scripts/`, `deploy/`, `install.sh`, `vendor/`, `.github/`, `web/` blueprint/recall-engine logic, security posture, T-2621 conformance-rail internals, per-verb churn, git-hooks contents) — none of these saw material re-derivation this round either; this round's fresh work was scoped to verification-critical spot-checks (§2, §4) plus the two subsystems that are genuinely new since 09-16 (sidecar, T-3411 driver). Also not reviewed this round: the full 727-file `docs/reports/` corpus beyond the T-3370 artifacts themselves; the 3,398-task ledger beyond the two aggregate counts pulled (E1, E11).

## 12. Sovereign questions for the operator (carried forward, none answered in the gap)

All 10 of T-3370 §12's Sovereign questions remain **fully open** — the decision ledger scan (E12, D-567…D-583) found zero decisions addressing any of them:

1. Confirm or amend the yardstick (F3/F1=D2 weighting contradiction, §1 above).
2. Is value scoring (BVP) still a product capability, given 0 human confirmations and no independent predictive signal (T-3370 finding, unre-verified this round but nothing contradicts it)?
3. Were the 172 `--skip-sovereignty` bypasses operator-authorised?
4. Approve or refuse, individually, the named `.claude/settings.json` wiring changes (4 unwired gates + 1 reversal of a deliberate prior decision).
5. Designer direction: executable workflows, or documentation/modelling only?
6. Arc closure: now **18** in-progress arcs (was 17), still **0** ever closed or abandoned (E10) — the gap widened, not narrowed.
7. Review backlog: now **278** active tasks carry `date_finished` awaiting Human ACs (was 265) — growing, not draining (E11). **T-3370 itself is one of these 278** — its own Human AC is still unticked (E4).
8. Complete-or-retire calls on govd/arc-013, arc-020, Antigravity.
9. Re-home or keep host-specific ops verbs (`fw gpu`, `fw deploy`) inside a portable framework.
10. Approve the instrumentation-cost principle before G1/G2 (still both ABSENT, E13) are built.

**My recommendation, stated rather than left blank per CLAUDE.md §Presenting Work for Human Review:** none of these are mine to decide, but if forced to rank for the operator's attention, **Q7 and Q6 deserve first look** — they are not judgment calls requiring deep context, they are counts (278 tasks, 18 arcs) that only grow while unanswered, and every day they go unaddressed is itself the cost this review is trying to make visible. Q1 (yardstick) gates the confidence of every other ranking in both this report and T-3370, so it is cheap to answer and unlocks the most.

---

**Stop marker:** Phase 6 (execute approved items) is **not** run. No task was filed, no file outside `docs/reports/SEQ-T3411/` was modified, no gate was bypassed. Sidecar inbox checked at start and immediately before this write — empty both times (`no pending consults on sidecar:seq-t3411-r1-review`).
