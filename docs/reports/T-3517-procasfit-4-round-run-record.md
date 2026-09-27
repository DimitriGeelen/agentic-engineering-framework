# T-3517 — run record: 4-round sequential procAsFit via TermLink

**Operator instruction, 2026-09-27:** run the procAsFit mandate four times
sequentially through TermLink, each round acting on the previous round's result,
and *"Do not execute the prompts yourself outside this sequence."*

**Orchestrator's role:** dispatch, wait, verify, harvest, feed forward. No round's
work was executed by the orchestrating session. What the orchestrator *did* do
directly is listed in §6, because the mandate requires that to be recorded rather
than assumed.

---

## 1. Per-round record

| round | worker | session | start (UTC) | end (UTC) | verdict | turns | new tokens | cache read | handback |
|---|---|---|---|---|---|---:|---:|---:|---|
| 1 | `pf0927-r1` | `7d3395a1-e7d` | 10:50:16 | 11:57:48 | success | 1* | 310,743 | 25,187,338 | 17,971 B |
| 2 | `pf0927-r2` | `f30f548e-7bf` | 13:55:50 | 14:15:12 | success | 12* | 278,622 | 16,176,772 | 20,862 B |
| 3 | `pf0927-r3` | `8ec753c5-19a` | 14:14:22 | 14:49:15 | success | 127 | 393,038 | 25,469,282 | 24,351 B |
| 4 | `pf0927-r4` | `c20e03fc-d71` | 14:52:21 | 15:03:27 | success | 41 | 142,988 | 4,349,237 | 13,455 B |
| | | | | | | | **1,125,391** | **71,182,629** | |

\* `num_turns` is read from the LAST result line, and rounds 1-2 emitted several —
see §3. The figure understates those rounds.

Tokens are from each stream's `modelUsage`, via `lib/dispatch_tokens.py` (T-3519,
built mid-run on operator instruction to report tokens rather than dollars). Cache
read is listed separately because it is ~20-60× the new-token figure and the cheapest
per token; one combined total would misrepresent every row.

**What each round advanced:**

- **R1** — closed **T-3506** (four-branch merge, left `started-work` with all ACs
  checked). Recorded the baseline. Independently reproduced the corpus-wide BVP
  flat-tie. Refused to close T-3481 because the evidence lives in an orchestrator's
  tool history no worker can read — correctly called that self-certification.
- **R2** — advanced **T-1820** to human review. Found via `fw review-queue` that
  **16 `owner: human` tasks have zero Human criteria and all Agent ACs done**, each
  with a ready-made close command, and **324 tasks total awaiting review**. Ran none
  of them: *"the ownership field itself is the sovereignty signal."*
- **R3** — closed **T-3516** (from the operator-approved queue): added
  `ctl-arc-membership-python-import`, a sibling to the T-1881 shell-grep rail that
  catches Python reinventions of arc-membership scanning. Strips comments via
  `tokenize` first, which avoids the T-3502 false-positive class. Also found that
  **OBS-545/546 were claimed as "filed" in T-3503 but existed in no register** —
  register-first-fix-second claimed, not done — and registered both.
- **R4** — closed **T-3514** (from the queue): `fw bvp arcs` slug column is now
  dynamically sized, fixing the 2-of-20 row misalignment.

## 2. Sequencing — ONE VIOLATION, recorded not waived

The AC required round N+1 not to start until round N terminated, *"verified by
comparing each round's start timestamp against the previous round's end, not by
assuming the wait worked."* The check found a violation:

| boundary | result |
|---|---|
| r1 → r2 | clean (118 min gap) |
| **r2 → r3** | **OVERLAP — r3 started 14:14:22Z, r2 worked until 14:15:12Z (~50 s)** |
| r3 → r4 | clean (186 s gap) |

**T-3517's strict-sequencing AC is therefore NOT met and is left unticked.**

