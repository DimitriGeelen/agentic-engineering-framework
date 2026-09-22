# EWCR drive 6 — procAsFit handback (arc-019)

**Task:** T-3437 · **Arc:** arc-019 `ewcr-arc0-contract-evidence`
**Mandate:** `tools/prompt-sequence/02-procasfit.prompt.md` (T-3411), one round, arc level pre-decided
**Operator instruction (2026-09-22 17:15Z, verbatim):** *"the work on arc 019 use the procasfit prompt"*
**Run:** 2026-09-22, TermLink worker `t3437-ewcr-procasfit`
**Predecessors:** T-3381 (drive 2), T-3384 (3), T-3392 (4), T-3395 (5)

Every claim below is traceable to a command run in this session or to a verb-gated
state change made by it. Where a number is quoted from a document rather than
re-measured, it says so.

---

## 1. Selection, stated before execution

Per the Mandate, selection is top-down and each level gates the one below.

| Level | Choice | Why this and not the next candidate |
|---|---|---|
| **Objective** | arc-019's headline mechanic — *"operator opens the Arc 0 page, picks any pilot invariant or review finding, and sees it traced to a versioned contract, a refusal scenario, a responsible component, and an executable verification fence they can run"* | Read from `bin/fw arc show ewcr-arc0-contract-evidence`. The arc is `in-progress` with 16 of 17 members work-completed; the objective it serves is the Arc-0 exit gate that blocks Arc 1. |
| **Arc** | arc-019, **Sovereign-selected** | Not the worker's choice. The operator named it. The Mandate's level-2 rule (prefer an in-flight arc) would have selected the same one independently: it is in flight, 89% complete, and its exit gate blocks every downstream EWCR arc. |
| **Task** | **T-3437** (this drive) | The only executable unit in the arc. The single other open member, **T-3389**, is blocked on an operator transfer that this drive re-verified as still absent (§3). T-3147 is a completed anchor awaiting a Sovereign finalisation, not agent work. There was no third candidate to rank against. |
| **Quadrant** | **High value, cost unmeasured** | Estimator, not self-assessment: `bin/fw bvp estimate T-3437` → `D1=4 D2=4 D3=3 D4=2 F-RECALL=3 F3=1`, BVP **110**, rank **2 of 192** in `fw bvp --include-proposed`, against a live corpus median of **62** (n=192; the dispatch stanza's "61" has moved one point). **Cost is `-`.** 165 of 192 tasks (86%) have no measurable cost because `components:` is unresolved (T-3068), so the tool assigns no quadrant and neither does this handback. On value alone the task is Q1/Q2; the Q1-vs-Q2 split is **not determinable from the corpus** and is not invented here. The cost estimator's own words, written to this task's frontmatter mid-drive: `blast_radius=? (no-components-UNMEASURED-not-zero); tier=3 (workflow:design); effort=8`. Unknown, not zero — which is the distinction T-3068 exists to preserve. |

A second unit was filed mid-drive (**T-3438**, §4) but not started: filing it closes
T-3437's AC A3, executing it does not, and the Mandate scopes activity to the ACs.

---

## 2. Objectives advanced, against the state at run start

| Measure | At run start (17:10Z, parent-verified) | At handback | Δ |
|---|---|---|---|
| arc-019 members work-completed | 16 of 17 | 16 of 19 | +2 members filed, none closed |
| §3 register rows with a recorded AEF decision | 0 of 15 | **3** (Q-01, Q-02, Q-07-AEF-half) | +3 landed |
| §3 register rows dispositioned in writing | 0 | **15 of 15** | +15 |
| Component Fabric `Unknown` cards | 544 (per T-3394 attestation, 2026-09-19) | **0 of 1332** (re-measured live) | **fence 1 clears** |
| Open EWCR structural defects registered | — | +1 (OBS-476) with a fix task (T-3438) | +1 |

The substantive advance is **Q-02**. The register has said since ingestion that AEF's
Component Fabric does *not* support the stated boundaries — 512 of 1117 cards (45.8%)
unclassified, *"Fence 1 fails today"*. That is no longer true and this drive is the
first to check it rather than inherit it. Measured directly against `.fabric/components`:

```
$ ls .fabric/components/*.yaml | wc -l                       -> 1332
$ grep -l "^subsystem: Unknown" .fabric/components/*.yaml | wc -l  -> 0
$ grep -ih "^subsystem:" .fabric/components/*.yaml | sort | uniq -c | sort -rn | head -3
    524 subsystem: tests
    282 subsystem: framework-core
    177 subsystem: watchtower
```

The 544 Unknown cards were reclassified corpus-wide, overwhelmingly into `tests`
(524) and `tests-playwright` (129). The discriminating control — the leg that exists
because a zero overlap means nothing if the write set has no cards at all — runs green:

```
$ python3 tools/ewcr-arc0-coverage-check.py
root        files on disk   with a card   coverage   card=Unknown
lib                   186           183      98.4%              0
web                   164           162      98.8%              0
agents                143           143     100.0%              0
bin                     9             9     100.0%              0
policy                 11            11     100.0%              0
```

High coverage **and** zero Unknown on every write-set root is the shape that makes the
zero a measured clear rather than an empty scan. Recorded as **D-615**.

---

## 3. T-3389 — the transfer was re-checked, not assumed

AC A2 required the four external review findings to be searched for rather than
presumed absent. Four searches, all negative, all reproducible:

| Surface | Command | Result |
|---|---|---|
| Repo research dir | `ls docs/research/executable-workflow/` | 8 files + `contracts/`. **No `reviews/` directory.** |
| Whole repo | `grep -rliE "deepseek\|mistral\|z\.ai" docs/ .context/` | Hits only in documents that *name* the reviews, never their content |
| Transfer channel | `termlink channel info xfer-832-bpmn` | **Posts: 0, Senders: 0** |
| 832 sidecar | `termlink channel state sidecar:832-Workflow-designer` | 1 post — the outbound branch-topology reply. Nothing inbound. |
| Hub-wide | `termlink agent search "DeepSeek" / "Mistral" / "external review" / "refusal matrix"` | 1001 envelopes scanned, **0 posts** |
| Pending transfers | `termlink inbox list cacc73ea32b121dd/999-Agentic-Engineering-Framework` | **No pending transfers** |

**Refinement the previous drives did not state.** The transfer gap is **two of four,
not four of four**. The Claude and Z.ai findings *were* transferred — they are
`architecture-c9070637.md` **§17 "Claude review dispositions"** and **§18 "Z.ai review
dispositions and operator decision"**. The DeepSeek and Mistral findings exist in this
repository only as four topic keywords apiece in `roadmap-5be23719.md` §8:

> - DeepSeek review: task TOCTOU, compensation idempotency, immutable evidence ordering.
> - Mistral review: secret-binding refusals, confused deputy, provider/model divergence, command-boundary refusal tests.

That is a bibliography line, not a finding set. Building dispositions from it would be
fabrication, which is the worst possible output for a document whose subject is refusal
fidelity. The arithmetic is unchanged — clause 2 is not satisfiable — but the ask is
smaller and more precise than "transfer the four reviews".

**Disposition: parked, unchanged. `captured` / `later`, not promoted.** `fw task update
T-3389 --horizon now` was **not** run, because the condition the previous drive attached
to the promotion is still false.

**Exactly what the operator must transfer, and where:**

> The **DeepSeek** and **Mistral** review artefacts from `0503-codex-cli-playground`,
> as files, into `docs/research/executable-workflow/reviews/` in this repository.
> The Claude and Z.ai findings are already here (architecture §17/§18) and need not be
> re-sent. Do **not** use the `http://192.168.10.107:3001/file/...` viewer endpoint —
> that is G-086, the HTML-wrapper transport defect that makes a byte-correct document
> fail its own hash check.

The alternative remains 832's option 2 — rule DeepSeek and Mistral out of Arc-0 scope
and record that ruling as their disposition. That is a scope decision on a
draft-authorised arc, which arc-019's own fence places outside agent authority. It is
in §6 as a Sovereign question, not taken here.

---

## 4. What this drive surfaced: the Arc-0 measurement tool refuses on success

Found by re-running the attestation's own reproduction command rather than citing it.

**Symptom.** `tools/ewcr-arc0-unknown-overlap.py` exits **2 REFUSED**:

```
REFUSED: enumerated 0 Unknown-subsystem cards.
  `fw fabric overview` reports a non-zero Unknown subsystem, so a zero
  here means this script's subsystem predicate is wrong, not that the
  fence is clear.
```

**Consequence, verified not inferred.** T-3394's pinned verification line 4 is red:

```
$ bash -c 'set -o pipefail; timeout 300 python3 tools/ewcr-arc0-unknown-overlap.py > /tmp/.o 2>&1 \
    && grep -q "Intersection with CORE write set" /tmp/.o'
rc=2
```

T-3394 closed green on 2026-09-19. The clause-1 attestation's own
*"Reproducing this"* command no longer runs — three days later, with nobody touching
the tool.

**Root cause.** The guard treats `unknown_cards == 0` as proof that its own subsystem
predicate is broken. Its stated premise — *"`fw fabric overview` reports a non-zero
Unknown subsystem"* — was true when written and is false now (§2). The guard has no way
to tell a broken predicate from a genuinely cleared fence, so it refuses on success.

**Why structurally allowed.** The guard hard-codes a **corpus fact as an invariant** —
precisely the mutable-corpus-anchor class T-3326 names, and the script's own header even
argues the opposite case correctly (*"The Unknown count moves… A fence keyed to a number
that drifts needs a command, not a citation"*) before embedding a drifting number in its
refusal text. The real "did we look at anything" discriminator is *total cards
enumerated* — 1332, non-zero — and that is not the number the guard reads.

**What was done.** Registered as **OBS-476** via `fw note` (register first). Filed as
**T-3438** with five real ACs and six verification lines, including a control leg that
runs the tool against an empty card directory to prove the false-green protection still
bites after the false red is removed. **Not fixed in this drive** — fixing it closes no
T-3437 acceptance criterion, and the Mandate scopes activity to the ACs.

Estimator on the new task: `bin/fw bvp estimate T-3438` → `D1=4`, everything else 0,
**BVP 42 — below the corpus median of 62.** That score is reported as the estimator
produced it. See §8 for why it is probably wrong and why this worker did not change it.

---

## 5. §3 open-questions register — every row dispositioned

Source: `docs/research/executable-workflow/questions-and-dispositions.md` §3.
**LANDED** = a decision recorded through `fw context add-decision`, or a task filed with
real ACs. **SOVEREIGN** = surfaced with a recommendation, not answered on the worker's
authority. **BLOCKED** = one-line reason. **PEER** = the sending project must answer.

| ID | Class | Disposition | Record / reason |
|---|---|---|---|
| **Q-01** | AEF | **LANDED** | **D-614.** Arc 0 belongs in AEF — closed by execution, not argument: 16 completed members, every one writing only to §5.1 AEF-owned surfaces, none touching the Designer repo. |
| **Q-02** | AEF | **LANDED** | **D-615.** Fence 1 passes for Arc-0 scope. 0 Unknown of 1332 cards; write-set coverage 98.4–100% with 0 Unknown on every row (§2). Supersedes the register's "Not yet, 45.8%". |
| **Q-03** | HUMAN | **SOVEREIGN — now answerable** | The register asked for *"a measured proposal rather than guessing"*. Arc 0 can now supply one; see §6 Q-03. The number itself is the operator's. |
| **Q-04** | HUMAN | **SOVEREIGN** | Two-plane bypass model. Constrains every future gate — explicitly not an agent call. §6 Q-04. |
| **Q-05** | HUMAN | **SOVEREIGN** | `--from-watchtower` is a direct mutation today. §6 Q-05. |
| **Q-06** | HUMAN | **SOVEREIGN — one falsifier killed** | §6 Q-06. The register's falsifier 3 ("if `rail-identity.key` already provides a usable service identity, Arc 2 is smaller") is **dead**: measured below. |
| **Q-07** | AEF→HUMAN | **LANDED (AEF half) + SOVEREIGN (policy half)** | **D-616.** The `dispatches.jsonl` row shape and dispatch↔outcome join are the reuse candidate; signing / retention / redaction / deterministic fold are operator policy. §6 Q-07. |
| **Q-08** | HUMAN | **SOVEREIGN** | Task snapshot/immutability friction lands on the operator's daily workflow. §6 Q-08. |
| **Q-09** | JOINT | **BLOCKED — peer** | TermLink's auth boundary cannot be per-project (machine-wide by design). Needs a paired contract with 832; no AEF-side move exists that does not presume their answer. |
| **Q-10** | JOINT | **BLOCKED — peer** | Execution-extension format. Named an Arc-0 joint handoff; the paired task in §4 of the register has never been created on either side. Outbound ask in §7. |
| **Q-11** | JOINT | **BLOCKED — peer** | Action-catalogue ownership. AEF owns the catalogue per §5.1 and cannot author the Designer's declarative reference half. Outbound ask in §7. |
| **Q-12** | JOINT | **BLOCKED — sequencing** | Guard/outcome expression language, deferred to Arc 1 by the register itself. Arc 1 is blocked on the Arc-0 exit gate, which is blocked on clause 2 (§3). |
| **Q-13** | AEF | **BLOCKED — out of scope** | Routing bands and provider capability matrix, deferred to Arcs 3/6. Neither arc exists (`ls .context/arcs/` has no Arc-3/Arc-6 entry); both are `DEFER` in §2. Analysing them now would be the low-value descent the Mandate forbids. |
| **Q-14** | HUMAN | **SOVEREIGN — highest priority** | Runner isolation topology. Mandatory before autonomy expands; C4 measures AEF at zero. §6 Q-14. |
| **Q-15** | PEER | **UNRESOLVED — peer-owned, registered** | G-086. The raw-URL transport defect is registered locally and homed to `0503-codex-cli-playground` per the gap-homing rule. Still open; the fix is not ours to make. Outbound ask in §7. |

**Totals: 3 landed · 6 Sovereign · 5 blocked-with-reason · 1 peer-unresolved = 15 of 15.**

---

## 6. Sovereign questions, unresolved, in priority order

Each carries the recommendation the Mandate requires — stated, not left blank. None is
answered here. These are arc-019/§3-scoped and are **distinct from** the 20 whole-repo
Sovereign questions in `docs/reports/SEQ-T3411/r5-review.md` §12; none is re-surfaced.

**S1 — Clause 2: transfer the two missing reviews, or rule them out of scope?**
*Blocks:* the Arc-0 exit gate, therefore Arc 1, therefore everything downstream. This is
the single question gating the arc.
*Recommendation:* **transfer.** The ask is now two artefacts, not four (§3), and their
topics — TOCTOU, compensation idempotency, evidence ordering, secret-binding refusals,
confused deputy, command-boundary refusal tests — are exactly the classes a refusal
matrix exists to enumerate. Ruling them out of scope makes the matrix cheaper and makes
it evidence of nothing. If the artefacts genuinely cannot be produced, option 2 is
legitimate, but it should be recorded as *"these findings were unavailable"*, not as
*"these findings were out of scope"*. (Q-15 / G-086 applies to the transport: send files,
not viewer URLs.)

**S2 — Q-14: runner isolation topology — separate service user, or separate host/container?**
*Why it outranks the rest:* the roadmap makes Arc 2 a hard gate that Arcs 5–6 cannot
pass, and C4 measures AEF at zero — TermLink dispatch spawns `claude -p` workers as the
*same* OS user as the parent. Every autonomy question downstream is unanswerable until
this is decided.
*Recommendation:* **separate service user first, container second.** A service user is
implementable against the existing TermLink substrate and immediately makes "the runner
is not the agent" checkable; a container is the stronger boundary but forces the
cross-repo composition question (Q-09) at the same time. Sequencing them separately
keeps one lock open at a time.

**S3 — Q-04: do Tier-2 bypasses survive on the runner plane?**
*Recommendation:* **ratify the two-plane model as the register proposes.** AEF's
bypasses are logged, human-authorised and antifragile on the *task/governance* plane —
that is a feature and removing it would break the framework's own operating model. On
the *runner* plane they must be structurally impossible: the runner must not read `FW_*`
at all. This needs operator ratification because it becomes a constraint on every gate
written from here on, and an agent cannot bind future gates.
*Note:* answering this also decides whether arch §13.16 is implementable in AEF or needs
a documented AEF-specific exception. Falsifier 2 of §6 is explicit that the exception
must be documented, never silent.

**S4 — Q-06: identity scheme — per-agent keys, or runner-issued attempt credentials?**
*New evidence, and it kills a falsifier.* The register's falsifier 3 said *"if
`.context/rail-identity.key` already provides a usable service identity, Arc 2 is
substantially smaller than C4 assumes."* Measured: the file is **32 bytes, mode 0600,
root-owned** — a single raw symmetric key, not a credential scheme. And **OBS-248**
records, from an unrelated incident, that *one key covers at least three agents on this
host* (this session, 832, and an opencode agent over a sudo bridge), concluding that
*"the fingerprint is not a discriminator"*. A shared secret on a machine-wide rail cannot
be per-agent identity.
*Recommendation:* **runner-issued attempt credentials.** Falsifier 3 is dead; Arc 2 is
the size C4 assumed, not smaller. Per-agent keys on a machine-wide rail reproduce
exactly the ambiguity OBS-248 documents.

**S5 — Q-03: what is the Fabric coverage threshold and limited-mode policy?**
*Now answerable, which it was not at ingestion.* The register deferred this to Arc 0
"with a measured proposal rather than guessing"; §2 is that measurement.
*Recommendation:* **threshold on the write set, not the repository, and on two axes.**
Proposed: *for any declared write set, ≥95% of files carry a Fabric card **and** 0 cards
in that set carry `subsystem: Unknown`; below either, the runtime enters limited mode and
refuses impact queries over that set.* Today's write set clears both (98.4–100%, 0
Unknown). A repo-wide threshold would be the wrong instrument — `tests/` is 524 of 1332
cards and is outside every runtime write set by construction, so a repo-wide number
measures test authorship, not runtime topology. The numbers are measured; **the threshold
is a policy choice and is the operator's.**

**S6 — Q-07 (policy half): ledger signing, retention, and redaction.**
*Recommendation:* **decide redaction before signing.** Signing is an engineering choice
with a clear right answer once retention is fixed; redaction is the one that cannot be
retrofitted — a signed append-only ledger with no redaction policy is a decision to never
erase anything, taken by omission. The AEF half is landed (D-616): the substrate shape is
reusable, the policy is not inferable from it.

**S7 — Q-05: is `--from-watchtower` an authenticated proposal or a direct mutation?**
*Recommendation:* **accept the register's reading and bound it.** It is a direct mutation
today. The runtime should not adopt the pattern, and Arc 4 should treat existing
`--from-watchtower` routes as prior art to *replace* rather than extend — otherwise AEF
ships a second mutation path and the projection API becomes advisory.

**S8 — Q-08: how much friction is acceptable on `.tasks/*.md`?**
*Recommendation:* **no recommendation on the number; one on the shape.** Content-hash
snapshots at gate transitions are cheap and invisible until something diverges;
write-locking task files mid-task is not, and would collide with the continuous-capture
discipline the whole framework rests on. Snapshot-at-transition, never lock. The
tolerance for even that is the operator's daily experience and this worker has none.

**S9 — arc-019 closure itself.** 16 of 19 members complete; the anchor **T-3147** is
`status: work-completed`, `owner: human`, sitting in `active/` with **zero** unticked
Human ACs — it needs only the operator's finalising transition. Arc closure is
`fw arc close`, which is agent-refused (T-1671), and rightly so.
*Recommendation:* **do not close yet.** Clause 2 (S1) is unresolved and T-3438 leaves a
red verification line on a completed member. Closing over both would be the §ACD pattern
the framework has recorded four times. Closure is the operator's act either way.

---

## 7. Outbound peer asks (not sent by this drive)

Recorded for the operator to route; none was transmitted, because each presumes a scope
position this worker does not hold.

1. **To `0503-codex-cli-playground`:** publish a raw-bytes endpoint or attach files
   directly (**G-086 / Q-15**), then re-issue the source packet — and send the DeepSeek
   and Mistral artefacts (§3).
2. **To `0503-codex-cli-playground` (§6 falsifier 4):** *do you intend
   `.context/dispatches.jsonl` to **be** the ledger?* Never asked. A yes narrows Q-07
   sharply.
3. **To 832-Workflow-designer:** the five paired contracts in register §4 (procedure
   interchange, mapping, validation/refusal diagnostics, runtime projection,
   ratification) have **no paired task created on either side**. Q-10 and Q-11 are blocked
   on that, not on analysis.

---

## 8. Gates that refused, and what was done instead

**No gate refused this drive.** That is the honest result and it is reported as such
rather than padded.

What was **declined without being attempted**, because attempting it would have been the
violation:

| Not done | Why |
|---|---|
| `fw arc close ewcr-arc0-contract-evidence` | Agent-refused by design (T-1671). Arc closure is the operator's act at `http://192.168.10.107:3002/arcs/ewcr-arc0-contract-evidence/close`. Surfaced, not attempted. |
| `fw task update T-3389 --horizon now` | The promotion condition is still false (§3). Promoting a task whose blocking input is absent makes the backlog lie. |
| Ticking any Human AC | T-3147's are already ticked by the human; none was touched. |
| Answering Q-03/04/05/06/08/14 | Sovereign. Recommendations given (§6); decisions not taken. |
| Ruling DeepSeek/Mistral out of Arc-0 scope | A scope change on a draft-authorised arc. Surfaced as S1. |
| Any `--force`, `--skip-*`, `--no-verify`, `FW_ALLOW_*` | None used. Nothing needed one. |
| Rescoring T-3438 upward | Producer-not-judge. See below. |
| Fixing T-3438 in this drive | One lock at a time; and it closes no T-3437 AC. |

---

## 9. Cost-vs-estimate deltas worth feeding back into calibration

**C1 — the corpus cannot produce a quadrant, and this is now the majority case.**
`fw bvp --include-proposed` reports **165 of 192 tasks (86%) with no known cost**;
quadrant thresholds are computed over the 27 that have one. The Mandate selects by
quadrant; the corpus supplies a quadrant for 14% of tasks. Both tasks this drive
touched are in the 86%. Reported rather than worked around: neither T-3437 nor T-3438
was assigned a quadrant by guess. The fix is upstream (T-3068, `components:` resolution
at the `work-completed` transition only), not in the Mandate.

**C2 — the estimator scores a red verification line at 42.** T-3438 makes a *completed*
task's pinned verification command fail; it is a small, bounded, fully-specified fix to a
file nobody is contending. On value-per-cost it is the most attractive unit in this arc.
The heuristic estimator returns `D1=4` and zero on everything else — BVP 42, **20 below
the corpus median**, because the body carries no keyword the rubric recognises
(`body:structural-gate`, `body:fw-audit-or-doctor`, `body:component-discoverability`).
Compare T-3437 at 110 for a drive whose output is a document. **This worker did not
adjust it.** The binding is explicit and the temptation here was real: rescoring one's
own filing upward is the exact move producer-not-judge forbids, and a rubric that
under-scores "a green check went red" is a calibration finding worth more to the operator
than a corrected number would be. Candidate rubric signal, for whoever owns it: *a task
whose ACs reference an existing red verification line on a completed task.*

**C3 — a citation drifted inside a landed decision, and the correction belongs here.**
D-616's rationale quotes CLAUDE.md's dispatch-ledger figures (1339 dispatches / 1838
outcomes) with attribution. Live counts this session: **2550 dispatches / 3035 outcomes**
(`wc -l`). CLAUDE.md says of that table *"Regenerate the table rather than trusting this
copy"* — and this handback did not, in one line, while spending §4 on exactly that class
of error. The decision's substance is unaffected (the substrate has no signing, retention,
redaction or fold at any row count) but the number in D-616 should be read as the stale
snapshot it is. Recorded rather than quietly fixed, because the point of §4 is that stale
citations are invisible until someone re-runs them.

