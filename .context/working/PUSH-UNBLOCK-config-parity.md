# Push-unblock recipe — config-registry parity (diagnosed S-2026-0907, arc-020 session)

**Symptom:** `git push origin bleeding-edge` blocked by pre-push audit — REF-scoped
FAIL: `Invariant suite (tests/lint): 2 of 108 structural invariant(s) RED (T-2837)`.

**Both RED invariants are in `tests/lint/config-registry-parity.bats`:**
- `not ok 35` — lib/config.sh and web/blueprints/config.py have the same config keys
- `not ok 37` — config registry key count matches across sources

**Root cause (single key):** `FW_PROVISION_LOAD_MAX` (the arc-020 S5 governor
threshold, T-3311) was added to the canonical registry `lib/config.sh:301` but never
mirrored into `web/blueprints/config.py` SETTINGS. 40 keys in config.sh vs 39 in
config.py. Fixing this one mirror clears BOTH invariants.

**The fix** (one line — add to the SETTINGS list in web/blueprints/config.py, after
the last entry at line 60, `AUDIT_TIMEOUT_WARN_FRACTION`):

```python
    ("PROVISION_LOAD_MAX", "0.8", "Per-core normalized 1-minute loadavg threshold for the environmental governor's provisioning admission (lib/aef_governor.py). Under = allow, at/over = defer, at/over 2x = deny; bad values fall back to 0.8, logged. T-3311."),
```

(mirrors `lib/config.sh:301` `"PROVISION_LOAD_MAX|0.8|..."` verbatim in description.)

**Verify:**
```
cd /opt/999-Agentic-Engineering-Framework && bats tests/lint/config-registry-parity.bats 2>&1 | grep -E "^not ok" || echo "PARITY CLEAN"
```

**Then** (web/ is a vendored path): `bin/fw vendor self` (scope to the file if the
concurrent session still has bin/fw uncommitted: `FW_VENDOR_ONLY="web/blueprints/config.py" bin/fw vendor self`), commit referencing a fresh task, and push.

**Governance notes:**
- Needs its own task (one-bug-one-task). web/blueprints/ is a render surface (P-013),
  but this is a mechanical data-mirror (one SETTINGS row identical to 39 siblings) whose
  objective check is the parity invariant — an Agent AC with the bats command in
  Verification; `--skip-render-review "mechanical config mirror, no visual change"` if the
  render gate fires (logged Tier-2).
- Could NOT be applied in S-2026-0907 (budget hit critical mid-diagnosis). Diagnosis is
  complete; only the edit + commit remain.

**Also blocking / already handled this session:** T-3298's mangled `name:` frontmatter
(promote-quoting YAML break, T-2069 class) — FIXED + committed (ea613ba21). That cleared
the separate "unparseable task YAML" audit check (audit failing-checks went 2 → 1).
