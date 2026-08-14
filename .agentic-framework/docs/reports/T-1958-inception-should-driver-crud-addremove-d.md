# T-1958 — Inception: should driver CRUD (add/remove drivers, change weights) belong in

> **Inception research artifact** (backfilled by T-2515 from the `T-1958` task body — the research was captured in-task at decision time; this extracts it verbatim to the canonical `docs/reports/` home per C-001). Source: `.tasks/completed/T-1958-inception-should-driver-crud-addremove-d.md`. **Decision recorded: GO.**

## Problem Statement

A human reviewing the BVP arc on 2026-05-20 said: *"missing ability to add / delete value drivers on top of the 4 base / core drivers, on the arc-006 not seeing any calculation to seeing framework global driver, no ability to add arc specific drivers"*. The framework already implements all of these mechanically — `fw bvp driver --add`, `fw bvp driver --remove`, `fw bvp weight --set`, `fw arc approve-driver` — but they are CLI-only. Watchtower ships only one driver-related write surface: the **live weight sliders** on `/bvp` (T-1929) which call `fw bvp weight --set --from-watchtower` on commit. There is no Watchtower form to:
1. Add a free driver to `policy/value-drivers.yaml`
2. Remove a free driver (D1-D4 protected)
3. Approve an arc-scoped driver from `proposed_scoped_drivers:` (the form *is* shipped on `/arcs/<slug>` per T-1926, so this row is **already done** — only #1 and #2 are gaps)

The trade-off in scope: friction-as-feature (CLI-only) vs. friction-as-bug (UI parity).

## Assumptions

- **A1** — The §ACD agent-gate on `fw bvp driver` would refuse a Watchtower-originated call without `--from-watchtower`. *Verifiable now via `bin/fw bvp driver --add "test" --weight 4 --rationale "..."` under `$CLAUDECODE=1`.*
- **A2** — Watchtower's existing `--from-watchtower` exemption pattern (used by `fw bvp weight` from `/bvp` sliders, by `fw arc approve-driver` from `/arcs/<slug>`, by `fw arc close --from-watchtower` from `/arcs/<slug>/close`) generalises to `fw bvp driver --add|--remove` with no new sovereignty risk. *Source-read of `lib/bvp.sh` and `lib/arc.sh` would confirm.*
- **A3** — The `--rationale ≥30 chars` requirement is sufficient friction for accidental edits — the human types intent in the form before the change persists. (Verified empirically for weights: T-1929 user feedback so far reports no accidental commits.)
- **A4** — A single form per write verb (add/remove) is the right granularity. A bulk-edit table would invite mass changes that bypass the per-row rationale.

Register via:
```
bin/fw assumption add "..." --task T-1958
```

## Exploration Plan

1. **Source-read existing code paths** for `fw bvp driver --add|--remove` to confirm the §ACD gate and rationale requirement are present (verifies A2 in ~3 minutes, no build).
2. **Check `policy/value-drivers.yaml` write shape** — what fields does `fw bvp driver --add` write (id, name, weight, scope, …)? Confirm the form's input set is minimal.
3. **Catalogue existing Watchtower driver-write forms** (already shipped): `/bvp` weight sliders (T-1929), `/arcs/<slug>` approve-driver (T-1926). Confirm the pattern they use is reproducible.
4. **Decide** GO / NO-GO / DEFER based on the trade-off below. If GO, file 1-2 build tasks for the actual forms; do NOT build under T-1958 (inception discipline).

**Time-box:** 30 minutes for steps 1-3, then write Recommendation.

## Technical Constraints

- Forms must be CSRF-protected (Flask `_csrf_token` already shipped framework-wide; the existing `/bvp` and `/arcs/<slug>` forms use it).
- Each write verb must shell out to `bin/fw bvp driver` with `--from-watchtower` — the Flask blueprint does NOT directly mutate `policy/value-drivers.yaml`. This is the T-1929 precedent and preserves the single-source-of-truth contract (CLI is canonical; web is a UI on top).
- Add-driver form must enforce `--drop Dn` when at cap=9 (M1 from arc-006 design). The CLI already enforces this; the form must surface the error gracefully.
- D1-D4 protected — remove-driver form must refuse with a non-confusing message (the CLI already does this; the form must surface it cleanly).
- Rationale ≥30 chars (R6) enforced both client-side (form validation) and server-side (the CLI rejects shorter rationales).

## Scope Fence

**IN scope for this inception:**
- Decide whether to build add/remove driver forms in Watchtower (GO/NO-GO/DEFER)
- If GO, file ONE build task per form (T-NEW-A: add driver; T-NEW-B: remove driver) — keep them small and shippable independently
- Document the decision in `## Decision` for future referencing

**OUT of scope:**
- Implementing the forms (separate build tasks)
- Arc-scoped driver CRUD beyond what `fw arc approve-driver` + the Watchtower form on `/arcs/<slug>` already covers (T-1926 shipped that)
- Bulk-edit tables — explicitly rejected by A4
- A "calculator" UI showing how each global driver applies to each arc — this is a **separate** complaint the user raised ("on arc-006 not seeing any calculation to see framework global driver"). The /arcs/<slug> page already renders a per-driver breakdown table (T-1956 just shipped this above-the-fold). If the human still finds it unclear, that's a separate render task, not a driver-CRUD question.

## Go/No-Go Criteria

**GO if:**
- The §ACD agent-gate is already wired on `fw bvp driver --add|--remove` (so adding a Watchtower form doesn't open a new bypass)
- The `--from-watchtower` exemption pattern from T-1929/T-1926 reapplies cleanly (no new sovereignty review needed)
- The per-row rationale-≥30-chars friction is sufficient to discourage accidental edits

**NO-GO if:**
- The sovereignty boundary at `fw bvp driver` requires a more conservative posture than `fw bvp weight` (e.g. because adding/removing drivers reshapes the scoring schema, not just its weights)
- The CLI-only friction is actually load-bearing — i.e. a human who can't be bothered to open a terminal to add a driver also probably shouldn't be adding one
- The current driver inventory (0 free drivers) is too small to justify the UI surface

**DEFER if:**
- More CLI-driven driver edits are needed first to surface the right form ergonomics
- BVP arc is still landing the basics; UI parity can wait for steady-state

## Recommendation

**Recommendation:** GO — build the add-driver and remove-driver Watchtower forms.

**Rationale:**

All three GO criteria are satisfied:

1. **§ACD agent-gate is already wired** on `fw bvp driver`: `lib/bvp.sh:64-68` refuses under `$CLAUDECODE=1` unless `--i-am-human` or `--from-watchtower`. Adding a Watchtower form does NOT introduce a new bypass — it consumes the exemption the framework already provisioned for exactly this case.
2. **Pattern reapplies cleanly.** T-1929 (`/bvp` weight sliders) and T-1926 (`/arcs/<slug>` approve-driver form) already implement the form-with-CSRF-and-rationale → `bin/fw bvp <verb> --from-watchtower` shape. Add/remove driver is a structurally identical shell-out. Zero new failure modes; the Flask blueprint stays a thin wrapper over the canonical CLI.
3. **Rationale friction is sufficient.** R6 (≥30 chars) is the same friction the CLI imposes. Combined with CSRF + explicit click-to-commit, accidental edits require deliberate steps. Current empirical evidence (T-1929 shipped 2 days ago, no reported accidental commits) supports A3.

None of the NO-GO conditions hold:
- The sovereignty boundary for `fw bvp driver` and `fw bvp weight` is the same boundary (both edit `policy/value-drivers.yaml`). The framework has already decided one is OK via Watchtower; the other inherits.
- CLI-only friction is not load-bearing for the use case the human flagged. The human was *already* a power user on the BVP arc and was blocked from a routine action by lack of UI parity — the friction was the wrong friction.
- 0 free drivers is the **starting** inventory, not the steady-state. The form *enables* the steady-state.

**Evidence:**
- `lib/bvp.sh:776` `_driver_add()` and `lib/bvp.sh:617` dispatcher — `--from-watchtower` already routes correctly
- `lib/bvp.sh:64-68` `_acd_gate()` — refuses under `$CLAUDECODE=1` without `--i-am-human|--from-watchtower`
- `policy/value-drivers.yaml:43-73` — current state: 4 protected, 0 free, cap 9 (M1)
- `web/blueprints/bvp.py:409-465` (`bvp_commit_weights`) — proven shell-out pattern from T-1929 with CSRF + rationale + per-change loop
- `web/blueprints/arcs.py` (T-1926 `arc_approve_driver`) — proven shell-out pattern for arc-level driver approval

**Recommended build slices (file as TWO separate tasks AFTER `fw inception decide T-1958 go`):**

- **T-NEW-A** — `web/blueprints/bvp.py` add `/api/bvp/driver/add` POST endpoint + `web/templates/bvp.html` insert add-driver form below the weight sliders. Shell-out: `bin/fw bvp driver --add "<name>" --weight N --rationale "..." [--drop Dn] --from-watchtower`. Form fields: name (slug, regex `[A-Za-z][A-Za-z0-9_-]*`), weight (0-9 slider), rationale (textarea, ≥30 chars), drop-driver dropdown (visible only when at cap=9).

- **T-NEW-B** — `web/blueprints/bvp.py` add `/api/bvp/driver/remove` POST endpoint + remove button per free-driver row in the weight-sliders table. Shell-out: `bin/fw bvp driver --remove Dn --rationale "..." --from-watchtower`. Confirm with a "Are you sure? (free drivers only; D1-D4 cannot be removed)" prompt — backend must additionally refuse Dn matching D1-D4 (the CLI already does, but the form should surface the refusal as a 400 with the protected-driver message).

Total estimated cost: ~80 LOC blueprint + ~60 LOC template per slice. Both shippable in <2 hours each.

**Out-of-scope follow-ups NOT recommended now:**
- Per-arc driver CRUD (separate from global): T-1926 already shipped the arc-side mechanism on `/arcs/<slug>` (Approve-driver form, partial CRUD). Wait for first cycle of arc-scoped drivers in the wild before extending.
- Bulk-edit table: explicitly rejected by A4 (one row per write, with rationale, is the friction-as-feature design).
- Calculator/visualisation UI for "how each global driver applies to each arc": separate complaint, already addressed by T-1956 (driver weights above-the-fold) — re-evaluate if human still finds it unclear after T-1956 lands.

## Decision

**Decision**: GO

**Rationale**: Recommendation: GO — build the add-driver and remove-driver Watchtower forms.

Rationale:

All three GO criteria are satisfied:

1. §ACD agent-gate is already wired on `fw bvp driver`: `lib/bvp.sh:64-68` refuses under `$CLAUDECODE=1` unless `--i-am-human` or `--from-watchtower`. Adding a Watchtower form does NOT introduce a new bypass — it consumes the exemption the framework already provisioned for exactly this case.
2. Pattern reapplies cleanly. T-1929 (`/bvp` weight sliders) and T-1926 (`/arcs/<slug>` approve-driver form) already implement the form-with-CSRF-and-rationale → `bin/fw bvp <verb> --from-watchtower` shape. Add/remove driver is a structurally identical shell-out. Zero new failure modes; the Flask blueprint stays a thin wrapper over the canonical CLI.
3. Rationale friction is sufficient. R6 (≥30 chars) is the same friction the CLI imposes. Combined with CSRF + explicit click-to-commit, accidental edits require deliberate steps. Current empirical evidence (T-1929 shipped 2 days ago, no reported accidental commits) supports A3.

None of the NO-GO conditions hold:
- The sovereignty boundary for `fw bvp driver` and `fw bvp weight` is the same boundary (both edit `policy/value-drivers.yaml`). The framework has already decided one is OK via Watchtower; the other inherits.
- CLI-only friction is not load-bearing for the use case the human flagged. The human was already a power user on the BVP arc and was blocked from a routine action by lack of UI parity — the friction was the wrong friction.
- 0 free drivers is the starting inventory, not the steady-state. The form enables the steady-state.

Evidence:
- `lib/bvp.sh:776` `_driver_add()` and `lib/bvp.sh:617` dispatcher — `--from-watchtower` already routes correctly
- `lib/bvp.sh:64-68` `_acd_gate()` — refuses under `$CLAUDECODE=1` without `--i-am-human|--from-watchtower`
- `policy/value-drivers.yaml:43-73` — current state: 4 protected, 0 free, cap 9 (M1)
- `web/blueprints/bvp.py:409-465` (`bvp_commit_weights`) — proven shell-out pattern from T-1929 with CSRF + rationale + per-change loop
- `web/blueprints/arcs.py` (T-1926 `arc_approve_driver`) — proven shell-out pattern for arc-level driver approval

Recommended build slices (file as TWO separate tasks AFTER `fw inception decide T-1958 go`):

- T-NEW-A — `web/blueprints/bvp.py` add `/api/bvp/driver/add` POST endpoint + `web/templates/bvp.html` insert add-driver form below the weight sliders. Shell-out: `bin/fw bvp driver --add "<name>" --weight N --rationale "..." [--drop Dn] --from-watchtower`. Form fields: name (slug, regex `[A-Za-z][A-Za-z0-9_-]`), weight (0-9 slider), rationale (textarea, ≥30 chars), drop-driver dropdown (visible only when at cap=9).

- T-NEW-B — `web/blueprints/bvp.py` add `/api/bvp/driver/remove` POST endpoint + remove button per free-driver row in the weight-sliders table. Shell-out: `bin/fw bvp driver --remove Dn --rationale "..." --from-watchtower`. Confirm with a "Are you sure? (free drivers only; D1-D4 cannot be removed)" prompt — backend must additionally refuse Dn matching D1-D4 (the CLI already does, but the form should surface the refusal as a 400 with the protected-driver message).

Total estimated cost: ~80 LOC blueprint + ~60 LOC template per slice. Both shippable in <2 hours each.

Out-of-scope follow-ups NOT recommended now:
- Per-arc driver CRUD (separate from global): T-1926 already shipped the arc-side mechanism on `/arcs/<slug>` (Approve-driver form, partial CRUD). Wait for first cycle of arc-scoped drivers in the wild before extending.
- Bulk-edit table: explicitly rejected by A4 (one row per write, with rationale, is the friction-as-feature design).
- Calculator/visualisation UI for "how each global driver applies to each arc": separate complaint, already addressed by T-1956 (driver weights above-the-fold) — re-evaluate if human still finds it unclear after T-1956 lands.

**Date**: 2026-05-20T17:54:40Z

## Reviewer Verdict (v1.5)

- **Scan ID:** R-9b655bb5
- **Timestamp:** 2026-06-02T15:00:39Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-20T17:54:41Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
