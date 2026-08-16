---
id: T-1841
name: "find_project_root sentinel — skip .agentic-framework / rollback dirs (consumer
  F3-trap)"
description: >
  Consumer email-archive's F3-trap finding: agent CWD landed in .agentic-framework.rollback/
  → find_project_root walked up, found .agentic-framework.rollback/.tasks/ (from vendored
  templates), returned .agentic-framework.rollback as PROJECT_ROOT. Boundary hook
  (T-559) then blocked all cd /opt/... commands. Root cause: bin/fw:61-71 find_project_root
  returns at the first dir with .framework.yaml OR .tasks/ — but .tasks/ alone is
  ambiguous (vendored framework has .tasks/templates/, rollback dir inherits it, uninitialized
  consumer has just .tasks/). Fix: drop a .fw-not-a-project sentinel in .agentic-framework/
  and .agentic-framework.rollback/ at vendor/rollback time. find_project_root checks
  for sentinel and skips the dir. Source: framework:pickup offset 1 F3-trap finding
  (email-archive, 2026-05-04).

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [consumer-fleet, bug, fw-cli]
components: [bin/fw, lib/update.sh]
related_tasks: [T-1838, T-1839, T-1840, T-559]
arc_id: project-shape-resilience
created: 2026-05-14T22:09:58Z
last_update: '2026-08-16T22:24:46Z'
date_finished: 2026-05-14T22:14:38Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:00Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:46Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); F-AUTONOMY=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-1841: find_project_root sentinel — skip .agentic-framework / rollback dirs (consumer F3-trap)

## Context

`bin/fw:61-71` `find_project_root` returns the first ancestor that has EITHER `.framework.yaml` OR a `.tasks/` directory. `.tasks/` alone is ambiguous: it appears legitimately in (a) uninitialised consumers, (b) vendored framework copies (`.agentic-framework/.tasks/templates/` ships from upstream), and (c) rollback dirs (`.agentic-framework.rollback/.tasks/templates/` inherits the structure from `cp -r vendored rollback_dir` at `lib/update.sh:175`).

The consumer F3-trap report: agent CWD ended up inside `.agentic-framework.rollback/`. find_project_root walked up, hit `.agentic-framework.rollback/.tasks/`, returned `.agentic-framework.rollback` as PROJECT_ROOT. Boundary hook (T-559) then blocked every `cd /opt/<consumer>` because that's "outside PROJECT_ROOT" — session became unusable, no escape route within the rules.

Fix: drop a marker file `.fw-not-a-project` inside `.agentic-framework/` (at vendor time) and inside `.agentic-framework.rollback/` (at rollback time). `find_project_root` checks for this sentinel and skips the dir, continuing the upward walk to the real consumer root.

## Acceptance Criteria

### Agent
- [x] `bin/fw:find_project_root` skips any directory containing a `.fw-not-a-project` sentinel and continues the upward walk
- [x] `bin/fw:do_vendor` writes `.fw-not-a-project` to `$dest/` after the include loop completes
- [x] `lib/update.sh:_do_rollback` and the rollback-creation path (`cp -r vendored rollback_dir`) write `.fw-not-a-project` to `$rollback_dir/`
- [x] Sentinel content includes a one-line explanation so a curious operator finds context (referencing T-1841)
- [x] Bats test `tests/unit/test_find_project_root_sentinel.bats` pins (a) walk skips dir with sentinel, (b) walk stops at dir without sentinel, (c) sentinel content carries the explanation — 8/8 pass
- [x] Existing project-root tests (if any) still pass — no existing test references find_project_root behaviour
- [x] `bash -n bin/fw lib/update.sh` parses clean — verified

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
bash -n lib/update.sh
test -f tests/unit/test_find_project_root_sentinel.bats
bats tests/unit/test_find_project_root_sentinel.bats > /tmp/t1841-bats.out 2>&1 && ! grep -q "^not ok " /tmp/t1841-bats.out
grep -q "fw-not-a-project" bin/fw
grep -q "fw-not-a-project" lib/update.sh

## RCA

**Symptom:** Consumer agent's CWD inside `.agentic-framework.rollback/` → all subsequent `cd /opt/<consumer>` commands blocked by boundary hook (T-559) because find_project_root mis-identified the rollback dir as PROJECT_ROOT. Session-fatal: no escape from inside the rules.

**Root cause:** `find_project_root` (bin/fw:61-71) uses `.framework.yaml || .tasks/` as the project-root signal. The OR is too permissive — `.tasks/` alone is ambiguous because vendored framework copies and rollback dirs both inherit `.tasks/templates/` from the framework's own structure.

