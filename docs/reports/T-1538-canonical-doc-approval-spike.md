# T-1538 — Canonical-Doc Approval Surface Spike

Inception research artifact. Validates assumptions A1-A4 from the task envelope and produces a concrete delta-plan for the GO/NO-GO decision.

Source pickup: `.context/pickup/processed/P-040-feature-proposal-from-ntb-atc.yaml` (003-NTB-ATC-Plugin T-210).

## Research Method

Read-only spike against the existing /approvals codebase. No production code written. Each assumption gets one focused probe; findings written here as they emerge.

## A1 — Three-loader pattern is the right shape to mirror

**Question:** Does adding a 4th category cleanly mirror the existing 3 loaders, or are there structural reasons it would diverge?

**Findings:** **CONFIRMED.** All three loaders in `web/blueprints/approvals.py` follow the same shape:

| Loader | Source | Returns | Decision endpoint |
|--------|--------|---------|-------------------|
| `_load_pending_approvals()` (Tier-0) | `.context/approvals/pending-*.yaml` | list of dicts with `_file`, `status` | `POST /api/approvals/decide` writes resolved-*.yaml + sets bypass token |
| `_load_pending_go_decisions()` (inception) | active inception tasks via `get_all_task_metadata()` | list of dicts with `task_id`, `name`, `verdict`, `recommendation` | `POST /api/inception/decide` (in inception blueprint) |
| `_load_pending_human_acs()` | active tasks with unchecked Human ACs | list of dicts with `task_id`, `human_acs`, `verdict`, `is_stale` | `POST /api/approvals/complete-batch` |

`_build_approvals_context()` (line 324-359) aggregates all three into the template render context with consistent count fields (`tier0_count`, `go_count`, `ac_count`, `total_count`). Adding a 4th category requires adding one loader, two count fields (`canonical_count`, augment `total_count`), and one route — purely additive, no refactor of existing surfaces.

The inception loader's recent additions (verdict extraction T-1531, deferred-count T-1518) demonstrate the loader pattern is actively extended in similar shape. No structural blockers.

## A2 — `.context/proposals/*.md` × `.claude/canonical-docs.list` is sufficient identification

**Question:** Can a loader uniquely identify pending canonical-doc proposals from filesystem state alone (without a separate registry)?

**Findings:** **PARTIALLY VALIDATED — design clarification needed.** The framework repo itself **does not ship** the canonical-doc gate. There is:

- No `.claude/hooks/check-canonical-doc.sh` in the framework repo (only in the consumer that originated the pickup, 003-NTB-ATC-Plugin).
- No `.claude/canonical-docs.list` in the framework repo.
- A `docs/proposals/` directory exists with two pickup-related markdown files but no `.approved` markers — this is the framework's own pickup-tracking artifact, not the consumer-pattern proposal flow.
- `.context/proposals/` directory does not exist in the framework repo.

This means the framework would be adding a **/approvals UI for a gate the framework itself does not deploy**. Implications:

- The loader must be defensive: if `.context/proposals/` is missing or empty, the section renders as empty (no error, no flash, no count).
- The pattern can still ship in the framework — other consumer projects opt in by adopting the gate hook + list. The UI is no-op until they do.
- Alternatively, the framework could ship the gate hook itself as a `fw init` opt-in template — but that's scope-creep beyond this task.

**Recommendation for the build:** scan unconditionally, fail-gracefully. Section appears only when at least one unmatched proposal exists.

## A4 — Existing `check-canonical-doc.sh` consumes the marker correctly

**Question:** Does the gate hook already handle marker-presence correctly, so adding a UI that creates the marker is a no-op for the existing hook?

**Findings:** **CANNOT VALIDATE on this host** — the hook lives in the consumer (003-NTB-ATC-Plugin) which is not present on this filesystem. The pickup envelope describes the contract:

> The canonical-doc edit gate (T-156/T-157, .claude/hooks/check-canonical-doc.sh) blocks Write/Edit on Marc-facing source documents until a matching `.context/proposals/<slug>.approved` marker exists.

If the contract holds (consumer-side ground truth), the framework UI's only job is atomic marker creation — `touch .context/proposals/<slug>.approved` — which the existing hook already consumes. No coordination logic, no race window beyond filesystem atomicity, no rollback path needed (rejection is a separate `.rejected` marker for audit).

**Mitigation for the validate-gap:** the build task should include a Human AC for the consumer-side end-to-end test (edit-blocked → click-approve → edit-passes), since only the consumer can prove the contract.

## A3 — Whole-file approval is sufficient

