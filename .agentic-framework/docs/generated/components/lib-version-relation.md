# version-relation

> TODO: describe what this component does

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/version-relation.sh`

## What It Does

T-2713 — one truthful answer to "is this consumer ahead or behind?".
THE DEFECT THIS REPLACES
Three sites open-coded the same comparison:
[ "$(printf '%s\n%s\n' "$a" "$b" | sort -V | tail -1)" = "$a" ] && ahead || behind
bin/fw:2015          doctor's consumer-fleet ahead/behind badge
lib/upgrade.sh:849   pre-step-1 runtime downgrade guard  (T-1912)
lib/upgrade.sh:1742  pin-rewrite downgrade guard         (T-1839)
`sort -V` orders version STRINGS. VERSION here is a tag counter that RESETS —
this repo's tags run v1.6.763, v1.6.762, v1.6.761, then v1.6.10, v1.6.9, and
VERSION itself has gone 1.6.354 -> 1.6.121 -> 1.6.176. A counter that resets

---
*Auto-generated from Component Fabric. Card: `lib-version-relation.yaml`*
*Last verified: 2026-08-01*
