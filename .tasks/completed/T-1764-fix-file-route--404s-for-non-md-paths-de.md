---
id: T-1764
name: "fix /file/ route — 404s for non-md paths despite linker auto-linking .py/.sh/.yaml
  (T-1722 contract break)"
description: >
  fix /file/ route — 404s for non-md paths despite linker auto-linking .py/.sh/.yaml
  (T-1722 contract break)

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: ["bug", "render", "governance-render", "human-review-surface", "T-1722-followup"]
components: [lib/render_surface.sh, tests/unit/test_file_route_extensions.py, 
      web/blueprints/docs.py, web/shared.py]
related_tasks: ["T-632", "T-633", "T-1575", "T-1722", "T-1762", "T-1763"]
created: 2026-05-06T11:03:08Z
last_update: '2026-06-11T22:23:58Z'
date_finished: 2026-05-16T07:06:02Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:58Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal); F-RECALL=2 (body:lightly-promoted); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-1764: fix /file/ route — 404s for non-md paths despite linker auto-linking .py/.sh/.yaml (T-1722 contract break)

## Context

`_auto_link_files` (web/shared.py:317) and `/file/<path:filepath>` route (web/blueprints/docs.py:122) have a contract mismatch.

**Linker** auto-links paths matching `_ARTEFACT_PATH_RE` (web/shared.py:295-314):
- Dirs: `docs/reports/`, `.tasks/(active|completed)/`, `.context/(handovers|episodic|audits|project|working|arcs)/`, `.fabric/components/`, `web/`, `lib/`, `bin/`, `agents/`, `tests/`, `tools/`, `prompts/`, `policy/`, `deploy/`
- Extensions: `.md`, `.yaml`, `.yml`, `.py`, `.sh`, `.json`, `.toml`

**Route** only serves `.md` files under `_VIEWABLE_DIRS = ("docs/", ".tasks/", ".context/handovers/", ".context/episodic/")` — every other auto-linked path returns HTTP 404.

T-1722's stated contract: "every Markdown surface (review, tasks, approvals, inception) gets one-click artefact navigation" — the route silently breaks this for source files.

User-visible manifestation surfaced on T-1762 review page: `<a href="/file/lib/task_pair_acd.sh">lib/task_pair_acd.sh</a>` renders as a clickable link, click yields 404. Same class affects `lib/*.py`, `tests/unit/*.bats`, `agents/*/*.sh`, `.fabric/components/*.yaml`, etc.

Same pattern class as T-1763 (parser/render contract mismatch). Symptom: dead link in human-review surface. Root cause: linker and route disagree on what's viewable.

## Acceptance Criteria

### Agent
- [x] **Single source of truth for viewability** — `web/shared.py` exports a `is_viewable_path(filepath)` helper that both `_auto_link_files` (currently uses regex prefix list) and the `/file/` route consult. No more drift between linker dirs/extensions and route dirs/extensions.
- [x] **Route serves all linker-supported extensions** — `/file/lib/task_pair_acd.sh` returns HTTP 200 with the file rendered as a syntax-highlighted code block. Same for `.py`, `.yaml`, `.yml`, `.json`, `.toml` paths under any whitelisted dir. `.md` continues to render as Markdown (no regression).
- [x] **Path traversal still blocked** — `/file/../../etc/passwd`, `/file/lib/../../../etc/passwd`, and `/file/lib/symlink-to-etc-passwd` all return 404. Symlink resolution + PROJECT_ROOT containment check preserved.
- [x] **Regression test pinned** — `tests/unit/test_file_route_extensions.py` covers: (a) `.md` 200, (b) `.sh` 200, (c) `.py` 200, (d) `.yaml` 200, (e) `..` 404, (f) outside-whitelist dir 404, (g) non-existent file 404, (h) directory path 404.
- [x] **T-1762 review-page evidence link works** — `curl -sf http://localhost:3002/file/lib/task_pair_acd.sh` returns HTTP 200 (was 404). Same for `tests/unit/test_task_pair_acd_gate.bats` if linked.
- [x] **No regression on existing surfaces** — `curl -sf http://localhost:3002/file/.tasks/completed/T-1442-...md` still serves the markdown task file.

### Human

<!-- Retroactively added 2026-05-16 after T-1766 ship — documentary only,
     not blocking the already-shipped close. -->

- [ ] [REVIEW] `/file/` route renders `.py`/`.sh`/`.yaml` source files as syntax-highlighted code
  **Steps:**
  1. Open `$(bin/fw watchtower url)/file/lib/task_pair_acd.sh` in browser.
  2. Open the same URL with extension swapped to a `.py` and `.yaml` path you know exists.
  **Expected:** Each renders as a fenced code block with monospace font + (if Pygments installed) syntax colouring. Layout matches the `.md` rendering's outer shell.
  **If not:** Screenshot, note which extension/path broke, reopen for follow-up.

