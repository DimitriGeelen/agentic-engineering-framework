# T-191: Component Fabric — Enforcement & Tooling Design (Phase 4)

## Design Principles

From Phase 2 (human validation) and Phase 3 (prototype findings):

1. **Single-direction edges** — store `depends_on` only, derive reverse at query time
2. **File path as ID** — canonical identifier is the file path, display aliases optional
3. **Unified card schema** — one YAML format, optional sections by type
4. **Warning-first** — blast radius and drift are informational, not gates (human decision)
5. **Auto-injection** — onboarding summary at session start, blast radius at commit

---

## 4a. Registration & Enforcement Points

### How Components Get Registered

**Manual registration (primary):**
```bash
fw fabric register <file-path>
```
- Creates a skeleton card in `.fabric/components/<slug>.yaml`
- Pre-fills: id (file path), name (from filename), type (inferred from watch-patterns), location, created_by (current task)
- Agent fills in: purpose, depends_on, tags
- Estimated time: 2-5 minutes per component

**Batch registration (bootstrap):**
```bash
fw fabric scan
```
- Scans all watch-pattern matches
- Creates skeleton cards for unregistered files
- Reports: "Created 47 skeleton cards. Run `fw fabric enrich` to fill details."

**Enrichment (AI-assisted):**
```bash
fw fabric enrich <component-id>
```
- Reads the component source file
- Infers: purpose, depends_on (from imports/source/open calls), tags
- Writes a draft card for human/agent review
- Not a gate — enrichment is optional, skeleton cards are valid

### Enforcement Points

| Point | Type | What it checks | Severity |
|-------|------|---------------|----------|
| `fw fabric drift` | On-demand | Unregistered files, stale edges | Report |
| `fw audit` structure section | Cron (30 min) | Unregistered files matching watch patterns | WARN |
| Post-commit hook | Automatic | Blast radius of changed files | Info (printed) |
| `work-completed` gate | Optional | Changed files have fabric cards | WARN (not blocking) |

**No blocking gates.** The fabric is informational infrastructure. Registration is encouraged by making unregistered components visible in audit warnings, not by blocking commits.

### Enforcement Rationale

Blocking was considered and rejected because:
- Framework already has enough gates (task, tier-0, budget, inception)
- Adding a registration gate would slow development velocity for marginal benefit
- The value of the fabric is in querying, not in forced compliance
- Drift detection in audit catches gaps without blocking flow

---

## 4b. Retroactive Validation (Drift Detection)

### Drift Types

| Type | Detection Method | Severity |
|------|-----------------|----------|
| **Unregistered** | File matches watch-pattern but no card | WARN in audit |
| **Orphaned** | Card exists but file deleted | WARN in audit |
| **Stale edge** | `depends_on` target file doesn't exist | WARN in audit |
| **Format drift** | Data file schema changed since card written | Manual (`fw fabric validate`) |

### Audit Integration

New section in `agents/audit/audit.sh`:

```bash
# === FABRIC DRIFT CHECKS ===
# Check for unregistered components matching watch patterns
# Check for orphaned cards (file deleted but card remains)
# Check for stale edges (target file missing)
```

**Implementation:**
1. Read `watch-patterns.yaml`, glob each pattern
2. Compare against registered locations in `.fabric/components/*.yaml`
3. WARN for each unregistered file
4. WARN for each orphaned card
5. For each `depends_on` edge, verify target file exists

### Deep Validation (`fw fabric validate`)

```bash
fw fabric validate [component-id]
```
- Re-reads source file
- Checks: does each `depends_on` target still exist at the declared location?
- Checks: are there obvious dependencies NOT in the card? (grep for `source`, `open(`, `yaml.safe_load`)
- Reports discrepancies as suggestions, doesn't auto-fix

---

## 4c. Query Interface (`fw fabric`)

### Command Design

Based on 6 use cases, incorporating Phase 3 refinement (derive reverse edges at query time):

