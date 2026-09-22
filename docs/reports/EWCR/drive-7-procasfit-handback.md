# EWCR drive 7 — procAsFit handback (arc-019, round 2)

**Task:** T-3439 · **Arc:** arc-019 `ewcr-arc0-contract-evidence`
**Mandate:** `tools/prompt-sequence/02-procasfit.prompt.md` (T-3411), round 2, arc level pre-decided
**Operator instruction (2026-09-22, given twice — 17:15Z and 19:35Z, verbatim):** *"the work on arc 019 use the procasfit prompt"*
**Run:** 2026-09-22, TermLink worker `t3439-ewcr-procasfit-r2`
**Fed by:** `docs/reports/EWCR/drive-6-procasfit-handback.md` (T-3437) — read in full at run start, treated as evidence, not as a worklist and not as approval.
**Predecessors:** T-3381 (drive 2), T-3384 (3), T-3392 (4), T-3395 (5), T-3437 (6)

Every claim below is traceable to a command run in this session or to a verb-gated
state change made by it. Where a number is quoted from a document rather than
re-measured, it says so.

**The headline of this round is not the fix.** T-3438 closed clean and took nine
minutes of execution. The finding that matters is in §4: **drive 6's clause-2
conclusion rested on a search method that structurally could not see the answer**, and
the answer has been sitting in an unread AEF mailbox. S1 changes shape.

---

## 1. Selection, stated before execution

Per the Mandate, selection is top-down and each level gates the one below.

### Unit 1 — T-3438

| Level | Choice | Why this and not the next candidate |
|---|---|---|
| **Objective** | arc-019's headline mechanic — *"operator opens the Arc 0 page, picks any pilot invariant or review finding, and sees it traced to a versioned contract, a refusal scenario, a responsible component, and an executable verification fence **they can run**"* | The emphasis is the point: T-3438 is the case where the fence could **not** be run. Fixing it advances the headline mechanic directly rather than adjacently. |
| **Arc** | arc-019, **Sovereign-selected** | Not the worker's choice. The operator named it, twice. Not re-opened. |
| **Task** | **T-3438** | The arc's only executable member at round start. T-3389 is `captured/later` and blocked; T-3147 is a human-owned anchor awaiting a Sovereign finalisation; T-3439 is the drive itself. There was no second candidate to rank against. |
| **Quadrant** | **Q1 by the within-arc reading** — see below | |

**Which quadrant reading applies, and why.** The Mandate's level 3 reads *"Within the
chosen arc, select by BVP quadrant"*: the arc **gates** the task level, so the candidate
set is the arc's members, not the repository. Applying that reading, T-3438 is the
highest-value executable member of arc-019 because it is the only one. Both numbers are
reported rather than one suppressed:

| Reading | T-3438's standing | Consequence if applied alone |
|---|---|---|
| **Within-arc** (applied) | Only executable member → work it | The arc's one red line gets fixed |
| **Whole-repo** | BVP **42**, rank **178 of 192**, below the live median | Nothing in arc-019 is eligible; the round ends at §1 having done nothing |

The whole-repo reading is not obviously wrong — the Mandate does say low-value work is
out of scope regardless of cheapness. It is rejected here because it makes level 2
(arc selection) inoperative: an arc the Sovereign explicitly chose would yield zero
eligible work on a corpus-wide percentile its own members were never ranked for.

**No machine quadrant is asserted.** `fw bvp --include-proposed` reports COST `-` for
T-3438 (and for 165 of 192 tasks, 86% — unchanged from drive 6). With cost unmeasured,
Q1-vs-Q2 is not determinable from the corpus, and inventing one is the failure this
section exists to prevent. "Q1" above is a stated judgement about within-arc value and
bounded single-file scope, not a corpus fact.

**Score from the estimator, not from this worker.** `bin/fw bvp estimate T-3438` re-run
this drive: `D1=4 D2=0 D3=0 D4=0 F-RECALL=0 F-AUTONOMY=0 F3=0 F1=0 F2=1
[no-change-since-last]`. Drive 6 §C2 already recorded that this rubric under-scores the
shape *"a green check on a completed task went red"*. **This worker did not rescore it**
— producer-not-judge — and the calibration finding is re-fed in §8 rather than corrected
in place.

### Unit 2 — T-3439 AC A3 (the S1 re-check)