**C4 — a concurrent worker committed this drive's records under its own task id.**
`fw` records go to shared append-only files, and a second worker (T-3429) was running in
the same checkout throughout. Its close commit **`32119079a`, 2026-09-22 18:16:34Z**,
contains **D-614, D-615, D-616 and OBS-476** — all authored by this worker minutes
earlier and none of them T-3429's:

```
$ git log --format="%h %cd %s" --date=iso -S "D-614" -- .context/project/decisions.yaml
32119079a 2026-09-22 20:16:34 +0200 T-3429: close — reviewer-gated by default, ...
```

Nothing is lost — each record names `task: T-3437` in its own body — but git history
attributes them to T-3429, so `Updates` mining by `T-XXX` (P-002) will trace this drive's
decisions to the wrong task. This drive's dispatch stanza instructed *"stage files by
name; never `git add -A`/`-u`"* and this worker followed it; the instruction binds on
discipline and nothing enforces it. The underlying shape is the one CLAUDE.md §Execution
Model item 4 already names: `decisions.yaml` and `inbox.yaml` are the **implicit framework
write-set** that two tasks converge on whether or not either declares anything. Registered
as **OBS-477**. Not fixed here — rewriting a pushed commit to re-attribute it would be a
Tier-0 action on another worker's history.

**C5 — drive 6 cost roughly one drive.** No comparable prior estimate exists (drives 2–5
recorded no cost estimate), so no delta can be computed. Noted as an absence, not
estimated after the fact.

