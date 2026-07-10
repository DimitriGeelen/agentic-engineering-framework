# vendor/designer/ — pinned Workflow Designer build (DO NOT EDIT)

This directory holds a **vendored, pinned, single-file build** of the Workflow
Designer. The single source of truth is **832-Workflow-designer**, not AEF.

## Read-only contract (T-2521 AC5)

- **Never edit the vendored `.html` in place.** `fw designer sync` installs it
  mode `0444` (read-only) precisely so an accidental edit fails loudly.
- **Improvements route upstream to 832**, per `docs/aef-designer-integration-protocol.md`
  (832 side): fix in 832 → cut a new release → deliver → `fw designer sync`.
- Editing the vendored copy would fork the SoT and silently diverge AEF from the
  released build — the exact failure this pin exists to prevent.

## How a build lands here

1. 832 cuts a release and **delivers** the artifact into AEF (the T-559 project
   boundary means this AEF session cannot pull it from `/opt/832`; 832 pushes it).
2. Update `policy/designer-pin.yaml` (`version`, `sha256`, `bytes`) to the release.
3. `fw designer sync --from <delivered-artifact>` — verifies sha256 against the
   pin and installs it here read-only. Mismatch ⇒ non-zero exit, nothing installed.
4. `fw serve` → Watchtower `/designer` serves it.

## Caveat (T-2521 AC6)

The build links **Google Fonts (CDN)**. Diagramming + import/export function
offline via system-font fallback, but a locked-down deployment will make (failing)
font requests on load. Full offline is a separate 832-side task.
