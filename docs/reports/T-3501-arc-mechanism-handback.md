# Handback — arc mechanism repair, 2026-09-26

**Trigger:** operator, verbatim — *"Please check messages, there's a number of
proposals from different agents on improving our ARC mechanism. Because it's faulty.
So let's work on that."*

**Inception:** T-3501 (GO given in chat; the record still wants an operator click at
`/inception/T-3501`). Full triage: `docs/reports/T-3501-arc-mechanism-faults.md`.

**State at handback:** `origin/bleeding-edge` at `8aba5732c`, **0 unpushed**,
verified by explicit ref check rather than exit code.

---

## 1. Where the proposals were, and what they said

`agent-chat-arc` offsets **1087**, **1090**, **1247** — three different agents. Not
in any `.context/` inbox, not in `framework:pickup`, not in the project inbox.

Worth recording because it cost most of the search: that topic is ~95% hourly
`vendored-arc heartbeat` noise, and "arc" in its name means TermLink's *chat arc*,
not AEF's arc mechanism. A sample of the twelve most recent messages returns only
heartbeats and reads as "nothing here."

| # | claim | from | status when checked |
|---|---|---|---|
| 1 | `fw arc tag` writes the deprecated tag, never `arc_id:` | 832 (their T-467) | **already fixed** here as T-2955, which credits them by id |
| 2 | reassignment guard blind to tag-only membership | 832 (their T-679) | **partial** — guard exists, reads only `arc_id:` |
| 3 | help text calls the *deprecated* form canonical | @1090 | **live** → fixed, T-3504 |
| 4 | 1 KB frontmatter read budget | @1247 | **live, worse than reported** → fixed, T-3502 |
| 5 | BVP arc ranking *drops* zero-member arcs | @1247 | **live** → fixed, T-3503 |

---

## 2. What shipped

| task | what | status |
|---|---|---|
| **T-3502** | S1 — removed the 1 KB frontmatter read budget | closed |
| **T-3503** | S3 — `fw bvp arcs` + `/bvp` union tag membership, stop dropping arcs | **partial-complete, `owner: human`** |
| **T-3504** | S4 — `fw arc help` no longer calls the deprecated form canonical | closed |
| **T-3507** | audit's completion-ratio check unions instead of falling back | closed |
| **T-3508** | restored the `fw arc close` gate to default-on | closed |
| **T-3509** | vendored-tree catch-up; unblocked the push | closed |
| **S2 (original)** | **not built — premise disproved.** OBS-545 | filed |

**Measured outcomes, before → after:**

| | before | after |
|---|---:|---:|
| membership markers past byte 1024 (invisible) | **56** | **0** |
| arcs undercounted by the reader | **17 of 29** | 0 |
| `orchestrator-rethink` members | 106 | **123** |
| phantom arc `orchestrator-reth` | present, 1 member | **gone** |
| arcs listed by `fw bvp arcs` | **16 of 20** | **20 of 20** |
| `fw bvp arcs` runtime | **>300 s (timeout)** | **18.8 s** |
| audit ratio, `arc-003` | 31/31 | **122/124** |
| audit ratio, `arc-007` | 1/1 | **70/70** |
| `test_arc_close_agent_gate.py` | 5 passed, **2 skipped** | **10 passed, 0 skipped** |

Tests added: **40** (12 + 11 + 7 + 10). Regression: 47 + 64 + 56 green, **0 skips**.
**Zero Tier-2 bypasses** across the whole session.

### The single most operator-relevant result

The four arcs `fw bvp arcs` was hiding were `horizon-axis-hardening`,
`onboarding-shape-detection`, `readme-first-run` and `ladder-trigger-producer` —
and **three of those four are among the five arcs the audit flags as stale.** Two
governance surfaces disagreed about the same arcs: one flagging them as needing
attention, the other omitting them from the table used to choose work. The value
ranking was hiding its own backlog.

---

## 3. The incident — a parked sovereignty gate went live

**This is the part that matters most, and it is not a code defect.**

At ~08:12 I parked **T-3487** on a Sovereign question. Its authorisation named
*"BVP and ARC **drivers**"*; the branch removes the gate on `fw arc **close**` — a
different verb and decision class — and the authorising quote itself ended
*"ask AEF agent."* I wrote out three options and did not decide.

Between my turns (13:33–17:07Z), another session:

- **T-3505** — made the two arc-close refusal tests `pytest.mark.skipif` on the new
  env var, clearing T-3487's two red tests
- **T-3506** — batch-merged four branches into `bleeding-edge` on the stated premise
  of *"four independently-reviewed branches"*

Result: the identity gate earned over **four repeat incidents** (T-1670/T-1671, one
an agent auto-closing `arc-003` and needing a revert) was **off by default**, and the
two tests that would have caught it were **skipped** — reporting as passes while
executing nothing (T-3217).

**No rule was broken.** I went looking for a bypass and there is none: no `--force`,
no `--skip-*`, no ignored refusal. T-3487 had an operator quote. T-3506 believed the
branches were reviewed. T-3505 made a red suite green. **Three locally-defensible
decisions across two sessions composed into a gate coming off.**

**Root cause:** parking lives in the **task** (`captured`, `horizon: later`, the
question in the body). A branch sweeper reads **topology**, which has no field for
*deliberately unlanded*. It could not have known.

**Remediated (T-3508):** default flipped from opt-in to opt-out —
`"${FW_REQUIRE_ARC_CLOSE_APPROVAL:-1}" != "0"`. The waiver and its name are kept, so
one line flips it back if the operator rules the wider authorisation correct. The
**authorised** `fw bvp confirm` half in `lib/bvp.sh` is untouched (empty diff). The
merge was **not** reverted, because that would drop the authorised half with the
unauthorised one. **T-3487 remains parked; the Sovereign question is unanswered.**

