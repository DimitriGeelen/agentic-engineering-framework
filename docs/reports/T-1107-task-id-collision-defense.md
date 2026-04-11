# T-1107 — Task-ID Collision Defense-in-Depth (Research Stub)

**Status:** Captured, not yet started. This document exists to satisfy C-001 (research artifact first) for the capture commit. Real research begins when T-1106 is decided GO and T-1107 is promoted to started-work.

---

## Why this task exists

T-1106's Option D (Bug 2 fix + `/identity` endpoint + emitter verification) closes the primary bleed-through at the **point of emission** — `fw task review` will refuse to emit a URL if the Watchtower at that URL does not serve `$PROJECT_ROOT`.

**The residual risk T-1107 addresses:** a URL that was correctly emitted can still be resolved against the *wrong* Watchtower later:

1. **QR code scanned after restart.** Human prints/shares a QR. Originating Watchtower is stopped; a different project's Watchtower now binds that port. QR scan resolves to the new Watchtower. Task-ID integer collision means the wrong page renders with HTTP 200.
2. **Bookmarked review link.** Human bookmarks `http://host:3003/inception/T-434`. Port reassigned to another project. Return visit serves wrong content.
3. **Cross-device context leak.** Link pasted into chat on another device. By the time the second device loads, Watchtower topology has changed. Same silent wrong-content failure.

T-1106's identity check only runs at the *emitter* side (the `fw task review` CLI on the originating host). Once the URL is in the wild, it is trusted unconditionally by whatever Watchtower it hits — because Task IDs are not globally unique.

## Options to evaluate (in later research)

### Option 1 — Globally unique task IDs
- Prefix all task IDs with project slug: `025/T-434`, `999/T-434`
- Change affects: `.tasks/active/<ID>.md` filenames, frontmatter `id` field, every git commit message, every cross-reference, every episodic, every bus envelope
- Migration burden: very high — all historical commits reference `T-XXX`; rewriting history is not an option
- Partial path: new task IDs start using the prefix; legacy IDs remain as-is; URL resolution requires both formats. Dirty but incremental.

### Option 2 — URL namespacing (`/proj/<name>/inception/T-XXX`)
- All Watchtower routes gain a project segment
- `fw task review` emits the namespaced form
- Wrong-Watchtower resolution → HTTP 404 because project segment mismatches
- Migration burden: medium — all routes, all templates, all QR codes, bookmarks break
- Backward compat: old URLs can be handled with a fallback route that returns HTTP 409 "wrong project — use canonical URL" with the correct URL in the body

### Option 3 — Embedded project identifier in QR payload, verified by Watchtower
- QR encodes both URL and `project_root` as a JSON blob (not just a plain URL)
- Watchtower's `/inception/T-XXX` route reads an optional `?pr=<hash>` query param; if present and mismatched with served `project_root`, returns an explicit "wrong project" error page
- Migration burden: low — backward compatible (URLs without the param work as before, with reduced safety)
- Weakness: only helps for QR-code paths. Plain URL sharing still fails open.

### Option 4 — Combined (2 + 3 + cross-project registry)
- URL namespacing as canonical form
- Query param as additional defense for old clients
- A framework-wide registry at `/root/.agentic-framework/.registry/projects.yaml` listing `<port> → <project_root>` so a redirector can route any URL to the correct Watchtower
- Highest cost, highest safety

## Inputs to the research

When T-1107 starts real work, read first:

- `docs/reports/T-1106-watchtower-port-bleed-rca.md` — primary context
- T-885 (configurable per-project port) — interacts with this inception; if T-885 lands first, the "second project binds the same port" scenario becomes less likely
- Audit: count task-ID collisions across all 11 consumer projects on this host (blocked from T-1106 by budget gate)
- History: any prior discussion of global IDs in the framework repo

## Scope Fence (for later research phase)

**IN:** path recommendation with evidence, migration sketch, cost/blast-radius analysis, interaction with T-885 and T-1106.

**OUT:** Any build. Any schema lock. Any actual ID rewrite. Any route change. Any URL emission change. Those are descendant build tasks created after T-1107 is decided GO.

## Status

Captured 2026-04-11 during T-1106 structural upgrade pass. Not yet started. Waiting on T-1106 decision before promotion.
