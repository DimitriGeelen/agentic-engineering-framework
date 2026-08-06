# T-2822 — Worktree policy: what may live inside a worktree

**Type:** inception · **Opened:** 2026-08-06 · **Status:** exploration in progress

Created before research per C-001. Updated incrementally; the thinking trail is the
artifact, and this file — not the conversation — is what survives.

## The question

> **What may live inside a worktree — source only, or shared governance state?**

Everything else in this inception falls out of that answer.

## Why this is a decision and not a task

Two contradictory premises are live in the codebase at once:

| Premise | Built on it |
|---|---|
| Governance state should follow you into the worktree | `fw_reanchor_from_cwd` (T-2464), worktree-aware audit/doctor (T-2435, T-2437), budget-gauge worktree fixes (T-2375, T-2377, T-2400) |
| Governance state lives only in the main checkout | CLAUDE.md §Trunk-Based Session Flow (T-100196) — session on master, worktrees for landing source |

Each is coherent alone. Holding both produces defects at the joins, which is the
shape of the incident record.

## Origin

The operator's question, verbatim:

> *"ok but why are we creating a worktree from start, thouigh we discussed only doing
> this is special circumstanced, pelase readback teh diacussiuona and decsioin we had
> for thsi (especially because we had somemany worktree isseus)"*

The readback found only **two** recorded worktree decisions in `decisions.yaml`
(:168 WorktreePool for audits; :2149 integrate cleanup). Neither authorises ambient
isolation of a governance session. `.claude/settings.json` has **no `worktree` key** —
so the `bgIsolation` behaviour that deadlocked the fresh-project session is a *harness
default AEF never chose*, not an AEF decision. That is the second question (IW-2).

## S1 — Corpus mine

*Status: running. Table lands here.*

## S2 — Source-only spike

*Status: not started.*

## S3 — Shared-state spike

*Status: not started.*

## Dialogue Log

**2026-08-06 — operator asks whether to incept.**

> *"ok what now, whjat do we do to better implement teh worktreeu usage when its
> reall yasneeded thinking?"*

Agent proposed five items (source-only gate, disable ambient isolation, preflight at
`fw worktree create`, deterministic cleanup + doctor surfacing, lifecycle testing) and
recommended **building none of them yet**, because items 1 and 2 are a genuine
either/or and building the wrong one is how the current state accumulated.

> *"should we incpet this and deep researcha nd etst this ?"*

Agent: yes. Reasoning recorded at the time — (a) it is a fork, not a task, and the two
premises above are demonstrably both live; (b) the evidence base already exists in
episodic memory, so this is a corpus *read*, not a discovery project. Scoped to one
question per §Task Sizing Rules; T-2821 fenced out because it is a bug under either
policy and is nearly done.

## Findings

*Populated as spikes complete.*

## Recommendation

*Pending S1. Filed DEFER at creation — a genuine evidence gap, not a hedge: no spike
has run.*

**Prior (to be killed or confirmed, not assumed):** source-only, with governance
writes structurally refused inside a worktree. It matches T-100196 and removes the
split rather than managing it. Recorded here explicitly so S1–S3 can falsify it.
