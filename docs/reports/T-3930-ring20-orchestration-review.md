# T-3930 — AEF stakeholder review of ring20 T-2250 orchestration concept

Reviewer: AEF (999), stakeholder panel seat 5A.4. Input: concept page as served 2026-10-06 (already v0.3:
§4R + §5E supersede §4 / §5B; reviewed against both). Every AEF claim below was checked in source on
`bleeding-edge` today, not taken from names.

## 1. Summary verdict

**Build S-1, with three corrections.** The shape (deterministic supervisor, judging orchestrator, provisioned
one-shot workers) is right, and §4R plus §5E have already absorbed most of what we would have said. Our main
disagreements are about dependencies on AEF:
(a) arc-012 cannot carry Scope A today: the loop is stopped and its own fix-or-abandon inception is open.
(b) Most of AEF's enforcement is Claude Code hooks. That reaches neither your non-Claude workers nor a
supervisor written as a script.
(c) `fw orchestrate` / "T-1624" does not exist anywhere in AEF and is not planned. Do not wait for it.

## 2. Section-by-section feedback

**F1 — §4R.1 / §5B.1.1, supervisor as a composition of existing gates.**
Observation: the gates you compose sit in three projects with three trust models: ring20 claims, AEF hooks
and git hooks, and SMA cred-gate.
Risk: a composed gate is only as strong as its weakest member. Several AEF members fire only when Claude Code
calls them (F2).
Suggestion: the supervisor should call each gate explicitly through its CLI, and never assume a gate fired just
because a worker ran. AEF hooks already work this way. `bin/fw hook <name>` takes the tool-call JSON on stdin
and returns its verdict through the exit code; we verified it outside Claude. A non-Claude supervisor can
therefore run `check-tier0` / `check-active-task` before every spawn and effect. That is the cheapest
"adapter".

**F2 — §5B.2.1 / §5C.3, enforcement escape. Here is what AEF actually enforces, and where.**

| Class | Mechanism (path) | Reaches non-Claude workers? |
|---|---|---|
| fw-CLI gate | task close gates P-010/P-011, verdict ledger (`agents/task-create/update-task.sh`, `lib/verdict_ledger.py`); dispatch worker cap and the review-only rule for codex/opencode/antigravity (`agents/termlink/termlink.sh:428`, `:899-901`); `fw continuous arm` halt refusal (`lib/continuous-mode.sh:302`) | Yes, if they go through `fw` |
| git hook | commit-msg task ref, master guard, pre-push force/delete approval (`agents/git/lib/hooks.sh`, `master-guard.sh`) | Yes, but `--no-verify` or a `core.hooksPath` override skips them |
| Claude Code hook only | task gate on Write/Edit, Tier 0 text gate, budget-gate, check-paid-backend, Human-AC tick, dispatch-limit, **and the continuous-run Stop driver itself** (`agents/context/stop-driver.sh`) | **No** |
| Advisory | CLAUDE.md rules (worktree opt-in, dispatch-by-default), `fw write-set check` (exits 2 on every real pair) | No |
| Out-of-harness, designed, **not installed** | arc-013 OS sandbox plus payload proxy (`policy/sandbox-profile.yaml`, `lib/govd_*.py`). `fw sandbox status` → "emitted but not installed" | Would, once installed |

To be candid about §5C.3: no AEF task owns "framework plugins per harness". AEF's design-of-record for
harness-independent enforcement is arc-013 (an OS cage below the agent), not a plugin per vendor.
Suggestion: S-1 should depend on neither. Keep write-capable bindings claude-only, as you planned. Get
isolation from controls ring20 owns: an unprivileged uid, writes limited to the worktree, and merges done by
the supervisor (§5E.1.1). That is already the arc-013 floor in miniature.

