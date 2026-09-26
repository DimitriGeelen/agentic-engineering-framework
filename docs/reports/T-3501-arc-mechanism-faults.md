# T-3501 — the ARC mechanism is faulty: the cross-agent proposals, verified

**Status:** inception. Research complete; awaiting operator GO on scope.

**Operator instruction, verbatim, 2026-09-26:** *"Please check messages, there's a
number of proposals from different agents on improving our ARC mechanism. Because
it's faulty. So let's work on that."*

The proposals are real, they are from three different agents, and **four of the
five claims are live in this tree.** Every claim below was re-derived here rather
than taken on the sender's word — the reports themselves ask for exactly that
(*"Check yours"*).

---

## Where they were

`agent-chat-arc`, offsets **1087**, **1090**, **1247**. Not in any `.context/`
inbox, not in `framework:pickup`, not in the project inbox.

Worth recording because it cost most of the search: **`agent-chat-arc` is
~95% hourly `vendored-arc heartbeat` noise with real cross-project design traffic
buried in it**, and the word "arc" in that topic name means TermLink's *chat arc*,
not AEF's arc mechanism. A sample of the most recent 12 messages returns only
heartbeats and reads as "nothing here."

### Search log — checked vs empty vs unexamined (T-3099)

| surface | result |
|---|---|
| `agent-chat-arc` pattern search | **FOUND — @1087, @1090, @1247** |
| `agent-chat-arc` recent-12 sample | misleading: all heartbeats |
| `framework:pickup` (182 msgs, decoded) | 0 arc-mechanism hits |
| `aef-operator-notices` | a real 832 fault report, but about **task ownership**, not arcs |
| `inbox:…/999-Agentic-Engineering-Framework` | self-probes only |
| `.context/pickup/processed` (80 files) | P-051 etc. are parallel-execution, not arcs |
| `.context/inbox.yaml` | arc entries exist but are **my own** prior observations |
| DMs `8e6fd77ec6f74b37` | sidecar + version-skew, not arcs |
| DMs `3bba15e681b3a078`, `9219671e28054458`, `fd794e…`, `deadbeef…` | **unexamined** |
| `channel:learnings` (257), `aef-install-findings` (39) | **unexamined** |

---

## The five claims, and their status here

| # | claim | from | status in this tree |
|---|---|---|---|
| 1 | `fw arc tag` writes the deprecated `arc:<slug>` tag and **never** `arc_id:` | 832 @1087 (their T-467) | **ALREADY FIXED** — `arc_tag()` writes `arc_id:` first; comment credits *"832 T-467 / T-2955"* |
| 2 | the reassignment guard is blind to tag-only membership | 832 @1087 (their T-679) | **PARTIAL** — a guard exists and refuses a differing `arc_id:`, but it reads only `arc_id:`, so tag-only dual membership is still reachable |
| 3 | the help text calls the **deprecated** form canonical | @1090 | **LIVE** — `lib/arc.sh:34` |
| 4 | a 1 KB frontmatter read budget truncates membership | @1247 | **LIVE, and worse than reported** — measured below |
| 5 | BVP arc ranking **drops** arcs with no canonical members instead of reporting zero | @1247 | **LIVE** — `lib/bvp.sh:563` |

---

## Claim 4 is the root cause, and it is measurable

`lib/arc_membership.py:50` — `_HEAD_READ_BYTES = 1024`, with the comment *"arc_id
and tags live at the top of frontmatter. 1KB is [enough]"*. That assumption is
false in this corpus, because the task template's **own comment block** (the
`arc_id:` / `demo_target:` / BVP guidance, ~25 lines) plus any
`bvp_scores_proposed:` / `cost_estimate_proposed:` block pushes real fields past
byte 1024.

**Measured over 3,484 task files, frontmatter-only, 1 KB-truncated vs full:**

| | |
|---|---:|
| membership markers living beyond byte 1024 | **56** (49 `arc_id:`, 7 `arc:`-tag) |
| arcs the reader **undercounts** | **17 of 29** |
| members invisible to membership | **59** |

| arc | 1 KB reader | full frontmatter | missed |
|---|---:|---:|---:|
| orchestrator-rethink | 106 | 123 | **+17** |
| continuous-run | 48 | 57 | +9 |
| watchtower-redesign | 83 | 90 | +7 |
| project-shape-resilience | 10 | 15 | +5 |
| value-prioritisation | 92 | 97 | +5 |
| arc-grooming | 42 | 45 | +3 |
| arc-005 | 1 | 4 | +3 |
| …10 more | | | +1 or +2 each |

### It does not only lose data — it invents an arc

`orchestrator-reth` appears with **one member and does not exist.**

```
T-1655-g-062-mechanism-1-codify-arc-completion-.md
  bytes 1000-1024, verbatim:  b'rc_id: orchestrator-reth'
  what the 1 KB reader sees:  orchestrator-reth      <- phantom
  what is actually written :  orchestrator-rethink
```

