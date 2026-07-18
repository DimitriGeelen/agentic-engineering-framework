# T-2541 — Write-out Promotion Inception (AEF compiler-side half)

**Status:** inception / exploration — NO build artifacts until Dimitri's go/no-go.
**Joint with:** 832 `T-201` (write-out mode inception, sovereign side). This artifact is the
**AEF-compiler half**; 832's `T-201` is the design+ratify authority. Single go/no-go, Dimitri's.
**Owner:** human (Dimitri). **Recommendation:** DEFER (pending spikes) — advisory leans GO-contingent.

> This is an inception/exploration task. The thinking trail below IS the artifact; it is updated
> incrementally as the dialogue and spikes produce findings (C-001). No `.tasks/`-writing capability
> is built here.

## The one question

**Can the write-out *promotion* guardrails be made MECHANICAL GATES on the AEF side — not conventions —
and what compiler-side seam does that require?**

"Promotion" = turning a staged BPMN proposal (T-2539: `.context/bpmn-staged/<diagram>/<uid>.md`,
`status: proposal`, zero `.tasks/` writes) into a real `.tasks/` task file. That write is the exact
act the Core Principle ("nothing gets done without a task") and the Authority Model exist to govern:
a compiler emitting real task files is a tool authoring governance artifacts (IW-1/IW-3). So the
question is not "is promotion useful" — it's "is every guardrail a gate, or is any of them merely a
convention an agent could skip?"

**GO** only if every guardrail below is enforced by a structural gate. **NO-GO** (promotion stays
proposal-only, T-2539 is the terminal capability) if any guardrail can only be a convention.

## Context — how we got here

- T-2538 (GO): staging-mode governance inception → `--write` stages **proposals**, not tasks (candidate C).
- T-2539 (shipped): `fw bpmn compile --write` writes uid-keyed proposals to `.context/bpmn-staged/`.
  Dry-run is the default; staging is idempotent (upsert by `aef:uid`, stale pruned); **no `.tasks/`
  write, no T-ID allocation, no gate crossed.**
- Dimitri's steer (rail offset 56, via 832): **write-out proceeds INCEPTION-FIRST, sequenced NEXT.**
  A GO to open *this* inception, NOT a build green-light. Guardrails named on the table: dry-run
  default, explicit `--write`, emitted tasks land `owner:human` + `status:captured` (nothing
  auto-activates), staging/confirmation. Go/no-go on the capability stays his.
- 832 (rail offset 56): "Ownership/mechanism (832-emits-bundle vs AEF-compiler-writes, which `.tasks/`
  root) is inception content, not yet settled — don't build against a fixed assumption; the inception
  will surface the seam and we'll converge on the rail. Your input on the compiler-side seam will be
  wanted during exploration."

## The guardrails, mapped to AEF gates (the load-bearing analysis)

The claim to test per-spike: each guardrail already corresponds to an EXISTING AEF mechanical gate, or
it doesn't. Convention ⇒ NO-GO for that guardrail.

| # | Guardrail | Candidate AEF gate | Mechanical today? |
|---|-----------|--------------------|-------------------|
| G1 | Dry-run is the default; writing requires explicit `--write` | CLI flag parse (T-2539 already: stdout default) | **YES** (staging leg proven) |
| G2 | Promoted tasks land `owner: human` + `status: captured` — nothing auto-activates | `create-task.sh` field-set at write; horizon/status invariants (T-1068) | **Likely** — needs spike: does the promote path set these unconditionally, un-overridable? |
| G3 | The **write seam** — the `.tasks/` write goes through the task-gate, not around it | PreToolUse `check-active-task` gates Write/Edit on `.tasks/`; `fw task create` is the governed writer | **Load-bearing UNKNOWN** — see seam fork. If a non-fw path writes the file, G3 is a convention. |
| G4 | Idempotent re-promote (same uid → update, not duplicate T-ID) | uid↔T-ID cross-ref registry (does not exist yet) | **NO** — the id-mapping contract (832 IW-2) is unbuilt. Spike required. |
| G5 | Provenance — each promoted task carries `aef:uid` + source `.bpmn` | frontmatter field + fabric register | **YES** (field is trivially settable; needs schema slot) |
| G6 | Build-readiness — a promoted task cannot be *started* without real ACs | G-020 build-readiness gate (already blocks placeholder ACs) | **YES** — already mechanical; this is the safety net that makes `captured` safe |

**Reading of the table:** G1/G5/G6 are already gates. G2 is probably a gate (needs confirmation).
**G3 (the write seam) and G4 (idempotent id-mapping) are the real inception content.** Everything
hinges on G3.

## The seam fork (AEF compiler-side input — my initial hypothesis, to be tested)

**Option A — 832-emits-bundle:** 832's designer emits a self-contained task bundle; some importer
writes `.tasks/` files. *Risk:* if the importer is not AEF's governed writer, the write skips the
task-gate → G3 becomes a convention. Content authority sits with 832 (correct), but the WRITE must
not leave AEF's gate perimeter.

