---
id: T-1824
name: "lib/upgrade.sh:1068 pyc_count grep -c || echo 0 yields 0\n0 — integer-expr breaks every upgrade run"
description: >
  FB-C-F1 (LOW/cosmetic but every-run) reported by penelope (050-email-archive). lib/upgrade.sh:1068-1070 sets pyc_count via 'grep -c ... || echo 0'. grep -c returns exit 1 when zero matches DESPITE outputting 0; the || echo 0 then appends a second '0' line. pyc_count becomes '0\n0', breaking the subsequent [ -gt 0 ] integer test. Symptom: every fw upgrade prints 'line 1070: [: 0\n0: integer expression expected'. Suggested fix: replace with pyc_count=$(cd "$target_dir" && git ls-files .agentic-framework/ 2>/dev/null | grep -E '__pycache__|\.pyc$' | wc -l) — wc -l drops grep's exit code.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [fw-upgrade-incident-2026-05-14, cosmetic, bug]
components: []
related_tasks: []
created: 2026-05-14T07:30:53Z
last_update: 2026-05-14T07:34:55Z
date_finished: null
---

# T-1824: lib/upgrade.sh:1068 pyc_count grep -c || echo 0 yields 0\n0 — integer-expr breaks every upgrade run

## Context

Reported by penelope (050-email-archive) during fw-upgrade-incident-2026-05-14. `lib/upgrade.sh:1091-1092` pipes `git ls-files` to `grep -c -E '__pycache__|\.pyc$' ... || echo 0`. `grep -c` returns exit 1 when zero matches DESPITE outputting `0`; the `|| echo 0` then appends a second `0` line. `pyc_count` becomes `"0\n0"`, breaking the subsequent `[ -gt 0 ]` integer test. Cosmetic but fires on every `fw upgrade` run.

## Acceptance Criteria

### Agent
- [ ] `lib/upgrade.sh` no longer uses `grep -c ... || echo 0` for `pyc_count`; replaced with `wc -l` (exits 0 even on zero matches).
- [ ] Running `fw upgrade --dry-run` produces no `[: 0\n0: integer expression expected` on stderr (reproducer fixed).
- [ ] Detection still fires correctly when tracked `__pycache__/.pyc` exist (manual fixture).

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

### 2026-05-14T07:30:53Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1824-libupgradesh1068-pyccount-grep--c--echo-.md
- **Context:** Initial task creation

### 2026-05-14T07:34:55Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
