---
task: T-2330
workflow_type: inception
recommendation: GO
session: S-2026-0611-1544
---

# T-2330 — BVP driver propose-queue surface

## Why this exists

Driver-add (`fw bvp driver --add`) is Sovereign-gated (D8 policy-edit). Today the only operator path is: operator opens `/bvp#bvp-driver-add`, types name + weight + rationale (≥30 chars) by hand, clicks Submit. Three times for the V_* trio T-2306 is staging. Three rationales × ≥30 chars each = real typing friction for a Sovereign decision whose hard work is *judging the rationale*, not *typing it*.

Every sibling Sovereign class already has an "agent proposes, human one-click approves" surface: `/inception/<id>`, `/approvals`, per-task `/review/<id>`, `/arcs/<slug>/close`, and `/bvp` weight-commit. Driver-add is the lone outlier.

The deferred T-2245 IW-3 verbs (`fw bvp driver suggest|create|edit|retire`) were the placeholder for exactly this surface. T-2330 takes the deferred shape and asks: ship it now, scoped to add (with edit/retire as natural follow-ons).

## Dialogue Log (S-2026-0611-1544)

Captured verbatim where it captures *why* the decision shape evolved.

### Round 1 — agent reaches for the Watchtower path

Operator: *"why can this nor be done ussing our approval routre eg in teh watchtower ?"*

Agent reflex was to point at the operator-typed form and stop. The honest answer was: the form exists (T-1964 shipped), the quickstart is stale (still says "once T-1964 is shipped" months after it shipped — L-477 sibling class). Operator's question landed.

### Round 2 — operator presses for agentic assist

Operator: *"ok but why can we not make this with agentic assitance ?"*

Agent listed three paths:
- **Path A** — Playwright pre-fills the form; operator clicks Submit
- **Path B** — propose-queue surface (`bvp_drivers_proposed:` + `/bvp/proposed` Watchtower section)
- **Path C** — session-scoped delegated authority (Watchtower mints short-lived token, agent runs with token)

### Round 3 — operator asks for adversarial analysis

Operator: *"strawman and steelman b and c and score against value drivers"*

Agent produced the matrix below. Decision in Round 4 was "b".

## Decision matrix

### Path B — Propose-queue surface

**Steelman:** Structural fix already half-designed by T-2245 IW-3. Mirrors patterns the operator's pattern-memory carries. R5 anti-Goodhart preserved (Sovereign click unchanged; only typing burden changes). Generalizes to retire/edit at zero marginal cost. Queue is the merge boundary for parallel proposals — no file collisions.

**Strawman:** Another `/bvp/*` page. Speed of approval ≠ quality of approval — batch-approving under time pressure erodes rationale discipline. Two agents proposing same driver create merge fight. The discipline of writing a good driver rationale becomes mechanical when the queue says "X pending".

**Score (raw BVP):**

| Driver | Weight | Score | Weighted |
|---|---|---|---|
| D1 Antifragility | 5 | 2 | 10 |
| D2 Reliability | 5 | 4 | 20 |
| D3 Usability | 5 | 3 | 15 |
| D4 Portability | 5 | 3 | 15 |
| F-RECALL | 6 | 3 | 18 |
| F-ORCH | 5 | 4 | 20 |
| (V_CONTEXT_FABRIC, latent) | 7 | 3 | 21 |
| (F-AUTONOMY, latent) | 4 | 2 | 8 |

Raw BVP = 98/155 = **0.63 norm**. Cost composite ~3. **HV/LC = 0.21.**

### Path C — Session-scoped delegated authority

**Steelman:** This IS the F-AUTONOMY L4/L5 earning move. Scope-narrow + time-narrow + auditable + revocable. Generalizes across all Sovereign classes. Inherently revocable; token lifecycle is the auditable evidence.

**Strawman:** Bespoke token mint/validate/expire/revoke subsystem for one Sovereign class. 5min windows are too short for thoughtful proposals and too long for security. Once "trust session for class X" exists, the next ask is class Y — scope-creep slope toward erosion. Token expiry mid-action is a new failure class. Driver-add's human review IS the gate's value, not its redundancy.

**Score (raw BVP):**

