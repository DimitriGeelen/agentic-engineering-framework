---
id: T-1723
name: "T-1722 follow-up: extend artefact linkifier to inception._md and core project-doc
  renderers"
description: >
  T-1722 follow-up: extend artefact linkifier to inception._md and core project-doc
  renderers

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [ux, watchtower]
components: [web/blueprints/core.py, web/blueprints/inception.py]
related_tasks: [T-1722, T-1721, T-1575, T-633]
arc_id: orchestrator-rethink
created: 2026-05-04T19:10:31Z
last_update: '2026-08-16T22:24:42Z'
date_finished: 2026-05-04T19:14:11Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:56Z'
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
  - ts: '2026-08-16T22:24:42Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal); F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-1723: T-1722 follow-up: extend artefact linkifier to inception._md and core project-doc renderers

## Context

T-1722 promoted the artefact linkifier to `web/shared.py` and wired it into
`render_markdown_safe()` plus `_render_md_inline/_render_md_block` in tasks.py.
Two markdown render sites still use bare `markdown2.markdown()` and so do not
get the new linkifier:

1. `web/blueprints/inception.py:_md()` — used by /inception/<task_id> pages.
2. `web/blueprints/core.py:project_doc()` — renders /<doc-name> like /CLAUDE,
   /FRAMEWORK, project-doc viewer.

Both surfaces routinely contain artefact paths that the human-reviewer would
want one-click access to (CLAUDE.md cross-references docs/reports/, agents/,
.fabric/components/; inception artifacts cite docs/reports/ and .context/
audits/ throughout).

Trivial extension: pipe each render's output through `_auto_link_files`
before returning the HTML. Existence-gated, idempotent — same contract as
T-1722, no new tests needed (the function is already covered).

## Acceptance Criteria

### Agent
- [x] `web/blueprints/inception.py:_md()` calls `_auto_link_files(html)` before returning Markup.
- [x] `web/blueprints/core.py:project_doc()` calls `_auto_link_files(html_content)` after the markdown→HTML conversion.
- [x] Both blueprints import `_auto_link_files` from `web.shared`.
- [x] Existing T-1722 + T-1575 test suites still pass: `tests/unit/test_render_artefact_paths.py` (12) + `tests/unit/test_extract_recommendation.py` (24).
- [x] Live verification: `curl -sf $(bin/fw watchtower url)/inception/T-1717` contains `href="/file/docs/reports/T-1717-embeddings-strategy-grill.md"` (or another artefact-path anchor on a known inception page).
- [x] Live verification: `curl -sf $(bin/fw watchtower url)/project/CLAUDE` contains at least one `href="/file/"` anchor (CLAUDE.md cross-references many artefact paths). Route is `/project/<doc>` per `web/blueprints/core.py:524`.

## Verification

test -f web/blueprints/inception.py
test -f web/blueprints/core.py
python3 -c "from web.blueprints.inception import _md; assert callable(_md); print('inception OK')"
PROJECT_ROOT=$(pwd) python3 -m pytest tests/unit/test_render_artefact_paths.py tests/unit/test_extract_recommendation.py -q
# curl into file (avoids SIGPIPE/exit 23 when grep -q closes pipe early under pipefail)
curl -sf "$(bin/fw watchtower url)/project/CLAUDE" -o /tmp/t1723-claude.html && grep -qE 'href="/file/(docs|agents|web|lib|bin)/' /tmp/t1723-claude.html

## Recommendation

**Recommendation:** GO

**Rationale:**

Trivial completion of T-1722. Two render sites that bypassed the new
linkifier now go through it. Same existence-gated, idempotent contract.
No new tests needed — coverage is in `tests/unit/test_render_artefact_paths.py`
(promoted function), and T-1722's regression suite still passes (36/36).

**Evidence:**

- `web/blueprints/inception.py:17-26` — `_md()` now calls `_auto_link_files`.
- `web/blueprints/core.py:551-553` — `project_doc()` now calls `_auto_link_files`.
- Both import from `web.shared` (single source of truth).
- 36/36 tests pass (12 T-1722 + 24 T-1575 contract).
- Live: `/inception/T-1721` → 7 unique `/file/` anchors (was 0).
- Live: `/project/CLAUDE` → 11 unique `/file/` anchors (was 0).
- Live: `/project/FRAMEWORK` → 2 unique `/file/` anchors (was 0).

## Evolution

### 2026-05-04 — second-pass coverage sweep
- **What changed:** T-1722 only covered `render_markdown_safe` and the
  inline/block renderers in tasks.py. Two more markdown render sites use
  bare `markdown2.markdown()` — found by grepping `web/blueprints/*.py`.
- **Plan impact:** None — same idiom, same function, same contract.
- **Triggered:** Filed as a separate task (T-1723) per Task Sizing
  ("one task = one deliverable"). Coverage now spans every
  `web/blueprints/` markdown render site (verified by grep).

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

### 2026-05-04T19:10:31Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1723-t-1722-follow-up-extend-artefact-linkifi.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-346b42e5
- **Timestamp:** 2026-06-02T14:59:20Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-04T19:14:11Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