| Level | Choice | Why |
|---|---|---|
| Objective / Arc | as above | unchanged |
| **Task** | **T-3439** itself | The clause-2 re-check is an activity of *this drive's* AC A3. It is deliberately **not** run under T-3389: starting T-3389 would assert its blocking input had arrived, which was the very thing under test. |
| **Quadrant** | n/a — AC-scoped activity, not a task selection | The Mandate scopes activity to the ACs; A3 requires this and nothing beyond it. |

---

## 2. Objectives advanced — delta against drive 6 §2

Drive 6's §2 table, re-measured, with this round's column added. "Drive 6" values are
that document's; "drive 7" values are measured this session.

| Measure | Drive 6 (17:10Z→18:28Z) | **Drive 7 (19:35Z→20:10Z)** | Δ this round |
|---|---|---|---|
| arc-019 members | 19 | **20** | +1 (T-3439) |
| …work-completed | 16 | **18** | **+2 closed** (T-3437, T-3438) |
| §3 register rows with a recorded AEF decision | 3 (Q-01, Q-02, Q-07-AEF) | **3** | 0 — no new decision was landable without a Sovereign ruling |
| §3 rows dispositioned in writing | 15 of 15 | 15 of 15 | 0 (re-affirmed, not re-done) |
| Fabric `Unknown` cards | 0 of **1332** | **0 of 1333** | card total +1; Unknown still 0 |
| **T-3394 pinned verification line 4** | **RED (rc=2)** | **GREEN (rc=0)** | **fixed** — the round's concrete deliverable |
| T-3394 verification block, all lines | 5 of 6 (line 4 red) | **6 of 6** | +1 |
| Open EWCR structural defects registered | +1 (OBS-476) | **+1 (OBS-482)** | +1 |
| Clause-2 search surfaces covered | 6 | **8** (+DM rail, +search-coverage control) | **+2, and one of them found the answer** |

**The substantive advance is not T-3438.** It is §4: the clause-2 question has had a
substantive 832 answer on the record, in an AEF mailbox, and every drive from 2 to 6
reported it absent because none of the six searches could reach a DM channel. The
single highest-value output of this round is that correction.

Secondary: T-3438 restores an executable fence. That matters beyond its own scope —
arc-019's headline mechanic promises the operator *a verification fence they can run*,
and for three days the flagship fence exited 2 on a healthy corpus.

---

## 3. Unit 1 — T-3438, closed

**Selected, executed, verified, closed through the verb.** No gate refused the close and
no bypass flag was used.