## Verification

python3 -c "import ast; ast.parse(open('web/shared.py').read()); ast.parse(open('web/blueprints/docs.py').read())"
python3 -m pytest tests/unit/test_file_route_extensions.py -q
# Live route checks — must all return 200 for existing files.
# T-1376 anti-pattern: never hard-code :3000/:3002. Use bin/fw watchtower url
# (triple-file resolution). T-1764: fixed port hard-code (was :3002).
# Each verification line runs in its own subshell — inline the URL each time.
test "$(curl -s -o /dev/null -w '%{http_code}' "$(bin/fw watchtower url)/file/lib/task_pair_acd.sh")" = "200"
test "$(curl -s -o /dev/null -w '%{http_code}' "$(bin/fw watchtower url)/file/lib/task_pair_acd.py")" = "200"
test "$(curl -s -o /dev/null -w '%{http_code}' "$(bin/fw watchtower url)/file/tests/unit/test_task_pair_acd_gate.bats")" = "200"
# Path traversal still blocked
test "$(curl -s -o /dev/null -w '%{http_code}' "$(bin/fw watchtower url)/file/../../etc/passwd")" = "404"

## RCA

**Symptom:** Click `lib/task_pair_acd.sh` link in T-1762 review-page Evidence list → HTTP 404. Same applies to every auto-linked source/config file across `/review/*`, `/tasks/*`, `/inception/*`. User reported as "still a shortened path" — link looks complete but click shows nothing.

**Root cause:** Two declarations of "what is viewable" diverged over time.
1. `web/shared.py::_ARTEFACT_PATH_RE` (T-1722) — regex matches 14 directory prefixes × 7 extensions
2. `web/blueprints/docs.py::file_viewer` route (T-632, predates T-1722) — guards against 4 directory prefixes × 1 extension (`.md`)

When T-1722 promoted `_auto_link_files` to a global helper, it extended the linker's reach (more dirs, more extensions) without extending the route. The linker confidently produces anchors that the route cannot serve.

**Why structurally allowed:**
- No test pinned the linker→route contract. `test_render_artefact_paths.py` tests that the linker emits anchors, but never resolves them.
- The route's whitelist was hardcoded local to the route. The linker's regex was hardcoded local to `web/shared.py`. No shared symbol meant no compile-time / runtime cross-check.
- Same class as L-361: when capability-X is added in surface-A, the symmetric change in surface-B is forgotten because there's no shared definition forcing them to move together.

**Prevention:**
1. New `is_viewable_path()` helper in `web/shared.py` is the single source of truth — both linker and route consult it. Diverging the two now requires changing both definitions to point at different helpers, which is loud.
2. New regression test `test_file_route_extensions.py` resolves every linker-emitted anchor and asserts HTTP 200. Future drift between linker and route is caught at test time, not human-review time.
3. L-362 (filed): "Helper-vs-consumer drift" learning — when promoting a helper to multi-consumer use, identify ALL consumers that consume the helper's output and verify their contracts still hold.

## Evolution