| Driver | Weight | Score | Weighted |
|---|---|---|---|
| D1 Antifragility | 5 | 3 | 15 |
| D2 Reliability | 5 | 2 | 10 |
| D3 Usability | 5 | 3 | 15 |
| D4 Portability | 5 | 2 | 10 |
| F-RECALL | 6 | 2 | 12 |
| F-ORCH | 5 | 3 | 15 |
| (V_CONTEXT_FABRIC, latent) | 7 | 1 | 7 |
| (F-AUTONOMY, latent) | 4 | 4 | 16 |

Raw BVP = 82/155 = **0.53 norm**. Cost composite ~5 (sovereignty primitive — pattern propagation across other verbs). **HV/LC = 0.11.**

### Verdict

B wins HV/LC by ~2×. C is the right answer for F-AUTONOMY later (post-T-2158 + L5/L6); driver-add is the wrong proving ground for a sovereignty primitive whose pattern compounds across Sovereign classes.

## Scope fence (proposal — IW-N decisions pending)

**IN scope:**
- Driver-add propose path: agent writes proposal entries, operator approves via Watchtower with single click
- Queue surface listing pending proposals with per-row Approve / Reject buttons
- Audit trail: proposal author + timestamp + rationale + decision outcome
- Sovereign click is preserved (the Approve button runs `fw bvp driver --add --from-watchtower`)
- Race semantics: two agents proposing same driver-id

**OUT of scope (this slice):**
- Driver-retire / driver-edit (natural follow-ons; same propose-queue pattern, but separate slices)
- Auto-approve of agent-proposed drivers (this IS the Sovereign rail; never)
- Cross-project driver propagation
- Token-based delegated authority (Path C — deferred)

## Open Questions (IW-N — see task body for disposition)

Mirrored from the task file's `## Open Questions` section so the artifact stands alone for reviewers. Authoritative dispositions live on the task.

- **IW-1: Storage location for proposals.** Sidecar `policy/value-drivers.proposed.yaml` vs in-place `bvp_drivers_proposed:` list — spike needed. Lean in-place for pattern consistency with `bvp_scores_proposed:` (T-1922); sidecar wins if multi-project propagation later lands.
- **IW-2: Queue surface placement.** New `/bvp/proposed` route vs inline section on `/bvp`. Lean inline initially; promote to route if >5 pending becomes the norm.
- **IW-3: Race semantics.** Two agents propose same driver-id. Lean: append all, operator Approves one, others Reject. Spike needed.
- **IW-4: Reject UX.** Inline delete vs reject-with-rationale. Lean reject-with-rationale for L-class capture.
- **IW-5: TTL on stale proposals.** 30d soft-expire (banner only, not auto-delete) so operator catches the backlog signal.
- **IW-6: Scope creep to retire / edit / suggest.** T-2330 ships `--add` first; retire/edit follow.
- **IW-7: Retrofit T-2306.** Answered — T-2306's V_* trio moves from 3 form-typings to 3 Approve clicks once queue lands.

## Recommendation

**GO** — file build slices for the propose-queue surface. Estimated 3-4 sub-slices (storage shape decision spike, Flask endpoint, Watchtower section, bats + Playwright tests).

## Evidence

- B-vs-C HV/LC = 2× advantage (scoring above)
- T-2245 IW-3 deferred verbs already point at this shape
- Sibling pattern parity: 5 existing approval surfaces, driver-add the lone outlier
- Operator-side ROI: 3 V_* driver-adds in T-2306 today, plus retire/edit naturally land on the same surface
- R5 anti-Goodhart preserved by construction (Sovereign click unchanged)

## See also

- `T-2245` — IW-3 deferred the `suggest|create|edit|retire` verb family
- `T-2306` — V_* trio operator-quickstart, first beneficiary of the queue
- `T-1964` — `/api/bvp/driver/add` Flask endpoint + form (existing Sovereign surface)
- `lib/bvp.sh:67-84` — `require_human_actor()` Sovereign gate (preserved)
- `policy/value-drivers.yaml` — driver pool + proposal location candidate
- `docs/reports/T-2305-bvp-drivers-batch-2026-06-10.md` — original V_* batch context
