---
id: T-1872
name: "stale-workflow audit: exclude inline:true workflows from staleness — inception/grilling/design-dialogue
  false-positives"
description: >
  stale-workflow audit: exclude inline:true workflows from staleness — inception/grilling/design-dialogue
  false-positives

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: []
related_tasks: []
created: 2026-05-16T07:21:39Z
last_update: '2026-06-11T22:24:01Z'
date_finished: 2026-05-16T07:30:44Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:01Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 0
      D4: 2
      F-RECALL: 0
      F-ORCH: 3
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=0
      (no-signal); D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); 
      F-ORCH=3 (body:typed-io-or-gate); F3=0 (no-signal); F1=0 (no-signal); F2=0
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1872: stale-workflow audit: exclude inline:true workflows from staleness — inception/grilling/design-dialogue false-positives

## Context

T-1803's stale-workflow audit class (`lib/workflow_coverage.py::flag_stale_workflows`) flags ANY declared workflow that has zero dispatches or was last-dispatched >90 days ago. Three workflows in `.context/project/workflows/` carry `inline: true` and are intentionally driven by non-resolver flows (`fw inception start`, `fw grill`, `fw design-dialogue`) rather than `fw resolver dispatch`. They will NEVER have a dispatch record by design — so the staleness detector reports them as WARN forever, polluting the audit signal-to-noise ratio.

Today (2026-05-16) the audit reports "5 stale workflow(s): cheap-research, design-dialogue, grilling, inception, ollama-research". Three of those (design-dialogue, grilling, inception) are false positives. The remaining two (cheap-research, ollama-research) are real signal — workflows declared for the resolver pipeline but never dispatched.

Fix: skip `inline: true` workflows in `flag_stale_workflows`. Real fix is to NOT count them at all, not to exempt them — exemption-by-flag is semantic; "inline" means "not resolver-managed, by design", which excludes the staleness premise.

## Acceptance Criteria

### Agent
- [x] `lib/workflow_coverage.py::flag_stale_workflows` skips rows whose `inline` field is truthy. Inline workflows are not counted toward `stale_workflows` or the `warn` boolean. (Implementation: continue-on-inline guard added at top of the per-workflow loop, T-1872 commented inline.)
- [x] Workflow YAML enrichment (`enrich_with_dispatch_recency` or upstream loader) carries the `inline` field through to the report row, so `flag_stale_workflows` can read it. (Implementation: `_parse_workflows` reads `inline: bool(data.get("inline"))`; `check_workflow_dispatcher_coverage` carries it into the `workflows[]` rows.)
- [x] `tests/unit/test_workflow_coverage.py` pins: (a) inline workflow with no dispatch → NOT stale, (b) non-inline workflow with no dispatch → stale, (c) inline workflow with stale dispatch → still NOT stale, (d) non-inline stale workflow when only inlines exist alongside → warn=False since the non-inline is fresh. Four new tests added under "T-1872: inline workflows excluded from staleness" section. 30/30 pass (was 26/26 before).
- [x] `bin/fw audit` after the fix reports 2 stale workflows (cheap-research, ollama-research) instead of 5 — visible in `.context/audits/2026-05-16.yaml` summary line `"2 stale workflow(s): cheap-research, ollama-research"` (was `"5 stale workflow(s): cheap-research, design-dialogue, grilling, inception, ollama-research"`).
- [x] `bash -n` / `python3 -c "import ast; ast.parse(open('lib/workflow_coverage.py').read())"` clean.

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
#
# Pipefail/SIGPIPE hint (L-387): P-011 runs each command under `set -eo pipefail`.
# `cmd | grep -q PATTERN` exits 141 (SIGPIPE) when grep matches and closes stdin
# while the upstream is still writing — verification then "fails" even though
# the pattern was present. Safe pattern: capture first, grep the capture:
#     out=$(cmd 2>&1); echo "$out" | grep -q "PATTERN"
# Or:
#     cmd > /tmp/.out 2>&1 && grep -q "PATTERN" /tmp/.out
# Origin: L-387, captured 4× (T-1716, T-1838, T-1862, T-1863) before this hint.

python3 -c "import ast; ast.parse(open('lib/workflow_coverage.py').read())"
python3 -m pytest tests/unit/test_workflow_coverage.py -q
# Audit's stale_workflow count drops from 5 → 2 (only cheap-research + ollama-research remain).
# Read the saved audit YAML rather than re-running audit (L-391: no nested audit invocation).
# Verification is a one-liner because the gate runs each line in its own subshell.
LATEST_AUDIT=$(ls -t .context/audits/[0-9]*.yaml 2>/dev/null | head -1); python3 -c "import yaml,sys; d=yaml.safe_load(open('$LATEST_AUDIT')); f=[x for x in d.get('findings',[]) if 'stale workflow' in x.get('check','')]; assert f, 'no stale workflow finding'; msg=f[0]['check']; assert 'design-dialogue' not in msg and 'grilling' not in msg and ' inception' not in msg, msg; print('PASS:', msg)"

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

## Recommendation

- **Recommendation:** **GO** — close T-1872 as work-completed. No human review needed; deterministic audit-signal improvement.
- **Rationale:** Three workflows (`inception`, `grilling`, `design-dialogue`) carry `inline: true` to mark their non-resolver-driven lifecycle. The staleness detector (T-1803) flagged them as WARN because they will never appear in `dispatches.jsonl` by design. This was a permanent false-positive — the audit signal would never go below 5 stale unless the operator deprecated workflows that are actively in use. Skipping inline rows is semantically clean (the staleness premise simply doesn't apply) and behaviour-equivalent to "remove false WARN, keep real signal". The two remaining stale workflows (`cheap-research`, `ollama-research`) are legitimate findings — declared for the resolver pipeline but never dispatched. Operator-actionable as before.
- **Evidence:**
  - `lib/workflow_coverage.py::_parse_workflows` reads `inline` from YAML; `flag_stale_workflows` early-continues on truthy `inline`.
  - 4 new tests in `tests/unit/test_workflow_coverage.py` under "T-1872" header — 30/30 pass.
  - Audit run 2026-05-16T07:21Z: stale list dropped from 5 → 2. The exact two remaining are the resolver-pipeline workflows that genuinely never dispatched. No reduction in real signal.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-05-16T07:21:39Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1872-stale-workflow-audit-exclude-inlinetrue-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-060b7cfc
- **Timestamp:** 2026-06-02T15:00:11Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#4 (Agent)** — `bin/fw audit` after the fix reports 2 stale workflows (cheap-research, ollama-research) instead of 5 — visible in `.context/audits/2026-05-16.yaml` summary line `"2 stale workflow(s): cheap-research,
  - **AC-verify-mismatch** (narrow, heuristic) — `path=context/audits/2026-05-16.yaml in: `bin/fw audit` after the fix reports 2 stale workflows (cheap-research, ollama-research) instead of 5 — visible in `.context/audits/2026-05-16.yaml` s`
### 2026-05-16T07:30:44Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