**F3 — §4R.4.1 / §5E.1.6, "unknown blast radius ⇒ blocked".**
Risk: this blocks almost everything. In AEF, blast radius comes from `components:`, which is only resolved
when a task is closed. 85% of rankable tasks therefore have no cost term (T-3471). Ring20 runs the same
framework and will hit the same wall.
Suggestion: compute pre-work risk from a `write_set:` declared at capture (T-3512 frontmatter). Treat "no
write_set" as unknown, which is correct, and make declaring it part of the orchestrator's queue intake. Without
this, the S-1 acceptance queue only works on hand-made fixtures.

**F4 — §4R.3.3 / §5E.1.2, commission ledger and a results channel bound to the launched process.**
AEF already has append-only `.context/dispatches.jsonl` (3,400 rows) with `dispatch_id`, `parent_dispatch_id`,
`worker_kind` and `task_type`, plus `dispatch-outcomes.jsonl`. Review dispatches are additionally HMAC-signed at
registration (`.context/reviews/review-dispatches.jsonl`) and signed again on completion.
Suggestion: key commissions to the `dispatch_id` that `fw termlink dispatch` emits, rather than starting an
unjoinable third ledger. Borrow the signed-registration and signed-completion pattern for 5E.1.2. Caveat
(T-3581): the signing only means something when the worker runs under a different uid from the key holder.
Your isolation work is what makes it bite.

**F5 — §4R.4.2 / §5E.1.4, caps by atomic reservation.**
AEF's worker cap is count-then-launch with no lock (`termlink.sh:428-440`), so two concurrent dispatchers can
both pass. `.continuous-mode.yaml` is project-wide and unlocked, and carries no agent id (confirmed). Your
exclusive ledger lease is stricter than anything AEF has. Do not assume our cap satisfies 5E.1.4; reserve in
your ledger. `lib/keylock.py` / `lib/keylock.sh` (flock over `.context/locks/`) gives you a primitive that both
shell and Python callers can contend on.

**F6 — §2.2 Scope A, arc-012 as the loop.** See §3.

**F7 — §4R.6 / §5B.1.3, standing workers deferred, and a worktree per commission.**
We agree with deferring standing workers and with not starting with the commit agent. We would warn about the
worktree side. Our operator made worktrees opt-in only (CLAUDE.md §Worktree Policy) after repeated damage:
commits stranded in torn-down directories, and `.claude/worktrees/*` surviving after leaving `git worktree
list`.
Suggestion: make "no worktree outlives its commission row" an S-1 acceptance test. Reconcile directories
against the ledger, and reclaim by content comparison (`lib/worktree.sh`, `fw worktree gc`) rather than by
`git cherry`.

**F8 — §4R.2.3-4, bindings by `review-backends.yaml` id.**
This is good reuse. "Allowed vs enabled" already exists mechanically: non-Claude kinds are refused unless
`--task-type review`. The registry has no `max_data_class` field, though, and it is operator-owned AEF data.
Suggestion: propose `max_data_class` per backend upstream, so cost gating and class gating read one registry
instead of a ring20 side-table drifting from ours.

**F9 — §5E.2 / §5D.1.4, egress.**
We agree it needs a standing ruling per class and vendor. One caution: `check-paid-backend` is a hook that sees
typed commands only. A supervisor script that launches codex is invisible to it. Your class gate must sit
inside the supervisor's mandatory dispatch path, not in a hook.

**F10 — §5C.4, identity.**
Correct: circuit ids give attribution, not authentication (`lib/sidecar/circuit.py`, arc-020
`lib/aef_circuit.py`). Add `lib/worker_identity.py` (T-2917). It gives each dispatched worker a distinct git
author and committer, which makes your `effect_marker` checkable from a bare `git log`.

**F11 — §5C.6, cap on review rounds.**
AEF has no such cap today, and the refusal ledger (T-3555) is captured but not built. The pickup is valid; we
will file it. Enforce it locally in S-1, as 5E.1.4 says.

**F12 — §4R.10 S-1 acceptance.**
"Hand-back schema-valid" is too weak. AEF measured 1,339 dispatches: build verification passes 30%, and
inception passes 0% (122 runs) (CLAUDE.md §Execution Model).
Suggestion: count a completion only when the task's own verification passes. A `fw outcome evaluate`-style
evaluator (`lib/outcome.py`) does this. Also add a hard rule: never commission inception or exploration work.

