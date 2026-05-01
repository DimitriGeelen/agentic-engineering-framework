---
id: T-1647
name: "Watchtower /orchestrator page — orchestrator-arc surface"
description: >
  W10 #2 — directly answers the question that triggered T-1641 ('absolutely seeing nothing that indicates we are now orchestrating'). Single Watchtower page surfacing: (a) MCP audit summary from .context/audits/orchestrator-LATEST.yaml (gated/total, drift findings, deprecated facades), (b) live sessions parsed from termlink list --json with task-type/role/task tag breakdown, (c) per-task-type specialist counts, (d) cross-link panel to T-1641 reconsideration artefact + T-1642/T-1643/T-1644 follow-up arcs. Modeled after web/blueprints/hooks.py shape.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [from-T-1641, t-1061-followup, drift-defense, watchtower, observability, arc:orchestrator-rethink]
components: []
related_tasks: [T-1641, T-1644, T-1646, T-1063, T-1064, T-1066]
created: 2026-05-01T12:14:30Z
last_update: 2026-05-01T18:57:17Z
date_finished: null
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
- [ ] [REVIEW] Page conveys whether the orchestrator arc is "doing anything" at a glance
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