Collateral, measured: round 2 committed `56c05d450` — *"live reproduction of T-3297
concurrent-push contention"* — inside exactly that window. The concurrency the
orchestrator introduced reproduced a known concurrency defect.

## 3. Root cause: a result line is not a completion signal

`pf0927-r1` emitted **eleven** `{"type":"result"}` lines, all `subtype: success`.
`pf0927-r2` emitted two. A worker that starts background tasks yields a result each
time it is re-invoked — the stream shows `background_tasks_changed` / `task_updated`
/ `task_notification` / `init` immediately before each continuation.

So **"first result line" means "first yield", not "finished"**, and the orchestrator's
wait fired early on round 2.

The two obvious signals are both wrong in opposite directions:

| signal | failure |
|---|---|
| `run.sh` process exit | `run.sh` outlives the work — the watchdog is `(sleep $TIMEOUT && kill …)`, so it always waits the full timeout. Cost ~1 h 31 m of dead waiting on round 1 |
| first `{"type":"result"}` | fires on the first yield, not on completion. Cost: the r2/r3 overlap |

Candidates not yet verified: the LAST result line plus a quiet period; the dispatch
verb's own `close_state` file; or an explicit worker-written done sentinel. Named
rather than asserted — filed as **OBS-557**.

## 4. A retracted finding

**OBS-556 is wrong and OBS-557 corrects it.** OBS-556 recorded that round 2 "wrote
its handback but did not commit it" and attributed it to per-round variance in
instruction-following. The worker had simply not finished: it committed its own
addendum at 14:14:55Z, *after* the orchestrator's 14:13:29Z "harvest" commit. The
artifact was untracked because it was still being written. The orchestrator's
premature completion detection caused both the false finding and the overlap.

## 5. Sovereign questions, unresolved, in priority order

1. **The BVP v1 heuristic has no differentiating signal for the structural/hygiene
   task family.** Independently reproduced **four** times now with identical numbers
   (T-3481 round 3 → r1 → r2 → r3). Quadrant-based selection — which the mandate
   specifies — has no usable input: `--quadrant hv-lc` and `hv-hc` return zero
   because no task carries a *confirmed* `bvp_scores:`, and `--include-proposed`
   collapses ≥17 tasks onto one tie at BVP 108 / norm 0.40 / cost 3.6.
2. **Should the standalone hygiene backlog get an accumulator arc**, or is arc-less
   maintenance-by-design intended? Unchanged across all four rounds.
3. **The narrower inception-vs-build `voi_score`/BVP flatness framing** — still
   unfiled after three rounds named it. Round 2's remark is worth quoting: *"a second
   round running without filing it is itself worth the operator's attention."*
4. **The 324-task human-review backlog**, 16 of which are structurally ready to
   close. Is there a sanctioned way for an agent to *batch-surface* (not
   batch-execute) that subset?

## 6. What the orchestrator did directly, and why

The mandate permits working directly *with a recorded reason*. Recorded:

- Dispatch, wait, verify, harvest for all four rounds.
- **Verified each round's claims against the tree** rather than its narrative —
  T-3506's closure, `7c0621df7`'s presence on `origin/bleeding-edge`, T-3516's diff,
  T-3514's status, OBS-545/546's register entries. One verification of mine was
  wrong (I read the inbox, not the concerns register) and round 3 was right.
- **Built T-3519 mid-run** on direct operator instruction (report tokens, not
  dollars, embedded in code). This is orchestrator work, not a round's work, and is
  its own task with its own ACs.
- **Committed round 2's handback** at 14:13:29Z — prematurely, see §4.
- Pushed between rounds, never during one.

## 7. Auditability

Every figure here is traceable: token rollups from each stream's `modelUsage` via
`lib/dispatch_tokens.py`; timestamps from the streams' own event records; task
statuses from `.tasks/`; commit claims from `git branch -r --contains`. The
sequencing violation in §2 was found by running the check the AC specified, not by
inspection — and it is reported as a failure rather than reconciled away.