**Option B — AEF-compiler-writes:** `fw bpmn promote <uid|all>` writes `.tasks/` files directly.
*Risk:* if promote calls the filesystem directly instead of routing through `fw task create`, it
reintroduces the same ungated-write hole T-2539 was built to avoid.

**Hypothesis (my lean, NOT a settled decision):** the fork is a false binary — the answer is a
**hybrid at a clean interface, and the interface is the proposal manifest that already exists**
(`.context/bpmn-staged/<diagram>/manifest.yaml`, uid-keyed, from T-2539):

- **832 owns CONTENT** — what tasks, what ACs, what lanes/owners. That's design authority (their side).
  The manifest (or a 832-emitted bundle that lands *as* proposals) is the content hand-off.
- **AEF owns the gated WRITE** — `fw bpmn promote` reads the manifest and calls **`fw task create`**
  (the governed writer) per uid, forcing `owner: human` + `status: captured`, stamping provenance.
  The write inherits `create-task.sh`'s gates + G-020 for free.

Under this hypothesis, G3 is satisfied because promote never touches `.tasks/` directly — it delegates
to the one writer that is already gated. The seam is the manifest; content is 832's, the write is
AEF's and gated. **This must be proven by Spike 1, not assumed** — if `fw task create` cannot be
driven programmatically with forced `owner:human/captured` un-overridably, the hypothesis fails and we
revisit.

## Open Questions (mirrored from the task file — G-067)

- **IW-1 (seam):** Does routing promote through `fw task create` keep the `.tasks/` write inside the
  task-gate perimeter end-to-end, with `owner:human`+`status:captured` un-overridable by the caller?
  (confidence 1, deferred → Spike 1)
- **IW-2 (id-mapping):** What is the uid↔T-ID cross-ref contract for idempotent re-promote (G4)? This
  is 832's IW-2 (rail offset 48) — their contract to define; AEF stores the mapping. (confidence 0,
  deferred → Spike 3)
- **IW-3 (root):** Which `.tasks/` root do promoted tasks land in — `active/` (captured) directly, or a
  quarantine the human confirms out of? Dimitri's guardrail says `captured`; does `captured` in
  `active/` + G-020 suffice, or is a separate confirm step needed? (confidence 1, deferred → Spike 2)

## Spikes (time-boxed — NEXT session, need 832 seam convergence + Dimitri review)

1. **Seam spike (IW-1, ~1h):** prove `fw task create` can be driven from a promote path with forced
   `owner:human`+`status:captured`, provenance stamped, write gated. Deliverable: one promoted task
   from a fixture proposal, showing the gate fired.
2. **Root/confirm spike (IW-3, ~45m):** does `captured` in `active/` + G-020 give "nothing
   auto-activates", or is an explicit human-confirm transition needed? Test against the horizon
   invariants (T-1068).
3. **Idempotency spike (IW-2, ~45m):** design the uid↔T-ID registry so re-promote updates in place;
   converge the contract with 832 on the rail (their IW-2).

## Assumptions (registered)

- **A1:** `fw task create` (`create-task.sh`) is the sole governed `.tasks/`-writer and can be invoked
  programmatically with field overrides. (Validate in Spike 1.)
- **A2:** `captured` + `owner:human` + G-020 build-readiness is sufficient for "nothing auto-activates"
  without a bespoke confirm step. (Validate in Spike 2.)

## Go/no-go criteria

- **GO** iff G1–G6 are each a structural gate (Spike 1 proves G2/G3; Spike 3 designs G4; G1/G5/G6
  already gates) AND the seam converges with 832 on the rail.
- **NO-GO** if any guardrail can only be a convention (esp. G3 write seam) — promotion stays
  proposal-only; T-2539 staging is the terminal capability and BPMN→AEF stops at proposals a human
  hand-promotes.
- **Decision authority:** Dimitri (joint with 832 T-201). This artifact produces a recommendation only.

## Dialogue Log (C-001 extension)

- **Rail offset 49–50 (832):** VETOed name-only-Human leniency (→ AEF T-2540, shipped); flagged PL-035
  (audited clean on AEF side). Item 4: write-out is Dimitri's call, don't build.
- **Rail offset 53 (832):** T-197 editor owner-retire shipped; vendored 0.2.0 pin unchanged; T-200
  release is human-owned.
- **Rail offset 54–55 (AEF):** VETO honored + PL-035 audit reported; confirmed holding on write-out.
- **Rail offset 56 (832, relaying Dimitri):** write-out = **inception-first, sequenced next**. Not a
  build GO. Seam unsettled; AEF's compiler-side seam input wanted during exploration. → this inception.

## Recommendation

**DEFER** — pending the 3 spikes. This is a genuine evidence gap (no spike data yet), not a confidence
hedge: the whole point of the inception is that G2/G3/G4 enforceability is unproven. Advisory leans
**GO-contingent** — G1/G5/G6 are already gates and the seam hypothesis (manifest interface + delegate
to `fw task create`) looks mechanizable — but the recommendation converts to a firm GO/NO-GO only after
Spike 1 proves the write seam is gated. Flips to **NO-GO** the moment a spike shows any guardrail can
only be a convention.