**Question:** Is per-section / per-paragraph approval needed?

**Findings:** **CONFIRMED out-of-scope** by the pickup envelope itself. Per-section approval would require either a structured proposal format (vs free-form Markdown) or an embedded annotation system — neither of which the existing gate hook supports. Whole-file is the natural unit.

## Go/No-Go Synthesis

**Recommendation: GO** with the following caveats:

1. The framework adds the UI surface for a gate hook that lives in consumers — net architectural shape is "framework provides Watchtower observability for consumer-deployed hooks", which is consistent with the existing /approvals model (Tier 0 approvals also originate in consumer-side `.context/approvals/`).

2. Build task must scan defensively — empty `.context/proposals/` is the normal state on most projects.

3. End-to-end validation (edit-blocked → approve → edit-passes) requires a Human AC on the consumer side (003-NTB-ATC-Plugin) since the gate hook is consumer-deployed.

4. Watchtower already runs on a consumer's PROJECT_ROOT, so reading `PROJECT_ROOT/.context/proposals/` Just Works — no path magic needed.

5. Risk surface is small: additive code, defensive scan, atomic marker write, audit log. Reversible: revert the loader and the section disappears with no state damage.

## Concrete Delta Plan (if GO)

**Files touched:**

1. **`web/blueprints/approvals.py`** (+~70 LOC)
   - New `_load_pending_canonical_proposals()` loader: glob `PROJECT_ROOT/.context/proposals/*.md`, exclude those matching `*.approved` siblings, return list of dicts with `proposal_path`, `target_path` (parsed from frontmatter or first-heading slug → `.claude/canonical-docs.list` lookup), `slug`, `summary` (first ~200 chars), `created_ts` (file mtime).
   - Extend `_build_approvals_context()` to include `pending_canonical=...`, `canonical_count=len(pending_canonical)`, augment `total_count`.
   - New endpoint `POST /api/approvals/canonical-decide` (~30 LOC): accept `{proposal_path, decision}`. On `approve`, atomic-touch `.context/proposals/<slug>.approved` + append-log to `.context/working/.canonical-approval.log`. On `reject`, atomic-touch `.context/proposals/<slug>.rejected` + log. Return rendered fragment.

2. **`web/templates/_approvals_content.html`** (+~25 LOC)
   - 4th render section after the existing three. Card per proposal showing target file, proposal path, summary excerpt, Approve/Reject buttons (htmx POST to the decide endpoint).
   - Adds a "Canonical-Doc Proposals" filter button to the existing filter row (gated on `{% if canonical_count %}`).

3. **`web/templates/cockpit.html` (landing page widget)** — optional, ~10 LOC
   - Add canonical-pill to the verdict-pill row when `canonical_count > 0`.

4. **Tests** — `tests/web/test_canonical_approval.py` (+~80 LOC)
   - Synthetic Flask render test: dir with 1 unmatched proposal → section renders; with `.approved` sibling → section hides.
   - Endpoint test: POST approve → marker created + audit-log line appended.
   - Endpoint test: POST reject → `.rejected` marker created.

**Estimated delta:** ~210 LOC added, 0 LOC removed, 0 refactors. ~1.5h build + 30min review-iteration. Fits the convergence-test pattern (small build → blind reviewer → fix → ship).

**Build task ACs (proposed):**

```
### Agent
- [ ] _load_pending_canonical_proposals() returns empty list when .context/proposals/ missing or empty
- [ ] Loader returns one dict per .md file lacking a .approved sibling, sorted by mtime descending
- [ ] _build_approvals_context() exposes canonical_count and pending_canonical to templates
- [ ] _approvals_content.html renders 4th section gated on canonical_count
- [ ] POST /api/approvals/canonical-decide creates .approved marker atomically and logs to .canonical-approval.log
- [ ] POST /api/approvals/canonical-decide rejection path creates .rejected marker
- [ ] Synthetic render test passes (proposal-with-marker hidden, proposal-without-marker shown)
- [ ] Endpoint test passes (approve creates marker, reject creates rejected-marker)
- [ ] Blind reviewer dispatch on the new surface (mirroring T-1539 pattern)

### Human
- [ ] [REVIEW] On the consumer (003-NTB-ATC-Plugin) where the gate hook is deployed: edit-blocked → click Approve in Watchtower → edit-passes (end-to-end contract validated)
```

**Open question for the human (not a blocker):** Should the framework also ship the canonical-doc gate hook itself as a `fw init` opt-in (so the UI's existence implies hook availability)? Suggest leaving for a follow-up inception — keep this task focused on the UI surface only.
