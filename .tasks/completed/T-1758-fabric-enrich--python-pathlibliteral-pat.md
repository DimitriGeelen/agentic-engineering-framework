---
id: T-1758
name: "fabric enrich — Python pathlib/literal path-ref detector (T-1754 sibling)"
description: >
  fabric enrich — Python pathlib/literal path-ref detector (T-1754 sibling)

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: ["fabric", "drift-defense"]
components: ["agents/fabric/lib/enrich.py"]
related_tasks: ["T-1753", "T-1754"]
arc_id: orchestrator-rethink
created: 2026-05-06T05:31:04Z
last_update: '2026-08-16T22:24:43Z'
date_finished: 2026-05-06T05:42:33Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:58Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 0
      D4: 2
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=0
      (no-signal); D4=2 (body:env-class-handled); F-RECALL=2 
      (body:lightly-promoted); F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=1 (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:43Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 0
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=0
      (no-signal); D4=2 (body:env-class-handled); F-RECALL=2 
      (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=1 (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-1758: fabric enrich — Python pathlib/literal path-ref detector (T-1754 sibling)

## Context

T-1753 ran `fw fabric enrich` mechanically (100→84 edgeless cards). T-1754 added a `.bats` parser + `standalone:` flag (84→33 cumulative). 27 of the 33 residual edgeless cards are Python files — the existing `detect_python_imports` only handles `from X import Y` and `render_page("...")` patterns, missing the dominant test-file shapes:

- `REPO_ROOT / "bin" / "fw"` — pathlib slash-chain with literal segments
- `subprocess.run(["bash", str(FW), ...])` after `FW = REPO_ROOT / "bin" / "fw"`
- `importlib.util.spec_from_file_location("name", str(PARSER_PATH))` where PARSER_PATH is a pathlib chain
- Literal strings like `"agents/handover/handover.sh"` matching framework directories

This task adds `detect_python_path_refs(content, source_location, framework_root)` modelled on the .bats parser (T-1754) — same dispatch shape, same dedup contract, same standalone-skip behaviour.

## Acceptance Criteria

### Agent
- [x] `agents/fabric/lib/enrich.py` exports `detect_python_path_refs(content, source_location, framework_root) -> list[(target, etype)]` covering pathlib-chain, literal-quoted-paths, and bare `bin/fw` patterns
- [x] `is_python` dispatch branch in enrich.py calls `detect_python_path_refs` in addition to `detect_python_imports`
- [x] Self-references (target == source_location) excluded; unknown targets (not on disk) skipped; (target, etype) deduped
- [x] `tests/unit/test_enrich_python_path_refs.py` covers ≥6 patterns: pathlib slash-chain, str(pathlib_var), bare `bin/fw`, literal quoted path, dedup, self-reference exclusion, unknown-target skip
- [x] `pytest tests/unit/test_enrich_python_path_refs.py -q` passes 100% (10/10)
- [x] After `fw fabric enrich` run, edgeless count in `fw audit` drops below current 36 — landed at 8 (target ≤25 met, also cleared WARN threshold)

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.
     Optionally prefix with [RUBBER-STAMP] or [REVIEW] for prioritization.
     Example:
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error
-->

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.
#
# Toolchain hint (L-291): if you edited *.vbproj/*.csproj/*.xaml add `dotnet build`;
# *.go → `go build ./...`; Cargo.toml → `cargo check`; tsconfig.json → `tsc --noEmit`;
# pom.xml → `mvn -q compile`. P-011 runs only what you write — broken builds slip
# past otherwise (origin: 003-NTB-ATC-Plugin T-077, broken WPF DLL on master 5 days).

cd /opt/999-Agentic-Engineering-Framework && pytest tests/unit/test_enrich_python_path_refs.py -q
cd /opt/999-Agentic-Engineering-Framework && python3 -c "import os,yaml; n=sum(1 for f in os.listdir('.fabric/components') if (lambda d: d and not d.get('standalone') and not d.get('depends_on') and not d.get('depended_by'))(yaml.safe_load(open(os.path.join('.fabric/components',f))))); print(f'edgeless={n}'); assert n<=25, f'edgeless count {n} > 25 target'"

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

### 2026-05-06 — scope expanded mid-task: dotted-import + missing fabric cards
- **What changed:** Initial scope was a path-ref detector (pathlib slash-chains + literal paths). After running it, edgeless dropped 36→14 — short of the WARN-clearing target. Investigation revealed two separate causes for residual edgeless: (a) `from lib.X / agents.X / tools.X` imports were being missed because `detect_python_imports` regex was hard-coded to `web.*`; (b) 8 `lib/reviewer/*.py` files had no fabric card at all, so `resolve_edges` dropped every edge pointing at them (loc_to_id miss).
- **Plan impact:** A pure path-ref detector wouldn't have cleared the WARN — the actual problem mix was 27 path-ref-shaped misses + 8 unregistered-target misses + 3 standalone-by-design (prompts/research). Fixed all three in this task rather than splitting.
- **Triggered:** No new tasks filed. Inline within T-1758: `detect_python_imports` regex extended to `(web|lib|agents|tools)\.X`; 8 `lib/reviewer/*.py` cards registered via `fw fabric register`; 3 cards (`prompts/default.md`, `prompts/escalation-triage.md`, `docs/reports/T-1688-candidate-consumer-survey.md`) marked `standalone: true`.

## Recommendation

**Recommendation:** GO

**Rationale:** Fabric WARN cleared structurally. Edgeless dropped 36 → 8 (-78%); audit `[WARN] Fabric: 14/539` (pre-task) → `[PASS] Fabric edges: 536/544` (post-task). The 8 residuals are genuine orphans by design: hook scripts invoked by Claude Code config, static JS referenced via Jinja `url_for()`, and playwright tests that exercise URLs not framework files. Detector contract pinned by 10 unit tests covering pathlib chains, literal paths, bare `bin/fw`, dedup, self-reference exclusion, unknown-target skip, and mixed patterns. T-1754's `.bats` shape was reused — same dispatch, same dedup contract, same standalone-skip behaviour.

**Evidence:**
- `tests/unit/test_enrich_python_path_refs.py` — 10/10 passing, covers all advertised patterns
- `bin/fw audit` post-run: `[PASS] Fabric edges: 536/544 cards enriched (8 without edges)` — was `[WARN] 14/539`
- 36 → 8 edgeless (3-step delta: T-1758 detector +14 dropped via path-refs, +5 via missing-card registrations, +3 via standalone flagging)
- 8 residual cards (legitimate orphans): `agents/context/check-human-ac-tick.sh` (hook config), `web/static/csrf-htmx.js` (Jinja url_for), 4 playwright tests, `tests/scripts/yaml_parse_all_tasks.py`, `tests/unit/test_arcs_routes.py` — all use patterns that don't reference framework files by path

## Decisions
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

### 2026-05-06T05:31:04Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1758-fabric-enrich--python-pathlibliteral-pat.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-e7fd4a65
- **Timestamp:** 2026-06-02T14:59:33Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#1 (Agent)** — `agents/fabric/lib/enrich.py` exports `detect_python_path_refs(content, source_location, framework_root) -> list[(target, etype)]` covering pathlib-chain, literal-quoted-paths, and bare `bin/fw` patte
  - **AC-verify-mismatch** (narrow, heuristic) — `path=agents/fabric/lib/enrich.py in: `agents/fabric/lib/enrich.py` exports `detect_python_path_refs(content, source_location, framework_root) -> list[(target, etype)]` covering pathlib-ch`
### 2026-05-06T05:42:33Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
