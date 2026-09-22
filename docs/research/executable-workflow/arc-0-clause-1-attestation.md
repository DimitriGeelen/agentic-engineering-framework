# EWCR Arc 0 — exit-clause 1 attestation (AEF side)

**Task:** T-3394 · **Arc:** arc-019 (`ewcr-arc0-contract-evidence`)
**Correlation:** EWCR-ARC0-ATTEST-832
**Answers:** 832-Workflow-designer's Arc-0 exit **clause 1**, routed at `agent-chat-arc` @643
**Measured at commit:** `996a4f9a5df1b1b76b56ea14bfb2f01df9564740`
**Measured at:** 2026-09-19T22:10:19Z

## What was asked

Quoted verbatim from @643, so the answer can be checked against the question:

> **CLAUSE 1** — "topology is non-empty and validated" (fence: Component Fabric
> non-empty, enriched, validated; required before implementation decomposition).
> Owner: aef, on roadmap_key_phrase "AEF topology". What would satisfy it: an
> attestation that YOUR Component Fabric is non-empty, enriched and validated for
> Arc-0 scope, CARRYING THE NUMBERS IT WAS MEASURED ON.

832 explicitly declined to answer this locally, and was right to: the topology under
test is AEF's. For calibration they reported their own fabric as 69 registered / 252
unregistered, 46 of 69 cards edgeless — as their own open concern, not as this clause.

## The answer

**Clause 1 is satisfied for Arc-0 scope.** Both legs below were re-run live at the
commit named above; neither number is copied from prose.

### Leg 1 — Unknown-subsystem intersection with the runtime write set

`tools/ewcr-arc0-unknown-overlap.py`, against the CORE and BROAD write sets derived in
`arc0-write-set.md` from architecture §5.1. **This block is the run of 2026-09-19 and is
kept verbatim as the dated capture it was; the Unknown total has since moved to 0 —
see `## The Unknown total moved 544 -> 0` below, which is the current state.**

```
Fabric cards enumerated          : 1279
Unknown-subsystem cards          : 544
  ...of which carry no location  : 0      <- cannot be placed either way

Intersection with CORE write set : 0      (0.0% of Unknown)
Intersection with BROAD write set: 0      (0.0% of Unknown)

── CORE breakdown by §5.1 row ──
     0  runner/ledger/actions (§5.1 row 5)
     0  procedure/runtime semantics (§5.1 row 2)
     0  fabrics — canonical/derived records (§5.1 row 6)

── BROAD-only additions by §5.1 row ──
     0  tasks/inception/approvals/BVP/gates (§5.1 row 1)
     0  diagram→procedure mapping validation (§5.1 row 4)
     0  operator interaction / projection (§5.1 row 7)
```

The 544 Unknown cards are real, and they are all outside the runtime write set:

```
   484  tests        <- explicitly excluded: authoring tests is not a runtime write
    44  tools
     9  docs
     2  context
     2  prompts
     2  vendor
     1  012-ArcSystem.md
```

### Leg 2 — the control, reported because leg 1 alone cannot carry the claim

`arc0-write-set.md` names its own weakness: *a path-prefix set can only find components
that have a Fabric card at all, so a runtime surface with zero cards produces zero
Unknown hits and is indistinguishable from a fully-classified one.* A bare `0` is
therefore not evidence. `tools/ewcr-arc0-coverage-check.py` is the discriminator:

```
root        files on disk   with a card   coverage   card=Unknown
lib                   169           166      98.2%              0
web                   164           162      98.8%              0
agents                140           140     100.0%              0
bin                     9             9     100.0%              0
policy                  8             8     100.0%              0
```

High coverage with zero Unknown across every write-set root. The zero in leg 1 is a
measured zero, not an absence of measurement.

`policy/` is the load-bearing row. When the control was first written (2026-08-26) it
found exactly the artefact case it exists to catch — `policy/` at zero cards, making its
zero overlap meaningless. T-3350 carded the 8 `policy/` governance YAMLs; it now reads
8/8. The control caught a real false green once, which is the reason to trust it here.

## How the numbers moved, and why the earlier figure differs

Anyone comparing against older EWCR documents will find `intersection_count: 3`. That
figure was correct when taken and is now superseded:

| When | CORE ∩ Unknown | BROAD ∩ Unknown | Source |
|---|---|---|---|
| commit `ce2987fd` | 3 | — | earliest falsifier-1 run (519 Unknown) |
| commit `42cd97a2` (2026-09-07) | 3 | 4 | `arc0-write-set.md` machine-readable block |
| commit `ac9a9d410` (T-3351) | **0** | **0** | 23 Unknown write-set cards reclassified |
| commit `996a4f9a5` (this attestation) | **0** | **0** | live re-run, 2026-09-19 |
| commit `d9841353f` (T-3438) | **0** | **0** | live re-run, 2026-09-22 — and the Unknown *total* is now **0** too |

`arc0-write-set.md`'s machine-readable block was left at the `42cd97a2` figures after
T-3351 drove the intersection to 0/0 — stale for twelve days. T-3394 corrects it in the
same change as this attestation, so the two documents cannot disagree again without one
of them going red.

The Unknown *total* grew (519 → 539 → 544) while the intersection stayed 0. That was the
expected shape: Unknown grew with `tests/`, which is outside the write set by
construction. **That trend then reversed and completed — see the next section.**

## The Unknown total moved 544 -> 0

**Measured 2026-09-22, commit `d9841353f`, by re-running this document's own reproduction
command rather than citing it** (T-3437 drive 6 §2, recorded as **D-615**; tool fix
**T-3438** / **OBS-476**):

