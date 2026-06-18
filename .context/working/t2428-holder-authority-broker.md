# T-2428 / T-2430 — privileged state-holder as AUTHORITY BROKER (capture)

Captured 2026-06-18 at budget-gate wrap (315K). **Owed next session:** fold into
design doc as **§4e** + enrich **T-2430** body. (Both blocked this turn — docs/ is
a source path the budget gate blocks; T-2430 Edit is blocked by the worktree
check-arc-id hook reading main's arcs dir.)

## The refinement (operator turn)

My binary "agent-proposes / sovereign-commits" partition was too coarse. The
holder is a **policy-driven authority broker** implementing the full tier ladder
(0/1/2/3), not a binary gate.

The "trust partition" is a **sovereign-authored envelope** in RO substrate (agent
can't edit it). Per decision the holder asks: *given type + parameters, who may
commit, at what log-tier?*

| Tier | Who commits | Example | Logged |
|---|---|---|---|
| 0 consequential | sovereign only, ALWAYS (hard ceiling, never delegable) | force-push, rm -rf, directive payload | — |
| 1 standard | agent, within task gate | normal edits | normal |
| 2 situational | agent commits, prominently logged | focus-drift override, bypass | Tier-2 audit |
| 3 pre-approved | agent commits autonomously, WITHIN envelope | low-blast inception GO | Tier-3 audit |

## Envelope structure — DECIDED: global ceiling + per-type overrides

```yaml
authority_envelope:            # sovereign-authored, RO substrate
  global:                      # default bound, all decision types
    max_blast_radius: 2        # BVP cost_estimate.blast_radius
    min_voi_score: 0.5
    scope: internal            # internal | cross-project | external
  overrides:                   # per-type; tighten / loosen / hard-deny
    inception_go:    { max_blast_radius: 2, min_voi_score: 0.5 }
    dispatch_approve:{ max_blast_radius: 1, require_disjoint_write_set: true, max_tier: 1 }
    tier0_approve:   { delegable: false }   # hard ceiling
    directive_author:{ delegable: false }   # D1/D3 — sovereign only
    focus_change:    { delegable: true }    # initiative — auto-commit + record
    bypass_log_append:{ delegable: true }   # append-only
```

**Evaluation:** resolve effective rule = `overrides[type] ?? global`; per-type
wins over global; Tier-0 + directive are a hard floor no override can loosen.
Check params → within → agent-commit + log at tier; exceeded → queue to human.
Append to audit log regardless.

## The invariant that keeps it safe

> **The agent commits WITHIN the envelope; the agent cannot change the envelope.**

Envelope is sovereign-authored, in RO substrate (S4). Autonomy is real but
bounded; the bound is un-self-modifiable. This is the middle between the two
failure modes: everything-sovereign-gated (kills the arc-012 autonomous loop) vs
agent-fully-authoritative (the A5/D7 hole).

## Worked example (reuses BVP fields already on these tasks)

- exploration `target_blast_radius: 1` → `fw inception decide … go` → within
  envelope → agent commits, Tier-3 logged. No human round-trip.
- **T-2428 itself** `target_blast_radius: 7` → beyond → holder queues to human.
  (Correct — high-blast stays sovereign.)

Same mechanism as the bounded-autonomy ceiling (T-2367, arc-012), generalized
into the holder for every decision class.

## Antifragile feedback loop

Every in-envelope commit is logged (append-only, agent-can't-erase). The sovereign
reviews the agent's autonomous decisions and **tunes the envelope** — tighten on
bad calls, widen as trust builds. The envelope is a dial the sovereign turns on
observed judgment.

## The inversion principle (prior turn, also owed to §4e)

Authoritative governance state = the **holder's record**; files become **read-only
projections**. Writing a file no longer *means* anything to governance — only a
holder-recorded event does. This is why task files / focus-choice / captures can
stay agent-RW: they no longer carry authority.

## Shape (prior turn)

Small daemon `aef-govd` (uid `aef-gov`), in the trusted zone outside the cage with
the proxy. State store RO-bind-mounted into the cage (free reads, no forging);
propose channel = unix socket (agent submits); commit = sovereign-principal only;
append-only audit. Keep it SMALL — it's the TCB.

## Three-in-one (why it's the keystone)

A5 fix + proxy/sandbox trust root + sandbox fs-boundary enabler (T-2430 precedes
T-2433). Structural home for D7 (dispatch self-approve), D1/D3 (directive), bypass-
log integrity.
