# T-2757: Should fw upgrade ship the pinned Workflow Designer to consumers?

## Summary

After `fw upgrade`, a consumer has no vendored Designer build. Guidance printed is "fw designer sync --from <delivered-artifact>" (agents/designer/designer.sh:76) with **no stated source** for the artifact. Investigation determines whether `do_vendor` should include the pinned Designer by default.

## Findings

### 1. Designer Pin Location (policy/designer-pin.yaml)

**File:** policy/designer-pin.yaml:19-21, 109

- **version:** 0.8.0
- **sha256:** cab3c75183979b0e15e23192518f9360ea12fe33b6a4f78641d7e264f6110935
- **bytes:** 903600 (903.6 KB)
- **vendored_path:** vendor/designer/aef-workflow-designer-0.8.0.html
- **source_origin:** ssh://git@192.168.10.201:6611/workflow-designer (read-only LAN repo for pull-at-tag intake)

This is the single source of truth for the pinned build.

### 2. Copy Behavior in do_vendor / fw upgrade

**File:** bin/fw:332-356

The `includes` array in `do_vendor()` lists:
```
bin, lib, agents, web, docs, policy, .tasks/templates, FRAMEWORK.md, metrics.sh,
.secret-scan-patterns, .secret-scan-allowlist, status-transitions.yaml
```

**`vendor/` is explicitly NOT in the includes list.** No `vendor/designer/` directories are copied to consumers. Commits T-2656 and T-2674 added `.secret-scan-patterns`, `.secret-scan-allowlist`, and `status-transitions.yaml` to includes; `vendor/` was never added.

### 3. User-Facing Guidance After upgrade

**File:** agents/designer/designer.sh:76, web/blueprints/designer.py:40-58

When Designer is not synced:
- CLI: "NOT SYNCED — 832 must deliver the build, then: fw designer sync --from <file>" (agents/designer/designer.sh:76)
- Web: Placeholder page at /designer (web/blueprints/designer.py:44-57) with identical message

**Problem:** Both messages say "832 must deliver" but do NOT tell consumers:
- WHERE to obtain the artifact (832's repo? S3? TermLink dispatch?)
- HOW to request delivery (which channel? who owns the delivery workflow?)
- WHEN to expect it (is delivery automatic after a pin bump? manual request?)

The `fw designer sync --from-tag` intake path (agents/designer/designer.sh:137-217) fetches from `source_origin` (the LAN repo) and verifies sha256 against BOTH the MANIFEST at the tag AND the pin — but this path is only useful if the consumer can reach the LAN origin (assumption not stated).

### 4. Watchtower /designer Route Behavior Without Vendor

**File:** web/blueprints/designer.py:100-107, 148-211

When vendored_path file is missing:
- `_serve_bundle()` returns `_placeholder()` (HTTP 200 status)
- Renders helpful but incomplete placeholder HTML
- `/designer` landing page and `/designer/app` both call `_serve_bundle()` → all Designer routes serve the placeholder

No critical functionality is broken, but all Designer workflows (edit, open projects, ghosts, overlay) are blocked.

### 5. Size and Precedent

**File:** vendor/designer/ directory

- **Total size:** 7.6 MB (9 versioned builds, 0.3.0 through 0.8.0)
- **Pinned version only:** 903.6 KB (0.8.0)
- **Precedent:** `vendor/designer/` already exists in the framework repo and is tracked in git
  - All 9 releases are vendored for historical reference and offline access
  - Only the pinned version is served at runtime
  - Build is self-contained single-file HTML (offline-hardened woff2 fonts embedded, no external dependencies per policy/designer-pin.yaml:115)

Consumers already vendor `policy/` (policy/designer-pin.yaml is copied), so the pin is available to consumers. Missing only the built HTML artifact.

### 6. Licensing and Maintenance

**File:** vendor/designer/README.md:6-13

- Read-only contract enforced via `install -m 0444`
- Improvements route upstream to 832, never edited in-place (T-2521 AC5)
- Boundary: AEF vendors the RELEASED build, never 832's source

No licensing concerns; treating as a frozen deliverable is the design intent.

---

## Recommendation

**GO — Ship the pinned Designer by default in fw upgrade**

### Rationale

1. **Unblocked common workflows:** Consumers can use Workflow Designer (edit, open, save diagrams) immediately after upgrade without a separate manual sync step that requires off-repo knowledge.

2. **Minimal cost:** Only 903.6 KB added to the vendored framework per consumer (the pinned version, not all 9 historical builds). Already precedent in framework repo.

3. **Solves the guidance gap:** Current message ("832 must deliver") leaves consumers stuck. Shipping the pinned build eliminates the blocker and avoids the need to document an external delivery workflow (which does not yet exist for consumers).

4. **Pins are immutable:** A pin bump happens rarely (T-2673 re-pinned to 0.8.0 on 2026-07-19). Once vendored at upgrade-time, the build never changes in the consumer unless the consumer explicitly runs `fw designer sync --from-tag` to adopt a newer pin (pull-at-tag intake for future releases).

5. **No workflow change for updates:** Framework upgrades already refresh `policy/designer-pin.yaml`. Including the matching `vendor/designer/aef-workflow-designer-X.Y.Z.html` is a natural companion.

### Trade-off

- **Cost:** +903.6 KB per consumer checkout (acceptable for a single critical tool; web/ is already vendored at ~4 MB)
- **Maintenance:** None — the pinned build is read-only and never edited. Updates come via `fw designer sync --from-tag` when the pin is bumped (operator-driven, same as today)

---

## Proposed Change

Add `vendor/designer` to the `includes` array in bin/fw:332-356, but only copy the **pinned version** (e.g., `vendor/designer/aef-workflow-designer-0.8.0.html`) to consumers, not the full directory of 9 historical builds.

**Alternative:** Copy only the pinned version by wrapping the copy in a small filter. Reduces bloat (903.6 KB vs 7.6 MB) and keeps the upgrade payload minimal.

