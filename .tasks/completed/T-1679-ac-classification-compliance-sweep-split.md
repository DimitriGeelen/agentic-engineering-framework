---
id: T-1679
name: "AC classification compliance sweep: split Human ACs of T-1062/T-1064/T-1065/T-1066 into Agent (mechanical, verifiable) + Human (genuinely subjective) per CLAUDE.md AC Classification Matrix"
description: >
  AC classification compliance sweep: split Human ACs of T-1062/T-1064/T-1065/T-1066 into Agent (mechanical, verifiable) + Human (genuinely subjective) per CLAUDE.md AC Classification Matrix

status: work-completed
workflow_type: refactor
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-05-02T11:37:12Z
last_update: 2026-05-02T11:45:37Z
date_finished: 2026-05-02T11:45:37Z
---

# T-1679: AC classification compliance sweep: split Human ACs of T-1062/T-1064/T-1065/T-1066 into Agent (mechanical, verifiable) + Human (genuinely subjective) per CLAUDE.md AC Classification Matrix

## Context

T-1062/T-1064/T-1065/T-1066 each carry a single `[REVIEW]` Human AC that conflates mechanical verifications (test pass, regression, code shape) with genuinely subjective design judgment ("clean", "useful", "intelligent defaults"). All four have empty `Steps:` blocks — non-compliant with §Human AC Format Requirements (T-325). Predecessor tasks for the orchestrator-rethink arc, each in human review queue 24-58 days.

Per CLAUDE.md §AC Classification Guidance: deterministic + reversible + internal scope + mechanical → Agent AC; subjective + irreversible → Human AC. Per T-193 Agent/Human AC Split: agent ACs gate completion (P-010), human ACs do not.

This task splits each Human AC into Agent + Human halves with proper Steps/Expected/If-not on the residual Human AC. Mechanical claims ride agent verification commands; subjective ship-decisions remain human-owned. No AC is checked as part of this task — restructuring only.

Anchor probes captured this session:
- T-1064: `task_type` parsed at `router.rs:1156` as Option<String>; backward-compat test at line 3350
- T-1065: `DEFAULT_MODEL_FALLBACK = ["opus","sonnet","haiku"]` in circuit_breaker.rs; resolve_dispatch_model at tools.rs:854 with 3 unit tests
- T-1066: governance_subscriber.rs uses async + broadcast::Receiver + mpsc::Sender (non-blocking shape); 5+ unit tests
- T-1062: plugin file at /opt/termlink/plugins/wezterm/termlink-chrome.lua; visual rendering needs desktop env

## Acceptance Criteria

### Agent
- [x] T-1062 Human AC split. Original `[REVIEW] Terminal chrome displays task state correctly` decomposed into: 3 mechanical Agent ACs (plugin file present, Lua syntax-valid, queries `termlink list --json` and `termlink status`) + 1 residual Human AC (visual render in live wezterm session — needs desktop env). `grep -E "^- \[ \] \[REVIEW\] Terminal chrome displays" .tasks/active/T-1062-*.md` returns NOTHING (original AC replaced).
- [x] T-1064 Human AC split. Original `[REVIEW] Routing design review` decomposed into: 3 mechanical Agent ACs (cargo test pass, backward-compat test pass, task_type field is Option<String>) + 1 residual Human AC (composite-key shape `method::task_type` — accept now or refactor to RoutingKey newtype first; T-1636 captured). `grep -E "^- \[ \] \[REVIEW\] Routing design review$" .tasks/active/T-1064-*.md` returns NOTHING.
- [x] T-1065 Human AC split. Original `[REVIEW] Multi-LLM routing design` decomposed into: 3 mechanical Agent ACs (resolver picks correctly per cache, fallback chain is opus→sonnet→haiku, outcome attribution uses task.completed `ok` field) + 1 residual Human AC (cost-aware routing NOT implemented — ship as-is or refactor first). `grep -E "^- \[ \] \[REVIEW\] Multi-LLM routing design$" .tasks/active/T-1065-*.md` returns NOTHING.
- [x] T-1066 Human AC split. Original `[REVIEW] Data plane governance design` decomposed into: 3 mechanical Agent ACs (subscriber is async + non-blocking shape, governance frame 0x8 protocol pinned, pattern detection unit tests pass) + 1 residual Human AC (subjective: are detected patterns useful?). `grep -E "^- \[ \] \[REVIEW\] Data plane governance design$" .tasks/active/T-1066-*.md` returns NOTHING.
- [x] All four task files still have at least one `### Human` AC remaining (residual subjective). `for t in T-1062 T-1064 T-1065 T-1066; do grep -A30 "^### Human" .tasks/active/${t}-*.md | grep -q "^- \[ \] \[REVIEW\]" || echo "FAIL: $t lost human AC"; done` produces no FAIL lines.
- [x] All four task files' frontmatter still parses (no YAML breakage). `for t in T-1062 T-1064 T-1065 T-1066; do python3 -c "import yaml; yaml.safe_load(open('.tasks/active/${t}-'+__import__('glob').glob('.tasks/active/${t}-*.md')[0].split('${t}-')[-1]).read().split('---',2)[1])"; done` exits 0.
- [x] Mechanical Agent ACs are RUN and ticked where they pass (separate from this task's own ACs). Each of T-1062/T-1064/T-1065/T-1066 has the new Agent ACs verified and checked, OR clearly noted in an Updates entry where verification couldn't run (e.g. T-1062 visual render).

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.
     Optionally prefix with [RUBBER-STAMP] or [REVIEW] for prioritization.
     Example:
       - [x] [REVIEW] Dashboard renders correctly
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
# AC1-4: original [REVIEW] lines removed (replaced with split versions)
test -z "$(grep -hE '^- \[ \] \[REVIEW\] (Terminal chrome displays task state correctly when TermLink sessions are active|Routing design review|Multi-LLM routing design|Data plane governance design)' .tasks/active/T-1062-*.md .tasks/active/T-1064-*.md .tasks/active/T-1065-*.md .tasks/active/T-1066-*.md)"
# AC5: each file still has ≥1 [REVIEW] human AC remaining
for t in T-1062 T-1064 T-1065 T-1066; do f=$(echo .tasks/active/${t}-*.md); awk '/^### Human/,/^## /' "$f" | grep -q "^- \[ \] \[REVIEW\]"; done
# AC6: all four frontmatters still parse
python3 -c "import yaml,glob; [yaml.safe_load(open(glob.glob(f'.tasks/active/{t}-*.md')[0]).read().split('---',2)[1]) for t in ['T-1062','T-1064','T-1065','T-1066']]"

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

### 2026-05-02T11:37:12Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1679-ac-classification-compliance-sweep-split.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-36be0cd2
- **Timestamp:** 2026-06-02T14:59:05Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 12
     - evidence: `for t in T-1062 T-1064 T-1065 T-1066; do f=$(echo .tasks/active/${t}-*.md); awk '/^### Human/,/^## /' "$f" | grep -q "^- \[ \] \[REVIEW\]"; done`
### 2026-05-02T11:45:37Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
