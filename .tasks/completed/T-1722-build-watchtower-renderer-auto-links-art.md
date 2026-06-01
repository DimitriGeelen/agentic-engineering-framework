---
id: T-1722
name: "Build: Watchtower renderer auto-links artefact paths (T-1721 implementation)"
description: >
  Build: Watchtower renderer auto-links artefact paths (T-1721 implementation)

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [ux, watchtower]
components: [web/blueprints/docs.py, web/blueprints/tasks.py, web/shared.py]
related_tasks: [T-1721, T-1575, T-633]
arc_id: orchestrator-rethink
created: 2026-05-04T17:18:51Z
last_update: 2026-05-04T19:06:16Z
date_finished: 2026-05-04T19:06:16Z
---

# T-1722: Build: Watchtower renderer auto-links artefact paths (T-1721 implementation)

## Context

T-1721 GO. Spike findings:

**Spike 1 (routes inventory):** Watchtower already has every route the linkifier needs.
- `/tasks/<task_id>`, `/episodic/...` (via `/file/`), `/inception/<task_id>`, `/review/<task_id>`
- `/fabric/component/<name>`, `/docs/generated/<card_name>`
- `/file/<path:filepath>` — generic file viewer (catches everything else)
- `/decisions`, `/learnings`, `/gaps`, `/arcs/<arc_id>`

**Spike 2 (renderer hook):** A path-linkifier ALREADY EXISTS at `web/blueprints/docs.py:21-40`
(`_FILE_REF_RE` + `_auto_link_files`, T-633). It is blueprint-private — exactly the
anti-pattern T-1575 RCA called out. Promotion to `web/shared.py:render_markdown_safe`
follows the same shape that T-1575 used for the URL/T-NNNN linkifiers.

**Spike 3 (port resolution):** Not needed. Existing T-NNNN linkifier emits `/tasks/T-NNNN`
(relative). Browser resolves against current `host:port`. Per-project, dynamic, free.
A relative `/file/.context/audits/2026-05-04.yaml` href works on every Watchtower
regardless of port.

**Scope (smaller than estimated):**
1. Promote `_FILE_REF_RE` + `_auto_link_files` from `web/blueprints/docs.py` → `web/shared.py`.
2. Extend the regex prefix set: add `.fabric/components/`, `.context/audits/`,
   `.context/project/`, and root-level source dirs (`web/`, `lib/`, `bin/`, `agents/`).
3. Call from `render_markdown_safe()` after the markdown→HTML pass (alongside the
   existing `_CODE_URL_HTML_RE_SHARED` post-process).
4. Keep the `(PROJECT_ROOT/path).exists()` guard — refuses to link non-existent paths,
   eliminates the false-positive risk identified as A3 in T-1721.
5. Re-export from `web/blueprints/docs.py` for the existing T-633 caller (no behavioural change there).

## Acceptance Criteria

### Agent
- [x] `_FILE_REF_RE` and `_auto_link_files` live in `web/shared.py` (promoted from `web/blueprints/docs.py`).
- [x] Path prefix set extended to: `docs/reports/`, `.tasks/{active,completed}/`, `.context/{handovers,episodic,audits,project}/`, `.fabric/components/`, plus root source dirs `web/`, `lib/`, `bin/`, `agents/`.
- [x] `render_markdown_safe()` invokes the path linkifier after markdown→HTML conversion. Path matches inside backticks remain inside `<code>` (T-1575 contract symmetry).
- [x] `web/blueprints/docs.py` continues to import & call the same function from `web.shared` (single source of truth).
- [x] Existing test `tests/unit/test_extract_recommendation.py::test_render_markdown_safe_makes_backticked_urls_clickable` still passes (no URL-link regression).
- [x] New test `tests/unit/test_render_artefact_paths.py` covers: bare path, backticked path, non-existent path (no link), path inside an existing `[md](url)` (no double-link), all 5 prefix classes.
- [x] Live verification: `curl -sf $(bin/fw watchtower url)/review/T-1700 | grep -q 'href="/file/docs/reports/T-1700-litellm-build.md"'` — the rendered page contains a real anchor for the previously-bare path.

### Human
- [x] [REVIEW] One-click reading verified — open `http://192.168.10.107:3000/review/T-1700`, click on the rendered `docs/reports/T-1700-litellm-build.md` reference; the report opens. No URL hand-construction needed.
  **Steps:**
  1. Open http://192.168.10.107:3000/review/T-1700
  2. Click any `docs/reports/...` reference in the rendered Recommendation/Evidence/AC body
  3. Confirm the file opens via `/file/...` route
  **Expected:** click → file viewer; no copy-paste-into-URL gymnastics.
  **If not:** note which path class did not link (will appear as bare text instead of anchor).

## Verification

test -f web/shared.py
python3 -c "from web.shared import _auto_link_files, _ARTEFACT_PATH_RE; print('OK')"
python3 -c "from web.blueprints.docs import _FILE_REF_RE, _auto_link_files; print('back-compat OK')"
python3 -m pytest tests/unit/test_extract_recommendation.py -q
PROJECT_ROOT=$(pwd) python3 -m pytest tests/unit/test_render_artefact_paths.py -q
curl -sf "$(bin/fw watchtower url)/review/T-1700" | grep -q 'href="/file/docs/reports/T-1700-litellm-build.md"'

