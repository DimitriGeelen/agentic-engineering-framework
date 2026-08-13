# t2927_observation_inbox_listing

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/t2927_observation_inbox_listing.bats`

## What It Does

T-2927 — the handover's observation-inbox section listed 1 of 112 pending
observations, and said nothing about the other 111.
Both sites in agents/handover/handover.sh split the inbox with
re.split(r'\n  - ', content)
the 2-space list indent that patterns.yaml uses. inbox.yaml puts its entries
at column 0. T-2514 named that exact mismatch and repaired it in audit.sh;
these two sites were never swept — which is L-533 ("a sibling sweep with no
enumerating guard cannot distinguish 'converted the ones we found' from
'converted all of them'") landing a second time, on a different idiom, after
the learning that describes it was already written down.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t2927_observation_inbox_listing.yaml`*
*Last verified: 2026-08-11*