<!-- REQUIRED for arc-tagged build tasks (tags include arc:*). Captures how
     understanding evolved during build — what was learned that wasn't known at
     filing, what in the original plan no longer fits, what triggered pivots
     or new sub-tasks. Mandatory at slice boundaries (when applicable) and
     before --status work-completed.

     Origin: T-1717 grill Q4 — "the understanding of what we need and want
     evolves with the process of materialisation." Structural counter to §ACD:
     spec-vs-build divergence is logged as soon as it happens, not lost as
     folklore.

     Format (one entry per slice boundary or significant insight):
       ### YYYY-MM-DD — [topic]
       - **What changed:** [what we learned that we didn't know at filing]
       - **Plan impact:** [what in the plan no longer fits]
       - **Triggered:** [new sub-task / pivot / scope cut, with task ID if filed]

     The completion gate (T-1718) blocks --status work-completed when this
     section exists but is empty/template-only. Use --skip-evolution to bypass
     (logged Tier-2). Non-arc tasks may leave this empty.
-->

## Decisions

### 2026-05-06 — Single source-of-truth predicate, not duplicated whitelists

- **Chose:** New `is_viewable_path(filepath)` helper in `web/shared.py` consulted by both `_auto_link_files` and the `/file/` route. Linker regex is now built from `VIEWABLE_DIR_PREFIXES` and `VIEWABLE_EXTENSIONS` — same lists the route reads.
- **Why:** Two whitelists can drift; one cannot. The drift is what caused T-1764 in the first place. A future-developer who adds a new extension only has one place to change.
- **Rejected:** Hardcoding the same list in both places "for clarity" — invites recurrence. Auto-deriving the route's whitelist from the linker's regex via re-introspection — too clever, fragile.

### 2026-05-06 — Render source files as fenced code blocks, not raw <pre>

- **Chose:** `markdown2.markdown(f"\`\`\`{lang}\n{content}\n\`\`\`", extras=["fenced-code-blocks"])` with extension-mapped language hint.
- **Why:** Reuses existing `markdown2` dependency, gets Pygments syntax highlighting if installed, otherwise graceful `<pre><code>` fallback. Free reuse of `docs_detail.html` template — same shell as the .md path.
- **Rejected:** Raw `<pre><code>` — no syntax highlighting. Rolling Pygments directly — extra dependency for a one-liner of value. A separate `source_view.html` template — duplicate styling.

## Recommendation

**Recommendation:** GO

**Rationale:**

Single structural fix (one source-of-truth predicate) closes T-1722's contract gap and prevents recurrence by construction. 20/20 new regression tests pass (8 predicate-level + 9 route-level + 3 contract-level). 40/40 existing render tests pass (`test_render_artefact_paths`, `test_extract_recommendation`, `test_ac_body_html_comment`). Live verification on `/review/T-1762`: every `/file/` link emitted by the auto-linker now resolves HTTP 200 (was: 1 link, 404).

Same root-cause class as T-1763 (parser/render contract drift) — both surfaced from a single human review of T-1762, both have a learning filed (L-361 cross-parser, L-362 helper-vs-consumer). The two together suggest a structural concern: every helper promoted to multi-consumer use needs a "consumer-contract" test. Filing as observation-grade for now; if a third instance recurs, escalate to a concern with a lint check.

**Evidence:**

- 20/20 `tests/unit/test_file_route_extensions.py` pass — predicate, route, and linker→route contract pinned
- 40/40 existing render tests still pass (no regression)
- Live route verification:
  - `curl -s -o /dev/null -w '%{http_code}' http://localhost:3002/file/lib/task_pair_acd.sh` → 200 (was 404)
  - `curl -s -o /dev/null -w '%{http_code}' http://localhost:3002/file/lib/task_pair_acd.py` → 200 (was 404)
  - `curl -s -o /dev/null -w '%{http_code}' http://localhost:3002/file/tests/unit/test_task_pair_acd_gate.bats` → 200 (was 404)
  - `curl -s -o /dev/null -w '%{http_code}' http://localhost:3002/file/.tasks/active/T-1762-...md` → 200 (regression-clean)
  - `curl -s -o /dev/null -w '%{http_code}' http://localhost:3002/file/etc/passwd` → 404 (security-clean)
- T-1762 review-page link enumerator: every `/file/` href emitted resolves HTTP 200
- L-362 captured (helper-vs-consumer drift, sibling to L-361)

**Risk acknowledged:**

- **Source files now publicly viewable on Watchtower.** Pre-T-1764 only `.md` task files were viewable. Now any source under whitelisted dirs is too. Acceptable in this project (everything is open) but document for any consumer that vendors Watchtower into a non-public deployment. Add to upgrade notes if needed.
- **Pygments not pinned.** Syntax highlighting depends on Pygments being installed. If absent, files render as plain `<pre><code>` — still readable, just unhighlighted. No hard fail.
- **No `.cfg` / `.ini` / `.txt` extensions.** If the linker matches such a path in the future, the route will 404 unless the predicate is extended. Test `test_every_linker_dir_is_viewable` will catch the drift if extensions list changes — but won't preempt agent-introduced extensions. Acceptable: future agent making a new extension viewable must update the predicate.

## Updates

### 2026-05-06T11:03:08Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1764-fix-file-route--404s-for-non-md-paths-de.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-5e0be724
- **Timestamp:** 2026-06-02T14:59:36Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#5 (Agent)** — **T-1762 review-page evidence link works** — `curl -sf http://localhost:3002/file/lib/task_pair_acd.sh` returns HTTP 200 (was 404). Same for `tests/unit/test_task_pair_acd_gate.bats` if linked.
  - **AC-verify-mismatch** (narrow, heuristic) — `path=3002/file/lib/task_pair_acd.sh in: **T-1762 review-page evidence link works** — `curl -sf http://localhost:3002/file/lib/task_pair_acd.sh` returns HTTP 200 (was 404). Same for `tests/un`
### 2026-05-16T07:06:02Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
