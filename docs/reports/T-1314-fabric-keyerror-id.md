# T-1314: /fabric crashes with KeyError on `id` when subsystems use only `name`

**Source:** termlink T-1129 pickup (P-036)
**Status:** GO — build sibling T-1318
**Date:** 2026-04-18

## Bug

`web/blueprints/fabric.py:93`:

```python
registered_ids = {s["id"] for s in subsystems}
```

Crashes with `KeyError: 'id'` when a consumer project's `.fabric/subsystems.yaml` contains list-of-dict entries that use `name:` as the identifier (no `id:` field). Triggers HTTP 500 on the `/fabric` page.

## Root Cause

`_load_subsystems` (web/blueprints/fabric.py:53-73) promises a normalized list-of-dicts shape `[{id, name, ...}]` in its docstring, but only normalizes the **dict-of-dicts** input branch (line 71-72). The list-of-dicts branch returns `raw` verbatim:

```python
if isinstance(raw, dict):
    return [{"id": k, **v} for k, v in raw.items() if isinstance(v, dict)]
return raw   # ← list-of-dicts: NOT normalized
```

When a consumer ships `- name: protocol` without `id:`, the function returns it as-is and the use site crashes.

## Fix

One-line normalization at the `return raw` branch — fill `id` from `name` when missing. This matches the function's own docstring promise and is idempotent (entries that already have `id:` are unchanged).

```python
if isinstance(raw, list):
    return [{**s, "id": s.get("id") or s.get("name")} for s in raw if isinstance(s, dict)]
```

## Verified Constraints

- Sole call site of `_load_subsystems`: `web/blueprints/fabric.py:81` (verified via `grep`)
- No other downstream consumer requires the un-normalized shape
- Dict-of-dicts branch already produces normalized output — fix is symmetric

## Why GO

- Concrete, reproducible crash with verified line numbers
- Fix is one line, idempotent, strictly more correct
- Risk near zero — entries with `id:` are unaffected
- Workaround (consumer adds `id:`) is reasonable but every consumer would have to do it; the framework-side fix is the right level

## Build Plan

Build task **T-1318** ships:
1. The one-line normalization in `_load_subsystems`
2. Pytest regression covering both shapes (id-present, name-only)
3. Optional: parallel normalization for `dict-of-dicts` to fall back to key-as-name (deferred unless needed)

## Decision Trail

- Source pickup: `.context/pickup/processed/P-036-bug-report.yaml`
- Inception task: `.tasks/active/T-1314-pickup-watchtower-fabric-crashes-keyerro.md`
- Build sibling: T-1318 (to be created)
- Recommendation: GO
