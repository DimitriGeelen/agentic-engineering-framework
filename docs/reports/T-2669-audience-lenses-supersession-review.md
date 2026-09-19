# T-2669 — audience lenses on corpus maps (package P1 / SD-14): supersession review

**Task:** T-2669 (inception, arc-014 designer-corpus)
**Question:** Should corpus maps gain per-audience render lenses — business/functional
view, technical view, one-way pseudocode — per the package's P1 purpose and SD-14?
**Filed:** 2026-07-28 with `Recommendation: NO-GO` — *"the corpus is write-mostly —
agents never read the maps during work and operator read-value is unproven …
NO-GO until T-2622 (agent retrieval seam) demonstrates read-pull; operator may
override if business-view legibility (V8) has independent value."*
**Reviewed:** 2026-09-19 under the T-3391 autonomous run. Read-only research; no
spikes. Third of three sibling reviews (T-2668, T-2670) against the same successor
arc.

## 1. Has read-pull appeared? (IW-1)

Yes — and from the audience the NO-GO doubted most.

| Evidence | What it shows |
|---|---|
| arc-017 onboarding curriculum (T-2877 Half A, T-2941 rehearsal) routes **10 `fw corpus explain` calls** from its eleven operator sections | An operator-facing artefact built to *read* corpus maps rather than embed them |
| T-2942 vendored the reader + maps into consumers because *"all 10 were dead in every consumer from the day Half A shipped"* | The read path mattered enough to be a shipped defect, not a hypothetical |
| 11 tasks created 2026-08/09 reference the reader (T-2715, T-2877, T-2941, T-2942, T-2972, T-2980, T-2981, T-2984, T-3001, T-3002, T-3003); 8 episodics cite `fw corpus explain` | Ongoing read-side use by agents and by the operator trial |

The reader renders **prose** (`tools/corpus_explain.py`): one lens, text, for
whoever asks. The write-mostly premise of the July NO-GO no longer holds as
stated; what holds is narrower — the read-pull that exists is served by one
prose rendering, and nobody has asked for a second.

## 2. Has a V8 / audience-lens need been filed? (IW-2)

No. `grep -rl -i "audience lens|business view|pseudocode lens|functional view"`
over `.tasks/active`, `.tasks/completed`, `inbox.yaml`, `concerns.yaml` restricted
to 2026-08/09 dates returns only T-2668, T-2669 and this run's record. The
"operator may override" clause was never exercised.

## 3. Who owns per-audience rendering now? (IW-3)

`architecture-c9070637.md` §10 *Operator and agent views*:

> The same procedure should render in distinct lenses:
> — **Business:** outcomes, roles, decision points, high-level status.
> — **Logical:** interfaces, branch conditions, handoffs, sub-procedure calls.
> — **Technical:** actions, scopes, profiles, evidence checks, Component/Context references.
> — **Runtime:** live current node, attempts, elapsed time, pauses, refusals, approvals, outputs, and audit links.

That is P1's functional (business) / logical / technical triple, plus a runtime
lens P1 did not have. `roadmap-5be23719.md` Arc 4 builds the read-only
projection and visual trace (items 1, 3). Operator GO 2026-08-20 (§18).

**Not covered:** the **pseudocode lens** (SD-14). EWCR names no such view.
T-2662 §4 routed SD-14 here with "rec NO-GO — no read-pull yet". With read-pull
now present but no request for pseudocode specifically, SD-14 stays unjustified
on its own evidence; whether arc-019 wants a fifth lens is arc-019's question.

## 4. Assumption ledger

| ID | Assumption | Verdict | Evidence |
|---|---|---|---|
| A-060 | No measurable read-pull; corpus still write-mostly | **invalidated** | §1 — curriculum's 10 reader calls; 11 tasks; T-2942 |
| A-061 | A V8 / audience-lens need has been filed | **invalidated** | §2 — none |
| A-062 | arc-019 owns per-audience rendering | **validated** | §3 — §10; Arc 4 items 1, 3 |

## 5. Go/No-Go evaluation

- **GO if** audience lenses are unowned and read-pull justifies building them under arc-014 — *not met on ownership*: §10 owns business/logical/technical/runtime; read-pull (§1) argues for the lenses' *value*, which is why the owner matters.
- **NO-GO if** building lenses here would duplicate a ratified programme's views — *met* for the three P1 lenses.
- **DEFER if** the read-pull evidence were still absent — *not met*; it is present.

## 6. Recommendation

**NO-GO — dissolved by supersession into arc-019 §10 / Arc 4**, with the
original NO-GO's premise corrected on the record. **On the form: GO means "build
P1 lenses under arc-014 now"; NO-GO means "the three lenses are arc-019's; close
as dissolved, carry the transfers".**

Transfers to arc-019 (recorded, not decided):

1. **The read-pull finding.** The first real read consumer of the corpus is the operator, through the onboarding curriculum, via prose. arc-019 §10's Business lens has a live consumer before it exists; the curriculum's 10 routes are the acceptance fixture for it.
2. **SD-14 pseudocode lens** — not in §10; stays retired unless arc-019 adds it. Recorded so SD-14 has a written terminus rather than an open pointer.
3. **T-2622's seam is the read path §10 will replace or wrap** (`fw corpus explain`, corpus in ask/recall): whichever lens ships first should not create a second reader.

## 7. Dialogue log

None — executed under an autonomous mandate (T-3391); go/no-go reserved to the
operator via `fw task review T-2669`.
