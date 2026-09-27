# designer-pin

> Pinned Workflow Designer build record (T-2521): the AEF-832 integration contract naming the vendored release (tag, sha, artifact) of the 832-Workflow-designer single-file build. Bumped via pull-at-tag protocol, never edited in place.

**Type:** config | **Subsystem:** governance | **Location:** `policy/designer-pin.yaml`

**Tags:** `policy`, `designer`, `T-2521`, `vendoring`

## What It Does

T-2521: pinned Workflow Designer build — the AEF↔832 integration contract.
832-Workflow-designer is the single source of truth (SoT). AEF vendors a
RELEASED single-file build artifact — never 832 source — and never edits the
vendored copy in place. Improvements route upstream to 832 (see protocol).
Bump procedure (pull-at-tag, T-247/D-335, first used for 0.4.0): 832 cuts a
release (annotated tag designer-vX.Y.Z carrying dist artifact + MANIFEST.yaml)
→ rail announce (version, sha256, bytes, tag — stays the trigger + verdict
handshake) → update this pin from the announce → `fw designer sync --from-tag`
(canonical intake step, T-2616) fetches artifact + MANIFEST AT the tag from
`source_origin:` below → independent sha256 must match BOTH the MANIFEST at

## Used By (9)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [designer](/docs/generated/agents-designer-designer) | reads | fw designer: vendors and serves a pinned Workflow Designer release build via the Watchtower /designer blueprint (832-Workflow-designer is source of truth; T-2521). |
| [designer](/docs/generated/web-blueprints-designer) | reads | Designer blueprint — serves the pinned Workflow Designer build (T-2521). |
| [corpus_lint](/docs/generated/tools-corpus_lint) | reads | corpus_lint — per-map + cross-map lint for the designer corpus (T-2604). |
| [corpus_spec](/docs/generated/tools-corpus_spec) | reads | corpus_spec — declarative spec ⇄ designer-corpus BPMN (T-2603, arc T-2602 GO). |
| [init](/docs/generated/lib-init) | writes | fw init - Bootstrap a new project with the Agentic Engineering Framework |
| [upgrade](/docs/generated/lib-upgrade) | writes | fw upgrade - Sync framework improvements to a consumer project |
| [corpus_lint](/docs/generated/tools-corpus_lint) | called_by | corpus_lint — per-map + cross-map lint for the designer corpus (T-2604). |
| [corpus_spec](/docs/generated/tools-corpus_spec) | called_by | corpus_spec — declarative spec ⇄ designer-corpus BPMN (T-2603, arc T-2602 GO). |
| [designer](/docs/generated/web-blueprints-designer) | called_by | Designer blueprint — serves the pinned Workflow Designer build (T-2521). |

---
*Auto-generated from Component Fabric. Card: `policy-designer-pin.yaml`*
*Last verified: 2026-09-08*
