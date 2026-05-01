# Cross-repo fabric cards

**Status:** convention introduced by T-1652 (2026-05-01).
**Origin:** T-1641 W10 #8 — fabric blast-radius blind beyond framework boundary.

## Why

The Component Fabric (`bin/fw fabric ...`) maps every significant file in this repo
into a YAML card. But the orchestrator arc's runtime substrate lives in
`/opt/termlink` — outside this checkout — so blast-radius and dependency queries
stop at the boundary. Cross-repo cards extend visibility without coupling the
fabric to filesystem state outside our control.

## Convention

A cross-repo card is a normal fabric YAML in `.fabric/components/` with two extra
fields:

```yaml
id: cross-repo:<project>/<path-from-project-root>
name: <short-name>
location: /absolute/path/at/canonical/checkout      # informational only
cross_project: <project>                            # marker — distinguishes from local cards
cross_repo_url: https://github.com/.../blob/master/<path>
purpose: '...'
depends_on: []                                      # may reference other cross-repo IDs
depended_by:                                        # MUST include at least one local component
  - target: <local-component-id>
    type: <relation>
related_tasks: [...]
```

**File naming**: `cross-repo-<project>-<module>.yaml` (slugify path; drop extension).

## Hand-crafted, not auto-registered

`bin/fw fabric register` will not register cross-repo paths because the file lives
outside `PROJECT_ROOT`. That's deliberate — these cards exist on purpose, are rare,
and require manual judgment about which external modules are genuinely framework
dependencies vs incidental neighbours.

To add a card: copy an existing one in this directory, swap fields, commit.

## What's tracked today

T-1652 registered the orchestrator-arc surface in /opt/termlink:

| Card | Purpose | Linked task |
|------|---------|-------------|
| `cross-repo-termlink-router.yaml` | Hub-side request router (13 hardcoded constants) | T-1642 (Arc A) |
| `cross-repo-termlink-route-cache.yaml` | Persistent routing cache (schema-pin needed) | T-1650 |
| `cross-repo-termlink-bypass.yaml` | N-success bypass-cache promotion | T-1642 |
| `cross-repo-termlink-circuit-breaker.yaml` | Per-target failure circuit breaker | T-1642 |
| `cross-repo-termlink-governance-frame.yaml` | Frame type 0x8 protocol | T-1648 |
| `cross-repo-termlink-governance-subscriber.yaml` | T-1066 data-plane subscriber | T-1066, T-1639 |

## What this enables

- `grep -l 'cross-repo:termlink' .fabric/components/*.yaml` — find every external dep we track
- Manual blast-radius: edit one of these (after coordinating with the cross-repo
  team) and the local `depended_by` edges show what surfaces here will need attention
- Watchtower `/orchestrator` (T-1647) future enhancement: render cross-repo cards
  alongside local fabric in the dependency view (not yet wired)

## What this does NOT do

- Verify that the linked file at `location:` still exists (the file may have
  moved upstream; we'll see drift only when a downstream task fails)
- Auto-fetch upstream changes (cross-repo fabric is an annotation, not a sync)
- Replace the cross-repo proposals via TermLink — code changes still go through
  the owning agent (memory: `feedback_no_cross_repo_edits`)
