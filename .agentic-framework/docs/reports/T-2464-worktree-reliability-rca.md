# T-2464 — Worktree reliability: systemic RCA + path

**Status:** inception (exploration)
**Date:** 2026-06-23
**Origin:** operator question — "are we systemically fixing the worktree issues, parallel working, merging back? Do we have a clear RCA and path to making this work reliable in the framework?"

## Verdict

**No — not yet systemic.** Two distinct problems, both currently un-systematized:

1. **Root-resolution defect (recurring bug class)** — patched per-surface 7+ times, never centrally.
2. **Parallel-work / merge-back lifecycle (feature gap)** — zero framework support; done by hand each time.

T-2463 (this session) is a *prototype* of the fix for (1) on one hook. It is not the general fix.

---

## Problem 1 — Root-resolution defect (one root, many symptoms)

### Mechanism

Framework hooks are wired into Claude Code `settings.json` by **main's absolute path**:

```
/opt/999-Agentic-Engineering-Framework/bin/fw hook <name>
```

When a hook fires inside a **worktree** (or a **spawned** session), `bin/fw` resolves
`PROJECT_ROOT` from the **hook process's cwd** (the launch/main dir) or **inherited env**
(`CLAUDE_PROJECT_DIR`), *not* from the per-call session context. So the hook reads the
**wrong project's** state — main's `focus.yaml`, `/root`'s budget, the wrong `.tasks/`.

The agent's *own* `bin/fw` tool commands run with cwd=worktree and resolve correctly. The
two never meet — the gate and the work operate on different roots.

### Evidence — same root, patched 7+ times

| Task | Surface patched | Symptom |
|------|-----------------|---------|
| T-2463 | active-task gate | reads main's focus → blocks ALL worktree work when main focus null |
| T-2446 | `CLAUDE_PROJECT_DIR` trust | inherited env points at wrong root (daemon-poison) |
| T-2389 / T-2390 | spawned-session hooks | resolve to `/root` → budget gauge blind |
| T-2392 / T-2400 | budget gauge | `.budget-status` freeze in worktree |
| T-2289 | `lib/paths.sh` | `TASKS_DIR`/`CONTEXT_DIR` not re-derived on root change (OBS-053) |
| T-2054 / T-2462 | active-task gate safe-list | git push/fetch/commit had to be exempted because the gate kept misfiring in worktrees |

This is whack-a-mole. Each fix re-implements "figure out the real root" locally. The
framework already has the primitive — `fw_is_linked_worktree` (`lib/paths.sh:144`) — but
nothing forces hooks through a single resolver.

### Systemic fix shape

- **One shared per-call resolver** every hook calls first: read stdin `cwd` (Claude Code
  passes "working directory when the event fired") → walk up to project root → honor
  `fw_is_linked_worktree` to distinguish "main's own linked worktree" from "genuinely
  different repo" (the T-2446 daemon-poison boundary). Re-anchor `PROJECT_ROOT` +
  `FOCUS_FILE` + `TASKS_DIR` + `CONTEXT_DIR`.
- **Suite-level worktree test** — run the *whole* hook suite under a simulated worktree
  invocation (PROJECT_ROOT=main, stdin cwd=worktree), not one hook at a time. The bug
  lives at the join; per-hook unit tests miss it (L-399 producer/consumer class).
- T-2463's re-anchor block is the prototype to generalize; the safe-list exemptions
  (T-2054/T-2462) may become unnecessary once resolution is correct.

---

## Problem 2 — Parallel-work / merge-back lifecycle (feature gap)

No framework guardrails exist for creating, tracking, or reconciling worktrees. All hit
**live this session**:

- **master locked in another worktree** — `git checkout master` in main dir is forbidden
  (`livefire-t2389` holds it). No helper routes around this.
- **main dir on a session branch** (`t2417-fw-sessions`), not master — so "merge to master"
  does **not** make the fix live on this host. "Live" semantics are invisible.
- **FF path ambiguity** — operator had to ask whether FF was even possible; no `fw` verb
  answers "can this merge back cleanly / is it live."
- **vendored `+x` loss** — `.agentic-framework/agents/context/*.sh` lost executable bit;
  bare `fw` shim hits "Permission denied" (observed, unfiled).

### Lifecycle fix shape (candidate)

A `fw worktree` workflow:
- `create` — branch-naming convention + auto vendor-sync + preserve `+x`
- `status` — which worktrees exist, which branch the main dir is on, per-worktree
  merged?/live? state, master-lock awareness
- `merge-back` — FF helper that handles the master-locked case (push-to-ref or merge in the
  holding worktree), syncs vendored copies, and confirms whether the fix is **live** on this
  host's on-disk hooks
- **doctor coverage** — surface worktree drift (stale, unmerged, not-live, +x loss)

---

## Candidate decompositions (for GO)

- **A — Resolution only.** Generalize T-2463 into a shared resolver + suite test. Smallest;
  closes the recurring bug class. Leaves lifecycle manual.
- **B — Lifecycle only.** Build `fw worktree`. Bigger; doesn't stop the resolution bugs.
- **C — Both, sequenced (recommended).** Resolution first (it's the bleeding wound and the
  prototype exists), then lifecycle. Two arcs/slices under one decision.

## Recommendation

**GO — Candidate C.** Evidence for the resolution root is overwhelming (7+ tasks, one
mechanism). The lifecycle gap is real but lower-frequency; sequence it after the resolver
lands. This is a Level-D "change ways of working" call: worktree-based parallel dispatch is
already in use (arc-011, livefire demos) but the substrate underneath it is not reliable.

## Dialogue Log

- **Operator (msg 1):** "are we rca'ing and systemically fixing" the deeper worktree root.
  → produced T-2463 (point-fix for the active-task gate).
- **Operator (msg 2, this):** "are we systemically fixing the worktree issues, parallel
  working, merging back? Do we have a clear RCA and path to making this work reliable?"
  → escalation from one-symptom to whole-substrate. Honest answer: no; T-2463 is a prototype,
  not the system. Filed this inception (T-2464) to hold the systemic RCA + decide the path.
