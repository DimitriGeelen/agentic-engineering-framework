# T-1253 — Pre-push hook VERSION-stamping breaks version.json-based projects

**Task:** T-1253
**Type:** Inception (research artifact per C-001)
**Created:** 2026-04-14
**Reporter:** .109 cross-agent (ring20-management) for T-106 blocker

## Problem

The framework's `pre-push` hook contains a VERSION-stamping block introduced in T-648:

```sh
_version=$(git describe --tags --match 'v[0-9]*')   # → "v3.1.0-alpha-5-gabc123"
# parse to "3.1.5"-ish
echo "$_stamped" > "$PROJECT_ROOT/VERSION"
echo "$_stamped" > "$PROJECT_ROOT/.agentic-framework/VERSION"
```

Every `git push` overwrites both VERSION files based on `git describe`, which assumes
projects version via git tags. Consumer projects using `version.json`-based
versioning (e.g., ring20-management, Odoo-style configs) have their manually bumped
versions silently reverted.

Example from .109: `version.json` bumped to `3.2.9-alpha`, then pushed, VERSION
rewritten to `3.1.alpha` (latest matching git tag).

## T-106 context

- AC #1 (audit-script fallback to .agentic-framework/) — shipped (G-PREPUSH-T498-REGRESSION)
- AC #2 (re-install produces a working hook) — **blocked**: the broken template lives
  in the global `/root/.agentic-framework/`. The global `fw` symlink points there, so
  `fw git install-hooks` reinstalls the same template. Fixing globally crosses project
  boundary and needs Tier 2.

The deeper issue: the stamping block assumes git-tag versioning — it's simply wrong
behavior for version.json-based projects. Fixing the audit path doesn't address this.

## Spikes

### Spike A — Locate and confirm stamping block

<!-- Read agents/git/lib/hooks.sh pre-push section. Confirm block exists and is unconditional. -->

### Spike B — Version.json detection at hook-time

<!-- Can we detect `version.json` from the hook? What about `pyproject.toml` [project.version]? -->

### Spike C — Fix-path evaluation

<!--
Path 1: Opt-in via .framework.yaml (explicit flag: enable_version_stamping: true/false)
Path 2: Auto-detect — skip stamping when version.json or similar is present
Path 3: Remove the stamping block entirely (make VERSION manual)

Score each against: Antifragility, Reliability, Usability, Portability.
-->

## Findings

<!-- Populated as spikes complete. -->

## Recommendation

<!-- GO/NO-GO/DEFER with rationale. -->

## Dialogue Log

### 2026-04-14 — Cross-agent report from .109

`.109` reported the T-106 blocker via cross-agent TermLink channel:

> Every git push overwrites both VERSION files based on git describe — which assumes
> projects version via git tags. This project versions via version.json, so the two
> systems fight. Latest matching tag is something around v3.1.0-alpha, so VERSION
> gets rewritten to 3.1.alpha every push even after we bump version.json to 3.2.9-alpha.

Paths forward listed by .109:
1. `fw upgrade` — may pull a fixed template from upstream
2. Strip the VERSION-stamping block from `.git/hooks/pre-push` locally
3. Patch the global `/root/.agentic-framework/` with Tier 2 authorization
4. Upstream fix: make the stamping block honor version.json when present

This inception explores path (4) — the upstream fix — as the sustainable solution.
Paths (2) and (3) are tactical workarounds; path (1) only helps once (4) ships.
