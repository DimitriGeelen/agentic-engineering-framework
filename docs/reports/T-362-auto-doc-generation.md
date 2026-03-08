# T-362: Auto-Generate Documentation from Component Fabric

## Research Artifact (C-001)

### Problem

127 components, only 24 have doc links (to 7 hand-written deep-dives). The remaining 103 have no documentation beyond a `purpose` field — and 60% of those are broken/incomplete. We need a system that generates useful documentation automatically, not just for the current 127 but for any future components.

### Research Findings (3 agents)

**Article structure** (agent 1): All 7 deep-dives follow a consistent pattern — domain analogy → core concept with code examples → research rationale with T-XXX citations → closing trio (try-it, platform notes, hashtags). Average 103 lines.

**Available data** (agent 2): Component cards have good dependency data but 60% broken purpose fields. Real content lives in: source code headers, CLAUDE.md sections, episodic memory, learnings.yaml, decisions.yaml. 80% of a doc is mechanical extraction; 20% needs AI judgment.

**Existing patterns** (agent 3): Framework already has heredoc-based document assembly (episodic.sh, handover.sh), git mining, embedded Python transforms, and markdown2 rendering in Watchtower. Proven pattern: YAML source → Python → markdown output.

### Design: Two-Layer Generation System

The system has two layers generating two different types of documentation:

#### Layer 1: Component Reference Docs (mechanical, no AI needed)

Auto-generated reference pages for every component, built from structured data. Think "API docs" — factual, navigable, always current.

**Data sources:**
- Component card: name, type, subsystem, purpose, location, tags
- Dependencies: depends_on, depended_by (with resolved names)
- Source code: first comment block / header (extracted via grep/sed)
- CLAUDE.md: matched section (by subsystem/component name)
- Episodic: related task history
- Learnings: related learnings (by tag/component match)

**Output format:** Markdown file per component in `docs/generated/components/`

**Template:**
```markdown
# {name}

> {purpose}

**Type:** {type} | **Subsystem:** {subsystem} | **Location:** `{location}`

## What It Does

{extracted from source header + CLAUDE.md section}

## Dependencies

### Uses ({N})
| Component | Relationship |
|-----------|-------------|
| {dep.name} | {dep.type} |

### Used By ({N})
| Component | Relationship |
|-----------|-------------|
| {rdep.name} | {rdep.type} |

## Related

- **Tasks:** {episodic references}
- **Learnings:** {matched learnings}
- **Deep Dive:** {link to article if exists}

---
*Auto-generated from Component Fabric. Last updated: {date}*
```

**Implementation:** `agents/docgen/generate-component.sh` — shell script with embedded Python, following episodic.sh pattern. Runs per-component or batch.

**CLI:** `fw docs generate [component-id]` or `fw docs generate --all`

#### Layer 2: Subsystem Articles (AI-assisted, uses LLM)

Deep-dive articles for subsystems, using the proven 4-section template. These require narrative judgment — domain analogies, architectural rationale, usage examples.

**Data sources (assembled as prompt context):**
- All component cards in the subsystem
- Source code of key files (entry points)
- CLAUDE.md section for the subsystem
- Episodic memory for related tasks
- Relevant learnings and decisions
- Existing deep-dive as style reference

**Output:** Markdown article in `docs/articles/deep-dives/`

**Template (from agent 1 analysis):**
```markdown
# Deep Dive #{N}: {Subsystem Name}

## Title
{SEO-friendly title}

## Lead
{Domain analogy establishing the principle → transition to AI agents → problem statement}

## Core Concept
{Mechanism explanation with 2-3 subsections, 1 code/YAML example, 1 comparison table}

## Research & Design Rationale
{T-XXX references, quantified findings, decision citations}

## Try It
{Installation + usage examples}

## Platform Notes
{Channel-specific guidance}

## Hashtags
{Relevant tags}
```

**Implementation:** `agents/docgen/generate-article.sh` — assembles context from fabric + source + episodic, then either:
- Option A: Outputs a prompt file for manual LLM use
- Option B: Calls Claude API directly (requires API key)
- Option C: Outputs a structured draft that `fw write` can polish

**CLI:** `fw docs article {subsystem-name}`

### Layer 0: Data Quality Fix (prerequisite)

Before generating anything useful, fix the 60% broken purpose fields:

`fw docs heal` — reads each card, if purpose is broken/placeholder:
1. Extract first comment block from source file
2. Parse for description patterns (# Description, ## Purpose, first docstring)
3. Update card's purpose field

### Watchtower Integration

- `/docs` route: index of all generated docs, grouped by subsystem
- `/fabric/component/{name}` already shows docs links (T-361)
- Generated docs served as rendered markdown (using existing markdown2)

### Architecture Diagram

```
Component Cards ──┐
Source Code ───────┤
CLAUDE.md ─────────┼──→ [Layer 1: generate-component.sh] ──→ docs/generated/components/*.md
Episodic Memory ───┤                                              ↓
Learnings ─────────┘                                     Watchtower /docs/{component}

Component Cards ──┐
Source Code ───────┤
CLAUDE.md ─────────┼──→ [Layer 2: generate-article.sh] ──→ docs/articles/deep-dives/*.md
Episodic Memory ───┤         ↑                                    ↓
Style Reference ───┘    (LLM assist)                     Watchtower /docs/articles/{slug}
```

### Go/No-Go Criteria

**GO if:**
- Layer 1 can generate useful reference docs from current card data (even with broken purposes)
- The generation is idempotent (re-running produces same output for unchanged inputs)
- Generated docs integrate cleanly with Watchtower

**NO-GO if:**
- Card data is too sparse for even basic reference docs (would need full enrichment first)
- Generation time exceeds 5 minutes for all 127 components
- Output quality is worse than just reading the source code directly

### Recommended Build Sequence

1. **T-363: Layer 0 — fix broken purpose fields** (prerequisite, small)
2. **T-364: Layer 1 — component reference generator** (mechanical, medium)
3. **T-365: Watchtower /docs route** (render generated docs, small)
4. **T-366: Layer 2 — subsystem article generator** (AI-assisted, medium)

Each is independently useful. Layer 1 alone covers 80% of the value.