**Why structurally allowed:** No test exercised the "PWD is inside a vendored framework copy" scenario. The vendored framework's own self-contents were never modelled as a confound. The boundary hook's blast radius (every `cd` blocked) made the bug session-fatal but pretty visible — but invisible to the framework's own self-tests because they run from the framework repo, not from inside a vendored copy.

**Prevention:** New bats fixture builds a synthetic `.agentic-framework.rollback/.tasks/templates/` and asserts `find_project_root` walks past it to the consumer root. Pins the sentinel contract — any future refactor that drops sentinel checking fails the test. Companion CLAUDE.md learning candidate: "every `find ancestor` walker in framework code must support an opt-out signal — otherwise legitimate-looking-but-wrong matches will trap users in surprising states."

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

### 2026-05-14 — sentinel-based skip vs blacklist approach

- **What changed:** Initial mental design was to teach find_project_root that any directory whose basename starts with `.agentic-framework` should be skipped. That works for the two known cases but couples the resolver to specific dir names. Sentinel approach is more semantic — any caller that wants to mark "this looks like a project but isn't" gets the skip behaviour by dropping the marker file. The skip clause is one block, the marker contract is documented at write sites.
- **Plan impact:** None to the AC set; the sentinel approach is the one captured in the original task description. Just confirmed at implementation time.
- **Triggered:** No new sub-tasks. Companion learning candidate filed in RCA-Prevention block — "every find-ancestor walker needs an opt-out signal" is potentially codifiable in a CLAUDE.md rule.

### 2026-05-14 — current `.agentic-framework/` backfilled inline

- **What changed:** Discovered the framework's own `.agentic-framework/` (current vendored copy) lacked the sentinel because it was vendored before T-1841 landed. New rule: vendor and rollback both write the sentinel forward, but existing vendored copies need a one-time backfill. Did it inline for this anchor (one Write tool call) since it's framework hygiene; for consumer fleet, the next `fw upgrade` cycle will re-vendor with sentinel.
- **Plan impact:** No AC change; backfill is operational housekeeping.
- **Triggered:** No new sub-task. Consumers who never re-vendor stay unprotected until the next `fw upgrade` runs against them — but with T-1838 + T-1839 also in place, they're protected from the most common trigger (silent downgrade routing them into a rollback dance).

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

### 2026-05-14T22:09:58Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1841-findprojectroot-sentinel--skip-agentic-f.md
- **Context:** Initial task creation

### 2026-05-14 — sentinel scheme shipped + backfill + bats
- **Action:** Edited `bin/fw:find_project_root` (lines 61-83) to skip dirs with .fw-not-a-project sentinel. Added sentinel write in `do_vendor` (lines ~344-352). Added sentinel write in `_do_rollback`/rollback creation path at `lib/update.sh:175-184`. Backfilled current `.agentic-framework/.fw-not-a-project`. Added `tests/unit/test_find_project_root_sentinel.bats` (8 tests).
- **Output:** `bin/fw` (+22 LOC across two sites), `lib/update.sh` (+8 LOC), `.agentic-framework/.fw-not-a-project` (new, 4 lines), `tests/unit/test_find_project_root_sentinel.bats` (new, 8/8 pass)
- **Context:** Closes consumer F3-trap. Future `fw vendor` and `fw update` cycles automatically carry the sentinel forward.

## Recommendation

**Recommendation:** GO

**Rationale:** Session-fatal trap (consumer agent CWD inside vendored copy = no escape via cd) closed by a single-purpose semantic marker. Both write sites (vendor + rollback) carry the sentinel forward; the read site (find_project_root) checks it before honoring the `.tasks/` signal. Sentinel content is self-explanatory and references T-1841 — operator who finds the file via `ls -la` gets context immediately. Pure additive — no existing flows changed.

**Evidence:**
- `bin/fw:61-83`: find_project_root sentinel skip clause
- `bin/fw:344-352`: do_vendor sentinel write
- `lib/update.sh:175-184`: rollback dir sentinel write
- `.agentic-framework/.fw-not-a-project`: framework's own vendored copy backfilled
- `tests/unit/test_find_project_root_sentinel.bats`: 8/8 pass — walk skip + without-sentinel control + source pins + parse checks + backfill check
- `bash -n bin/fw lib/update.sh`: clean
- Consumer F3-trap (framework:pickup offset 1) closed by this fix

## Reviewer Verdict (v1.5)

- **Scan ID:** R-45a314d7
- **Timestamp:** 2026-06-02T14:59:58Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-14T22:14:38Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
