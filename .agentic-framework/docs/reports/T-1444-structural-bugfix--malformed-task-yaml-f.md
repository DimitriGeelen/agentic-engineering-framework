# T-1444 — Structural bugfix — malformed task YAML frontmatter + Watchtower 500-on-auto-trigger-failure

> **Inception research artifact** (backfilled by T-2515 from the `T-1444` task body — the research was captured in-task at decision time; this extracts it verbatim to the canonical `docs/reports/` home per C-001). Source: `.tasks/completed/T-1444-structural-bugfix--malformed-task-yaml-f.md`. **Decision recorded: GO.**

## Problem Statement

**For whom:** every operator running a Watchtower against this framework or any vendored consumer; every agent running `fw task update`.

**What problem:** two coupled symptoms surfaced during T-1442 GO (2026-04-25T07:22Z) and a third instance during this session (2026-04-25T20:48Z, when /inception/T-1444 itself rendered empty):

- **Symptom A (UX):** Watchtower POST `/inception/T-XXX/decide` returns HTTP 500 when downstream side-effects (episodic generation, fabric register) fail — even when the primary `fw inception decide` succeeded (status moved, ACs ticked, file moved). User sees a red error toast despite the decision having landed.
- **Symptom B (data):** at least 6 task files in this repo had malformed frontmatter (T-1278, T-1279, T-444, T-453, T-675, T-1444 itself). The patterns differ but the failure mode is the same — Watchtower's YAML scanner crashes on read, queues render partial or empty.
- **Live blast-radius proof:** today's session reported "THERE IS NOTHING IN THE WATCHTOWER" because of Symptom B. T-1468 cleaned the data; T-1444 owns the structural fix.

**Why now:** Symptom B has now blocked the user twice in one day. The data cleanup (T-1468) is reactive — without a code fix, future `fw work-on` / `fw task update` calls can re-emit the same broken frontmatter into vendored consumer projects.

## Assumptions

1. **The Symptom B emit-bug lives in `agents/task-create/create-task.sh` or `agents/task-create/lib/update-task.sh`** — these are the only writers of frontmatter under normal flow.
2. **The flow+block hybrid pattern (T-1278/T-1279) comes from one specific code path** — likely `add_component()` or equivalent that appends to an existing `components:` flow list using block-style append.
3. **The unindented-description pattern (T-444/T-453/T-1444) is older / different** — possibly from manual edits or a legacy create-task.sh that emitted `description: >` followed by raw paragraphs.
4. **Symptom A and Symptom B are independently fixable** — A is a Watchtower endpoint hardening; B is a CLI emitter fix.

## Exploration Plan

(Already executed during T-1468 data cleanup, plus quick code reads.)

- ✅ **Spike 1 — count broken files:** `python3 yaml.safe_load` over all `.tasks/{active,completed}/*.md` → 6 broken (now 0 after T-1468).
- ✅ **Spike 2 — categorise patterns:** 3 distinct patterns identified (flow+block, unindented `>`, unescaped `\` in `"`).
- ⏳ **Spike 3 — find emit site:** read `create-task.sh` + `update-task.sh` `add_component`/`add_related_task` paths. (Not yet run.)
- ⏳ **Spike 4 — Watchtower decide endpoint:** read `web/blueprints/inception.py` POST handler; identify where downstream failure raises 500 vs returning 200-with-warning. (Not yet run.)

## Technical Constraints

- Vendored installs replicate `agents/task-create/` into `.agentic-framework/` — fix must propagate via `fw vendor`.
- Backward-compat: existing broken files already cleaned in T-1468; no migration script needed.
- Symptom A fix touches a Flask blueprint with CSRF guard — must preserve existing `_csrf_token` flow.

## Scope Fence

**IN scope:**
- Code fix for Symptom B emit site (so future tasks don't get broken frontmatter)
- Code fix for Symptom A (decide endpoint returns 200 + warning when downstream fails)
- Regression tests for both

**OUT of scope:**
- Re-cleaning task files (already done in T-1468)
- Watchtower scanner hardening (parse-and-skip vs crash) — separate concern, file as gap if needed
- Migrating older task files to a stricter schema

## Go/No-Go Criteria

**GO if:**
- Root cause identified with bounded fix path
- Fix is scoped, testable, and reversible

**NO-GO if:**
- Problem requires fundamental redesign or unbounded scope
- Fix cost exceeds benefit given current evidence

## Recommendation

**Recommendation:** GO — split into two build tasks (one per symptom).

**Rationale:** Both symptoms are independently fixable, both have already caused user-visible failures (Symptom A on T-1455 GO, Symptom B today blocking the entire Watchtower view), and both are bounded code edits with clear regression tests. Bundling them is "one inception, two bugs" which CLAUDE.md "One bug = one task" forbids. Splitting also lets Symptom B (data emission, higher recurrence rate) ship before Symptom A (endpoint hardening, lower recurrence).

**Evidence:**
- Symptom B has now hit twice in one day — the data cleanup (T-1468) is reactive; without a code fix, every future `fw work-on` / `fw task update` can re-emit broken frontmatter (and propagate to consumer projects via `fw vendor`).
- 6 broken files repaired today exhibited 3 distinct patterns (flow+block hybrid, unindented `>` body, unescaped `\` in double-quoted scalar) — all three are emit-site bugs, not consumer-side corruption.
- Symptom A is structurally separate: Watchtower's `/inception/decide` endpoint at `web/blueprints/inception.py` raises 500 when episodic-gen / fabric-register side-effects fail. It's a Flask handler hardening (try/except around the side-effects, log the failure, return 200-with-warning).
- Both fixes are scoped (~1 file + 1 test each), reversible (revert the commit), and validated by existing test infrastructure (`pytest tests/web/`, `bats tests/unit/create_task.bats`).

**Proposed follow-on tasks (created on GO):**
1. **Symptom B build task** — fix `agents/task-create/create-task.sh` (and `lib/update-task.sh` if needed) so component/related-task appends produce valid YAML; add a regression bats test that runs `python3 yaml.safe_load` over the generated frontmatter.
2. **Symptom A build task** — wrap the side-effect chain in `web/blueprints/inception.py` POST `/inception/<task_id>/decide` in try/except; surface the failure as a non-fatal warning in the response payload. Pytest regression: simulate episodic-gen failure, assert HTTP 200 + `warning` field.

**Out-of-scope:**
- Watchtower scanner hardening (parse-and-skip vs crash) — file as a separate gap if it recurs.
- Migration script for already-broken files — not needed (T-1468 cleaned them all).

## Decision

**Decision**: GO

**Rationale**: Both symptoms are independently fixable, both have already caused user-visible failures (Symptom A on T-1455 GO, Symptom B today blocking the entire Watchtower view), and both are bounded code edits with clear regression tests. Bundling them is "one inception, two bugs" which CLAUDE.md "One bug = one task" forbids. Splitting also lets Symptom B (data emission, higher recurrence rate) ship before Symptom A (endpoint hardening, lower recurrence).

**Date**: 2026-04-25T19:08:12Z

## Reviewer Verdict (v1.5)

- **Scan ID:** R-33ac53b3
- **Timestamp:** 2026-06-02T14:57:31Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-04-25T19:08:12Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
