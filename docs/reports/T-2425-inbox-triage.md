# T-2425: Observation Inbox Triage (OBS-075 through OBS-078)

## Summary

Triaged 4 pending observations from inbox. 2 promoted to tasks, 2 dismissed as incomplete.

## Findings

### OBS-076 → T-2426 (PROMOTE - Blocking Bug)
**Issue:** `_self_vendor_libs` find doesn't prune `node_modules/__pycache__`, reports phantom drift for untracked `lib/ts/node_modules/**/*.md` files
**Impact:** Blocks ALL master pushes when npm install has populated lib/ts/node_modules
**Severity:** HIGH - blocking issue
**Action:** Promoted to T-2426 build task

### OBS-075 → T-2427 (PROMOTE - Documentation)
**Issue:** arc-012 live-fire precondition missing — coordination files (`.restart-requested`, `.tool-counter`, `.budget-status`) are repo-global, not per-session
**Impact:** Live-fire loop coordination unsafe when multiple claude-fw wrappers active
**Severity:** MEDIUM - operational safety
**Action:** Promoted to T-2427 build task

### OBS-077 (DISMISS - Incomplete)
**Text:** "add"
**Action:** Dismissed - no context or actionable information

### OBS-078 (DISMISS - Incomplete)  
**Text:** "add"
**Action:** Dismissed - no context or actionable information

## Outcome

- Inbox cleared: `bin/fw note list` returns empty
- 2 actionable issues promoted to build tasks
- 2 incomplete entries dismissed

## Recommendation

**GO** - Triage complete, actionable items captured as T-2426/T-2427
