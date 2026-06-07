# T-2097: fw upgrade [3/10] seed-files merge strategy

**Status:** inception (research artifact, C-001)
**Filed:** 2026-05-29
**Sibling:** T-2098 (Playwright MCP-aware fallback)
**Parent cluster:** T-2078 (fw upgrade reliability)

---

## Problem Statement

`fw upgrade` step [3/10] seeds three universal-governance files into each consumer:

- `.context/project/practices.yaml`
- `.context/project/decisions.yaml`
- `.context/project/patterns.yaml`

Current heuristic (`lib/upgrade.sh:556-575`):

```bash
seed_count=$(grep -c "^  - " "$seed_file")
project_count=$(grep -c "^  - " "$project_file")
if [ "$project_count" -gt "$seed_count" ]; then
    echo "SKIP ${seed_name}.yaml (has project-specific items — manual merge recommended)"
fi
```

**Failure mode:** any consumer that has *ever* added a single project-specific item to one of these files SKIPs that file on every subsequent upgrade. The canonical framework items (cross-cutting practices, decisions, patterns) that the framework wants to broadcast to all consumers **never land**. Consumer governance drifts further from canonical with every framework release.

**Why structurally allowed:** the upgrader was written for the easy case (untouched consumer ← drop in fresh seed). The "customized consumer" case was punted to a manual-merge note in the SKIP message — but no consumer ever actually performs that manual merge, because:
- YAML merging is annoying (no tool ships with the framework)
- Humans don't see the SKIP line as actionable — it reads as "OK, framework was smart"
- Each release silently adds 1-3 SKIPs; cumulative drift is invisible

**Evidence of drift:** the 003-NTB-ATC-Plugin and 050-email-archive consumers both have `practices.yaml` files that have not received a single canonical framework item since they first customized — months of drift.

---

## Scope Fence

**In scope:**
- A merge strategy for the three seed YAMLs that **lands canonical items without clobbering project items**.
- The strategy may use any of: structural YAML merging, dual-file layout (canonical+local), declarative item IDs, append-only canonical section.
- Detection of conflicts (same id, different content) and reporting them clearly to the human.

**Out of scope (other arcs):**
- General-purpose YAML diff/merge tooling — only the three seed files need this.
- Render-surface or UI changes — pure shell + YAML.
- Schema migration of existing consumer YAMLs (one-off, separate task at GO time).

---

## Candidate Strategies

### A. Item-keyed merge (canonical wins on `id:`, project wins on absent ids)

Each item has an `id:` (e.g. `P-013`, `D-127`, `PAT-42`). On upgrade:
- For each canonical item: if consumer has that id → leave consumer's version (project may have customized); if not → add it.
- For each consumer item not in canonical → leave it (project-specific).
- Report: which items were added, which already existed.

**Pros:** simple, predictable, idempotent. Most existing seed items already have ids.
**Cons:** requires every item to have an id (some current items don't); schema enforcement needed.

### B. Dual-file layout (`.canonical.yaml` + `.local.yaml`, merged at read time)

Split each seed into two physical files:
- `.context/project/practices.canonical.yaml` — framework-owned, auto-replaced on upgrade
- `.context/project/practices.local.yaml` — project-owned, never touched on upgrade

Consumers of these files (audit, watchtower, fw practices) merge at read time.

**Pros:** clean ownership boundary; impossible to lose canonical or local items.
**Cons:** every read site has to merge; touches ~5 sites (audit.sh, lib/practice.sh, web/blueprints/practices.py, etc.); migration script needed to split existing files.

### C. Append-only canonical section (in-file delimited block)

Keep the single file, but mark a canonical section:

```yaml
# === CANONICAL (framework-managed, do not edit) — replaced on fw upgrade ===
items:
  - id: P-001
    ...
# === END CANONICAL ===

# === LOCAL (project-specific, never touched by fw upgrade) ===
items:
  - id: PROJ-001
    ...
```

On upgrade: replace the canonical block; preserve the local block.

**Pros:** single file, no migration of consumer code; humans see both in one view.
**Cons:** delimiters are fragile (a missing line breaks parse); two `items:` lists need merging by the reader anyway.

### D. Hybrid: A + B (item-keyed merge AS the primary, with .local.yaml as overflow)

For items with `id:`, use strategy A (in-place merge).
For consumers with truly novel content, allow `.local.yaml` overflow files (strategy B for the long tail).

---

## Decision Criteria

A GO answer should specify:
1. Which strategy (A/B/C/D)
2. Whether `id:` field becomes mandatory on all seed items
3. Migration plan for current consumers (one-shot script vs lazy)
4. Conflict-reporting format (output during `fw upgrade`)
5. Test coverage: a bats test that proves a customized consumer receives a new canonical item on next upgrade without losing its local item

---

## Recommendation

**Recommendation:** GO with **Strategy A (item-keyed merge)**.

**Rationale:**
- Simplest path that solves the actual problem.
- Most current seed items already have `id:` — minor schema cleanup, not a redesign.
- No touch on read-site code (audit.sh, lib/practice.sh, etc. continue reading a single file).
- Conflict path is clear: canonical-vs-local with same id → leave local, log a warning ("framework has new canonical content for `id: X`; review and reconcile manually").
- Idempotent: running upgrade twice produces identical state.

**Evidence supporting GO:**
- Existing seed files (`lib/seeds/{practices,decisions,patterns}.yaml`) — sampling shows >80% of items already carry `id:`.
- Comparable pattern already used in `lib/seeds/value-drivers.yaml` (T-1933, BVP arc) — merges into project YAML with id-key wins.
- T-2078 reliability arc V1 slices (T-2092..T-2095) address the **mechanical** reliability of fw upgrade; this slice addresses **completeness** — together they close the upgrade-trust gap.

**Suggested follow-ups (on GO):**
- T-2097-V1: schema enforcement — every seed item must have `id:`; bats test refuses commit otherwise.
- T-2097-V2: implement item-keyed merge in `lib/upgrade.sh` step [3/10]; add bats coverage exercising a customized consumer.
- T-2097-V3: backfill `id:` on the ~20% of items lacking it; one-shot migration commit.
- T-2097-V4: replace the SKIP message with a richer output: "MERGED 3 canonical items into practices.yaml (X new, Y already present, Z conflicts logged)".

**Rejected alternatives:**
- B (dual-file) — touches too many read sites for a problem this narrow.
- C (in-file delimiters) — fragile, no real advantage over A.
- D (hybrid) — premature complexity; revisit if A hits a real edge case.

---

## Dialogue Log

Inception filed in response to user observation during fw upgrade run:

> "[3/10] Seed files (universal governance)
>        SKIP  practices.yaml (has project-specific items — manual merge recommended)
>        SKIP  decisions.yaml (has project-specific items — manual merge recommended)
>        SKIP  patterns.yaml (has project-specific items — manual merge recommended)"

User asked: "incept better strategy for ... SKIP ... manual merge recommended".

Agent eval: this is a G-019-class silent quality decay — "no error" but consumer governance progressively diverges from canonical. Filed as inception per "one inception = one question" rule (the playwright SKIP is a separate failure class → T-2098).
