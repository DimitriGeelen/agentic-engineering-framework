# t4536_literal_var_curl

> T-4536 — T-4512 made the curl/wget check refuse any word that begins with a quoted expansion ("$X" could expand to -o FILE). That is right when X comes from the environment, and it turned T-3644's `WURL=x; curl -sf "$WURL/"` red.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t4536_literal_var_curl.bats`

## What It Does

T-4536 — T-4512 made the curl/wget check refuse any word that begins with a
quoted expansion ("$X" could expand to -o FILE). That is right when X comes
from the environment, and it turned T-3644's `WURL=x; curl -sf "$WURL/"` red.
The fix honours an expansion only of a name THIS line assigned a literal that
cannot begin an option, carried only across && / ; into further literal
assignments or the curl/wget clause itself. Everything else stays refused.
`! cmd` at statement position is INERT in bats (L-628) — this file uses
`if cmd; then false; fi` for NOT-SAFE assertions.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t4536_literal_var_curl.yaml`*
*Last verified: 2026-10-21*