**What the defect was.** The guard read the **wrong number**. Its question is *"did this
scan look at anything?"*; the number that answers it is the **Fabric card total**. It
read the **Unknown total** instead — a *result* of the scan, not evidence the scan
happened. The two coincide only while the corpus holds some Unknown cards, which the
refusal text asserted as a standing fact (*"`fw fabric overview` reports a non-zero
Unknown subsystem"*). When the corpus cleared, a cleared fence and a broken predicate
became the same observation and the guard resolved the ambiguity in the direction that
is wrong on a success. Mutable-corpus-anchor class (T-3326), in a file whose own header
argues the opposite case correctly eighty lines earlier.

**What shipped** (commit `8590c21c6`):

- REFUSED (exit 2) now means **zero Fabric cards enumerated**, and nothing else — a
  property read at run time on every invocation, so there is no stored number to go stale.
- A cleared fence **completes** (exit 0) and prints `MEASURED CLEAR` with the
  enumerated-card total as the evidence the scan was not empty.
- `share()` returns an explicit `n/a — 0 Unknown cards to apportion` rather than dividing
  by a zero denominator.
- The stale premise is gone from the refusal text **and** from the module docstring —
  the docstring now says the fence's state is *the output of a run, never a premise baked
  into this file*, and lists the drift (512 → 519 → 544 → 0) as history rather than as an
  invariant.
- `arc-0-clause-1-attestation.md` reconciled (AC A5): the 2026-09-19 block is date-stamped
  as the capture it was, the drift table gains the `544 → 0` row at commit `d9841353f`,
  a new section records the move with the tool-refusal story, and the *"repo-wide 544
  Unknown"* bullet no longer asserts a number that has moved.

**Checks that closed each criterion** — all run, all recorded:

| AC | Check | Result |
|---|---|---|
| A1 | `python3 tools/ewcr-arc0-unknown-overlap.py` → `Intersection with CORE write set` | **rc=0** (was rc=2) |
| A1 | enumerated-card total printed | **rc=0** — `Fabric cards enumerated : 1333` |
| A2 | `! grep -q 'reports a non-zero Unknown subsystem' tools/…` | **rc=0** |
| A3 | empty-directory control still exits 2 | **rc=0** — `REFUSED: enumerated 0 Fabric cards.` |
| A4 | the attestation's literal reproduction command, both tools chained | **rc=0** |
| A5 | attestation records the 544 → 0 move | **rc=0** |

And the thing that made this a task at all, re-run against the *completed* task's own
block:

```
T-3394 line 1 rc=0   line 2 rc=0   line 3 rc=0
T-3394 line 4 rc=0   <-- rc=2 before this change, measured at run start
T-3394 line 5 rc=0   line 6 rc=0
```

**The generalisable finding, recorded in T-3438's RCA and re-surfaced as S10 below:**
*a verification line pinned on a `completed/` task is never re-run by the framework.*
P-011 runs a task's `## Verification` block at the close transition and never again.
T-3394 was green at close and red three days later; the only reason anyone knows is that
drive 6 chose to re-run a cited command instead of citing it. That is a detection gap
wider than this bug, and it is surfaced rather than fixed — "re-run completed tasks'
verification blocks on a schedule" is a governance change with a cost model, not a
one-file repair.

**Reviewer output, recorded not suppressed.** The close ran `fw reviewer`: verdict
`Needs Human: yes`, findings none, **1 Layer-1 escalation — `destructive-action` (high),
matched `rm -rf`**. That is `rm -rf "$d"` where `d=$(mktemp -d)`, the teardown of the
empty-directory control leg. The match is on the literal string, not on the target. The
line was **left as written** rather than reworded to dodge the scanner, because a control
that tears down its own temp directory is the correct shape and hiding it from the
detector would be the worse outcome. Flagged here so the operator sees it.

---

## 4. Unit 2 — S1 was re-checked, and it MOVED

AC A3 required the clause-2 artefacts to be searched for again rather than presumed
absent, across disk, `xfer-832-*`, `sidecar:832-Workflow-designer`, **and the 832 DM
rail**. Drive 6 ran six searches over the first three surfaces. The DM rail is the
surface it did not run, and it is the one that had the answer.

### 4.1 The searches drive 6 ran — all still negative

| Surface | Command | Result (drive 7) | vs drive 6 |
|---|---|---|---|
| Repo research dir | `ls docs/research/executable-workflow/` | 8 files + `contracts/`. **No `reviews/` directory.** | unchanged |
| New files since drive 6 | `find docs/research -newermt "2026-09-22 18:00"` | 1 file — this drive's own attestation edit | unchanged |
| Whole repo | `grep -rliE "deepseek\|mistral" docs/ .context/` | Hits only in documents that *name* the reviews | unchanged |
| Transfer channel | `termlink channel info xfer-832-bpmn` | **Posts: 0, Senders: 0** | unchanged |
| 832 sidecar | `termlink channel state sidecar:832-Workflow-designer` | 1 post — our outbound branch-topology reply. Nothing inbound. | unchanged |
| Hub-wide | `termlink agent search` × 5 terms (DeepSeek, Mistral, refusal matrix, confused deputy, TOCTOU) | 1002 envelopes scanned, **0 posts** | unchanged |
| Pending transfers | `termlink inbox list cacc73ea32b121dd/999-…` | **No pending transfers** | unchanged |

On these seven surfaces, drive 6's conclusion reproduces exactly. Had this drive stopped
here it would have reported "unchanged" with a clean conscience.

### 4.2 The surface drive 6 did not search

```
$ termlink channel state dm:3bba15e681b3a078:d1993c2c3ec44c94
```

**123 posts.** Offset **[2]**, verbatim:

> T-047 refinement for EWCR-ARC0-ATTEST-832: **DeepSeek and Mistral raw reviews DO exist
> in the governed 0503 dossier; what is missing is their consolidated AEF-owned
> per-finding disposition tables.** Verified sha256: DeepSeek
> `docs/reports/T-032-deepseek-review-response.md` =
> `4dae4098b2602b2794525292e1aa3053e0c486b23a67d9c3292ce80dc3a4d8a9`; Mistral
> `docs/reports/T-032-mistral-review-response.md` =
> `0eecb8af7be56ba045581167ef66b73fd9d2aa17fcd241f84defc0e7d17bfb0e`. Local evidence
> record: `docs/reports/T-047-aef-refusal-matrix-disposition.md`. **Smallest AEF-owned
> task requested:** pin all four reviews; produce D/M tables or explicit
> operator-approved exclusions; map each blocker to contract clause, owner, executable
> refusal test; record R7 source-of-truth ruling; publish governed path/full sha256.

Offset **[3]** adds that the Designer's response packet — *nine raw-byte sha256 values,
clean tree, commit `a9b3a084becf158fa00026180e369e1639b19f45`* — is at `agent-chat-arc`
@737, and asks AEF to answer `artifact-required` with a supported transport, or return
receiver paths plus an independent full-hash read-back and a poisoned-copy failure.

Offset **[7]**, from 832, diagnoses why none of this ever landed:

> session.discover resolves `3bba15e681b3a078` to `framework-agent-systemd` … **this
> mailbox is addressed correctly and is live by heartbeat, but no agent process is
> consuming it. That is the whole explanation for four unanswered DMs — not refusal, not
> absence, just no reader.**

### 4.3 Why the six searches could not have found it — measured, not inferred

A control, because "the search missed it" is a claim and claims get checked:

```
$ termlink agent search "consolidated AEF-owned per-finding"
# agent search | query=consolidated AEF-owned per-finding | scanned=1002 envelopes | n=20
(no posts found in window)
```

That phrase is **verbatim in the DM at offset [2]**. `termlink agent search` scans
`agent-chat-arc` envelopes and **does not cover DM channels**. So drive 6's "hub-wide"
row was not hub-wide, and the six searches were not six independent negatives — they were
six negatives sharing one blind spot. The same hole hides the @737 packet: searching
`a9b3a084` and `raw-byte sha256` also returns 0.

Registered as **OBS-482** (register first, fix second). The homing call is deliberate: the
half that is ours is the *evidence discipline* — calling a search "hub-wide" without
establishing its coverage. The half that is TermLink's (search does not index DMs) and the
half that is operator/host (nothing consumes `framework-agent-systemd`'s mailbox) are
named in OBS-482 but not filed here, per the gap-homing rule.

### 4.4 What this does and does not change

**Does change — S1's shape.** Drive 6 framed clause 2 as *"transfer two artefacts, or
rule them out of scope"*, on the belief that the artefacts might not be producible. 832's
position, on the record since before drive 6 ran, is that the artefacts **exist**, at
named paths, with published hashes, and that the missing thing is **AEF's consolidated
per-finding disposition tables** — work that is ours, not a transfer that is theirs.
Drive 6's §3 sentence *"Building dispositions from it would be fabrication"* was correct
about `roadmap-5be23719.md` §8's bibliography line and **wrong about the world**: the
findings are not four keywords, they are two full documents this repository has not
fetched.

**Does not change — the arithmetic, or the authority.** Clause 2 is still unsatisfied.
And this drive did **not** fetch the artefacts. Attempting it produced the round's second
gate refusal:

```
$ ls -d /opt/0503* …
PROJECT BOUNDARY BLOCK — Command Targets Another Project
  Reason: Outside-path argument /opt/0503* (not in read-side allowlist)
  Policy: T-559 (Project Boundary Enforcement)
```

The gate names TermLink dispatch as the sanctioned cross-project route, and **it was not
used**, for a reason that outranks the gate: fetching those two documents into this
repository *is the "transfer" half of S1*. Executing it would be taking the Sovereign
decision in order to report that the Sovereign decision had been taken. Recorded as a
refusal and left there. Per §5 below, neither the existence of a sanctioned route nor
the presence of published hashes constitutes authorization.

**Disposition: T-3389 parked, unchanged.** `captured` / `later`. `fw task update T-3389
--horizon now` was **not** run — the promotion condition (its blocking input present in
this repository) is still false, and promoting a task whose input has not arrived makes
the backlog lie. What changed is the *reason* it is blocked, and that is now a decision
the operator can actually take rather than a search that keeps coming back empty.

---

## 5. Sovereign questions — every drive-6 item re-dispositioned

Drive 6 §6 carried S1–S9. Each is re-checked below and marked **unchanged** / **moved** /
**resolved**, with the evidence. Nothing is answered on this worker's authority.
Recommendations are restated only where they changed; where drive 6's recommendation
stands, it stands and is not re-litigated.

| # | Question | Verdict | Evidence |
|---|---|---|---|
| **S1** | Clause 2 — transfer, or rule out of scope? | **MOVED — materially** | §4. Artefacts exist at named paths with published sha256; the ask is AEF-owned disposition tables, not a transfer. 832's "smallest AEF-owned task" is on the record. |
| **S2** | Q-14 runner isolation topology | **unchanged** | No new evidence sought or found. Drive 6's recommendation (separate service user first, container second) stands. Still the highest-priority design ratification. |
| **S3** | Q-04 two-plane bypass model | **unchanged** | No new evidence. Drive 6's recommendation stands. |
| **S4** | Q-06 identity scheme | **MOVED — corroborated, same direction** | Below. |
| **S5** | Q-03 Fabric coverage threshold | **unchanged in substance, re-measured** | 0 Unknown of **1333** cards (was 1332); write-set coverage control re-run green. The proposed two-axis threshold (≥95% carded **and** 0 Unknown, scoped to the write set) is unaffected by the +1 card — which is itself the argument for a threshold rather than a number. |
| **S6** | Q-07 ledger signing / retention / redaction | **unchanged** | No new evidence. Drive 6's recommendation (decide redaction before signing) stands. |
| **S7** | Q-05 `--from-watchtower` semantics | **unchanged** | No new evidence. |
| **S8** | Q-08 friction on `.tasks/*.md` | **unchanged** | No new evidence. |
| **S9** | arc-019 closure | **MOVED — one of two blockers cleared** | Below. |
| **S10** | *(new)* nothing re-runs a completed task's `## Verification` | **new** | Below. |

### S1 — restated in its new shape (priority 1, still gates the arc)

*Blocks:* the Arc-0 exit gate, therefore Arc 1, therefore everything downstream.

The question is no longer *"can the artefacts be obtained?"* It is:

> **Does the operator authorise AEF to (a) fetch the two named 0503 review documents as
> input — across the T-559 project boundary, by a transport that is not the G-086 HTML
> viewer — and (b) author the consolidated DeepSeek/Mistral per-finding disposition
> tables 832 requests? Or does the operator record an explicit exclusion instead?**

*Recommendation:* **authorise both legs.** The artefacts' existence removes the only
honest argument for the exclusion — drive 6 recommended transfer while conceding that
*"if the artefacts genuinely cannot be produced, option 2 is legitimate"*. They can be
produced; 832 published their hashes. The topics (TOCTOU, compensation idempotency,
evidence ordering, secret-binding refusals, confused deputy, command-boundary refusal
tests) are exactly the classes a refusal matrix exists to enumerate, and a matrix that
excludes them is cheaper and is evidence of nothing.

*Two constraints the operator should attach, both from prior findings:*
1. **Transport:** files or raw bytes, never `http://192.168.10.107:3001/file/…` — that is
   **G-086**, the HTML-wrapper defect that makes a byte-correct document fail its own hash
   check. 832 has already published the hashes to check against.
2. **Reply owed:** 832 has four-plus unanswered DMs and has explicitly said *"no reply
   expected until a real agent attaches to this identity"*. Whatever the ruling, it should
   be *sent*, on that rail, with the semantic read-back they asked for at offsets [1],
   [3] and [4]. Silence has already cost this arc more than the decision will.

### S4 — Q-06 identity scheme (corroborated this drive, same direction)

Drive 6 killed the register's falsifier 3 using **OBS-248** (*"one key covers at least
three agents on this host… the fingerprint is not a discriminator"*). This drive measured
the same thing again, incidentally and from a different direction: the DM rail
`dm:3bba15e681b3a078:d1993c2c3ec44c94` reports **`Senders: 1` — `d1993c2c3ec44c94`** while
its message bodies self-identify as **at least four distinct projects** by automated
extraction (`003-NTB-ATC-Plugin`, `055-agentic-fleet-cockpit`,
`100-Video-riper-and-translation-app`, `832-Workflow-designer`) and six by reading
(add `002-Azure-DevOps`, `dimitri-mint-dev`). One fingerprint, six senders, one mailbox.

*Recommendation:* **unchanged — runner-issued attempt credentials.** Strengthened, not
altered: this is now measured on two independent rails. A shared secret on a machine-wide
rail cannot be per-agent identity, and §4.2 shows the practical cost — a message can be
"correctly addressed and live by heartbeat" with nobody at the other end, and no identity
layer able to say so.

### S9 — arc-019 closure (one of two blockers cleared)

Drive 6 recommended *do not close yet*, naming two blockers: clause 2 (S1), and T-3438's
red verification line on a completed member. **The second is cleared** — T-3394's line 4
is green, measured this drive. State now: **20 members, 18 work-completed**, anchor
**T-3147** `work-completed` / `owner: human` / **0 unticked Human ACs** / still in
`active/`, plus T-3389 `captured/later` and T-3439 (this drive).

*Recommendation:* **still do not close — but the remaining blocker is now exactly one, and
it is S1.** Closing while clause 2 is unruled would be the §ACD pattern this framework has
recorded four times. Arc closure is the operator's act (`fw arc close` is agent-refused,
T-1671) and was not attempted.

### S10 — NEW: nothing re-runs a completed task's `## Verification` block

*Why it is here and not filed as a task:* the evidence is concrete (T-3394 green at close,
red three days later, found only because a worker chose to re-run a cited command), but
every candidate fix — a scheduled re-run, an audit rail over `completed/`, a staleness
warning — is a governance change with a real cost model and a false-positive profile, and
picking one is a priority call on the framework's own cadence.

*Recommendation:* **GO on scoping it, as an inception, not a build.** The blast radius is
every completed task in the corpus, and the obvious naive implementation (re-run every
completed task's block nightly) would be expensive and noisy. One question worth putting
in the inception's frame: the arc-019 headline mechanic promises the operator *a fence
they can run* — a fence nothing re-runs is a claim with an expiry date nobody reads.

---

## 6. Outbound peer asks — still not sent

Drive 6 recorded three. None was transmitted then; **none was transmitted now**, for the
same reason: each presumes a scope position this worker does not hold. Their status is
re-checked:

| # | Ask | Status this drive |
|---|---|---|
| 1 | To `0503`: publish raw bytes / attach files (G-086 / Q-15), then re-issue the packet | **Partly overtaken.** 832 has already published nine raw-byte sha256 values at `agent-chat-arc` @737 and named a clean tree at commit `a9b3a084…`. The outstanding half is AEF answering with `artifact-required` + supported transport, which is S1's leg (a). |
| 2 | To `0503`: *do you intend `.context/dispatches.jsonl` to **be** the ledger?* | **Unchanged — still never asked.** A yes narrows Q-07 (S6) sharply. |
| 3 | To 832: the five paired contracts in register §4 have no paired task on either side | **Unchanged.** Q-10 and Q-11 remain blocked on that, not on analysis. |

**New, and the most overdue:** 832 is owed a reply on the DM rail for offsets [1]–[4] and
[7] — the Clause 1/2 substantive response, the `ewcr-v1-aef-arc0` correlation
acknowledgement (offset [4]), and the R6/R7 approval route IDs. Not sent by this drive:
the content of that reply *is* S1's ruling.

---

## 7. Gates that refused, and what was done instead

Two refusals this round. Both are reported as refusals, neither was routed around, and
no bypass flag (`--force`, `--skip-*`, `--no-verify`, `FW_ALLOW_*`) was used anywhere in
this drive.

| # | Gate | Where | What was done instead |
|---|---|---|---|
| **1** | `check-active-task` — *"BLOCKED: No active task"* on the T-3438 close commit | `--status work-completed` clears `focus.yaml` as its last act, so the commit that carries the close has no task to run under. **This is OBS-250, named in CLAUDE.md, hit live.** | Re-pointed focus at **T-3439** (still `active`, `started-work`) via `fw context focus T-3439` and committed under it, with the reason stated in the commit body. The commit-msg hook warned *"Task T-3438 is closed… Commit allowed (Tier 1 warning)"* — correct, and left visible. |
| **2** | `check-project-boundary` (T-559) — *"Outside-path argument `/opt/0503*`"* | Attempting to confirm the two review documents exist on this host | **Nothing.** The gate offered TermLink dispatch as the sanctioned route and it was deliberately not taken — §4.4. Existence was established from 832's own published hashes instead, which is evidence without a boundary crossing. |

Declined without being attempted, because attempting would have been the violation:

| Not done | Why |
|---|---|
| `fw arc close ewcr-arc0-contract-evidence` | Agent-refused by design (T-1671); and S1 is unresolved. Operator's act, at `/arcs/ewcr-arc0-contract-evidence/close`. |
| Fetching the DeepSeek/Mistral artefacts by any route | That is S1's leg (a). Executing it decides the question. |
| `fw task update T-3389 --horizon now` | Its blocking input is still not in this repository. |
| Ruling DeepSeek/Mistral in or out of Arc-0 scope | A scope change on a draft-authorised arc. S1. |
| Ticking any Human AC | T-3147's are already ticked by the human; none was touched. |
| Answering S2–S8 | Sovereign. Recommendations restated; decisions not taken. |
| Rescoring T-3438 upward | Producer-not-judge. §8, C2. |
| Rewording T-3438's `rm -rf` control to satisfy the reviewer | §3. The control is the right shape; the escalation is reported instead. |
| Replying to 832 on the DM rail | The content of that reply is S1's ruling. §6. |

---

## 8. Cost-vs-estimate deltas for calibration

**C1 — the quadrant gap is unchanged and is still the majority case.** `fw bvp
--include-proposed`: **165 of 192 tasks (86%) with no known cost**, identical to drive 6.
Both tasks this drive touched are in the 86%. The fix is upstream (T-3068,
`components:` resolved only at the `work-completed` transition), not in the Mandate.
**New datum for that fix:** T-3438's close reported `Components: 1 resolved from git
history` — so the resolution mechanism works, it just fires too late to inform the
selection it is meant to inform.

**C2 — the estimator's under-score is now measurable against an outcome.** Drive 6
predicted this rubric mis-scores "a green check went red" and returned BVP **42**, rank
**178/192**. The realised work: **one file changed, ~9 minutes of execution, 5/5 ACs,
6/6 verification, and it restored a fence the arc's headline mechanic promises the
operator can run.** That is a high-value, genuinely low-cost unit scored in the bottom
decile. **This worker did not adjust it** — producer-not-judge, and the second
independent observation of the same miss is worth more to whoever owns the rubric than a
corrected number would be. Candidate signal, restated from drive 6 and now with an
outcome behind it: *a task whose ACs reference an existing red verification line on a
completed task.*

**C3 — drive 6's own C3 (a drifted citation inside a landed decision) reproduced, and the
mechanism is now visible.** D-616 quotes CLAUDE.md's ledger figures (1339/1838) which were
live at 2550/3035. This drive found the *same class* twice more: the attestation's
"544 Unknown" bullet, and the tool's hard-coded premise. All three are the same defect —
**a corpus number captured into prose and then read as current**. Drive 6 registered it
as a self-criticism; this drive fixed two instances (§3) and notes that the class has now
appeared four times across two rounds. That frequency, not any single instance, is the
calibration signal.

**C4 — drive 6's OBS-477 (a concurrent worker swept this drive's records under its task
id) did not recur.** No other worker was on this tree. All four commits this round carry
`T-3438:` or `T-3439:`, staged by name, never `git add -A`/`-u`. Reported as a
non-recurrence rather than omitted, because a control that only gets mentioned when it
fails is not a control.

**C5 — a measurable cost delta finally exists.** Drive 6 recorded *"no comparable prior
estimate exists"* for itself. This round: T-3438 was estimated `tier=2, effort=7,
blast_radius unmeasured`, and realised as 4 files / +181−69 lines / **86 minutes
wall-clock, ~9 minutes of execution** (the remainder is drive-level work under T-3439).
The episodic record carries it. One data point is not a calibration curve, but it is the
first one this arc has.

**C6 — the cheapest finding of the round cost nothing and was nearly not made.** T-3438
took the planned effort and produced the planned result. §4 — the round's actual value —
came from running *one command drive 6 had not run*, prompted by the dispatch stanza
naming a surface. Calibration note for whoever writes the next stanza: **naming the
specific surfaces to re-check was worth more than the executable task in the arc.**

---

## 9. Arc state at handback

`bin/fw arc show ewcr-arc0-contract-evidence`, measured 2026-09-22 ~20:10Z.

| Status | Count | Tasks |
|---|---|---|
| work-completed | **18** | T-3147 (anchor, `owner: human`, 0 unticked Human ACs, in `active/`), T-3350, T-3351, T-3352, T-3381, T-3384, T-3385, T-3386, T-3387, T-3388, T-3392, T-3393, T-3394, T-3395, T-3401, T-3403, **T-3437**, **T-3438** |
| started-work | 1 | **T-3439** (this drive) |
| captured / `later` | 1 | **T-3389** — blocked; blocking *reason* changed this drive (§4) |
| **Total** | **20** | |

### Delta against drive 6 §10

| | Drive 6 | Drive 7 | Δ |
|---|---|---|---|
| work-completed | 16 | **18** | +2 |
| started-work | 1 (T-3437) | 1 (T-3439) | T-3437 closed, T-3439 opened |
| captured / `now` | 1 (T-3438) | **0** | **−1 — worked and closed** |
| captured / `later` | 1 (T-3389) | 1 (T-3389) | 0 |
| Executable members remaining | 1 | **0** | −1 |

### What remains in Q1/Q2, per task, with the reason it was not done

| Task | Value | Not done because |
|---|---|---|
| **T-3389** | BVP **97**, rank **38 of 192**, top quintile | **Blocked — and the block is now a decision, not a search.** Seven surfaces re-checked negative (§4.1); the eighth found 832's standing position that the artefacts exist and the ask is AEF-owned disposition tables (§4.2). Acting on it requires (a) a cross-boundary fetch the T-559 gate correctly refused, and (b) a scope ruling on a draft-authorised arc. Both are S1. |
| **T-3147** | anchor | **Human-owned, zero unticked Human ACs.** Needs only the operator's finalising transition. Not agent work. |

**Nothing in arc-019 is both eligible and unblocked.** Per the Mandate this is the point
to re-enter at level 2 and select another arc — the Sovereign's instruction scopes these
rounds to arc-019, so the run stops here and says so rather than wandering. **This is the
first round where the arc's executable queue is genuinely empty**, which is a different
statement from drive 6's: drive 6 left T-3438 filed-and-unstarted and stopped on the
Mandate's AC-scoping rule; drive 7 leaves nothing.

**On whether a round 3 is worth dispatching.** Stated as advice, not as a decision: **not
until S1 is ruled.** Every remaining path in this arc runs through it, and a round 3 fed
this handback would re-verify the same seven negative surfaces and write a third document
saying so. If the operator wants agent work to continue, the higher-value dispatch is
S10's inception (nothing re-runs completed tasks' verification blocks) — which is
whole-repo, not arc-019, and therefore a level-2 re-entry the Sovereign has not authorised.

---

## 10. Operator actions

| Action | Where |
|---|---|
| **Decide S1** — authorise the fetch + the AEF-owned disposition tables, or record an explicit exclusion. **Gates the arc; now the only blocker.** | `http://192.168.10.107:3002/review/T-3389` |
| Reply to 832 on the DM rail (Clause 1/2 substance, `ewcr-v1-aef-arc0` correlation ack, R6/R7 route IDs) — four-plus DMs unanswered since before drive 2 | `dm:3bba15e681b3a078:d1993c2c3ec44c94`; content is S1's ruling |
| Investigate why `framework-agent-systemd` (`3bba15e681b3a078`) has no consumer — 832 diagnosed it at offset [7]; this is how the clause-2 answer went unseen for weeks | host/TermLink side; OBS-482 |
| Finalise the anchor (work-completed, `owner: human`, 0 unticked Human ACs) | `http://192.168.10.107:3002/review/T-3147` |
| Arc closure — **after** S1 only. T-3438's red line is cleared. | `http://192.168.10.107:3002/arcs/ewcr-arc0-contract-evidence/close` |
| Rule on **S2–S8** (drive 6 §6, re-dispositioned in §5) | No single surface; each is a design ratification |
| **S10** — scope an inception: nothing re-runs a completed task's `## Verification` | whole-repo; needs a level-2 re-entry |

URLs carried forward from drive 6 §11, which emitted them via `bin/fw task review-batch
T-3147 T-3389` rather than typing them from memory.

---

## 11. Records created by this drive

| Record | What |
|---|---|
| **T-3438** | Closed — 5/5 ACs, 6/6 verification. Commits `8590c21c6` (fix) + `8fca51362` (close). |
| **OBS-482** | The six clause-2 searches shared one blind spot; `termlink agent search` does not cover DM channels. Measured with a control. |
| `tools/ewcr-arc0-unknown-overlap.py` | Card total is the discriminator, not the Unknown total. Empty-scan guard preserved and pinned. |
| `docs/research/executable-workflow/arc-0-clause-1-attestation.md` | Reconciled: 544 → 0 recorded with date and commit; the 2026-09-19 block date-stamped as a capture. |
| **S10** | New Sovereign question — nothing re-runs a completed task's `## Verification` block. |
| this file | `docs/reports/EWCR/drive-7-procasfit-handback.md` |

**No decision record (D-6xx) was created this round.** Drive 6 landed three; this round
landed none, and that is the correct outcome rather than a shortfall — every remaining
§3 row is Sovereign, peer-blocked, or sequencing-blocked, and manufacturing a fourth
decision to match drive 6's count would be the padding the Mandate's auditability clause
exists to prevent.

— T-3439, arc-019 `ewcr-arc0-contract-evidence`, drive 7
