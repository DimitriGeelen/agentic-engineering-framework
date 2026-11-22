# printed-fw-commands-ratchet

> T-5306 (slice 4 of T-5302) — ratchet on hand-written `bin/fw <verb>` and `bin/watchtower.sh ...` in text printed to a person or an agent.

**Type:** script | **Subsystem:** tests | **Location:** `tests/lint/printed-fw-commands-ratchet.bats`

## What It Does

T-5306 (slice 4 of T-5302) — ratchet on hand-written `bin/fw <verb>` and
`bin/watchtower.sh ...` in text printed to a person or an agent.
Rule (T-5302 GO): printed commands come from the builder —
shell   $(_emit_user_command "<args>") / "$(_fw_cmd) <args>"   lib/fw-command.sh
python  user_command("<args>") / fw_path()                      lib/fw_command.py
jinja   {{ fw_cmd('<args>') }}                                  web/app.py
A vendored project has no bin/ at its root, so a hand-written one fails as
printed. Detector and its heuristics: tools/printed-fw-commands-lint.py.
Baseline (path -> count, may only shrink):
tests/lint/fixtures/printed-fw-commands-baseline.json

---
*Auto-generated from Component Fabric. Card: `tests-lint-printed-fw-commands-ratchet.yaml`*
*Last verified: 2026-11-21*