## 3. Fit with arc-012 and "T-1624 `fw orchestrate`"

- **arc-012 today.** `fw continuous status` returns STOPPED, with the directive lapsed since 2026-09-04. M1 caps
  at one continuation (T-3240). The arc's close task T-3895 is a captured, unfilled inception asking whether to
  "fix or honestly abandon". The loop driver is a Claude Stop hook, so it cannot drive a non-Claude
  orchestrator at all.
- **"T-1624" is an id collision.** In AEF, T-1624 is an unrelated hub.secret refresh. No AEF task, pickup or
  code exists for `fw orchestrate` (T-3922 triage reached the same finding).
- **Proposed ownership.**
  - ring20: registry data, cards, orchestrator, commission ledger v1, supervisor v1 in `scripts/`.
  - AEF: transport (`fw termlink dispatch`), the review ladder and verdict ledger, the backend registry
    including the new class field, gate verbs callable from non-hook code, and arc-012's brake vocabulary
    (halt file, expiry, max_tasks, tier ceiling). Reuse that vocabulary rather than inventing your own.
  - arc-013: OS-level isolation.
  - TermLink: per-agent authentication.
- **The seam.** Your supervisor *is* the deterministic, harness-neutral M1 driver that arc-012 lacks. We
  suggest T-3895 evaluate "arc-012 consumes ring20's supervisor contract" as one of its options. AEF should
  open an inception on upstreaming only after S-1 produces evidence, not before.

## 4. Reuse list (all paths verified to exist)

- R1 `agents/termlink/termlink.sh` — dispatch with a worker cap, worker kinds, review-only enforcement, and
  exit_code / meta.json result files.
- R2 `.context/dispatches.jsonl` + `lib/outcome.py` — the dispatch_id ledger, outcome evaluation and back-prop.
- R3 `policy/review-backends.yaml` + `lib/review_cost.py` + `lib/review_credential.py` — backend registry,
  cost ledger and credential location (never the value).
- R4 `lib/review_policy.py` + `lib/verdict_ledger.py` — the IW-7 rung computation and verdict-closes-criterion,
  with provenance.
- R5 `lib/tier0_action.py` — the action grammar (verb + target keys) for approvals scoped to a commission.
- R6 `lib/continuous-mode.sh` + `agents/context/stop-driver.sh` — the brake order (halt, expiry, caps) to copy
  into your supervisor.
- R7 `lib/keylock.py` — flock-based leases shared between shell and Python.
- R8 `lib/worker_identity.py` — a distinct git identity per worker.
- R9 `lib/sidecar/circuit.py`, `lib/aef_circuit.py` — circuit addressing and lifecycle.
- R10 `lib/dispatch_pause.py` + `lib/retry_ladder.py` — the pause-to-operator chain (maps to your
  awaiting-approval state) and the message retry ladder.
- R11 `lib/write_set.py` — write-set overlap and convergence, including the implicit framework-state
  write-set.
- R12 `policy/sandbox-profile.yaml` + `lib/govd_sandbox.py` — uid demotion, a read-only substrate and an
  egress-pinning profile to start from for §5E.1.1.
- R13 `policy/designer-pin.yaml` — the existing AEF↔832 pin-at-tag contract, a model for registry
  id@version→sha pinning.
- R14 `policy/review-worker-settings.json` — a locked-down settings file for Claude workers (no project MCP,
  inbound refused).

## 5. Open questions back to ring20

1. Which concrete ring20 task id should AEF reference for `fw orchestrate`, now that "T-1624" collides with
   ours?
2. Will S-1 key commissions to AEF `dispatch_id`, or do you need a reason to keep a separate id space?
3. Where will S-1 get pre-work blast radius (F3): `write_set:` at capture, or something else?
4. Would ring20 accept arc-013's sandbox profile as the S-1 isolation baseline, and co-test `fw sandbox
   install` on ring20?
5. Should arc-012's T-3895 adopt your supervisor as its M1 driver? (This is a question for both operators.)
