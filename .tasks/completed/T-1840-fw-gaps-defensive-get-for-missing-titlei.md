---
id: T-1840
name: "fw gaps: defensive .get() for missing 'title'/'id' fields (consumer report
  F4)"
description: >
  Consumer email-archive reported via framework:pickup offset 2: fw gaps crashes with
  KeyError on concerns.yaml entries lacking 'title' field. Reproduced in bin/fw:4864
  (print(f"  {gap['id']} [{sev}]  {gap['title']}")) — both gap['id'] and gap['title']
  use direct dict subscript. When concerns predates the title-field requirement (older
  consumer trees), the CLI is fully broken with no visibility into the project's own
  gaps. Suggested fix from reporter: c.get('title', '<untitled>'). Apply same defense
  to gap['id']. Source: framework:pickup F4 finding, evidence at consumer T-1382,
  commit 273894fd.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [consumer-fleet, fw-cli, bug]
components: [bin/fw]
related_tasks: [T-1838, T-1839]
created: 2026-05-14T22:03:00Z
last_update: '2026-06-11T22:24:00Z'
date_finished: 2026-05-14T22:06:49Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:00Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=2 (body:lightly-promoted); 
      F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1840: fw gaps: defensive .get() for missing 'title'/'id' fields (consumer report F4)

## Context

Consumer email-archive's F4 bug report (framework:pickup offset 2, sender d1993c2c3ec44c94, 2026-05-04): `fw gaps` crashes with `KeyError: 'title'` on `concerns.yaml` entries lacking a `title:` field. The direct subscript pattern at `bin/fw:4864` — `f"  {gap['id']} [{sev}]  {gap['title']}"` — short-circuits the entire CLI on the first malformed entry, blocking visibility into the consumer's own gaps. Reporter discovered during T-1382, workaround was backfilling all 8 entries with derived titles; that should not have been necessary.

Defensive fix: `gap.get('id', '?')` + `gap.get('title', '<untitled>')` at the print site. Pure additive — no breaking change to existing entries that have both fields.

## Acceptance Criteria

### Agent
- [x] `bin/fw:4864` uses `gap.get('id', '?')` and `gap.get('title', '<untitled>')` instead of direct subscripts
- [x] `bin/fw` parses with `bash -n` post-edit
- [x] Synthetic test: a temp concerns.yaml with a watching entry missing `title:` field runs `fw gaps` without traceback and renders `<untitled>` in the output
- [x] Synthetic test: a temp concerns.yaml with a watching entry having both `id:` and `title:` renders both unchanged (no regression for the well-formed case)
- [x] Bats test `tests/unit/test_gaps_missing_title_defaults.bats` pins both behaviours — 5/5 pass

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

bash -n bin/fw
test -f tests/unit/test_gaps_missing_title_defaults.bats
bats tests/unit/test_gaps_missing_title_defaults.bats > /tmp/t1840-bats.out 2>&1 && ! grep -q "^not ok " /tmp/t1840-bats.out
grep -q "gap.get('title'" bin/fw

## RCA

**Symptom:** Consumer email-archive ran `fw gaps` against their `.context/project/concerns.yaml` (8 entries, all predating the title-field requirement). The CLI exited with `Traceback ... KeyError: 'title'` and no gap entries were rendered — full breakage of the visibility surface that gaps register exists to provide.

**Root cause:** `bin/fw:4864` accesses `gap['title']` and `gap['id']` via direct dict subscript. Python's dict subscript raises KeyError on missing keys instead of falling back to a default. The first malformed entry in the iteration killed the entire output stream.

**Why structurally allowed:** No test fixture exercised `fw gaps` against legacy/partial concerns entries. The schema expectation (every concern MUST have `id` and `title`) is implicit in the writer code path but the reader doesn't validate or default. The framework's own concerns.yaml has well-formed entries, so the framework's self-test never hit the path. The class is "framework code assumes schema completeness it doesn't enforce".

**Prevention:** New bats fixture builds a concerns.yaml with one missing-title entry and asserts (a) no traceback, (b) `<untitled>` placeholder renders. This pins the defensive behaviour and catches a regression to direct-subscript. Companion learning candidate: "any reader of project-state YAML files (concerns, focus, audit-history) should use `.get(key, default)` since consumer states pre-date current schemas — schema migrations are gradual, never atomic."

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

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-05-14T22:03:00Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1840-fw-gaps-defensive-get-for-missing-titlei.md
- **Context:** Initial task creation

### 2026-05-14 — fix shipped + bats coverage
- **Action:** Edited `bin/fw:4864` to replace direct subscripts (`gap['id']` and `gap['title']`) with defensive `.get()` calls (defaults `'?'` and `'<untitled>'`). Added `tests/unit/test_gaps_missing_title_defaults.bats` (5 tests) exercising real `fw gaps` invocation against synthetic concerns.yaml fixtures.
- **Output:** `bin/fw` (+3 LOC, 1 LOC removed), `tests/unit/test_gaps_missing_title_defaults.bats` (new, 5/5 pass)
- **Context:** Direct reproduction of the consumer F4 report — pre-fix `fw gaps` on a concerns.yaml entry missing `title:` field crashed with `KeyError: 'title'`. Post-fix renders `<untitled>` and continues iteration. Test fixture caveat: top-level YAML must use `concerns:` key (not bare list) — caught during test debug.

## Recommendation

**Recommendation:** GO

**Rationale:** Direct dict subscripts in user-facing readers are a known foot-gun when projects evolve schemas gradually (consumers don't migrate atomically). The defensive `.get()` fix is minimal, pure-additive, and the behavioural bats fixture catches the next regression to direct-subscript. The class of bug ("framework reader assumes schema completeness it doesn't enforce") would benefit from a sweep — but T-1840 keeps this slice scoped to the reported instance.

**Evidence:**
- `bin/fw:4864-4866`: `gap.get('id', '?')` + `gap.get('title', '<untitled>')`
- `tests/unit/test_gaps_missing_title_defaults.bats`: 5/5 — covers missing-title / missing-id / well-formed / source-pin / parse-check
- Consumer F4 report (framework:pickup offset 2, sender d1993c2c3ec44c94, 2026-05-04) closed by this fix
- Bash parse: clean

## Reviewer Verdict (v1.5)

- **Scan ID:** R-530ec93c
- **Timestamp:** 2026-06-02T14:59:58Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-14T22:06:49Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