Truncation lands **mid-token**, so the reader simultaneously drops T-1655 from its
real arc and fabricates a phantom arc id. And the task it happens to is
**T-1655, "G-062 mechanism 1: codify arc completion"** — the arc-completion
governance task is itself invisible to arc membership.

### Why nobody noticed — the transferable half

832 @1087 states it better than I would:

> every reader (`lib/arc_membership.py`) **UNIONS** both forms, so an arc recorded
> in two representations renders identically to one recorded canonically. No view
> was ever wrong. **A defect that cannot change any output cannot be found by
> checking outputs** — which is what verification normally does. […] a
> compatibility path needs its own assertion **ON THE PRODUCER**, because the
> consumer never complains.

The 1 KB budget is the same shape one layer down: a reader that stops mid-file
**cannot distinguish "no value" from "a value I never reached"** (@1247's phrasing).
That is the identical rule this repo already applies to cost (`blast_radius`
unknown-not-zero, T-3068) and to the BVP ledger (`attributable: false`, never 0) —
applied everywhere except here.

### What it explains that was previously filed as separate mysteries

- **arc-017's constituent count "disagrees three ways"** and its `arc_id:` matching
  zero tasks.
- **Five arcs WARNing as stale** in today's audit with membership counts that do
  not match their own YAML.
- Zero-population arcs being **exempt from the staleness WARN for the wrong
  reason**.
- Claim 5 compounds it: `lib/bvp.sh:563` reads only `arc_id:` and returns
  `(None, '')` for an empty member list, so a tag-only arc is **dropped from the
  BVP ranking** rather than ranked at zero.

---

## Mechanism or adoption? (IW-3)

Both, and they separate cleanly — which matters, because they take different
repairs and one of the gates involved is currently doing its job.

- **Mechanism defects (repair the code):** claims 3, 4, 5, and the residue of 2.
  Claim 4 is a silent false-negative in a reader; claim 5 is a silent drop; claim 3
  is documentation that actively teaches the wrong field.
- **Adoption defect (do NOT touch the gate):** arc-020 shipped seven slices with
  nothing calling the result (OBS-537). G-062 **correctly** refused closure because
  the headline mechanic never fired. The gate worked; the wiring did not. Any
  proposal that loosens G-062 is solving the wrong problem.

---

## Recommendation

**GO**, scoped to the four verified mechanism defects, in this order. Slices are
proposed, not filed — no build task exists until the operator rules.

| slice | what | why this order |
|---|---|---|
| **S1** | Remove the 1 KB read budget in `lib/arc_membership.py`; read the whole frontmatter block. Add a producer-side assertion and a fixture whose `arc_id:` sits past byte 1024. | Root cause. Fixes 17 arcs' counts and kills the phantom. Cheapest real repair available. |
| **S2** | Re-measure every arc's membership after S1 and reconcile `constituent_tasks:` in the arc YAMLs against it. | The stored counts were written from the truncated reads; fixing the reader without reconciling leaves the YAMLs wrong. |
| **S3** | `lib/bvp.sh:_arc_member_tasks` — accept the legacy tag form, and report a zero-member arc **as zero** rather than dropping it. | Makes the BVP arc ranking stop hiding arcs. Depends on S1 for correct input. |
| **S4** | Fix `lib/arc.sh:34`'s help text, and audit the file for the other three contradictory lines @1090 names. | Cheap, and it is what teaches the next agent the wrong field. |

**Deliberately NOT proposed:** any change to G-062 / T-1671 closure gating; a
migration that collapses dual membership (@1087 flags two such tasks and calls the
collapse an operator decision, correctly); adopting 832's patches as bytes (they
offered the *shape*, and their commits sit on a different tree).

**One thing to take them up on:** both @1087 and @1090 ask for the fixture-set
shape for both frontmatter forms. 832's fence is
`tools/_t467-arc-tag-source-of-truth.py`, 10 arms. Worth requesting before building
S1's fixtures, since they have already solved the harder half — @1087's root-cause
note is that *"a fence whose fixtures all come from today's template cannot see
yesterday's records."* Our 1 KB defect is precisely a fixture-blindness problem:
every short fixture passes.

---

## Dialogue Log

### 2026-09-26 — instruction received

Operator: *"Please check messages, there's a number of proposals from different
agents on improving our ARC mechanism. Because it's faulty. So let's work on
that."*

Filed as an inception, not a build, per G-020: a detailed report from another
session is a proposal, not authorisation. Recommendation filed `DEFER` because the
proposals had not been read — a genuine evidence gap, replaced with `GO` above once
they were read and verified.

### 2026-09-26 — one correction against myself, mid-measurement

My first per-arc impact table was **wrong and inflated**. It compared a
1 KB-truncated *frontmatter* read against a regex over the *whole file*, so body
prose leaked in and it reported phantom arcs named `foo`, `alpha`, `slug`, `ntfy`.
The real comparison is frontmatter-vs-frontmatter, which gives 17 arcs and 59
members rather than the 30 arcs and 235 members the bad version claimed. Corrected
before reporting. The genuine phantom (`orchestrator-reth`) survived the
correction and was then confirmed byte-exactly.
