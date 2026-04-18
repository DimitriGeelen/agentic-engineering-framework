# T-1311: RPC Resilience-Tier Taxonomy + Version Skew Enforcement

**Source:** termlink T-1071 pickup (P-033)
**Status:** DEFER
**Date:** 2026-04-18

## Proposal

Termlink proposes the framework formally codify a two-tier RPC taxonomy:
- **Tier-A** "opaque pass-through" (no schema validation at the boundary; data flows verbatim)
- **Tier-B** "typed envelope" (schema-validated, version-tagged, refused on skew)

And add version-skew enforcement at MCP and TermLink boundaries.

## Analysis

The framework already has multiple RPC-shaped boundaries:
- MCP tools (`mcp__skills__*`, `mcp__termlink__*`)
- TermLink dispatch (PTY inject, exec, interact)
- `fw bus` post/read (inline + blob with size gating)
- `fw dispatch` send (cross-machine SSH-piped envelopes)
- Pickup envelopes (typed YAML, schema in `lib/pickup.sh`)

Each boundary makes its own correctness call. The framework documents *how to choose* between them (CLAUDE.md "Sub-Agent Dispatch Protocol", "Cross-Agent Communication Protocol") but does not enforce a tier label.

## Why DEFER

Episodic memory has zero incidents traceable to RPC version skew. The dispatch-vs-tool guidance is the actual decision agents face — adding a "Tier-A vs Tier-B" label to each call site is overhead without a forcing function.

**Promote to GO if:** A consumer (termlink, ring20-*, email-archive, or framework itself) reports a concrete skew incident — wrong field shape, missing required field, breaking change deployed without coordination — that taxonomy + enforcement would have caught.

## Decision Trail

- Source pickup: `.context/pickup/processed/P-033-feature-proposal.yaml`
- Task: `.tasks/active/T-1311-pickup-codify-rpc-resilience-tier-taxono.md`
- Recommendation: DEFER pending concrete need