---

## 10. Arc state at handback

`bin/fw arc show ewcr-arc0-contract-evidence`, plus the two tasks filed this drive.

| Status | Count | Tasks |
|---|---|---|
| work-completed | 16 | T-3147 (anchor, `owner: human`, in `active/`), T-3350, T-3351, T-3352, T-3381, T-3384, T-3385, T-3386, T-3387, T-3388, T-3392, T-3393, T-3394, T-3395, T-3401, T-3403 |
| started-work | 1 | **T-3437** (this drive) |
| captured / `later` | 1 | **T-3389** — blocked on operator transfer (§3) |
| captured / `now` | 1 | **T-3438** — filed this drive, unstarted (§4) |

**Quadrants.** Value from the estimator, cost unmeasured for all four open tasks:
T-3437 **BVP 110** (rank 2/192), T-3389 **97** (rank 45/192), T-3438 **42**; corpus
median **62**. T-3389 and T-3437 are high-value on the corpus distribution; T-3438 is
below median *as scored* (see C2). **No quadrant is asserted for any of them** — with
cost `-`, Q1-vs-Q2 is not determinable, and inventing one is the failure mode this
section exists to avoid.

**What remains in Q1/Q2, and why it was not done:**

| Task | Value | Not done because |
|---|---|---|
| **T-3389** | BVP 97, top quartile | **Blocked, re-verified this drive.** Six independent searches found no trace of the DeepSeek/Mistral artefacts on disk, on the hub, or in the 832 exchange (§3). No agent route exists to obtain them. The matrix cannot be built from findings this repository has never held. |
| **T-3438** | BVP 42 as scored; see C2 | **Filed, deliberately not started.** Executing it closes no T-3437 acceptance criterion, and the Mandate scopes activity to the ACs. Ready for the next drive or a direct dispatch — ACs and six verification lines are written, including the empty-directory control. |