```bash
# === Registration ===
fw fabric register <file-path>         # Create skeleton card
fw fabric scan                         # Batch-create skeletons for unregistered files
fw fabric enrich <component-id>        # AI-assisted card enrichment

# === UC-1: Navigate ===
fw fabric search <keyword>             # Topic search across tags, names, purpose
fw fabric get <component-id>           # Show full card
fw fabric deps <file-path>             # What does this file depend on + what depends on it

# === UC-2: Impact ===
fw fabric impact <file-path>           # Full transitive downstream chain
fw fabric impact <file-path> --depth N # Limit traversal depth

# === UC-3: UI Identify ===
fw fabric ui <route>                   # All interactive elements on a route
fw fabric ui --action <data-action>    # Find element by data-action attribute

# === UC-4: Onboard ===
fw fabric overview                     # Compact subsystem summary
fw fabric subsystem <id>               # Drill into one subsystem

# === UC-5: Regress ===
fw fabric blast-radius [commit]        # Downstream impact of commit (default: HEAD)
fw fabric blast-radius <from>..<to>    # Impact of commit range

# === UC-6: Completeness ===
fw fabric drift                        # Full drift report
fw fabric validate [component-id]      # Deep validation of one or all cards

# === Meta ===
fw fabric stats                        # Component count, edge count, coverage %
```

### Implementation Architecture

```
agents/fabric/
  fabric.sh              # Main dispatcher (like context.sh)
  lib/
    register.sh          # Registration commands
    query.sh             # Search, get, deps
    traverse.sh          # Impact, blast-radius (graph traversal)
    ui.sh                # UI-specific queries
    drift.sh             # Drift detection
    summary.sh           # Overview generation
  AGENT.md               # Intelligence guidance
```

**Graph traversal algorithm** (for `impact` and `blast-radius`):
1. Find starting component by file path (grep across cards)
2. Collect all `depends_on` edges where this component is the target (reverse lookup)
3. For each consumer, recursively collect their consumers
4. Deduplicate and sort by distance from start
5. Output as indented tree or flat list

**Reverse edge derivation** (key design choice from Phase 3):
```bash
# Instead of reading depended_by from each card,
# scan all cards for depends_on targeting this component
grep -rl "target:.*$COMPONENT_ID" .fabric/components/
```
This is O(n) where n = number of cards. At ~100 cards, this takes <100ms.

### Output Format

All commands output human-readable text by default, with `--yaml` flag for machine-readable output:

```
$ fw fabric impact agents/context/lib/learning.sh

Impact chain for: agents/context/lib/learning.sh (add-learning)

  writes → .context/project/learnings.yaml (learnings-data)
    read by → web/blueprints/discovery.py (learnings-route)
      renders → web/templates/learnings.html (learnings-template)
    read by → agents/audit/audit.sh#yaml-validation (audit-yaml-validator)
    read by → agents/audit/audit.sh#graduation (graduation-pipeline)

5 downstream components affected
```

---

## 4d. Adaptive Granularity

### Granularity Levels

| Level | What's documented | When to escalate |
|-------|------------------|-----------------|
| **Skeleton** | id, name, type, location, subsystem | Default (batch registration) |
| **Standard** | + purpose, depends_on, tags | After first meaningful work on the component |
| **Detailed** | + interfaces, contracts, shared_constants, coupling_notes | After a bug involving this component |
| **UI-rich** | + interactive_elements, template_inheritance, htmx chains | For all route/template components |

### Escalation Triggers

1. **Bug trigger:** When `fw healing resolve` records a fix touching a component → prompt to enrich its card
2. **Frequency trigger:** When a component appears in 3+ blast-radius reports in a week → suggest enrichment
3. **Coupling trigger:** When a soft-coupling edge is involved in a failure → upgrade from skeleton to detailed

### Escalation Flow

```
Skeleton → "fw fabric enrich" prompt after bug/frequency trigger
         → Agent enriches card with depends_on, purpose, tags
         → If soft-coupling bug: add contract + coupling_note
         → Standard/Detailed card
```

**No automatic escalation.** Triggers generate suggestions (like audit warnings). Agent or human decides whether to act.

---

## 4e. Hook Integration

