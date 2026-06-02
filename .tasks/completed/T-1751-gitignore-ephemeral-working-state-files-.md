---
id: T-1751
name: "gitignore ephemeral working-state files — focus.yaml.bak + escalation-drift-LATEST-v0.5.yaml accidentally tracked"
description: >
  Two ephemeral working-state files were accidentally tracked by git add -A in c2bf1682a (the T-1750 governance close). focus.yaml.bak is a backup created by focus-switching; escalation-drift-LATEST-v0.5.yaml is rewritten every 5:33 UTC cron firing and read by Watchtower for rendering. Both belong in .gitignore alongside .context/dispatches.jsonl and other ephemeral substrate. Untrack via git rm --cached + add gitignore patterns; future commits stay clean.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [hygiene, governance]
components: []
related_tasks: [T-1750, T-1727, T-1749]
arc_id: orchestrator-rethink
created: 2026-05-05T21:18:12Z
last_update: 2026-05-05T21:20:53Z
date_finished: 2026-05-05T21:20:53Z
---

# T-1751: gitignore ephemeral working-state files — focus.yaml.bak + escalation-drift-LATEST-v0.5.yaml accidentally tracked

## Context

In commit `c2bf1682a` (T-1750 governance close) my `git add -A` picked up two ephemeral working-state files that should not be tracked:

1. `.context/working/focus.yaml.bak` — backup of an old focus state (T-1700 from 2026-05-05 09:46), created by some focus-switch path. Single line, stale, never useful in future commits.
2. `.context/working/escalation-drift-LATEST-v0.5.yaml` — output of `tools/escalation-scan-v0.5.py`, rewritten every 5:33 UTC cron firing (and on every manual `--force` re-run). 257 lines representing a snapshot of one scan; the next firing rewrites it entirely. Read by Watchtower (`web/blueprints/escalation.py:25`) for rendering the v0.5 panel.

Both are the same shape as `.context/dispatches.jsonl` (already gitignored): substrate state read by the framework, not source code. Tracking them produces enormous diff noise on every cron firing and serves no archival purpose — earlier scan outputs are not useful once the next one runs.

This task: add gitignore patterns + untrack the currently-tracked copies. Same pattern that was already applied for `.context/dispatches.jsonl` (post T-1696/T-1697 substrate consolidation).

## Acceptance Criteria

### Agent
- [x] `.gitignore` contains a pattern that ignores `.context/working/*.yaml.bak` (or equivalent — covering at minimum `focus.yaml.bak`)
- [x] `.gitignore` contains a pattern that ignores `.context/working/escalation-drift-LATEST-v0.5.yaml` (or `escalation-drift-LATEST-*.yaml` if generalized for future scan versions)
- [x] `git ls-files .context/working/focus.yaml.bak` returns empty (file untracked)
- [x] `git ls-files .context/working/escalation-drift-LATEST-v0.5.yaml` returns empty (file untracked)
- [x] `git check-ignore -v .context/working/focus.yaml.bak` exits 0 (gitignore covers it)
- [x] `git check-ignore -v .context/working/escalation-drift-LATEST-v0.5.yaml` exits 0
- [x] After this task's commit, the working copies of those files still exist on disk (untrack, don't delete — Watchtower reads the YAML for rendering)
- [x] No regression: `git ls-files .gitignore` confirmed; `python3 -c "import yaml; yaml.safe_load(open('.context/working/escalation-drift-LATEST-v0.5.yaml'))"` still parses

### Human

(none — pure git-tracking hygiene)

## Verification

git ls-files .context/working/focus.yaml.bak | grep -q . && exit 1 || true
git ls-files .context/working/escalation-drift-LATEST-v0.5.yaml | grep -q . && exit 1 || true
git check-ignore -q .context/working/focus.yaml.bak
git check-ignore -q .context/working/escalation-drift-LATEST-v0.5.yaml
test -f .context/working/escalation-drift-LATEST-v0.5.yaml
python3 -c "import yaml; yaml.safe_load(open('.context/working/escalation-drift-LATEST-v0.5.yaml'))"

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

### 2026-05-05 — generalised gitignore patterns rather than literal filenames

- **What changed:** Initial patch impulse was to add literal `focus.yaml.bak` and `escalation-drift-LATEST-v0.5.yaml`. Generalised to `*.yaml.bak` and `escalation-drift-LATEST-*.yaml` so future scan versions (v0.6, v1, ...) and any future YAML-bak emission paths are covered without needing a follow-up gitignore patch.
- **Plan impact:** Both ACs widened to "or equivalent" wording so the generalisation is explicit. Pattern now matches the v1-roadmap of escalation-scan (T-1727 forward-work mentions v1 cross-model comparison).
- **Triggered:** No new task — generalisation captured here.

## Recommendation

**Recommendation:** GO — close T-1751 as work-completed.

**Rationale:** Self-discovered governance bug (my own `git add -A` in c2bf1682a tracked two ephemeral files). Fix is mechanical: add gitignore patterns + `git rm --cached`. All 8 Agent ACs satisfied; no Human ACs. Generalised patterns prevent future scan-version variants from re-introducing the bug.

**Evidence:**
- `git ls-files` returns empty for both files (untracked)
- `git check-ignore -q` exits 0 for both (gitignore covers them)
- Working copies still on disk; YAML still parses (Watchtower's `web/blueprints/escalation.py:25` read path unaffected)
- All 6 `## Verification` gates green pre-completion

## Decisions

### 2026-05-05 — generalised gitignore patterns

- **Chose:** `*.yaml.bak` and `escalation-drift-LATEST-*.yaml` (wildcards)
- **Why:** Covers future variants without follow-up patches — matches the existing pattern `dispatches-*.jsonl` already in .gitignore.
- **Rejected:** Literal filenames — too narrow; would re-leak when v0.6 scan ships.

## Updates

### 2026-05-05T21:18:12Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1751-gitignore-ephemeral-working-state-files-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-e63ac94a
- **Timestamp:** 2026-06-02T14:59:30Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 1
     - evidence: `git ls-files .context/working/focus.yaml.bak | grep -q . && exit 1 || true`
  2. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 2
     - evidence: `git ls-files .context/working/escalation-drift-LATEST-v0.5.yaml | grep -q . && exit 1 || true`
### 2026-05-05T21:20:53Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
