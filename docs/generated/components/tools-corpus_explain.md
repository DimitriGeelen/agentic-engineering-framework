# corpus_explain

> T-2622: agent retrieval seam — corpus maps readable without a browser.

**Type:** script | **Subsystem:** framework-core | **Location:** `tools/corpus_explain.py`

## What It Does

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [corpus_spec](/docs/generated/tools-corpus_spec) | uses | corpus_spec — declarative spec ⇄ designer-corpus BPMN (T-2603, arc T-2602 GO). |
| [corpus_conformance](/docs/generated/tools-corpus_conformance) | uses | Map-conformance rail — corpus map assertions vs the enforced state machine. |

## Used By (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [vendor_visibility](/docs/generated/tests-unit-vendor_visibility) | tests_by | T-3144 — `fw vendor` writes executable code into a consumer tree and never checked that the consumer's git could see it. Reported by 010-termlink for `tools/`; the measured set is wider. |

---
*Auto-generated from Component Fabric. Card: `tools-corpus_explain.yaml`*
*Last verified: 2026-07-26*
