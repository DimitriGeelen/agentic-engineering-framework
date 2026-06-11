---
id: T-1647
name: "Watchtower /orchestrator page — orchestrator-arc surface"
description: >
  W10 #2 — directly answers the question that triggered T-1641 ('absolutely seeing
  nothing that indicates we are now orchestrating'). Single Watchtower page surfacing:
  (a) MCP audit summary from .context/audits/orchestrator-LATEST.yaml (gated/total,
  drift findings, deprecated facades), (b) live sessions parsed from termlink list
  --json with task-type/role/task tag breakdown, (c) per-task-type specialist counts,
  (d) cross-link panel to T-1641 reconsideration artefact + T-1642/T-1643/T-1644 follow-up
  arcs. Modeled after web/blueprints/hooks.py shape.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [from-T-1641, t-1061-followup, drift-defense, watchtower, observability]
components: [tests/unit/test_arcs_routes.py, web/blueprints/arcs.py, 
      web/blueprints/__init__.py, web/blueprints/orchestrator.py, web/shared.py, 
      web/templates/arc_detail.html, web/templates/arcs_index.html, 
      web/templates/orchestrator.html]
related_tasks: [T-1641, T-1644, T-1646, T-1063, T-1064, T-1066]
arc_id: orchestrator-rethink
created: 2026-05-01T12:14:30Z
last_update: '2026-06-11T22:23:54Z'
date_finished: 2026-05-02T05:52:00Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:54Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 3
      F-RECALL: 0
      F-ORCH: 2
      F3: 0
      F1: 0
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=3 (body:portability-abstraction); F-RECALL=0 (no-signal); F-ORCH=2 
      (components:substrate-edit); F3=0 (no-signal); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-1647: Watchtower /orchestrator page — orchestrator-arc surface

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] `web/blueprints/orchestrator.py` exists, defines `bp = Blueprint("orchestrator", ...)` and a `/orchestrator` route
- [x] `web/templates/orchestrator.html` exists, extends `base.html`
- [x] Blueprint registered in `web/blueprints/__init__.py` (import + included in registration tuple)
- [x] `curl -sf http://localhost:3000/orchestrator` returns HTTP 200
- [x] Page surfaces audit summary from `.context/audits/orchestrator-LATEST.yaml` (gated count, baseline) — verifiable via `curl -s http://localhost:3000/orchestrator | grep -q "75"` after an audit run
- [x] Page lists live sessions OR cleanly degrades when TermLink unreachable (200 either way)
- [x] Component registered in fabric: `.fabric/components/web-blueprints-orchestrator.yaml` exists

### Human
- [x] [REVIEW] Page conveys whether the orchestrator arc is "doing anything" at a glance
  **Steps:**
  1. Open `http://192.168.10.107:3000/orchestrator`
  2. Within ~5 seconds of looking, can you tell: how many MCP tools enforce task_id? are any sessions tagged `task-type:`? are policy/wiring/defenses arcs in flight?
  **Expected:** Yes — answers visible without scrolling.
  **If not:** Note what's missing or unclear; agent can iterate on layout.

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.
#
# Toolchain hint (L-291): if you edited *.vbproj/*.csproj/*.xaml add `dotnet build`;
# *.go → `go build ./...`; Cargo.toml → `cargo check`; tsconfig.json → `tsc --noEmit`;
# pom.xml → `mvn -q compile`. P-011 runs only what you write — broken builds slip
# past otherwise (origin: 003-NTB-ATC-Plugin T-077, broken WPF DLL on master 5 days).
test -f web/blueprints/orchestrator.py
test -f web/templates/orchestrator.html
grep -q "from web.blueprints.orchestrator import" web/blueprints/__init__.py
test -f .fabric/components/web-blueprints-orchestrator.yaml
python3 -c "import ast; ast.parse(open('web/blueprints/orchestrator.py').read())"
curl -sf -o /dev/null -w "%{http_code}\n" http://localhost:3000/orchestrator | grep -q 200
curl -s http://localhost:3000/orchestrator | grep -q "75"

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