## Recommendation

**Recommendation:** GO

**Rationale:**

T-1721 inception found this was even smaller than estimated. The artefact-path
linkifier already existed at `web/blueprints/docs.py:21-40` (T-633) but was
blueprint-private — exactly the anti-pattern T-1575 RCA called out. Promotion
to `web/shared.py` plus prefix-set extension covers every Markdown surface
that reaches a human reviewer: `/review`, `/tasks` (Recommendation/Evidence),
AC Steps/Expected/If-not on every blueprint that uses `_render_md_inline`.

Port-aware: linker emits relative `href="/file/<path>"` URLs. Browser
resolves against the current host:port, so the same code works on every
Watchtower regardless of port — no shell-out, no startup cache, no
`request.host_url` plumbing.

Risk: low. Existence-gated (`(PROJECT_ROOT/path).exists()`) eliminates the
false-positive class A3 in T-1721 — a path that doesn't resolve stays as
plain text. Three negative-lookbehind guards prevent double-wrapping when
the path is already a link target (`href="..."`), already a `/file/` URL,
or the link text immediately following an anchor's closing `">`.

Backwards-compatible: T-633's existing call site (`/docs/generated/<card>`)
re-imports the same function from shared via aliased name (`_FILE_REF_RE`),
no behaviour change.

**Evidence:**

- `web/shared.py:259-310` — promoted regex + `_auto_link_files()`, three
  negative lookbehinds, existence gate.
- `web/shared.py:295` — `render_markdown_safe()` calls `_auto_link_files`
  after the markdown→HTML pass and after `_CODE_URL_HTML_RE_SHARED`.
- `web/blueprints/tasks.py:249,264` — `_render_md_inline` and
  `_render_md_block` both call `_auto_link_files`. Covers AC Steps/Expected/
  If-not on `/review` and `/tasks` surfaces.
- `web/blueprints/docs.py:15-26` — re-imports the promoted function with
  the `_FILE_REF_RE` alias for back-compat with the existing T-633 caller
  at line 163. No call-site change.
- `tests/unit/test_render_artefact_paths.py` — 12 tests, all pass. Covers:
  bare path, backticked path, non-existent path (no link), already-linked
  path (no double-link), all 5 path classes (`docs/reports/`, `.tasks/active/`,
  `.tasks/completed/`, `.fabric/components/`, `.context/audits/`,
  `web/<source>`), URL-link regression, T-NNNN regression, idempotency.
- `tests/unit/test_extract_recommendation.py` — 24 tests, all pass (T-1575
  contract preserved).
- Live verification: `curl -sf $(bin/fw watchtower url)/review/T-1700`
  returns `href="/file/docs/reports/T-1700-litellm-build.md"` and
  `href="/file/docs/reports/T-1700-harness-results.md"`. Was 0 anchors
  before this change — both reports were bare text.

## Evolution

### 2026-05-04 — scope shrank after spike inventory
- **What changed:** T-1721 spikes found the linkifier already existed
  (T-633, blueprint-private) and Watchtower's `/file/<path>` route already
  serves arbitrary paths. Originally estimated as "extend renderer + decide
  port resolution"; turned out to be "promote one function and broaden one
  regex." Port resolution issue evaporated — relative URLs work because
  the browser is already on the right host:port.
- **Plan impact:** Scope cut from 3 spikes + ~4 hour build to 1 hour
  total (spikes folded into Context section, build is essentially a
  refactor + regex extension).
- **Triggered:** Decided to extend `_render_md_inline/_render_md_block`
  in tasks.py too (not just `render_markdown_safe`), because AC Steps go
  through that pipeline. Caught during live verification — T-1722's review
  page initially had 0 /file/ links because Steps render via `_render_md_inline`,
  not `render_markdown_safe`.

## RCA

<!-- REQUIRED for bug-class tasks (workflow_type=build with bug-tag, OR title matches
     fix/bug/rca/broken/crash/error/regression/fail/hotfix).
     Non-bug-class tasks may leave this section empty or remove it.

     For bug-class, fill in:
       **Symptom:** what was observed (the user-facing manifestation).
       **Root cause:** the specific structural/logical gap — not "the code was wrong".
       **Why structurally allowed:** what in the framework/code/tooling let this go undetected.
       **Prevention:** what catches the next instance (test/lint/gate/doc/learning) — distinct from the fix itself.

     The completion gate (T-1550, G-019) blocks --status work-completed when
     bug-class AND this section is empty/template-only. Use --skip-rca to bypass (logged).
-->

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

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Updates

### 2026-05-04T17:18:51Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1722-build-watchtower-renderer-auto-links-art.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.4)

- **Scan ID:** R-f7f00e23
- **Timestamp:** 2026-05-04T19:19:52Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-04T19:06:16Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Completed via Watchtower UI (human action)
