# T-2538 — Child-2 write-out mode: how do compiled BPMN skeletons become governed AEF tasks?

**Type:** inception (exploration → go/no-go)
**Focus:** should the Child-2 forward compiler gain a mode that turns its stdout skeletons
into real, persisted AEF tasks — and if so, through what governance-respecting contract?

---

## Problem Statement

The Child-2 forward compiler (`tools/bpmn_to_tasks.py`) today reads one `.bpmn` and prints
AEF task-**skeleton** frontmatter to **stdout**. That is the last-mile gap: you can *see* the
tasks a diagram implies, but you cannot *use* them without hand-copying each block into a
`.tasks/active/T-*.md` file. "Write-out mode" would close that gap.

But the framework's Core Principle is **"Nothing gets done without a task,"** enforced
*structurally* — task creation is gated (`check-active-task`, G-020 AC-readiness, T-ID
allocation via the task-create agent, template compliance). A compiler that writes straight
into `.tasks/active/` would **bypass every one of those gates**. So write-out mode is not a
mechanical "also write a file" feature — it is a governance-boundary design question. That is
why this is an inception, not a build.

## The tension, precisely

A compiled skeleton and a governed AEF task differ in four load-bearing ways:

| Dimension | Compiled skeleton (today) | Governed AEF task |
|-----------|---------------------------|-------------------|
| **Identity** | `id: <aef:uid>` (BPMN-native, e.g. `n_inception`) | `id: T-NNNN` (allocated by task-create) |
| **ACs** | `# [NEEDS-FILL]` placeholder | Real ACs (G-020 blocks placeholders from build) |
| **Entry** | print to stdout | created via `fw task create` (gated) |
| **Lifecycle** | none | captured→started→completed, episodic, handover |

Write-out mode has to bridge all four **without** letting a diagram silently manufacture
"work that gets done" outside the task system's structural enforcement.

## Constraints (hard)

1. **C1 — Must not bypass the task gate.** Direct writes to `.tasks/active/T-*.md` would let a
   `.bpmn` file create governed tasks with zero human/agent authorship — the exact class
   Pickup Message Handling (G-020) exists to prevent ("a detailed spec is a proposal, not
   authorization").
2. **C2 — Must not fabricate ACs.** Emitted skeletons carry `[NEEDS-FILL]` ACs. G-020 would
   (correctly) block them from `started-work` anyway. Write-out must not paper over this.
3. **C3 — Must be idempotent on re-compile.** A diagram is edited and recompiled repeatedly.
   IW-1 (`aef:uid`) is the stable identity precisely so the second compile can tell
   *modify* from *create*. Write-out must upsert by uid, never duplicate. (IW-3)
4. **C4 — ID mapping is a JOINT contract with 832.** 832 owns the reverse direction
   (tasks→diagram). If AEF allocates a `T-NNNN` and keeps the `aef:uid` as a cross-ref, 832's
   reverse-map must read that mapping. The uid↔T-ID binding cannot be decided unilaterally. (IW-2)
5. **C5 — Project isolation (T-559).** Nothing here reads 832's repo directly; the contract
   flows over the rail.

## Candidate approaches

- **A — Direct write.** Compiler writes `.tasks/active/T-*.md` itself.
  *Rejected:* violates C1 outright. Bypasses task-create, ID allocation, the AC gate, and the
  Core Principle's structural enforcement. This is the anti-pattern, not the design.

- **B — Drive `fw task create` per skeleton.** Compiler shells out to the task-create agent
  for each node (allocates T-ID, applies template, respects the gate).
  *Viable but heavy:* every node becomes a real `captured` task immediately. A 24-node diagram
  floods `active/` with placeholder-AC tasks that then trip G-020 the moment anyone touches
  them. Governed, but it conflates "the diagram proposes these" with "these are now tasks".

- **C — Staged proposals (lean here).** Compiler writes skeletons to a **staging area**
  (`.context/bpmn-staged/<diagram>/`) as *proposals*, plus a manifest keyed by `aef:uid`. A
  human/agent reviews and **promotes** selected proposals via `fw task create` (which
  allocates the T-ID, records the uid cross-ref, and passes the gate). Re-compile upserts the
  staging manifest by uid (C3). Proposals are **not tasks** until promoted — so C1 holds by
  construction, and this mirrors Pickup governance (specs are proposals).

- **D — Emit a review script.** Compiler emits a runnable `fw task create …` command list the
  operator reviews and runs. Maximally transparent, zero bypass, but no persistence/idempotency
  layer — it's C without the manifest. Good as a *sub-mode* of C (`--emit-commands`).

## Preliminary lean

**C (staged proposals) with D as a sub-mode**, and an explicit uid↔T-ID cross-ref recorded at
promotion time. This is the only candidate that satisfies C1–C3 by construction and leaves C4
(the id-mapping contract) as a clean, single question to settle with 832 over the rail. It
also reuses the framework's own idiom: the compiler is a *proposer* (initiative), promotion is
the *authorized* act (the task gate), exactly matching the Authority Model.

## Recommendation (advisory — mirrored in the task `## Recommendation`)

**GO** to build write-out mode as **staged proposals (candidate C)**, in two slices:
1. **Staging slice (unblocked, AEF-only):** `--write` emits proposals + a uid-keyed manifest to
   `.context/bpmn-staged/`. No task-gate interaction; nothing becomes a task. Idempotent upsert.
2. **Promotion slice (gated on C4/IW-2):** `fw bpmn promote <uid|all>` runs proposals through
   `fw task create`, recording the uid↔T-ID cross-ref. Blocked until 832 confirms the id
   mapping over the rail.

NOT-GO on candidate A (direct write) — it is the structural-bypass anti-pattern this whole
inception exists to reject.

This is **GO, not DEFER**: the go/no-go on *whether and how* to build write-out is answerable
now (candidate C, staged). Only the *promotion sub-slice's id contract* (IW-2) is a genuine
evidence gap, and it is deferred at the question level, not the decision level (T-2144 —
DEFER is for evidence gaps, not confidence hedges).

## Dialogue Log

### 2026-07-13 — autonomous inception under standing directive
- **Trigger:** operator standing directive ("focus on workflow design integration, work and
  communicate with workflow designer agent"). Child-2 slices 1–3 + O-3 fail-fast (T-2537) all
  shipped; write-out is the next AEF-side slice on the AGENT.md roadmap.
- **Course:** framed write-out NOT as a file-emit feature but as a task-gate boundary question
  — because "nothing gets done without a task" makes direct-write a Core-Principle violation.
- **832 dependency:** the uid↔T-ID mapping (C4/IW-2) is a joint contract; surfaced to 832 at
  rail offset 48 ("what's the next integration surface — write-out mode … or something else?").
  The staging slice does not depend on their answer; the promotion slice does.