**Not remediated — and this is the real fix: OBS-547.** Flipping a default is
mitigation. Per this repo's own G-019, mitigation is not prevention. A sweeper can
land parked work again tomorrow.

Also cleaned up en route: the G-052 gate refused a commit because the batch merge had
**resurrected `.tasks/active/T-3485`** (pre-close) beside the closed copy, and a
background estimator then scored the resurrected task at 17:15Z as if it were live.

---

## 4. Sovereign questions and decisions, in priority order

1. **OBS-547 — give a parked branch a way to say so.** The prevention for §3.
   Suggested: have any batch-merge worker refuse a branch whose governing task is
   `captured`. An allowlist of mergeable branches is finite; inferring intent from
   topology is not possible.
2. **T-3487 — was removing the `fw arc close` gate authorised?** Unchanged and
   unanswered. Advisory: land the `bvp.sh` half, drop the `arc.sh` half.
3. **T-3471 — how should `blast_radius` be derived before close?** 85% of the corpus
   has no quadrant, so quadrant-based selection has no computed input. Candidates:
   parse body paths against fabric dependents; use `depended_by` counts; keep the
   T-shirt fallback but flag it. They differ enough to need a ruling.
4. **`/review/T-3503`** — does a 20-row `/bvp` table still read well? Layout only.
5. **`/inception/T-3501`** — the GO record for work already done.
6. **OBS-545, OBS-546** — two small filed fixes, deliberately not folded into
   approved slices.

---

## 5. Gates that refused, and what was done

**Zero bypasses.** No `--force`, `--skip-*`, `FW_ALLOW_*`, `FW_VENDOR_ALL`, or
`FW_SWITCH_FOCUS` anywhere in this session.

| gate | refused | response |
|---|---|---|
| **G-052** duplicate task id | the T-3507 commit | removed the merge-resurrected `active/T-3485` orphan after checking both copies |
| **P-011** verification | T-3503's close, on a blank Recommendation | wrote the advisory rather than `--skip-recommendation` |
| **T-1718** Evolution | T-3504, T-3507, T-3508 closes | wrote real entries; never `--skip-evolution` |
| **G-020** scope gate | every build task with placeholder ACs | wrote real ACs each time |
| **P-013** render surface | T-3503's close | added the `[REVIEW]` Human AC; task is now the operator's |
| **Pre-push self-vendor** | the push, twice | synced only clean committed source; left the foreign dirty file withheld (T-3509) |
| **G-067** inception questions | T-3501's exploration | filed IW-1…IW-4 before exploring |
| **OBS-250** task gate | `fw vendor self` and this handback after a close, **5×** | filed a task to run one command — the dead end CLAUDE.md names |

---

## 6. The pattern, stated once

Every defect repaired today was **invisible to the check that should have caught
it**, and in three cases the check reported PASS in the same run:

| the rail | why it could not see it |
|---|---|
| `fw watchtower current` | scope is `web/`; the change was in `lib/` (**OBS-544**) |
| audit's T-1881 duplication rail | pattern needs a literal `grep`; both offenders were Python (**OBS-546**) |
| the 39-test arc-membership suite | every fixture was short enough to pass a 1 KB read |
| arc-completion fixtures | every one had an *empty* cache, so the defective branch was unreachable |
| the arc-close gate's own tests | `skipif` — they never ran |
| the branch sweeper | topology cannot express "parked" (**OBS-547**) |

**Guards narrower than the thing they guard.** 832 named the general form for us in
their own report, and it is the most useful sentence anyone wrote this week:

> *"A defect that cannot change any output cannot be found by checking outputs —
> which is what verification normally does. A compatibility path needs its own
> assertion **on the producer**, because the consumer never complains."*

### Mistakes I made, kept on the record

1. **S2's premise was wrong twice** — `constituent_tasks:` is not written from a
   scan, and it is already deprecated with readers unioning it. Building the approved
   slice would have made the disease worse. Filed OBS-545 instead of executing it.
2. **My first impact table was inflated** — 30 arcs / 235 members, because I compared
   truncated *frontmatter* against a whole-file regex and leaked body prose, inventing
   arcs named `foo` and `alpha`. Real figures: 17 and 59.
3. **I wrote an unsatisfiable AC, twice** — `vendor self --check` reports clean can
   never pass while another worker holds a file dirty. Recorded on T-3495 this
   morning, then repeated on T-3509.
4. **My own verification line failed on a correct tree** — `grep -q
   "_HEAD_READ_BYTES"` matched the comment explaining the constant's removal. That is
   precisely the learning the @1090 peer had volunteered in the same thread hours
   earlier.

All four were caught by running a check, not by reasoning harder. **On this
subsystem, measurement overturned my reasoning more often than it confirmed it** —
the same conclusion the arc-006 run reached this morning, now on different code.

---

## 7. Not done, and why

- **832 and cashweb-integration-agent have had no reply.** 832 stated their state
  stays open until a triage verdict lands. The verdict exists — three of their five
  claims were live — but the operator withdrew the instruction to share it, so it
  was not sent.
- **De-duplicating arc membership.** Five implementations existed; three now
  delegate to `lib/arc_membership.py` (T-3503 ×2, T-3507). `lib/arc.sh` keeps thin
  shims to the shell helper. A single reader remains the right destination and
  deserves its own task.
- **The `/bvp` scoreless-arc row.** The CLI reports `no-members` /
  `members-unscored`; the web surface still skips such an arc, because rendering one
  needs a reviewed template change. Bounded to arcs with zero scorable members —
  currently none.