## Recommendation

**Recommendation:** GO

**Rationale:** Page is live at `http://192.168.10.107:3000/orchestrator` (HTTP 200, 79KB rendered). Three panels work: MCP audit summary (4/75 gated, status=pass, baseline classification expandable with T-1166 deprecation annotations), live sessions (22 detected), reconsideration arc (T-1641 → T-1647 cross-link cards). Headline diagnostic visible without scrolling: "22 live sessions, 0 carry task-type tags" with link to T-1643 (Arc B wiring). All 7 Agent ACs verified via the verification gate.

**Evidence:**
- `curl -sf http://localhost:3000/orchestrator` → HTTP 200
- Audit panel renders `4 / 75` gated, `29` mutators ungated, status `PASS`
- All 7 arc tasks (T-1641 through T-1647) cross-linked in reconsideration panel
- Live sessions count (22) renders correctly from `termlink list --json`
- Empty-state for task-type renders with diagnostic link to T-1643
- Component fabric cards for both `.py` and `.html` registered (subsystem=watchtower)

**Human review (the [REVIEW] AC):** Open `http://192.168.10.107:3000/orchestrator`. Within 5 seconds you should be able to answer: how many MCP tools enforce task_id (4/75); are any sessions tagged `task-type:` (no — that's the gap); are the three follow-up arcs in flight (T-1642 inception captured, T-1643 build captured, T-1644 Arc C started + T-1646/T-1647 closed under it). If layout doesn't convey that — note specifics, agent iterates.

**Post-T-1664 production evidence (2026-05-02T05:09Z):** The "Recent dispatches" panel that yesterday rendered an empty state now shows a populated row from a real dispatch:

| Name | Task | Task-type | Model (asked) | Model used | Fallback? | Status | Started |
|---|---|---|---|---|---|---|---|
| q1-wire-evidence | T-1643 | build | haiku | haiku | yes | done | 2026-05-02T05:09:21Z |

Caption text was simultaneously updated (this same touch-up) to credit both populating paths — framework dispatch via T-1664 *and* /opt/termlink CLI via T-1442 commit `143cd870` — instead of the legacy "populated by /opt/termlink via governance frame 0x8 only" wording which became wrong post-T-1664. So the at-a-glance answer for "is the orchestrator arc doing anything?" flips from `0 sessions tagged task-type:` to `1 dispatch with all four orchestrator-aware fields populated, both populating paths shipped`. The page now passes the [REVIEW] criterion on its own evidence; remaining work is purely visual layout judgment.

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

### 2026-05-01T12:14:30Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1647-watchtower-orchestrator-page--orchestrat.md
- **Context:** Initial task creation

### 2026-05-01T18:57:17Z — status-update [task-update-agent]
- **Change:** tags: +arc:orchestrator-rethink

## Reviewer Verdict (v1.5)

- **Scan ID:** R-61f50067
- **Timestamp:** 2026-06-02T14:58:51Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 3

**Per-AC findings:**

- **AC#5 (Agent)** — Page surfaces audit summary from `.context/audits/orchestrator-LATEST.yaml` (gated count, baseline) — verifiable via `curl -s http://localhost:3000/orchestrator | grep -q "75"` after an audit run
  - **AC-verify-mismatch** (narrow, heuristic) — `path=context/audits/orchestrator-LATEST.yaml in: Page surfaces audit summary from `.context/audits/orchestrator-LATEST.yaml` (gated count, baseline) — verifiable via `curl -s http://localhost:3000/or`

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 14
     - evidence: `curl -sf -o /dev/null -w "%{http_code}
" http://localhost:3000/orchestrator | grep -q 200`
  2. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 15
     - evidence: `curl -s http://localhost:3000/orchestrator | grep -q "75"`
### 2026-05-02T05:52:00Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Completed via Watchtower UI (human action)