**Nothing in arc-019 is both eligible and unblocked.** Per the Mandate this would be the
point to re-enter at level 2 and select another arc — the Sovereign's instruction scopes
this drive to arc-019, so the run stops here and says so rather than wandering.

---

## 11. Operator actions

| Action | Where |
|---|---|
| Decide **S1** (transfer DeepSeek + Mistral, or rule out of scope) — gates the arc | `http://192.168.10.107:3002/review/T-3389` |
| Finalise the anchor (work-completed, `owner: human`, zero unticked Human ACs) | `http://192.168.10.107:3002/review/T-3147` |
| Arc closure — **after** S1, and after T-3438's red line is green | `http://192.168.10.107:3002/arcs/ewcr-arc0-contract-evidence/close` |
| Rule on **S2–S8** (§6) | No single surface; each is a design ratification |

URLs emitted by `bin/fw task review-batch T-3147 T-3389`, not typed from memory.

---

## 12. Records created by this drive

| Record | What |
|---|---|
| **D-614** | Q-01 landed — Arc 0 belongs in AEF, closed by execution |
| **D-615** | Q-02 landed — fence 1 passes; 0 Unknown of 1332 cards |
| **D-616** | Q-07 AEF half landed — ledger shape reusable, policy is not (citation caveat: C3) |
| **OBS-476** | Leg-1 measurement tool refuses on success |
| **OBS-477** | Concurrent worker's close commit swept this drive's records under its task id (C4) |
| **T-3438** | Fix task, 5 real ACs, 6 verification lines incl. empty-scan control |
| this file | `docs/reports/EWCR/drive-6-procasfit-handback.md` |

— T-3437, arc-019 `ewcr-arc0-contract-evidence`, drive 6
