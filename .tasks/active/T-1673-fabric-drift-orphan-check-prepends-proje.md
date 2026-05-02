---
id: T-1673
name: "fabric drift orphan check prepends PROJECT_ROOT even for absolute paths — false orphans for cross-repo cards"
description: >
  fabric drift orphan check prepends PROJECT_ROOT even for absolute paths — false orphans for cross-repo cards

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-05-02T08:59:51Z
last_update: 2026-05-02T08:59:51Z
date_finished: null
---

# T-1673: fabric drift orphan check prepends PROJECT_ROOT even for absolute paths — false orphans for cross-repo cards

## Context

`agents/fabric/lib/drift.sh:55` checks orphan status with:
```bash
if [ -n "$loc" ] && [ ! -f "$PROJECT_ROOT/$loc" ]; then
```
This unconditionally prepends `$PROJECT_ROOT` to `$loc`. For cross-repo
fabric cards shipped under T-1652 (6 cards: termlink-bypass,
termlink-circuit-breaker, termlink-governance-frame,
termlink-governance-subscriber, termlink-route-cache, termlink-router),
the `location:` field is an absolute path like
`/opt/termlink/crates/termlink-hub/src/bypass.rs`. The check becomes
`! -f "/opt/999-Agentic-Engineering-Framework//opt/termlink/.../bypass.rs"`
which is always true → all 6 cross-repo cards are reported as orphaned
on every `fw fabric drift` run, even though the files exist at their
absolute locations.

Fix: detect absolute paths (`loc` starts with `/`) and skip the prefix
in that case. Same pattern is needed in the stale-edge resolver (lines
68–...) for `depends_on:` targets.

## Acceptance Criteria

### Agent
- [ ] `agents/fabric/lib/drift.sh:55` orphan check handles absolute `location:` paths without prepending `$PROJECT_ROOT`
- [ ] All 6 cross-repo cards (cross-repo-termlink-{bypass,circuit-breaker,governance-frame,governance-subscriber,route-cache,router}) no longer appear in orphaned list when their absolute-path files exist
- [ ] Regression test pins the cross-repo-card-not-orphaned behaviour

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

test -f /opt/termlink/crates/termlink-hub/src/bypass.rs
test -f /opt/termlink/crates/termlink-hub/src/route_cache.rs
bash -c 'out=$(bin/fw fabric drift 2>&1); echo "$out" | grep -q "termlink-bypass.*file missing" && exit 1; exit 0'
bash -c 'out=$(bin/fw fabric drift 2>&1); echo "$out" | grep -q "termlink-route-cache.*file missing" && exit 1; exit 0'
python3 -m pytest tests/unit/test_fabric_drift_absolute_paths.py -q
# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.
#
# Toolchain hint (L-291): if you edited *.vbproj/*.csproj/*.xaml add `dotnet build`;
# *.go → `go build ./...`; Cargo.toml → `cargo check`; tsconfig.json → `tsc --noEmit`;
# pom.xml → `mvn -q compile`. P-011 runs only what you write — broken builds slip
# past otherwise (origin: 003-NTB-ATC-Plugin T-077, broken WPF DLL on master 5 days).

## RCA

**Symptom:** `bin/fw fabric drift` reports 6 cross-repo cards as
"file missing" on every run (since T-1652 shipped 2026-05-01), polluting
audit output and masking real drift.

**Root cause:** `agents/fabric/lib/drift.sh:55` does
`[ ! -f "$PROJECT_ROOT/$loc" ]` unconditionally. When `$loc` is already
absolute (cross-repo cards point at `/opt/termlink/...`), the join
becomes `$PROJECT_ROOT//opt/termlink/...` — never resolves.

**Why structurally allowed:** Cross-repo fabric cards (T-1652) were a
new pattern; prior cards always had project-relative paths. The orphan
check assumption (PROJECT_ROOT-relative locations) was correct at write
time and silently invalidated when the cross-repo card pattern was
introduced. No test enforced the orphan-check semantics on absolute
paths because the test fixtures predate cross-repo cards.

**Prevention:** Regression test (`tests/unit/test_fabric_drift_absolute_paths.py`)
that registers an absolute-path card pointing at a real file and asserts
drift does NOT mark it orphaned. Catches the next instance even if
someone "fixes" the path-handling and accidentally re-introduces the
prefix-always pattern.

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

### 2026-05-02T08:59:51Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1673-fabric-drift-orphan-check-prepends-proje.md
- **Context:** Initial task creation