```
Fabric cards enumerated          : 1333
Unknown-subsystem cards          : 0
Intersection with CORE write set : 0   (n/a — 0 Unknown cards to apportion)
Intersection with BROAD write set: 0   (n/a — 0 Unknown cards to apportion)
```

The 544 cards were reclassified corpus-wide in the three days after 2026-09-19,
overwhelmingly into `tests` (524) and `tests-playwright` (129) — not by any Arc-0 task,
which is why nothing in this arc noticed. Leg 1 is therefore now clear on both axes:
zero intersection *and* zero Unknown anywhere. The discriminating control in leg 2
(coverage 98.4–100% on every write-set root, 0 Unknown on each) is what makes that zero
a measured clear rather than an empty scan.

**The tool refused on this success for three days.** `ewcr-arc0-unknown-overlap.py`
treated `unknown == 0` as proof that its own subsystem predicate must be broken, on the
hard-coded premise that `fw fabric overview` always reports a non-zero Unknown subsystem
— a corpus fact copied into a string (the T-3326 mutable-corpus-anchor class). When the
premise went false the script exited 2, and **this attestation's own pinned verification
line went red on 2026-09-22, three days after T-3394 closed green**. T-3438 split the two
conditions: REFUSED now means *zero Fabric cards enumerated*, which is the real
"nothing was looked at" signal and is read at run time on every invocation. The
enumerated-card total (1333) is the evidence the scan was not empty; an empty-directory
control run still exits 2, pinned as a verification line on T-3438.

Note the card total itself moved 1332 → 1333 between drive 6 (2026-09-22 18:00Z) and
this reconciliation (20:00Z). It is recorded here to make the point rather than to be
tracked: **every number on this page is a dated capture of a moving corpus, and the
command is the claim.**

## Reproducing this

```
cd /opt/999-Agentic-Engineering-Framework && python3 tools/ewcr-arc0-unknown-overlap.py && python3 tools/ewcr-arc0-coverage-check.py
```

Both are pinned as executable verification lines on T-3394, so this attestation cannot
go stale silently the way the block it corrects did.

## What this attestation does NOT claim

Stated explicitly, because the failure mode in this collaboration has been each side
reporting a number the other side did not ask for:

- **It is not a ratification.** Per 832's §2.3, a TermLink post or file transfer is
  transport evidence, not collaboration completion. This document is input to their
  operator's ruling. `attestation: null` and `definition_ratified: false` in their
  register do not flip because this exists.
- **It answers clause 1 only.** Clause 2 (the consolidated refusal/threat matrix) is
  *not* addressed here and is **not satisfiable on the AEF side today** — see
  `## Clause 2` below.
- **It does not speak to exit-clause 3.** H1/H3/H5/H6 are 832's register and their
  operator's ruling. 832 measured clause 3 at 2/6 and explicitly did not ask us for it.
- **It is scoped to the Arc-0 write set**, not to the repository. When this attestation
  was written, repo-wide Fabric coverage — 544 Unknown cards, overwhelmingly under
  `tests/` — was a real and separately tracked concern, and reporting it as this clause
  would have been answering a question nobody asked (the error 832 declined to make in
  the other direction). That concern has since resolved on its own (0 Unknown
  corpus-wide, 2026-09-22), but the scoping claim stands unchanged: this clause is about
  the write set, and a repo-wide number would still be the wrong answer to it now that
  the repo-wide number happens to agree.
- **No runtime code was written.** arc-019's fence forbids runtime implementation; this
  is documentation and measurement only.

## Clause 2 — why it is not answered here

Clause 2 asks for the consolidated refusal/threat matrix built from the Claude, Z.ai,
DeepSeek and Mistral findings, every blocker carrying a contract disposition and a
testable scenario.

**It is blocked on an operator action, not on AEF effort.** The governed task exists —
T-3389, `arc_id: ewcr-arc0-contract-evidence` — and its title records the block:
*"(blocked: reviews not transferred)"*. Its Human AC requires the four external review
documents to be copied into `docs/research/executable-workflow/reviews/` from the
sending project (`0503-codex-cli-playground`). **That directory does not exist in this
repository.** The matrix cannot be built from memory of reviews this repo has never
held, and fabricating dispositions for findings we cannot read would be the worst
possible output for a document whose purpose is refusal fidelity.

This is the same arithmetic 832 stated at @643 under R6: two of four model families have
no disposition table anywhere, so clause 2 is not satisfiable from the packet alone
regardless of how good the Claude (§17) and Z.ai (§18) tables are.

832 named two ways to close it, and **both are the operator's**, not ours:

1. Transfer the four reviews, unblocking T-3389 to build the matrix; or
2. Rule the DeepSeek and Mistral findings out of Arc-0 scope, and record that ruling as
   their disposition.

Option 2 is a scope decision on a draft-authorised arc, which arc-019's own fence places
outside agent authority. Raised to the operator rather than taken.

## Register

- Arc-0 exit clauses (832's register): `docs/research/executable-workflow/arc-0-exit-clauses.yaml` — their repo, not mirrored here
- Operator decisions H1–H6 (832's register): `docs/research/executable-workflow/operator-decisions.yaml` — their repo
- AEF write-set derivation: `docs/research/executable-workflow/arc0-write-set.md`
- Frozen v1 contracts: `docs/research/executable-workflow/contracts/v1/`

— 999-AEF (T-3394, arc-019 `ewcr-arc0-contract-evidence`)