### Post-Commit Hook (blast-radius)

Added to existing `post-commit` hook chain:

```bash
# In agents/git/hooks/post-commit (after existing git-mining logic)
if [ -d ".fabric" ]; then
    # Get changed files from this commit
    changed=$(git diff-tree --no-commit-id --name-only -r HEAD)

    # Run blast-radius (silent if no registered components affected)
    blast=$(fw fabric blast-radius HEAD --quiet 2>/dev/null)
    if [ -n "$blast" ]; then
        echo ""
        echo "=== Fabric Blast Radius ==="
        echo "$blast"
    fi
fi
```

**Constraint:** Must complete in <5 seconds. At 100 cards, grep-based traversal is <500ms.

### Session Start Hook (onboarding)

Added to existing `SessionStart` hook chain:

```bash
# In post-compact-resume.sh or a new SessionStart hook
if [ -f ".fabric/subsystems.yaml" ]; then
    fw fabric overview --compact  # Generates ~500 token summary
fi
```

Output injected alongside handover context.

### Audit Integration

New section in `agents/audit/audit.sh` structure checks:

```bash
# === FABRIC DRIFT CHECKS ===
if [ -d "$PROJECT_ROOT/.fabric" ]; then
    drift_output=$(fw fabric drift --summary 2>/dev/null)
    unregistered=$(echo "$drift_output" | grep "unregistered:" | awk '{print $2}')
    orphaned=$(echo "$drift_output" | grep "orphaned:" | awk '{print $2}')
    stale=$(echo "$drift_output" | grep "stale:" | awk '{print $2}')

    if [ "$unregistered" = "0" ] && [ "$orphaned" = "0" ] && [ "$stale" = "0" ]; then
        pass "Fabric: no drift detected"
    else
        [ "$unregistered" -gt 0 ] && warn "Fabric: $unregistered unregistered components" "..." "Run: fw fabric scan"
        [ "$orphaned" -gt 0 ] && warn "Fabric: $orphaned orphaned cards" "..." "Remove stale cards"
        [ "$stale" -gt 0 ] && warn "Fabric: $stale stale edges" "..." "Run: fw fabric validate"
    fi
fi
```

---

## Build Task Decomposition (Preview for Phase 5)

Preliminary task breakdown for GO decision:

| # | Task | Type | Depends On | Est. |
|---|------|------|-----------|------|
| 1 | Create `agents/fabric/` agent structure | Build | — | 1 session |
| 2 | Implement `fw fabric register` + `scan` | Build | #1 | 1 session |
| 3 | Implement `fw fabric search` + `get` + `deps` | Build | #1 | 1 session |
| 4 | Implement `fw fabric impact` + `blast-radius` (graph traversal) | Build | #3 | 1-2 sessions |
| 5 | Implement `fw fabric drift` + audit integration | Build | #3 | 1 session |
| 6 | Implement `fw fabric overview` + session injection | Build | #3 | 1 session |
| 7 | Implement `fw fabric ui` queries | Build | #3 | 1 session |
| 8 | Post-commit blast-radius hook | Build | #4 | 0.5 session |
| 9 | Batch-register all AEF components (~100 cards) | Build | #2 | 2-3 sessions |
| 10 | Implement `fw fabric enrich` (AI-assisted) | Build | #2 | 1 session |

**Total estimate:** 10-13 sessions for full implementation.
**MVP (tasks 1-5):** 5-6 sessions — gives navigate, impact, drift detection.

---

## Open Questions for Phase 5

1. Should `fw fabric` be a new agent or a subcommand of `fw context`?
   - Recommendation: New agent (`agents/fabric/`). The fabric is a new subsystem, not a context extension.
2. Should cards live in `.fabric/` (framework-level) or `.context/fabric/` (project-level)?
   - Recommendation: `.fabric/` at project root. It's structural metadata about the codebase, not session context.
3. Should the refined schema (single-direction edges, path-as-ID) be applied to the existing 10 prototype cards?
   - Recommendation: Yes, as part of task #2 (registration tooling). The tooling generates cards in the refined format.
