# T-339: Link Documentation to Component Fabric Endpoints

## Research Artifact (C-001)

### Current State

**Documentation assets:**
- `docs/articles/deep-dives/` — 7 concept deep-dives (task gate, tier0, context budget, memory, healing, authority, fabric)
- `docs/articles/launch-article.md` — launch article
- `docs/reports/` — 30+ research/inception reports
- `CLAUDE.md` — primary governance reference (sections map to subsystems)
- `FRAMEWORK.md` — provider-neutral guide

**Component Fabric:**
- 127 registered components in `.fabric/components/*.yaml`
- Cards have: id, name, type, subsystem, location, purpose, depends_on, depended_by, tags
- No existing `docs` or `documentation` field in any card
- Watchtower renders component detail at `/fabric/<name>` — shows deps, reverse deps, purpose

**Gap:** Zero bidirectional links exist between docs and fabric components. A user reading about "the healing loop" in `05-healing-loop.md` cannot navigate to the code (`agents/healing/`). A user viewing `agents-healing-healing.yaml` in Watchtower sees no reference to the deep-dive article.

### Design Options

#### Option A: Add `docs` field to component cards

```yaml
# In .fabric/components/agents-healing-healing.yaml
docs:
  - path: docs/articles/deep-dives/05-healing-loop.md
    type: deep-dive
  - path: CLAUDE.md#healing-agent
    type: reference
```

**Pros:** Simple, declarative, lives with the component
**Cons:** Manual maintenance, N:M relationship gets awkward (one doc covers multiple components)

#### Option B: Add `components` frontmatter to doc files

```yaml
---
components: [agents/healing/healing.sh, agents/healing/lib/diagnose.sh]
---
# The Healing Loop
```

**Pros:** Doc authors declare what they cover, one place to update
**Cons:** Requires parsing doc frontmatter, reverse lookup needed for fabric→doc direction

#### Option C: Mapping file (registry approach)

```yaml
# .fabric/doc-links.yaml
mappings:
  - doc: docs/articles/deep-dives/05-healing-loop.md
    components: [agents-healing-healing, agents-healing-lib-diagnose, agents-healing-lib-resolve]
    type: deep-dive
```

**Pros:** Single source of truth, easy to audit, supports N:M cleanly
**Cons:** One more file to maintain, not co-located with either docs or cards

#### Option D: Convention-based (no explicit links)

Use naming conventions and tags to infer links. Deep-dive `05-healing-loop.md` matches subsystem `healing-loop` or tag `healing`.

**Pros:** Zero maintenance
**Cons:** Fragile, imprecise, doesn't handle cross-cutting docs

### Recommendation

**Option A (docs field in component cards)** is the simplest and most aligned with existing patterns. The fabric already has `depends_on`/`depended_by` — adding `docs` is natural. For the reverse direction (doc→components), Watchtower can scan cards for docs pointing to a given path.

Option C (mapping file) is cleaner for N:M but adds another artifact. Could be a follow-up if Option A proves insufficient.

### Scope Assessment

**Minimal viable version:**
1. Add optional `docs` field to component card schema
2. Populate for 7 deep-dive articles → ~20 component cards
3. Watchtower: show doc links on component detail page
4. Watchtower: add `/docs` page listing articles with component links

**Estimated effort:** Small build task (1-2 sessions)

### Agent Research Findings (5 parallel agents)

#### 1. Deep-dive → Component Mapping (28 cards across 7 articles)
| Article | Components |
|---------|-----------|
| 01-task-gate | check-active-task, create-task, lib-focus, git |
| 02-tier0-protection | check-tier0, bin-fw |
| 03-context-budget | budget-gate, checkpoint, handover |
| 04-three-layer-memory | lib-decision, lib-episodic, lib-pattern, lib-init, lib-status |
| 05-healing-loop | healing, lib-diagnose, lib-patterns, lib-resolve |
| 06-authority-model | check-tier0, update-task, git, bin-fw |
| 07-component-fabric | fabric, lib-register, lib-traverse, lib-drift, lib-query |

#### 2. Template Analysis
Component detail route already passes full dict to Jinja2. Add `docs` field to YAML, add conditional template block after Route section. Pattern matches existing optional fields (route, coupling_note). Zero backend changes needed.

#### 3. Schema Audit
127 cards, 11 core fields at 100%. No `docs` field exists anywhere. Register generates skeleton without it. Enrichment only touches `depends_on`/`depended_by`/`last_enriched`. Adding `docs` is a clean addition.

#### 4. Tooling Resilience (Grade B)
Most code uses safe `.get()`. One unsafe direct access in `traverse.sh` line 105: `dep['target']` should be `dep.get('target', '')`. All other tooling handles unknown fields gracefully.

#### 5. Reverse Lookup
`fabric.py` already does O(n) reverse scans for `depended_by`. Same approach works for docs→components. Performance fine at 127 components. Existing nav has a Docs link that could wire to a fabric docs view.

### Go/No-Go Analysis

**GO if:**
- The `docs` field can be added without breaking existing fabric tooling — **CONFIRMED** (all .get(), one fix needed)
- Watchtower can render doc links with minimal template changes — **CONFIRMED** (conditional Jinja2 block)
- At least 5 of 7 deep-dives map cleanly to specific components — **CONFIRMED** (7/7, 28 cards total)

**NO-GO if:**
- Adding fields to cards breaks fabric tooling — **NOT the case**
- The doc↔component relationship is too many-to-many — **NOT the case** (2-5 components per article)
- No one actually navigates between docs and code — **Demand exists** (captured as task)

### Decision: GO

Build task scope:
1. Add `docs` field to ~28 component cards (mapping above)
2. Add "Documentation" section to `fabric_detail.html` template
3. Fix `dep['target']` safety issue in traverse.sh (bonus)
4. Optional stretch: `/fabric/docs` reverse-lookup page
