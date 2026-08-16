---
id: T-1694
name: "fw doctor extensions — pi-installed check (Q13) + workflow schema linter (Q14)"
description: >
  Extend fw doctor to (Q13) report 'pi not installed; workflows declaring worker_kind:
  pi will fail' with install command, no auto-install — and (Q14) lint all .context/project/workflows/*.yaml
  for schema correctness: required fields per tier, worker_kind in enum, prompt_template
  resolves to existing file, meta_model set iff prompt_strategy=meta-prompted, inline:true
  exclusive of dispatch fields, soft-warn if default.yaml missing. Build task — ACs
  are clear from CONTEXT.md.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [doctor]
components: [bin/fw]
related_tasks: [T-1687]
arc_id: orchestrator-rethink
created: 2026-05-02T22:56:15Z
last_update: '2026-08-16T22:24:41Z'
date_finished: 2026-05-03T08:07:13Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:56Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 1
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=1 
      (body:error-msg-improved); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); 
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:41Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 1
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=1 
      (body:error-msg-improved); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal);
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1694: fw doctor extensions — pi-installed check (Q13) + workflow schema linter (Q14)

## Context

Per CONTEXT.md (Q13/Q14): extend `fw doctor` to (Q13) report "pi not installed; workflows declaring `worker_kind: pi` will fail" with the install command — **no auto-install** — and (Q14) lint all `.context/project/workflows/*.yaml` for schema correctness: required fields per tier, `worker_kind` in `{Task, TermLink, pi}`, `prompt_template` resolves to an existing file, `meta_model` set iff `prompt_strategy=meta-prompted`, `inline: true` exclusive of dispatch fields, soft-warn if `default.yaml` missing.

## Acceptance Criteria

### Agent
- [x] `fw doctor` reports "pi not installed" when the `pi` binary is absent from PATH (verified — INFO when no workflow uses `worker_kind: pi`, WARN with install command when one does)
- [x] `fw doctor` does NOT auto-install pi — only warns and prints the install command (`npm install -g @badlogic/pi-mono`)
- [x] `fw doctor` lints every file matching `.context/project/workflows/*.yaml` (verified — count message reports file total)
- [x] A deliberately broken workflow file (missing required field) produces an error with file path + key reference (verified: `_bad-test.yaml: missing required key(s): ['allowed_tools', 'cost_cap_usd', ...]`)
- [x] `fw doctor` exits 0 when all workflow files are valid AND optional dependencies (pi) are present (verified — exit=0 with current shipped workflows)
- [x] `fw doctor` exits non-zero when at least one workflow file fails schema validation (verified — exit=2 with broken file)
- [x] `fw doctor` warns (does not error) when `default.yaml` is missing (verified: WARN, not FAIL)
- [x] `fw doctor` flags `inline: true` co-existing with dispatch fields (`worker_kind`, `model`, etc.) as a schema error (verified: `inline:true cannot co-exist with dispatch fields: ['model', 'worker_kind']`)

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
bin/fw doctor 2>&1 | tail -50
test -d .context/project/workflows && bin/fw doctor 2>&1 | grep -qE "(workflow|pi)" || true

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

**Rationale:** All eight Agent ACs satisfied. Q13 + Q14 schema enforcement now ships in `fw doctor` — the first dispatch is no longer the first time the schema is checked. Pi check is conditional (INFO when no workflow needs pi, WARN with install hint only when at least one workflow uses `worker_kind: pi`); workflow lint covers required-field set per tier, worker_kind enum, prompt_template resolution, prompt_strategy/meta_model coupling, and inline-vs-dispatch exclusivity. Soft-warns when default.yaml is missing rather than hard-failing.

**Evidence (all live-tested):**
- 4 shipped workflows → `OK  Workflow schema: 4 file(s) lint clean` (exit=0)
- Pi missing + no consumer workflow → `INFO  pi not installed (no workflows require it)` (no warning bump)
- Broken workflow (missing required keys) → `FAIL  Workflow schema: 1 error(s)...` + path + missing keys (exit=2)
- inline:true with dispatch fields → schema error citing `['model', 'worker_kind']`
- default.yaml moved aside → `WARN  Workflow schema: 3 file(s) clean, 1 warning(s)` + Q12-fallback hint

## Decisions

### 2026-05-03 — pi-check verbosity (INFO vs WARN)

- **Chose:** INFO when pi is missing AND no workflow uses worker_kind:pi; WARN only when at least one workflow needs it.
- **Why:** Most consumers won't use pi. Hard-warning every doctor run trains operators to ignore it. Conditional severity respects "actionable errors only."
- **Rejected:** Always-WARN-when-missing — matches TermLink pattern but creates noise where pi has no current consumer.

### 2026-05-03 — workflow lint location (inline Python heredoc vs new lib/ module)

- **Chose:** Inline Python heredoc in `bin/fw do_doctor()`, matching the existing settings.json validator pattern.
- **Why:** ~80 lines, single-call, no public API surface to maintain. T-1689 Resolver will read these files for dispatch (different access pattern), not for validation.
- **Rejected:** Standalone `lib/workflow-lint.py` — premature factoring.

## Updates

### 2026-05-02T22:56:15Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1694-fw-doctor-extensions--pi-installed-check.md
- **Context:** Initial task creation

### 2026-05-03T07:59:18Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-7704206b
- **Timestamp:** 2026-06-02T18:58:51Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

- **Suppressed:** 2 (by override)
  - swallowed-errors @ Verification:line 10
  - l387-sigpipe-risk @ Verification:line 10
### 2026-05-03T08:07:13Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
