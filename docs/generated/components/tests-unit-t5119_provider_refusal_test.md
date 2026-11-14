# t5119_provider_refusal_test

> T-5119 (055 T-645) — a review seat refused by its provider is named as a provider refusal, and a harness seat under the /tmp root is found at all (it used to read "no completion").

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t5119_provider_refusal_test.py`

## What It Does

The shape opencode prints when z.ai refuses the account (055, 2026-11-13): HTTP 429, code 1113,
the provider body nested as an escaped JSON string.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t5119_provider_refusal_test.yaml`*
*Last verified: 2026-11-13*
